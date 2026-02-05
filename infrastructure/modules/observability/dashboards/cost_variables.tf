# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - Cost Dashboard Module Variables
# -----------------------------------------------------------------------------
# This file defines all input variables for the CloudWatch Cost Monitoring
# Dashboard module. Variables are prefixed with "cost_" to avoid conflicts
# with the existing fleet-health dashboard variables.
#
# IMPORTANT: AWS Billing metrics are ONLY available in the us-east-1 region.
# This module must be deployed to us-east-1 or use a provider alias.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "cost_environment" {
  description = "Environment name (e.g., dev, staging, production). Used in dashboard naming and tagging."
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|production|prod)$", var.cost_environment))
    error_message = "Environment must be dev, staging, or production/prod."
  }
}

variable "cost_project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "hyperion"

  validation {
    condition     = length(var.cost_project_name) > 0 && length(var.cost_project_name) <= 32
    error_message = "Project name must be between 1 and 32 characters."
  }
}

# -----------------------------------------------------------------------------
# Budget Configuration
# -----------------------------------------------------------------------------

variable "cost_budget_amount" {
  description = "Monthly budget amount in USD for cost monitoring thresholds and dashboard annotations"
  type        = number
  default     = 1000

  validation {
    condition     = var.cost_budget_amount > 0
    error_message = "Budget amount must be a positive number."
  }
}

variable "cost_alert_thresholds" {
  description = <<-EOT
    Cost alert threshold percentages relative to budget. These values trigger
    visual indicators on the dashboard and CloudWatch alarms.
    Keys:
      - warning: Percentage threshold for warning state (default: 80)
      - critical: Percentage threshold for critical state (default: 100)
  EOT
  type = object({
    warning  = number
    critical = number
  })
  default = {
    warning  = 80
    critical = 100
  }

  validation {
    condition     = var.cost_alert_thresholds.warning > 0 && var.cost_alert_thresholds.warning <= 100
    error_message = "Warning threshold must be between 1 and 100."
  }

  validation {
    condition     = var.cost_alert_thresholds.critical > 0 && var.cost_alert_thresholds.critical <= 200
    error_message = "Critical threshold must be between 1 and 200."
  }

  validation {
    condition     = var.cost_alert_thresholds.warning < var.cost_alert_thresholds.critical
    error_message = "Warning threshold must be less than critical threshold."
  }
}

variable "cost_enable_budget_alarms" {
  description = "Enable CloudWatch alarms for budget threshold breaches"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Multi-Account Configuration
# -----------------------------------------------------------------------------

variable "cost_linked_accounts" {
  description = "List of linked AWS account IDs for consolidated billing cost tracking"
  type = list(object({
    account_id   = string
    account_name = string
  }))
  default = []

  validation {
    condition     = alltrue([for acct in var.cost_linked_accounts : can(regex("^[0-9]{12}$", acct.account_id))])
    error_message = "All account IDs must be 12-digit AWS account numbers."
  }
}

variable "cost_enable_linked_account_widgets" {
  description = "Enable cost widgets for linked accounts (requires organization access)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Cost Anomaly Detection Configuration
# -----------------------------------------------------------------------------

variable "cost_enable_cost_anomaly_detection" {
  description = "Enable AWS Cost Anomaly Detection monitor for proactive cost monitoring"
  type        = bool
  default     = true
}

variable "cost_anomaly_monitor_type" {
  description = <<-EOT
    Type of anomaly monitor:
      - DIMENSIONAL: Monitor by a single dimension (SERVICE or LINKED_ACCOUNT)
      - CUSTOM: Monitor using custom cost filters
  EOT
  type        = string
  default     = "DIMENSIONAL"

  validation {
    condition     = contains(["DIMENSIONAL", "CUSTOM"], var.cost_anomaly_monitor_type)
    error_message = "Anomaly monitor type must be DIMENSIONAL or CUSTOM."
  }
}

variable "cost_anomaly_monitor_dimension" {
  description = "Dimension for DIMENSIONAL monitor type (SERVICE or LINKED_ACCOUNT)"
  type        = string
  default     = "SERVICE"

  validation {
    condition     = contains(["SERVICE", "LINKED_ACCOUNT"], var.cost_anomaly_monitor_dimension)
    error_message = "Anomaly monitor dimension must be SERVICE or LINKED_ACCOUNT."
  }
}

variable "cost_anomaly_threshold_expression" {
  description = "Absolute dollar amount threshold above expected spend to trigger anomaly alerts"
  type        = number
  default     = 100

  validation {
    condition     = var.cost_anomaly_threshold_expression >= 0
    error_message = "Anomaly threshold must be non-negative."
  }
}

variable "cost_anomaly_threshold_percentage" {
  description = "Percentage above expected spend to trigger anomaly alerts"
  type        = number
  default     = 10

  validation {
    condition     = var.cost_anomaly_threshold_percentage >= 0 && var.cost_anomaly_threshold_percentage <= 100
    error_message = "Anomaly threshold percentage must be between 0 and 100."
  }
}

variable "cost_enable_service_anomaly_monitors" {
  description = "Enable individual anomaly monitors for specific AWS services"
  type        = bool
  default     = false
}

variable "cost_services_for_anomaly_detection" {
  description = "List of AWS services for individual anomaly monitors (when cost_enable_service_anomaly_monitors is true)"
  type        = list(string)
  default = [
    "AmazonEC2",
    "AmazonS3",
    "AWSDataTransfer"
  ]
}

# -----------------------------------------------------------------------------
# SNS Notification Configuration
# -----------------------------------------------------------------------------

variable "cost_sns_topic_arn" {
  description = "ARN of existing SNS topic for cost anomaly alerts (if not provided, a new one will be created)"
  type        = string
  default     = null
}

variable "cost_alert_email_addresses" {
  description = "Email addresses to receive cost anomaly alerts"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for email in var.cost_alert_email_addresses : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))])
    error_message = "All email addresses must be valid email format."
  }
}

