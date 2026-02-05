# =============================================================================
# Outputs for SNS Alerting Module
# =============================================================================

# -----------------------------------------------------------------------------
# SNS Topic ARNs
# -----------------------------------------------------------------------------

output "topic_arns" {
  description = "Map of SNS topic ARNs by severity level"
  value = {
    critical = aws_sns_topic.critical.arn
    warning  = aws_sns_topic.warning.arn
    info     = aws_sns_topic.info.arn
    security = aws_sns_topic.security.arn
    cost     = aws_sns_topic.cost.arn
  }
}

output "critical_topic_arn" {
  description = "ARN of the critical alerts SNS topic"
  value       = aws_sns_topic.critical.arn
}

output "warning_topic_arn" {
  description = "ARN of the warning alerts SNS topic"
  value       = aws_sns_topic.warning.arn
}

output "info_topic_arn" {
  description = "ARN of the info alerts SNS topic"
  value       = aws_sns_topic.info.arn
}

output "security_topic_arn" {
  description = "ARN of the security alerts SNS topic"
  value       = aws_sns_topic.security.arn
}

output "cost_topic_arn" {
  description = "ARN of the cost alerts SNS topic"
  value       = aws_sns_topic.cost.arn
}

# -----------------------------------------------------------------------------
# SNS Topic Names
# -----------------------------------------------------------------------------

output "topic_names" {
  description = "Map of SNS topic names by severity level"
  value = {
    critical = aws_sns_topic.critical.name
    warning  = aws_sns_topic.warning.name
    info     = aws_sns_topic.info.name
    security = aws_sns_topic.security.name
    cost     = aws_sns_topic.cost.name
  }
}

# -----------------------------------------------------------------------------
# Subscription ARNs
# -----------------------------------------------------------------------------

output "email_subscription_arns" {
  description = "Map of email subscription ARNs"
  value       = local.email_subscription_arns
}

output "sms_subscription_arns" {
  description = "Map of SMS subscription ARNs"
  value       = local.sms_subscription_arns
}

output "https_subscription_arns" {
  description = "Map of HTTPS/webhook subscription ARNs"
  value       = local.https_subscription_arns
}

output "subscription_summary" {
  description = "Summary of all subscription types and counts"
  value = {
    email_count    = length(local.email_subscription_arns)
    sms_count      = length(local.sms_subscription_arns)
    https_count    = length(local.https_subscription_arns)
    lambda_enabled = var.enable_lambda_processor
    sqs_enabled    = var.enable_sqs_subscriptions
  }
}

# -----------------------------------------------------------------------------
# Lambda Function Outputs
# -----------------------------------------------------------------------------

output "lambda_function_arn" {
  description = "ARN of the alert processor Lambda function"
  value       = var.enable_lambda_processor ? aws_lambda_function.alert_processor[0].arn : null
}

output "lambda_function_name" {
  description = "Name of the alert processor Lambda function"
  value       = var.enable_lambda_processor ? aws_lambda_function.alert_processor[0].function_name : null
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the alert processor Lambda function"
  value       = var.enable_lambda_processor ? aws_lambda_function.alert_processor[0].invoke_arn : null
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_processor.arn
}

output "lambda_dlq_arn" {
  description = "ARN of the Lambda dead letter queue"
  value       = var.enable_lambda_processor ? aws_sqs_queue.lambda_dlq[0].arn : null
}

output "lambda_dlq_url" {
  description = "URL of the Lambda dead letter queue"
  value       = var.enable_lambda_processor ? aws_sqs_queue.lambda_dlq[0].url : null
}

# -----------------------------------------------------------------------------
# SQS Queue Outputs
# -----------------------------------------------------------------------------

output "sqs_queue_arns" {
  description = "Map of SQS queue ARNs for alert processing"
  value       = local.sqs_queue_arns
}

output "sqs_queue_urls" {
  description = "Map of SQS queue URLs"
  value = var.enable_sqs_subscriptions ? {
    critical_queue = aws_sqs_queue.critical_alerts[0].url
    critical_dlq   = aws_sqs_queue.critical_alerts_dlq[0].url
    security_queue = aws_sqs_queue.security_alerts[0].url
    security_dlq   = aws_sqs_queue.security_alerts_dlq[0].url
  } : {}
}

output "aggregate_queue_arn" {
  description = "ARN of the aggregate alerts queue (if enabled)"
  value       = var.enable_aggregate_queue ? aws_sqs_queue.all_alerts[0].arn : null
}

output "aggregate_queue_url" {
  description = "URL of the aggregate alerts queue (if enabled)"
  value       = var.enable_aggregate_queue ? aws_sqs_queue.all_alerts[0].url : null
}

# -----------------------------------------------------------------------------
# KMS Key Outputs
# -----------------------------------------------------------------------------

output "kms_key_arn" {
  description = "ARN of the KMS key used for SNS encryption"
  value       = local.kms_key_arn
}

