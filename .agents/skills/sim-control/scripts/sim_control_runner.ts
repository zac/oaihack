#!/usr/bin/env bun
/**
 * CLI helper for simulator control via AXe and simctl.
 *
 * Run with: bun skill/sim-control/scripts/sim_control_runner.ts <command> [options]
 */

import { exec } from "child_process";
import { promisify } from "util";
import * as fs from "fs";
import * as path from "path";

const execAsync = promisify(exec);

type ExecOptions = { maxBuffer?: number };
type ExecResult = { stdout: string; stderr: string };
type ExecFn = (cmd: string, options?: ExecOptions) => Promise<ExecResult>;

const defaultExec: ExecFn = (cmd, options) => execAsync(cmd, options);
let execFn: ExecFn = defaultExec;

export function setDeps(next: Partial<{ exec: ExecFn }>): void {
  if (next.exec) {
    execFn = next.exec;
  }
}

export function resetDeps(): void {
  execFn = defaultExec;
}

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const DEFAULT_DEVICE_NAME = "iPhone 17 Pro";
const DEFAULT_OS_VERSION = "26.0.1";
const DEFAULT_OUTPUT_DIR = "./sim-output";

// ─────────────────────────────────────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────────────────────────────────────

interface SimControlConfig {
  defaultDevice?: string;
  defaultOsVersion?: string;
  outputDir?: string;
  derivedDataPath?: string;
}

export function loadConfig(configPath?: string): SimControlConfig {
  const searchPaths = [
    configPath,
    ".simcontrol",
    path.join(process.cwd(), ".simcontrol"),
  ].filter(Boolean) as string[];

  for (const searchPath of searchPaths) {
    if (fs.existsSync(searchPath)) {
      try {
        const content = fs.readFileSync(searchPath, "utf-8");
        const config = JSON.parse(content) as SimControlConfig;
        console.log(`Loaded config from: ${searchPath}`);
        return config;
      } catch (error) {
        console.warn(`Warning: Failed to parse config at ${searchPath}: ${error}`);
      }
    }
  }

  return {};
}

