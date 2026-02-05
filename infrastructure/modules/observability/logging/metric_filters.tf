#------------------------------------------------------------------------------
# CloudWatch Log Metric Filters
#------------------------------------------------------------------------------
# Metric filters extract data from log events and transform them into
# CloudWatch metrics for monitoring and alerting.
#------------------------------------------------------------------------------

locals {
  # Namespace for all custom metrics from this module
  metric_namespace = "${var.cloudwatch_namespace}/${var.environment}/Logs"
}

#------------------------------------------------------------------------------
# Error Count Filters
#------------------------------------------------------------------------------

# Application Error Count - Captures ERROR and CRITICAL level log entries
resource "aws_cloudwatch_log_metric_filter" "application_error_count" {
  name           = "${var.project_name}-${var.environment}-application-error-count"
  log_group_name = aws_cloudwatch_log_group.application.name

  # Pattern matches common error formats:
  # - JSON: "level":"ERROR" or "level":"CRITICAL"
  # - Plaintext: [ERROR], [CRITICAL], ERROR:, CRITICAL:
  pattern = var.custom_error_pattern != "" ? var.custom_error_pattern : "?ERROR ?CRITICAL ?\"level\":\"ERROR\" ?\"level\":\"CRITICAL\" ?[ERROR] ?[CRITICAL]"

  metric_transformation {
    name          = "ApplicationErrorCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "application"
    }
  }
}

# System Error Count - Captures system-level errors
resource "aws_cloudwatch_log_metric_filter" "system_error_count" {
  name           = "${var.project_name}-${var.environment}-system-error-count"
  log_group_name = aws_cloudwatch_log_group.system.name

  # Pattern for Windows Event Log error levels (Error = 2, Critical = 1)
  pattern = "?\"EventType\":\"Error\" ?\"EventType\":\"Critical\" ?\"Level\":\"Error\" ?\"Level\":\"Critical\" ?Error ?Critical"

  metric_transformation {
    name          = "SystemErrorCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "system"
    }
  }
}

#------------------------------------------------------------------------------
# Warning Count Filters
#------------------------------------------------------------------------------

# Application Warning Count
resource "aws_cloudwatch_log_metric_filter" "application_warning_count" {
  name           = "${var.project_name}-${var.environment}-application-warning-count"
  log_group_name = aws_cloudwatch_log_group.application.name

  # Pattern matches WARNING level entries
  pattern = "?WARNING ?WARN ?\"level\":\"WARNING\" ?\"level\":\"WARN\" ?[WARNING] ?[WARN]"

  metric_transformation {
    name          = "ApplicationWarningCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "application"
    }
  }
}

# System Warning Count
resource "aws_cloudwatch_log_metric_filter" "system_warning_count" {
  name           = "${var.project_name}-${var.environment}-system-warning-count"
  log_group_name = aws_cloudwatch_log_group.system.name

  # Pattern for Windows Event Log warning level
  pattern = "?\"EventType\":\"Warning\" ?\"Level\":\"Warning\" ?Warning"

  metric_transformation {
    name          = "SystemWarningCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "system"
    }
  }
}

#------------------------------------------------------------------------------
# Authentication Failure Filters
#------------------------------------------------------------------------------

# Failed Authentication Attempts - Captures login failures from security logs
resource "aws_cloudwatch_log_metric_filter" "authentication_failure" {
  name           = "${var.project_name}-${var.environment}-authentication-failure"
  log_group_name = aws_cloudwatch_log_group.security.name

  # Pattern matches Windows Security Event IDs for authentication failures:
  # 4625 - Failed logon
  # 4771 - Kerberos pre-authentication failed
  # 4776 - NTLM authentication failed
  # 529-537, 539 - Legacy logon failure events
  pattern = "?\"EventId\":4625 ?\"EventId\":4771 ?\"EventId\":4776 ?\"EventID\":\"4625\" ?\"EventID\":\"4771\" ?\"EventID\":\"4776\" ?\"Audit Failure\""

  metric_transformation {
    name          = "AuthenticationFailureCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "security"
    }
  }
}

