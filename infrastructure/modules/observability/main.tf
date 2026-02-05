# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - Observability Module Root
# -----------------------------------------------------------------------------
# This is the root module that composes all observability submodules into a
# unified, enterprise-grade observability solution.
#
# Submodules included:
#   - dashboards: CloudWatch dashboards for fleet health, security, and cost
#   - alarms: CloudWatch metric alarms with tiered severity
#   - logging: Centralized CloudWatch log management
#   - alerting: SNS topics, subscriptions, and EventBridge rules
#
# Architecture:
#   The alerting module creates SNS topics that are passed to the alarms module.
#   The logging module creates log groups that can be referenced by dashboards.
#   All modules share common variables for environment, project, and tags.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  # Common naming prefix
  name_prefix = "${var.project_name}-${var.environment}"

  # Merged tags applied to all resources
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      Module      = "observability"
    }
  )

  # Feature flag defaults
  dashboards_enabled = var.enable_dashboards
  alarms_enabled     = var.enable_alarms
  alerting_enabled   = var.enable_alerting
  logging_enabled    = var.enable_logging
}

# -----------------------------------------------------------------------------
# Alerting Submodule
# -----------------------------------------------------------------------------
# Creates SNS topics, subscriptions, Lambda processor, and EventBridge rules.
# This is instantiated first as other modules depend on SNS topic ARNs.
# -----------------------------------------------------------------------------

module "alerting" {
  source = "./alerting"
  count  = local.alerting_enabled ? 1 : 0

  environment  = var.environment
  project_name = var.project_name
  tags         = local.common_tags

  # KMS Configuration
  kms_key_arn             = var.kms_key_arn
  kms_key_deletion_window = var.kms_key_deletion_window

  # Email Subscriptions
  email_endpoints = var.notification_emails

  # SMS Subscriptions
  sms_endpoints       = var.notification_sms
  enable_security_sms = var.enable_security_sms

  # Webhook/HTTPS Subscriptions
  webhook_endpoints            = var.webhook_endpoints
  webhook_auto_confirm         = var.webhook_auto_confirm
  webhook_raw_message_delivery = var.webhook_raw_message_delivery

  # Slack Integration
  slack_webhook_url = var.slack_webhook_url

  # PagerDuty Integration
  pagerduty_integration_key = var.pagerduty_integration_key

  # Lambda Processor Configuration
  enable_lambda_processor     = var.enable_lambda_processor
  lambda_log_level            = var.lambda_log_level
  lambda_log_retention_days   = var.lambda_log_retention_days
  lambda_reserved_concurrency = var.lambda_reserved_concurrency
  lambda_vpc_config           = var.lambda_vpc_config
  enable_xray_tracing         = var.enable_xray_tracing
  enable_lambda_alarms        = var.enable_lambda_alarms
  runbook_base_url            = var.runbook_base_url
  enable_pii_redaction        = var.enable_pii_redaction

  # SQS Configuration
  enable_sqs_subscriptions = var.enable_sqs_subscriptions
  enable_aggregate_queue   = var.enable_aggregate_queue

  # EventBridge Configuration
  enable_security_hub_rules = var.enable_security_hub_rules
  enable_cost_anomaly_rules = var.enable_cost_anomaly_rules
  enable_iam_monitoring     = var.enable_iam_monitoring

  # Cross-Account Configuration
  enable_cross_account_events = var.enable_cross_account_events
  cross_account_ids           = var.cross_account_ids
}

# -----------------------------------------------------------------------------
# Logging Submodule
# -----------------------------------------------------------------------------
# Creates CloudWatch Log Groups, metric filters, and Insights queries.
# Provides centralized log management for the fleet.
# -----------------------------------------------------------------------------

module "logging" {
  source = "./logging"
  count  = local.logging_enabled ? 1 : 0

  environment  = var.environment
  project_name = var.project_name
  tags         = local.common_tags

  # Retention Configuration
  retention_days = var.log_retention_days

  # Encryption Configuration
  kms_key_arn              = var.kms_key_arn
  encrypt_application_logs = var.encrypt_application_logs
  encrypt_system_logs      = var.encrypt_system_logs
  encrypt_ssm_logs         = var.encrypt_ssm_logs
  encrypt_dsc_logs         = var.encrypt_dsc_logs

