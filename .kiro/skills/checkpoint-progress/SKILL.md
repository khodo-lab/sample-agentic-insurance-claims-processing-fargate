---
name: checkpoint-progress
description: Create a lightweight checkpoint of current task progress to prevent context loss.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Checkpoint Progress

Create a lightweight checkpoint of current task progress to prevent context loss.

## When to Run

- Automatically at the end of every `implement-task` sub-phase.
- Every 5 successful turns during active implementation.
- Before running high-risk or long-running shell commands.

## Workflow

1. Get current git state: `git status --short`, `git branch --show-current`, `git log -n 1 --oneline`.
2. Identify active specification: `ls -t docs/specs/In-Progress/ | head -n 1`.
3. Extract last completed task: `grep -E "\[x\]" <active-spec> | tail -n 1`.
4. Write checkpoint to `.kiro/context/checkpoint.md`:
   - **Timestamp**: Current ISO date/time
   - **Branch**: Current branch
   - **Last Commit**: Short SHA + Message
   - **Active Spec**: Path to the spec file
   - **Last Task**: The task ID and description
   - **Immediate Next Step**: Based on the next unchecked task in the spec
5. **Pit of Success**: If uncommitted changes exist, remind The Team: "Checkpoint saved. You have uncommitted changes — consider a 'WIP' commit if you're at a stable point."

## Rules

- **Silent & Fast**: Do not ask for confirmation. Just do it.
- **Overwrite**: Always overwrite `.kiro/context/checkpoint.md`. It's a "rolling latest" for recovery.
- **Reference**: `session-resume` will check this file if the handoff is stale.
- Refer to the user as "The Team".
