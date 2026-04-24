# Project Structure

## Repository Organization

```
sample-agentic-insurance-claims-processing-fargate/
├── README.md
├── ARCHITECTURE.md
├── DEMO_GUIDE.md
├── SECURITY.md
├── config.env.example                # Environment variable template
├── scripts/
│   ├── deploy.sh                     # One-command full deploy
│   ├── deploy-all.sh                 # Deploy all components
│   ├── build-docker-images.sh        # Build + push ECR images
│   ├── deploy-kubernetes.sh          # Apply K8s manifests
│   ├── deploy-infrastructure.sh      # Terraform apply
│   ├── load-data.sh                  # Load sample policies + claims
│   ├── validate-deployment.sh        # Post-deploy validation
│   ├── validate-infrastructure.sh    # Infrastructure validation
│   └── demo.sh                       # Interactive demo script
├── applications/
│   ├── shared/                       # Shared Python modules
│   │   ├── authentic_llm_integration.py
│   │   ├── agent_negotiation_protocol.py
│   │   ├── observability.py
│   │   └── dynamic_workflow_engine.py
│   └── insurance-claims-processing/
│       ├── src/
│       │   ├── web_interface.py              # Main FastAPI app
│       │   ├── persona_web_interface.py      # Portal-specific logic
│       │   ├── langgraph_agentic_coordinator.py  # Multi-agent coordinator
│       │   ├── langgraph_fraud_agent.py      # Fraud detection agent
│       │   ├── langgraph_policy_agent.py     # Policy verification agent
│       │   ├── langgraph_investigation_agent.py  # SIU investigation agent
│       │   ├── langgraph_shared_memory.py    # Redis-backed shared state
│       │   ├── database_models.py            # MongoDB models (Pydantic)
│       │   ├── enhanced_models.py            # Extended data models
│       │   ├── human_workflow_manager.py     # Human-in-the-loop logic
│       │   ├── real_time_claims_simulator.py # Demo data generator
│       │   ├── data_loader.py                # Seed data loader
│       │   ├── templates/                    # Jinja2 HTML templates
│       │   │   ├── claimant_portal.html
│       │   │   ├── adjuster_dashboard.html
│       │   │   └── claim_detail.html
│       │   ├── static/                       # CSS + JS assets
│       │   │   ├── css/style.css
│       │   │   └── js/main.js
│       │   ├── shared/                       # App-level shared modules
│       │   ├── external_integrations/        # Third-party API clients
│       │   └── analytics/                    # Actuarial models
│       ├── docker/                           # Dockerfiles per service
│       ├── data/                             # Sample data files
│       ├── requirements-langgraph.txt        # LangGraph + FastAPI deps
│       ├── requirements-analytics.txt        # Analytics deps
│       └── requirements-production.txt       # Production deps
├── infrastructure/
│   ├── terraform/                    # Terraform IaC
│   │   ├── eks.tf                    # EKS cluster
│   │   ├── vpc.tf                    # VPC + networking
│   │   ├── addons.tf                 # EKS addons
│   │   ├── karpenter-nodepools.tf    # Node auto-scaling
│   │   ├── secrets-manager.tf        # Secrets
│   │   ├── storage.tf                # S3
│   │   ├── iam.tf                    # IAM roles
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── backend.tf                # Remote state
│   │   └── terraform.tfvars          # Environment values
│   ├── kubernetes/                   # K8s manifests
│   │   ├── insurance-claims-processing/  # App deployments
│   │   ├── coordinator.yaml
│   │   ├── claims-web-interface.yaml
│   │   ├── claims-simulator.yaml
│   │   ├── policy-agent.yaml
│   │   ├── mongodb-deployment.yaml
│   │   ├── redis-deployment.yaml
│   │   ├── ollama-deployment.yaml
│   │   ├── external-secrets.yaml
│   │   ├── network-policies.yaml
│   │   ├── insurance-claims-ingress.yaml
│   │   └── cloudwatch-observability.yaml
│   └── performance/                  # Load testing configs
├── tests/
│   ├── comprehensive-e2e-demo.sh
│   ├── demo-insurance.sh
│   ├── agentic-patterns-demo.py
│   └── README.md
├── docs/
│   ├── DEPLOYMENT_GUIDE.md
│   ├── INFRASTRUCTURE_SETUP.md
│   ├── PRODUCTION_DEPLOYMENT.md
│   ├── SECRETS_MANAGEMENT.md
│   ├── LANGGRAPH_AGENTIC_README.md
│   ├── INSURANCE_CLAIMS_PROCESSING.md
│   └── ...
└── .kiro/                            # Kiro configuration
    ├── steering/                     # Always-loaded context files
    ├── agents/                       # Agent definitions + prompts
    ├── skills/                       # Skill definitions
    ├── hooks/                        # Automation hooks
    ├── context/                      # Session state (gitignored)
    └── telemetry/                    # Skill execution logs (gitignored)
```

## Key Conventions

### Naming Patterns
- **Python modules**: `snake_case.py` (e.g., `langgraph_fraud_agent.py`)
- **LangGraph agents**: `langgraph_{name}_agent.py`
- **Terraform files**: `{resource_type}.tf` (e.g., `eks.tf`, `vpc.tf`)
- **Kubernetes manifests**: `{app-name}-deployment.yaml` or `{app-name}.yaml`
- **Docker images**: `insurance-claims-{service}` (e.g., `insurance-claims-web`, `insurance-claims-coordinator`)

### Configuration Sources
- **Kubernetes ConfigMaps**: Non-sensitive runtime config (model names, feature flags)
- **AWS Secrets Manager** (via ExternalSecrets): MongoDB URI, API keys, credentials
- **`config.env`** (local dev only, gitignored): Local environment overrides
- **`terraform.tfvars`**: Terraform input variables (gitignored for sensitive values)

### Documentation
- **Specs**: `docs/specs/In-Progress/{feature-name}-tasks.md`
- **ADRs**: `docs/adr/{YYYYMMDD}-{kebab-case-description}.md`
- **Reviews**: `docs/reviews/review-{DATE}-{description}.md` (gitignored)

### Test Structure
- **Unit tests**: `applications/insurance-claims-processing/tests/`
- **E2E tests**: `tests/` (shell scripts + Python)
- **Load tests**: `infrastructure/performance/`

### GitHub CI/CD Structure
- `.github/workflows/` defines CI/CD pipelines
- OIDC trust with AWS — no long-lived credentials stored in GitHub secrets
- Stages: `lint` → `test` → `terraform-plan` → `build` → `deploy`
