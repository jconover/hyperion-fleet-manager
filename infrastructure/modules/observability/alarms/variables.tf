# -----------------------------------------------------------------------------
# Variables for CloudWatch Alarms Module
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod", "development", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, development, production."
  }
}

variable "project_name" {
  description = "Name of the project, used for resource naming and tagging"
  type        = string
  default     = "hyperion"

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 32
    error_message = "Project name must be between 1 and 32 characters."
  }
}

# -----------------------------------------------------------------------------
# Instance Configuration
# -----------------------------------------------------------------------------

variable "instance_ids" {
  description = "List of EC2 instance IDs to monitor"
  type        = list(string)
  default     = []
}

variable "ami_id" {
  description = "AMI ID used for CloudWatch Agent metric dimensions (Windows Server)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Instance type used for CloudWatch Agent metric dimensions"
  type        = string
  default     = ""
}

variable "ebs_volume_ids" {
  description = "List of EBS volume IDs to monitor for burst balance"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Auto Scaling Group Configuration
# -----------------------------------------------------------------------------

variable "auto_scaling_group_names" {
  description = "List of Auto Scaling group names to monitor"
  type        = list(string)
  default     = []
}

variable "asg_minimum_capacity" {
  description = "Map of ASG names to their minimum required capacity for alarms"
  type        = map(number)
  default     = {}

  # Example:
  # {
  #   "hyperion-web-asg" = 2
  #   "hyperion-api-asg" = 3
  # }
}

# -----------------------------------------------------------------------------
# Alarm Thresholds
# -----------------------------------------------------------------------------

variable "alarm_thresholds" {
  description = "Map of alarm thresholds to override defaults"
  type        = map(number)
  default     = {}

  # Default thresholds (set in locals):
  # cpu_percent              = 80    # CPU utilization threshold
  # memory_percent           = 85    # Memory utilization threshold
  # disk_free_percent        = 15    # Disk free space threshold
  # network_bytes_per_second = 100000000  # Network throughput (100 MB/s)
  # ebs_burst_balance        = 20    # EBS burst balance threshold
  # health_check_threshold   = 1     # Health check success threshold
}

variable "evaluation_periods" {
  description = "Map of metric types to their evaluation periods"
  type        = map(number)
  default = {
    cpu     = 5
    memory  = 5
    disk    = 3
    network = 3
    ebs     = 3
  }
}

variable "period_seconds" {
  description = "Map of metric types to their period in seconds"
  type        = map(number)
  default = {
    cpu     = 60
    memory  = 60
    disk    = 300
    network = 300
    ebs     = 300
  }
}

# -----------------------------------------------------------------------------
# Feature Toggles
# -----------------------------------------------------------------------------

variable "enable_memory_alarms" {
  description = "Enable memory utilization alarms (requires CloudWatch Agent)"
  type        = bool
  default     = true
}

variable "enable_disk_alarms" {
  description = "Enable disk space alarms (requires CloudWatch Agent)"
  type        = bool
  default     = true
}

variable "enable_network_alarms" {
  description = "Enable network utilization alarms"
  type        = bool
  default     = true
}

variable "enable_ebs_alarms" {
  description = "Enable EBS burst balance alarms"
  type        = bool
  default     = true
}

variable "enable_ssm_alarms" {
  description = "Enable SSM Agent connectivity alarms"
  type        = bool
  default     = true
}

variable "enable_composite_alarms" {
  description = "Enable composite alarms for aggregated alerting"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Notification Configuration - Email
# -----------------------------------------------------------------------------

variable "notification_emails_critical" {
  description = "List of email addresses for critical alert notifications (pages on-call)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.notification_emails_critical :
      can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All email addresses must be valid email format."
  }
}

variable "notification_emails_warning" {
  description = "List of email addresses for warning alert notifications (creates tickets)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.notification_emails_warning :
      can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All email addresses must be valid email format."
  }
}

variable "notification_emails_info" {
  description = "List of email addresses for info alert notifications (dashboard/logging)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.notification_emails_info :
      can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All email addresses must be valid email format."
  }
}

# -----------------------------------------------------------------------------
# Notification Configuration - SMS
# -----------------------------------------------------------------------------

variable "notification_phone_numbers" {
  description = "List of phone numbers for critical SMS notifications (E.164 format, e.g., +12025551234)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for phone in var.notification_phone_numbers :
      can(regex("^\\+[1-9]\\d{1,14}$", phone))
    ])
    error_message = "Phone numbers must be in E.164 format (e.g., +12025551234)."
  }
}

# -----------------------------------------------------------------------------
# Notification Configuration - Lambda
# -----------------------------------------------------------------------------

variable "lambda_function_arn_critical" {
  description = "ARN of Lambda function to invoke for critical alerts (e.g., PagerDuty integration)"
  type        = string
  default     = ""
}

variable "lambda_function_arn_warning" {
  description = "ARN of Lambda function to invoke for warning alerts (e.g., ticket creation)"
  type        = string
  default     = ""
}

variable "lambda_function_arn_info" {
  description = "ARN of Lambda function to invoke for info alerts (e.g., logging/metrics)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Notification Configuration - Webhooks
# -----------------------------------------------------------------------------

variable "webhook_endpoints_critical" {
  description = "List of HTTPS webhook endpoints for critical alerts (e.g., PagerDuty, Opsgenie)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for url in var.webhook_endpoints_critical :
      can(regex("^https://", url))
    ])
    error_message = "Webhook endpoints must be HTTPS URLs."
  }
}

variable "webhook_endpoints_warning" {
  description = "List of HTTPS webhook endpoints for warning alerts (e.g., ServiceNow)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for url in var.webhook_endpoints_warning :
      can(regex("^https://", url))
    ])
    error_message = "Webhook endpoints must be HTTPS URLs."
  }
}

# -----------------------------------------------------------------------------
# Application Health Check Configuration
# -----------------------------------------------------------------------------

variable "health_check_configs" {
  description = "Map of application health check configurations"
  type = map(object({
    metric_name        = string
    namespace          = string
    period             = number
    evaluation_periods = number
    description        = string
    dimensions         = map(string)
  }))
  default = {}

  # Example:
  # {
  #   "web-app" = {
  #     metric_name        = "HealthCheckStatus"
  #     namespace          = "Custom/Application"
  #     period             = 60
  #     evaluation_periods = 3
  #     description        = "Web application health check"
  #     dimensions = {
  #       Application = "web-app"
  #       Environment = "prod"
  #     }
  #   }
  # }
}

variable "target_group_arns" {
  description = "Map of target group configurations for health monitoring"
  type = map(object({
    arn_suffix               = string
    load_balancer_arn_suffix = string
    minimum_healthy_hosts    = number
  }))
  default = {}

  # Example:
  # {
  #   "web-tg" = {
  #     arn_suffix               = "targetgroup/web-tg/1234567890123456"
  #     load_balancer_arn_suffix = "app/web-alb/1234567890123456"
  #     minimum_healthy_hosts    = 2
  #   }
  # }
}

# -----------------------------------------------------------------------------
# SNS Configuration
# -----------------------------------------------------------------------------

variable "sns_kms_key_id" {
  description = "KMS key ID for SNS topic encryption (uses AWS managed key if empty)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
