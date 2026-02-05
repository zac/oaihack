---
name: codex-devlog
description: Create and maintain per-session developer log entries that document how Codex and the Codex app accelerated development. Use when asked to write a Codex usage log, create a devlog entry after a session, summarize acceleration impact, or maintain `codex-log/` markdown files with timestamps and session stats.
---

# Codex Devlog

## Overview
Create a concise, factual devlog entry after a Codex session to capture what was done, what Codex accelerated, and key session stats. Store each entry as a standalone markdown file in `codex-log/` at the repo root (or the current workspace root if no repo context is provided).

## Workflow
1. Gather session metadata.
- Local timestamp and timezone.
- Workspace path and repo name.
- Git branch and status (clean/dirty).
- Primary goal for the session.
- Tools used (terminal, apply_patch, web, tests, etc.).
- Outputs produced (files, patches, artifacts).
- Any tests run (or explicitly note not run).
- Optional session logs: if present, read `~/.codex/sessions/YYYY/MM/DD` for the relevant date and summarize entries that match the workspace path (e.g., include `oaihack`).
2. Create the log directory if missing.
- Ensure `codex-log/` exists at the repo/workspace root.
3. Create the log file.
- Multiple entries per day are expected. Always create a new file per session; never overwrite an existing entry.
- File name: `codex-log/YYYY-MM-DD_HHMM-<slug>.md` using local time.
- Use a short slug derived from the session goal (lowercase, hyphenated). Use `session` if unclear.
- If a file with the same name already exists (same minute), append a numeric suffix like `-2`, `-3`, etc., or include seconds.
4. Fill in the log template.
- Start from `assets/devlog-template.md`.
- Replace placeholders; do not fabricate unknown details. Use `unknown` or `n/a` if needed.
5. Emphasize acceleration impact.
- Describe what Codex handled end-to-end, what it simplified, and any time saved (estimate is fine if labeled).

## Data Sources
When you need details, prefer lightweight, local commands:
- `date` for timestamp.
- `pwd` for workspace path.
- `git rev-parse --show-toplevel` for repo root.
- `git rev-parse --abbrev-ref HEAD` for branch.
- `git status -sb` and `git diff --stat` for status and touched files.
- `ls ~/.codex/sessions/YYYY/MM/DD` for session logs on a given date.

## Output Guidelines
- Keep the entry short and scannable.
- Focus on how Codex accelerated development, not a full narrative.
- Note any important decisions made by the user vs. Codex.
- Avoid sensitive data unless the user explicitly asks for it.

## Assets
- `assets/devlog-template.md`: Base template for new entries.
