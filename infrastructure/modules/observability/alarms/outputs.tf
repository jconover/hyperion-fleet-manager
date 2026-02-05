# -----------------------------------------------------------------------------
# Outputs for CloudWatch Alarms Module
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# SNS Topic Outputs
# -----------------------------------------------------------------------------

output "sns_topic_arns" {
  description = "Map of SNS topic ARNs by severity level"
  value = {
    critical = aws_sns_topic.critical.arn
    warning  = aws_sns_topic.warning.arn
    info     = aws_sns_topic.info.arn
  }
}

output "sns_topic_ids" {
  description = "Map of SNS topic IDs by severity level"
  value = {
    critical = aws_sns_topic.critical.id
    warning  = aws_sns_topic.warning.id
    info     = aws_sns_topic.info.id
  }
}

output "sns_topic_names" {
  description = "Map of SNS topic names by severity level"
  value = {
    critical = aws_sns_topic.critical.name
    warning  = aws_sns_topic.warning.name
    info     = aws_sns_topic.info.name
  }
}

# Convenience output for alarm actions
output "alarm_actions_arn" {
  description = "Primary SNS topic ARN for alarm actions (critical)"
  value       = aws_sns_topic.critical.arn
}

# -----------------------------------------------------------------------------
# Alarm ARN Outputs
# -----------------------------------------------------------------------------

output "alarm_arns" {
  description = "Map of all alarm ARNs organized by type"
  value = {
    # EC2 Instance Alarms
    high_cpu = {
      for k, v in aws_cloudwatch_metric_alarm.high_cpu : k => v.arn
    }
    high_memory = {
      for k, v in aws_cloudwatch_metric_alarm.high_memory : k => v.arn
    }
    low_disk_space = {
      for k, v in aws_cloudwatch_metric_alarm.low_disk_space : k => v.arn
    }
    instance_status_check = {
      for k, v in aws_cloudwatch_metric_alarm.instance_status_check : k => v.arn
    }
    high_network_in = {
      for k, v in aws_cloudwatch_metric_alarm.high_network_in : k => v.arn
    }
    high_network_out = {
      for k, v in aws_cloudwatch_metric_alarm.high_network_out : k => v.arn
    }

    # EBS Alarms
    ebs_burst_balance = {
      for k, v in aws_cloudwatch_metric_alarm.ebs_burst_balance : k => v.arn
    }

    # Auto Scaling Alarms
    asg_unhealthy_instances = {
      for k, v in aws_cloudwatch_metric_alarm.asg_unhealthy_instances : k => v.arn
    }
    asg_capacity = {
      for k, v in aws_cloudwatch_metric_alarm.asg_capacity : k => v.arn
    }

    # SSM Alarms
    ssm_agent_disconnected = {
      for k, v in aws_cloudwatch_metric_alarm.ssm_agent_disconnected : k => v.arn
    }

    # Application Health Alarms
    application_health = {
      for k, v in aws_cloudwatch_metric_alarm.application_health : k => v.arn
    }
    target_group_health = {
      for k, v in aws_cloudwatch_metric_alarm.target_group_health : k => v.arn
    }
  }
}

output "alarm_names" {
  description = "Map of all alarm names organized by type"
  value = {
    high_cpu = {
      for k, v in aws_cloudwatch_metric_alarm.high_cpu : k => v.alarm_name
    }
    high_memory = {
      for k, v in aws_cloudwatch_metric_alarm.high_memory : k => v.alarm_name
    }
    low_disk_space = {
      for k, v in aws_cloudwatch_metric_alarm.low_disk_space : k => v.alarm_name
    }
    instance_status_check = {
      for k, v in aws_cloudwatch_metric_alarm.instance_status_check : k => v.alarm_name
    }
    high_network_in = {
      for k, v in aws_cloudwatch_metric_alarm.high_network_in : k => v.alarm_name
    }
    high_network_out = {
      for k, v in aws_cloudwatch_metric_alarm.high_network_out : k => v.alarm_name
    }
    ebs_burst_balance = {
      for k, v in aws_cloudwatch_metric_alarm.ebs_burst_balance : k => v.alarm_name
    }
    asg_unhealthy_instances = {
      for k, v in aws_cloudwatch_metric_alarm.asg_unhealthy_instances : k => v.alarm_name
    }
    asg_capacity = {
      for k, v in aws_cloudwatch_metric_alarm.asg_capacity : k => v.alarm_name
    }
    ssm_agent_disconnected = {
      for k, v in aws_cloudwatch_metric_alarm.ssm_agent_disconnected : k => v.alarm_name
    }
    application_health = {
      for k, v in aws_cloudwatch_metric_alarm.application_health : k => v.alarm_name
    }
    target_group_health = {
      for k, v in aws_cloudwatch_metric_alarm.target_group_health : k => v.alarm_name
    }
  }
}

