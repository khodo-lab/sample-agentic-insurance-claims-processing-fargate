#!/usr/bin/env bash
# teardown.sh — EKS cluster teardown for issue #25
# Usage: ./scripts/teardown.sh [--pre-drain | --destroy | --post-cleanup | --verify | --all]
#
# Phases:
#   --pre-drain    Delete K8s Ingress/workloads/NodePools to unblock VPC deletion
#   --destroy      Run terraform destroy (requires pre-drain to have completed)
#   --post-cleanup Delete ECR repos and orphaned CloudWatch log groups
#   --verify       Confirm no orphaned resources remain
#   --all          Run all phases in sequence (interactive confirmation between phases)
#
# PRESERVED (never touched):
#   - IAM role: github-actions-deploy
#   - OIDC provider: token.actions.githubusercontent.com
#   - S3 bucket: agentic-eks-terraform-state-<account>

set -euo pipefail

CLUSTER="agentic-eks-cluster"
REGION="us-west-2"
NAMESPACE="insurance-claims"
TF_DIR="$(cd "$(dirname "$0")/../infrastructure/terraform" && pwd)"
KUBECTL="$(cd "$(dirname "$0")/.." && pwd)/kubectl"

# Fall back to system kubectl if local binary not present
if [[ ! -x "$KUBECTL" ]]; then
  KUBECTL="kubectl"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}==>${NC} $*"; }
warn() { echo -e "${YELLOW}WARN:${NC} $*"; }
die()  { echo -e "${RED}ERROR:${NC} $*" >&2; exit 1; }

confirm() {
  read -r -p "$1 [y/N] " response
  [[ "$response" =~ ^[Yy]$ ]] || die "Aborted."
}

# Validate AWS credentials and return account ID
get_account_id() {
  local ACCOUNT
  ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null) || \
    die "AWS credentials invalid or expired. Run: mwinit -s"
  echo "$ACCOUNT"
}

# ---------------------------------------------------------------------------
phase_pre_drain() {
  log "Phase 1: Pre-drain — removing K8s resources outside Terraform state"

  local ACCOUNT
  ACCOUNT=$(get_account_id)
  log "AWS account: $ACCOUNT, region: $REGION"

  log "Updating kubeconfig..."
  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

  # IMPORTANT: Delete Ingress FIRST so ALB controller (in kube-system) is still
  # running when it processes the deletion and calls elbv2:DeleteLoadBalancer.
  # Deleting the namespace first garbage-collects Ingress objects without giving
  # the controller a clean reconcile, leaving an orphaned ALB that blocks VPC deletion.
  log "Deleting Ingress objects FIRST (ALB controller must be alive to delete the ALB)..."
  "$KUBECTL" delete ingress --all -A --wait=true --timeout=60s 2>/dev/null || \
    warn "No Ingress objects found"

  log "Waiting for ALB deletion (max 4 min)..."
  for i in $(seq 1 24); do
    COUNT=$(aws elbv2 describe-load-balancers --region "$REGION" \
      --query "length(LoadBalancers[?contains(LoadBalancerName,'k8s') || contains(LoadBalancerName,'insurance') || contains(LoadBalancerName,'langgraph')])" \
      --output text 2>/dev/null || echo "0")
    if [[ "$COUNT" -eq 0 ]]; then
      log "ALB deleted."
      break
    fi
    echo "  Waiting for $COUNT ALB(s) to be deleted by ALB controller... ($i/24)"
    sleep 10
    [[ "$i" -eq 24 ]] && die "ALB not deleted after 4 min. Check ALB controller logs: kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller"
  done

  log "Deleting namespace $NAMESPACE (releases PVCs → EBS volumes deleted by EBS CSI)..."
  "$KUBECTL" delete namespace "$NAMESPACE" --wait=true --timeout=180s 2>/dev/null || \
    warn "Namespace $NAMESPACE not found or already deleted"

  log "Deleting Karpenter NodePools..."
  "$KUBECTL" delete nodepool --all --wait=true --timeout=300s 2>/dev/null || \
    warn "No NodePools found"

  log "Deleting Karpenter EC2NodeClasses..."
  "$KUBECTL" delete ec2nodeclass --all --wait=true --timeout=60s 2>/dev/null || \
    warn "No EC2NodeClasses found"

  log "Waiting for Karpenter-provisioned EC2 nodes to terminate (max 5 min)..."
  # Use karpenter.sh/nodepool tag — NOT karpenter.sh/discovery, which is also
  # applied to managed node group instances via the node security group.
  for i in $(seq 1 30); do
    COUNT=$(aws ec2 describe-instances --region "$REGION" \
      --filters \
        "Name=tag-key,Values=karpenter.sh/nodepool" \
        "Name=instance-state-name,Values=running,pending,stopping,shutting-down" \
      --query 'length(Reservations[*].Instances[*])' --output text 2>/dev/null || echo "0")
    if [[ "$COUNT" -eq 0 ]]; then
      log "All Karpenter nodes terminated."
      break
    fi
    echo "  Waiting for $COUNT Karpenter node(s)... ($i/30)"
    sleep 10
    [[ "$i" -eq 30 ]] && die "Karpenter nodes did not terminate in time. Check AWS console."
  done

  log "Pre-drain complete. Verifying no blockers remain..."
  KARPENTER_NODES=$(aws ec2 describe-instances --region "$REGION" \
    --filters \
      "Name=tag-key,Values=karpenter.sh/nodepool" \
      "Name=instance-state-name,Values=running,pending" \
    --query 'length(Reservations[*].Instances[*])' --output text 2>/dev/null || echo "0")
  ALB_COUNT=$(aws elbv2 describe-load-balancers --region "$REGION" \
    --query "length(LoadBalancers[?contains(LoadBalancerName,'k8s') || contains(LoadBalancerName,'insurance') || contains(LoadBalancerName,'langgraph')])" \
    --output text 2>/dev/null || echo "0")

  echo ""
  echo "  Karpenter EC2 nodes remaining: $KARPENTER_NODES (want: 0)"
  echo "  ALBs remaining:                $ALB_COUNT (want: 0)"
  echo ""

  [[ "$KARPENTER_NODES" -eq 0 && "$ALB_COUNT" -eq 0 ]] || \
    die "Blockers remain. Resolve before running --destroy."

  log "Pre-drain PASSED. Safe to run --destroy."
}

