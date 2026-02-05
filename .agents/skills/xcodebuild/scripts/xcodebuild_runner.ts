#!/usr/bin/env bun
/**
 * CLI helper for xcodebuild workflows used by the xcodebuild skill.
 *
 * Run with: bun skill/xcodebuild/scripts/xcodebuild_runner.ts <command> [options]
 */

import { exec, spawn } from "child_process";
import { promisify } from "util";
import * as fs from "fs";
import * as path from "path";
import { parseArgs } from "util";

const execAsync = promisify(exec);

type ExecOptions = { cwd?: string; env?: NodeJS.ProcessEnv; maxBuffer?: number };
type ExecResult = { stdout: string; stderr: string };
type ExecFn = (cmd: string, options?: ExecOptions) => Promise<ExecResult>;
type SpawnFn = typeof spawn;

const defaultExec: ExecFn = (cmd, options) => execAsync(cmd, options);
let execFn: ExecFn = defaultExec;
let spawnFn: SpawnFn = spawn;

export function setDeps(next: Partial<{ exec: ExecFn; spawn: SpawnFn }>): void {
  if (next.exec) {
    execFn = next.exec;
  }
  if (next.spawn) {
    spawnFn = next.spawn;
  }
}

export function resetDeps(): void {
  execFn = defaultExec;
  spawnFn = spawn;
}

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

interface XcodeContainer {
  flag: "-workspace" | "-project";
  path: string;
}

interface BuildPaths {
  buildRoot: string;
  derivedData: string;
  sourcePackages: string;
  resultBundle: string;
}

