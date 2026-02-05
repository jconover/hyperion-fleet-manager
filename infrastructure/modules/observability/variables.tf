# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - Observability Module Variables
# -----------------------------------------------------------------------------
# This file defines all input variables for the observability root module.
# Variables are organized by category for maintainability.
# -----------------------------------------------------------------------------

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "environment" {
  description = "Environment name (e.g., dev, staging, production). Used for resource naming and tagging."
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|production|prod|uat|qa)$", var.environment))
    error_message = "Environment must be one of: dev, staging, production, prod, uat, qa."
  }
}

variable "project_name" {
  description = "Project name used for resource naming, tagging, and CloudWatch namespace."
  type        = string
  default     = "hyperion"

  validation {
    condition     = length(var.project_name) >= 3 && length(var.project_name) <= 32
    error_message = "Project name must be between 3 and 32 characters."
  }

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "Project name must start with a letter, end with a letter or number, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "aws_region" {
  description = "AWS region for resources. If empty, uses the current provider region."
  type        = string
  default     = ""

  validation {
    condition     = var.aws_region == "" || can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be a valid region format (e.g., us-east-1, eu-west-2) or empty."
  }
}

# =============================================================================
# COMMON TAGS
# =============================================================================

variable "tags" {
  description = "Common tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}

  validation {
    condition     = length(var.tags) <= 50
    error_message = "Maximum of 50 tags allowed per resource."
  }
}

# =============================================================================
# FEATURE FLAGS
# =============================================================================

variable "enable_dashboards" {
  description = "Enable CloudWatch dashboards (fleet health, security, cost)."
  type        = bool
  default     = true
}

variable "enable_alarms" {
  description = "Enable CloudWatch metric alarms for all monitored resources."
  type        = bool
  default     = true
}

variable "enable_alerting" {
  description = "Enable SNS alerting infrastructure (topics, subscriptions, Lambda processor)."
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable centralized CloudWatch logging infrastructure."
  type        = bool
  default     = true
}

# =============================================================================
# VPC CONFIGURATION
# =============================================================================

variable "vpc_id" {
  description = "VPC ID for observability resources that require VPC placement."
  type        = string
  default     = ""
}

# =============================================================================
# INSTANCE CONFIGURATION
# =============================================================================

variable "instance_ids" {
  description = "List of EC2 instance IDs to monitor. If empty, uses aggregate metrics from ASGs."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.instance_ids : can(regex("^i-[a-f0-9]{8,17}$", id))])
    error_message = "All instance IDs must be valid EC2 instance ID format (i-xxxxxxxxxxxxxxxxx)."
  }
}

variable "ami_id" {
  description = "AMI ID used for CloudWatch Agent metric dimensions."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Instance type used for CloudWatch Agent metric dimensions."
  type        = string
  default     = ""
}

variable "ebs_volume_ids" {
  description = "List of EBS volume IDs to monitor for burst balance and disk metrics."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.ebs_volume_ids : can(regex("^vol-[a-f0-9]{8,17}$", id))])
    error_message = "All volume IDs must be valid EBS volume ID format (vol-xxxxxxxxxxxxxxxxx)."
  }
}

# =============================================================================
# AUTO SCALING GROUP CONFIGURATION
# =============================================================================

variable "auto_scaling_group_names" {
  description = "List of Auto Scaling Group names to monitor."
  type        = list(string)
  default     = []
}

variable "asg_minimum_capacity" {
  description = "Map of ASG names to their minimum required capacity for alarms."
  type        = map(number)
  default     = {}
}

# =============================================================================
# NOTIFICATION CONFIGURATION - EMAILS
# =============================================================================

variable "notification_emails" {
  description = <<-EOF
    Map of email addresses by severity level for SNS subscriptions.
    Keys: critical, warning, info, security, cost
    Example: {
      critical = ["oncall@example.com"]
      warning  = ["ops@example.com"]
    }
  EOF
  type        = map(list(string))
  default     = {}

  validation {
    condition = alltrue([
      for severity, emails in var.notification_emails : contains(["critical", "warning", "info", "security", "cost"], severity)
    ])
    error_message = "Email endpoint keys must be one of: critical, warning, info, security, cost."
  }
}

variable "notification_emails_critical" {
  description = "List of email addresses for critical alert notifications."
  type        = list(string)
  default     = []
}