# ---------------------------------------------------------------------------
phase_destroy() {
  log "Phase 2: terraform destroy"

  local ACCOUNT
  ACCOUNT=$(get_account_id)
  local STATE_BUCKET="agentic-eks-terraform-state-${ACCOUNT}"

  # Safety check: confirm preserved resources are NOT in TF state
  log "Verifying preserved resources are not in Terraform state..."
  cd "$TF_DIR"

  # Check TF state list for any resource referencing the GitHub OIDC provider
  OIDC_IN_STATE=$(terraform state list 2>/dev/null | grep "token.actions.githubusercontent.com" || true)
  [[ -z "$OIDC_IN_STATE" ]] || die "GitHub OIDC provider found in TF state — STOP. Do not destroy."

  # Check TF state list for github-actions-deploy role
  DEPLOY_ROLE_IN_STATE=$(terraform state list 2>/dev/null | grep "github-actions-deploy" || true)
  [[ -z "$DEPLOY_ROLE_IN_STATE" ]] || die "github-actions-deploy role found in TF state — STOP. Do not destroy."

  # Belt-and-suspenders: verify preserved resources still exist via AWS API
  aws iam get-role --role-name github-actions-deploy --query 'Role.RoleName' --output text > /dev/null || \
    die "github-actions-deploy role not found in AWS — unexpected state."
  aws s3 ls "s3://${STATE_BUCKET}" --region "$REGION" > /dev/null 2>&1 || \
    die "State bucket ${STATE_BUCKET} not accessible — unexpected state."

  log "Safety check passed — preserved resources not in state and verified to exist."

  log "Running terraform plan -destroy..."
  terraform plan -destroy -var-file=terraform.tfvars -out=destroy.plan

  echo ""
  warn "⚠️  REVIEW THE PLAN ABOVE before proceeding."
  warn "    Confirm: github-actions-deploy NOT in plan"
  warn "    Confirm: ${STATE_BUCKET} NOT in plan"
  echo ""
  confirm "Apply destroy plan?"

  log "Running terraform apply destroy.plan (timeout: 30 min)..."
  timeout 1800 terraform apply destroy.plan || {
    EXIT=$?
    rm -f destroy.plan
    [[ $EXIT -eq 124 ]] && die "terraform apply timed out after 30 min. Check AWS console for stuck resources."
    die "terraform apply failed with exit code $EXIT."
  }

  rm -f destroy.plan
  log "terraform destroy complete."
}

# ---------------------------------------------------------------------------
phase_post_cleanup() {
  log "Phase 3: Post-destroy cleanup"

  get_account_id > /dev/null  # validate credentials

  log "Deleting ECR repositories..."
  ECR_REPOS=$(aws ecr describe-repositories --region "$REGION" \
    --query 'repositories[?starts_with(repositoryName,`insurance-claims`)].repositoryName' \
    --output text 2>/dev/null || true)

  if [[ -z "$ECR_REPOS" ]]; then
    warn "No insurance-claims ECR repos found (already deleted?)"
  else
    for REPO in $ECR_REPOS; do
      log "  Deleting ECR repo: $REPO"
      aws ecr delete-repository --repository-name "$REPO" --force --region "$REGION" 2>/dev/null || \
        warn "  Could not delete $REPO (may already be gone)"
    done
  fi

  log "Deleting orphaned CloudWatch log groups..."
  for LG in \
    "/aws/eks/${CLUSTER}/cluster" \
    "/aws/eks/${CLUSTER}/langgraph"; do
    aws logs delete-log-group --log-group-name "$LG" --region "$REGION" 2>/dev/null && \
      log "  Deleted: $LG" || warn "  Not found (already deleted?): $LG"
  done

  log "Post-cleanup complete."
}

