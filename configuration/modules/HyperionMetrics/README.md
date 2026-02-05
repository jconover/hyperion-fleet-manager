# HyperionMetrics PowerShell Module

CloudWatch custom metrics module for Hyperion Fleet Manager. Provides comprehensive cmdlets for publishing system metrics, compliance metrics, application health metrics, and scheduled metric collection to Amazon CloudWatch.

## Overview

HyperionMetrics simplifies AWS CloudWatch custom metrics by providing high-level PowerShell cmdlets that handle batching, dimension management, unit validation, and scheduled collection. Designed for enterprise Windows and Linux fleet monitoring.

## Features

- **System Metrics**: CPU, memory, disk, and network metrics collection
- **Compliance Metrics**: Compliance percentage, control counts, remediation tracking
- **Application Metrics**: Request counts, latency, error rates, queue depth, job status
- **Metric Batching**: Automatic batching to comply with CloudWatch 20-metric limit
- **Standard Dimensions**: Consistent Environment, InstanceId, Role, Project dimensions
- **EC2 Metadata Integration**: Auto-detection of instance ID, region, availability zone
- **Scheduled Collection**: Windows Task Scheduler and Linux systemd/cron integration
- **Cross-Platform**: Full support for Windows and Linux (PowerShell 7+)

## Requirements

- **PowerShell**: 7.0 or higher
- **AWS Modules**:
  - `AWS.Tools.CloudWatch` (4.1.0+)
- **AWS Permissions**: IAM permissions for CloudWatch PutMetricData
- **Optional**: EC2 instance role for automatic instance ID detection

## Installation

### From Local Path

```powershell
# Import module
Import-Module /home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionMetrics

# Verify installation
Get-Module HyperionMetrics
Get-Command -Module HyperionMetrics
```

### From PowerShell Gallery (Future)

```powershell
# Install from PSGallery (when published)
Install-Module -Name HyperionMetrics -Scope CurrentUser

# Import module
Import-Module HyperionMetrics
```

### Install AWS Prerequisites

```powershell
# Install AWS CloudWatch module
Install-Module -Name AWS.Tools.CloudWatch -Scope CurrentUser -Force

# Verify installation
Get-Module -ListAvailable AWS.Tools.CloudWatch
```

### Configure AWS Credentials

```powershell
# Option 1: Environment variables
$env:AWS_ACCESS_KEY_ID = 'your-key'
$env:AWS_SECRET_ACCESS_KEY = 'your-secret'
$env:AWS_DEFAULT_REGION = 'us-east-1'

# Option 2: AWS credential profile
Set-AWSCredential -AccessKey 'your-key' -SecretKey 'your-secret' -StoreAs 'hyperion-profile'

# Option 3: Use IAM instance role (if running on EC2)
# No configuration needed - automatically uses instance role
```

## Quick Start

```powershell
# Import module
Import-Module HyperionMetrics

# Collect and publish system metrics
Get-SystemMetrics | Publish-FleetMetric -Environment 'prod' -Role 'WebServer'

# Publish a single custom metric
Publish-FleetMetric -MetricName 'RequestCount' -Value 1000 -Unit 'Count' -Environment 'prod'

# Publish compliance metrics
Publish-ComplianceMetrics -CompliancePercentage 95.5 -FailedControlsCount 3 -Framework 'CIS'

# Publish application metrics
Publish-ApplicationMetrics -ApplicationName 'WebAPI' -RequestCount 5000 -ErrorCount 25 -LatencyMs 45

# Start scheduled metric collection
Start-MetricCollector -IntervalMinutes 5 -Environment 'prod' -Role 'WebServer'
```

## Cmdlet Reference

### Publish-FleetMetric

Publishes custom metrics to Amazon CloudWatch with automatic batching and dimension management.

**Parameters:**
- `MetricName`: The metric name (1-255 characters)
- `Value`: The numeric metric value
- `Unit`: CloudWatch unit (Seconds, Bytes, Percent, Count, etc.)
- `Dimensions`: Custom dimensions hashtable
- `Namespace`: CloudWatch namespace (default: Hyperion/FleetManager)
- `Environment`: Deployment environment (dev, staging, prod, test)
- `Role`: Server role identifier
- `InstanceId`: EC2 instance ID (auto-detected if not provided)
- `Metrics`: Array of metric objects for batch publishing
- `StorageResolution`: 1 for high-resolution, 60 for standard
- `Region`: AWS region
- `ProfileName`: AWS credential profile
- `PassThru`: Return published metric data

