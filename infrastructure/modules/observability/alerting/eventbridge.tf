# =============================================================================
# EventBridge Rules for Alert Routing
# =============================================================================
# Configures EventBridge rules to capture and route events from:
# - GuardDuty findings
# - CloudWatch alarms
# - AWS Config rule violations
# - EC2 state changes
# - Security Hub findings
# - Cost anomaly detection
# =============================================================================

# -----------------------------------------------------------------------------
# GuardDuty Finding Rules
# -----------------------------------------------------------------------------

# Route all GuardDuty findings to security topic
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${local.name_prefix}-guardduty-findings"
  description = "Capture GuardDuty findings for security alerting"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })

  tags = merge(
    local.common_tags,
    {
      Name   = "${local.name_prefix}-guardduty-findings"
      Source = "guardduty"
    }
  )
}

resource "aws_cloudwatch_event_target" "guardduty_to_security" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToSecurityTopic"
  arn       = aws_sns_topic.security.arn

  input_transformer {
    input_paths = {
      account     = "$.account"
      region      = "$.region"
      time        = "$.time"
      finding_id  = "$.detail.id"
      type        = "$.detail.type"
      severity    = "$.detail.severity"
      title       = "$.detail.title"
      description = "$.detail.description"
    }
    input_template = <<-EOF
      {
        "source": "guardduty",
        "account": <account>,
        "region": <region>,
        "time": <time>,
        "finding_id": <finding_id>,
        "type": <type>,
        "severity": <severity>,
        "title": <title>,
        "description": <description>,
        "severity_label": "SECURITY",
        "priority": "P1"
      }
    EOF
  }
}

# High severity GuardDuty findings also go to critical
resource "aws_cloudwatch_event_rule" "guardduty_critical" {
  name        = "${local.name_prefix}-guardduty-critical"
  description = "Capture high-severity GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [
        { numeric = [">=", 7] }
      ]
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-guardduty-critical"
      Source   = "guardduty"
      Severity = "critical"
    }
  )
}

resource "aws_cloudwatch_event_target" "guardduty_critical_to_critical" {
  rule      = aws_cloudwatch_event_rule.guardduty_critical.name
  target_id = "SendToCriticalTopic"
  arn       = aws_sns_topic.critical.arn

  input_transformer {
    input_paths = {
      account     = "$.account"
      region      = "$.region"
      time        = "$.time"
      finding_id  = "$.detail.id"
      type        = "$.detail.type"
      severity    = "$.detail.severity"
      title       = "$.detail.title"
      description = "$.detail.description"
    }
    input_template = <<-EOF
      {
        "source": "guardduty",
        "severity_label": "CRITICAL",
        "priority": "P1",
        "account": <account>,
        "region": <region>,
        "time": <time>,
        "finding_id": <finding_id>,
        "type": <type>,
        "severity": <severity>,
        "title": <title>,
        "description": <description>,
        "requires_immediate_action": true
      }
    EOF
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarm State Change Rules
# -----------------------------------------------------------------------------

# Route ALARM state changes based on alarm name patterns
resource "aws_cloudwatch_event_rule" "cloudwatch_alarm_critical" {
  name        = "${local.name_prefix}-cloudwatch-alarm-critical"
  description = "Route critical CloudWatch alarms"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state = {
        value = ["ALARM"]
      }
      alarmName = [
        { prefix = "${var.environment}-critical-" },
        { prefix = "${var.environment}-high-cpu" },
        { prefix = "${var.environment}-unhealthy-host" }
      ]
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-cloudwatch-alarm-critical"
      Source   = "cloudwatch"
      Severity = "critical"
    }
  )
}

