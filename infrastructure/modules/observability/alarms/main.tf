# -----------------------------------------------------------------------------
# CloudWatch Alarms for Hyperion Fleet Manager
# -----------------------------------------------------------------------------
# This module creates comprehensive CloudWatch alarms for monitoring
# Windows server fleet health, performance, and availability.
# -----------------------------------------------------------------------------

locals {
  # Common alarm naming convention
  alarm_name_prefix = "${var.project_name}-${var.environment}"

  # Default thresholds with user overrides
  thresholds = merge(
    {
      cpu_percent              = 80
      memory_percent           = 85
      disk_free_percent        = 15
      network_bytes_per_second = 100000000 # 100 MB/s
      ebs_burst_balance        = 20
      health_check_threshold   = 1
    },
    var.alarm_thresholds
  )

  # Common tags for all alarm resources
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      Module      = "observability/alarms"
    }
  )
}

# -----------------------------------------------------------------------------
# EC2 Instance Alarms
# -----------------------------------------------------------------------------

# High CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  for_each = toset(var.instance_ids)

  alarm_name          = "${local.alarm_name_prefix}-high-cpu-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods.cpu
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.period_seconds.cpu
  statistic           = "Average"
  threshold           = local.thresholds.cpu_percent
  alarm_description   = "CPU utilization exceeded ${local.thresholds.cpu_percent}% for ${var.evaluation_periods.cpu * var.period_seconds.cpu / 60} minutes on instance ${each.value}"
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = each.value
  }

  alarm_actions             = [aws_sns_topic.warning.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = [aws_sns_topic.info.arn]

  tags = merge(
    local.common_tags,
    {
      Name       = "${local.alarm_name_prefix}-high-cpu-${each.value}"
      AlarmType  = "performance"
      Severity   = "warning"
      InstanceId = each.value
    }
  )
}

# High Memory Utilization Alarm (requires CloudWatch Agent)
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  for_each = var.enable_memory_alarms ? toset(var.instance_ids) : toset([])

  alarm_name          = "${local.alarm_name_prefix}-high-memory-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods.memory
  metric_name         = "Memory % Committed Bytes In Use"
  namespace           = "CWAgent"
  period              = var.period_seconds.memory
  statistic           = "Average"
  threshold           = local.thresholds.memory_percent
  alarm_description   = "Memory utilization exceeded ${local.thresholds.memory_percent}% for ${var.evaluation_periods.memory * var.period_seconds.memory / 60} minutes on instance ${each.value}"
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId   = each.value
    objectname   = "Memory"
    ImageId      = var.ami_id
    InstanceType = var.instance_type
  }

  alarm_actions             = [aws_sns_topic.warning.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = [aws_sns_topic.warning.arn]

  tags = merge(
    local.common_tags,
    {
      Name       = "${local.alarm_name_prefix}-high-memory-${each.value}"
      AlarmType  = "performance"
      Severity   = "warning"
      InstanceId = each.value
    }
  )
}

# Low Disk Space Alarm (requires CloudWatch Agent)
resource "aws_cloudwatch_metric_alarm" "low_disk_space" {
  for_each = var.enable_disk_alarms ? toset(var.instance_ids) : toset([])

  alarm_name          = "${local.alarm_name_prefix}-low-disk-${each.value}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.evaluation_periods.disk
  metric_name         = "LogicalDisk % Free Space"
  namespace           = "CWAgent"
  period              = var.period_seconds.disk
  statistic           = "Average"
  threshold           = local.thresholds.disk_free_percent
  alarm_description   = "Disk free space below ${local.thresholds.disk_free_percent}% for ${var.evaluation_periods.disk * var.period_seconds.disk / 60} minutes on instance ${each.value}"
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = each.value
    objectname = "LogicalDisk"
    instance   = "C:"
  }

  alarm_actions             = [aws_sns_topic.warning.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = [aws_sns_topic.warning.arn]

  tags = merge(
    local.common_tags,
    {
      Name       = "${local.alarm_name_prefix}-low-disk-${each.value}"
      AlarmType  = "capacity"
      Severity   = "warning"
      InstanceId = each.value
    }
  )
}

