---
name: implement-and-review-loop
description: Orchestrate an automated implement → review → fix cycle for tasks in a spec. Chains the implement-task and review-code skills in a loop until code is clean.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Implement and Review Loop

Orchestrate an automated implement → review → fix cycle for tasks in a spec. Chains the `implement-task` and `review-code` skills in a loop until code is clean.

**⚠️ THIS IS THE DEFAULT ENTRY POINT for implementation work.** When the user asks to "implement", "build", "code", or "next task", use THIS skill — not `implement-task` standalone.

## Input

Same as `implement-task`: a task number, "next task", or "implement all open tasks".
The spec is read from `docs/specs/In-Progress/`.

## Subagent Throttling

Max 4 concurrent subagents per invocation. Batch if more are needed.

## Process

### Phase 0: Write Tests First (TDD — Red Phase)

**⚠️ MANDATORY — DO NOT SKIP. Tests must be written BEFORE implementation code.**

For each task:
1. Read the spec for the component being implemented.
2. Write failing tests that define the expected behaviour:
   - **Python/FastAPI tasks**: add tests to `applications/insurance-claims-processing/tests/`
   - **LangGraph agent tasks**: add unit tests for graph nodes and state transitions
   - **Terraform tasks**: add `terraform plan` assertions or use `terratest` if available
3. Run the tests — they MUST fail (red). If they pass without implementation, the tests are wrong.
4. Commit the failing tests with message `test: #N — failing tests for {task}` before writing implementation.

**Minimum test coverage per task type:**
- New FastAPI endpoint: at least 1 happy path + 1 error case + 1 auth check
- New LangGraph node: at least 1 happy path + 1 error/edge case
- New Terraform resource: at least `terraform validate` + `terraform plan` passes
- New utility function: at least 1 happy path + 1 edge case

### Phase 1: Implement (Green Phase — delegate to `implement-task` in loop mode)

**⚠️ TELEMETRY: Log `{"type":"skill","skill":"implement-and-review-loop","status":"started"}` BEFORE doing anything else.**

**⚠️ AWS CREDENTIALS: Before any task that requires AWS CLI calls (ECR push, kubectl, terraform), run `aws sts get-caller-identity`. If it fails, STOP and tell The Team: "AWS credentials expired — re-authenticate before continuing."**

Run the `implement-task` skill with `mode: loop`:
1. Phases 1–5 execute normally.
2. Phase 6 (update spec) executes normally.
3. Phase 7 (present for approval) is **skipped** — control returns here instead.

### Phase 1.5: Simplify (delegate to `simplify` skill)

**Run after TDD green phase, before guard-rails and review.**

Run the `simplify` skill scoped to files modified in this task:
1. Scan for complexity signals (deep nesting, generic names, dead code, duplicated logic)
2. Apply one simplification at a time, run tests after each
3. All existing tests must pass without modification — behavior is frozen
4. Commit simplifications separately from implementation if substantial

Skip if: the implementation is already clean and a scan finds no signals. Log the skip.

### Phase 1.6: Verify Test Coverage

**⚠️ MANDATORY — DO NOT SKIP. Run guard-rails after every implementation, before review.**

Run the `guard-rails` skill:
1. All build gates must pass (hard fail blocks the loop).
2. All test gates must pass (hard fail blocks the loop).
3. New code coverage check — flag untested public functions.
4. Secrets scan — block if detected.
5. Branch check — block if on main.

### Phase 2: Review (delegate to `review-code` in loop mode)

**⚠️ MANDATORY — DO NOT SKIP THIS PHASE. Every implementation must be reviewed before committing.**

**⚠️ MUST USE PARALLEL REVIEW via `use_subagent`. Inline review is NOT acceptable unless subagents are confirmed unavailable.**

**⚠️ ALL 5 REVIEW AGENTS MUST RUN ON EVERY REVIEW — NO EXCEPTIONS.**

Run the `review-code` skill with `mode: loop`. Always execute the full 2-batch pattern:

**Batch 1 — invoke IN PARALLEL (3 subagents):**
- `review-security`
- `review-maintainability`
- `review-infrastructure`

**Wait for Batch 1 to complete, then:**

**Batch 2 — invoke IN PARALLEL (2 subagents):**
- `review-performance`
- `principal-pse`

Never skip any agent. Never merge batches into fewer than 5 agents. If a subagent fails, retry it once before proceeding.

### Phase 3: Fix (if actionable findings exist)

1. For each actionable finding (🔴 Agree + 🟡 Agree), apply the fix.
2. Re-run the relevant test suite(s).
3. If tests fail, feed the error back and retry the fix (max 2 retries per finding).

### Phase 4: Re-review (if fixes were applied)

1. Run a quick inline review on the fix diff only.
2. If new 🔴 or 🟡 findings emerge, loop back to Phase 3.
3. **Max 3 total review→fix iterations**. If still unresolved after 3 passes, present remaining findings to user.

### Phase 5: Present Final State

**STOP here.** Present to The Team:
- Summary of files created/modified
- Test count (total passing)
- Spec progress (X/Y tasks complete)
- Review iterations completed
- Any remaining findings that couldn't be auto-resolved
- Newly eligible tasks
- "Ready to commit, or do you want to review the changes manually?"

**After presenting, offer the full chain**: "Ready to build-deploy → push-and-mr → handoff?"

### Phase 6: Commit (only after approval)

**⚠️ TELEMETRY: Log `{"type":"skill","skill":"implement-and-review-loop","status":"completed"}` with duration and outcome BEFORE committing.**

1. Stage specific files (not `git add .`).
2. Commit with message:
   ```
   Implement Task X.Y: {Task Title}

   {Brief description}
   - Key changes as bullet points
   - Review: {N} findings fixed across {M} iterations
   ```

## Tiered Merge Gates

- **Non-critical tasks** (config, docs, minor features): The Team can approve from the Phase 5 summary alone.
- **Critical tasks** (Terraform/infrastructure, auth, LangGraph agent config, security): recommend full manual review before commit. Flag with "⚠️ Critical — manual review recommended".

A task is "critical" if it touches: Terraform/infrastructure, auth/RBAC, MongoDB schema, LangGraph agent config, IAM policies, or claims processing logic.

## Rules

- **ALWAYS write tests first (Phase 0)**. Red → Green → Refactor. Non-negotiable.
- **NEVER skip Phase 2 (review)**. Every task gets a code review. Non-negotiable.
- **When batching tasks**: implement one task → review → fix → commit → next task. Each task gets its own cycle.
- Max 3 review→fix iterations. Escalate to human after that.
- Never commit without user approval.
- Follow branching workflow in `.kiro/steering/branching.md`.
- Refer to the user as "The Team".
