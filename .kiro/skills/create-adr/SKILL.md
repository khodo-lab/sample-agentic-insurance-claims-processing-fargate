---
name: create-adr
description: Create an Architectural Decision Record (ADR) to document a design choice or technical strategy.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Create ADR

Create an Architectural Decision Record (ADR) to document a design choice or technical strategy.

## Input

A description of the technical decision, or a reference to a recent decision made in the conversation.

## Process

### Phase 1: Gather Context

1. Identify the core technical decision and its rationale.
2. Ask the user for specific details if needed:
   - **Context**: What was the problem or requirement?
   - **Decision**: What did we choose to do?
   - **Alternatives**: What other options were considered and why were they rejected?
   - **Consequences**: What are the pros, cons, and maintenance impacts?

### Phase 2: Draft ADR

Use the standard ADR template:

```markdown
# ADR: {YYYYMMDD} - {Short Description}

## Status
Accepted

## Context
{The background and problem...}

## Decision
{The technical choice made...}

## Consequences
- **Pros**: ...
- **Cons**: ...
- **Maintenance**: ...
```

Generate the ID using the current date. Format: `YYYYMMDD`.

### Phase 3: Save and Commit

1. Define the filename: `{ID}-{kebab-case-description}.md`.
2. Ensure the `docs/adr/` directory exists.
3. Save the file to `docs/adr/{filename}`.
4. Stage and commit: `git commit -m "docs: record ADR {ID} - {description}"`.

## Rules

- Always use the `YYYYMMDD` format for IDs.
- Ensure consequences are balanced (Pros and Cons).
- Link to related ADRs if they exist.
- Refer to the user as "The Team".
