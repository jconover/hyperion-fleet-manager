# CloudWatch Security Dashboard for Hyperion Fleet Manager
# Provides comprehensive security monitoring with color-coded severity indicators
# and time-based trend analysis for security-related metrics and events.

locals {
  security_dashboard_name = "${var.environment}-hyperion-security"

  # Color scheme for severity indicators
  security_colors = {
    critical = "#d62728" # Red
    high     = "#ff7f0e" # Orange
    medium   = "#ffbb78" # Light Orange
    low      = "#2ca02c" # Green
    info     = "#1f77b4" # Blue
    success  = "#98df8a" # Light Green
  }

  # CloudWatch Logs Insights queries - defined as locals to avoid heredoc issues in jsonencode
  security_queries = {
    failed_logins_trend = var.windows_security_log_group_name != "" ? "SOURCE '${var.windows_security_log_group_name}'\n| filter @message like /4625/ or @message like /FailureReason/ or @message like /Logon Type/\n| stats count(*) as FailedLogins by bin(1h) as TimeWindow\n| sort TimeWindow desc\n| limit 24" : "fields @timestamp | limit 1"

    failed_logins_by_account = var.windows_security_log_group_name != "" ? "SOURCE '${var.windows_security_log_group_name}'\n| filter @message like /4625/\n| parse @message /Account Name:\\s+(?<AccountName>\\S+)/\n| parse @message /Source Network Address:\\s+(?<SourceIP>\\S+)/\n| stats count(*) as Attempts by AccountName, SourceIP\n| sort Attempts desc\n| limit 10" : "fields @timestamp | limit 1"

    iam_policy_changes = var.cloudtrail_log_group_name != "" ? "SOURCE '${var.cloudtrail_log_group_name}'\n| filter eventSource = 'iam.amazonaws.com'\n| filter eventName in ['CreateUser', 'DeleteUser', 'CreateRole', 'DeleteRole', 'AttachUserPolicy', 'DetachUserPolicy', 'AttachRolePolicy', 'DetachRolePolicy', 'PutUserPolicy', 'DeleteUserPolicy', 'PutRolePolicy', 'DeleteRolePolicy', 'CreateAccessKey', 'DeleteAccessKey', 'UpdateAccessKey']\n| stats count(*) as Changes by eventName\n| sort Changes desc\n| limit 10" : "fields @timestamp | limit 1"

    security_group_changes = var.cloudtrail_log_group_name != "" ? "SOURCE '${var.cloudtrail_log_group_name}'\n| filter eventSource = 'ec2.amazonaws.com'\n| filter eventName in ['AuthorizeSecurityGroupIngress', 'AuthorizeSecurityGroupEgress', 'RevokeSecurityGroupIngress', 'RevokeSecurityGroupEgress', 'CreateSecurityGroup', 'DeleteSecurityGroup', 'ModifySecurityGroupRules']\n| stats count(*) as Changes by eventName, userIdentity.arn as User\n| sort Changes desc\n| limit 10" : "fields @timestamp | limit 1"

    cloudtrail_api_errors = var.cloudtrail_log_group_name != "" ? "SOURCE '${var.cloudtrail_log_group_name}'\n| filter errorCode like /AccessDenied/ or errorCode like /UnauthorizedAccess/ or errorCode like /Unauthorized/\n| stats count(*) as Errors by eventSource, eventName, errorCode\n| sort Errors desc\n| limit 10" : "fields @timestamp | limit 1"

    vpc_rejected_trend = var.vpc_flow_log_group_name != "" ? "SOURCE '${var.vpc_flow_log_group_name}'\n| filter action = 'REJECT'\n| stats count(*) as RejectedPackets by bin(1h) as TimeWindow\n| sort TimeWindow desc\n| limit 24" : "fields @timestamp | limit 1"

    vpc_rejected_by_source = var.vpc_flow_log_group_name != "" ? "SOURCE '${var.vpc_flow_log_group_name}'\n| filter action = 'REJECT'\n| stats count(*) as RejectedCount by srcAddr, dstPort\n| sort RejectedCount desc\n| limit 15" : "fields @timestamp | limit 1"

    kms_key_usage = var.cloudtrail_log_group_name != "" ? "SOURCE '${var.cloudtrail_log_group_name}'\n| filter eventSource = 'kms.amazonaws.com'\n| filter eventName in ['Decrypt', 'Encrypt', 'GenerateDataKey', 'GenerateDataKeyWithoutPlaintext', 'CreateKey', 'ScheduleKeyDeletion', 'DisableKey', 'EnableKey']\n| stats count(*) as Operations by eventName, userIdentity.arn as User\n| sort Operations desc\n| limit 10" : "fields @timestamp | limit 1"

    secrets_manager_access = var.cloudtrail_log_group_name != "" ? "SOURCE '${var.cloudtrail_log_group_name}'\n| filter eventSource = 'secretsmanager.amazonaws.com'\n| filter eventName in ['GetSecretValue', 'CreateSecret', 'DeleteSecret', 'UpdateSecret', 'PutSecretValue', 'RotateSecret']\n| stats count(*) as Operations by eventName, requestParameters.secretId as SecretId, userIdentity.arn as User\n| sort Operations desc\n| limit 10" : "fields @timestamp | limit 1"

    api_error_summary = var.cloudtrail_log_group_name != "" ? "SOURCE '${var.cloudtrail_log_group_name}'\n| filter errorCode != ''\n| stats count(*) as ErrorCount by eventSource, errorCode\n| sort ErrorCount desc\n| limit 10" : "fields @timestamp | limit 1"

    security_event_timeline = var.cloudtrail_log_group_name != "" ? "SOURCE '${var.cloudtrail_log_group_name}'\n| filter eventSource in ['iam.amazonaws.com', 'ec2.amazonaws.com', 'kms.amazonaws.com', 'secretsmanager.amazonaws.com', 's3.amazonaws.com']\n| filter eventName like /Delete/ or eventName like /Remove/ or eventName like /Revoke/ or eventName like /Disable/ or errorCode like /AccessDenied/\n| stats count(*) as SecurityEvents by bin(1h) as TimeWindow, eventSource\n| sort TimeWindow desc" : "fields @timestamp | limit 1"
  }
}

