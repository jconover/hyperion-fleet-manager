# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - CloudWatch Fleet Health Dashboard
# -----------------------------------------------------------------------------
# This module creates a comprehensive CloudWatch Dashboard for monitoring
# Windows server fleet health across multiple metrics including compute,
# memory, disk, network, status checks, and Auto Scaling group capacity.
#
# Dashboard Layout (24-column grid):
# Row 0-5:   Fleet Overview (instance counts, ASG capacity summary)
# Row 6-11:  CPU Utilization (average, max, p99)
# Row 12-17: Memory Utilization (via CloudWatch agent)
# Row 18-23: Disk Utilization (by volume)
# Row 24-29: Network I/O (in/out bytes)
# Row 30-35: Status Checks (instance/system checks, SSM agent)
# Row 36-41: Auto Scaling Group Capacity Details
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  # Dashboard naming
  dashboard_name = "${var.environment}-${var.project_name}-fleet-health"

  # Common tags for all resources
  common_tags = merge(
    var.tags,
    {
      Name        = local.dashboard_name
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      Module      = "observability/dashboards"
    }
  )

  # Threshold defaults with user overrides
  thresholds = {
    cpu_percent         = var.alarm_thresholds.cpu_percent
    memory_percent      = var.alarm_thresholds.memory_percent
    disk_percent        = var.alarm_thresholds.disk_percent
    network_in_bytes    = var.alarm_thresholds.network_in_bytes
    network_out_bytes   = var.alarm_thresholds.network_out_bytes
    status_check_failed = var.alarm_thresholds.status_check_failed
  }

  # Build per-instance CPU metrics if instance_ids provided
  instance_cpu_metrics = var.enable_detailed_instance_metrics && length(var.instance_ids) > 0 ? [
    for id in var.instance_ids : [
      "AWS/EC2", "CPUUtilization", "InstanceId", id, { "label" : id }
    ]
  ] : []

  # SSM widget definition - metric type
  ssm_metric_widget = {
    type   = "metric"
    x      = 16
    y      = 30
    width  = 8
    height = 6
    properties = {
      metrics = [
        [var.ssm_namespace, "CommandsSucceeded", { stat = "Sum", label = "Commands Succeeded", color = "#2ca02c" }],
        [var.ssm_namespace, "CommandsFailed", { stat = "Sum", label = "Commands Failed", color = "#d62728" }]
      ]
      view    = "timeSeries"
      stacked = false
      region  = var.aws_region
      title   = "SSM Agent Activity"
      period  = var.metric_period_standard
      yAxis = {
        left = {
          min   = 0
          label = "Count"
        }
      }
    }
  }

  # SSM widget definition - text placeholder
  ssm_text_widget = {
    type   = "text"
    x      = 16
    y      = 30
    width  = 8
    height = 6
    properties = {
      markdown = "### SSM Status Widget Disabled\n\nEnable `enable_ssm_status_widget` to show SSM agent metrics."
    }
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard Resource
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "fleet_health" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    periodOverride = var.dashboard_refresh_interval == "auto" ? null : var.dashboard_refresh_interval
    widgets = [
      # =========================================================================
      # ROW 0: Fleet Overview Header
      # =========================================================================
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# Fleet Health Dashboard - ${upper(var.environment)} Environment\n**Project:** ${var.project_name} | **Region:** ${var.aws_region} | **Last Updated:** Auto-refresh enabled"
        }
      },

      # =========================================================================
      # ROW 1-5: Fleet Instance Count Summary
      # =========================================================================

      # Running Instances Count
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 6
        height = 5
        properties = {
          metrics = [
            for asg in var.auto_scaling_group_names : [
              "AWS/AutoScaling", "GroupInServiceInstances",
              "AutoScalingGroupName", asg,
              { stat = "Average", label = asg }
            ]
          ]
          view                 = "singleValue"
          region               = var.aws_region
          title                = "Running Instances"
          period               = var.metric_period_standard
          stat                 = "Average"
          setPeriodToTimeRange = false
        }
      },

      # Pending/Standby Instances
      {
        type   = "metric"
        x      = 6
        y      = 1
        width  = 6
        height = 5
        properties = {
          metrics = concat(
            [
              for asg in var.auto_scaling_group_names : [
                "AWS/AutoScaling", "GroupPendingInstances",
                "AutoScalingGroupName", asg,
                { stat = "Average", label = "${asg} Pending" }
              ]
            ],
            [
              for asg in var.auto_scaling_group_names : [
                "AWS/AutoScaling", "GroupStandbyInstances",
                "AutoScalingGroupName", asg,
                { stat = "Average", label = "${asg} Standby" }
              ]
            ]
          )
          view                 = "singleValue"
          region               = var.aws_region
          title                = "Pending/Standby Instances"
          period               = var.metric_period_standard
          setPeriodToTimeRange = false
        }
      },

      # Terminating Instances
      {
        type   = "metric"
        x      = 12
        y      = 1
        width  = 6
        height = 5
        properties = {
          metrics = [
            for asg in var.auto_scaling_group_names : [
              "AWS/AutoScaling", "GroupTerminatingInstances",
              "AutoScalingGroupName", asg,
              { stat = "Average", label = asg, color = "#d62728" }
            ]
          ]
          view                 = "singleValue"
          region               = var.aws_region
          title                = "Terminating Instances"
          period               = var.metric_period_standard
          setPeriodToTimeRange = false
        }
      },

      # Total Desired Capacity
      {
        type   = "metric"
        x      = 18
        y      = 1
        width  = 6
        height = 5
        properties = {
          metrics = [
            for asg in var.auto_scaling_group_names : [
              "AWS/AutoScaling", "GroupDesiredCapacity",
              "AutoScalingGroupName", asg,
              { stat = "Average", label = asg }
            ]
          ]
          view                 = "singleValue"
          region               = var.aws_region
          title                = "Desired Capacity"
          period               = var.metric_period_standard
          setPeriodToTimeRange = false
        }
      },

      # =========================================================================
      # ROW 6-11: CPU Utilization
      # =========================================================================

      # CPU Utilization - Time Series (Avg, Max, P99)
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 16
        height = 6
        properties = {
          metrics = concat(
            # Aggregate metrics across all instances
            [
              ["AWS/EC2", "CPUUtilization", { stat = "Average", label = "Avg CPU", color = "#2ca02c" }],
              ["AWS/EC2", "CPUUtilization", { stat = "Maximum", label = "Max CPU", color = "#d62728" }],
              ["AWS/EC2", "CPUUtilization", { stat = "p99", label = "P99 CPU", color = "#ff7f0e" }]
            ],
            # Per-instance metrics if enabled
            local.instance_cpu_metrics
          )
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "CPU Utilization Across Fleet"
          period  = var.metric_period_detailed
          yAxis = {
            left = {
              min   = 0
              max   = 100
              label = "Percent"
            }
          }
          annotations = {
            horizontal = [
              {
                label = "High CPU Threshold"
                value = local.thresholds.cpu_percent
                fill  = "above"
                color = "#d62728"
              }
            ]
          }
        }
      },

      # CPU Utilization - Gauge
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average" }]
          ]
          view   = "gauge"
          region = var.aws_region
          title  = "Current Avg CPU"
          period = var.metric_period_detailed
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
          annotations = {
            horizontal = [
              { value = local.thresholds.cpu_percent, color = "#d62728" }
            ]
          }
        }
      },

      # =========================================================================
      # ROW 12-17: Memory Utilization (CloudWatch Agent)
      # =========================================================================

      # Memory Utilization - Time Series
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 16
        height = 6
        properties = {
          metrics = [
            [var.cloudwatch_namespace, "Memory % Committed Bytes In Use", { stat = "Average", label = "Avg Memory", color = "#1f77b4" }],
            [var.cloudwatch_namespace, "Memory % Committed Bytes In Use", { stat = "Maximum", label = "Max Memory", color = "#d62728" }],
            [var.cloudwatch_namespace, "Memory % Committed Bytes In Use", { stat = "p99", label = "P99 Memory", color = "#ff7f0e" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Memory Utilization (via CloudWatch Agent)"
          period  = var.metric_period_standard
          yAxis = {
            left = {
              min   = 0
              max   = 100
              label = "Percent"
            }
          }
          annotations = {
            horizontal = [
              {
                label = "High Memory Threshold"
                value = local.thresholds.memory_percent
                fill  = "above"
                color = "#d62728"
              }
            ]
          }
        }
      },

      # Memory Available - Single Value
      {
        type   = "metric"
        x      = 16
        y      = 12
        width  = 8
        height = 6
        properties = {
          metrics = [
            [var.cloudwatch_namespace, "Memory Available MBytes", { stat = "Average", label = "Available MB" }]
          ]
          view                 = "singleValue"
          region               = var.aws_region
          title                = "Avg Available Memory (MB)"
          period               = var.metric_period_standard
          setPeriodToTimeRange = false
        }
      },

      # =========================================================================
      # ROW 18-23: Disk Utilization by Volume
      # =========================================================================

      # Disk Free Space - Time Series
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = [
            for path in var.disk_mount_paths : [
              var.cloudwatch_namespace, "LogicalDisk % Free Space",
              "instance", path,
              { stat = "Average", label = "Free Space ${path}" }
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Disk Free Space by Mount"
          period  = var.metric_period_standard
          yAxis = {
            left = {
              min   = 0
              max   = 100
              label = "Percent Free"
            }
          }
          annotations = {
            horizontal = [
              {
                label = "Low Disk Space Warning"
                value = 100 - local.thresholds.disk_percent
                fill  = "below"
                color = "#d62728"
              }
            ]
          }
        }
      },

      # Disk Read/Write Bytes - EBS
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = length(var.ebs_volume_ids) > 0 ? concat(
            [
              for vol in var.ebs_volume_ids : [
                "AWS/EBS", "VolumeReadBytes",
                "VolumeId", vol,
                { stat = "Sum", label = "Read ${vol}" }
              ]
            ],
            [
              for vol in var.ebs_volume_ids : [
                "AWS/EBS", "VolumeWriteBytes",
                "VolumeId", vol,
                { stat = "Sum", label = "Write ${vol}" }
              ]
            ]
            ) : [
            ["AWS/EC2", "EBSReadBytes", { stat = "Sum", label = "EBS Read", color = "#2ca02c" }],
            ["AWS/EC2", "EBSWriteBytes", { stat = "Sum", label = "EBS Write", color = "#1f77b4" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Disk I/O (Bytes)"
          period  = var.metric_period_standard
          yAxis = {
            left = {
              min   = 0
              label = "Bytes"
            }
          }
        }
      },

      # =========================================================================
      # ROW 24-29: Network In/Out Bytes
      # =========================================================================

      # Network In - Time Series
      {
        type   = "metric"
        x      = 0
        y      = 24
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", { stat = "Sum", label = "Total Network In", color = "#2ca02c" }],
            ["AWS/EC2", "NetworkIn", { stat = "Average", label = "Avg Network In", color = "#1f77b4" }],
            ["AWS/EC2", "NetworkIn", { stat = "Maximum", label = "Max Network In", color = "#ff7f0e" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Network Ingress (Bytes)"
          period  = var.metric_period_standard
          yAxis = {
            left = {
              min   = 0
              label = "Bytes"
            }
          }
          annotations = {
            horizontal = [
              {
                label   = "High Traffic Threshold"
                value   = local.thresholds.network_in_bytes
                fill    = "above"
                color   = "#ff7f0e"
                visible = true
              }
            ]
          }
        }
      },

      # Network Out - Time Series
      {
        type   = "metric"
        x      = 12
        y      = 24
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkOut", { stat = "Sum", label = "Total Network Out", color = "#9467bd" }],
            ["AWS/EC2", "NetworkOut", { stat = "Average", label = "Avg Network Out", color = "#8c564b" }],
            ["AWS/EC2", "NetworkOut", { stat = "Maximum", label = "Max Network Out", color = "#d62728" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Network Egress (Bytes)"
          period  = var.metric_period_standard
          yAxis = {
            left = {
              min   = 0
              label = "Bytes"
            }
          }
          annotations = {
            horizontal = [
              {
                label   = "High Traffic Threshold"
                value   = local.thresholds.network_out_bytes
                fill    = "above"
                color   = "#ff7f0e"
                visible = true
              }
            ]
          }
        }
      },

      # =========================================================================
      # ROW 30-35: Instance Status Checks
      # =========================================================================

      # Status Check Failed - Time Series
      {
        type   = "metric"
        x      = 0
        y      = 30
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", { stat = "Sum", label = "Total Failed", color = "#d62728" }],
            ["AWS/EC2", "StatusCheckFailed_Instance", { stat = "Sum", label = "Instance Check Failed", color = "#ff7f0e" }],
            ["AWS/EC2", "StatusCheckFailed_System", { stat = "Sum", label = "System Check Failed", color = "#9467bd" }]
          ]
          view    = "timeSeries"
          stacked = true
          region  = var.aws_region
          title   = "Status Check Failures"
          period  = var.metric_period_detailed
          yAxis = {
            left = {
              min   = 0
              label = "Count"
            }
          }
          annotations = {
            horizontal = [
              {
                label = "Failure Threshold"
                value = local.thresholds.status_check_failed
                fill  = "above"
                color = "#d62728"
              }
            ]
          }
        }
      },

      # Status Check Passed - Current Count
      {
        type   = "metric"
        x      = 8
        y      = 30
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", { stat = "Sum", label = "Failed Checks" }]
          ]
          view                 = "singleValue"
          region               = var.aws_region
          title                = "Current Failed Status Checks"
          period               = var.metric_period_detailed
          setPeriodToTimeRange = false
        }
      },

      # SSM Agent Status - Using local conditional
      var.enable_ssm_status_widget ? local.ssm_metric_widget : local.ssm_text_widget,

      # =========================================================================
      # ROW 36-41: Auto Scaling Group Capacity Details
      # =========================================================================

      # ASG Capacity Over Time
      {
        type   = "metric"
        x      = 0
        y      = 36
        width  = 16
        height = 6
        properties = {
          metrics = concat(
            [
              for asg in var.auto_scaling_group_names : [
                "AWS/AutoScaling", "GroupDesiredCapacity",
                "AutoScalingGroupName", asg,
                { stat = "Average", label = "${asg} Desired" }
              ]
            ],
            [
              for asg in var.auto_scaling_group_names : [
                "AWS/AutoScaling", "GroupInServiceInstances",
                "AutoScalingGroupName", asg,
                { stat = "Average", label = "${asg} In Service" }
              ]
            ],
            [
              for asg in var.auto_scaling_group_names : [
                "AWS/AutoScaling", "GroupMaxSize",
                "AutoScalingGroupName", asg,
                { stat = "Average", label = "${asg} Max", visible = false }
              ]
            ],
            [
              for asg in var.auto_scaling_group_names : [
                "AWS/AutoScaling", "GroupMinSize",
                "AutoScalingGroupName", asg,
                { stat = "Average", label = "${asg} Min", visible = false }
              ]
            ]
          )
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Auto Scaling Group Capacity"
          period  = var.metric_period_standard
          yAxis = {
            left = {
              min   = 0
              label = "Instance Count"
            }
          }
        }
      },

      # ASG Summary Table
      {
        type   = "metric"
        x      = 16
        y      = 36
        width  = 8
        height = 6
        properties = {
          metrics = [
            for asg in var.auto_scaling_group_names : [
              "AWS/AutoScaling", "GroupTotalInstances",
              "AutoScalingGroupName", asg,
              { stat = "Average", label = asg }
            ]
          ]
          view                 = "singleValue"
          region               = var.aws_region
          title                = "Total Instances per ASG"
          period               = var.metric_period_standard
          setPeriodToTimeRange = false
        }
      },

      # =========================================================================
      # ROW 42: Footer
      # =========================================================================
      {
        type   = "text"
        x      = 0
        y      = 42
        width  = 24
        height = 1
        properties = {
          markdown = "---\n**Hyperion Fleet Manager** | Dashboard managed by Terraform | Thresholds: CPU ${local.thresholds.cpu_percent}%, Memory ${local.thresholds.memory_percent}%, Disk ${local.thresholds.disk_percent}%"
        }
      }
    ]
  })
}
