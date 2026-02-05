# Observability Module

Enterprise-grade Terraform module for comprehensive AWS observability using CloudWatch, SNS, EventBridge, and X-Ray. This root module composes four specialized submodules into a unified observability solution for the Hyperion Fleet Manager.

## Features

- **CloudWatch Dashboards**: Fleet health, security, and cost monitoring visualization
- **CloudWatch Alarms**: Tiered severity alerts (critical, warning, info) with composite alarms
- **Centralized Logging**: Structured log groups with metric filters and Insights queries
- **SNS Alerting**: Multi-channel notifications (email, SMS, webhooks, Slack, PagerDuty)
- **EventBridge Rules**: Automated event routing and cross-account support
- **Lambda Processor**: Alert enrichment, PII redaction, and intelligent routing
- **Cost Monitoring**: Budget tracking, anomaly detection, and service-level analysis
- **Security Monitoring**: GuardDuty, Security Hub, CloudTrail, and VPC Flow Logs integration

## Architecture

```
                                 Observability Module
    +-------------------------------------------------------------------------+
    |                                                                         |
    |  +-------------------+     +-------------------+     +----------------+ |
    |  |    Dashboards     |     |      Alarms       |     |    Logging     | |
    |  |   Submodule       |     |    Submodule      |     |   Submodule    | |
    |  +-------------------+     +-------------------+     +----------------+ |
    |  | - Fleet Health    |     | - CPU/Memory/Disk |     | - Application  | |
    |  | - Security        |     | - Network/EBS     |     | - System       | |
    |  | - Cost            |     | - ASG/Target Grp  |     | - Security     | |
    |  |                   |     | - Composite       |     | - PowerShell   | |
    |  +--------+----------+     +--------+----------+     | - SSM/DSC      | |
    |           |                         |                +-------+--------+ |
    |           |                         |                        |          |
    |           v                         v                        v          |
    |  +----------------------------------------------------------------------+
    |  |                        Alerting Submodule                            |
    |  +----------------------------------------------------------------------+
    |  | SNS Topics (critical, warning, info, security, cost)                 |
    |  | Lambda Processor (enrichment, routing, PII redaction)                |
    |  | EventBridge Rules (GuardDuty, Config, EC2, AutoScaling, Cost)        |
    |  | SQS Queues (dead letter, aggregate)                                  |
    |  | Subscriptions (email, SMS, HTTPS/webhooks)                           |
    |  +----------------------------------------------------------------------+
    |                                                                         |
    +-------------------------------------------------------------------------+
                |                    |                    |
                v                    v                    v
         +------------+      +-------------+      +---------------+
         |   Email    |      |    Slack    |      |   PagerDuty   |
         | Recipients |      |   Channels  |      |   Escalation  |
         +------------+      +-------------+      +---------------+
```

## Submodule Relationships

```
                    +------------------+
                    |   Root Module    |
                    |   (main.tf)      |
                    +--------+---------+
                             |
         +-------------------+-------------------+
         |                   |                   |
         v                   v                   v
+----------------+  +----------------+  +----------------+
|   Alerting     |  |    Logging     |  |    Alarms      |
|   (./alerting) |  |   (./logging)  |  |   (./alarms)   |
+-------+--------+  +----------------+  +--------+-------+
        |                                        |
        |  SNS Topic ARNs                        |
        +----------------------------------------+
                             |
                             v
                    +----------------+
                    |   Dashboards   |
                    | (./dashboards) |
                    +----------------+
```

## Usage

### Basic Configuration

```hcl
module "observability" {
  source = "./modules/observability"

  environment  = "production"
  project_name = "hyperion"

  # Auto Scaling Groups to monitor
  auto_scaling_group_names = ["hyperion-web-asg", "hyperion-api-asg"]

  # Email notifications by severity
  notification_emails = {
    critical = ["oncall@example.com", "sre@example.com"]
    warning  = ["ops@example.com"]
    info     = ["monitoring@example.com"]
    security = ["security@example.com"]
    cost     = ["finops@example.com"]
  }

  tags = {
    Project     = "hyperion-fleet-manager"
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
  }
}
```

### Full Configuration

