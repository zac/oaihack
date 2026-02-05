---
name: sim-control
description: Use when asked to automate iOS Simulator UI, capture screenshots or videos, or validate end-to-end flows.
---

# Sim Control

## Overview
Use `.agents/skills/sim-control/scripts/sim_control_runner.ts` (run with `bun`) to control iOS simulators via AXe + `xcrun simctl`. The Xcode MCP tools do **not** provide simulator UI automation, so this remains the preferred path for UI flows and screenshots.

**Prereqs:** AXe installed (`brew install axe`). Xcode does not need to be open, but you need a built app (use `xcodebuild` to build).

## When to Use This Skill

Use `sim-control` when:
- Installing and launching apps on the simulator
- UI automation (tap, type, swipe, buttons, gestures)
- Capturing screenshots or videos for PR reviews
- Validating navigation flows with reusable flow files
- End-to-end UI testing without building

Do NOT use this skill for:
- Building projects (use `xcodebuild` skill)
- Running tests with coverage (use `xcodebuild` skill)
- Project file management (use `xcodeproj-edit` skill)
- Managing Xcode schemes or targets (use `xcodebuild` skill)
- SwiftUI previews (use `xcodebuild` → `RenderPreview`)

## Scripted workflow (preferred)
Use `.agents/skills/sim-control/scripts/sim_control_runner.ts` (run with `bun`) to keep simulator automation repeatable. Defaults to **iPhone 17 Pro** and the latest available iOS for that device; if unavailable, it picks the closest available match.

Examples:
```
# List simulators
bun .agents/skills/sim-control/scripts/sim_control_runner.ts list-simulators

# Boot the preferred simulator
bun .agents/skills/sim-control/scripts/sim_control_runner.ts boot

# Install + launch without building (uses DerivedData by default)
bun .agents/skills/sim-control/scripts/sim_control_runner.ts install-launch --app-name MyApp

# Dump UI hierarchy for element labels/ids
bun .agents/skills/sim-control/scripts/sim_control_runner.ts describe-ui --output ./sim-output/ui.txt

# Tap and type
bun .agents/skills/sim-control/scripts/sim_control_runner.ts tap --label "Profile"
bun .agents/skills/sim-control/scripts/sim_control_runner.ts type "hello@example.com"

# Screenshot
bun .agents/skills/sim-control/scripts/sim_control_runner.ts screenshot --name profile
```

### Flow files (multi-step UI automation)
Use `run-flow` with a JSON array of steps (see `references/flow-format.md`). This is ideal for PR screenshots or validating navigation flows.

```
bun .agents/skills/sim-control/scripts/sim_control_runner.ts run-flow --flow ./flows/profile_flow.json --output-dir ./sim-output
```

## Destination Format

The script accepts three destination formats for simulator selection:

```bash
# 1. Auto-resolve (recommended) - finds latest OS automatically
bun .agents/skills/sim-control/scripts/sim_control_runner.ts boot --device-name "iPhone 17 Pro"

# 2. Explicit OS version
bun .agents/skills/sim-control/scripts/sim_control_runner.ts boot --device-name "iPhone 17 Pro" --os-version 26.0.1

# 3. Direct UDID
bun .agents/skills/sim-control/scripts/sim_control_runner.ts boot --udid ABC-123-DEF-456
```

If no destination is specified, it uses the configured defaults (or built‑in defaults) and finds the closest available match.

## Efficiency Tips

AXe is accessibility-first, which makes it more efficient than coordinate-based approaches:

- **Use `describe-ui`** to discover accessibility identifiers before interacting with elements. This queries the accessibility tree (~120ms) and is 3-4x faster than coordinate-based methods.

- **Prefer labels/IDs over coordinates**: Elements may move between screen sizes or OS versions. Accessibility identifiers remain stable.

- **Use flow files** for repeatable multi-step UI validation. Define once, run many times.

- **Combine with screenshots**: Capture visual evidence of UI state after important actions for PR reviews.

## Configuration

Create a `.simcontrol` file in your project root to set defaults:

```json
{
  "defaultDevice": "iPhone 17 Pro",
  "defaultOsVersion": "26.0.1",
  "outputDir": "./sim-output",
  "derivedDataPath": "./DerivedData"
}
```

The script reads this file if present and uses these values as defaults.

## Workflow Examples

### PR Screenshot Validation
```
# 1. Install and launch app from DerivedData
bun .agents/skills/sim-control/scripts/sim_control_runner.ts install-launch --app-name MyApp

# 2. Run flow to capture PR screenshots
bun .agents/skills/sim-control/scripts/sim_control_runner.ts run-flow \
  --flow ./flows/pr-screenshots.json \
  --output-dir ./pr-screenshots
```

### Debug UI Issue
```
# 1. Describe current UI to find element identifiers
bun .agents/skills/sim-control/scripts/sim_control_runner.ts describe-ui --output ui-state.txt

# 2. Interact with specific elements
bun .agents/skills/sim-control/scripts/sim_control_runner.ts tap --label "Submit Button"
bun .agents/skills/sim-control/scripts/sim_control_runner.ts type "test@example.com"

# 3. Capture screenshot of resulting state
bun .agents/skills/sim-control/scripts/sim_control_runner.ts screenshot --name debug-issue
```

### App Launch Verification
```
# Boot simulator, install, launch, and check it didn't crash
bun .agents/skills/sim-control/scripts/sim_control_runner.ts boot
bun .agents/skills/sim-control/scripts/sim_control_runner.ts install-launch --app-name MyApp
sleep 5
bun .agents/skills/sim-control/scripts/sim_control_runner.ts describe-ui --output after-launch.txt
```

## Notes
- Prefer accessibility identifiers/labels; use `describe-ui` to discover them.
- `axe type` supports US keyboard characters only.
- Keep this skill focused on simulator automation; use `xcodebuild` for build/test/coverage.

## References
- `references/axe-cheatsheet.md`
- `references/simctl-cheatsheet.md`
- `references/flow-format.md`
