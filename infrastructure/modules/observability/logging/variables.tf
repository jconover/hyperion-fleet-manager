#------------------------------------------------------------------------------
# CloudWatch Logging Module Variables
#------------------------------------------------------------------------------
# This file defines all input variables for the CloudWatch logging module.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Required Variables
#------------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (e.g., dev, staging, production). Used for resource naming and tagging."
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|production|prod|uat|qa)$", var.environment))
    error_message = "Environment must be one of: dev, staging, production, prod, uat, qa."
  }
}

variable "project_name" {
  description = "Name of the project. Used for resource naming and tagging."
  type        = string
  default     = "hyperion-fleet"

  validation {
    condition     = length(var.project_name) >= 3 && length(var.project_name) <= 32
    error_message = "Project name must be between 3 and 32 characters."
  }

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "Project name must start with a letter, end with a letter or number, and contain only lowercase letters, numbers, and hyphens."
  }
}

#------------------------------------------------------------------------------
# Retention Configuration
#------------------------------------------------------------------------------

variable "retention_days" {
  description = <<-EOT
    Log retention periods in days for each log type. CloudWatch Logs supports specific retention values.
    Map keys: application, system, security, powershell, ssm, dsc
    Valid values: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
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

  validation {
    condition = alltrue([
      for k, v in var.retention_days : contains([
        0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180,
        365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922,
        3288, 3653
      ], v)
    ])
    error_message = "All retention values must be valid CloudWatch Logs retention periods."
  }
}

#------------------------------------------------------------------------------
# Encryption Configuration
#------------------------------------------------------------------------------

variable "kms_key_arn" {
  description = <<-EOT
    ARN of the KMS key for encrypting CloudWatch Log Groups. If null, logs will not be encrypted.
    Note: Security and PowerShell logs are always encrypted when a KMS key is provided.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$", var.kms_key_arn))
    error_message = "KMS key ARN must be a valid ARN format or null."
  }
}

variable "encrypt_application_logs" {
  description = "Enable KMS encryption for application logs. Requires kms_key_arn to be set."
  type        = bool
  default     = false
}

variable "encrypt_system_logs" {
  description = "Enable KMS encryption for system logs. Requires kms_key_arn to be set."
  type        = bool
  default     = false
}

variable "encrypt_ssm_logs" {
  description = "Enable KMS encryption for SSM logs. Requires kms_key_arn to be set."
  type        = bool
  default     = true
}

variable "encrypt_dsc_logs" {
  description = "Enable KMS encryption for DSC logs. Requires kms_key_arn to be set."
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# Log Group Configuration
#------------------------------------------------------------------------------

variable "log_group_class" {
  description = <<-EOT
    The log class for CloudWatch Log Groups.
    STANDARD - Default class with full feature support.
    INFREQUENT_ACCESS - Lower cost for logs that are infrequently accessed.
  EOT
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "INFREQUENT_ACCESS"], var.log_group_class)
    error_message = "Log group class must be STANDARD or INFREQUENT_ACCESS."
  }
}

variable "skip_destroy_on_deletion" {
  description = <<-EOT
    If true, prevents CloudWatch Log Groups from being deleted when the resource is destroyed.
    Useful for retaining logs for compliance even after infrastructure is torn down.
  EOT
  type        = bool
  default     = false
}

variable "enable_cross_service_logging" {
  description = "Enable resource policy to allow AWS services (SSM, EC2) to write to log groups."
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Data Protection Configuration
#------------------------------------------------------------------------------

variable "enable_data_protection" {
  description = "Enable CloudWatch Logs data protection policy for sensitive data masking."
  type        = bool
  default     = false
}

variable "data_identifiers_to_audit" {
  description = <<-EOT
    List of data identifiers to audit in logs. These are logged but not masked.
    Common identifiers: arn:aws:dataprotection::aws:data-identifier/CreditCardNumber,
    arn:aws:dataprotection::aws:data-identifier/SsnUs, etc.
  EOT
  type        = list(string)
  default = [
    "arn:aws:dataprotection::aws:data-identifier/CreditCardNumber",
    "arn:aws:dataprotection::aws:data-identifier/EmailAddress"
  ]
}

variable "data_identifiers_to_redact" {
  description = <<-EOT
    List of data identifiers to redact (mask) in logs.
    These values will be replaced with [REDACTED] in log output.
  EOT
  type        = list(string)
  default = [
    "arn:aws:dataprotection::aws:data-identifier/SsnUs",
    "arn:aws:dataprotection::aws:data-identifier/DriversLicense-US"
  ]
}

#------------------------------------------------------------------------------
# Metric Filter Configuration
#------------------------------------------------------------------------------

variable "cloudwatch_namespace" {
  description = "CloudWatch namespace for custom metrics from log metric filters."
  type        = string
  default     = "HyperionFleet"

  validation {
    condition     = length(var.cloudwatch_namespace) >= 1 && length(var.cloudwatch_namespace) <= 255
    error_message = "CloudWatch namespace must be between 1 and 255 characters."
  }
}

variable "custom_error_pattern" {
  description = <<-EOT
    Custom CloudWatch Logs filter pattern for error detection.
    If empty, uses the default pattern that matches common error formats.
  EOT
  type        = string
  default     = ""
}

variable "custom_metric_filters" {
  description = <<-EOT
    Map of custom metric filters to create. Each filter extracts metrics from log events.
    Key is the filter name suffix, value contains filter configuration.
  EOT
  type = map(object({
    log_group             = string      # Which log group: application, system, security, powershell, ssm, dsc
    pattern               = string      # CloudWatch Logs filter pattern
    metric_name           = string      # Name of the metric to create
    metric_value          = string      # Value to record (usually "1" for counts)
    metric_unit           = string      # Unit: Count, Bytes, Seconds, etc.
    additional_dimensions = map(string) # Additional metric dimensions
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.custom_metric_filters :
      contains(["application", "system", "security", "powershell", "ssm", "dsc"], v.log_group)
    ])
    error_message = "Log group must be one of: application, system, security, powershell, ssm, dsc."
  }
}

#------------------------------------------------------------------------------
# S3 Archival Configuration
#------------------------------------------------------------------------------

variable "enable_s3_archival" {
  description = <<-EOT
    Enable log archival to S3 via Kinesis Firehose.
    Requires archive_bucket_name to be set.
  EOT
  type        = bool
  default     = false
}

variable "archive_bucket_name" {
  description = <<-EOT
    Name of the S3 bucket for log archival.
    The bucket must exist and have appropriate permissions.
    Required if enable_s3_archival is true.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.archive_bucket_name == "" || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.archive_bucket_name))
    error_message = "S3 bucket name must be valid (3-63 characters, lowercase letters, numbers, hyphens, and periods)."
  }
}

