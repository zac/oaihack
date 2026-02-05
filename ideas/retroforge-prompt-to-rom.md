# RetroForge: Prompt-to-ROM for a Retro Target

## One-line summary
A tiny “retro dev kit” that ships a playable retro build (ROM/COM) in one command — and a repeatable Codex workflow that turns an idea into an esoteric-platform release in hours, not weeks.

## Target user + pain point
- **User:** indie devs, retrocomputing hobbyists, and game-jam folks who want to ship to weird/old targets (Game Boy, DOS, etc.)
- **Pain:** retro toolchains are arcane + slow; most projects never start because setup + iteration costs are too high

## Deadline + constraints (Codex Hackathon)
- **Submission deadline:** **Thursday, February 5, 2026 at 4:00 PM PT**
- **Rules:** open source only + new work only; team size ≤ 4; demo must be a working product (no slides); avoid disallowed “anti-project” categories
- **Judging weights:** Impact 25%, Codex App story 25%, Creative use of skills 25%, Demo & pitch 25%

## Idea candidates (pick one target for MVP)
### A) Game Boy “Prompt-to-ROM”
- **Build:** RGBDS/GBDK-style toolchain + emulator runner + one small “microgame” (e.g., endless runner)
- **Why it fits:** strong “this would take forever normally” vibe; very demo-friendly; output is a real ROM artifact

### B) DOSBox “Prompt-to-COM”
- **Build:** 16-bit `.com` or `.exe` VGA/text-mode game + DOSBox runner + capture script
- **Why it fits:** simplest distribution and fast feedback loop; easy to show on a modern Mac

### C) CHIP-8 “Prompt-to-Cartridge”
- **Build:** CHIP-8 bytecode game + minimal emulator UI + “shareable cartridge” file
- **Why it fits:** lowest risk + fastest; slightly less “wow” than GB/DOS but extremely stable demo

## Winner + fallback (scorecard)
**Winner: Game Boy “Prompt-to-ROM”**
- Impact: 4/5
- Codex App story: 5/5
- Creative use of skills: 4/5
- Demo & pitch: 4/5
- Total: 21/25 (average × 5)
- Parallelizability (bonus): 4/5

**Fallback (within 10%): DOSBox “Prompt-to-COM”**
- Impact: 3/5
- Codex App story: 5/5
- Creative use of skills: 4/5
- Demo & pitch: 4/5
- Total: 20/25
- Parallelizability (bonus): 4/5

## Demo flow (3 steps)
1. Pick a target (“Game Boy”) + choose a tiny game spec (one sentence + 2 constraints).
2. Run `make run` (or `./retroforge run`) to build the ROM and auto-launch the emulator.
3. Play 10 seconds, then show the produced artifact (`.gb` ROM) + a generated release bundle (README + controls + screenshots).

## Codex story (agents, skills, worktrees)
**How Codex is the core accelerator:**
- Split into parallel agents/worktrees: `toolchain`, `game-loop`, `gfx+audio`, `build+release`, `docs+demo`.
- Codex handles the “unfun cliff”: toolchain setup, project scaffolding, build scripts, emulator runner, and tight iteration loops.
- Skills usage: use skills for architecture decisions, build automation, test scaffolding, docs, and submission polish (plus a small custom “retro-toolchain” skill if time).

## Parallelization plan (what can run in parallel)
- Toolchain + `make run` + emulator/capture.
- Microgame engine (input, update loop, collision, score).
- Content: tiles/sprites, palette, simple SFX/music (all original).
- Release packaging: README, controls, screenshots, build instructions, license.
- Demo script + 1-minute demo video checklist.

## Feasibility in remaining time (what is in / out)
**In (demo-ready MVP):**
- One target platform (Game Boy *or* DOS).
- One microgame with 1 mechanic + 1 loop + simple scoring.
- One-command build + run + a deterministic “demo mode”.
- A “release” folder with the built artifact + docs + screenshots.

**Out (defer):**
- Multiple targets in the same repo.
- Level editor, save files, or advanced audio.
- Live “AI inside the app” integration (risk: reliability + rules interpretation + keys/network).

## Risks + mitigations
- **Toolchain friction:** pick the most turnkey target; pin versions; document exact install steps; ship a “demo mode”.
- **Demo instability:** use deterministic seed + prerecorded capture plan; keep gameplay trivial.
- **Open-source compliance:** choose OSI-licensed toolchain + emulator; include licenses/attribution; use only original or properly-licensed assets.

## Demo script (60–120s)
- **Hook:** “Retro targets are where good ideas go to die — toolchains are brutal, so most projects never ship.”
- **Solution:** “RetroForge is a one-command dev kit that outputs a real retro artifact you can play immediately.”
- **Live flow:** (1) pick a tiny spec → (2) `make run` builds + boots the emulator → (3) play 10 seconds + show the `.gb`/`.com` output in the release bundle.
- **Codex moment:** “We built this with Codex via parallel agents: toolchain, game loop, content, and release packaging shipped in parallel worktrees.”
- **Close:** “If you can describe it, you can ship it — even to weird platforms.”

## 3-minute pitch outline (no slides)
1. Problem + user: retro is hard; setup cost kills creativity.
2. Walkthrough (3 steps): spec → build/run → artifact + release.
3. Codex under the hood: parallel agents/worktrees; what Codex generated/refactored/debugged.
4. Novelty: not a normal app — the output target is the product; Codex compresses “toolchain archaeology”.
5. Impact + next: add more targets; shareable “prompt packs” for genres; community templates.

## Q/A prep
- What parts were built during the hackathon vs reused (toolchains are dependencies; game + harness are new)?
- What makes this more than “a small game” (the repeatable pipeline + release artifact)?
- How did Codex materially accelerate (parallel worktrees + end-to-end automation)?
- How do you ensure license compliance (only OSI deps + original assets + attribution)?

## Compliance checklist
- New work only (repo created during hackathon).
- Open source license added (MIT/Apache-2.0).
- Demo shows working product (no slides/Figma).
- No disallowed categories (medical/mental health/etc).
- One-minute demo video link ready (Loom/YouTube).

## Assumptions (TODO confirm)
- Team size: 1–2 people.
- Demo target: 60–120s live run + 1-minute recorded demo video.
- Platform choice: Game Boy ROM (preferred) or DOSBox executable (fallback).

## Next steps for build
1. Choose target (Game Boy vs DOS) and lock toolchain.
2. Scaffold build + `make run` + deterministic demo mode.
3. Implement microgame loop + input + scoring.
4. Add minimal art/audio + credits + license/attribution.
5. Record the 1-minute demo video and polish README + submission text.

