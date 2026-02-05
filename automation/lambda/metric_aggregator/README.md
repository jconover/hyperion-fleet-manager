# Hyperion Fleet Manager - Metric Aggregator Lambda

A serverless AWS Lambda function that aggregates metrics across the Hyperion Fleet Manager Windows server fleet and publishes consolidated metrics to CloudWatch.

## Overview

The Metric Aggregator Lambda function runs on a scheduled basis (default: every 5 minutes) to:

- Collect CPU, memory, and disk utilization metrics from CloudWatch
- Query EC2 for fleet instance information
- Retrieve compliance status from AWS Systems Manager (SSM)
- Calculate fleet health, compliance, and cost efficiency scores
- Publish aggregated metrics to a custom CloudWatch namespace

## Architecture

```
+------------------+     +-----------------+     +------------------+
|  CloudWatch      |     |    Lambda       |     |   CloudWatch     |
|  Events          |---->|    Metric       |---->|   Custom         |
|  (Schedule)      |     |    Aggregator   |     |   Namespace      |
+------------------+     +--------+--------+     +------------------+
                                 |
                    +------------+------------+
                    |            |            |
              +-----v----+ +-----v----+ +-----v----+
              |   EC2    | |   SSM    | |CloudWatch|
              |  (Fleet  | |(Compliance| |  (CPU    |
              | Instances)| |  Data)   | |  Metrics)|
              +----------+ +----------+ +----------+
```

### Data Flow

```
1. CloudWatch Events triggers Lambda (every 5 minutes)
                    |
                    v
2. Query EC2 for fleet instances (filtered by "Fleet" tag)
                    |
                    v
3. Query CloudWatch for utilization metrics
   - CPUUtilization (AWS/EC2 namespace)
   - mem_used_percent (CWAgent namespace)
   - disk_used_percent (CWAgent namespace)
                    |
                    v
4. Query SSM for compliance status
                    |
                    v
5. Calculate aggregated metrics and scores
   - Fleet Health Score
   - Compliance Score
   - Cost Efficiency Score
   - Capacity Utilization
                    |
                    v
6. Publish to CloudWatch (Hyperion/FleetManager namespace)
```

## Project Structure

```
metric_aggregator/
├── handler.py           # Lambda entry point
├── metrics.py           # Metric definitions and score calculations
├── cloudwatch_client.py # CloudWatch API wrapper
├── ssm_client.py        # SSM and EC2 API wrappers
├── config.py            # Configuration management
├── requirements.txt     # Python dependencies
├── template.yaml        # SAM deployment template
├── Makefile             # Build and deployment automation
├── README.md            # This file
└── tests/
    ├── __init__.py
    ├── conftest.py      # Pytest fixtures
    ├── test_handler.py  # Handler tests
    └── test_metrics.py  # Metric calculation tests
```

## Metrics Published

### Instance Count Metrics

| Metric Name        | Unit  | Description                      |
|--------------------|-------|----------------------------------|
| InstanceCount      | Count | Total instances in fleet         |
| RunningInstances   | Count | Number of running instances      |
| StoppedInstances   | Count | Number of stopped instances      |
| PendingInstances   | Count | Number of pending instances      |

### Utilization Metrics

| Metric Name        | Unit    | Description                           |
|--------------------|---------|---------------------------------------|
| CPUUtilization     | Percent | Average CPU utilization across fleet  |
| MemoryUtilization  | Percent | Average memory utilization            |
| DiskUtilization    | Percent | Average disk utilization              |

### Score Metrics

| Metric Name         | Unit    | Description                                |
|---------------------|---------|-------------------------------------------|
| FleetHealthScore    | Percent | Overall fleet health (0-100)              |
| ComplianceScore     | Percent | Compliance percentage (0-100)             |
| CostEfficiencyScore | Percent | Cost efficiency rating (0-100)            |
| CapacityUtilization | Percent | Average capacity utilization (0-100)      |

### Cost Metrics

| Metric Name       | Unit | Description                          |
|-------------------|------|--------------------------------------|
| CostPerInstance   | None | Hourly cost per running instance     |
| TotalFleetCost    | None | Total hourly cost of running fleet   |

### Metric Dimensions

