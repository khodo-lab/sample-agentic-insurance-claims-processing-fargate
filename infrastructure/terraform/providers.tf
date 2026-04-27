###############################################################
# AWS Provider Configuration
###############################################################

provider "aws" {
  region = var.region

  # skip_credentials_validation allows `terraform validate` in CI without real AWS creds
  skip_credentials_validation = true
  skip_requesting_account_id  = true

  default_tags {
    tags = local.base_tags
  }
}

# Virginia provider for ECR Public access
provider "aws" {
  alias  = "virginia"
  region = "us-east-1"

  skip_credentials_validation = true
  skip_requesting_account_id  = true

  default_tags {
    tags = local.base_tags
  }
}

###############################################################
# Kubernetes Provider Configuration
###############################################################

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
  }
}

###############################################################
# Helm Provider Configuration
###############################################################

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", var.region
      ]
    }
  }
}

###############################################################
# Kubectl Provider Configuration
###############################################################

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.region
    ]
  }
}