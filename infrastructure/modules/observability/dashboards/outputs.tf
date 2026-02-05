# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - Fleet Health Dashboard Outputs
# -----------------------------------------------------------------------------
# This file exports key attributes of the CloudWatch Fleet Health Dashboard
# for use by other modules or root configuration.
# -----------------------------------------------------------------------------

output "dashboard_arn" {
  description = "ARN of the CloudWatch Fleet Health Dashboard"
  value       = aws_cloudwatch_dashboard.fleet_health.dashboard_arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch Fleet Health Dashboard"
  value       = aws_cloudwatch_dashboard.fleet_health.dashboard_name
}

output "dashboard_url" {
  description = "URL to access the CloudWatch Fleet Health Dashboard in the AWS Console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.fleet_health.dashboard_name}"
}

# -----------------------------------------------------------------------------
# Additional Outputs for Integration
# -----------------------------------------------------------------------------

output "dashboard_configuration" {
  description = "Summary of dashboard configuration for reference"
  value = {
    name                   = aws_cloudwatch_dashboard.fleet_health.dashboard_name
    environment            = var.environment
    project                = var.project_name
    region                 = var.aws_region
    refresh_interval       = var.dashboard_refresh_interval
    monitored_asgs         = var.auto_scaling_group_names
    monitored_instances    = length(var.instance_ids) > 0 ? var.instance_ids : ["aggregate metrics only"]
    cloudwatch_namespace   = var.cloudwatch_namespace
    metric_period_standard = var.metric_period_standard
    metric_period_detailed = var.metric_period_detailed
  }
}

output "alarm_thresholds" {
  description = "Configured alarm thresholds displayed on the dashboard"
  value = {
    cpu_percent         = var.alarm_thresholds.cpu_percent
    memory_percent      = var.alarm_thresholds.memory_percent
    disk_percent        = var.alarm_thresholds.disk_percent
    network_in_bytes    = var.alarm_thresholds.network_in_bytes
    network_out_bytes   = var.alarm_thresholds.network_out_bytes
    status_check_failed = var.alarm_thresholds.status_check_failed
  }
}

output "widget_summary" {
  description = "Summary of widgets included in the dashboard"
  value = {
    fleet_overview_widgets = 5
    cpu_widgets            = 2
    memory_widgets         = 2
    disk_widgets           = var.enable_disk_by_volume ? 2 : 0
    network_widgets        = 2
    status_check_widgets   = var.enable_ssm_status_widget ? 3 : 2
    asg_capacity_widgets   = 2
    footer_widget          = 1
    total_widgets          = 5 + 2 + 2 + (var.enable_disk_by_volume ? 2 : 0) + 2 + (var.enable_ssm_status_widget ? 3 : 2) + 2 + 1
  }
}
