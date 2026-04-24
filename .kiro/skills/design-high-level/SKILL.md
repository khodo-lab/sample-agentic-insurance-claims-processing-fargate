---
name: design-high-level
description: Produce a high-level architecture design from a requirements document.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# High Level Design

Produce a high-level architecture design from a requirements document.

## Mode

- **interactive** (default): Full standalone workflow. Reads from `docs/specs/In-Progress/`, saves to `docs/designs/{feature-name}-hld.md`.
- **spec**: Called by `create-spec`. Reads the Requirements section from the unified spec, produces the `## 2. High-Level Design` section in the same file.

## Workflow

1. **Interactive mode**: Look for requirements docs in `docs/specs/In-Progress/`. If multiple exist, ask the user which one to use.
   **Spec mode**: Read the `## 1. Requirements` section from the unified spec.
2. Read the requirements document thoroughly.
3. Ask the user if they have any additional commentary, design decisions already made, or constraints not in the requirements.
4. Produce a high-level design document covering:

## Output Format

```markdown
# High Level Design: {Feature Name}

## Overview
Brief summary of what this design achieves.

## Architecture

### System Context
How this fits into the existing Insurance Claims system. Include a Mermaid diagram:
```mermaid
graph LR
    ...
```

### Architectural Decisions
| Decision | Choice | Rationale | Alternatives Considered |
|----------|--------|-----------|------------------------|

### Major Modules
Description of each major component/module and its responsibility.

### Data Flow
How data moves through the system. Include a Mermaid sequence or flow diagram.

### Data Model
How data is structured and stored (MongoDB collections, Redis keys, S3 key structure).

### API Design
High-level API surface — FastAPI endpoints, protocols, authentication.

### Security Concerns
- Authentication and authorization approach
- Data protection (at rest, in transit with TLS)
- Input validation strategy
- LLM prompt injection considerations

### Infrastructure
AWS resources, Terraform modules affected, Kubernetes deployments.

## Dependencies
External services, libraries, or teams this depends on.

## Risks and Mitigations
| Risk | Impact | Likelihood | Mitigation |

## Requirements Traceability
Map design components back to requirement IDs (FR-1, NFR-2, etc.)
```

5. Present the document to the user for review before saving.

## Rules

- Use Mermaid diagrams for architecture, data flow, and sequence diagrams.
- Every architectural decision must have a rationale and alternatives considered.
- Trace back to requirements — every FR/NFR should be addressed.
- Don't design implementation details — that's for the low-level design.
- All config values must be in env vars or Kubernetes ConfigMaps — flag any design that hardcodes them.
- Refer to the user as "The Team".