resource "aws_cloudwatch_event_target" "cloudwatch_alarm_to_critical" {
  rule      = aws_cloudwatch_event_rule.cloudwatch_alarm_critical.name
  target_id = "SendToCriticalTopic"
  arn       = aws_sns_topic.critical.arn

  input_transformer {
    input_paths = {
      alarm_name = "$.detail.alarmName"
      state      = "$.detail.state.value"
      reason     = "$.detail.state.reason"
      time       = "$.time"
      account    = "$.account"
      region     = "$.region"
    }
    input_template = <<-EOF
      {
        "source": "cloudwatch-alarm",
        "severity_label": "CRITICAL",
        "priority": "P1",
        "alarm_name": <alarm_name>,
        "state": <state>,
        "reason": <reason>,
        "time": <time>,
        "account": <account>,
        "region": <region>
      }
    EOF
  }
}

# Warning level alarms
resource "aws_cloudwatch_event_rule" "cloudwatch_alarm_warning" {
  name        = "${local.name_prefix}-cloudwatch-alarm-warning"
  description = "Route warning CloudWatch alarms"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state = {
        value = ["ALARM"]
      }
      alarmName = [
        { prefix = "${var.environment}-warning-" },
        { prefix = "${var.environment}-high-memory" },
        { prefix = "${var.environment}-low-disk" }
      ]
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-cloudwatch-alarm-warning"
      Source   = "cloudwatch"
      Severity = "warning"
    }
  )
}

resource "aws_cloudwatch_event_target" "cloudwatch_alarm_to_warning" {
  rule      = aws_cloudwatch_event_rule.cloudwatch_alarm_warning.name
  target_id = "SendToWarningTopic"
  arn       = aws_sns_topic.warning.arn

  input_transformer {
    input_paths = {
      alarm_name = "$.detail.alarmName"
      state      = "$.detail.state.value"
      reason     = "$.detail.state.reason"
      time       = "$.time"
      account    = "$.account"
      region     = "$.region"
    }
    input_template = <<-EOF
      {
        "source": "cloudwatch-alarm",
        "severity_label": "WARNING",
        "priority": "P2",
        "alarm_name": <alarm_name>,
        "state": <state>,
        "reason": <reason>,
        "time": <time>,
        "account": <account>,
        "region": <region>
      }
    EOF
  }
}

# OK state changes for recovery notifications
resource "aws_cloudwatch_event_rule" "cloudwatch_alarm_recovery" {
  name        = "${local.name_prefix}-cloudwatch-alarm-recovery"
  description = "Route CloudWatch alarm recovery notifications"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state = {
        value = ["OK"]
      }
      previousState = {
        value = ["ALARM"]
      }
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name   = "${local.name_prefix}-cloudwatch-alarm-recovery"
      Source = "cloudwatch"
      Type   = "recovery"
    }
  )
}

resource "aws_cloudwatch_event_target" "cloudwatch_alarm_recovery_to_info" {
  rule      = aws_cloudwatch_event_rule.cloudwatch_alarm_recovery.name
  target_id = "SendToInfoTopic"
  arn       = aws_sns_topic.info.arn

  input_transformer {
    input_paths = {
      alarm_name = "$.detail.alarmName"
      state      = "$.detail.state.value"
      time       = "$.time"
    }
    input_template = <<-EOF
      {
        "source": "cloudwatch-alarm",
        "severity_label": "INFO",
        "type": "recovery",
        "alarm_name": <alarm_name>,
        "state": <state>,
        "time": <time>,
        "message": "Alarm has recovered to OK state"
      }
    EOF
  }
}

# -----------------------------------------------------------------------------
# AWS Config Rule Violation Rules
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "config_compliance" {
  name        = "${local.name_prefix}-config-compliance"
  description = "Capture AWS Config compliance state changes"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      messageType = ["ComplianceChangeNotification"]
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name   = "${local.name_prefix}-config-compliance"
      Source = "config"
    }
  )
}

