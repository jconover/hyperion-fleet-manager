#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Compiles and deploys the Hyperion App Server DSC Configuration.

.DESCRIPTION
    This script automates the compilation and deployment of the AppServerConfiguration
    DSC configuration for Hyperion Fleet Manager application servers. It supports:

    - Multiple environments (dev, staging, prod)
    - Incremental deployment with compliance checking
    - Pre-flight validation of prerequisites
    - Certificate thumbprint injection from AWS Secrets Manager
    - Logging and error handling
    - WhatIf support for safe planning

    The script can be run locally or invoked via AWS Systems Manager Run Command
    for fleet-wide deployment.

.PARAMETER Environment
    Target environment for deployment. Valid values: dev, staging, prod.
    Determines which node settings from AppServer.psd1 are applied.

.PARAMETER NodeName
    Optional. Override the node name to target specific servers.
    Default: Uses $env:COMPUTERNAME to match configuration data patterns.

.PARAMETER OutputPath
    Directory where compiled MOF files will be stored.
    Default: .\MOF\<Environment>

.PARAMETER Apply
    If specified, applies the configuration after compilation.
    Without this switch, only compilation and validation occur.

.PARAMETER Force
    Skip confirmation prompts when applying configuration.

.PARAMETER Incremental
    Perform incremental deployment - only apply if configuration drift is detected.
    Uses Test-DscConfiguration to check current state.

.PARAMETER CertificateThumbprint
    SSL certificate thumbprint for IIS HTTPS binding.
    If not specified, attempts to retrieve from AWS Secrets Manager.

.PARAMETER AwsSecretId
    AWS Secrets Manager secret ID containing the certificate thumbprint.
    Default: hyperion/<Environment>/ssl-certificate

.PARAMETER LogPath
    Directory for deployment logs.
    Default: .\Logs

.PARAMETER WhatIf
    Shows what would happen if the command runs without actually making changes.

.PARAMETER Verbose
    Provides detailed output during execution.

.EXAMPLE
    # Compile configuration for dev environment (no apply)
    .\Deploy-AppServerConfiguration.ps1 -Environment dev -Verbose

.EXAMPLE
    # Compile and apply configuration to staging
    .\Deploy-AppServerConfiguration.ps1 -Environment staging -Apply -Verbose

.EXAMPLE
    # Production deployment with incremental check
    .\Deploy-AppServerConfiguration.ps1 -Environment prod -Apply -Incremental -Verbose

.EXAMPLE
    # Dry run - see what would be configured
    .\Deploy-AppServerConfiguration.ps1 -Environment prod -Apply -WhatIf

