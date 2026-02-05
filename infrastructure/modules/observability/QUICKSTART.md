# Observability Module - Quick Start Guide

Get started with the observability module in 5 minutes.

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- EC2 instances running with IAM role for CloudWatch
- (Optional) Load balancer for target group monitoring

## Quick Setup

### Step 1: Copy Example Variables

```bash
cd /home/justin/Projects/hyperion-fleet-manager/infrastructure/modules/observability
cp terraform.tfvars.example terraform.tfvars
```

### Step 2: Edit terraform.tfvars

Edit `terraform.tfvars` with your specific values:

```hcl
environment = "production"

alert_email_addresses = [
  "your-email@example.com"
]

instance_ids = [
  "i-your-instance-id"
]

target_group_arn_suffix  = "targetgroup/your-tg/suffix"
load_balancer_arn_suffix = "app/your-alb/suffix"

tags = {
  Project   = "your-project"
  ManagedBy = "terraform"
}
```

### Step 3: Initialize and Validate

```bash
terraform init
terraform validate
terraform plan
```

### Step 4: Deploy

```bash
terraform apply
```

Confirm by typing `yes` when prompted.

### Step 5: Confirm Email Subscriptions

Check your email inbox for SNS subscription confirmation emails and click the confirmation links.

## Basic Usage in Root Module

Create or update your root `main.tf`:

```hcl
module "observability" {
  source = "./modules/observability"

  environment = "production"

  alert_email_addresses = [
    "ops@example.com"
  ]

  instance_ids = module.compute.instance_ids

  target_group_arn_suffix  = module.networking.target_group_arn_suffix
  load_balancer_arn_suffix = module.networking.alb_arn_suffix

  tags = {
    Project   = "fleet-manager"
    ManagedBy = "terraform"
  }
}

output "dashboard_url" {
  value = module.observability.dashboard_url
}

output "log_groups" {
  value = module.observability.log_group_names
}
```

## CloudWatch Agent Setup

### Install Agent

```bash
# Amazon Linux 2
sudo yum install amazon-cloudwatch-agent -y

# Ubuntu
sudo apt-get update
sudo apt-get install amazon-cloudwatch-agent -y
```

### Configure Agent

Copy the example configuration:

```bash
sudo cp cloudwatch-agent-config.json /opt/aws/amazon-cloudwatch-agent/etc/config.json
```

Edit the configuration to match your application log paths:

```bash
sudo vim /opt/aws/amazon-cloudwatch-agent/etc/config.json
```

### Start Agent

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

### Verify Agent Status

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a query \
  -m ec2 \
  -c default
```

## IAM Role Setup

Your EC2 instances need the following IAM permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "ec2:DescribeVolumes",
        "ec2:DescribeTags",
        "logs:PutLogEvents",
        "logs:CreateLogStream",
        "logs:CreateLogGroup",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }
  ]
}
```

For X-Ray (if enabled):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets"
      ],
      "Resource": "*"
    }
  ]
}
```

## Accessing Your Dashboard

After deployment, get the dashboard URL:

```bash
terraform output dashboard_url
```

Or construct it manually:
```
https://console.aws.amazon.com/cloudwatch/home?region=<region>#dashboards:name=<environment>-fleet-health-overview
```

## Testing Alarms

### Test CPU Alarm

```bash
# SSH into your instance
ssh ec2-user@your-instance

# Generate CPU load
stress --cpu 4 --timeout 600s

# Or use a simple loop
while true; do echo "stress"; done
```

### Test Memory Alarm

```bash
# Generate memory pressure
stress --vm 2 --vm-bytes 1G --timeout 600s
```

### Test Disk Alarm

```bash
# Fill disk space (careful!)
dd if=/dev/zero of=/tmp/testfile bs=1M count=10000
```

### Test Application Error Alarm

```bash
# Write errors to application log
for i in {1..20}; do
  echo "$(date) ERROR: Test error message $i" >> /var/log/fleet-manager/application.log
done
```

### Test Unhealthy Host

```bash
# Stop your application service
sudo systemctl stop your-application

# Wait for health check to fail
# Check target group in AWS console
```

## Viewing Logs

### AWS CLI

```bash
# View recent logs
aws logs tail /hyperion/fleet/application --follow

# Filter for errors
aws logs filter-log-events \
  --log-group-name /hyperion/fleet/application \
  --filter-pattern "ERROR"
```

### AWS Console

1. Navigate to CloudWatch → Log groups
2. Select log group (e.g., `/hyperion/fleet/application`)
3. Click on log stream for your instance
4. Use CloudWatch Logs Insights for advanced queries

## CloudWatch Logs Insights Queries

### Find Recent Errors

```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

