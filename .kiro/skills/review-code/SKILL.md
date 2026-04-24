---
name: review-code
description: Run a multi-faceted code review on uncommitted changes using specialized review subagents.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Review Code

Run a multi-faceted code review on uncommitted changes using specialized review subagents.

## Mode

- **interactive** (default): Full workflow with human-facing presentation. Used when running standalone.
- **loop**: Called by `implement-and-review-loop`. Returns structured findings instead of presenting a table. Skips "Want me to fix?" prompt — the orchestrator decides.

## Finding Schema

See [Finding Schema](references/FINDING-SCHEMA.md) for the typed contract.

## Subagent Throttling

Max 4 subagents per invocation. This skill uses 5 review subagents. **Always run all 5 in 2 batches — never skip any agent:**
1. **Batch 1 (3 parallel):** `review-security`, `review-maintainability`, `review-infrastructure`
2. **Batch 2 (2):** `review-performance`, `principal-pse`
3. **Merge:** Combine all findings from both batches into a single assessment table.

**⚠️ ALL 5 AGENTS ARE MANDATORY ON EVERY REVIEW. Skipping any agent is a compliance violation. If a subagent fails, retry it once before proceeding.**

## Workflow

### Step 1: Gather Changes

1. Run `git diff HEAD --name-only` and `git ls-files --others --exclude-standard` to identify changed files.
2. Separate files into: code files (substantive) vs. documentation-only files.
3. If only documentation changed, skip the full review — do a quick inline check instead.

### Step 2: Read All Code Files

Read the full content of every substantive changed/new file. This is critical — subagents need the actual code, not just file names.

### Step 3: Invoke Review Subagents

**Batch 1 — invoke IN PARALLEL (3 subagents):**
- `review-security` — auth, input validation, secrets, IAM, LLM prompt injection
- `review-maintainability` — code organization, naming, duplication, DRY, configuration
- `review-infrastructure` — Terraform patterns, Kubernetes manifests, monitoring, cost

**Wait for Batch 1 to complete, then:**

**Batch 2 — invoke IN PARALLEL (2 subagents):**
- `review-performance` — async patterns, MongoDB queries, LangGraph latency, Ollama throughput
- `principal-pse` — architecture decisions, coupling risks, simplicity, long-term design concerns

**If changes include UI files (`src/templates/**` or `src/static/**`):** Add `review-design` to Batch 2 (max 3 in Batch 2 when UI is included).

**⚠️ CRITICAL — Subagent source code delivery:**
Subagents **cannot read files**. The ONLY way to get code to a subagent is to **embed the full source code directly in the `query` string**:
- Read every changed file with `fs_read`
- Paste the full file contents into the `query` parameter as fenced code blocks
- Include the file path as a label above each code block

### Step 4: Assess Findings

For each finding, state:
- **Agree** — valid issue, should fix
- **Disagree** — explain why (e.g., "by design", "tracked in future task")
- **Defer** — valid but belongs in a later phase, reference the task number

### Step 5: Present to User

**Interactive mode:** Present findings as a summary table:

```
| # | Severity | File | Issue | Assessment |
|---|----------|------|-------|------------|
| 1 | 🔴 | web_interface.py | Description | Agree — should fix |
| 2 | 🟡 | langgraph_fraud_agent.py | Description | Defer to Task X.Y |
```

End with:
- Count by severity
- List of items to fix now
- List of items deferred (with task references)
- "Want me to fix the agreed items?"

**Loop mode:** Return structured findings to the orchestrator as a list conforming to the Finding Schema.

### Step 6: Fix (interactive mode)

Fix all agreed items. Run tests after fixes. Present updated test results.

## Rules

- Always read the actual code before reviewing — never review based on file names alone.
- Skip trivial changes (comments, whitespace, gitignore additions).
- Focus on new files and substantive modifications.
- The `docs/reviews/` folder is gitignored — review artifacts don't go into source control.
- Be honest about findings — disagree with the subagents when they're wrong.
- Don't flag items that are explicitly tracked in future tasks (check the spec).
- **Hardcoded config values**: When code contains hardcoded model names, MongoDB URIs, or connection strings, flag them — all config must be in env vars or Kubernetes ConfigMaps.
- Refer to the user as "The Team".
