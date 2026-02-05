<#
.SYNOPSIS
    Required DSC Modules for Hyperion Fleet Manager Baseline Configuration

.DESCRIPTION
    This manifest defines all DSC modules required to compile and apply the
    HyperionBaselineConfiguration. Install these modules on:
    - The authoring workstation (where you compile the configuration)
    - The target nodes (where the configuration will be applied)
    - The DSC pull server (if using pull mode)

    Use the Install-RequiredDscModules function below to install all modules.

.NOTES
    Project: Hyperion Fleet Manager
    Version: 1.0.0
    Author: Infrastructure Team

.EXAMPLE
    # Import this file and install modules
    $modules = Import-PowerShellDataFile -Path '.\Modules\RequiredModules.psd1'
    foreach ($module in $modules.RequiredModules) {
        Install-Module -Name $module.ModuleName -RequiredVersion $module.ModuleVersion -Force
    }

.LINK
    https://www.powershellgallery.com/
#>

@{
    #region Module Manifest Metadata
    # Manifest version for tracking updates
    ManifestVersion     = '1.0.0'

    # Last updated date
    LastUpdated         = '2024-12-15'

    # Minimum PowerShell version required
    PowerShellVersion   = '7.0'

    # Compatible PowerShell editions
    CompatiblePSEditions = @('Core', 'Desktop')
    #endregion

    #region Required DSC Modules
    # List of all DSC modules required for the baseline configuration
    # Each module includes version pinning for reproducibility

    RequiredModules = @(
        #region Core DSC Module
        @{
            ModuleName      = 'PSDesiredStateConfiguration'
            # Note: Version varies by PowerShell version
            # PowerShell 7.x includes PSDesiredStateConfiguration 2.x
            # Use the version appropriate for your environment
            ModuleVersion   = '2.0.7'
            Description     = 'Core DSC module providing fundamental DSC resources'
            Repository      = 'PSGallery'
            Required        = $true
            Notes           = @'
The core DSC module is included with PowerShell but may need updating.
For PowerShell 7+, ensure you have version 2.0.5 or later.
This module provides: Registry, Service, User, Group, and other built-in resources.
'@
        }
        #endregion

        #region SecurityPolicyDsc
        @{
            ModuleName      = 'SecurityPolicyDsc'
            ModuleVersion   = '2.10.0'
            Description     = 'DSC resources for managing local security policies'
            Repository      = 'PSGallery'
            Required        = $true
            Resources       = @(
                'AccountPolicy'         # Password and account lockout policies
                'SecurityOption'        # Local security options
                'SecurityTemplate'      # Security template application
                'UserRightsAssignment'  # User rights assignments
            )
            Notes           = @'
SecurityPolicyDsc provides resources to configure:
- Password policies (length, complexity, history, age)
- Account lockout policies (threshold, duration, reset counter)
- Security options (interactive logon, network security, UAC)
- User rights assignments (access rights, logon rights, privileges)

CIS Benchmark sections covered:
- Section 1.1: Password Policy
- Section 1.2: Account Lockout Policy
- Section 2.2: User Rights Assignment
- Section 2.3: Security Options
'@
            InstallCommand  = 'Install-Module -Name SecurityPolicyDsc -RequiredVersion 2.10.0 -Force -AllowClobber'
        }
        #endregion

        #region AuditPolicyDsc
        @{
            ModuleName      = 'AuditPolicyDsc'
            ModuleVersion   = '1.4.0'
            Description     = 'DSC resources for managing Windows audit policies'
            Repository      = 'PSGallery'
            Required        = $true
            Resources       = @(
                'AuditPolicySubcategory'    # Configure audit subcategories
                'AuditPolicyOption'         # Configure audit options
                'AuditPolicyGUID'           # Configure by GUID
            )
            Notes           = @'
AuditPolicyDsc provides resources to configure Windows Advanced Audit Policy.
This replaces the legacy audit policy settings with granular subcategory control.

CIS Benchmark sections covered:
- Section 17.1: Account Logon
- Section 17.2: Account Management
- Section 17.3: Detailed Tracking
- Section 17.4: DS Access
- Section 17.5: Logon/Logoff
- Section 17.6: Object Access
- Section 17.7: Policy Change
- Section 17.8: Privilege Use
- Section 17.9: System

Audit subcategories include:
- Credential Validation
- Kerberos Authentication Service
- Security Group Management
- User Account Management
- Process Creation
- Logon/Logoff events
- And many more...
'@
            InstallCommand  = 'Install-Module -Name AuditPolicyDsc -RequiredVersion 1.4.0 -Force -AllowClobber'
        }
        #endregion

        #region ComputerManagementDsc
        @{
            ModuleName      = 'ComputerManagementDsc'
            ModuleVersion   = '8.5.0'
            Description     = 'DSC resources for computer management tasks'
            Repository      = 'PSGallery'
            Required        = $true
            Resources       = @(
                'Computer'              # Computer name and domain join
                'OfflineDomainJoin'     # Offline domain join
                'PendingReboot'         # Pending reboot detection
                'PowerPlan'             # Power plan configuration
                'PowerShellExecutionPolicy'  # Execution policy
                'RemoteDesktopAdmin'    # Remote Desktop settings
                'ScheduledTask'         # Scheduled task management
                'SmbServerConfiguration' # SMB server settings
                'SmbShare'              # SMB share management
                'SystemLocale'          # System locale settings
                'TimeZone'              # Time zone configuration
                'VirtualMemory'         # Virtual memory settings
                'WindowsCapability'     # Windows capability management
                'WindowsEventLog'       # Event log configuration
            )
            Notes           = @'
ComputerManagementDsc provides general computer management resources.

Key resources used in baseline:
- WindowsEventLog: Configure event log sizes and retention
- ScheduledTask: Create maintenance tasks
- TimeZone: Ensure consistent time zone
- PendingReboot: Check for required reboots
- SmbServerConfiguration: Harden SMB settings

CIS Benchmark sections covered:
- Section 18.9.27: Event Log Service
- Section 18.8.5: Windows Time Service
'@
            InstallCommand  = 'Install-Module -Name ComputerManagementDsc -RequiredVersion 8.5.0 -Force -AllowClobber'
        }
        #endregion

        #region NetworkingDsc
        @{
            ModuleName      = 'NetworkingDsc'
            ModuleVersion   = '9.0.0'
            Description     = 'DSC resources for network configuration'
            Repository      = 'PSGallery'
            Required        = $true
            Resources       = @(
                'DefaultGatewayAddress'   # Default gateway configuration
                'DnsClientGlobalSetting'  # DNS client global settings
                'DnsConnectionSuffix'     # DNS suffix configuration
                'DnsServerAddress'        # DNS server addresses
                'Firewall'                # Windows Firewall rules
                'FirewallProfile'         # Firewall profile settings
                'HostsFile'               # Hosts file management
                'IPAddress'               # IP address configuration
                'IPAddressOption'         # IP address options
                'NetAdapterAdvancedProperty'  # NIC advanced properties
                'NetAdapterBinding'       # NIC binding configuration
                'NetAdapterLso'           # Large Send Offload
                'NetAdapterName'          # NIC naming
                'NetAdapterRdma'          # RDMA configuration
                'NetAdapterRsc'           # Receive Segment Coalescing
                'NetAdapterRss'           # Receive Side Scaling
                'NetBios'                 # NetBIOS settings
                'NetConnectionProfile'    # Network connection profile
                'NetIPInterface'          # IP interface settings
                'NetworkTeam'             # NIC teaming
                'NetworkTeamInterface'    # Team interface
                'ProxySettings'           # Proxy configuration
                'Route'                   # Static routes
                'WinsSetting'             # WINS settings
            )
            Notes           = @'
NetworkingDsc provides comprehensive network configuration resources.

Key resources used in baseline:
- Firewall: Create/manage firewall rules
- FirewallProfile: Configure firewall profiles
- NetBios: Disable NetBIOS over TCP/IP
- DnsClientGlobalSetting: Configure DNS client

CIS Benchmark sections covered:
- Section 9: Windows Firewall
- Section 18.6: Networking
'@
            InstallCommand  = 'Install-Module -Name NetworkingDsc -RequiredVersion 9.0.0 -Force -AllowClobber'
        }
        #endregion

        #region Optional/Recommended Modules
        # These modules are not strictly required but provide additional capabilities

        @{
            ModuleName      = 'xPSDesiredStateConfiguration'
            ModuleVersion   = '9.1.0'
            Description     = 'Extended DSC resources (community)'
            Repository      = 'PSGallery'
            Required        = $false
            Resources       = @(
                'xArchive'              # Archive extraction
                'xDSCWebService'        # DSC pull server
                'xEnvironment'          # Environment variables
                'xGroup'                # Local groups (extended)
                'xPackage'              # Package installation
                'xRemoteFile'           # File download
                'xScript'               # Custom scripts
                'xService'              # Service configuration (extended)
                'xUser'                 # Local users (extended)
                'xWindowsFeature'       # Windows features
                'xWindowsOptionalFeature'  # Optional features
                'xWindowsProcess'       # Process management
            )
            Notes           = @'
xPSDesiredStateConfiguration provides extended resources beyond the built-in module.
Useful for additional configuration scenarios but not required for baseline.
'@
            InstallCommand  = 'Install-Module -Name xPSDesiredStateConfiguration -RequiredVersion 9.1.0 -Force -AllowClobber'
        }

        @{
            ModuleName      = 'ActiveDirectoryDsc'
            ModuleVersion   = '6.3.0'
            Description     = 'DSC resources for Active Directory'
            Repository      = 'PSGallery'
            Required        = $false
            Resources       = @(
                'ADDomain'              # AD Domain creation
                'ADDomainController'    # DC promotion
                'ADGroup'               # AD groups
                'ADUser'                # AD users
                'ADOrganizationalUnit'  # OUs
                'ADReplicationSite'     # Replication sites
                # And many more...
            )
            Notes           = @'
ActiveDirectoryDsc is required only for Domain Controller configuration.
Not needed for member servers unless managing AD objects.
'@
            InstallCommand  = 'Install-Module -Name ActiveDirectoryDsc -RequiredVersion 6.3.0 -Force -AllowClobber'
        }

        @{
            ModuleName      = 'CertificateDsc'
            ModuleVersion   = '5.1.0'
            Description     = 'DSC resources for certificate management'
            Repository      = 'PSGallery'
            Required        = $false
            Resources       = @(
                'CertificateExport'     # Export certificates
                'CertificateImport'     # Import certificates
                'CertReq'               # Certificate requests
                'PfxImport'             # PFX import
                'WaitForCertificateServices'  # Wait for CA
            )
            Notes           = @'
CertificateDsc is useful for managing certificates on target nodes.
Can be used to import DSC encryption certificates automatically.
'@
            InstallCommand  = 'Install-Module -Name CertificateDsc -RequiredVersion 5.1.0 -Force -AllowClobber'
        }

        @{
            ModuleName      = 'StorageDsc'
            ModuleVersion   = '5.1.0'
            Description     = 'DSC resources for storage configuration'
            Repository      = 'PSGallery'
            Required        = $false
            Resources       = @(
                'Disk'                  # Disk management
                'DiskAccessPath'        # Mount points
                'MountImage'            # ISO/VHD mounting
                'OpticalDiskDriveLetter'  # CD/DVD drive letters
                'WaitForDisk'           # Wait for disk availability
                'WaitForVolume'         # Wait for volume
            )
            Notes           = @'
StorageDsc is useful for disk and volume configuration.
Helpful for data disk configuration in cloud environments.
'@
            InstallCommand  = 'Install-Module -Name StorageDsc -RequiredVersion 5.1.0 -Force -AllowClobber'
        }
        #endregion
    )
    #endregion

    #region Helper Functions
    # PowerShell code to install modules - can be dot-sourced

    InstallScript = @'
function Install-RequiredDscModules {
    <#
    .SYNOPSIS
        Installs all required DSC modules for Hyperion Fleet Manager.

    .DESCRIPTION
        Reads the RequiredModules.psd1 manifest and installs all required
        DSC modules from the PowerShell Gallery.

    .PARAMETER ModuleManifestPath
        Path to the RequiredModules.psd1 file.

    .PARAMETER RequiredOnly
        If specified, only installs modules marked as Required = $true.

    .PARAMETER Force
        Force installation even if module is already installed.

    .EXAMPLE
        Install-RequiredDscModules -ModuleManifestPath '.\Modules\RequiredModules.psd1'

    .EXAMPLE
        Install-RequiredDscModules -RequiredOnly -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()]
        [string]$ModuleManifestPath = '.\Modules\RequiredModules.psd1',

        [Parameter()]
        [switch]$RequiredOnly,

        [Parameter()]
        [switch]$Force
    )

    begin {
        # Ensure running as administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )

        if (-not $isAdmin) {
            throw 'This function must be run as Administrator to install modules for all users.'
        }

        # Import the manifest
        if (-not (Test-Path -Path $ModuleManifestPath)) {
            throw "Module manifest not found at: $ModuleManifestPath"
        }

        $manifest = Import-PowerShellDataFile -Path $ModuleManifestPath
    }

    process {
        foreach ($module in $manifest.RequiredModules) {
            # Skip optional modules if RequiredOnly is specified
            if ($RequiredOnly -and -not $module.Required) {
                Write-Verbose "Skipping optional module: $($module.ModuleName)"
                continue
            }

            $moduleName = $module.ModuleName
            $moduleVersion = $module.ModuleVersion

            Write-Host "Processing module: $moduleName v$moduleVersion" -ForegroundColor Cyan

            # Check if already installed
            $installed = Get-Module -ListAvailable -Name $moduleName |
                         Where-Object { $_.Version -eq $moduleVersion }

            if ($installed -and -not $Force) {
                Write-Host "  Module already installed." -ForegroundColor Green
                continue
            }

            # Install the module
            if ($PSCmdlet.ShouldProcess($moduleName, 'Install DSC Module')) {
                try {
                    $installParams = @{
                        Name            = $moduleName
                        RequiredVersion = $moduleVersion
                        Force           = $true
                        AllowClobber    = $true
                        Scope           = 'AllUsers'
                        ErrorAction     = 'Stop'
                    }

                    Install-Module @installParams
                    Write-Host "  Successfully installed $moduleName v$moduleVersion" -ForegroundColor Green
                }
                catch {
                    Write-Warning "  Failed to install $moduleName : $_"
                }
            }
        }
    }

    end {
        Write-Host "`nModule installation complete." -ForegroundColor Cyan
        Write-Host "Run 'Get-DscResource' to verify available DSC resources." -ForegroundColor Yellow
    }
}
'@
    #endregion

    #region Verification Commands
    # Commands to verify module installation

    VerificationCommands = @{
        # Check installed modules
        CheckModules     = 'Get-Module -ListAvailable -Name SecurityPolicyDsc, AuditPolicyDsc, ComputerManagementDsc, NetworkingDsc | Select-Object Name, Version'

        # List all DSC resources
        ListResources    = 'Get-DscResource | Sort-Object Module, Name | Select-Object Name, Module, Version'

        # Check specific resources
        CheckResources   = @'
$requiredResources = @(
    'Registry',
    'Service',
    'User',
    'AccountPolicy',
    'SecurityOption',
    'UserRightsAssignment',
    'AuditPolicySubcategory',
    'Firewall',
    'FirewallProfile'
)
foreach ($resource in $requiredResources) {
    $r = Get-DscResource -Name $resource -ErrorAction SilentlyContinue
    if ($r) {
        Write-Host "$resource - Available ($($r.ModuleName) v$($r.Version))" -ForegroundColor Green
    } else {
        Write-Host "$resource - NOT FOUND" -ForegroundColor Red
    }
}
'@
    }
    #endregion
}
