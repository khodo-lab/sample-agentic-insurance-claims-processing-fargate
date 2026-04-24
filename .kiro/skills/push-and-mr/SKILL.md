---
name: push-and-mr
description: Commit (if needed), push the current branch to origin, and create a GitHub Pull Request.
metadata:
  author: insurance-claims-team
  version: "1.1"
---
# Push and MR

Commit (if needed), push the current branch to origin, and create a GitHub Pull Request.

## Process

1. Check `git status` — if there are uncommitted changes, ask the user if they want to commit first.
2. **Branch Guard**:
   - If the current branch is `main`, STOP and ask the user to create a feature branch.
3. Push the current branch: `git push origin <branch>` (with `-u` flag if first push).
4. Check if `.github/PULL_REQUEST_TEMPLATE.md` exists and read it. If not, use the standard format below.
5. Read `git log main..HEAD --oneline` and `git diff main --stat` to understand the scope.
6. Fill out the PR template:
   - Summary of what this PR does and why
   - Grouped changes (Python/FastAPI, LangGraph agents, Terraform, Kubernetes, tests)
   - Testing status with current test counts
   - Security considerations (new secrets, IAM changes, auth changes)
   - Deployment notes (new env vars, migration steps, deploy order)
7. **Create the PR via GitHub CLI**:
   ```bash
   gh pr create \
     --base main \
     --title "feat: {short description}" \
     --body "{filled PR template}"
   ```
   If `gh` is not available or not authenticated, output the PR description to chat so The Team can paste it into the GitHub UI.
8. Print the PR URL.

## Standard PR Format (if no template exists)

```markdown
## Summary
{What this PR does and why}

## Changes
### Python / FastAPI
- {specific changes}

### LangGraph Agents
- {specific changes}

### Infrastructure (Terraform / Kubernetes)
- {specific changes}

### Tests
- {what was tested}

## Testing
- [ ] `python -m pytest tests/ -v` passes
- [ ] `terraform validate` passes (if Terraform changed)
- [ ] `kubectl apply --dry-run=client` passes (if K8s changed)
- [ ] E2E smoke test passes

## Deployment Notes
{New env vars, migration steps, deploy order, rollback plan}

## Security Considerations
{Auth changes, new secrets, IAM changes, data exposure risks}
```

## Rules

- Never push to `main` directly.
- Always read the actual PR template — don't guess the format.
- Include deploy order when Terraform changes are involved.
- If `gh pr create` fails, output the description to chat for manual copy-paste.
- Refer to the user as "The Team".
