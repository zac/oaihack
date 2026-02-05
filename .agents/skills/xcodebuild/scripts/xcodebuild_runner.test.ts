import { expect, test, describe, spyOn, beforeEach, afterEach } from "bun:test";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { main, findXcodeContainer, resetDeps, setDeps } from "./xcodebuild_runner";

const mockExec = async (cmd: string): Promise<{ stdout: string; stderr: string }> => {
  if (cmd.startsWith("which xcbeautify")) {
    const err: any = new Error("not found");
    err.code = 1;
    throw err;
  }
  if (cmd.includes("xcodebuild") && cmd.includes("-version")) {
    return { stdout: "Xcode 16.0\nBuild version 16A123\n", stderr: "" };
  }
  if (cmd.includes("xcodebuild -list -json")) {
    return { stdout: JSON.stringify({ project: { schemes: ["App"] } }), stderr: "" };
  }
  if (cmd.startsWith("xcrun simctl list devices --json")) {
    return { stdout: JSON.stringify({ devices: {} }), stderr: "" };
  }
  if (cmd.startsWith("xcrun xccov view")) {
    return { stdout: JSON.stringify({ targets: [] }), stderr: "" };
  }
  return { stdout: "", stderr: "" };
};

beforeEach(() => {
  setDeps({ exec: mockExec });
});

afterEach(() => {
  resetDeps();
});

describe("xcodebuild_runner", () => {
  test("main returns 0 for help flag", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["--help"]);
    expect(exitCode).toBe(0);
    expect(logSpy).toHaveBeenCalled();
    logSpy.mockRestore();
  });

  test("main returns 1 for unknown command", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["unknown-command"]);
    expect(exitCode).toBe(1);
    expect(errorSpy).toHaveBeenCalled();
    errorSpy.mockRestore();
  });

  test("main returns 0 for list-versions command", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["list-versions"]);
    expect([0, 1]).toContain(exitCode);
    logSpy.mockRestore();
  });

  test("main returns 2 for error condition", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["build", "--folder", "/nonexistent"]);
    expect([1, 2]).toContain(exitCode);
    errorSpy.mockRestore();
  });

  test("-h flag triggers help", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["-h"]);
    expect(exitCode).toBe(0);
    expect(logSpy).toHaveBeenCalled();
    logSpy.mockRestore();
  });

  test("empty args triggers help", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main([]);
    expect(exitCode).toBe(0);
    expect(logSpy).toHaveBeenCalled();
    logSpy.mockRestore();
  });

  test("help shows available commands", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["--help"]);
    expect(exitCode).toBe(0);
    const output = logSpy.mock.calls.join("\n");
    expect(output).toContain("list-versions");
    expect(output).toContain("list-schemes");
    expect(output).toContain("build");
    expect(output).toContain("test");
    expect(output).toContain("clean");
    expect(output).toContain("coverage");
    logSpy.mockRestore();
  });

  test("help shows common options", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["--help"]);
    expect(exitCode).toBe(0);
    const output = logSpy.mock.calls.join("\n");
    expect(output).toContain("--folder");
    expect(output).toContain("--workspace");
    expect(output).toContain("--project");
    logSpy.mockRestore();
  });

  test("help shows build/test options", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["--help"]);
    expect(exitCode).toBe(0);
    const output = logSpy.mock.calls.join("\n");
    expect(output).toContain("--scheme");
    expect(output).toContain("--configuration");
    expect(output).toContain("--destination");
    logSpy.mockRestore();
  });

  test("help shows coverage options", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["--help"]);
    expect(exitCode).toBe(0);
    const output = logSpy.mock.calls.join("\n");
    expect(output).toContain("--threshold");
    expect(output).toContain("--format");
    expect(output).toContain("--show-all-files");
    logSpy.mockRestore();
  });

  test("unknown command shows error and usage", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["fake-command"]);
    expect(exitCode).toBe(1);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("Unknown command"));
    expect(logSpy).toHaveBeenCalledWith(expect.stringContaining("Usage:"));
    errorSpy.mockRestore();
    logSpy.mockRestore();
  });

  test("list-schemes requires folder with xcworkspace/xcodeproj", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["list-schemes", "--folder", "/nonexistent"]);
    expect([1, 2]).toContain(exitCode);
    errorSpy.mockRestore();
  });

  test("coverage-report shows help when no xcresult found", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["coverage-report", "--folder", "/nonexistent"]);
    expect([1, 2]).toContain(exitCode);
    errorSpy.mockRestore();
  });
});