  # Log Group Configuration
  log_group_class              = var.log_group_class
  skip_destroy_on_deletion     = var.skip_destroy_on_deletion
  enable_cross_service_logging = var.enable_cross_service_logging

  # Data Protection
  enable_data_protection     = var.enable_data_protection
  data_identifiers_to_audit  = var.data_identifiers_to_audit
  data_identifiers_to_redact = var.data_identifiers_to_redact

  # Metric Filter Configuration
  cloudwatch_namespace  = var.cloudwatch_namespace
  custom_error_pattern  = var.custom_error_pattern
  custom_metric_filters = var.custom_metric_filters

  # S3 Archival Configuration
  enable_s3_archival       = var.enable_s3_archival
  archive_bucket_name      = var.archive_bucket_name
  archive_kms_key_arn      = var.archive_kms_key_arn
  archival_filter_pattern  = var.archival_filter_pattern
  firehose_buffer_size     = var.firehose_buffer_size
  firehose_buffer_interval = var.firehose_buffer_interval

  # Lambda Processing Configuration
  enable_lambda_processing        = var.enable_log_lambda_processing
  lambda_processor_arn            = var.log_lambda_processor_arn
  lambda_filter_pattern           = var.log_lambda_filter_pattern
  enable_application_error_lambda = var.enable_application_error_lambda

  # Cross-Account Sharing Configuration
  enable_cross_account_sharing      = var.enable_cross_account_log_sharing
  cross_account_destination_arn     = var.cross_account_log_destination_arn
  cross_account_principal_arns      = var.cross_account_log_principal_arns
  cross_account_share_security_logs = var.cross_account_share_security_logs
  cross_account_filter_pattern      = var.cross_account_log_filter_pattern
}

# -----------------------------------------------------------------------------
# Alarms Submodule
# -----------------------------------------------------------------------------
# Creates CloudWatch metric alarms with tiered severity levels.
# Uses SNS topics from the alerting module for notifications.
# -----------------------------------------------------------------------------

module "alarms" {
  source = "./alarms"
  count  = local.alarms_enabled ? 1 : 0

  environment  = var.environment
  project_name = var.project_name
  tags         = local.common_tags

  # Instance Configuration
  instance_ids   = var.instance_ids
  ami_id         = var.ami_id
  instance_type  = var.instance_type
  ebs_volume_ids = var.ebs_volume_ids

  # Auto Scaling Group Configuration
  auto_scaling_group_names = var.auto_scaling_group_names
  asg_minimum_capacity     = var.asg_minimum_capacity

  # Alarm Thresholds
  alarm_thresholds   = var.alarm_thresholds
  evaluation_periods = var.evaluation_periods
  period_seconds     = var.period_seconds

  # Feature Toggles
  enable_memory_alarms    = var.enable_memory_alarms
  enable_disk_alarms      = var.enable_disk_alarms
  enable_network_alarms   = var.enable_network_alarms
  enable_ebs_alarms       = var.enable_ebs_alarms
  enable_ssm_alarms       = var.enable_ssm_alarms
  enable_composite_alarms = var.enable_composite_alarms

  # Email Notification Configuration
  notification_emails_critical = var.notification_emails_critical
  notification_emails_warning  = var.notification_emails_warning
  notification_emails_info     = var.notification_emails_info

  # SMS Notification Configuration
  notification_phone_numbers = var.notification_phone_numbers

  # Lambda Notification Configuration
  lambda_function_arn_critical = var.lambda_function_arn_critical
  lambda_function_arn_warning  = var.lambda_function_arn_warning
  lambda_function_arn_info     = var.lambda_function_arn_info

  # Webhook Configuration
  webhook_endpoints_critical = var.webhook_endpoints_critical
  webhook_endpoints_warning  = var.webhook_endpoints_warning

  # Application Health Check Configuration
  health_check_configs = var.health_check_configs
  target_group_arns    = var.target_group_arns

  # SNS Configuration
  sns_kms_key_id = var.kms_key_arn
}

# -----------------------------------------------------------------------------
# Dashboards Submodule
# -----------------------------------------------------------------------------
# Creates CloudWatch dashboards for fleet health, security, and cost monitoring.
# Visualizes metrics from all other observability components.
# -----------------------------------------------------------------------------