# CloudWatch Security Dashboard
# Note: Uses data.aws_region.current and data.aws_caller_identity.current
# defined in cost_anomaly_detection.tf
resource "aws_cloudwatch_dashboard" "security" {
  dashboard_name = local.security_dashboard_name

  dashboard_body = jsonencode({
    widgets = concat(
      # Row 1: Header and Summary Widgets
      [
        {
          type   = "text"
          x      = 0
          y      = 0
          width  = 24
          height = 1
          properties = {
            markdown   = "# Security Dashboard - ${upper(var.environment)} Environment\n**Project:** ${var.project_name} | **Region:** ${data.aws_region.current.name} | **Last Updated:** Auto-refresh enabled"
            background = "transparent"
          }
        }
      ],

      # Row 2: GuardDuty Findings by Severity
      var.guardduty_detector_id != "" ? [
        {
          type   = "metric"
          x      = 0
          y      = 1
          width  = 8
          height = 6
          properties = {
            metrics = [
              ["AWS/GuardDuty", "FindingsCount", "DetectorId", var.guardduty_detector_id, "Severity", "High", { stat = "Sum", label = "High Severity", color = local.security_colors.critical }],
              ["...", "Medium", { stat = "Sum", label = "Medium Severity", color = local.security_colors.medium }],
              ["...", "Low", { stat = "Sum", label = "Low Severity", color = local.security_colors.low }]
            ]
            view    = "timeSeries"
            stacked = true
            region  = data.aws_region.current.name
            title   = "GuardDuty Findings by Severity"
            period  = 3600
            yAxis = {
              left = {
                min   = 0
                label = "Count"
              }
            }
            annotations = {
              horizontal = [
                {
                  label = "Alert Threshold"
                  value = 5
                  fill  = "above"
                  color = local.security_colors.critical
                }
              ]
            }
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 1
          width  = 4
          height = 6
          properties = {
            metrics = [
              ["AWS/GuardDuty", "FindingsCount", "DetectorId", var.guardduty_detector_id, "Severity", "High", { stat = "Sum", label = "High", color = local.security_colors.critical }]
            ]
            view                 = "singleValue"
            region               = data.aws_region.current.name
            title                = "High Severity Findings (24h)"
            period               = 86400
            sparkline            = true
            setPeriodToTimeRange = false
          }
        }
        ] : [
        {
          type   = "text"
          x      = 0
          y      = 1
          width  = 12
          height = 6
          properties = {
            markdown   = "## GuardDuty\n\n**Status:** Not Configured\n\nEnable GuardDuty and provide the detector ID to monitor for threats."
            background = "transparent"
          }
        }
      ],

      # Security Hub Compliance Score
      var.security_hub_enabled ? [
        {
          type   = "metric"
          x      = 12
          y      = 1
          width  = 6
          height = 6
          properties = {
            metrics = [
              ["AWS/SecurityHub", "ComplianceScore", "StandardsArn", "arn:aws:securityhub:::standards/aws-foundational-security-best-practices/v/1.0.0", { stat = "Average", label = "AWS Foundational", color = local.security_colors.info }],
              ["...", "arn:aws:securityhub:::standards/cis-aws-foundations-benchmark/v/1.2.0", { stat = "Average", label = "CIS Benchmark", color = local.security_colors.success }]
            ]
            view   = "gauge"
            region = data.aws_region.current.name
            title  = "Security Hub Compliance Score"
            period = 3600
            yAxis = {
              left = {
                min = 0
                max = 100
              }
            }
            annotations = {
              horizontal = [
                {
                  color = local.security_colors.critical
                  label = "Critical"
                  value = 50
                  fill  = "below"
                },
                {
                  color = local.security_colors.medium
                  label = "Warning"
                  value = 80
                  fill  = "below"
                }
              ]
            }
          }
        },
        {
          type   = "metric"
          x      = 18
          y      = 1
          width  = 6
          height = 6
          properties = {
            metrics = [
              ["AWS/SecurityHub", "FindingCount", "FindingSeverity", "CRITICAL", { stat = "Sum", label = "Critical", color = local.security_colors.critical }],
              ["...", "HIGH", { stat = "Sum", label = "High", color = local.security_colors.high }],
              ["...", "MEDIUM", { stat = "Sum", label = "Medium", color = local.security_colors.medium }],
              ["...", "LOW", { stat = "Sum", label = "Low", color = local.security_colors.low }]
            ]
            view                 = "pie"
            region               = data.aws_region.current.name
            title                = "Security Hub Findings Distribution"
            period               = 86400
            setPeriodToTimeRange = false
          }
        }
        ] : [
        {
          type   = "text"
          x      = 12
          y      = 1
          width  = 12
          height = 6
          properties = {
            markdown   = "## Security Hub\n\n**Status:** Not Enabled\n\nEnable Security Hub to monitor compliance and security findings."
            background = "transparent"
          }
        }
      ],

      # Row 3: Windows Security Logs - Failed Login Attempts
      var.windows_security_log_group_name != "" ? [
        {
          type   = "log"
          x      = 0
          y      = 7
          width  = 12
          height = 6
          properties = {
            query  = local.security_queries.failed_logins_trend
            region = data.aws_region.current.name
            title  = "Failed Login Attempts (Windows Event 4625)"
            view   = "bar"
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 7
          width  = 12
          height = 6
          properties = {
            query  = local.security_queries.failed_logins_by_account
            region = data.aws_region.current.name
            title  = "Top Failed Login Attempts by Account/IP"
            view   = "table"
          }
        }
        ] : [
        {
          type   = "text"
          x      = 0
          y      = 7
          width  = 24
          height = 6
          properties = {
            markdown   = "## Windows Security Logs\n\n**Status:** Log Group Not Configured\n\nProvide the Windows Security log group name to monitor failed login attempts."
            background = "transparent"
          }
        }
      ],

      # Row 4: IAM and Security Group Changes (CloudTrail)
      var.cloudtrail_log_group_name != "" ? [
        {
          type   = "log"
          x      = 0
          y      = 13
          width  = 8
          height = 6
          properties = {
            query  = local.security_queries.iam_policy_changes
            region = data.aws_region.current.name
            title  = "IAM Policy Changes"
            view   = "table"
          }
        },
        {
          type   = "log"
          x      = 8
          y      = 13
          width  = 8
          height = 6
          properties = {
            query  = local.security_queries.security_group_changes
            region = data.aws_region.current.name
            title  = "Security Group Changes"
            view   = "table"
          }
        },
        {
          type   = "log"
          x      = 16
          y      = 13
          width  = 8
          height = 6
          properties = {
            query  = local.security_queries.cloudtrail_api_errors
            region = data.aws_region.current.name
            title  = "CloudTrail API Errors (Access Denied)"
            view   = "table"
          }
        }
        ] : [
        {
          type   = "text"
          x      = 0
          y      = 13
          width  = 24
          height = 6
          properties = {
            markdown   = "## CloudTrail Monitoring\n\n**Status:** Log Group Not Configured\n\nProvide the CloudTrail log group name to monitor IAM and Security Group changes."
            background = "transparent"
          }
        }
      ],

      # Row 5: VPC Flow Logs - Rejected Packets
      var.vpc_flow_log_group_name != "" ? [
        {
          type   = "log"
          x      = 0
          y      = 19
          width  = 12
          height = 6
          properties = {
            query  = local.security_queries.vpc_rejected_trend
            region = data.aws_region.current.name
            title  = "VPC Flow Log Rejected Packets (Hourly Trend)"
            view   = "bar"
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 19
          width  = 12
          height = 6
          properties = {
            query  = local.security_queries.vpc_rejected_by_source
            region = data.aws_region.current.name
            title  = "Top Rejected Connections (Source IP / Dest Port)"
            view   = "table"
          }
        }
        ] : [
        {
          type   = "text"
          x      = 0
          y      = 19
          width  = 24
          height = 6
          properties = {
            markdown   = "## VPC Flow Logs\n\n**Status:** Log Group Not Configured\n\nProvide the VPC Flow Log group name to monitor rejected network traffic."
            background = "transparent"
          }
        }
      ],

      # Row 6: KMS Key Usage and Secrets Manager Access
      [
        {
          type   = "log"
          x      = 0
          y      = 25
          width  = 12
          height = 6
          properties = {
            query  = local.security_queries.kms_key_usage
            region = data.aws_region.current.name
            title  = "KMS Key Usage"
            view   = "table"
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 25
          width  = 12
          height = 6
          properties = {
            query  = local.security_queries.secrets_manager_access
            region = data.aws_region.current.name
            title  = "Secrets Manager Access Patterns"
            view   = "table"
          }
        }
      ],

      # Row 7: Config Rule Compliance Status
      [
        {
          type   = "metric"
          x      = 0
          y      = 31
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/Config", "ComplianceByConfigRule", "ConfigRuleName", "required-tags", { stat = "Average", label = "Required Tags", color = local.security_colors.info }],
              ["...", "encrypted-volumes", { stat = "Average", label = "Encrypted Volumes", color = local.security_colors.success }],
              ["...", "ec2-security-group-attached-to-eni", { stat = "Average", label = "SG Attached to ENI", color = local.security_colors.low }],
              ["...", "iam-password-policy", { stat = "Average", label = "IAM Password Policy", color = local.security_colors.medium }]
            ]
            view    = "timeSeries"
            stacked = false
            region  = data.aws_region.current.name
            title   = "AWS Config Rule Compliance Status"
            period  = 3600
            yAxis = {
              left = {
                min   = 0
                max   = 1
                label = "Compliance (1=Compliant)"
              }
            }
            annotations = {
              horizontal = [
                {
                  label = "Compliant"
                  value = 1
                  color = local.security_colors.success
                },
                {
                  label = "Non-Compliant"
                  value = 0
                  color = local.security_colors.critical
                }
              ]
            }
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 31
          width  = 6
          height = 6
          properties = {
            metrics = [
              ["AWS/Config", "ComplianceByConfigRule", { stat = "Average", label = "Overall Compliance" }]
            ]
            view   = "gauge"
            region = data.aws_region.current.name
            title  = "Overall Config Compliance"
            period = 3600
            yAxis = {
              left = {
                min = 0
                max = 1
              }
            }
          }
        },
        {
          type   = "log"
          x      = 18
          y      = 31
          width  = 6
          height = 6
          properties = {
            query  = local.security_queries.api_error_summary
            region = data.aws_region.current.name
            title  = "API Error Summary"
            view   = "table"
          }
        }
      ],

      # Row 8: Security Trend Analysis
      var.cloudtrail_log_group_name != "" && var.enable_trend_analysis ? [
        {
          type   = "log"
          x      = 0
          y      = 37
          width  = 24
          height = 6
          properties = {
            query  = local.security_queries.security_event_timeline
            region = data.aws_region.current.name
            title  = "Security Event Timeline (Potentially Risky Operations)"
            view   = "bar"
          }
        }
      ] : [],

      # Row 9: Active Alarms Widget
      [
        {
          type   = "alarm"
          x      = 0
          y      = 43
          width  = 24
          height = 4
          properties = {
            title = "Active Security Alarms"
            alarms = [
              "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:${var.environment}-*security*",
              "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:${var.environment}-*guardduty*",
              "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:${var.environment}-*compliance*"
            ]
          }
        }
      ]
    )
  })
}

# CloudWatch Metric Alarm for GuardDuty High Severity Findings
resource "aws_cloudwatch_metric_alarm" "guardduty_high_severity" {
  count = var.guardduty_detector_id != "" && var.enable_security_alarms ? 1 : 0

  alarm_name          = "${var.environment}-guardduty-high-severity-findings"
  alarm_description   = "Triggers when GuardDuty detects high severity findings"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.security_alarm_evaluation_periods
  metric_name         = "FindingsCount"
  namespace           = "AWS/GuardDuty"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    DetectorId = var.guardduty_detector_id
    Severity   = "High"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-guardduty-high-severity-findings"
      Environment = var.environment
      Project     = var.project_name
      AlarmType   = "security"
      ManagedBy   = "terraform"
    }
  )
}

# CloudWatch Metric Alarm for Security Hub Critical Findings
resource "aws_cloudwatch_metric_alarm" "security_hub_critical" {
  count = var.security_hub_enabled && var.enable_security_alarms ? 1 : 0

  alarm_name          = "${var.environment}-security-hub-critical-findings"
  alarm_description   = "Triggers when Security Hub detects critical findings"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.security_alarm_evaluation_periods
  metric_name         = "FindingCount"
  namespace           = "AWS/SecurityHub"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    FindingSeverity = "CRITICAL"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-security-hub-critical-findings"
      Environment = var.environment
      Project     = var.project_name
      AlarmType   = "security"
      ManagedBy   = "terraform"
    }
  )
}

