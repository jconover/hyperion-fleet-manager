#Requires -Version 7.4

<#
.SYNOPSIS
    HyperionCompliance module root loader.

.DESCRIPTION
    This module provides CIS compliance benchmarking and remediation capabilities including:
    - CIS benchmark compliance checking (Level 1 and Level 2)
    - Compliance report generation in multiple formats
    - Automated remediation of compliance findings
    - S3 export for compliance audit trails
    - DSC configuration compliance status

.NOTES
    Module Name: HyperionCompliance
    Version: 1.0.0
    Requires: PowerShell 7.4+, AWS.Tools.SimpleSystemsManagement, AWS.Tools.S3
#>

#region Module Variables
$script:ModuleRoot = $PSScriptRoot
$script:ModuleName = 'HyperionCompliance'
$script:DefaultLogPath = Join-Path -Path $env:TEMP -ChildPath "$ModuleName.log"

# Module-level configuration
$script:ModuleConfig = @{
    DefaultRegion           = 'us-east-1'
    LogLevel                = 'Information'
    DefaultCISLevel         = 1
    RemediationLogPath      = Join-Path -Path $env:TEMP -ChildPath "$ModuleName-remediation.log"
    ReportOutputPath        = Join-Path -Path $env:TEMP -ChildPath 'HyperionCompliance-Reports'
    MaxConcurrentChecks     = 10
    ComplianceThreshold     = 80
    RetryAttempts           = 3
    RetryDelaySeconds       = 5
}

# Load CIS benchmark definitions
$script:CISBenchmarkPath = Join-Path -Path $PSScriptRoot -ChildPath 'Data/CISBenchmarks.psd1'
if (Test-Path -Path $script:CISBenchmarkPath) {
    $script:CISBenchmarks = Import-PowerShellDataFile -Path $script:CISBenchmarkPath
}
else {
    Write-Warning "CIS benchmark definitions not found at: $script:CISBenchmarkPath"
    $script:CISBenchmarks = @{ Controls = @() }
}
#endregion

#region Dot-source Private Functions
$privateFunctions = @(
    Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue
)

foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Imported private function: $($function.BaseName)"
    }
    catch {
        Write-Error "Failed to import private function $($function.FullName): $_"
    }
}
#endregion

#region Dot-source Public Functions
$publicFunctions = @(
    Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue
)

foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Imported public function: $($function.BaseName)"
    }
    catch {
        Write-Error "Failed to import public function $($function.FullName): $_"
    }
}
#endregion

#region Dot-source Classes (if any)
$classFiles = @(
    Get-ChildItem -Path "$PSScriptRoot/Classes/*.ps1" -ErrorAction SilentlyContinue
)

foreach ($class in $classFiles) {
    try {
        . $class.FullName
        Write-Verbose "Imported class: $($class.BaseName)"
    }
    catch {
        Write-Error "Failed to import class $($class.FullName): $_"
    }
}
#endregion

#region Module Initialization
# Verify AWS modules are available
$requiredModules = @('AWS.Tools.SimpleSystemsManagement', 'AWS.Tools.S3')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Write-Warning "Required module '$module' is not installed. Install with: Install-Module $module -Scope CurrentUser"
    }
}

# Create default report output directory if it doesn't exist
if (-not (Test-Path -Path $script:ModuleConfig.ReportOutputPath)) {
    try {
        New-Item -Path $script:ModuleConfig.ReportOutputPath -ItemType Directory -Force | Out-Null
        Write-Verbose "Created report output directory: $($script:ModuleConfig.ReportOutputPath)"
    }
    catch {
        Write-Warning "Failed to create report output directory: $_"
    }
}

# Set default AWS region if not already set
if (-not $env:AWS_DEFAULT_REGION) {
    $env:AWS_DEFAULT_REGION = $script:ModuleConfig.DefaultRegion
}

Write-Verbose "$ModuleName module loaded successfully (v$((Test-ModuleManifest -Path "$PSScriptRoot/$ModuleName.psd1").Version))"
#endregion

#region Exported Members
# Export public functions (explicit export for clarity)
Export-ModuleMember -Function @(
    'Test-CISCompliance',
    'Get-ComplianceReport',
    'Invoke-ComplianceRemediation',
    'Export-ComplianceToS3',
    'Get-DSCComplianceStatus'
)

# Export module configuration variable for advanced scenarios
Export-ModuleMember -Variable 'ModuleConfig'
#endregion