```hcl
module "observability" {
  source = "./modules/observability"

  # Required
  environment  = "production"
  project_name = "hyperion"
  aws_region   = "us-east-1"

  # Feature Flags
  enable_dashboards = true
  enable_alarms     = true
  enable_alerting   = true
  enable_logging    = true

  # Instance Monitoring
  instance_ids = [
    "i-1234567890abcdef0",
    "i-0987654321fedcba0"
  ]
  auto_scaling_group_names = ["hyperion-web-asg", "hyperion-api-asg"]
  ebs_volume_ids = ["vol-1234567890abcdef0"]

  # Notification Configuration
  notification_emails = {
    critical = ["oncall@example.com"]
    warning  = ["ops@example.com"]
    info     = ["info@example.com"]
    security = ["security@example.com"]
    cost     = ["finops@example.com"]
  }
  notification_sms      = ["+14155552671"]
  enable_security_sms   = true

  # Webhook Integrations
  webhook_endpoints = {
    critical = {
      pagerduty = "https://events.pagerduty.com/integration/xxx/enqueue"
    }
    info = {
      slack = "https://hooks.slack.com/services/xxx"
    }
  }

  # Direct Integrations
  slack_webhook_url         = "https://hooks.slack.com/services/xxx"
  pagerduty_integration_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxx"

  # Alarm Thresholds
  alarm_thresholds = {
    cpu_percent              = 80
    memory_percent           = 85
    disk_free_percent        = 15
    network_bytes_per_second = 100000000
  }

  # Logging Configuration
  log_retention_days = {
    application = 30
    system      = 60
    security    = 90
    powershell  = 90
    ssm         = 30
    dsc         = 30
  }
  enable_data_protection = true
  enable_s3_archival     = true
  archive_bucket_name    = "hyperion-logs-archive"

  # Security Dashboard
  security_guardduty_detector_id     = "1234567890abcdef1234567890abcdef"
  security_hub_enabled               = true
  security_vpc_flow_log_group_name   = "/aws/vpc/flow-logs"
  security_cloudtrail_log_group_name = "/aws/cloudtrail/logs"

  # Cost Dashboard
  cost_budget_amount               = 5000
  cost_enable_cost_anomaly_detection = true
  cost_services_to_track = [
    "AmazonEC2",
    "AmazonEBS",
    "AmazonS3",
    "AWSDataTransfer"
  ]

  # KMS Encryption
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/xxx"

  tags = {
    Project     = "hyperion-fleet-manager"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### Selective Submodule Deployment

```hcl
# Deploy only logging and alerting
module "observability_minimal" {
  source = "./modules/observability"

  environment  = "dev"
  project_name = "hyperion"

  enable_dashboards = false
  enable_alarms     = false
  enable_alerting   = true
  enable_logging    = true

  notification_emails = {
    critical = ["dev-alerts@example.com"]
  }
}
```

### Multi-Environment Pattern

```hcl
locals {
  environments = {
    dev = {
      alarm_thresholds = { cpu_percent = 90, memory_percent = 90 }
      retention_days   = { application = 7, system = 14, security = 30, powershell = 30, ssm = 7, dsc = 7 }
    }
    staging = {
      alarm_thresholds = { cpu_percent = 85, memory_percent = 85 }
      retention_days   = { application = 14, system = 30, security = 60, powershell = 60, ssm = 14, dsc = 14 }
    }
    production = {
      alarm_thresholds = { cpu_percent = 80, memory_percent = 85 }
      retention_days   = { application = 30, system = 60, security = 365, powershell = 90, ssm = 30, dsc = 30 }
    }
  }
}

module "observability" {
  for_each = local.environments
  source   = "./modules/observability"

  environment      = each.key
  project_name     = "hyperion"
  alarm_thresholds = each.value.alarm_thresholds
  log_retention_days = each.value.retention_days

  auto_scaling_group_names = ["hyperion-${each.key}-web-asg"]

  notification_emails = {
    critical = ["oncall-${each.key}@example.com"]
  }
}
```

## Input Variables

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| `environment` | Environment name (dev, staging, production, prod, uat, qa) | `string` |

### Common Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `project_name` | Project name for resource naming | `string` | `"hyperion"` |
| `aws_region` | AWS region (uses provider region if empty) | `string` | `""` |
| `tags` | Common tags to apply to all resources | `map(string)` | `{}` |

### Feature Flags

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_dashboards` | Enable CloudWatch dashboards | `bool` | `true` |
| `enable_alarms` | Enable CloudWatch metric alarms | `bool` | `true` |
| `enable_alerting` | Enable SNS alerting infrastructure | `bool` | `true` |
| `enable_logging` | Enable centralized logging | `bool` | `true` |

### Instance Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `instance_ids` | List of EC2 instance IDs to monitor | `list(string)` | `[]` |
| `auto_scaling_group_names` | List of ASG names to monitor | `list(string)` | `[]` |
| `ebs_volume_ids` | List of EBS volume IDs to monitor | `list(string)` | `[]` |

### Notification Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `notification_emails` | Map of emails by severity (critical, warning, info, security, cost) | `map(list(string))` | `{}` |
| `notification_sms` | List of phone numbers (E.164 format) | `list(string)` | `[]` |
| `webhook_endpoints` | Map of webhook URLs by severity | `map(map(string))` | `{}` |
| `slack_webhook_url` | Slack webhook URL | `string` | `null` |
| `pagerduty_integration_key` | PagerDuty integration key | `string` | `null` |

### Alarm Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `alarm_thresholds` | Map of alarm thresholds | `map(number)` | `{}` |
| `enable_memory_alarms` | Enable memory alarms | `bool` | `true` |
| `enable_disk_alarms` | Enable disk alarms | `bool` | `true` |
| `enable_network_alarms` | Enable network alarms | `bool` | `true` |
| `enable_composite_alarms` | Enable composite alarms | `bool` | `true` |

### Logging Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `log_retention_days` | Retention periods by log type | `object` | See defaults |
| `log_group_class` | Log group class (STANDARD or INFREQUENT_ACCESS) | `string` | `"STANDARD"` |
| `enable_data_protection` | Enable PII/sensitive data masking | `bool` | `false` |
| `enable_s3_archival` | Enable log archival to S3 | `bool` | `false` |
| `archive_bucket_name` | S3 bucket for log archival | `string` | `""` |

