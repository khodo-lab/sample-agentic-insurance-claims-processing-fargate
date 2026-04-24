# Branching Workflow

## Current Model: Trunk-Based (main branch)

Feature branches merge directly to `main`.

**NEVER commit directly to `main`.**

## Required Workflow

1. **Start from main**: Always create feature branches from `main`
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/your-feature-name
   ```

2. **Work in feature branch**: Make all changes in your feature branch

3. **Merge to main**: Create PR from feature branch → `main`

## Before Making Changes

If the user is about to make code changes, remind them:
- "Should we create a feature branch for this work?"
- Suggest a branch name: `feature/description` or `bugfix/description`

## When Changes Are Complete

After completing work in a feature branch:
1. Commit and push the feature branch
2. Create PR to `main` via GitHub UI or `gh pr create --base main`
3. Pipeline runs lint + test + `terraform plan` on the PR
4. After approval and merge, pipeline runs deploy

## Branch Naming

- Features: `feature/add-fraud-detection-rule`
- Bug fixes: `bugfix/fix-coordinator-timeout`
- Infrastructure: `infra/update-eks-nodepool`
- Hotfixes: `hotfix/critical-security-patch`

## GitHub CLI

```bash
# Create PR targeting main
gh pr create --base main --title "feat: ..." --body-file .github/PR_BODY.md

# List open PRs
gh pr list

# Check CI status
gh run list
```

## Pipeline Behavior

- **Feature branch push**: Runs lint + test (no deploy, no terraform plan)
- **PR to main**: Runs lint + test + `terraform plan` — must pass before merge
- **Merge to main**: Runs full pipeline including deploy

## Commit Message Format

```
<type>: <short description>

<optional body>
- Key changes as bullet points
```

Types: `feat`, `fix`, `infra`, `docs`, `test`, `chore`, `refactor`