variable "archive_kms_key_arn" {
  description = <<-EOT
    ARN of the KMS key for encrypting archived logs in S3.
    If null, uses S3 default encryption.
  EOT
  type        = string
  default     = null
}

variable "archival_filter_pattern" {
  description = <<-EOT
    CloudWatch Logs filter pattern for S3 archival subscription.
    Empty string means all logs are archived.
  EOT
  type        = string
  default     = ""
}

variable "firehose_buffer_size" {
  description = <<-EOT
    Buffer size in MB for Kinesis Firehose before flushing to S3.
    Range: 1-128 MB.
  EOT
  type        = number
  default     = 5

  validation {
    condition     = var.firehose_buffer_size >= 1 && var.firehose_buffer_size <= 128
    error_message = "Firehose buffer size must be between 1 and 128 MB."
  }
}

variable "firehose_buffer_interval" {
  description = <<-EOT
    Buffer interval in seconds for Kinesis Firehose before flushing to S3.
    Range: 60-900 seconds.
  EOT
  type        = number
  default     = 300

  validation {
    condition     = var.firehose_buffer_interval >= 60 && var.firehose_buffer_interval <= 900
    error_message = "Firehose buffer interval must be between 60 and 900 seconds."
  }
}

#------------------------------------------------------------------------------
# Lambda Processing Configuration
#------------------------------------------------------------------------------

variable "enable_lambda_processing" {
  description = <<-EOT
    Enable real-time log processing via Lambda function.
    Requires lambda_processor_arn to be set.
  EOT
  type        = bool
  default     = false
}

variable "lambda_processor_arn" {
  description = <<-EOT
    ARN of the Lambda function for real-time log processing.
    Required if enable_lambda_processing is true.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.lambda_processor_arn == null || can(regex("^arn:aws:lambda:[a-z0-9-]+:[0-9]{12}:function:[a-zA-Z0-9-_]+$", var.lambda_processor_arn))
    error_message = "Lambda ARN must be a valid ARN format or null."
  }
}

variable "lambda_filter_pattern" {
  description = <<-EOT
    CloudWatch Logs filter pattern for Lambda subscription.
    Default matches security-relevant events.
  EOT
  type        = string
  default     = "?ERROR ?CRITICAL ?4625 ?4740 ?Failure ?Denied"
}

variable "enable_application_error_lambda" {
  description = "Enable Lambda subscription for application error logs."
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# Cross-Account Sharing Configuration
#------------------------------------------------------------------------------

variable "enable_cross_account_sharing" {
  description = <<-EOT
    Enable cross-account log sharing.
    Requires cross_account_destination_arn and cross_account_principal_arns to be set.
  EOT
  type        = bool
  default     = false
}

variable "cross_account_destination_arn" {
  description = <<-EOT
    ARN of the destination (Kinesis stream) in the central logging account.
    Required if enable_cross_account_sharing is true.
  EOT
  type        = string
  default     = null
}

variable "cross_account_principal_arns" {
  description = <<-EOT
    List of AWS account ARNs allowed to send logs to the cross-account destination.
    Format: arn:aws:iam::ACCOUNT_ID:root
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.cross_account_principal_arns :
      can(regex("^arn:aws:iam::[0-9]{12}:root$", arn))
    ])
    error_message = "Cross-account principal ARNs must be valid AWS account root ARNs."
  }
}

variable "cross_account_share_security_logs" {
  description = "Enable cross-account sharing specifically for security logs."
  type        = bool
  default     = true
}

variable "cross_account_filter_pattern" {
  description = <<-EOT
    CloudWatch Logs filter pattern for cross-account subscription.
    Empty string means all matching logs are shared.
  EOT
  type        = string
  default     = ""
}

#------------------------------------------------------------------------------
# Tagging
#------------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}

  validation {
    condition     = length(var.tags) <= 50
    error_message = "Maximum of 50 tags allowed per resource."
  }
}
