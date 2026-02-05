# =============================================================================
# Variables for SNS Alerting Module
# =============================================================================

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (e.g., dev, staging, production)"
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|production|prod)$", var.environment))
    error_message = "Environment must be dev, staging, production, or prod."
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "hyperion"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

# -----------------------------------------------------------------------------
# Common Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# KMS Configuration
# -----------------------------------------------------------------------------

variable "kms_key_arn" {
  description = "ARN of existing KMS key for SNS encryption. If not provided, a new key will be created."
  type        = string
  default     = null
}

variable "kms_key_deletion_window" {
  description = "Duration in days after which the KMS key is deleted after destruction (7-30 days)"
  type        = number
  default     = 30

  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

# -----------------------------------------------------------------------------
# Email Subscription Configuration
# -----------------------------------------------------------------------------

variable "email_endpoints" {
  description = <<-EOF
    Map of email addresses by severity level for SNS subscriptions.
    Keys: critical, warning, info, security, cost
    Example: {
      critical = ["oncall@example.com", "sre@example.com"]
      warning  = ["ops@example.com"]
      info     = ["info@example.com"]
      security = ["security@example.com"]
      cost     = ["finops@example.com"]
    }
  EOF
  type        = map(list(string))
  default     = {}

  validation {
    condition = alltrue([
      for severity, emails in var.email_endpoints : contains(["critical", "warning", "info", "security", "cost"], severity)
    ])
    error_message = "Email endpoint keys must be one of: critical, warning, info, security, cost."
  }

  validation {
    condition = alltrue(flatten([
      for severity, emails in var.email_endpoints : [
        for email in emails : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
      ]
    ]))
    error_message = "All email addresses must be in valid email format."
  }
}

# -----------------------------------------------------------------------------
# SMS Subscription Configuration
# -----------------------------------------------------------------------------

variable "sms_endpoints" {
  description = <<-EOF
    List of phone numbers for SMS subscriptions (critical alerts only).
    Phone numbers must be in E.164 format (e.g., +14155552671).
    GDPR Note: Ensure proper consent is obtained for SMS communications.
  EOF
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for phone in var.sms_endpoints : can(regex("^\\+[1-9]\\d{1,14}$", phone))
    ])
    error_message = "Phone numbers must be in E.164 format (e.g., +14155552671)."
  }
}

variable "enable_security_sms" {
  description = "Enable SMS notifications for high-severity security alerts"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Webhook/HTTPS Subscription Configuration
# -----------------------------------------------------------------------------

variable "webhook_endpoints" {
  description = <<-EOF
    Map of webhook URLs by severity level.
    Keys: critical, warning, info, security, cost
    Values: Map of endpoint_name => URL
    Example: {
      critical = {
        pagerduty = "https://events.pagerduty.com/integration/xxx/enqueue"
      }
      info = {
        slack = "https://hooks.slack.com/services/xxx"
      }
    }
  EOF
  type        = map(map(string))
  default     = {}

  validation {
    condition = alltrue([
      for severity, endpoints in var.webhook_endpoints : contains(["critical", "warning", "info", "security", "cost"], severity)
    ])
    error_message = "Webhook endpoint keys must be one of: critical, warning, info, security, cost."
  }

  validation {
    condition = alltrue(flatten([
      for severity, endpoints in var.webhook_endpoints : [
        for name, url in endpoints : can(regex("^https://", url))
      ]
    ]))
    error_message = "All webhook URLs must use HTTPS."
  }
}

variable "webhook_auto_confirm" {
  description = "Whether HTTPS endpoints should auto-confirm subscription"
  type        = bool
  default     = false
}

variable "webhook_confirmation_timeout" {
  description = "Timeout in minutes for webhook subscription confirmation"
  type        = number
  default     = 5

  validation {
    condition     = var.webhook_confirmation_timeout >= 1 && var.webhook_confirmation_timeout <= 1440
    error_message = "Webhook confirmation timeout must be between 1 and 1440 minutes."
  }
}

variable "webhook_raw_message_delivery" {
  description = "Whether to deliver raw message to HTTPS endpoints (no SNS metadata)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Slack Integration
# -----------------------------------------------------------------------------

variable "slack_webhook_url" {
  description = "Slack webhook URL for alert notifications (optional)"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.slack_webhook_url == null || can(regex("^https://hooks\\.slack\\.com/", var.slack_webhook_url))
    error_message = "Slack webhook URL must start with https://hooks.slack.com/"
  }
}

# -----------------------------------------------------------------------------
# PagerDuty Integration
# -----------------------------------------------------------------------------

variable "pagerduty_integration_key" {
  description = "PagerDuty Events API v2 routing key for alert escalation (optional)"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.pagerduty_integration_key == null || can(regex("^[a-zA-Z0-9]{32}$", var.pagerduty_integration_key))
    error_message = "PagerDuty integration key must be a 32-character alphanumeric string."
  }
}

