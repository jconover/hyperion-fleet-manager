<#
.SYNOPSIS
    Configuration data for Hyperion Fleet Manager Build Agent DSC Configuration.

.DESCRIPTION
    This PowerShell data file contains all configuration settings for the
    BuildAgentConfiguration DSC configuration. It defines:
    - Build tool versions
    - Agent configuration settings
    - Workspace and cache paths
    - Scheduled task settings
    - Service account configuration
    - Certificate configuration

    Modify these values to customize the build agent configuration for your
    environment. Each setting is documented with its purpose and valid values.

.NOTES
    Project:     Hyperion Fleet Manager
    Module:      DSC Build Agent Configuration Data
    Version:     1.0.0
    Author:      Hyperion Fleet Team

    IMPORTANT: Review and update these settings before deployment:
    - Tool versions should match your organization's requirements
    - Paths may need adjustment based on disk configuration
    - Service account settings require proper credential management

.EXAMPLE
    # Import configuration data
    $configData = Import-PowerShellDataFile -Path '.\ConfigurationData\BuildAgent.psd1'

    # Compile DSC configuration with data
    BuildAgentConfiguration -ConfigurationData $configData -OutputPath '.\Output'
#>

@{
    # AllNodes defines the target nodes and their specific configurations
    AllNodes = @(
        # Default configuration applied to all nodes
        @{
            NodeName                    = '*'
            Role                        = 'BuildAgent'

            #region Directory Paths
            # Primary build agent installation directory
            BuildAgentPath              = 'C:\BuildAgent'

            # Workspace directory for build jobs
            WorkspacePath               = 'C:\Workspace'

            # Temporary files directory (separate from system temp for cleanup)
            BuildTempPath               = 'C:\BuildAgent\Temp'

            # Package cache directories for faster builds
            NuGetCachePath              = 'C:\BuildAgent\Cache\NuGet'
            NpmCachePath                = 'C:\BuildAgent\Cache\npm'
            PipCachePath                = 'C:\BuildAgent\Cache\pip'
            TerraformPluginCachePath    = 'C:\BuildAgent\Cache\terraform-plugins'
            #endregion

            #region Tool Versions
            # Specify exact versions for reproducible builds
            # Set to $null or remove version to get latest from Chocolatey

            # Node.js LTS version (use 'latest' for most recent LTS)
            NodeJSVersion               = '20.11.0'

            # Python 3 version
            PythonVersion               = '3.12.1'

            # Visual Studio 2022 Build Tools version
            # Note: Major releases only, e.g., '17.8.0'
            VSBuildToolsVersion         = '17.8.0'

            # .NET SDK version
            DotNetSDKVersion            = '8.0.101'

            # Terraform version (match infrastructure team's version)
            TerraformVersion            = '1.7.0'
            #endregion

            #region Package Management
            # Enable automatic upgrades for non-version-pinned packages
            AutoUpgradePackages         = $false
            #endregion

            #region Docker Configuration
            # Enable Docker Desktop installation
            EnableDocker                = $true

            # Enable Hyper-V for Windows containers (requires compatible hardware)
            EnableHyperV                = $true
            #endregion

            #region Service Account Configuration
            # Create a dedicated service account for the build agent
            CreateServiceAccount        = $true

            # Local service account name
            ServiceAccountName          = 'svc_buildagent'

            # Note: Password should be provided via secure parameter at runtime
            # or retrieved from a secrets manager
            #endregion

            #region Maintenance Settings
            # Number of days to retain temporary build files
            TempFileRetentionDays       = 7

            # Number of days to retain cached packages
            CacheRetentionDays          = 30
            #endregion

            #region Certificate Configuration
            # Code signing certificate configuration
            # Set to $null if not using code signing
            CodeSigningCertificate      = $null
            # Example configuration:
            # CodeSigningCertificate = @{
            #     Thumbprint = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
            #     Path       = 'C:\Certificates\codesigning.pfx'
            #     Credential = (Get-Credential)  # Provided at runtime
            # }

            # Root CA certificates to trust
            # Set to $null or empty array if not needed
            RootCACertificates          = @()
            # Example configuration:
            # RootCACertificates = @(
            #     @{
            #         Name       = 'EnterpriseRootCA'
            #         Thumbprint = 'YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY'
            #         Path       = 'C:\Certificates\enterprise-root-ca.cer'
            #     }
            # )
            #endregion

            #region PSDscAllowPlainTextPassword
            # IMPORTANT: In production, use certificates for credential encryption
            # This should be $false in production environments
            PSDscAllowPlainTextPassword = $false
            PSDscAllowDomainUser        = $true
            #endregion
        },

        #region Individual Node Configurations
        # Example: Development Build Agent
        @{
            NodeName                    = 'BUILD-DEV-01'
            Role                        = 'BuildAgent'

            # Override defaults for dev environment
            EnableDocker                = $true
            AutoUpgradePackages         = $true  # Allow updates in dev
            TempFileRetentionDays       = 3      # Shorter retention in dev
        },

        # Example: Production Build Agent Pool
        @{
            NodeName                    = 'BUILD-PROD-01'
            Role                        = 'BuildAgent'

            # Production-specific settings
            EnableDocker                = $true
            AutoUpgradePackages         = $false  # Strict version control
            TempFileRetentionDays       = 14      # Longer retention for debugging
            CacheRetentionDays          = 60      # Keep caches longer
        },

        @{
            NodeName                    = 'BUILD-PROD-02'
            Role                        = 'BuildAgent'

            # Match BUILD-PROD-01 configuration
            EnableDocker                = $true
            AutoUpgradePackages         = $false
            TempFileRetentionDays       = 14
            CacheRetentionDays          = 60
        }
        #endregion
    )

    #region Non-Node Data
    # Global settings not specific to any node

    # Build pool definitions
    BuildPools = @{
        Development = @{
            Nodes       = @('BUILD-DEV-01')
            Description = 'Development and testing builds'
            Priority    = 'Low'
        }
        Production  = @{
            Nodes       = @('BUILD-PROD-01', 'BUILD-PROD-02')
            Description = 'Production release builds'
            Priority    = 'High'
        }
    }

    # Common paths used across configuration
    CommonPaths = @{
        ChocolateyInstall = 'C:\ProgramData\chocolatey'
        ProgramFiles      = 'C:\Program Files'
        ProgramFilesX86   = 'C:\Program Files (x86)'
        WindowsTemp       = 'C:\Windows\Temp'
    }

    # Required DSC modules and versions
    RequiredModules = @{
        'ComputerManagementDsc' = '8.5.0'
        'cChoco'                = '2.5.0'
        'CertificateDsc'        = '5.1.0'
        'SecurityPolicyDsc'     = '2.10.0'
    }

    # Environment-specific settings
    Environments = @{
        Development = @{
            Prefix            = 'DEV'
            AllowAutoUpgrade  = $true
            RetentionDays     = 3
        }
        Staging     = @{
            Prefix            = 'STG'
            AllowAutoUpgrade  = $false
            RetentionDays     = 7
        }
        Production  = @{
            Prefix            = 'PROD'
            AllowAutoUpgrade  = $false
            RetentionDays     = 14
        }
    }
    #endregion
}
