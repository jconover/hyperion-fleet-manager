# =============================================================================
# Hyperion Fleet Manager - SNS Alerting Infrastructure
# =============================================================================
# This module provides comprehensive alerting infrastructure using SNS topics
# organized by severity and purpose, with KMS encryption and delivery policies.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Standard resource naming
  name_prefix = "${var.project_name}-${var.environment}"

  # Topic configuration map
  topics = {
    critical = {
      name         = "${local.name_prefix}-critical-alerts"
      display_name = "Hyperion Critical Alerts (P1)"
      description  = "P1 incidents requiring immediate on-call response"
      severity     = "critical"
    }
    warning = {
      name         = "${local.name_prefix}-warning-alerts"
      display_name = "Hyperion Warning Alerts (P2/P3)"
      description  = "P2/P3 issues that create tickets for investigation"
      severity     = "warning"
    }
    info = {
      name         = "${local.name_prefix}-info-alerts"
      display_name = "Hyperion Info Alerts"
      description  = "Informational notifications for dashboards and logs"
      severity     = "info"
    }
    security = {
      name         = "${local.name_prefix}-security-alerts"
      display_name = "Hyperion Security Alerts"
      description  = "Security-specific alerts requiring SOC review"
      severity     = "security"
    }
    cost = {
      name         = "${local.name_prefix}-cost-alerts"
      display_name = "Hyperion Cost Alerts"
      description  = "Budget and cost anomaly notifications"
      severity     = "cost"
    }
  }

  # Common tags for all resources
  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "observability/alerting"
    }
  )
}

# -----------------------------------------------------------------------------
# KMS Key for SNS Encryption (if not provided)
# -----------------------------------------------------------------------------

resource "aws_kms_key" "sns" {
  count = var.kms_key_arn == null ? 1 : 0

  description             = "KMS key for Hyperion Fleet Manager SNS topic encryption"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsEncryption"
        Effect = "Allow"
        Principal = {
          Service = "logs.${local.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${local.region}:${local.account_id}:*"
          }
        }
      },
      {
        Sid    = "AllowSNSEncryption"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchAlarmsEncryption"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEventBridgeEncryption"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowBudgetsEncryption"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-sns-kms-key"
    }
  )
}

resource "aws_kms_alias" "sns" {
  count = var.kms_key_arn == null ? 1 : 0

  name          = "alias/${local.name_prefix}-sns"
  target_key_id = aws_kms_key.sns[0].key_id
}

locals {
  kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.sns[0].arn
}

# -----------------------------------------------------------------------------
# SNS Topics
# -----------------------------------------------------------------------------

