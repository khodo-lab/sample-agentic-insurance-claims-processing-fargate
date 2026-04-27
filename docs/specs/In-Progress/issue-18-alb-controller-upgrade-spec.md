# Specification: Upgrade aws-load-balancer-controller (Issue #18)

**Issue:** [#18](https://github.com/khodo-lab/sample-agentic-insurance-claims-processing-fargate/issues/18)  
**Branch:** `feature/issue-18-alb-controller-upgrade`  
**Status:** In Progress — Phase 0 (Research) complete, Phase 1 (Requirements) awaiting approval

---

## 0. Research Findings

### Actual Scope (audited from codebase)

- **File:** `infrastructure/terraform/addons.tf`, lines 124–155
- **Module:** `aws-ia/eks-blueprints-addons/aws` version `~> 1.20`
- **Current config:** `chart_version = "1.8.1"`, image `public.ecr.aws/eks/aws-load-balancer-controller:v2.8.1`
- **EKS cluster:** `agentic-eks-cluster`, Kubernetes 1.33, us-west-2
- **Active ingress:** `insurance-claims-ingress` in namespace `insurance-claims`, serving 4 portals via ALB `insurance-claims-alb`
- **Inspector finding:** OS CVEs in v2.8.1 image, severity Info, status Assigned, owner hodok

### Version Landscape (verified April 2026)

| Version | Helm Chart | Released | Notes |
|---------|-----------|----------|-------|
| v2.8.1 | 1.8.1 | ~mid-2024 | **Current — has OS CVEs** |
| v2.17.1 | 1.17.1 | Jan 2026 | Last v2.x release, patched OS packages |
| v3.0.0 | 3.0.0 | Jan 2026 | Major version — chart version now = controller version |
| v3.2.2 | 3.2.2 | Apr 18, 2026 | **Latest stable** |

**Key fact:** Starting v3.0.0, Helm chart version = controller version (e.g., chart 3.2.2 = controller v3.2.2). Before v3.0.0, chart 1.x.x = controller v2.x.x.

### Recommended Approach

**Upgrade to v2.17.1 (Helm chart 1.17.1)** — the last v2.x release. This is the surgical choice:
- Stays within the v2.x line (no major version risk)
- Patched OS packages resolve the Inspector finding
- No breaking changes to existing Ingress annotations
- No CRD schema changes that require manual pre-apply
- Single-line change to `chart_version` in `addons.tf`

**Why not v3.x?** v3.0.0 introduced Gateway API GA and Helm chart version alignment. While v3.x is backward-compatible for Ingress users, it requires CRD updates (`kubectl apply -k`) and the eks-blueprints-addons module (~> 1.20) may not have been tested against chart 3.x. The v2→v3 jump is a larger change than needed to resolve an OS CVE. Defer to the CDK migration (#2) which will replace this stack entirely.

### Alternatives Considered

| Option | Verdict | Reason |
|--------|---------|--------|
| Bump `chart_version` to `1.17.1` (v2.17.1) | ✅ **Recommended** | Surgical, no breaking changes, resolves CVE |
| Bump to `3.2.2` (v3.x latest) | ⚠️ Defer | Major version, CRD updates required, module compatibility unknown |
| Pin image tag only (`image.tag = "v2.17.1"`) | ❌ Avoid | Version mismatch between chart and image; doesn't update CRDs or chart manifests |
| Do nothing | ❌ | Inspector finding persists; OS CVEs in a controller with broad IAM permissions |

### Edge Cases & Gotchas

- **IAM policy drift (highest risk):** The eks-blueprints-addons module embeds the LBC IAM policy at module install time. Bumping only `chart_version` does NOT update the IRSA policy. Between v2.8.1 and v2.17.1, new IAM actions may have been added. Must diff the IAM policies and add any missing actions via `source_policy_documents` in the `aws_load_balancer_controller` block.
- **CRDs not updated by Helm upgrade:** Helm does not update CRDs on `helm upgrade`. For v2.8.1 → v2.17.1, CRD schema additions (if any) must be applied manually before or after the upgrade. Check the CRD diff between the two versions.
- **No automatic rollback with `atomic=false`:** Current config has `atomic=false`. A failed upgrade leaves the Helm release in `failed` state with no rollback. Have `helm rollback aws-load-balancer-controller -n kube-system` ready.
- **`wait=false` means Terraform reports success before pod is healthy:** After `terraform apply`, manually verify pod status.
- **ALB traffic is NOT disrupted during upgrade:** The ALB is an AWS-managed resource independent of the controller pod. Existing routing continues during the ~30-second controller pod restart.
- **Webhook gap (~30s):** During pod restart, any concurrent Ingress/TargetGroupBinding creates will be rejected. Not a concern for this single-ingress setup.
- **`enableServiceMutatorWebhook=false` must be preserved:** If accidentally re-enabled, it breaks all Service mutations cluster-wide.
- **Inspector finding closure:** The finding on the old image digest does NOT auto-close when a new version is deployed. It closes when the old image is removed from ECR (or after 90 days of inactivity). To actively close it: delete the old image tag from ECR after confirming the new version is healthy.
- **No Inspector SLA for Info severity:** AWS does not impose a deadline. This is a hygiene fix.

### AWS Constraints

- **IAM policy:** Diff `https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.8.1/docs/install/iam_policy.json` vs `v2.17.1` before applying. The eks-blueprints-addons module (~> 1.20) does NOT auto-update the IRSA policy on chart version bump.
- **EKS 1.33 compatibility:** v2.17.1 fully supports Kubernetes 1.22+. No blockers.
- **ECR enhanced scanning:** `public.ecr.aws` images are not scanned by your account's Inspector. To verify the new image is CVE-free: pull to private ECR and scan, or check ECR Public Gallery scan results at https://gallery.ecr.aws/eks/aws-load-balancer-controller.
- **No quota concerns:** Upgrade is a controller pod replacement, not new ALB provisioning.

### Open Questions (resolved by research)

- ✅ **v2.x or v3.x?** → v2.17.1 (last v2.x, surgical, no major version risk)
- ✅ **IAM policy update needed?** → Must diff and patch if new actions added between v2.8.1 and v2.17.1
- ✅ **CRD update needed?** → Check diff; likely minor additions only for v2.8→v2.17
- ✅ **Inspector SLA?** → No AWS-imposed deadline for Info severity

---

## 1. Requirements

### Problem Statement

Amazon Inspector flagged OS-level package CVEs in the `aws-load-balancer-controller:v2.8.1` container image running in `agentic-eks-cluster`. The controller has broad IAM permissions (EC2, ELBv2, ACM, WAF) — OS CVEs in this image represent meaningful blast radius if exploited. The fix is to upgrade to v2.17.1 which has patched OS packages.

### Users

- **Platform team (hodok)** — owns the Inspector finding, responsible for remediation
- **Application users** — must not experience ALB downtime during upgrade

### Functional Requirements

**Must Have:**
- FR-1: Upgrade `aws-load-balancer-controller` from chart `1.8.1` (image v2.8.1) to chart `1.17.1` (image v2.17.1) in `infrastructure/terraform/addons.tf`
- FR-2: Verify and patch the IRSA IAM policy if v2.17.1 requires new IAM actions not present in the current policy
- FR-3: Apply any CRD updates required by chart 1.17.1 before or alongside the Helm upgrade
- FR-4: Confirm the controller pod is Running and healthy after upgrade (no CrashLoopBackOff, no AccessDenied errors in logs)
- FR-5: Confirm all 4 portals remain reachable at the ALB URL after upgrade (smoke test)
- FR-6: Confirm the Inspector finding is addressed (new image deployed; old image removed from ECR to trigger finding closure)

**Should Have:**
- FR-7: Preserve all existing `set[]` values in the `aws_load_balancer_controller` block (especially `enableServiceMutatorWebhook=false`)
- FR-8: Document the upgrade in the spec with before/after versions

**Nice to Have:**
- FR-9: Scan the new image via ECR enhanced scanning before deploying to confirm CVE resolution

### Non-Functional Requirements

- NFR-1: Zero ALB downtime — existing routing must continue during upgrade
- NFR-2: Change is surgical — minimum diff to `addons.tf`, no structural Terraform changes
- NFR-3: CI deploy pipeline passes (terraform plan + apply via GitHub Actions)
- NFR-4: Rollback plan documented and tested (helm rollback command ready)

### Constraints

- IaC is Terraform (not CDK — CDK migration is issue #2, future work)
- eks-blueprints-addons module version stays at `~> 1.20` (no module version bump)
- Must stay on v2.x line (v3.x deferred to CDK migration)
- `atomic=false` and `wait=false` remain (existing config, not changing)

### Integrations

- `infrastructure/terraform/addons.tf` — Helm chart version bump
- AWS IAM — IRSA policy may need supplemental permissions
- Kubernetes CRDs — may need manual pre-apply
- Amazon Inspector — finding closure after old image removed

### Acceptance Criteria

- [ ] `chart_version` in `addons.tf` updated to `1.17.1`
- [ ] IAM policy diff completed; any new actions added via `source_policy_documents`
- [ ] CRD update applied if required
- [ ] `aws-load-balancer-controller` pod Running in `kube-system` with image `v2.17.1`
- [ ] No `AccessDenied` errors in controller logs
- [ ] All 4 portals return HTTP 200 after upgrade
- [ ] Old image `v2.8.1` removed from ECR (or confirmed not present — it's a public image, not in private ECR)
- [ ] CI deploy pipeline passes

---

## ⛔ HARD STOP — Phase 1 Complete

**The Team must review and approve the Requirements section before proceeding to Phase 2 (High-Level Design).**

Key decisions to confirm:
1. **v2.17.1 vs v3.2.2** — do you want the surgical v2.x upgrade, or jump to the latest v3.x?
2. **IAM policy approach** — patch via `source_policy_documents` in the Terraform block, or bump the module version?
3. **CRD update approach** — manual `kubectl apply` step in the task plan, or skip if no schema changes?

Ready to proceed to Phase 2?
