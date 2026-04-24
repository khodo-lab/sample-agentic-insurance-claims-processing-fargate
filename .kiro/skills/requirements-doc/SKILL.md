---
name: requirements-doc
description: Capture a stream-of-consciousness description of requirements and produce a structured requirements document.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Requirements Doc

Capture a stream-of-consciousness description of requirements and produce a structured requirements document.

## Mode

- **interactive** (default): Full standalone workflow. Saves to `docs/specs/In-Progress/{feature-name}.md`.
- **spec**: Called by `create-spec`. Produces the Requirements section of the unified spec. Does not create a standalone file.

## Workflow

1. Ask the user: "What are you building? Give me the full stream of consciousness — don't worry about structure, I'll organize it."
2. If the user has already provided the description, proceed directly.
3. Ask clarifying questions where the description is ambiguous. Focus on:
   - Who are the users (claimants, adjusters, SIU investigators, supervisors)?
   - What problem does this solve?
   - What are the must-haves vs nice-to-haves?
   - Are there constraints (Ollama model availability, MongoDB limits, EKS resource limits)?
   - Are there integrations with existing Insurance Claims components?
4. Produce a structured Markdown document:

## Output Format

```markdown
# Requirements: {Feature Name}

## Problem Statement
What problem are we solving and for whom?

## Users
Who will use this and how? (Claimants, Adjusters, SIU Investigators, Supervisors)

## Functional Requirements
### Must Have
- FR-1: ...

### Should Have
- FR-N: ...

### Nice to Have
- FR-N: ...

## Non-Functional Requirements
- NFR-1: Performance — ...
- NFR-2: Security — encryption at rest/in transit, least-privilege IAM
- NFR-3: Scalability — ...

## Constraints
- Technology, timeline, or organizational constraints
- Ollama model availability constraints
- EKS resource limits

## Integrations
- Existing Insurance Claims components this must work with

## Open Questions
- Anything unresolved that needs stakeholder input

## Acceptance Criteria
- How do we know this is done?
```

5. Present the document to the user for review before saving.

## Rules

- Capture everything the user says — don't filter out ideas prematurely.
- Number all requirements for traceability.
- Flag ambiguities as Open Questions rather than making assumptions.
- This is a prerequisite for `design-high-level` — always run requirements first.
- Refer to the user as "The Team".
