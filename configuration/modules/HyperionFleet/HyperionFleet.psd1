@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'HyperionFleet.psm1'

    # Version number of this module.
    ModuleVersion = '0.1.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID = 'a7f3e9d1-4c8b-4a2f-9e6d-3b5c7a9f1e4d'

    # Author of this module
    Author = 'DevOps Team'

    # Company or vendor of this module
    CompanyName = 'Infrastructure Operations'

    # Copyright statement for this module
    Copyright = '(c) 2026. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'AWS EC2 fleet management and automation module for Hyperion infrastructure. Provides cmdlets for health monitoring, inventory management, SSM command execution, and patching workflows.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.4'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{
            ModuleName = 'AWS.Tools.EC2'
            ModuleVersion = '4.1.0'
        },
        @{
            ModuleName = 'AWS.Tools.SimpleSystemsManagement'
            ModuleVersion = '4.1.0'
        }
    )

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Get-FleetHealth',
        'Get-FleetInventory',
        'Invoke-FleetCommand',
        'Start-FleetPatch'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('AWS', 'EC2', 'Fleet', 'SSM', 'Automation', 'Infrastructure', 'Patching')

            # A URL to the license for this module.
            LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = ''

            # A URL to an icon representing this module.
            IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
## 0.1.0 - Initial Release
- Get-FleetHealth: Query EC2 instances and return health metrics
- Get-FleetInventory: List all instances with tags
- Invoke-FleetCommand: Execute SSM Run Command across fleet
- Start-FleetPatch: Trigger patching workflow with validation
'@

            # Prerelease string of this module
            Prerelease = 'beta'

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            RequireLicenseAcceptance = $false

            # External dependent modules of this module
            ExternalModuleDependencies = @('AWS.Tools.EC2', 'AWS.Tools.SimpleSystemsManagement')
        }
    }

    # HelpInfo URI of this module
    HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    DefaultCommandPrefix = ''
}
