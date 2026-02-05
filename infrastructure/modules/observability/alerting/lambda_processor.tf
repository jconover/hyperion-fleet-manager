# =============================================================================
# Lambda Alert Processor
# =============================================================================
# This Lambda function processes alerts for:
# - Alert enrichment (adding instance details, runbook links)
# - Formatting for different destinations (Slack, PagerDuty, email)
# - Routing to external systems based on severity and type
# =============================================================================

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "alert_processor" {
  count = var.enable_lambda_processor ? 1 : 0

  function_name = "${local.name_prefix}-alert-processor"
  description   = "Processes and enriches alerts, routes to external systems"
  role          = aws_iam_role.lambda_processor.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.lambda_processor[0].output_path
  source_code_hash = data.archive_file.lambda_processor[0].output_base64sha256

  # VPC configuration (optional - for accessing internal resources)
  dynamic "vpc_config" {
    for_each = var.lambda_vpc_config != null ? [var.lambda_vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  environment {
    variables = {
      ENVIRONMENT           = var.environment
      PROJECT_NAME          = var.project_name
      SLACK_WEBHOOK_URL     = var.slack_webhook_url != null ? var.slack_webhook_url : ""
      PAGERDUTY_ROUTING_KEY = var.pagerduty_integration_key != null ? var.pagerduty_integration_key : ""
      RUNBOOK_BASE_URL      = var.runbook_base_url
      LOG_LEVEL             = var.lambda_log_level
      CRITICAL_TOPIC_ARN    = aws_sns_topic.critical.arn
      WARNING_TOPIC_ARN     = aws_sns_topic.warning.arn
      INFO_TOPIC_ARN        = aws_sns_topic.info.arn
      SECURITY_TOPIC_ARN    = aws_sns_topic.security.arn
      COST_TOPIC_ARN        = aws_sns_topic.cost.arn
      ENABLE_PII_REDACTION  = tostring(var.enable_pii_redaction)
    }
  }

  # Dead letter queue for failed invocations
  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq[0].arn
  }

  # Enable X-Ray tracing
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  # Reserved concurrency to prevent runaway costs
  reserved_concurrent_executions = var.lambda_reserved_concurrency

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-alert-processor"
      Purpose = "Alert enrichment and routing"
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.lambda_processor,
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_sns_publish,
    aws_iam_role_policy_attachment.lambda_ec2_describe
  ]
}

# -----------------------------------------------------------------------------
# Lambda Source Code
# -----------------------------------------------------------------------------

data "archive_file" "lambda_processor" {
  count = var.enable_lambda_processor ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/files/alert_processor.zip"

  source {
    content  = local.lambda_source_code
    filename = "index.py"
  }
}

locals {
  lambda_source_code = <<-EOF
"""
Hyperion Fleet Manager - Alert Processor Lambda

This function processes SNS alerts for:
- Alert enrichment (instance details, runbook links, context)
- Format transformation for different destinations
- Routing to external systems (Slack, PagerDuty)
- PII redaction for GDPR compliance
"""

import json
import os
import re
import urllib.request
import urllib.parse
import logging
from datetime import datetime
from typing import Any, Dict, Optional

# Configure logging
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger = logging.getLogger()
logger.setLevel(getattr(logging, log_level.upper(), logging.INFO))

# Environment variables
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'unknown')
PROJECT_NAME = os.environ.get('PROJECT_NAME', 'hyperion')
SLACK_WEBHOOK_URL = os.environ.get('SLACK_WEBHOOK_URL', '')
PAGERDUTY_ROUTING_KEY = os.environ.get('PAGERDUTY_ROUTING_KEY', '')
RUNBOOK_BASE_URL = os.environ.get('RUNBOOK_BASE_URL', 'https://runbooks.example.com')
ENABLE_PII_REDACTION = os.environ.get('ENABLE_PII_REDACTION', 'true').lower() == 'true'

