@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'HyperionCompliance.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID = 'b8e4f2a1-5d9c-4b3e-a7f6-2c8d9e1f3a5b'

    # Author of this module
    Author = 'DevOps Team'

    # Company or vendor of this module
    CompanyName = 'Infrastructure Operations'

    # Copyright statement for this module
    Copyright = '(c) 2026. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'CIS compliance benchmarking, remediation, and reporting module for Hyperion Fleet Manager. Provides cmdlets for running CIS benchmark checks, generating compliance reports, automated remediation, and S3 export capabilities.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.4'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{
            ModuleName = 'AWS.Tools.SimpleSystemsManagement'
            ModuleVersion = '4.1.0'
        },
        @{
            ModuleName = 'AWS.Tools.S3'
            ModuleVersion = '4.1.0'
        }
    )

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Test-CISCompliance',
        'Get-ComplianceReport',
        'Invoke-ComplianceRemediation',
        'Export-ComplianceToS3',
        'Get-DSCComplianceStatus'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # DSC resources to export from this module
    DscResourcesToExport = @()

    # List of all modules packaged with this module
    ModuleList = @()

    # List of all files packaged with this module
    FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('AWS', 'Compliance', 'CIS', 'Security', 'Audit', 'Remediation', 'DSC', 'Windows')

            # A URL to the license for this module.
            LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = ''

            # A URL to an icon representing this module.
            IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
## 1.0.0 - Initial Release
- Test-CISCompliance: Run CIS benchmark checks with Level 1/2 support
- Get-ComplianceReport: Generate compliance reports in JSON, HTML, or CSV format
- Invoke-ComplianceRemediation: Auto-remediate compliance findings with WhatIf support
- Export-ComplianceToS3: Upload compliance reports to S3 with metadata tags
- Get-DSCComplianceStatus: Get DSC configuration compliance status
'@

            # Prerelease string of this module
            Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            RequireLicenseAcceptance = $false

            # External dependent modules of this module
            ExternalModuleDependencies = @('AWS.Tools.SimpleSystemsManagement', 'AWS.Tools.S3')
        }
    }

    # HelpInfo URI of this module
    HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    DefaultCommandPrefix = ''
}
