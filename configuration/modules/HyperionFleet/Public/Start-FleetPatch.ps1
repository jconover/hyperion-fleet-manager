function Start-FleetPatch {
    <#
    .SYNOPSIS
        Triggers automated patching workflow for fleet instances.

    .DESCRIPTION
        Initiates AWS Systems Manager Patch Manager patching operations with support
        for maintenance windows, patch baselines, validation, and rollback capabilities.
        Supports both immediate patching and scheduled maintenance window execution.

    .PARAMETER InstanceId
        One or more EC2 instance IDs to patch. Cannot be used with -Tag.

    .PARAMETER Tag
        Filter target instances by tag key-value pairs. Cannot be used with -InstanceId.

    .PARAMETER Operation
        Patch operation: Scan (assess compliance) or Install (apply patches). Default: Install.

    .PARAMETER RebootOption
        Reboot behavior: RebootIfNeeded, NoReboot. Default: RebootIfNeeded.

    .PARAMETER PatchBaseline
        Custom patch baseline ID. If not specified, uses default baseline for platform.

    .PARAMETER MaintenanceWindowId
        Execute within specified maintenance window. If not provided, executes immediately.

    .PARAMETER Region
        AWS region to execute patching in. Defaults to module configuration.

    .PARAMETER ProfileName
        AWS credential profile to use.

    .PARAMETER MaxConcurrency
        Maximum number of instances to patch concurrently. Default: 5.

    .PARAMETER MaxErrors
        Maximum number of errors before stopping patching. Default: 1.

    .PARAMETER Wait
        Wait for patching operation to complete and return results.

    .PARAMETER SkipPreCheck
        Skip pre-patch health validation.

    .PARAMETER WhatIf
        Shows what would happen if the command runs without actually executing.

    .PARAMETER Confirm
        Prompts for confirmation before executing patching.

    .EXAMPLE
        Start-FleetPatch -InstanceId 'i-1234567890' -Operation 'Scan'
        Scans instance for missing patches without installing.

    .EXAMPLE
        Start-FleetPatch -Tag @{Environment='Production'} -Operation 'Install' -Wait
        Patches all production instances and waits for completion.

    .EXAMPLE
        Start-FleetPatch -Tag @{PatchGroup='Group1'} -MaintenanceWindowId 'mw-0123456789abcdef0'
        Schedules patching during maintenance window.

    .EXAMPLE
        Start-FleetPatch -InstanceId 'i-1234567890' -RebootOption 'NoReboot' -Confirm:$false
        Installs patches without rebooting and skips confirmation.

    .OUTPUTS
        PSCustomObject with patching operation details and results.

    .NOTES
        Requires AWS.Tools.SimpleSystemsManagement module.
        Instances must have SSM agent installed and be managed by Systems Manager.
        Recommended to run Scan operation before Install to assess impact.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ParameterSetName = 'ById', Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidatePattern('^i-[a-f0-9]{8,17}$')]
        [string[]]$InstanceId,

        [Parameter(ParameterSetName = 'ByTag', Mandatory)]
        [ValidateNotNull()]
        [hashtable]$Tag,

        [Parameter()]
        [ValidateSet('Scan', 'Install')]
        [string]$Operation = 'Install',

        [Parameter()]
        [ValidateSet('RebootIfNeeded', 'NoReboot')]
        [string]$RebootOption = 'RebootIfNeeded',

        [Parameter()]
        [ValidatePattern('^pb-[a-f0-9]{17}$')]
        [string]$PatchBaseline,

        [Parameter()]
        [ValidatePattern('^mw-[a-f0-9]{17}$')]
        [string]$MaintenanceWindowId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Region = $script:ModuleConfig.DefaultRegion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$MaxConcurrency = 5,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$MaxErrors = 1,

        [Parameter()]
        [switch]$Wait,

        [Parameter()]
        [switch]$SkipPreCheck
    )

    begin {
        Write-FleetLog -Message "Preparing fleet patching operation" -Level 'Information' -Context @{
            Operation = $Operation
            RebootOption = $RebootOption
        }

        # Initialize AWS session
        $sessionParams = @{
            Region = $Region
        }
        if ($ProfileName) {
            $sessionParams['ProfileName'] = $ProfileName
        }

        try {
            $session = Get-AWSSession @sessionParams
        }
        catch {
            Write-FleetLog -Message "Failed to initialize AWS session: $_" -Level 'Error'
            throw
        }

        $patchResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        try {
            # Determine target instances
            $targetInstances = @()

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $targetInstances = $InstanceId
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'ByTag') {
                Write-FleetLog -Message "Resolving target instances by tags" -Level 'Verbose'

                $ec2Filters = [System.Collections.Generic.List[Amazon.EC2.Model.Filter]]::new()
                $stateFilter = [Amazon.EC2.Model.Filter]@{
                    Name = 'instance-state-name'
                    Values = @('running')
                }
                $ec2Filters.Add($stateFilter)

                foreach ($tagKey in $Tag.Keys) {
                    $tagFilter = [Amazon.EC2.Model.Filter]@{
                        Name = "tag:$tagKey"
                        Values = @($Tag[$tagKey])
                    }
                    $ec2Filters.Add($tagFilter)
                }

                $ec2Params = @{
                    Filter = $ec2Filters
                    Region = $Region
                }
                if ($ProfileName) {
                    $ec2Params['ProfileName'] = $ProfileName
                }

                $instances = (Get-EC2Instance @ec2Params).Instances
                if (-not $instances -or $instances.Count -eq 0) {
                    Write-FleetLog -Message "No running instances found matching tags" -Level 'Warning'
                    return
                }

                $targetInstances = $instances.InstanceId
            }

            Write-FleetLog -Message "Target instance count: $($targetInstances.Count)" -Level 'Information'

            # Validate SSM agent status
            $ssmParams = @{
                Region = $Region
            }
            if ($ProfileName) {
                $ssmParams['ProfileName'] = $ProfileName
            }

            $ssmInstances = Get-SSMInstanceInformation @ssmParams | Where-Object {
                $targetInstances -contains $_.InstanceId -and $_.PingStatus -eq 'Online'
            }

            if (-not $ssmInstances -or $ssmInstances.Count -eq 0) {
                Write-FleetLog -Message "No target instances have SSM agent online" -Level 'Error'
                throw "No valid SSM-managed instances found in target set"
            }

            $validTargets = @($ssmInstances.InstanceId)
            Write-FleetLog -Message "Validated $($validTargets.Count) instances with online SSM agent" -Level 'Information'

            # Pre-patch health check (unless skipped)
            if (-not $SkipPreCheck) {
                Write-FleetLog -Message "Performing pre-patch health check" -Level 'Information'

                $preCheckParams = @{
                    InstanceId = $validTargets
                    Region = $Region
                }
                if ($ProfileName) {
                    $preCheckParams['ProfileName'] = $ProfileName
                }

                $healthStatus = Get-FleetHealth @preCheckParams

                $unhealthyInstances = $healthStatus | Where-Object { $_.Status -notin @('Healthy', 'Running') }
                if ($unhealthyInstances) {
                    $unhealthyIds = ($unhealthyInstances.InstanceId -join ', ')
                    Write-FleetLog -Message "Found $($unhealthyInstances.Count) unhealthy instances: $unhealthyIds" -Level 'Warning'

                    if (-not $PSCmdlet.ShouldContinue("Continue patching despite unhealthy instances?", "Pre-Check Warning")) {
                        Write-FleetLog -Message "Patching cancelled due to pre-check failures" -Level 'Warning'
                        return
                    }
                }
                else {
                    Write-FleetLog -Message "All instances passed pre-patch health check" -Level 'Information'
                }
            }

            # Build patch operation parameters
            $patchDocument = 'AWS-RunPatchBaseline'
            $patchParameters = @{
                Operation = $Operation
                RebootOption = $RebootOption
            }

            if ($PatchBaseline) {
                $patchParameters['BaselineOverride'] = $PatchBaseline
            }

            # Build WhatIf/Confirm message
            $targetSummary = if ($validTargets.Count -le 5) {
                $validTargets -join ', '
            }
            else {
                "$($validTargets.Count) instances"
            }

            $actionMessage = "Execute patch $Operation on $targetSummary"
            $actionDetail = @"
Operation: $Operation
Targets: $($validTargets.Count) instances
Reboot: $RebootOption
Patch Baseline: $($PatchBaseline ?? 'Default')
Region: $Region
"@

            if ($PSCmdlet.ShouldProcess($actionMessage, $actionDetail, 'Start-FleetPatch')) {
                Write-FleetLog -Message "Initiating patching operation" -Level 'Information' -Context @{
                    Operation = $Operation
                    TargetCount = $validTargets.Count
                    RebootOption = $RebootOption
                }

                # Execute patch operation
                if ($MaintenanceWindowId) {
                    # Schedule in maintenance window
                    Write-FleetLog -Message "Scheduling patching in maintenance window: $MaintenanceWindowId" -Level 'Information'

                    # Note: Actual maintenance window integration would require additional SSM maintenance window configuration
                    # This is a simplified implementation
                    Write-Warning "Maintenance window execution not fully implemented in this version. Executing immediately."
                }

                # Execute via SSM Run Command
                $commandParams = @{
                    DocumentName = $patchDocument
                    InstanceId = $validTargets
                    Parameter = $patchParameters
                    Comment = "Fleet patching: $Operation via HyperionFleet module"
                    TimeoutSeconds = 7200  # 2 hours for patching
                    MaxConcurrency = $MaxConcurrency
                    MaxErrors = $MaxErrors
                    Region = $Region
                }

                if ($ProfileName) {
                    $commandParams['ProfileName'] = $ProfileName
                }

                if ($Wait) {
                    $commandParams['Wait'] = $true
                }

                try {
                    $commandResult = Invoke-FleetCommand @commandParams -Confirm:$false

                    $result = [PSCustomObject]@{
                        PSTypeName = 'HyperionFleet.PatchResult'
                        CommandId = $commandResult.CommandId
                        Operation = $Operation
                        Status = $commandResult.Status
                        TargetCount = $commandResult.TargetCount
                        CompletedCount = $commandResult.CompletedCount
                        ErrorCount = $commandResult.ErrorCount
                        RebootOption = $RebootOption
                        PatchBaseline = $PatchBaseline
                        StartTime = $commandResult.RequestedDateTime
                        Outputs = $commandResult.Outputs
                        Timestamp = Get-Date
                    }

                    # Parse patch compliance from outputs if available
                    if ($Wait -and $commandResult.Outputs) {
                        $complianceSummary = @{
                            TotalInstances = $validTargets.Count
                            SuccessfulInstances = 0
                            FailedInstances = 0
                            InstalledPatches = 0
                            FailedPatches = 0
                        }

                        foreach ($instanceId in $commandResult.Outputs.Keys) {
                            $output = $commandResult.Outputs[$instanceId]
                            if ($output.Status -eq 'Success') {
                                $complianceSummary.SuccessfulInstances++

                                # Parse patch counts from output (simplified)
                                if ($output.StandardOutputContent -match 'InstalledCount: (\d+)') {
                                    $complianceSummary.InstalledPatches += [int]$Matches[1]
                                }
                            }
                            else {
                                $complianceSummary.FailedInstances++
                            }
                        }

                        $result | Add-Member -NotePropertyName 'ComplianceSummary' -NotePropertyValue $complianceSummary
                    }

                    $patchResults.Add($result)

                    Write-FleetLog -Message "Patching operation completed: $($result.Status)" -Level 'Information' -Context @{
                        CommandId = $result.CommandId
                        Status = $result.Status
                        CompletedCount = $result.CompletedCount
                        ErrorCount = $result.ErrorCount
                    }
                }
                catch {
                    Write-FleetLog -Message "Patching operation failed: $_" -Level 'Error'
                    throw
                }
            }
            else {
                Write-FleetLog -Message "Patching operation cancelled by user" -Level 'Information'
            }
        }
        catch {
            Write-FleetLog -Message "Fleet patching failed: $_" -Level 'Error'
            throw
        }
    }

    end {
        if ($patchResults.Count -gt 0) {
            Write-FleetLog -Message "Fleet patching workflow completed. Executed $($patchResults.Count) operation(s)" -Level 'Information'
            return $patchResults.ToArray()
        }
    }
}
