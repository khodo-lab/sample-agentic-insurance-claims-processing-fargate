---
name: validate-deployment
description: Verify that code changes have been successfully deployed to EKS after CI/CD completes.
metadata:
  author: insurance-claims-team
  version: "1.0"
---
# Validate Deployment

Verify that code changes have been successfully deployed to EKS after GitHub Actions CI/CD completes.

## Process

### Phase 0: Verify AWS Credentials and kubectl

```bash
aws sts get-caller-identity --region us-east-1
kubectl get nodes
```
If either fails → **STOP**. Tell The Team: "AWS credentials or kubectl config expired. Re-authenticate and try again."

### Phase 1: Detect What Changed

Run `git log main..HEAD --name-only` to identify changed file types:
- `applications/` → Python/FastAPI deployment
- `infrastructure/terraform/` → Terraform/EKS infrastructure
- `infrastructure/kubernetes/` → Kubernetes manifest deployment

### Phase 2: Validate Kubernetes Deployments (if application changed)

1. Check ECR image push time:
   ```bash
   aws ecr describe-images --repository-name insurance-claims-{service} \
     --region us-east-1 --query 'sort_by(imageDetails,&imagePushedAt)[-1].imagePushedAt'
   ```
   Verify `imagePushedAt` is after the CI/CD run.

2. Check deployment rollout status:
   ```bash
   kubectl rollout status deployment/{service-name} -n insurance-claims
   kubectl get pods -n insurance-claims -l app={service-name}
   ```

3. Confirm running pod count matches desired replicas.

4. Check pod logs for startup errors:
   ```bash
   kubectl logs -n insurance-claims -l app={service-name} --tail=50
   ```

### Phase 3: Validate Terraform (if infrastructure changed)

1. Check Terraform state:
   ```bash
   cd infrastructure/terraform
   terraform show -json | python3 -c "import sys,json; s=json.load(sys.stdin); print('Resources:', len(s.get('values',{}).get('root_module',{}).get('resources',[])))"
   ```

2. Verify EKS cluster is healthy:
   ```bash
   aws eks describe-cluster --name agentic-eks-cluster --region us-east-1 \
     --query 'cluster.status'
   ```

3. Verify all nodes are Ready:
   ```bash
   kubectl get nodes
   ```

### Phase 4: Validate Kubernetes Manifests (if K8s manifests changed)

1. Check all pods in namespace are Running:
   ```bash
   kubectl get pods -n insurance-claims
   ```

2. Check ingress is configured:
   ```bash
   kubectl get ingress -n insurance-claims
   ```

### Phase 5: End-to-End Smoke Test

1. Get the ALB URL:
   ```bash
   ALB_URL=$(kubectl get ingress -n insurance-claims -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
   echo "App URL: http://${ALB_URL}"
   ```

2. Test each portal responds:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://${ALB_URL}/claimant
   curl -s -o /dev/null -w "%{http_code}" http://${ALB_URL}/adjuster
   curl -s -o /dev/null -w "%{http_code}" http://${ALB_URL}/supervisor
   ```

3. Run the validation script:
   ```bash
   ./scripts/validate-deployment.sh
   ```

### Phase 6: Report

```
| Component | Status | Evidence |
|-----------|--------|----------|
| web-interface | ✅ | Image pushed: {timestamp}, 2/2 pods running |
| coordinator | ✅ | Image pushed: {timestamp}, 1/1 pods running |
| Terraform | N/A | No infrastructure changes |
| Ingress | ✅ | ALB URL: {url} |
```

## Rules

- Always verify timestamps — "is the deployed code newer than the CI/CD run?"
- Don't assume deployment succeeded just because CI/CD passed — verify pod status.
- **NEVER delete Kubernetes resources or Terraform resources without explicit approval from The Team.**
- Refer to the user as "The Team".

## Pre-Launch Checklist

### Code Quality
- [ ] All Python tests pass (`python -m pytest tests/ -v`)
- [ ] `terraform plan` shows no unexpected destroy/replace
- [ ] No TODO comments that should be resolved before launch
- [ ] Guard-rails passed

### Security
- [ ] No secrets in code or version control (security-scanner hook)
- [ ] New IAM policies follow least-privilege
- [ ] Auth on all new API endpoints
- [ ] Kubernetes NetworkPolicies updated for new services

### Infrastructure
- [ ] Terraform state is clean (no pending changes)
- [ ] All pods have resource limits/requests set
- [ ] Liveness and readiness probes configured
- [ ] Rollback plan documented

### Rollback Plan Template
```
## Rollback Plan — {Feature}
Trigger: pod crash-loop OR error rate >2x baseline OR ALB health checks failing
Steps:
  1. Kubernetes: kubectl rollout undo deployment/{service} -n insurance-claims
  2. Terraform: git revert + terraform apply (for infra changes)
  3. Feature flag: update ConfigMap and restart pods
Time to rollback: kubectl rollout undo ~2 min | terraform apply ~10 min
```
