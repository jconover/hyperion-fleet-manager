# Makefile for Hyperion Fleet Manager Metric Aggregator Lambda
# Provides targets for building, testing, and deploying the Lambda function

.PHONY: help build test test-coverage test-verbose lint format clean deploy local validate install dev-install

# Default environment
ENV ?= dev
REGION ?= us-east-1
STACK_NAME ?= hyperion-metric-aggregator-$(ENV)
FLEET_NAME ?= hyperion-fleet
S3_BUCKET ?= hyperion-deployment-$(ENV)

# Python settings
PYTHON := python3
PIP := pip3
PYTEST := pytest
VENV_DIR := .venv
VENV_ACTIVATE := $(VENV_DIR)/bin/activate

# SAM settings
SAM := sam
SAM_BUILD_DIR := .aws-sam

# Coverage settings
COV_REPORT_DIR := htmlcov
COV_MIN_PERCENT := 80

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development Setup

install: ## Install production dependencies
	@echo "$(BLUE)Installing production dependencies...$(NC)"
	$(PIP) install -r requirements.txt

dev-install: ## Install development dependencies
	@echo "$(BLUE)Installing development dependencies...$(NC)"
	$(PIP) install -r requirements.txt
	$(PIP) install pytest pytest-cov pytest-mock moto boto3-stubs[cloudwatch,ssm,ec2] black ruff mypy

venv: ## Create virtual environment
	@echo "$(BLUE)Creating virtual environment...$(NC)"
	$(PYTHON) -m venv $(VENV_DIR)
	@echo "$(GREEN)Virtual environment created. Activate with:$(NC)"
	@echo "  source $(VENV_ACTIVATE)"

setup: venv ## Set up complete development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	. $(VENV_ACTIVATE) && $(PIP) install --upgrade pip
	. $(VENV_ACTIVATE) && $(MAKE) dev-install
	@echo "$(GREEN)Development environment ready!$(NC)"

##@ Testing

test: ## Run all tests with pytest
	@echo "$(BLUE)Running tests...$(NC)"
	$(PYTEST) tests/ -v --tb=short
	@echo "$(GREEN)Tests completed!$(NC)"

test-coverage: ## Run tests with coverage report
	@echo "$(BLUE)Running tests with coverage...$(NC)"
	$(PYTEST) tests/ \
		--cov=. \
		--cov-report=term-missing \
		--cov-report=html:$(COV_REPORT_DIR) \
		--cov-fail-under=$(COV_MIN_PERCENT) \
		-v
	@echo "$(GREEN)Coverage report generated at $(COV_REPORT_DIR)/index.html$(NC)"

test-verbose: ## Run tests with detailed output
	@echo "$(BLUE)Running tests with verbose output...$(NC)"
	$(PYTEST) tests/ -v -s --tb=long

test-handler: ## Run only handler tests
	@echo "$(BLUE)Running handler tests...$(NC)"
	$(PYTEST) tests/test_handler.py -v

test-metrics: ## Run only metrics tests
	@echo "$(BLUE)Running metrics tests...$(NC)"
	$(PYTEST) tests/test_metrics.py -v

test-quick: ## Run tests without coverage (faster)
	@echo "$(BLUE)Running quick tests...$(NC)"
	$(PYTEST) tests/ -q --tb=line

##@ Code Quality

lint: ## Run linter (ruff)
	@echo "$(BLUE)Running linter...$(NC)"
	ruff check .
	@echo "$(GREEN)Linting complete!$(NC)"

lint-fix: ## Run linter and fix issues automatically
	@echo "$(BLUE)Running linter with auto-fix...$(NC)"
	ruff check . --fix
	@echo "$(GREEN)Linting complete!$(NC)"

format: ## Format code with black
	@echo "$(BLUE)Formatting code...$(NC)"
	black .
	@echo "$(GREEN)Formatting complete!$(NC)"

format-check: ## Check code formatting without making changes
	@echo "$(BLUE)Checking code format...$(NC)"
	black --check --diff .

typecheck: ## Run type checking with mypy
	@echo "$(BLUE)Running type checker...$(NC)"
	mypy handler.py metrics.py cloudwatch_client.py ssm_client.py config.py \
		--ignore-missing-imports \
		--strict
	@echo "$(GREEN)Type checking complete!$(NC)"

quality: lint format-check typecheck ## Run all code quality checks
	@echo "$(GREEN)All quality checks passed!$(NC)"

##@ Building

build: ## Build the Lambda package with SAM
	@echo "$(BLUE)Building Lambda package...$(NC)"
	$(SAM) build --use-container
	@echo "$(GREEN)Build complete!$(NC)"

build-fast: ## Build without container (faster, requires Python 3.11)
	@echo "$(BLUE)Building Lambda package (no container)...$(NC)"
	$(SAM) build
	@echo "$(GREEN)Build complete!$(NC)"

validate: ## Validate SAM template
	@echo "$(BLUE)Validating SAM template...$(NC)"
	$(SAM) validate --lint
	@echo "$(GREEN)Template is valid!$(NC)"

package: build ## Package the Lambda for deployment
	@echo "$(BLUE)Packaging Lambda function...$(NC)"
	$(SAM) package \
		--s3-bucket $(S3_BUCKET) \
		--output-template-file packaged.yaml
	@echo "$(GREEN)Package created: packaged.yaml$(NC)"

##@ Deployment

deploy: build ## Deploy to AWS with SAM (use ENV=prod for production)
	@echo "$(BLUE)Deploying to $(ENV) environment...$(NC)"
	$(SAM) deploy \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--parameter-overrides \
			Environment=$(ENV) \
			FleetName=$(FLEET_NAME) \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--no-confirm-changeset \
		--no-fail-on-empty-changeset
	@echo "$(GREEN)Deployment complete!$(NC)"

