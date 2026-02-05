# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - Security Dashboard Module Outputs
# -----------------------------------------------------------------------------
# This file exports key attributes of the CloudWatch Security Dashboard
# for use by other modules or root configuration.
# -----------------------------------------------------------------------------

# =============================================================================
# SECURITY DASHBOARD OUTPUTS
# =============================================================================

output "security_dashboard_arn" {
  description = "ARN of the CloudWatch Security Dashboard"
  value       = aws_cloudwatch_dashboard.security.dashboard_arn
}

output "security_dashboard_name" {
  description = "Name of the CloudWatch Security Dashboard"
  value       = aws_cloudwatch_dashboard.security.dashboard_name
}

output "security_dashboard_url" {
  description = "URL to access the CloudWatch Security Dashboard in the AWS Console"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.security.dashboard_name}"
}

# -----------------------------------------------------------------------------
# Security Dashboard Configuration Summary
# -----------------------------------------------------------------------------

output "security_dashboard_configuration" {
  description = "Summary of Security dashboard configuration for reference"
  value = {
    name                     = aws_cloudwatch_dashboard.security.dashboard_name
    environment              = var.security_environment
    project                  = var.security_project_name
    guardduty_enabled        = var.security_guardduty_detector_id != ""
    security_hub_enabled     = var.security_hub_enabled
    vpc_flow_logs_enabled    = var.security_vpc_flow_log_group_name != ""
    cloudtrail_enabled       = var.security_cloudtrail_log_group_name != ""
    windows_security_enabled = var.security_windows_log_group_name != ""
    trend_analysis_enabled   = var.security_enable_trend_analysis
    trend_analysis_hours     = var.security_trend_analysis_hours
  }
}

output "security_alarm_thresholds_output" {
  description = "Configured alarm thresholds for the Security dashboard"
  value = {
    failed_login_threshold     = var.security_failed_login_threshold
    rejected_packets_threshold = var.security_rejected_packets_threshold
    api_error_threshold        = var.security_api_error_threshold
  }
}

output "security_widget_summary" {
  description = "Summary of widgets included in the Security dashboard"
  value = {
    header_widget             = 1
    guardduty_widgets         = var.security_guardduty_detector_id != "" ? 2 : 1
    security_hub_widgets      = var.security_hub_enabled ? 2 : 1
    windows_security_widgets  = var.security_windows_log_group_name != "" ? 2 : 1
    cloudtrail_widgets        = var.security_cloudtrail_log_group_name != "" ? 3 : 1
    vpc_flow_log_widgets      = var.security_vpc_flow_log_group_name != "" ? 2 : 1
    kms_secrets_widgets       = 2
    config_compliance_widgets = 3
    trend_analysis_widgets    = var.security_cloudtrail_log_group_name != "" && var.security_enable_trend_analysis ? 1 : 0
    active_alarms_widget      = 1
  }
}

# =============================================================================
# SECURITY ALARMS OUTPUTS
# =============================================================================

output "security_alarm_arns" {
  description = "Map of security alarm names to their ARNs"
  value = {
    guardduty_high_severity = length(aws_cloudwatch_metric_alarm.guardduty_high_severity) > 0 ? aws_cloudwatch_metric_alarm.guardduty_high_severity[0].arn : null
    security_hub_critical   = length(aws_cloudwatch_metric_alarm.security_hub_critical) > 0 ? aws_cloudwatch_metric_alarm.security_hub_critical[0].arn : null
    failed_logins           = length(aws_cloudwatch_metric_alarm.failed_logins) > 0 ? aws_cloudwatch_metric_alarm.failed_logins[0].arn : null
    iam_changes             = length(aws_cloudwatch_metric_alarm.iam_changes) > 0 ? aws_cloudwatch_metric_alarm.iam_changes[0].arn : null
    security_group_changes  = length(aws_cloudwatch_metric_alarm.security_group_changes) > 0 ? aws_cloudwatch_metric_alarm.security_group_changes[0].arn : null
    vpc_rejected_packets    = length(aws_cloudwatch_metric_alarm.vpc_rejected_packets) > 0 ? aws_cloudwatch_metric_alarm.vpc_rejected_packets[0].arn : null
    cloudtrail_api_errors   = length(aws_cloudwatch_metric_alarm.cloudtrail_api_errors) > 0 ? aws_cloudwatch_metric_alarm.cloudtrail_api_errors[0].arn : null
  }
}

output "security_alarm_names" {
  description = "List of all security alarm names created by this module"
  value = compact([
    length(aws_cloudwatch_metric_alarm.guardduty_high_severity) > 0 ? aws_cloudwatch_metric_alarm.guardduty_high_severity[0].alarm_name : "",
    length(aws_cloudwatch_metric_alarm.security_hub_critical) > 0 ? aws_cloudwatch_metric_alarm.security_hub_critical[0].alarm_name : "",
    length(aws_cloudwatch_metric_alarm.failed_logins) > 0 ? aws_cloudwatch_metric_alarm.failed_logins[0].alarm_name : "",
    length(aws_cloudwatch_metric_alarm.iam_changes) > 0 ? aws_cloudwatch_metric_alarm.iam_changes[0].alarm_name : "",
    length(aws_cloudwatch_metric_alarm.security_group_changes) > 0 ? aws_cloudwatch_metric_alarm.security_group_changes[0].alarm_name : "",
    length(aws_cloudwatch_metric_alarm.vpc_rejected_packets) > 0 ? aws_cloudwatch_metric_alarm.vpc_rejected_packets[0].alarm_name : "",
    length(aws_cloudwatch_metric_alarm.cloudtrail_api_errors) > 0 ? aws_cloudwatch_metric_alarm.cloudtrail_api_errors[0].alarm_name : ""
  ])
}

# =============================================================================
# METRIC FILTER OUTPUTS
# =============================================================================

output "security_metric_filter_names" {
  description = "List of all security metric filter names created by this module"
  value = compact([
    length(aws_cloudwatch_log_metric_filter.failed_logins) > 0 ? aws_cloudwatch_log_metric_filter.failed_logins[0].name : "",
    length(aws_cloudwatch_log_metric_filter.iam_changes) > 0 ? aws_cloudwatch_log_metric_filter.iam_changes[0].name : "",
    length(aws_cloudwatch_log_metric_filter.security_group_changes) > 0 ? aws_cloudwatch_log_metric_filter.security_group_changes[0].name : "",
    length(aws_cloudwatch_log_metric_filter.vpc_rejected_packets) > 0 ? aws_cloudwatch_log_metric_filter.vpc_rejected_packets[0].name : "",
    length(aws_cloudwatch_log_metric_filter.cloudtrail_api_errors) > 0 ? aws_cloudwatch_log_metric_filter.cloudtrail_api_errors[0].name : ""
  ])
}

output "security_metrics_namespace" {
  description = "CloudWatch namespace where security metrics are published"
  value       = "${var.security_project_name}/Security"
}
