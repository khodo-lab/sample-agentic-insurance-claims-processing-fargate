---
name: session-resume
description: Resume a previous working session by loading the latest context and auditing for state drift.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Session Resume

Resume a previous working session by loading the latest handoff context and auditing for state drift.

## Workflow

1. **Load Project Context**: Read steering files (`.kiro/steering/`), agent definitions (`.kiro/agents/`), and skill definitions.
2. **Find Latest Context**:
   - List files in `.kiro/context/` sorted by modification date.
   - Read the most recent of: `checkpoint.md` or `session-handoff.md`.
3. **State Drift Audit** (Critical):
   - Get current git state: `git status`, `git branch`, `git log -n 5 --oneline`.
   - Compare git state with the handoff doc:
     - Is the current branch different?
     - Are there commits newer than the handoff timestamp?
     - Are there untracked changes in `docs/`?
4. **Reconstruct Missing Context**:
   - If drift is detected, search for the most recent spec: `ls -t docs/specs/In-Progress/ docs/specs/Done/ | head -n 5`.
   - Read these specs to identify tasks completed since the handoff.
5. **Archive Check**:
   - Identify the work area from the handoff.
   - Scan the `## 📚 Archive Index` in `memory.md` for matching topics.
   - If the work area matches an archived topic not recently touched, note: "Before we start: the Archive Index has entries for [topic] in [archive file]. Worth a quick scan."
6. **Present Summary to The Team**:
   - **Context Source**: Handoff vs Checkpoint vs Reconstructed from Git.
   - **Where we left off**: Branch, phase, and detected state drift.
   - **What's next**: Top 3-5 items from the most recent progress.
   - **Blockers**: Any discrepancies found during audit.
   - **Archive heads-up**: Any relevant archived topics for the work area.
7. **Confirmation**: Ask: "Ready to pick up from here, The Team? Or do you want to pivot?"

## Rules

- **State Drift First**: Never trust a stale handoff. Proactively search for newer commits or spec updates.
- **PIT OF SUCCESS**: If the user is on a different branch than the handoff, ASK before switching.
- Refer to the user as "The Team".
