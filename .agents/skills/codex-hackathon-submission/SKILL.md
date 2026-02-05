---
name: codex-hackathon-submission
description: Guide drafting and refining Codex hackathon submissions, including project narrative, demo video summary, repository readiness, Codex feedback, model/agent disclosure, and team social handles. Use when preparing or improving a hackathon submission form (e.g., the OpenAI Codex Hackathon on Cerebral Valley) or when assembling required submission inputs under a deadline.
---

# Codex Hackathon Submission

## Overview
Provide a concise, compelling submission by gathering the right inputs, shaping a clear project narrative, and ensuring all required links and disclosures are ready.

## Workflow
1. Confirm deadline and constraints.
Restate the deadline as an absolute date and time with timezone. For this hackathon, the stated deadline is **Thursday, February 5, 2026 at 4:00 PM PT**. If the user gives a relative date (e.g., “Thursday 4pm”), convert it to a specific date and confirm. Note any submission rules or required fields from the live form.

2. Gather inputs.
Collect the core submission data before drafting. If anything is missing, mark it as TODO and ask for it explicitly.
- Never invent links, handles, or emails. Use TODOs until confirmed.
- Team members: names, handles, emails, and social links.
- Project: name, one-line tagline, problem, target user, solution, differentiator, status.
- Links: public repo URL, demo video URL, live demo URL if any.
- AI details: models used, number of agents, key automations.
- Codex feedback: what worked, what didn’t, bugs, feature requests.
- Keep each narrative field to a few sentences unless the user specifies otherwise.

3. Time check and scope.
Confirm the time remaining until the deadline and trim any optional outputs if time is short. Prioritize the submission form fields over extras.

4. Draft project description.
Produce a short, high-signal description. Aim for 4–7 sentences that answer: What problem? For whom? What you built? Why it’s better? How AI/Codex was used? What the demo proves? Keep concrete nouns and verbs; avoid buzzwords.

5. Prepare the demo video summary.
Ensure the written description matches the demo. If the demo is not ready, create a placeholder script and checklist and mark the link as TODO.

6. Write Codex feedback and model/agent disclosure.
Be specific about friction points or wins. Include model names and agent count exactly as used. Keep a neutral, constructive tone. Use this structure:
- Most valuable help.
- Biggest friction.
- One bug.
- One feature request.

7. Final polish and submission readiness.
Verify links are public and working. Ensure the repo has a clean README and quickstart. Confirm team social handles are accurate. Do a final pass for clarity and brevity. Repo readiness checklist:
- Setup steps are complete.
- Demo or run steps are explicit.
- License exists (if required by rules).
- Tests or a basic verification step exists.
- `.env.example` exists if any env vars are needed.

## If The Project Is Not Chosen Yet
Run a short discovery:
- Available time and skill mix.
- Target user and problem space.
- What can be demoed in 60–120 seconds.
- What would make this distinct from common hackathon demos.
Propose 2–3 project directions with a clear demo story and low integration risk. Pick the one with the clearest demo and smallest unknowns.

## Output Expectations
Deliver a compact “submission packet” response:
- Assumptions list (only if any were made).
- TODO list for missing inputs.
- Final draft text for each submission field (kept to a few sentences).
- Codex feedback and model/agent disclosure.
- Link checklist with pass/fail status.

## Reference Files
- `references/form-fields.md` for known submission fields and content guidance.
- `references/demo-video-outline.md` for a short demo narrative outline.
- `references/submission-template.md` for a fill-in template and final checklist.
