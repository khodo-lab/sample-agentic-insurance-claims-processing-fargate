"""
Tests for CI/CD infrastructure files (Issue #7).

These tests validate:
- Terraform backend.tf has use_lockfile = true
- versions.tf requires >= 1.10 and has no stale backend comment
- bootstrap-cicd.sh is executable and contains required logic
- ci.yml is valid YAML with required jobs
- deploy.yml is valid YAML with required jobs and OIDC config
"""
import os
import re
import stat
import yaml
import pytest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
TERRAFORM_DIR = os.path.join(REPO_ROOT, "infrastructure", "terraform")
SCRIPTS_DIR = os.path.join(REPO_ROOT, "scripts")
WORKFLOWS_DIR = os.path.join(REPO_ROOT, ".github", "workflows")


# ---------------------------------------------------------------------------
# Task 1: Terraform backend.tf + versions.tf
# ---------------------------------------------------------------------------

class TestBackendTf:
    def _read(self):
        with open(os.path.join(TERRAFORM_DIR, "backend.tf")) as f:
            return f.read()

    def test_use_lockfile_present(self):
        """backend.tf must contain use_lockfile = true for state locking."""
        assert "use_lockfile" in self._read(), "use_lockfile missing from backend.tf"

    def test_use_lockfile_is_true(self):
        content = self._read()
        assert re.search(r'use_lockfile\s*=\s*true', content), \
            "use_lockfile must be set to true"

    def test_bucket_unchanged(self):
        assert "agentic-eks-terraform-state" in self._read()

    def test_region_unchanged(self):
        assert "us-west-2" in self._read()


class TestVersionsTf:
    def _read(self):
        with open(os.path.join(TERRAFORM_DIR, "versions.tf")) as f:
            return f.read()

    def test_required_version_at_least_1_10(self):
        """versions.tf must require Terraform >= 1.10 for use_lockfile support."""
        content = self._read()
        match = re.search(r'required_version\s*=\s*"([^"]+)"', content)
        assert match, "required_version not found in versions.tf"
        version_constraint = match.group(1)
        # Must not still be >= 1.9 only
        assert ">= 1.9\"" not in content or ">= 1.10" in content, \
            f"required_version must be >= 1.10, got: {version_constraint}"
        assert "1.10" in version_constraint or "1.1" in version_constraint, \
            f"required_version must be >= 1.10, got: {version_constraint}"

    def test_no_stale_backend_comment(self):
        """Stale commented-out backend block referencing old bucket must be removed."""
        content = self._read()
        assert "langgraph-insurance-terraform-state" not in content, \
            "Stale backend comment referencing old bucket must be removed"
        assert "langgraph-insurance-terraform-lock" not in content, \
            "Stale DynamoDB lock table reference must be removed"

    def test_no_duplicate_terraform_block(self):
        """versions.tf must not have two terraform {} blocks (backend.tf has one)."""
        content = self._read()
        # The stale commented-out backend block inside versions.tf terraform{} is gone
        # Count uncommented backend blocks
        uncommented_backend = re.findall(r'^\s*backend\s+"s3"', content, re.MULTILINE)
        assert len(uncommented_backend) == 0, \
            "versions.tf must not contain an uncommented backend block (it belongs in backend.tf)"

    def test_has_closing_brace(self):
        """versions.tf terraform block must be properly closed."""
        content = self._read()
        # Count opening and closing braces — they must balance
        opens = content.count('{')
        closes = content.count('}')
        assert opens == closes, \
            f"versions.tf has unbalanced braces: {opens} open, {closes} close"


# ---------------------------------------------------------------------------
# Task 2: bootstrap-cicd.sh
# ---------------------------------------------------------------------------

