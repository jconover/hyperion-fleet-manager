# -----------------------------------------------------------------------------
# SNS Topics and Subscriptions for CloudWatch Alarms
# -----------------------------------------------------------------------------
# This file manages SNS topics for alarm notifications at different severity
# levels and configures subscriptions for email, SMS, and Lambda processing.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# SNS Topics
# -----------------------------------------------------------------------------

# Critical Alerts Topic - Pages on-call engineers
resource "aws_sns_topic" "critical" {
  name         = "${var.project_name}-${var.environment}-alerts-critical"
  display_name = "${var.project_name} Critical Alerts (${var.environment})"

  # Enable encryption at rest using AWS managed key
  kms_master_key_id = var.sns_kms_key_id != "" ? var.sns_kms_key_id : "alias/aws/sns"

  tags = merge(
    local.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-alerts-critical"
      Severity = "critical"
      Purpose  = "pages-oncall"
    }
  )
}

# Warning Alerts Topic - Creates tickets/notifications
resource "aws_sns_topic" "warning" {
  name         = "${var.project_name}-${var.environment}-alerts-warning"
  display_name = "${var.project_name} Warning Alerts (${var.environment})"

  kms_master_key_id = var.sns_kms_key_id != "" ? var.sns_kms_key_id : "alias/aws/sns"

  tags = merge(
    local.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-alerts-warning"
      Severity = "warning"
      Purpose  = "create-tickets"
    }
  )
}

# Info Alerts Topic - Dashboard and logging only
resource "aws_sns_topic" "info" {
  name         = "${var.project_name}-${var.environment}-alerts-info"
  display_name = "${var.project_name} Info Alerts (${var.environment})"

  kms_master_key_id = var.sns_kms_key_id != "" ? var.sns_kms_key_id : "alias/aws/sns"

  tags = merge(
    local.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-alerts-info"
      Severity = "info"
      Purpose  = "dashboard-logging"
    }
  )
}

# -----------------------------------------------------------------------------
# SNS Topic Policies
# -----------------------------------------------------------------------------

# Policy allowing CloudWatch to publish to critical topic
resource "aws_sns_topic_policy" "critical" {
  arn = aws_sns_topic.critical.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.project_name}-${var.environment}-critical-policy"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.critical.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudwatch:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:alarm:*"
          }
        }
      },
      {
        Sid    = "AllowAccountAdminAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:AddPermission",
          "sns:RemovePermission",
          "sns:DeleteTopic",
          "sns:Subscribe",
          "sns:ListSubscriptionsByTopic",
          "sns:Publish"
        ]
        Resource = aws_sns_topic.critical.arn
      }
    ]
  })
}

# Policy allowing CloudWatch to publish to warning topic
resource "aws_sns_topic_policy" "warning" {
  arn = aws_sns_topic.warning.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.project_name}-${var.environment}-warning-policy"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.warning.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudwatch:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:alarm:*"
          }
        }
      },
      {
        Sid    = "AllowAccountAdminAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:AddPermission",
          "sns:RemovePermission",
          "sns:DeleteTopic",
          "sns:Subscribe",
          "sns:ListSubscriptionsByTopic",
          "sns:Publish"
        ]
        Resource = aws_sns_topic.warning.arn
      }
    ]
  })
}

# Policy allowing CloudWatch to publish to info topic
resource "aws_sns_topic_policy" "info" {
  arn = aws_sns_topic.info.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.project_name}-${var.environment}-info-policy"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.info.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudwatch:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:alarm:*"
          }
        }
      },
      {
        Sid    = "AllowAccountAdminAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:AddPermission",
          "sns:RemovePermission",
          "sns:DeleteTopic",
          "sns:Subscribe",
          "sns:ListSubscriptionsByTopic",
          "sns:Publish"
        ]
        Resource = aws_sns_topic.info.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Email Subscriptions
# -----------------------------------------------------------------------------

# Critical email subscriptions
resource "aws_sns_topic_subscription" "critical_email" {
  for_each = toset(var.notification_emails_critical)

  topic_arn = aws_sns_topic.critical.arn
  protocol  = "email"
  endpoint  = each.value

  # Note: Email subscriptions require confirmation by the recipient
}

