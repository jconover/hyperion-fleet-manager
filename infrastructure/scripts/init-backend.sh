#!/bin/bash

# Terraform Backend Initialization Script
# This script initializes the S3 backend and DynamoDB table for state management
# Run this script ONCE before using Terraform in environment directories

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_DIR="$(dirname "$SCRIPT_DIR")/global"
AWS_REGION="${AWS_REGION:-us-east-1}"
STATE_BUCKET="${STATE_BUCKET:-hyperion-fleet-terraform-state}"
LOCK_TABLE="${LOCK_TABLE:-hyperion-fleet-terraform-lock}"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi

    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are not configured. Please configure AWS credentials first."
        exit 1
    fi

    log_info "Prerequisites check passed."
}

check_bucket_exists() {
    log_info "Checking if S3 bucket exists..."

    if aws s3api head-bucket --bucket "$STATE_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
        log_warn "S3 bucket '$STATE_BUCKET' already exists."
        return 0
    else
        log_info "S3 bucket '$STATE_BUCKET' does not exist."
        return 1
    fi
}

check_table_exists() {
    log_info "Checking if DynamoDB table exists..."

    if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$AWS_REGION" &> /dev/null; then
        log_warn "DynamoDB table '$LOCK_TABLE' already exists."
        return 0
    else
        log_info "DynamoDB table '$LOCK_TABLE' does not exist."
        return 1
    fi
}

init_global_backend() {
    log_info "Initializing global backend resources..."

    cd "$GLOBAL_DIR"

    # Initialize Terraform
    log_info "Running terraform init..."
    terraform init

    # Validate configuration
    log_info "Running terraform validate..."
    terraform validate

    # Plan the changes
    log_info "Running terraform plan..."
    terraform plan -out=tfplan

    # Ask for confirmation
    echo ""
    read -p "Do you want to apply these changes? (yes/no): " confirmation

    if [ "$confirmation" != "yes" ]; then
        log_warn "Backend initialization cancelled."
        rm -f tfplan
        exit 0
    fi

    # Apply the changes
    log_info "Running terraform apply..."
    terraform apply tfplan

    # Clean up plan file
    rm -f tfplan

    log_info "Global backend resources created successfully."
}

init_environment_backends() {
    log_info "Initializing environment backends..."

    local environments=("dev" "staging" "prod")

    for env in "${environments[@]}"; do
        local env_dir="$(dirname "$GLOBAL_DIR")/environments/$env"

        if [ -d "$env_dir" ]; then
            log_info "Initializing backend for environment: $env"
            cd "$env_dir"

            # Initialize Terraform with backend configuration
            terraform init

            log_info "Backend initialized for environment: $env"
        else
            log_warn "Environment directory not found: $env_dir"
        fi
    done
}

display_summary() {
    log_info "Backend initialization complete!"
    echo ""
    echo "=========================================="
    echo "Backend Configuration Summary"
    echo "=========================================="
    echo "S3 Bucket:       $STATE_BUCKET"
    echo "DynamoDB Table:  $LOCK_TABLE"
    echo "AWS Region:      $AWS_REGION"
    echo "=========================================="
    echo ""
    log_info "You can now use Terraform in the environment directories:"
    echo "  - environments/dev/"
    echo "  - environments/staging/"
    echo "  - environments/prod/"
    echo ""
    log_info "Example usage:"
    echo "  cd environments/dev"
    echo "  terraform plan"
    echo "  terraform apply"
}

main() {
    echo "=========================================="
    echo "Terraform Backend Initialization"
    echo "=========================================="
    echo ""

    # Check prerequisites
    check_prerequisites

    # Check if resources already exist
    bucket_exists=false
    table_exists=false

    if check_bucket_exists; then
        bucket_exists=true
    fi

    if check_table_exists; then
        table_exists=true
    fi

    # If both resources exist, skip creation
    if [ "$bucket_exists" = true ] && [ "$table_exists" = true ]; then
        log_warn "Backend resources already exist. Skipping creation."
        log_info "Proceeding to initialize environment backends..."
    else
        # Initialize global backend
        init_global_backend
    fi

    # Initialize environment backends
    init_environment_backends

    # Display summary
    display_summary
}

# Run main function
main
