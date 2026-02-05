# Observability Module

Production-ready Terraform module for comprehensive AWS observability using CloudWatch, SNS, EventBridge, and X-Ray.

## Features

- **CloudWatch Log Groups**: Structured logging for system, application, and security events
- **CloudWatch Dashboards**: Fleet health overview with real-time metrics visualization
- **CloudWatch Metric Alarms**: Proactive alerting for CPU, memory, disk, and application health
- **SNS Notifications**: Email alerts for critical events
- **EventBridge Rules**: Automation triggers for instance state changes, health checks, and backups
- **X-Ray Tracing**: Optional distributed tracing for request analysis (optional)
- **Composite Alarms**: Advanced alarm logic for complex failure scenarios

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     CloudWatch Observability                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Log Groups                  Metrics & Alarms                   │
│  ┌──────────────────┐       ┌──────────────────┐              │
│  │ /hyperion/fleet/ │       │ CPU > 80%        │              │
│  │   - system       │       │ Memory > 85%     │              │
│  │   - application  │◄─────►│ Disk < 15%       │              │
│  │   - security     │       │ UnhealthyHosts   │              │
│  └──────────────────┘       │ Error Rate       │              │
│           │                  └──────────────────┘              │
│           │                           │                         │
│           ▼                           ▼                         │
│  ┌──────────────────┐       ┌──────────────────┐              │
│  │ Metric Filters   │       │  SNS Topic       │              │
│  │ - Error Count    │       │  - Email Alerts  │              │
│  │ - Security Events│       └──────────────────┘              │
│  └──────────────────┘                                          │
│                                                                  │
│  EventBridge Rules           Dashboard                          │
│  ┌──────────────────┐       ┌──────────────────┐              │
│  │ Instance States  │       │ Fleet Health     │              │
│  │ Health Checks    │       │ - CPU/Memory     │              │
│  │ Backup Triggers  │       │ - Network/Disk   │              │
│  └──────────────────┘       │ - Response Times │              │
│                              └──────────────────┘              │
│                                                                  │
│  X-Ray (Optional)                                               │
│  ┌──────────────────┐                                          │
│  │ Trace Groups     │                                          │
│  │ Sampling Rules   │                                          │
│  │ Insights         │                                          │
│  └──────────────────┘                                          │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Configuration

```hcl
module "observability" {
  source = "./modules/observability"

  environment = "production"

  alert_email_addresses = [
    "ops-team@example.com",
    "platform-team@example.com"
  ]

  instance_ids = [
    "i-1234567890abcdef0",
    "i-0987654321fedcba0"
  ]

  target_group_arn_suffix  = "targetgroup/fleet-tg/1234567890abcdef"
  load_balancer_arn_suffix = "app/fleet-alb/1234567890abcdef"

  tags = {
    Project     = "fleet-manager"
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
  }
}
```

### Advanced Configuration with Custom Thresholds

```hcl
module "observability" {
  source = "./modules/observability"

  environment = "production"

  # SNS Configuration
  alert_email_addresses = [
    "ops-team@example.com",
    "platform-team@example.com"
  ]

  # Instance Monitoring
  instance_ids           = var.instance_ids
  enable_instance_alarms = true

  # Custom Alarm Thresholds
  cpu_threshold_percent    = 75
  cpu_evaluation_periods   = 4  # 20 minutes at 5-min periods

  memory_threshold_percent = 80
  memory_evaluation_periods = 3  # 15 minutes

  disk_free_threshold_percent = 20
  disk_evaluation_periods     = 2  # 10 minutes

  unhealthy_host_threshold           = 1
  unhealthy_host_evaluation_periods  = 3

  error_rate_threshold     = 5
  error_evaluation_periods = 3

  # Target Group Monitoring
  target_group_arn_suffix    = var.target_group_arn_suffix
  load_balancer_arn_suffix   = var.load_balancer_arn_suffix
  enable_target_group_alarms = true

  # Log Configuration
  log_retention_days          = 90
  security_log_retention_days = 365
  kms_key_id                  = aws_kms_key.logs.id

  # CloudWatch Configuration
  cloudwatch_namespace = "FleetManager"
  alarm_period         = 300  # 5 minutes

  # EventBridge Configuration
  health_check_schedule       = "rate(5 minutes)"
  enable_scheduled_health_checks = true

  backup_schedule           = "cron(0 2 * * ? *)"  # 2 AM daily
  enable_scheduled_backups  = true

  # X-Ray Configuration
  enable_xray                   = true
  xray_sampling_priority        = 100
  xray_reservoir_size           = 5
  xray_fixed_rate               = 0.10  # 10% sampling
  xray_service_name             = "fleet-manager"
  xray_response_time_threshold  = 2
  xray_insights_enabled         = true
  xray_notifications_enabled    = true

  tags = {
    Project     = "fleet-manager"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### Multi-Environment Setup

```hcl
# Production
module "observability_prod" {
  source = "./modules/observability"