class TestBootstrapScript:
    def _path(self):
        return os.path.join(SCRIPTS_DIR, "bootstrap-cicd.sh")

    def _read(self):
        with open(self._path()) as f:
            return f.read()

    def test_file_exists(self):
        assert os.path.exists(self._path()), "bootstrap-cicd.sh must exist"

    def test_is_executable(self):
        mode = os.stat(self._path()).st_mode
        assert mode & stat.S_IXUSR, "bootstrap-cicd.sh must be executable"

    def test_has_shebang(self):
        with open(self._path()) as f:
            first_line = f.readline()
        assert first_line.startswith("#!/"), "bootstrap-cicd.sh must have a shebang"

    def test_creates_s3_bucket(self):
        content = self._read()
        assert "agentic-eks-terraform-state" in content, \
            "bootstrap script must reference the S3 state bucket"
        assert "aws s3" in content or "s3api" in content, \
            "bootstrap script must create S3 bucket"

    def test_creates_oidc_provider(self):
        content = self._read()
        assert "token.actions.githubusercontent.com" in content, \
            "bootstrap script must create OIDC provider for GitHub Actions"
        assert "create-open-id-connect-provider" in content or \
               "oidc" in content.lower(), \
            "bootstrap script must create OIDC provider"

    def test_creates_iam_role(self):
        content = self._read()
        assert "github-actions-deploy" in content, \
            "bootstrap script must create github-actions-deploy IAM role"
        assert "create-role" in content, \
            "bootstrap script must call aws iam create-role"

    def test_trust_policy_scoped_to_main(self):
        content = self._read()
        assert "ref:refs/heads/main" in content, \
            "Trust policy must be scoped to main branch only"

    def test_correct_account_id(self):
        content = self._read()
        assert "621967485578" in content, \
            "bootstrap script must use workshop account ID 621967485578"

    def test_max_session_duration_7200(self):
        content = self._read()
        assert "7200" in content, \
            "IAM role MaxSessionDuration must be set to 7200 seconds"

    def test_idempotent_s3_check(self):
        content = self._read()
        # Script should check if bucket exists before creating
        assert "exists" in content.lower() or "already" in content.lower() or \
               "BucketAlreadyOwnedByYou" in content or "if " in content, \
            "bootstrap script must be idempotent (check before create)"

    def test_prints_eks_access_entry_command(self):
        content = self._read()
        assert "create-access-entry" in content, \
            "bootstrap script must print the EKS access entry command"

    def test_set_e_for_safety(self):
        content = self._read()
        assert "set -e" in content, "bootstrap script must use set -e"

    def test_sts_audience(self):
        content = self._read()
        assert "sts.amazonaws.com" in content, \
            "OIDC provider audience must be sts.amazonaws.com"

    def test_sts_permissions(self):
        content = self._read()
        assert "sts:AssumeRole" in content, \
            "bootstrap script must grant sts:AssumeRole for IRSA role chains"
        assert "sts:TagSession" in content, \
            "bootstrap script must grant sts:TagSession (required by AWS provider >= 5.x)"


# ---------------------------------------------------------------------------
# Task 3: .github/workflows/ci.yml
# ---------------------------------------------------------------------------

