function Get-DSCComplianceStatus {
    <#
    .SYNOPSIS
        Retrieves DSC (Desired State Configuration) compliance status.

    .DESCRIPTION
        Gets the current DSC compliance status by running Test-DscConfiguration and
        returning structured results. Provides detailed information about compliant
        and non-compliant resources, along with configuration metadata.

    .PARAMETER Detailed
        Return detailed resource-level compliance information.

    .PARAMETER ConfigurationName
        Filter results to a specific DSC configuration name.

    .PARAMETER CimSession
        CIM session for remote computer DSC status.

    .PARAMETER ComputerName
        Computer name(s) to check DSC status on. Defaults to local computer.

    .PARAMETER Credential
        Credentials for remote computer access.

    .PARAMETER OutputPath
        Path to save DSC compliance results as JSON.

    .EXAMPLE
        Get-DSCComplianceStatus
        Gets DSC compliance status for the local computer.

    .EXAMPLE
        Get-DSCComplianceStatus -Detailed
        Gets detailed resource-level compliance information.

    .EXAMPLE
        Get-DSCComplianceStatus -ComputerName 'Server01', 'Server02' -Credential $cred
        Gets DSC compliance status from remote computers.

    .EXAMPLE
        Get-DSCComplianceStatus -Detailed -OutputPath 'C:\Reports\dsc-status.json'
        Gets detailed DSC status and saves to JSON file.

    .OUTPUTS
        PSCustomObject with DSC compliance status.

    .NOTES
        Requires the PSDesiredStateConfiguration module.
        Remote queries require appropriate WinRM/CIM configuration.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Local')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [switch]$Detailed,

        [Parameter()]
        [string]$ConfigurationName,

        [Parameter(ParameterSetName = 'CimSession')]
        [Microsoft.Management.Infrastructure.CimSession]$CimSession,

        [Parameter(ParameterSetName = 'Remote')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName,

        [Parameter(ParameterSetName = 'Remote')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    begin {
        Write-ComplianceLog -Message "Getting DSC compliance status" -Level 'Information' -Operation 'Check' -Context @{
            Detailed = $Detailed.IsPresent
        }

        $results = [System.Collections.Generic.List[PSCustomObject]]::new()

        # Check if DSC module is available
        if (-not (Get-Module -Name 'PSDesiredStateConfiguration' -ListAvailable)) {
            Write-ComplianceLog -Message "PSDesiredStateConfiguration module not available" -Level 'Warning' -Operation 'Check'
        }

        # Determine targets
        $targets = switch ($PSCmdlet.ParameterSetName) {
            'CimSession' { @('CimSession') }
            'Remote'     { $ComputerName }
            default      { @($env:COMPUTERNAME ?? 'localhost') }
        }
    }

    process {
        foreach ($target in $targets) {
            try {
                $dscResult = [PSCustomObject]@{
                    PSTypeName           = 'HyperionCompliance.DSCStatus'
                    ComputerName         = $target
                    InDesiredState       = $null
                    Status               = 'Unknown'
                    ConfigurationName    = $null
                    ConfigurationMode    = $null
                    RefreshMode          = $null
                    LastConfigurationApply = $null
                    ConfigurationModeFrequencyMins = $null
                    RefreshFrequencyMins = $null
                    RebootPending        = $null
                    ResourcesInDesiredState = @()
                    ResourcesNotInDesiredState = @()
                    TotalResources       = 0
                    CompliantResources   = 0
                    NonCompliantResources = 0
                    CompliancePercentage = 0
                    CheckedAt            = Get-Date
                    Error                = $null
                }

                # Build parameters for DSC cmdlets
                $dscParams = @{}
                switch ($PSCmdlet.ParameterSetName) {
                    'CimSession' {
                        $dscParams['CimSession'] = $CimSession
                        $dscResult.ComputerName = $CimSession.ComputerName
                    }
                    'Remote' {
                        $dscParams['ComputerName'] = $target
                        if ($Credential) {
                            $dscParams['Credential'] = $Credential
                        }
                    }
                }

                # Check if running on Windows
                if (-not $IsWindows -and $PSCmdlet.ParameterSetName -eq 'Local') {
                    $dscResult.Status = 'NotApplicable'
                    $dscResult.Error = 'DSC is only available on Windows'
                    $results.Add($dscResult)
                    continue
                }

                # Get LCM (Local Configuration Manager) status
                try {
                    $lcm = Get-DscLocalConfigurationManager @dscParams -ErrorAction Stop

                    $dscResult.ConfigurationName = $lcm.ConfigurationName
                    $dscResult.ConfigurationMode = $lcm.ConfigurationMode.ToString()
                    $dscResult.RefreshMode = $lcm.RefreshMode.ToString()
                    $dscResult.ConfigurationModeFrequencyMins = $lcm.ConfigurationModeFrequencyMins
                    $dscResult.RefreshFrequencyMins = $lcm.RefreshFrequencyMins

                    # Get LCM state
                    if ($lcm.LCMState) {
                        $dscResult.Status = $lcm.LCMState.ToString()
                    }
                }
                catch {
                    Write-ComplianceLog -Message "Failed to get LCM status for $target : $_" -Level 'Warning' -Operation 'Check'
                }

                # Test DSC configuration
                try {
                    $testParams = $dscParams.Clone()
                    if ($Detailed) {
                        $testParams['Detailed'] = $true
                    }

                    $testResult = Test-DscConfiguration @testParams -ErrorAction Stop

                    if ($Detailed -and $testResult) {
                        # Detailed results return different object structure
                        $dscResult.InDesiredState = $testResult.InDesiredState

                        if ($testResult.ResourcesInDesiredState) {
                            $dscResult.ResourcesInDesiredState = @($testResult.ResourcesInDesiredState | ForEach-Object {
                                [PSCustomObject]@{
                                    ResourceId    = $_.ResourceId
                                    SourceInfo    = $_.SourceInfo
                                    ModuleName    = $_.ModuleName
                                    ModuleVersion = $_.ModuleVersion
                                    ConfigurationName = $_.ConfigurationName
                                    InDesiredState = $true
                                }
                            })
                        }

                        if ($testResult.ResourcesNotInDesiredState) {
                            $dscResult.ResourcesNotInDesiredState = @($testResult.ResourcesNotInDesiredState | ForEach-Object {
                                [PSCustomObject]@{
                                    ResourceId    = $_.ResourceId
                                    SourceInfo    = $_.SourceInfo
                                    ModuleName    = $_.ModuleName
                                    ModuleVersion = $_.ModuleVersion
                                    ConfigurationName = $_.ConfigurationName
                                    InDesiredState = $false
                                    StartDate     = $_.StartDate
                                    DurationInSeconds = $_.DurationInSeconds
                                    Error         = $_.Error
                                    FinalState    = $_.FinalState
                                    InitialState  = $_.InitialState
                                }
                            })
                        }

                        $dscResult.CompliantResources = $dscResult.ResourcesInDesiredState.Count
                        $dscResult.NonCompliantResources = $dscResult.ResourcesNotInDesiredState.Count
                        $dscResult.TotalResources = $dscResult.CompliantResources + $dscResult.NonCompliantResources
                    }
                    else {
                        # Simple boolean result
                        $dscResult.InDesiredState = [bool]$testResult
                    }

                    # Set status based on compliance
                    if ($dscResult.InDesiredState -eq $true) {
                        $dscResult.Status = 'Compliant'
                    }
                    elseif ($dscResult.InDesiredState -eq $false) {
                        $dscResult.Status = 'NonCompliant'
                    }

                    # Calculate compliance percentage
                    if ($dscResult.TotalResources -gt 0) {
                        $dscResult.CompliancePercentage = [math]::Round(($dscResult.CompliantResources / $dscResult.TotalResources) * 100, 2)
                    }
                    elseif ($dscResult.InDesiredState -eq $true) {
                        $dscResult.CompliancePercentage = 100
                    }
                }
                catch [System.Management.Automation.RuntimeException] {
                    if ($_.Exception.Message -match 'No configuration') {
                        $dscResult.Status = 'NoConfiguration'
                        $dscResult.Error = 'No DSC configuration is applied to this computer'
                    }
                    else {
                        throw
                    }
                }

                # Get configuration status (last apply time, reboot pending)
                try {
                    $configStatus = Get-DscConfigurationStatus @dscParams -ErrorAction SilentlyContinue
                    if ($configStatus) {
                        $dscResult.LastConfigurationApply = $configStatus[0].StartDate
                        $dscResult.RebootPending = $configStatus[0].RebootRequested
                    }
                }
                catch {
                    # Ignore errors getting configuration status
                }

                Write-ComplianceLog -Message "DSC status for $target : $($dscResult.Status)" -Level 'Information' -Operation 'Check' -Context @{
                    ComputerName = $target
                    InDesiredState = $dscResult.InDesiredState
                    Status = $dscResult.Status
                }

                $results.Add($dscResult)
            }
            catch {
                $errorResult = [PSCustomObject]@{
                    PSTypeName     = 'HyperionCompliance.DSCStatus'
                    ComputerName   = $target
                    InDesiredState = $null
                    Status         = 'Error'
                    Error          = $_.Exception.Message
                    CheckedAt      = Get-Date
                }

                Write-ComplianceLog -Message "Failed to get DSC status for $target : $_" -Level 'Error' -Operation 'Check' -Context @{
                    ComputerName = $target
                }

                $results.Add($errorResult)
            }
        }
    }

    end {
        # Export to file if OutputPath specified
        if ($OutputPath) {
            try {
                $outputDir = Split-Path -Path $OutputPath -Parent
                if ($outputDir -and -not (Test-Path -Path $outputDir)) {
                    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
                }

                $exportData = @{
                    GeneratedAt = Get-Date -Format 'o'
                    Results     = $results.ToArray()
                }

                $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

                Write-ComplianceLog -Message "DSC status exported to: $OutputPath" -Level 'Information' -Operation 'Check'
                Write-Information "Results saved to: $OutputPath" -InformationAction Continue
            }
            catch {
                Write-ComplianceLog -Message "Failed to export DSC status: $_" -Level 'Error' -Operation 'Check'
                throw
            }
        }

        # Output summary
        foreach ($result in $results) {
            $statusIcon = switch ($result.Status) {
                'Compliant'      { '[COMPLIANT]' }
                'NonCompliant'   { '[NON-COMPLIANT]' }
                'NoConfiguration' { '[NO CONFIG]' }
                'NotApplicable'  { '[N/A]' }
                'Error'          { '[ERROR]' }
                default          { '[UNKNOWN]' }
            }

            $message = "$statusIcon $($result.ComputerName)"
            if ($result.CompliancePercentage -gt 0) {
                $message += " - $($result.CompliancePercentage)% compliant"
            }
            if ($result.Error) {
                $message += " - $($result.Error)"
            }

            Write-Information $message -InformationAction Continue
        }

        return $results.ToArray()
    }
}
