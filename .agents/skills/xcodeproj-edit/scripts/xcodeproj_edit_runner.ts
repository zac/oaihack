#!/usr/bin/env bun
/**
 * CLI wrapper to edit .xcodeproj files via the xcodeproj Ruby gem.
 *
 * Run with: bun skill/xcodeproj-edit/scripts/xcodeproj_edit_runner.ts <command> [options]
 */

import { exec, spawn } from "child_process";
import { promisify } from "util";
import * as path from "path";
import * as fs from "fs";

const execAsync = promisify(exec);

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

interface Payload {
  action: string;
  project: string;
  targets: string[];
  [key: string]: any;
}

// ─────────────────────────────────────────────────────────────────────────────
// Utility Functions
// ─────────────────────────────────────────────────────────────────────────────

async function requireXcodeproj(): Promise<void> {
  try {
    await execAsync("ruby -e \"require 'xcodeproj'\"");
  } catch {
    console.error(
      "Error: xcodeproj gem not found. Install with: gem install xcodeproj"
    );
    process.exit(2);
  }
}

async function runRuby(payload: Payload): Promise<number> {
  const scriptPath = path.join(import.meta.dir, "xcodeproj_edit.rb");

  // Verify the Ruby script exists
  if (!fs.existsSync(scriptPath)) {
    console.error(`Error: Ruby script not found at ${scriptPath}`);
    return 1;
  }

  return new Promise((resolve) => {
    const ruby = spawn("ruby", [scriptPath], {
      stdio: ["pipe", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";

    ruby.stdout?.on("data", (data) => {
      stdout += data.toString();
    });

    ruby.stderr?.on("data", (data) => {
      stderr += data.toString();
    });

    ruby.on("close", (code) => {
      if (stdout) console.log(stdout.trimEnd());
      if (stderr) console.error(stderr.trimEnd());
      resolve(code ?? 0);
    });

    ruby.stdin?.write(JSON.stringify(payload));
    ruby.stdin?.end();
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CLI
// ─────────────────────────────────────────────────────────────────────────────

function printUsage(): void {
  console.log(`
Usage: bun xcodeproj_edit_runner.ts --project <path> <command> [options]

Commands:
  add-files       Add files to a group and target(s)
  remove-files    Remove files from project and target(s)
  add-group       Add a group to the project
  remove-group    Remove a group from the project
  add-spm         Add Swift Package dependency to target(s)
  remove-spm      Remove Swift Package dependency from target(s)
  list-targets    List all targets in the project
  show-files      Show files in a target's build phases
  find-orphans    Find source files not in the project

Required:
  --project <path>    Path to the .xcodeproj

Add Files Options:
  --group <path>      Group path (e.g., 'MyApp/Models') (required)
  --target <name>     Target name (repeatable)
  --no-create-groups  Do not auto-create missing groups
  <files...>          File paths to add (positional)

Remove Files Options:
  --target <name>     Target name (repeatable)
  <files...>          File paths to remove (positional)

Add Group Options:
  --group <path>      Group path to create (required)

Remove Group Options:
  --group <path>      Group path to remove (required)
  --recursive         Remove group and all descendants

Add SPM Options:
  --url <url>         Package repository URL (required)
  --product <name>    Swift package product name (required)
  --target <name>     Target name (repeatable)
  --version <ver>     Minimum version (uses upToNextMajorVersion)
  --exact <ver>       Exact version
  --branch <name>     Branch name
  --revision <hash>   Revision hash

Remove SPM Options:
  --url <url>         Package repository URL (optional)
  --product <name>    Swift package product name (required)
  --target <name>     Target name (repeatable)

List Targets Options:
  (no additional options)

Show Files Options:
  --target <name>     Target name (repeatable, required)

Find Orphans Options:
  --source-dir <path> Source directory to scan (required)

Examples:
  # Add files to a group and target
  bun xcodeproj_edit_runner.ts --project MyApp.xcodeproj \\
    add-files --group "MyApp/Models" --target MyApp \\
    MyApp/Models/NewModel.swift

  # Remove files from all targets
  bun xcodeproj_edit_runner.ts --project MyApp.xcodeproj \\
    remove-files MyApp/Models/OldModel.swift

  # Add an empty group
  bun xcodeproj_edit_runner.ts --project MyApp.xcodeproj \\
    add-group --group "MyApp/New Feature"

  # Remove a group recursively
  bun xcodeproj_edit_runner.ts --project MyApp.xcodeproj \\
    remove-group --group "MyApp/Deprecated" --recursive

  # Add an SPM package product to target
  bun xcodeproj_edit_runner.ts --project MyApp.xcodeproj \\
    add-spm --url https://github.com/pointfreeco/swift-composable-architecture \\
    --product ComposableArchitecture --version 1.3.0 --target MyApp

  # Remove an SPM product from all targets
  bun xcodeproj_edit_runner.ts --project MyApp.xcodeproj \\
    remove-spm --product ComposableArchitecture

  # List all targets
  bun xcodeproj_edit_runner.ts --project MyApp.xcodeproj list-targets

  # Show files in a target
  bun xcodeproj_edit_runner.ts --project MyApp.xcodeproj \\
    show-files --target MyApp

  # Find orphaned source files
  bun xcodeproj_edit_runner.ts --project MyApp.xcodeproj \\
    find-orphans --source-dir MyApp/Sources
`);
}

export async function main(argv: string[] = process.argv.slice(2)): Promise<number> {
  const args = argv;

  if (args.length === 0 || args[0] === "--help" || args[0] === "-h") {
    printUsage();
    return 0;
  }

  // Check for xcodeproj gem
  await requireXcodeproj();

  // Parse arguments
  const getArg = (names: string[]): string | undefined => {
    for (const name of names) {
      const idx = args.indexOf(name);
      if (idx !== -1 && idx + 1 < args.length) {
        return args[idx + 1];
      }
    }
    return undefined;
  };

  const hasFlag = (names: string[]): boolean => {
    return names.some((name) => args.includes(name));
  };

  const getMultiple = (names: string[]): string[] => {
    const result: string[] = [];
    for (const name of names) {
      let idx = 0;
      while ((idx = args.indexOf(name, idx)) !== -1) {
        if (idx + 1 < args.length) {
          result.push(args[idx + 1]);
        }
        idx++;
      }
    }
    return result;
  };

  // Get project path
  const project = getArg(["--project"]);
  if (!project) {
    console.error("Error: --project is required");
    printUsage();
    return 1;
  }

  // Find command (first positional arg that isn't part of a flag)
  const flagsWithValues = [
    "--project",
    "--group",
    "--target",
    "--url",
    "--product",
    "--version",
    "--exact",
    "--branch",
    "--revision",
    "--source-dir",
  ];

  let command: string | undefined;
  let positionalArgs: string[] = [];

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg.startsWith("-")) {
      // Check if this flag takes a value
      if (flagsWithValues.includes(arg)) {
        i++; // Skip the value
      }
      continue;
    }

    // First non-flag arg is the command
    if (!command) {
      command = arg;
    } else {
      // Subsequent non-flag args are positional (file paths, etc.)
      positionalArgs.push(arg);
    }
  }

  if (!command) {
    console.error("Error: command is required");
    printUsage();
    return 1;
  }

  const targets = getMultiple(["--target"]);

  const payload: Payload = {
    action: command,
    project,
    targets,
  };

  try {
    switch (command) {
      case "add-files": {
        const group = getArg(["--group"]);
        if (!group) {
          throw new Error("--group is required for add-files");
        }
        if (positionalArgs.length === 0) {
          throw new Error("At least one file path is required for add-files");
        }
        payload.group = group;
        payload.create_groups = !hasFlag(["--no-create-groups"]);
        payload.files = positionalArgs;
        break;
      }

      case "remove-files": {
        if (positionalArgs.length === 0) {
          throw new Error("At least one file path is required for remove-files");
        }
        payload.files = positionalArgs;
        break;
      }

      case "add-group": {
        const group = getArg(["--group"]);
        if (!group) {
          throw new Error("--group is required for add-group");
        }
        payload.group = group;
        break;
      }

      case "remove-group": {
        const group = getArg(["--group"]);
        if (!group) {
          throw new Error("--group is required for remove-group");
        }
        payload.group = group;
        payload.recursive = hasFlag(["--recursive"]);
        break;
      }

      case "add-spm": {
        const url = getArg(["--url"]);
        const product = getArg(["--product"]);
        if (!url) {
          throw new Error("--url is required for add-spm");
        }
        if (!product) {
          throw new Error("--product is required for add-spm");
        }

        const version = getArg(["--version"]);
        const exact = getArg(["--exact"]);
        const branch = getArg(["--branch"]);
        const revision = getArg(["--revision"]);

        if (!version && !exact && !branch && !revision) {
          throw new Error(
            "One of --version, --exact, --branch, or --revision is required for add-spm"
          );
        }

        payload.url = url;
        payload.product = product;
        if (version) payload.version = version;
        if (exact) payload.exact = exact;
        if (branch) payload.branch = branch;
        if (revision) payload.revision = revision;
        break;
      }

      case "remove-spm": {
        const product = getArg(["--product"]);
        if (!product) {
          throw new Error("--product is required for remove-spm");
        }
        payload.product = product;
        payload.url = getArg(["--url"]);
        break;
      }

      case "list-targets":
        // No additional options needed
        break;

      case "show-files": {
        if (targets.length === 0) {
          throw new Error("--target is required for show-files");
        }
        break;
      }

      case "find-orphans": {
        const sourceDir = getArg(["--source-dir"]);
        if (!sourceDir) {
          throw new Error("--source-dir is required for find-orphans");
        }
        payload.source_dir = sourceDir;
        break;
      }

      default:
        console.error(`Unknown command: ${command}`);
        printUsage();
        return 1;
    }

    return await runRuby(payload);
  } catch (error: any) {
    console.error(`Error: ${error.message}`);
    return 2;
  }
}

if (import.meta.main) {
  main().then((code) => process.exit(code));
}