variable "notification_emails_warning" {
  description = "List of email addresses for warning alert notifications."
  type        = list(string)
  default     = []
}

variable "notification_emails_info" {
  description = "List of email addresses for info alert notifications."
  type        = list(string)
  default     = []
}

# =============================================================================
# NOTIFICATION CONFIGURATION - SMS
# =============================================================================

variable "notification_sms" {
  description = "List of phone numbers for SMS subscriptions (E.164 format)."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for phone in var.notification_sms : can(regex("^\\+[1-9]\\d{1,14}$", phone))
    ])
    error_message = "Phone numbers must be in E.164 format (e.g., +14155552671)."
  }
}

variable "notification_phone_numbers" {
  description = "List of phone numbers for critical SMS notifications (E.164 format)."
  type        = list(string)
  default     = []
}

variable "enable_security_sms" {
  description = "Enable SMS notifications for high-severity security alerts."
  type        = bool
  default     = false
}

# =============================================================================
# NOTIFICATION CONFIGURATION - WEBHOOKS
# =============================================================================

variable "webhook_endpoints" {
  description = <<-EOF
    Map of webhook URLs by severity level.
    Keys: critical, warning, info, security, cost
    Values: Map of endpoint_name => URL
  EOF
  type        = map(map(string))
  default     = {}
}

variable "webhook_endpoints_critical" {
  description = "List of HTTPS webhook endpoints for critical alerts."
  type        = list(string)
  default     = []
}

variable "webhook_endpoints_warning" {
  description = "List of HTTPS webhook endpoints for warning alerts."
  type        = list(string)
  default     = []
}

variable "webhook_auto_confirm" {
  description = "Whether HTTPS endpoints should auto-confirm subscription."
  type        = bool
  default     = false
}

variable "webhook_raw_message_delivery" {
  description = "Whether to deliver raw message to HTTPS endpoints."
  type        = bool
  default     = false
}

# =============================================================================
# NOTIFICATION CONFIGURATION - INTEGRATIONS
# =============================================================================

variable "slack_webhook_url" {
  description = "Slack webhook URL for alert notifications."
  type        = string
  default     = null
  sensitive   = true
}

variable "pagerduty_integration_key" {
  description = "PagerDuty Events API v2 routing key for alert escalation."
  type        = string
  default     = null
  sensitive   = true
}

# =============================================================================
# ALARM THRESHOLDS
# =============================================================================

variable "alarm_thresholds" {
  description = "Map of alarm thresholds to override defaults."
  type        = map(number)
  default     = {}
}

variable "dashboard_alarm_thresholds" {
  description = <<-EOT
    Map of alarm threshold values for dashboard annotations.
    Keys: cpu_percent, memory_percent, disk_percent, network_in_bytes, network_out_bytes, status_check_failed
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
}

variable "evaluation_periods" {
  description = "Map of metric types to their evaluation periods."
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
  description = "Map of metric types to their period in seconds."
  type        = map(number)
  default = {
    cpu     = 60
    memory  = 60
    disk    = 300
    network = 300
    ebs     = 300
  }
}

# =============================================================================
# ALARM FEATURE TOGGLES
# =============================================================================

variable "enable_memory_alarms" {
  description = "Enable memory utilization alarms (requires CloudWatch Agent)."
  type        = bool
  default     = true
}

variable "enable_disk_alarms" {
  description = "Enable disk space alarms (requires CloudWatch Agent)."
  type        = bool
  default     = true
}

variable "enable_network_alarms" {
  description = "Enable network utilization alarms."
  type        = bool
  default     = true
}

variable "enable_ebs_alarms" {
  description = "Enable EBS burst balance alarms."
  type        = bool
  default     = true
}

variable "enable_ssm_alarms" {
  description = "Enable SSM Agent connectivity alarms."
  type        = bool
  default     = true
}

variable "enable_composite_alarms" {
  description = "Enable composite alarms for aggregated alerting."
  type        = bool
  default     = true
}

# =============================================================================
# LAMBDA NOTIFICATION CONFIGURATION
# =============================================================================

variable "lambda_function_arn_critical" {
  description = "ARN of Lambda function to invoke for critical alerts."
  type        = string
  default     = ""
}

variable "lambda_function_arn_warning" {
  description = "ARN of Lambda function to invoke for warning alerts."
  type        = string
  default     = ""
}

