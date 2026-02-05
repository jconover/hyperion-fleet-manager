# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - Fleet Health Dashboard Variables
# -----------------------------------------------------------------------------
# This file defines all input variables for the CloudWatch Fleet Health
# Dashboard module. Variables follow the project naming conventions and include
# comprehensive validation where applicable.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (e.g., dev, staging, production). Used in dashboard naming and tagging."
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|production|prod)$", var.environment))
    error_message = "Environment must be dev, staging, or production/prod."
  }
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "hyperion"

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 32
    error_message = "Project name must be between 1 and 32 characters."
  }
}

variable "aws_region" {
  description = "AWS region where the dashboard will be created and metrics will be sourced"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be a valid region format (e.g., us-east-1, eu-west-2)."
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Group Configuration
# -----------------------------------------------------------------------------

variable "auto_scaling_group_names" {
  description = "List of Auto Scaling Group names to monitor. Required for ASG capacity widgets."
  type        = list(string)

  validation {
    condition     = length(var.auto_scaling_group_names) > 0
    error_message = "At least one Auto Scaling Group name must be provided."
  }
}

# -----------------------------------------------------------------------------
# Instance Configuration
# -----------------------------------------------------------------------------

variable "instance_ids" {
  description = "List of specific EC2 instance IDs to monitor. If empty, dashboard uses aggregate metrics from ASGs."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.instance_ids : can(regex("^i-[a-f0-9]{8,17}$", id))])
    error_message = "All instance IDs must be valid EC2 instance ID format (i-xxxxxxxxxxxxxxxxx)."
  }
}

# -----------------------------------------------------------------------------
# Alarm Thresholds
# -----------------------------------------------------------------------------

variable "alarm_thresholds" {
  description = <<-EOT
    Map of alarm threshold values for dashboard annotations.
    Keys:
      - cpu_percent: CPU utilization percentage threshold (default: 80)
      - memory_percent: Memory utilization percentage threshold (default: 85)
      - disk_percent: Disk utilization percentage threshold (default: 85)
      - network_in_bytes: Network ingress bytes threshold (default: 1073741824 = 1GB)
      - network_out_bytes: Network egress bytes threshold (default: 1073741824 = 1GB)
      - status_check_failed: Status check failure threshold (default: 1)
  EOT
  type = object({
    cpu_percent         = optional(number, 80)
    memory_percent      = optional(number, 85)
    disk_percent        = optional(number, 85)
    network_in_bytes    = optional(number, 1073741824)
    network_out_bytes   = optional(number, 1073741824)
    status_check_failed = optional(number, 1)
  })
  default = {}

  validation {
    condition     = var.alarm_thresholds.cpu_percent >= 0 && var.alarm_thresholds.cpu_percent <= 100
    error_message = "CPU threshold must be between 0 and 100."
  }

  validation {
    condition     = var.alarm_thresholds.memory_percent >= 0 && var.alarm_thresholds.memory_percent <= 100
    error_message = "Memory threshold must be between 0 and 100."
  }

  validation {
    condition     = var.alarm_thresholds.disk_percent >= 0 && var.alarm_thresholds.disk_percent <= 100
    error_message = "Disk threshold must be between 0 and 100."
  }
}

# -----------------------------------------------------------------------------
# Dashboard Configuration
# -----------------------------------------------------------------------------

variable "dashboard_refresh_interval" {
  description = "Dashboard auto-refresh interval. Valid values: auto, 10, 30, 60, 300, 900, 3600 (seconds). Use 'auto' for CloudWatch default."
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "10", "30", "60", "300", "900", "3600"], var.dashboard_refresh_interval)
    error_message = "Dashboard refresh interval must be one of: auto, 10, 30, 60, 300, 900, 3600."
  }
}

variable "cloudwatch_namespace" {
  description = "CloudWatch custom metrics namespace for CloudWatch Agent metrics (memory, disk)"
  type        = string
  default     = "CWAgent"
}

variable "ssm_namespace" {
  description = "CloudWatch namespace for SSM agent metrics"
  type        = string
  default     = "AWS/SSM"
}

# -----------------------------------------------------------------------------
# Metric Period Configuration
# -----------------------------------------------------------------------------

variable "metric_period_standard" {
  description = "Standard metric period in seconds for most widgets"
  type        = number
  default     = 300

  validation {
    condition     = contains([60, 300, 900, 3600], var.metric_period_standard)
    error_message = "Standard metric period must be 60, 300, 900, or 3600 seconds."
  }
}

variable "metric_period_detailed" {
  description = "Detailed metric period in seconds for high-resolution widgets"
  type        = number
  default     = 60

  validation {
    condition     = contains([1, 5, 10, 30, 60], var.metric_period_detailed)
    error_message = "Detailed metric period must be 1, 5, 10, 30, or 60 seconds."
  }
}

# -----------------------------------------------------------------------------
# Feature Toggles
# -----------------------------------------------------------------------------

variable "enable_ssm_status_widget" {
  description = "Enable SSM agent status widget. Requires SSM agent metrics to be published."
  type        = bool
  default     = true
}

variable "enable_detailed_instance_metrics" {
  description = "Enable detailed per-instance metrics widgets. Only applicable when instance_ids is populated."
  type        = bool
  default     = false
}

variable "enable_disk_by_volume" {
  description = "Enable disk utilization breakdown by volume. Requires CloudWatch agent with disk metrics."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Volume Configuration
# -----------------------------------------------------------------------------

variable "ebs_volume_ids" {
  description = "List of EBS volume IDs to monitor for disk metrics. If empty, uses aggregate disk metrics."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.ebs_volume_ids : can(regex("^vol-[a-f0-9]{8,17}$", id))])
    error_message = "All volume IDs must be valid EBS volume ID format (vol-xxxxxxxxxxxxxxxxx)."
  }
}

variable "disk_mount_paths" {
  description = "List of disk mount paths to monitor (for CloudWatch agent disk metrics). Common Windows paths: C:, D:"
  type        = list(string)
  default     = ["C:"]
}

# -----------------------------------------------------------------------------
# Tagging
# -----------------------------------------------------------------------------

variable "tags" {
  description = "A map of tags to add to all resources created by this module"
  type        = map(string)
  default     = {}
}