**Examples:**

```powershell
# Single metric
Publish-FleetMetric -MetricName 'ActiveUsers' -Value 150 -Unit 'Count' -Environment 'prod'

# Metric with custom dimensions
Publish-FleetMetric -MetricName 'APILatency' -Value 45.3 -Unit 'Milliseconds' `
    -Dimensions @{ Endpoint = '/api/users'; Method = 'GET' }

# Batch metrics
$metrics = @(
    @{ MetricName = 'CPU'; Value = 75; Unit = 'Percent' }
    @{ MetricName = 'Memory'; Value = 8192; Unit = 'Megabytes' }
    @{ MetricName = 'Connections'; Value = 250; Unit = 'Count' }
)
Publish-FleetMetric -Metrics $metrics -Environment 'prod'

# High-resolution metric (1-second granularity)
Publish-FleetMetric -MetricName 'Latency' -Value 12.5 -Unit 'Milliseconds' -StorageResolution 1

# Pipeline from Get-SystemMetrics
Get-SystemMetrics | Publish-FleetMetric -Environment 'prod' -Role 'AppServer'
```

### Get-SystemMetrics

Collects system performance metrics from the local machine (CPU, memory, disk, network).

**Parameters:**
- `IncludeCPU`: Include CPU utilization metrics (default: true)
- `IncludeMemory`: Include memory usage metrics (default: true)
- `IncludeDisk`: Include disk space metrics (default: true)
- `IncludeNetwork`: Include network throughput metrics (default: true)
- `DiskDrives`: Specific drives to monitor (e.g., 'C:', 'D:' or '/', '/home')
- `NetworkInterfaces`: Specific interfaces to monitor
- `SampleInterval`: CPU sampling interval in seconds (1-60)

**Examples:**

```powershell
# Collect all metrics
$metrics = Get-SystemMetrics

# CPU and memory only
$metrics = Get-SystemMetrics -IncludeCPU -IncludeMemory -IncludeDisk:$false -IncludeNetwork:$false

# Specific disk drives
$metrics = Get-SystemMetrics -DiskDrives @('C:', 'D:')

# Linux mount points
$metrics = Get-SystemMetrics -DiskDrives @('/', '/home', '/var')

# View collected metrics
Get-SystemMetrics | Format-Table MetricName, Value, Unit
```

**Output Metrics:**

| Metric Name | Unit | Description |
|-------------|------|-------------|
| CPUUtilization | Percent | Overall CPU usage |
| ProcessorQueueLength | Count | CPU queue length |
| MemoryUsed | Megabytes | Used physical memory |
| MemoryAvailable | Megabytes | Free physical memory |
| MemoryUtilization | Percent | Memory usage percentage |
| DiskSpaceUsed | Gigabytes | Used disk space |
| DiskSpaceAvailable | Gigabytes | Free disk space |
| DiskSpaceUtilization | Percent | Disk usage percentage |
| NetworkBytesIn | Kilobytes/Second | Network receive rate |
| NetworkBytesOut | Kilobytes/Second | Network transmit rate |

### Publish-ComplianceMetrics

Publishes compliance scan metrics to CloudWatch for security and audit tracking.

**Parameters:**
- `CompliancePercentage`: Overall compliance percentage (0-100)
- `FailedControlsCount`: Number of failed controls
- `TotalControlsCount`: Total controls evaluated
- `PassedControlsCount`: Number of passed controls
- `RemediationSuccessRate`: Remediation success percentage
- `ComplianceReport`: Compliance report object from HyperionCompliance module
- `Framework`: Compliance framework (CIS, NIST, SOC2, Custom)
- `Environment`: Deployment environment
- `LastScanTimestamp`: Timestamp of last scan

**Examples:**

```powershell
# Manual metric entry
Publish-ComplianceMetrics -CompliancePercentage 95.5 `
    -FailedControlsCount 3 `
    -TotalControlsCount 67 `
    -Framework 'CIS' `
    -Environment 'prod'

