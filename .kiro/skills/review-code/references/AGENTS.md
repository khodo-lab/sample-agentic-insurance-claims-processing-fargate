## Review Agents

The following specialized review agents are available for `review-code`:

| Agent | Focus | Batch |
|-------|-------|-------|
| `review-security` | Auth, IAM, secrets, encryption, LLM prompt injection | 1 |
| `review-maintainability` | Code organization, naming, DRY, testability | 1 |
| `review-infrastructure` | Terraform patterns, Kubernetes manifests, encryption, cost, monitoring | 1 |
| `review-performance` | Async patterns, MongoDB queries, LangGraph latency, Ollama throughput | 2 |
| `principal-pse` | Architecture decisions, coupling risks, simplicity | 2 |

Max 4 concurrent subagents. Batch 1 runs first (3 agents), then Batch 2 (2 agents).
