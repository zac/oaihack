import { expect, test, describe, spyOn } from "bun:test";
import { main } from "./xcodeproj_edit_runner";

describe("xcodeproj_edit_runner", () => {
  test("main returns 0 for help flag", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["--help"]);
    expect(exitCode).toBe(0);
    expect(logSpy).toHaveBeenCalled();
    logSpy.mockRestore();
  });

  test("main returns 1 when project is missing", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["add-files"]);
    expect(exitCode).toBe(1);
    expect(errorSpy).toHaveBeenCalled();
    errorSpy.mockRestore();
  });

  test("main returns 1 when command is missing", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["--project", "Test.xcodeproj"]);
    expect(exitCode).toBe(1);
    expect(errorSpy).toHaveBeenCalled();
    errorSpy.mockRestore();
  });

  test("main returns 1 for unknown command", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["--project", "Test.xcodeproj", "unknown-command"]);
    expect(exitCode).toBe(1);
    expect(errorSpy).toHaveBeenCalled();
    errorSpy.mockRestore();
  });

  test("-h flag triggers help", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["-h"]);
    expect(exitCode).toBe(0);
    expect(logSpy).toHaveBeenCalled();
    logSpy.mockRestore();
  });

  test("help shows available commands", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["--help"]);
    expect(exitCode).toBe(0);
    const output = logSpy.mock.calls.join("\n");
    expect(output).toContain("add-files");
    expect(output).toContain("remove-files");
    expect(output).toContain("add-group");
    expect(output).toContain("remove-group");
    expect(output).toContain("add-spm");
    expect(output).toContain("remove-spm");
    expect(output).toContain("list-targets");
    expect(output).toContain("show-files");
    expect(output).toContain("find-orphans");
    logSpy.mockRestore();
  });

  test("help shows add-files options", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["--help"]);
    expect(exitCode).toBe(0);
    const output = logSpy.mock.calls.join("\n");
    expect(output).toContain("--group");
    expect(output).toContain("--target");
    expect(output).toContain("--no-create-groups");
    logSpy.mockRestore();
  });

  test("help shows add-spm options", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main(["--help"]);
    expect(exitCode).toBe(0);
    const output = logSpy.mock.calls.join("\n");
    expect(output).toContain("--url");
    expect(output).toContain("--product");
    expect(output).toContain("--version");
    expect(output).toContain("--exact");
    expect(output).toContain("--branch");
    expect(output).toContain("--revision");
    logSpy.mockRestore();
  });

  test("add-files requires --group", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["--project", "Test.xcodeproj", "add-files"]);
    expect(exitCode).toBe(2);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("--group is required"));
    errorSpy.mockRestore();
  });

  test("add-files requires file paths", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["--project", "Test.xcodeproj", "add-files", "--group", "MyApp/Sources"]);
    expect(exitCode).toBe(2);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("file path"));
    errorSpy.mockRestore();
  });

  test("remove-files requires file paths", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["--project", "Test.xcodeproj", "remove-files"]);
    expect(exitCode).toBe(2);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("file path"));
    errorSpy.mockRestore();
  });

  test("add-group requires --group", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["--project", "Test.xcodeproj", "add-group"]);
    expect(exitCode).toBe(2);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("--group is required"));
    errorSpy.mockRestore();
  });

  test("remove-group requires --group", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["--project", "Test.xcodeproj", "remove-group"]);
    expect(exitCode).toBe(2);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("--group is required"));
    errorSpy.mockRestore();
  });

  test("add-spm requires --url", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["--project", "Test.xcodeproj", "add-spm", "--product", "MyLib"]);
    expect(exitCode).toBe(2);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("--url is required"));
    errorSpy.mockRestore();
  });

  test("add-spm requires --product", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["--project", "Test.xcodeproj", "add-spm", "--url", "https://example.com"]);
    expect(exitCode).toBe(2);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("--product is required"));
    errorSpy.mockRestore();
  });

  test("add-spm requires version requirement", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main([
      "--project", "Test.xcodeproj",
      "add-spm",
      "--url", "https://example.com",
      "--product", "MyLib"
    ]);
    expect(exitCode).toBe(2);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("version"));
    errorSpy.mockRestore();
  });

  test("remove-spm requires --product", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["--project", "Test.xcodeproj", "remove-spm"]);
    expect(exitCode).toBe(2);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("--product is required"));
    errorSpy.mockRestore();
  });

  test("show-files requires --target", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["--project", "Test.xcodeproj", "show-files"]);
    expect(exitCode).toBe(2);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("--target is required"));
    errorSpy.mockRestore();
  });

  test("find-orphans requires --source-dir", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});
    const exitCode = await main(["--project", "Test.xcodeproj", "find-orphans"]);
    expect(exitCode).toBe(2);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining("--source-dir is required"));
    errorSpy.mockRestore();
  });

  test("empty args triggers help", async () => {
    const logSpy = spyOn(console, "log").mockImplementation(() => {});
    const exitCode = await main([]);
    expect(exitCode).toBe(0);
    expect(logSpy).toHaveBeenCalled();
    logSpy.mockRestore();
  });
});
