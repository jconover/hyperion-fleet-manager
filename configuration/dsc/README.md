# Build Agent DSC Configuration

PowerShell Desired State Configuration (DSC) for provisioning and maintaining Windows build agents in the Hyperion Fleet Manager infrastructure.

## Overview

This DSC configuration creates clean, reproducible build environments for Windows-based build agents. It automates the installation and configuration of development tools, runtimes, and maintenance tasks required for CI/CD pipelines.

## Features

- **Automated Tool Installation**: Chocolatey-based package management for consistent deployments
- **Build Environment Setup**: Workspace directories, cache locations, and environment variables
- **Scheduled Maintenance**: Automated disk cleanup and cache management
- **Security Configuration**: Certificate installation, firewall rules, and service account setup
- **Multi-Environment Support**: Configurable settings for development, staging, and production

## Prerequisites

### System Requirements

- Windows Server 2019 or later (Windows Server 2022 recommended)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Administrator privileges
- Network access to Chocolatey package repository

### Required DSC Modules

The deployment script automatically installs these modules:

| Module | Minimum Version | Purpose |
|--------|-----------------|---------|
| ComputerManagementDsc | 8.5.0 | Scheduled tasks, Windows features |
| cChoco | 2.5.0 | Chocolatey package management |
| CertificateDsc | 5.1.0 | Certificate installation |
| SecurityPolicyDsc | 2.10.0 | Security policy configuration |

## Directory Structure

```
dsc/
|-- BuildAgentConfiguration.ps1      # Main DSC configuration
|-- Deploy-BuildAgentConfiguration.ps1  # Deployment script
|-- ChocolateyPackages.psd1          # Package definitions
|-- ConfigurationData/
|   |-- BuildAgent.psd1              # Configuration data
|-- Output/                          # Compiled MOF files (generated)
|-- Logs/                            # Deployment logs (generated)
```

## Quick Start

### Local Deployment

Deploy to the local machine with default settings:

```powershell
# Run as Administrator
.\Deploy-BuildAgentConfiguration.ps1
```

### Remote Deployment

Deploy to remote build agents:

```powershell
$credential = Get-Credential
.\Deploy-BuildAgentConfiguration.ps1 -NodeName 'BUILD-PROD-01', 'BUILD-PROD-02' `
    -Environment Production `
    -BuildPool Production `
    -Credential $credential
```

### Compile Only

Generate MOF files without deploying:

```powershell
.\Deploy-BuildAgentConfiguration.ps1 -CompileOnly -OutputPath 'C:\DSC\Output'
```

## Configuration

### Configuration Data (BuildAgent.psd1)

The configuration data file defines all settings for build agents. Key sections include:

#### Directory Paths

```powershell
BuildAgentPath           = 'C:\BuildAgent'      # Agent installation
WorkspacePath            = 'C:\Workspace'        # Build workspace
BuildTempPath            = 'C:\BuildAgent\Temp'  # Temporary files
NuGetCachePath           = 'C:\BuildAgent\Cache\NuGet'
NpmCachePath             = 'C:\BuildAgent\Cache\npm'
PipCachePath             = 'C:\BuildAgent\Cache\pip'
TerraformPluginCachePath = 'C:\BuildAgent\Cache\terraform-plugins'
```

#### Tool Versions

Pin specific versions for reproducible builds:

```powershell
NodeJSVersion       = '20.11.0'
PythonVersion       = '3.12.1'
VSBuildToolsVersion = '17.8.0'
DotNetSDKVersion    = '8.0.101'
TerraformVersion    = '1.7.0'
```

#### Node-Specific Settings

Configure individual nodes:

```powershell
@{
    NodeName            = 'BUILD-PROD-01'
    Role                = 'BuildAgent'
    EnableDocker        = $true
    AutoUpgradePackages = $false
    TempFileRetentionDays = 14
}
```

### Chocolatey Packages (ChocolateyPackages.psd1)

Defines all packages installed on build agents.

#### Core Packages (Always Installed)

| Package | Version | Description |
|---------|---------|-------------|
| git | latest | Version control |
| nodejs-lts | 20.11.0 | Node.js LTS runtime |
| python3 | 3.12.1 | Python runtime |
| visualstudio2022buildtools | 17.8.0 | .NET build tools |
| dotnet-sdk | 8.0.101 | .NET SDK |
| awscli | latest | AWS CLI |
| terraform | 1.7.0 | Infrastructure as Code |
| 7zip | latest | Archive utility |
| powershell-core | latest | PowerShell 7 |

#### Optional Packages

- docker-desktop
- azure-cli
- kubernetes-cli
- kubernetes-helm
- sonarqube-scanner.portable
- openjdk
- golang
- rust

### Installation Profiles

Pre-defined package sets for different agent types:

```powershell
# Minimal - Essential tools only
Profiles.Minimal

# DotNet - .NET-focused development
Profiles.DotNet

# FullStack - Complete development environment
Profiles.FullStack

# CloudInfra - DevOps and infrastructure
Profiles.CloudInfra
```

## Deployment Options

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| NodeName | string[] | localhost | Target node(s) |
| Environment | string | Development | Target environment |
| BuildPool | string | Development | Build pool name |
| OutputPath | string | .\Output | MOF output path |
| ConfigurationDataPath | string | .\ConfigurationData\BuildAgent.psd1 | Config data file |
| Force | switch | $false | Skip confirmations |
| CompileOnly | switch | $false | Compile without deploying |
| Credential | PSCredential | $null | Remote authentication |
| AgentName | string | hostname | Custom agent name |
| SkipPrerequisites | switch | $false | Skip prerequisite checks |

### Examples

```powershell
# Development environment
.\Deploy-BuildAgentConfiguration.ps1 -Environment Development -BuildPool Development

