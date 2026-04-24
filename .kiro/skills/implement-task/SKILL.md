---
name: implement-task
description: Implement a specific task from the task plan, then verify documentation is current.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Implement Task

Implement a specific task from the task plan, then verify documentation is current.

## Mode

- **interactive** (default): Full workflow with human approval gates.
- **loop**: Called by `implement-and-review-loop`. Skips Phase 7 (present for approval) and returns control to the orchestrator after Phase 6. No commit in this mode.

## Input

The user provides a task number (e.g., "2.1", "3.4"), says "next task", or says "implement all open tasks".

## Process

### Phase 1: Validate and Select Task

1. Read the task plan from `docs/specs/In-Progress/` (most recent spec file with a task table).
2. If user said "next task", find the first eligible task (status `[ ]` with all prerequisites `[x]`).
3. If user said "implement all open tasks", find ALL eligible tasks and implement them sequentially.
4. If user gave a task number, validate: not already `[x]`, warn if `[~]`, check prerequisites.
5. Read task details: objective, files, instructions, definition of done.

### Phase 2: Mark In Progress

Update the task status from `[ ]` to `[~]` in the task plan.

### Phase 3: Git Branch Check

1. Check current branch with `git branch`.
2. If on `main`, remind user to create a feature branch per `.kiro/steering/branching.md`.
3. If already on a feature branch, continue. Do NOT create per-task branches.

### Phase 4: Implementation

⚠️ **Before writing any code**, read the existing patterns in the target area:
- For Python/FastAPI: check existing route handlers and service patterns in `applications/insurance-claims-processing/src/`
- For LangGraph agents: check existing agent patterns in `langgraph_*_agent.py` files
- For Terraform: check existing resource patterns in `infrastructure/terraform/`
- For Kubernetes: check existing manifest patterns in `infrastructure/kubernetes/`
- **Never hardcode** MongoDB URIs, Redis URLs, model names, or credentials — use env vars
- **Never hardcode** Kubernetes namespace — use `insurance-claims` from config

For each component of the task:
1. Write the implementation.
2. Write tests alongside the implementation.
3. Include tests for: happy path, configuration/parameterization, error conditions, edge cases.

### Phase 5: Verify Build

```bash
# Python syntax + tests (if Python files changed)
cd applications/insurance-claims-processing
python -m py_compile src/*.py
python -m pytest tests/ -v --tb=short

# Terraform validate (if Terraform files changed)
cd infrastructure/terraform && terraform validate

# Kubernetes dry-run (if K8s files changed)
kubectl apply --dry-run=client -f infrastructure/kubernetes/ -n insurance-claims
```

### Phase 6: Update Spec and Documentation

After implementation passes all tests:
1. Update task status from `[~]` to `[x]` in the task plan.
2. Update the progress summary counts.
3. Update the "Eligible Tasks" section with newly unlocked tasks.
4. Check if `README.md` needs updating.

### Phase 7: Present for Approval (interactive mode only)

**STOP before committing.** Present to the user:
- Summary of files created/modified
- Test count (total passing)
- Spec progress (X/Y tasks complete)
- Newly eligible tasks
- "Ready to commit, or would you like to run a code review first?"

In **loop mode**, skip this phase entirely.

### Phase 8: Commit (interactive mode only)

1. Stage specific files (not `git add .`).
2. Commit with message:
   ```
   Implement Task X.Y: {Task Title}

   {Brief description}
   - Key changes as bullet points
   ```

## Rules

- Follow branching workflow in `.kiro/steering/branching.md`.
- Match existing project patterns from `.kiro/steering/`.
- Keep changes minimal — only what the task requires.
- Never commit secrets or credentials.
- All config must be in env vars or Kubernetes ConfigMaps — never hardcoded.
- Always update the spec after completing a task.
- Refer to the user as "The Team".