resource "aws_cloudwatch_event_target" "config_to_security" {
  rule      = aws_cloudwatch_event_rule.config_compliance.name
  target_id = "SendToSecurityTopic"
  arn       = aws_sns_topic.security.arn

  input_transformer {
    input_paths = {
      rule_name       = "$.detail.configRuleName"
      resource_type   = "$.detail.resourceType"
      resource_id     = "$.detail.resourceId"
      compliance_type = "$.detail.newEvaluationResult.complianceType"
      time            = "$.time"
      account         = "$.account"
      region          = "$.region"
    }
    input_template = <<-EOF
      {
        "source": "aws-config",
        "severity_label": "SECURITY",
        "priority": "P2",
        "rule_name": <rule_name>,
        "resource_type": <resource_type>,
        "resource_id": <resource_id>,
        "compliance_type": <compliance_type>,
        "time": <time>,
        "account": <account>,
        "region": <region>,
        "message": "Config rule violation detected"
      }
    EOF
  }
}

# -----------------------------------------------------------------------------
# EC2 Instance State Change Rules
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "ec2_state_change" {
  name        = "${local.name_prefix}-ec2-state-change"
  description = "Capture EC2 instance state changes"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["terminated", "stopped", "stopping"]
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name   = "${local.name_prefix}-ec2-state-change"
      Source = "ec2"
    }
  )
}

resource "aws_cloudwatch_event_target" "ec2_state_to_warning" {
  rule      = aws_cloudwatch_event_rule.ec2_state_change.name
  target_id = "SendToWarningTopic"
  arn       = aws_sns_topic.warning.arn

  input_transformer {
    input_paths = {
      instance_id = "$.detail.instance-id"
      state       = "$.detail.state"
      time        = "$.time"
      account     = "$.account"
      region      = "$.region"
    }
    input_template = <<-EOF
      {
        "source": "ec2",
        "severity_label": "WARNING",
        "priority": "P2",
        "instance_id": <instance_id>,
        "state": <state>,
        "time": <time>,
        "account": <account>,
        "region": <region>,
        "message": "EC2 instance state changed"
      }
    EOF
  }
}

# Terminated instances are more critical
resource "aws_cloudwatch_event_rule" "ec2_terminated" {
  name        = "${local.name_prefix}-ec2-terminated"
  description = "Capture EC2 instance termination events"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["terminated"]
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-ec2-terminated"
      Source   = "ec2"
      Severity = "critical"
    }
  )
}

resource "aws_cloudwatch_event_target" "ec2_terminated_to_critical" {
  rule      = aws_cloudwatch_event_rule.ec2_terminated.name
  target_id = "SendToCriticalTopic"
  arn       = aws_sns_topic.critical.arn

  input_transformer {
    input_paths = {
      instance_id = "$.detail.instance-id"
      state       = "$.detail.state"
      time        = "$.time"
      account     = "$.account"
      region      = "$.region"
    }
    input_template = <<-EOF
      {
        "source": "ec2",
        "severity_label": "CRITICAL",
        "priority": "P1",
        "instance_id": <instance_id>,
        "state": <state>,
        "time": <time>,
        "account": <account>,
        "region": <region>,
        "message": "EC2 instance has been TERMINATED",
        "requires_immediate_action": true
      }
    EOF
  }
}

# -----------------------------------------------------------------------------
# Security Hub Finding Rules
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "security_hub_findings" {
  count = var.enable_security_hub_rules ? 1 : 0

  name        = "${local.name_prefix}-security-hub-findings"
  description = "Capture Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["CRITICAL", "HIGH"]
        }
        Workflow = {
          Status = ["NEW"]
        }
      }
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name   = "${local.name_prefix}-security-hub-findings"
      Source = "securityhub"
    }
  )
}

resource "aws_cloudwatch_event_target" "security_hub_to_security" {
  count = var.enable_security_hub_rules ? 1 : 0

  rule      = aws_cloudwatch_event_rule.security_hub_findings[0].name
  target_id = "SendToSecurityTopic"
  arn       = aws_sns_topic.security.arn
}

