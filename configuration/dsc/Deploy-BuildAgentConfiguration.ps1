<#
.SYNOPSIS
    Compiles and deploys the Build Agent DSC Configuration for Hyperion Fleet Manager.

.DESCRIPTION
    This script provides a complete deployment workflow for the Build Agent DSC
    configuration. It handles:
    - Prerequisite validation and installation
    - DSC module dependency management
    - Configuration compilation to MOF files
    - Local or remote deployment to target nodes
    - Build pool specification and agent registration
    - Configuration verification and rollback support

    The script supports both push (default) and pull deployment modes and can
    be integrated with CI/CD pipelines for automated agent provisioning.

.PARAMETER NodeName
    Target node(s) for configuration deployment. Accepts single hostname,
    array of hostnames, or 'localhost' for local deployment.
    Default: localhost

.PARAMETER Environment
    Target environment (Development, Staging, Production).
    Affects configuration settings and logging verbosity.
    Default: Development

.PARAMETER BuildPool
    Name of the build pool to register the agent with.
    Corresponds to pool definitions in configuration data.
    Options: Development, Production
    Default: Development

.PARAMETER OutputPath
    Path where compiled MOF files will be stored.
    Default: .\Output

.PARAMETER ConfigurationDataPath
    Path to the configuration data file.
    Default: .\ConfigurationData\BuildAgent.psd1

.PARAMETER Force
    Skip confirmation prompts and force configuration application.
    Use with caution in production environments.

.PARAMETER WhatIf
    Shows what would happen if the cmdlet runs. Does not compile or deploy.

.PARAMETER Confirm
    Prompts for confirmation before any changes.

.PARAMETER CompileOnly
    Only compile the configuration; do not deploy to nodes.

.PARAMETER Credential
    Credentials for remote node authentication.
    Required for remote deployments.

.PARAMETER AgentName
    Custom name for the build agent (used in logging and identification).
    Default: Auto-generated from hostname

.PARAMETER SkipPrerequisites
    Skip prerequisite checks and module installation.
    Use when prerequisites are known to be present.

.PARAMETER Verbose
    Enable verbose output for detailed progress information.

.EXAMPLE
    # Deploy to local machine with default settings
    .\Deploy-BuildAgentConfiguration.ps1

