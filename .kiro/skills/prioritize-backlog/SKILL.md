---
name: prioritize-backlog
description: Generate a prioritized backlog from all open GitHub issues using dual principal-pm + principal-pse agent review. Run at the start of each sprint.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Prioritize Backlog

Generate a prioritized backlog from all open GitHub issues using dual principal-pm + principal-pse agent review. Produces `docs/product-backlog/prioritized-sprint-backlog.md`.

## When to Run

- Start of each sprint
- After a significant batch of issues is closed or opened
- Route triggers: "prioritize backlog", "what should we work on", "sprint planning"

## Issue Categories

Issues are classified into four types for rotation balancing:

| Type | Description | Examples |
|---|---|---|
| **functionality** | Core features that deliver user value | New portal features, agent improvements, fraud detection rules |
| **infra** | Infrastructure, Terraform, CI/CD, security hardening | EKS upgrades, Karpenter config, network policies |
| **ui** | User-visible frontend progress | Portal UI improvements, dashboard enhancements |
| **bug** | Fixes for broken or degraded behaviour | Pod crashes, MongoDB connection issues, agent timeouts |

## Process

### Phase 1: Fetch Issues

```bash
gh issue list --state open --limit 100 --json number,title,labels,body
```

### Phase 2: Dual Agent Review (inline)

Run both agents inline against the full issue list:

**Principal PM lens** (user value, correctness before features):
- Tier 1: Broken or blocking — fix before any feature work
- Tier 2: High value — unblocks other work or high user impact
- Tier 3: Quality & maintainability
- Tier 4: Features & improvements
- Tier 5: Strategic / long-term
- Tier 6: Backlog / low urgency

**Principal PSE lens** (correctness, blast radius, operational stability):
- Critical: Fix before next deploy
- High: Architectural correctness
- Medium: Operational quality
- Lower: Quality of life
- Strategic: Evaluate before committing

### Phase 3: Merge & Resolve Conflicts

Where agents disagree on tier placement:
- Default to the more conservative (higher urgency) position
- Document the conflict and resolution in an "Agent Disagreements" table
- The Team makes the final call on escalated conflicts

### Phase 4: Write Backlog File

Overwrite `docs/product-backlog/prioritized-sprint-backlog.md` with:
- Generation date and method
- Total open issue count
- 6-tier table (one table per tier, with issue #, title, and "Why" column)
- Sprint Loading Recommendation section
- Agent Disagreements & Resolutions table at the bottom

### Phase 5: Commit

```bash
git add docs/product-backlog/prioritized-sprint-backlog.md
git commit -m "docs: regenerate prioritized backlog — {N} issues, {date}"
```

## Rules

- Always fetch fresh from GitHub — never use a cached list.
- Always run both agents — never single-agent prioritization.
- Document every conflict resolution.
- Overwrite the existing file — one source of truth.
- Commit immediately after writing.
- Refer to the user as "The Team".
