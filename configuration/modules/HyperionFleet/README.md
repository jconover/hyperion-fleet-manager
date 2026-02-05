# HyperionFleet PowerShell Module

AWS EC2 fleet management and automation module for Hyperion infrastructure. Provides comprehensive cmdlets for health monitoring, inventory management, SSM command execution, and automated patching workflows.

## Overview

HyperionFleet simplifies AWS EC2 fleet operations by providing high-level PowerShell cmdlets that wrap AWS Systems Manager and EC2 APIs with intelligent defaults, error handling, and logging.

## Features

- **Health Monitoring**: Query instance health with CloudWatch metrics and SSM agent status
- **Inventory Management**: Comprehensive instance inventory with tag-based filtering and export
- **Command Execution**: Execute SSM Run Commands across fleets with progress tracking
- **Patch Management**: Automated patching workflows with validation and compliance tracking
- **Structured Logging**: JSON-based logging with automatic rotation
- **Credential Management**: Flexible AWS credential and role assumption support

## Requirements

- **PowerShell**: 7.4 or higher
- **AWS Modules**:
  - `AWS.Tools.EC2` (4.1.0+)
  - `AWS.Tools.SimpleSystemsManagement` (4.1.0+)
- **AWS Permissions**: IAM permissions for EC2, SSM, CloudWatch, and STS operations
- **SSM Agent**: Target instances must have AWS Systems Manager agent installed

## Installation

### From Local Path

```powershell
# Import module
Import-Module /home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionFleet

# Verify installation
Get-Module HyperionFleet
Get-Command -Module HyperionFleet
```

### Install AWS Prerequisites

```powershell
Install-Module -Name AWS.Tools.EC2 -Scope CurrentUser
Install-Module -Name AWS.Tools.SimpleSystemsManagement -Scope CurrentUser
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
Import-Module HyperionFleet

# Get health status of all fleet instances
Get-FleetHealth

# Get health with CloudWatch metrics
Get-FleetHealth -IncludeMetrics -IncludePatches

# Check specific instances
Get-FleetHealth -InstanceId 'i-1234567890abcdef0', 'i-0987654321fedcba0'

# Get complete inventory
Get-FleetInventory

# Filter inventory by tags
Get-FleetInventory -Tag @{Environment='Production'; Role='WebServer'}

# Execute command on instances
Invoke-FleetCommand -InstanceId 'i-1234567890abcdef0' -Command 'uptime'

# Scan for missing patches
Start-FleetPatch -Tag @{Environment='Production'} -Operation 'Scan' -Wait

# Install patches
Start-FleetPatch -Tag @{PatchGroup='Group1'} -Operation 'Install' -Wait
```

## Cmdlet Reference

### Get-FleetHealth

Retrieves health metrics for EC2 fleet instances including SSM agent status, CloudWatch metrics, and patch compliance.

**Parameters:**
- `InstanceId`: One or more instance IDs
- `Tag`: Filter by tag key-value pairs
- `Region`: AWS region (default: module config)
- `ProfileName`: AWS credential profile
- `IncludeMetrics`: Include CloudWatch metrics
- `MetricPeriod`: Metric time period in minutes (5-1440)
- `IncludePatches`: Include patch compliance status

**Examples:**

```powershell
# Basic health check
Get-FleetHealth

# Production instances with metrics
Get-FleetHealth -Tag @{Environment='Production'} -IncludeMetrics

# Specific instances with patch status
Get-FleetHealth -InstanceId 'i-123456789' -IncludePatches -Wait

# Filter unhealthy instances
Get-FleetHealth | Where-Object {$_.Status -ne 'Healthy'}
```

**Output Properties:**
- `InstanceId`, `InstanceName`, `InstanceType`, `State`
- `Status` (Healthy, Degraded, Unhealthy, Stopped)
- `SSMAgentStatus`, `SSMPingStatus`, `SSMLastPingTime`
- `StatusChecks` (SystemStatus, InstanceStatus)
- `Metrics` (CPUUtilization, NetworkIn/Out)
- `PatchCompliance` (InstalledCount, MissingCount, FailedCount)