variable "lambda_function_arn_info" {
  description = "ARN of Lambda function to invoke for info alerts."
  type        = string
  default     = ""
}

# =============================================================================
# APPLICATION HEALTH CHECK CONFIGURATION
# =============================================================================

variable "health_check_configs" {
  description = "Map of application health check configurations."
  type = map(object({
    metric_name        = string
    namespace          = string
    period             = number
    evaluation_periods = number
    description        = string
    dimensions         = map(string)
  }))
  default = {}
}

variable "target_group_arns" {
  description = "Map of target group configurations for health monitoring."
  type = map(object({
    arn_suffix               = string
    load_balancer_arn_suffix = string
    minimum_healthy_hosts    = number
  }))
  default = {}
}

# =============================================================================
# KMS CONFIGURATION
# =============================================================================

variable "kms_key_arn" {
  description = "ARN of existing KMS key for encryption. If not provided, a new key may be created."
  type        = string
  default     = null
}

variable "kms_key_deletion_window" {
  description = "Duration in days after which the KMS key is deleted after destruction (7-30 days)."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

# =============================================================================
# LOGGING CONFIGURATION - RETENTION
# =============================================================================

variable "log_retention_days" {
  description = <<-EOT
    Log retention periods in days for each log type.
    Map keys: application, system, security, powershell, ssm, dsc
  EOT
  type = object({
    application = number
    system      = number
    security    = number
    powershell  = number
    ssm         = number
    dsc         = number
  })
  default = {
    application = 30
    system      = 60
    security    = 90
    powershell  = 90
    ssm         = 30
    dsc         = 30
  }
}

# =============================================================================
# LOGGING CONFIGURATION - ENCRYPTION
# =============================================================================

variable "encrypt_application_logs" {
  description = "Enable KMS encryption for application logs."
  type        = bool
  default     = false
}

variable "encrypt_system_logs" {
  description = "Enable KMS encryption for system logs."
  type        = bool
  default     = false
}

variable "encrypt_ssm_logs" {
  description = "Enable KMS encryption for SSM logs."
  type        = bool
  default     = true
}

variable "encrypt_dsc_logs" {
  description = "Enable KMS encryption for DSC logs."
  type        = bool
  default     = false
}

# =============================================================================
# LOGGING CONFIGURATION - LOG GROUPS
# =============================================================================

variable "log_group_class" {
  description = "The log class for CloudWatch Log Groups (STANDARD or INFREQUENT_ACCESS)."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "INFREQUENT_ACCESS"], var.log_group_class)
    error_message = "Log group class must be STANDARD or INFREQUENT_ACCESS."
  }
}

variable "skip_destroy_on_deletion" {
  description = "If true, prevents CloudWatch Log Groups from being deleted when the resource is destroyed."
  type        = bool
  default     = false
}

variable "enable_cross_service_logging" {
  description = "Enable resource policy to allow AWS services to write to log groups."
  type        = bool
  default     = true
}

# =============================================================================
# LOGGING CONFIGURATION - DATA PROTECTION
# =============================================================================

variable "enable_data_protection" {
  description = "Enable CloudWatch Logs data protection policy for sensitive data masking."
  type        = bool
  default     = false
}

variable "data_identifiers_to_audit" {
  description = "List of data identifiers to audit in logs (logged but not masked)."
  type        = list(string)
  default = [
    "arn:aws:dataprotection::aws:data-identifier/CreditCardNumber",
    "arn:aws:dataprotection::aws:data-identifier/EmailAddress"
  ]
}

variable "data_identifiers_to_redact" {
  description = "List of data identifiers to redact (mask) in logs."
  type        = list(string)
  default = [
    "arn:aws:dataprotection::aws:data-identifier/SsnUs",
    "arn:aws:dataprotection::aws:data-identifier/DriversLicense-US"
  ]
}

# =============================================================================
# LOGGING CONFIGURATION - METRIC FILTERS
# =============================================================================

variable "cloudwatch_namespace" {
  description = "CloudWatch namespace for custom metrics from log metric filters."
  type        = string
  default     = "HyperionFleet"
}

variable "custom_error_pattern" {
  description = "Custom CloudWatch Logs filter pattern for error detection."
  type        = string
  default     = ""
}