class TestCiWorkflow:
    def _path(self):
        return os.path.join(WORKFLOWS_DIR, "ci.yml")

    def _load(self):
        with open(self._path()) as f:
            return yaml.safe_load(f)

    def test_file_exists(self):
        assert os.path.exists(self._path()), "ci.yml must exist"

    def test_valid_yaml(self):
        doc = self._load()
        assert doc is not None

    def test_triggers_on_pull_request(self):
        doc = self._load()
        # PyYAML parses 'on' as True (YAML 1.1 boolean)
        triggers = doc.get("on", doc.get(True, {}))
        assert "pull_request" in triggers, \
            "ci.yml must trigger on pull_request"

    def test_targets_main_branch(self):
        doc = self._load()
        triggers = doc.get("on", doc.get(True, {}))
        pr_config = triggers.get("pull_request", {})
        branches = pr_config.get("branches", []) if pr_config else []
        assert "main" in branches, "ci.yml pull_request trigger must target main branch"

    def test_has_lint_test_job(self):
        doc = self._load()
        jobs = doc.get("jobs", {})
        assert any("lint" in k or "test" in k for k in jobs), \
            "ci.yml must have a lint/test job"

    def test_has_terraform_validate_job(self):
        doc = self._load()
        jobs = doc.get("jobs", {})
        assert any("terraform" in k for k in jobs), \
            "ci.yml must have a terraform validation job"

    def test_no_id_token_permission(self):
        """ci.yml must NOT have id-token: write — no AWS creds on PRs."""
        doc = self._load()
        top_perms = doc.get("permissions", {})
        if isinstance(top_perms, dict):
            assert top_perms.get("id-token") != "write", \
                "ci.yml must not have id-token: write (no AWS creds on PRs)"
        # Also check individual jobs
        for job_name, job in doc.get("jobs", {}).items():
            job_perms = job.get("permissions", {})
            if isinstance(job_perms, dict):
                assert job_perms.get("id-token") != "write", \
                    f"Job {job_name} must not have id-token: write"

    def test_uses_python_311(self):
        doc = self._load()
        content_str = str(doc)
        assert "3.11" in content_str, "ci.yml must use Python 3.11"

    def test_uses_terraform_110(self):
        doc = self._load()
        content_str = str(doc)
        assert "1.10" in content_str, "ci.yml must use Terraform 1.10.x"

    def test_terraform_init_backend_false(self):
        """terraform init must use -backend=false to avoid needing AWS creds."""
        with open(self._path()) as f:
            raw = f.read()
        assert "backend=false" in raw or "backend-config" not in raw, \
            "terraform init in ci.yml must use -backend=false"
        assert "-backend=false" in raw, \
            "terraform init must pass -backend=false in ci.yml"

    def test_ruff_check(self):
        with open(self._path()) as f:
            raw = f.read()
        assert "ruff" in raw, "ci.yml must run ruff for linting"

    def test_pytest_runs(self):
        with open(self._path()) as f:
            raw = f.read()
        assert "pytest" in raw, "ci.yml must run pytest"

    def test_no_pip_install_or_true(self):
        """pip install must not use || true — it hides real failures."""
        with open(self._path()) as f:
            raw = f.read()
        assert "pip install" not in raw or "|| true" not in raw, \
            "ci.yml must not use '|| true' on pip install (hides failures)"

    def test_fetch_depth_1(self):
        """Checkouts should use fetch-depth: 1 for performance."""
        doc = self._load()
        for job_name, job in doc.get("jobs", {}).items():
            for step in job.get("steps", []):
                if step.get("uses", "").startswith("actions/checkout"):
                    fetch_depth = step.get("with", {}).get("fetch-depth")
                    assert fetch_depth == 1, \
                        f"Job {job_name} checkout should use fetch-depth: 1"


# ---------------------------------------------------------------------------
# Task 4: .github/workflows/deploy.yml
# ---------------------------------------------------------------------------