### Security Dashboard

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_security_dashboard` | Enable security dashboard | `bool` | `true` |
| `security_guardduty_detector_id` | GuardDuty detector ID | `string` | `""` |
| `security_hub_enabled` | Whether Security Hub is enabled | `bool` | `false` |
| `security_vpc_flow_log_group_name` | VPC Flow Log group name | `string` | `""` |

### Cost Dashboard

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `cost_budget_amount` | Monthly budget in USD | `number` | `1000` |
| `cost_enable_cost_anomaly_detection` | Enable cost anomaly detection | `bool` | `true` |
| `cost_services_to_track` | AWS services to track | `list(string)` | See defaults |

## Outputs

### Dashboard Outputs

| Name | Description |
|------|-------------|
| `dashboard_arns` | Map of all dashboard ARNs |
| `dashboard_urls` | Map of direct URLs to dashboards |
| `fleet_health_dashboard_url` | URL to Fleet Health dashboard |
| `security_dashboard_url` | URL to Security dashboard |
| `cost_dashboard_url` | URL to Cost dashboard |

### Alarm Outputs

| Name | Description |
|------|-------------|
| `alarm_arns` | Map of alarm ARNs by type |
| `alarm_count` | Count of alarms by severity |
| `critical_alarm_arns` | List of critical alarm ARNs |
| `composite_alarm_arns` | Map of composite alarm ARNs |

### SNS Topic Outputs

| Name | Description |
|------|-------------|
| `sns_topic_arns` | Map of SNS topic ARNs by severity |
| `critical_topic_arn` | ARN of critical alerts topic |
| `security_topic_arn` | ARN of security alerts topic |

### Log Group Outputs

| Name | Description |
|------|-------------|
| `log_group_arns` | Map of log group ARNs by type |
| `log_group_names` | Map of log group names by type |
| `cloudwatch_namespace` | CloudWatch namespace for metrics |

### Summary Output

| Name | Description |
|------|-------------|
| `observability_summary` | Consolidated summary of all resources |

## Submodule Documentation

- [Dashboards Submodule](./dashboards/README.md) - CloudWatch dashboard creation
- [Alarms Submodule](./alarms/README.md) - Metric alarm configuration
- [Logging Submodule](./logging/README.md) - Log group and metric filter management
- [Alerting Submodule](./alerting/README.md) - SNS topics, EventBridge, and Lambda processor

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 5.0 |

## Cost Considerations

### CloudWatch Costs (Estimated)
- **Dashboards**: $3.00 per dashboard/month
- **Alarms**: $0.10 per alarm/month
- **Logs Ingestion**: $0.50 per GB
- **Logs Storage**: $0.03 per GB/month
- **Metrics**: $0.30 per custom metric/month

### SNS Costs
- **Email**: First 1,000 free, then $2.00 per 100,000
- **SMS**: Varies by destination country
- **HTTPS**: $0.60 per 1 million requests

### Estimated Monthly Cost
| Component | Small (3 instances) | Medium (10 instances) | Large (50 instances) |
|-----------|---------------------|----------------------|----------------------|
| Dashboards | $9 | $9 | $9 |
| Alarms | $5 | $15 | $60 |
| Log Ingestion | $5 | $15 | $75 |
| Log Storage | $1 | $5 | $25 |
| SNS | $1 | $3 | $10 |
| **Total** | **~$21** | **~$47** | **~$179** |

## Security Best Practices

1. **Enable KMS Encryption**: Encrypt logs and SNS topics with customer-managed keys
2. **Use Data Protection**: Enable PII/sensitive data masking for logs
3. **Least Privilege**: Use IAM roles with minimal required permissions
4. **Separate Security Logs**: Longer retention for security/audit logs
5. **Enable MFA**: Require MFA for SNS subscription confirmations
6. **Audit Access**: Monitor CloudWatch and SNS API calls via CloudTrail

## Troubleshooting

### Alarms Not Triggering
1. Verify CloudWatch agent is running on instances
2. Check metric namespace matches configuration
3. Review IAM permissions for metric publishing

### No Dashboard Data
1. Ensure CloudWatch agent is configured
2. Verify metric dimensions match
3. Check agent logs: `/opt/aws/amazon-cloudwatch-agent/logs/`

### SNS Emails Not Received
1. Confirm subscriptions in SNS console
2. Check spam/junk folders
3. Verify topic policy allows publishing

## Changelog

### v2.0.0
- Refactored into composable submodules
- Added security and cost dashboards
- Implemented tiered severity alerting
- Added Lambda processor for alert enrichment
- Cross-account support for logs and events

### v1.0.0
- Initial release
- Basic CloudWatch Logs and Metrics
- SNS alerting
- EventBridge automation

## Contributing

1. Follow Terraform best practices
2. Update documentation for new features
3. Test across multiple environments
4. Validate with `terraform validate` and `tflint`

## License

This module is provided as part of the Hyperion Fleet Manager project.
