#Requires -Version 7.0
#Requires -Modules AWS.Tools.CloudWatch

<#
.SYNOPSIS
    HyperionMetrics module loader for CloudWatch custom metrics.

.DESCRIPTION
    This module provides functions for publishing custom CloudWatch metrics
    for Hyperion Fleet Manager. It supports system metrics, compliance metrics,
    application health metrics, and scheduled metric collection.

.NOTES
    Module: HyperionMetrics
    Version: 1.0.0
    Author: Hyperion Fleet Manager Team
#>

# Module-level variables
$script:ModuleRoot = $PSScriptRoot
$script:DefaultNamespace = 'Hyperion/FleetManager'
$script:MetricBatchSize = 20  # CloudWatch limit per PutMetricData call
$script:CollectorTaskName = 'HyperionMetricCollector'

# Import private functions
$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
if (Test-Path -Path $privatePath) {
    $privateFiles = Get-ChildItem -Path $privatePath -Filter '*.ps1' -ErrorAction SilentlyContinue
    foreach ($file in $privateFiles) {
        try {
            . $file.FullName
            Write-Verbose "Imported private function: $($file.BaseName)"
        }
        catch {
            Write-Error "Failed to import private function $($file.FullName): $_"
        }
    }
}

# Import public functions
$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
if (Test-Path -Path $publicPath) {
    $publicFiles = Get-ChildItem -Path $publicPath -Filter '*.ps1' -ErrorAction SilentlyContinue
    foreach ($file in $publicFiles) {
        try {
            . $file.FullName
            Write-Verbose "Imported public function: $($file.BaseName)"
        }
        catch {
            Write-Error "Failed to import public function $($file.FullName): $_"
        }
    }
}

# Export module variables for advanced use cases
Export-ModuleMember -Variable @(
    'DefaultNamespace',
    'MetricBatchSize',
    'CollectorTaskName'
)
