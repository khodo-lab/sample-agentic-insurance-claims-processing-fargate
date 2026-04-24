---
name: session-handoff
description: Generate and commit a session handoff to sync state across machines.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Session Handoff

Generate and commit a session handoff document to ensure seamless resumption across machines.

## Workflow

0. **Pre-flight check**: Run `git status` and search for unchecked tasks in `docs/specs/In-Progress/`.
1. **Check Git state**: Get branch, status, and last 5 commits.
2. **Scan conversation history**: Identify tasks accomplished this session.
3. **ADR Audit**: Scan for ADR-worthy choices. Run `create-adr` and commit if needed.
4. **Write Handoff**: Overwrite `.kiro/context/session-handoff.md`.
   - Include **Machine Metadata** (OS, Hostname) in the "CURRENT STATE" section.
5. **Update `CHANGELOG.md`** if it exists: Prepend the session summary.
6. **Cross-Machine Sync**:
   - `git add .kiro/context/session-handoff.md .kiro/steering/memory.md`
   - `git commit -m "chore: session handoff $(date +%Y-%m-%d)"`
   - **MANDATORY**: Remind The Team: "Handoff committed. **Run 'git push' now** to sync this state to your other machine."
7. **Automatic Chain**: Immediately run `auto-memory` skill.
8. **Cleanup**: Delete `.kiro/context/checkpoint.md` if it exists.

## Required Sections

- **⚠️ BEFORE RESUMING**: Blockers (credentials, kubectl config, Ollama model status, etc.).
- **IMMEDIATE NEXT STEPS**: Numbered list.
- **CURRENT STATE**: Machine (OS/Host), Branch, Clean/Dirty, Last Commit.
- **WHAT WE DID THIS SESSION**: Completed tasks, bugs fixed.
- **MEMORY ENTRIES TO ADD**: Explicit list for `auto-memory`.

## Rules

- **Sync is King**: Always commit the handoff. It's the only way to ensure the next machine is "hot" on pull.
- Use `fs_write` for all Markdown updates to avoid shell-escape issues.
- Refer to the user as "The Team".
