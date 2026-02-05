<#
.SYNOPSIS
    Chocolatey package definitions for Hyperion Fleet Manager Build Agents.

.DESCRIPTION
    This PowerShell data file defines all Chocolatey packages to be installed
    on build agents. Each package entry includes:
    - Package name (Chocolatey package ID)
    - Version specification (specific version or 'latest')
    - Installation parameters
    - Dependencies and ordering
    - Purpose and documentation

    This file serves as a single source of truth for build agent software
    inventory and enables consistent, reproducible build environments.

.NOTES
    Project:     Hyperion Fleet Manager
    Module:      Chocolatey Package Definitions
    Version:     1.0.0
    Author:      Hyperion Fleet Team

    Version Pinning Strategy:
    - 'latest' - Use latest stable version, auto-upgrade enabled
    - Specific version (e.g., '20.11.0') - Pin to exact version, no auto-upgrade
    - Version range not supported by Chocolatey; use specific versions

    Package Sources:
    - Primary: https://community.chocolatey.org/api/v2/
    - Enterprise environments should consider Chocolatey for Business
      with private package repository

.EXAMPLE
    # Load package definitions
    $packages = Import-PowerShellDataFile -Path '.\ChocolateyPackages.psd1'

    # Install all core packages
    foreach ($pkg in $packages.CorePackages) {
        choco install $pkg.Name --version $pkg.Version -y
    }
#>

