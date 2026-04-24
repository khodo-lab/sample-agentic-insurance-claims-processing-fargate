# Project Memory

Persistent learnings loaded every session.

---

## ⚡ Core — Always Active

High-signal facts that will bite you if forgotten. Keep this under 15 entries.

- **GitHub repo**: `khodo-lab/sample-agentic-insurance-claims-processing-fargate` — GitHub user `hodok-aws`
- **AWS account**: `597088050001`, region `us-west-2` — credentials via Isengard (`hodok-Isengard` assumed role)
- **Target architecture** (decided 2026-04-24): CDK TypeScript + Fargate (2 services) + DynamoDB + ElastiCache Redis + Strands/AgentCore (Claude Sonnet 4.5). See ADRs 01–04 in `docs/adr/`.
- **Issue dependency chain**: #2 (CDK) → #3 (Fargate) + #4 (DynamoDB) in parallel → #5 (Strands/AgentCore) → #6 (GitHub Actions for new stack). Issue #7 (GitHub Actions for current stack) is unblocked and can start immediately.
- **Never commit directly to `main`** — always branch + PR.
- **Ollama is gone** — replaced by Claude Sonnet 4.5 on Bedrock AgentCore. Do not add Ollama back.
- **MongoDB is gone** — replaced by DynamoDB. Do not add Motor/PyMongo back.
- **Terraform is gone** — replaced by CDK TypeScript. Do not add Terraform back.
- **2 ECS services only**: `web-interface` (FastAPI portals) and `coordinator` (agent processing). No more than 2 services unless explicitly re-decided.

---

## 📚 Topical Memory

Grouped by area. Check the relevant section before working in that area.

### Architecture Decisions (ADRs)
- `docs/adr/20260424-01-strands-bedrock-agentcore.md` — Why Strands + AgentCore over LangGraph/Ollama
- `docs/adr/20260424-02-eks-to-fargate.md` — Why Fargate over EKS, 2-service consolidation
- `docs/adr/20260424-03-mongodb-to-dynamodb.md` — Why DynamoDB over MongoDB/DocumentDB
- `docs/adr/20260424-04-terraform-to-cdk.md` — Why CDK TypeScript over Terraform

### Open Issues (as of 2026-04-24)
- #2: Terraform → CDK TypeScript (unblocked, start here)
- #3: EKS → Fargate + ElastiCache Redis (blocked by #2)
- #4: MongoDB → DynamoDB (blocked by #2)
- #5: LangGraph/Ollama → Strands + AgentCore (blocked by #2, #3)
- #6: GitHub Actions for new CDK/Fargate stack (blocked by #2, #3)
- #7: GitHub Actions + OIDC for current stack (unblocked — deploy what exists today)
- PR #1: Initial Kiro configuration (open, needs merge)

### Kiro Configuration
- Ported from `titan-daws` project and adapted for Python/FastAPI/LangGraph/EKS stack
- All steering, agents, skills, hooks in `.kiro/`
- `.kiro/context/` and `.kiro/telemetry/` are gitignored (local session state only)
- Team reference: "The Team" (not "The Titan Team")

### Infrastructure
- Current stack: Terraform + EKS + MongoDB + Redis + Ollama (Kubernetes pods)
- Target stack: CDK TypeScript + Fargate + DynamoDB + ElastiCache + Bedrock AgentCore
- CDK bootstrap needed: `cdk bootstrap aws://597088050001/us-west-2`
- OIDC trust: `repo:khodo-lab/sample-agentic-insurance-claims-processing-fargate:ref:refs/heads/main`

### Application
- Main FastAPI app: `applications/insurance-claims-processing/src/web_interface.py`
- Portals: `/claimant`, `/adjuster`, `/siu`, `/supervisor`
- Agent files (to be replaced): `langgraph_*_agent.py`
- Database models (to be replaced): `database_models.py` (Motor/PyMongo → boto3 DynamoDB)

### Strands / AgentCore
- Model: `us.anthropic.claude-sonnet-4-5-20251101-v1:0` (cross-region inference profile)
- AgentCore image must be `linux/arm64`
- AgentCore cold start ~30s — use PUBLIC network mode (VPC mode cold start >30s)
- See `.kiro/steering/memory.md` in titan-daws for detailed AgentCore gotchas if needed

---

## Stakeholder Preferences (2026-04-24)

- **LLM**: Claude Sonnet 4.5 on Bedrock AgentCore via Strands (not Ollama, not LangGraph)
- **Shared state**: ElastiCache Redis (not DynamoDB for state)
- **Service count**: 2 consolidated ECS services (not 4)
- **IaC**: CDK TypeScript (not Terraform)
- **Deploy now**: Issue #7 — get current stack deploying via GitHub Actions + OIDC as a baseline
