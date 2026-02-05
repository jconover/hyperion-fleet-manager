#------------------------------------------------------------------------------
# CloudWatch Log Groups for Hyperion Fleet Manager
#------------------------------------------------------------------------------
# This module creates and manages CloudWatch Log Groups for Windows server fleet
# logging, including application logs, system logs, security events, PowerShell
# transcripts, SSM Run Command logs, and DSC configuration logs.
#
# Features:
# - Configurable retention periods per log type
# - Optional KMS encryption for sensitive logs
# - Metric filters for error detection
# - Saved Logs Insights queries
# - Optional archival to S3 via Kinesis Firehose
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Local Values
#------------------------------------------------------------------------------
locals {
  # Base log group path
  log_group_base = "/hyperion/fleet"

  # Log group definitions with their configurations
  log_groups = {
    application = {
      name           = "${local.log_group_base}/application"
      description    = "Application logs from Windows fleet instances"
      retention_days = var.retention_days.application
      encrypt        = var.encrypt_application_logs
      log_type       = "application"
    }
    system = {
      name           = "${local.log_group_base}/system"
      description    = "Windows system logs from fleet instances"
      retention_days = var.retention_days.system
      encrypt        = var.encrypt_system_logs
      log_type       = "system"
    }
    security = {
      name           = "${local.log_group_base}/security"
      description    = "Security event logs from Windows fleet instances"
      retention_days = var.retention_days.security
      encrypt        = true # Always encrypt security logs
      log_type       = "security"
    }
    powershell = {
      name           = "${local.log_group_base}/powershell"
      description    = "PowerShell transcript logs from fleet instances"
      retention_days = var.retention_days.powershell
      encrypt        = true # Always encrypt PowerShell transcripts
      log_type       = "powershell"
    }
    ssm = {
      name           = "${local.log_group_base}/ssm"
      description    = "SSM Run Command execution logs"
      retention_days = var.retention_days.ssm
      encrypt        = var.encrypt_ssm_logs
      log_type       = "ssm"
    }
    dsc = {
      name           = "${local.log_group_base}/dsc"
      description    = "DSC (Desired State Configuration) logs"
      retention_days = var.retention_days.dsc
      encrypt        = var.encrypt_dsc_logs
      log_type       = "dsc"
    }
  }

  # Common tags for all resources
  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "observability/logging"
    }
  )
}

#------------------------------------------------------------------------------
# CloudWatch Log Groups
#------------------------------------------------------------------------------

# Application Logs - General application events, errors, and diagnostics
resource "aws_cloudwatch_log_group" "application" {
  name              = local.log_groups.application.name
  retention_in_days = local.log_groups.application.retention_days
  kms_key_id        = local.log_groups.application.encrypt ? var.kms_key_arn : null
  skip_destroy      = var.skip_destroy_on_deletion
  log_group_class   = var.log_group_class

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-application-logs"
      LogType     = local.log_groups.application.log_type
      Description = local.log_groups.application.description
    }
  )
}

# System Logs - Windows Event Logs (System channel)
resource "aws_cloudwatch_log_group" "system" {
  name              = local.log_groups.system.name
  retention_in_days = local.log_groups.system.retention_days
  kms_key_id        = local.log_groups.system.encrypt ? var.kms_key_arn : null
  skip_destroy      = var.skip_destroy_on_deletion
  log_group_class   = var.log_group_class

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-system-logs"
      LogType     = local.log_groups.system.log_type
      Description = local.log_groups.system.description
    }
  )
}

# Security Logs - Windows Security Event Logs (authentication, authorization)
resource "aws_cloudwatch_log_group" "security" {
  name              = local.log_groups.security.name
  retention_in_days = local.log_groups.security.retention_days
  kms_key_id        = var.kms_key_arn # Always use KMS for security logs
  skip_destroy      = var.skip_destroy_on_deletion
  log_group_class   = var.log_group_class

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-security-logs"
      LogType     = local.log_groups.security.log_type
      Description = local.log_groups.security.description
      Compliance  = "security-audit"
    }
  )
}

