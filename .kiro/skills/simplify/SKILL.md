---
name: simplify
description: Simplify code for clarity after tests pass. Use after TDD green phase — reduce complexity without changing behavior. Runs automatically as Phase 1.5 of implement-and-review-loop.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Simplify

Reduce complexity while preserving exact behavior. The goal is not fewer lines — it's code a new team member understands faster.

**Only run after tests pass. Never change behavior.**

## When to Use

- Automatically: after Phase 1 (TDD green) in `implement-and-review-loop`, before Phase 2 (review)
- Manually: when review agents flag readability or complexity findings
- Scope: recently modified files only — no drive-by refactors of unrelated code

## Process

### Step 1: Understand before touching

Before changing anything, answer:
- What is this code's responsibility?
- Why might it have been written this way?
- Are there tests that define the expected behavior?

### Step 2: Scan for simplification signals

| Pattern | Signal | Fix |
|---|---|---|
| Deep nesting (3+ levels) | Hard to follow control flow | Extract guard clauses or helper functions |
| Long functions (50+ lines) | Multiple responsibilities | Split into focused functions |
| Generic names (`data`, `result`, `temp`) | Unclear intent | Rename to describe content |
| Comments explaining "what" | Code isn't clear enough | Rename the thing instead |
| Comments explaining "why" | Intent the code can't express | Keep these |
| Duplicated logic (5+ lines, 2+ places) | DRY violation | Extract shared function |
| Dead code / unused variables | Residue of iteration | Remove |
| Unnecessary async wrapper | Adds no value | Inline |

### Step 3: Apply one change at a time, run tests after each

```
FOR EACH SIMPLIFICATION:
1. Make the change
2. Run: python -m pytest tests/ -v --tb=short
3. Tests pass → continue
4. Tests fail → revert and reconsider
```

### Step 4: Verify

- [ ] All existing tests pass without modification (behavior unchanged)
- [ ] Python syntax check passes
- [ ] No error handling removed or weakened
- [ ] Diff is clean — no unrelated changes mixed in

## Python-Specific Patterns

- Guard clauses over nested `if` blocks
- Dict/list comprehensions over manual `for` + `append` (when intent is clearer)
- Remove redundant `return None` at end of functions
- Use `async`/`await` consistently — don't mix sync and async in the same call chain
- Use Pydantic models for data validation instead of manual dict checks
- Use `Optional[T]` type hints instead of `Union[T, None]`

## Rules

- Stay scoped to recently modified files only.
- Never batch multiple simplifications into one untested change.
- Refer to the user as "The Team".
