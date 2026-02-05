terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "system" {
  name              = "/hyperion/fleet/system"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name        = "hyperion-fleet-system-logs"
      LogType     = "system"
      Environment = var.environment
    }
  )
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/hyperion/fleet/application"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name        = "hyperion-fleet-application-logs"
      LogType     = "application"
      Environment = var.environment
    }
  )
}

resource "aws_cloudwatch_log_group" "security" {
  name              = "/hyperion/fleet/security"
  retention_in_days = var.security_log_retention_days
  kms_key_id        = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name        = "hyperion-fleet-security-logs"
      LogType     = "security"
      Environment = var.environment
    }
  )
}

# CloudWatch Log Metric Filters
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "${var.environment}-error-count"
  log_group_name = aws_cloudwatch_log_group.application.name
  pattern        = "[time, request_id, level = ERROR*, ...]"

  metric_transformation {
    name      = "ErrorCount"
    namespace = var.cloudwatch_namespace
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "security_events" {
  name           = "${var.environment}-security-events"
  log_group_name = aws_cloudwatch_log_group.security.name
  pattern        = "[time, event_type, severity = CRITICAL*, ...]"

  metric_transformation {
    name      = "SecurityEvents"
    namespace = var.cloudwatch_namespace
    value     = "1"
    unit      = "Count"
  }
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.environment}-fleet-alerts"
  display_name      = "Fleet Monitoring Alerts"
  kms_master_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-fleet-alerts"
      Environment = var.environment
    }
  )
}

resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Sid    = "AllowEventsToPublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "email_alerts" {
  for_each = toset(var.alert_email_addresses)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "fleet_health" {
  dashboard_name = "${var.environment}-fleet-health-overview"
  dashboard_body = templatefile("${path.module}/dashboards/fleet-health.json", {
    region              = data.aws_region.current.name
    environment         = var.environment
    namespace           = var.cloudwatch_namespace
    system_log_group    = aws_cloudwatch_log_group.system.name
    app_log_group       = aws_cloudwatch_log_group.application.name
    security_log_group  = aws_cloudwatch_log_group.security.name
    target_group_arn    = var.target_group_arn_suffix
    load_balancer_arn   = var.load_balancer_arn_suffix
  })
}

# CloudWatch Metric Alarms - CPU
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  for_each = var.enable_instance_alarms ? toset(var.instance_ids) : []

  alarm_name          = "${var.environment}-high-cpu-${each.value}"
  alarm_description   = "Triggers when CPU utilization exceeds ${var.cpu_threshold_percent}% for ${var.cpu_evaluation_periods * var.alarm_period / 60} minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cpu_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.cpu_threshold_percent
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = each.value
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-high-cpu-${each.value}"
      Environment = var.environment
      AlarmType   = "cpu"
    }
  )
}

# CloudWatch Metric Alarms - Memory
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  for_each = var.enable_instance_alarms ? toset(var.instance_ids) : []

  alarm_name          = "${var.environment}-high-memory-${each.value}"
  alarm_description   = "Triggers when memory utilization exceeds ${var.memory_threshold_percent}% for ${var.memory_evaluation_periods * var.alarm_period / 60} minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.memory_evaluation_periods
  metric_name         = "mem_used_percent"
  namespace           = var.cloudwatch_namespace
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.memory_threshold_percent
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = each.value
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-high-memory-${each.value}"
      Environment = var.environment
      AlarmType   = "memory"
    }
  )
}

# CloudWatch Metric Alarms - Disk Space
resource "aws_cloudwatch_metric_alarm" "low_disk_space" {
  for_each = var.enable_instance_alarms ? toset(var.instance_ids) : []

  alarm_name          = "${var.environment}-low-disk-space-${each.value}"
  alarm_description   = "Triggers when disk space available is less than ${var.disk_free_threshold_percent}%"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.disk_evaluation_periods
  metric_name         = "disk_free_percent"
  namespace           = var.cloudwatch_namespace
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.disk_free_threshold_percent
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = each.value
    path       = var.disk_mount_path
    fstype     = var.disk_filesystem_type
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-low-disk-space-${each.value}"
      Environment = var.environment
      AlarmType   = "disk"
    }
  )
}

# CloudWatch Metric Alarms - Target Group Health
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  count = var.enable_target_group_alarms && var.target_group_arn_suffix != "" ? 1 : 0

  alarm_name          = "${var.environment}-unhealthy-host-count"
  alarm_description   = "Triggers when unhealthy host count is greater than ${var.unhealthy_host_threshold}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.unhealthy_host_evaluation_periods
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = var.alarm_period
  statistic           = "Maximum"
  threshold           = var.unhealthy_host_threshold
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.load_balancer_arn_suffix
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-unhealthy-host-count"
      Environment = var.environment
      AlarmType   = "target-group"
    }
  )
}

