---
name: xcodeproj-edit
description: Use when adding, removing, or reorganizing files/groups in an Xcode project, or when managing Swift Package dependencies.
---

# Xcodeproj Edit

## Overview
Prefer Xcode MCP tools for file/group changes. The MCP service requires the Xcode app to be running **with the target project open**. Use `XcodeListWindows` to find the correct `tabIdentifier`.

Use the Ruby script only for Swift Package dependency changes or when MCP is unavailable.

## When to Use
- Add/remove/move files or groups in the project navigator
- Rename or reorganize project folders/groups
- Add/remove Swift Package dependencies

Do NOT use for:
- Build/test/coverage (use `xcodebuild`)
- Simulator UI automation (use `sim-control`)

## MCP Quick Reference (project structure)
| Task | MCP tool |
| --- | --- |
| Create group/folder | `mcp__xcode__XcodeMakeDir` |
| Add file | `mcp__xcode__XcodeWrite` |
| Edit file | `mcp__xcode__XcodeUpdate` |
| Move/rename | `mcp__xcode__XcodeMV` |
| Remove | `mcp__xcode__XcodeRM` |
| Discover paths | `mcp__xcode__XcodeLS` / `mcp__xcode__XcodeGlob` |

## Fallback: Swift Package dependencies (script)
```
bun .agents/skills/xcodeproj-edit/scripts/xcodeproj_edit_runner.ts --project <Project>.xcodeproj \
  add-files --group "App/Models" --target <Target> App/Models/NewModel.swift

bun .agents/skills/xcodeproj-edit/scripts/xcodeproj_edit_runner.ts --project <Project>.xcodeproj \
  add-spm --url <repo> --product <Product> --version <Semver> --target <Target>

bun .agents/skills/xcodeproj-edit/scripts/xcodeproj_edit_runner.ts --project <Project>.xcodeproj \
  remove-spm --product <Product>
```

**Prereq:** `xcodeproj` gem (`gem install xcodeproj`).

## Common Mistakes
- MCP fails because Xcode isn’t open → open Xcode and retry.
- Using the old `scripts/xcodeproj_edit_runner.ts` path → use `.agents/skills/xcodeproj-edit/scripts/...`.
- Trying to manage SPM or explicit target membership via MCP → use the script.