### Get-FleetInventory

Lists all EC2 instances with comprehensive tag and configuration information.

**Parameters:**
- `Region`: AWS region(s) to query (accepts array)
- `ProfileName`: AWS credential profile
- `Tag`: Filter by tag key-value pairs
- `State`: Filter by instance state
- `InstanceType`: Filter by instance type pattern
- `GroupBy`: Group results by tag key
- `IncludeTerminated`: Include terminated instances
- `ExportPath`: Export inventory to CSV file

**Examples:**

```powershell
# Complete inventory
Get-FleetInventory

# Multi-region inventory
Get-FleetInventory -Region 'us-east-1', 'us-west-2'

# Filter and group
Get-FleetInventory -Tag @{Environment='Production'} -GroupBy 'Application'

# Export to CSV
Get-FleetInventory -ExportPath '/tmp/fleet-inventory.csv'

# Running instances only
Get-FleetInventory -State 'running' -InstanceType 't3.*'
```

**Output Properties:**
- Instance details (ID, type, state, platform)
- Network configuration (VPC, subnet, IPs)
- Security groups and IAM profile
- Tags (Environment, Application, Owner, CostCenter)
- Launch time and monitoring status

### Invoke-FleetCommand

Executes SSM Run Command across fleet instances with support for command tracking and output retrieval.

**Parameters:**
- `InstanceId`: Target instance IDs
- `Tag`: Filter targets by tags
- `DocumentName`: SSM document name
- `Command`: Command(s) to execute
- `Parameter`: SSM document parameters
- `Comment`: Command description
- `TimeoutSeconds`: Command timeout (1-28800)
- `MaxConcurrency`: Max concurrent executions
- `MaxErrors`: Max errors before stopping
- `Wait`: Wait for completion and retrieve output
- `WhatIf`: Preview without executing
- `Confirm`: Prompt for confirmation

**Examples:**

```powershell
# Simple command execution
Invoke-FleetCommand -InstanceId 'i-123456789' -Command 'uptime'

# Multiple commands with wait
Invoke-FleetCommand -Tag @{Role='WebServer'} -Command 'df -h', 'free -m' -Wait

# Custom SSM document
Invoke-FleetCommand -InstanceId 'i-123456789' `
    -DocumentName 'AWS-ConfigureAWSPackage' `
    -Parameter @{action='Install'; name='AmazonCloudWatchAgent'}

# Preview with WhatIf
Invoke-FleetCommand -Tag @{Environment='Production'} -Command 'sudo reboot' -WhatIf
```

**Output Properties:**
- `CommandId`: SSM command identifier
- `Status` (Pending, InProgress, Success, Failed)
- `TargetCount`, `CompletedCount`, `ErrorCount`
- `Outputs`: Per-instance stdout/stderr (when `-Wait` used)

### Start-FleetPatch

Triggers automated patching workflow with validation and compliance tracking.

**Parameters:**
- `InstanceId`: Target instance IDs
- `Tag`: Filter targets by tags
- `Operation`: Scan or Install
- `RebootOption`: RebootIfNeeded or NoReboot
- `PatchBaseline`: Custom patch baseline ID
- `MaintenanceWindowId`: Execute in maintenance window
- `MaxConcurrency`: Max concurrent patches
- `MaxErrors`: Max errors before stopping
- `Wait`: Wait for completion
- `SkipPreCheck`: Skip pre-patch validation
- `WhatIf`: Preview without executing
- `Confirm`: Prompt for confirmation

**Examples:**

```powershell
# Scan for missing patches
Start-FleetPatch -Tag @{Environment='Production'} -Operation 'Scan'

# Install patches with reboot
Start-FleetPatch -Tag @{PatchGroup='Group1'} -Operation 'Install' -Wait

# Install without reboot
Start-FleetPatch -InstanceId 'i-123456789' `
    -Operation 'Install' `
    -RebootOption 'NoReboot' `
    -Confirm:$false

