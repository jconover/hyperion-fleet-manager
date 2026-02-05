# SNS Alerting Module

Enterprise-grade alerting infrastructure for the Hyperion Fleet Manager using AWS SNS, with support for multiple notification channels, alert enrichment, and GDPR-compliant PII handling.

## Overview

This module creates a comprehensive alerting system with:

- **5 SNS Topics** organized by severity and purpose
- **Multiple subscription types** (email, SMS, webhooks, Lambda, SQS)
- **Lambda alert processor** for enrichment and routing
- **EventBridge rules** for automated alert routing from AWS services
- **KMS encryption** for data at rest and in transit
- **GDPR-compliant** PII redaction capabilities

## Architecture

```
                                    +------------------+
                                    |   CloudWatch     |
                                    |    Alarms        |
                                    +--------+---------+
                                             |
+----------------+    +----------+           v           +------------------+
|   GuardDuty    +--->|          |    +-----------+     |  Email/SMS       |
+----------------+    |          |    |           |     +------------------+
                      | Event    +--->| SNS       +---->|  Slack           |
+----------------+    | Bridge   |    | Topics    |     +------------------+
|   Config       +--->|          |    |           |     |  PagerDuty       |
+----------------+    |          |    +-----------+     +------------------+
                      +----------+           |          |  SQS Queues      |
+----------------+                           v          +------------------+
|   EC2/ASG      +--->               +-------------+
+----------------+                   |   Lambda    |
                                     |  Processor  |
+----------------+                   +-------------+
|   Security Hub +--->
+----------------+
```

## SNS Topics

| Topic | Purpose | Use Case |
|-------|---------|----------|
| `critical` | P1 incidents | Pages on-call engineers immediately |
| `warning` | P2/P3 issues | Creates tickets for investigation |
| `info` | Informational | Dashboard updates, logs only |
| `security` | Security alerts | SOC team review required |
| `cost` | Cost anomalies | FinOps team notifications |

## Usage

### Basic Usage

```hcl
module "alerting" {
  source = "./infrastructure/modules/observability/alerting"

  environment  = "production"
  project_name = "hyperion"

  email_endpoints = {
    critical = ["oncall@example.com", "sre@example.com"]
    warning  = ["ops@example.com"]
    security = ["security@example.com"]
    cost     = ["finops@example.com"]
  }

  tags = {
    Team    = "Platform"
    Service = "Fleet Manager"
  }
}
```

### With Slack and PagerDuty Integration

```hcl
module "alerting" {
  source = "./infrastructure/modules/observability/alerting"

  environment  = "production"
  project_name = "hyperion"

  email_endpoints = {
    critical = ["oncall@example.com"]
    warning  = ["ops@example.com"]
  }

  sms_endpoints = [
    "+14155551234",
    "+14155555678"
  ]

  slack_webhook_url         = "https://hooks.slack.com/services/xxx/yyy/zzz"
  pagerduty_integration_key = "abcd1234efgh5678ijkl9012mnop3456"

  enable_lambda_processor = true
  enable_pii_redaction    = true

  tags = {
    Team = "Platform"
  }
}
```

### With Custom Webhooks

```hcl
module "alerting" {
  source = "./infrastructure/modules/observability/alerting"

  environment  = "production"
  project_name = "hyperion"

  webhook_endpoints = {
    critical = {
      pagerduty   = "https://events.pagerduty.com/integration/xxx/enqueue"
      opsgenie    = "https://api.opsgenie.com/v1/json/cloudwatch"
    }
    warning = {
      jira        = "https://your-jira.atlassian.net/rest/webhooks/1.0/xxx"
      servicenow  = "https://your-instance.service-now.com/api/xxx"
    }
    info = {
      slack       = "https://hooks.slack.com/services/xxx"
      teams       = "https://outlook.office.com/webhook/xxx"
    }
  }

  tags = {
    Team = "Platform"
  }
}
```

### With SQS Queues for Processing

```hcl
module "alerting" {
  source = "./infrastructure/modules/observability/alerting"

  environment  = "production"
  project_name = "hyperion"

  enable_sqs_subscriptions = true
  enable_aggregate_queue   = true

  email_endpoints = {
    critical = ["oncall@example.com"]
  }

  tags = {
    Team = "Platform"
  }
}

# Use the SQS queue for custom processing
resource "aws_lambda_event_source_mapping" "alert_processor" {
  event_source_arn = module.alerting.aggregate_queue_arn
  function_name    = aws_lambda_function.custom_processor.arn
  batch_size       = 10
}
```

### With Cross-Account Events

```hcl
module "alerting" {
  source = "./infrastructure/modules/observability/alerting"

  environment  = "production"
  project_name = "hyperion"

  enable_cross_account_events = true
  cross_account_ids = [
    "123456789012",  # Dev account
    "234567890123",  # Staging account
  ]

  email_endpoints = {
    critical = ["oncall@example.com"]
  }

  tags = {
    Team = "Platform"
  }
}
```

### Using Existing KMS Key