# CloudWatch Metric Alarms - Application Errors
resource "aws_cloudwatch_metric_alarm" "application_errors" {
  alarm_name          = "${var.environment}-application-error-rate"
  alarm_description   = "Triggers when application error rate exceeds ${var.error_rate_threshold} per minute"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.error_evaluation_periods
  metric_name         = "ErrorCount"
  namespace           = var.cloudwatch_namespace
  period              = 60
  statistic           = "Sum"
  threshold           = var.error_rate_threshold
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-application-error-rate"
      Environment = var.environment
      AlarmType   = "application"
    }
  )
}

# CloudWatch Metric Alarms - Security Events
resource "aws_cloudwatch_metric_alarm" "security_events" {
  alarm_name          = "${var.environment}-critical-security-events"
  alarm_description   = "Triggers when critical security events are detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SecurityEvents"
  namespace           = var.cloudwatch_namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-critical-security-events"
      Environment = var.environment
      AlarmType   = "security"
    }
  )
}

# EventBridge Rules for Automation
resource "aws_cloudwatch_event_rule" "instance_state_change" {
  name        = "${var.environment}-instance-state-change"
  description = "Capture EC2 instance state changes"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["stopped", "terminated", "stopping"]
    }
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-instance-state-change"
      Environment = var.environment
    }
  )
}

resource "aws_cloudwatch_event_target" "instance_state_change_sns" {
  rule      = aws_cloudwatch_event_rule.instance_state_change.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.alerts.arn

  input_transformer {
    input_paths = {
      instance = "$.detail.instance-id"
      state    = "$.detail.state"
      time     = "$.time"
    }
    input_template = "\"EC2 Instance <instance> has changed to state: <state> at <time>\""
  }
}

resource "aws_cloudwatch_event_rule" "scheduled_health_check" {
  name                = "${var.environment}-scheduled-health-check"
  description         = "Trigger automated health checks"
  schedule_expression = var.health_check_schedule
  is_enabled          = var.enable_scheduled_health_checks

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-scheduled-health-check"
      Environment = var.environment
    }
  )
}

resource "aws_cloudwatch_event_rule" "backup_trigger" {
  name                = "${var.environment}-backup-trigger"
  description         = "Trigger automated backups"
  schedule_expression = var.backup_schedule
  is_enabled          = var.enable_scheduled_backups

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-backup-trigger"
      Environment = var.environment
    }
  )
}

resource "aws_cloudwatch_event_target" "backup_trigger_sns" {
  rule      = aws_cloudwatch_event_rule.backup_trigger.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.alerts.arn

  input_transformer {
    input_paths = {
      time = "$.time"
    }
    input_template = "\"Scheduled backup triggered at <time>\""
  }
}

# X-Ray Tracing (Optional)
resource "aws_xray_sampling_rule" "fleet_sampling" {
  count = var.enable_xray ? 1 : 0

  rule_name      = "${var.environment}-fleet-sampling"
  priority       = var.xray_sampling_priority
  version        = 1
  reservoir_size = var.xray_reservoir_size
  fixed_rate     = var.xray_fixed_rate
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"

  attributes = {
    environment = var.environment
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-fleet-sampling"
      Environment = var.environment
    }
  )
}

resource "aws_xray_group" "fleet_traces" {
  count = var.enable_xray ? 1 : 0

  group_name        = "${var.environment}-fleet-traces"
  filter_expression = "service(\"${var.xray_service_name}\") { fault = true OR error = true OR responsetime > ${var.xray_response_time_threshold} }"

  insights_configuration {
    insights_enabled      = var.xray_insights_enabled
    notifications_enabled = var.xray_notifications_enabled
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-fleet-traces"
      Environment = var.environment
    }
  )
}

# CloudWatch Composite Alarms
resource "aws_cloudwatch_composite_alarm" "critical_system_health" {
  alarm_name          = "${var.environment}-critical-system-health"
  alarm_description   = "Composite alarm for critical system health issues"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  actions_suppressor {
    alarm            = aws_cloudwatch_metric_alarm.security_events.alarm_name
    extension_period = 300
    wait_period      = 60
  }

  alarm_rule = var.enable_target_group_alarms && var.target_group_arn_suffix != "" ? format(
    "ALARM(%s) OR ALARM(%s)",
    aws_cloudwatch_metric_alarm.unhealthy_hosts[0].alarm_name,
    aws_cloudwatch_metric_alarm.application_errors.alarm_name
  ) : format("ALARM(%s)", aws_cloudwatch_metric_alarm.application_errors.alarm_name)

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-critical-system-health"
      Environment = var.environment
      AlarmType   = "composite"
    }
  )
}

# Data sources
data "aws_region" "current" {}