# Account Lockout Events
resource "aws_cloudwatch_log_metric_filter" "account_lockout" {
  name           = "${var.project_name}-${var.environment}-account-lockout"
  log_group_name = aws_cloudwatch_log_group.security.name

  # Event ID 4740 - User account was locked out
  pattern = "?\"EventId\":4740 ?\"EventID\":\"4740\" ?\"Account Locked Out\""

  metric_transformation {
    name          = "AccountLockoutCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "security"
    }
  }
}

# Privilege Escalation Attempts
resource "aws_cloudwatch_log_metric_filter" "privilege_escalation" {
  name           = "${var.project_name}-${var.environment}-privilege-escalation"
  log_group_name = aws_cloudwatch_log_group.security.name

  # Event IDs for privilege use:
  # 4672 - Special privileges assigned to new logon
  # 4673 - A privileged service was called
  # 4674 - An operation was attempted on a privileged object
  pattern = "?\"EventId\":4672 ?\"EventId\":4673 ?\"EventId\":4674 ?\"Special Logon\""

  metric_transformation {
    name          = "PrivilegeEscalationCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "security"
    }
  }
}

#------------------------------------------------------------------------------
# Exception and Stack Trace Filters
#------------------------------------------------------------------------------

# Exception Count - Captures .NET and general exceptions
resource "aws_cloudwatch_log_metric_filter" "exception_count" {
  name           = "${var.project_name}-${var.environment}-exception-count"
  log_group_name = aws_cloudwatch_log_group.application.name

  # Pattern matches common exception formats
  pattern = "?Exception ?exception ?\"Exception\" ?StackTrace ?stackTrace ?\"at \" ?Traceback"

  metric_transformation {
    name          = "ExceptionCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "application"
    }
  }
}

# Unhandled Exception Count - More severe exceptions
resource "aws_cloudwatch_log_metric_filter" "unhandled_exception_count" {
  name           = "${var.project_name}-${var.environment}-unhandled-exception-count"
  log_group_name = aws_cloudwatch_log_group.application.name

  # Pattern for unhandled/fatal exceptions
  pattern = "?\"UnhandledException\" ?\"Unhandled Exception\" ?\"FATAL\" ?\"Fatal\" ?\"fatal\""

  metric_transformation {
    name          = "UnhandledExceptionCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "application"
    }
  }
}

#------------------------------------------------------------------------------
# Custom Application Error Patterns
#------------------------------------------------------------------------------

# Custom Error Pattern - User-defined error patterns
resource "aws_cloudwatch_log_metric_filter" "custom_error_pattern" {
  for_each = var.custom_metric_filters

  name           = "${var.project_name}-${var.environment}-${each.key}"
  log_group_name = each.value.log_group == "application" ? aws_cloudwatch_log_group.application.name : (each.value.log_group == "system" ? aws_cloudwatch_log_group.system.name : (each.value.log_group == "security" ? aws_cloudwatch_log_group.security.name : (each.value.log_group == "powershell" ? aws_cloudwatch_log_group.powershell.name : (each.value.log_group == "ssm" ? aws_cloudwatch_log_group.ssm.name : aws_cloudwatch_log_group.dsc.name))))

  pattern = each.value.pattern

  metric_transformation {
    name          = each.value.metric_name
    namespace     = local.metric_namespace
    value         = each.value.metric_value
    unit          = each.value.metric_unit
    default_value = "0"

    dimensions = merge(
      {
        Environment = var.environment
        LogType     = each.value.log_group
      },
      each.value.additional_dimensions
    )
  }
}

#------------------------------------------------------------------------------
# SSM and DSC Specific Filters
#------------------------------------------------------------------------------