All metrics include the following dimensions:

- **Environment**: Deployment environment (dev, staging, production)
- **FleetName**: Name of the monitored fleet

## Environment Variables

| Variable                     | Required | Default              | Description                           |
|------------------------------|----------|----------------------|---------------------------------------|
| ENVIRONMENT                  | No       | dev                  | Deployment environment                |
| AWS_REGION                   | No       | us-east-1            | AWS region for API calls              |
| FLEET_NAME                   | No       | hyperion-fleet       | Fleet name for tag filtering          |
| METRIC_NAMESPACE             | No       | Hyperion/FleetManager| CloudWatch custom namespace           |
| AGGREGATION_PERIOD_MINUTES   | No       | 5                    | Metric aggregation period             |
| MAX_INSTANCES_PER_QUERY      | No       | 100                  | Max instances per CloudWatch query    |
| ENABLE_DETAILED_METRICS      | No       | false                | Enable per-instance metrics           |
| LOG_LEVEL                    | No       | INFO                 | Logging level                         |
| POWERTOOLS_SERVICE_NAME      | No       | hyperion-metric-aggregator | Lambda Powertools service name |
| POWERTOOLS_METRICS_NAMESPACE | No       | Hyperion/FleetManager| Lambda Powertools metrics namespace   |

## IAM Permissions Required

The Lambda function requires the following IAM permissions:

```yaml
# CloudWatch - Read metrics
- cloudwatch:GetMetricData
- cloudwatch:GetMetricStatistics
- cloudwatch:ListMetrics

# CloudWatch - Write custom metrics
- cloudwatch:PutMetricData (restricted to Hyperion/FleetManager namespace)

# EC2 - Describe instances
- ec2:DescribeInstances
- ec2:DescribeTags

# SSM - Read inventory and compliance
- ssm:DescribeInstanceInformation
- ssm:GetInventory
- ssm:ListComplianceItems
- ssm:ListComplianceSummaries
- ssm:ListResourceComplianceSummaries
- ssm:DescribeInstancePatchStates

# CloudWatch Logs
- logs:CreateLogGroup
- logs:CreateLogStream
- logs:PutLogEvents

# X-Ray (if tracing enabled)
- xray:PutTraceSegments
- xray:PutTelemetryRecords
- xray:GetSamplingRules
- xray:GetSamplingTargets
```

## Deployment

### Prerequisites

- AWS CLI configured with appropriate credentials
- AWS SAM CLI installed (`pip install aws-sam-cli`)
- Python 3.11+
- Make (optional, for using Makefile)

### Deploy with SAM

```bash
# Build the Lambda package
sam build

# Deploy to AWS (guided mode for first deployment)
sam deploy --guided

# Subsequent deployments
sam deploy --parameter-overrides Environment=dev FleetName=my-fleet
```

### Deploy with Makefile

```bash
# Build the package
make build

# Run tests
make test

# Deploy to dev
make deploy ENV=dev

# Deploy to production
make deploy ENV=production
```

### SAM Parameters

| Parameter              | Default       | Description                          |
|------------------------|---------------|--------------------------------------|
| Environment            | dev           | Deployment environment               |
| FleetName              | hyperion-fleet| Fleet name for monitoring            |
| VpcId                  | (empty)       | VPC ID (optional, for VPC access)    |
| SubnetIds              | (empty)       | Subnet IDs (optional)                |
| EnableVpcAccess        | false         | Enable VPC access for Lambda         |
| AggregationPeriodMinutes| 5            | Metric collection frequency          |

## Local Testing

### Setup Development Environment

```bash
# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # Linux/Mac
# or
.venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt

# Install test dependencies
pip install pytest pytest-cov moto pytest-mock boto3-stubs[cloudwatch,ssm,ec2]
```

### Run Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=. --cov-report=html

# Run specific test file
pytest tests/test_metrics.py -v

# Run with verbose output
pytest -v --tb=short
```

### Local Invocation with SAM

```bash
# Build the function
sam build

# Invoke locally with test event
sam local invoke MetricAggregatorFunction -e events/scheduled_event.json

