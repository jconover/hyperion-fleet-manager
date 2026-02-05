function Invoke-ComplianceRemediation {
    <#
    .SYNOPSIS
        Automatically remediates CIS compliance findings.

    .DESCRIPTION
        Applies remediation scripts to fix non-compliant CIS controls. Supports
        selective remediation by control ID, WhatIf mode for testing, and comprehensive
        logging of all changes. All remediation actions are logged for audit purposes.

    .PARAMETER FindingIds
        Array of CIS control IDs to remediate. If not specified, remediates all
        failed controls from the provided ComplianceResults.

    .PARAMETER ComplianceResults
        Results from Test-CISCompliance to use for remediation. If not provided,
        runs Test-CISCompliance to get current state.

    .PARAMETER Level
        If generating new compliance results, specifies the CIS level to check.

    .PARAMETER Category
        If generating new compliance results, filters by category.

    .PARAMETER Force
        Skip confirmation prompts. Use with caution.

    .PARAMETER WhatIf
        Shows what changes would be made without actually applying them.

    .PARAMETER Confirm
        Prompts for confirmation before each remediation action.

    .PARAMETER LogPath
        Path to save remediation log. Defaults to module configuration.

    .PARAMETER ExcludeHighImpact
        Exclude high-impact controls from automatic remediation. These require
        manual intervention.

    .EXAMPLE
        Invoke-ComplianceRemediation -WhatIf
        Shows what remediations would be applied without making changes.

    .EXAMPLE
        Invoke-ComplianceRemediation -FindingIds 'CIS-1.1.1', 'CIS-1.1.2' -Confirm
        Remediates specific controls with confirmation prompts.

    .EXAMPLE
        $results = Test-CISCompliance -Level 1 -PassThru
        $results | Where-Object { $_.Status -eq 'Fail' } | Invoke-ComplianceRemediation

    .EXAMPLE
        Invoke-ComplianceRemediation -ExcludeHighImpact -Force
        Remediates all low/medium impact controls without prompts.

    .OUTPUTS
        PSCustomObject[] with remediation results.

    .NOTES
        - Remediation requires elevated privileges (Administrator)
        - All changes are logged to the remediation log file
        - Some controls may not have automatic remediation and require manual intervention
        - Always test in a non-production environment first
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('ControlId')]
        [ValidatePattern('^CIS-[\d\.]+$')]
        [string[]]$FindingIds,

        [Parameter(ValueFromPipeline)]
        [PSCustomObject[]]$ComplianceResults,

        [Parameter()]
        [ValidateSet(1, 2)]
        [int]$Level = 1,

        [Parameter()]
        [ValidateSet('Account Policies', 'Local Policies', 'Administrative Templates', 'Advanced Audit Policy')]
        [string]$Category,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = $script:ModuleConfig.RemediationLogPath,

        [Parameter()]
        [switch]$ExcludeHighImpact
    )

    begin {
        Write-ComplianceLog -Message "Starting compliance remediation" -Level 'Information' -Operation 'Remediation' -Context @{
            FindingIds       = $FindingIds -join ', '
            ExcludeHighImpact = $ExcludeHighImpact.IsPresent
        }

        $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()
        $remediationResults = [System.Collections.Generic.List[PSCustomObject]]::new()

        # Check for admin privileges on Windows
        if ($IsWindows) {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if (-not $isAdmin -and -not $WhatIfPreference) {
                Write-ComplianceLog -Message "Remediation requires Administrator privileges" -Level 'Warning' -Operation 'Remediation'
                Write-Warning "Remediation requires Administrator privileges. Run PowerShell as Administrator or use -WhatIf to preview changes."
            }
        }

        $startTime = Get-Date
    }

    process {
        # Collect pipeline results
        if ($ComplianceResults) {
            foreach ($result in $ComplianceResults) {
                $allResults.Add($result)
            }
        }
    }

    end {
        try {
            # If no results provided, run compliance check
            if ($allResults.Count -eq 0) {
                Write-ComplianceLog -Message "No compliance results provided, running compliance check" -Level 'Information' -Operation 'Remediation'

                $checkParams = @{
                    Level    = $Level
                    PassThru = $true
                    Quiet    = $true
                }
                if ($Category) {
                    $checkParams['Category'] = $Category
                }

                $checkResults = Test-CISCompliance @checkParams
                foreach ($result in $checkResults) {
                    $allResults.Add($result)
                }
            }

            # Filter to only failed controls
            $failedControls = $allResults | Where-Object { $_.Status -eq 'Fail' }

            # Filter by FindingIds if specified
            if ($FindingIds -and $FindingIds.Count -gt 0) {
                $failedControls = $failedControls | Where-Object { $_.ControlId -in $FindingIds }
            }

            # Exclude high impact if requested
            if ($ExcludeHighImpact) {
                $failedControls = $failedControls | Where-Object { $_.Impact -ne 'High' }
            }

            if ($failedControls.Count -eq 0) {
                Write-Information "No failed controls found requiring remediation." -InformationAction Continue
                return
            }

            Write-Information "Found $($failedControls.Count) controls requiring remediation." -InformationAction Continue

            # Process each failed control
            foreach ($failed in $failedControls) {
                $remediationResult = [PSCustomObject]@{
                    PSTypeName     = 'HyperionCompliance.RemediationResult'
                    ControlId      = $failed.ControlId
                    Title          = $failed.Title
                    Impact         = $failed.Impact
                    Category       = $failed.Category
                    Status         = 'Skipped'
                    Message        = $null
                    WhatIf         = $WhatIfPreference
                    AppliedAt      = $null
                    Duration       = $null
                    PreviousValue  = $failed.ActualValue
                    NewValue       = $null
                }

                $actionStartTime = Get-Date

                # Find the control definition
                $controlDef = $script:CISBenchmarks.Controls | Where-Object { $_.ControlId -eq $failed.ControlId }

                if (-not $controlDef) {
                    $remediationResult.Status = 'Failed'
                    $remediationResult.Message = 'Control definition not found'
                    Write-ComplianceLog -Message "Control definition not found: $($failed.ControlId)" -Level 'Warning' -Operation 'Remediation'
                    $remediationResults.Add($remediationResult)
                    continue
                }

                if (-not $controlDef.RemediationScript) {
                    $remediationResult.Status = 'Skipped'
                    $remediationResult.Message = 'No remediation script available - manual remediation required'
                    Write-ComplianceLog -Message "No remediation script for: $($failed.ControlId)" -Level 'Information' -Operation 'Remediation'
                    $remediationResults.Add($remediationResult)
                    continue
                }

                # Warn about high-impact remediations
                if ($failed.Impact -eq 'High' -and -not $Force) {
                    Write-Warning "Control $($failed.ControlId) is HIGH IMPACT: $($failed.Title)"
                }

                # Build target description for ShouldProcess
                $targetDescription = "$($failed.ControlId): $($failed.Title)"

                if ($PSCmdlet.ShouldProcess($targetDescription, 'Apply remediation')) {
                    try {
                        # Execute remediation script
                        $remediationScript = [scriptblock]::Create($controlDef.RemediationScript.ToString())

                        if ($WhatIfPreference) {
                            # Execute with WhatIf parameter
                            $output = & $remediationScript -WhatIf
                            $remediationResult.Status = 'WhatIf'
                            $remediationResult.Message = $output -join '; '
                        }
                        else {
                            # Execute actual remediation
                            $output = & $remediationScript
                            $remediationResult.Status = 'Success'
                            $remediationResult.Message = $output -join '; '
                            $remediationResult.AppliedAt = Get-Date

                            # Try to get new value after remediation
                            try {
                                $newCheckResult = Test-CISCompliance -ControlId $failed.ControlId -PassThru -Quiet
                                if ($newCheckResult) {
                                    $remediationResult.NewValue = $newCheckResult.ActualValue
                                }
                            }
                            catch {
                                # Ignore errors getting new value
                            }
                        }

                        Write-RemediationLog -ControlId $failed.ControlId -Action $failed.Title -Result $remediationResult.Status -Details $remediationResult.Message -WhatIf:$WhatIfPreference
                    }
                    catch {
                        $remediationResult.Status = 'Failed'
                        $remediationResult.Message = "Remediation failed: $($_.Exception.Message)"

                        Write-RemediationLog -ControlId $failed.ControlId -Action $failed.Title -Result 'Failed' -Details $_.Exception.Message

                        Write-ComplianceLog -Message "Remediation failed for $($failed.ControlId): $_" -Level 'Error' -Operation 'Remediation' -Context @{
                            ControlId = $failed.ControlId
                        }
                    }
                }
                else {
                    $remediationResult.Status = 'Skipped'
                    $remediationResult.Message = 'User cancelled or declined'
                }

                $remediationResult.Duration = (Get-Date) - $actionStartTime
                $remediationResults.Add($remediationResult)

                # Output progress
                $statusIcon = switch ($remediationResult.Status) {
                    'Success' { '[OK]' }
                    'WhatIf'  { '[WHATIF]' }
                    'Failed'  { '[FAIL]' }
                    'Skipped' { '[SKIP]' }
                }
                Write-Information "$statusIcon $($failed.ControlId): $($remediationResult.Message)" -InformationAction Continue
            }

            # Summary
            $duration = (Get-Date) - $startTime
            $successCount = ($remediationResults | Where-Object { $_.Status -eq 'Success' }).Count
            $failedCount = ($remediationResults | Where-Object { $_.Status -eq 'Failed' }).Count
            $skippedCount = ($remediationResults | Where-Object { $_.Status -eq 'Skipped' }).Count
            $whatIfCount = ($remediationResults | Where-Object { $_.Status -eq 'WhatIf' }).Count

            Write-ComplianceLog -Message "Compliance remediation completed" -Level 'Information' -Operation 'Remediation' -Context @{
                Total    = $remediationResults.Count
                Success  = $successCount
                Failed   = $failedCount
                Skipped  = $skippedCount
                WhatIf   = $whatIfCount
                Duration = $duration.TotalSeconds
            }

            Write-Information "" -InformationAction Continue
            Write-Information "========================================" -InformationAction Continue
            Write-Information "Remediation Summary" -InformationAction Continue
            Write-Information "========================================" -InformationAction Continue
            Write-Information "Total Controls: $($remediationResults.Count)" -InformationAction Continue
            Write-Information "Successful: $successCount" -InformationAction Continue
            Write-Information "Failed: $failedCount" -InformationAction Continue
            Write-Information "Skipped: $skippedCount" -InformationAction Continue
            if ($whatIfCount -gt 0) {
                Write-Information "WhatIf: $whatIfCount" -InformationAction Continue
            }
            Write-Information "Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -InformationAction Continue
            Write-Information "Log File: $LogPath" -InformationAction Continue
            Write-Information "========================================" -InformationAction Continue

            return $remediationResults.ToArray()
        }
        catch {
            Write-ComplianceLog -Message "Compliance remediation failed: $_" -Level 'Error' -Operation 'Remediation'
            throw
        }
    }
}
