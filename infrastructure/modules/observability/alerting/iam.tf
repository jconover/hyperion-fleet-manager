# =============================================================================
# IAM Configuration for Alerting Module
# =============================================================================
# This file defines IAM roles and policies for:
# - Lambda alert processor execution
# - SNS publish permissions
# - CloudWatch Logs permissions
# - EC2 describe permissions for alert enrichment
# - SQS permissions for dead letter queues
# =============================================================================

# -----------------------------------------------------------------------------
# Lambda Execution Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "lambda_processor" {
  name = "${local.name_prefix}-alert-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-alert-processor-role"
      Purpose = "Lambda execution role for alert processing"
    }
  )
}

# -----------------------------------------------------------------------------
# Lambda Basic Execution Policy
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_basic_execution" {
  name        = "${local.name_prefix}-alert-processor-basic"
  description = "Basic execution permissions for alert processor Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.name_prefix}-alert-processor",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.name_prefix}-alert-processor:*"
        ]
      },
      {
        Sid    = "XRayTracing"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alert-processor-basic"
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_processor.name
  policy_arn = aws_iam_policy.lambda_basic_execution.arn
}

# -----------------------------------------------------------------------------
# SNS Publish Policy
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_sns_publish" {
  name        = "${local.name_prefix}-alert-processor-sns"
  description = "SNS publish permissions for alert processor Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:GetTopicAttributes"
        ]
        Resource = [
          aws_sns_topic.critical.arn,
          aws_sns_topic.warning.arn,
          aws_sns_topic.info.arn,
          aws_sns_topic.security.arn,
          aws_sns_topic.cost.arn
        ]
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alert-processor-sns"
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda_sns_publish" {
  role       = aws_iam_role.lambda_processor.name
  policy_arn = aws_iam_policy.lambda_sns_publish.arn
}

# -----------------------------------------------------------------------------
# EC2 Describe Policy (for alert enrichment)
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_ec2_describe" {
  name        = "${local.name_prefix}-alert-processor-ec2"
  description = "EC2 describe permissions for alert enrichment"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Describe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeInstanceStatus"
        ]
        Resource = "*"
      },
      {
        Sid    = "AutoScalingDescribe"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alert-processor-ec2"
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda_ec2_describe" {
  role       = aws_iam_role.lambda_processor.name
  policy_arn = aws_iam_policy.lambda_ec2_describe.arn
}

# -----------------------------------------------------------------------------
# SQS Policy (for dead letter queue)
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_sqs" {
  count = var.enable_lambda_processor ? 1 : 0

  name        = "${local.name_prefix}-alert-processor-sqs"
  description = "SQS permissions for Lambda dead letter queue"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SQSSendMessage"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.lambda_dlq[0].arn
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alert-processor-sqs"
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  count = var.enable_lambda_processor ? 1 : 0

  role       = aws_iam_role.lambda_processor.name
  policy_arn = aws_iam_policy.lambda_sqs[0].arn
}

# -----------------------------------------------------------------------------
# KMS Decrypt Policy (for encrypted resources)
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_kms" {
  name        = "${local.name_prefix}-alert-processor-kms"
  description = "KMS permissions for alert processor Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = local.kms_key_arn
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alert-processor-kms"
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda_kms" {
  role       = aws_iam_role.lambda_processor.name
  policy_arn = aws_iam_policy.lambda_kms.arn
}

# -----------------------------------------------------------------------------
# VPC Access Policy (optional - for VPC-deployed Lambda)
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_vpc" {
  count = var.lambda_vpc_config != null ? 1 : 0

  name        = "${local.name_prefix}-alert-processor-vpc"
  description = "VPC access permissions for alert processor Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VPCNetworkInterfaces"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alert-processor-vpc"
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count = var.lambda_vpc_config != null ? 1 : 0

  role       = aws_iam_role.lambda_processor.name
  policy_arn = aws_iam_policy.lambda_vpc[0].arn
}

# -----------------------------------------------------------------------------
# Secrets Manager Access Policy (optional - for external integrations)
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_secrets" {
  count = var.slack_webhook_url != null || var.pagerduty_integration_key != null ? 1 : 0

  name        = "${local.name_prefix}-alert-processor-secrets"
  description = "Secrets Manager access for alert processor Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${local.name_prefix}-alerting-*"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alert-processor-secrets"
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda_secrets" {
  count = var.slack_webhook_url != null || var.pagerduty_integration_key != null ? 1 : 0

  role       = aws_iam_role.lambda_processor.name
  policy_arn = aws_iam_policy.lambda_secrets[0].arn
}

# -----------------------------------------------------------------------------
# CloudWatch Metrics Policy (for custom metrics)
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "lambda_cloudwatch_metrics" {
  name        = "${local.name_prefix}-alert-processor-metrics"
  description = "CloudWatch metrics permissions for alert processor Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "Hyperion/Alerting"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alert-processor-metrics"
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_metrics" {
  role       = aws_iam_role.lambda_processor.name
  policy_arn = aws_iam_policy.lambda_cloudwatch_metrics.arn
}

# -----------------------------------------------------------------------------
# EventBridge Permissions for SNS Topics
# -----------------------------------------------------------------------------

# IAM policy for EventBridge to publish to SNS
resource "aws_iam_policy" "eventbridge_sns" {
  name        = "${local.name_prefix}-eventbridge-sns"
  description = "EventBridge permissions to publish to SNS topics"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = "sns:Publish"
        Resource = [
          aws_sns_topic.critical.arn,
          aws_sns_topic.warning.arn,
          aws_sns_topic.info.arn,
          aws_sns_topic.security.arn,
          aws_sns_topic.cost.arn
        ]
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-eventbridge-sns"
    }
  )
}

# -----------------------------------------------------------------------------
# Service-Linked Role References (informational)
# -----------------------------------------------------------------------------
# Note: The following service-linked roles are automatically created by AWS
# and do not need to be managed by Terraform:
# - AWSServiceRoleForAmazonGuardDuty
# - AWSServiceRoleForSecurityHub
# - AWSServiceRoleForConfig
# - AWSServiceRoleForCloudWatch

# -----------------------------------------------------------------------------
# Cross-Account Event Bus Policy (if enabled)
# -----------------------------------------------------------------------------

resource "aws_iam_policy" "cross_account_events" {
  count = var.enable_cross_account_events ? 1 : 0

  name        = "${local.name_prefix}-cross-account-events"
  description = "Permissions for cross-account event handling"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PutEventsToCustomBus"
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = aws_cloudwatch_event_bus.cross_account[0].arn
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-cross-account-events"
    }
  )
}

# -----------------------------------------------------------------------------
# IAM Role Outputs (for reference by other modules)
# -----------------------------------------------------------------------------

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_processor.arn
}

output "lambda_execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_processor.name
}

output "eventbridge_sns_policy_arn" {
  description = "ARN of the EventBridge to SNS policy"
  value       = aws_iam_policy.eventbridge_sns.arn
}
