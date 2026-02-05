#Requires -Version 7.4
#Requires -Modules HyperionFleet

<#
.SYNOPSIS
    Basic usage examples for HyperionFleet module.

.DESCRIPTION
    Demonstrates common fleet management workflows using the HyperionFleet module
    including health checks, inventory management, command execution, and patching.

.NOTES
    Requires AWS credentials to be configured.
    Ensure target instances have SSM agent installed and running.
#>

# Import module
Import-Module HyperionFleet -Force

Write-Host "=== HyperionFleet Module Examples ===" -ForegroundColor Cyan

# Example 1: Basic Health Check
Write-Host "`n--- Example 1: Basic Health Check ---" -ForegroundColor Yellow
try {
    $health = Get-FleetHealth -Verbose
    $health | Format-Table InstanceId, InstanceName, State, Status, SSMAgentStatus -AutoSize

    # Count by status
    $healthSummary = $health | Group-Object -Property Status
    Write-Host "`nHealth Summary:"
    $healthSummary | Format-Table Name, Count -AutoSize
}
catch {
    Write-Warning "Health check failed: $_"
}

# Example 2: Advanced Health Check with Metrics
Write-Host "`n--- Example 2: Health Check with Metrics ---" -ForegroundColor Yellow
try {
    $detailedHealth = Get-FleetHealth -Tag @{Environment='Production'} -IncludeMetrics -IncludePatches
    $detailedHealth | Format-Table InstanceId, InstanceName, Status, @{
        Label = 'CPU%'
        Expression = { if ($_.Metrics) { [math]::Round($_.Metrics.CPUUtilization, 2) } }
    }, @{
        Label = 'Missing Patches'
        Expression = { if ($_.PatchCompliance) { $_.PatchCompliance.MissingCount } }
    } -AutoSize
}
catch {
    Write-Warning "Detailed health check failed: $_"
}

# Example 3: Fleet Inventory
Write-Host "`n--- Example 3: Fleet Inventory ---" -ForegroundColor Yellow
try {
    $inventory = Get-FleetInventory -Region 'us-east-1'
    $inventory | Format-Table InstanceId, Name, InstanceType, State, Environment, Application -AutoSize

    Write-Host "`nTotal Instances: $($inventory.Count)"

    # Group by environment
    if ($inventory) {
        $byEnv = $inventory | Group-Object -Property Environment
        Write-Host "`nInstances by Environment:"
        $byEnv | Format-Table Name, Count -AutoSize
    }
}
catch {
    Write-Warning "Inventory retrieval failed: $_"
}

# Example 4: Export Inventory to CSV
Write-Host "`n--- Example 4: Export Inventory ---" -ForegroundColor Yellow
try {
    $exportPath = "/tmp/fleet-inventory-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    Get-FleetInventory -ExportPath $exportPath
    Write-Host "Inventory exported to: $exportPath" -ForegroundColor Green

    if (Test-Path $exportPath) {
        $fileInfo = Get-Item $exportPath
        Write-Host "File size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB"
    }
}
catch {
    Write-Warning "Inventory export failed: $_"
}

# Example 5: Execute Simple Command
Write-Host "`n--- Example 5: Execute Command ---" -ForegroundColor Yellow
try {
    # Get first running instance for demo
    $targetInstance = (Get-FleetInventory -State 'running' | Select-Object -First 1).InstanceId

    if ($targetInstance) {
        Write-Host "Executing command on: $targetInstance"

        # Use WhatIf to preview
        Invoke-FleetCommand -InstanceId $targetInstance -Command 'uptime', 'df -h' -WhatIf

        # Uncomment to actually execute
        # $result = Invoke-FleetCommand -InstanceId $targetInstance -Command 'uptime' -Wait
        # $result | Format-List

        Write-Host "Command preview completed (use -Confirm:`$false to execute)" -ForegroundColor Green
    }
    else {
        Write-Warning "No running instances found for command execution"
    }
}
catch {
    Write-Warning "Command execution failed: $_"
}

