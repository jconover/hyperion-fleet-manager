#!/bin/bash

# Plan All Environments Script
# This script runs terraform plan for all environments

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

plan_environment() {
    local env="$1"
    local env_dir="$INFRA_DIR/environments/$env"

    if [ ! -d "$env_dir" ]; then
        log_error "Environment directory not found: $env_dir"
        return 1
    fi

    log_info "Planning environment: $env"
    echo "=========================================="

    cd "$env_dir"

    # Initialize if needed
    if [ ! -d ".terraform" ]; then
        log_info "Initializing Terraform for $env..."
        terraform init
    fi

    # Run plan
    terraform plan -out="tfplan-$env"

    echo ""
    log_info "Plan saved to: $env_dir/tfplan-$env"
    echo ""
}

main() {
    log_info "Planning all environments..."
    echo ""

    local environments=("dev" "staging" "prod")
    local failed=()

    for env in "${environments[@]}"; do
        if ! plan_environment "$env"; then
            failed+=("$env")
        fi
    done

    echo "=========================================="
    log_info "Plan Summary"
    echo "=========================================="

    if [ ${#failed[@]} -eq 0 ]; then
        log_info "All environments planned successfully!"
    else
        log_error "Failed to plan the following environments:"
        for env in "${failed[@]}"; do
            echo "  - $env"
        done
        exit 1
    fi

    echo ""
    log_info "Review the plans above and run:"
    log_info "  cd environments/<env> && terraform apply tfplan-<env>"
}

main "$@"