# From compliance report
$report = Test-Compliance -Framework 'CIS'
Publish-ComplianceMetrics -ComplianceReport $report

# With remediation metrics
Publish-ComplianceMetrics -CompliancePercentage 98 `
    -FailedControlsCount 2 `
    -TotalControlsCount 100 `
    -RemediationSuccessRate 85 `
    -Framework 'NIST'
```

### Publish-ApplicationMetrics

Publishes application health and performance metrics for monitoring application workloads.

**Parameters:**
- `ApplicationName`: Application identifier (required)
- `RequestCount`: Requests processed
- `ErrorCount`: Errors encountered
- `ErrorRate`: Error percentage
- `LatencyMs`: Average latency in milliseconds
- `LatencyP50Ms`, `LatencyP95Ms`, `LatencyP99Ms`: Percentile latencies
- `QueueDepth`: Current queue depth
- `QueueOldestItemAge`: Age of oldest queue item (seconds)
- `ActiveJobs`, `CompletedJobs`, `FailedJobs`: Job counts
- `HealthScore`: Application health score (0-100)
- `ActiveConnections`: Current connection count
- `ThreadPoolActive`, `ThreadPoolAvailable`: Thread pool metrics
- `CustomMetrics`: Hashtable of custom application metrics

**Examples:**

```powershell
# Web API metrics
Publish-ApplicationMetrics -ApplicationName 'WebAPI' `
    -RequestCount 10000 `
    -ErrorCount 50 `
    -LatencyMs 45 `
    -LatencyP95Ms 120 `
    -LatencyP99Ms 350 `
    -Environment 'prod'

# Job processor metrics
Publish-ApplicationMetrics -ApplicationName 'JobProcessor' `
    -QueueDepth 150 `
    -ActiveJobs 10 `
    -CompletedJobs 500 `
    -FailedJobs 2 `
    -QueueOldestItemAge 3600

# Custom application metrics
Publish-ApplicationMetrics -ApplicationName 'DataService' `
    -HealthScore 98 `
    -CustomMetrics @{
        CacheHitRate = 0.95
        DatabaseConnections = 10
        PendingTransactions = 25
    }
```

### Start-MetricCollector

Starts scheduled metric collection using Windows Task Scheduler or Linux systemd/cron.

**Parameters:**
- `IntervalMinutes`: Collection interval (1-1440 minutes, default: 5)
- `CollectionProfile`: What to collect (System, Compliance, Application, Full)
- `ApplicationName`: Application name for Application profile
- `Environment`: Deployment environment
- `Role`: Server role
- `TaskName`: Scheduled task name
- `CustomMetricScript`: Path to custom metric collection script
- `Force`: Overwrite existing scheduled task

**Examples:**

```powershell
# Start full metric collection every 5 minutes
Start-MetricCollector -Environment 'prod' -Role 'WebServer'

# System metrics only, every minute
Start-MetricCollector -IntervalMinutes 1 -CollectionProfile 'System' -Environment 'prod'

# With custom metric script
Start-MetricCollector -CustomMetricScript 'C:\Scripts\Get-CustomMetrics.ps1' `
    -Environment 'prod' `
    -IntervalMinutes 5

# Check collector status
Get-MetricCollectorStatus

# Stop collector
Stop-MetricCollector
```

### Stop-MetricCollector

Stops and removes the scheduled metric collector.

```powershell
Stop-MetricCollector
Stop-MetricCollector -TaskName 'CustomCollector'
```

### Get-MetricCollectorStatus

Returns the current status of the metric collector scheduled task.

```powershell
$status = Get-MetricCollectorStatus
$status | Format-List
```

## CloudWatch Namespace Conventions

HyperionMetrics uses a consistent namespace structure for metric organization.

### Default Namespace

```
Hyperion/FleetManager
```

### Dimension Hierarchy

All metrics include standard dimensions for filtering and aggregation:

| Dimension | Description | Example |
|-----------|-------------|---------|
| Environment | Deployment environment | prod, staging, dev |
| Role | Server function | WebServer, Database, AppServer |
| Project | Project identifier | hyperion-fleet-manager |
| InstanceId | EC2 instance ID | i-1234567890abcdef0 |
| Hostname | Server hostname | web-server-01 |
| Region | AWS region | us-east-1 |
| AvailabilityZone | Availability zone | us-east-1a |

