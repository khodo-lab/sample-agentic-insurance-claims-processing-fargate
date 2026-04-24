---
name: guard-rails
description: Deterministic pre-commit and post-implementation checks. Run automatically at the end of implement-task Phase 5 and before any commit.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Guard Rails

Deterministic pre-commit and post-implementation checks. Run automatically at the end of `implement-task` Phase 5 and before any commit.

## Checks

### 1. Build Gate (hard fail — blocks commit)

```bash
# Python syntax check (if Python files changed)
python -m py_compile applications/insurance-claims-processing/src/*.py

# Python tests (if Python files changed)
cd applications/insurance-claims-processing
python -m pytest tests/ -v --tb=short

# Terraform validate (if Terraform files changed)
cd infrastructure/terraform && terraform validate

# Kubernetes manifest validation (if K8s files changed)
kubectl apply --dry-run=client -f infrastructure/kubernetes/ -n insurance-claims
```

### 2. Test Gate (hard fail — blocks commit)

```bash
# Run all Python tests
cd applications/insurance-claims-processing
python -m pytest tests/ -v

# Check test exit code — non-zero = fail
```

### 3. New Code Coverage Check (soft fail — warn)

For every new public function/class added in this session:
- Grep for the function name in test files
- If zero test references found → ⚠️ WARNING: `{function_name}` has no tests

### 4. Secrets & Security Scan (hard fail — blocks commit)

```bash
# Scan staged changes for secrets
git diff --cached --diff-filter=ACMR -U0 | \
  grep -iE '(password|secret|token|api.?key|aws_access|aws_secret|mongodb.?uri)\s*[:=]' | \
  grep -v '\.(md|txt|example|tfvars\.example)' | head -5
```

If findings detected → **STOP**. Must be resolved or justified as false positives before committing.

### 5. Branch Check (hard fail — blocks commit)

```bash
BRANCH=$(git branch --show-current)
if [ "$BRANCH" = "main" ]; then
    echo "🔴 BLOCKED: Cannot commit to main directly. Create a feature branch first."
    exit 1
fi
```

### 6. Hardcoded Config Check (hard fail — blocks commit)

Scan for hardcoded connection strings, model names, or credentials in Python code:
```bash
git diff --cached -- "*.py" | grep "^\+" | \
  grep -E "(mongodb://|redis://|localhost:[0-9]+|qwen2\.5|ollama\.)" | \
  grep -v "^\+\s*#" | grep -v "test_" | head -5 && \
  echo "🔴 HARDCODED CONFIG DETECTED — use environment variables" || true
```

### 7. Terraform State Check (soft fail — warn, only if Terraform changed)

```bash
# Only runs when Terraform files were modified
if git diff --cached --name-only | grep -q "infrastructure/terraform/"; then
    cd infrastructure/terraform
    terraform validate && echo "✅ Terraform valid" || echo "🔴 Terraform validation failed"
fi
```

### 8. Python Type Check (soft fail — warn)

```bash
# If mypy is available
if command -v mypy &>/dev/null; then
    mypy applications/insurance-claims-processing/src/ --ignore-missing-imports --no-error-summary 2>&1 | tail -5
fi
```

---

```
Guard Rails Report:
  ✅ Build: Python syntax OK | Tests 45 passed
  ✅ Tests: 45 passed, 0 failed
  ⚠️ Coverage: process_claim() has no test
  ✅ Secrets: None detected
  ✅ Branch: feature/add-fraud-detection-rule
  ✅ Config: No hardcoded values
  ✅ Terraform: Valid (no Terraform changes)

Result: PASS (1 warning)
```

## Rules

- Hard fails BLOCK the commit. No exceptions.
- Soft fails are warnings — present them but don't block.
- Run ALL checks, not just the ones for changed files.
- Refer to the user as "The Team".
