# CloudWatch Logging Module

Terraform module for creating and managing CloudWatch Log Groups, Metric Filters, Logs Insights Queries, and Subscription Filters for the Hyperion Fleet Manager Windows server fleet.

## Features

- **Six specialized log groups** for different log types (application, system, security, PowerShell, SSM, DSC)
- **Configurable retention periods** per log type
- **KMS encryption** for sensitive logs (security and PowerShell always encrypted when KMS key provided)
- **Comprehensive metric filters** for error detection, security monitoring, and operational insights
- **Pre-built Logs Insights queries** for common analysis tasks
- **Optional S3 archival** via Kinesis Firehose with dynamic partitioning
- **Optional Lambda subscription** for real-time processing
- **Cross-account log sharing** support

## Usage

### Basic Usage

```hcl
module "logging" {
  source = "./modules/observability/logging"

  environment  = "production"
  project_name = "hyperion-fleet"

  retention_days = {
    application = 30
    system      = 60
    security    = 90
    powershell  = 90
    ssm         = 30
    dsc         = 30
  }

  tags = {
    Owner = "platform-team"
  }
}
```

### With KMS Encryption

```hcl
module "logging" {
  source = "./modules/observability/logging"

  environment  = "production"
  project_name = "hyperion-fleet"

  kms_key_arn              = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  encrypt_application_logs = true
  encrypt_system_logs      = true
  encrypt_ssm_logs         = true
  encrypt_dsc_logs         = true

  retention_days = {
    application = 30
    system      = 60
    security    = 365  # Longer retention for compliance
    powershell  = 365
    ssm         = 30
    dsc         = 30
  }

  tags = {
    Compliance = "SOC2"
  }
}
```

### With S3 Archival

```hcl
module "logging" {
  source = "./modules/observability/logging"

  environment  = "production"
  project_name = "hyperion-fleet"

  # S3 Archival via Kinesis Firehose
  enable_s3_archival       = true
  archive_bucket_name      = "my-log-archive-bucket"
  archive_kms_key_arn      = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  firehose_buffer_size     = 10
  firehose_buffer_interval = 300

  tags = {
    DataRetention = "7years"
  }
}
```

### With Lambda Processing

```hcl
module "logging" {
  source = "./modules/observability/logging"

  environment  = "production"
  project_name = "hyperion-fleet"

  # Lambda for real-time processing
  enable_lambda_processing      = true
  lambda_processor_arn          = "arn:aws:lambda:us-east-1:123456789012:function:log-processor"
  lambda_filter_pattern         = "?ERROR ?CRITICAL ?4625"
  enable_application_error_lambda = true

  tags = {
    RealTimeAlerts = "enabled"
  }
}
```

### With Cross-Account Sharing

```hcl
module "logging" {
  source = "./modules/observability/logging"

  environment  = "production"
  project_name = "hyperion-fleet"

  # Cross-account log sharing to central logging account
  enable_cross_account_sharing    = true
  cross_account_destination_arn   = "arn:aws:kinesis:us-east-1:999888777666:stream/central-logs"
  cross_account_principal_arns    = ["arn:aws:iam::999888777666:root"]
  cross_account_share_security_logs = true

  tags = {
    CentralLogging = "enabled"
  }
}
```

### With Custom Metric Filters

```hcl
module "logging" {
  source = "./modules/observability/logging"

  environment  = "production"
  project_name = "hyperion-fleet"

  custom_metric_filters = {
    database_connection_errors = {
      log_group             = "application"
      pattern               = "?\"Database connection failed\" ?\"Connection timeout\" ?\"SQL Error\""
      metric_name           = "DatabaseConnectionErrors"
      metric_value          = "1"
      metric_unit           = "Count"
      additional_dimensions = {
        Component = "database"
      }
    }
    api_latency_high = {
      log_group             = "application"
      pattern               = "?\"API response time exceeded\" ?\"Slow query\""
      metric_name           = "HighLatencyEvents"
      metric_value          = "1"
      metric_unit           = "Count"
      additional_dimensions = {
        Component = "api"
      }
    }
  }

  tags = {
    Monitoring = "custom"
  }
}
```

## Log Groups

| Log Group | Path | Description |
|-----------|------|-------------|
| Application | `/hyperion/fleet/application` | Application logs, errors, diagnostics |
| System | `/hyperion/fleet/system` | Windows Event Logs (System channel) |
| Security | `/hyperion/fleet/security` | Security events, authentication logs |
| PowerShell | `/hyperion/fleet/powershell` | PowerShell transcript and script block logs |
| SSM | `/hyperion/fleet/ssm` | SSM Run Command execution logs |
| DSC | `/hyperion/fleet/dsc` | DSC compliance and configuration logs |