.EXAMPLE
    # Deploy to specific nodes in production pool
    .\Deploy-BuildAgentConfiguration.ps1 -NodeName 'BUILD-PROD-01', 'BUILD-PROD-02' `
        -Environment Production -BuildPool Production

.EXAMPLE
    # Compile only without deployment
    .\Deploy-BuildAgentConfiguration.ps1 -CompileOnly -OutputPath 'C:\DSC\Compiled'

.EXAMPLE
    # Remote deployment with credentials
    $cred = Get-Credential
    .\Deploy-BuildAgentConfiguration.ps1 -NodeName 'BUILD-DEV-01' -Credential $cred

.EXAMPLE
    # What-if mode for testing
    .\Deploy-BuildAgentConfiguration.ps1 -NodeName 'localhost' -WhatIf

.NOTES
    Project:     Hyperion Fleet Manager
    Module:      DSC Deployment Script
    Version:     1.0.0
    Author:      Hyperion Fleet Team
    Requires:    PowerShell 5.1+, Administrator privileges

    Exit Codes:
    0 - Success
    1 - Prerequisites check failed
    2 - Configuration compilation failed
    3 - Deployment failed
    4 - Verification failed
    5 - User cancelled operation

.LINK
    https://github.com/jconover/hyperion-fleet-manager/tree/main/docs/dsc
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]]$NodeName = @('localhost'),

    [Parameter()]
    [ValidateSet('Development', 'Staging', 'Production')]
    [string]$Environment = 'Development',

    [Parameter()]
    [ValidateSet('Development', 'Production')]
    [string]$BuildPool = 'Development',

    [Parameter()]
    [ValidateScript({
        if (-not (Test-Path -Path (Split-Path $_ -Parent) -PathType Container)) {
            throw "Output path parent directory does not exist: $(Split-Path $_ -Parent)"
        }
        $true
    })]
    [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath 'Output'),

    [Parameter()]
    [ValidateScript({
        if (-not (Test-Path -Path $_ -PathType Leaf)) {
            throw "Configuration data file not found: $_"
        }
        $true
    })]
    [string]$ConfigurationDataPath = (Join-Path -Path $PSScriptRoot -ChildPath 'ConfigurationData\BuildAgent.psd1'),

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$CompileOnly,

    [Parameter()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential,

    [Parameter()]
    [ValidateLength(1, 50)]
    [string]$AgentName,

    [Parameter()]
    [switch]$SkipPrerequisites
)

#region Script Configuration
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

# Script metadata
$script:Version = '1.0.0'
$script:StartTime = Get-Date
$script:LogPath = Join-Path -Path $PSScriptRoot -ChildPath 'Logs'
$script:LogFile = Join-Path -Path $script:LogPath -ChildPath "Deploy-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Required DSC modules
$script:RequiredModules = @{
    'ComputerManagementDsc' = '8.5.0'
    'cChoco'                = '2.5.0'
    'CertificateDsc'        = '5.1.0'
    'SecurityPolicyDsc'     = '2.10.0'
}
#endregion

#region Helper Functions
function Write-Log {
    <#
    .SYNOPSIS
        Writes a log message to console and log file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug')]
        [string]$Level = 'Info',

        [Parameter()]
        [switch]$NoConsole
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to log file
    if (-not (Test-Path -Path $script:LogPath)) {
        New-Item -Path $script:LogPath -ItemType Directory -Force | Out-Null
    }
    Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue

    # Write to console with color
    if (-not $NoConsole) {
        $color = switch ($Level) {
            'Info'    { 'White' }
            'Warning' { 'Yellow' }
            'Error'   { 'Red' }
            'Success' { 'Green' }
            'Debug'   { 'Cyan' }
            default   { 'White' }
        }
        Write-Host $logMessage -ForegroundColor $color
    }
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Validates and installs required prerequisites.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Log -Message 'Validating prerequisites...' -Level Info

    $success = $true

    # Check PowerShell version
    Write-Log -Message "PowerShell Version: $($PSVersionTable.PSVersion)" -Level Debug
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Log -Message 'PowerShell 5.1 or later is required' -Level Error
        $success = $false
    }

    # Check administrator privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        Write-Log -Message 'Administrator privileges are required' -Level Error
        $success = $false
    }

    # Check and install required DSC modules
    foreach ($moduleName in $script:RequiredModules.Keys) {
        $requiredVersion = $script:RequiredModules[$moduleName]
        $module = Get-Module -Name $moduleName -ListAvailable |
            Where-Object { $_.Version -ge [version]$requiredVersion } |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if ($null -eq $module) {
            Write-Log -Message "Installing required module: $moduleName (>= $requiredVersion)" -Level Info
            try {
                Install-Module -Name $moduleName -MinimumVersion $requiredVersion `
                    -Force -AllowClobber -Scope AllUsers -SkipPublisherCheck
                Write-Log -Message "Successfully installed $moduleName" -Level Success
            }
            catch {
                Write-Log -Message "Failed to install $moduleName: $_" -Level Error
                $success = $false
            }
        }
        else {
            Write-Log -Message "Module $moduleName v$($module.Version) is available" -Level Debug
        }
    }

    # Verify WinRM is running for remote deployments
    if ($NodeName -ne 'localhost' -and $NodeName -ne $env:COMPUTERNAME) {
        $winrmService = Get-Service -Name WinRM -ErrorAction SilentlyContinue
        if ($winrmService.Status -ne 'Running') {
            Write-Log -Message 'WinRM service is not running. Required for remote deployments.' -Level Warning
            try {
                Start-Service -Name WinRM
                Write-Log -Message 'Started WinRM service' -Level Info
            }
            catch {
                Write-Log -Message "Failed to start WinRM: $_" -Level Error
                $success = $false
            }
        }
    }

    return $success
}

