# -----------------------------------------------------------------------------
# Hyperion Fleet Manager - CloudWatch Cost Monitoring Dashboard
# -----------------------------------------------------------------------------
# This module creates a comprehensive CloudWatch dashboard for AWS cost
# monitoring and analysis. It provides visibility into spending patterns,
# service-level costs, and budget threshold tracking.
#
# IMPORTANT: AWS Billing metrics are ONLY available in the us-east-1 region.
# This module must be deployed to us-east-1 or use a provider alias for
# us-east-1 to access billing metrics.
#
# Prerequisites:
# - Billing alerts must be enabled in AWS Billing console
# - Cost allocation tags should be configured for environment tracking
# - For multi-account: Organization Cost Explorer access required
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Local Variables for Dashboard Configuration
# -----------------------------------------------------------------------------

locals {
  # Dashboard naming convention
  dashboard_name = "${var.cost_environment}-${var.cost_project_name}-cost-monitoring"

  # Calculate budget thresholds in dollars
  warning_threshold  = var.cost_budget_amount * (var.cost_alert_thresholds.warning / 100)
  critical_threshold = var.cost_budget_amount * (var.cost_alert_thresholds.critical / 100)

  # Common tags for cost dashboard resources
  cost_dashboard_tags = merge(
    var.cost_tags,
    {
      Name        = local.dashboard_name
      Environment = var.cost_environment
      Project     = var.cost_project_name
      ManagedBy   = "terraform"
      Module      = "observability/dashboards/cost"
      Purpose     = "cost-monitoring"
    }
  )

  # Default services to track if not specified
  default_services = [
    "AmazonEC2",
    "AmazonEBS",
    "AmazonS3",
    "AmazonVPC",
    "AWSDataTransfer",
    "AmazonCloudWatch",
    "AWSSecretsManager",
    "AWSELB"
  ]

  # Services list - use provided or defaults
  tracked_services = length(var.cost_services_to_track) > 0 ? var.cost_services_to_track : local.default_services

  # Generate service cost metrics for the dashboard
  service_metrics = [
    for service in local.tracked_services : [
      "AWS/Billing",
      "EstimatedCharges",
      "ServiceName", service,
      "Currency", "USD",
      { "stat" : "Maximum", "label" : service, "period" : var.cost_metric_period }
    ]
  ]

  # Environment comparison metrics
  env_comparison_metrics = var.cost_enable_environment_comparison ? [
    for env in var.cost_environments_to_compare : [
      "AWS/Billing",
      "EstimatedCharges",
      "LinkedAccount", lookup(var.cost_environment_account_map, env, ""),
      "Currency", "USD",
      { "stat" : "Maximum", "label" : env, "period" : var.cost_metric_period }
    ]
  ] : []
}

