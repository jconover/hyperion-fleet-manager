# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - Security Dashboard Module Variables
# -----------------------------------------------------------------------------
# This file defines all input variables for the CloudWatch Security Dashboard
# module. Variables are prefixed with "security_" to avoid conflicts with
# existing dashboard variables.
#
# The Security Dashboard monitors:
# - GuardDuty findings by severity
# - Security Hub compliance score and findings
# - Failed Windows login attempts (Event 4625)
# - IAM policy changes via CloudTrail
# - Security group changes via CloudTrail
# - VPC Flow Log rejected packets
# - KMS key usage patterns
# - Secrets Manager access patterns
# - CloudTrail API errors
# - AWS Config rule compliance
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "security_environment" {
  description = "Environment name (e.g., dev, staging, production). Used in dashboard naming and tagging."
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|production|prod)$", var.security_environment))
    error_message = "Environment must be dev, staging, or production/prod."
  }
}

variable "security_project_name" {
  description = "Project name used for resource naming, tagging, and CloudWatch namespace."
  type        = string
  default     = "hyperion"

  validation {
    condition     = length(var.security_project_name) > 0 && length(var.security_project_name) <= 32
    error_message = "Project name must be between 1 and 32 characters."
  }
}

# -----------------------------------------------------------------------------
# Security Service Integration
# -----------------------------------------------------------------------------

variable "security_guardduty_detector_id" {
  description = "GuardDuty detector ID for monitoring threat findings. Leave empty if GuardDuty is not enabled."
  type        = string
  default     = ""

  validation {
    condition     = var.security_guardduty_detector_id == "" || can(regex("^[a-z0-9]{32}$", var.security_guardduty_detector_id))
    error_message = "GuardDuty detector ID must be a 32-character lowercase alphanumeric string or empty."
  }
}

variable "security_hub_enabled" {
  description = "Whether AWS Security Hub is enabled in the account. Enables compliance score and findings widgets."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Log Group Configuration
# -----------------------------------------------------------------------------

variable "security_vpc_flow_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs. Used to monitor rejected network traffic. Leave empty if not configured."
  type        = string
  default     = ""

  validation {
    condition     = var.security_vpc_flow_log_group_name == "" || can(regex("^[a-zA-Z0-9/_.-]+$", var.security_vpc_flow_log_group_name))
    error_message = "VPC Flow Log group name must contain only alphanumeric characters, forward slashes, underscores, periods, and hyphens."
  }
}

variable "security_cloudtrail_log_group_name" {
  description = "CloudWatch Log Group name for CloudTrail logs. Used to monitor IAM, security group, and API changes. Leave empty if not configured."
  type        = string
  default     = ""

  validation {
    condition     = var.security_cloudtrail_log_group_name == "" || can(regex("^[a-zA-Z0-9/_.-]+$", var.security_cloudtrail_log_group_name))
    error_message = "CloudTrail Log group name must contain only alphanumeric characters, forward slashes, underscores, periods, and hyphens."
  }
}

variable "security_windows_log_group_name" {
  description = "CloudWatch Log Group name for Windows Security logs. Used to monitor failed login attempts (Event ID 4625). Leave empty if not configured."
  type        = string
  default     = ""

  validation {
    condition     = var.security_windows_log_group_name == "" || can(regex("^[a-zA-Z0-9/_.-]+$", var.security_windows_log_group_name))
    error_message = "Windows Security Log group name must contain only alphanumeric characters, forward slashes, underscores, periods, and hyphens."
  }
}

# -----------------------------------------------------------------------------
# Security Alarm Thresholds
# -----------------------------------------------------------------------------

variable "security_failed_login_threshold" {
  description = "Number of failed login attempts in 5 minutes to trigger an alarm. Adjust based on fleet size."
  type        = number
  default     = 10

  validation {
    condition     = var.security_failed_login_threshold >= 1 && var.security_failed_login_threshold <= 1000
    error_message = "Failed login threshold must be between 1 and 1000."
  }
}

variable "security_rejected_packets_threshold" {
  description = "Number of rejected VPC Flow Log packets in 5 minutes to trigger an alarm. Higher values for busy networks."
  type        = number
  default     = 1000

  validation {
    condition     = var.security_rejected_packets_threshold >= 1
    error_message = "Rejected packets threshold must be at least 1."
  }
}

variable "security_api_error_threshold" {
  description = "Number of CloudTrail API authorization errors in 5 minutes to trigger an alarm."
  type        = number
  default     = 5

  validation {
    condition     = var.security_api_error_threshold >= 1
    error_message = "API error threshold must be at least 1."
  }
}

# -----------------------------------------------------------------------------
# Alarm Actions
# -----------------------------------------------------------------------------

variable "security_alarm_actions" {
  description = "List of ARNs to notify when any alarm transitions to ALARM state. Typically SNS topic ARNs."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.security_alarm_actions : can(regex("^arn:aws:sns:[a-z0-9-]+:[0-9]{12}:.+$", arn))])
    error_message = "All alarm actions must be valid SNS topic ARNs."
  }
}

variable "security_ok_actions" {
  description = "List of ARNs to notify when any alarm transitions to OK state. Typically SNS topic ARNs."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.security_ok_actions : can(regex("^arn:aws:sns:[a-z0-9-]+:[0-9]{12}:.+$", arn))])
    error_message = "All OK actions must be valid SNS topic ARNs."
  }
}

# -----------------------------------------------------------------------------
# Security Dashboard Configuration
# -----------------------------------------------------------------------------

variable "security_enable_dashboard" {
  description = "Enable the Security Dashboard. Set to false to skip creation of security monitoring dashboard."
  type        = bool
  default     = true
}

variable "security_enable_alarms" {
  description = "Enable CloudWatch alarms for security events. Set to false to create dashboard only without alarms."
  type        = bool
  default     = true
}

variable "security_alarm_evaluation_periods" {
  description = "Number of periods to evaluate before triggering a security alarm. Higher values reduce false positives."
  type        = number
  default     = 1

  validation {
    condition     = var.security_alarm_evaluation_periods >= 1 && var.security_alarm_evaluation_periods <= 10
    error_message = "Security alarm evaluation periods must be between 1 and 10."
  }
}

variable "security_enable_trend_analysis" {
  description = "Enable time-based trend analysis widgets for security events. May increase CloudWatch costs."
  type        = bool
  default     = true
}

variable "security_trend_analysis_hours" {
  description = "Number of hours to include in trend analysis queries. Longer periods may affect query performance."
  type        = number
  default     = 24

  validation {
    condition     = var.security_trend_analysis_hours >= 1 && var.security_trend_analysis_hours <= 168
    error_message = "Trend analysis period must be between 1 and 168 hours (7 days)."
  }
}

# -----------------------------------------------------------------------------
# Tagging
# -----------------------------------------------------------------------------

variable "security_tags" {
  description = "A map of tags to add to all security dashboard resources"
  type        = map(string)
  default     = {}
}
