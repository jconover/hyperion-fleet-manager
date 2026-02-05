# =============================================================================
# SNS Subscriptions Configuration
# =============================================================================
# Configures various subscription types for SNS topics including:
# - Email subscriptions (with confirmation)
# - SMS subscriptions (for critical alerts)
# - HTTPS/Webhook subscriptions
# - Lambda subscriptions (for processing)
# - SQS subscriptions (for queuing)
# =============================================================================

# -----------------------------------------------------------------------------
# Email Subscriptions
# -----------------------------------------------------------------------------

# Critical alerts email subscriptions
resource "aws_sns_topic_subscription" "critical_email" {
  for_each = toset(lookup(var.email_endpoints, "critical", []))

  topic_arn = aws_sns_topic.critical.arn
  protocol  = "email"
  endpoint  = each.value

  # Note: Email subscriptions require manual confirmation
  # No filter policy needed for critical - all messages are delivered
}

# Warning alerts email subscriptions
resource "aws_sns_topic_subscription" "warning_email" {
  for_each = toset(lookup(var.email_endpoints, "warning", []))

  topic_arn = aws_sns_topic.warning.arn
  protocol  = "email"
  endpoint  = each.value
}

# Info alerts email subscriptions
resource "aws_sns_topic_subscription" "info_email" {
  for_each = toset(lookup(var.email_endpoints, "info", []))

  topic_arn = aws_sns_topic.info.arn
  protocol  = "email"
  endpoint  = each.value
}

# Security alerts email subscriptions
resource "aws_sns_topic_subscription" "security_email" {
  for_each = toset(lookup(var.email_endpoints, "security", []))

  topic_arn = aws_sns_topic.security.arn
  protocol  = "email"
  endpoint  = each.value
}

# Cost alerts email subscriptions
resource "aws_sns_topic_subscription" "cost_email" {
  for_each = toset(lookup(var.email_endpoints, "cost", []))

  topic_arn = aws_sns_topic.cost.arn
  protocol  = "email"
  endpoint  = each.value
}

# -----------------------------------------------------------------------------
# SMS Subscriptions (Critical Alerts Only)
# -----------------------------------------------------------------------------
# SMS is reserved for critical P1 incidents that require immediate attention
# GDPR Note: Ensure phone numbers are collected with proper consent

resource "aws_sns_topic_subscription" "critical_sms" {
  for_each = toset(var.sms_endpoints)

  topic_arn = aws_sns_topic.critical.arn
  protocol  = "sms"
  endpoint  = each.value
}

# Optional: Security SMS for high-severity security incidents
resource "aws_sns_topic_subscription" "security_sms" {
  for_each = var.enable_security_sms ? toset(var.sms_endpoints) : []

  topic_arn = aws_sns_topic.security.arn
  protocol  = "sms"
  endpoint  = each.value
  filter_policy = jsonencode({
    severity = ["CRITICAL", "HIGH"]
  })
}

# -----------------------------------------------------------------------------
# HTTPS/Webhook Subscriptions
# -----------------------------------------------------------------------------

# Critical webhook subscriptions (e.g., PagerDuty)
resource "aws_sns_topic_subscription" "critical_https" {
  for_each = lookup(var.webhook_endpoints, "critical", {})

  topic_arn                       = aws_sns_topic.critical.arn
  protocol                        = "https"
  endpoint                        = each.value
  endpoint_auto_confirms          = var.webhook_auto_confirm
  confirmation_timeout_in_minutes = var.webhook_confirmation_timeout
  raw_message_delivery            = var.webhook_raw_message_delivery
}

# Warning webhook subscriptions (e.g., Jira, ServiceNow)
resource "aws_sns_topic_subscription" "warning_https" {
  for_each = lookup(var.webhook_endpoints, "warning", {})

  topic_arn                       = aws_sns_topic.warning.arn
  protocol                        = "https"
  endpoint                        = each.value
  endpoint_auto_confirms          = var.webhook_auto_confirm
  confirmation_timeout_in_minutes = var.webhook_confirmation_timeout
  raw_message_delivery            = var.webhook_raw_message_delivery
}

