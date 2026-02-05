.PHONY: help init validate format lint test plan apply destroy clean docs checkov

# Default target
help:
	@echo "Available targets:"
	@echo "  init      - Initialize Terraform"
	@echo "  validate  - Validate Terraform configuration"
	@echo "  format    - Format Terraform files"
	@echo "  lint      - Run tflint"
	@echo "  checkov   - Run Checkov security scanning"
	@echo "  test      - Run all tests"
	@echo "  plan      - Run terraform plan in test directory"
	@echo "  apply     - Apply test configuration"
	@echo "  destroy   - Destroy test resources"
	@echo "  clean     - Clean Terraform files"
	@echo "  docs      - Generate documentation"

# Initialize Terraform
init:
	@echo "Initializing Terraform..."
	terraform -chdir=test init

# Validate configuration
validate: init
	@echo "Validating Terraform configuration..."
	terraform -chdir=test validate

# Format Terraform files
format:
	@echo "Formatting Terraform files..."
	terraform fmt -recursive .

# Run tflint
lint:
	@echo "Running tflint..."
	tflint --init
	tflint --recursive

# Run Checkov security scanning
checkov:
	@echo "Running Checkov security scanning..."
	checkov -d . --framework terraform --compact --quiet

# Run Checkov with detailed output
checkov-verbose:
	@echo "Running Checkov with detailed output..."
	checkov -d . --framework terraform

# Run all tests
test: format validate checkov
	@echo "All tests passed!"

# Run terraform plan in test directory
plan: init
	@echo "Running terraform plan..."
	terraform -chdir=test plan

# Apply test configuration
apply: init
	@echo "Applying test configuration..."
	terraform -chdir=test apply -auto-approve

# Destroy test resources
destroy:
	@echo "Destroying test resources..."
	terraform -chdir=test destroy -auto-approve

# Clean Terraform files
clean:
	@echo "Cleaning Terraform files..."
	find . -type d -name ".terraform" -exec rm -rf {} +
	find . -type f -name ".terraform.lock.hcl" -delete
	find . -type f -name "terraform.tfstate*" -delete
	find . -type f -name "*.tfplan" -delete

# Generate documentation using terraform-docs
docs:
	@echo "Generating documentation..."
	@if command -v terraform-docs >/dev/null 2>&1; then \
		terraform-docs markdown table --output-file TERRAFORM.md .; \
		echo "Documentation generated in TERRAFORM.md"; \
	else \
		echo "terraform-docs not found. Install with: brew install terraform-docs"; \
	fi

# Pre-commit hook simulation
pre-commit: format validate checkov
	@echo "Pre-commit checks completed successfully!"

# CI/CD pipeline simulation
ci: format validate lint checkov
	@echo "CI pipeline checks completed successfully!"