deploy-guided: build ## Deploy with guided prompts (for first deployment)
	@echo "$(BLUE)Starting guided deployment...$(NC)"
	$(SAM) deploy --guided

deploy-prod: ## Deploy to production (requires confirmation)
	@echo "$(YELLOW)WARNING: Deploying to PRODUCTION$(NC)"
	@read -p "Are you sure you want to deploy to production? [y/N] " confirm && \
		[ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] && \
		$(MAKE) deploy ENV=production

undeploy: ## Remove the deployed stack
	@echo "$(YELLOW)Removing stack $(STACK_NAME)...$(NC)"
	aws cloudformation delete-stack --stack-name $(STACK_NAME) --region $(REGION)
	@echo "$(GREEN)Stack deletion initiated$(NC)"

##@ Local Development

local: build ## Invoke Lambda locally with SAM
	@echo "$(BLUE)Invoking Lambda locally...$(NC)"
	$(SAM) local invoke MetricAggregatorFunction \
		--event events/scheduled_event.json \
		--env-vars env.json

local-debug: build ## Invoke Lambda locally with debug port
	@echo "$(BLUE)Starting Lambda with debugger...$(NC)"
	$(SAM) local invoke MetricAggregatorFunction \
		--event events/scheduled_event.json \
		--env-vars env.json \
		--debug-port 5858

start-api: build ## Start local Lambda endpoint
	@echo "$(BLUE)Starting local Lambda endpoint...$(NC)"
	$(SAM) local start-lambda

logs: ## Tail Lambda logs from CloudWatch
	@echo "$(BLUE)Tailing logs for $(STACK_NAME)...$(NC)"
	$(SAM) logs -n MetricAggregatorFunction \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--tail

logs-recent: ## Show recent Lambda logs
	@echo "$(BLUE)Fetching recent logs...$(NC)"
	aws logs tail /aws/lambda/hyperion-metric-aggregator-$(ENV) \
		--region $(REGION) \
		--since 1h

##@ Cleanup

clean: ## Remove build artifacts and cache
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	rm -rf $(SAM_BUILD_DIR)
	rm -rf $(COV_REPORT_DIR)
	rm -rf .pytest_cache
	rm -rf __pycache__
	rm -rf tests/__pycache__
	rm -rf .coverage
	rm -rf .mypy_cache
	rm -rf .ruff_cache
	rm -f packaged.yaml
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "$(GREEN)Clean complete!$(NC)"

clean-all: clean ## Remove all generated files including venv
	@echo "$(BLUE)Removing virtual environment...$(NC)"
	rm -rf $(VENV_DIR)
	@echo "$(GREEN)Full clean complete!$(NC)"

##@ Utilities

create-event: ## Create sample test event file
	@mkdir -p events
	@echo '{\n  "version": "0",\n  "id": "12345678-1234-1234-1234-123456789012",\n  "detail-type": "Scheduled Event",\n  "source": "aws.events",\n  "account": "123456789012",\n  "time": "2024-01-01T12:00:00Z",\n  "region": "us-east-1",\n  "resources": ["arn:aws:events:us-east-1:123456789012:rule/test"],\n  "detail": {}\n}' > events/scheduled_event.json
	@echo "$(GREEN)Created events/scheduled_event.json$(NC)"

create-env: ## Create sample env.json for local testing
	@echo '{\n  "MetricAggregatorFunction": {\n    "ENVIRONMENT": "dev",\n    "FLEET_NAME": "test-fleet",\n    "LOG_LEVEL": "DEBUG",\n    "AWS_REGION": "us-east-1"\n  }\n}' > env.json
	@echo "$(GREEN)Created env.json$(NC)"

describe-stack: ## Show deployed stack details
	@echo "$(BLUE)Stack details for $(STACK_NAME):$(NC)"
	aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].{Status:StackStatus,Outputs:Outputs}' \
		--output table

invoke-remote: ## Invoke the deployed Lambda function
	@echo "$(BLUE)Invoking deployed function...$(NC)"
	aws lambda invoke \
		--function-name hyperion-metric-aggregator-$(ENV) \
		--region $(REGION) \
		--log-type Tail \
		--query 'LogResult' \
		--output text \
		response.json | base64 -d
	@echo "\n$(GREEN)Response saved to response.json$(NC)"
	@cat response.json | $(PYTHON) -m json.tool
	@rm -f response.json

check-deps: ## Check for outdated dependencies
	@echo "$(BLUE)Checking for outdated dependencies...$(NC)"
	$(PIP) list --outdated

update-deps: ## Update all dependencies
	@echo "$(BLUE)Updating dependencies...$(NC)"
	$(PIP) install --upgrade -r requirements.txt
	@echo "$(GREEN)Dependencies updated!$(NC)"

##@ CI/CD Helpers

ci-test: ## Run tests in CI environment
	$(PYTEST) tests/ \
		--cov=. \
		--cov-report=xml:coverage.xml \
		--cov-report=term \
		--cov-fail-under=$(COV_MIN_PERCENT) \
		--junitxml=test-results.xml \
		-v

ci-lint: ## Run linting in CI environment
	ruff check . --output-format=github

ci-build: validate build ## Build for CI (with validation)
	@echo "$(GREEN)CI build complete!$(NC)"

ci-deploy: ci-build ## Full CI deployment pipeline
	@echo "$(BLUE)Running CI deployment pipeline...$(NC)"
	$(MAKE) deploy ENV=$(ENV)
	@echo "$(GREEN)CI deployment complete!$(NC)"
