#------------------------------------------------------------------------------
# CloudWatch Logging Module Outputs
#------------------------------------------------------------------------------
# This file defines all outputs from the CloudWatch logging module.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Log Group ARNs
#------------------------------------------------------------------------------

output "log_group_arns" {
  description = "Map of log group names to their ARNs."
  value = {
    application = aws_cloudwatch_log_group.application.arn
    system      = aws_cloudwatch_log_group.system.arn
    security    = aws_cloudwatch_log_group.security.arn
    powershell  = aws_cloudwatch_log_group.powershell.arn
    ssm         = aws_cloudwatch_log_group.ssm.arn
    dsc         = aws_cloudwatch_log_group.dsc.arn
  }
}

output "log_group_arn_application" {
  description = "ARN of the application log group."
  value       = aws_cloudwatch_log_group.application.arn
}

output "log_group_arn_system" {
  description = "ARN of the system log group."
  value       = aws_cloudwatch_log_group.system.arn
}

output "log_group_arn_security" {
  description = "ARN of the security log group."
  value       = aws_cloudwatch_log_group.security.arn
}

output "log_group_arn_powershell" {
  description = "ARN of the PowerShell log group."
  value       = aws_cloudwatch_log_group.powershell.arn
}

output "log_group_arn_ssm" {
  description = "ARN of the SSM log group."
  value       = aws_cloudwatch_log_group.ssm.arn
}

output "log_group_arn_dsc" {
  description = "ARN of the DSC log group."
  value       = aws_cloudwatch_log_group.dsc.arn
}

#------------------------------------------------------------------------------
# Log Group Names
#------------------------------------------------------------------------------

output "log_group_names" {
  description = "Map of log types to their CloudWatch Log Group names."
  value = {
    application = aws_cloudwatch_log_group.application.name
    system      = aws_cloudwatch_log_group.system.name
    security    = aws_cloudwatch_log_group.security.name
    powershell  = aws_cloudwatch_log_group.powershell.name
    ssm         = aws_cloudwatch_log_group.ssm.name
    dsc         = aws_cloudwatch_log_group.dsc.name
  }
}

output "log_group_name_application" {
  description = "Name of the application log group."
  value       = aws_cloudwatch_log_group.application.name
}

output "log_group_name_system" {
  description = "Name of the system log group."
  value       = aws_cloudwatch_log_group.system.name
}

output "log_group_name_security" {
  description = "Name of the security log group."
  value       = aws_cloudwatch_log_group.security.name
}

output "log_group_name_powershell" {
  description = "Name of the PowerShell log group."
  value       = aws_cloudwatch_log_group.powershell.name
}

output "log_group_name_ssm" {
  description = "Name of the SSM log group."
  value       = aws_cloudwatch_log_group.ssm.name
}

output "log_group_name_dsc" {
  description = "Name of the DSC log group."
  value       = aws_cloudwatch_log_group.dsc.name
}

#------------------------------------------------------------------------------
# Metric Filter Names
#------------------------------------------------------------------------------

output "metric_filter_names" {
  description = "Map of metric filter purposes to their names."
  value = {
    application_error_count     = aws_cloudwatch_log_metric_filter.application_error_count.name
    system_error_count          = aws_cloudwatch_log_metric_filter.system_error_count.name
    application_warning_count   = aws_cloudwatch_log_metric_filter.application_warning_count.name
    system_warning_count        = aws_cloudwatch_log_metric_filter.system_warning_count.name
    authentication_failure      = aws_cloudwatch_log_metric_filter.authentication_failure.name
    account_lockout             = aws_cloudwatch_log_metric_filter.account_lockout.name
    privilege_escalation        = aws_cloudwatch_log_metric_filter.privilege_escalation.name
    exception_count             = aws_cloudwatch_log_metric_filter.exception_count.name
    unhandled_exception_count   = aws_cloudwatch_log_metric_filter.unhandled_exception_count.name
    ssm_command_failure         = aws_cloudwatch_log_metric_filter.ssm_command_failure.name
    dsc_configuration_drift     = aws_cloudwatch_log_metric_filter.dsc_configuration_drift.name
    dsc_apply_failure           = aws_cloudwatch_log_metric_filter.dsc_apply_failure.name
    powershell_suspicious       = aws_cloudwatch_log_metric_filter.powershell_suspicious_activity.name
    powershell_execution_bypass = aws_cloudwatch_log_metric_filter.powershell_execution_bypass.name
    total_critical_events       = aws_cloudwatch_log_metric_filter.total_critical_events.name
  }
}

output "custom_metric_filter_names" {
  description = "Map of custom metric filter keys to their names."
  value = {
    for k, v in aws_cloudwatch_log_metric_filter.custom_error_pattern :
    k => v.name
  }
}

#------------------------------------------------------------------------------
# CloudWatch Metrics Information
#------------------------------------------------------------------------------

output "cloudwatch_namespace" {
  description = "CloudWatch namespace where log metrics are published."
  value       = "${var.cloudwatch_namespace}/${var.environment}/Logs"
}