interface CommandResult {
  exitCode: number;
  output: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Utility Functions
// ─────────────────────────────────────────────────────────────────────────────

function formatCommand(cmd: string[]): string {
  return cmd.map((part) => (part.includes(" ") ? `'${part}'` : part)).join(" ");
}

function tailLines(text: string, maxLines = 200): string {
  const lines = text.split("\n");
  if (lines.length <= maxLines) return text;
  return lines.slice(-maxLines).join("\n");
}

function extractWarningsErrors(text: string): string {
  return text
    .split("\n")
    .filter((line) => {
      const lower = line.toLowerCase();
      return lower.includes("error:") || lower.includes("warning:");
    })
    .join("\n");
}

function defaultBuildPaths(folder: string): BuildPaths {
  const buildRoot = path.join(path.resolve(folder), "build", "xcodebuild");
  return {
    buildRoot,
    derivedData: path.join(buildRoot, "DerivedData"),
    sourcePackages: path.join(buildRoot, "SourcePackages"),
    resultBundle: path.join(buildRoot, "TestResults.xcresult"),
  };
}

function isUnder(testPath: string, root: string): boolean {
  const absPath = path.resolve(testPath);
  const absRoot = path.resolve(root);
  return absPath.startsWith(absRoot);
}

function ensureBuildRoot(paths: (string | undefined)[], buildRoot: string): void {
  if (paths.some((p) => p && isUnder(p, buildRoot))) {
    fs.mkdirSync(buildRoot, { recursive: true });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Xcode Version Discovery
// ─────────────────────────────────────────────────────────────────────────────

async function listXcodeVersions(): Promise<string[]> {
  try {
    const files = await fs.promises.readdir("/Applications");
    const xcodeApps = files.filter((file) => file.startsWith("Xcode") && file.endsWith(".app"));

    return xcodeApps
      .map((app) => {
        if (app === "Xcode.app") return "default";
        const match = app.match(/^Xcode-(.+)\.app$/);
        return match ? match[1] : app;
      })
      .sort((a, b) => {
        if (a === "default") return -1;
        if (b === "default") return 1;
        return a.localeCompare(b);
      });
  } catch {
    return [];
  }
}

function getDeveloperDir(version?: string): string | undefined {
  if (!version || version === "default") {
    return undefined;
  }

  const path = `/Applications/Xcode-${version}.app/Contents/Developer`;
  if (fs.existsSync(path)) {
    return path;
  }

  return undefined;
}

async function cmdListVersions(): Promise<number> {
  const versions = await listXcodeVersions();

  if (versions.length === 0) {
    console.log("No Xcode installations found in /Applications");
    return 0;
  }

  console.log("Available Xcode versions:\n");

  for (const version of versions) {
    const devDir =
      version === "default"
        ? "/Applications/Xcode.app/Contents/Developer"
        : `/Applications/Xcode-${version}.app/Contents/Developer`;

    const xcodebuildPath = `"${devDir}/usr/bin/xcodebuild"`;

    try {
      const { stdout } = await execFn(`${xcodebuildPath} -version`);
      const versionOutput = stdout.trim().replace(/\n/g, " ");
      console.log(`  ${version}: ${versionOutput}`);
    } catch {
      console.log(`  ${version}: (version info unavailable)`);
    }
  }

  return 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Xcode Container Discovery
// ─────────────────────────────────────────────────────────────────────────────

const DEPENDENCY_DIRS = new Set([
  "SourcePackages",
  "build",
  "DerivedData",
  "Pods",
  ".build",
  "Carthage",
  "Packages",
]);

export function findXcodeContainer(
  root: string,
  preferWorkspace = true
): XcodeContainer | null {
  const workspaces: string[] = [];
  const projects: string[] = [];

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

      if (DEPENDENCY_DIRS.has(entry.name)) continue;

      if (entry.name.endsWith(".xcworkspace")) {
        workspaces.push(fullPath);
      } else if (entry.name.endsWith(".xcodeproj")) {
        projects.push(fullPath);
      } else if (!entry.name.startsWith(".")) {
        walkDir(fullPath);
      }
    }
  }

  walkDir(root);

  const pick = (paths: string[]): string | null => {
    if (!paths.length) return null;
    paths.sort((a, b) => {
      const depthA = a.split(path.sep).length;
      const depthB = b.split(path.sep).length;
      return depthA - depthB || a.localeCompare(b);
    });
    return paths[0];
  };

  if (preferWorkspace) {
    const ws = pick(workspaces);
    if (ws) return { flag: "-workspace", path: ws };
    const proj = pick(projects);
    if (proj) return { flag: "-project", path: proj };
    return null;
  }

  const proj = pick(projects);
  if (proj) return { flag: "-project", path: proj };
  const ws = pick(workspaces);
  if (ws) return { flag: "-workspace", path: ws };
  return null;
}

async function resolveContainer(
  folder: string,
  workspace?: string,
  project?: string,
  preferWorkspace = true
): Promise<XcodeContainer> {
  if (workspace && project) {
    throw new Error("Provide only one of --workspace or --project.");
  }
  if (workspace) return { flag: "-workspace", path: workspace };
  if (project) return { flag: "-project", path: project };

  const found = findXcodeContainer(folder, preferWorkspace);
  if (!found) {
    throw new Error("No .xcworkspace or .xcodeproj found.");
  }
  return found;
}

// ─────────────────────────────────────────────────────────────────────────────
// Scheme Discovery
// ─────────────────────────────────────────────────────────────────────────────

async function listSchemes(
  container: XcodeContainer,
  cwd: string,
  env: NodeJS.ProcessEnv
): Promise<string[]> {
  const cmd = `xcodebuild -list -json ${container.flag} '${container.path}'`;
  try {
    const { stdout } = await execFn(cmd, { cwd, env, maxBuffer: 10 * 1024 * 1024 });
    const data = JSON.parse(stdout);
    if (container.flag === "-workspace") {
      return data.workspace?.schemes ?? [];
    }
    return data.project?.schemes ?? [];
  } catch (error: any) {
    throw new Error(error.stderr?.trim() || "Failed to list schemes.");
  }
}

function pickScheme(
  explicit: string | undefined,
  schemes: string[],
  container: XcodeContainer
): string {
  if (explicit) return explicit;
  if (!schemes.length) {
    throw new Error("No schemes found.");
  }
  const base = path.basename(container.path, path.extname(container.path));
  const match = schemes.find((s) => s === base);
  return match ?? schemes[0];
}

// ─────────────────────────────────────────────────────────────────────────────
// Simulator Discovery
// ─────────────────────────────────────────────────────────────────────────────

function parseRuntimeVersion(runtimeId: string): string | null {
  if (!runtimeId.includes("iOS")) return null;
  const token = runtimeId.split("iOS-").pop()?.replace(/-/g, ".") ?? "";
  if (token === runtimeId) return null;
  return token;
}

function runtimeSortKey(runtimeId: string): number[] {
  const version = parseRuntimeVersion(runtimeId);
  if (!version) return [0, 0, 0];
  const parts = version.split(".").map((p) => parseInt(p, 10) || 0);
  while (parts.length < 3) parts.push(0);
  return parts;
}

async function findAvailableSimulator(): Promise<string | null> {
  try {
    const { stdout } = await execFn("xcrun simctl list devices --json", {
      maxBuffer: 10 * 1024 * 1024,
    });
    const payload = JSON.parse(stdout);
    const devices = payload.devices ?? {};

    const runtimeIds = Object.keys(devices).sort((a, b) => {
      const keyA = runtimeSortKey(a);
      const keyB = runtimeSortKey(b);
      for (let i = 0; i < 3; i++) {
        if (keyB[i] !== keyA[i]) return keyB[i] - keyA[i];
      }
      return 0;
    });

    for (const runtimeId of runtimeIds) {
      if (!runtimeId.includes("iOS")) continue;
      const available = (devices[runtimeId] ?? []).filter(
        (d: any) => d.isAvailable
      );
      if (!available.length) continue;

      const iphone = available.find((d: any) =>
        d.name?.toLowerCase().includes("iphone")
      );
      const picked = iphone ?? available[0];
      const runtimeVersion = parseRuntimeVersion(runtimeId);
      if (!runtimeVersion) continue;

      return `platform=iOS Simulator,name=${picked.name},OS=${runtimeVersion}`;
    }
    return null;
  } catch {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Command Execution
// ─────────────────────────────────────────────────────────────────────────────

function buildEnv(developerDir?: string): NodeJS.ProcessEnv {
  const env = { ...process.env };
  if (developerDir) {
    env.DEVELOPER_DIR = developerDir;
  }
  return env;
}

async function hasXcbeautify(): Promise<boolean> {
  try {
    await execFn("which xcbeautify");
    return true;
  } catch {
    return false;
  }
}

async function runCommand(
  cmd: string[],
  cwd: string,
  env: NodeJS.ProcessEnv,
  pretty: boolean
): Promise<CommandResult> {
  const hasBeautify = await hasXcbeautify();

  if (pretty && hasBeautify) {
    return new Promise((resolve) => {
      const proc = spawnFn(cmd[0], cmd.slice(1), {
        cwd,
        env,
        stdio: ["inherit", "pipe", "pipe"],
      });

      const beautify = spawnFn("xcbeautify", [], {
        stdio: ["pipe", "pipe", "pipe"],
      });

      proc.stdout?.pipe(beautify.stdin);
      proc.stderr?.pipe(beautify.stdin);

      let output = "";
      beautify.stdout?.on("data", (data) => {
        output += data.toString();
      });
      beautify.stderr?.on("data", (data) => {
        output += data.toString();
      });

      proc.on("close", (code) => {
        beautify.stdin?.end();
      });

      beautify.on("close", () => {
        proc.on("close", (code) => {
          resolve({ exitCode: code ?? 0, output });
        });
      });

      // Handle case where beautify closes before we get proc exit
      let exitCode = 0;
      proc.on("close", (code) => {
        exitCode = code ?? 0;
      });
      beautify.on("close", () => {
        resolve({ exitCode, output });
      });
    });
  }

  // Non-pretty execution
  const cmdStr = formatCommand(cmd);
  try {
    const { stdout, stderr } = await execFn(cmdStr, {
      cwd,
      env,
      maxBuffer: 50 * 1024 * 1024,
    });
    return { exitCode: 0, output: stdout + stderr };
  } catch (error: any) {
    return {
      exitCode: error.code ?? 1,
      output: (error.stdout ?? "") + (error.stderr ?? ""),
    };
  }
}

function appendCommonFlags(
  cmd: string[],
  options: {
    destination?: string;
    derivedDataPath?: string;
    clonedSourcePackagesDirPath?: string;
    skipPackagePluginValidation?: boolean;
  }
): void {
  if (options.destination) {
    cmd.push("-destination", options.destination);
  }
  if (options.derivedDataPath) {
    cmd.push("-derivedDataPath", options.derivedDataPath);
  }
  if (options.clonedSourcePackagesDirPath) {
    cmd.push("-clonedSourcePackagesDirPath", options.clonedSourcePackagesDirPath);
  }
  if (options.skipPackagePluginValidation) {
    cmd.push("-skipPackagePluginValidation");
  }
}

function printCommandResult(cmd: string[], exitCode: number, output: string): void {
  const summary = exitCode === 0 ? "Success" : `Exit code ${exitCode}`;
  console.log(`Command: ${formatCommand(cmd)}`);
  console.log(summary);

  const errors = extractWarningsErrors(output);
  if (errors) {
    console.log("Warnings/Errors:");
    console.log(errors);
  }

  if (exitCode !== 0) {
    console.log(tailLines(output));
  } else {
    console.log(output);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Commands
// ─────────────────────────────────────────────────────────────────────────────

interface CommonOptions {
  folder: string;
  workspace?: string;
  project?: string;
  preferWorkspace: boolean;
  developerDir?: string;
}

interface BuildOptions extends CommonOptions {
  scheme?: string;
  configuration: string;
  destination?: string;
  derivedDataPath?: string;
  clonedSourcePackagesDirPath?: string;
  skipPackagePluginValidation: boolean;
  pretty: boolean;
}

interface TestOptions extends BuildOptions {
  testPlan?: string;
  onlyTesting: string[];
  skipTesting: string[];
  enableCodeCoverage: boolean;
  resultBundlePath?: string;
}

interface CoverageOptions extends TestOptions {
  reportOnlyTargets: string[];
  reportFiles: string[];
}

interface CoverageReportOptions {
  folder: string;
  xcresultPath?: string;
  threshold: number;
  showAllFiles: boolean;
  format: "text" | "markdown";
}

interface CoverageData {
  overall: number;
  files: {
    path: string;
    coverage: number;
    lines: { total: number; covered: number };
  }[];
}

async function cmdListSchemes(options: CommonOptions): Promise<number> {
  const env = buildEnv(options.developerDir);
  const container = await resolveContainer(
    options.folder,
    options.workspace,
    options.project,
    options.preferWorkspace
  );
  const schemes = await listSchemes(container, options.folder, env);
  console.log(JSON.stringify({ schemes }, null, 2));
  return 0;
}

async function cmdBuild(options: BuildOptions): Promise<number> {
  const env = buildEnv(options.developerDir);
  const defaults = defaultBuildPaths(options.folder);
  const container = await resolveContainer(
    options.folder,
    options.workspace,
    options.project,
    options.preferWorkspace
  );
  const schemes = await listSchemes(container, options.folder, env);
  const scheme = pickScheme(options.scheme, schemes, container);

  const destination = options.destination ?? (await findAvailableSimulator());
  if (!destination) {
    throw new Error("No available iOS Simulator destination found.");
  }

  const derivedDataPath = options.derivedDataPath ?? defaults.derivedData;
  const sourcePackagesPath =
    options.clonedSourcePackagesDirPath ?? defaults.sourcePackages;

  ensureBuildRoot([derivedDataPath, sourcePackagesPath], defaults.buildRoot);

  const cmd = [
    "xcodebuild",
    "build",
    container.flag,
    container.path,
    "-scheme",
    scheme,
    "-configuration",
    options.configuration,
  ];

  appendCommonFlags(cmd, {
    destination,
    derivedDataPath,
    clonedSourcePackagesDirPath: sourcePackagesPath,
    skipPackagePluginValidation: options.skipPackagePluginValidation,
  });

  const { exitCode, output } = await runCommand(
    cmd,
    options.folder,
    env,
    options.pretty
  );
  printCommandResult(cmd, exitCode, output);
  return exitCode;
}

async function cmdTest(options: TestOptions): Promise<number> {
  const env = buildEnv(options.developerDir);
  const defaults = defaultBuildPaths(options.folder);
  const container = await resolveContainer(
    options.folder,
    options.workspace,
    options.project,
    options.preferWorkspace
  );
  const schemes = await listSchemes(container, options.folder, env);
  const scheme = pickScheme(options.scheme, schemes, container);

  const destination = options.destination ?? (await findAvailableSimulator());
  if (!destination) {
    throw new Error("No available iOS Simulator destination found.");
  }

  const derivedDataPath = options.derivedDataPath ?? defaults.derivedData;
  const sourcePackagesPath =
    options.clonedSourcePackagesDirPath ?? defaults.sourcePackages;
  let resultBundle = options.resultBundlePath;
  if (options.enableCodeCoverage && !resultBundle) {
    resultBundle = defaults.resultBundle;
  }

  ensureBuildRoot(
    [derivedDataPath, sourcePackagesPath, resultBundle],
    defaults.buildRoot
  );

  const cmd = [
    "xcodebuild",
    "test",
    container.flag,
    container.path,
    "-scheme",
    scheme,
  ];

  appendCommonFlags(cmd, {
    destination,
    derivedDataPath,
    clonedSourcePackagesDirPath: sourcePackagesPath,
    skipPackagePluginValidation: options.skipPackagePluginValidation,
  });

  if (options.testPlan) {
    cmd.push("-testPlan", options.testPlan);
  }
  for (const selector of options.onlyTesting) {
    cmd.push("-only-testing", selector);
  }
  for (const selector of options.skipTesting) {
    cmd.push("-skip-testing", selector);
  }
  if (options.enableCodeCoverage) {
    cmd.push("-enableCodeCoverage", "YES");
  }
  if (resultBundle) {
    cmd.push("-resultBundlePath", resultBundle);
  }

  const { exitCode, output } = await runCommand(
    cmd,
    options.folder,
    env,
    options.pretty
  );
  printCommandResult(cmd, exitCode, output);
  return exitCode;
}

async function cmdClean(
  options: CommonOptions & { scheme?: string; skipPackagePluginValidation: boolean }
): Promise<number> {
  const env = buildEnv(options.developerDir);
  const container = await resolveContainer(
    options.folder,
    options.workspace,
    options.project,
    options.preferWorkspace
  );
  const schemes = await listSchemes(container, options.folder, env);
  const scheme = pickScheme(options.scheme, schemes, container);

  const cmd = [
    "xcodebuild",
    "clean",
    container.flag,
    container.path,
    "-scheme",
    scheme,
  ];
  if (options.skipPackagePluginValidation) {
    cmd.push("-skipPackagePluginValidation");
  }

  const { exitCode, output } = await runCommand(cmd, options.folder, env, false);
  printCommandResult(cmd, exitCode, output);
  return exitCode;
}

async function cmdCoverage(options: CoverageOptions): Promise<number> {
  const env = buildEnv(options.developerDir);
  const defaults = defaultBuildPaths(options.folder);
  const container = await resolveContainer(
    options.folder,
    options.workspace,
    options.project,
    options.preferWorkspace
  );
  const schemes = await listSchemes(container, options.folder, env);
  const scheme = pickScheme(options.scheme, schemes, container);

  const destination = options.destination ?? (await findAvailableSimulator());
  if (!destination) {
    throw new Error("No available iOS Simulator destination found.");
  }

  const derivedDataPath = options.derivedDataPath ?? defaults.derivedData;
  const sourcePackagesPath =
    options.clonedSourcePackagesDirPath ?? defaults.sourcePackages;
  const resultBundle = options.resultBundlePath ?? defaults.resultBundle;

  ensureBuildRoot(
    [derivedDataPath, sourcePackagesPath, resultBundle],
    defaults.buildRoot
  );

  const cmd = [
    "xcodebuild",
    "test",
    container.flag,
    container.path,
    "-scheme",
    scheme,
  ];

  appendCommonFlags(cmd, {
    destination,
    derivedDataPath,
    clonedSourcePackagesDirPath: sourcePackagesPath,
    skipPackagePluginValidation: options.skipPackagePluginValidation,
  });

  cmd.push("-enableCodeCoverage", "YES", "-resultBundlePath", resultBundle);

  if (options.testPlan) {
    cmd.push("-testPlan", options.testPlan);
  }
  for (const selector of options.onlyTesting) {
    cmd.push("-only-testing", selector);
  }
  for (const selector of options.skipTesting) {
    cmd.push("-skip-testing", selector);
  }

  const { exitCode, output } = await runCommand(
    cmd,
    options.folder,
    env,
    options.pretty
  );
  printCommandResult(cmd, exitCode, output);

  if (exitCode !== 0) {
    return exitCode;
  }

  // Run coverage report
  let reportCmd = ["xcrun", "xccov", "view", "--report", resultBundle];
  if (options.reportOnlyTargets.length) {
    reportCmd.push("--only-targets", options.reportOnlyTargets.join(","));
  }
  if (options.reportFiles.length) {
    reportCmd.push("--files", options.reportFiles.join(","));
  }

  let reportResult = await runCommand(reportCmd, options.folder, env, false);

  // Retry without filters if it failed
  if (
    reportResult.exitCode !== 0 &&
    (options.reportOnlyTargets.length || options.reportFiles.length)
  ) {
    reportCmd = ["xcrun", "xccov", "view", "--report", resultBundle];
    reportResult = await runCommand(reportCmd, options.folder, env, false);
  }

  console.log(`Coverage report (${resultBundle}):`);
  console.log(reportResult.output);
  return reportResult.exitCode;
}

// ─────────────────────────────────────────────────────────────────────────────
// Coverage Report (report-only, from existing xcresult)
// ─────────────────────────────────────────────────────────────────────────────

async function findLatestXCResult(basePath: string): Promise<string | null> {
  const searchPaths = [
    path.join(basePath, "build", "xcodebuild"),
    path.join(basePath, "build", "Logs", "Test"),
    path.join(basePath, "DerivedData", "Logs", "Test"),
    path.join(basePath, "xcresults"),
  ];

  let latestResult: { path: string; mtime: number } | null = null;

  for (const searchPath of searchPaths) {
    try {
      const files = fs.readdirSync(searchPath);
      for (const file of files) {
        if (file.endsWith(".xcresult")) {
          const fullPath = path.join(searchPath, file);
          const stats = fs.statSync(fullPath);
          if (!latestResult || stats.mtimeMs > latestResult.mtime) {
            latestResult = { path: fullPath, mtime: stats.mtimeMs };
          }
        }
      }
    } catch {
      // Skip if directory doesn't exist
    }
  }

  return latestResult?.path ?? null;
}

async function parseCoverageData(xcresultPath: string): Promise<CoverageData> {
  const command = `xcrun xccov view --report --json "${xcresultPath}"`;

  const { stdout } = await execFn(command, {
    cwd: process.cwd(),
    maxBuffer: 50 * 1024 * 1024,
  });

  const json = JSON.parse(stdout);

  const files: CoverageData["files"] = [];
  let totalLines = 0;
  let totalCovered = 0;

  for (const target of json.targets ?? []) {
    for (const file of target.files ?? []) {
      const lineCoverage = file.lineCoverage ?? 0;
      const executableLines = file.executableLines ?? 0;
      const coveredLines = Math.round(executableLines * lineCoverage);

      if (executableLines > 0) {
        files.push({
          path: file.path,
          coverage: lineCoverage * 100,
          lines: {
            total: executableLines,
            covered: coveredLines,
          },
        });

        totalLines += executableLines;
        totalCovered += coveredLines;
      }
    }
  }

  const overall = totalLines > 0 ? (totalCovered / totalLines) * 100 : 0;

  return {
    overall,
    files: files.sort((a, b) => a.coverage - b.coverage),
  };
}

async function cmdCoverageReport(options: CoverageReportOptions): Promise<number> {
  let xcresultPath = options.xcresultPath;

  if (!xcresultPath) {
    xcresultPath = await findLatestXCResult(options.folder);
    if (!xcresultPath) {
      console.error("No .xcresult bundle found. Run tests first to generate coverage data.");
      return 1;
    }
  }

  if (!fs.existsSync(xcresultPath)) {
    console.error(`xcresult bundle not found at: ${xcresultPath}`);
    return 1;
  }

  try {
    const data = await parseCoverageData(xcresultPath);
    const passed = data.overall >= options.threshold;
    const filesUnderThreshold = data.files.filter((f) => f.coverage < options.threshold);

    if (options.format === "markdown") {
      // Markdown format for PR descriptions
      let report = `## Test Coverage Report\n\n`;

      const statusIcon = passed ? "PASSED" : "FAILED";
      report += `**Overall Coverage: ${data.overall.toFixed(1)}%** (threshold: ${options.threshold}%)\n`;
      report += `Status: ${statusIcon}\n\n`;

      if (!passed) {
        report += `Coverage is below the ${options.threshold}% threshold.\n\n`;
      }

      if (filesUnderThreshold.length > 0) {
        report += `### Files Under ${options.threshold}% Coverage\n\n`;
        report += `| File | Coverage | Lines |\n`;
        report += `|------|----------|-------|\n`;

        for (const file of filesUnderThreshold.slice(0, 20)) {
          const fileName = path.basename(file.path);
          const coverage = file.coverage.toFixed(1);
          report += `| ${fileName} | ${coverage}% | ${file.lines.covered}/${file.lines.total} |\n`;
        }

        if (filesUnderThreshold.length > 20) {
          report += `\n*...and ${filesUnderThreshold.length - 20} more files under threshold*\n`;
        }
        report += `\n`;
      } else {
        report += `All files meet the ${options.threshold}% coverage threshold.\n\n`;
      }

      if (options.showAllFiles && data.files.length > 0) {
        report += `### All Files\n\n`;
        report += `| File | Coverage | Lines |\n`;
        report += `|------|----------|-------|\n`;

        for (const file of data.files) {
          const fileName = path.basename(file.path);
          const coverage = file.coverage.toFixed(1);
          report += `| ${fileName} | ${coverage}% | ${file.lines.covered}/${file.lines.total} |\n`;
        }
        report += `\n`;
      }

      report += `---\n`;
      report += `*Coverage from: ${path.basename(xcresultPath)}*\n`;

      console.log(report);
    } else {
      // Text format
      console.log(`${"=".repeat(60)}`);
      console.log(`COVERAGE REPORT`);
      console.log(`${"=".repeat(60)}\n`);
      console.log(`Overall Coverage: ${data.overall.toFixed(1)}%`);
      console.log(`Threshold: ${options.threshold}%`);
      console.log(`Status: ${passed ? "PASSED" : "FAILED"}`);
      console.log(`Total Files: ${data.files.length}`);
      console.log(`Files Under Threshold: ${filesUnderThreshold.length}\n`);

      if (data.files.length > 0) {
        console.log(`Files with Lowest Coverage:`);
        console.log(`${"=".repeat(60)}`);
        const lowestFiles = data.files.slice(0, Math.min(10, data.files.length));
        for (const file of lowestFiles) {
          const fileName = path.basename(file.path);
          const coverage = file.coverage.toFixed(1).padStart(5);
          const bar =
            "\u2588".repeat(Math.floor(file.coverage / 5)) +
            "\u2591".repeat(20 - Math.floor(file.coverage / 5));
          console.log(`${coverage}% ${bar} ${fileName}`);
        }
      }

      console.log(`\n${"=".repeat(60)}`);
      console.log(`\nUsing: ${xcresultPath}`);
    }

    return passed ? 0 : 1;
  } catch (error: any) {
    console.error(`Failed to parse coverage: ${error.message}`);
    return 2;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLI Argument Parsing
// ─────────────────────────────────────────────────────────────────────────────

function printUsage(): void {
  console.log(`
Usage: bun xcodebuild_runner.ts <command> [options]

Commands:
  list-versions          List available Xcode versions in /Applications
  list-schemes           List schemes for workspace/project
  build                  Build the workspace/project
  test                   Run tests for the workspace/project
  clean                  Clean build artifacts
  coverage               Run tests with coverage and report with xccov
  coverage-report        Generate coverage report from existing xcresult bundle

Common Options:
  --folder <path>             Root folder (default: .)
  --workspace <path>          Path to .xcworkspace
  --project <path>            Path to .xcodeproj
  --prefer-workspace          Prefer .xcworkspace when auto-discovering (default)
  --no-prefer-workspace       Prefer .xcodeproj when auto-discovering
  --developer-dir <path>      DEVELOPER_DIR for specific Xcode install (e.g., /Applications/Xcode-16.4.app/Contents/Developer)

Build/Test Options:
  --scheme <name>             Xcode scheme
  --configuration <config>    Build configuration (default: Debug)
  --destination <dest>        xcodebuild destination string
  --derived-data-path <path>  DerivedData path override
  --cloned-source-packages-dir-path <path>  SwiftPM cache override
  --skip-package-plugin-validation          Pass -skipPackagePluginValidation (default)
  --no-skip-package-plugin-validation       Disable -skipPackagePluginValidation
  --pretty                    Pipe through xcbeautify (default)
  --no-pretty                 Disable xcbeautify output

Test Options:
  --test-plan <name>          Xcode test plan name
  --only-testing <selector>   Only-testing selector (repeatable)
  --skip-testing <selector>   Skip-testing selector (repeatable)
  --enable-code-coverage      Enable code coverage
  --result-bundle-path <path> Explicit .xcresult bundle path

Coverage Options:
  --report-only-targets <targets>  xccov --only-targets values (repeatable)
  --report-files <files>           xccov --files values (repeatable)

Coverage Report Options:
  --xcresult-path <path>      Path to .xcresult bundle (auto-finds if not specified)
  --threshold <percent>       Minimum coverage threshold (default: 80)
  --show-all-files            Show all files in report
  --format <text|markdown>    Output format (default: text)
`);
}

export async function main(argv: string[] = process.argv.slice(2)): Promise<number> {
  const args = argv;

  if (args.length === 0 || args[0] === "--help" || args[0] === "-h") {
    printUsage();
    return 0;
  }

  const command = args[0];
  const restArgs = args.slice(1);

  // Parse common options manually for flexibility
  const getArg = (names: string[]): string | undefined => {
    for (const name of names) {
      const idx = restArgs.indexOf(name);
      if (idx !== -1 && idx + 1 < restArgs.length) {
        return restArgs[idx + 1];
      }
    }
    return undefined;
  };

  const hasFlag = (names: string[]): boolean => {
    return names.some((name) => restArgs.includes(name));
  };

  const getMultiple = (names: string[]): string[] => {
    const result: string[] = [];
    for (const name of names) {
      let idx = 0;
      while ((idx = restArgs.indexOf(name, idx)) !== -1) {
        if (idx + 1 < restArgs.length) {
          result.push(restArgs[idx + 1]);
        }
        idx++;
      }
    }
    return result;
  };

  const commonOptions: CommonOptions = {
    folder: getArg(["--folder"]) ?? ".",
    workspace: getArg(["--workspace"]),
    project: getArg(["--project"]),
    preferWorkspace: !hasFlag(["--no-prefer-workspace"]),
    developerDir: getArg(["--developer-dir"]),
  };

  try {
    // Check for xcbeautify
    const hasPretty = await hasXcbeautify();
    if (!hasPretty && !hasFlag(["--no-pretty"])) {
      console.error(
        "Warning: xcbeautify not found. Install with Homebrew: brew install xcbeautify"
      );
      console.error("Continuing without formatted output...");
    }

    switch (command) {
      case "list-versions":
        return await cmdListVersions();

      case "list-schemes":
        return await cmdListSchemes(commonOptions);

      case "build": {
        const buildOptions: BuildOptions = {
          ...commonOptions,
          scheme: getArg(["--scheme"]),
          configuration: getArg(["--configuration"]) ?? "Debug",
          destination: getArg(["--destination"]),
          derivedDataPath: getArg(["--derived-data-path"]),
          clonedSourcePackagesDirPath: getArg([
            "--cloned-source-packages-dir-path",
          ]),
          skipPackagePluginValidation: !hasFlag([
            "--no-skip-package-plugin-validation",
          ]),
          pretty: !hasFlag(["--no-pretty"]),
        };
        return await cmdBuild(buildOptions);
      }

      case "test": {
        const testOptions: TestOptions = {
          ...commonOptions,
          scheme: getArg(["--scheme"]),
          configuration: getArg(["--configuration"]) ?? "Debug",
          destination: getArg(["--destination"]),
          derivedDataPath: getArg(["--derived-data-path"]),
          clonedSourcePackagesDirPath: getArg([
            "--cloned-source-packages-dir-path",
          ]),
          skipPackagePluginValidation: !hasFlag([
            "--no-skip-package-plugin-validation",
          ]),
          pretty: !hasFlag(["--no-pretty"]),
          testPlan: getArg(["--test-plan"]),
          onlyTesting: getMultiple(["--only-testing"]),
          skipTesting: getMultiple(["--skip-testing"]),
          enableCodeCoverage: hasFlag(["--enable-code-coverage"]),
          resultBundlePath: getArg(["--result-bundle-path"]),
        };
        return await cmdTest(testOptions);
      }

      case "clean": {
        const cleanOptions = {
          ...commonOptions,
          scheme: getArg(["--scheme"]),
          skipPackagePluginValidation: !hasFlag([
            "--no-skip-package-plugin-validation",
          ]),
        };
        return await cmdClean(cleanOptions);
      }

      case "coverage": {
        const coverageOptions: CoverageOptions = {
          ...commonOptions,
          scheme: getArg(["--scheme"]),
          configuration: getArg(["--configuration"]) ?? "Debug",
          destination: getArg(["--destination"]),
          derivedDataPath: getArg(["--derived-data-path"]),
          clonedSourcePackagesDirPath: getArg([
            "--cloned-source-packages-dir-path",
          ]),
          skipPackagePluginValidation: !hasFlag([
            "--no-skip-package-plugin-validation",
          ]),
          pretty: !hasFlag(["--no-pretty"]),
          testPlan: getArg(["--test-plan"]),
          onlyTesting: getMultiple(["--only-testing"]),
          skipTesting: getMultiple(["--skip-testing"]),
          enableCodeCoverage: true,
          resultBundlePath: getArg(["--result-bundle-path"]),
          reportOnlyTargets: getMultiple(["--report-only-targets"]),
          reportFiles: getMultiple(["--report-files"]),
        };
        return await cmdCoverage(coverageOptions);
      }

      case "coverage-report": {
        const format = getArg(["--format"]);
        const reportOptions: CoverageReportOptions = {
          folder: commonOptions.folder,
          xcresultPath: getArg(["--xcresult-path"]),
          threshold: parseFloat(getArg(["--threshold"]) ?? "80"),
          showAllFiles: hasFlag(["--show-all-files"]),
          format: format === "markdown" ? "markdown" : "text",
        };
        return await cmdCoverageReport(reportOptions);
      }

      default:
        console.error(`Unknown command: ${command}`);
        printUsage();
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