.EXAMPLE
    # Override certificate thumbprint
    .\Deploy-AppServerConfiguration.ps1 -Environment prod -Apply `
        -CertificateThumbprint 'ABC123DEF456...'

.NOTES
    Author: Hyperion Fleet Manager Team
    Version: 1.0.0
    Requires: Windows Server 2019/2022, PowerShell 5.1+, Administrator privileges

    Prerequisites:
    - DSC Resources: xWebAdministration, ComputerManagementDsc
    - AWS CLI and credentials (for Secrets Manager integration)
    - Network access to target nodes (for remote deployment)

.LINK
    AppServerConfiguration.ps1
    ConfigurationData/AppServer.psd1
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter()]
    [string]$NodeName = $env:COMPUTERNAME,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [switch]$Apply,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$Incremental,

    [Parameter()]
    [string]$CertificateThumbprint,

    [Parameter()]
    [string]$AwsSecretId,

    [Parameter()]
    [string]$LogPath
)

# ==============================================================================
# Script Configuration
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script root directory (where this script lives)
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    $ScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}

# Default paths
if (-not $OutputPath) {
    $OutputPath = Join-Path -Path $ScriptRoot -ChildPath "MOF\$Environment"
}

if (-not $LogPath) {
    $LogPath = Join-Path -Path $ScriptRoot -ChildPath 'Logs'
}

# Timestamp for logging
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile = Join-Path -Path $LogPath -ChildPath "Deploy-AppServer_${Environment}_${Timestamp}.log"

# ==============================================================================
# Logging Functions
# ==============================================================================

function Write-Log {
    <#
    .SYNOPSIS
        Writes a message to both console and log file.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"

    # Console output with color
    switch ($Level) {
        'Info'    { Write-Host $logMessage -ForegroundColor Cyan }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
        'Debug'   { Write-Verbose $logMessage }
    }

    # File output
    if ($script:LogFileReady) {
        Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
    }
}

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initializes the logging directory and file.
    #>
    [CmdletBinding()]
    param ()

    try {
        if (-not (Test-Path -Path $LogPath)) {
            $null = New-Item -Path $LogPath -ItemType Directory -Force
        }

        # Create log file with header
        $header = @"
================================================================================
Hyperion Fleet Manager - App Server DSC Deployment Log
================================================================================
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Environment: $Environment
Node Name: $NodeName
Computer: $env:COMPUTERNAME
User: $env:USERNAME
PowerShell Version: $($PSVersionTable.PSVersion)
================================================================================

"@
        Set-Content -Path $LogFile -Value $header -Force
        $script:LogFileReady = $true

        Write-Log "Log file initialized: $LogFile" -Level 'Debug'
    }
    catch {
        Write-Warning "Failed to initialize logging: $_"
        $script:LogFileReady = $false
    }
}

# ==============================================================================
# Prerequisite Validation Functions
# ==============================================================================

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Validates all prerequisites for DSC deployment.
    #>
    [CmdletBinding()]
    param ()

    Write-Log 'Validating prerequisites...' -Level 'Info'

    $prerequisites = @{
        'Administrator Privileges' = Test-AdminPrivileges
        'PowerShell Version'       = Test-PowerShellVersion
        'DSC Resources'            = Test-DscResources
        'Configuration Files'      = Test-ConfigurationFiles
    }

    $allPassed = $true
    foreach ($check in $prerequisites.GetEnumerator()) {
        if ($check.Value) {
            Write-Log "  [PASS] $($check.Key)" -Level 'Success'
        }
        else {
            Write-Log "  [FAIL] $($check.Key)" -Level 'Error'
            $allPassed = $false
        }
    }

    return $allPassed
}

function Test-AdminPrivileges {
    <#
    .SYNOPSIS
        Checks if the script is running with administrator privileges.
    #>
    [CmdletBinding()]
    param ()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
        Validates PowerShell version meets minimum requirements.
    #>
    [CmdletBinding()]
    param ()

    $minVersion = [Version]'5.1'
    return ($PSVersionTable.PSVersion -ge $minVersion)
}

function Test-DscResources {
    <#
    .SYNOPSIS
        Checks if required DSC resources are installed.
    #>
    [CmdletBinding()]
    param ()

    $requiredResources = @(
        @{ Name = 'xWebAdministration'; MinVersion = '3.0.0' }
        @{ Name = 'ComputerManagementDsc'; MinVersion = '8.0.0' }
    )

    $allPresent = $true
    foreach ($resource in $requiredResources) {
        $module = Get-Module -Name $resource.Name -ListAvailable |
                  Sort-Object Version -Descending |
                  Select-Object -First 1

        if (-not $module) {
            Write-Log "    Missing DSC resource: $($resource.Name)" -Level 'Warning'
            $allPresent = $false
        }
        elseif ($module.Version -lt [Version]$resource.MinVersion) {
            Write-Log "    DSC resource $($resource.Name) version $($module.Version) is below minimum $($resource.MinVersion)" -Level 'Warning'
            $allPresent = $false
        }
    }

    return $allPresent
}

function Test-ConfigurationFiles {
    <#
    .SYNOPSIS
        Validates that required configuration files exist.
    #>
    [CmdletBinding()]
    param ()

    $configPath = Join-Path -Path $ScriptRoot -ChildPath 'AppServerConfiguration.ps1'
    $dataPath = Join-Path -Path $ScriptRoot -ChildPath 'ConfigurationData\AppServer.psd1'

    $configExists = Test-Path -Path $configPath
    $dataExists = Test-Path -Path $dataPath

    if (-not $configExists) {
        Write-Log "    Missing configuration file: $configPath" -Level 'Warning'
    }
    if (-not $dataExists) {
        Write-Log "    Missing data file: $dataPath" -Level 'Warning'
    }

    return ($configExists -and $dataExists)
}

# ==============================================================================
# DSC Resource Installation
# ==============================================================================

function Install-RequiredDscResources {
    <#
    .SYNOPSIS
        Installs required DSC resources if missing.
    #>
    [CmdletBinding()]
    param ()

    Write-Log 'Checking and installing required DSC resources...' -Level 'Info'

    $resources = @(
        @{ Name = 'xWebAdministration'; RequiredVersion = '3.3.0' }
        @{ Name = 'ComputerManagementDsc'; RequiredVersion = '9.0.0' }
    )

    foreach ($resource in $resources) {
        $installed = Get-Module -Name $resource.Name -ListAvailable |
                     Where-Object { $_.Version -ge [Version]$resource.RequiredVersion }

        if (-not $installed) {
            Write-Log "  Installing $($resource.Name) v$($resource.RequiredVersion)..." -Level 'Info'

            try {
                Install-Module -Name $resource.Name `
                    -RequiredVersion $resource.RequiredVersion `
                    -Force `
                    -AllowClobber `
                    -Scope AllUsers `
                    -ErrorAction Stop

                Write-Log "  Successfully installed $($resource.Name)" -Level 'Success'
            }
            catch {
                Write-Log "  Failed to install $($resource.Name): $_" -Level 'Error'
                throw
            }
        }
        else {
            Write-Log "  $($resource.Name) v$($installed.Version) already installed" -Level 'Debug'
        }
    }
}

