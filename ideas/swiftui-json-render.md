# SwiftUI JSON Render (native json-render.dev)

## One-line summary
An open-source Swift Package + SwiftUI Playground app that renders a **guardrailed JSON UI spec** into native SwiftUI, with **component catalogs**, **streaming patch updates (JSONL)**, **data binding (JSON Pointer)**, and **named actions** — a SwiftUI-native counterpart to https://json-render.dev.

## Target user + pain point
- **User:** iOS/macOS teams building AI-assisted UI or server-driven UI (SDUI), plus dev-tool builders
- **Pain:** “free-form AI UI” is brittle and unsafe; teams need a constrained contract (schema + catalog) that’s easy to validate, stream, and render natively

## Deadline + constraints (Codex Hackathon)
- **Submission deadline:** **Thursday, February 5, 2026 at 4:00 PM PT**
- **Time remaining (as of Tue Feb 3, 2026 ~10:01 PM PT):** ~42 hours
- **Rules:** open source only + new work only; team size ≤ 4; demo must be a working product (no slides); avoid disallowed “anti-project” categories
- **Judging weights:** Impact 25%, Codex App story 25%, Creative use of skills 25%, Demo & pitch 25%

## Demo flow (3 steps)
1. Pick a catalog (e.g., “Support Dashboard”) + load sample data (a JSON document).
2. Tap **Stream UI**: the app consumes a **JSONL patch stream** (simulated for demo safety) and the UI renders progressively; invalid nodes show guardrail errors.
3. Interact: edit a bound field (two-way binding via JSON Pointer) and tap a button that triggers a **named action**; then **Export SwiftUI** to generate a minimal, compile-ready view.

## What you build (MVP scope)
**Package:** `JSONRenderSwiftUI`
- **Catalog:** Register components + action definitions with JSON schemas + SwiftUI render closures.
- **Render tree:** A normalized element graph (`root` + `elements`) to enable incremental/streaming updates.
- **Streaming:** Apply JSONL ops like `set`, `merge`, `remove` against JSON Pointer paths (guardrailed diff instead of full re-renders).
- **Data binding:** Resolve JSON Pointer paths into a `DataDocument` for read/write bindings (e.g., `TextField`).
- **Actions:** Only allow catalog-defined actions with validated params (no arbitrary code).
- **Export:** Convert a validated render tree into a simple SwiftUI view (best-effort, limited component set).

**Playground app:** `JSONRenderPlayground`
- JSON editor + catalog inspector + live preview.
- Sample prompts + sample streams (recorded JSONL sessions).
- “Guardrails” panel showing schema validation failures and unknown components/actions.

## Codex story (agents, skills, worktrees)
**How Codex is the core accelerator:**
- Parallel agents/worktrees: `core-json`, `catalog+schema`, `swiftui-renderer`, `streaming-patches`, `json-pointer+binding`, `actions`, `exporter`, `playground-app`, `docs+demo-video`.
- Skill usage (practical + demoable): `$mobile-architecture` (module boundaries), `$xcodeproj-edit` (targets/SPM wiring), `$xcodebuild` (repeatable builds/tests), `$sim-control` (scripted demo capture), `$codex-hackathon-submission` (final submission text + checklist).

## Parallelization plan (what can run in parallel)
- **Core model:** `JSONValue`, normalized render tree, JSON Pointer parser/evaluator.
- **Catalog DSL:** component/action registration + schema validation layer.
- **SwiftUI renderer:** `AnyView` rendering, error fallbacks, theming.
- **Streaming engine:** JSONL decoder + patch applier + state diffing.
- **Exporter:** render-tree → SwiftUI code (limited components first).
- **Demo app + assets:** playground UX, sample catalogs, sample streams, demo script + README.

## Feasibility in remaining time (what is in / out)
**In (demo-ready MVP):**
- 6–10 components: `Text`, `VStack`, `HStack`, `Card`, `Badge`, `Divider`, `Button(action)`, `TextField(binding)`, optional `List`.
- 2–4 actions: `open_url` (stub), `log_event`, `set_data`, `submit`.
- Streaming patch playback (from bundled `.jsonl` files).
- A single polished end-to-end demo scenario (support dashboard or checkout form).

