# ADR-20260424-04: Migrate from Terraform to AWS CDK (TypeScript)

## Status
Accepted

## Context
The application uses Terraform for infrastructure as code. Terraform requires separate remote state management (S3 bucket + DynamoDB lock table), manual `terraform init` on each machine, and a separate HCL language from the application code. As the team adds new AWS services (Fargate, DynamoDB, AgentCore), the CDK ecosystem provides tighter integration and type safety.

## Decision
Replace Terraform with **AWS CDK v2 (TypeScript)**. Infrastructure lives in `infrastructure/cdk/` as a TypeScript CDK app with four stacks: `NetworkingStack`, `DataStack`, `ComputeStack`, `ObservabilityStack`.

## Consequences

### Pros
- TypeScript CDK gives compile-time safety — invalid resource configurations caught at `cdk synth`
- No separate state backend to manage — CloudFormation handles state
- `cdk deploy` integrates directly with GitHub Actions via OIDC (no Terraform Cloud or S3 state bucket needed)
- CDK constructs for ECS, DynamoDB, ElastiCache, and AgentCore are well-maintained
- `cdk diff` shows exact CloudFormation changes before deploy

### Cons
- CDK synthesizes CloudFormation — CloudFormation deploy is slower than Terraform apply for large stacks
- CDK bootstrap must be run once per account/region (`cdk bootstrap aws://597088050001/us-west-2`)
- TypeScript adds a build step (`tsc`) before `cdk synth`
- CDK L1 constructs (raw CloudFormation) are verbose; L2/L3 constructs may not cover all resources

### Maintenance
- `infrastructure/terraform/` deleted; all IaC in `infrastructure/cdk/`
- CDK app entry point: `infrastructure/cdk/bin/app.ts`
- Stack outputs (ALB URL, ECR repo URIs) exported as CloudFormation outputs and SSM parameters
- `cdk.context.json` committed to repo for deterministic synth
