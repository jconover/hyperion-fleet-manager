# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - Observability Module Outputs
# -----------------------------------------------------------------------------
# This file exports all outputs from the observability root module,
# aggregating outputs from all submodules into a unified interface.
# -----------------------------------------------------------------------------

# =============================================================================
# DASHBOARD OUTPUTS
# =============================================================================

output "dashboard_arns" {
  description = "Map of all CloudWatch dashboard ARNs"
  value = var.enable_dashboards ? {
    fleet_health = module.dashboards[0].dashboard_arn
    security     = module.dashboards[0].security_dashboard_arn
    cost         = module.dashboards[0].cost_dashboard_arn
  } : {}
}

output "dashboard_names" {
  description = "Map of all CloudWatch dashboard names"
  value = var.enable_dashboards ? {
    fleet_health = module.dashboards[0].dashboard_name
    security     = module.dashboards[0].security_dashboard_name
    cost         = module.dashboards[0].cost_dashboard_name
  } : {}
}

output "dashboard_urls" {
  description = "Map of direct URLs to CloudWatch dashboards in AWS Console"
  value = var.enable_dashboards ? {
    fleet_health = module.dashboards[0].dashboard_url
    security     = module.dashboards[0].security_dashboard_url
    cost         = module.dashboards[0].cost_dashboard_url
  } : {}
}

output "fleet_health_dashboard_arn" {
  description = "ARN of the Fleet Health CloudWatch dashboard"
  value       = var.enable_dashboards ? module.dashboards[0].dashboard_arn : null
}

output "fleet_health_dashboard_url" {
  description = "URL to access the Fleet Health dashboard"
  value       = var.enable_dashboards ? module.dashboards[0].dashboard_url : null
}

output "security_dashboard_arn" {
  description = "ARN of the Security CloudWatch dashboard"
  value       = var.enable_dashboards ? module.dashboards[0].security_dashboard_arn : null
}

output "security_dashboard_url" {
  description = "URL to access the Security dashboard"
  value       = var.enable_dashboards ? module.dashboards[0].security_dashboard_url : null
}

output "cost_dashboard_arn" {
  description = "ARN of the Cost Monitoring CloudWatch dashboard"
  value       = var.enable_dashboards ? module.dashboards[0].cost_dashboard_arn : null
}

output "cost_dashboard_url" {
  description = "URL to access the Cost Monitoring dashboard"
  value       = var.enable_dashboards ? module.dashboards[0].cost_dashboard_url : null
}

# =============================================================================
# ALARM OUTPUTS
# =============================================================================

output "alarm_arns" {
  description = "Map of all CloudWatch alarm ARNs organized by type"
  value       = var.enable_alarms ? module.alarms[0].alarm_arns : {}
}

output "alarm_names" {
  description = "Map of all CloudWatch alarm names organized by type"
  value       = var.enable_alarms ? module.alarms[0].alarm_names : {}
}

output "composite_alarm_arns" {
  description = "Map of composite alarm ARNs"
  value       = var.enable_alarms ? module.alarms[0].composite_alarm_arns : {}
}

output "composite_alarm_names" {
  description = "Map of composite alarm names"
  value       = var.enable_alarms ? module.alarms[0].composite_alarm_names : {}
}

output "critical_alarm_arns" {
  description = "List of all critical alarm ARNs for easy iteration"
  value       = var.enable_alarms ? module.alarms[0].critical_alarm_arns : []
}

output "warning_alarm_arns" {
  description = "List of all warning alarm ARNs for easy iteration"
  value       = var.enable_alarms ? module.alarms[0].warning_alarm_arns : []
}

output "alarm_count" {
  description = "Count of alarms by severity"
  value       = var.enable_alarms ? module.alarms[0].alarm_count : {}
}

output "effective_thresholds" {
  description = "The effective alarm thresholds after merging with defaults"
  value       = var.enable_alarms ? module.alarms[0].effective_thresholds : {}
}