# Production with specific nodes
.\Deploy-BuildAgentConfiguration.ps1 -NodeName 'BUILD-PROD-01' -Environment Production

# What-if mode (no changes)
.\Deploy-BuildAgentConfiguration.ps1 -WhatIf

# Verbose output
.\Deploy-BuildAgentConfiguration.ps1 -Verbose
```

## Maintenance

### Scheduled Tasks

The configuration creates these maintenance tasks:

| Task | Schedule | Purpose |
|------|----------|---------|
| Hyperion-BuildAgent-DiskCleanup | Daily 3:00 AM | Windows disk cleanup |
| Hyperion-BuildAgent-TempCleanup | Daily 4:00 AM | Remove old temp files |
| Hyperion-BuildAgent-NuGetCacheCleanup | Weekly Sunday 5:00 AM | Clean NuGet cache |
| Hyperion-BuildAgent-NpmCacheCleanup | Weekly Sunday 5:30 AM | Clean npm cache |

### Manual Cache Cleanup

```powershell
# Clear NuGet cache
dotnet nuget locals all --clear

# Clear npm cache
npm cache clean --force

# Clear pip cache
pip cache purge
```

## Customization

### Adding New Packages

1. Edit `ChocolateyPackages.psd1`
2. Add package to `CorePackages` or `OptionalPackages`:

```powershell
@{
    Name        = 'package-name'
    Version     = '1.0.0'  # or 'latest'
    Description = 'Package description'
    Required    = $true
    AutoUpgrade = $false
    Parameters  = @('/SomeParameter')
    VerifyCommand = 'package --version'
    Category    = 'CategoryName'
}
```

3. If core package, update `BuildAgentConfiguration.ps1`

### Adding Environment Variables

Edit `BuildAgentConfiguration.ps1`:

```powershell
Environment 'MyVariable' {
    Name   = 'MY_VARIABLE'
    Value  = 'my-value'
    Ensure = 'Present'
    Path   = $false
}
```

### Adding Scheduled Tasks

```powershell
ScheduledTask 'MyCustomTask' {
    TaskName         = 'Hyperion-BuildAgent-MyTask'
    TaskPath         = '\Hyperion\'
    ActionExecutable = 'powershell.exe'
    ActionArguments  = '-Command "My-Script"'
    ScheduleType     = 'Daily'
    StartTime        = '02:00:00'
    Enable           = $true
}
```

## Troubleshooting

### Common Issues

#### DSC Module Not Found

```powershell
# Install modules manually
Install-Module -Name ComputerManagementDsc -MinimumVersion 8.5.0 -Force
Install-Module -Name cChoco -MinimumVersion 2.5.0 -Force
```

#### Configuration Not Applying

```powershell
# Check DSC status
Get-DscConfigurationStatus

# View detailed logs
Get-DscConfigurationStatus -All

# Test current compliance
Test-DscConfiguration -Detailed
```

#### Chocolatey Package Failures

```powershell
# Check Chocolatey logs
Get-Content C:\ProgramData\chocolatey\logs\chocolatey.log -Tail 100

# Retry failed package
choco install package-name -y --force
```

### Log Files

Deployment logs are stored in:

```
.\Logs\Deploy-YYYYMMDD-HHmmss.log
```

### Compliance Verification

```powershell
# Test if configuration is applied
Test-DscConfiguration

# Get detailed compliance report
Test-DscConfiguration -Detailed

# View current configuration
Get-DscConfiguration
```

## Security Considerations

### Service Account

The configuration creates a local service account (`svc_buildagent`) for running build agent services. In production:

1. Use a domain service account where possible
2. Store credentials in Azure Key Vault or AWS Secrets Manager
3. Apply least-privilege permissions

### Certificates

For code signing:

1. Store PFX files securely (not in source control)
2. Use certificate thumbprints in configuration
3. Rotate certificates before expiration

### Network Security

The configuration creates outbound firewall rules for:

- HTTPS (port 443) for Git, NuGet, npm, and package downloads

Review and adjust based on your security requirements.

## Integration

### Azure DevOps Agent

After DSC configuration, install Azure DevOps agent:

```powershell
# Download agent
Invoke-WebRequest -Uri "https://vstsagentpackage.azureedge.net/agent/3.x.x/vsts-agent-win-x64-3.x.x.zip" -OutFile agent.zip

# Extract and configure
Expand-Archive agent.zip -DestinationPath C:\BuildAgent\AzureAgent
.\config.cmd --unattended --url https://dev.azure.com/org --auth pat --token $PAT --pool "BuildPool" --agent $env:COMPUTERNAME
```

### GitHub Actions Runner

```powershell
# Download runner
Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v2.x.x/actions-runner-win-x64-2.x.x.zip" -OutFile runner.zip

# Extract and configure
Expand-Archive runner.zip -DestinationPath C:\BuildAgent\GitHubRunner
.\config.cmd --url https://github.com/org/repo --token $TOKEN
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following PowerShell best practices
4. Test in a development environment
5. Submit a pull request

## License

MIT License - see LICENSE file in project root.

## Related Documentation

- [CLAUDE.md](../../CLAUDE.md) - Project context and conventions
- [ARCHITECTURE.md](../../docs/architecture/ARCHITECTURE.md) - System architecture
- [CONTRIBUTING.md](../../docs/CONTRIBUTING.md) - Contribution guidelines