# Start local API (if API Gateway configured)
sam local start-lambda
```

### Create Test Event

Create `events/scheduled_event.json`:

```json
{
  "version": "0",
  "id": "12345678-1234-1234-1234-123456789012",
  "detail-type": "Scheduled Event",
  "source": "aws.events",
  "account": "123456789012",
  "time": "2024-01-01T12:00:00Z",
  "region": "us-east-1",
  "resources": [
    "arn:aws:events:us-east-1:123456789012:rule/test-rule"
  ],
  "detail": {}
}
```

## Troubleshooting

### Common Issues

#### 1. No Instances Found

**Symptom**: Lambda returns success but reports 0 instances processed.

**Cause**: Instances not tagged correctly.

**Solution**: Ensure EC2 instances have the `Fleet` tag with the correct value matching `FLEET_NAME`:

```bash
aws ec2 create-tags --resources i-1234567890abcdef0 \
  --tags Key=Fleet,Value=hyperion-fleet
```

#### 2. Missing Memory/Disk Metrics

**Symptom**: Memory and disk utilization show as 0.

**Cause**: CloudWatch Agent not installed or configured.

**Solution**: Install and configure the CloudWatch Agent on fleet instances:

```bash
# Install CloudWatch Agent
aws ssm send-command \
  --document-name "AWS-ConfigureAWSPackage" \
  --parameters '{"action":["Install"],"name":["AmazonCloudWatchAgent"]}' \
  --targets "Key=tag:Fleet,Values=hyperion-fleet"
```

#### 3. Permission Denied Errors

**Symptom**: Lambda fails with AccessDenied errors.

**Cause**: Missing IAM permissions.

**Solution**: Verify the Lambda execution role has all required permissions. Check CloudWatch Logs for specific permission errors.

#### 4. Timeout Errors

**Symptom**: Lambda times out before completing.

**Cause**: Too many instances to process in allotted time.

**Solution**:
- Increase Lambda timeout in `template.yaml`
- Reduce `MAX_INSTANCES_PER_QUERY`
- Increase Lambda memory for faster execution

### Viewing Logs

```bash
# Tail logs in real-time
sam logs -n MetricAggregatorFunction --stack-name hyperion-metric-aggregator-dev --tail

# View recent logs
aws logs tail /aws/lambda/hyperion-metric-aggregator-dev --since 1h
```

### Debugging

Enable debug logging by setting `LOG_LEVEL=DEBUG` in the Lambda environment variables.

```bash
aws lambda update-function-configuration \
  --function-name hyperion-metric-aggregator-dev \
  --environment Variables={LOG_LEVEL=DEBUG}
```

## Monitoring

### CloudWatch Dashboard

The SAM template automatically creates a CloudWatch dashboard with:

- Lambda invocations and errors
- Lambda duration (average and p99)
- Fleet health score over time
- Instance counts
- CPU, memory utilization trends
- Compliance score

Access the dashboard:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=Hyperion-MetricAggregator-{Environment}
```

### CloudWatch Alarms

The following alarms are created automatically:

| Alarm Name                                    | Condition                    |
|-----------------------------------------------|------------------------------|
| hyperion-metric-aggregator-errors-{env}       | Errors >= 1 in 2 periods     |
| hyperion-metric-aggregator-duration-{env}     | Duration > 60s avg (3 periods)|

### X-Ray Tracing

X-Ray tracing is enabled by default. View traces in the AWS X-Ray console to analyze:

- Function execution time breakdown
- AWS SDK call latencies
- Error locations

## Score Calculations

### Fleet Health Score

Weighted combination of:
- CPU utilization health (30%)
- Memory utilization health (25%)
- Disk utilization health (20%)
- Compliance percentage (25%)

Thresholds:
- Healthy: >= 80
- Warning: 60-79
- Critical: < 60

### Compliance Score

Percentage of compliant instances:
```
Score = (Compliant Instances / Total Checked Instances) * 100
```

### Cost Efficiency Score

Based on CPU utilization distribution:
- Well-utilized (>= 20% CPU): 100 points
- Underutilized (5-20% CPU): 50 points
- Idle (< 5% CPU): 10 points

Final score is the weighted average.

### Capacity Utilization

Average of all utilization metrics (CPU, memory, disk).

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass (`make test`)
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
