---
name: background-research
description: Kick off parallel background research before building. Dispatches specialist agents to compare alternatives, surface edge cases, and check AWS constraints.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Background Research

Kick off parallel background research before building. Dispatch research agents before you leave, come back to a structured brief.

## When to Run

- Before writing a spec for a new feature ("what are my options for X?")
- Before adopting a new AWS service or LangGraph capability
- When you want edge cases and gotchas surfaced before implementation starts
- Route triggers: "research before I build", "compare approaches", "what are my options", "what could go wrong with"

## Input

A natural language description of what you're about to build or decide. Examples:
- "I want to add streaming to the claims processing response"
- "Should I use Redis or MongoDB for LangGraph shared state?"
- "What are the gotchas with Ollama and concurrent requests?"

## Process

### Phase 1: Dispatch (parallel)

Run all 3 research agents simultaneously via `use_subagent` (all 3 fit in one batch):

1. **`research-alternatives`** — What are the viable approaches? Compare 2-4 options with tradeoffs.
2. **`research-edge-cases`** — What could go wrong? Failure modes, known bugs, operational gotchas.
3. **`research-aws-constraints`** — AWS-specific: API limits, IAM requirements, regional availability, pricing surprises.

Each agent receives:
- The full research question
- Relevant tech stack context (from `.kiro/steering/tech.md`)
- Any specific constraints mentioned by the user

### Phase 2: Synthesize

Combine the 3 agent outputs into a **Research Brief**:

```
## Research Brief: {topic}

### Recommended Approach
One paragraph. The best option given the project's stack and constraints.

### Alternatives Considered
| Option | Pros | Cons | Verdict |

### Edge Cases & Gotchas
- Bullet list of failure modes, known issues, operational surprises

### AWS Constraints
- API limits, IAM requirements, regional availability, pricing notes

### Open Questions
- Anything that needs a decision from The Team before proceeding

### Ready to Feed Into
- [ ] `create-spec` — use this brief as requirements input
- [ ] `implement-and-review-loop` — reference during implementation
```

### Phase 3: Offer Next Step

After presenting the brief, ask:
> "Ready to turn this into a spec? I can run `create-spec` with this brief as input."

## Rules

- Run all 3 agents in parallel — don't serialize them.
- **Subagent fallback**: If agents fail, do the research inline using `aws___search_documentation` and `web_search`. Never skip research.
- Keep the brief scannable — bullets and tables, not paragraphs.
- Don't make a final recommendation without surfacing the tradeoffs — The Team makes the call.
- Refer to the user as "The Team".