describe("dependency directory checks", () => {
  let tempDir: string;

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "xcodebuild-test-"));
  });

  afterEach(() => {
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  test("finds project outside dependency directories", () => {
    const projectDir = path.join(tempDir, "MyApp.xcodeproj");
    fs.mkdirSync(projectDir, { recursive: true });

    const result = findXcodeContainer(tempDir);
    expect(result).not.toBeNull();
    expect(result?.path).toBe(projectDir);
  });

  test("skips SourcePackages directory when searching for project", () => {
    const sourcePackages = path.join(tempDir, "SourcePackages");
    const nestedProject = path.join(sourcePackages, "MyApp.xcodeproj");
    fs.mkdirSync(nestedProject, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).toBeNull();
  });

  test("skips build directory when searching for project", () => {
    const buildDir = path.join(tempDir, "build");
    const nestedProject = path.join(buildDir, "MyApp.xcodeproj");
    fs.mkdirSync(nestedProject, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).toBeNull();
  });

  test("skips DerivedData directory when searching for project", () => {
    const derivedData = path.join(tempDir, "DerivedData");
    const nestedProject = path.join(derivedData, "MyApp.xcodeproj");
    fs.mkdirSync(nestedProject, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).toBeNull();
  });

  test("skips Pods directory when searching for project", () => {
    const podsDir = path.join(tempDir, "Pods");
    const nestedProject = path.join(podsDir, "MyApp.xcodeproj");
    fs.mkdirSync(nestedProject, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).toBeNull();
  });

  test("skips .build directory when searching for project", () => {
    const buildDir = path.join(tempDir, ".build");
    const nestedProject = path.join(buildDir, "MyApp.xcodeproj");
    fs.mkdirSync(nestedProject, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).toBeNull();
  });

  test("skips Carthage directory when searching for project", () => {
    const carthageDir = path.join(tempDir, "Carthage");
    const nestedProject = path.join(carthageDir, "Checkouts", "MyApp.xcodeproj");
    fs.mkdirSync(nestedProject, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).toBeNull();
  });

  test("skips Packages directory when searching for project", () => {
    const packagesDir = path.join(tempDir, "Packages");
    const nestedProject = path.join(packagesDir, "MyApp.xcodeproj");
    fs.mkdirSync(nestedProject, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).toBeNull();
  });

  test("finds project outside dependency even when nested inside one exists", () => {
    const sourcePackages = path.join(tempDir, "SourcePackages");
    const nestedProject = path.join(sourcePackages, "MyApp.xcodeproj");
    fs.mkdirSync(nestedProject, { recursive: true });

    const rootProject = path.join(tempDir, "App.xcodeproj");
    fs.mkdirSync(rootProject, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).not.toBeNull();
    expect(result?.path).toBe(rootProject);
  });

  test("prefers workspace over project in non-dependency directory", () => {
    const workspaceDir = path.join(tempDir, "MyApp.xcworkspace");
    fs.mkdirSync(workspaceDir, { recursive: true });

    const projectDir = path.join(tempDir, "MyApp.xcodeproj");
    fs.mkdirSync(projectDir, { recursive: true });

    const result = findXcodeContainer(tempDir, true);
    expect(result).not.toBeNull();
    expect(result?.flag).toBe("-workspace");
    expect(result?.path).toBe(workspaceDir);
  });

  test("finds deeply nested project when parent has dependency dir", () => {
    const sourcePackages = path.join(tempDir, "SourcePackages");
    fs.mkdirSync(sourcePackages, { recursive: true });

    const appDir = path.join(tempDir, "App");
    fs.mkdirSync(appDir, { recursive: true });
    const projectDir = path.join(appDir, "MyApp.xcodeproj");
    fs.mkdirSync(projectDir, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).not.toBeNull();
    expect(result?.path).toBe(projectDir);
  });

  test("skips all dependency directories simultaneously", () => {
    const dependencyDirs = ["SourcePackages", "build", "DerivedData", "Pods", ".build", "Carthage", "Packages"];

    for (const depDir of dependencyDirs) {
      const depPath = path.join(tempDir, depDir);
      fs.mkdirSync(depPath, { recursive: true });
      const nestedProject = path.join(depPath, "NestedApp.xcodeproj");
      fs.mkdirSync(nestedProject, { recursive: true });
    }

    const result = findXcodeContainer(tempDir, false);
    expect(result).toBeNull();
  });

  test("finds workspace in nested directory when not in dependency dirs", () => {
    const appDir = path.join(tempDir, "App");
    fs.mkdirSync(appDir, { recursive: true });
    const workspaceDir = path.join(appDir, "MyApp.xcworkspace");
    fs.mkdirSync(workspaceDir, { recursive: true });

    const result = findXcodeContainer(tempDir, true);
    expect(result).not.toBeNull();
    expect(result?.flag).toBe("-workspace");
    expect(result?.path).toBe(workspaceDir);
  });

  test("finds project at root when dependency dirs exist elsewhere", () => {
    const sourcePackages = path.join(tempDir, "SourcePackages");
    fs.mkdirSync(sourcePackages, { recursive: true });

    const rootProject = path.join(tempDir, "App.xcodeproj");
    fs.mkdirSync(rootProject, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).not.toBeNull();
    expect(result?.path).toBe(rootProject);
  });

  test("does not descend into SourcePackages even with deep nesting", () => {
    const sourcePackages = path.join(tempDir, "SourcePackages");
    fs.mkdirSync(sourcePackages, { recursive: true });
    const deepNested = path.join(sourcePackages, "a", "b", "c", "MyApp.xcodeproj");
    fs.mkdirSync(deepNested, { recursive: true });

    const rootProject = path.join(tempDir, "App.xcodeproj");
    fs.mkdirSync(rootProject, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).not.toBeNull();
    expect(result?.path).toBe(rootProject);
  });

  test("handles empty directory gracefully", () => {
    const result = findXcodeContainer(tempDir, false);
    expect(result).toBeNull();
  });

  test("handles directory with only hidden files and dirs", () => {
    fs.mkdirSync(path.join(tempDir, ".git"), { recursive: true });
    fs.writeFileSync(path.join(tempDir, ".gitignore"), "# test");
    fs.writeFileSync(path.join(tempDir, ".DS_Store"), "");

    const result = findXcodeContainer(tempDir, false);
    expect(result).toBeNull();
  });

  test("prefers project over workspace when preferWorkspace is false", () => {
    const projectDir = path.join(tempDir, "MyApp.xcodeproj");
    fs.mkdirSync(projectDir, { recursive: true });

    const workspaceDir = path.join(tempDir, "MyApp.xcworkspace");
    fs.mkdirSync(workspaceDir, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).not.toBeNull();
    expect(result?.flag).toBe("-project");
    expect(result?.path).toBe(projectDir);
  });

  test("skips nested dependency dirs at any depth", () => {
    const nestedBuild = path.join(tempDir, "App", "build", "MyApp.xcodeproj");
    fs.mkdirSync(nestedBuild, { recursive: true });

    const rootProject = path.join(tempDir, "App.xcodeproj");
    fs.mkdirSync(rootProject, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).not.toBeNull();
    expect(result?.path).toBe(rootProject);
  });

  test("returns shallowest project when multiple exist outside dependency dirs", () => {
    const nestedProject = path.join(tempDir, "deeply", "nested", "MyApp.xcodeproj");
    fs.mkdirSync(nestedProject, { recursive: true });

    const rootProject = path.join(tempDir, "App.xcodeproj");
    fs.mkdirSync(rootProject, { recursive: true });

    const result = findXcodeContainer(tempDir, false);
    expect(result).not.toBeNull();
    expect(result?.path).toBe(rootProject);
  });
});