# Custom patch baseline
Start-FleetPatch -Tag @{Environment='Dev'} `
    -Operation 'Install' `
    -PatchBaseline 'pb-0123456789abcdef0'
```

**Output Properties:**
- `CommandId`: SSM command identifier
- `Operation`, `Status`, `TargetCount`
- `ComplianceSummary` (when `-Wait` used)
  - InstalledPatches, FailedPatches
  - SuccessfulInstances, FailedInstances

## Module Configuration

The module exposes a configuration hashtable for advanced customization:

```powershell
# View current configuration
$ModuleConfig

# Modify settings (affects current session only)
$ModuleConfig.DefaultRegion = 'us-west-2'
$ModuleConfig.LogLevel = 'Verbose'
$ModuleConfig.MaxConcurrentCommands = 100
```

**Configuration Options:**
- `DefaultRegion`: Default AWS region (us-east-1)
- `MaxConcurrentCommands`: Command concurrency limit (50)
- `CommandTimeout`: Default timeout in seconds (3600)
- `LogLevel`: Logging verbosity (Information, Verbose, Warning, Error)
- `RetryAttempts`: API retry count (3)
- `RetryDelaySeconds`: Delay between retries (5)

## Logging

HyperionFleet uses structured JSON logging for all operations:

```powershell
# Default log location
$env:TEMP/HyperionFleet.log  # Linux: /tmp/HyperionFleet.log

# View logs
Get-Content $env:TEMP/HyperionFleet.log | ConvertFrom-Json | Format-Table

# Filter by level
Get-Content $env:TEMP/HyperionFleet.log | ConvertFrom-Json |
    Where-Object {$_.Level -eq 'Error'} | Format-List
```

**Log Entry Format:**
```json
{
  "Timestamp": "2026-02-04T12:34:56.789Z",
  "Level": "Information",
  "Message": "Fleet health check completed",
  "Module": "HyperionFleet",
  "Context": {"InstanceCount": 42},
  "User": "admin",
  "Hostname": "mgmt-server",
  "ProcessId": 12345
}
```

## Error Handling

All cmdlets implement consistent error handling:

```powershell
# Verbose output
Get-FleetHealth -Verbose

# Error action preference
Get-FleetHealth -ErrorAction Stop

# Try-catch for programmatic handling
try {
    $health = Get-FleetHealth -Tag @{Environment='Production'}
    if ($health | Where-Object {$_.Status -eq 'Unhealthy'}) {
        # Handle unhealthy instances
    }
}
catch {
    Write-Error "Health check failed: $_"
}
```

## Best Practices

### 1. Use Tags for Fleet Management

```powershell
# Tag-based operations are more maintainable than instance lists
Get-FleetInventory -Tag @{Environment='Production'; Role='WebServer'}
Invoke-FleetCommand -Tag @{Application='API'} -Command 'systemctl status app'
```

### 2. Always Scan Before Patching

```powershell
# Assess impact before installing patches
$scan = Start-FleetPatch -Tag @{Environment='Production'} -Operation 'Scan' -Wait
$scan | Format-Table InstanceId, MissingPatches

# Then proceed with installation
Start-FleetPatch -Tag @{Environment='Production'} -Operation 'Install' -Wait
```

### 3. Use WhatIf for Validation

```powershell
# Preview operations before execution
Invoke-FleetCommand -Tag @{Environment='Production'} `
    -Command 'sudo systemctl restart app' -WhatIf

Start-FleetPatch -Tag @{Environment='Production'} `
    -Operation 'Install' -WhatIf
```

### 4. Implement Health Checks

```powershell
# Regular health monitoring
$health = Get-FleetHealth -IncludeMetrics -IncludePatches
$alerts = $health | Where-Object {
    $_.Status -ne 'Healthy' -or
    $_.PatchCompliance.MissingCount -gt 10 -or
    $_.Metrics.CPUUtilization -gt 80
}

