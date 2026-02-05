# Hyperion Fleet Manager - Observability Dashboards

This directory contains CloudWatch dashboard modules for the Hyperion Fleet Manager project.

## Modules

### Cost Dashboard

The Cost Dashboard module (`cost_dashboard.tf`, `cost_variables.tf`, `cost_outputs.tf`, `cost_anomaly_detection.tf`) provides comprehensive AWS cost monitoring capabilities.

#### Features

- **Total Estimated Charges**: Single-value widget showing current month's estimated total
- **Budget Utilization Gauge**: Visual gauge with warning/critical threshold annotations
- **Cost by Service**: Stacked time series and pie chart showing cost distribution
- **EC2 Cost Analysis**: Instance type running hours, reserved vs on-demand usage
- **Data Transfer Costs**: Network in/out volume and associated charges
- **EBS Volume Costs**: Storage costs and I/O metrics
- **Cost Trends**: Daily and weekly cost trend analysis
- **Environment Comparison**: Cross-environment cost comparison (optional)
- **Anomaly Detection**: ML-powered cost anomaly detection with SNS alerts

#### Important Notes

**Region Requirement**: AWS Billing metrics are ONLY available in the `us-east-1` region. This module must be deployed to us-east-1 or use a provider alias.

**Prerequisites**:
1. Enable billing alerts in the AWS Billing console
2. Configure cost allocation tags for environment tracking
3. For multi-account setups, enable Organization Cost Explorer access

#### Usage

```hcl
module "cost_dashboard" {
  source = "./modules/observability/dashboards"

  # Required variables
  cost_environment  = "production"
  cost_project_name = "hyperion"

  # Budget configuration
  cost_budget_amount = 5000
  cost_alert_thresholds = {
    warning  = 80
    critical = 100
  }

  # Anomaly detection
  cost_enable_cost_anomaly_detection = true
  cost_anomaly_threshold_expression  = 100  # $100 above expected
  cost_anomaly_threshold_percentage  = 10   # 10% above expected

  # Notifications
  cost_alert_email_addresses = ["ops-team@example.com"]

  # Optional: Multi-account setup
  cost_enable_linked_account_widgets = false
  cost_linked_accounts = [
    {
      account_id   = "123456789012"
      account_name = "development"
    }
  ]

  # Tags
  cost_tags = {
    Project     = "hyperion-fleet-manager"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

#### Outputs

| Output | Description |
|--------|-------------|
| `cost_dashboard_arn` | ARN of the CloudWatch Cost Monitoring Dashboard |
| `cost_dashboard_name` | Name of the CloudWatch Cost Monitoring Dashboard |
| `cost_dashboard_url` | Direct URL to the dashboard in AWS Console |
| `cost_alerts_sns_topic_arn` | ARN of the SNS topic for cost anomaly alerts |
| `cost_anomaly_monitor_arn` | ARN of the Cost Anomaly Detection monitor |
| `cost_anomaly_subscription_arn` | ARN of the anomaly subscription |
| `cost_budget_warning_alarm_arn` | ARN of the budget warning CloudWatch alarm |
| `cost_budget_critical_alarm_arn` | ARN of the budget critical CloudWatch alarm |
| `cost_budget_thresholds` | Calculated budget threshold values |
| `cost_dashboard_configuration` | Summary of dashboard configuration |

### Fleet Health Dashboard

The Fleet Health Dashboard (`fleet-health.json`, referenced by parent module) provides operational health monitoring for the Windows server fleet.

### Security Dashboard

The Security Dashboard (`security_dashboard.tf`) provides security event monitoring and compliance visibility.

## Variables Reference

### Cost Dashboard Variables

See `cost_variables.tf` for the complete list of variables. Key variables include:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cost_environment` | string | required | Environment name (dev/staging/production) |
| `cost_project_name` | string | "hyperion" | Project name for naming |
| `cost_budget_amount` | number | 1000 | Monthly budget in USD |
| `cost_alert_thresholds` | object | {warning: 80, critical: 100} | Alert thresholds as percentages |
| `cost_enable_cost_anomaly_detection` | bool | true | Enable anomaly detection |
| `cost_anomaly_threshold_expression` | number | 100 | Dollar amount for anomaly alerts |
| `cost_anomaly_threshold_percentage` | number | 10 | Percentage for anomaly alerts |
| `cost_services_to_track` | list(string) | [EC2, EBS, S3, etc.] | AWS services to monitor |

## Architecture

```
observability/dashboards/
|-- cost_dashboard.tf           # Main cost dashboard resource
|-- cost_anomaly_detection.tf   # Cost anomaly monitors and SNS
|-- cost_variables.tf           # Cost dashboard input variables
|-- cost_outputs.tf             # Cost dashboard output values
|-- fleet-health.json           # Fleet health dashboard template
|-- fleet_health_dashboard.tf   # Fleet health dashboard resources
|-- security_dashboard.tf       # Security dashboard resources
|-- variables.tf                # Shared/fleet-health variables
|-- outputs.tf                  # Shared/fleet-health outputs
|-- versions.tf                 # Terraform version constraints
+-- README.md                   # This file
```

## Best Practices

### Cost Optimization

1. **Set realistic budgets**: Start with current spending and adjust
2. **Configure meaningful thresholds**: Warning at 80%, critical at 100%
3. **Enable anomaly detection**: Catch unexpected spending early
4. **Use service-specific monitors**: Track high-cost services individually
5. **Review regularly**: Check dashboard weekly minimum

### Security

1. **Encrypt SNS topics**: Use KMS for sensitive alerts
2. **Limit email recipients**: Only necessary personnel
3. **Use IAM least privilege**: Restrict access to billing data

### Operational

1. **Deploy to us-east-1**: Required for billing metrics
2. **Enable cost allocation tags**: Improves cost breakdown accuracy
3. **Integrate with budgets**: Use AWS Budgets for proactive alerts

## Troubleshooting

### No billing data appearing

1. Verify billing alerts are enabled in AWS Billing console
2. Confirm deployment is in us-east-1 region
3. Wait up to 4-6 hours for billing data to populate

### Anomaly detection not working

1. Cost Anomaly Detection requires at least 10 days of billing history
2. Verify SNS topic permissions include `costalerts.amazonaws.com`
3. Check subscription threshold values are appropriate

### Multi-account costs not showing

1. Enable Cost Explorer in the management account
2. Configure linked account access
3. Verify cost allocation tags are configured organization-wide

## Related Documentation

- [AWS Cost Explorer User Guide](https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html)
- [AWS Cost Anomaly Detection](https://docs.aws.amazon.com/cost-management/latest/userguide/manage-ad.html)
- [CloudWatch Dashboards](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards.html)
- [Hyperion Fleet Manager Architecture](../../docs/architecture/ARCHITECTURE.md)