output "security_alarm_arns" {
  description = "Map of security alarm names to their ARNs"
  value       = var.enable_dashboards ? module.dashboards[0].security_alarm_arns : {}
}

output "security_alarm_names" {
  description = "List of all security alarm names"
  value       = var.enable_dashboards ? module.dashboards[0].security_alarm_names : []
}

# =============================================================================
# SNS TOPIC OUTPUTS
# =============================================================================

output "sns_topic_arns" {
  description = "Map of SNS topic ARNs by severity level"
  value = var.enable_alerting ? {
    critical = module.alerting[0].critical_topic_arn
    warning  = module.alerting[0].warning_topic_arn
    info     = module.alerting[0].info_topic_arn
    security = module.alerting[0].security_topic_arn
    cost     = module.alerting[0].cost_topic_arn
  } : {}
}

output "sns_topic_names" {
  description = "Map of SNS topic names by severity level"
  value       = var.enable_alerting ? module.alerting[0].topic_names : {}
}

output "critical_topic_arn" {
  description = "ARN of the critical alerts SNS topic"
  value       = var.enable_alerting ? module.alerting[0].critical_topic_arn : null
}

output "warning_topic_arn" {
  description = "ARN of the warning alerts SNS topic"
  value       = var.enable_alerting ? module.alerting[0].warning_topic_arn : null
}

output "info_topic_arn" {
  description = "ARN of the info alerts SNS topic"
  value       = var.enable_alerting ? module.alerting[0].info_topic_arn : null
}

output "security_topic_arn" {
  description = "ARN of the security alerts SNS topic"
  value       = var.enable_alerting ? module.alerting[0].security_topic_arn : null
}

output "cost_topic_arn" {
  description = "ARN of the cost alerts SNS topic"
  value       = var.enable_alerting ? module.alerting[0].cost_topic_arn : null
}

# Alarms submodule SNS topics (separate from alerting)
output "alarms_sns_topic_arns" {
  description = "Map of SNS topic ARNs from alarms submodule by severity level"
  value       = var.enable_alarms ? module.alarms[0].sns_topic_arns : {}
}

output "alarms_sns_topic_names" {
  description = "Map of SNS topic names from alarms submodule by severity level"
  value       = var.enable_alarms ? module.alarms[0].sns_topic_names : {}
}

# =============================================================================
# LOG GROUP OUTPUTS
# =============================================================================

output "log_group_arns" {
  description = "Map of CloudWatch Log Group ARNs by log type"
  value       = var.enable_logging ? module.logging[0].log_group_arns : {}
}

output "log_group_names" {
  description = "Map of CloudWatch Log Group names by log type"
  value       = var.enable_logging ? module.logging[0].log_group_names : {}
}

output "log_group_arn_application" {
  description = "ARN of the application log group"
  value       = var.enable_logging ? module.logging[0].log_group_arn_application : null
}

output "log_group_arn_system" {
  description = "ARN of the system log group"
  value       = var.enable_logging ? module.logging[0].log_group_arn_system : null
}

output "log_group_arn_security" {
  description = "ARN of the security log group"
  value       = var.enable_logging ? module.logging[0].log_group_arn_security : null
}

output "log_group_arn_powershell" {
  description = "ARN of the PowerShell log group"
  value       = var.enable_logging ? module.logging[0].log_group_arn_powershell : null
}

output "log_group_arn_ssm" {
  description = "ARN of the SSM log group"
  value       = var.enable_logging ? module.logging[0].log_group_arn_ssm : null
}

output "log_group_arn_dsc" {
  description = "ARN of the DSC log group"
  value       = var.enable_logging ? module.logging[0].log_group_arn_dsc : null
}

# =============================================================================
# METRIC FILTER OUTPUTS
# =============================================================================

output "metric_filter_names" {
  description = "Map of metric filter purposes to their names"
  value       = var.enable_logging ? module.logging[0].metric_filter_names : {}
}