# Info webhook subscriptions (e.g., Slack, Teams)
resource "aws_sns_topic_subscription" "info_https" {
  for_each = lookup(var.webhook_endpoints, "info", {})

  topic_arn                       = aws_sns_topic.info.arn
  protocol                        = "https"
  endpoint                        = each.value
  endpoint_auto_confirms          = var.webhook_auto_confirm
  confirmation_timeout_in_minutes = var.webhook_confirmation_timeout
  raw_message_delivery            = var.webhook_raw_message_delivery
}

# Security webhook subscriptions (e.g., SIEM, SOC tools)
resource "aws_sns_topic_subscription" "security_https" {
  for_each = lookup(var.webhook_endpoints, "security", {})

  topic_arn                       = aws_sns_topic.security.arn
  protocol                        = "https"
  endpoint                        = each.value
  endpoint_auto_confirms          = var.webhook_auto_confirm
  confirmation_timeout_in_minutes = var.webhook_confirmation_timeout
  raw_message_delivery            = var.webhook_raw_message_delivery
}

# Cost webhook subscriptions (e.g., FinOps tools)
resource "aws_sns_topic_subscription" "cost_https" {
  for_each = lookup(var.webhook_endpoints, "cost", {})

  topic_arn                       = aws_sns_topic.cost.arn
  protocol                        = "https"
  endpoint                        = each.value
  endpoint_auto_confirms          = var.webhook_auto_confirm
  confirmation_timeout_in_minutes = var.webhook_confirmation_timeout
  raw_message_delivery            = var.webhook_raw_message_delivery
}

# -----------------------------------------------------------------------------
# Lambda Processor Subscriptions
# -----------------------------------------------------------------------------
# Lambda processes alerts for enrichment and routing to external systems

resource "aws_sns_topic_subscription" "critical_lambda" {
  count = var.enable_lambda_processor ? 1 : 0

  topic_arn = aws_sns_topic.critical.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alert_processor[0].arn
}

resource "aws_sns_topic_subscription" "warning_lambda" {
  count = var.enable_lambda_processor ? 1 : 0

  topic_arn = aws_sns_topic.warning.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alert_processor[0].arn
}

resource "aws_sns_topic_subscription" "info_lambda" {
  count = var.enable_lambda_processor ? 1 : 0

  topic_arn = aws_sns_topic.info.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alert_processor[0].arn
}

resource "aws_sns_topic_subscription" "security_lambda" {
  count = var.enable_lambda_processor ? 1 : 0

  topic_arn = aws_sns_topic.security.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alert_processor[0].arn
}

resource "aws_sns_topic_subscription" "cost_lambda" {
  count = var.enable_lambda_processor ? 1 : 0

  topic_arn = aws_sns_topic.cost.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alert_processor[0].arn
}

