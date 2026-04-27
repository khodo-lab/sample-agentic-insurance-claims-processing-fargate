#!/usr/bin/env bash
# bootstrap-cicd.sh — One-time setup of AWS prerequisites for GitHub Actions CI/CD.
# Idempotent: safe to re-run. Each step checks if the resource already exists.
#
# Prerequisites: AWS CLI configured with admin credentials for account 621967485578
# Usage: ./scripts/bootstrap-cicd.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
AWS_ACCOUNT="621967485578"
AWS_REGION="us-west-2"
STATE_BUCKET="agentic-eks-terraform-state-621967485578"
OIDC_PROVIDER_URL="token.actions.githubusercontent.com"
OIDC_AUDIENCE="sts.amazonaws.com"
ROLE_NAME="github-actions-deploy"
REPO="khodo-lab/sample-agentic-insurance-claims-processing-fargate"
EKS_CLUSTER="agentic-eks-cluster"
MAX_SESSION_DURATION=7200

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[bootstrap]${NC} $*"; }
ok()   { echo -e "${GREEN}[ok]${NC} $*"; }
skip() { echo -e "${YELLOW}[skip]${NC} $*"; }

# ---------------------------------------------------------------------------
# Step 1: S3 state bucket
# ---------------------------------------------------------------------------
log "Step 1: S3 state bucket ($STATE_BUCKET)"

if aws s3api head-bucket --bucket "$STATE_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
    skip "Bucket $STATE_BUCKET already exists"
else
    aws s3api create-bucket \
        --bucket "$STATE_BUCKET" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION"

    aws s3api put-bucket-versioning \
        --bucket "$STATE_BUCKET" \
        --versioning-configuration Status=Enabled

    aws s3api put-bucket-encryption \
        --bucket "$STATE_BUCKET" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'

    aws s3api put-public-access-block \
        --bucket "$STATE_BUCKET" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    ok "Created S3 bucket $STATE_BUCKET with versioning + SSE-S3 + public access block"
fi

# ---------------------------------------------------------------------------
# Step 2: IAM OIDC provider for GitHub Actions
# ---------------------------------------------------------------------------
log "Step 2: IAM OIDC provider ($OIDC_PROVIDER_URL)"

OIDC_ARN="arn:aws:iam::${AWS_ACCOUNT}:oidc-provider/${OIDC_PROVIDER_URL}"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" 2>/dev/null; then
    skip "OIDC provider $OIDC_PROVIDER_URL already exists"
else
    # GitHub's OIDC thumbprint (stable — SHA1 of the root CA)
    THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"

    aws iam create-open-id-connect-provider \
        --url "https://${OIDC_PROVIDER_URL}" \
        --client-id-list "$OIDC_AUDIENCE" \
        --thumbprint-list "$THUMBPRINT"

    ok "Created OIDC provider $OIDC_PROVIDER_URL"
fi

# ---------------------------------------------------------------------------
# Step 3: IAM deploy role
# ---------------------------------------------------------------------------
log "Step 3: IAM role ($ROLE_NAME)"

TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT}:oidc-provider/${OIDC_PROVIDER_URL}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER_URL}:aud": "${OIDC_AUDIENCE}",
          "${OIDC_PROVIDER_URL}:sub": "repo:${REPO}:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF
)

if aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null; then
    skip "IAM role $ROLE_NAME already exists"
else
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --description "GitHub Actions deploy role for $REPO (main branch only)" \
        --max-session-duration "$MAX_SESSION_DURATION"

    ok "Created IAM role $ROLE_NAME"
fi

# ---------------------------------------------------------------------------
# Step 4: Attach permissions policy to deploy role
# ---------------------------------------------------------------------------
log "Step 4: Attaching permissions policy to $ROLE_NAME"

