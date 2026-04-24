# Project Memory

Persistent learnings loaded every session.

---

## ⚡ Core — Always Active

These caused issues or will recur on every session.

- **Ollama model must be running before agents start** — `langgraph_agentic_coordinator.py` calls Ollama at startup. If Ollama pod is not ready, coordinator crashes with connection refused. Check `kubectl get pods -n insurance-claims -l app=ollama` first.
- **MongoDB auth uses Secrets Manager** — credentials are in `infrastructure/kubernetes/external-secrets.yaml`. Never hardcode MongoDB URI. Use `MONGODB_URI` env var injected via ExternalSecret.
- **Terraform state is remote (S3 + DynamoDB lock)** — `infrastructure/terraform/backend.tf`. Always `terraform init` before plan/apply on a new machine.
- **EKS cluster name is `agentic-eks-cluster`** — set `EKS_CLUSTER_NAME` or use `aws eks update-kubeconfig --name agentic-eks-cluster --region $AWS_REGION`.
- **Docker images must be pushed to ECR before kubectl apply** — `scripts/build-docker-images.sh` handles ECR login + build + push. Never apply Kubernetes manifests with stale image tags.
- **Karpenter manages node scaling** — do not manually scale node groups. Karpenter NodePools are in `infrastructure/terraform/karpenter-nodepools.tf`.
- **LangGraph agents use shared Redis for state** — `infrastructure/kubernetes/shared-memory.yaml`. Redis is not persistent; agent state is ephemeral across pod restarts.
- **Never commit directly to `main`** — always branch + PR.
- **`scripts/deploy.sh` is the canonical deploy entry point** — it handles Terraform + Docker + Kubernetes in the correct order. Do not run steps manually unless debugging.
- **ALB URL is the only public entry point** — get it with `kubectl get ingress -n insurance-claims`. All portals are sub-paths: `/claimant`, `/adjuster`, `/siu`, `/supervisor`.

---

## 📚 Archive Index

Check the relevant section before working in that area.

### Infrastructure & Terraform
- EKS cluster provisioned via `infrastructure/terraform/eks.tf`
- Karpenter NodePools in `infrastructure/terraform/karpenter-nodepools.tf`
- Secrets Manager secrets defined in `infrastructure/terraform/secrets-manager.tf`
- ALB Ingress Controller managed via `infrastructure/terraform/addons.tf`

### Kubernetes
- Namespace: `insurance-claims`
- Key deployments: coordinator, web-interface, claims-simulator, policy-agent, mongodb, redis, ollama
- ExternalSecrets operator syncs Secrets Manager → K8s secrets
- Network policies in `infrastructure/kubernetes/network-policies.yaml`

### Application
- Main coordinator: `applications/insurance-claims-processing/src/langgraph_agentic_coordinator.py`
- Web interface (FastAPI): `applications/insurance-claims-processing/src/web_interface.py`
- Persona portals: `applications/insurance-claims-processing/src/persona_web_interface.py`
- Database models: `applications/insurance-claims-processing/src/database_models.py`
- Fraud agent: `applications/insurance-claims-processing/src/langgraph_fraud_agent.py`
- Policy agent: `applications/insurance-claims-processing/src/langgraph_policy_agent.py`

### Monitoring
- CloudWatch Container Insights: `infrastructure/kubernetes/cloudwatch-observability.yaml`
- Custom metrics via `applications/insurance-claims-processing/src/shared/observability.py`

---

## Stakeholder Preferences

*(Add decisions here as they are made)*
