output "log_group_names" {
  description = "Names of all CloudWatch Log Groups"
  value = {
    system      = aws_cloudwatch_log_group.system.name
    application = aws_cloudwatch_log_group.application.name
    security    = aws_cloudwatch_log_group.security.name
  }
}

output "log_group_arns" {
  description = "ARNs of all CloudWatch Log Groups"
  value = {
    system      = aws_cloudwatch_log_group.system.arn
    application = aws_cloudwatch_log_group.application.arn
    security    = aws_cloudwatch_log_group.security.arn
  }
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.name
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.fleet_health.dashboard_name
}

output "dashboard_url" {
  description = "URL to access the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.fleet_health.dashboard_name}"
}

output "alarm_names" {
  description = "Names of all CloudWatch alarms"
  value = {
    cpu_alarms              = var.enable_instance_alarms ? [for alarm in aws_cloudwatch_metric_alarm.high_cpu : alarm.alarm_name] : []
    memory_alarms           = var.enable_instance_alarms ? [for alarm in aws_cloudwatch_metric_alarm.high_memory : alarm.alarm_name] : []
    disk_alarms             = var.enable_instance_alarms ? [for alarm in aws_cloudwatch_metric_alarm.low_disk_space : alarm.alarm_name] : []
    unhealthy_host_alarm    = var.enable_target_group_alarms && var.target_group_arn_suffix != "" ? aws_cloudwatch_metric_alarm.unhealthy_hosts[0].alarm_name : null
    application_error_alarm = aws_cloudwatch_metric_alarm.application_errors.alarm_name
    security_event_alarm    = aws_cloudwatch_metric_alarm.security_events.alarm_name
    composite_alarm         = aws_cloudwatch_composite_alarm.critical_system_health.alarm_name
  }
}

output "alarm_arns" {
  description = "ARNs of all CloudWatch alarms"
  value = {
    cpu_alarms              = var.enable_instance_alarms ? [for alarm in aws_cloudwatch_metric_alarm.high_cpu : alarm.arn] : []
    memory_alarms           = var.enable_instance_alarms ? [for alarm in aws_cloudwatch_metric_alarm.high_memory : alarm.arn] : []
    disk_alarms             = var.enable_instance_alarms ? [for alarm in aws_cloudwatch_metric_alarm.low_disk_space : alarm.arn] : []
    unhealthy_host_alarm    = var.enable_target_group_alarms && var.target_group_arn_suffix != "" ? aws_cloudwatch_metric_alarm.unhealthy_hosts[0].arn : null
    application_error_alarm = aws_cloudwatch_metric_alarm.application_errors.arn
    security_event_alarm    = aws_cloudwatch_metric_alarm.security_events.arn
    composite_alarm         = aws_cloudwatch_composite_alarm.critical_system_health.arn
  }
}

output "eventbridge_rule_names" {
  description = "Names of EventBridge rules"
  value = {
    instance_state_change  = aws_cloudwatch_event_rule.instance_state_change.name
    scheduled_health_check = aws_cloudwatch_event_rule.scheduled_health_check.name
    backup_trigger         = aws_cloudwatch_event_rule.backup_trigger.name
  }
}

output "eventbridge_rule_arns" {
  description = "ARNs of EventBridge rules"
  value = {
    instance_state_change  = aws_cloudwatch_event_rule.instance_state_change.arn
    scheduled_health_check = aws_cloudwatch_event_rule.scheduled_health_check.arn
    backup_trigger         = aws_cloudwatch_event_rule.backup_trigger.arn
  }
}

output "xray_sampling_rule_id" {
  description = "ID of the X-Ray sampling rule (if enabled)"
  value       = var.enable_xray ? aws_xray_sampling_rule.fleet_sampling[0].id : null
}

output "xray_sampling_rule_arn" {
  description = "ARN of the X-Ray sampling rule (if enabled)"
  value       = var.enable_xray ? aws_xray_sampling_rule.fleet_sampling[0].arn : null
}

output "xray_group_name" {
  description = "Name of the X-Ray group (if enabled)"
  value       = var.enable_xray ? aws_xray_group.fleet_traces[0].group_name : null
}

output "xray_group_arn" {
  description = "ARN of the X-Ray group (if enabled)"
  value       = var.enable_xray ? aws_xray_group.fleet_traces[0].arn : null
}

output "metric_filter_names" {
  description = "Names of CloudWatch Log metric filters"
  value = {
    error_count      = aws_cloudwatch_log_metric_filter.error_count.name
    security_events  = aws_cloudwatch_log_metric_filter.security_events.name
  }
}

output "cloudwatch_namespace" {
  description = "CloudWatch custom metrics namespace"
  value       = var.cloudwatch_namespace
}

output "alarm_thresholds" {
  description = "Configured alarm thresholds for reference"
  value = {
    cpu_percent               = var.cpu_threshold_percent
    memory_percent            = var.memory_threshold_percent
    disk_free_percent         = var.disk_free_threshold_percent
    unhealthy_host_count      = var.unhealthy_host_threshold
    error_rate_per_minute     = var.error_rate_threshold
    cpu_evaluation_minutes    = var.cpu_evaluation_periods * var.alarm_period / 60
    memory_evaluation_minutes = var.memory_evaluation_periods * var.alarm_period / 60
  }
}

output "monitoring_summary" {
  description = "Summary of monitoring configuration"
  value = {
    environment               = var.environment
    log_groups_count          = 3
    instance_alarms_enabled   = var.enable_instance_alarms
    monitored_instances_count = length(var.instance_ids)
    target_group_alarms       = var.enable_target_group_alarms && var.target_group_arn_suffix != ""
    xray_enabled              = var.enable_xray
    alert_recipients_count    = length(var.alert_email_addresses)
    log_retention_days        = var.log_retention_days
    security_log_retention    = var.security_log_retention_days
  }
}