# Critical Alerts Topic (P1 - Pages On-Call)
resource "aws_sns_topic" "critical" {
  name              = local.topics.critical.name
  display_name      = local.topics.critical.display_name
  kms_master_key_id = local.kms_key_arn

  # Delivery policy for reliable message delivery
  delivery_policy = jsonencode({
    http = {
      defaultHealthyRetryPolicy = {
        minDelayTarget     = 1
        maxDelayTarget     = 60
        numRetries         = 50
        numMaxDelayRetries = 20
        numNoDelayRetries  = 3
        numMinDelayRetries = 3
        backoffFunction    = "exponential"
      }
      disableSubscriptionOverrides = false
      defaultThrottlePolicy = {
        maxReceivesPerSecond = 10
      }
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name     = local.topics.critical.name
      Severity = local.topics.critical.severity
      Purpose  = "P1 incidents - pages on-call"
    }
  )
}

# Warning Alerts Topic (P2/P3 - Creates Tickets)
resource "aws_sns_topic" "warning" {
  name              = local.topics.warning.name
  display_name      = local.topics.warning.display_name
  kms_master_key_id = local.kms_key_arn

  delivery_policy = jsonencode({
    http = {
      defaultHealthyRetryPolicy = {
        minDelayTarget     = 5
        maxDelayTarget     = 120
        numRetries         = 25
        numMaxDelayRetries = 10
        numNoDelayRetries  = 2
        numMinDelayRetries = 2
        backoffFunction    = "exponential"
      }
      disableSubscriptionOverrides = false
      defaultThrottlePolicy = {
        maxReceivesPerSecond = 5
      }
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name     = local.topics.warning.name
      Severity = local.topics.warning.severity
      Purpose  = "P2/P3 issues - creates tickets"
    }
  )
}

# Info Alerts Topic (Informational - Dashboard/Logs Only)
resource "aws_sns_topic" "info" {
  name              = local.topics.info.name
  display_name      = local.topics.info.display_name
  kms_master_key_id = local.kms_key_arn

  delivery_policy = jsonencode({
    http = {
      defaultHealthyRetryPolicy = {
        minDelayTarget     = 10
        maxDelayTarget     = 300
        numRetries         = 10
        numMaxDelayRetries = 5
        numNoDelayRetries  = 1
        numMinDelayRetries = 1
        backoffFunction    = "linear"
      }
      disableSubscriptionOverrides = false
      defaultThrottlePolicy = {
        maxReceivesPerSecond = 3
      }
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name     = local.topics.info.name
      Severity = local.topics.info.severity
      Purpose  = "Informational - dashboard and logs"
    }
  )
}

# Security Alerts Topic
resource "aws_sns_topic" "security" {
  name              = local.topics.security.name
  display_name      = local.topics.security.display_name
  kms_master_key_id = local.kms_key_arn

  # Security alerts use aggressive retry policy
  delivery_policy = jsonencode({
    http = {
      defaultHealthyRetryPolicy = {
        minDelayTarget     = 1
        maxDelayTarget     = 30
        numRetries         = 100
        numMaxDelayRetries = 50
        numNoDelayRetries  = 5
        numMinDelayRetries = 5
        backoffFunction    = "exponential"
      }
      disableSubscriptionOverrides = false
      defaultThrottlePolicy = {
        maxReceivesPerSecond = 20
      }
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name     = local.topics.security.name
      Severity = local.topics.security.severity
      Purpose  = "Security alerts - SOC review"
    }
  )
}

# Cost Alerts Topic
resource "aws_sns_topic" "cost" {
  name              = local.topics.cost.name
  display_name      = local.topics.cost.display_name
  kms_master_key_id = local.kms_key_arn

  delivery_policy = jsonencode({
    http = {
      defaultHealthyRetryPolicy = {
        minDelayTarget     = 10
        maxDelayTarget     = 300
        numRetries         = 15
        numMaxDelayRetries = 8
        numNoDelayRetries  = 2
        numMinDelayRetries = 2
        backoffFunction    = "exponential"
      }
      disableSubscriptionOverrides = false
      defaultThrottlePolicy = {
        maxReceivesPerSecond = 2
      }
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name     = local.topics.cost.name
      Severity = local.topics.cost.severity
      Purpose  = "Budget and cost anomalies"
    }
  )
}

# -----------------------------------------------------------------------------
# SNS Topic Policies
# -----------------------------------------------------------------------------

resource "aws_sns_topic_policy" "critical" {
  arn = aws_sns_topic.critical.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "CriticalAlertsPolicy"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.critical.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowEventBridge"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.critical.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowLambdaProcessor"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_processor.arn
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.critical.arn
      },
      {
        Sid    = "AllowAccountOwner"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
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
        Resource = aws_sns_topic.critical.arn
      }
    ]
  })
}

resource "aws_sns_topic_policy" "warning" {
  arn = aws_sns_topic.warning.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "WarningAlertsPolicy"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.warning.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowEventBridge"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.warning.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowLambdaProcessor"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_processor.arn
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.warning.arn
      },
      {
        Sid    = "AllowAccountOwner"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
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
        Resource = aws_sns_topic.warning.arn
      }
    ]
  })
}

resource "aws_sns_topic_policy" "info" {
  arn = aws_sns_topic.info.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "InfoAlertsPolicy"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.info.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowEventBridge"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.info.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowLambdaProcessor"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_processor.arn
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.info.arn
      },
      {
        Sid    = "AllowAccountOwner"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
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
        Resource = aws_sns_topic.info.arn
      }
    ]
  })
}

resource "aws_sns_topic_policy" "security" {
  arn = aws_sns_topic.security.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "SecurityAlertsPolicy"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.security.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowEventBridge"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.security.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowGuardDuty"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.security.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowSecurityHub"
        Effect = "Allow"
        Principal = {
          Service = "securityhub.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.security.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowConfig"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.security.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowLambdaProcessor"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_processor.arn
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.security.arn
      },
      {
        Sid    = "AllowAccountOwner"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
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
        Resource = aws_sns_topic.security.arn
      }
    ]
  })
}

resource "aws_sns_topic_policy" "cost" {
  arn = aws_sns_topic.cost.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "CostAlertsPolicy"
    Statement = [
      {
        Sid    = "AllowBudgets"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cost.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowCostAnomalyDetection"
        Effect = "Allow"
        Principal = {
          Service = "costalerts.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cost.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cost.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowEventBridge"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cost.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AllowLambdaProcessor"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_processor.arn
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cost.arn
      },
      {
        Sid    = "AllowAccountOwner"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
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
        Resource = aws_sns_topic.cost.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Topic Map for Easy Reference
# -----------------------------------------------------------------------------

locals {
  topic_arns = {
    critical = aws_sns_topic.critical.arn
    warning  = aws_sns_topic.warning.arn
    info     = aws_sns_topic.info.arn
    security = aws_sns_topic.security.arn
    cost     = aws_sns_topic.cost.arn
  }

  topic_names = {
    critical = aws_sns_topic.critical.name
    warning  = aws_sns_topic.warning.name
    info     = aws_sns_topic.info.name
    security = aws_sns_topic.security.name
    cost     = aws_sns_topic.cost.name
  }
}