variable "custom_metric_filters" {
  description = "Map of custom metric filters to create."
  type = map(object({
    log_group             = string
    pattern               = string
    metric_name           = string
    metric_value          = string
    metric_unit           = string
    additional_dimensions = map(string)
  }))
  default = {}
}

# =============================================================================
# LOGGING CONFIGURATION - S3 ARCHIVAL
# =============================================================================

variable "enable_s3_archival" {
  description = "Enable log archival to S3 via Kinesis Firehose."
  type        = bool
  default     = false
}

variable "archive_bucket_name" {
  description = "Name of the S3 bucket for log archival."
  type        = string
  default     = ""
}

variable "archive_kms_key_arn" {
  description = "ARN of the KMS key for encrypting archived logs in S3."
  type        = string
  default     = null
}

variable "archival_filter_pattern" {
  description = "CloudWatch Logs filter pattern for S3 archival subscription."
  type        = string
  default     = ""
}

variable "firehose_buffer_size" {
  description = "Buffer size in MB for Kinesis Firehose before flushing to S3."
  type        = number
  default     = 5

  validation {
    condition     = var.firehose_buffer_size >= 1 && var.firehose_buffer_size <= 128
    error_message = "Firehose buffer size must be between 1 and 128 MB."
  }
}

variable "firehose_buffer_interval" {
  description = "Buffer interval in seconds for Kinesis Firehose before flushing to S3."
  type        = number
  default     = 300

  validation {
    condition     = var.firehose_buffer_interval >= 60 && var.firehose_buffer_interval <= 900
    error_message = "Firehose buffer interval must be between 60 and 900 seconds."
  }
}

# =============================================================================
# LOGGING CONFIGURATION - LAMBDA PROCESSING
# =============================================================================

variable "enable_log_lambda_processing" {
  description = "Enable real-time log processing via Lambda function."
  type        = bool
  default     = false
}

variable "log_lambda_processor_arn" {
  description = "ARN of the Lambda function for real-time log processing."
  type        = string
  default     = null
}

variable "log_lambda_filter_pattern" {
  description = "CloudWatch Logs filter pattern for Lambda subscription."
  type        = string
  default     = "?ERROR ?CRITICAL ?4625 ?4740 ?Failure ?Denied"
}

variable "enable_application_error_lambda" {
  description = "Enable Lambda subscription for application error logs."
  type        = bool
  default     = false
}

# =============================================================================
# LOGGING CONFIGURATION - CROSS-ACCOUNT
# =============================================================================

variable "enable_cross_account_log_sharing" {
  description = "Enable cross-account log sharing."
  type        = bool
  default     = false
}

variable "cross_account_log_destination_arn" {
  description = "ARN of the destination (Kinesis stream) in the central logging account."
  type        = string
  default     = null
}

variable "cross_account_log_principal_arns" {
  description = "List of AWS account ARNs allowed to send logs to the cross-account destination."
  type        = list(string)
  default     = []
}

variable "cross_account_share_security_logs" {
  description = "Enable cross-account sharing specifically for security logs."
  type        = bool
  default     = true
}

variable "cross_account_log_filter_pattern" {
  description = "CloudWatch Logs filter pattern for cross-account subscription."
  type        = string
  default     = ""
}

# =============================================================================
# ALERTING CONFIGURATION - LAMBDA PROCESSOR
# =============================================================================

variable "enable_lambda_processor" {
  description = "Enable Lambda function for alert enrichment and routing."
  type        = bool
  default     = true
}

variable "lambda_log_level" {
  description = "Log level for Lambda function (DEBUG, INFO, WARNING, ERROR)."
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.lambda_log_level)
    error_message = "Lambda log level must be one of: DEBUG, INFO, WARNING, ERROR."
  }
}

variable "lambda_log_retention_days" {
  description = "Number of days to retain Lambda function logs."
  type        = number
  default     = 30
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrent executions for Lambda function (-1 for no limit)."
  type        = number
  default     = 10
}

variable "lambda_vpc_config" {
  description = "VPC configuration for Lambda function."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for Lambda function."
  type        = bool
  default     = false
}

variable "enable_lambda_alarms" {
  description = "Enable CloudWatch alarms for Lambda function monitoring."
  type        = bool
  default     = true
}

variable "runbook_base_url" {
  description = "Base URL for runbook documentation links."
  type        = string
  default     = "https://runbooks.example.com"
}

variable "enable_pii_redaction" {
  description = "Enable automatic PII redaction in alert messages."
  type        = bool
  default     = true
}