function Get-ConfigurationData {
    <#
    .SYNOPSIS
        Loads and customizes configuration data for deployment.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string[]]$TargetNodes,

        [Parameter(Mandatory)]
        [string]$BuildPoolName
    )

    Write-Log -Message "Loading configuration data from: $Path" -Level Info

    $configData = Import-PowerShellDataFile -Path $Path

    # Update node names in configuration if deploying to specific nodes
    if ($TargetNodes -ne @('*') -and $TargetNodes[0] -ne 'localhost') {
        # Add specific nodes to configuration
        foreach ($node in $TargetNodes) {
            $existingNode = $configData.AllNodes | Where-Object { $_.NodeName -eq $node }
            if (-not $existingNode) {
                # Get the default node configuration as template
                $defaultConfig = ($configData.AllNodes | Where-Object { $_.NodeName -eq '*' }).Clone()
                $defaultConfig.NodeName = $node
                $defaultConfig.Role = 'BuildAgent'
                $configData.AllNodes += $defaultConfig
            }
        }
    }
    elseif ($TargetNodes[0] -eq 'localhost') {
        # Ensure localhost is in the configuration
        $localhostNode = $configData.AllNodes | Where-Object { $_.NodeName -eq 'localhost' }
        if (-not $localhostNode) {
            $defaultConfig = ($configData.AllNodes | Where-Object { $_.NodeName -eq '*' }).Clone()
            $defaultConfig.NodeName = 'localhost'
            $defaultConfig.Role = 'BuildAgent'
            $configData.AllNodes += $defaultConfig
        }
    }

    # Apply build pool-specific settings
    if ($configData.BuildPools -and $configData.BuildPools.ContainsKey($BuildPoolName)) {
        $poolConfig = $configData.BuildPools[$BuildPoolName]
        Write-Log -Message "Applying build pool configuration: $BuildPoolName" -Level Debug
        Write-Log -Message "Pool description: $($poolConfig.Description)" -Level Debug
    }

    return $configData
}

function Invoke-ConfigurationCompile {
    <#
    .SYNOPSIS
        Compiles the DSC configuration to MOF files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ConfigurationData,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    Write-Log -Message 'Compiling DSC configuration...' -Level Info

    # Create output directory
    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    # Import the configuration
    $configPath = Join-Path -Path $PSScriptRoot -ChildPath 'BuildAgentConfiguration.ps1'
    if (-not (Test-Path -Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    Write-Log -Message "Loading configuration from: $configPath" -Level Debug

    # Dot-source the configuration file
    . $configPath

    # Compile the configuration
    try {
        $mofPath = BuildAgentConfiguration -ConfigurationData $ConfigurationData -OutputPath $OutputPath
        Write-Log -Message "Configuration compiled successfully to: $OutputPath" -Level Success

        # List generated MOF files
        $mofFiles = Get-ChildItem -Path $OutputPath -Filter '*.mof' -File
        foreach ($mof in $mofFiles) {
            Write-Log -Message "Generated MOF: $($mof.Name)" -Level Debug
        }

        return $mofPath
    }
    catch {
        Write-Log -Message "Configuration compilation failed: $_" -Level Error
        throw
    }
}

function Deploy-Configuration {
    <#
    .SYNOPSIS
        Deploys the compiled DSC configuration to target nodes.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$MofPath,

        [Parameter(Mandatory)]
        [string[]]$TargetNodes,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [switch]$Force
    )

    Write-Log -Message 'Starting configuration deployment...' -Level Info

    $results = @()

    foreach ($node in $TargetNodes) {
        Write-Log -Message "Deploying to node: $node" -Level Info

        if ($PSCmdlet.ShouldProcess($node, 'Apply DSC Configuration')) {
            try {
                $dscParams = @{
                    Path    = $MofPath
                    Wait    = $true
                    Verbose = $VerbosePreference -eq 'Continue'
                    Force   = $Force.IsPresent
                }

                # Add credential for remote nodes
                if ($node -ne 'localhost' -and $node -ne $env:COMPUTERNAME) {
                    if ($null -eq $Credential) {
                        throw "Credential required for remote deployment to $node"
                    }
                    $dscParams['Credential'] = $Credential
                    $dscParams['ComputerName'] = $node
                }

                # Apply configuration
                $job = Start-DscConfiguration @dscParams

                # Check for errors
                $status = Get-DscConfigurationStatus -CimSession $node -ErrorAction SilentlyContinue
                if ($status.Status -eq 'Failure') {
                    throw "Configuration application failed on $node"
                }

                $results += [PSCustomObject]@{
                    Node      = $node
                    Status    = 'Success'
                    Timestamp = Get-Date
                    Duration  = $status.DurationInSeconds
                }

                Write-Log -Message "Successfully deployed to $node" -Level Success
            }
            catch {
                $results += [PSCustomObject]@{
                    Node      = $node
                    Status    = 'Failed'
                    Error     = $_.Exception.Message
                    Timestamp = Get-Date
                }
                Write-Log -Message "Deployment failed for $node: $_" -Level Error
            }
        }
    }

    return $results
}

function Test-ConfigurationCompliance {
    <#
    .SYNOPSIS
        Verifies that the configuration was applied successfully.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$TargetNodes,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    Write-Log -Message 'Verifying configuration compliance...' -Level Info

    $results = @()

    foreach ($node in $TargetNodes) {
        try {
            $testParams = @{
                Verbose = $false
            }

            if ($node -ne 'localhost' -and $node -ne $env:COMPUTERNAME) {
                $testParams['CimSession'] = New-CimSession -ComputerName $node -Credential $Credential
            }

            $testResult = Test-DscConfiguration @testParams

            $results += [PSCustomObject]@{
                Node       = $node
                InDesired  = $testResult
                Status     = if ($testResult) { 'Compliant' } else { 'Non-Compliant' }
                Timestamp  = Get-Date
            }

            $level = if ($testResult) { 'Success' } else { 'Warning' }
            Write-Log -Message "$node compliance: $($results[-1].Status)" -Level $level
        }
        catch {
            $results += [PSCustomObject]@{
                Node      = $node
                InDesired = $false
                Status    = 'Error'
                Error     = $_.Exception.Message
                Timestamp = Get-Date
            }
            Write-Log -Message "Compliance check failed for $node: $_" -Level Error
        }
    }

    return $results
}

function Register-BuildAgent {
    <#
    .SYNOPSIS
        Registers the build agent with the build pool (placeholder for future integration).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NodeName,

        [Parameter(Mandatory)]
        [string]$BuildPool,

        [Parameter()]
        [string]$AgentName
    )

    $agentDisplayName = if ($AgentName) { $AgentName } else { $NodeName }

    Write-Log -Message "Registering agent '$agentDisplayName' with build pool '$BuildPool'" -Level Info

    # This is a placeholder for actual agent registration logic
    # In a real implementation, this would:
    # 1. Download the build agent software (e.g., Azure DevOps Agent, GitHub Actions Runner)
    # 2. Configure the agent with pool-specific settings
    # 3. Register the agent with the build service

    $registrationInfo = [PSCustomObject]@{
        AgentName     = $agentDisplayName
        NodeName      = $NodeName
        BuildPool     = $BuildPool
        RegisteredAt  = Get-Date
        Status        = 'Pending'
        Message       = 'Agent registration requires manual completion or CI/CD integration'
    }

    Write-Log -Message 'Agent registration placeholder completed' -Level Warning
    Write-Log -Message 'To complete registration, run the appropriate agent installer for your build system:' -Level Info
    Write-Log -Message '  - Azure DevOps: https://docs.microsoft.com/azure/devops/pipelines/agents/agents' -Level Info
    Write-Log -Message '  - GitHub Actions: https://docs.github.com/actions/hosting-your-own-runners' -Level Info

    return $registrationInfo
}