# -----------------------------------------------------------------------------
# Dashboard Widget Configuration
# -----------------------------------------------------------------------------

variable "cost_metric_period" {
  description = <<-EOT
    Period in seconds for cost metric calculations. Billing metrics update
    approximately every 4-6 hours, so shorter periods may show stale data.
    Recommended: 86400 (1 day)
  EOT
  type        = number
  default     = 86400 # 1 day - billing metrics are updated ~3 times daily

  validation {
    condition     = var.cost_metric_period >= 3600
    error_message = "Cost metric period must be at least 3600 seconds (1 hour)."
  }
}

variable "cost_services_to_track" {
  description = <<-EOT
    List of AWS services to track in cost dashboard. Service names must match
    the exact service name as it appears in AWS Cost Explorer (e.g., "AmazonEC2",
    not "EC2" or "Amazon EC2").
  EOT
  type        = list(string)
  default = [
    "AmazonEC2",
    "AmazonEBS",
    "AmazonS3",
    "AmazonVPC",
    "AWSDataTransfer",
    "AmazonCloudWatch",
    "AWSSecretsManager",
    "AWSELB"
  ]
}

variable "cost_instance_types_to_track" {
  description = "List of EC2 instance types to track for running hours and cost analysis"
  type        = list(string)
  default = [
    "t3.micro",
    "t3.small",
    "t3.medium",
    "t3.large",
    "m5.large",
    "m5.xlarge",
    "r5.large"
  ]
}

# -----------------------------------------------------------------------------
# Environment Comparison Configuration
# -----------------------------------------------------------------------------

variable "cost_enable_environment_comparison" {
  description = "Enable cost comparison widgets across environments"
  type        = bool
  default     = false
}

variable "cost_environments_to_compare" {
  description = "List of environment names for cost comparison widgets"
  type        = list(string)
  default     = ["dev", "staging", "production"]

  validation {
    condition     = length(var.cost_environments_to_compare) > 0
    error_message = "At least one environment must be specified for comparison."
  }
}

variable "cost_environment_account_map" {
  description = <<-EOT
    Map of environment names to AWS account IDs for multi-account cost comparison.
    Only required when cost_enable_environment_comparison is true.
    Example: { "dev" = "123456789012", "staging" = "234567890123" }
  EOT
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# KMS Encryption Configuration
# -----------------------------------------------------------------------------

variable "cost_kms_key_arn" {
  description = "ARN of KMS key for encrypting SNS topic (optional, uses AWS managed key if not specified)"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Tagging Configuration
# -----------------------------------------------------------------------------

variable "cost_tags" {
  description = "Common tags to apply to all cost monitoring resources"
  type        = map(string)
  default     = {}
}