# CloudWatch Log Metric Filter for Failed Login Attempts
resource "aws_cloudwatch_log_metric_filter" "failed_logins" {
  count = var.windows_security_log_group_name != "" && var.enable_security_alarms ? 1 : 0

  name           = "${var.environment}-failed-login-attempts"
  log_group_name = var.windows_security_log_group_name
  pattern        = "[timestamp, ..., event_id=4625, ...]"

  metric_transformation {
    name          = "FailedLoginAttempts"
    namespace     = "${var.project_name}/Security"
    value         = "1"
    unit          = "Count"
    default_value = "0"
  }
}

# CloudWatch Metric Alarm for Failed Login Attempts
resource "aws_cloudwatch_metric_alarm" "failed_logins" {
  count = var.windows_security_log_group_name != "" && var.enable_security_alarms ? 1 : 0

  alarm_name          = "${var.environment}-excessive-failed-logins"
  alarm_description   = "Triggers when failed login attempts exceed threshold in 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.security_alarm_evaluation_periods
  metric_name         = "FailedLoginAttempts"
  namespace           = "${var.project_name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = var.failed_login_threshold
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions
  treat_missing_data  = "notBreaching"

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-excessive-failed-logins"
      Environment = var.environment
      Project     = var.project_name
      AlarmType   = "security"
      ManagedBy   = "terraform"
    }
  )

  depends_on = [aws_cloudwatch_log_metric_filter.failed_logins]
}