function Show-DeploymentSummary {
    <#
    .SYNOPSIS
        Displays a summary of the deployment operation.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSCustomObject[]]$DeploymentResults,

        [Parameter()]
        [PSCustomObject[]]$ComplianceResults,

        [Parameter()]
        [TimeSpan]$Duration
    )

    Write-Host "`n" -NoNewline
    Write-Host ('=' * 60) -ForegroundColor Cyan
    Write-Host '  DEPLOYMENT SUMMARY' -ForegroundColor Cyan
    Write-Host ('=' * 60) -ForegroundColor Cyan
    Write-Host "`n"

    Write-Host "Duration: $($Duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
    Write-Host "Log File: $script:LogFile" -ForegroundColor White
    Write-Host "`n"

    if ($DeploymentResults) {
        Write-Host 'Deployment Results:' -ForegroundColor Yellow
        $successCount = ($DeploymentResults | Where-Object Status -eq 'Success').Count
        $failedCount = ($DeploymentResults | Where-Object Status -eq 'Failed').Count
        Write-Host "  Successful: $successCount" -ForegroundColor Green
        Write-Host "  Failed: $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { 'Red' } else { 'Green' })
        Write-Host "`n"
    }

    if ($ComplianceResults) {
        Write-Host 'Compliance Results:' -ForegroundColor Yellow
        $compliantCount = ($ComplianceResults | Where-Object Status -eq 'Compliant').Count
        $nonCompliantCount = ($ComplianceResults | Where-Object Status -ne 'Compliant').Count
        Write-Host "  Compliant: $compliantCount" -ForegroundColor Green
        Write-Host "  Non-Compliant: $nonCompliantCount" -ForegroundColor $(if ($nonCompliantCount -gt 0) { 'Yellow' } else { 'Green' })
    }

    Write-Host "`n"
    Write-Host ('=' * 60) -ForegroundColor Cyan
}
#endregion

