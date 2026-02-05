# Test configuration for security module
# This file demonstrates module usage and can be used for testing

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "test"
      ManagedBy   = "terraform"
      Purpose     = "module-testing"
    }
  }
}

# Mock VPC for testing
resource "aws_vpc" "test" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "test-vpc"
  }
}

# Mock bastion security group
resource "aws_security_group" "bastion" {
  name        = "test-bastion-sg"
  description = "Test bastion security group"
  vpc_id      = aws_vpc.test.id

  tags = {
    Name = "test-bastion-sg"
  }
}

# Mock S3 bucket for testing (ARN only, not created)
locals {
  test_bucket_arns = [
    "arn:aws:s3:::test-bucket-1",
    "arn:aws:s3:::test-bucket-2"
  ]
}

# Test the security module
module "security" {
  source = "../"

  environment  = "test"
  project_name = "hyperion-fleet-manager"
  vpc_id       = aws_vpc.test.id

  bastion_security_group_id = aws_security_group.bastion.id
  fleet_s3_bucket_arns      = local.test_bucket_arns
  fleet_application_port    = 8080

  alb_ingress_cidr_blocks = ["10.0.0.0/8"]

  # KMS configuration
  kms_deletion_window = 7 # Shorter for testing

  # Secrets Manager configuration
  db_master_username     = "testadmin"
  secret_recovery_window = 7

  # Security services (disabled for cost during testing)
  enable_security_hub  = false
  enable_cis_benchmark = false
  enable_guardduty     = false

  tags = {
    Project    = "Hyperion Fleet Manager"
    Owner      = "platform-team"
    CostCenter = "engineering"
  }
}

# Outputs for verification
output "test_role_arn" {
  description = "Test Windows fleet role ARN"
  value       = module.security.windows_fleet_role_arn
}

output "test_instance_profile" {
  description = "Test instance profile name"
  value       = module.security.windows_fleet_instance_profile_name
}

output "test_security_groups" {
  description = "Test security group IDs"
  value       = module.security.security_group_ids
}

output "test_kms_keys" {
  description = "Test KMS key IDs"
  value       = module.security.kms_key_ids
}

output "test_secret_arn" {
  description = "Test secret ARN"
  value       = module.security.db_credentials_secret_arn
}