# -----------------------------------------------------------------------------
# Lambda Processor Configuration
# -----------------------------------------------------------------------------

variable "enable_lambda_processor" {
  description = "Enable Lambda function for alert enrichment and routing"
  type        = bool
  default     = true
}

variable "lambda_log_level" {
  description = "Log level for Lambda function (DEBUG, INFO, WARNING, ERROR)"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.lambda_log_level)
    error_message = "Lambda log level must be one of: DEBUG, INFO, WARNING, ERROR."
  }
}

variable "lambda_log_retention_days" {
  description = "Number of days to retain Lambda function logs"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.lambda_log_retention_days)
    error_message = "Lambda log retention days must be a valid CloudWatch Logs retention period."
  }
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrent executions for Lambda function (-1 for no limit)"
  type        = number
  default     = 10

  validation {
    condition     = var.lambda_reserved_concurrency >= -1 && var.lambda_reserved_concurrency <= 1000
    error_message = "Lambda reserved concurrency must be between -1 (no limit) and 1000."
  }
}

variable "lambda_vpc_config" {
  description = "VPC configuration for Lambda function (optional)"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for Lambda function"
  type        = bool
  default     = false
}

variable "enable_lambda_alarms" {
  description = "Enable CloudWatch alarms for Lambda function monitoring"
  type        = bool
  default     = true
}

variable "runbook_base_url" {
  description = "Base URL for runbook documentation links"
  type        = string
  default     = "https://runbooks.example.com"
}

variable "enable_pii_redaction" {
  description = "Enable automatic PII redaction in alert messages (GDPR compliance)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# SQS Configuration
# -----------------------------------------------------------------------------

variable "enable_sqs_subscriptions" {
  description = "Enable SQS queue subscriptions for critical and security topics"
  type        = bool
  default     = true
}

variable "enable_aggregate_queue" {
  description = "Enable aggregate SQS queue for all alerts (centralized processing)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# EventBridge Configuration
# -----------------------------------------------------------------------------

variable "enable_security_hub_rules" {
  description = "Enable EventBridge rules for Security Hub findings"
  type        = bool
  default     = false
}

variable "enable_cost_anomaly_rules" {
  description = "Enable EventBridge rules for Cost Anomaly Detection"
  type        = bool
  default     = true
}

variable "enable_iam_monitoring" {
  description = "Enable EventBridge rules for IAM changes (requires CloudTrail)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Cross-Account Configuration
# -----------------------------------------------------------------------------

variable "enable_cross_account_events" {
  description = "Enable cross-account event bus for multi-account alerting"
  type        = bool
  default     = false
}

variable "cross_account_ids" {
  description = "List of AWS account IDs allowed to send events to cross-account bus"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for account_id in var.cross_account_ids : can(regex("^\\d{12}$", account_id))
    ])
    error_message = "AWS account IDs must be 12-digit numbers."
  }
}
