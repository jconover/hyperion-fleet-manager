################################################################################
# Required Variables
################################################################################

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|prod|test)$", var.environment))
    error_message = "Environment must be one of: dev, staging, prod, test."
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must be a valid VPC identifier starting with 'vpc-'."
  }
}

variable "bastion_security_group_id" {
  description = "Security group ID of the bastion host for RDP access"
  type        = string

  validation {
    condition     = can(regex("^sg-", var.bastion_security_group_id))
    error_message = "Security group ID must be a valid identifier starting with 'sg-'."
  }
}

################################################################################
# S3 and Storage Configuration
################################################################################

variable "fleet_s3_bucket_arns" {
  description = "List of S3 bucket ARNs that Windows fleet instances need access to"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.fleet_s3_bucket_arns : can(regex("^arn:aws:s3:::", arn))])
    error_message = "All S3 bucket ARNs must be valid ARN format starting with 'arn:aws:s3:::'."
  }
}

################################################################################
# Security Group Configuration
################################################################################

variable "fleet_application_port" {
  description = "Application port for Windows fleet instances (used for ALB health checks and traffic)"
  type        = number
  default     = 8080

  validation {
    condition     = var.fleet_application_port >= 1024 && var.fleet_application_port <= 65535
    error_message = "Application port must be between 1024 and 65535."
  }
}

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access the Application Load Balancer on HTTPS (443)"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.alb_ingress_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "All entries must be valid CIDR blocks."
  }
}

################################################################################
# KMS Configuration
################################################################################

variable "kms_deletion_window" {
  description = "KMS key deletion window in days (7-30)"
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}

################################################################################
# Secrets Manager Configuration
################################################################################

variable "db_master_username" {
  description = "Master username for RDS database (stored in Secrets Manager)"
  type        = string
  default     = "dbadmin"
  sensitive   = true

  validation {
    condition     = length(var.db_master_username) >= 1 && length(var.db_master_username) <= 16
    error_message = "Database username must be between 1 and 16 characters."
  }
}

variable "secret_recovery_window" {
  description = "Number of days to retain deleted secrets (0 for immediate deletion, 7-30 for recovery window)"
  type        = number
  default     = 7

  validation {
    condition     = var.secret_recovery_window == 0 || (var.secret_recovery_window >= 7 && var.secret_recovery_window <= 30)
    error_message = "Secret recovery window must be 0 (immediate deletion) or between 7 and 30 days."
  }
}

################################################################################
# Security Hub Configuration
################################################################################

variable "enable_security_hub" {
  description = "Enable AWS Security Hub for security posture management"
  type        = bool
  default     = true
}

variable "enable_cis_benchmark" {
  description = "Enable CIS AWS Foundations Benchmark in Security Hub"
  type        = bool
  default     = true
}

################################################################################
# GuardDuty Configuration
################################################################################

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty for threat detection"
  type        = bool
  default     = false
}

variable "guardduty_finding_frequency" {
  description = "GuardDuty finding publishing frequency (FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS)"
  type        = string
  default     = "FIFTEEN_MINUTES"

  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.guardduty_finding_frequency)
    error_message = "GuardDuty finding frequency must be one of: FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS."
  }
}

################################################################################
# Tagging Configuration
################################################################################

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}

  validation {
    condition     = length(var.tags) <= 50
    error_message = "Maximum of 50 tags allowed per resource."
  }
}
