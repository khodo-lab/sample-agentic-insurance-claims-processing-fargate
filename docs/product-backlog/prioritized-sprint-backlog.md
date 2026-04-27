# Prioritized Sprint Backlog

**Generated:** 2026-04-27  
**Method:** Dual agent review (Principal PM + Principal PSE)  
**Total open issues:** 9  

---

## Tier 1 — Broken / Fix Before Next Deploy

| # | Title | Type | Why |
|---|-------|------|-----|
| [#20](https://github.com/khodo-lab/sample-agentic-insurance-claims-processing-fargate/issues/20) | fix: coordinator + external-integrations crash (PYTHONUSERBASE wrong user) | bug | AI processing completely non-functional. One-line Dockerfile fix. |
| [#17](https://github.com/khodo-lab/sample-agentic-insurance-claims-processing-fargate/issues/17) | security: upgrade torch (1 Critical RCE, 2 High CVEs) | infra | Critical RCE in production analytics image. Must fix before next deploy. |

## Tier 2 — High Value / Operational Risk

| # | Title | Type | Why |
|---|-------|------|-----|
| [#21](https://github.com/khodo-lab/sample-agentic-insurance-claims-processing-fargate/issues/21) | fix: wire up ExternalSecrets IRSA | infra | Manual K8s secrets lost on namespace recreation. Silent failure risk. |
| [#18](https://github.com/khodo-lab/sample-agentic-insurance-claims-processing-fargate/issues/18) | security: upgrade aws-load-balancer-controller (Inspector CVE) | infra | Inspector finding assigned to owner. Security SLA clock running. |
| [#2](https://github.com/khodo-lab/sample-agentic-insurance-claims-processing-fargate/issues/2) | migrate: Terraform → AWS CDK (TypeScript) | infra | Unblocks #3, #4, #5, #6 — entire migration chain. Highest leverage item. |

## Tier 3 — Quality & Architecture (blocked by #2)

| # | Title | Type | Why |
|---|-------|------|-----|
| [#3](https://github.com/khodo-lab/sample-agentic-insurance-claims-processing-fargate/issues/3) | migrate: EKS → AWS Fargate (2 consolidated ECS services) | infra | Reduces ops overhead. Blocked by #2. |
| [#4](https://github.com/khodo-lab/sample-agentic-insurance-claims-processing-fargate/issues/4) | migrate: MongoDB → Amazon DynamoDB | infra | Managed persistence, no pod management. Blocked by #2. |

## Tier 4 — Features & Strategic (blocked by #2, #3)

| # | Title | Type | Why |
|---|-------|------|-----|
| [#5](https://github.com/khodo-lab/sample-agentic-insurance-claims-processing-fargate/issues/5) | migrate: LangGraph/Ollama → Strands + Amazon Bedrock AgentCore | functionality | Core AI upgrade. Blocked by #2, #3. |
| [#6](https://github.com/khodo-lab/sample-agentic-insurance-claims-processing-fargate/issues/6) | feat: GitHub Actions CI/CD for CDK/Fargate stack | infra | Supersedes current CI/CD. Blocked by #2, #3. |

---

## Sprint Loading Recommendation

**Sprint 1 (now):**
- #20 — coordinator crash fix (30 min, unblocked)
- #17 — torch CVE upgrade (1–2 hrs, unblocked)
- #21 — ExternalSecrets IRSA (1–2 hrs, unblocked)
- #18 — ALB controller upgrade (1 hr, unblocked)

**Sprint 2:**
- #2 — CDK migration (large, unblocks everything else)

**Sprint 3+:**
- #3, #4 in parallel (after #2)
- #5 (after #3)
- #6 (after #3)

---

## Agent Disagreements & Resolutions

None — both agents agreed on all tier placements.