function getEffectiveDefaults(config: SimControlConfig): {
  deviceName: string;
  osVersion: string;
  outputDir: string;
  derivedDataPath: string;
} {
  return {
    deviceName: config.defaultDevice ?? DEFAULT_DEVICE_NAME,
    osVersion: config.defaultOsVersion ?? DEFAULT_OS_VERSION,
    outputDir: config.outputDir ?? DEFAULT_OUTPUT_DIR,
    derivedDataPath: config.derivedDataPath ?? "./DerivedData",
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

interface SimulatorInfo {
  udid: string;
  name: string;
  state: string;
  osVersion: string;
}

interface FlowStep {
  action: string;
  [key: string]: any;
}

// ─────────────────────────────────────────────────────────────────────────────
// Utility Functions
// ─────────────────────────────────────────────────────────────────────────────

function formatCommand(cmd: string[]): string {
  return cmd.map((part) => (part.includes(" ") ? `'${part}'` : part)).join(" ");
}

function versionTuple(version: string): number[] {
  const parts = version.split(".").map((p) => parseInt(p, 10) || 0);
  while (parts.length < 3) parts.push(0);
  return parts;
}

function compareVersions(a: string, b: string): number {
  const partsA = versionTuple(a);
  const partsB = versionTuple(b);
  for (let i = 0; i < 3; i++) {
    if (partsB[i] !== partsA[i]) return partsB[i] - partsA[i];
  }
  return 0;
}

function parseAxeListLine(line: string): SimulatorInfo | null {
  const parts = line.split("|").map((chunk) => chunk.trim());
  if (parts.length < 5) return null;

  const udid = parts[0];
  const name = parts[1];
  const state = parts[2];
  const osToken = parts[parts.length - 1];

  let osVersion = "";
  if (osToken.includes("OS '")) {
    const osPart = osToken.split("OS '").pop()?.replace(/'/g, "").trim() ?? "";
    osVersion = osPart.startsWith("iOS ") ? osPart.replace("iOS ", "") : osPart;
  }

  return { udid, name, state, osVersion };
}

function timestamp(): string {
  const now = new Date();
  const pad = (n: number) => n.toString().padStart(2, "0");
  return `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
}

function ensureOutputDir(dirPath: string): void {
  fs.mkdirSync(dirPath, { recursive: true });
}

function defaultScreenshotPath(outputDir: string, name?: string): string {
  ensureOutputDir(outputDir);
  const suffix = name ?? "screenshot";
  return path.join(outputDir, `${suffix}-${timestamp()}.png`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Simulator Discovery
// ─────────────────────────────────────────────────────────────────────────────

async function axeListSimulators(): Promise<SimulatorInfo[]> {
  try {
    const { stdout } = await execFn("axe list-simulators", {
      maxBuffer: 10 * 1024 * 1024,
    });
    const sims: SimulatorInfo[] = [];
    for (const line of stdout.split("\n")) {
      const info = parseAxeListLine(line);
      if (info) sims.push(info);
    }
    if (sims.length === 0) {
      throw new Error("No simulators found from axe list-simulators");
    }
    return sims;
  } catch (error: any) {
    throw new Error(error.stderr?.trim() || "axe list-simulators failed");
  }
}

async function simctlListSimulators(): Promise<SimulatorInfo[]> {
  try {
    const { stdout } = await execFn("xcrun simctl list devices --json", {
      maxBuffer: 10 * 1024 * 1024,
    });
    const payload = JSON.parse(stdout);
    const devices = payload.devices ?? {};
    const sims: SimulatorInfo[] = [];

    for (const [runtimeId, deviceList] of Object.entries(devices)) {
      if (!runtimeId.includes("iOS")) continue;
      const osVersion = runtimeId.split("iOS-").pop()?.replace(/-/g, ".") ?? "";

      for (const device of deviceList as any[]) {
        if (device.isAvailable) {
          sims.push({
            udid: device.udid ?? "",
            name: device.name ?? "",
            state: device.state ?? "",
            osVersion,
          });
        }
      }
    }

    if (sims.length === 0) {
      throw new Error("No simulators found from simctl");
    }
    return sims;
  } catch (error: any) {
    throw new Error(error.stderr?.trim() || "simctl list devices failed");
  }
}

async function listSimulators(): Promise<SimulatorInfo[]> {
  try {
    return await axeListSimulators();
  } catch {
    return await simctlListSimulators();
  }
}

async function chooseSimulator(
  deviceName: string,
  osVersion?: string
): Promise<SimulatorInfo> {
  const sims = await listSimulators();
  const nameLower = deviceName.toLowerCase();

  let matchingName = sims.filter((s) =>
    s.name.toLowerCase().includes(nameLower)
  );
  if (matchingName.length === 0) {
    matchingName = sims;
  }

  if (osVersion) {
    const exact = matchingName.filter((s) => s.osVersion === osVersion);
    if (exact.length > 0) {
      return exact.sort((a, b) => compareVersions(a.osVersion, b.osVersion))[0];
    }
  }

  return matchingName.sort((a, b) => compareVersions(a.osVersion, b.osVersion))[0];
}

async function resolveUdid(
  udid?: string,
  deviceName?: string,
  osVersion?: string
): Promise<string> {
  if (udid) return udid;

  const device = deviceName ?? DEFAULT_DEVICE_NAME;
  const os = osVersion ?? DEFAULT_OS_VERSION;
  const sim = await chooseSimulator(device, os);

  if (sim.osVersion !== os) {
    console.error(
      `Warning: requested iOS ${os} not found; using iOS ${sim.osVersion} on ${sim.name} (${sim.udid}).`
    );
  }
  return sim.udid;
}

// ─────────────────────────────────────────────────────────────────────────────
// Command Execution
// ─────────────────────────────────────────────────────────────────────────────

async function run(cmd: string[]): Promise<void> {
  console.log(`Command: ${formatCommand(cmd)}`);
  try {
    const { stdout, stderr } = await execFn(cmd.join(" "), {
      maxBuffer: 10 * 1024 * 1024,
    });
    if (stdout) console.log(stdout);
    if (stderr) console.error(stderr);
  } catch (error: any) {
    if (error.stdout) console.log(error.stdout);
    if (error.stderr) console.error(error.stderr);
    throw new Error(`Command failed with exit code ${error.code ?? 1}`);
  }
}

async function runAxe(cmd: string[]): Promise<void> {
  await run(cmd);
}

// ─────────────────────────────────────────────────────────────────────────────
// App Discovery
// ─────────────────────────────────────────────────────────────────────────────

function findAppPath(derivedData: string, appName?: string): string | null {
  const candidates: { path: string; mtime: number }[] = [];

  function walkDir(dir: string): void {
    let entries: fs.Dirent[];
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const fullPath = path.join(dir, entry.name);

      if (entry.name.endsWith(".app")) {
        if (appName && entry.name.toLowerCase() !== `${appName.toLowerCase()}.app`) {
          continue;
        }
        try {
          const stat = fs.statSync(fullPath);
          candidates.push({ path: fullPath, mtime: stat.mtimeMs });
        } catch {
          // Ignore stat errors
        }
      } else {
        walkDir(fullPath);
      }
    }
  }

  walkDir(derivedData);
  if (candidates.length === 0) return null;

  candidates.sort((a, b) => b.mtime - a.mtime);
  return candidates[0].path;
}

function bundleIdFromApp(appPath: string): string | null {
  const infoPath = path.join(appPath, "Info.plist");
  if (!fs.existsSync(infoPath)) return null;

  try {
    // Use plutil to convert plist to JSON and read CFBundleIdentifier
    const { execSync } = require("child_process");
    const json = execSync(`plutil -convert json -o - "${infoPath}"`, {
      encoding: "utf-8",
    });
    const data = JSON.parse(json);
    return data.CFBundleIdentifier ?? null;
  } catch {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Commands
// ─────────────────────────────────────────────────────────────────────────────

interface DeviceOptions {
  udid?: string;
  deviceName?: string;
  osVersion?: string;
}

async function cmdListSimulators(): Promise<number> {
  const sims = await listSimulators();
  sims.sort((a, b) => {
    const versionCmp = compareVersions(a.osVersion, b.osVersion);
    if (versionCmp !== 0) return versionCmp;
    return a.name.localeCompare(b.name);
  });

  for (const sim of sims) {
    console.log(`${sim.udid} | ${sim.name} | ${sim.state} | iOS ${sim.osVersion}`);
  }
  return 0;
}

async function cmdBoot(options: DeviceOptions & { noWait?: boolean }): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  await run(["xcrun", "simctl", "boot", udid]);
  if (!options.noWait) {
    await run(["xcrun", "simctl", "bootstatus", udid, "-b"]);
  }
  return 0;
}

async function cmdShutdown(options: DeviceOptions): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  await run(["xcrun", "simctl", "shutdown", udid]);
  return 0;
}

async function cmdInstall(
  options: DeviceOptions & {
    appPath?: string;
    appName?: string;
    derivedData?: string;
  }
): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  let appPath = options.appPath;

  if (!appPath) {
    appPath = findAppPath(options.derivedData ?? "./DerivedData", options.appName) ?? undefined;
  }
  if (!appPath) {
    throw new Error(
      "App path not found. Provide --app-path or --app-name with --derived-data."
    );
  }

  await run(["xcrun", "simctl", "install", udid, appPath]);
  return 0;
}

async function cmdLaunch(
  options: DeviceOptions & {
    bundleId?: string;
    appPath?: string;
    appArgs?: string[];
  }
): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  let bundleId = options.bundleId;

  if (!bundleId && options.appPath) {
    bundleId = bundleIdFromApp(options.appPath) ?? undefined;
  }
  if (!bundleId) {
    throw new Error("Bundle id not found. Provide --bundle-id or --app-path.");
  }

  const cmd = ["xcrun", "simctl", "launch", udid, bundleId];
  if (options.appArgs && options.appArgs.length > 0) {
    cmd.push(...options.appArgs);
  }
  await run(cmd);
  return 0;
}

async function cmdInstallLaunch(
  options: DeviceOptions & {
    appPath?: string;
    appName?: string;
    derivedData?: string;
    bundleId?: string;
    appArgs?: string[];
  }
): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  let appPath = options.appPath;

  if (!appPath) {
    appPath = findAppPath(options.derivedData ?? "./DerivedData", options.appName) ?? undefined;
  }
  if (!appPath) {
    throw new Error(
      "App path not found. Provide --app-path or --app-name with --derived-data."
    );
  }

  await run(["xcrun", "simctl", "install", udid, appPath]);

  const bundleId = options.bundleId ?? bundleIdFromApp(appPath);
  if (!bundleId) {
    throw new Error(
      "Bundle id not found. Provide --bundle-id or ensure Info.plist exists."
    );
  }

  const cmd = ["xcrun", "simctl", "launch", udid, bundleId];
  if (options.appArgs && options.appArgs.length > 0) {
    cmd.push(...options.appArgs);
  }
  await run(cmd);
  return 0;
}

async function cmdTerminate(
  options: DeviceOptions & { bundleId: string }
): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  await run(["xcrun", "simctl", "terminate", udid, options.bundleId]);
  return 0;
}

async function cmdOpenUrl(options: DeviceOptions & { url: string }): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  await run(["xcrun", "simctl", "openurl", udid, options.url]);
  return 0;
}

async function cmdDescribeUi(
  options: DeviceOptions & { output?: string }
): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  const cmd = ["axe", "describe-ui", "--udid", udid];

  try {
    const { stdout, stderr } = await execFn(cmd.join(" "), {
      maxBuffer: 10 * 1024 * 1024,
    });

    if (options.output) {
      fs.writeFileSync(options.output, stdout, "utf-8");
      console.log(`Wrote ${options.output}`);
    } else {
      console.log(stdout);
    }
    return 0;
  } catch (error: any) {
    throw new Error(error.stderr?.trim() || "axe describe-ui failed");
  }
}

async function cmdTap(
  options: DeviceOptions & {
    x?: number;
    y?: number;
    elementId?: string;
    label?: string;
    preDelay?: number;
    postDelay?: number;
  }
): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  const cmd = ["axe", "tap", "--udid", udid];

  if (options.x !== undefined && options.y !== undefined) {
    cmd.push("-x", String(options.x), "-y", String(options.y));
  }
  if (options.elementId) {
    cmd.push("--id", options.elementId);
  }
  if (options.label) {
    cmd.push("--label", options.label);
  }
  if (options.preDelay !== undefined) {
    cmd.push("--pre-delay", String(options.preDelay));
  }
  if (options.postDelay !== undefined) {
    cmd.push("--post-delay", String(options.postDelay));
  }

  await runAxe(cmd);
  return 0;
}

async function cmdType(
  options: DeviceOptions & {
    text?: string;
    stdin?: boolean;
    file?: string;
  }
): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  const cmd = ["axe", "type", "--udid", udid];

  if (options.stdin) {
    // Read from stdin
    const chunks: Buffer[] = [];
    for await (const chunk of process.stdin) {
      chunks.push(chunk);
    }
    const text = Buffer.concat(chunks).toString("utf-8");
    cmd.splice(2, 0, text);
    await runAxe(cmd);
    return 0;
  }

  if (options.file) {
    cmd.splice(2, 0, "--file", options.file);
    await runAxe(cmd);
    return 0;
  }

  if (!options.text) {
    throw new Error("Provide text, --stdin, or --file.");
  }
  cmd.splice(2, 0, options.text);
  await runAxe(cmd);
  return 0;
}

async function cmdSwipe(
  options: DeviceOptions & {
    startX: number;
    startY: number;
    endX: number;
    endY: number;
    duration?: number;
    delta?: number;
    preDelay?: number;
    postDelay?: number;
  }
): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  const cmd = [
    "axe",
    "swipe",
    "--start-x",
    String(options.startX),
    "--start-y",
    String(options.startY),
    "--end-x",
    String(options.endX),
    "--end-y",
    String(options.endY),
    "--udid",
    udid,
  ];

  if (options.duration !== undefined) {
    cmd.push("--duration", String(options.duration));
  }
  if (options.delta !== undefined) {
    cmd.push("--delta", String(options.delta));
  }
  if (options.preDelay !== undefined) {
    cmd.push("--pre-delay", String(options.preDelay));
  }
  if (options.postDelay !== undefined) {
    cmd.push("--post-delay", String(options.postDelay));
  }

  await runAxe(cmd);
  return 0;
}

async function cmdButton(
  options: DeviceOptions & {
    buttonType: string;
    duration?: number;
  }
): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  const cmd = ["axe", "button", options.buttonType, "--udid", udid];

  if (options.duration !== undefined) {
    cmd.push("--duration", String(options.duration));
  }

  await runAxe(cmd);
  return 0;
}

async function cmdScreenshot(
  options: DeviceOptions & {
    output?: string;
    outputDir?: string;
    name?: string;
  }
): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  const outputPath =
    options.output ??
    defaultScreenshotPath(options.outputDir ?? DEFAULT_OUTPUT_DIR, options.name);

  const cmd = ["axe", "screenshot", "--udid", udid, "--output", outputPath];
  await runAxe(cmd);
  return 0;
}

async function cmdRecordVideo(
  options: DeviceOptions & {
    fps?: number;
    quality?: number;
    scale?: number;
    output?: string;
  }
): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  const cmd = ["axe", "record-video", "--udid", udid];

  if (options.fps !== undefined) {
    cmd.push("--fps", String(options.fps));
  }
  if (options.quality !== undefined) {
    cmd.push("--quality", String(options.quality));
  }
  if (options.scale !== undefined) {
    cmd.push("--scale", String(options.scale));
  }
  if (options.output) {
    cmd.push("--output", options.output);
  }

  await runAxe(cmd);
  return 0;
}

async function cmdRunFlow(
  options: DeviceOptions & {
    flow: string;
    outputDir?: string;
  }
): Promise<number> {
  const udid = await resolveUdid(options.udid, options.deviceName, options.osVersion);
  const outputDir = options.outputDir ?? DEFAULT_OUTPUT_DIR;

  const flowContent = fs.readFileSync(options.flow, "utf-8");
  const steps: FlowStep[] = JSON.parse(flowContent);

  if (!Array.isArray(steps)) {
    throw new Error("Flow file must be a JSON array of steps");
  }

  for (let i = 0; i < steps.length; i++) {
    const step = steps[i];
    const index = i + 1;

    if (typeof step !== "object" || step === null) {
      throw new Error(`Step ${index} is not an object`);
    }

    const { action } = step;
    if (!action) {
      throw new Error(`Step ${index} missing action`);
    }

    switch (action) {
      case "wait": {
        const seconds = parseFloat(step.seconds ?? 1.0);
        await new Promise((resolve) => setTimeout(resolve, seconds * 1000));
        break;
      }

      case "tap": {
        const cmd = ["axe", "tap", "--udid", udid];
        if (step.x !== undefined && step.y !== undefined) {
          cmd.push("-x", String(step.x), "-y", String(step.y));
        }
        if (step.id) cmd.push("--id", step.id);
        if (step.label) cmd.push("--label", step.label);
        if (step.pre_delay !== undefined)
          cmd.push("--pre-delay", String(step.pre_delay));
        if (step.post_delay !== undefined)
          cmd.push("--post-delay", String(step.post_delay));
        await runAxe(cmd);
        break;
      }

      case "type": {
        if (step.text === undefined) {
          throw new Error(`Step ${index} missing text`);
        }
        const cmd = ["axe", "type", step.text, "--udid", udid];
        await runAxe(cmd);
        break;
      }

      case "swipe": {
        const cmd = [
          "axe",
          "swipe",
          "--start-x",
          String(step.start_x),
          "--start-y",
          String(step.start_y),
          "--end-x",
          String(step.end_x),
          "--end-y",
          String(step.end_y),
          "--udid",
          udid,
        ];
        if (step.duration !== undefined)
          cmd.push("--duration", String(step.duration));
        if (step.delta !== undefined) cmd.push("--delta", String(step.delta));
        if (step.pre_delay !== undefined)
          cmd.push("--pre-delay", String(step.pre_delay));
        if (step.post_delay !== undefined)
          cmd.push("--post-delay", String(step.post_delay));
        await runAxe(cmd);
        break;
      }

      case "button": {
        const cmd = ["axe", "button", step.button, "--udid", udid];
        if (step.duration !== undefined)
          cmd.push("--duration", String(step.duration));
        await runAxe(cmd);
        break;
      }

      case "screenshot": {
        const outputPath =
          step.output ?? defaultScreenshotPath(outputDir, step.name);
        const cmd = ["axe", "screenshot", "--udid", udid, "--output", outputPath];
        await runAxe(cmd);
        break;
      }

      case "openurl": {
        await run(["xcrun", "simctl", "openurl", udid, step.url]);
        break;
      }

      case "describe-ui": {
        const cmd = ["axe", "describe-ui", "--udid", udid];
        await runAxe(cmd);
        break;
      }

      default:
        throw new Error(`Unsupported action '${action}' at step ${index}`);
    }
  }

  return 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// CLI
// ─────────────────────────────────────────────────────────────────────────────

function printUsage(defaults: { deviceName: string; osVersion: string; outputDir: string }): void {
  console.log(`
Usage: bun sim_control_runner.ts <command> [options]

Commands:
  list-simulators   List available simulators
  boot              Boot a simulator (waits for boot)
  shutdown          Shutdown a simulator
  install           Install an .app to the simulator
  launch            Launch an installed app
  install-launch    Install then launch without building
  terminate         Terminate a running app
  openurl           Open a URL on the simulator
  describe-ui       Dump accessibility tree
  tap               Tap by coordinates, id, or label
  type              Type text into the simulator
  swipe             Swipe gesture
  button            Press a hardware button
  screenshot        Capture a screenshot
  record-video      Record simulator video
  run-flow          Run a JSON flow of actions

Config Options:
  --config <path>   Path to .simcontrol config file (default: .simcontrol in cwd)

Device Options:
  --udid <udid>           Simulator UDID (overrides device selection)
  --device-name <name>    Preferred device name (default: ${defaults.deviceName})
  --os-version <version>  Preferred iOS version (default: ${defaults.osVersion})

Install Options:
  --app-path <path>       Path to the .app bundle
  --app-name <name>       App name (used to search DerivedData)
  --derived-data <path>   DerivedData root for app lookup (default: ./DerivedData)

Launch Options:
  --bundle-id <id>        Bundle identifier to launch
  --app-args [...]        Arguments passed to the app

Tap Options:
  -x <coord>              X coordinate
  -y <coord>              Y coordinate
  --id <id>               AXUniqueId / accessibilityIdentifier
  --label <label>         AXLabel / accessibilityLabel
  --pre-delay <seconds>   Delay before tap
  --post-delay <seconds>  Delay after tap

Type Options:
  --stdin                 Read text from stdin
  --file <path>           Read text from a file

Swipe Options:
  --start-x <coord>       Start X coordinate
  --start-y <coord>       Start Y coordinate
  --end-x <coord>         End X coordinate
  --end-y <coord>         End Y coordinate
  --duration <seconds>    Duration of swipe
  --delta <value>         Delta value

Button Options:
  <button_type>           One of: apple-pay, home, lock, side-button, siri
  --duration <seconds>    Button press duration

Screenshot Options:
  --output <path>         Output PNG path
  --output-dir <path>     Output directory (default: ${defaults.outputDir})
  --name <name>           Base name for default output

Record Video Options:
  --fps <number>          Frames per second
  --quality <number>      Video quality
  --scale <number>        Video scale
  --output <path>         Output MP4 path

Run Flow Options:
  --flow <path>           Path to JSON flow file (required)
  --output-dir <path>     Output directory for screenshots (default: ${defaults.outputDir})
`);
}

async function checkAxe(): Promise<boolean> {
  try {
    await execFn("which axe");
    return true;
  } catch {
    return false;
  }
}

export async function main(argv: string[] = process.argv.slice(2)): Promise<number> {
  const args = argv;

  const command = args[0] ?? "";
  const restArgs = args.slice(1);

  // Check for --help flag anywhere in arguments
  const hasHelpFlag = args.length === 0 || args[0] === "--help" || args[0] === "-h" || restArgs.includes("--help") || restArgs.includes("-h");

  // Parse arguments - helper functions defined first for config loading
  const getArg = (names: string[]): string | undefined => {
    for (const name of names) {
      const idx = restArgs.indexOf(name);
      if (idx !== -1 && idx + 1 < restArgs.length) {
        return restArgs[idx + 1];
      }
    }
    return undefined;
  };

  // Load config file early (before help check)
  const config = loadConfig(getArg(["--config"]) ?? undefined);
  const defaults = getEffectiveDefaults(config);

  if (hasHelpFlag) {
    printUsage(defaults);
    return 0;
  }

  // Check for axe
  if (!(await checkAxe())) {
    console.error("Error: axe not found. Install with Homebrew: brew install axe");
    return 2;
  }

  const hasFlag = (names: string[]): boolean => {
    return names.some((name) => restArgs.includes(name));
  };

  const getNumber = (names: string[]): number | undefined => {
    const val = getArg(names);
    return val !== undefined ? parseFloat(val) : undefined;
  };

  const getRemainingArgs = (afterFlag: string): string[] => {
    const idx = restArgs.indexOf(afterFlag);
    if (idx === -1) return [];
    return restArgs.slice(idx + 1);
  };

  const deviceOptions: DeviceOptions = {
    udid: getArg(["--udid"]),
    deviceName: getArg(["--device-name"]) ?? defaults.deviceName,
    osVersion: getArg(["--os-version"]) ?? defaults.osVersion,
  };

  try {
    switch (command) {
      case "list-simulators":
        return await cmdListSimulators();

      case "boot":
        return await cmdBoot({
          ...deviceOptions,
          noWait: hasFlag(["--no-wait"]),
        });

      case "shutdown":
        return await cmdShutdown(deviceOptions);

      case "install":
        return await cmdInstall({
          ...deviceOptions,
          appPath: getArg(["--app-path"]),
          appName: getArg(["--app-name"]),
          derivedData: getArg(["--derived-data"]) ?? defaults.derivedDataPath,
        });

      case "launch":
        return await cmdLaunch({
          ...deviceOptions,
          bundleId: getArg(["--bundle-id"]),
          appPath: getArg(["--app-path"]),
          appArgs: getRemainingArgs("--app-args"),
        });

      case "install-launch":
        return await cmdInstallLaunch({
          ...deviceOptions,
          appPath: getArg(["--app-path"]),
          appName: getArg(["--app-name"]),
          derivedData: getArg(["--derived-data"]) ?? defaults.derivedDataPath,
          bundleId: getArg(["--bundle-id"]),
          appArgs: getRemainingArgs("--app-args"),
        });

      case "terminate": {
        const bundleId = getArg(["--bundle-id"]);
        if (!bundleId) throw new Error("--bundle-id is required");
        return await cmdTerminate({ ...deviceOptions, bundleId });
      }

      case "openurl": {
        const url = getArg(["--url"]);
        if (!url) throw new Error("--url is required");
        return await cmdOpenUrl({ ...deviceOptions, url });
      }

      case "describe-ui":
        return await cmdDescribeUi({
          ...deviceOptions,
          output: getArg(["--output"]),
        });

      case "tap":
        return await cmdTap({
          ...deviceOptions,
          x: getNumber(["-x"]),
          y: getNumber(["-y"]),
          elementId: getArg(["--id"]),
          label: getArg(["--label"]),
          preDelay: getNumber(["--pre-delay"]),
          postDelay: getNumber(["--post-delay"]),
        });

      case "type": {
        // Get positional text argument (first non-flag arg)
        const text = restArgs.find((arg) => !arg.startsWith("-"));
        return await cmdType({
          ...deviceOptions,
          text,
          stdin: hasFlag(["--stdin"]),
          file: getArg(["--file"]),
        });
      }

      case "swipe": {
        const startX = getNumber(["--start-x"]);
        const startY = getNumber(["--start-y"]);
        const endX = getNumber(["--end-x"]);
        const endY = getNumber(["--end-y"]);
        if (
          startX === undefined ||
          startY === undefined ||
          endX === undefined ||
          endY === undefined
        ) {
          throw new Error(
            "--start-x, --start-y, --end-x, --end-y are all required"
          );
        }
        return await cmdSwipe({
          ...deviceOptions,
          startX,
          startY,
          endX,
          endY,
          duration: getNumber(["--duration"]),
          delta: getNumber(["--delta"]),
          preDelay: getNumber(["--pre-delay"]),
          postDelay: getNumber(["--post-delay"]),
        });
      }

      case "button": {
        const buttonType = restArgs.find(
          (arg) =>
            !arg.startsWith("-") &&
            ["apple-pay", "home", "lock", "side-button", "siri"].includes(arg)
        );
        if (!buttonType) {
          throw new Error(
            "Button type required: apple-pay, home, lock, side-button, siri"
          );
        }
        return await cmdButton({
          ...deviceOptions,
          buttonType,
          duration: getNumber(["--duration"]),
        });
      }

      case "screenshot":
        return await cmdScreenshot({
          ...deviceOptions,
          output: getArg(["--output"]),
          outputDir: getArg(["--output-dir"]) ?? defaults.outputDir,
          name: getArg(["--name"]),
        });

      case "record-video":
        return await cmdRecordVideo({
          ...deviceOptions,
          fps: getNumber(["--fps"]),
          quality: getNumber(["--quality"]),
          scale: getNumber(["--scale"]),
          output: getArg(["--output"]),
        });

      case "run-flow": {
        const flow = getArg(["--flow"]);
        if (!flow) throw new Error("--flow is required");
        return await cmdRunFlow({
          ...deviceOptions,
          flow,
          outputDir: getArg(["--output-dir"]) ?? defaults.outputDir,
        });
      }

      default:
        console.error(`Unknown command: ${command}`);
        printUsage(defaults);
        return 1;
    }
  } catch (error: any) {
    console.error(`Error: ${error.message}`);
    return 2;
  }
}

if (import.meta.main) {
  main().then((code) => process.exit(code));
}
