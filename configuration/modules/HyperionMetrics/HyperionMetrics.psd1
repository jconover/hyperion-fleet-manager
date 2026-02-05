@{
    # Module manifest for HyperionMetrics
    # CloudWatch custom metrics for Hyperion Fleet Manager

    # Script module or binary module file associated with this manifest
    RootModule        = 'HyperionMetrics.psm1'

    # Version number of this module
    ModuleVersion     = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID              = 'a8f3c7e2-4b91-4d5a-9c8e-2f6b3a1d7e4c'

    # Author of this module
    Author            = 'Hyperion Fleet Manager Team'

    # Company or vendor of this module
    CompanyName       = 'Hyperion'

    # Copyright statement for this module
    Copyright         = '(c) 2026 Hyperion Fleet Manager. MIT License.'

    # Description of the functionality provided by this module
    Description       = 'PowerShell module for publishing custom CloudWatch metrics for Hyperion Fleet Manager. Supports system metrics, compliance metrics, application metrics, and scheduled collection.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @(
        @{
            ModuleName    = 'AWS.Tools.CloudWatch'
            ModuleVersion = '4.1.0'
        }
    )

    # Functions to export from this module
    FunctionsToExport = @(
        'Publish-FleetMetric',
        'Get-SystemMetrics',
        'Publish-ComplianceMetrics',
        'Publish-ApplicationMetrics',
        'Start-MetricCollector',
        'Stop-MetricCollector',
        'Get-MetricCollectorStatus'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport   = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module for module discovery
            Tags         = @(
                'AWS',
                'CloudWatch',
                'Metrics',
                'Monitoring',
                'Windows',
                'Fleet',
                'Infrastructure'
            )

            # A URL to the license for this module
            LicenseUri   = 'https://opensource.org/licenses/MIT'

            # A URL to the main website for this project
            ProjectUri   = 'https://github.com/hyperion/fleet-manager'

            # Release notes for this module
            ReleaseNotes = @'
## Version 1.0.0
- Initial release
- Publish-FleetMetric: Publish custom metrics to CloudWatch
- Get-SystemMetrics: Collect system performance metrics
- Publish-ComplianceMetrics: Publish compliance scan results
- Publish-ApplicationMetrics: Publish application health metrics
- Start-MetricCollector: Schedule automatic metric collection
- Stop-MetricCollector: Remove scheduled metric collection
- Get-MetricCollectorStatus: Check collector status
'@
        }
    }

    # HelpInfo URI of this module
    HelpInfoURI       = 'https://github.com/hyperion/fleet-manager/docs/metrics'
}
