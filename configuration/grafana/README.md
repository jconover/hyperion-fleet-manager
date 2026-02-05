# Hyperion Fleet Manager - Grafana Configuration

This directory contains Grafana dashboards and provisioning configuration for monitoring the Hyperion Fleet Manager infrastructure.

## Directory Structure

```
grafana/
├── dashboards/                          # Dashboard JSON files
│   ├── fleet-overview.json              # Fleet health overview dashboard
│   ├── fleet-performance.json           # Detailed performance metrics
│   ├── fleet-compliance.json            # Compliance and configuration status
│   └── fleet-costs.json                 # Cost monitoring and analysis
├── provisioning/
│   ├── dashboards/
│   │   └── hyperion.yml                 # Dashboard provisioning config
│   └── datasources/
│       └── cloudwatch.yml               # CloudWatch data source config
└── README.md                            # This file
```

## Prerequisites

- Grafana 10.x or later
- AWS account with appropriate IAM permissions
- CloudWatch metrics enabled for your AWS resources
- Custom metrics published to the following namespaces:
  - `Hyperion/Compliance`
  - `Hyperion/Costs`
  - `Hyperion/DSC`
  - `CWAgent` (for custom Windows metrics)

## Installation

### Option 1: Docker / Container Deployment

1. Mount the dashboards directory to your Grafana container:

```yaml
# docker-compose.yml example
services:
  grafana:
    image: grafana/grafana:10.2.0
    volumes:
      - ./configuration/grafana/dashboards:/etc/grafana/dashboards/hyperion:ro
      - ./configuration/grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./configuration/grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:ro
    environment:
      - AWS_DEFAULT_REGION=us-east-1
      # Use IAM role or configure credentials
      # - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      # - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
```

2. Start Grafana:

```bash
docker-compose up -d grafana
```

### Option 2: Standalone Grafana Installation

1. Copy provisioning files to Grafana's provisioning directory:

```bash
# Default location: /etc/grafana/provisioning/
sudo cp -r provisioning/datasources/* /etc/grafana/provisioning/datasources/
sudo cp -r provisioning/dashboards/* /etc/grafana/provisioning/dashboards/

# Create dashboard directory
sudo mkdir -p /etc/grafana/dashboards/hyperion
sudo cp dashboards/*.json /etc/grafana/dashboards/hyperion/
```

2. Restart Grafana:

```bash
sudo systemctl restart grafana-server
```

### Option 3: Manual Import

1. Log in to Grafana
2. Navigate to **Configuration** > **Data Sources**
3. Add a new CloudWatch data source (see Data Source Setup below)
4. Navigate to **Dashboards** > **Import**
5. Upload each JSON file from the `dashboards/` directory

## Data Source Setup

### CloudWatch Data Source Configuration

The CloudWatch data source is configured in `provisioning/datasources/cloudwatch.yml`.

**Authentication Options:**

1. **IAM Instance Profile (Recommended for EC2/ECS)**
   - Ensure Grafana runs on an EC2 instance or ECS task with an IAM role
   - Set `authType: default` in the configuration

2. **IAM Role Assumption**
   - Configure `assumeRoleArn` in the data source
   - Grafana's execution role needs `sts:AssumeRole` permission

3. **Access Keys (Not Recommended for Production)**
   - Set `authType: keys`
   - Configure `accessKey` and `secretKey` in `secureJsonData`

**Default Region:**

The data source uses `us-east-1` by default. Override this with the `AWS_DEFAULT_REGION` environment variable.

> **Note:** AWS Billing metrics are **only available in us-east-1**. The cost dashboard queries this region directly.

## Dashboard Overview

### Fleet Overview (`fleet-overview.json`)

Provides a high-level view of fleet health:

- Total instances and health status
- Active alarms
- Fleet average CPU and memory utilization
- Instance status table
- Geographic distribution

**Variables:**
- `$datasource` - CloudWatch data source
- `$region` - AWS region
- `$environment` - Environment filter (dev, staging, prod)

### Fleet Performance (`fleet-performance.json`)

Detailed performance metrics:

- CPU utilization by instance and role
- Memory utilization trends
- Disk I/O (IOPS and throughput)
- Network performance (throughput and packets)
- EBS burst balance monitoring
- Performance comparison table

**Variables:**
- `$datasource` - CloudWatch data source
- `$region` - AWS region
- `$instance` - Instance filter (multi-select)
- `$period` - Metric aggregation period

### Fleet Compliance (`fleet-compliance.json`)

Compliance and configuration monitoring:

- Overall compliance score
- Control pass/fail status
- Findings by severity and category
- Compliance score trends
- Non-compliant instance details
- DSC configuration status

**Variables:**
- `$datasource` - CloudWatch data source
- `$region` - AWS region
- `$environment` - Environment filter

### Fleet Costs (`fleet-costs.json`)

Cost monitoring and optimization:

- Current month spend (total and by service)
- Budget vs. actual spending
- Daily/weekly cost trends
- Cost per instance analysis
- Savings opportunities and recommendations
- Cost by environment breakdown

**Variables:**
- `$datasource` - CloudWatch data source
- `$region` - AWS region
- `$environment` - Environment filter
- `$timeRange` - Time range for cost analysis

## Variable Configuration

All dashboards use template variables for flexibility:

