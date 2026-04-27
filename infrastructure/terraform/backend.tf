terraform {
  backend "s3" {
    bucket       = "agentic-eks-terraform-state-621967485578"
    key          = "insurance-demo/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true # Requires Terraform >= 1.10
  }
}