module "dashboards" {
  source = "./dashboards"
  count  = local.dashboards_enabled ? 1 : 0

  # Common Configuration
  environment  = var.environment
  project_name = var.project_name
  aws_region   = var.aws_region != "" ? var.aws_region : data.aws_region.current.name
  tags         = local.common_tags

  # Auto Scaling Group Configuration
  auto_scaling_group_names = var.auto_scaling_group_names

  # Instance Configuration
  instance_ids = var.instance_ids

  # Dashboard Configuration
  alarm_thresholds           = var.dashboard_alarm_thresholds
  dashboard_refresh_interval = var.dashboard_refresh_interval
  cloudwatch_namespace       = var.cloudwatch_namespace
  ssm_namespace              = var.ssm_namespace
  metric_period_standard     = var.metric_period_standard
  metric_period_detailed     = var.metric_period_detailed

  # Feature Toggles
  enable_ssm_status_widget         = var.enable_ssm_status_widget
  enable_detailed_instance_metrics = var.enable_detailed_instance_metrics
  enable_disk_by_volume            = var.enable_disk_by_volume

  # Volume Configuration
  ebs_volume_ids   = var.ebs_volume_ids
  disk_mount_paths = var.disk_mount_paths

  # Security Dashboard Configuration
  security_environment                = var.environment
  security_project_name               = var.project_name
  security_guardduty_detector_id      = var.security_guardduty_detector_id
  security_hub_enabled                = var.security_hub_enabled
  security_vpc_flow_log_group_name    = var.security_vpc_flow_log_group_name
  security_cloudtrail_log_group_name  = var.security_cloudtrail_log_group_name
  security_windows_log_group_name     = var.security_windows_log_group_name
  security_failed_login_threshold     = var.security_failed_login_threshold
  security_rejected_packets_threshold = var.security_rejected_packets_threshold
  security_api_error_threshold        = var.security_api_error_threshold
  security_alarm_actions              = local.alerting_enabled ? [module.alerting[0].security_topic_arn] : var.security_alarm_actions
  security_ok_actions                 = var.security_ok_actions
  security_enable_dashboard           = var.enable_security_dashboard
  security_enable_alarms              = var.enable_security_alarms
  security_alarm_evaluation_periods   = var.security_alarm_evaluation_periods
  security_enable_trend_analysis      = var.security_enable_trend_analysis
  security_trend_analysis_hours       = var.security_trend_analysis_hours
  security_tags                       = local.common_tags

  # Cost Dashboard Configuration
  cost_environment                     = var.environment
  cost_project_name                    = var.project_name
  cost_budget_amount                   = var.cost_budget_amount
  cost_alert_thresholds                = var.cost_alert_thresholds
  cost_enable_budget_alarms            = var.cost_enable_budget_alarms
  cost_linked_accounts                 = var.cost_linked_accounts
  cost_enable_linked_account_widgets   = var.cost_enable_linked_account_widgets
  cost_enable_cost_anomaly_detection   = var.cost_enable_cost_anomaly_detection
  cost_anomaly_monitor_type            = var.cost_anomaly_monitor_type
  cost_anomaly_monitor_dimension       = var.cost_anomaly_monitor_dimension
  cost_anomaly_threshold_expression    = var.cost_anomaly_threshold_expression
  cost_anomaly_threshold_percentage    = var.cost_anomaly_threshold_percentage
  cost_enable_service_anomaly_monitors = var.cost_enable_service_anomaly_monitors
  cost_services_for_anomaly_detection  = var.cost_services_for_anomaly_detection
  cost_sns_topic_arn                   = local.alerting_enabled ? module.alerting[0].cost_topic_arn : var.cost_sns_topic_arn
  cost_alert_email_addresses           = var.cost_alert_email_addresses
  cost_metric_period                   = var.cost_metric_period
  cost_services_to_track               = var.cost_services_to_track
  cost_instance_types_to_track         = var.cost_instance_types_to_track
  cost_enable_environment_comparison   = var.cost_enable_environment_comparison
  cost_environments_to_compare         = var.cost_environments_to_compare
  cost_environment_account_map         = var.cost_environment_account_map
  cost_kms_key_arn                     = var.kms_key_arn
  cost_tags                            = local.common_tags
}
