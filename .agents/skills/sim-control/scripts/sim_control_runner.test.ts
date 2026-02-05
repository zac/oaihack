import { expect, test, describe, spyOn, beforeEach, afterEach } from "bun:test";
import { main, loadConfig, resetDeps, setDeps } from "./sim_control_runner";
import * as fs from "fs";
import * as path from "path";

describe("sim_control_runner", () => {
  let tempDir: string;
  let originalCwd: string;
  let execCalls: string[];
  let execResponder: (cmd: string) => Promise<{ stdout: string; stderr: string }>;

  const axeListOutput = [
    "SIM-1 | iPhone 15 | Booted | 1320x2868 | OS 'iOS 18.0'",
    "SIM-2 | iPhone 14 | Shutdown | 1170x2532 | OS 'iOS 17.2'",
  ].join("\n");

  const simctlPayload = JSON.stringify({
    devices: {
      "com.apple.CoreSimulator.SimRuntime.iOS-18-0": [
        { isAvailable: true, udid: "SIM-3", name: "iPhone 15", state: "Shutdown" },
      ],
    },
  });

  const mockExec = async (cmd: string): Promise<{ stdout: string; stderr: string }> => {
    execCalls.push(cmd);
    return execResponder(cmd);
  };

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join("/tmp", "sim-control-test-"));
    originalCwd = process.cwd();
    process.chdir(tempDir);
    execCalls = [];
    execResponder = async (cmd: string) => {
      if (cmd.startsWith("which axe")) {
        return { stdout: "/usr/local/bin/axe\n", stderr: "" };
      }
      if (cmd.startsWith("axe list-simulators")) {
        return { stdout: axeListOutput, stderr: "" };
      }
      if (cmd.startsWith("xcrun simctl list devices --json")) {
        return { stdout: simctlPayload, stderr: "" };
      }
      return { stdout: "", stderr: "" };
    };
    setDeps({ exec: mockExec });
  });

  afterEach(() => {
    process.chdir(originalCwd);
    fs.rmSync(tempDir, { recursive: true, force: true });
    resetDeps();
  });

  test("main returns 0 for help flag", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["--help"]);
    expect(exitCode).toBe(0);
    expect(logSpy).toHaveBeenCalled();
    logSpy.mockRestore();
  });

  test("returns 2 when axe is missing", async () => {
    execResponder = async (cmd: string) => {
      if (cmd.startsWith("which axe")) {
        const err: any = new Error("not found");
        err.code = 1;
        throw err;
      }
      return { stdout: "", stderr: "" };
    };
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["list-simulators"]);
    expect(exitCode).toBe(2);
    expect(errorSpy).toHaveBeenCalledWith(
      expect.stringContaining("axe not found")
    );
    errorSpy.mockRestore();
  });

  describe("config file loading", () => {
    test("loads config from specified path", async () => {
      const configPath = path.join(tempDir, "custom-config.json");
      fs.writeFileSync(
        configPath,
        JSON.stringify({
          defaultDevice: "iPhone 15",
          defaultOsVersion: "18.0",
          outputDir: "/custom/output",
          derivedDataPath: "/custom/dd",
        })
      );

      const config = loadConfig(configPath);
      expect(config.defaultDevice).toBe("iPhone 15");
      expect(config.defaultOsVersion).toBe("18.0");
      expect(config.outputDir).toBe("/custom/output");
      expect(config.derivedDataPath).toBe("/custom/dd");
    });

    test("loads .simcontrol from cwd when no path specified", async () => {
      fs.writeFileSync(
        path.join(tempDir, ".simcontrol"),
        JSON.stringify({
          defaultDevice: "iPhone 14",
          outputDir: "./test-output",
        })
      );

      const config = loadConfig(undefined);
      expect(config.defaultDevice).toBe("iPhone 14");
      expect(config.outputDir).toBe("./test-output");
    });

    test("returns empty config when file is missing", async () => {
      const config = loadConfig("/nonexistent/path/config.json");
      expect(config).toEqual({});
    });

    test("warns on invalid config file", async () => {
      const configPath = path.join(tempDir, "invalid.json");
      fs.writeFileSync(configPath, "not valid json");

      const warnSpy = spyOn(console, "warn").mockImplementation(() => {});
      const config = loadConfig(configPath);

      expect(warnSpy).toHaveBeenCalledWith(expect.stringContaining("Warning: Failed to parse config"));
      expect(config).toEqual({});

      warnSpy.mockRestore();
    });

    test("config with all fields", async () => {
      const configPath = path.join(tempDir, "full-config.json");
      fs.writeFileSync(
        configPath,
        JSON.stringify({
          defaultDevice: "iPhone 16 Pro",
          defaultOsVersion: "20.0.1",
          outputDir: "./custom-output",
          derivedDataPath: "./custom-derived-data",
        })
      );

      const config = loadConfig(configPath);
      expect(config.defaultDevice).toBe("iPhone 16 Pro");
      expect(config.defaultOsVersion).toBe("20.0.1");
      expect(config.outputDir).toBe("./custom-output");
      expect(config.derivedDataPath).toBe("./custom-derived-data");
    });

    test("config with only some fields uses defaults for missing", async () => {
      const configPath = path.join(tempDir, "partial-config.json");
      fs.writeFileSync(
        configPath,
        JSON.stringify({
          defaultDevice: "iPhone SE",
        })
      );

      const config = loadConfig(configPath);
      expect(config.defaultDevice).toBe("iPhone SE");
      expect(config.defaultOsVersion).toBeUndefined();
    });

    test("loads config from path relative to cwd", async () => {
      const configPath = path.join(tempDir, "relative-config.json");
      fs.writeFileSync(
        configPath,
        JSON.stringify({
          defaultDevice: "iPhone 13",
          defaultOsVersion: "15.0",
        })
      );

      const config = loadConfig(configPath);
      expect(config.defaultDevice).toBe("iPhone 13");
    });

    test("handles JSON with comments gracefully", async () => {
      const configPath = path.join(tempDir, "comment-config.json");
      fs.writeFileSync(configPath, '{"defaultDevice": "iPhone 12"}');

      const config = loadConfig(configPath);
      expect(config.defaultDevice).toBe("iPhone 12");
    });
  });

  describe("command parsing", () => {
    test("help flag anywhere in args triggers help", async () => {
      const logSpy = spyOn(console, "log").mockImplementation(() => {});

      const exitCode = await main([
        "--device-name",
        "iPhone 16",
        "--os-version",
        "20.0",
        "--help",
      ]);

      expect(exitCode).toBe(0);
      expect(logSpy).toHaveBeenCalled();

      logSpy.mockRestore();
    });

    test("config file is loaded when using --config", async () => {
      const configPath = path.join(tempDir, "test-config.json");
      fs.writeFileSync(
        configPath,
        JSON.stringify({
          defaultDevice: "iPhone 15",
          defaultOsVersion: "18.0",
        })
      );

      const logSpy = spyOn(console, "log").mockImplementation(() => {});

      const exitCode = await main(["--config", configPath, "--help"]);

      expect(exitCode).toBe(0);
      expect(logSpy).toHaveBeenCalled();

      logSpy.mockRestore();
    });

    test("help with config file shows config defaults", async () => {
      const configPath = path.join(tempDir, "test-config.json");
      fs.writeFileSync(
        configPath,
        JSON.stringify({
          defaultDevice: "iPhone 15",
          defaultOsVersion: "18.0",
        })
      );

      const logSpy = spyOn(console, "log").mockImplementation(() => {});

      const exitCode = await main(["--config", configPath, "--help"]);

      expect(exitCode).toBe(0);
      expect(logSpy).toHaveBeenCalled();

      logSpy.mockRestore();
    });

    test("prints error when no command and no help", async () => {
      const errorSpy = spyOn(console, "error").mockImplementation(() => {});
      const logSpy = spyOn(console, "log").mockImplementation(() => {});

      const exitCode = await main([]);

      expect(exitCode).toBe(0);
      expect(logSpy).toHaveBeenCalled();
      expect(logSpy).toHaveBeenCalledWith(expect.stringContaining("Usage:"));

      logSpy.mockRestore();
      errorSpy.mockRestore();
    });

    test("-h flag triggers help", async () => {
      const logSpy = spyOn(console, "log").mockImplementation(() => {});
      const exitCode = await main(["-h"]);
      expect(exitCode).toBe(0);
      expect(logSpy).toHaveBeenCalled();
      logSpy.mockRestore();
    });
  });

  describe("default values", () => {
    test("shows default device in help", async () => {
      const logSpy = spyOn(console, "log").mockImplementation(() => {});

      const exitCode = await main(["--help"]);

      expect(exitCode).toBe(0);
      expect(logSpy).toHaveBeenCalledWith(expect.stringContaining("iPhone 17 Pro"));
      expect(logSpy).toHaveBeenCalledWith(expect.stringContaining("26.0.1"));

      logSpy.mockRestore();
    });

    test("shows default output directory in help", async () => {
      const logSpy = spyOn(console, "log").mockImplementation(() => {});

      const exitCode = await main(["--help"]);

      expect(exitCode).toBe(0);
      expect(logSpy).toHaveBeenCalledWith(expect.stringContaining("./sim-output"));

      logSpy.mockRestore();
    });

    test("shows available commands in help", async () => {
      const logSpy = spyOn(console, "log").mockImplementation(() => {});

      const exitCode = await main(["--help"]);

      expect(exitCode).toBe(0);
      const output = logSpy.mock.calls.join("\n");
      expect(output).toContain("list-simulators");
      expect(output).toContain("boot");
      expect(output).toContain("install");
      expect(output).toContain("screenshot");

      logSpy.mockRestore();
    });
  });

  describe("error handling", () => {
    test("returns error when command not recognized", async () => {
      const localExec = async (cmd: string): Promise<{ stdout: string; stderr: string }> => {
        if (cmd.startsWith("which axe")) {
          return { stdout: "/usr/local/bin/axe\n", stderr: "" };
        }
        return { stdout: "", stderr: "" };
      };
      setDeps({ exec: localExec });
      const errorSpy = spyOn(console, "error").mockImplementation(() => {});
      const logSpy = spyOn(console, "log").mockImplementation(() => {});

      const exitCode = await main(["not-a-command"]);

      expect(exitCode).toBe(1);
      expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("Unknown command"));

      logSpy.mockRestore();
      errorSpy.mockRestore();
      resetDeps();
    });

    test("launch requires bundle id", async () => {
      const errorSpy = spyOn(console, "error").mockImplementation(() => {});
      const exitCode = await main(["launch", "--udid", "SIM-1"]);
      expect(exitCode).toBe(2);
      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining("Bundle id not found")
      );
      errorSpy.mockRestore();
    });
  });

  describe("command execution", () => {
    test("list-simulators uses axe output", async () => {
      const logSpy = spyOn(console, "log").mockImplementation(() => {});
      const exitCode = await main(["list-simulators"]);
      expect(exitCode).toBe(0);
      const output = logSpy.mock.calls.join("\n");
      expect(output).toContain("SIM-1 | iPhone 15");
      logSpy.mockRestore();
    });

    test("list-simulators falls back to simctl", async () => {
      execResponder = async (cmd: string) => {
        if (cmd.startsWith("which axe")) {
          return { stdout: "/usr/local/bin/axe\n", stderr: "" };
        }
        if (cmd.startsWith("axe list-simulators")) {
          const err: any = new Error("axe failed");
          err.stderr = "axe failed";
          throw err;
        }
        if (cmd.startsWith("xcrun simctl list devices --json")) {
          return { stdout: simctlPayload, stderr: "" };
        }
        return { stdout: "", stderr: "" };
      };

      const logSpy = spyOn(console, "log").mockImplementation(() => {});
      const exitCode = await main(["list-simulators"]);
      expect(exitCode).toBe(0);
      const output = logSpy.mock.calls.join("\n");
      expect(output).toContain("SIM-3 | iPhone 15");
      logSpy.mockRestore();
    });

    test("boot uses udid and respects --no-wait", async () => {
      const exitCode = await main(["boot", "--udid", "SIM-1", "--no-wait"]);
      expect(exitCode).toBe(0);
      expect(execCalls.some((cmd) => cmd.includes("xcrun simctl boot SIM-1"))).toBe(true);
      expect(execCalls.some((cmd) => cmd.includes("bootstatus"))).toBe(false);
    });

    test("screenshot uses provided output path", async () => {
      const outputPath = path.join(tempDir, "shot.png");
      const exitCode = await main([
        "screenshot",
        "--udid",
        "SIM-1",
        "--output",
        outputPath,
      ]);
      expect(exitCode).toBe(0);
      expect(
        execCalls.some((cmd) => cmd.includes(`axe screenshot --udid SIM-1 --output ${outputPath}`))
      ).toBe(true);
    });

    test("run-flow rejects unsupported action", async () => {
      const flowPath = path.join(tempDir, "flow.json");
      fs.writeFileSync(
        flowPath,
        JSON.stringify([{ action: "tap", x: 1, y: 2 }, { action: "nope" }])
      );
      const errorSpy = spyOn(console, "error").mockImplementation(() => {});
      const exitCode = await main(["run-flow", "--flow", flowPath, "--udid", "SIM-1"]);
      expect(exitCode).toBe(2);
      expect(errorSpy).toHaveBeenCalledWith(
        expect.stringContaining("Unsupported action")
      );
      errorSpy.mockRestore();
    });
  });
});