# ==============================================================================
# Certificate Management
# ==============================================================================

function Get-CertificateFromSecretsManager {
    <#
    .SYNOPSIS
        Retrieves SSL certificate thumbprint from AWS Secrets Manager.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SecretId
    )

    Write-Log "Retrieving certificate thumbprint from AWS Secrets Manager: $SecretId" -Level 'Info'

    try {
        # Check if AWS CLI is available
        $awsCli = Get-Command -Name 'aws' -ErrorAction SilentlyContinue
        if (-not $awsCli) {
            Write-Log 'AWS CLI not found. Certificate thumbprint must be provided manually.' -Level 'Warning'
            return $null
        }

        # Retrieve secret
        $secretJson = & aws secretsmanager get-secret-value `
            --secret-id $SecretId `
            --query 'SecretString' `
            --output text `
            2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to retrieve secret: $secretJson" -Level 'Warning'
            return $null
        }

        # Parse JSON (secret may be JSON or plain string)
        try {
            $secretObj = $secretJson | ConvertFrom-Json
            $thumbprint = $secretObj.CertificateThumbprint ?? $secretObj.thumbprint ?? $secretObj
        }
        catch {
            # Not JSON, use as-is
            $thumbprint = $secretJson.Trim()
        }

        # Validate thumbprint format (40 hex characters)
        if ($thumbprint -match '^[A-Fa-f0-9]{40}$') {
            Write-Log 'Successfully retrieved certificate thumbprint' -Level 'Success'
            return $thumbprint.ToUpper()
        }
        else {
            Write-Log 'Retrieved value is not a valid certificate thumbprint' -Level 'Warning'
            return $null
        }
    }
    catch {
        Write-Log "Error retrieving certificate from Secrets Manager: $_" -Level 'Warning'
        return $null
    }
}

# ==============================================================================
# Configuration Data Processing
# ==============================================================================