# CloudWatch Log Metric Filter for IAM Policy Changes
resource "aws_cloudwatch_log_metric_filter" "iam_changes" {
  count = var.cloudtrail_log_group_name != "" && var.enable_security_alarms ? 1 : 0

  name           = "${var.environment}-iam-policy-changes"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.eventSource = \"iam.amazonaws.com\") && (($.eventName = \"CreateUser\") || ($.eventName = \"DeleteUser\") || ($.eventName = \"CreateRole\") || ($.eventName = \"DeleteRole\") || ($.eventName = \"AttachUserPolicy\") || ($.eventName = \"DetachUserPolicy\") || ($.eventName = \"AttachRolePolicy\") || ($.eventName = \"DetachRolePolicy\")) }"

  metric_transformation {
    name          = "IAMPolicyChanges"
    namespace     = "${var.project_name}/Security"
    value         = "1"
    unit          = "Count"
    default_value = "0"
  }
}

# CloudWatch Metric Alarm for IAM Policy Changes
resource "aws_cloudwatch_metric_alarm" "iam_changes" {
  count = var.cloudtrail_log_group_name != "" && var.enable_security_alarms ? 1 : 0

  alarm_name          = "${var.environment}-iam-policy-changes"
  alarm_description   = "Triggers when IAM policy changes are detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.security_alarm_evaluation_periods
  metric_name         = "IAMPolicyChanges"
  namespace           = "${var.project_name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-iam-policy-changes"
      Environment = var.environment
      Project     = var.project_name
      AlarmType   = "security"
      ManagedBy   = "terraform"
    }
  )

  depends_on = [aws_cloudwatch_log_metric_filter.iam_changes]
}

