variable "environment" {
  description = "Environment name (e.g., dev, staging, production)"
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|production|prod)$", var.environment))
    error_message = "Environment must be dev, staging, or production/prod."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Log Configuration
variable "log_retention_days" {
  description = "Number of days to retain logs in CloudWatch"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention period."
  }
}

variable "security_log_retention_days" {
  description = "Number of days to retain security logs (typically longer than standard logs)"
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.security_log_retention_days)
    error_message = "Security log retention days must be a valid CloudWatch Logs retention period."
  }
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting CloudWatch Logs and SNS topic (optional)"
  type        = string
  default     = null
}

# CloudWatch Configuration
variable "cloudwatch_namespace" {
  description = "CloudWatch custom metrics namespace"
  type        = string
  default     = "FleetManager"
}

# SNS Configuration
variable "alert_email_addresses" {
  description = "List of email addresses to receive CloudWatch alerts"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for email in var.alert_email_addresses : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))])
    error_message = "All email addresses must be valid email format."
  }
}

# Instance Configuration
variable "instance_ids" {
  description = "List of EC2 instance IDs to monitor"
  type        = list(string)
  default     = []
}

variable "enable_instance_alarms" {
  description = "Enable CloudWatch alarms for EC2 instances"
  type        = bool
  default     = true
}

# Target Group Configuration
variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group to monitor (required for target group alarms)"
  type        = string
  default     = ""
}

variable "load_balancer_arn_suffix" {
  description = "ARN suffix of the load balancer (required for target group alarms)"
  type        = string
  default     = ""
}

variable "enable_target_group_alarms" {
  description = "Enable CloudWatch alarms for target group health"
  type        = bool
  default     = true
}

# Alarm Period Configuration
variable "alarm_period" {
  description = "Period in seconds for CloudWatch alarm evaluation"
  type        = number
  default     = 300

  validation {
    condition     = var.alarm_period >= 60 && var.alarm_period % 60 == 0
    error_message = "Alarm period must be at least 60 seconds and a multiple of 60."
  }
}

# CPU Alarm Configuration
variable "cpu_threshold_percent" {
  description = "CPU utilization threshold percentage to trigger alarm"
  type        = number
  default     = 80

  validation {
    condition     = var.cpu_threshold_percent >= 0 && var.cpu_threshold_percent <= 100
    error_message = "CPU threshold must be between 0 and 100."
  }
}

variable "cpu_evaluation_periods" {
  description = "Number of periods to evaluate CPU threshold"
  type        = number
  default     = 3

  validation {
    condition     = var.cpu_evaluation_periods >= 1
    error_message = "CPU evaluation periods must be at least 1."
  }
}

# Memory Alarm Configuration
variable "memory_threshold_percent" {
  description = "Memory utilization threshold percentage to trigger alarm"
  type        = number
  default     = 85

  validation {
    condition     = var.memory_threshold_percent >= 0 && var.memory_threshold_percent <= 100
    error_message = "Memory threshold must be between 0 and 100."
  }
}

variable "memory_evaluation_periods" {
  description = "Number of periods to evaluate memory threshold"
  type        = number
  default     = 3

  validation {
    condition     = var.memory_evaluation_periods >= 1
    error_message = "Memory evaluation periods must be at least 1."
  }
}

# Disk Alarm Configuration
variable "disk_free_threshold_percent" {
  description = "Minimum free disk space percentage before triggering alarm"
  type        = number
  default     = 15

  validation {
    condition     = var.disk_free_threshold_percent >= 0 && var.disk_free_threshold_percent <= 100
    error_message = "Disk free threshold must be between 0 and 100."
  }
}

variable "disk_evaluation_periods" {
  description = "Number of periods to evaluate disk space threshold"
  type        = number
  default     = 2

  validation {
    condition     = var.disk_evaluation_periods >= 1
    error_message = "Disk evaluation periods must be at least 1."
  }
}

variable "disk_mount_path" {
  description = "Disk mount path to monitor"
  type        = string
  default     = "/"
}

