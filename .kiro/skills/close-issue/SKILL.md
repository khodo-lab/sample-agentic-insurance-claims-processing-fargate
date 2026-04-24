---
name: close-issue
description: Wrap up a completed issue: verify all tasks done, group deferred findings, create follow-up issues, close with summary, move spec to Done.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Close Issue

Wrap up a completed issue: verify all tasks done, group deferred findings, deduplicate against existing GitHub issues, create follow-up issues, close with summary, move spec to Done.

## When to Run

When all tasks in a spec are complete, deployed, and validated.

## GitHub CLI Pattern

All GitHub operations use the `gh` CLI.

```bash
# List open issues
gh issue list --state open --limit 100

# Create issue
gh issue create --title "..." --body "..."

# Close issue with comment
gh issue close {number} --comment "## What Shipped\n...\n\n## Deferred\n..."

# Add comment to issue
gh issue comment {number} --body "..."
```

## Workflow

### Step 1: Verify Completion

1. Read the spec from `docs/specs/In-Progress/`.
2. Check for any `[ ]` (unchecked) tasks. If any remain, categorize them:
   - **Superseded tasks** — replaced by a v2 equivalent. Mark `[x]` with a note and proceed.
   - **Genuinely incomplete tasks** — stop and report to The Team.
3. Confirm all acceptance criteria are met.

### Step 2: Group Deferred Findings

1. Scan all review findings in the spec for items with action `log`.
2. Group into categories:
   - **Should track** — real work with value (test gaps, known limitations, refactors)
   - **Acceptable as-is** — by design, low risk, or already mitigated
   - **Correctly skipped** — disagreed with reviewer, documented rationale
3. Present the grouped summary to The Team.

### Step 3: Deduplicate Against Open Issues

1. List open issues: `gh issue list --state open --limit 100`
2. For each "should track" item, check if an existing issue already covers it.
3. **Club findings by theme** — group multiple findings sharing a domain into a single existing issue.
4. Present the deduplication table: finding → existing issue (fold in) or "new issue needed".
5. Ask: "Does this look right, or do you want to adjust?" — one round only.

### Step 4: Create Follow-Up Issues

For items needing new issues:
```bash
gh issue create --title "..." --body "..."
```

For items folding into existing issues, add a comment:
```bash
gh issue comment {number} --body "..."
```

### Step 5: Close the Issue

1. Close with a summary comment:
   ```bash
   gh issue close {number} --comment "## What Shipped\n...\n\n## MRs Merged\n...\n\n## Deferred\n..."
   ```
2. Move the spec from `docs/specs/In-Progress/` to `docs/specs/Done/`.
3. Commit and push on a feature branch, then open a PR to `main`.

## Rules

- Never close an issue with unchecked tasks.
- Always deduplicate before creating new issues.
- **Never commit directly to `main`** — spec moves must happen on a feature branch → PR → merge.
- Refer to the user as "The Team".