# Instance Status Check Failed Alarm
resource "aws_cloudwatch_metric_alarm" "instance_status_check" {
  for_each = toset(var.instance_ids)

  alarm_name          = "${local.alarm_name_prefix}-status-check-${each.value}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Instance status check failed on ${each.value}. This indicates a problem with the underlying host or instance."
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = each.value
  }

  alarm_actions             = [aws_sns_topic.critical.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = [aws_sns_topic.critical.arn]

  tags = merge(
    local.common_tags,
    {
      Name       = "${local.alarm_name_prefix}-status-check-${each.value}"
      AlarmType  = "availability"
      Severity   = "critical"
      InstanceId = each.value
    }
  )
}

# High Network Utilization Alarm (Network In)
resource "aws_cloudwatch_metric_alarm" "high_network_in" {
  for_each = var.enable_network_alarms ? toset(var.instance_ids) : toset([])

  alarm_name          = "${local.alarm_name_prefix}-high-network-in-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods.network
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period              = var.period_seconds.network
  statistic           = "Average"
  threshold           = local.thresholds.network_bytes_per_second
  alarm_description   = "Network ingress exceeded ${local.thresholds.network_bytes_per_second / 1000000} MB/s on instance ${each.value}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = each.value
  }

  alarm_actions             = [aws_sns_topic.warning.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = []

  tags = merge(
    local.common_tags,
    {
      Name       = "${local.alarm_name_prefix}-high-network-in-${each.value}"
      AlarmType  = "performance"
      Severity   = "warning"
      InstanceId = each.value
    }
  )
}

# High Network Utilization Alarm (Network Out)
resource "aws_cloudwatch_metric_alarm" "high_network_out" {
  for_each = var.enable_network_alarms ? toset(var.instance_ids) : toset([])

  alarm_name          = "${local.alarm_name_prefix}-high-network-out-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods.network
  metric_name         = "NetworkOut"
  namespace           = "AWS/EC2"
  period              = var.period_seconds.network
  statistic           = "Average"
  threshold           = local.thresholds.network_bytes_per_second
  alarm_description   = "Network egress exceeded ${local.thresholds.network_bytes_per_second / 1000000} MB/s on instance ${each.value}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = each.value
  }

  alarm_actions             = [aws_sns_topic.warning.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = []

  tags = merge(
    local.common_tags,
    {
      Name       = "${local.alarm_name_prefix}-high-network-out-${each.value}"
      AlarmType  = "performance"
      Severity   = "warning"
      InstanceId = each.value
    }
  )
}

# EBS Burst Balance Low Alarm
resource "aws_cloudwatch_metric_alarm" "ebs_burst_balance" {
  for_each = var.enable_ebs_alarms ? toset(var.ebs_volume_ids) : toset([])

  alarm_name          = "${local.alarm_name_prefix}-ebs-burst-balance-${each.value}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.evaluation_periods.ebs
  metric_name         = "BurstBalance"
  namespace           = "AWS/EBS"
  period              = var.period_seconds.ebs
  statistic           = "Average"
  threshold           = local.thresholds.ebs_burst_balance
  alarm_description   = "EBS burst balance below ${local.thresholds.ebs_burst_balance}% on volume ${each.value}. Consider upgrading to a larger volume or provisioned IOPS."
  treat_missing_data  = "notBreaching"

  dimensions = {
    VolumeId = each.value
  }

  alarm_actions             = [aws_sns_topic.warning.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = []

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.alarm_name_prefix}-ebs-burst-balance-${each.value}"
      AlarmType = "performance"
      Severity  = "warning"
      VolumeId  = each.value
    }
  )
}

# -----------------------------------------------------------------------------
# Auto Scaling Group Alarms
# -----------------------------------------------------------------------------

# ASG Unhealthy Instances Alarm
resource "aws_cloudwatch_metric_alarm" "asg_unhealthy_instances" {
  for_each = toset(var.auto_scaling_group_names)

  alarm_name          = "${local.alarm_name_prefix}-asg-unhealthy-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/AutoScaling"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Auto Scaling group ${each.value} has unhealthy instances"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = each.value
  }

  alarm_actions             = [aws_sns_topic.critical.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = []

  tags = merge(
    local.common_tags,
    {
      Name                 = "${local.alarm_name_prefix}-asg-unhealthy-${each.value}"
      AlarmType            = "availability"
      Severity             = "critical"
      AutoScalingGroupName = each.value
    }
  )
}