  environment               = "production"
  alert_email_addresses     = ["ops-prod@example.com"]
  log_retention_days        = 90
  cpu_threshold_percent     = 80
  memory_threshold_percent  = 85
  enable_xray               = true

  instance_ids              = module.compute_prod.instance_ids
  target_group_arn_suffix   = module.networking_prod.target_group_arn_suffix
  load_balancer_arn_suffix  = module.networking_prod.alb_arn_suffix

  tags = local.common_tags_prod
}

# Staging
module "observability_staging" {
  source = "./modules/observability"

  environment               = "staging"
  alert_email_addresses     = ["ops-staging@example.com"]
  log_retention_days        = 30
  cpu_threshold_percent     = 85
  memory_threshold_percent  = 90
  enable_xray               = false

  instance_ids              = module.compute_staging.instance_ids
  target_group_arn_suffix   = module.networking_staging.target_group_arn_suffix
  load_balancer_arn_suffix  = module.networking_staging.alb_arn_suffix

  tags = local.common_tags_staging
}
```

## Alarm Configurations

### CPU Alarm
- **Metric**: `CPUUtilization`
- **Default Threshold**: 80%
- **Default Evaluation**: 3 periods of 5 minutes (15 minutes)
- **Action**: SNS notification

### Memory Alarm
- **Metric**: `mem_used_percent` (custom metric)
- **Default Threshold**: 85%
- **Default Evaluation**: 3 periods of 5 minutes (15 minutes)
- **Action**: SNS notification
- **Note**: Requires CloudWatch agent on EC2 instances

### Disk Space Alarm
- **Metric**: `disk_free_percent` (custom metric)
- **Default Threshold**: < 15% free
- **Default Evaluation**: 2 periods of 5 minutes (10 minutes)
- **Action**: SNS notification
- **Note**: Requires CloudWatch agent on EC2 instances

### Unhealthy Host Alarm
- **Metric**: `UnHealthyHostCount`
- **Default Threshold**: > 0
- **Default Evaluation**: 2 periods of 5 minutes (10 minutes)
- **Action**: SNS notification

### Application Error Rate Alarm
- **Metric**: `ErrorCount` (from log metric filter)
- **Default Threshold**: > 10 errors per minute
- **Default Evaluation**: 2 periods of 1 minute
- **Action**: SNS notification

### Security Event Alarm
- **Metric**: `SecurityEvents` (from log metric filter)
- **Default Threshold**: > 0 critical events
- **Default Evaluation**: 1 period of 1 minute
- **Action**: SNS notification

## CloudWatch Agent Configuration

To enable memory and disk metrics, install and configure the CloudWatch agent on EC2 instances:

```json
{
  "metrics": {
    "namespace": "FleetManager",
    "metrics_collected": {
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "mem_used_percent",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          {
            "name": "disk_free",
            "rename": "disk_free_percent",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ]
      }
    }
  }
}
```

Install the agent:

```bash
# Amazon Linux 2
sudo yum install amazon-cloudwatch-agent -y

# Ubuntu
sudo apt-get install amazon-cloudwatch-agent -y

# Start the agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

## EventBridge Automation

### Instance State Changes
Captures EC2 instance state changes (stopped, terminated, stopping) and sends SNS notifications.

### Scheduled Health Checks
Triggers automated health checks at regular intervals (default: every 5 minutes).

### Backup Triggers
Triggers automated backups on a schedule (default: 2 AM daily).

## X-Ray Tracing

When enabled, X-Ray provides distributed tracing capabilities:

1. **Sampling Rule**: Controls trace collection rate
2. **Trace Groups**: Organizes traces by service
3. **Insights**: Automatic anomaly detection
4. **Notifications**: Alerts for detected issues

To use X-Ray, instrument your application:

```python
# Python Example
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all

patch_all()

@xray_recorder.capture('process_request')
def process_request(event):
    # Your code here
    pass
```

## Dashboard

The module creates a comprehensive CloudWatch dashboard with:

- **CPU Utilization**: Average and maximum CPU across instances
- **Memory Utilization**: Memory usage trends with thresholds
- **Disk Space**: Free disk space monitoring
- **Target Group Health**: Healthy vs unhealthy host counts
- **HTTP Response Codes**: 2xx, 4xx, 5xx breakdown
- **Response Time**: Average and p99 latency
- **Application Errors**: Error rate from logs
- **Recent Errors**: Table of recent application errors
- **Security Events**: Critical security event log
- **Network Traffic**: Network in/out metrics
- **Disk I/O**: Read/write operations
- **Load Balancer Connections**: Active and new connections
- **Active Alarms**: Current alarm states

## Outputs