# -----------------------------------------------------------------------------
# Auto Scaling Events
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "autoscaling_events" {
  name        = "${local.name_prefix}-autoscaling-events"
  description = "Capture Auto Scaling events"

  event_pattern = jsonencode({
    source = ["aws.autoscaling"]
    detail-type = [
      "EC2 Instance Launch Successful",
      "EC2 Instance Launch Unsuccessful",
      "EC2 Instance Terminate Successful",
      "EC2 Instance Terminate Unsuccessful"
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name   = "${local.name_prefix}-autoscaling-events"
      Source = "autoscaling"
    }
  )
}

resource "aws_cloudwatch_event_target" "autoscaling_to_info" {
  rule      = aws_cloudwatch_event_rule.autoscaling_events.name
  target_id = "SendToInfoTopic"
  arn       = aws_sns_topic.info.arn

  input_transformer {
    input_paths = {
      asg_name    = "$.detail.AutoScalingGroupName"
      instance_id = "$.detail.EC2InstanceId"
      detail_type = "$.detail-type"
      time        = "$.time"
    }
    input_template = <<-EOF
      {
        "source": "autoscaling",
        "severity_label": "INFO",
        "asg_name": <asg_name>,
        "instance_id": <instance_id>,
        "event_type": <detail_type>,
        "time": <time>
      }
    EOF
  }
}

# Failed auto scaling events are warnings
resource "aws_cloudwatch_event_rule" "autoscaling_failures" {
  name        = "${local.name_prefix}-autoscaling-failures"
  description = "Capture Auto Scaling failure events"

  event_pattern = jsonencode({
    source = ["aws.autoscaling"]
    detail-type = [
      "EC2 Instance Launch Unsuccessful",
      "EC2 Instance Terminate Unsuccessful"
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name     = "${local.name_prefix}-autoscaling-failures"
      Source   = "autoscaling"
      Severity = "warning"
    }
  )
}

resource "aws_cloudwatch_event_target" "autoscaling_failures_to_warning" {
  rule      = aws_cloudwatch_event_rule.autoscaling_failures.name
  target_id = "SendToWarningTopic"
  arn       = aws_sns_topic.warning.arn

  input_transformer {
    input_paths = {
      asg_name    = "$.detail.AutoScalingGroupName"
      detail_type = "$.detail-type"
      cause       = "$.detail.Cause"
      time        = "$.time"
    }
    input_template = <<-EOF
      {
        "source": "autoscaling",
        "severity_label": "WARNING",
        "priority": "P2",
        "asg_name": <asg_name>,
        "event_type": <detail_type>,
        "cause": <cause>,
        "time": <time>,
        "message": "Auto Scaling operation failed"
      }
    EOF
  }
}

# -----------------------------------------------------------------------------
# Cost Anomaly Detection Rules
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "cost_anomaly" {
  count = var.enable_cost_anomaly_rules ? 1 : 0

  name        = "${local.name_prefix}-cost-anomaly"
  description = "Capture AWS Cost Anomaly Detection alerts"

  event_pattern = jsonencode({
    source      = ["aws.ce"]
    detail-type = ["AWS Cost Anomaly Detection Alerts"]
  })

  tags = merge(
    local.common_tags,
    {
      Name   = "${local.name_prefix}-cost-anomaly"
      Source = "cost-explorer"
    }
  )
}

resource "aws_cloudwatch_event_target" "cost_anomaly_to_cost" {
  count = var.enable_cost_anomaly_rules ? 1 : 0

  rule      = aws_cloudwatch_event_rule.cost_anomaly[0].name
  target_id = "SendToCostTopic"
  arn       = aws_sns_topic.cost.arn

  input_transformer {
    input_paths = {
      anomaly_id    = "$.detail.anomalyId"
      anomaly_score = "$.detail.anomalyScore"
      impact        = "$.detail.impact"
      root_causes   = "$.detail.rootCauses"
      time          = "$.time"
    }
    input_template = <<-EOF
      {
        "source": "cost-anomaly-detection",
        "severity_label": "COST",
        "anomaly_id": <anomaly_id>,
        "anomaly_score": <anomaly_score>,
        "impact": <impact>,
        "root_causes": <root_causes>,
        "time": <time>,
        "message": "Cost anomaly detected"
      }
    EOF
  }
}

# -----------------------------------------------------------------------------
# Cross-Account Event Bus (Optional)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_bus" "cross_account" {
  count = var.enable_cross_account_events ? 1 : 0

  name = "${local.name_prefix}-cross-account-bus"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-cross-account-bus"
      Type = "cross-account"
    }
  )
}