# ASG Group In-Service Instances Alarm (below minimum)
resource "aws_cloudwatch_metric_alarm" "asg_capacity" {
  for_each = var.asg_minimum_capacity

  alarm_name          = "${local.alarm_name_prefix}-asg-capacity-${each.key}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = 60
  statistic           = "Average"
  threshold           = each.value
  alarm_description   = "Auto Scaling group ${each.key} has fewer than ${each.value} in-service instances"
  treat_missing_data  = "breaching"

  dimensions = {
    AutoScalingGroupName = each.key
  }

  alarm_actions             = [aws_sns_topic.critical.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = [aws_sns_topic.warning.arn]

  tags = merge(
    local.common_tags,
    {
      Name                 = "${local.alarm_name_prefix}-asg-capacity-${each.key}"
      AlarmType            = "availability"
      Severity             = "critical"
      AutoScalingGroupName = each.key
    }
  )
}

# -----------------------------------------------------------------------------
# SSM Agent Alarms
# -----------------------------------------------------------------------------

# SSM Agent Disconnected Alarm
resource "aws_cloudwatch_metric_alarm" "ssm_agent_disconnected" {
  for_each = var.enable_ssm_alarms ? toset(var.instance_ids) : toset([])

  alarm_name          = "${local.alarm_name_prefix}-ssm-disconnected-${each.value}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "SSMAgentStatus"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "SSM Agent appears disconnected on instance ${each.value}. Instance may be unreachable for management operations."
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = each.value
  }

  alarm_actions             = [aws_sns_topic.warning.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = [aws_sns_topic.warning.arn]

  tags = merge(
    local.common_tags,
    {
      Name       = "${local.alarm_name_prefix}-ssm-disconnected-${each.value}"
      AlarmType  = "connectivity"
      Severity   = "warning"
      InstanceId = each.value
    }
  )
}

# -----------------------------------------------------------------------------
# Application Health Check Alarms
# -----------------------------------------------------------------------------

# Application Health Check Failed Alarm
resource "aws_cloudwatch_metric_alarm" "application_health" {
  for_each = var.health_check_configs

  alarm_name          = "${local.alarm_name_prefix}-app-health-${each.key}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = "Average"
  threshold           = local.thresholds.health_check_threshold
  alarm_description   = "Application health check failed for ${each.key}: ${each.value.description}"
  treat_missing_data  = "breaching"

  dimensions = each.value.dimensions

  alarm_actions             = [aws_sns_topic.critical.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = [aws_sns_topic.critical.arn]

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.alarm_name_prefix}-app-health-${each.key}"
      AlarmType   = "availability"
      Severity    = "critical"
      Application = each.key
    }
  )
}

# Target Group Healthy Host Count Alarm
resource "aws_cloudwatch_metric_alarm" "target_group_health" {
  for_each = var.target_group_arns

  alarm_name          = "${local.alarm_name_prefix}-tg-health-${each.key}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = each.value.minimum_healthy_hosts
  alarm_description   = "Target group ${each.key} has fewer than ${each.value.minimum_healthy_hosts} healthy hosts"
  treat_missing_data  = "breaching"

  dimensions = {
    TargetGroup  = each.value.arn_suffix
    LoadBalancer = each.value.load_balancer_arn_suffix
  }

  alarm_actions             = [aws_sns_topic.critical.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = [aws_sns_topic.critical.arn]

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.alarm_name_prefix}-tg-health-${each.key}"
      AlarmType   = "availability"
      Severity    = "critical"
      TargetGroup = each.key
    }
  )
}

# -----------------------------------------------------------------------------
# Composite Alarms
# -----------------------------------------------------------------------------