## Metric Filters

The module creates the following metric filters:

### Error Metrics
- `ApplicationErrorCount` - Errors in application logs
- `SystemErrorCount` - Errors in system logs
- `ApplicationWarningCount` - Warnings in application logs
- `SystemWarningCount` - Warnings in system logs
- `ExceptionCount` - Exception occurrences
- `UnhandledExceptionCount` - Unhandled/fatal exceptions
- `TotalCriticalEventCount` - Critical events across logs

### Security Metrics
- `AuthenticationFailureCount` - Failed login attempts (Event IDs 4625, 4771, 4776)
- `AccountLockoutCount` - Account lockout events (Event ID 4740)
- `PrivilegeEscalationCount` - Privilege use events (Event IDs 4672, 4673, 4674)
- `PowerShellSuspiciousActivityCount` - Potentially malicious PowerShell patterns
- `PowerShellExecutionBypassCount` - Execution policy bypass attempts

### Operational Metrics
- `SSMCommandFailureCount` - Failed SSM command executions
- `DSCConfigurationDriftCount` - DSC configuration drift detections
- `DSCApplyFailureCount` - Failed DSC configuration applications

## Logs Insights Queries

Pre-built queries are organized into categories:

### Error Analysis
- Top errors by count
- Errors by instance
- Error trends over time
- Recent critical errors

### Performance Analysis
- Slow operations (>5s)
- Operation duration percentiles
- Request throughput

### Security Analysis
- Failed authentication attempts
- Account lockout events
- Privilege escalation analysis
- Suspicious security events

### Tracing & Correlation
- Correlation ID trace
- Request flow analysis
- Cross-service error correlation

### Operations
- SSM command execution history
- SSM failure analysis
- DSC compliance status
- DSC configuration drift details
- PowerShell script execution
- Log volume by type
- Instance health summary

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name | `string` | n/a | yes |
| project_name | Project name | `string` | `"hyperion-fleet"` | no |
| retention_days | Log retention periods by type | `object` | See variables.tf | no |
| kms_key_arn | KMS key ARN for encryption | `string` | `null` | no |
| enable_s3_archival | Enable S3 archival | `bool` | `false` | no |
| archive_bucket_name | S3 bucket for archival | `string` | `""` | no |
| enable_lambda_processing | Enable Lambda processing | `bool` | `false` | no |
| lambda_processor_arn | Lambda function ARN | `string` | `null` | no |
| enable_cross_account_sharing | Enable cross-account sharing | `bool` | `false` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

See `variables.tf` for complete list of inputs.

## Outputs

| Name | Description |
|------|-------------|
| log_group_arns | Map of log group types to ARNs |
| log_group_names | Map of log group types to names |
| metric_filter_names | Map of metric filter purposes to names |
| insights_query_names | Map of query purposes to names |
| cloudwatch_namespace | CloudWatch namespace for metrics |
| firehose_delivery_stream_arn | Firehose stream ARN (if enabled) |
| configuration_summary | Module configuration summary |

See `outputs.tf` for complete list of outputs.

## Architecture

```
                                    +------------------+
                                    |   CloudWatch     |
                                    |   Logs Insights  |
                                    +--------+---------+
                                             |
+---------------+    +-------------------+   |   +------------------+
| EC2 Instances |    |   CloudWatch      |<--+   |   CloudWatch     |
| (Windows)     |--->|   Log Groups      |------>|   Metrics        |
+---------------+    +-------------------+       +------------------+
                             |                           |
                             v                           v
                     +-------+-------+           +-------+-------+
                     |               |           |               |
              +------+------+ +------+------+    |   CloudWatch  |
              |   Kinesis   | |   Lambda    |    |    Alarms     |
              |   Firehose  | |   Function  |    +---------------+
              +------+------+ +------+------+
                     |               |
                     v               v
              +------+------+ +------+------+
              |     S3      | |   Custom    |
              |   Archive   | |  Processing |
              +-------------+ +-------------+
```

## Security Considerations

1. **Encryption**: Security and PowerShell logs are always encrypted when a KMS key is provided
2. **Data Protection**: Optional data protection policies can mask sensitive data (SSN, credit cards)
3. **Cross-Account**: Use resource policies to control cross-account access
4. **IAM**: Module creates minimal IAM roles with least-privilege policies

## Cost Considerations

1. **Log Group Class**: Use `INFREQUENT_ACCESS` for logs rarely queried to reduce costs
2. **Retention**: Set appropriate retention periods to avoid unnecessary storage costs
3. **Firehose**: Buffer settings affect cost and latency tradeoffs
4. **Metric Filters**: Each filter incurs additional costs when matching events

## License

MIT License - See LICENSE file for details.