# CloudWatch Log Metric Filter for Security Group Changes
resource "aws_cloudwatch_log_metric_filter" "security_group_changes" {
  count = var.cloudtrail_log_group_name != "" && var.enable_security_alarms ? 1 : 0

  name           = "${var.environment}-security-group-changes"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.eventSource = \"ec2.amazonaws.com\") && (($.eventName = \"AuthorizeSecurityGroupIngress\") || ($.eventName = \"AuthorizeSecurityGroupEgress\") || ($.eventName = \"RevokeSecurityGroupIngress\") || ($.eventName = \"RevokeSecurityGroupEgress\") || ($.eventName = \"CreateSecurityGroup\") || ($.eventName = \"DeleteSecurityGroup\")) }"

  metric_transformation {
    name          = "SecurityGroupChanges"
    namespace     = "${var.project_name}/Security"
    value         = "1"
    unit          = "Count"
    default_value = "0"
  }
}

# CloudWatch Metric Alarm for Security Group Changes
resource "aws_cloudwatch_metric_alarm" "security_group_changes" {
  count = var.cloudtrail_log_group_name != "" && var.enable_security_alarms ? 1 : 0

  alarm_name          = "${var.environment}-security-group-changes"
  alarm_description   = "Triggers when security group changes are detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.security_alarm_evaluation_periods
  metric_name         = "SecurityGroupChanges"
  namespace           = "${var.project_name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-security-group-changes"
      Environment = var.environment
      Project     = var.project_name
      AlarmType   = "security"
      ManagedBy   = "terraform"
    }
  )

  depends_on = [aws_cloudwatch_log_metric_filter.security_group_changes]
}

