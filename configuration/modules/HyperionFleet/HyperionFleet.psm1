#Requires -Version 7.4

<#
.SYNOPSIS
    HyperionFleet module root loader.

.DESCRIPTION
    This module provides AWS EC2 fleet management capabilities including:
    - Health monitoring and metrics collection
    - Instance inventory with tag-based filtering
    - SSM Run Command execution
    - Automated patching workflows

.NOTES
    Module Name: HyperionFleet
    Version: 0.1.0
    Requires: PowerShell 7.4+, AWS.Tools.EC2, AWS.Tools.SimpleSystemsManagement
#>

#region Module Variables
$script:ModuleRoot = $PSScriptRoot
$script:ModuleName = 'HyperionFleet'
$script:DefaultLogPath = Join-Path -Path $env:TEMP -ChildPath "$ModuleName.log"

# Module-level configuration
$script:ModuleConfig = @{
    DefaultRegion = 'us-east-1'
    MaxConcurrentCommands = 50
    CommandTimeout = 3600
    LogLevel = 'Information'
    RetryAttempts = 3
    RetryDelaySeconds = 5
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
$requiredModules = @('AWS.Tools.EC2', 'AWS.Tools.SimpleSystemsManagement')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Write-Warning "Required module '$module' is not installed. Install with: Install-Module $module -Scope CurrentUser"
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
    'Get-FleetHealth',
    'Get-FleetInventory',
    'Invoke-FleetCommand',
    'Start-FleetPatch'
)

# Export module configuration variable for advanced scenarios
Export-ModuleMember -Variable 'ModuleConfig'
#endregion