PERMISSIONS_POLICY=$(cat <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EC2AndNetworking",
      "Effect": "Allow",
      "Action": ["ec2:*", "elasticloadbalancing:*", "autoscaling:Describe*"],
      "Resource": "*"
    },
    {
      "Sid": "EKS",
      "Effect": "Allow",
      "Action": ["eks:*"],
      "Resource": "*"
    },
    {
      "Sid": "IAM",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:ListRoles",
        "iam:AttachRolePolicy", "iam:DetachRolePolicy",
        "iam:PutRolePolicy", "iam:DeleteRolePolicy",
        "iam:GetRolePolicy", "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies", "iam:PassRole",
        "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
        "iam:GetInstanceProfile", "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
        "iam:GetOpenIDConnectProvider", "iam:TagOpenIDConnectProvider",
        "iam:TagRole", "iam:UntagRole", "iam:ListRoleTags",
        "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy",
        "iam:GetPolicyVersion", "iam:ListPolicyVersions",
        "iam:CreatePolicyVersion", "iam:DeletePolicyVersion"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SecretsManager",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret",
        "secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue",
        "secretsmanager:DescribeSecret", "secretsmanager:TagResource",
        "secretsmanager:ListSecrets", "secretsmanager:UpdateSecret"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3Backend",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket", "s3:DeleteBucket",
        "s3:GetBucketVersioning", "s3:PutBucketVersioning",
        "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
        "s3:ListBucket", "s3:GetBucketPolicy", "s3:PutBucketPolicy",
        "s3:GetEncryptionConfiguration", "s3:PutEncryptionConfiguration",
        "s3:GetBucketPublicAccessBlock", "s3:PutBucketPublicAccessBlock",
        "s3:GetBucketAcl", "s3:PutBucketAcl",
        "s3:GetBucketCORS", "s3:PutBucketCORS",
        "s3:GetBucketWebsite", "s3:GetBucketLogging",
        "s3:GetBucketRequestPayment", "s3:GetBucketTagging",
        "s3:PutBucketTagging", "s3:GetLifecycleConfiguration",
        "s3:PutLifecycleConfiguration"
      ],
      "Resource": "*"
    },
    {
      "Sid": "KMS",
      "Effect": "Allow",
      "Action": [
        "kms:CreateKey", "kms:DescribeKey", "kms:GetKeyPolicy",
        "kms:PutKeyPolicy", "kms:ScheduleKeyDeletion",
        "kms:CreateAlias", "kms:DeleteAlias", "kms:TagResource",
        "kms:ListAliases", "kms:ListKeys", "kms:EnableKeyRotation",
        "kms:GetKeyRotationStatus", "kms:CreateGrant", "kms:Decrypt",
        "kms:Encrypt", "kms:GenerateDataKey"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Logs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup", "logs:DeleteLogGroup",
        "logs:DescribeLogGroups", "logs:PutRetentionPolicy",
        "logs:TagLogGroup", "logs:ListTagsLogGroup",
        "logs:CreateLogDelivery", "logs:DeleteLogDelivery",
        "logs:DescribeLogStreams", "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECRPrivate",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:CreateRepository", "ecr:DescribeRepositories",
        "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage", "ecr:PutImage",
        "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload", "ecr:PutLifecyclePolicy",
        "ecr:PutImageScanningConfiguration", "ecr:TagResource",
        "ecr:ListTagsForResource", "ecr:DeleteRepository"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECRPublic",
      "Effect": "Allow",
      "Action": [
        "ecr-public:GetAuthorizationToken",
        "ecr-public:BatchCheckLayerAvailability",
        "ecr-public:GetRepositoryPolicy",
        "ecr-public:DescribeRepositories",
        "ecr-public:DescribeImageTags",
        "ecr-public:DescribeImages",
        "ecr-public:GetRepositoryCatalogData"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ACM",
      "Effect": "Allow",
      "Action": [
        "acm:RequestCertificate", "acm:DescribeCertificate",
        "acm:DeleteCertificate", "acm:ListCertificates",
        "acm:AddTagsToCertificate"
      ],
      "Resource": "*"
    },
    {
      "Sid": "WAF",
      "Effect": "Allow",
      "Action": [
        "wafv2:CreateWebACL", "wafv2:DeleteWebACL",
        "wafv2:GetWebACL", "wafv2:UpdateWebACL",
        "wafv2:ListWebACLs", "wafv2:TagResource",
        "wafv2:AssociateWebACL", "wafv2:DisassociateWebACL",
        "wafv2:GetWebACLForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "STS",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity",
        "sts:AssumeRole",
        "sts:TagSession"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

# Check if policy already attached
EXISTING_POLICIES=$(aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames' --output text 2>/dev/null || echo "")

if echo "$EXISTING_POLICIES" | grep -q "deploy-permissions"; then
    skip "Permissions policy already attached to $ROLE_NAME"
else
    aws iam put-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name "deploy-permissions" \
        --policy-document "$PERMISSIONS_POLICY"

    ok "Attached permissions policy to $ROLE_NAME"
fi

# ---------------------------------------------------------------------------
# Step 5: Update MaxSessionDuration (idempotent)
# ---------------------------------------------------------------------------
log "Step 5: Setting MaxSessionDuration to ${MAX_SESSION_DURATION}s"

aws iam update-role \
    --role-name "$ROLE_NAME" \
    --max-session-duration "$MAX_SESSION_DURATION"

ok "MaxSessionDuration set to ${MAX_SESSION_DURATION}s"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Bootstrap complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Resources created/verified:"
echo "  S3 bucket:     s3://${STATE_BUCKET}"
echo "  OIDC provider: ${OIDC_PROVIDER_URL}"
echo "  IAM role:      arn:aws:iam::${AWS_ACCOUNT}:role/${ROLE_NAME}"
echo ""
echo -e "${YELLOW}MANUAL STEP REQUIRED (after EKS cluster exists):${NC}"
echo ""
echo "  # Grant the deploy role access to the EKS cluster:"
echo "  aws eks create-access-entry \\"
echo "    --cluster-name ${EKS_CLUSTER} \\"
echo "    --principal-arn arn:aws:iam::${AWS_ACCOUNT}:role/${ROLE_NAME} \\"
echo "    --type STANDARD \\"
echo "    --region ${AWS_REGION}"
echo ""
echo "  aws eks associate-access-policy \\"
echo "    --cluster-name ${EKS_CLUSTER} \\"
echo "    --principal-arn arn:aws:iam::${AWS_ACCOUNT}:role/${ROLE_NAME} \\"
echo "    --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \\"
echo "    --access-scope type=cluster \\"
echo "    --region ${AWS_REGION}"
echo ""
echo "  # Verify:"
echo "  aws eks list-access-entries --cluster-name ${EKS_CLUSTER} --region ${AWS_REGION}"
echo ""
echo "Next: Push to main to trigger the deploy workflow."