# SSM Command Failure
resource "aws_cloudwatch_log_metric_filter" "ssm_command_failure" {
  name           = "${var.project_name}-${var.environment}-ssm-command-failure"
  log_group_name = aws_cloudwatch_log_group.ssm.name

  # Pattern for failed SSM command executions
  pattern = "?\"Status\":\"Failed\" ?\"status\":\"failed\" ?\"Failed\" ?\"TimedOut\" ?\"Cancelled\""

  metric_transformation {
    name          = "SSMCommandFailureCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "ssm"
    }
  }
}

# DSC Configuration Drift
resource "aws_cloudwatch_log_metric_filter" "dsc_configuration_drift" {
  name           = "${var.project_name}-${var.environment}-dsc-configuration-drift"
  log_group_name = aws_cloudwatch_log_group.dsc.name

  # Pattern for DSC configuration drift detection
  pattern = "?\"Status\":\"NotCompliant\" ?\"InDesiredState\":false ?\"ResourcesNotInDesiredState\" ?Drift ?drift"

  metric_transformation {
    name          = "DSCConfigurationDriftCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "dsc"
    }
  }
}

# DSC Apply Failure
resource "aws_cloudwatch_log_metric_filter" "dsc_apply_failure" {
  name           = "${var.project_name}-${var.environment}-dsc-apply-failure"
  log_group_name = aws_cloudwatch_log_group.dsc.name

  # Pattern for DSC configuration apply failures
  pattern = "?\"Status\":\"Failed\" ?\"ApplyFailed\" ?\"ConfigurationApplyError\""

  metric_transformation {
    name          = "DSCApplyFailureCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "dsc"
    }
  }
}

#------------------------------------------------------------------------------
# PowerShell Security Filters
#------------------------------------------------------------------------------

# PowerShell Script Block Warning/Suspicious Activity
resource "aws_cloudwatch_log_metric_filter" "powershell_suspicious_activity" {
  name           = "${var.project_name}-${var.environment}-powershell-suspicious-activity"
  log_group_name = aws_cloudwatch_log_group.powershell.name

  # Pattern for potentially suspicious PowerShell activity
  # This catches common malicious patterns like encoded commands, download cradles, etc.
  pattern = "?-EncodedCommand ?-enc ?Invoke-Expression ?IEX ?downloadstring ?Net.WebClient ?Invoke-Mimikatz ?-bxor ?FromBase64String"

  metric_transformation {
    name          = "PowerShellSuspiciousActivityCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "powershell"
    }
  }
}

# PowerShell Execution Policy Bypass
resource "aws_cloudwatch_log_metric_filter" "powershell_execution_bypass" {
  name           = "${var.project_name}-${var.environment}-powershell-execution-bypass"
  log_group_name = aws_cloudwatch_log_group.powershell.name

  # Pattern for execution policy bypass attempts
  pattern = "?-ExecutionPolicy ?Bypass ?Unrestricted ?-ep"

  metric_transformation {
    name          = "PowerShellExecutionBypassCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
      LogType     = "powershell"
    }
  }
}

#------------------------------------------------------------------------------
# Aggregated Metrics
#------------------------------------------------------------------------------

# Total Error Count Across All Log Groups (using a combined filter on application)
# Note: This is a representative metric; for true aggregation, use CloudWatch Metric Math
resource "aws_cloudwatch_log_metric_filter" "total_critical_events" {
  name           = "${var.project_name}-${var.environment}-total-critical-events"
  log_group_name = aws_cloudwatch_log_group.application.name

  # Pattern for any critical event
  pattern = "?CRITICAL ?\"level\":\"CRITICAL\" ?[CRITICAL] ?\"Fatal\""

  metric_transformation {
    name          = "TotalCriticalEventCount"
    namespace     = local.metric_namespace
    value         = "1"
    unit          = "Count"
    default_value = "0"

    dimensions = {
      Environment = var.environment
    }
  }
}