# Lambda permissions to be invoked by SNS
resource "aws_lambda_permission" "critical_sns" {
  count = var.enable_lambda_processor ? 1 : 0

  statement_id  = "AllowExecutionFromSNSCritical"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_processor[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.critical.arn
}

resource "aws_lambda_permission" "warning_sns" {
  count = var.enable_lambda_processor ? 1 : 0

  statement_id  = "AllowExecutionFromSNSWarning"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_processor[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.warning.arn
}

resource "aws_lambda_permission" "info_sns" {
  count = var.enable_lambda_processor ? 1 : 0

  statement_id  = "AllowExecutionFromSNSInfo"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_processor[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.info.arn
}

resource "aws_lambda_permission" "security_sns" {
  count = var.enable_lambda_processor ? 1 : 0

  statement_id  = "AllowExecutionFromSNSSecurity"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_processor[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.security.arn
}

resource "aws_lambda_permission" "cost_sns" {
  count = var.enable_lambda_processor ? 1 : 0

  statement_id  = "AllowExecutionFromSNSCost"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_processor[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.cost.arn
}

# -----------------------------------------------------------------------------
# SQS Subscriptions (for alert queuing and batch processing)
# -----------------------------------------------------------------------------

# SQS Queue for Critical Alerts (backup queue for reliability)
resource "aws_sqs_queue" "critical_alerts" {
  count = var.enable_sqs_subscriptions ? 1 : 0

  name                       = "${local.name_prefix}-critical-alerts-queue"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 1209600 # 14 days
  receive_wait_time_seconds  = 20
  visibility_timeout_seconds = 300
  kms_master_key_id          = local.kms_key_arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.critical_alerts_dlq[0].arn
    maxReceiveCount     = 3
  })

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-critical-alerts-queue"
      Severity = "critical"
    }
  )
}

# Dead Letter Queue for Critical Alerts
resource "aws_sqs_queue" "critical_alerts_dlq" {
  count = var.enable_sqs_subscriptions ? 1 : 0

  name                      = "${local.name_prefix}-critical-alerts-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = local.kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-critical-alerts-dlq"
      Severity = "critical"
      Type     = "dead-letter-queue"
    }
  )
}

# SQS Queue Policy for Critical Alerts
resource "aws_sqs_queue_policy" "critical_alerts" {
  count = var.enable_sqs_subscriptions ? 1 : 0

  queue_url = aws_sqs_queue.critical_alerts[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.critical_alerts[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.critical.arn
          }
        }
      }
    ]
  })
}

# SNS to SQS Subscription for Critical Alerts
resource "aws_sns_topic_subscription" "critical_sqs" {
  count = var.enable_sqs_subscriptions ? 1 : 0

  topic_arn            = aws_sns_topic.critical.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.critical_alerts[0].arn
  raw_message_delivery = true
}

# SQS Queue for Security Alerts
resource "aws_sqs_queue" "security_alerts" {
  count = var.enable_sqs_subscriptions ? 1 : 0

  name                       = "${local.name_prefix}-security-alerts-queue"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 1209600 # 14 days
  receive_wait_time_seconds  = 20
  visibility_timeout_seconds = 300
  kms_master_key_id          = local.kms_key_arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.security_alerts_dlq[0].arn
    maxReceiveCount     = 3
  })

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-security-alerts-queue"
      Severity = "security"
    }
  )
}

# Dead Letter Queue for Security Alerts
resource "aws_sqs_queue" "security_alerts_dlq" {
  count = var.enable_sqs_subscriptions ? 1 : 0

  name                      = "${local.name_prefix}-security-alerts-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = local.kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-security-alerts-dlq"
      Severity = "security"
      Type     = "dead-letter-queue"
    }
  )
}

# SQS Queue Policy for Security Alerts
resource "aws_sqs_queue_policy" "security_alerts" {
  count = var.enable_sqs_subscriptions ? 1 : 0

  queue_url = aws_sqs_queue.security_alerts[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.security_alerts[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.security.arn
          }
        }
      }
    ]
  })
}

# SNS to SQS Subscription for Security Alerts
resource "aws_sns_topic_subscription" "security_sqs" {
  count = var.enable_sqs_subscriptions ? 1 : 0

  topic_arn            = aws_sns_topic.security.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.security_alerts[0].arn
  raw_message_delivery = true
}

# -----------------------------------------------------------------------------
# Aggregate Queue for All Alerts (optional - for centralized processing)
# -----------------------------------------------------------------------------

resource "aws_sqs_queue" "all_alerts" {
  count = var.enable_aggregate_queue ? 1 : 0

  name                       = "${local.name_prefix}-all-alerts-queue"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 604800 # 7 days
  receive_wait_time_seconds  = 20
  visibility_timeout_seconds = 300
  kms_master_key_id          = local.kms_key_arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.all_alerts_dlq[0].arn
    maxReceiveCount     = 5
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-all-alerts-queue"
      Type = "aggregate"
    }
  )
}