output "custom_metric_filter_names" {
  description = "Map of custom metric filter keys to their names"
  value       = var.enable_logging ? module.logging[0].custom_metric_filter_names : {}
}

output "cloudwatch_namespace" {
  description = "CloudWatch namespace where log metrics are published"
  value       = var.enable_logging ? module.logging[0].cloudwatch_namespace : var.cloudwatch_namespace
}

output "metric_names" {
  description = "List of metric names created by the metric filters"
  value       = var.enable_logging ? module.logging[0].metric_names : []
}

# =============================================================================
# LOGS INSIGHTS QUERY OUTPUTS
# =============================================================================

output "insights_query_names" {
  description = "Map of query purposes to their saved query names"
  value       = var.enable_logging ? module.logging[0].insights_query_names : {}
}

# =============================================================================
# LAMBDA FUNCTION OUTPUTS
# =============================================================================

output "lambda_function_arn" {
  description = "ARN of the alert processor Lambda function"
  value       = var.enable_alerting ? module.alerting[0].lambda_function_arn : null
}

output "lambda_function_name" {
  description = "Name of the alert processor Lambda function"
  value       = var.enable_alerting ? module.alerting[0].lambda_function_name : null
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the alert processor Lambda function"
  value       = var.enable_alerting ? module.alerting[0].lambda_function_invoke_arn : null
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = var.enable_alerting ? module.alerting[0].lambda_role_arn : null
}

output "lambda_dlq_arn" {
  description = "ARN of the Lambda dead letter queue"
  value       = var.enable_alerting ? module.alerting[0].lambda_dlq_arn : null
}

output "lambda_dlq_url" {
  description = "URL of the Lambda dead letter queue"
  value       = var.enable_alerting ? module.alerting[0].lambda_dlq_url : null
}

output "lambda_log_group_name" {
  description = "Name of the CloudWatch Log Group for Lambda function"
  value       = var.enable_alerting ? module.alerting[0].lambda_log_group_name : null
}

output "lambda_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for Lambda function"
  value       = var.enable_alerting ? module.alerting[0].lambda_log_group_arn : null
}

# =============================================================================
# SQS QUEUE OUTPUTS
# =============================================================================

output "sqs_queue_arns" {
  description = "Map of SQS queue ARNs for alert processing"
  value       = var.enable_alerting ? module.alerting[0].sqs_queue_arns : {}
}

output "sqs_queue_urls" {
  description = "Map of SQS queue URLs"
  value       = var.enable_alerting ? module.alerting[0].sqs_queue_urls : {}
}

output "aggregate_queue_arn" {
  description = "ARN of the aggregate alerts queue (if enabled)"
  value       = var.enable_alerting ? module.alerting[0].aggregate_queue_arn : null
}

output "aggregate_queue_url" {
  description = "URL of the aggregate alerts queue (if enabled)"
  value       = var.enable_alerting ? module.alerting[0].aggregate_queue_url : null
}

# =============================================================================
# EVENTBRIDGE OUTPUTS
# =============================================================================

output "eventbridge_rule_arns" {
  description = "Map of EventBridge rule ARNs"
  value       = var.enable_alerting ? module.alerting[0].eventbridge_rule_arns : {}
}

output "cross_account_event_bus_arn" {
  description = "ARN of the cross-account event bus (if enabled)"
  value       = var.enable_alerting ? module.alerting[0].cross_account_event_bus_arn : null
}

output "cross_account_event_bus_name" {
  description = "Name of the cross-account event bus (if enabled)"
  value       = var.enable_alerting ? module.alerting[0].cross_account_event_bus_name : null
}

# =============================================================================
# KMS KEY OUTPUTS
# =============================================================================

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = var.enable_alerting ? module.alerting[0].kms_key_arn : var.kms_key_arn
}

output "kms_key_id" {
  description = "ID of the KMS key used for encryption (if created by this module)"
  value       = var.enable_alerting ? module.alerting[0].kms_key_id : null
}

