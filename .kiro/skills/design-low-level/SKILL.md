---
name: design-low-level
description: Produce a detailed component-level design from a high-level design document.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Low Level Design

Produce a detailed component-level design from a high-level design document.

## Mode

- **interactive** (default): Full standalone workflow. Reads from `docs/designs/`, saves to `docs/designs/{feature-name}-lld.md`.
- **spec**: Called by `create-spec`. Reads the Requirements and HLD sections from the unified spec, produces the `## 3. Low-Level Design` section.

## Workflow

1. **Interactive mode**: Look for HLD docs in `docs/designs/` (files ending in `-hld.md`).
   **Spec mode**: Read the `## 1. Requirements` and `## 2. High-Level Design` sections from the unified spec.
2. Read the high-level design document thoroughly.
3. Ask the user if they have refinements or decisions about component separation.
4. Produce a low-level design document covering:

## Output Format

```markdown
# Low Level Design: {Feature Name}

## Overview
Brief summary linking back to the HLD.

## Component Design

### {Component Name}
For each major component from the HLD:

**Responsibility**: What this component does.

**Module Diagram**:
```mermaid
classDiagram
    ...
```

**Key Classes/Functions**:
| Class/Function | Responsibility | Dependencies |

**Public API**:
```
Function/Endpoint signature
  Input: ...
  Output: ...
  Errors: ...
```

**Internal Logic**: Key algorithms or decision flows.

### Component Interactions
```mermaid
sequenceDiagram
    ...
```

## Module Separation
How code is organized per `.kiro/steering/structure.md`:
- Python modules in `applications/insurance-claims-processing/src/`
- LangGraph agents as `langgraph_{name}_agent.py`
- Terraform resources in `infrastructure/terraform/`
- Kubernetes manifests in `infrastructure/kubernetes/`

## Interface Contracts
Detailed API contracts between components — request/response shapes, error codes.

## Configuration
All configuration values, their sources (env vars, Kubernetes ConfigMaps, Secrets Manager), and defaults.

## Error Handling Strategy
How errors propagate across component boundaries. How LangGraph node failures are surfaced.

## Task Readiness Checklist
- [ ] Each component has clear boundaries and a single responsibility
- [ ] All interfaces between components are defined
- [ ] Data models are specified (Pydantic models for MongoDB documents)
- [ ] Error handling is defined at each boundary
- [ ] Configuration is documented
```

5. Present the document to the user for review before saving.

## Rules

- Use Mermaid class diagrams for component structure.
- Use Mermaid sequence diagrams for component interactions.
- Every public API must have input/output/error documented.
- The design should make task breakdown straightforward.
- Match existing project conventions from `.kiro/steering/structure.md` and `.kiro/steering/tech.md`.
- Refer to the user as "The Team".
