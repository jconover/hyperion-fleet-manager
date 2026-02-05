#!/bin/bash
set -e

# Terraform Observability Module Validation Script
# This script validates the Terraform module configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Terraform Observability Module Validation"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if required tools are installed
check_tool() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is not installed"
        return 1
    fi
}

echo "Checking required tools..."
TOOLS_OK=true
check_tool "terraform" || TOOLS_OK=false
check_tool "jq" || TOOLS_OK=false

# Optional tools
if command -v "tflint" &> /dev/null; then
    echo -e "${GREEN}✓${NC} tflint is installed (optional)"
    HAS_TFLINT=true
else
    echo -e "${YELLOW}!${NC} tflint is not installed (optional, recommended)"
    HAS_TFLINT=false
fi

if command -v "terraform-docs" &> /dev/null; then
    echo -e "${GREEN}✓${NC} terraform-docs is installed (optional)"
    HAS_TERRAFORM_DOCS=true
else
    echo -e "${YELLOW}!${NC} terraform-docs is not installed (optional, recommended)"
    HAS_TERRAFORM_DOCS=false
fi

echo ""

if [ "$TOOLS_OK" = false ]; then
    echo -e "${RED}ERROR: Required tools are missing. Please install them first.${NC}"
    exit 1
fi

# Terraform Format Check
echo "Running terraform fmt check..."
if terraform fmt -check -recursive > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Terraform formatting is correct"
else
    echo -e "${RED}✗${NC} Terraform formatting issues found. Run 'terraform fmt -recursive' to fix."
    terraform fmt -check -recursive
    exit 1
fi
echo ""

# Terraform Validation
echo "Initializing Terraform..."
if terraform init -backend=false > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Terraform initialization successful"
else
    echo -e "${RED}✗${NC} Terraform initialization failed"
    terraform init -backend=false
    exit 1
fi
echo ""

echo "Validating Terraform configuration..."
if terraform validate > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Terraform validation passed"
else
    echo -e "${RED}✗${NC} Terraform validation failed"
    terraform validate
    exit 1
fi
echo ""

# TFLint
if [ "$HAS_TFLINT" = true ]; then
    echo "Running tflint..."
    if tflint --init > /dev/null 2>&1; then
        if tflint > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} tflint passed"
        else
            echo -e "${YELLOW}!${NC} tflint found issues:"
            tflint
        fi
    else
        echo -e "${YELLOW}!${NC} tflint initialization failed"
    fi
    echo ""
fi

# Validate JSON files
echo "Validating JSON files..."
JSON_VALID=true
for json_file in dashboards/*.json cloudwatch-agent-config.json; do
    if [ -f "$json_file" ]; then
        if jq empty "$json_file" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} $json_file is valid JSON"
        else
            echo -e "${RED}✗${NC} $json_file is invalid JSON"
            JSON_VALID=false
        fi
    fi
done

if [ "$JSON_VALID" = false ]; then
    exit 1
fi
echo ""

# Check for required files
echo "Checking for required files..."
REQUIRED_FILES=(
    "main.tf"
    "variables.tf"
    "outputs.tf"
    "versions.tf"
    "README.md"
    "dashboards/fleet-health.json"
)

FILES_OK=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file exists"
    else
        echo -e "${RED}✗${NC} $file is missing"
        FILES_OK=false
    fi
done

if [ "$FILES_OK" = false ]; then
    exit 1
fi
echo ""

# Validate variable constraints
echo "Validating variable constraints..."
CONSTRAINT_TESTS=(
    "Testing environment variable validation..."
    "Testing log retention validation..."
    "Testing threshold validations..."
)

# This would require actual Terraform plan with test values
# For now, we just check that validation blocks exist
if grep -q "validation {" variables.tf; then
    echo -e "${GREEN}✓${NC} Variable validations are defined"
else
    echo -e "${YELLOW}!${NC} No variable validations found"
fi
echo ""

# Generate documentation
if [ "$HAS_TERRAFORM_DOCS" = true ]; then
    echo "Generating documentation..."
    if terraform-docs markdown table . > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Documentation generated successfully"
    else
        echo -e "${YELLOW}!${NC} Documentation generation had issues"
    fi
    echo ""
fi

# Check for hardcoded values (basic check)
echo "Checking for potential hardcoded values..."
HARDCODED_OK=true

# Check for hardcoded IPs
if grep -rn --include="*.tf" --exclude="examples.tf" -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" . | grep -v "0.0.0.0" | grep -v "127.0.0.1"; then
    echo -e "${YELLOW}!${NC} Found potential hardcoded IP addresses"
    HARDCODED_OK=false
fi

# Check for hardcoded AWS account IDs (excluding examples)
if grep -rn --include="*.tf" --exclude="examples.tf" -E "[0-9]{12}" . | grep -v "123456789012"; then
    echo -e "${YELLOW}!${NC} Found potential hardcoded AWS account IDs"
    HARDCODED_OK=false
fi

if [ "$HARDCODED_OK" = true ]; then
    echo -e "${GREEN}✓${NC} No obvious hardcoded values found"
fi
echo ""

# Summary
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo -e "${GREEN}✓${NC} All critical validations passed!"
echo ""
echo "Module is ready for use."
echo ""
echo "Next steps:"
echo "  1. Review the generated documentation"
echo "  2. Customize variables in terraform.tfvars"
echo "  3. Run 'terraform plan' to preview changes"
echo "  4. Run 'terraform apply' to deploy"
echo ""