# =============================================================================
# ALERTING CONFIGURATION - SQS
# =============================================================================

variable "enable_sqs_subscriptions" {
  description = "Enable SQS queue subscriptions for critical and security topics."
  type        = bool
  default     = true
}

variable "enable_aggregate_queue" {
  description = "Enable aggregate SQS queue for all alerts."
  type        = bool
  default     = false
}

# =============================================================================
# ALERTING CONFIGURATION - EVENTBRIDGE
# =============================================================================

variable "enable_security_hub_rules" {
  description = "Enable EventBridge rules for Security Hub findings."
  type        = bool
  default     = false
}

variable "enable_cost_anomaly_rules" {
  description = "Enable EventBridge rules for Cost Anomaly Detection."
  type        = bool
  default     = true
}

variable "enable_iam_monitoring" {
  description = "Enable EventBridge rules for IAM changes."
  type        = bool
  default     = false
}

# =============================================================================
# ALERTING CONFIGURATION - CROSS-ACCOUNT
# =============================================================================

variable "enable_cross_account_events" {
  description = "Enable cross-account event bus for multi-account alerting."
  type        = bool
  default     = false
}

variable "cross_account_ids" {
  description = "List of AWS account IDs allowed to send events to cross-account bus."
  type        = list(string)
  default     = []
}

# =============================================================================
# DASHBOARD CONFIGURATION
# =============================================================================

variable "dashboard_refresh_interval" {
  description = "Dashboard auto-refresh interval (auto, 10, 30, 60, 300, 900, 3600 seconds)."
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["auto", "10", "30", "60", "300", "900", "3600"], var.dashboard_refresh_interval)
    error_message = "Dashboard refresh interval must be one of: auto, 10, 30, 60, 300, 900, 3600."
  }
}

variable "ssm_namespace" {
  description = "CloudWatch namespace for SSM agent metrics."
  type        = string
  default     = "AWS/SSM"
}

variable "metric_period_standard" {
  description = "Standard metric period in seconds for most widgets."
  type        = number
  default     = 300

  validation {
    condition     = contains([60, 300, 900, 3600], var.metric_period_standard)
    error_message = "Standard metric period must be 60, 300, 900, or 3600 seconds."
  }
}

variable "metric_period_detailed" {
  description = "Detailed metric period in seconds for high-resolution widgets."
  type        = number
  default     = 60

  validation {
    condition     = contains([1, 5, 10, 30, 60], var.metric_period_detailed)
    error_message = "Detailed metric period must be 1, 5, 10, 30, or 60 seconds."
  }
}

variable "enable_ssm_status_widget" {
  description = "Enable SSM agent status widget."
  type        = bool
  default     = true
}

variable "enable_detailed_instance_metrics" {
  description = "Enable detailed per-instance metrics widgets."
  type        = bool
  default     = false
}

variable "enable_disk_by_volume" {
  description = "Enable disk utilization breakdown by volume."
  type        = bool
  default     = true
}

variable "disk_mount_paths" {
  description = "List of disk mount paths to monitor."
  type        = list(string)
  default     = ["C:"]
}

# =============================================================================
# SECURITY DASHBOARD CONFIGURATION
# =============================================================================

variable "enable_security_dashboard" {
  description = "Enable the Security Dashboard."
  type        = bool
  default     = true
}

variable "enable_security_alarms" {
  description = "Enable CloudWatch alarms for security events."
  type        = bool
  default     = true
}

variable "security_guardduty_detector_id" {
  description = "GuardDuty detector ID for monitoring threat findings."
  type        = string
  default     = ""
}

variable "security_hub_enabled" {
  description = "Whether AWS Security Hub is enabled in the account."
  type        = bool
  default     = false
}

variable "security_vpc_flow_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs."
  type        = string
  default     = ""
}

variable "security_cloudtrail_log_group_name" {
  description = "CloudWatch Log Group name for CloudTrail logs."
  type        = string
  default     = ""
}

variable "security_windows_log_group_name" {
  description = "CloudWatch Log Group name for Windows Security logs."
  type        = string
  default     = ""
}

variable "security_failed_login_threshold" {
  description = "Number of failed login attempts in 5 minutes to trigger an alarm."
  type        = number
  default     = 10
}

