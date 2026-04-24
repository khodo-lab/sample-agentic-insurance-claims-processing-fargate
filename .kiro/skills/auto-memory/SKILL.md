---
name: auto-memory
description: Capture learnings, patterns, and corrections discovered during this session into persistent project memory. Runs automatically at the end of session-handoff.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Auto Memory

Capture learnings, patterns, and corrections discovered during this session into persistent project memory.

## When to Run

- End of every session (chained from `session-handoff`)
- After a bug is found and fixed
- After a code review reveals a recurring issue
- When the user says "remember this" or "don't forget"

## Memory File

`.kiro/steering/memory.md` — loaded every session via steering, survives across sessions.

### Structure
- **`## ⚡ Core — Always Active`** — ~15 entries max. Production incidents and patterns that recur every session. If it's not going to bite us in the next 2 weeks, it doesn't belong here.
- **`## 📚 Archive Index`** — one-line topic summaries grouped by area, with links to archive files. Tells you *what* is archived and *where* to look without loading the detail.

### Archive Files
- `.kiro/context/memory-archive-YYYY-MM-DD.md` — created when memory.md exceeds ~150 lines

## Process

### Phase 1: Scan Session for Learnings

Review the conversation for:
1. **Bugs found** — what broke, why, how it was caught
2. **API contract surprises** — Kubernetes API fields, Terraform resource arguments, LangGraph state schema that didn't match docs
3. **Pattern corrections** — things the AI got wrong and had to be corrected
4. **Stakeholder preferences** — new preferences expressed this session
5. **Tool/SDK gotchas** — things that work differently than expected (Motor async, LangGraph state, Ollama API)
6. **Review findings that recur** — if the same finding keeps coming up, it's a pattern to remember

### Phase 2: Deduplicate

Read existing `.kiro/steering/memory.md`. Don't add entries that are already captured.

### Phase 3: Append

Add new entries to the **`## ⚡ Core — Always Active`** section only if the entry meets the bar: it caused a production incident OR will recur on every session. Otherwise add a one-line summary to the relevant topic in **`## 📚 Archive Index`**.

Each Core entry is one line:

```markdown
## ⚡ Core — Always Active
- **[YYYY-MM-DD] description of bug and fix**
```

### Phase 4: Archive if Needed

If `memory.md` exceeds ~150 lines, move older Core entries that haven't recurred in 3+ months to a new dated archive file: `.kiro/context/memory-archive-YYYY-MM-DD.md`. Add a one-line summary to the Archive Index.

## Rules

- One line per learning. Keep it scannable.
- Include the date for temporal context.
- Don't duplicate — check before appending.
- Don't editorialize — state facts, not opinions.
- This file is loaded every session — keep Core section under ~15 entries.
- **Graduation rule:** An entry moves from Core to Archive when the underlying issue is fixed at the source or after 3+ months with no recurrence.
- Refer to the user as "The Team".
