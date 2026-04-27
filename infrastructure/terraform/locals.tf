###############################################################
# Local Values
###############################################################

locals {
  # Shortened naming convention: {project}-{environment}
  name = "${var.project_name}-${var.environment}"

  # EKS cluster name - use existing cluster name to prevent recreation
  cluster_name = "agentic-eks-cluster"


  # Availability zones
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # Base tags applied to all resources via provider default_tags (no k8s-specific keys)
  base_tags = {
    Project     = var.project_name
    Environment = var.environment
    Region      = var.region
    ManagedBy   = "terraform"
    Purpose     = "insurance-agentic-ai"
    Owner       = "platform-team"
    CostCenter  = "ai-ml"
    UniqueId    = random_string.cluster_suffix.result
  }

  # Full tags including EKS and Karpenter discovery tags (use on EKS/Karpenter resources only)
  tags = merge(local.base_tags, {
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    "karpenter.sh/discovery"                      = local.cluster_name
  })

  # Tags safe for Secrets Manager (strips k8s tags — SM rejects keys with '/' or '.')
  secret_tags = local.base_tags


}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}


# Random suffix for unique naming
resource "random_string" "cluster_suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = true
  lower   = true
}
