# ADR-20260424-01: Replace LangGraph/Ollama with Strands + Amazon Bedrock AgentCore

## Status
Accepted

## Context
The original application uses LangGraph for multi-agent orchestration and Ollama (Qwen2.5) for local LLM inference, both running as Kubernetes pods. As part of the EKS → Fargate migration, the Ollama pod must be replaced. Ollama on Fargate requires 8+ GB RAM per task and slow model load times (~30s cold start), making it impractical for a serverless deployment.

The team evaluated three options:
1. Keep Ollama on Fargate (large task, expensive, slow cold start)
2. Replace with Amazon Bedrock direct API calls + keep LangGraph
3. Replace with Strands Agents on Amazon Bedrock AgentCore

## Decision
Replace LangGraph and Ollama with **Strands Agents** running on **Amazon Bedrock AgentCore Runtime**, backed by **Claude Sonnet 4.5** (`us.anthropic.claude-sonnet-4-5-20251101-v1:0`) via Amazon Bedrock.

## Consequences

### Pros
- Eliminates the Ollama pod entirely — no GPU/large-memory Fargate task needed
- Strands is a simpler, Python-native framework vs LangGraph's graph DSL
- AgentCore Runtime handles session management, scaling, and observability out of the box
- Claude Sonnet 4.5 is significantly more capable than local Qwen2.5
- Cross-region inference profiles provide automatic failover
- No model weights to manage or update

### Cons
- Bedrock API calls incur per-token cost (vs free local inference)
- AgentCore Runtime has a cold start (~30s) on first invocation per session
- Strands is a newer framework with a smaller community than LangGraph
- Requires `bedrock:InvokeModel` IAM permissions and Bedrock model access enabled in us-west-2

### Maintenance
- Agent logic moves from `langgraph_*_agent.py` files to `agents/*.py` (Strands)
- Model ID managed via SSM Parameter Store — swap models without code changes
- AgentCore Runtime versioned via CDK — rollback is a CDK redeploy
