#!/bin/bash

# Environment Switching Helper Script
# This script helps you switch between different Terraform environments

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

show_usage() {
    echo "Usage: $0 [dev|staging|prod]"
    echo ""
    echo "This script helps you switch between Terraform environments."
    echo ""
    echo "Examples:"
    echo "  $0 dev      - Switch to development environment"
    echo "  $0 staging  - Switch to staging environment"
    echo "  $0 prod     - Switch to production environment"
    exit 1
}

validate_environment() {
    local env="$1"

    case "$env" in
        dev|staging|prod)
            return 0
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Invalid environment: $env"
            show_usage
            ;;
    esac
}

switch_environment() {
    local env="$1"
    local env_dir="$INFRA_DIR/environments/$env"

    if [ ! -d "$env_dir" ]; then
        echo -e "${RED}[ERROR]${NC} Environment directory not found: $env_dir"
        exit 1
    fi

    cd "$env_dir"

    echo -e "${GREEN}[INFO]${NC} Switched to $env environment"
    echo -e "${GREEN}[INFO]${NC} Current directory: $(pwd)"
    echo ""
    echo -e "${YELLOW}[TIP]${NC} You can now run Terraform commands:"
    echo "  terraform plan"
    echo "  terraform apply"
    echo "  terraform destroy"
    echo ""
    echo -e "${YELLOW}[TIP]${NC} To open a new shell in this directory:"
    echo "  bash"

    # Start a new shell in the environment directory
    exec bash
}

main() {
    if [ $# -ne 1 ]; then
        show_usage
    fi

    local env="$1"
    validate_environment "$env"
    switch_environment "$env"
}

main "$@"