output "metric_names" {
  description = "List of metric names created by the metric filters."
  value = [
    "ApplicationErrorCount",
    "SystemErrorCount",
    "ApplicationWarningCount",
    "SystemWarningCount",
    "AuthenticationFailureCount",
    "AccountLockoutCount",
    "PrivilegeEscalationCount",
    "ExceptionCount",
    "UnhandledExceptionCount",
    "SSMCommandFailureCount",
    "DSCConfigurationDriftCount",
    "DSCApplyFailureCount",
    "PowerShellSuspiciousActivityCount",
    "PowerShellExecutionBypassCount",
    "TotalCriticalEventCount"
  ]
}

#------------------------------------------------------------------------------
# Logs Insights Query Names
#------------------------------------------------------------------------------

output "insights_query_names" {
  description = "Map of query purposes to their saved query names."
  value = {
    top_errors_by_count             = aws_cloudwatch_query_definition.top_errors_by_count.name
    errors_by_instance              = aws_cloudwatch_query_definition.errors_by_instance.name
    error_trends_over_time          = aws_cloudwatch_query_definition.error_trends_over_time.name
    recent_critical_errors          = aws_cloudwatch_query_definition.recent_critical_errors.name
    slow_operations                 = aws_cloudwatch_query_definition.slow_operations.name
    operation_duration_percentiles  = aws_cloudwatch_query_definition.operation_duration_percentiles.name
    request_throughput              = aws_cloudwatch_query_definition.request_throughput.name
    failed_authentication           = aws_cloudwatch_query_definition.failed_authentication_attempts.name
    account_lockout_events          = aws_cloudwatch_query_definition.account_lockout_events.name
    privilege_escalation            = aws_cloudwatch_query_definition.privilege_escalation_analysis.name
    suspicious_security_events      = aws_cloudwatch_query_definition.suspicious_security_events.name
    correlation_id_trace            = aws_cloudwatch_query_definition.correlation_id_trace.name
    request_flow_analysis           = aws_cloudwatch_query_definition.request_flow_analysis.name
    cross_service_error_correlation = aws_cloudwatch_query_definition.cross_service_error_correlation.name
    ssm_command_execution           = aws_cloudwatch_query_definition.ssm_command_execution_history.name
    ssm_failure_analysis            = aws_cloudwatch_query_definition.ssm_failure_analysis.name
    dsc_compliance_status           = aws_cloudwatch_query_definition.dsc_compliance_status.name
    dsc_drift_details               = aws_cloudwatch_query_definition.dsc_configuration_drift_details.name
    powershell_script_execution     = aws_cloudwatch_query_definition.powershell_script_execution.name
    powershell_suspicious           = aws_cloudwatch_query_definition.powershell_suspicious_commands.name
    log_volume_by_type              = aws_cloudwatch_query_definition.log_volume_by_type.name
    instance_health_summary         = aws_cloudwatch_query_definition.instance_health_summary.name
  }
}

#------------------------------------------------------------------------------
# S3 Archival Outputs (Conditional)
#------------------------------------------------------------------------------

output "firehose_delivery_stream_arn" {
  description = "ARN of the Kinesis Firehose delivery stream for log archival (if enabled)."
  value       = var.enable_s3_archival ? aws_kinesis_firehose_delivery_stream.log_archival[0].arn : null
}

output "firehose_delivery_stream_name" {
  description = "Name of the Kinesis Firehose delivery stream for log archival (if enabled)."
  value       = var.enable_s3_archival ? aws_kinesis_firehose_delivery_stream.log_archival[0].name : null
}

output "log_archival_s3_prefix" {
  description = "S3 prefix where archived logs are stored."
  value       = var.enable_s3_archival ? "logs/${var.environment}/" : null
}

#------------------------------------------------------------------------------
# Cross-Account Sharing Outputs (Conditional)
#------------------------------------------------------------------------------

output "cross_account_destination_arn" {
  description = "ARN of the CloudWatch Logs destination for cross-account sharing (if enabled)."
  value       = var.enable_cross_account_sharing ? aws_cloudwatch_log_destination.cross_account[0].arn : null
}

#------------------------------------------------------------------------------
# IAM Role ARNs (for reference)
#------------------------------------------------------------------------------

output "cloudwatch_logs_to_firehose_role_arn" {
  description = "ARN of the IAM role used for CloudWatch Logs to Firehose delivery (if S3 archival is enabled)."
  value       = var.enable_s3_archival ? aws_iam_role.cloudwatch_logs_to_firehose[0].arn : null
}

output "firehose_to_s3_role_arn" {
  description = "ARN of the IAM role used for Firehose to S3 delivery (if S3 archival is enabled)."
  value       = var.enable_s3_archival ? aws_iam_role.firehose_to_s3[0].arn : null
}

#------------------------------------------------------------------------------
# Module Configuration Summary
#------------------------------------------------------------------------------

output "configuration_summary" {
  description = "Summary of the logging module configuration."
  value = {
    environment                   = var.environment
    project_name                  = var.project_name
    log_group_class               = var.log_group_class
    s3_archival_enabled           = var.enable_s3_archival
    lambda_processing_enabled     = var.enable_lambda_processing
    cross_account_sharing_enabled = var.enable_cross_account_sharing
    data_protection_enabled       = var.enable_data_protection
    kms_encryption_enabled        = var.kms_key_arn != null
    retention_days                = var.retention_days
  }
}