if ($alerts) {
    # Send notifications or trigger remediation
}
```

### 5. Export Inventory Regularly

```powershell
# Scheduled inventory exports for auditing
$date = Get-Date -Format 'yyyyMMdd'
Get-FleetInventory -Region 'us-east-1', 'us-west-2' `
    -ExportPath "/backups/fleet-inventory-$date.csv"
```

## Testing

Run Pester tests to validate module functionality:

```powershell
# Install Pester if not already installed
Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser

# Run all tests
Invoke-Pester -Path /home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionFleet/Tests

# Run module-level tests only
Invoke-Pester -Path /home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionFleet/Tests/HyperionFleet.Tests.ps1

# Run specific function tests
Invoke-Pester -Path /home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionFleet/Tests/Public/Get-FleetHealth.Tests.ps1

# Generate code coverage report
Invoke-Pester -Path /home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionFleet/Tests -CodeCoverage /home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionFleet/**/*.ps1
```

## Troubleshooting

### AWS Credentials Not Found

```powershell
# Verify credentials
Get-AWSCredential -ListProfileDetail

# Test connectivity
Get-STSCallerIdentity -Region us-east-1
```

### SSM Agent Not Online

```powershell
# Check SSM agent status
Get-SSMInstanceInformation -Region us-east-1 |
    Where-Object {$_.PingStatus -ne 'Online'} |
    Select-Object InstanceId, PingStatus, LastPingDateTime
```

### Module Import Errors

```powershell
# Verify prerequisites
Get-Module -ListAvailable AWS.Tools.*

# Import with verbose output
Import-Module HyperionFleet -Verbose -Force
```

### Timeout Errors

```powershell
# Increase timeout for long-running operations
Invoke-FleetCommand -InstanceId 'i-123456789' `
    -Command 'long-running-task' `
    -TimeoutSeconds 7200

Start-FleetPatch -Tag @{Environment='Production'} `
    -Operation 'Install' `
    -TimeoutSeconds 10800
```

## Contributing

### Module Structure

```
HyperionFleet/
├── HyperionFleet.psd1       # Module manifest
├── HyperionFleet.psm1       # Root module loader
├── Public/                  # Exported functions
│   ├── Get-FleetHealth.ps1
│   ├── Get-FleetInventory.ps1
│   ├── Invoke-FleetCommand.ps1
│   └── Start-FleetPatch.ps1
├── Private/                 # Internal helpers
│   ├── Get-AWSSession.ps1
│   └── Write-FleetLog.ps1
├── Classes/                 # PowerShell classes (optional)
├── Tests/                   # Pester tests
│   ├── HyperionFleet.Tests.ps1
│   └── Public/
│       ├── Get-FleetHealth.Tests.ps1
│       └── Invoke-FleetCommand.Tests.ps1
└── README.md               # This file
```

### Development Guidelines

1. **Use Approved Verbs**: All functions must use approved PowerShell verbs
2. **CmdletBinding**: All public functions use `[CmdletBinding()]`
3. **Comment-Based Help**: Include `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`
4. **Error Handling**: Use try-catch and Write-FleetLog
5. **ShouldProcess**: Implement `-WhatIf`/`-Confirm` for state-changing operations
6. **Parameter Validation**: Use `ValidatePattern`, `ValidateRange`, etc.
7. **Output Types**: Declare `[OutputType()]` attribute
8. **Tests**: Write Pester tests for all new functions

## Version History

### 0.1.0-beta (2026-02-04)
- Initial release
- Core cmdlets: Get-FleetHealth, Get-FleetInventory, Invoke-FleetCommand, Start-FleetPatch
- Structured logging and AWS credential management
- Comprehensive Pester test suite
- PowerShell 7.4+ support

## License

Copyright (c) 2026. All rights reserved.

## Support

For issues, questions, or contributions, contact the DevOps team.

---

**Module**: HyperionFleet
**Version**: 0.1.0-beta
**PowerShell**: 7.4+
**Platform**: Cross-platform (Windows, Linux, macOS)