# Warning email subscriptions
resource "aws_sns_topic_subscription" "warning_email" {
  for_each = toset(var.notification_emails_warning)

  topic_arn = aws_sns_topic.warning.arn
  protocol  = "email"
  endpoint  = each.value
}

# Info email subscriptions (typically for operations dashboard)
resource "aws_sns_topic_subscription" "info_email" {
  for_each = toset(var.notification_emails_info)

  topic_arn = aws_sns_topic.info.arn
  protocol  = "email"
  endpoint  = each.value
}

# -----------------------------------------------------------------------------
# SMS Subscriptions (Optional - for critical alerts only)
# -----------------------------------------------------------------------------

# Critical SMS subscriptions for immediate paging
resource "aws_sns_topic_subscription" "critical_sms" {
  for_each = toset(var.notification_phone_numbers)

  topic_arn = aws_sns_topic.critical.arn
  protocol  = "sms"
  endpoint  = each.value
}

# -----------------------------------------------------------------------------
# Lambda Subscriptions for Custom Processing
# -----------------------------------------------------------------------------

# Lambda subscription for critical alerts (e.g., PagerDuty, Slack integration)
resource "aws_sns_topic_subscription" "critical_lambda" {
  count = var.lambda_function_arn_critical != "" ? 1 : 0

  topic_arn = aws_sns_topic.critical.arn
  protocol  = "lambda"
  endpoint  = var.lambda_function_arn_critical
}

# Lambda subscription for warning alerts (e.g., ticket creation)
resource "aws_sns_topic_subscription" "warning_lambda" {
  count = var.lambda_function_arn_warning != "" ? 1 : 0

  topic_arn = aws_sns_topic.warning.arn
  protocol  = "lambda"
  endpoint  = var.lambda_function_arn_warning
}

# Lambda subscription for info alerts (e.g., logging, metrics)
resource "aws_sns_topic_subscription" "info_lambda" {
  count = var.lambda_function_arn_info != "" ? 1 : 0

  topic_arn = aws_sns_topic.info.arn
  protocol  = "lambda"
  endpoint  = var.lambda_function_arn_info
}

# -----------------------------------------------------------------------------
# Lambda Permissions for SNS Invocation
# -----------------------------------------------------------------------------

# Permission for SNS to invoke critical Lambda
resource "aws_lambda_permission" "sns_critical" {
  count = var.lambda_function_arn_critical != "" ? 1 : 0

  statement_id  = "AllowSNSCriticalInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn_critical
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.critical.arn
}

# Permission for SNS to invoke warning Lambda
resource "aws_lambda_permission" "sns_warning" {
  count = var.lambda_function_arn_warning != "" ? 1 : 0

  statement_id  = "AllowSNSWarningInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn_warning
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.warning.arn
}

# Permission for SNS to invoke info Lambda
resource "aws_lambda_permission" "sns_info" {
  count = var.lambda_function_arn_info != "" ? 1 : 0

  statement_id  = "AllowSNSInfoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn_info
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.info.arn
}

# -----------------------------------------------------------------------------
# HTTPS Endpoint Subscriptions (for webhooks)
# -----------------------------------------------------------------------------

# HTTPS endpoint for critical alerts (e.g., PagerDuty, Opsgenie)
resource "aws_sns_topic_subscription" "critical_https" {
  for_each = toset(var.webhook_endpoints_critical)

  topic_arn                       = aws_sns_topic.critical.arn
  protocol                        = "https"
  endpoint                        = each.value
  endpoint_auto_confirms          = true
  confirmation_timeout_in_minutes = 5
}

# HTTPS endpoint for warning alerts (e.g., ServiceNow)
resource "aws_sns_topic_subscription" "warning_https" {
  for_each = toset(var.webhook_endpoints_warning)

  topic_arn                       = aws_sns_topic.warning.arn
  protocol                        = "https"
  endpoint                        = each.value
  endpoint_auto_confirms          = true
  confirmation_timeout_in_minutes = 5
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
