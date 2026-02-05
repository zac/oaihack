---
name: codex-hackathon-ideation
description: Guide ideation, concept selection, and demo storytelling for the OpenAI Codex Hackathon. Use when choosing a project idea, shaping a narrative, or preparing a judged-aligned demo/pitch that satisfies hackathon rules, judging criteria, and submission requirements.
---

# Codex Hackathon Ideation

## Overview
Generate and select project ideas that fit the Codex Hackathon problem statement, avoid disallowed categories, and optimize for the judging rubric and demo-first evaluation.

## Workflow
1. Confirm constraints and deadline.
State the deadline as an absolute date and time with timezone. For this event, submissions are due **Thursday, February 5, 2026 at 4:00 PM PT**. Restate the hackathon rules and judging criteria before ideation, summarizing from `references/requirements-and-judging.md` (avoid long verbatim blocks).

2. Gather inputs.
Collect what is known and mark unknowns as TODO.
- Team size and roles.
- Available build time and technical stack.
- Target user or domain of interest.
- Demo length targets and capture method.
- Any must-use features or constraints.

3. Time check and scope.
Confirm the time remaining until the deadline and trim optional outputs if time is short. Prioritize a single demoable flow.

4. Refine the user-initiated idea (default path).
Assume the user starts with an idea. Tighten it into a demoable scope for the remaining time. Remove risky integrations, reduce surface area, and lock to a single crisp end-to-end flow. Prefer offline or demo-safe dependencies and avoid new external approvals or API keys. Ensure it clearly showcases Codex as the core accelerator with skills and agents.

5. If no idea is provided, generate 3–5 idea candidates.
Each idea must explicitly show how Codex enables the build and accelerates developer workflows. Avoid banned project types. For each idea, include:
- One-line summary.
- Target user and pain point.
- Core workflow demo in 3 steps.
- Codex involvement and skills usage.
- Why it is novel and demoable in 60–120 seconds.

6. Score and select.
Evaluate each idea against the rubric: Impact, Codex App usage, Creative use of Skills, Demo & Pitch. Apply the rubric weights from `references/idea-scorecard.md` and show the numbers. Also evaluate parallelizability: how well the work can be split across multiple Codex agents and worktrees with a harness. Prefer ideas that:
- Show an end-to-end Codex story with parallel agents and worktrees.
- Demonstrate non-technical technical work (docs, refactors, migrations, QA workflows).
- Are easy to demo live without slides.
- Can be decomposed into parallel tasks with clear contracts (e.g., independent modules, data prep, test generation, UI surfaces).
Document the winner and one fallback. Pivot to the fallback if the winner has more than two critical unknowns to validate. See `references/idea-scorecard.md`.

7. Craft the story.
Produce a narrative aligned to judging and demo-first expectations.
- Problem statement fit.
- What the product does and for whom.
- How Codex was used under the hood.
- What the demo proves in a single flow.
- Expected impact if continued.
Use `references/pitch-and-demo.md` for the 60–120s demo script and 3-minute pitch outline.

8. Curate the idea to file.
Create or update a markdown file in `ideas/` at the repo root. File name: kebab-case slug of the idea (e.g., `ideas/agentic-migration-helper.md`). Include the sections below and keep it to one page.
- Title
- One-line summary
- Target user + pain point
- Demo flow (3 steps)
- Codex story (agents, skills, worktrees)
- Parallelization plan (what can run in parallel, harness idea)
- Feasibility in remaining time (what is in, what is out)
- Risks + mitigations
- Next steps for build

9. Prep for submission and judging.
Ensure the idea does not violate open source, new work only, or banned project rules. Ensure the demo is a working product, not a presentation. Ensure the submission includes a 1-minute demo video link. See `references/requirements-and-judging.md`.

## Output Expectations
Deliver a concise bundle:
- Top idea with one-line summary and user value.
- Demo flow in 3 steps.
- Codex usage narrative with skills/agents.
- 60–120 second demo script.
- 3-minute pitch outline and Q/A prep.
- Compliance checklist with rules and submission items.
- Curated idea file saved under `ideas/` in the repo root.

If time is short, deliver a minimum bundle:
- Top idea with one-line summary.
- Demo flow in 3 steps.
- 60–120 second demo script.
- Compliance checklist.

Include an assumptions list if any assumptions were made.

## Reference Files
- `references/requirements-and-judging.md` for rules, judging rubric, and submission requirements.
- `references/idea-scorecard.md` for rubric-weighted scoring.
- `references/pitch-and-demo.md` for demo and pitch templates.