### Metric Types

Additional MetricType dimension categorizes metrics:

| MetricType | Description |
|------------|-------------|
| System | OS-level metrics (CPU, memory, disk, network) |
| Compliance | Security and compliance metrics |
| Application | Application-specific metrics |
| Queue | Message queue metrics |
| Jobs | Background job metrics |
| Custom | User-defined custom metrics |

## Custom Metric Best Practices

### 1. Use Meaningful Metric Names

```powershell
# Good: Descriptive, follows naming conventions
Publish-FleetMetric -MetricName 'OrderProcessingLatency' -Value 125 -Unit 'Milliseconds'

# Avoid: Vague or generic names
Publish-FleetMetric -MetricName 'Value1' -Value 125 -Unit 'None'
```

### 2. Choose Appropriate Units

```powershell
# Use CloudWatch standard units for better aggregation
-Unit 'Percent'       # For percentages (0-100)
-Unit 'Count'         # For counts/totals
-Unit 'Milliseconds'  # For latency
-Unit 'Bytes'         # For data sizes
-Unit 'Count/Second'  # For rates
```

### 3. Use Dimensions Wisely

```powershell
# Good: Relevant, low-cardinality dimensions
-Dimensions @{
    Environment = 'prod'
    Service = 'OrderAPI'
    Operation = 'CreateOrder'
}

# Avoid: High-cardinality dimensions (unique per request)
-Dimensions @{
    RequestId = '550e8400-e29b-41d4-a716-446655440000'  # Too many unique values
}
```

### 4. Batch Metrics for Efficiency

```powershell
# Efficient: Batch multiple metrics
$metrics = @(
    @{ MetricName = 'CPU'; Value = 75; Unit = 'Percent' }
    @{ MetricName = 'Memory'; Value = 8192; Unit = 'Megabytes' }
)
Publish-FleetMetric -Metrics $metrics

# Less efficient: Individual calls
Publish-FleetMetric -MetricName 'CPU' -Value 75 -Unit 'Percent'
Publish-FleetMetric -MetricName 'Memory' -Value 8192 -Unit 'Megabytes'
```

### 5. Use High-Resolution Metrics Sparingly

```powershell
# High-resolution (1-second) - use for critical metrics only
Publish-FleetMetric -MetricName 'Latency' -Value 45 -StorageResolution 1

# Standard resolution (60-second) - default, cost-effective
Publish-FleetMetric -MetricName 'RequestCount' -Value 1000
```

## Scheduled Task Setup

### Windows Task Scheduler

The module creates a Windows Scheduled Task that runs under SYSTEM:

```powershell
# Create collector task
Start-MetricCollector -Environment 'prod' -Role 'WebServer' -IntervalMinutes 5

# View task in Task Scheduler
Get-ScheduledTask -TaskName 'HyperionMetricCollector'

# Task runs every 5 minutes:
# C:\Program Files\PowerShell\7\pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "...\Invoke-MetricCollection.ps1"
```

### Linux Systemd Timer

On Linux systems with systemd, creates a timer unit:

```bash
# Service file: /etc/systemd/system/hyperionmetriccollector.service
# Timer file: /etc/systemd/system/hyperionmetriccollector.timer

# View timer status
systemctl status hyperionmetriccollector.timer
systemctl list-timers | grep hyperion

# View logs
journalctl -u hyperionmetriccollector
```

### Linux Cron (Fallback)

On systems without systemd, creates a cron job:

```bash
# Cron file: /etc/cron.d/hyperionmetriccollector

# View cron job
cat /etc/cron.d/hyperionmetriccollector

# View logs
tail -f /var/log/hyperion-metrics.log
```

## Troubleshooting

### AWS Credentials Not Found

```powershell
# Verify credentials
Get-AWSCredential -ListProfileDetail

# Test connectivity
Get-STSCallerIdentity

# Check IAM permissions
aws iam simulate-principal-policy --policy-source-arn arn:aws:iam::123456789012:role/my-role \
    --action-names cloudwatch:PutMetricData
```

### Module Import Errors

```powershell
# Verify AWS module
Get-Module -ListAvailable AWS.Tools.CloudWatch

# Import with verbose output
Import-Module HyperionMetrics -Verbose -Force

# Check PowerShell version
$PSVersionTable.PSVersion
```

