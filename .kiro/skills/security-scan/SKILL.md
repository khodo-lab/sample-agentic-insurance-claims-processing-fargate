---
name: security-scan
description: Run secret-scanning tools against the codebase to detect credentials, API keys, tokens, and other sensitive data before committing.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Security Scan

Run secret-scanning tools against the codebase to detect credentials, API keys, tokens, and other sensitive data before committing.

## Prerequisites

Install via Homebrew:
```bash
brew install git-secrets trufflehog gitleaks
```

Initialize git-secrets in the repo (one-time):
```bash
git secrets --install --force
git secrets --register-aws
```

## Process

1. Determine the scan scope. Default: `applications/`, `infrastructure/`, `.github/`.

2. Run all three scanners:

```bash
echo "=== git-secrets ==="
git secrets --scan -r applications/ infrastructure/ 2>&1
echo "Exit: $?"

echo "=== gitleaks ==="
gitleaks detect --source . --no-git --verbose 2>&1
echo "Exit: $?"

echo "=== trufflehog ==="
trufflehog filesystem applications/ infrastructure/ --no-update 2>&1
echo "Exit: $?"
```

3. Report results:
   - **Clean** — all three exit 0 → "All clear — safe to commit."
   - **Findings** — list each finding with file, line, rule ID, and whether it's a real secret or false positive.
   - **Action needed** — for real secrets: remove them, rotate the credential, add the file to `.gitignore`.

## What Each Tool Catches

| Tool | Strengths |
|------|-----------|
| `git-secrets` | AWS-specific patterns (AKIA keys, secret keys). Installs pre-commit hooks. |
| `gitleaks` | Broad regex rules — API keys, tokens, passwords, high-entropy strings. |
| `trufflehog` | Entropy-based detection + known credential patterns. |

## Known False Positives

- `config.env.example` with placeholder values — documentation examples
- `infrastructure/terraform/terraform.tfvars.example` — example config
- `.kiro/context/` session handoff files referencing AWS resource IDs (not secrets)

## Rules

- Run this before every `push-and-mr`.
- Real secrets must be removed AND rotated (the key is compromised if it was ever in a file).
- Never suppress a finding without explaining why it's a false positive.
- Refer to the user as "The Team".
