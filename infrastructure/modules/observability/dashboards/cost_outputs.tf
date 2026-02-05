# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - Cost Dashboard Module Outputs
# -----------------------------------------------------------------------------
# This file defines all output values from the Cost Monitoring Dashboard module.
# Outputs are prefixed with "cost_" for consistency with the cost dashboard
# variable naming convention.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Dashboard Outputs
# -----------------------------------------------------------------------------

output "cost_dashboard_arn" {
  description = "ARN of the CloudWatch Cost Monitoring Dashboard"
  value       = aws_cloudwatch_dashboard.cost_monitoring.dashboard_arn
}

output "cost_dashboard_name" {
  description = "Name of the CloudWatch Cost Monitoring Dashboard"
  value       = aws_cloudwatch_dashboard.cost_monitoring.dashboard_name
}

output "cost_dashboard_url" {
  description = "Direct URL to the CloudWatch Cost Monitoring Dashboard in the AWS Console"
  value       = "https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=${aws_cloudwatch_dashboard.cost_monitoring.dashboard_name}"
}

# -----------------------------------------------------------------------------
# SNS Topic Outputs
# -----------------------------------------------------------------------------

output "cost_alerts_sns_topic_arn" {
  description = "ARN of the SNS topic for cost anomaly alerts (null if using existing topic)"
  value       = var.cost_enable_cost_anomaly_detection && var.cost_sns_topic_arn == null ? aws_sns_topic.cost_alerts[0].arn : var.cost_sns_topic_arn
}

output "cost_alerts_sns_topic_name" {
  description = "Name of the SNS topic for cost anomaly alerts"
  value       = var.cost_enable_cost_anomaly_detection && var.cost_sns_topic_arn == null ? aws_sns_topic.cost_alerts[0].name : null
}

# -----------------------------------------------------------------------------
# Cost Anomaly Detection Outputs
# -----------------------------------------------------------------------------

output "cost_anomaly_monitor_arn" {
  description = "ARN of the primary AWS Cost Anomaly Detection monitor"
  value       = var.cost_enable_cost_anomaly_detection ? aws_ce_anomaly_monitor.cost_monitor[0].arn : null
}

output "cost_anomaly_monitor_id" {
  description = "ID of the primary AWS Cost Anomaly Detection monitor"
  value       = var.cost_enable_cost_anomaly_detection ? aws_ce_anomaly_monitor.cost_monitor[0].id : null
}

output "cost_anomaly_subscription_arn" {
  description = "ARN of the AWS Cost Anomaly Detection subscription"
  value       = var.cost_enable_cost_anomaly_detection ? aws_ce_anomaly_subscription.cost_subscription[0].arn : null
}

output "cost_anomaly_subscription_id" {
  description = "ID of the AWS Cost Anomaly Detection subscription"
  value       = var.cost_enable_cost_anomaly_detection ? aws_ce_anomaly_subscription.cost_subscription[0].id : null
}

# -----------------------------------------------------------------------------
# Service-Specific Anomaly Monitor Outputs
# -----------------------------------------------------------------------------

output "cost_service_anomaly_monitor_arns" {
  description = "Map of service names to their anomaly monitor ARNs"
  value = var.cost_enable_service_anomaly_monitors ? {
    for service, monitor in aws_ce_anomaly_monitor.service_monitors : service => monitor.arn
  } : {}
}

# -----------------------------------------------------------------------------
# Linked Account Monitor Outputs
# -----------------------------------------------------------------------------

output "cost_linked_account_monitor_arn" {
  description = "ARN of the linked account anomaly monitor (for multi-account setups)"
  value       = var.cost_enable_cost_anomaly_detection && var.cost_enable_linked_account_widgets && length(var.cost_linked_accounts) > 0 ? aws_ce_anomaly_monitor.linked_account_monitor[0].arn : null
}

# -----------------------------------------------------------------------------
# CloudWatch Alarm Outputs
# -----------------------------------------------------------------------------

output "cost_budget_warning_alarm_arn" {
  description = "ARN of the budget warning CloudWatch alarm"
  value       = var.cost_enable_budget_alarms ? aws_cloudwatch_metric_alarm.budget_warning[0].arn : null
}

output "cost_budget_warning_alarm_name" {
  description = "Name of the budget warning CloudWatch alarm"
  value       = var.cost_enable_budget_alarms ? aws_cloudwatch_metric_alarm.budget_warning[0].alarm_name : null
}

output "cost_budget_critical_alarm_arn" {
  description = "ARN of the budget critical CloudWatch alarm"
  value       = var.cost_enable_budget_alarms ? aws_cloudwatch_metric_alarm.budget_critical[0].arn : null
}

output "cost_budget_critical_alarm_name" {
  description = "Name of the budget critical CloudWatch alarm"
  value       = var.cost_enable_budget_alarms ? aws_cloudwatch_metric_alarm.budget_critical[0].alarm_name : null
}

# -----------------------------------------------------------------------------
# Budget Threshold Outputs
# -----------------------------------------------------------------------------

output "cost_budget_thresholds" {
  description = "Calculated budget threshold values in USD"
  value = {
    monthly_budget     = var.cost_budget_amount
    warning_threshold  = var.cost_budget_amount * (var.cost_alert_thresholds.warning / 100)
    critical_threshold = var.cost_budget_amount * (var.cost_alert_thresholds.critical / 100)
    daily_budget       = var.cost_budget_amount / 30
    weekly_budget      = var.cost_budget_amount / 4
  }
}

# -----------------------------------------------------------------------------
# Configuration Summary Output
# -----------------------------------------------------------------------------

output "cost_dashboard_configuration" {
  description = "Summary of the cost dashboard configuration"
  value = {
    dashboard_name                    = local.dashboard_name
    environment                       = var.cost_environment
    project_name                      = var.cost_project_name
    budget_amount                     = var.cost_budget_amount
    anomaly_detection_enabled         = var.cost_enable_cost_anomaly_detection
    service_anomaly_monitors_enabled  = var.cost_enable_service_anomaly_monitors
    environment_comparison_enabled    = var.cost_enable_environment_comparison
    budget_alarms_enabled             = var.cost_enable_budget_alarms
    linked_account_monitoring_enabled = var.cost_enable_linked_account_widgets
    tracked_services                  = var.cost_services_to_track
    tracked_instance_types            = var.cost_instance_types_to_track
  }
}
