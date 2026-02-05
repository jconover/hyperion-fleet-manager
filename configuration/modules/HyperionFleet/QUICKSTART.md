# HyperionFleet Quick Start Guide

Fast-track guide to get started with the HyperionFleet PowerShell module.

## Prerequisites

```powershell
# 1. Check PowerShell version (requires 7.4+)
$PSVersionTable.PSVersion

# 2. Install AWS modules
Install-Module AWS.Tools.EC2 -Scope CurrentUser -Force
Install-Module AWS.Tools.SimpleSystemsManagement -Scope CurrentUser -Force

# 3. Configure AWS credentials
Set-AWSCredential -AccessKey 'YOUR_KEY' -SecretKey 'YOUR_SECRET' -StoreAs 'default'
Set-DefaultAWSRegion -Region 'us-east-1'
```

## Installation

```powershell
# Import module
Import-Module /home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionFleet

# Verify
Get-Command -Module HyperionFleet
```

## Common Tasks

### 1. Check Fleet Health

```powershell
# All instances
Get-FleetHealth

# With metrics and patches
Get-FleetHealth -IncludeMetrics -IncludePatches

# Specific instances
Get-FleetHealth -InstanceId 'i-1234567890abcdef0'

# Filter by tags
Get-FleetHealth -Tag @{Environment='Production'}
```

### 2. Get Fleet Inventory

```powershell
# All instances
Get-FleetInventory

# Filter by tags
Get-FleetInventory -Tag @{Environment='Production'; Role='WebServer'}

# Multiple regions
Get-FleetInventory -Region 'us-east-1', 'us-west-2'

# Export to CSV
Get-FleetInventory -ExportPath '/tmp/inventory.csv'
```

### 3. Execute Commands

```powershell
# Single command
Invoke-FleetCommand -InstanceId 'i-1234567890' -Command 'uptime'

# Multiple commands with wait
Invoke-FleetCommand -Tag @{Role='WebServer'} `
    -Command 'df -h', 'free -m' `
    -Wait

# Preview with WhatIf
Invoke-FleetCommand -Tag @{Environment='Production'} `
    -Command 'sudo systemctl restart app' `
    -WhatIf
```

### 4. Patch Management

```powershell
# Scan for patches
Start-FleetPatch -Tag @{Environment='Production'} `
    -Operation 'Scan' `
    -Wait

# Install patches
Start-FleetPatch -Tag @{PatchGroup='Group1'} `
    -Operation 'Install' `
    -RebootOption 'RebootIfNeeded' `
    -Wait

# Install without reboot
Start-FleetPatch -InstanceId 'i-1234567890' `
    -Operation 'Install' `
    -RebootOption 'NoReboot' `
    -Confirm:$false
```

## Useful One-Liners

```powershell
# Find unhealthy instances
Get-FleetHealth | Where-Object {$_.Status -ne 'Healthy'}

# Count instances by environment
Get-FleetInventory | Group-Object Environment | Format-Table Name, Count

# Get instances with missing patches
Get-FleetHealth -IncludePatches | Where-Object {$_.PatchCompliance.MissingCount -gt 0}

# List stopped instances
Get-FleetInventory -State 'stopped' | Select-Object InstanceId, Name, Environment

# Execute command on all production web servers
Get-FleetInventory -Tag @{Environment='Production'; Role='WebServer'} |
    ForEach-Object { Invoke-FleetCommand -InstanceId $_.InstanceId -Command 'uptime' }
```

## Error Handling

```powershell
# With try-catch
try {
    $health = Get-FleetHealth -ErrorAction Stop
    # Process results
}
catch {
    Write-Error "Health check failed: $_"
}

# With verbose output
Get-FleetHealth -Verbose

# Silent errors
Get-FleetHealth -ErrorAction SilentlyContinue
```

## Configuration

```powershell
# View module config
$ModuleConfig

# Change defaults (current session only)
$ModuleConfig.DefaultRegion = 'us-west-2'
$ModuleConfig.LogLevel = 'Verbose'
```

## Testing

```powershell
# Run all tests
Invoke-Pester /home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionFleet/Tests

# Run specific test
Invoke-Pester /home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionFleet/Tests/HyperionFleet.Tests.ps1 -Output Detailed
```

## Examples

Run the included examples script:

```powershell
# View examples
Get-Content /home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionFleet/Examples/Basic-Usage.ps1

# Run examples (requires AWS credentials)
& /home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionFleet/Examples/Basic-Usage.ps1
```

## Logs

```powershell
# View logs
Get-Content $env:TEMP/HyperionFleet.log | ConvertFrom-Json | Format-Table

# Filter errors
Get-Content $env:TEMP/HyperionFleet.log | ConvertFrom-Json |
    Where-Object {$_.Level -eq 'Error'}

# Tail logs (real-time)
Get-Content $env:TEMP/HyperionFleet.log -Wait -Tail 10
```

## Troubleshooting

### No instances returned

```powershell
# Check credentials
Get-STSCallerIdentity

# Check region
$env:AWS_DEFAULT_REGION

# List all instances (bypass filters)
Get-EC2Instance -Region us-east-1
```

### SSM agent offline

```powershell
# Check SSM status
Get-SSMInstanceInformation | Where-Object {$_.PingStatus -ne 'Online'}
```

### Module import errors

```powershell
# Check prerequisites
Get-Module -ListAvailable AWS.Tools.*

# Reimport with verbose
Import-Module HyperionFleet -Force -Verbose
```

## Next Steps

1. Read full documentation: `/home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionFleet/README.md`
2. Review function help: `Get-Help Get-FleetHealth -Full`
3. Run example workflows: `/home/justin/Projects/hyperion-fleet-manager/configuration/modules/HyperionFleet/Examples/Basic-Usage.ps1`
4. Write custom scripts using the module

## Support

For detailed documentation, see README.md in the module directory.
