# ADR-20260424-02: Migrate from EKS to AWS Fargate (2 consolidated ECS services)

## Status
Accepted

## Context
The application runs on EKS with 4 separate Kubernetes deployments (web-interface, coordinator, policy-agent, claims-simulator) plus supporting pods (MongoDB, Redis, Ollama). EKS adds significant operational overhead: cluster version upgrades, node group management, Karpenter configuration, and the ExternalSecrets operator. The team wants to simplify the deployment model.

## Decision
Replace EKS with **AWS Fargate** (ECS), consolidating from 4 application deployments to **2 ECS services**:
- `web-interface` — FastAPI app serving all 4 portals (2 tasks, 1 vCPU / 2 GB)
- `coordinator` — Agent coordinator + background claim processing (1 task, 2 vCPU / 4 GB)

Supporting infrastructure:
- **ElastiCache Redis** replaces the Redis Kubernetes pod (for LangGraph/Strands shared state)
- **Secrets Manager** native ECS injection replaces the ExternalSecrets operator
- **ALB** with path-based routing replaces the ALB Ingress Controller

## Consequences

### Pros
- No Kubernetes control plane to manage or upgrade
- Fargate is serverless — no node sizing, no Karpenter, no node group management
- Consolidating to 2 services reduces operational surface area
- Native Secrets Manager injection eliminates the ExternalSecrets operator
- ECS integrates directly with CDK, ALB, and CloudWatch without extra operators

### Cons
- Fargate has higher per-vCPU cost than EC2 nodes at sustained load
- No GPU support on Fargate (mitigated by moving to Bedrock for LLM inference)
- ECS service discovery is less flexible than Kubernetes DNS
- Fargate cold starts (~10s) vs always-warm EKS pods

### Maintenance
- `infrastructure/kubernetes/` deleted; service definitions live in CDK `ComputeStack`
- Scaling via ECS target tracking (CPU) instead of Karpenter NodePools
- Log groups per service in CloudWatch; no need for Fluent Bit DaemonSet
