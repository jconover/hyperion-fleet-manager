function Test-CISCompliance {
    <#
    .SYNOPSIS
        Runs CIS benchmark compliance checks against the local system.

    .DESCRIPTION
        Executes CIS (Center for Internet Security) benchmark compliance checks against
        Windows Server systems. Supports Level 1 and Level 2 benchmarks, with filtering
        by category. Returns detailed compliance results as objects for further processing.

        Level 1 benchmarks are intended for all systems and have minimal performance impact.
        Level 2 benchmarks provide additional security for high-security environments.

    .PARAMETER Level
        The CIS benchmark level to check. Valid values: 1, 2.
        Level 1: Basic security settings recommended for all systems.
        Level 2: Enhanced security settings for high-security environments.
        Default: 1

    .PARAMETER Category
        Filter checks by category. If not specified, all categories are checked.
        Valid values: 'Account Policies', 'Local Policies', 'Administrative Templates', 'Advanced Audit Policy'

    .PARAMETER ControlId
        Run specific controls by their CIS control ID(s).
        Example: 'CIS-1.1.1', 'CIS-2.3.1.1'

    .PARAMETER OutputPath
        Path to save detailed results. If specified, results are exported to JSON.

    .PARAMETER IncludeLevel2
        Include Level 2 checks when Level 1 is specified. This provides comprehensive coverage.

    .PARAMETER PassThru
        Return all results including passed checks. By default, only failed checks are returned.

    .PARAMETER Quiet
        Suppress console output. Useful for scripted/automated scenarios.

    .EXAMPLE
        Test-CISCompliance
        Runs all Level 1 CIS benchmark checks and returns failed controls.

    .EXAMPLE
        Test-CISCompliance -Level 2 -PassThru
        Runs all Level 1 and Level 2 checks and returns all results.

    .EXAMPLE
        Test-CISCompliance -Category 'Account Policies' -OutputPath 'C:\Reports\compliance.json'
        Runs Level 1 Account Policy checks and saves results to JSON.

    .EXAMPLE
        Test-CISCompliance -ControlId 'CIS-1.1.1', 'CIS-1.1.2' -PassThru
        Runs specific CIS controls and returns all results.

    .EXAMPLE
        $results = Test-CISCompliance -Level 1 -PassThru
        $results | Where-Object { -not $_.IsCompliant } | Format-Table ControlId, Title, ActualValue

    .OUTPUTS
        PSCustomObject[] with compliance check results.

    .NOTES
        Requires elevated privileges to check some security policies.
        Some checks may return 'Unknown' status on non-Windows systems.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByLevel')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ParameterSetName = 'ByLevel')]
        [ValidateSet(1, 2)]
        [int]$Level = 1,

        [Parameter(ParameterSetName = 'ByLevel')]
        [Parameter(ParameterSetName = 'ByControl')]
        [ValidateSet('Account Policies', 'Local Policies', 'Administrative Templates', 'Advanced Audit Policy')]
        [string]$Category,

        [Parameter(ParameterSetName = 'ByControl', Mandatory)]
        [ValidatePattern('^CIS-[\d\.]+$')]
        [string[]]$ControlId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(ParameterSetName = 'ByLevel')]
        [switch]$IncludeLevel2,

        [Parameter()]
        [switch]$PassThru,

        [Parameter()]
        [switch]$Quiet
    )

    begin {
        Write-ComplianceLog -Message "Starting CIS compliance check" -Level 'Information' -Operation 'Check' -Context @{
            Level     = $Level
            Category  = $Category ?? 'All'
            ControlId = $ControlId -join ', '
        }

        # Initialize results collection
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()

        # Load CIS benchmarks
        if (-not $script:CISBenchmarks -or $script:CISBenchmarks.Controls.Count -eq 0) {
            Write-ComplianceLog -Message "CIS benchmark definitions not loaded" -Level 'Error' -Operation 'Check'
            throw "CIS benchmark definitions are not available. Ensure Data/CISBenchmarks.psd1 exists."
        }

        # Determine which levels to check
        $levelsToCheck = @($Level)
        if ($Level -eq 2 -or $IncludeLevel2) {
            $levelsToCheck = @(1, 2)
        }

        # Track timing
        $startTime = Get-Date
    }

    process {
        try {
            # Filter controls based on parameters
            $controlsToCheck = $script:CISBenchmarks.Controls

            # Filter by control ID if specified
            if ($PSCmdlet.ParameterSetName -eq 'ByControl') {
                $controlsToCheck = $controlsToCheck | Where-Object { $_.ControlId -in $ControlId }

                if ($controlsToCheck.Count -eq 0) {
                    Write-ComplianceLog -Message "No controls found matching specified IDs: $($ControlId -join ', ')" -Level 'Warning' -Operation 'Check'
                    return
                }
            }
            else {
                # Filter by level
                $controlsToCheck = $controlsToCheck | Where-Object { $_.Level -in $levelsToCheck }
            }

            # Filter by category if specified
            if ($Category) {
                $controlsToCheck = $controlsToCheck | Where-Object { $_.Category -eq $Category }
            }

            if (-not $Quiet) {
                Write-Information "Checking $($controlsToCheck.Count) CIS controls..." -InformationAction Continue
            }

            $checkedCount = 0
            $passedCount = 0
            $failedCount = 0
            $errorCount = 0

            foreach ($control in $controlsToCheck) {
                $checkedCount++

                $checkResult = [PSCustomObject]@{
                    PSTypeName       = 'HyperionCompliance.CISCheckResult'
                    ControlId        = $control.ControlId
                    Title            = $control.Title
                    Description      = $control.Description
                    Level            = $control.Level
                    Category         = $control.Category
                    SubCategory      = $control.SubCategory
                    Impact           = $control.Impact
                    ExpectedValue    = $control.ExpectedValue
                    ActualValue      = $null
                    IsCompliant      = $false
                    Status           = 'Unknown'
                    Message          = $null
                    RemediationAvailable = $null -ne $control.RemediationScript
                    AuditCommand     = $control.AuditCommand
                    CheckedAt        = Get-Date
                    Duration         = $null
                }

                $checkStartTime = Get-Date

                try {
                    # Execute the check script
                    if ($control.CheckScript) {
                        $checkScriptBlock = [scriptblock]::Create($control.CheckScript.ToString())
                        $isCompliant = & $checkScriptBlock

                        $checkResult.IsCompliant = [bool]$isCompliant
                        $checkResult.Status = $isCompliant ? 'Pass' : 'Fail'

                        if ($isCompliant) {
                            $passedCount++
                            $checkResult.Message = 'Control is compliant'
                        }
                        else {
                            $failedCount++
                            $checkResult.Message = 'Control is not compliant'
                        }

                        # Try to get actual value for reporting
                        $checkResult.ActualValue = Get-ControlActualValue -Control $control
                    }
                    else {
                        $checkResult.Status = 'Skipped'
                        $checkResult.Message = 'No check script defined'
                    }
                }
                catch {
                    $errorCount++
                    $checkResult.Status = 'Error'
                    $checkResult.Message = "Check failed: $($_.Exception.Message)"

                    Write-ComplianceLog -Message "Error checking control $($control.ControlId): $_" -Level 'Warning' -Operation 'Check' -Context @{
                        ControlId = $control.ControlId
                    }
                }

                $checkResult.Duration = (Get-Date) - $checkStartTime

                # Add to results
                $results.Add($checkResult)

                # Progress indicator
                if (-not $Quiet -and ($checkedCount % 5 -eq 0)) {
                    Write-Progress -Activity "CIS Compliance Check" -Status "Checking controls..." -PercentComplete (($checkedCount / $controlsToCheck.Count) * 100)
                }
            }

            if (-not $Quiet) {
                Write-Progress -Activity "CIS Compliance Check" -Completed
            }

            # Log summary
            $duration = (Get-Date) - $startTime
            Write-ComplianceLog -Message "CIS compliance check completed" -Level 'Information' -Operation 'Check' -Context @{
                TotalChecked = $checkedCount
                Passed       = $passedCount
                Failed       = $failedCount
                Errors       = $errorCount
                Duration     = $duration.TotalSeconds
            }

            # Summary output
            if (-not $Quiet) {
                $compliancePercent = $checkedCount -gt 0 ? [math]::Round(($passedCount / $checkedCount) * 100, 1) : 0

                Write-Information "" -InformationAction Continue
                Write-Information "========================================" -InformationAction Continue
                Write-Information "CIS Compliance Check Summary" -InformationAction Continue
                Write-Information "========================================" -InformationAction Continue
                Write-Information "Total Controls Checked: $checkedCount" -InformationAction Continue
                Write-Information "Passed: $passedCount" -InformationAction Continue
                Write-Information "Failed: $failedCount" -InformationAction Continue
                Write-Information "Errors: $errorCount" -InformationAction Continue
                Write-Information "Compliance Rate: $compliancePercent%" -InformationAction Continue
                Write-Information "Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -InformationAction Continue
                Write-Information "========================================" -InformationAction Continue
            }

            # Export to file if OutputPath specified
            if ($OutputPath) {
                try {
                    $outputDir = Split-Path -Path $OutputPath -Parent
                    if ($outputDir -and -not (Test-Path -Path $outputDir)) {
                        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
                    }

                    $exportData = @{
                        GeneratedAt      = Get-Date -Format 'o'
                        BenchmarkVersion = $script:CISBenchmarks.BenchmarkVersion
                        BenchmarkName    = $script:CISBenchmarks.BenchmarkName
                        LevelChecked     = $levelsToCheck
                        CategoryFilter   = $Category
                        Summary          = @{
                            TotalChecked     = $checkedCount
                            Passed           = $passedCount
                            Failed           = $failedCount
                            Errors           = $errorCount
                            ComplianceRate   = $compliancePercent
                        }
                        Results          = $results.ToArray()
                    }

                    $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

                    Write-ComplianceLog -Message "Results exported to: $OutputPath" -Level 'Information' -Operation 'Check'

                    if (-not $Quiet) {
                        Write-Information "Results saved to: $OutputPath" -InformationAction Continue
                    }
                }
                catch {
                    Write-ComplianceLog -Message "Failed to export results to '$OutputPath': $_" -Level 'Error' -Operation 'Check'
                    throw
                }
            }
        }
        catch {
            Write-ComplianceLog -Message "CIS compliance check failed: $_" -Level 'Error' -Operation 'Check'
            throw
        }
    }

    end {
        # Return results based on PassThru parameter
        if ($PassThru) {
            return $results.ToArray()
        }
        else {
            # Return only failed/error results by default
            return $results | Where-Object { $_.Status -in @('Fail', 'Error') }
        }
    }
}


# Helper function to get actual value for a control
function Get-ControlActualValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Control
    )

    try {
        # If control has a registry path, read it
        if ($Control.RegistryPath -and $Control.RegistryName) {
            $regValue = Get-ItemProperty -Path $Control.RegistryPath -Name $Control.RegistryName -ErrorAction SilentlyContinue
            if ($regValue) {
                return $regValue.($Control.RegistryName)
            }
        }

        # For security policies, try to get the value
        $controlId = $Control.ControlId
        switch -Regex ($controlId) {
            'CIS-1\.1\.' {
                # Password policies
                $output = net accounts 2>$null
                return $output -join "`n"
            }
            'CIS-1\.2\.' {
                # Lockout policies
                $output = net accounts 2>$null
                return $output -join "`n"
            }
            'CIS-17\.' {
                # Audit policies
                if ($Control.SubCategory -eq 'Audit Policy') {
                    $subcategory = $Control.Title -replace '.*Audit\s+', '' -replace '\s+is set to.*', ''
                    return (auditpol /get /subcategory:"$subcategory" 2>$null) -join "`n"
                }
            }
        }

        return 'Unable to retrieve actual value'
    }
    catch {
        return "Error: $($_.Exception.Message)"
    }
}
