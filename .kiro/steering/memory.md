# Project Memory

Persistent learnings loaded every session.

---

## ⚡ Core — Always Active

High-signal facts that will bite you if forgotten. Keep this under 15 entries.

- **GitHub repo**: `khodo-lab/sample-agentic-insurance-claims-processing-fargate` — GitHub user `hodok-aws`
- **AWS account**: `621967485578`, region `us-west-2` — credentials via Isengard (`hodok-Isengard` assumed role)
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

### Open Issues (as of 2026-04-27)
- #2: Terraform → CDK TypeScript (unblocked)
- #3: EKS → Fargate + ElastiCache Redis (blocked by #2)
- #4: MongoDB → DynamoDB (blocked by #2)
- #5: LangGraph/Ollama → Strands + AgentCore (blocked by #2, #3)
- #6: GitHub Actions for new CDK/Fargate stack (blocked by #2, #3)
- **#7: GitHub Actions + OIDC for current stack — COMPLETE ✅ (PRs #9–16 merged)**
- **#17: Upgrade torch to fix 5 Dependabot CVEs (1 Critical) — unblocked**
- **#18: Upgrade aws-load-balancer-controller — COMPLETE ✅ (PR #22 merged, deployed)**
- **#20: coordinator crash (PYTHONUSERBASE wrong user) — unblocked**
- **#21: ExternalSecrets IRSA not wired up — unblocked**
- **#24: Mirador PVRE OS patching (EC2 i-026adde3dd7224006) — unblocked**
- PR #1: Merged ✅

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

### Issue #7 — Script Interfaces (verified 2026-04-27)
- `build-docker-images.sh`: `IMAGE_TAG` + `ECR_REGISTRY` env vars; `build-push` command; GPU excluded by omitting `--include-gpu` (no `SKIP_GPU` env var); ECR repo creation with `scanOnPush=true` already built in
- `deploy-kubernetes.sh`: requires `deploy` command argument + `IMAGE_TAG` + `ECR_REGISTRY` env vars
- `validate-deployment.sh`: no args, hardcoded namespace `insurance-claims`, exits non-zero on failure

### Issue #7 — Infrastructure Gotchas (verified 2026-04-27)
- S3 state bucket `agentic-eks-terraform-state-621967485578` (account-scoped name) — created by bootstrap script
- Terraform `use_lockfile = true` requires `>= 1.10`; lock file committed at `infrastructure/terraform/.terraform.lock.hcl` with `linux_amd64` checksums for CI
- `providers.tf` uses `aws.virginia` alias for ECR Public (Karpenter Helm chart) — deploy role needs `ecr-public:GetAuthorizationToken` in us-east-1
- OIDC sub-claim for push to main: `repo:khodo-lab/...:ref:refs/heads/main` — PR events use different sub-claim and correctly fail to assume the deploy role
- `provider default_tags` must NOT include k8s tags (`kubernetes.io/cluster/*`, `karpenter.sh/discovery`) — Secrets Manager rejects tag keys with `/` or `.`. Use `local.base_tags` in provider, `local.tags` (adds k8s tags) only on EKS/Karpenter resources directly.
- `terraform init -backend=false` in CI fails even with `-backend=false` because modules make AWS API calls during init. CI only runs `terraform fmt -check`; full validate happens in deploy workflow via `terraform plan`.
- IAM role `github-actions-deploy` needs `cloudformation:*` and `events:*` in addition to the original policy (EKS blueprints addons use CloudFormation for telemetry and EventBridge for Karpenter rules).
- Secrets in deletion window: `recovery_window_in_days = 0` alone is not enough if the secret already exists — must `aws secretsmanager restore-secret` first, then import into TF state with `terraform import`.
- EKS CloudWatch log group `/aws/eks/{cluster}/cluster` is auto-created by EKS — set `create_cloudwatch_log_group = false` in the EKS module to prevent conflict.
- AWS account in use is `621967485578` (not `597088050001` from earlier sessions — that was a different account).
- Local kubectl access: add `arn:aws:iam::621967485578:role/admin` as EKS access entry with `AmazonEKSClusterAdminPolicy`.

### Kubernetes / Docker Gotchas (verified 2026-04-27)
- K8s manifests had hardcoded old account ID `123255318457` — must use `${ECR_REGISTRY}/insurance-claims/${name}:${IMAGE_TAG}` placeholders for `envsubst` substitution in `deploy-kubernetes.sh`.
- Dockerfiles use multi-stage build with `pip install --user` → copy `/root/.local` to `/home/webapp/.local`. Must set `ENV PYTHONUSERBASE=/home/webapp/.local` in runtime stage or `python -m uvicorn` can't find packages.
- `starlette>=1.0.0` breaks `TemplateResponse("template.html", {"request": request, ...})` — pin `starlette<1.0.0` in `requirements-production.txt`.
- MongoDB pod needs `securityContext.fsGroup: 999` (pod-level) so PVC is writable, and an `emptyDir` volume mounted at `/tmp` when `readOnlyRootFilesystem: true`.
- MongoDB URI password must be URL-encoded (`urllib.parse.quote_plus`) before embedding in the connection string — special chars like `:`, `!`, `#` break pymongo URI parsing.
- Kubernetes secrets for MongoDB must include both `MONGODB_PASSWORD` (plain, for app) and `MONGO_INITDB_ROOT_PASSWORD` (plain, for MongoDB init container).
- `torch==2.0.1` + `torchvision==0.15.2` are compatible but have 5 CVEs — tracked in issue #17.
- ALB ingress: remove `ssl-redirect` and HTTPS listener annotations if no ACM cert is configured — otherwise ALB redirects HTTP→HTTPS and browser gets "refused to connect".
- ALB controller v2.17.1 requires `ec2:DescribeRouteTables` — added via `source_policy_documents` in `addons.tf`. The eks-blueprints-addons module (~> 1.20) does NOT auto-update the IRSA policy on chart version bump.
- CRDs for ALB controller must be applied manually before Helm upgrade: `kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=aws-load-balancer-controller-1.17.1"`. Not automated in CI.
- `github-actions-deploy` role is the EKS cluster creator — its access entry is managed by the EKS module's `cluster_creator` slot. Local `terraform plan` (as `admin`) will show a replace for this entry — expected, CI plan is clean.
- `admin` role access entry must be added manually after cluster creation for local kubectl — not managed by Terraform.
- `./kubectl` binary in repo root (gitignored) — re-download: `curl -LO https://dl.k8s.io/release/v1.33.0/bin/darwin/arm64/kubectl && chmod +x kubectl`
- `security` GitHub label created (was missing — only `migration` and `infrastructure` existed before).
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