# PII patterns for redaction
PII_PATTERNS = [
    (r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', '[EMAIL_REDACTED]'),
    (r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b', '[PHONE_REDACTED]'),
    (r'\b\d{3}[-]?\d{2}[-]?\d{4}\b', '[SSN_REDACTED]'),
    (r'\b(?:\d{4}[-\s]?){3}\d{4}\b', '[CARD_REDACTED]'),
    (r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', '[IP_REDACTED]'),
]

# Runbook mappings
RUNBOOK_MAPPINGS = {
    'high_cpu': 'cpu-high-utilization',
    'high_memory': 'memory-high-utilization',
    'disk_space': 'disk-space-low',
    'instance_terminated': 'ec2-instance-terminated',
    'security_group_change': 'security-group-modified',
    'unauthorized_access': 'unauthorized-access-attempt',
    'budget_threshold': 'budget-threshold-exceeded',
    'guardduty': 'guardduty-finding',
    'config_violation': 'config-rule-violation',
}


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for processing SNS alerts.

    Args:
        event: SNS event containing alert message
        context: Lambda context

    Returns:
        Processing result
    """
    logger.info(f"Processing alert event: {json.dumps(event)[:1000]}")

    results = []

    for record in event.get('Records', []):
        try:
            result = process_record(record)
            results.append(result)
        except Exception as e:
            logger.error(f"Error processing record: {str(e)}")
            results.append({
                'status': 'error',
                'error': str(e)
            })

    return {
        'statusCode': 200,
        'body': json.dumps({
            'processed': len(results),
            'results': results
        })
    }


def process_record(record: Dict[str, Any]) -> Dict[str, Any]:
    """Process a single SNS record."""
    sns_message = record.get('Sns', {})
    topic_arn = sns_message.get('TopicArn', '')
    message_str = sns_message.get('Message', '{}')
    subject = sns_message.get('Subject', 'Alert')

    # Parse message
    try:
        message = json.loads(message_str)
    except json.JSONDecodeError:
        message = {'raw_message': message_str}

    # Determine severity from topic
    severity = determine_severity(topic_arn)

    # Enrich the alert
    enriched_alert = enrich_alert(message, severity, subject)

    # Apply PII redaction if enabled
    if ENABLE_PII_REDACTION:
        enriched_alert = redact_pii(enriched_alert)

    # Route to external systems
    routing_results = route_alert(enriched_alert, severity)

    return {
        'status': 'success',
        'severity': severity,
        'routing': routing_results
    }


def determine_severity(topic_arn: str) -> str:
    """Determine alert severity from topic ARN."""
    topic_name = topic_arn.split(':')[-1].lower()

    if 'critical' in topic_name:
        return 'critical'
    elif 'warning' in topic_name:
        return 'warning'
    elif 'security' in topic_name:
        return 'security'
    elif 'cost' in topic_name:
        return 'cost'
    else:
        return 'info'


def enrich_alert(message: Dict[str, Any], severity: str, subject: str) -> Dict[str, Any]:
    """Enrich alert with additional context."""
    enriched = {
        'original_message': message,
        'severity': severity,
        'subject': subject,
        'environment': ENVIRONMENT,
        'project': PROJECT_NAME,
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'processed_by': 'hyperion-alert-processor',
    }

    # Add runbook link
    runbook_key = find_runbook_key(message, subject)
    if runbook_key:
        enriched['runbook_url'] = f"{RUNBOOK_BASE_URL}/{runbook_key}"
        enriched['runbook_key'] = runbook_key

    # Extract instance details if present
    instance_id = extract_instance_id(message)
    if instance_id:
        enriched['instance_id'] = instance_id
        enriched['console_url'] = f"https://console.aws.amazon.com/ec2/v2/home?region={os.environ.get('AWS_REGION', 'us-east-1')}#Instances:instanceId={instance_id}"

    # Extract alarm details if CloudWatch alarm
    if 'AlarmName' in message:
        enriched['alarm_name'] = message.get('AlarmName')
        enriched['alarm_state'] = message.get('NewStateValue')
        enriched['alarm_reason'] = message.get('NewStateReason')
        enriched['metric_name'] = message.get('Trigger', {}).get('MetricName')

    # Extract GuardDuty finding details
    if 'detail-type' in message and 'GuardDuty' in str(message.get('detail-type', '')):
        detail = message.get('detail', {})
        enriched['guardduty_finding'] = {
            'type': detail.get('type'),
            'severity': detail.get('severity'),
            'title': detail.get('title'),
            'description': detail.get('description'),
        }

    return enriched


def find_runbook_key(message: Dict[str, Any], subject: str) -> Optional[str]:
    """Find appropriate runbook based on alert content."""
    content = json.dumps(message).lower() + subject.lower()

    for keyword, runbook in RUNBOOK_MAPPINGS.items():
        if keyword.replace('_', ' ') in content or keyword in content:
            return runbook

    return None


def extract_instance_id(message: Dict[str, Any]) -> Optional[str]:
    """Extract EC2 instance ID from message."""
    # Check common locations
    if 'detail' in message and 'instance-id' in message['detail']:
        return message['detail']['instance-id']

    if 'Trigger' in message and 'Dimensions' in message['Trigger']:
        for dim in message['Trigger']['Dimensions']:
            if dim.get('name') == 'InstanceId':
                return dim.get('value')

    # Search for instance ID pattern
    content = json.dumps(message)
    match = re.search(r'i-[a-f0-9]{8,17}', content)
    if match:
        return match.group(0)

    return None


def redact_pii(data: Any) -> Any:
    """Recursively redact PII from data structures."""
    if isinstance(data, str):
        for pattern, replacement in PII_PATTERNS:
            data = re.sub(pattern, replacement, data, flags=re.IGNORECASE)
        return data
    elif isinstance(data, dict):
        return {k: redact_pii(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [redact_pii(item) for item in data]
    else:
        return data


def route_alert(alert: Dict[str, Any], severity: str) -> Dict[str, str]:
    """Route alert to external systems based on severity."""
    results = {}

    # Send to Slack for all severities
    if SLACK_WEBHOOK_URL:
        results['slack'] = send_to_slack(alert)

    # Send to PagerDuty for critical and security alerts
    if PAGERDUTY_ROUTING_KEY and severity in ['critical', 'security']:
        results['pagerduty'] = send_to_pagerduty(alert)

    return results


def send_to_slack(alert: Dict[str, Any]) -> str:
    """Send formatted alert to Slack."""
    try:
        severity = alert.get('severity', 'info')
        color = {
            'critical': '#FF0000',
            'security': '#FF4500',
            'warning': '#FFA500',
            'cost': '#9932CC',
            'info': '#36A64F',
        }.get(severity, '#808080')

        emoji = {
            'critical': ':rotating_light:',
            'security': ':shield:',
            'warning': ':warning:',
            'cost': ':moneybag:',
            'info': ':information_source:',
        }.get(severity, ':bell:')

        blocks = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"{emoji} {alert.get('subject', 'Alert')}",
                    "emoji": True
                }
            },
            {
                "type": "section",
                "fields": [
                    {"type": "mrkdwn", "text": f"*Environment:*\n{alert.get('environment')}"},
                    {"type": "mrkdwn", "text": f"*Severity:*\n{severity.upper()}"},
                    {"type": "mrkdwn", "text": f"*Timestamp:*\n{alert.get('timestamp')}"},
                ]
            }
        ]

        # Add instance details if available
        if alert.get('instance_id'):
            blocks.append({
                "type": "section",
                "fields": [
                    {"type": "mrkdwn", "text": f"*Instance ID:*\n{alert.get('instance_id')}"},
                    {"type": "mrkdwn", "text": f"*<{alert.get('console_url')}|View in Console>*"}
                ]
            })

        # Add runbook link if available
        if alert.get('runbook_url'):
            blocks.append({
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f":book: *Runbook:* <{alert.get('runbook_url')}|{alert.get('runbook_key')}>"
                }
            })

        # Add alarm details if present
        if alert.get('alarm_name'):
            blocks.append({
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Alarm:* {alert.get('alarm_name')}\n*State:* {alert.get('alarm_state')}\n*Reason:* {alert.get('alarm_reason', 'N/A')[:200]}"
                }
            })

        payload = {
            "attachments": [{
                "color": color,
                "blocks": blocks
            }]
        }

        response = http_post(SLACK_WEBHOOK_URL, payload)
        return 'success' if response else 'failed'

    except Exception as e:
        logger.error(f"Slack send failed: {str(e)}")
        return f'error: {str(e)}'


def send_to_pagerduty(alert: Dict[str, Any]) -> str:
    """Send alert to PagerDuty."""
    try:
        severity = alert.get('severity', 'info')
        pd_severity = {
            'critical': 'critical',
            'security': 'critical',
            'warning': 'warning',
            'cost': 'warning',
            'info': 'info',
        }.get(severity, 'info')

        payload = {
            "routing_key": PAGERDUTY_ROUTING_KEY,
            "event_action": "trigger",
            "dedup_key": f"{PROJECT_NAME}-{alert.get('subject', 'alert')}-{alert.get('timestamp', '')}",
            "payload": {
                "summary": f"[{ENVIRONMENT.upper()}] {alert.get('subject', 'Alert')}",
                "severity": pd_severity,
                "source": f"hyperion-{ENVIRONMENT}",
                "timestamp": alert.get('timestamp'),
                "custom_details": {
                    "environment": alert.get('environment'),
                    "instance_id": alert.get('instance_id'),
                    "runbook_url": alert.get('runbook_url'),
                    "alarm_name": alert.get('alarm_name'),
                    "alarm_state": alert.get('alarm_state'),
                }
            },
            "links": [],
            "images": []
        }

        if alert.get('runbook_url'):
            payload["links"].append({
                "href": alert.get('runbook_url'),
                "text": "Runbook"
            })

        if alert.get('console_url'):
            payload["links"].append({
                "href": alert.get('console_url'),
                "text": "AWS Console"
            })

        response = http_post(
            "https://events.pagerduty.com/v2/enqueue",
            payload
        )
        return 'success' if response else 'failed'

    except Exception as e:
        logger.error(f"PagerDuty send failed: {str(e)}")
        return f'error: {str(e)}'


def http_post(url: str, payload: Dict[str, Any]) -> bool:
    """Make HTTP POST request."""
    try:
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            url,
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            return response.status == 200 or response.status == 202
    except Exception as e:
        logger.error(f"HTTP POST failed: {str(e)}")
        return False
EOF
}

# -----------------------------------------------------------------------------
# Lambda Dead Letter Queue
# -----------------------------------------------------------------------------

resource "aws_sqs_queue" "lambda_dlq" {
  count = var.enable_lambda_processor ? 1 : 0

  name                      = "${local.name_prefix}-alert-processor-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = local.kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-alert-processor-dlq"
      Purpose = "Lambda dead letter queue"
    }
  )
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group for Lambda
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda_processor" {
  count = var.enable_lambda_processor ? 1 : 0

  name              = "/aws/lambda/${local.name_prefix}-alert-processor"
  retention_in_days = var.lambda_log_retention_days
  kms_key_id        = local.kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-alert-processor-logs"
      Purpose = "Lambda function logs"
    }
  )
}

# -----------------------------------------------------------------------------
# Lambda Async Configuration
# -----------------------------------------------------------------------------

resource "aws_lambda_function_event_invoke_config" "alert_processor" {
  count = var.enable_lambda_processor ? 1 : 0

  function_name          = aws_lambda_function.alert_processor[0].function_name
  maximum_retry_attempts = 2

  destination_config {
    on_failure {
      destination = aws_sqs_queue.lambda_dlq[0].arn
    }
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms for Lambda
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.enable_lambda_processor && var.enable_lambda_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-alert-processor-errors"
  alarm_description   = "Alert processor Lambda function errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_actions       = [aws_sns_topic.warning.arn]
  ok_actions          = [aws_sns_topic.info.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.alert_processor[0].function_name
  }

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.name_prefix}-alert-processor-errors"
      AlarmType = "lambda-errors"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count = var.enable_lambda_processor && var.enable_lambda_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-alert-processor-duration"
  alarm_description   = "Alert processor Lambda function duration exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 25000 # 25 seconds (function timeout is 30s)
  alarm_actions       = [aws_sns_topic.warning.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.alert_processor[0].function_name
  }

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.name_prefix}-alert-processor-duration"
      AlarmType = "lambda-duration"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "lambda_dlq_messages" {
  count = var.enable_lambda_processor && var.enable_lambda_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-alert-processor-dlq-messages"
  alarm_description   = "Messages appearing in Lambda dead letter queue"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.critical.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.lambda_dlq[0].name
  }

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.name_prefix}-alert-processor-dlq-messages"
      AlarmType = "dlq-messages"
    }
  )
}
