<#
.SYNOPSIS
    PowerShell DSC Configuration for Hyperion Fleet Manager Build Agents.

.DESCRIPTION
    This DSC configuration creates a clean, reproducible build environment for
    Windows-based build agents in the Hyperion Fleet Manager infrastructure.

    The configuration includes:
    - Base OS configuration and security hardening
    - Build tools installation (Visual Studio Build Tools, .NET SDK)
    - Development tools (Git, Node.js, Python, Docker)
    - Build agent service account configuration
    - Build directories and workspace setup
    - Environment variables for build tools
    - Disk cleanup and maintenance scheduled tasks
    - Certificate installation for code signing

.PARAMETER ConfigurationData
    Configuration data hashtable containing node-specific settings.

.PARAMETER OutputPath
    Path where the compiled MOF files will be stored.

.EXAMPLE
    # Compile the configuration
    $configData = Import-PowerShellDataFile -Path '.\ConfigurationData\BuildAgent.psd1'
    BuildAgentConfiguration -ConfigurationData $configData -OutputPath '.\Output'

.EXAMPLE
    # Apply configuration to local machine
    Start-DscConfiguration -Path '.\Output' -Wait -Verbose -Force

.NOTES
    Project:     Hyperion Fleet Manager
    Module:      DSC Build Agent Configuration
    Version:     1.0.0
    Author:      Hyperion Fleet Team
    Requires:    PowerShell 5.1+, DSC Resources (ComputerManagementDsc, cChoco)

    Required DSC Resources:
    - ComputerManagementDsc (>= 8.5.0)
    - cChoco (>= 2.5.0)
    - CertificateDsc (>= 5.1.0)
    - SecurityPolicyDsc (>= 2.10.0)

.LINK
    https://github.com/jconover/hyperion-fleet-manager/tree/main/docs/dsc
#>

#Requires -Version 5.1