# -----------------------------------------------------------------------------
# Composite Alarm Outputs
# -----------------------------------------------------------------------------

output "composite_alarm_arns" {
  description = "Map of composite alarm ARNs"
  value = {
    critical_infrastructure = var.enable_composite_alarms && length(var.instance_ids) > 0 ? aws_cloudwatch_composite_alarm.critical_infrastructure[0].arn : null
    performance_degradation = var.enable_composite_alarms && length(var.instance_ids) > 0 ? aws_cloudwatch_composite_alarm.performance_degradation[0].arn : null
    capacity_warning        = var.enable_composite_alarms && var.enable_disk_alarms && length(var.instance_ids) > 0 ? aws_cloudwatch_composite_alarm.capacity_warning[0].arn : null
  }
}

output "composite_alarm_names" {
  description = "Map of composite alarm names"
  value = {
    critical_infrastructure = var.enable_composite_alarms && length(var.instance_ids) > 0 ? aws_cloudwatch_composite_alarm.critical_infrastructure[0].alarm_name : null
    performance_degradation = var.enable_composite_alarms && length(var.instance_ids) > 0 ? aws_cloudwatch_composite_alarm.performance_degradation[0].alarm_name : null
    capacity_warning        = var.enable_composite_alarms && var.enable_disk_alarms && length(var.instance_ids) > 0 ? aws_cloudwatch_composite_alarm.capacity_warning[0].alarm_name : null
  }
}

# -----------------------------------------------------------------------------
# Alarm Summary Outputs
# -----------------------------------------------------------------------------

output "alarm_count" {
  description = "Count of alarms by severity"
  value = {
    critical = (
      length(aws_cloudwatch_metric_alarm.instance_status_check) +
      length(aws_cloudwatch_metric_alarm.asg_unhealthy_instances) +
      length(aws_cloudwatch_metric_alarm.asg_capacity) +
      length(aws_cloudwatch_metric_alarm.application_health) +
      length(aws_cloudwatch_metric_alarm.target_group_health)
    )
    warning = (
      length(aws_cloudwatch_metric_alarm.high_cpu) +
      length(aws_cloudwatch_metric_alarm.high_memory) +
      length(aws_cloudwatch_metric_alarm.low_disk_space) +
      length(aws_cloudwatch_metric_alarm.high_network_in) +
      length(aws_cloudwatch_metric_alarm.high_network_out) +
      length(aws_cloudwatch_metric_alarm.ebs_burst_balance) +
      length(aws_cloudwatch_metric_alarm.ssm_agent_disconnected)
    )
    composite = (
      (var.enable_composite_alarms && length(var.instance_ids) > 0 ? 2 : 0) +
      (var.enable_composite_alarms && var.enable_disk_alarms && length(var.instance_ids) > 0 ? 1 : 0)
    )
    total = (
      length(aws_cloudwatch_metric_alarm.high_cpu) +
      length(aws_cloudwatch_metric_alarm.high_memory) +
      length(aws_cloudwatch_metric_alarm.low_disk_space) +
      length(aws_cloudwatch_metric_alarm.instance_status_check) +
      length(aws_cloudwatch_metric_alarm.high_network_in) +
      length(aws_cloudwatch_metric_alarm.high_network_out) +
      length(aws_cloudwatch_metric_alarm.ebs_burst_balance) +
      length(aws_cloudwatch_metric_alarm.asg_unhealthy_instances) +
      length(aws_cloudwatch_metric_alarm.asg_capacity) +
      length(aws_cloudwatch_metric_alarm.ssm_agent_disconnected) +
      length(aws_cloudwatch_metric_alarm.application_health) +
      length(aws_cloudwatch_metric_alarm.target_group_health)
    )
  }
}