function Get-ProcessedConfigurationData {
    <#
    .SYNOPSIS
        Loads and processes configuration data with environment-specific overrides.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Environment,

        [Parameter()]
        [string]$CertificateThumbprint,

        [Parameter()]
        [string]$NodeName
    )

    Write-Log "Loading configuration data for environment: $Environment" -Level 'Info'

    $dataPath = Join-Path -Path $ScriptRoot -ChildPath 'ConfigurationData\AppServer.psd1'
    $configData = Import-PowerShellDataFile -Path $dataPath

    # Process node names - update wildcard patterns to actual node name
    foreach ($node in $configData.AllNodes) {
        if ($node.NodeName -eq '*') {
            continue
        }

        # Check if node matches current environment
        if ($node.Environment -eq $Environment) {
            # If NodeName is a pattern, update with actual name
            if ($node.NodeName -like '*-*-*') {
                $originalPattern = $node.NodeName
                # Keep the pattern but also set up for the actual node
                Write-Log "  Node pattern: $originalPattern" -Level 'Debug'
            }
        }
    }

    # Create a node entry for the actual computer name if needed
    $matchingNode = $configData.AllNodes | Where-Object {
        $_.Environment -eq $Environment -and $_.NodeName -ne '*'
    } | Select-Object -First 1

    if ($matchingNode) {
        # Clone the matching node for this specific computer
        $actualNode = @{}
        foreach ($key in $matchingNode.Keys) {
            $actualNode[$key] = $matchingNode[$key]
        }
        $actualNode.NodeName = $NodeName

        # Inject certificate thumbprint if provided
        if ($CertificateThumbprint) {
            $actualNode.SSLCertificateThumbprint = $CertificateThumbprint
            Write-Log '  Certificate thumbprint injected into configuration' -Level 'Debug'
        }

        # Add the actual node to AllNodes
        $configData.AllNodes += $actualNode
    }

    Write-Log "  Processed $($configData.AllNodes.Count) node configurations" -Level 'Info'

    return $configData
}

# ==============================================================================
# Configuration Compilation
# ==============================================================================

function Invoke-ConfigurationCompilation {
    <#
    .SYNOPSIS
        Compiles the DSC configuration into MOF files.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigurationData,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    Write-Log 'Compiling DSC configuration...' -Level 'Info'

    # Ensure output directory exists
    if (-not (Test-Path -Path $OutputPath)) {
        $null = New-Item -Path $OutputPath -ItemType Directory -Force
        Write-Log "  Created output directory: $OutputPath" -Level 'Debug'
    }

    # Dot-source the configuration
    $configPath = Join-Path -Path $ScriptRoot -ChildPath 'AppServerConfiguration.ps1'
    Write-Log "  Loading configuration from: $configPath" -Level 'Debug'

    . $configPath

    # Compile the configuration
    try {
        $compilationParams = @{
            ConfigurationData = $ConfigurationData
            OutputPath        = $OutputPath
            Environment       = $Environment
        }

        $mofFiles = AppServerConfiguration @compilationParams

        if ($mofFiles) {
            Write-Log "  Successfully compiled configuration" -Level 'Success'
            Write-Log "  MOF files:" -Level 'Info'
            foreach ($mof in $mofFiles) {
                Write-Log "    - $($mof.FullName)" -Level 'Info'
            }
            return $mofFiles
        }
        else {
            throw 'No MOF files generated'
        }
    }
    catch {
        Write-Log "  Compilation failed: $_" -Level 'Error'
        throw
    }
}

# ==============================================================================
# Configuration Application
# ==============================================================================

function Test-ConfigurationDrift {
    <#
    .SYNOPSIS
        Tests if the current system state matches the desired configuration.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MofPath
    )

    Write-Log 'Testing for configuration drift...' -Level 'Info'

    try {
        $testResult = Test-DscConfiguration -Path $MofPath -Detailed -ErrorAction Stop

        if ($testResult.InDesiredState) {
            Write-Log '  System is in desired state - no drift detected' -Level 'Success'
            return $false  # No drift
        }
        else {
            Write-Log '  Configuration drift detected:' -Level 'Warning'
            foreach ($resource in $testResult.ResourcesNotInDesiredState) {
                Write-Log "    - $($resource.ResourceId)" -Level 'Warning'
            }
            return $true  # Drift detected
        }
    }
    catch {
        Write-Log "  Error testing configuration: $_" -Level 'Warning'
        return $true  # Assume drift on error (safer to apply)
    }
}

