# Product Overview

**AI-Powered Insurance Claims Processing** — a production-ready multi-agent AI system on AWS EKS that automates insurance claims adjudication with intelligent fraud detection.

## What It Does

- Accepts insurance claims from policyholders via the Claimant Portal
- Automatically processes claims through a LangGraph multi-agent pipeline (policy verification, fraud detection, risk scoring)
- Provides adjusters with AI-generated risk assessments and recommendations
- Enables SIU (Special Investigations Unit) investigators to flag and escalate fraud cases
- Gives supervisors real-time business KPIs and analytics dashboards

## Key Portals

| Portal | Path | Users | Purpose |
|--------|------|-------|---------|
| **Claimant** | `/claimant` | Policyholders | Submit claims, upload documents, track status |
| **Adjuster** | `/adjuster` | Claims adjusters | Review AI assessments, approve/deny claims |
| **SIU** | `/siu` | Fraud investigators | Investigate flagged claims, escalate cases |
| **Supervisor** | `/supervisor` | Management | Business KPIs, fraud analytics, performance metrics |

## AI Agent Architecture

- **Coordinator** (`langgraph_agentic_coordinator.py`): Orchestrates the full claims processing pipeline
- **Policy Agent** (`langgraph_policy_agent.py`): Verifies policy coverage and eligibility
- **Fraud Agent** (`langgraph_fraud_agent.py`): ML-driven fraud risk scoring with explainable AI
- **Investigation Agent** (`langgraph_investigation_agent.py`): Deep-dive analysis for SIU cases
- **Claims Simulator** (`real_time_claims_simulator.py`): Generates realistic test claims for demos

## Key Business KPIs

- **Loss Ratio**: Incurred Losses / Earned Premiums (target: <70%)
- **Fraud Detection Rate**: 10-15% (industry standard)
- **AI Accuracy**: 94.7% fraud detection accuracy
- **Processing Time**: 2.3 min average (target: <3 min)
- **Throughput**: 1000+ claims/day

## Architecture Principles

- Multi-agent LangGraph pipeline — each agent has a single responsibility
- Human-in-the-loop — adjusters can override AI decisions at any point
- Explainable AI — fraud scores include reasoning, not just a number
- Cloud-native — Kubernetes-first, auto-scaling via Karpenter
- Security-first — RBAC, network policies, secrets via AWS Secrets Manager
- Local LLM inference — Ollama (Qwen2.5) runs in-cluster, no external API dependency

## Demo Scenarios

1. **Standard Claim**: Auto claim → policy verified → low fraud risk → auto-approved
2. **Fraud Detection**: Suspicious claim → high fraud score → SIU escalation → investigation
3. **Human Override**: Borderline claim → adjuster reviews AI recommendation → manual decision
4. **Supervisor Dashboard**: Real-time KPIs, fraud analytics, processing metrics