# ---------------------------------------------------------------------------
phase_verify() {
  log "Phase 4: Verification"
  local PASS=0
  local FAIL=0

  check() {
    local DESC="$1"
    local RESULT="$2"
    local WANT="$3"  # "empty" or "exists"
    if [[ "$WANT" == "empty" && -z "$RESULT" ]]; then
      echo -e "  ${GREEN}✓${NC} $DESC"
      PASS=$(( PASS + 1 ))
    elif [[ "$WANT" == "exists" && -n "$RESULT" ]]; then
      echo -e "  ${GREEN}✓${NC} $DESC"
      PASS=$(( PASS + 1 ))
    else
      echo -e "  ${RED}✗${NC} $DESC (got: ${RESULT:-<empty>})"
      FAIL=$(( FAIL + 1 ))
    fi
  }

  local ACCOUNT
  ACCOUNT=$(get_account_id)
  local STATE_BUCKET="agentic-eks-terraform-state-${ACCOUNT}"

  echo ""
  echo "=== Acceptance Criteria ==="

  check "EKS cluster deleted" \
    "$(aws eks describe-cluster --name "$CLUSTER" --region "$REGION" 2>&1 | grep -i 'not found\|ResourceNotFoundException\|error' || true)" \
    "exists"

  check "No Karpenter EC2 nodes running" \
    "$(aws ec2 describe-instances --region "$REGION" \
      --filters "Name=tag-key,Values=karpenter.sh/nodepool" "Name=instance-state-name,Values=running,pending" \
      --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null || true)" \
    "empty"

  check "No orphaned ALBs (k8s/insurance/langgraph)" \
    "$(aws elbv2 describe-load-balancers --region "$REGION" \
      --query "LoadBalancers[?contains(LoadBalancerName,'k8s') || contains(LoadBalancerName,'insurance') || contains(LoadBalancerName,'langgraph')].LoadBalancerArn" \
      --output text 2>/dev/null || true)" \
    "empty"

  check "No VPC with agentic tag" \
    "$(aws ec2 describe-vpcs --region "$REGION" \
      --filters "Name=tag:Name,Values=*agentic*" \
      --query 'Vpcs[*].VpcId' --output text 2>/dev/null || true)" \
    "empty"

  check "No orphaned EBS volumes (kubernetes-owned)" \
    "$(aws ec2 describe-volumes --region "$REGION" \
      --filters "Name=tag:kubernetes.io/cluster/$CLUSTER,Values=owned" "Name=status,Values=available" \
      --query 'Volumes[*].VolumeId' --output text 2>/dev/null || true)" \
    "empty"

  check "No ECR repos for insurance-claims" \
    "$(aws ecr describe-repositories --region "$REGION" \
      --query 'repositories[?starts_with(repositoryName,`insurance-claims`)].repositoryName' \
      --output text 2>/dev/null || true)" \
    "empty"

  check "No orphaned CW log group /aws/eks/$CLUSTER/cluster" \
    "$(aws logs describe-log-groups --region "$REGION" \
      --log-group-name-prefix "/aws/eks/$CLUSTER/cluster" \
      --query 'logGroups[*].logGroupName' --output text 2>/dev/null || true)" \
    "empty"

  check "github-actions-deploy role preserved" \
    "$(aws iam get-role --role-name github-actions-deploy --query 'Role.RoleName' --output text 2>/dev/null || true)" \
    "exists"

  check "GitHub OIDC provider preserved" \
    "$(aws iam get-open-id-connect-provider \
      --open-id-connect-provider-arn "arn:aws:iam::${ACCOUNT}:oidc-provider/token.actions.githubusercontent.com" \
      --query 'Url' --output text 2>/dev/null || true)" \
    "exists"

  check "Terraform state bucket preserved" \
    "$(aws s3 ls "s3://${STATE_BUCKET}" --region "$REGION" 2>/dev/null | head -1 || true)" \
    "exists"

  echo ""
  echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
  echo ""

  [[ "$FAIL" -eq 0 ]] && log "All acceptance criteria PASSED." || warn "$FAIL check(s) failed — review above."
  return "$FAIL"
}

# ---------------------------------------------------------------------------
usage() {
  echo "Usage: $0 [--pre-drain | --destroy | --post-cleanup | --verify | --all]"
  echo ""
  echo "  --pre-drain    Delete K8s Ingress/workloads/NodePools (run first)"
  echo "  --destroy      terraform plan -destroy + apply (requires pre-drain)"
  echo "  --post-cleanup Delete ECR repos + orphaned CloudWatch log groups"
  echo "  --verify       Check all acceptance criteria"
  echo "  --all          Run all phases with confirmation prompts"
  exit 1
}

[[ $# -eq 0 ]] && usage

case "$1" in
  --pre-drain)    phase_pre_drain ;;
  --destroy)      phase_destroy ;;
  --post-cleanup) phase_post_cleanup ;;
  --verify)       phase_verify ;;
  --all)
    phase_pre_drain
    echo ""
    confirm "Pre-drain complete. Proceed to terraform destroy?"
    phase_destroy
    echo ""
    confirm "Destroy complete. Proceed to post-cleanup (deletes ECR repos — irreversible)?"
    phase_post_cleanup
    echo ""
    phase_verify
    ;;
  *) usage ;;
esac