```hcl
# Log Groups
output "log_group_names" {
  value = module.observability.log_group_names
}

# SNS Topic
output "sns_topic_arn" {
  value = module.observability.sns_topic_arn
}

# Dashboard
output "dashboard_url" {
  value = module.observability.dashboard_url
}

# Alarms
output "alarm_names" {
  value = module.observability.alarm_names
}

# X-Ray
output "xray_group_name" {
  value = module.observability.xray_group_name
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Resources Created

- 3 CloudWatch Log Groups
- 2 CloudWatch Log Metric Filters
- 1 SNS Topic with email subscriptions
- 1 CloudWatch Dashboard
- Multiple CloudWatch Metric Alarms (per instance + shared)
- 1 Composite Alarm
- 3 EventBridge Rules
- 3 EventBridge Targets
- 1 X-Ray Sampling Rule (optional)
- 1 X-Ray Group (optional)

## Cost Considerations

### CloudWatch Logs
- **Ingestion**: $0.50 per GB
- **Storage**: $0.03 per GB/month
- **Insights Queries**: $0.005 per GB scanned

### CloudWatch Metrics
- **Custom Metrics**: $0.30 per metric/month
- **Alarms**: $0.10 per alarm/month
- **Dashboard**: $3.00 per dashboard/month

### SNS
- **Email Notifications**: $2.00 per 100,000 notifications

### X-Ray
- **Traces Recorded**: $5.00 per 1 million traces
- **Traces Retrieved**: $0.50 per 1 million traces
- **Traces Scanned**: $0.50 per 1 million traces

### Example Monthly Cost (Medium Deployment)
- 3 EC2 instances with custom metrics: ~$5
- 10 CloudWatch alarms: ~$1
- 1 dashboard: $3
- 10 GB log ingestion: $5
- 5 GB log storage: $0.15
- SNS notifications (1000/month): ~$0.02
- X-Ray (100K traces): ~$0.50

**Total**: ~$15/month

## Security Best Practices

1. **Encrypt Logs**: Use KMS encryption for sensitive log data
2. **Restrict SNS Access**: Use IAM policies to control topic access
3. **Separate Security Logs**: Keep security logs isolated with longer retention
4. **Monitor Metric Filters**: Set up alerts for security-related log patterns
5. **Use IAM Roles**: Grant CloudWatch agent permissions via IAM roles
6. **Enable MFA**: Require MFA for SNS subscription confirmations
7. **Audit Access**: Monitor CloudWatch API calls via CloudTrail

## Operational Runbook

### Responding to Alarms

#### High CPU Alert
1. Check dashboard for CPU trends
2. Review application logs for errors
3. Identify resource-intensive processes
4. Consider scaling horizontally or vertically

#### High Memory Alert
1. Review memory usage trends
2. Check for memory leaks in application logs
3. Analyze heap dumps if available
4. Consider increasing instance size

#### Low Disk Space Alert
1. Identify large files/directories
2. Clean up temporary files and logs
3. Implement log rotation
4. Consider increasing EBS volume size

#### Unhealthy Host Alert
1. Check instance status in EC2 console
2. Review instance logs for errors
3. Verify security group and network ACL rules
4. Test application health endpoint manually

#### Application Error Alert
1. Query CloudWatch Logs Insights for error details
2. Identify error patterns and frequency
3. Check recent deployments for correlation
4. Review application monitoring for root cause

## Maintenance

### Log Retention Management
Adjust retention periods based on compliance requirements and cost optimization.

### Alarm Threshold Tuning
Monitor alarm frequency and adjust thresholds to reduce false positives.

### Dashboard Updates
Keep dashboard widgets updated as infrastructure evolves.

### Regular Reviews
- Weekly: Review alarm patterns and adjust thresholds
- Monthly: Analyze log costs and optimize retention
- Quarterly: Review dashboard effectiveness and update widgets

## Troubleshooting

### Alarms Not Triggering
- Verify CloudWatch agent is running on instances
- Check IAM permissions for CloudWatch agent
- Confirm metric namespace matches configuration
- Review alarm threshold and evaluation period settings

### No Data in Dashboard
- Ensure CloudWatch agent is configured correctly
- Verify metric namespace and dimensions
- Check IAM permissions for metric publishing
- Review agent logs: `/opt/aws/amazon-cloudwatch-agent/logs/`

### SNS Emails Not Received
- Confirm email subscriptions in SNS console
- Check spam/junk folders
- Verify SNS topic policy allows CloudWatch to publish
- Test SNS topic with manual publish

### X-Ray Traces Not Appearing
- Confirm X-Ray daemon is running
- Check application instrumentation
- Verify IAM permissions for X-Ray
- Review sampling rule configuration

## Examples

See the `examples/` directory for complete implementation examples:
- `examples/basic/` - Minimal configuration
- `examples/complete/` - Full-featured setup
- `examples/multi-environment/` - Dev/staging/prod patterns

## Contributing

When contributing to this module:
1. Follow Terraform best practices
2. Update documentation for new features
3. Add examples for complex configurations
4. Test across multiple AWS regions
5. Validate with `terraform validate` and `tflint`

## License

This module is provided as-is for use in infrastructure projects.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review AWS CloudWatch documentation
3. Open an issue in the repository
4. Contact the platform team

## Changelog

### v1.0.0
- Initial release
- CloudWatch Logs, Metrics, and Dashboards
- SNS alerting
- EventBridge automation
- X-Ray tracing support
- Comprehensive documentation