# Example 6: Patch Scanning
Write-Host "`n--- Example 6: Patch Scanning ---" -ForegroundColor Yellow
try {
    # Get instances to scan
    $patchTargets = Get-FleetInventory -Tag @{PatchGroup='Group1'} -State 'running'

    if ($patchTargets) {
        Write-Host "Found $($patchTargets.Count) instances in patch group"

        # Scan for missing patches (WhatIf mode)
        Start-FleetPatch -Tag @{PatchGroup='Group1'} -Operation 'Scan' -WhatIf

        Write-Host "Patch scan preview completed" -ForegroundColor Green

        # Uncomment to actually scan
        # $scanResult = Start-FleetPatch -Tag @{PatchGroup='Group1'} -Operation 'Scan' -Wait
        # $scanResult | Format-List
    }
    else {
        Write-Warning "No instances found with PatchGroup=Group1 tag"
    }
}
catch {
    Write-Warning "Patch scanning failed: $_"
}

# Example 7: Filter Unhealthy Instances
Write-Host "`n--- Example 7: Find Unhealthy Instances ---" -ForegroundColor Yellow
try {
    $allHealth = Get-FleetHealth
    $unhealthy = $allHealth | Where-Object { $_.Status -notin @('Healthy', 'Running') }

    if ($unhealthy) {
        Write-Host "Found $($unhealthy.Count) unhealthy instances:" -ForegroundColor Red
        $unhealthy | Format-Table InstanceId, InstanceName, State, Status, SSMAgentStatus -AutoSize
    }
    else {
        Write-Host "All instances are healthy!" -ForegroundColor Green
    }
}
catch {
    Write-Warning "Unhealthy instance check failed: $_"
}

# Example 8: Multi-Region Inventory
Write-Host "`n--- Example 8: Multi-Region Inventory ---" -ForegroundColor Yellow
try {
    $regions = @('us-east-1', 'us-west-2', 'eu-west-1')
    Write-Host "Querying regions: $($regions -join ', ')"

    $multiRegionInventory = Get-FleetInventory -Region $regions

    if ($multiRegionInventory) {
        Write-Host "`nTotal instances across all regions: $($multiRegionInventory.Count)"

        $byRegion = $multiRegionInventory | Group-Object -Property Region
        Write-Host "`nInstances by Region:"
        $byRegion | Format-Table Name, Count -AutoSize
    }
}
catch {
    Write-Warning "Multi-region inventory failed: $_"
}

# Example 9: Pipeline Operations
Write-Host "`n--- Example 9: Pipeline Operations ---" -ForegroundColor Yellow
try {
    # Chain operations using pipeline
    Get-FleetInventory -Tag @{Environment='Development'} |
        Where-Object { $_.State -eq 'running' } |
        Select-Object -First 3 |
        ForEach-Object {
            Write-Host "Processing instance: $($_.InstanceId) ($($_.Name))"
            # Could pipe to Invoke-FleetCommand here
        }
}
catch {
    Write-Warning "Pipeline operations failed: $_"
}

# Example 10: Error Handling Best Practice
Write-Host "`n--- Example 10: Error Handling ---" -ForegroundColor Yellow
try {
    $ErrorActionPreference = 'Stop'

    # Validate prerequisites
    if (-not (Get-Module -Name AWS.Tools.EC2 -ListAvailable)) {
        throw "AWS.Tools.EC2 module is not installed"
    }

    # Execute with proper error handling
    $health = Get-FleetHealth -ErrorAction Stop
    Write-Host "Successfully retrieved health for $($health.Count) instances" -ForegroundColor Green

    # Process results with validation
    foreach ($instance in $health) {
        if ($instance.Status -eq 'Unhealthy') {
            Write-Warning "Instance $($instance.InstanceId) requires attention"
            # Trigger alerts or remediation
        }
    }
}
catch {
    Write-Error "Operation failed: $_"
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    $ErrorActionPreference = 'Continue'
}

Write-Host "`n=== Examples Completed ===" -ForegroundColor Cyan
Write-Host "Note: Many examples use -WhatIf to preview operations safely." -ForegroundColor Yellow
Write-Host "Remove -WhatIf and add -Confirm:`$false to execute actual operations." -ForegroundColor Yellow