@{
    #region Metadata
    SchemaVersion    = '1.0'
    LastUpdated      = '2024-12-15'
    MaintainedBy     = 'Hyperion Fleet Team'
    #endregion

    #region Core Build Packages
    # Essential packages required for all build agents
    CorePackages = @(
        #region Version Control
        @{
            Name            = 'git'
            Version         = 'latest'
            Description     = 'Git distributed version control system'
            Required        = $true
            AutoUpgrade     = $true
            Parameters      = @(
                '/GitAndUnixToolsOnPath'
                '/NoAutoCrlf'
                '/WindowsTerminal'
            )
            PostInstall     = @(
                'git config --system core.longpaths true'
                'git config --system core.autocrlf true'
            )
            VerifyCommand   = 'git --version'
            Category        = 'VersionControl'
        },

        @{
            Name            = 'gh'
            Version         = 'latest'
            Description     = 'GitHub CLI for repository and PR management'
            Required        = $false
            AutoUpgrade     = $true
            Parameters      = @()
            VerifyCommand   = 'gh --version'
            Category        = 'VersionControl'
            DependsOn       = @('git')
        }
        #endregion

        #region JavaScript/Node.js
        @{
            Name            = 'nodejs-lts'
            Version         = '20.11.0'
            Description     = 'Node.js LTS runtime for JavaScript/TypeScript builds'
            Required        = $true
            AutoUpgrade     = $false
            Parameters      = @()
            PostInstall     = @(
                'npm config set cache C:\BuildAgent\Cache\npm --global'
                'npm install -g npm@latest'
                'npm install -g yarn'
            )
            VerifyCommand   = 'node --version'
            Category        = 'Runtime'
            Notes           = 'Pin to LTS version for stability; upgrade during maintenance windows'
        }
        #endregion

        #region Python
        @{
            Name            = 'python3'
            Version         = '3.12.1'
            Description     = 'Python 3 runtime for Python builds and scripts'
            Required        = $true
            AutoUpgrade     = $false
            Parameters      = @(
                '/InstallDir:C:\Python312'
            )
            PostInstall     = @(
                'python -m pip install --upgrade pip'
                'python -m pip install virtualenv'
            )
            VerifyCommand   = 'python --version'
            Category        = 'Runtime'
            Notes           = 'Install to custom directory to avoid path issues'
        }
        #endregion

        #region .NET Development
        @{
            Name            = 'visualstudio2022buildtools'
            Version         = '17.8.0'
            Description     = 'Visual Studio 2022 Build Tools for .NET compilation'
            Required        = $true
            AutoUpgrade     = $false
            Parameters      = @(
                '--add Microsoft.VisualStudio.Workload.AzureBuildTools'
                '--add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools'
                '--add Microsoft.VisualStudio.Workload.WebBuildTools'
                '--add Microsoft.VisualStudio.Workload.NetCoreBuildTools'
                '--add Microsoft.VisualStudio.Component.NuGet.BuildTools'
                '--add Microsoft.Net.Component.4.8.SDK'
                '--passive'
                '--norestart'
            )
            VerifyCommand   = 'vswhere -latest -products * -requires Microsoft.Component.MSBuild'
            Category        = 'BuildTools'
            Notes           = 'Large installation (~5GB); includes C# compiler, MSBuild, NuGet'
            InstallTimeout  = 3600  # 60 minutes
        },

        @{
            Name            = 'dotnet-sdk'
            Version         = '8.0.101'
            Description     = '.NET 8 SDK for modern .NET development'
            Required        = $true
            AutoUpgrade     = $false
            Parameters      = @()
            PostInstall     = @(
                'dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org'
            )
            VerifyCommand   = 'dotnet --list-sdks'
            Category        = 'Runtime'
            Notes           = 'Install alongside VS Build Tools for latest SDK features'
        },

        @{
            Name            = 'nuget.commandline'
            Version         = 'latest'
            Description     = 'NuGet CLI for package management'
            Required        = $true
            AutoUpgrade     = $true
            Parameters      = @()
            VerifyCommand   = 'nuget help'
            Category        = 'BuildTools'
        }
        #endregion

        #region Cloud CLI Tools
        @{
            Name            = 'awscli'
            Version         = 'latest'
            Description     = 'AWS CLI v2 for AWS resource management'
            Required        = $true
            AutoUpgrade     = $true
            Parameters      = @()
            PostInstall     = @(
                'aws --version'
            )
            VerifyCommand   = 'aws --version'
            Category        = 'CloudTools'
        },

        @{
            Name            = 'terraform'
            Version         = '1.7.0'
            Description     = 'Terraform CLI for infrastructure as code'
            Required        = $true
            AutoUpgrade     = $false
            Parameters      = @()
            PostInstall     = @(
                'terraform -install-autocomplete'
            )
            VerifyCommand   = 'terraform version'
            Category        = 'InfrastructureTools'
            Notes           = 'Version should match infrastructure team requirements'
        }
        #endregion

        #region Utilities
        @{
            Name            = '7zip'
            Version         = 'latest'
            Description     = '7-Zip file archiver for build artifacts'
            Required        = $true
            AutoUpgrade     = $true
            Parameters      = @()
            VerifyCommand   = '7z'
            Category        = 'Utilities'
        },

        @{
            Name            = 'powershell-core'
            Version         = 'latest'
            Description     = 'PowerShell 7+ cross-platform automation'
            Required        = $true
            AutoUpgrade     = $true
            Parameters      = @(
                '/ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL'
                '/ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL'
                '/ENABLE_PSREMOTING'
            )
            VerifyCommand   = 'pwsh --version'
            Category        = 'Runtime'
            Notes           = 'Required for modern PowerShell scripts and modules'
        }
        #endregion
    )
    #endregion

    #region Optional Packages
    # Packages that may be installed based on project requirements
    OptionalPackages = @(
        #region Containers
        @{
            Name            = 'docker-desktop'
            Version         = 'latest'
            Description     = 'Docker Desktop for container builds'
            Required        = $false
            AutoUpgrade     = $false
            Parameters      = @()
            Prerequisites   = @(
                'Windows Containers feature enabled'
                'Hyper-V enabled (for Windows containers)'
                'WSL2 (for Linux containers)'
            )
            VerifyCommand   = 'docker --version'
            Category        = 'Containers'
            Notes           = 'Requires system restart after installation'
            RequiresReboot  = $true
        },

        @{
            Name            = 'docker-compose'
            Version         = 'latest'
            Description     = 'Docker Compose for multi-container applications'
            Required        = $false
            AutoUpgrade     = $true
            Parameters      = @()
            VerifyCommand   = 'docker-compose --version'
            Category        = 'Containers'
            DependsOn       = @('docker-desktop')
        }
        #endregion

        #region Additional Cloud Tools
        @{
            Name            = 'azure-cli'
            Version         = 'latest'
            Description     = 'Azure CLI for Azure resource management'
            Required        = $false
            AutoUpgrade     = $true
            Parameters      = @()
            VerifyCommand   = 'az --version'
            Category        = 'CloudTools'
        },

        @{
            Name            = 'kubernetes-cli'
            Version         = 'latest'
            Description     = 'kubectl for Kubernetes cluster management'
            Required        = $false
            AutoUpgrade     = $true
            Parameters      = @()
            VerifyCommand   = 'kubectl version --client'
            Category        = 'Containers'
        },

        @{
            Name            = 'kubernetes-helm'
            Version         = 'latest'
            Description     = 'Helm package manager for Kubernetes'
            Required        = $false
            AutoUpgrade     = $true
            Parameters      = @()
            VerifyCommand   = 'helm version'
            Category        = 'Containers'
            DependsOn       = @('kubernetes-cli')
        }
        #endregion

        #region Code Quality Tools
        @{
            Name            = 'sonarqube-scanner.portable'
            Version         = 'latest'
            Description     = 'SonarQube Scanner for code quality analysis'
            Required        = $false
            AutoUpgrade     = $true
            Parameters      = @()
            VerifyCommand   = 'sonar-scanner --version'
            Category        = 'CodeQuality'
        }
        #endregion

        #region Database Tools
        @{
            Name            = 'sql-server-management-studio'
            Version         = 'latest'
            Description     = 'SQL Server Management Studio for database operations'
            Required        = $false
            AutoUpgrade     = $false
            Parameters      = @()
            VerifyCommand   = $null  # No CLI verification
            Category        = 'DatabaseTools'
            InstallTimeout  = 1800  # 30 minutes
        },

        @{
            Name            = 'sqlcmd'
            Version         = 'latest'
            Description     = 'SQL Server command-line utility'
            Required        = $false
            AutoUpgrade     = $true
            Parameters      = @()
            VerifyCommand   = 'sqlcmd -?'
            Category        = 'DatabaseTools'
        }
        #endregion

        #region Additional Runtimes
        @{
            Name            = 'openjdk'
            Version         = '21.0.1'
            Description     = 'OpenJDK for Java builds'
            Required        = $false
            AutoUpgrade     = $false
            Parameters      = @()
            PostInstall     = @(
                '[Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\OpenJDK\jdk-21.0.1", "Machine")'
            )
            VerifyCommand   = 'java --version'
            Category        = 'Runtime'
        },

        @{
            Name            = 'golang'
            Version         = '1.21.6'
            Description     = 'Go programming language'
            Required        = $false
            AutoUpgrade     = $false
            Parameters      = @()
            VerifyCommand   = 'go version'
            Category        = 'Runtime'
        },

        @{
            Name            = 'rust'
            Version         = 'latest'
            Description     = 'Rust programming language'
            Required        = $false
            AutoUpgrade     = $true
            Parameters      = @()
            VerifyCommand   = 'rustc --version'
            Category        = 'Runtime'
        }
        #endregion

        #region Development Utilities
        @{
            Name            = 'jq'
            Version         = 'latest'
            Description     = 'JSON processor for build scripts'
            Required        = $false
            AutoUpgrade     = $true
            Parameters      = @()
            VerifyCommand   = 'jq --version'
            Category        = 'Utilities'
        },

        @{
            Name            = 'yq'
            Version         = 'latest'
            Description     = 'YAML processor for configuration files'
            Required        = $false
            AutoUpgrade     = $true
            Parameters      = @()
            VerifyCommand   = 'yq --version'
            Category        = 'Utilities'
        },

        @{
            Name            = 'make'
            Version         = 'latest'
            Description     = 'GNU Make for Makefile builds'
            Required        = $false
            AutoUpgrade     = $true
            Parameters      = @()
            VerifyCommand   = 'make --version'
            Category        = 'BuildTools'
        }
        #endregion
    )
    #endregion

    #region Package Categories
    # Groupings for selective installation
    Categories = @{
        VersionControl      = @{
            Description = 'Version control systems and tools'
            Packages    = @('git', 'gh')
        }
        Runtime             = @{
            Description = 'Language runtimes and SDKs'
            Packages    = @('nodejs-lts', 'python3', 'dotnet-sdk', 'powershell-core')
        }
        BuildTools          = @{
            Description = 'Compilation and build tools'
            Packages    = @('visualstudio2022buildtools', 'nuget.commandline', 'make')
        }
        CloudTools          = @{
            Description = 'Cloud provider CLI tools'
            Packages    = @('awscli', 'azure-cli')
        }
        InfrastructureTools = @{
            Description = 'Infrastructure as code tools'
            Packages    = @('terraform')
        }
        Containers          = @{
            Description = 'Container runtime and orchestration'
            Packages    = @('docker-desktop', 'docker-compose', 'kubernetes-cli', 'kubernetes-helm')
        }
        Utilities           = @{
            Description = 'General build utilities'
            Packages    = @('7zip', 'jq', 'yq')
        }
        CodeQuality         = @{
            Description = 'Code analysis and quality tools'
            Packages    = @('sonarqube-scanner.portable')
        }
        DatabaseTools       = @{
            Description = 'Database management tools'
            Packages    = @('sql-server-management-studio', 'sqlcmd')
        }
    }
    #endregion

    #region Installation Profiles
    # Pre-defined package sets for different agent types
    Profiles = @{
        Minimal = @{
            Description = 'Minimal build agent with essential tools only'
            Packages    = @('git', 'powershell-core', '7zip')
        }
        DotNet  = @{
            Description = '.NET-focused build agent'
            Packages    = @(
                'git', 'gh', 'powershell-core', '7zip'
                'visualstudio2022buildtools', 'dotnet-sdk', 'nuget.commandline'
                'awscli', 'terraform'
            )
        }
        FullStack = @{
            Description = 'Full-stack development build agent'
            Packages    = @(
                'git', 'gh', 'powershell-core', '7zip'
                'visualstudio2022buildtools', 'dotnet-sdk', 'nuget.commandline'
                'nodejs-lts', 'python3'
                'awscli', 'terraform'
                'docker-desktop', 'docker-compose'
            )
        }
        CloudInfra = @{
            Description = 'Cloud infrastructure and DevOps agent'
            Packages    = @(
                'git', 'gh', 'powershell-core', '7zip'
                'awscli', 'azure-cli', 'terraform'
                'docker-desktop', 'kubernetes-cli', 'kubernetes-helm'
                'jq', 'yq'
            )
        }
    }
    #endregion

    #region Chocolatey Configuration
    # Chocolatey-specific settings
    ChocolateyConfig = @{
        # Installation directory
        InstallDir              = 'C:\ProgramData\chocolatey'

        # Cache location for downloaded packages
        CacheLocation           = 'C:\ProgramData\chocolatey\cache'

        # Command execution timeout (seconds)
        CommandTimeout          = 3600

        # Features to enable
        EnabledFeatures         = @(
            'usePackageExitCodes'
            'failOnAutoUninstaller'
            'allowGlobalConfirmation'
        )

        # Features to disable
        DisabledFeatures        = @(
            'showDownloadProgress'  # Cleaner CI/CD output
        )

        # Default package parameters
        DefaultParameters       = @(
            '--yes'
            '--no-progress'
            '--limit-output'
        )
    }
    #endregion
}