### Metrics Not Appearing in CloudWatch

```powershell
# Verify namespace
# Default: Hyperion/FleetManager

# Check metric publication
$result = Publish-FleetMetric -MetricName 'Test' -Value 1 -PassThru -Verbose
$result

# Verify dimensions match your CloudWatch query
# Metrics with different dimensions appear as different metric streams
```

### Scheduled Task Not Running

```powershell
# Windows: Check task status
Get-MetricCollectorStatus

# View task history
Get-ScheduledTask -TaskName 'HyperionMetricCollector' | Get-ScheduledTaskInfo

# Check Windows Event Log
Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 50 |
    Where-Object { $_.Message -match 'Hyperion' }
```

```bash
# Linux: Check systemd timer
systemctl status hyperionmetriccollector.timer
journalctl -u hyperionmetriccollector -n 50

# Check cron logs
grep hyperion /var/log/syslog
```

### EC2 Metadata Not Available

```powershell
# Test metadata service
Invoke-RestMethod -Uri 'http://169.254.169.254/latest/meta-data/instance-id' -TimeoutSec 2

# If IMDSv2 required:
$token = Invoke-RestMethod -Uri 'http://169.254.169.254/latest/api/token' -Method PUT `
    -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = 21600}
Invoke-RestMethod -Uri 'http://169.254.169.254/latest/meta-data/instance-id' `
    -Headers @{'X-aws-ec2-metadata-token' = $token}

# Provide InstanceId manually if not on EC2
Publish-FleetMetric -MetricName 'Test' -Value 1 -InstanceId 'on-prem-server-01'
```

### High API Error Rate

```powershell
# Reduce batch size if hitting rate limits
$script:MetricBatchSize = 10

# Add delays between batches
# Consider using high-resolution metrics sparingly

# Check CloudWatch quotas
# Default: 150 PutMetricData calls/second/account
```

## Testing

Run Pester tests to validate module functionality:

```powershell
# Install Pester if needed
Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser

# Run all tests
Invoke-Pester -Path /home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionMetrics/Tests

# Run with verbose output
Invoke-Pester -Path ./Tests/HyperionMetrics.Tests.ps1 -Output Detailed

# Generate code coverage report
$config = New-PesterConfiguration
$config.Run.Path = './Tests'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @('./Public/*.ps1', './Private/*.ps1')
$config.CodeCoverage.OutputPath = './coverage.xml'
Invoke-Pester -Configuration $config
```

## Module Structure

```
HyperionMetrics/
├── HyperionMetrics.psd1          # Module manifest
├── HyperionMetrics.psm1          # Root module loader
├── Public/                       # Exported functions
│   ├── Get-SystemMetrics.ps1
│   ├── Publish-FleetMetric.ps1
│   ├── Publish-ComplianceMetrics.ps1
│   ├── Publish-ApplicationMetrics.ps1
│   └── Start-MetricCollector.ps1
├── Private/                      # Internal helpers
│   ├── Get-StandardDimensions.ps1
│   └── Convert-ToCloudWatchFormat.ps1
├── Tests/                        # Pester tests
│   └── HyperionMetrics.Tests.ps1
└── README.md                     # This file
```

## Related Modules

- **HyperionFleet**: EC2 fleet management and automation
- **HyperionCompliance**: Security compliance scanning and remediation

## Version History

### 1.0.0 (2026-02-05)
- Initial release
- Publish-FleetMetric: CloudWatch metric publishing with batching
- Get-SystemMetrics: Cross-platform system metrics collection
- Publish-ComplianceMetrics: Compliance scan metrics
- Publish-ApplicationMetrics: Application health metrics
- Start-MetricCollector: Scheduled metric collection
- Stop-MetricCollector: Remove scheduled collection
- Get-MetricCollectorStatus: Check collector status
- EC2 metadata caching for performance
- Full Pester test suite

## License

Copyright (c) 2026 Hyperion Fleet Manager. MIT License.

## Support

For issues, questions, or contributions, contact the DevOps team.

---

**Module**: HyperionMetrics
**Version**: 1.0.0
**PowerShell**: 7.0+
**Platform**: Cross-platform (Windows, Linux)
