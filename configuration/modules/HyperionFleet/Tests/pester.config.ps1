#Requires -Version 7.4
#Requires -Modules Pester

<#
.SYNOPSIS
    Pester 5.x configuration for HyperionFleet module tests.

.DESCRIPTION
    Configures code coverage, output format, test discovery, and execution options
    for comprehensive testing of the HyperionFleet PowerShell module.

.EXAMPLE
    $Config = . ./pester.config.ps1
    Invoke-Pester -Configuration $Config

.EXAMPLE
    # Run with verbose output
    $Config = . ./pester.config.ps1
    $Config.Output.Verbosity = 'Detailed'
    Invoke-Pester -Configuration $Config

.NOTES
    Requires Pester 5.x or higher.
#>

# Get module paths
$ModuleRoot = Split-Path -Path $PSScriptRoot -Parent
$TestsPath = $PSScriptRoot

# Create Pester configuration
$PesterConfiguration = New-PesterConfiguration

#region Run Configuration
$PesterConfiguration.Run.Path = $TestsPath
$PesterConfiguration.Run.Exit = $false
$PesterConfiguration.Run.Throw = $false
$PesterConfiguration.Run.PassThru = $true
$PesterConfiguration.Run.SkipRemainingOnFailure = 'None'
#endregion

#region Filter Configuration
$PesterConfiguration.Filter.Tag = @()
$PesterConfiguration.Filter.ExcludeTag = @('Integration', 'Slow')
$PesterConfiguration.Filter.Line = @()
$PesterConfiguration.Filter.FullName = @()
#endregion

#region Code Coverage Configuration
$PesterConfiguration.CodeCoverage.Enabled = $true
$PesterConfiguration.CodeCoverage.OutputFormat = 'JaCoCo'
$PesterConfiguration.CodeCoverage.OutputPath = Join-Path -Path $TestsPath -ChildPath 'coverage.xml'
$PesterConfiguration.CodeCoverage.OutputEncoding = 'UTF8'
$PesterConfiguration.CodeCoverage.Path = @(
    (Join-Path -Path $ModuleRoot -ChildPath 'Public/*.ps1'),
    (Join-Path -Path $ModuleRoot -ChildPath 'Private/*.ps1'),
    (Join-Path -Path $ModuleRoot -ChildPath 'HyperionFleet.psm1')
)
$PesterConfiguration.CodeCoverage.ExcludeTests = $true
$PesterConfiguration.CodeCoverage.RecursePaths = $true
$PesterConfiguration.CodeCoverage.CoveragePercentTarget = 80
$PesterConfiguration.CodeCoverage.SingleHitBreakpoints = $true
#endregion

#region Test Result Configuration
$PesterConfiguration.TestResult.Enabled = $true
$PesterConfiguration.TestResult.OutputFormat = 'NUnitXml'
$PesterConfiguration.TestResult.OutputPath = Join-Path -Path $TestsPath -ChildPath 'testResults.xml'
$PesterConfiguration.TestResult.OutputEncoding = 'UTF8'
$PesterConfiguration.TestResult.TestSuiteName = 'HyperionFleet'
#endregion

#region Should Configuration
$PesterConfiguration.Should.ErrorAction = 'Continue'
#endregion

#region Debug Configuration
$PesterConfiguration.Debug.ShowFullErrors = $true
$PesterConfiguration.Debug.WriteDebugMessages = $false
$PesterConfiguration.Debug.WriteDebugMessagesFrom = @('Discovery', 'Skip', 'Mock', 'CodeCoverage')
$PesterConfiguration.Debug.ShowNavigationMarkers = $false
$PesterConfiguration.Debug.ReturnRawResultObject = $false
#endregion

#region Output Configuration
$PesterConfiguration.Output.Verbosity = 'Normal'
$PesterConfiguration.Output.StackTraceVerbosity = 'Filtered'
$PesterConfiguration.Output.CIFormat = 'Auto'
$PesterConfiguration.Output.RenderMode = 'Auto'
#endregion

# Return configuration
return $PesterConfiguration

<#
.SYNOPSIS
    Helper functions for running tests.

.DESCRIPTION
    Additional utility functions for test execution.
#>

function Invoke-HyperionFleetTests {
    <#
    .SYNOPSIS
        Runs all HyperionFleet module tests.

    .PARAMETER Tag
        Run only tests with specified tag(s).

    .PARAMETER ExcludeTag
        Exclude tests with specified tag(s).

    .PARAMETER Coverage
        Enable code coverage reporting.

    .PARAMETER Detailed
        Show detailed output.

    .EXAMPLE
        Invoke-HyperionFleetTests

    .EXAMPLE
        Invoke-HyperionFleetTests -Tag 'Unit' -Coverage
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$Tag,

        [Parameter()]
        [string[]]$ExcludeTag = @('Integration', 'Slow'),

        [Parameter()]
        [switch]$Coverage,

        [Parameter()]
        [switch]$Detailed
    )

    $Config = New-PesterConfiguration

    $Config.Run.Path = $PSScriptRoot
    $Config.Run.PassThru = $true

    if ($Tag) {
        $Config.Filter.Tag = $Tag
    }
    if ($ExcludeTag) {
        $Config.Filter.ExcludeTag = $ExcludeTag
    }

    $Config.CodeCoverage.Enabled = $Coverage.IsPresent
    if ($Coverage) {
        $ModuleRoot = Split-Path -Path $PSScriptRoot -Parent
        $Config.CodeCoverage.Path = @(
            (Join-Path -Path $ModuleRoot -ChildPath 'Public/*.ps1'),
            (Join-Path -Path $ModuleRoot -ChildPath 'Private/*.ps1')
        )
        $Config.CodeCoverage.CoveragePercentTarget = 80
    }

    if ($Detailed) {
        $Config.Output.Verbosity = 'Detailed'
    }

    $Results = Invoke-Pester -Configuration $Config

    # Summary output
    Write-Host "`n====== Test Summary ======" -ForegroundColor Cyan
    Write-Host "Total Tests:  $($Results.TotalCount)" -ForegroundColor White
    Write-Host "Passed:       $($Results.PassedCount)" -ForegroundColor Green
    Write-Host "Failed:       $($Results.FailedCount)" -ForegroundColor $(if ($Results.FailedCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "Skipped:      $($Results.SkippedCount)" -ForegroundColor Yellow

    if ($Coverage -and $Results.CodeCoverage) {
        $CoveragePercent = [math]::Round(($Results.CodeCoverage.CoveragePercent), 2)
        $CoverageColor = if ($CoveragePercent -ge 80) { 'Green' } elseif ($CoveragePercent -ge 60) { 'Yellow' } else { 'Red' }
        Write-Host "Coverage:     $CoveragePercent%" -ForegroundColor $CoverageColor
    }

    Write-Host "==========================`n" -ForegroundColor Cyan

    return $Results
}