# Import required DSC resources
Configuration BuildAgentConfiguration {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CertificateThumbprint
    )

    # Import DSC Resources
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'ComputerManagementDsc' -ModuleVersion '8.5.0'
    Import-DscResource -ModuleName 'cChoco' -ModuleVersion '2.5.0'
    Import-DscResource -ModuleName 'CertificateDsc' -ModuleVersion '5.1.0'

    #region Helper Functions
    # Node configuration block
    Node $AllNodes.Where({ $_.Role -eq 'BuildAgent' }).NodeName {

        #region Local Configuration Manager
        LocalConfigurationManager {
            ConfigurationMode              = 'ApplyAndAutoCorrect'
            ConfigurationModeFrequencyMins = 30
            RebootNodeIfNeeded             = $true
            RefreshMode                    = 'Push'
            ActionAfterReboot              = 'ContinueConfiguration'
            AllowModuleOverwrite           = $true
        }
        #endregion

        #region Windows Features
        # Enable required Windows features for build agents
        WindowsFeature 'NetFramework45' {
            Name   = 'NET-Framework-45-Core'
            Ensure = 'Present'
        }

        WindowsFeature 'NetFramework45Features' {
            Name      = 'NET-Framework-45-Features'
            Ensure    = 'Present'
            DependsOn = '[WindowsFeature]NetFramework45'
        }

        WindowsFeature 'ContainersFeature' {
            Name   = 'Containers'
            Ensure = if ($Node.EnableDocker) { 'Present' } else { 'Absent' }
        }

        WindowsFeature 'HyperVFeature' {
            Name   = 'Hyper-V'
            Ensure = if ($Node.EnableDocker -and $Node.EnableHyperV) { 'Present' } else { 'Absent' }
        }

        WindowsFeature 'HyperVManagementTools' {
            Name      = 'Hyper-V-Tools'
            Ensure    = if ($Node.EnableDocker -and $Node.EnableHyperV) { 'Present' } else { 'Absent' }
            DependsOn = '[WindowsFeature]HyperVFeature'
        }
        #endregion

        #region Build Directories
        # Create main build agent directory
        File 'BuildAgentDirectory' {
            DestinationPath = $Node.BuildAgentPath
            Type            = 'Directory'
            Ensure          = 'Present'
        }

        # Create workspace directory
        File 'WorkspaceDirectory' {
            DestinationPath = $Node.WorkspacePath
            Type            = 'Directory'
            Ensure          = 'Present'
        }

        # Create build cache directories
        File 'NuGetCacheDirectory' {
            DestinationPath = $Node.NuGetCachePath
            Type            = 'Directory'
            Ensure          = 'Present'
        }

        File 'NpmCacheDirectory' {
            DestinationPath = $Node.NpmCachePath
            Type            = 'Directory'
            Ensure          = 'Present'
        }

        File 'PipCacheDirectory' {
            DestinationPath = $Node.PipCachePath
            Type            = 'Directory'
            Ensure          = 'Present'
        }

        File 'TerraformPluginCacheDirectory' {
            DestinationPath = $Node.TerraformPluginCachePath
            Type            = 'Directory'
            Ensure          = 'Present'
        }

        # Create logs directory
        File 'BuildLogsDirectory' {
            DestinationPath = Join-Path -Path $Node.BuildAgentPath -ChildPath 'Logs'
            Type            = 'Directory'
            Ensure          = 'Present'
            DependsOn       = '[File]BuildAgentDirectory'
        }

        # Create tools directory for custom scripts
        File 'BuildToolsDirectory' {
            DestinationPath = Join-Path -Path $Node.BuildAgentPath -ChildPath 'Tools'
            Type            = 'Directory'
            Ensure          = 'Present'
            DependsOn       = '[File]BuildAgentDirectory'
        }

        # Create temp directory for builds
        File 'BuildTempDirectory' {
            DestinationPath = $Node.BuildTempPath
            Type            = 'Directory'
            Ensure          = 'Present'
        }

        # Create artifacts directory
        File 'ArtifactsDirectory' {
            DestinationPath = Join-Path -Path $Node.WorkspacePath -ChildPath 'Artifacts'
            Type            = 'Directory'
            Ensure          = 'Present'
            DependsOn       = '[File]WorkspaceDirectory'
        }
        #endregion

        #region Chocolatey Installation
        # Install Chocolatey package manager
        cChocoInstaller 'InstallChocolatey' {
            InstallDir = 'C:\ProgramData\chocolatey'
        }

        # Configure Chocolatey settings
        cChocoConfig 'CacheLocation' {
            ConfigName = 'cacheLocation'
            Value      = 'C:\ProgramData\chocolatey\cache'
            DependsOn  = '[cChocoInstaller]InstallChocolatey'
        }

        cChocoConfig 'CommandExecutionTimeout' {
            ConfigName = 'commandExecutionTimeoutSeconds'
            Value      = '3600'
            DependsOn  = '[cChocoInstaller]InstallChocolatey'
        }

        # Enable Chocolatey features for better reliability
        cChocoFeature 'UsePackageExitCodes' {
            FeatureName = 'usePackageExitCodes'
            Ensure      = 'Present'
            DependsOn   = '[cChocoInstaller]InstallChocolatey'
        }

        cChocoFeature 'FailOnAutoUninstaller' {
            FeatureName = 'failOnAutoUninstaller'
            Ensure      = 'Present'
            DependsOn   = '[cChocoInstaller]InstallChocolatey'
        }
        #endregion

        #region Build Tools Installation via Chocolatey
        # Git for Windows
        cChocoPackageInstaller 'Git' {
            Name        = 'git'
            Ensure      = 'Present'
            AutoUpgrade = $Node.AutoUpgradePackages
            DependsOn   = '[cChocoInstaller]InstallChocolatey'
        }

        # Node.js LTS
        cChocoPackageInstaller 'NodeJS' {
            Name        = 'nodejs-lts'
            Version     = $Node.NodeJSVersion
            Ensure      = 'Present'
            AutoUpgrade = $false
            DependsOn   = '[cChocoInstaller]InstallChocolatey'
        }

        # Python 3
        cChocoPackageInstaller 'Python3' {
            Name        = 'python3'
            Version     = $Node.PythonVersion
            Ensure      = 'Present'
            AutoUpgrade = $false
            DependsOn   = '[cChocoInstaller]InstallChocolatey'
        }

        # Visual Studio 2022 Build Tools
        cChocoPackageInstaller 'VSBuildTools' {
            Name                 = 'visualstudio2022buildtools'
            Version              = $Node.VSBuildToolsVersion
            Ensure               = 'Present'
            AutoUpgrade          = $false
            chocoParams          = '--add Microsoft.VisualStudio.Workload.AzureBuildTools --add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools --add Microsoft.VisualStudio.Workload.WebBuildTools --add Microsoft.VisualStudio.Workload.NetCoreBuildTools --passive --norestart'
            DependsOn            = '[cChocoInstaller]InstallChocolatey'
        }

        # .NET SDK
        cChocoPackageInstaller 'DotNetSDK' {
            Name        = 'dotnet-sdk'
            Version     = $Node.DotNetSDKVersion
            Ensure      = 'Present'
            AutoUpgrade = $false
            DependsOn   = '[cChocoInstaller]InstallChocolatey'
        }

        # AWS CLI v2
        cChocoPackageInstaller 'AWSCLI' {
            Name        = 'awscli'
            Ensure      = 'Present'
            AutoUpgrade = $Node.AutoUpgradePackages
            DependsOn   = '[cChocoInstaller]InstallChocolatey'
        }

        # Terraform
        cChocoPackageInstaller 'Terraform' {
            Name        = 'terraform'
            Version     = $Node.TerraformVersion
            Ensure      = 'Present'
            AutoUpgrade = $false
            DependsOn   = '[cChocoInstaller]InstallChocolatey'
        }

        # 7-Zip for archive handling
        cChocoPackageInstaller '7Zip' {
            Name        = '7zip'
            Ensure      = 'Present'
            AutoUpgrade = $Node.AutoUpgradePackages
            DependsOn   = '[cChocoInstaller]InstallChocolatey'
        }

        # PowerShell 7 (pwsh)
        cChocoPackageInstaller 'PowerShell7' {
            Name        = 'powershell-core'
            Ensure      = 'Present'
            AutoUpgrade = $Node.AutoUpgradePackages
            DependsOn   = '[cChocoInstaller]InstallChocolatey'
        }

        # Docker Desktop (optional based on configuration)
        if ($Node.EnableDocker) {
            cChocoPackageInstaller 'DockerDesktop' {
                Name        = 'docker-desktop'
                Ensure      = 'Present'
                AutoUpgrade = $false
                DependsOn   = @('[cChocoInstaller]InstallChocolatey', '[WindowsFeature]ContainersFeature')
            }
        }

        # Additional build utilities
        cChocoPackageInstaller 'NuGet' {
            Name        = 'nuget.commandline'
            Ensure      = 'Present'
            AutoUpgrade = $Node.AutoUpgradePackages
            DependsOn   = '[cChocoInstaller]InstallChocolatey'
        }

        cChocoPackageInstaller 'GitHubCLI' {
            Name        = 'gh'
            Ensure      = 'Present'
            AutoUpgrade = $Node.AutoUpgradePackages
            DependsOn   = '[cChocoInstaller]InstallChocolatey'
        }
        #endregion

        #region Environment Variables
        # Set build-related environment variables
        Environment 'BuildAgentHome' {
            Name   = 'BUILD_AGENT_HOME'
            Value  = $Node.BuildAgentPath
            Ensure = 'Present'
            Path   = $false
        }

        Environment 'WorkspacePath' {
            Name   = 'WORKSPACE'
            Value  = $Node.WorkspacePath
            Ensure = 'Present'
            Path   = $false
        }

        Environment 'NuGetPackagesPath' {
            Name   = 'NUGET_PACKAGES'
            Value  = $Node.NuGetCachePath
            Ensure = 'Present'
            Path   = $false
        }

        Environment 'NpmCachePath' {
            Name   = 'npm_config_cache'
            Value  = $Node.NpmCachePath
            Ensure = 'Present'
            Path   = $false
        }

        Environment 'PipCachePath' {
            Name   = 'PIP_CACHE_DIR'
            Value  = $Node.PipCachePath
            Ensure = 'Present'
            Path   = $false
        }

        Environment 'TerraformPluginCache' {
            Name   = 'TF_PLUGIN_CACHE_DIR'
            Value  = $Node.TerraformPluginCachePath
            Ensure = 'Present'
            Path   = $false
        }

        Environment 'TempPath' {
            Name   = 'TEMP'
            Value  = $Node.BuildTempPath
            Ensure = 'Present'
            Path   = $false
        }

        Environment 'TmpPath' {
            Name   = 'TMP'
            Value  = $Node.BuildTempPath
            Ensure = 'Present'
            Path   = $false
        }

        # Add build tools to PATH
        Environment 'ChocolateyBinPath' {
            Name   = 'Path'
            Value  = 'C:\ProgramData\chocolatey\bin'
            Ensure = 'Present'
            Path   = $true
        }

        Environment 'BuildToolsPath' {
            Name      = 'Path'
            Value     = Join-Path -Path $Node.BuildAgentPath -ChildPath 'Tools'
            Ensure    = 'Present'
            Path      = $true
            DependsOn = '[File]BuildToolsDirectory'
        }
        #endregion

        #region Service Account Configuration
        # Create local service account for build agent (if specified)
        if ($Node.CreateServiceAccount) {
            User 'BuildAgentServiceAccount' {
                UserName                 = $Node.ServiceAccountName
                Description              = 'Hyperion Fleet Manager Build Agent Service Account'
                Ensure                   = 'Present'
                PasswordChangeRequired   = $false
                PasswordNeverExpires     = $true
                PasswordChangeNotAllowed = $true
            }

            Group 'AddBuildAgentToAdministrators' {
                GroupName        = 'Administrators'
                MembersToInclude = @($Node.ServiceAccountName)
                Ensure           = 'Present'
                DependsOn        = '[User]BuildAgentServiceAccount'
            }
        }
        #endregion

        #region Scheduled Tasks for Maintenance
        # Disk cleanup scheduled task
        ScheduledTask 'DiskCleanupTask' {
            TaskName           = 'Hyperion-BuildAgent-DiskCleanup'
            TaskPath           = '\Hyperion\'
            ActionExecutable   = 'C:\Windows\System32\cleanmgr.exe'
            ActionArguments    = '/sagerun:1'
            ScheduleType       = 'Daily'
            StartTime          = '03:00:00'
            DaysInterval       = 1
            Enable             = $true
            ExecutionTimeLimit = '02:00:00'
            RunLevel           = 'Highest'
            Description        = 'Daily disk cleanup for build agent maintenance'
        }

        # Temporary files cleanup task
        ScheduledTask 'TempFilesCleanupTask' {
            TaskName           = 'Hyperion-BuildAgent-TempCleanup'
            TaskPath           = '\Hyperion\'
            ActionExecutable   = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
            ActionArguments    = @"
-NoProfile -ExecutionPolicy Bypass -Command "& {
    `$paths = @(
        '$($Node.BuildTempPath)',
        '$($Node.WorkspacePath)\Artifacts\*'
    )
    foreach (`$path in `$paths) {
        if (Test-Path `$path) {
            Get-ChildItem -Path `$path -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { `$_.LastWriteTime -lt (Get-Date).AddDays(-$($Node.TempFileRetentionDays)) } |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}"
