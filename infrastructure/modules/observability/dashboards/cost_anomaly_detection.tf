# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - AWS Cost Anomaly Detection
# -----------------------------------------------------------------------------
# This file creates AWS Cost Anomaly Detection resources for proactive
# monitoring of unusual spending patterns. Cost Anomaly Detection uses
# machine learning to identify anomalies in your AWS spending.
#
# IMPORTANT: Cost Anomaly Detection is a separate AWS service from CloudWatch.
# It monitors Cost Explorer data and can detect anomalies at the service,
# account, or cost category level.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# SNS Topic for Cost Anomaly Alerts
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "cost_alerts" {
  count = var.cost_enable_cost_anomaly_detection && var.cost_sns_topic_arn == null ? 1 : 0

  name              = "${var.cost_environment}-${var.cost_project_name}-cost-anomaly-alerts"
  display_name      = "Hyperion Fleet Manager Cost Anomaly Alerts"
  kms_master_key_id = var.cost_kms_key_arn

  tags = merge(
    var.cost_tags,
    {
      Name        = "${var.cost_environment}-${var.cost_project_name}-cost-anomaly-alerts"
      Environment = var.cost_environment
      Project     = var.cost_project_name
      ManagedBy   = "terraform"
      Purpose     = "cost-anomaly-alerts"
    }
  )
}

# -----------------------------------------------------------------------------
# SNS Topic Policy for Cost Anomaly Detection
# -----------------------------------------------------------------------------

resource "aws_sns_topic_policy" "cost_alerts" {
  count = var.cost_enable_cost_anomaly_detection && var.cost_sns_topic_arn == null ? 1 : 0

  arn = aws_sns_topic.cost_alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "CostAnomalyDetectionSNSPolicy"
    Statement = [
      {
        Sid    = "AllowCostAnomalyDetectionToPublish"
        Effect = "Allow"
        Principal = {
          Service = "costalerts.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cost_alerts[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowCloudWatchToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cost_alerts[0].arn
      },
      {
        Sid    = "AllowAccountOwner"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.cost_alerts[0].arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# SNS Email Subscriptions for Cost Alerts
# -----------------------------------------------------------------------------

resource "aws_sns_topic_subscription" "cost_alert_emails" {
  for_each = var.cost_enable_cost_anomaly_detection && var.cost_sns_topic_arn == null ? toset(var.cost_alert_email_addresses) : []

  topic_arn = aws_sns_topic.cost_alerts[0].arn
  protocol  = "email"
  endpoint  = each.value
}

# -----------------------------------------------------------------------------
# AWS Cost Anomaly Detection Monitor
# -----------------------------------------------------------------------------

resource "aws_ce_anomaly_monitor" "cost_monitor" {
  count = var.cost_enable_cost_anomaly_detection ? 1 : 0

  name              = "${var.cost_environment}-${var.cost_project_name}-cost-anomaly-monitor"
  monitor_type      = var.cost_anomaly_monitor_type
  monitor_dimension = var.cost_anomaly_monitor_type == "DIMENSIONAL" ? var.cost_anomaly_monitor_dimension : null

  # Custom monitor specification (only used when monitor_type is CUSTOM)
  dynamic "monitor_specification" {
    for_each = var.cost_anomaly_monitor_type == "CUSTOM" ? [1] : []
    content {
      # Filter by cost allocation tags for environment-specific monitoring
      and {
        tags {
          key           = "Environment"
          values        = [var.cost_environment]
          match_options = ["EQUALS"]
        }
      }
    }
  }

  tags = merge(
    var.cost_tags,
    {
      Name        = "${var.cost_environment}-${var.cost_project_name}-cost-anomaly-monitor"
      Environment = var.cost_environment
      Project     = var.cost_project_name
      ManagedBy   = "terraform"
      Purpose     = "cost-anomaly-detection"
    }
  )
}

# -----------------------------------------------------------------------------
# AWS Cost Anomaly Detection Subscription
# -----------------------------------------------------------------------------

resource "aws_ce_anomaly_subscription" "cost_subscription" {
  count = var.cost_enable_cost_anomaly_detection ? 1 : 0

  name      = "${var.cost_environment}-${var.cost_project_name}-cost-anomaly-subscription"
  frequency = "DAILY"

  monitor_arn_list = [
    aws_ce_anomaly_monitor.cost_monitor[0].arn
  ]

  subscriber {
    type    = "SNS"
    address = var.cost_sns_topic_arn != null ? var.cost_sns_topic_arn : aws_sns_topic.cost_alerts[0].arn
  }

  # Threshold expression - only alert when anomaly exceeds these thresholds
  # Using AND logic: both absolute and percentage thresholds must be met
  threshold_expression {
    and {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = [tostring(var.cost_anomaly_threshold_expression)]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
    and {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_PERCENTAGE"
        values        = [tostring(var.cost_anomaly_threshold_percentage)]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
  }

  tags = merge(
    var.cost_tags,
    {
      Name        = "${var.cost_environment}-${var.cost_project_name}-cost-anomaly-subscription"
      Environment = var.cost_environment
      Project     = var.cost_project_name
      ManagedBy   = "terraform"
      Purpose     = "cost-anomaly-subscription"
    }
  )
}

# -----------------------------------------------------------------------------
# Service-Specific Anomaly Monitors (Optional)
# -----------------------------------------------------------------------------

resource "aws_ce_anomaly_monitor" "service_monitors" {
  for_each = var.cost_enable_service_anomaly_monitors ? toset(var.cost_services_for_anomaly_detection) : []

  name         = "${var.cost_environment}-${var.cost_project_name}-${lower(replace(each.value, "Amazon", ""))}-anomaly-monitor"
  monitor_type = "CUSTOM"

  monitor_specification = jsonencode({
    And = [
      {
        Dimensions = {
          Key          = "SERVICE"
          Values       = [each.value]
          MatchOptions = ["EQUALS"]
        }
      }
    ]
  })

  tags = merge(
    var.cost_tags,
    {
      Name        = "${var.cost_environment}-${var.cost_project_name}-${lower(replace(each.value, "Amazon", ""))}-anomaly-monitor"
      Environment = var.cost_environment
      Project     = var.cost_project_name
      ManagedBy   = "terraform"
      Purpose     = "service-cost-anomaly-detection"
      Service     = each.value
    }
  )
}

# -----------------------------------------------------------------------------
# Linked Account Anomaly Monitor (for multi-account setups)
# -----------------------------------------------------------------------------

resource "aws_ce_anomaly_monitor" "linked_account_monitor" {
  count = var.cost_enable_cost_anomaly_detection && var.cost_enable_linked_account_widgets && length(var.cost_linked_accounts) > 0 ? 1 : 0

  name              = "${var.cost_environment}-${var.cost_project_name}-linked-accounts-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "LINKED_ACCOUNT"

  tags = merge(
    var.cost_tags,
    {
      Name        = "${var.cost_environment}-${var.cost_project_name}-linked-accounts-anomaly-monitor"
      Environment = var.cost_environment
      Project     = var.cost_project_name
      ManagedBy   = "terraform"
      Purpose     = "linked-account-anomaly-detection"
    }
  )
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
