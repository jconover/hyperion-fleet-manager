#!/bin/bash
set -e

echo "==================================="
echo "GitHub Actions Setup Validation"
echo "==================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "Checking prerequisites..."
if command -v gh &> /dev/null; then
    check_pass "GitHub CLI installed"
else
    check_fail "GitHub CLI not installed"
fi

echo ""
echo "Checking workflow files..."

WORKFLOWS=(
    "pr-validation.yml"
    "deploy-dev.yml"
    "deploy-staging.yml"
    "deploy-prod.yml"
    "drift-detection.yml"
    "compliance-scan.yml"
    "workflow-validation.yml"
)

for workflow in "${WORKFLOWS[@]}"; do
    if [ -f ".github/workflows/$workflow" ]; then
        check_pass "Workflow: $workflow"
    else
        check_fail "Missing: $workflow"
    fi
done

echo ""
echo "Checking composite actions..."

ACTIONS=(
    "setup-terraform"
    "run-security-scan"
    "terraform-plan-comment"
)

for action in "${ACTIONS[@]}"; do
    if [ -f ".github/actions/$action/action.yml" ]; then
        check_pass "Action: $action"
    else
        check_fail "Missing: $action"
    fi
done

echo ""
echo "Checking configuration files..."

CONFIG_FILES=(
    ".tflint.hcl"
    ".github/dependabot.yml"
    ".github/CODEOWNERS"
    ".github/PULL_REQUEST_TEMPLATE.md"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        check_pass "Config: $file"
    else
        check_fail "Missing: $file"
    fi
done

echo ""
echo "Validation complete!"
echo ""
echo "Next: See .github/SETUP.md for configuration steps"