| Variable | Type | Description |
|----------|------|-------------|
| `$datasource` | Data Source | CloudWatch data source selector |
| `$region` | Custom | AWS region (us-east-1, us-west-2, etc.) |
| `$environment` | Query | Environment tag values |
| `$instance` | Query | EC2 instance IDs |
| `$period` | Custom | Metric aggregation period |
| `$timeRange` | Custom | Cost analysis time range |

## IAM Permissions Required

The IAM role or user used by Grafana needs the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudWatchReadOnly",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:DescribeAlarmsForMetric",
                "cloudwatch:DescribeAlarmHistory",
                "cloudwatch:DescribeAlarms",
                "cloudwatch:ListMetrics",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:GetMetricData",
                "cloudwatch:GetInsightRuleReport"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CloudWatchLogsReadOnly",
            "Effect": "Allow",
            "Action": [
                "logs:DescribeLogGroups",
                "logs:GetLogGroupFields",
                "logs:StartQuery",
                "logs:StopQuery",
                "logs:GetQueryResults",
                "logs:GetLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Sid": "EC2DescribeReadOnly",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeRegions"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ResourceGroupsTagging",
            "Effect": "Allow",
            "Action": [
                "tag:GetResources"
            ],
            "Resource": "*"
        }
    ]
}
```

**For Cost Dashboard (additional permissions):**

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "BillingViewAccess",
            "Effect": "Allow",
            "Action": [
                "ce:GetCostAndUsage",
                "ce:GetCostForecast",
                "ce:GetReservationUtilization",
                "ce:GetSavingsPlansUtilization",
                "budgets:ViewBudget"
            ],
            "Resource": "*"
        }
    ]
}
```

## Custom Metrics

The dashboards expect custom metrics in the following namespaces:

### Hyperion/Compliance

Published by the HyperionCompliance PowerShell module:

| Metric | Description | Dimensions |
|--------|-------------|------------|
| ComplianceScore | Overall compliance percentage | Environment |
| TotalControls | Total number of controls | Environment |
| PassedControls | Number of passed controls | Category, Environment |
| FailedControls | Number of failed controls | Category, Environment |
| CriticalFindings | Critical security findings | Environment |
| InstanceComplianceScore | Per-instance compliance | InstanceId |

### Hyperion/Costs

Published by the HyperionMetrics PowerShell module:

| Metric | Description | Dimensions |
|--------|-------------|------------|
| BudgetUsagePercent | Budget utilization percentage | - |
| MonthlyBudget | Monthly budget amount | - |
| EstimatedInstanceCost | Estimated monthly cost per instance | InstanceId |
| PotentialMonthlySavings | Identified savings opportunities | - |
| EnvironmentCost | Cost by environment | Environment |

### Hyperion/DSC

Published by DSC configuration scripts:

| Metric | Description | Dimensions |
|--------|-------------|------------|
| DSCStatus | DSC configuration status | InstanceId |
| ResourcesInDesiredState | Resources in compliance | InstanceId |
| ResourcesNotInDesiredState | Resources with drift | InstanceId |

## Troubleshooting

### Data Source Connection Issues

1. **Verify IAM permissions:**
   ```bash
   aws cloudwatch list-metrics --namespace AWS/EC2
   ```

2. **Check Grafana logs:**
   ```bash
   sudo journalctl -u grafana-server -f
   # Or for Docker:
   docker logs grafana -f
   ```

3. **Test credentials in Grafana:**
   - Go to Data Sources > CloudWatch
   - Click "Save & Test"

### Missing Metrics

1. **Ensure CloudWatch Agent is installed:**
   ```powershell
   Get-Service AmazonCloudWatchAgent
   ```

2. **Verify custom metrics are being published:**
   ```bash
   aws cloudwatch list-metrics --namespace Hyperion/Compliance
   ```

3. **Check metric retention:**
   - CloudWatch retains metrics based on resolution
   - High-resolution (1-second): 3 hours
   - Standard (1-minute): 15 days
   - Aggregated (5-minute): 63 days
   - Aggregated (1-hour): 455 days

### Dashboard Not Loading

1. **Check provisioning path:**
   ```bash
   ls -la /etc/grafana/dashboards/hyperion/
   ```

2. **Verify JSON syntax:**
   ```bash
   python -m json.tool dashboards/fleet-costs.json > /dev/null
   ```

3. **Review provisioning logs:**
   ```bash
   grep -i "provisioning" /var/log/grafana/grafana.log
   ```

## Screenshots

*(Add screenshots of each dashboard here)*

### Fleet Overview
![Fleet Overview](screenshots/fleet-overview.png)

### Fleet Performance
![Fleet Performance](screenshots/fleet-performance.png)

### Fleet Compliance
![Fleet Compliance](screenshots/fleet-compliance.png)

### Fleet Costs
![Fleet Costs](screenshots/fleet-costs.png)

## Contributing

1. Make changes to dashboard JSON files
2. Test in a development Grafana instance
3. Export updated JSON (Settings > JSON Model > Copy to clipboard)
4. Replace the file content with exported JSON
5. Ensure `id` is set to `null` for portability
6. Update `version` number
7. Submit a pull request

## Related Documentation

- [Grafana CloudWatch Data Source](https://grafana.com/docs/grafana/latest/datasources/cloudwatch/)
- [Grafana Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [AWS CloudWatch Metrics Reference](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/aws-services-cloudwatch-metrics.html)
- [CloudWatch Agent Configuration](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html)

## License

This project is licensed under the MIT License - see the [LICENSE](../../LICENSE) file for details.