# PowerShell Logs - PowerShell transcript and script block logging
resource "aws_cloudwatch_log_group" "powershell" {
  name              = local.log_groups.powershell.name
  retention_in_days = local.log_groups.powershell.retention_days
  kms_key_id        = var.kms_key_arn # Always use KMS for PowerShell transcripts
  skip_destroy      = var.skip_destroy_on_deletion
  log_group_class   = var.log_group_class

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-powershell-logs"
      LogType     = local.log_groups.powershell.log_type
      Description = local.log_groups.powershell.description
      Compliance  = "script-audit"
    }
  )
}

# SSM Logs - Systems Manager Run Command execution logs
resource "aws_cloudwatch_log_group" "ssm" {
  name              = local.log_groups.ssm.name
  retention_in_days = local.log_groups.ssm.retention_days
  kms_key_id        = local.log_groups.ssm.encrypt ? var.kms_key_arn : null
  skip_destroy      = var.skip_destroy_on_deletion
  log_group_class   = var.log_group_class

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-ssm-logs"
      LogType     = local.log_groups.ssm.log_type
      Description = local.log_groups.ssm.description
    }
  )
}

# DSC Logs - Desired State Configuration compliance and status logs
resource "aws_cloudwatch_log_group" "dsc" {
  name              = local.log_groups.dsc.name
  retention_in_days = local.log_groups.dsc.retention_days
  kms_key_id        = local.log_groups.dsc.encrypt ? var.kms_key_arn : null
  skip_destroy      = var.skip_destroy_on_deletion
  log_group_class   = var.log_group_class

  tags = merge(
    local.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-dsc-logs"
      LogType     = local.log_groups.dsc.log_type
      Description = local.log_groups.dsc.description
      Compliance  = "configuration-management"
    }
  )
}

#------------------------------------------------------------------------------
# Log Group Resource Policy (for cross-service logging)
#------------------------------------------------------------------------------
resource "aws_cloudwatch_log_resource_policy" "allow_aws_services" {
  count = var.enable_cross_service_logging ? 1 : 0

  policy_name = "${var.project_name}-${var.environment}-log-resource-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSSMLogging"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.ssm.arn}:*"
        ]
      },
      {
        Sid    = "AllowEC2Logging"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.application.arn}:*",
          "${aws_cloudwatch_log_group.system.arn}:*",
          "${aws_cloudwatch_log_group.security.arn}:*"
        ]
      }
    ]
  })
}

#------------------------------------------------------------------------------
# Data Retention Policy (for compliance)
#------------------------------------------------------------------------------
resource "aws_cloudwatch_log_data_protection_policy" "security_logs" {
  count = var.enable_data_protection ? 1 : 0

  log_group_name = aws_cloudwatch_log_group.security.name

  policy_document = jsonencode({
    Name    = "SecurityLogDataProtection"
    Version = "2021-06-01"

    Statement = [
      {
        Sid            = "Audit"
        DataIdentifier = var.data_identifiers_to_audit
        Operation = {
          Audit = {
            FindingsDestination = {
              CloudWatchLogs = {
                LogGroup = aws_cloudwatch_log_group.application.name
              }
            }
          }
        }
      },
      {
        Sid            = "Redact"
        DataIdentifier = var.data_identifiers_to_redact
        Operation = {
          Deidentify = {
            MaskConfig = {}
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_data_protection_policy" "powershell_logs" {
  count = var.enable_data_protection ? 1 : 0

  log_group_name = aws_cloudwatch_log_group.powershell.name

  policy_document = jsonencode({
    Name    = "PowerShellLogDataProtection"
    Version = "2021-06-01"

    Statement = [
      {
        Sid            = "Audit"
        DataIdentifier = var.data_identifiers_to_audit
        Operation = {
          Audit = {
            FindingsDestination = {
              CloudWatchLogs = {
                LogGroup = aws_cloudwatch_log_group.application.name
              }
            }
          }
        }
      },
      {
        Sid            = "Redact"
        DataIdentifier = var.data_identifiers_to_redact
        Operation = {
          Deidentify = {
            MaskConfig = {}
          }
        }
      }
    ]
  })
}