"@
            ScheduleType       = 'Daily'
            StartTime          = '04:00:00'
            DaysInterval       = 1
            Enable             = $true
            ExecutionTimeLimit = '01:00:00'
            RunLevel           = 'Highest'
            Description        = 'Daily cleanup of temporary build files older than retention period'
        }

        # NuGet cache cleanup task (weekly)
        ScheduledTask 'NuGetCacheCleanupTask' {
            TaskName           = 'Hyperion-BuildAgent-NuGetCacheCleanup'
            TaskPath           = '\Hyperion\'
            ActionExecutable   = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
            ActionArguments    = @"
-NoProfile -ExecutionPolicy Bypass -Command "& {
    `$nugetPath = '$($Node.NuGetCachePath)'
    if (Test-Path `$nugetPath) {
        Get-ChildItem -Path `$nugetPath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { `$_.LastWriteTime -lt (Get-Date).AddDays(-$($Node.CacheRetentionDays)) } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}"
"@
            ScheduleType       = 'Weekly'
            StartTime          = '05:00:00'
            DaysOfWeek         = 'Sunday'
            Enable             = $true
            ExecutionTimeLimit = '02:00:00'
            RunLevel           = 'Highest'
            Description        = 'Weekly cleanup of NuGet package cache'
        }

        # npm cache cleanup task (weekly)
        ScheduledTask 'NpmCacheCleanupTask' {
            TaskName           = 'Hyperion-BuildAgent-NpmCacheCleanup'
            TaskPath           = '\Hyperion\'
            ActionExecutable   = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
            ActionArguments    = @"
-NoProfile -ExecutionPolicy Bypass -Command "& {
    `$npmPath = '$($Node.NpmCachePath)'
    if (Test-Path `$npmPath) {
        Get-ChildItem -Path `$npmPath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { `$_.LastWriteTime -lt (Get-Date).AddDays(-$($Node.CacheRetentionDays)) } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}"
