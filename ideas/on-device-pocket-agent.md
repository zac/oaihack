# On-Device Pocket Agent (iOS)

## One-line summary
A fully on-device iOS personal assistant powered by an open-source LLM (via MLX) that plans and executes **tool calls** (Reminders, Calendar, optional Weather), with **approval per tool call**, an audit log, and local memory.

## Target user + pain point
- **User:** privacy-focused power users / devs / founders who want their phone to run multi-step tasks for them
- **Pain:** cloud assistants are hard to trust (privacy), hard to control (surprising actions), and hard to audit (what happened and why)

## Demo flow (3 steps)
1. Ask: “Schedule dentist next Tue 2pm, add ‘buy coffee beans’ Friday, and if it’s raining Friday remind me to bring an umbrella.”
2. The agent proposes tool calls (each as a card). You **approve/deny each tool call**.
3. The agent executes approved actions via iOS APIs, shows results, and saves a short memory note (e.g., preferred calendars/lists).

## Codex story (agents, skills, worktrees)
**How Codex is the core accelerator:**
- Split into parallel worktrees/agents: `chat-ui`, `tool-protocol`, `reminders-tool`, `calendar-tool`, `weather-tool`, `mlx-llm`, `memory-store`, `demo-docs`.
- Use skills for “non-technical technical work”: architecture, Xcode wiring, test scaffolds, demo script, and README polish.

## Parallelization plan (what can run in parallel)
- Chat UI (SwiftUI) + tool-call approval cards + execution log.
- Tool-call protocol: schema, validation, error handling, retries, redaction.
- iOS tools: Reminders + Calendar (EventKit), optional Weather tool.
- On-device LLM: MLX integration + prompt format + constrained JSON/tool-call output.
- Agent loop: plan → approve per call → execute → summarize → store memory.
- Docs + demo assets: sample prompts, screenshots/video checklist, pitch text.

## Feasibility in remaining time (what is in / out)
**In (MVP for demo):**
- Chat UI with tool-call cards + per-call approval.
- `reminders` and `calendar` tool calls via EventKit (create + list).
- Local memory (JSON/SQLite) + “What I remember” screen (lists, calendars, defaults).
- On-device LLM that emits **constrained tool calls** (small model, quantized, strict schema).

**Out (defer):**
- Broad iOS surface area (location, Apple Music, opening arbitrary apps, etc.).
- Complex autonomy (background agents, long-running jobs).
- “Ask anything” web browsing or knowledge features.
- Weather as a hard dependency if WeatherKit entitlements/licensing interpretation is unclear.

## Risks + mitigations
- **Hackathon rule: open source only (incl. models).** Mitigate by choosing an open-source-licensed model/weights for on-device inference and documenting license + download steps.
- **iOS permissions (Calendar/Reminders):** Mitigate with per-tool-call approval + clear audit log; demo on Simulator with permissions pre-granted.
- **On-device model reliability/perf:** Mitigate by constraining outputs (JSON tool calls only), using a smaller quantized model, and having a “demo mode” fallback prompt set.
- **Weather tool risk (WeatherKit + network + entitlements):** Make weather optional; ship a stubbed forecast provider for the demo if needed.

## Scorecard (subjective)
- Impact: 4/5
- Codex App story: 5/5
- Creative use of skills: 4/5
- Demo & pitch: 4/5
- Total: 21/25 (average × 5)
- Parallelizability (bonus): 5/5

## Demo script (60–120s)
- **Hook:** “I want a personal assistant that runs *on my phone*, not in the cloud—and never takes actions I didn’t approve.”
- **Solution:** “This on-device agent plans tool calls and asks permission *per action*.”
- **Live flow:** (1) ask multi-step task (incl. weather condition) → (2) approve/deny each tool call → (3) show Reminders/Calendar populated + audit log + memory update.
- **Codex moment:** “We built this with Codex using parallel agents/worktrees to ship MLX inference, tool adapters, approval UI, and memory fast.”
- **Close:** “Private autonomy with guardrails: on-device, inspectable, and extensible.”

## 3-minute pitch outline
1. Problem + user: privacy + trust + control gaps in current assistants.
2. Walkthrough (3 steps): request → approve per tool call → execute + audit + memory.
3. Codex under the hood: parallel agents/worktrees; what Codex generated/refactored/tested.
4. Novelty: on-device LLM + permissioned tools + per-action approval and audit trail.
5. Impact + next: expand tool surface safely; shareable “agent recipes”; personal preference memory.

## Q/A prep
- What was built during the hackathon vs reused?
- What permissions does it need and how do you prevent unsafe actions?
- How is it not “just a chatbot”?
- What model/weights are you using and what’s the license?
- If continued: what are the first 3 additional tools users would demand?

## Compliance checklist
- New work only (repo created during hackathon).
- Open source license added (MIT/Apache-2.0).
- Demo shows working product (no slides/Figma).
- If using a model: model weights + runtime are under an approved open-source license; document license + how to run.
- One-minute demo video link ready (Loom/YouTube).

## Assumptions (TODO confirm)
- Team size: 1–2 people, SwiftUI + iOS 17+.
- Demo target: 60–120s live demo, recorded on Simulator.
- “Brain”: on-device open-source LLM via MLX (small, quantized), emitting constrained tool calls.

## Next steps for build
1. Create Xcode project + SwiftUI chat scaffold.
2. Define tool-call schema + approval UI + audit log.
3. Add EventKit-backed Reminders + Calendar tool adapters.
4. Add local memory store + default selection (calendar/list) UX.
5. Integrate MLXSwift inference + “tool-call only” prompting and validation.
