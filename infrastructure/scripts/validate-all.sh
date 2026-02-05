#!/bin/bash

# Validate All Environments Script
# This script validates Terraform configuration for all environments

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

validate_environment() {
    local env="$1"
    local env_dir="$INFRA_DIR/environments/$env"

    if [ ! -d "$env_dir" ]; then
        log_error "Environment directory not found: $env_dir"
        return 1
    fi

    log_info "Validating environment: $env"
    echo "=========================================="

    cd "$env_dir"

    # Initialize if needed
    if [ ! -d ".terraform" ]; then
        log_info "Initializing Terraform for $env..."
        terraform init -backend=false
    fi

    # Run validation
    if terraform validate; then
        log_info "Validation passed for $env"
    else
        log_error "Validation failed for $env"
        return 1
    fi

    # Run format check
    log_info "Checking Terraform format for $env..."
    if terraform fmt -check -recursive .; then
        log_info "Format check passed for $env"
    else
        log_warn "Format check failed for $env. Run 'terraform fmt -recursive' to fix."
    fi

    echo ""
}

validate_modules() {
    log_info "Validating modules..."
    echo "=========================================="

    local modules_dir="$INFRA_DIR/modules"

    if [ ! -d "$modules_dir" ]; then
        log_warn "Modules directory not found: $modules_dir"
        return 0
    fi

    for module_dir in "$modules_dir"/*; do
        if [ -d "$module_dir" ]; then
            local module_name=$(basename "$module_dir")
            log_info "Validating module: $module_name"

            cd "$module_dir"

            # Check for required files
            if [ ! -f "main.tf" ]; then
                log_warn "Module $module_name is missing main.tf"
                continue
            fi

            # Initialize and validate
            terraform init -backend=false > /dev/null 2>&1 || true

            if terraform validate; then
                log_info "Module $module_name validated successfully"
            else
                log_error "Module $module_name validation failed"
                return 1
            fi
        fi
    done

    echo ""
}

validate_global() {
    log_info "Validating global configuration..."
    echo "=========================================="

    local global_dir="$INFRA_DIR/global"

    if [ ! -d "$global_dir" ]; then
        log_error "Global directory not found: $global_dir"
        return 1
    fi

    cd "$global_dir"

    # Initialize if needed
    if [ ! -d ".terraform" ]; then
        log_info "Initializing Terraform for global..."
        terraform init -backend=false
    fi

    # Run validation
    if terraform validate; then
        log_info "Global configuration validated successfully"
    else
        log_error "Global configuration validation failed"
        return 1
    fi

    echo ""
}

main() {
    log_info "Starting validation of all Terraform configurations..."
    echo ""

    local failed=()

    # Validate global
    if ! validate_global; then
        failed+=("global")
    fi

    # Validate modules
    if ! validate_modules; then
        failed+=("modules")
    fi

    # Validate environments
    local environments=("dev" "staging" "prod")
    for env in "${environments[@]}"; do
        if ! validate_environment "$env"; then
            failed+=("$env")
        fi
    done

    echo "=========================================="
    log_info "Validation Summary"
    echo "=========================================="

    if [ ${#failed[@]} -eq 0 ]; then
        log_info "All validations passed successfully!"
        exit 0
    else
        log_error "Validation failed for the following:"
        for item in "${failed[@]}"; do
            echo "  - $item"
        done
        exit 1
    fi
}

main "$@"
