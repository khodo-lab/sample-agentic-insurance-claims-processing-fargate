---
name: create-spec
description: Orchestrate the full specification pipeline — requirements → high-level design → low-level design → task plan — producing a single unified spec document.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Create Spec

Orchestrate the full specification pipeline — requirements → high-level design → low-level design → task plan — producing a single unified spec document. This spec is the primary input for `implement-and-review-loop`.

## Input

A stream-of-consciousness description of what to build, or "resume" to continue an in-progress spec.

## Output

A single file: `docs/specs/In-Progress/{feature-name}-spec.md`

## Process

**⚠️ TELEMETRY: Log `{"type":"skill","skill":"create-spec","status":"started"}` BEFORE doing anything else.**

### Phase 0: Research (if not already done)

If the feature involves AWS APIs, EKS capabilities, Terraform patterns, LangGraph patterns, or any codebase scope claim:
1. **Audit actual code/files first** — grep, read, and count before accepting scope claims.
2. **Run `background-research`** — dispatch the 3 parallel research agents.
3. **Document findings in `## 0. Research Findings`** — add this section to the spec BEFORE Section 1.
4. **Flag constraints early** — if research reveals an EKS limitation or quota, surface it in requirements.

### Phase 1: Requirements (delegate to `requirements-doc` in spec mode)

1. Run `requirements-doc` with `mode: spec`.
2. Gather the user's description, ask clarifying questions.
3. Produce the Requirements section.
4. **Run `principal-pm` review** via `use_subagent`. Present findings grouped as Blockers / Concerns / Open Questions. Resolve all blockers before proceeding.
5. **⛔ HARD STOP — present to The Team for review. Do NOT proceed to Phase 2 until explicitly approved.**
6. Loop until approved. Save spec file with Requirements section.

### Phase 2: High-Level Design (delegate to `design-high-level` in spec mode)

1. Run `design-high-level` with `mode: spec`.
2. Ask for additional design constraints or decisions already made.
3. Produce the High-Level Design section.
4. **Run `principal-pse` review** via `use_subagent`. Present findings grouped as Blockers / Concerns / Alternatives. Resolve all blockers.
5. **⛔ HARD STOP — present to The Team for review. Do NOT proceed to Phase 3 until explicitly approved.**
6. Loop until approved. Update spec file.

### Phase 3: Low-Level Design (delegate to `design-low-level` in spec mode)

1. Run `design-low-level` with `mode: spec`.
2. Ask for refinements on component separation.
3. Produce the Low-Level Design section.
4. **STOP — present to The Team for review.**
5. Loop until approved. Update spec file.

### Phase 4: Task Plan (delegate to `plan-tasks` in spec mode)

1. Run `plan-tasks` with `mode: spec`.
2. Break the LLD into implementation tasks with dependencies.
3. Produce the Task Plan section.
4. **STOP — present to The Team for review.**
5. Loop until approved. Update spec file.

**⚠️ DEPLOYMENT TASK: If the spec involves Terraform or Kubernetes changes, the task plan MUST include a deployment validation task as the final task.**

### Phase 5: Final Summary

Present:
- Spec file path
- Requirement count (FR + NFR)
- Component count from LLD
- Task count with dependency waves
- "Ready to finalize? I will create the GitHub issue, get the ID, and rename the spec file."

### Phase 6: Finalize & File

1. **Create GitHub Issue** via `gh issue create --title "..." --body "..."`.
2. Capture the issue number.
3. **Rename Spec File**: Move to `docs/specs/In-Progress/issue-{ID}-{feature-name}-spec.md`.
4. **Confirm**: "Issue #{ID} created and spec renamed. Ready for `implement-and-review-loop`."

## Unified Spec Format

```markdown
# Specification: {Feature Name}

## 0. Research Findings
### Actual Scope
### Recommended Approach
### Alternatives Considered
### Edge Cases & Gotchas
### Known Limitations (out of scope)

## 1. Requirements
### Problem Statement
### Users
### Functional Requirements (Must Have / Should Have / Nice to Have)
### Non-Functional Requirements
### Constraints
### Integrations
### Open Questions
### Acceptance Criteria

## 2. High-Level Design
### Overview
### System Context (Mermaid diagram)
### Architectural Decisions (ADR table)
### Major Modules
### Data Flow (Mermaid diagram)
### Data Model
### API Design
### Security Concerns
### Infrastructure
### Dependencies
### Risks and Mitigations

## 3. Low-Level Design
### Component Design (per-component: responsibility, class diagram, public API)
### Component Interactions (Mermaid sequence diagram)
### Module Separation
### Interface Contracts
### Configuration
### Error Handling Strategy

## 4. Task Plan
### Progress Summary
### Task Status (table)
### Eligible Tasks
### Dependency Graph (Mermaid)
### Detailed Task Definitions
```

## Rules

- Human review gate after every phase — never auto-advance.
- Each phase builds on the previous — HLD references requirements, LLD references HLD, tasks reference LLD.
- Every FR/NFR must be traceable through HLD → LLD → at least one task.
- The unified spec replaces separate requirements and design files.
- Refer to the user as "The Team".