variable "disk_filesystem_type" {
  description = "Filesystem type to monitor"
  type        = string
  default     = "ext4"
}

# Target Group Alarm Configuration
variable "unhealthy_host_threshold" {
  description = "Number of unhealthy hosts to trigger alarm"
  type        = number
  default     = 0

  validation {
    condition     = var.unhealthy_host_threshold >= 0
    error_message = "Unhealthy host threshold must be non-negative."
  }
}

variable "unhealthy_host_evaluation_periods" {
  description = "Number of periods to evaluate unhealthy host threshold"
  type        = number
  default     = 2

  validation {
    condition     = var.unhealthy_host_evaluation_periods >= 1
    error_message = "Unhealthy host evaluation periods must be at least 1."
  }
}

# Application Error Alarm Configuration
variable "error_rate_threshold" {
  description = "Application error count per minute to trigger alarm"
  type        = number
  default     = 10

  validation {
    condition     = var.error_rate_threshold >= 0
    error_message = "Error rate threshold must be non-negative."
  }
}

variable "error_evaluation_periods" {
  description = "Number of periods to evaluate error rate threshold"
  type        = number
  default     = 2

  validation {
    condition     = var.error_evaluation_periods >= 1
    error_message = "Error evaluation periods must be at least 1."
  }
}

# EventBridge Configuration
variable "health_check_schedule" {
  description = "Cron expression for scheduled health checks"
  type        = string
  default     = "rate(5 minutes)"

  validation {
    condition     = can(regex("^(rate\\([0-9]+ (minute|minutes|hour|hours|day|days)\\)|cron\\(.+\\))$", var.health_check_schedule))
    error_message = "Health check schedule must be a valid EventBridge schedule expression."
  }
}

variable "enable_scheduled_health_checks" {
  description = "Enable scheduled health check events"
  type        = bool
  default     = true
}

variable "backup_schedule" {
  description = "Cron expression for scheduled backups"
  type        = string
  default     = "cron(0 2 * * ? *)"

  validation {
    condition     = can(regex("^(rate\\([0-9]+ (minute|minutes|hour|hours|day|days)\\)|cron\\(.+\\))$", var.backup_schedule))
    error_message = "Backup schedule must be a valid EventBridge schedule expression."
  }
}

variable "enable_scheduled_backups" {
  description = "Enable scheduled backup events"
  type        = bool
  default     = true
}

# X-Ray Configuration
variable "enable_xray" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = false
}

variable "xray_sampling_priority" {
  description = "Priority of the X-Ray sampling rule (lower number = higher priority)"
  type        = number
  default     = 1000

  validation {
    condition     = var.xray_sampling_priority >= 1 && var.xray_sampling_priority <= 9999
    error_message = "X-Ray sampling priority must be between 1 and 9999."
  }
}

variable "xray_reservoir_size" {
  description = "Number of requests per second to record at any rate"
  type        = number
  default     = 1

  validation {
    condition     = var.xray_reservoir_size >= 0
    error_message = "X-Ray reservoir size must be non-negative."
  }
}

variable "xray_fixed_rate" {
  description = "Percentage of requests to record after the reservoir is exhausted (0.0 to 1.0)"
  type        = number
  default     = 0.05

  validation {
    condition     = var.xray_fixed_rate >= 0 && var.xray_fixed_rate <= 1
    error_message = "X-Ray fixed rate must be between 0.0 and 1.0."
  }
}

variable "xray_service_name" {
  description = "Service name for X-Ray tracing"
  type        = string
  default     = "fleet-manager"
}

variable "xray_response_time_threshold" {
  description = "Response time threshold in seconds for X-Ray error detection"
  type        = number
  default     = 3

  validation {
    condition     = var.xray_response_time_threshold > 0
    error_message = "X-Ray response time threshold must be positive."
  }
}

variable "xray_insights_enabled" {
  description = "Enable X-Ray Insights for automatic anomaly detection"
  type        = bool
  default     = true
}

variable "xray_notifications_enabled" {
  description = "Enable X-Ray notifications for detected anomalies"
  type        = bool
  default     = false
}