resource "aws_sqs_queue" "all_alerts_dlq" {
  count = var.enable_aggregate_queue ? 1 : 0

  name                      = "${local.name_prefix}-all-alerts-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = local.kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-all-alerts-dlq"
      Type = "dead-letter-queue"
    }
  )
}

resource "aws_sqs_queue_policy" "all_alerts" {
  count = var.enable_aggregate_queue ? 1 : 0

  queue_url = aws_sqs_queue.all_alerts[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.all_alerts[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = [
              aws_sns_topic.critical.arn,
              aws_sns_topic.warning.arn,
              aws_sns_topic.info.arn,
              aws_sns_topic.security.arn,
              aws_sns_topic.cost.arn
            ]
          }
        }
      }
    ]
  })
}

# Subscriptions for aggregate queue
resource "aws_sns_topic_subscription" "aggregate_critical" {
  count = var.enable_aggregate_queue ? 1 : 0

  topic_arn            = aws_sns_topic.critical.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.all_alerts[0].arn
  raw_message_delivery = true

  filter_policy = jsonencode({
    severity = ["critical"]
  })
}

resource "aws_sns_topic_subscription" "aggregate_warning" {
  count = var.enable_aggregate_queue ? 1 : 0

  topic_arn            = aws_sns_topic.warning.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.all_alerts[0].arn
  raw_message_delivery = true
}

resource "aws_sns_topic_subscription" "aggregate_security" {
  count = var.enable_aggregate_queue ? 1 : 0

  topic_arn            = aws_sns_topic.security.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.all_alerts[0].arn
  raw_message_delivery = true
}

# -----------------------------------------------------------------------------
# Local values for subscription tracking
# -----------------------------------------------------------------------------

locals {
  # Collect all subscription ARNs for output
  email_subscription_arns = merge(
    { for k, v in aws_sns_topic_subscription.critical_email : "critical_email_${k}" => v.arn },
    { for k, v in aws_sns_topic_subscription.warning_email : "warning_email_${k}" => v.arn },
    { for k, v in aws_sns_topic_subscription.info_email : "info_email_${k}" => v.arn },
    { for k, v in aws_sns_topic_subscription.security_email : "security_email_${k}" => v.arn },
    { for k, v in aws_sns_topic_subscription.cost_email : "cost_email_${k}" => v.arn }
  )

  sms_subscription_arns = merge(
    { for k, v in aws_sns_topic_subscription.critical_sms : "critical_sms_${k}" => v.arn },
    { for k, v in aws_sns_topic_subscription.security_sms : "security_sms_${k}" => v.arn }
  )

  https_subscription_arns = merge(
    { for k, v in aws_sns_topic_subscription.critical_https : "critical_https_${k}" => v.arn },
    { for k, v in aws_sns_topic_subscription.warning_https : "warning_https_${k}" => v.arn },
    { for k, v in aws_sns_topic_subscription.info_https : "info_https_${k}" => v.arn },
    { for k, v in aws_sns_topic_subscription.security_https : "security_https_${k}" => v.arn },
    { for k, v in aws_sns_topic_subscription.cost_https : "cost_https_${k}" => v.arn }
  )

  sqs_queue_arns = var.enable_sqs_subscriptions ? {
    critical_queue = aws_sqs_queue.critical_alerts[0].arn
    critical_dlq   = aws_sqs_queue.critical_alerts_dlq[0].arn
    security_queue = aws_sqs_queue.security_alerts[0].arn
    security_dlq   = aws_sqs_queue.security_alerts_dlq[0].arn
  } : {}

  aggregate_queue_arns = var.enable_aggregate_queue ? {
    all_alerts_queue = aws_sqs_queue.all_alerts[0].arn
    all_alerts_dlq   = aws_sqs_queue.all_alerts_dlq[0].arn
  } : {}
}
