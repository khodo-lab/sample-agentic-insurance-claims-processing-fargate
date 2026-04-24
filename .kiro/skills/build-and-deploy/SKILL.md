---
name: build-and-deploy
description: Build Docker images, push to ECR, and roll out Kubernetes deployments on EKS.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Build and Deploy

Build Docker images, push to ECR, and roll out Kubernetes deployments on EKS. Use for manual deploys when you need to see changes live without waiting for GitHub Actions CI/CD.

## Prerequisites

- Docker running (`docker info`)
- AWS credentials valid (`aws sts get-caller-identity`)
- kubectl configured (`kubectl get nodes`)
- ECR login active

## Process

### Step 1: Identify What Changed

Determine which service(s) need rebuilding:
- `applications/insurance-claims-processing/src/web_interface.py` changed → rebuild `insurance-claims-web`
- `applications/insurance-claims-processing/src/langgraph_agentic_coordinator.py` changed → rebuild `insurance-claims-coordinator`
- `applications/insurance-claims-processing/src/real_time_claims_simulator.py` changed → rebuild `insurance-claims-simulator`
- `infrastructure/terraform/` changed → run `terraform apply` (not Docker)
- `infrastructure/kubernetes/` changed → run `kubectl apply` (not Docker)

### Step 2: Build Image

```bash
# Get AWS account ID and region
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-east-1}
ECR_REGISTRY="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Build image
docker build \
  -t ${ECR_REGISTRY}/insurance-claims-{service}:latest \
  -f applications/insurance-claims-processing/docker/Dockerfile.{service} .
```

### Step 3: Push to ECR

```bash
# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Tag with commit SHA (avoid stale :latest issues)
COMMIT=$(git rev-parse --short HEAD)
docker tag ${ECR_REGISTRY}/insurance-claims-{service}:latest \
  ${ECR_REGISTRY}/insurance-claims-{service}:${COMMIT}

docker push ${ECR_REGISTRY}/insurance-claims-{service}:${COMMIT}
docker push ${ECR_REGISTRY}/insurance-claims-{service}:latest
```

### Step 4: Roll Out Kubernetes Deployment

```bash
# Update kubeconfig if needed
aws eks update-kubeconfig --name agentic-eks-cluster --region ${AWS_REGION}

# Trigger rolling restart (picks up new :latest image)
kubectl rollout restart deployment/{service-name} -n insurance-claims

# Watch rollout
kubectl rollout status deployment/{service-name} -n insurance-claims
```

### Step 5: Verify

```bash
# Check pods are running
kubectl get pods -n insurance-claims -l app={service-name}

# Check logs for startup errors
kubectl logs -n insurance-claims -l app={service-name} --tail=50

# Get ALB URL
kubectl get ingress -n insurance-claims
```

### Full Deploy (all services)

Use the canonical deploy script instead of manual steps:
```bash
./scripts/deploy.sh --apps-only
```

### Infrastructure Only (Terraform changes)

```bash
cd infrastructure/terraform
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Rules

- This only deploys the changed service. It does NOT run Terraform.
- For Terraform changes, run `terraform apply` separately.
- Manual deploys will be overwritten by the next GitHub Actions pipeline run.
- Always verify the rollout completed before declaring success.
- Refer to the user as "The Team".
