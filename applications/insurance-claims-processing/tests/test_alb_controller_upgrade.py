"""
Tests for Issue #18: aws-load-balancer-controller upgrade (v2.8.1 → v2.17.1).

Validates:
- addons.tf uses chart_version 1.17.1
- addons.tf has source_policy_documents with ec2:DescribeRouteTables
- All existing set[] values are preserved (especially enableServiceMutatorWebhook=false)
- Terraform files are valid (fmt + validate)
"""
import os
import re
import pytest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
TERRAFORM_DIR = os.path.join(REPO_ROOT, "infrastructure", "terraform")
ADDONS_TF = os.path.join(TERRAFORM_DIR, "addons.tf")


def _read_addons():
    with open(ADDONS_TF) as f:
        return f.read()


class TestAlbControllerChartVersion:
    def test_chart_version_is_1_17_1(self):
        """addons.tf must use chart_version 1.17.1 for aws-load-balancer-controller."""
        content = _read_addons()
        # Find the aws_load_balancer_controller block and check its chart_version
        # The block starts after enable_aws_load_balancer_controller
        lbc_section = content[content.find("aws_load_balancer_controller"):]
        match = re.search(r'chart_version\s*=\s*"([^"]+)"', lbc_section)
        assert match, "chart_version not found in aws_load_balancer_controller block"
        assert match.group(1) == "1.17.1", \
            f"chart_version must be 1.17.1, got {match.group(1)}"

    def test_old_chart_version_not_present_in_lbc_block(self):
        """The old chart version 1.8.1 must not be the active value in the LBC block."""
        content = _read_addons()
        lbc_section = content[content.find("aws_load_balancer_controller"):]
        # Check the actual chart_version value, not comments
        match = re.search(r'chart_version\s*=\s*"([^"]+)"', lbc_section)
        assert match, "chart_version not found"
        assert match.group(1) != "1.8.1", \
            "chart_version must not be 1.8.1 (old version with CVEs)"


class TestAlbControllerIamPolicy:
    def test_source_policy_documents_present(self):
        """addons.tf must have source_policy_documents in aws_load_balancer_controller block."""
        content = _read_addons()
        lbc_section = content[content.find("aws_load_balancer_controller"):]
        assert "source_policy_documents" in lbc_section, \
            "aws_load_balancer_controller block must have source_policy_documents"

    def test_describe_route_tables_action_present(self):
        """addons.tf must include ec2:DescribeRouteTables (new in v2.17.1)."""
        content = _read_addons()
        assert "ec2:DescribeRouteTables" in content, \
            "addons.tf must include ec2:DescribeRouteTables action (required by v2.17.1)"

    def test_iam_policy_document_data_source_exists(self):
        """A data source for the extra ALB controller policy must exist."""
        content = _read_addons()
        assert 'data "aws_iam_policy_document"' in content, \
            "addons.tf must define an aws_iam_policy_document data source for the extra policy"
        # Must reference it in the LBC block
        lbc_section = content[content.find("aws_load_balancer_controller"):]
        assert "aws_iam_policy_document" in lbc_section, \
            "aws_load_balancer_controller block must reference the iam_policy_document data source"


class TestAlbControllerPreservedConfig:
    def test_service_mutator_webhook_disabled(self):
        """enableServiceMutatorWebhook must remain false (critical — breaks Services if true)."""
        content = _read_addons()
        lbc_section = content[content.find("aws_load_balancer_controller"):]
        assert "enableServiceMutatorWebhook" in lbc_section, \
            "enableServiceMutatorWebhook setting must be preserved"
        # Find the value
        match = re.search(
            r'enableServiceMutatorWebhook["\s]*\n\s*value\s*=\s*"([^"]+)"',
            lbc_section
        )
        if not match:
            # Try inline format
            match = re.search(
                r'name\s*=\s*"enableServiceMutatorWebhook".*?value\s*=\s*"([^"]+)"',
                lbc_section, re.DOTALL
            )
        assert match, "enableServiceMutatorWebhook value not found"
        assert match.group(1) == "false", \
            f"enableServiceMutatorWebhook must be false, got {match.group(1)}"

    def test_wait_false_preserved(self):
        """wait = false must be preserved (prevents Terraform timeout)."""
        content = _read_addons()
        lbc_section = content[content.find("aws_load_balancer_controller"):]
        assert re.search(r'wait\s*=\s*false', lbc_section), \
            "wait = false must be preserved in aws_load_balancer_controller block"

    def test_atomic_false_preserved(self):
        """atomic = false must be preserved."""
        content = _read_addons()
        lbc_section = content[content.find("aws_load_balancer_controller"):]
        assert re.search(r'atomic\s*=\s*false', lbc_section), \
            "atomic = false must be preserved in aws_load_balancer_controller block"

    def test_cpu_limits_preserved(self):
        """Resource limits must be preserved."""
        content = _read_addons()
        lbc_section = content[content.find("aws_load_balancer_controller"):]
        assert "resources.limits.cpu" in lbc_section, \
            "resources.limits.cpu must be preserved"
        assert "200m" in lbc_section, \
            "CPU limit of 200m must be preserved"

    def test_memory_limits_preserved(self):
        """Memory limits must be preserved."""
        content = _read_addons()
        lbc_section = content[content.find("aws_load_balancer_controller"):]
        assert "resources.limits.memory" in lbc_section, \
            "resources.limits.memory must be preserved"
        assert "512Mi" in lbc_section, \
            "Memory limit of 512Mi must be preserved"


class TestTerraformFormat:
    def test_addons_tf_is_formatted(self):
        """addons.tf must pass terraform fmt -check."""
        import subprocess
        result = subprocess.run(
            ["terraform", "fmt", "-check", ADDONS_TF],
            capture_output=True, text=True
        )
        assert result.returncode == 0, \
            f"addons.tf is not properly formatted. Run 'terraform fmt {ADDONS_TF}'\n{result.stdout}"