# -----------------------------------------------------------------------------
# CloudWatch Cost Monitoring Dashboard
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "cost_monitoring" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = concat(
      # Row 1: Summary Widgets (Total Estimated Charges)
      [
        {
          type   = "metric"
          x      = 0
          y      = 0
          width  = 8
          height = 6
          properties = {
            metrics = [
              ["AWS/Billing", "EstimatedCharges", "Currency", "USD", { "stat" : "Maximum", "label" : "Total Estimated Charges" }]
            ]
            view                 = "singleValue"
            region               = "us-east-1"
            title                = "Total Estimated Monthly Charges (USD)"
            period               = var.cost_metric_period
            stat                 = "Maximum"
            setPeriodToTimeRange = true
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 0
          width  = 8
          height = 6
          properties = {
            metrics = [
              ["AWS/Billing", "EstimatedCharges", "Currency", "USD", { "stat" : "Maximum" }]
            ]
            view   = "gauge"
            region = "us-east-1"
            title  = "Budget Utilization"
            period = var.cost_metric_period
            yAxis = {
              left = {
                min = 0
                max = var.cost_budget_amount * 1.2
              }
            }
            annotations = {
              horizontal = [
                {
                  label = "Warning (${var.cost_alert_thresholds.warning}%)"
                  value = local.warning_threshold
                  color = "#ff7f0e"
                  fill  = "above"
                },
                {
                  label = "Critical (${var.cost_alert_thresholds.critical}%)"
                  value = local.critical_threshold
                  color = "#d62728"
                  fill  = "above"
                },
                {
                  label = "Budget"
                  value = var.cost_budget_amount
                  color = "#1f77b4"
                }
              ]
            }
          }
        },
        {
          type   = "text"
          x      = 16
          y      = 0
          width  = 8
          height = 6
          properties = {
            markdown = <<-EOT
              ## Cost Monitoring Dashboard

              **Environment:** ${var.cost_environment}
              **Monthly Budget:** $${var.cost_budget_amount}
              **Warning Threshold:** $${local.warning_threshold} (${var.cost_alert_thresholds.warning}%)
              **Critical Threshold:** $${local.critical_threshold} (${var.cost_alert_thresholds.critical}%)

              ---
              *Note: Billing metrics update approximately every 4 hours.*
              *Data is only available in us-east-1 region.*
            EOT
          }
        }
      ],

      # Row 2: Cost by Service Breakdown
      [
        {
          type   = "metric"
          x      = 0
          y      = 6
          width  = 12
          height = 8
          properties = {
            metrics = local.service_metrics
            view    = "timeSeries"
            stacked = true
            region  = "us-east-1"
            title   = "Cost by Service (Stacked)"
            period  = var.cost_metric_period
            yAxis = {
              left = {
                min   = 0
                label = "USD"
              }
            }
            legend = {
              position = "right"
            }
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 6
          width  = 12
          height = 8
          properties = {
            metrics              = local.service_metrics
            view                 = "pie"
            region               = "us-east-1"
            title                = "Cost Distribution by Service"
            period               = var.cost_metric_period
            setPeriodToTimeRange = true
            legend = {
              position = "right"
            }
          }
        }
      ],

      # Row 3: EC2 and Instance Type Costs
      [
        {
          type   = "metric"
          x      = 0
          y      = 14
          width  = 8
          height = 6
          properties = {
            metrics = [
              ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonEC2", "Currency", "USD", { "stat" : "Maximum", "label" : "EC2 Charges" }]
            ]
            view   = "timeSeries"
            region = "us-east-1"
            title  = "EC2 Estimated Charges"
            period = var.cost_metric_period
            yAxis = {
              left = {
                min   = 0
                label = "USD"
              }
            }
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 14
          width  = 8
          height = 6
          properties = {
            metrics = [
              for instance_type in var.cost_instance_types_to_track : [
                "AWS/EC2", "RunningSeconds",
                "InstanceType", instance_type,
                { "stat" : "Sum", "label" : instance_type, "period" : 86400 }
              ]
            ]
            view   = "bar"
            region = "us-east-1"
            title  = "Running Hours by Instance Type (Daily)"
            period = 86400
            yAxis = {
              left = {
                min   = 0
                label = "Seconds"
              }
            }
            legend = {
              position = "bottom"
            }
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 14
          width  = 8
          height = 6
          properties = {
            metrics = [
              ["AWS/EC2", "InstanceRunningMinutes", { "stat" : "Sum", "label" : "Total Running Minutes" }]
            ]
            view                 = "singleValue"
            region               = "us-east-1"
            title                = "Total EC2 Running Minutes (This Month)"
            period               = 2592000
            setPeriodToTimeRange = true
          }
        }
      ],

      # Row 4: Reserved vs On-Demand and Usage Tracking
      [
        {
          type   = "metric"
          x      = 0
          y      = 20
          width  = 8
          height = 6
          properties = {
            metrics = [
              ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonEC2", "Currency", "USD", { "stat" : "Maximum", "label" : "EC2 Total" }],
              ["AWS/EC2", "RICoveredUsageHours", { "stat" : "Sum", "label" : "RI Covered Hours", "yAxis" : "right" }],
              ["AWS/EC2", "OnDemandUsageHours", { "stat" : "Sum", "label" : "On-Demand Hours", "yAxis" : "right" }]
            ]
            view   = "timeSeries"
            region = "us-east-1"
            title  = "Reserved vs On-Demand Usage"
            period = 86400
            yAxis = {
              left = {
                min   = 0
                label = "USD"
              }
              right = {
                min   = 0
                label = "Hours"
              }
            }
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 20
          width  = 8
          height = 6
          properties = {
            metrics = [
              ["AWS/Usage", "ResourceCount", "Type", "Resource", "Resource", "OnDemand", "Service", "EC2", "Class", "None", { "stat" : "Maximum", "label" : "On-Demand Instances" }],
              ["...", "Resource", "Reserved", "...", { "stat" : "Maximum", "label" : "Reserved Instances" }],
              ["...", "Resource", "Spot", "...", { "stat" : "Maximum", "label" : "Spot Instances" }]
            ]
            view   = "timeSeries"
            region = "us-east-1"
            title  = "Instance Count by Purchase Option"
            period = 3600
            yAxis = {
              left = {
                min   = 0
                label = "Count"
              }
            }
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 20
          width  = 8
          height = 6
          properties = {
            metrics = [
              ["AWS/EC2", "RIUtilization", { "stat" : "Average", "label" : "RI Utilization %" }]
            ]
            view   = "gauge"
            region = "us-east-1"
            title  = "Reserved Instance Utilization"
            period = 86400
            yAxis = {
              left = {
                min = 0
                max = 100
              }
            }
            annotations = {
              horizontal = [
                {
                  label = "Target"
                  value = 80
                  color = "#2ca02c"
                }
              ]
            }
          }
        }
      ],

      # Row 5: Data Transfer Costs
      [
        {
          type   = "metric"
          x      = 0
          y      = 26
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/Billing", "EstimatedCharges", "ServiceName", "AWSDataTransfer", "Currency", "USD", { "stat" : "Maximum", "label" : "Data Transfer Charges" }]
            ]
            view   = "timeSeries"
            region = "us-east-1"
            title  = "Data Transfer Costs"
            period = var.cost_metric_period
            yAxis = {
              left = {
                min   = 0
                label = "USD"
              }
            }
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 26
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/EC2", "NetworkIn", { "stat" : "Sum", "label" : "Data In (Bytes)" }],
              ["AWS/EC2", "NetworkOut", { "stat" : "Sum", "label" : "Data Out (Bytes)" }]
            ]
            view   = "timeSeries"
            region = "us-east-1"
            title  = "Network Data Transfer Volume"
            period = 3600
            yAxis = {
              left = {
                min   = 0
                label = "Bytes"
              }
            }
          }
        }
      ],

      # Row 6: EBS Volume Costs
      [
        {
          type   = "metric"
          x      = 0
          y      = 32
          width  = 8
          height = 6
          properties = {
            metrics = [
              ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonEBS", "Currency", "USD", { "stat" : "Maximum", "label" : "EBS Charges" }]
            ]
            view   = "timeSeries"
            region = "us-east-1"
            title  = "EBS Volume Costs"
            period = var.cost_metric_period
            yAxis = {
              left = {
                min   = 0
                label = "USD"
              }
            }
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 32
          width  = 8
          height = 6
          properties = {
            metrics = [
              ["AWS/EBS", "VolumeReadBytes", { "stat" : "Sum", "label" : "Read Bytes" }],
              ["AWS/EBS", "VolumeWriteBytes", { "stat" : "Sum", "label" : "Write Bytes" }]
            ]
            view   = "timeSeries"
            region = "us-east-1"
            title  = "EBS I/O Volume (affects provisioned IOPS costs)"
            period = 3600
            yAxis = {
              left = {
                min   = 0
                label = "Bytes"
              }
            }
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 32
          width  = 8
          height = 6
          properties = {
            metrics = [
              ["AWS/EBS", "VolumeIdleTime", { "stat" : "Average", "label" : "Idle Time %" }]
            ]
            view   = "timeSeries"
            region = "us-east-1"
            title  = "EBS Volume Idle Time (optimization opportunity)"
            period = 3600
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
                  label = "High Idle (consider downsizing)"
                  value = 80
                  color = "#ff7f0e"
                  fill  = "above"
                }
              ]
            }
          }
        }
      ],

      # Row 7: Cost Trend Analysis
      [
        {
          type   = "metric"
          x      = 0
          y      = 38
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/Billing", "EstimatedCharges", "Currency", "USD", { "stat" : "Maximum", "label" : "Daily Trend", "period" : 86400 }]
            ]
            view   = "timeSeries"
            region = "us-east-1"
            title  = "Daily Cost Trend"
            period = 86400
            yAxis = {
              left = {
                min   = 0
                label = "USD"
              }
            }
            annotations = {
              horizontal = [
                {
                  label = "Daily Budget (${var.cost_budget_amount}/30)"
                  value = var.cost_budget_amount / 30
                  color = "#1f77b4"
                }
              ]
            }
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 38
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/Billing", "EstimatedCharges", "Currency", "USD", { "stat" : "Maximum", "label" : "Weekly Trend", "period" : 604800 }]
            ]
            view   = "timeSeries"
            region = "us-east-1"
            title  = "Weekly Cost Trend"
            period = 604800
            yAxis = {
              left = {
                min   = 0
                label = "USD"
              }
            }
            annotations = {
              horizontal = [
                {
                  label = "Weekly Budget (${var.cost_budget_amount}/4)"
                  value = var.cost_budget_amount / 4
                  color = "#1f77b4"
                }
              ]
            }
          }
        }
      ],

      # Row 8: Environment Cost Comparison (if enabled)
      var.cost_enable_environment_comparison ? [
        {
          type   = "metric"
          x      = 0
          y      = 44
          width  = 24
          height = 6
          properties = {
            metrics = [
              for env in var.cost_environments_to_compare : [
                "AWS/Billing",
                "EstimatedCharges",
                "Currency", "USD",
                { "stat" : "Maximum", "label" : "${env} Environment", "period" : var.cost_metric_period }
              ]
            ]
            view   = "bar"
            region = "us-east-1"
            title  = "Cost Comparison by Environment"
            period = var.cost_metric_period
            yAxis = {
              left = {
                min   = 0
                label = "USD"
              }
            }
            legend = {
              position = "bottom"
            }
          }
        }
      ] : [],

      # Row 9: Cost Anomaly Indicator
      [
        {
          type   = "metric"
          x      = 0
          y      = var.cost_enable_environment_comparison ? 50 : 44
          width  = 12
          height = 4
          properties = {
            metrics = [
              ["AWS/Billing", "EstimatedCharges", "Currency", "USD", { "stat" : "Maximum", "id" : "current" }],
              [{ "expression" : "ANOMALY_DETECTION_BAND(current, 2)", "label" : "Anomaly Band", "id" : "anomaly" }]
            ]
            view   = "timeSeries"
            region = "us-east-1"
            title  = "Cost Anomaly Detection"
            period = 86400
            yAxis = {
              left = {
                min   = 0
                label = "USD"
              }
            }
          }
        },
        {
          type   = "text"
          x      = 12
          y      = var.cost_enable_environment_comparison ? 50 : 44
          width  = 12
          height = 4
          properties = {
            markdown = <<-EOT
              ## Cost Optimization Tips

              - **EC2:** Consider Reserved Instances for steady-state workloads
              - **EBS:** Delete unattached volumes and old snapshots
              - **Data Transfer:** Use VPC endpoints to reduce NAT Gateway costs
              - **S3:** Review storage classes and lifecycle policies
              - **Monitoring:** Set up AWS Budgets for proactive alerts

              [View Cost Explorer](https://console.aws.amazon.com/cost-management/home#/cost-explorer)
            EOT
          }
        }
      ],

      # Row 10: S3 Storage Costs
      [
        {
          type   = "metric"
          x      = 0
          y      = var.cost_enable_environment_comparison ? 54 : 48
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonS3", "Currency", "USD", { "stat" : "Maximum", "label" : "S3 Charges" }]
            ]
            view   = "timeSeries"
            region = "us-east-1"
            title  = "S3 Storage Costs"
            period = var.cost_metric_period
            yAxis = {
              left = {
                min   = 0
                label = "USD"
              }
            }
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = var.cost_enable_environment_comparison ? 54 : 48
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/S3", "BucketSizeBytes", "StorageType", "StandardStorage", { "stat" : "Average", "label" : "Standard Storage" }],
              ["...", "StorageType", "StandardIAStorage", { "stat" : "Average", "label" : "IA Storage" }],
              ["...", "StorageType", "GlacierStorage", { "stat" : "Average", "label" : "Glacier Storage" }]
            ]
            view   = "timeSeries"
            region = "us-east-1"
            title  = "S3 Storage by Class"
            period = 86400
            yAxis = {
              left = {
                min   = 0
                label = "Bytes"
              }
            }
          }
        }
      ]
    )
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms for Budget Thresholds
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "budget_warning" {
  count = var.cost_enable_budget_alarms ? 1 : 0

  alarm_name          = "${local.dashboard_name}-budget-warning"
  alarm_description   = "Estimated charges have exceeded ${var.cost_alert_thresholds.warning}% of monthly budget ($${local.warning_threshold})"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600 # 6 hours
  statistic           = "Maximum"
  threshold           = local.warning_threshold
  alarm_actions       = var.cost_sns_topic_arn != null ? [var.cost_sns_topic_arn] : (var.cost_enable_cost_anomaly_detection ? [aws_sns_topic.cost_alerts[0].arn] : [])
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  tags = local.cost_dashboard_tags
}

resource "aws_cloudwatch_metric_alarm" "budget_critical" {
  count = var.cost_enable_budget_alarms ? 1 : 0

  alarm_name          = "${local.dashboard_name}-budget-critical"
  alarm_description   = "Estimated charges have exceeded ${var.cost_alert_thresholds.critical}% of monthly budget ($${local.critical_threshold})"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600 # 6 hours
  statistic           = "Maximum"
  threshold           = local.critical_threshold
  alarm_actions       = var.cost_sns_topic_arn != null ? [var.cost_sns_topic_arn] : (var.cost_enable_cost_anomaly_detection ? [aws_sns_topic.cost_alerts[0].arn] : [])
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  tags = local.cost_dashboard_tags
}