output "critical_alarm_arns" {
  description = "List of all critical alarm ARNs for easy iteration"
  value = concat(
    [for k, v in aws_cloudwatch_metric_alarm.instance_status_check : v.arn],
    [for k, v in aws_cloudwatch_metric_alarm.asg_unhealthy_instances : v.arn],
    [for k, v in aws_cloudwatch_metric_alarm.asg_capacity : v.arn],
    [for k, v in aws_cloudwatch_metric_alarm.application_health : v.arn],
    [for k, v in aws_cloudwatch_metric_alarm.target_group_health : v.arn]
  )
}

output "warning_alarm_arns" {
  description = "List of all warning alarm ARNs for easy iteration"
  value = concat(
    [for k, v in aws_cloudwatch_metric_alarm.high_cpu : v.arn],
    [for k, v in aws_cloudwatch_metric_alarm.high_memory : v.arn],
    [for k, v in aws_cloudwatch_metric_alarm.low_disk_space : v.arn],
    [for k, v in aws_cloudwatch_metric_alarm.high_network_in : v.arn],
    [for k, v in aws_cloudwatch_metric_alarm.high_network_out : v.arn],
    [for k, v in aws_cloudwatch_metric_alarm.ebs_burst_balance : v.arn],
    [for k, v in aws_cloudwatch_metric_alarm.ssm_agent_disconnected : v.arn]
  )
}

# -----------------------------------------------------------------------------
# Subscription Outputs
# -----------------------------------------------------------------------------

output "subscription_count" {
  description = "Count of subscriptions by type"
  value = {
    email_critical = length(aws_sns_topic_subscription.critical_email)
    email_warning  = length(aws_sns_topic_subscription.warning_email)
    email_info     = length(aws_sns_topic_subscription.info_email)
    sms_critical   = length(aws_sns_topic_subscription.critical_sms)
    lambda         = (var.lambda_function_arn_critical != "" ? 1 : 0) + (var.lambda_function_arn_warning != "" ? 1 : 0) + (var.lambda_function_arn_info != "" ? 1 : 0)
    https_critical = length(aws_sns_topic_subscription.critical_https)
    https_warning  = length(aws_sns_topic_subscription.warning_https)
  }
}

# -----------------------------------------------------------------------------
# Dashboard Integration Outputs
# -----------------------------------------------------------------------------

output "dashboard_widget_config" {
  description = "Configuration for CloudWatch dashboard widgets"
  value = {
    alarm_status_widget = {
      type   = "alarm"
      width  = 24
      height = 6
      properties = {
        title = "Hyperion Fleet Alarm Status"
        alarms = concat(
          [for k, v in aws_cloudwatch_metric_alarm.instance_status_check : v.arn],
          [for k, v in aws_cloudwatch_metric_alarm.high_cpu : v.arn],
          [for k, v in aws_cloudwatch_metric_alarm.asg_unhealthy_instances : v.arn]
        )
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Thresholds Output (for reference)
# -----------------------------------------------------------------------------

output "effective_thresholds" {
  description = "The effective alarm thresholds after merging with defaults"
  value = {
    cpu_percent              = lookup(var.alarm_thresholds, "cpu_percent", 80)
    memory_percent           = lookup(var.alarm_thresholds, "memory_percent", 85)
    disk_free_percent        = lookup(var.alarm_thresholds, "disk_free_percent", 15)
    network_bytes_per_second = lookup(var.alarm_thresholds, "network_bytes_per_second", 100000000)
    ebs_burst_balance        = lookup(var.alarm_thresholds, "ebs_burst_balance", 20)
    health_check_threshold   = lookup(var.alarm_thresholds, "health_check_threshold", 1)
  }
}