"@
            ScheduleType       = 'Weekly'
            StartTime          = '05:30:00'
            DaysOfWeek         = 'Sunday'
            Enable             = $true
            ExecutionTimeLimit = '02:00:00'
            RunLevel           = 'Highest'
            Description        = 'Weekly cleanup of npm cache'
        }
        #endregion

        #region Git Configuration
        # Configure Git system-wide settings
        Script 'GitGlobalConfig' {
            GetScript  = {
                $gitConfig = git config --system --list 2>$null
                return @{ Result = $gitConfig }
            }
            SetScript  = {
                # Core settings
                git config --system core.autocrlf true
                git config --system core.longpaths true
                git config --system core.symlinks false

                # Performance settings
                git config --system core.preloadindex true
                git config --system core.fscache true

                # Credential settings
                git config --system credential.helper manager

                # HTTP settings for large repos
                git config --system http.postBuffer 524288000
                git config --system http.version HTTP/1.1

                # Diff and merge settings
                git config --system diff.algorithm histogram
                git config --system merge.conflictstyle diff3
            }
            TestScript = {
                $longPaths = git config --system --get core.longpaths 2>$null
                return ($longPaths -eq 'true')
            }
            DependsOn  = '[cChocoPackageInstaller]Git'
        }
        #endregion

        #region Certificate Installation for Code Signing
        if ($Node.CodeSigningCertificate) {
            # Import code signing certificate from PFX file or certificate store
            PfxImport 'CodeSigningCertificate' {
                Thumbprint = $Node.CodeSigningCertificate.Thumbprint
                Path       = $Node.CodeSigningCertificate.Path
                Location   = 'LocalMachine'
                Store      = 'My'
                Credential = $Node.CodeSigningCertificate.Credential
                Ensure     = 'Present'
            }
        }

        # Install root CA certificates if specified
        if ($Node.RootCACertificates) {
            foreach ($cert in $Node.RootCACertificates) {
                CertificateImport "RootCA_$($cert.Name)" {
                    Thumbprint = $cert.Thumbprint
                    Path       = $cert.Path
                    Location   = 'LocalMachine'
                    Store      = 'Root'
                    Ensure     = 'Present'
                }
            }
        }
        #endregion

        #region PowerShell Configuration
        # Configure PowerShell execution policy
        Script 'PowerShellExecutionPolicy' {
            GetScript  = {
                $policy = Get-ExecutionPolicy -Scope LocalMachine
                return @{ Result = $policy }
            }
            SetScript  = {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
            }
            TestScript = {
                $policy = Get-ExecutionPolicy -Scope LocalMachine
                return ($policy -eq 'RemoteSigned')
            }
        }

        # Install essential PowerShell modules
        Script 'InstallPSModules' {
            GetScript  = {
                $modules = Get-Module -ListAvailable | Select-Object Name, Version
                return @{ Result = $modules }
            }
            SetScript  = {
                $modulesToInstall = @(
                    'Pester',
                    'PSScriptAnalyzer',
                    'Az',
                    'AWS.Tools.Common',
                    'AWS.Tools.EC2',
                    'AWS.Tools.S3',
                    'AWS.Tools.SSM'
                )

                foreach ($module in $modulesToInstall) {
                    if (-not (Get-Module -ListAvailable -Name $module)) {
                        Install-Module -Name $module -Force -AllowClobber -Scope AllUsers -SkipPublisherCheck
                    }
                }
            }
            TestScript = {
                $requiredModules = @('Pester', 'PSScriptAnalyzer')
                $installed = $true
                foreach ($module in $requiredModules) {
                    if (-not (Get-Module -ListAvailable -Name $module)) {
                        $installed = $false
                        break
                    }
                }
                return $installed
            }
            DependsOn  = '[cChocoPackageInstaller]PowerShell7'
        }
        #endregion

        #region Windows Services Configuration
        # Ensure Windows Update service is running for security patches
        Service 'WindowsUpdateService' {
            Name        = 'wuauserv'
            StartupType = 'Manual'
            State       = 'Running'
        }

        # Ensure Windows Time service is running for consistent timestamps
        Service 'WindowsTimeService' {
            Name        = 'W32Time'
            StartupType = 'Automatic'
            State       = 'Running'
        }
        #endregion

        #region Registry Settings for Build Optimization
        # Enable long path support in Windows
        Registry 'LongPathsEnabled' {
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
            ValueName = 'LongPathsEnabled'
            ValueData = '1'
            ValueType = 'Dword'
            Ensure    = 'Present'
        }

        # Increase system handle limit for large builds
        Registry 'SessionPoolSize' {
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
            ValueName = 'SessionPoolSize'
            ValueData = '48'
            ValueType = 'Dword'
            Ensure    = 'Present'
        }

        # Disable Windows Search for build performance
        Registry 'DisableWindowsSearch' {
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
            ValueName = 'AllowCortana'
            ValueData = '0'
            ValueType = 'Dword'
            Ensure    = 'Present'
        }
        #endregion

        #region Firewall Rules
        # Allow Git over HTTPS
        Script 'GitFirewallRule' {
            GetScript  = {
                $rule = Get-NetFirewallRule -DisplayName 'Git HTTPS' -ErrorAction SilentlyContinue
                return @{ Result = ($null -ne $rule) }
            }
            SetScript  = {
                New-NetFirewallRule -DisplayName 'Git HTTPS' -Direction Outbound -Protocol TCP -RemotePort 443 -Action Allow -Profile Any
            }
            TestScript = {
                $rule = Get-NetFirewallRule -DisplayName 'Git HTTPS' -ErrorAction SilentlyContinue
                return ($null -ne $rule)
            }
        }

        # Allow NuGet package downloads
        Script 'NuGetFirewallRule' {
            GetScript  = {
                $rule = Get-NetFirewallRule -DisplayName 'NuGet HTTPS' -ErrorAction SilentlyContinue
                return @{ Result = ($null -ne $rule) }
            }
            SetScript  = {
                New-NetFirewallRule -DisplayName 'NuGet HTTPS' -Direction Outbound -Protocol TCP -RemotePort 443 -Action Allow -Profile Any
            }
            TestScript = {
                $rule = Get-NetFirewallRule -DisplayName 'NuGet HTTPS' -ErrorAction SilentlyContinue
                return ($null -ne $rule)
            }
        }
        #endregion

        #region Disk Cleanup Configuration
        # Configure disk cleanup settings
        Registry 'DiskCleanupSageSet' {
            Key       = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Files'
            ValueName = 'StateFlags0001'
            ValueData = '2'
            ValueType = 'Dword'
            Ensure    = 'Present'
        }

        Registry 'DiskCleanupDownloads' {
            Key       = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Downloaded Program Files'
            ValueName = 'StateFlags0001'
            ValueData = '2'
            ValueType = 'Dword'
            Ensure    = 'Present'
        }

        Registry 'DiskCleanupRecycleBin' {
            Key       = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Recycle Bin'
            ValueName = 'StateFlags0001'
            ValueData = '2'
            ValueType = 'Dword'
            Ensure    = 'Present'
        }

        Registry 'DiskCleanupWindowsUpdate' {
            Key       = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Update Cleanup'
            ValueName = 'StateFlags0001'
            ValueData = '2'
            ValueType = 'Dword'
            Ensure    = 'Present'
        }
        #endregion
    }
}

# Export the configuration
Export-ModuleMember -Function BuildAgentConfiguration
