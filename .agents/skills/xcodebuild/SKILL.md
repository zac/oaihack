---
name: xcodebuild
description: Use when asked to build, test, preview, or inspect build issues for an Xcode project in this workspace.
---

# Xcodebuild

## Overview
Prefer the Xcode MCP tools for build/test/preview tasks. The MCP service requires the Xcode app to be running **with the target project open**. Use `XcodeListWindows` to find the correct `tabIdentifier`.

If MCP tools are unavailable or you specifically need code coverage output, fall back to the local `xcodebuild_runner.ts` script.

## When to Use
- Build or test an Xcode project
- Run specific tests or list tests
- Render SwiftUI previews
- Inspect build/test diagnostics

Do NOT use for:
- Project file/group edits or SPM dependency changes (use `xcodeproj-edit`)
- Simulator UI automation or screenshots (use `sim-control`)

## MCP Quick Reference
| Task | MCP tool |
| --- | --- |
| Build | `mcp__xcode__BuildProject` |
| All tests | `mcp__xcode__RunAllTests` |
| Specific tests | `mcp__xcode__GetTestList` → `mcp__xcode__RunSomeTests` |
| Preview | `mcp__xcode__RenderPreview` |
| Build logs | `mcp__xcode__GetBuildLog` |
| Issues | `mcp__xcode__XcodeListNavigatorIssues` |
| Inspect code | `mcp__xcode__XcodeRead` / `mcp__xcode__XcodeGrep` |

**Note:** If MCP calls fail, verify Xcode is open and the correct window is active.

## Fallback (script-only tasks)
Use this when MCP is unavailable or when you need coverage reports.

```
bun .agents/skills/xcodebuild/scripts/xcodebuild_runner.ts list-schemes --folder .
bun .agents/skills/xcodebuild/scripts/xcodebuild_runner.ts build --scheme <Scheme>
bun .agents/skills/xcodebuild/scripts/xcodebuild_runner.ts test --scheme <Scheme>
bun .agents/skills/xcodebuild/scripts/xcodebuild_runner.ts coverage --scheme <Scheme>
bun .agents/skills/xcodebuild/scripts/xcodebuild_runner.ts coverage-report --threshold 80 --format markdown
```

**Prereqs:** `bun` and `xcbeautify` (install via Homebrew).

## Common Mistakes
- MCP fails because Xcode isn’t running or the project isn’t open → open Xcode and retry.
- Using the old `scripts/xcodebuild_runner.ts` path → use `.agents/skills/xcodebuild/scripts/...`.
- Expecting coverage from MCP → use the fallback script.
