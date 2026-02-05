.PHONY: help init validate plan apply destroy test lint fmt clean install docs

# Variables
TERRAFORM_DIR := infrastructure
ANSIBLE_DIR := configuration/ansible
ENVIRONMENT ?= dev
AWS_REGION ?= us-east-1

# Colors for output
COLOR_RESET := \033[0m
COLOR_BOLD := \033[1m
COLOR_GREEN := \033[32m
COLOR_YELLOW := \033[33m
COLOR_BLUE := \033[34m

help: ## Display this help message
	@echo "$(COLOR_BOLD)Hyperion Fleet Manager - Available Commands$(COLOR_RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(COLOR_BLUE)%-20s$(COLOR_RESET) %s\n", $$1, $$2}'

## Infrastructure Commands

init: ## Initialize Terraform workspace
	@echo "$(COLOR_GREEN)Initializing Terraform...$(COLOR_RESET)"
	cd $(TERRAFORM_DIR) && terraform init -upgrade

validate: ## Validate Terraform configuration
	@echo "$(COLOR_GREEN)Validating Terraform configuration...$(COLOR_RESET)"
	cd $(TERRAFORM_DIR) && terraform validate
	@echo "$(COLOR_GREEN)Running tflint...$(COLOR_RESET)"
	cd $(TERRAFORM_DIR) && tflint --recursive

plan: init validate ## Create Terraform execution plan
	@echo "$(COLOR_GREEN)Creating Terraform plan for $(ENVIRONMENT)...$(COLOR_RESET)"
	cd $(TERRAFORM_DIR) && terraform plan -var-file=environments/$(ENVIRONMENT)/terraform.tfvars -out=$(ENVIRONMENT).tfplan

apply: ## Apply Terraform changes
	@echo "$(COLOR_YELLOW)Applying Terraform changes for $(ENVIRONMENT)...$(COLOR_RESET)"
	cd $(TERRAFORM_DIR) && terraform apply $(ENVIRONMENT).tfplan

apply-auto: plan ## Apply Terraform changes without confirmation
	@echo "$(COLOR_YELLOW)Auto-applying Terraform changes for $(ENVIRONMENT)...$(COLOR_RESET)"
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve -var-file=environments/$(ENVIRONMENT)/terraform.tfvars

destroy: ## Destroy Terraform-managed infrastructure
	@echo "$(COLOR_YELLOW)WARNING: This will destroy infrastructure in $(ENVIRONMENT)$(COLOR_RESET)"
	cd $(TERRAFORM_DIR) && terraform destroy -var-file=environments/$(ENVIRONMENT)/terraform.tfvars

## Configuration Management

ansible-install: ## Install Ansible dependencies
	@echo "$(COLOR_GREEN)Installing Ansible dependencies...$(COLOR_RESET)"
	cd $(ANSIBLE_DIR) && ansible-galaxy install -r requirements.yml

ansible-lint: ## Lint Ansible playbooks
	@echo "$(COLOR_GREEN)Linting Ansible playbooks...$(COLOR_RESET)"
	cd $(ANSIBLE_DIR) && ansible-lint playbooks/

ansible-run: ## Run Ansible playbook
	@echo "$(COLOR_GREEN)Running Ansible playbook for $(ENVIRONMENT)...$(COLOR_RESET)"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/$(ENVIRONMENT) playbooks/site.yml

ansible-check: ## Run Ansible playbook in check mode
	@echo "$(COLOR_GREEN)Running Ansible in check mode...$(COLOR_RESET)"
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/$(ENVIRONMENT) playbooks/site.yml --check

## Testing

test: test-unit test-integration ## Run all tests

test-unit: ## Run unit tests
	@echo "$(COLOR_GREEN)Running unit tests...$(COLOR_RESET)"
	cd tests && go test ./... -v -cover

test-integration: ## Run integration tests
	@echo "$(COLOR_GREEN)Running integration tests...$(COLOR_RESET)"
	cd tests/integration && go test ./... -v -tags=integration

test-e2e: ## Run end-to-end tests
	@echo "$(COLOR_GREEN)Running E2E tests...$(COLOR_RESET)"
	cd tests/e2e && go test ./... -v -tags=e2e

test-performance: ## Run performance tests
	@echo "$(COLOR_GREEN)Running performance tests...$(COLOR_RESET)"
	cd tests/performance && go test ./... -v -bench=.

## Code Quality

lint: lint-terraform lint-ansible lint-go lint-shell ## Run all linters

lint-terraform: ## Lint Terraform code
	@echo "$(COLOR_GREEN)Linting Terraform...$(COLOR_RESET)"
	cd $(TERRAFORM_DIR) && tflint --recursive
	cd $(TERRAFORM_DIR) && terraform fmt -check -recursive

lint-ansible: ## Lint Ansible code
	@echo "$(COLOR_GREEN)Linting Ansible...$(COLOR_RESET)"
	cd $(ANSIBLE_DIR) && ansible-lint

lint-go: ## Lint Go code
	@echo "$(COLOR_GREEN)Linting Go code...$(COLOR_RESET)"
	golangci-lint run ./...

lint-shell: ## Lint shell scripts
	@echo "$(COLOR_GREEN)Linting shell scripts...$(COLOR_RESET)"
	find scripts -name "*.sh" -exec shellcheck {} \;

fmt: fmt-terraform fmt-go ## Format all code

fmt-terraform: ## Format Terraform code
	@echo "$(COLOR_GREEN)Formatting Terraform...$(COLOR_RESET)"
	cd $(TERRAFORM_DIR) && terraform fmt -recursive

fmt-go: ## Format Go code
	@echo "$(COLOR_GREEN)Formatting Go code...$(COLOR_RESET)"
	go fmt ./...

## Security

security-scan: ## Run security scans
	@echo "$(COLOR_GREEN)Running security scans...$(COLOR_RESET)"
	@echo "Scanning Terraform..."
	cd $(TERRAFORM_DIR) && tfsec .
	@echo "Scanning dependencies..."
	trivy fs --scanners vuln,secret,config .

## Build

build: build-cli build-dashboard ## Build all components

build-cli: ## Build fleet CLI tool
	@echo "$(COLOR_GREEN)Building fleet-cli...$(COLOR_RESET)"
	cd tools/fleet-cli && go build -o ../../bin/fleet-cli ./cmd

build-dashboard: ## Build web dashboard
	@echo "$(COLOR_GREEN)Building fleet-dashboard...$(COLOR_RESET)"
	cd web/fleet-dashboard && npm run build

## Installation

install: ## Install dependencies
	@echo "$(COLOR_GREEN)Installing dependencies...$(COLOR_RESET)"
	@echo "Installing Go dependencies..."
	go mod download
	@echo "Installing NPM dependencies..."
	cd web/fleet-dashboard && npm install
	@echo "Installing Ansible dependencies..."
	$(MAKE) ansible-install

## Documentation

docs: ## Generate documentation
	@echo "$(COLOR_GREEN)Generating documentation...$(COLOR_RESET)"
	cd docs && terraform-docs markdown table ../infrastructure > architecture/terraform.md

docs-serve: ## Serve documentation locally
	@echo "$(COLOR_GREEN)Serving documentation...$(COLOR_RESET)"
	cd docs && python3 -m http.server 8000

## Utilities

clean: ## Clean build artifacts and caches
	@echo "$(COLOR_GREEN)Cleaning build artifacts...$(COLOR_RESET)"
	rm -rf bin/
	rm -rf dist/
	rm -rf $(TERRAFORM_DIR)/*.tfplan
	rm -rf $(TERRAFORM_DIR)/.terraform/
	rm -rf web/fleet-dashboard/dist/
	rm -rf web/fleet-dashboard/node_modules/
	find . -name ".terraform.lock.hcl" -delete
	find . -name "*.tfstate*" -delete

state-list: ## List Terraform state resources
	@echo "$(COLOR_GREEN)Listing Terraform state for $(ENVIRONMENT)...$(COLOR_RESET)"
	cd $(TERRAFORM_DIR) && terraform state list

state-pull: ## Pull current Terraform state
	@echo "$(COLOR_GREEN)Pulling Terraform state for $(ENVIRONMENT)...$(COLOR_RESET)"
	cd $(TERRAFORM_DIR) && terraform state pull

cost-estimate: ## Estimate infrastructure costs
	@echo "$(COLOR_GREEN)Estimating infrastructure costs...$(COLOR_RESET)"
	cd $(TERRAFORM_DIR) && infracost breakdown --path .

## CI/CD

ci-validate: validate lint test ## Run CI validation pipeline
	@echo "$(COLOR_GREEN)CI validation complete$(COLOR_RESET)"

ci-deploy: init plan apply ## Run CI deployment pipeline
	@echo "$(COLOR_GREEN)CI deployment complete$(COLOR_RESET)"

## Default target
.DEFAULT_GOAL := help