output "kms_key_alias" {
  description = "Alias of the KMS key (if created by this module)"
  value       = var.enable_alerting ? module.alerting[0].kms_key_alias : null
}

# =============================================================================
# S3 ARCHIVAL OUTPUTS
# =============================================================================

output "firehose_delivery_stream_arn" {
  description = "ARN of the Kinesis Firehose delivery stream for log archival (if enabled)"
  value       = var.enable_logging ? module.logging[0].firehose_delivery_stream_arn : null
}

output "firehose_delivery_stream_name" {
  description = "Name of the Kinesis Firehose delivery stream for log archival (if enabled)"
  value       = var.enable_logging ? module.logging[0].firehose_delivery_stream_name : null
}

output "log_archival_s3_prefix" {
  description = "S3 prefix where archived logs are stored"
  value       = var.enable_logging ? module.logging[0].log_archival_s3_prefix : null
}

# =============================================================================
# CROSS-ACCOUNT OUTPUTS
# =============================================================================

output "cross_account_log_destination_arn" {
  description = "ARN of the CloudWatch Logs destination for cross-account sharing (if enabled)"
  value       = var.enable_logging ? module.logging[0].cross_account_destination_arn : null
}

# =============================================================================
# IAM ROLE OUTPUTS
# =============================================================================

output "cloudwatch_logs_to_firehose_role_arn" {
  description = "ARN of the IAM role used for CloudWatch Logs to Firehose delivery"
  value       = var.enable_logging ? module.logging[0].cloudwatch_logs_to_firehose_role_arn : null
}

output "firehose_to_s3_role_arn" {
  description = "ARN of the IAM role used for Firehose to S3 delivery"
  value       = var.enable_logging ? module.logging[0].firehose_to_s3_role_arn : null
}

# =============================================================================
# COST ANOMALY DETECTION OUTPUTS
# =============================================================================

output "cost_anomaly_monitor_arn" {
  description = "ARN of the primary AWS Cost Anomaly Detection monitor"
  value       = var.enable_dashboards ? module.dashboards[0].cost_anomaly_monitor_arn : null
}

output "cost_anomaly_subscription_arn" {
  description = "ARN of the AWS Cost Anomaly Detection subscription"
  value       = var.enable_dashboards ? module.dashboards[0].cost_anomaly_subscription_arn : null
}

output "cost_service_anomaly_monitor_arns" {
  description = "Map of service names to their anomaly monitor ARNs"
  value       = var.enable_dashboards ? module.dashboards[0].cost_service_anomaly_monitor_arns : {}
}

output "cost_budget_thresholds" {
  description = "Calculated budget threshold values in USD"
  value       = var.enable_dashboards ? module.dashboards[0].cost_budget_thresholds : {}
}

# =============================================================================
# SUBSCRIPTION OUTPUTS
# =============================================================================

output "email_subscription_arns" {
  description = "Map of email subscription ARNs"
  value       = var.enable_alerting ? module.alerting[0].email_subscription_arns : {}
}

output "sms_subscription_arns" {
  description = "Map of SMS subscription ARNs"
  value       = var.enable_alerting ? module.alerting[0].sms_subscription_arns : {}
}

output "https_subscription_arns" {
  description = "Map of HTTPS/webhook subscription ARNs"
  value       = var.enable_alerting ? module.alerting[0].https_subscription_arns : {}
}

output "subscription_summary" {
  description = "Summary of all subscription types and counts"
  value       = var.enable_alerting ? module.alerting[0].subscription_summary : {}
}

output "alarms_subscription_count" {
  description = "Count of subscriptions by type from alarms submodule"
  value       = var.enable_alarms ? module.alarms[0].subscription_count : {}
}

# =============================================================================
# DASHBOARD INTEGRATION OUTPUTS
# =============================================================================