resource "aws_cloudwatch_event_bus_policy" "cross_account" {
  count = var.enable_cross_account_events && length(var.cross_account_ids) > 0 ? 1 : 0

  event_bus_name = aws_cloudwatch_event_bus.cross_account[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPutEvents"
        Effect = "Allow"
        Principal = {
          AWS = [for account_id in var.cross_account_ids : "arn:aws:iam::${account_id}:root"]
        }
        Action   = "events:PutEvents"
        Resource = aws_cloudwatch_event_bus.cross_account[0].arn
      }
    ]
  })
}

# Rule to forward cross-account events to appropriate topics
resource "aws_cloudwatch_event_rule" "cross_account_forward" {
  count = var.enable_cross_account_events ? 1 : 0

  name           = "${local.name_prefix}-cross-account-forward"
  description    = "Forward events from cross-account event bus"
  event_bus_name = aws_cloudwatch_event_bus.cross_account[0].name

  event_pattern = jsonencode({
    source = [{ prefix = "" }]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-cross-account-forward"
      Type = "cross-account"
    }
  )
}

resource "aws_cloudwatch_event_target" "cross_account_to_info" {
  count = var.enable_cross_account_events ? 1 : 0

  rule           = aws_cloudwatch_event_rule.cross_account_forward[0].name
  event_bus_name = aws_cloudwatch_event_bus.cross_account[0].name
  target_id      = "SendToInfoTopic"
  arn            = aws_sns_topic.info.arn
}

# -----------------------------------------------------------------------------
# IAM Service-Linked Role Events
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "iam_changes" {
  count = var.enable_iam_monitoring ? 1 : 0

  name        = "${local.name_prefix}-iam-changes"
  description = "Capture IAM policy and role changes"

  event_pattern = jsonencode({
    source      = ["aws.iam"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["iam.amazonaws.com"]
      eventName = [
        "CreatePolicy",
        "DeletePolicy",
        "CreatePolicyVersion",
        "DeletePolicyVersion",
        "AttachRolePolicy",
        "DetachRolePolicy",
        "AttachUserPolicy",
        "DetachUserPolicy",
        "CreateRole",
        "DeleteRole",
        "UpdateAssumeRolePolicy"
      ]
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name   = "${local.name_prefix}-iam-changes"
      Source = "iam"
    }
  )
}

resource "aws_cloudwatch_event_target" "iam_changes_to_security" {
  count = var.enable_iam_monitoring ? 1 : 0

  rule      = aws_cloudwatch_event_rule.iam_changes[0].name
  target_id = "SendToSecurityTopic"
  arn       = aws_sns_topic.security.arn

  input_transformer {
    input_paths = {
      event_name     = "$.detail.eventName"
      user_arn       = "$.detail.userIdentity.arn"
      source_ip      = "$.detail.sourceIPAddress"
      time           = "$.time"
      request_params = "$.detail.requestParameters"
    }
    input_template = <<-EOF
      {
        "source": "iam",
        "severity_label": "SECURITY",
        "priority": "P2",
        "event_name": <event_name>,
        "user_arn": <user_arn>,
        "source_ip": <source_ip>,
        "time": <time>,
        "request_params": <request_params>,
        "message": "IAM configuration change detected"
      }
    EOF
  }
}