output "kms_key_id" {
  description = "ID of the KMS key used for SNS encryption"
  value       = var.kms_key_arn == null ? aws_kms_key.sns[0].key_id : null
}

output "kms_key_alias" {
  description = "Alias of the KMS key (if created by this module)"
  value       = var.kms_key_arn == null ? aws_kms_alias.sns[0].name : null
}

# -----------------------------------------------------------------------------
# EventBridge Outputs
# -----------------------------------------------------------------------------

output "eventbridge_rule_arns" {
  description = "Map of EventBridge rule ARNs"
  value = {
    guardduty_findings   = aws_cloudwatch_event_rule.guardduty_findings.arn
    guardduty_critical   = aws_cloudwatch_event_rule.guardduty_critical.arn
    cloudwatch_critical  = aws_cloudwatch_event_rule.cloudwatch_alarm_critical.arn
    cloudwatch_warning   = aws_cloudwatch_event_rule.cloudwatch_alarm_warning.arn
    cloudwatch_recovery  = aws_cloudwatch_event_rule.cloudwatch_alarm_recovery.arn
    config_compliance    = aws_cloudwatch_event_rule.config_compliance.arn
    ec2_state_change     = aws_cloudwatch_event_rule.ec2_state_change.arn
    ec2_terminated       = aws_cloudwatch_event_rule.ec2_terminated.arn
    autoscaling_events   = aws_cloudwatch_event_rule.autoscaling_events.arn
    autoscaling_failures = aws_cloudwatch_event_rule.autoscaling_failures.arn
    security_hub         = var.enable_security_hub_rules ? aws_cloudwatch_event_rule.security_hub_findings[0].arn : null
    cost_anomaly         = var.enable_cost_anomaly_rules ? aws_cloudwatch_event_rule.cost_anomaly[0].arn : null
    iam_changes          = var.enable_iam_monitoring ? aws_cloudwatch_event_rule.iam_changes[0].arn : null
  }
}

output "cross_account_event_bus_arn" {
  description = "ARN of the cross-account event bus (if enabled)"
  value       = var.enable_cross_account_events ? aws_cloudwatch_event_bus.cross_account[0].arn : null
}

output "cross_account_event_bus_name" {
  description = "Name of the cross-account event bus (if enabled)"
  value       = var.enable_cross_account_events ? aws_cloudwatch_event_bus.cross_account[0].name : null
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group Outputs
# -----------------------------------------------------------------------------

output "lambda_log_group_name" {
  description = "Name of the CloudWatch Log Group for Lambda function"
  value       = var.enable_lambda_processor ? aws_cloudwatch_log_group.lambda_processor[0].name : null
}

output "lambda_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for Lambda function"
  value       = var.enable_lambda_processor ? aws_cloudwatch_log_group.lambda_processor[0].arn : null
}

# -----------------------------------------------------------------------------
# Integration Outputs
# -----------------------------------------------------------------------------

output "integration_config" {
  description = "Configuration details for integrating with this alerting module"
  value = {
    topics = {
      critical = {
        arn         = aws_sns_topic.critical.arn
        name        = aws_sns_topic.critical.name
        description = "P1 incidents - pages on-call"
      }
      warning = {
        arn         = aws_sns_topic.warning.arn
        name        = aws_sns_topic.warning.name
        description = "P2/P3 issues - creates tickets"
      }
      info = {
        arn         = aws_sns_topic.info.arn
        name        = aws_sns_topic.info.name
        description = "Informational - dashboard and logs"
      }
      security = {
        arn         = aws_sns_topic.security.arn
        name        = aws_sns_topic.security.name
        description = "Security alerts - SOC review"
      }
      cost = {
        arn         = aws_sns_topic.cost.arn
        name        = aws_sns_topic.cost.name
        description = "Budget and cost anomalies"
      }
    }
    kms_key_arn = local.kms_key_arn
    environment = var.environment
    project     = var.project_name
  }
}

# -----------------------------------------------------------------------------
# Module Summary
# -----------------------------------------------------------------------------

output "module_summary" {
  description = "Summary of all resources created by this module"
  value = {
    sns_topics_count          = 5
    email_subscriptions_count = length(local.email_subscription_arns)
    sms_subscriptions_count   = length(local.sms_subscription_arns)
    https_subscriptions_count = length(local.https_subscription_arns)
    lambda_enabled            = var.enable_lambda_processor
    sqs_queues_enabled        = var.enable_sqs_subscriptions
    aggregate_queue_enabled   = var.enable_aggregate_queue
    cross_account_enabled     = var.enable_cross_account_events
    kms_key_created           = var.kms_key_arn == null
    eventbridge_rules_count   = 10 + (var.enable_security_hub_rules ? 1 : 0) + (var.enable_cost_anomaly_rules ? 1 : 0) + (var.enable_iam_monitoring ? 1 : 0)
  }
}