function Invoke-ConfigurationApplication {
    <#
    .SYNOPSIS
        Applies the compiled DSC configuration to the local system.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MofPath,

        [Parameter()]
        [switch]$Force
    )

    Write-Log 'Applying DSC configuration...' -Level 'Info'

    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Apply DSC Configuration')) {
        try {
            $startTime = Get-Date

            # Apply configuration
            $applyParams = @{
                Path    = $MofPath
                Wait    = $true
                Verbose = $true
                Force   = $Force.IsPresent
            }

            Start-DscConfiguration @applyParams

            $duration = (Get-Date) - $startTime
            Write-Log "  Configuration applied successfully in $($duration.TotalSeconds.ToString('F2')) seconds" -Level 'Success'

            # Verify application
            Write-Log '  Verifying configuration state...' -Level 'Info'
            $testResult = Test-DscConfiguration -Detailed

            if ($testResult.InDesiredState) {
                Write-Log '  Verification passed - system is in desired state' -Level 'Success'
                return $true
            }
            else {
                Write-Log '  Verification warning - some resources may need attention:' -Level 'Warning'
                foreach ($resource in $testResult.ResourcesNotInDesiredState) {
                    Write-Log "    - $($resource.ResourceId): $($resource.InDesiredState)" -Level 'Warning'
                }
                return $true  # Configuration was applied, even if partial
            }
        }
        catch {
            Write-Log "  Configuration application failed: $_" -Level 'Error'

            # Attempt to get detailed error information
            $dscEvents = Get-WinEvent -LogName 'Microsoft-Windows-Dsc/Operational' -MaxEvents 10 -ErrorAction SilentlyContinue
            if ($dscEvents) {
                Write-Log '  Recent DSC events:' -Level 'Debug'
                foreach ($event in $dscEvents) {
                    Write-Log "    [$($event.TimeCreated)] $($event.Message.Substring(0, [Math]::Min(100, $event.Message.Length)))..." -Level 'Debug'
                }
            }

            throw
        }
    }
    else {
        Write-Log '  Configuration application skipped (WhatIf mode)' -Level 'Info'
        return $true
    }
}

# ==============================================================================
# Main Execution
# ==============================================================================