# CloudWatch Log Metric Filter for VPC Flow Log Rejected Packets
resource "aws_cloudwatch_log_metric_filter" "vpc_rejected_packets" {
  count = var.vpc_flow_log_group_name != "" && var.enable_security_alarms ? 1 : 0

  name           = "${var.environment}-vpc-rejected-packets"
  log_group_name = var.vpc_flow_log_group_name
  pattern        = "[version, account_id, interface_id, srcaddr, dstaddr, srcport, dstport, protocol, packets, bytes, start, end, action=\"REJECT\", log_status]"

  metric_transformation {
    name          = "VPCRejectedPackets"
    namespace     = "${var.project_name}/Security"
    value         = "$packets"
    unit          = "Count"
    default_value = "0"
  }
}

# CloudWatch Metric Alarm for High Volume of Rejected Packets
resource "aws_cloudwatch_metric_alarm" "vpc_rejected_packets" {
  count = var.vpc_flow_log_group_name != "" && var.enable_security_alarms ? 1 : 0

  alarm_name          = "${var.environment}-high-vpc-rejected-packets"
  alarm_description   = "Triggers when rejected packet count exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "VPCRejectedPackets"
  namespace           = "${var.project_name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = var.rejected_packets_threshold
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions
  treat_missing_data  = "notBreaching"

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-high-vpc-rejected-packets"
      Environment = var.environment
      Project     = var.project_name
      AlarmType   = "security"
      ManagedBy   = "terraform"
    }
  )

  depends_on = [aws_cloudwatch_log_metric_filter.vpc_rejected_packets]
}