#region Main Execution
try {
    # Display banner
    Write-Host "`n"
    Write-Host ('=' * 60) -ForegroundColor Cyan
    Write-Host '  HYPERION FLEET MANAGER - BUILD AGENT DEPLOYMENT' -ForegroundColor Cyan
    Write-Host "  Version: $script:Version" -ForegroundColor Cyan
    Write-Host ('=' * 60) -ForegroundColor Cyan
    Write-Host "`n"

    Write-Log -Message "Starting deployment process..." -Level Info
    Write-Log -Message "Target nodes: $($NodeName -join ', ')" -Level Info
    Write-Log -Message "Environment: $Environment" -Level Info
    Write-Log -Message "Build Pool: $BuildPool" -Level Info

    # Step 1: Prerequisites
    if (-not $SkipPrerequisites) {
        if (-not (Test-Prerequisites)) {
            Write-Log -Message 'Prerequisites validation failed' -Level Error
            exit 1
        }
        Write-Log -Message 'Prerequisites validated successfully' -Level Success
    }
    else {
        Write-Log -Message 'Skipping prerequisites check' -Level Warning
    }

    # Step 2: Load configuration data
    $configData = Get-ConfigurationData -Path $ConfigurationDataPath -TargetNodes $NodeName -BuildPoolName $BuildPool

    # Step 3: Compile configuration
    $mofPath = Invoke-ConfigurationCompile -ConfigurationData $configData -OutputPath $OutputPath

    if ($CompileOnly) {
        Write-Log -Message 'Compile-only mode: skipping deployment' -Level Info
        Write-Log -Message "MOF files available at: $OutputPath" -Level Success
        exit 0
    }

    # Step 4: Confirm deployment
    if (-not $Force -and -not $WhatIfPreference) {
        $confirmMessage = "Deploy Build Agent Configuration to $($NodeName.Count) node(s)?"
        if (-not $PSCmdlet.ShouldContinue($confirmMessage, 'Confirm Deployment')) {
            Write-Log -Message 'Deployment cancelled by user' -Level Warning
            exit 5
        }
    }

    # Step 5: Deploy configuration
    $deployParams = @{
        MofPath     = $OutputPath
        TargetNodes = $NodeName
        Force       = $Force
    }
    if ($Credential) {
        $deployParams['Credential'] = $Credential
    }

    $deploymentResults = Deploy-Configuration @deployParams

    # Step 6: Verify compliance
    $complianceParams = @{
        TargetNodes = $NodeName
    }
    if ($Credential) {
        $complianceParams['Credential'] = $Credential
    }

    $complianceResults = Test-ConfigurationCompliance @complianceParams

    # Step 7: Register agents (if applicable)
    $failedNodes = $deploymentResults | Where-Object Status -eq 'Failed'
    $successNodes = $deploymentResults | Where-Object Status -eq 'Success'

    foreach ($result in $successNodes) {
        $agentDisplayName = if ($AgentName) { "$AgentName-$($result.Node)" } else { $null }
        Register-BuildAgent -NodeName $result.Node -BuildPool $BuildPool -AgentName $agentDisplayName
    }

    # Step 8: Summary
    $duration = (Get-Date) - $script:StartTime
    Show-DeploymentSummary -DeploymentResults $deploymentResults -ComplianceResults $complianceResults -Duration $duration

    # Determine exit code
    if ($failedNodes.Count -gt 0) {
        Write-Log -Message 'Deployment completed with errors' -Level Warning
        exit 3
    }

    $nonCompliant = $complianceResults | Where-Object Status -ne 'Compliant'
    if ($nonCompliant.Count -gt 0) {
        Write-Log -Message 'Some nodes are not in desired state' -Level Warning
        exit 4
    }

    Write-Log -Message 'Deployment completed successfully' -Level Success
    exit 0
}
catch {
    Write-Log -Message "Deployment failed with error: $_" -Level Error
    Write-Log -Message $_.ScriptStackTrace -Level Debug
    exit 2
}
finally {
    Write-Log -Message "Deployment process ended. Duration: $((Get-Date) - $script:StartTime)" -Level Info
}
#endregion