variable "security_rejected_packets_threshold" {
  description = "Number of rejected VPC Flow Log packets in 5 minutes to trigger an alarm."
  type        = number
  default     = 1000
}

variable "security_api_error_threshold" {
  description = "Number of CloudTrail API authorization errors in 5 minutes to trigger an alarm."
  type        = number
  default     = 5
}

variable "security_alarm_actions" {
  description = "List of ARNs to notify when security alarms trigger."
  type        = list(string)
  default     = []
}

variable "security_ok_actions" {
  description = "List of ARNs to notify when security alarms return to OK."
  type        = list(string)
  default     = []
}

variable "security_alarm_evaluation_periods" {
  description = "Number of periods to evaluate before triggering a security alarm."
  type        = number
  default     = 1
}

variable "security_enable_trend_analysis" {
  description = "Enable time-based trend analysis widgets for security events."
  type        = bool
  default     = true
}

variable "security_trend_analysis_hours" {
  description = "Number of hours to include in trend analysis queries."
  type        = number
  default     = 24
}

# =============================================================================
# COST DASHBOARD CONFIGURATION
# =============================================================================

variable "cost_budget_amount" {
  description = "Monthly budget amount in USD for cost monitoring thresholds."
  type        = number
  default     = 1000

  validation {
    condition     = var.cost_budget_amount > 0
    error_message = "Budget amount must be a positive number."
  }
}

variable "cost_alert_thresholds" {
  description = "Cost alert threshold percentages relative to budget."
  type = object({
    warning  = number
    critical = number
  })
  default = {
    warning  = 80
    critical = 100
  }
}

variable "cost_enable_budget_alarms" {
  description = "Enable CloudWatch alarms for budget threshold breaches."
  type        = bool
  default     = true
}

variable "cost_linked_accounts" {
  description = "List of linked AWS account IDs for consolidated billing cost tracking."
  type = list(object({
    account_id   = string
    account_name = string
  }))
  default = []
}

variable "cost_enable_linked_account_widgets" {
  description = "Enable cost widgets for linked accounts."
  type        = bool
  default     = false
}

variable "cost_enable_cost_anomaly_detection" {
  description = "Enable AWS Cost Anomaly Detection monitor."
  type        = bool
  default     = true
}

variable "cost_anomaly_monitor_type" {
  description = "Type of anomaly monitor (DIMENSIONAL or CUSTOM)."
  type        = string
  default     = "DIMENSIONAL"
}

variable "cost_anomaly_monitor_dimension" {
  description = "Dimension for DIMENSIONAL monitor type (SERVICE or LINKED_ACCOUNT)."
  type        = string
  default     = "SERVICE"
}

variable "cost_anomaly_threshold_expression" {
  description = "Absolute dollar amount threshold above expected spend to trigger alerts."
  type        = number
  default     = 100
}

variable "cost_anomaly_threshold_percentage" {
  description = "Percentage above expected spend to trigger alerts."
  type        = number
  default     = 10
}

variable "cost_enable_service_anomaly_monitors" {
  description = "Enable individual anomaly monitors for specific AWS services."
  type        = bool
  default     = false
}

variable "cost_services_for_anomaly_detection" {
  description = "List of AWS services for individual anomaly monitors."
  type        = list(string)
  default = [
    "AmazonEC2",
    "AmazonS3",
    "AWSDataTransfer"
  ]
}

variable "cost_sns_topic_arn" {
  description = "ARN of existing SNS topic for cost anomaly alerts."
  type        = string
  default     = null
}

variable "cost_alert_email_addresses" {
  description = "Email addresses to receive cost anomaly alerts."
  type        = list(string)
  default     = []
}

variable "cost_metric_period" {
  description = "Period in seconds for cost metric calculations."
  type        = number
  default     = 86400
}

variable "cost_services_to_track" {
  description = "List of AWS services to track in cost dashboard."
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
  description = "List of EC2 instance types to track for running hours and cost analysis."
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

variable "cost_enable_environment_comparison" {
  description = "Enable cost comparison widgets across environments."
  type        = bool
  default     = false
}

variable "cost_environments_to_compare" {
  description = "List of environment names for cost comparison widgets."
  type        = list(string)
  default     = ["dev", "staging", "production"]
}

variable "cost_environment_account_map" {
  description = "Map of environment names to AWS account IDs for multi-account cost comparison."
  type        = map(string)
  default     = {}
}