```hcl
module "alerting" {
  source = "./infrastructure/modules/observability/alerting"

  environment  = "production"
  project_name = "hyperion"
  kms_key_arn  = aws_kms_key.existing.arn

  email_endpoints = {
    critical = ["oncall@example.com"]
  }

  tags = {
    Team = "Platform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `environment` | Environment name (dev, staging, production) | `string` | n/a | yes |
| `project_name` | Project name for resource naming | `string` | `"hyperion"` | no |
| `tags` | Common tags for all resources | `map(string)` | `{}` | no |
| `kms_key_arn` | ARN of existing KMS key | `string` | `null` | no |
| `email_endpoints` | Map of email addresses by severity | `map(list(string))` | `{}` | no |
| `sms_endpoints` | List of phone numbers (E.164 format) | `list(string)` | `[]` | no |
| `webhook_endpoints` | Map of webhook URLs by severity | `map(map(string))` | `{}` | no |
| `slack_webhook_url` | Slack webhook URL | `string` | `null` | no |
| `pagerduty_integration_key` | PagerDuty routing key | `string` | `null` | no |
| `enable_lambda_processor` | Enable Lambda alert processor | `bool` | `true` | no |
| `enable_pii_redaction` | Enable GDPR-compliant PII redaction | `bool` | `true` | no |
| `enable_sqs_subscriptions` | Enable SQS queue subscriptions | `bool` | `true` | no |
| `enable_aggregate_queue` | Enable aggregate queue for all alerts | `bool` | `false` | no |
| `enable_cross_account_events` | Enable cross-account event bus | `bool` | `false` | no |
| `cross_account_ids` | AWS account IDs for cross-account events | `list(string)` | `[]` | no |

See [variables.tf](variables.tf) for complete list of variables.

## Outputs

| Name | Description |
|------|-------------|
| `topic_arns` | Map of all SNS topic ARNs |
| `critical_topic_arn` | ARN of critical alerts topic |
| `warning_topic_arn` | ARN of warning alerts topic |
| `info_topic_arn` | ARN of info alerts topic |
| `security_topic_arn` | ARN of security alerts topic |
| `cost_topic_arn` | ARN of cost alerts topic |
| `lambda_function_arn` | ARN of alert processor Lambda |
| `sqs_queue_arns` | Map of SQS queue ARNs |
| `kms_key_arn` | ARN of KMS key used for encryption |
| `eventbridge_rule_arns` | Map of EventBridge rule ARNs |
| `integration_config` | Configuration for integrating with this module |

See [outputs.tf](outputs.tf) for complete list of outputs.

## Integration Examples

### CloudWatch Alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "production-high-cpu-instance-1"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  alarm_actions = [module.alerting.critical_topic_arn]
  ok_actions    = [module.alerting.info_topic_arn]

  dimensions = {
    InstanceId = aws_instance.example.id
  }
}
```

### AWS Budgets

```hcl
resource "aws_budgets_budget" "monthly" {
  name         = "monthly-budget"
  budget_type  = "COST"
  limit_amount = "1000"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_sns_topic_arns  = [module.alerting.cost_topic_arn]
  }
}
```

### Custom Application Alerts

```hcl
# Python example using boto3
import boto3

sns = boto3.client('sns')

def send_alert(severity, message, context=None):
    topic_arns = {
        'critical': 'arn:aws:sns:...:hyperion-production-critical-alerts',
        'warning': 'arn:aws:sns:...:hyperion-production-warning-alerts',
        'info': 'arn:aws:sns:...:hyperion-production-info-alerts',
    }

    sns.publish(
        TopicArn=topic_arns[severity],
        Subject=f'[{severity.upper()}] Application Alert',
        Message=json.dumps({
            'message': message,
            'context': context,
            'timestamp': datetime.utcnow().isoformat()
        })
    )
```

## GDPR Compliance

This module includes PII redaction capabilities when `enable_pii_redaction = true`:

- Email addresses are replaced with `[EMAIL_REDACTED]`
- Phone numbers are replaced with `[PHONE_REDACTED]`
- Social Security Numbers are replaced with `[SSN_REDACTED]`
- Credit card numbers are replaced with `[CARD_REDACTED]`
- IP addresses are replaced with `[IP_REDACTED]`

For SMS subscriptions, ensure proper consent is obtained from recipients.

## Security Considerations

1. **KMS Encryption**: All SNS topics and SQS queues are encrypted at rest
2. **Access Policies**: Strict IAM policies limit who can publish/subscribe
3. **HTTPS Only**: Webhook endpoints must use HTTPS
4. **PII Redaction**: Optional automatic PII removal from alerts
5. **Audit Trail**: All events are logged to CloudWatch

## Cost Optimization

- Use `enable_lambda_processor = false` if not using Slack/PagerDuty integration
- Use `enable_sqs_subscriptions = false` if not processing alerts asynchronously
- Consider `enable_aggregate_queue = false` unless centralized processing is needed
- SMS notifications incur additional costs - use sparingly

## Troubleshooting

### Email Subscriptions Not Receiving Alerts

1. Check if subscription is confirmed (look for confirmation email)
2. Verify the SNS topic policy allows CloudWatch/EventBridge to publish
3. Check CloudWatch Logs for Lambda processor errors

### Lambda Processor Failing

1. Check the Lambda dead letter queue for failed messages
2. Review CloudWatch Logs at `/aws/lambda/{name}-alert-processor`
3. Verify IAM permissions are correct

### Missing EventBridge Events

1. Ensure the source service (GuardDuty, Config, etc.) is enabled
2. Check if the event pattern matches expected events
3. Verify the EventBridge rule is enabled

## Related Documentation

- [AWS SNS Best Practices](https://docs.aws.amazon.com/sns/latest/dg/sns-best-practices.html)
- [EventBridge Event Patterns](https://docs.aws.amazon.com/eventbridge/latest/userguide/aws-events.html)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)

## License

MIT License - see [LICENSE](../../../../LICENSE) for details.