# Critical Infrastructure Composite Alarm
# Triggers when multiple critical conditions are met simultaneously
resource "aws_cloudwatch_composite_alarm" "critical_infrastructure" {
  count = var.enable_composite_alarms && length(var.instance_ids) > 0 ? 1 : 0

  alarm_name        = "${local.alarm_name_prefix}-critical-infrastructure"
  alarm_description = "Critical infrastructure alarm - multiple systems in alarm state indicating potential widespread issue"

  # Alarm rule: triggers when 2 or more status check alarms are in ALARM state
  alarm_rule = join(" OR ", [
    for instance_id in var.instance_ids :
    "ALARM(${aws_cloudwatch_metric_alarm.instance_status_check[instance_id].alarm_name})"
  ])

  alarm_actions             = [aws_sns_topic.critical.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = [aws_sns_topic.warning.arn]

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.alarm_name_prefix}-critical-infrastructure"
      AlarmType = "composite"
      Severity  = "critical"
    }
  )

  depends_on = [aws_cloudwatch_metric_alarm.instance_status_check]
}

# Performance Degradation Composite Alarm
# Triggers when multiple performance metrics indicate issues
resource "aws_cloudwatch_composite_alarm" "performance_degradation" {
  count = var.enable_composite_alarms && length(var.instance_ids) > 0 ? 1 : 0

  alarm_name        = "${local.alarm_name_prefix}-performance-degradation"
  alarm_description = "Performance degradation detected across fleet - investigate for root cause"

  # Alarm rule: triggers when multiple CPU alarms are in ALARM state
  alarm_rule = join(" OR ", [
    for instance_id in var.instance_ids :
    "ALARM(${aws_cloudwatch_metric_alarm.high_cpu[instance_id].alarm_name})"
  ])

  alarm_actions             = [aws_sns_topic.warning.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = []

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.alarm_name_prefix}-performance-degradation"
      AlarmType = "composite"
      Severity  = "warning"
    }
  )

  depends_on = [aws_cloudwatch_metric_alarm.high_cpu]
}

# Capacity Warning Composite Alarm
# Triggers when capacity-related metrics indicate potential exhaustion
resource "aws_cloudwatch_composite_alarm" "capacity_warning" {
  count = var.enable_composite_alarms && var.enable_disk_alarms && length(var.instance_ids) > 0 ? 1 : 0

  alarm_name        = "${local.alarm_name_prefix}-capacity-warning"
  alarm_description = "Capacity warning - disk space or other resources running low across multiple instances"

  # Alarm rule: triggers when disk space alarms are active
  alarm_rule = join(" OR ", [
    for instance_id in var.instance_ids :
    "ALARM(${aws_cloudwatch_metric_alarm.low_disk_space[instance_id].alarm_name})"
  ])

  alarm_actions             = [aws_sns_topic.warning.arn]
  ok_actions                = [aws_sns_topic.info.arn]
  insufficient_data_actions = []

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.alarm_name_prefix}-capacity-warning"
      AlarmType = "composite"
      Severity  = "warning"
    }
  )

  depends_on = [aws_cloudwatch_metric_alarm.low_disk_space]
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard Widget Data
# -----------------------------------------------------------------------------

# This local outputs alarm information for use in dashboards
locals {
  alarm_summary = {
    critical_alarms = concat(
      [for k, v in aws_cloudwatch_metric_alarm.instance_status_check : v.arn],
      [for k, v in aws_cloudwatch_metric_alarm.asg_unhealthy_instances : v.arn],
      [for k, v in aws_cloudwatch_metric_alarm.asg_capacity : v.arn],
      [for k, v in aws_cloudwatch_metric_alarm.application_health : v.arn],
      [for k, v in aws_cloudwatch_metric_alarm.target_group_health : v.arn]
    )
    warning_alarms = concat(
      [for k, v in aws_cloudwatch_metric_alarm.high_cpu : v.arn],
      [for k, v in aws_cloudwatch_metric_alarm.high_memory : v.arn],
      [for k, v in aws_cloudwatch_metric_alarm.low_disk_space : v.arn],
      [for k, v in aws_cloudwatch_metric_alarm.high_network_in : v.arn],
      [for k, v in aws_cloudwatch_metric_alarm.high_network_out : v.arn],
      [for k, v in aws_cloudwatch_metric_alarm.ebs_burst_balance : v.arn],
      [for k, v in aws_cloudwatch_metric_alarm.ssm_agent_disconnected : v.arn]
    )
  }
}
