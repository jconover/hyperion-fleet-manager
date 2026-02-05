# CloudWatch Alarms Module

This module creates comprehensive CloudWatch alarms with SNS notifications for monitoring the Hyperion Fleet Manager Windows server infrastructure.

## Features

- **EC2 Instance Monitoring**
  - High CPU utilization (>80% for 5 minutes)
  - High memory utilization (>85% for 5 minutes, requires CloudWatch Agent)
  - Low disk space (<15% free, requires CloudWatch Agent)
  - Instance status check failures
  - Network utilization monitoring

- **Auto Scaling Group Monitoring**
  - Unhealthy instance detection
  - Capacity threshold alarms

- **EBS Volume Monitoring**
  - Burst balance depletion warnings

- **SSM Agent Monitoring**
  - Agent connectivity status

- **Application Health Checks**
  - Custom health check metrics
  - Target group health monitoring

- **Composite Alarms**
  - Critical infrastructure alerts (multiple status check failures)
  - Performance degradation detection
  - Capacity warnings

- **SNS Notification Tiers**
  - Critical: Pages on-call engineers (email, SMS, webhooks)
  - Warning: Creates tickets (email, webhooks)
  - Info: Dashboard and logging (email)

## Usage

### Basic Example

```hcl
module "alarms" {
  source = "./modules/observability/alarms"

  environment  = "prod"
  project_name = "hyperion"

  instance_ids = [
    "i-0123456789abcdef0",
    "i-0123456789abcdef1"
  ]

  auto_scaling_group_names = ["hyperion-prod-asg"]

  notification_emails_critical = ["oncall@example.com"]
  notification_emails_warning  = ["ops-team@example.com"]

  tags = {
    Team = "Platform"
  }
}
```

### Complete Example with All Features

```hcl
module "alarms" {
  source = "./modules/observability/alarms"

  environment  = "prod"
  project_name = "hyperion"

  # EC2 Instances to monitor
  instance_ids  = ["i-0123456789abcdef0", "i-0123456789abcdef1"]
  ami_id        = "ami-0123456789abcdef0"
  instance_type = "m5.xlarge"

  # EBS Volumes
  ebs_volume_ids = ["vol-0123456789abcdef0", "vol-0123456789abcdef1"]

  # Auto Scaling Groups
  auto_scaling_group_names = ["hyperion-prod-web-asg", "hyperion-prod-api-asg"]
  asg_minimum_capacity = {
    "hyperion-prod-web-asg" = 2
    "hyperion-prod-api-asg" = 3
  }

  # Custom thresholds
  alarm_thresholds = {
    cpu_percent       = 75
    memory_percent    = 80
    disk_free_percent = 20
  }

  # Email notifications
  notification_emails_critical = ["oncall@example.com", "escalation@example.com"]
  notification_emails_warning  = ["ops-team@example.com"]
  notification_emails_info     = ["ops-dashboard@example.com"]

  # SMS for critical (E.164 format)
  notification_phone_numbers = ["+12025551234"]

  # Webhook integrations
  webhook_endpoints_critical = ["https://events.pagerduty.com/integration/xxx/enqueue"]
  webhook_endpoints_warning  = ["https://servicenow.example.com/api/now/webhooks/alert"]

  # Lambda processing
  lambda_function_arn_critical = "arn:aws:lambda:us-east-1:123456789012:function:alert-processor"

  # Application health checks
  health_check_configs = {
    "web-app" = {
      metric_name        = "HealthCheckStatus"
      namespace          = "Custom/Hyperion"
      period             = 60
      evaluation_periods = 3
      description        = "Web application health check"
      dimensions = {
        Application = "web"
        Environment = "prod"
      }
    }
  }

  # Target group monitoring
  target_group_arns = {
    "web-tg" = {
      arn_suffix               = "targetgroup/hyperion-web/1234567890123456"
      load_balancer_arn_suffix = "app/hyperion-alb/1234567890123456"
      minimum_healthy_hosts    = 2
    }
  }

  # Feature toggles
  enable_memory_alarms    = true
  enable_disk_alarms      = true
  enable_network_alarms   = true
  enable_ebs_alarms       = true
  enable_ssm_alarms       = true
  enable_composite_alarms = true

  # Encryption
  sns_kms_key_id = "alias/hyperion-sns"

  tags = {
    Team        = "Platform"
    CostCenter  = "Engineering"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| project_name | Project name for resource naming | `string` | `"hyperion"` | no |
| instance_ids | List of EC2 instance IDs to monitor | `list(string)` | `[]` | no |
| auto_scaling_group_names | List of ASG names to monitor | `list(string)` | `[]` | no |
| alarm_thresholds | Map of threshold overrides | `map(number)` | `{}` | no |
| notification_emails_critical | Critical alert email addresses | `list(string)` | `[]` | no |
| notification_emails_warning | Warning alert email addresses | `list(string)` | `[]` | no |
| notification_phone_numbers | SMS phone numbers (E.164 format) | `list(string)` | `[]` | no |
| enable_composite_alarms | Enable composite alarms | `bool` | `true` | no |

See `variables.tf` for complete list of inputs.

## Outputs

| Name | Description |
|------|-------------|
| sns_topic_arns | Map of SNS topic ARNs by severity |
| alarm_arns | Map of all alarm ARNs by type |
| alarm_actions_arn | Primary SNS topic ARN for alarm actions |
| alarm_count | Count of alarms by severity |
| composite_alarm_arns | Map of composite alarm ARNs |

See `outputs.tf` for complete list of outputs.

## CloudWatch Agent Prerequisites

For memory and disk alarms, the CloudWatch Agent must be installed and configured on Windows instances:

```json
{
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "Memory": {
        "metrics_collection_interval": 60,
        "measurement": ["% Committed Bytes In Use"]
      },
      "LogicalDisk": {
        "metrics_collection_interval": 60,
        "measurement": ["% Free Space"],
        "resources": ["C:"]
      }
    }
  }
}
```

## Alarm Severity Definitions

| Severity | Response Time | Notification Method | Use Case |
|----------|--------------|---------------------|----------|
| Critical | Immediate | SMS, Email, PagerDuty | Instance down, ASG unhealthy |
| Warning | Business hours | Email, ServiceNow | High CPU, Low disk |
| Info | No response | Dashboard only | Recovery notifications |

## treat_missing_data Settings

| Alarm Type | Setting | Rationale |
|------------|---------|-----------|
| Status Check | `breaching` | Missing data likely means instance is down |
| CPU | `breaching` | Missing data indicates monitoring issue |
| Memory/Disk | `missing` | CloudWatch Agent may not be installed |
| Network | `notBreaching` | Low traffic is normal |
| EBS Burst | `notBreaching` | Provisioned IOPS volumes don't report |

## Best Practices

1. **Start with email subscriptions** - Confirm they work before adding SMS/webhooks
2. **Use composite alarms** for reducing alert fatigue
3. **Tune thresholds** based on baseline metrics
4. **Document runbooks** for each alarm type
5. **Test alarms** using `aws cloudwatch set-alarm-state`

## Cost Considerations

- CloudWatch alarms: ~$0.10/alarm/month
- SNS notifications: First 1M requests free, then $0.50/1M
- SMS: $0.00645/message (US)

## License

MIT License - See LICENSE file in project root.