# CloudWatch Log Metric Filter for CloudTrail API Errors
resource "aws_cloudwatch_log_metric_filter" "cloudtrail_api_errors" {
  count = var.cloudtrail_log_group_name != "" && var.enable_security_alarms ? 1 : 0

  name           = "${var.environment}-cloudtrail-api-errors"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.errorCode = \"*UnauthorizedAccess*\") || ($.errorCode = \"AccessDenied*\") || ($.errorCode = \"AuthorizationError\") }"

  metric_transformation {
    name          = "CloudTrailAPIErrors"
    namespace     = "${var.project_name}/Security"
    value         = "1"
    unit          = "Count"
    default_value = "0"
  }
}

# CloudWatch Metric Alarm for CloudTrail API Errors
resource "aws_cloudwatch_metric_alarm" "cloudtrail_api_errors" {
  count = var.cloudtrail_log_group_name != "" && var.enable_security_alarms ? 1 : 0

  alarm_name          = "${var.environment}-cloudtrail-api-errors"
  alarm_description   = "Triggers when API authorization errors are detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.security_alarm_evaluation_periods
  metric_name         = "CloudTrailAPIErrors"
  namespace           = "${var.project_name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = var.api_error_threshold
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-cloudtrail-api-errors"
      Environment = var.environment
      Project     = var.project_name
      AlarmType   = "security"
      ManagedBy   = "terraform"
    }
  )

  depends_on = [aws_cloudwatch_log_metric_filter.cloudtrail_api_errors]
}