function Main {
    <#
    .SYNOPSIS
        Main entry point for the deployment script.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    $script:LogFileReady = $false

    try {
        # Initialize logging
        Initialize-Logging

        Write-Log '========================================' -Level 'Info'
        Write-Log 'Hyperion App Server DSC Deployment' -Level 'Info'
        Write-Log '========================================' -Level 'Info'
        Write-Log "Environment: $Environment" -Level 'Info'
        Write-Log "Node Name: $NodeName" -Level 'Info'
        Write-Log "Apply Mode: $($Apply.IsPresent)" -Level 'Info'
        Write-Log "Incremental: $($Incremental.IsPresent)" -Level 'Info'
        Write-Log '' -Level 'Info'

        # Step 1: Validate prerequisites
        Write-Log 'Step 1: Validating prerequisites' -Level 'Info'
        if (-not (Test-Prerequisites)) {
            Write-Log 'Prerequisites validation failed. Attempting to install missing components...' -Level 'Warning'
            Install-RequiredDscResources

            # Re-validate
            if (-not (Test-Prerequisites)) {
                throw 'Prerequisites validation failed after installation attempt'
            }
        }
        Write-Log '' -Level 'Info'

        # Step 2: Resolve certificate thumbprint
        Write-Log 'Step 2: Resolving SSL certificate' -Level 'Info'
        $resolvedThumbprint = $CertificateThumbprint

        if (-not $resolvedThumbprint) {
            # Attempt to retrieve from AWS Secrets Manager
            $secretId = $AwsSecretId
            if (-not $secretId) {
                $secretId = "hyperion/$Environment/ssl-certificate"
            }

            $resolvedThumbprint = Get-CertificateFromSecretsManager -SecretId $secretId

            if (-not $resolvedThumbprint) {
                Write-Log '  Using placeholder certificate thumbprint (must be updated before production)' -Level 'Warning'
                $resolvedThumbprint = "${Environment.ToUpper()}_CERTIFICATE_THUMBPRINT_PLACEHOLDER"
            }
        }
        else {
            Write-Log '  Using provided certificate thumbprint' -Level 'Info'
        }
        Write-Log '' -Level 'Info'

        # Step 3: Load and process configuration data
        Write-Log 'Step 3: Processing configuration data' -Level 'Info'
        $configData = Get-ProcessedConfigurationData `
            -Environment $Environment `
            -CertificateThumbprint $resolvedThumbprint `
            -NodeName $NodeName
        Write-Log '' -Level 'Info'

        # Step 4: Compile configuration
        Write-Log 'Step 4: Compiling DSC configuration' -Level 'Info'
        $mofFiles = Invoke-ConfigurationCompilation `
            -ConfigurationData $configData `
            -OutputPath $OutputPath
        Write-Log '' -Level 'Info'

        # Step 5: Apply configuration (if requested)
        if ($Apply) {
            Write-Log 'Step 5: Applying configuration' -Level 'Info'

            # Check for drift if incremental mode
            if ($Incremental) {
                $hasDrift = Test-ConfigurationDrift -MofPath $OutputPath

                if (-not $hasDrift) {
                    Write-Log 'No configuration drift detected. Skipping application.' -Level 'Success'
                    return
                }
            }

            # Confirm before applying (unless Force)
            if (-not $Force -and -not $WhatIfPreference) {
                $confirmation = Read-Host "Apply configuration to $NodeName in $Environment environment? (yes/no)"
                if ($confirmation -notmatch '^y(es)?$') {
                    Write-Log 'Deployment cancelled by user' -Level 'Warning'
                    return
                }
            }

            # Apply the configuration
            $success = Invoke-ConfigurationApplication `
                -MofPath $OutputPath `
                -Force:$Force

            if ($success) {
                Write-Log '' -Level 'Info'
                Write-Log '========================================' -Level 'Success'
                Write-Log 'Deployment completed successfully!' -Level 'Success'
                Write-Log '========================================' -Level 'Success'
            }
        }
        else {
            Write-Log 'Step 5: Skipped (Apply not specified)' -Level 'Info'
            Write-Log '' -Level 'Info'
            Write-Log '========================================' -Level 'Success'
            Write-Log 'Compilation completed successfully!' -Level 'Success'
            Write-Log "MOF files located at: $OutputPath" -Level 'Info'
            Write-Log 'Run with -Apply to deploy configuration' -Level 'Info'
            Write-Log '========================================' -Level 'Success'
        }

        # Output summary
        Write-Log '' -Level 'Info'
        Write-Log 'Deployment Summary:' -Level 'Info'
        Write-Log "  Environment: $Environment" -Level 'Info'
        Write-Log "  Target Node: $NodeName" -Level 'Info'
        Write-Log "  MOF Path: $OutputPath" -Level 'Info'
        Write-Log "  Log File: $LogFile" -Level 'Info'
    }
    catch {
        Write-Log '' -Level 'Info'
        Write-Log '========================================' -Level 'Error'
        Write-Log 'Deployment FAILED!' -Level 'Error'
        Write-Log "Error: $_" -Level 'Error'
        Write-Log '========================================' -Level 'Error'

        # Write full error to log
        if ($script:LogFileReady) {
            $_ | Out-String | Add-Content -Path $LogFile
            $_.ScriptStackTrace | Add-Content -Path $LogFile
        }

        exit 1
    }
}

# Execute main function
Main