class TestDeployWorkflow:
    def _path(self):
        return os.path.join(WORKFLOWS_DIR, "deploy.yml")

    def _load(self):
        with open(self._path()) as f:
            return yaml.safe_load(f)

    def test_file_exists(self):
        assert os.path.exists(self._path()), "deploy.yml must exist"

    def test_valid_yaml(self):
        doc = self._load()
        assert doc is not None

    def test_triggers_on_push_to_main(self):
        doc = self._load()
        # PyYAML parses 'on' as True (YAML 1.1 boolean)
        triggers = doc.get("on", doc.get(True, {}))
        push_config = triggers.get("push", {})
        branches = push_config.get("branches", [])
        assert "main" in branches, "deploy.yml must trigger on push to main"

    def test_has_id_token_write(self):
        """deploy.yml must have id-token: write for OIDC."""
        with open(self._path()) as f:
            raw = f.read()
        assert "id-token" in raw and "write" in raw, \
            "deploy.yml must have id-token: write permission for OIDC"

    def test_has_concurrency_group(self):
        doc = self._load()
        assert "concurrency" in doc, \
            "deploy.yml must have concurrency group to prevent parallel deploys"
        concurrency = doc["concurrency"]
        assert "deploy" in str(concurrency.get("group", "")), \
            "concurrency group must be named for deploy"

    def test_cancel_in_progress_false(self):
        doc = self._load()
        concurrency = doc.get("concurrency", {})
        assert concurrency.get("cancel-in-progress") is False, \
            "cancel-in-progress must be false (don't cancel in-flight deploys)"

    def test_has_terraform_job(self):
        doc = self._load()
        jobs = doc.get("jobs", {})
        assert any("terraform" in k for k in jobs), \
            "deploy.yml must have a terraform job"

    def test_has_build_push_job(self):
        doc = self._load()
        jobs = doc.get("jobs", {})
        assert any("build" in k or "push" in k for k in jobs), \
            "deploy.yml must have a build/push job"

    def test_has_deploy_k8s_job(self):
        doc = self._load()
        jobs = doc.get("jobs", {})
        assert any("deploy" in k or "k8s" in k or "kube" in k for k in jobs), \
            "deploy.yml must have a kubernetes deploy job"

    def test_oidc_role_arn_uses_workshop_account(self):
        with open(self._path()) as f:
            raw = f.read()
        assert "621967485578" in raw, \
            "deploy.yml must use workshop account ID 621967485578"

    def test_role_duration_7200(self):
        with open(self._path()) as f:
            raw = f.read()
        assert "7200" in raw, \
            "deploy.yml must set role-duration-seconds to 7200"

    def test_regional_sts_endpoint(self):
        with open(self._path()) as f:
            raw = f.read()
        assert "regional" in raw, \
            "deploy.yml must set AWS_STS_REGIONAL_ENDPOINTS: regional"

    def test_tf_log_error(self):
        with open(self._path()) as f:
            raw = f.read()
        assert "TF_LOG" in raw and "ERROR" in raw, \
            "deploy.yml must set TF_LOG: ERROR to suppress sensitive output"

    def test_change_detection_on_applications(self):
        with open(self._path()) as f:
            raw = f.read()
        assert "paths-filter" in raw or "dorny" in raw, \
            "deploy.yml must use paths-filter for change detection on applications/"

    def test_image_tag_uses_github_sha(self):
        with open(self._path()) as f:
            raw = f.read()
        assert "github.sha" in raw, \
            "deploy.yml must tag Docker images with github.sha"

    def test_validate_deployment_script_called(self):
        with open(self._path()) as f:
            raw = f.read()
        assert "validate-deployment.sh" in raw, \
            "deploy.yml must call validate-deployment.sh as post-deploy health check"

    def test_eks_update_kubeconfig(self):
        with open(self._path()) as f:
            raw = f.read()
        assert "update-kubeconfig" in raw, \
            "deploy.yml must run aws eks update-kubeconfig"

    def test_terraform_auto_approve(self):
        with open(self._path()) as f:
            raw = f.read()
        assert "auto-approve" in raw, \
            "deploy.yml must use terraform apply -auto-approve"

    def test_no_gpu_flag(self):
        with open(self._path()) as f:
            raw = f.read()
        assert "--include-gpu" not in raw, \
            "deploy.yml must not pass --include-gpu (no GPU runners)"

    def test_deploy_role_arn_in_env(self):
        """DEPLOY_ROLE_ARN must be in top-level env to avoid repetition."""
        doc = self._load()
        env = doc.get("env", {})
        assert "DEPLOY_ROLE_ARN" in env, \
            "deploy.yml must define DEPLOY_ROLE_ARN in top-level env block"

    def test_image_tag_fallback_for_infra_only_push(self):
        """deploy-k8s must use a fallback image tag when build was skipped."""
        with open(self._path()) as f:
            raw = f.read()
        assert "latest" in raw or "image_tag" in raw, \
            "deploy.yml must handle infra-only pushes with a fallback image tag"
        assert "needs.build-push.outputs" in raw, \
            "deploy-k8s must consume image_tag from build-push job outputs"

    def test_eks_wait_cluster_active(self):
        """deploy-k8s must wait for EKS cluster to be active before kubectl."""
        with open(self._path()) as f:
            raw = f.read()
        assert "wait cluster-active" in raw or "cluster-active" in raw, \
            "deploy.yml must wait for EKS cluster-active before kubectl steps"

    def test_terraform_plan_summary_not_full_output(self):
        """Terraform plan must not dump full output to Step Summary (secret leak risk)."""
        with open(self._path()) as f:
            raw = f.read()
        # Should NOT cat the full plan file
        assert "cat /tmp/tfplan.txt >> $GITHUB_STEP_SUMMARY" not in raw, \
            "deploy.yml must not write full terraform plan to Step Summary (leaks secrets)"

    def test_fetch_depth_1(self):
        """Checkouts should use fetch-depth: 1 for performance."""
        doc = self._load()
        for job_name, job in doc.get("jobs", {}).items():
            for step in job.get("steps", []):
                if step.get("uses", "").startswith("actions/checkout"):
                    fetch_depth = step.get("with", {}).get("fetch-depth")
                    assert fetch_depth == 1, \
                        f"Job {job_name} checkout should use fetch-depth: 1"

    def test_terraform_provider_cache(self):
        """deploy.yml should cache Terraform providers for performance."""
        with open(self._path()) as f:
            raw = f.read()
        assert "actions/cache" in raw and ".terraform" in raw, \
            "deploy.yml should cache .terraform directory for faster runs"
