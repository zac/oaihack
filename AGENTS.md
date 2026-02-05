# AGENTS.md

## Project Focus
- Hackathon project: SwiftUI JSON Render (see `ideas/swiftui-json-render.md`).
- Deliverables:
  - `SwiftUIRender` Swift Package for JSON -> SwiftUI rendering logic.
  - `RenderChat` multi-platform app as the playground/demo shell.
- MVP priorities:
  - Guardrailed catalog of components + actions with validation.
  - Normalized render tree and SwiftUI renderer.
  - JSON Pointer data binding for read/write.
  - JSONL streaming patch playback (deterministic demo streams).
  - Minimal exporter only for supported components.
- Demo constraints: open-source only, no external APIs or closed-source models, deterministic streams.

## Repo Layout
- `RenderChat/`: Xcode multi-platform app target (demo shell).
- `SwiftUIRender/`: SPM package for JSON rendering and core logic.
- `ideas/swiftui-json-render.md`: primary spec, scope, and demo plan.
- `codex-log/`: Codex devlog entries.
- `codex-hackathon-details.md`: event rules and judging criteria.

## Skills (from .agents)
- `codex-hackathon-ideation`: use when refining scope, narrative, demo flow, or judging alignment.
- `codex-hackathon-submission`: use when drafting the submission form, demo description, compliance checklist, and Codex story.
- `codex-devlog`: use at the end of each session to create a new entry in `codex-log/` using `.agents/skills/codex-devlog/assets/devlog-template.md`.

## Working Guidelines
- Keep the JSON spec guardrailed: only catalog-defined components/actions.
- Prefer stable demo behavior (recorded JSONL streams + sample data).
- Keep renderer side-effect-free; surface invalid nodes via explicit guardrail views.
- Maintain iOS/macOS compatibility in shared package code.