output "dashboard_widget_config" {
  description = "Configuration for CloudWatch dashboard widgets"
  value       = var.enable_alarms ? module.alarms[0].dashboard_widget_config : {}
}

# =============================================================================
# CONFIGURATION SUMMARIES
# =============================================================================

output "logging_configuration_summary" {
  description = "Summary of the logging module configuration"
  value       = var.enable_logging ? module.logging[0].configuration_summary : {}
}

output "alerting_integration_config" {
  description = "Configuration details for integrating with the alerting module"
  value       = var.enable_alerting ? module.alerting[0].integration_config : {}
}

output "alerting_module_summary" {
  description = "Summary of all resources created by the alerting module"
  value       = var.enable_alerting ? module.alerting[0].module_summary : {}
}

output "dashboard_configuration" {
  description = "Summary of dashboard configuration"
  value       = var.enable_dashboards ? module.dashboards[0].dashboard_configuration : {}
}

output "security_dashboard_configuration" {
  description = "Summary of Security dashboard configuration"
  value       = var.enable_dashboards ? module.dashboards[0].security_dashboard_configuration : {}
}

output "cost_dashboard_configuration" {
  description = "Summary of the cost dashboard configuration"
  value       = var.enable_dashboards ? module.dashboards[0].cost_dashboard_configuration : {}
}

# =============================================================================
# CONSOLIDATED SUMMARY OUTPUT
# =============================================================================

output "observability_summary" {
  description = "Consolidated summary of all observability resources and configuration"
  value = {
    # Module Status
    modules_enabled = {
      dashboards = var.enable_dashboards
      alarms     = var.enable_alarms
      alerting   = var.enable_alerting
      logging    = var.enable_logging
    }

    # Environment
    environment  = var.environment
    project_name = var.project_name
    aws_region   = var.aws_region != "" ? var.aws_region : data.aws_region.current.name
    aws_account  = data.aws_caller_identity.current.account_id

    # Dashboard Summary
    dashboards = var.enable_dashboards ? {
      fleet_health_url = module.dashboards[0].dashboard_url
      security_url     = module.dashboards[0].security_dashboard_url
      cost_url         = module.dashboards[0].cost_dashboard_url
    } : {}

    # Alarms Summary
    alarms = var.enable_alarms ? {
      total_count    = module.alarms[0].alarm_count.total
      critical_count = module.alarms[0].alarm_count.critical
      warning_count  = module.alarms[0].alarm_count.warning
    } : {}

    # Alerting Summary
    alerting = var.enable_alerting ? {
      sns_topics_count          = module.alerting[0].module_summary.sns_topics_count
      email_subscriptions_count = module.alerting[0].module_summary.email_subscriptions_count
      sms_subscriptions_count   = module.alerting[0].module_summary.sms_subscriptions_count
      lambda_enabled            = module.alerting[0].module_summary.lambda_enabled
      eventbridge_rules_count   = module.alerting[0].module_summary.eventbridge_rules_count
    } : {}

    # Logging Summary
    logging = var.enable_logging ? {
      log_groups_count              = 6
      s3_archival_enabled           = module.logging[0].configuration_summary.s3_archival_enabled
      lambda_processing_enabled     = module.logging[0].configuration_summary.lambda_processing_enabled
      cross_account_sharing_enabled = module.logging[0].configuration_summary.cross_account_sharing_enabled
      data_protection_enabled       = module.logging[0].configuration_summary.data_protection_enabled
      kms_encryption_enabled        = module.logging[0].configuration_summary.kms_encryption_enabled
    } : {}

    # Quick Reference
    quick_reference = {
      critical_sns_topic = var.enable_alerting ? module.alerting[0].critical_topic_arn : null
      security_sns_topic = var.enable_alerting ? module.alerting[0].security_topic_arn : null
      application_logs   = var.enable_logging ? module.logging[0].log_group_arn_application : null
      security_logs      = var.enable_logging ? module.logging[0].log_group_arn_security : null
    }
  }
}