### Count Errors by Hour

```
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by bin(@timestamp, 1h)
```

### Find Slow Requests

```
fields @timestamp, @message
| filter @message like /duration/
| parse @message "duration=* ms" as duration
| filter duration > 1000
| sort duration desc
```

## Common Commands

### Check Module Status

```bash
terraform state list | grep observability
```

### Update Alarm Thresholds

Edit `terraform.tfvars`:

```hcl
cpu_threshold_percent = 75  # Changed from 80
```

Apply changes:

```bash
terraform apply -target=module.observability
```

### Add More Email Recipients

Edit `terraform.tfvars`:

```hcl
alert_email_addresses = [
  "ops@example.com",
  "new-team@example.com"  # Added
]
```

Apply:

```bash
terraform apply
```

### Disable X-Ray

```hcl
enable_xray = false
```

```bash
terraform apply
```

## Troubleshooting

### No Metrics Appearing

1. Check CloudWatch agent status:
   ```bash
   sudo systemctl status amazon-cloudwatch-agent
   ```

2. Check agent logs:
   ```bash
   sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
   ```

3. Verify IAM permissions on EC2 instance role

### Alarms Not Triggering

1. Verify metric data exists:
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace FleetManager \
     --metric-name mem_used_percent \
     --dimensions Name=InstanceId,Value=i-your-instance \
     --start-time 2026-02-04T00:00:00Z \
     --end-time 2026-02-04T23:59:59Z \
     --period 300 \
     --statistics Average
   ```

2. Check alarm state in AWS Console

3. Review alarm threshold and evaluation periods

### SNS Emails Not Received

1. Check SNS subscription status:
   ```bash
   aws sns list-subscriptions-by-topic \
     --topic-arn $(terraform output -raw sns_topic_arn)
   ```

2. Look for confirmation email in spam folder

3. Test SNS topic manually:
   ```bash
   aws sns publish \
     --topic-arn $(terraform output -raw sns_topic_arn) \
     --message "Test message"
   ```

### Dashboard Shows No Data

1. Verify instance IDs are correct in `terraform.tfvars`

2. Check that CloudWatch agent is publishing metrics

3. Verify AWS region matches where resources are deployed

4. Check dashboard JSON template variables

## Next Steps

1. **Customize Thresholds**: Adjust alarm thresholds based on your baseline
2. **Add More Instances**: Update `instance_ids` variable
3. **Enable X-Ray**: Set `enable_xray = true` and instrument your application
4. **Create Runbooks**: Document response procedures for each alarm
5. **Set Up Integrations**: Connect to Slack, PagerDuty, or other tools
6. **Review Costs**: Monitor CloudWatch usage in AWS Cost Explorer
7. **Optimize Retention**: Adjust log retention based on needs

## Cost Management

### Current Configuration Cost

Run this to estimate:

```bash
# Log ingestion: Depends on log volume
# Metrics: Count custom metrics
# Alarms: Count total alarms
# Dashboard: $3/month
```

### Reduce Costs

1. Decrease log retention:
   ```hcl
   log_retention_days = 7
   ```

2. Disable per-instance alarms:
   ```hcl
   enable_instance_alarms = false
   ```

3. Reduce X-Ray sampling:
   ```hcl
   xray_fixed_rate = 0.01  # 1% instead of 5%
   ```

4. Use metric filters selectively

## Support

- Review full README.md for detailed documentation
- Check CHANGELOG.md for version information
- Run `./validate.sh` to verify configuration
- Check AWS CloudWatch documentation for service details

## Quick Reference

| Action | Command |
|--------|---------|
| Initialize | `terraform init` |
| Validate | `terraform validate` |
| Plan | `terraform plan` |
| Apply | `terraform apply` |
| Destroy | `terraform destroy` |
| View outputs | `terraform output` |
| Check agent | `sudo systemctl status amazon-cloudwatch-agent` |
| Tail logs | `aws logs tail /hyperion/fleet/application --follow` |
| Test alarm | `aws cloudwatch set-alarm-state --alarm-name <name> --state-value ALARM --state-reason "Testing"` |

## Additional Resources

- [AWS CloudWatch Agent Setup](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/install-CloudWatch-Agent-on-EC2-Instance.html)
- [CloudWatch Logs Insights Query Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [X-Ray SDK Documentation](https://docs.aws.amazon.com/xray/latest/devguide/xray-instrumenting-your-app.html)
- [EventBridge Rule Patterns](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html)

---

**Ready to deploy?**

```bash
terraform init && terraform plan
```

If the plan looks good:

```bash
terraform apply
```

Your observability stack will be ready in minutes!
