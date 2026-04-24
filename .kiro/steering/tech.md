# Technology Stack

## Core Technologies

- **Infrastructure**: Terraform (v1.5+) for all AWS infrastructure as code
- **Container Orchestration**: AWS EKS (Kubernetes 1.33) with Karpenter for node auto-scaling
- **Backend**: Python 3.11 + FastAPI web services
  - `web_interface.py` — main FastAPI app serving all portals
  - `persona_web_interface.py` — persona-specific portal logic
  - `langgraph_agentic_coordinator.py` — LangGraph multi-agent coordinator
  - `langgraph_fraud_agent.py` — fraud detection agent
  - `langgraph_policy_agent.py` — policy verification agent
  - `langgraph_investigation_agent.py` — SIU investigation agent
- **AI Framework**: LangGraph for agentic workflows and multi-agent coordination
- **LLM**: Ollama (Qwen2.5) running as a Kubernetes deployment — local inference, no external API calls
- **Database**: MongoDB 6.0 (document storage for claims, policies, users)
- **Cache**: Redis (session state, LangGraph shared memory, response caching)
- **Frontend**: Jinja2 HTML templates + vanilla JS/CSS (served by FastAPI)
- **Networking**: AWS VPC + ALB (Application Load Balancer) via AWS Load Balancer Controller
- **Secrets**: AWS Secrets Manager + ExternalSecrets Operator (syncs to K8s secrets)
- **Monitoring**: CloudWatch Container Insights + custom metrics via `observability.py`
- **CI/CD**: GitHub Actions (OIDC-based AWS authentication)

## Key Patterns

### LangGraph Agent Architecture
Agents are defined as LangGraph `StateGraph` instances. The coordinator (`langgraph_agentic_coordinator.py`) orchestrates sub-agents (fraud, policy, investigation) via message passing. Shared state is stored in Redis via `langgraph_shared_memory.py`.

### Environment Config
All runtime config is injected via Kubernetes environment variables sourced from:
- AWS Secrets Manager (via ExternalSecrets): MongoDB URI, API keys
- ConfigMaps: non-sensitive config (model names, feature flags)
- Never hardcode connection strings, credentials, or model names in Python code.

### Least Privilege
Each Kubernetes service account has a dedicated IAM role (IRSA) scoped to its exact needs. No shared credentials between services.

### Ollama Model Config
Model name is configurable via `OLLAMA_MODEL` env var (default: `qwen2.5-coder:7b`). Override in Kubernetes deployment manifests or `config.env`.

## Common Commands

### Local Development
```bash
# Install dependencies
pip install -r applications/insurance-claims-processing/requirements-langgraph.txt

# Run locally (requires MongoDB + Redis + Ollama running)
cd applications/insurance-claims-processing/src
uvicorn web_interface:app --reload --port 8000
```

### Docker Build
```bash
# Build all images
./scripts/build-docker-images.sh

# Build specific image
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-east-1}
docker build -t ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/insurance-claims-web:latest \
  -f applications/insurance-claims-processing/docker/Dockerfile.web .
```

### Terraform
```bash
cd infrastructure/terraform
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Kubernetes
```bash
# Update kubeconfig
aws eks update-kubeconfig --name agentic-eks-cluster --region $AWS_REGION

# Deploy all manifests
kubectl apply -f infrastructure/kubernetes/ -n insurance-claims

# Check pod status
kubectl get pods -n insurance-claims

# View logs
kubectl logs -n insurance-claims -l app=web-interface --tail=100
```

### Testing
```bash
# Run all tests
cd applications/insurance-claims-processing
python -m pytest tests/ -v

# Run specific test file
python -m pytest tests/test_fraud_agent.py -v

# E2E demo
./tests/comprehensive-e2e-demo.sh
```

### Full Deploy
```bash
# One-command deploy (Terraform + Docker + Kubernetes + data)
./scripts/deploy.sh

# Apps only (skip Terraform)
./scripts/deploy.sh --apps-only

# Validate deployment
./scripts/validate-deployment.sh
```

## SSM / Config Naming Convention

```
/insurance-claims/{environment}/config/{key}    # Feature flags, config values
/insurance-claims/{environment}/secrets/{name}  # Credentials (via Secrets Manager)
```

## Terraform Module Structure

```
infrastructure/terraform/
├── eks.tf                    # EKS cluster
├── vpc.tf                    # VPC and networking
├── addons.tf                 # EKS addons (ALB controller, ExternalSecrets, etc.)
├── karpenter-nodepools.tf    # Karpenter node pools
├── secrets-manager.tf        # Secrets Manager secrets
├── storage.tf                # S3 buckets
├── iam.tf                    # IAM roles and policies
├── variables.tf              # Input variables
├── outputs.tf                # Output values
└── backend.tf                # Remote state (S3 + DynamoDB lock)
```
