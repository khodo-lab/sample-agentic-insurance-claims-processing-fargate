---
name: route
description: Detect user intent and automatically chain to the correct skill or tool.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Route

Detect user intent and automatically chain to the correct skill or tool.

## Intent Map

| User Says (patterns) | Route To | Notes |
|---|---|---|
| "implement", "build", "code", "next task", "start work" | `implement-and-review-loop` | Always chain to the loop |
| "checkpoint", "save current" | `checkpoint-progress` | Lightweight state save |
| "handoff", "end session", "wrap up" | `session-handoff` | Full state save + auto-memory |
| "resume", "where were we", "load context" | `session-resume` | Includes State Drift Audit |
| "file issue", "create issue" | `gh issue create` | **Deterministic Action Gate**: Just file it |
| "review", "check my code" | `review-code` | Full multi-agent review |
| "spec", "design", "plan a feature" | `create-spec` | Full pipeline |
| "ADR", "record decision" | `create-adr` | Record architectural decision |
| "push", "PR", "pull request" | `push-and-mr` | Commit, push, create PR |
| "remember this", "save learning" | `auto-memory` | Persist a learning |
| "backlog", "prioritize", "sprint planning" | `prioritize-backlog` | Dual-agent backlog prioritization |
| "deploy", "push to ECR", "rollout" | `build-and-deploy` | Manual deploy |
| "verify deploy", "validate" | `validate-deployment` | Post-deploy verification |
| "security scan", "secrets scan" | `security-scan` | Scan for credentials |
| "simplify", "clean up", "refactor for clarity" | `simplify` | Runs automatically as Phase 1.5 of implement-and-review-loop |
| "research", "compare approaches", "what are my options" | `background-research` | Pre-build research |

## Workflow Rules

1. **Deterministic Action Gate**: When the user says "file/create" an issue, call `gh issue create` immediately. Do not summarize or ask for confirmation first.
2. **Implicit Chaining**:
   - After TDD green phase in `implement-and-review-loop`, run `simplify` (Phase 1.5).
   - At the end of `implement-task` sub-phases, run `checkpoint-progress`.
   - At the end of `session-handoff`, run `auto-memory`.
3. **Pit of Success**: If a user is about to make a risky change without a checkpoint, offer to run `checkpoint-progress` first.

## Rules

- Don't over-route. If it's just Q&A, answer directly.
- When routing, announce the destination: "Routing to `session-handoff` — wrapping up."
- Refer to the user as "The Team".
