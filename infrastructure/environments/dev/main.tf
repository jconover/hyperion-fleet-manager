# Development Environment - Main Configuration
# This file composes all modules for the dev environment

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.33"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "hyperion-fleet-manager"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
    }
  }
}

# Local variables for common configurations
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  environment     = var.environment
  vpc_cidr        = var.vpc_cidr
  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Component = "networking"
    }
  )
}

# Security Module
module "security" {
  source = "../../modules/security"

  environment = var.environment
  vpc_id      = module.networking.vpc_id

  # Security group rules
  allowed_cidr_blocks = var.allowed_cidr_blocks

  # KMS encryption
  enable_kms_encryption = var.enable_kms_encryption

  tags = merge(
    local.common_tags,
    {
      Component = "security"
    }
  )
}

# Compute Module
module "compute" {
  source = "../../modules/compute"

  environment         = var.environment
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  public_subnet_ids   = module.networking.public_subnet_ids

  # EC2 configuration
  instance_type       = var.instance_type
  instance_count      = var.instance_count
  key_name            = var.ssh_key_name

  # Auto Scaling
  enable_auto_scaling = var.enable_auto_scaling
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity

  # Security
  security_group_ids  = [module.security.app_security_group_id]

  tags = merge(
    local.common_tags,
    {
      Component = "compute"
    }
  )
}

# Observability Module
module "observability" {
  source = "../../modules/observability"

  environment = var.environment

  # CloudWatch configuration
  log_retention_days         = var.log_retention_days
  enable_detailed_monitoring = var.enable_detailed_monitoring

  # Alarms
  enable_cpu_alarm    = var.enable_cpu_alarm
  cpu_threshold       = var.cpu_alarm_threshold
  alarm_email         = var.alarm_notification_email

  # Resources to monitor
  instance_ids = module.compute.instance_ids

  tags = merge(
    local.common_tags,
    {
      Component = "observability"
    }
  )
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