**Out (defer):**
- Full JSON Schema compliance and rich validation messages.
- Complex layout (grid), animations, virtualization/perf tuning.
- Real LLM integration inside the demo (rule risk: models must be open source; also API keys/network risk).

## Risks + mitigations
- **Scope creep (renderer + schema + exporter):** start with a tiny catalog + limited op set; exporter only for supported components.
- **SwiftUI dynamic rendering pitfalls:** normalize the tree and keep rendering side-effect-free; show invalid nodes as explicit “GuardrailErrorView”.
- **Hackathon open-source constraint (incl. models):** demo using prerecorded streams; optionally document how to connect an open-source model later without shipping one in MVP.
- **Demo stability:** ship a “demo mode” with deterministic streams and sample data; record on Simulator.

## Technical note (optional future)
If you want computed values / conditional rendering beyond simple JSON Pointer bindings, consider a tiny, sandboxed expression/interpreter layer (still gated by catalog + schema). Useful references from Bitrig on “Swift interpreting in Swift”:
- [Swift interpreter](https://bitrig.com/blog/swift-interpreter)
- [Interpreter bytecode](https://bitrig.com/blog/interpreter-bytecode)
- [Interpreter expressions](https://bitrig.com/blog/interpreter-expressions)

## Scorecard (subjective)
**Winner: SwiftUI JSON Render**
- Impact: 4/5
- Codex App story: 5/5
- Creative use of skills: 4/5
- Demo & pitch: 4/5
- Total: 21/25 (average × 5)
- Parallelizability (bonus): 5/5

**Fallback (within 10%): Playground-only renderer**
- Same package + app, but **no streaming** and **no exporter**: paste JSON → validate → render → trigger actions.
- Total: 20/25

## Demo script (60–120s)
- **Hook:** “AI can draft UI, but free-form UI output is unsafe and unpredictable for native apps.”
- **Solution:** “SwiftUI JSON Render lets AI output a constrained JSON UI spec from a catalog, then renders it natively with guardrails.”
- **Live flow:** (1) choose catalog + data → (2) stream JSONL patches and watch the UI appear → (3) interact with bound fields + run a named action → export SwiftUI.
- **Codex moment:** “We built this with Codex via parallel agents: streaming engine, renderer, catalog schemas, and the demo app all in parallel worktrees.”
- **Close:** “It’s a safer contract for AI-generated or server-driven UI on iOS/macOS.”

## 3-minute pitch outline (no slides)
1. Problem + user: teams want AI-assisted UI, but need guardrails and deterministic rendering.
2. Walkthrough (3 steps): catalog + data → stream patches → interact/actions → export code.
3. Codex under the hood: how parallel agents/worktrees shipped the package + app fast.
4. Novelty: json-render.dev concept, but native SwiftUI + streaming + binding + action sandbox.
5. Impact + next: richer catalog, better exporter, optional open-source model adapter, adoption as an SPM package.

## Q/A prep
- What parts were built during the hackathon vs reused?
- What makes this “guardrailed” (schema validation + named actions + bounded catalog)?
- How is this different from “just a JSON viewer” or “SDUI”?
- Why no live model in the demo (open-source model + reliability constraints)?
- If continued, what’s next (bigger catalog, testing harness, exporter quality)?

## Compliance checklist
- New work only (repo created during hackathon).
- Open source license added (MIT/Apache-2.0).
- Demo shows working product (no slides/Figma).
- No disallowed categories (medical/mental health/etc).
- One-minute demo video link ready (Loom/YouTube).

## Assumptions (TODO confirm)
- Team: 1–3 people; comfortable with SwiftUI + SPM.
- Platforms: iOS 17+ (Simulator) and/or macOS 14+.
- Demo uses prerecorded JSONL streams (no external keys/network).

## Next steps for build
1. Scaffold `JSONRenderSwiftUI` package + `JSONRenderPlayground` app target.
2. Implement render tree + catalog registration + schema validation.
3. Build SwiftUI renderer + guardrail error surfaces + theme.
4. Add JSON Pointer binding + a few safe actions.
5. Implement streaming patch playback + sample `.jsonl` streams.
6. Add minimal SwiftUI exporter for supported components.
7. Record demo video + polish README and submission text.
