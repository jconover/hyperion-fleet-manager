<#
.SYNOPSIS
    DSC Configuration Data for Hyperion Fleet Manager Baseline

.DESCRIPTION
    This file contains the configuration data used by the HyperionBaselineConfiguration.
    It defines node-specific settings, environment overrides, and common configuration values.

    Configuration data is separated from the configuration logic to enable:
    - Environment-specific deployments (Dev, Staging, Production)
    - Node-specific customizations
    - Credential encryption via certificates
    - Easy maintenance and updates

.NOTES
    Project: Hyperion Fleet Manager
    Version: 1.0.0
    Author: Infrastructure Team

    IMPORTANT: Update certificate thumbprints before deployment!
    IMPORTANT: Review and customize node names for your environment!

.LINK
    https://docs.microsoft.com/en-us/powershell/scripting/dsc/configurations/configdata
#>

@{
    #region AllNodes Configuration
    # AllNodes contains node-specific configuration settings
    # Each node entry represents a target server for DSC configuration

    AllNodes = @(
        #region Default Node Settings
        # The '*' NodeName applies settings to ALL nodes as defaults
        # Individual nodes can override these settings
        @{
            # Special wildcard - applies to all nodes
            NodeName                    = '*'

            # Role assignment - used for conditional configuration
            Role                        = 'WindowsServer'

            # PSDscAllowPlainTextPassword - MUST be $false in production
            # Set to $true only for testing without certificates
            PSDscAllowPlainTextPassword = $false

            # PSDscAllowDomainUser - allows domain credentials
            PSDscAllowDomainUser        = $true

            # Certificate configuration for credential encryption
            # Replace with your document encryption certificate thumbprint
            # To generate a certificate for DSC:
            # New-SelfSignedCertificate -Type DocumentEncryptionCertLegacyCsp `
            #     -DnsName 'DscEncryptionCert' `
            #     -HashAlgorithm SHA256 `
            #     -KeyLength 2048 `
            #     -NotAfter (Get-Date).AddYears(5)
            CertificateFile             = 'C:\DscCertificates\DscPublicKey.cer'

            # Thumbprint of the certificate used to decrypt credentials on target node
            # IMPORTANT: Replace with actual certificate thumbprint!
            Thumbprint                  = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'

            # Reboot behavior
            RebootNodeIfNeeded          = $true

            # Configuration mode
            # ApplyOnly - Apply configuration once
            # ApplyAndMonitor - Apply and report drift
            # ApplyAndAutoCorrect - Apply and automatically fix drift
            ConfigurationMode           = 'ApplyAndAutoCorrect'

            # How often (in minutes) to check for configuration drift
            ConfigurationModeFrequencyMins = 30

            # How often (in minutes) to refresh configuration from pull server
            RefreshFrequencyMins        = 30

            # Action after reboot
            ActionAfterReboot           = 'ContinueConfiguration'

            # Allow module overwrite during pull
            AllowModuleOverwrite        = $true

            # Debug mode - set to $true for troubleshooting
            DebugMode                   = 'None'  # None, ForceModuleImport, All
        }
        #endregion

        #region Development Environment Nodes
        @{
            NodeName    = 'YOURCOMPUTER'  # Placeholder node - used for testing
            Environment = 'Development'
            Role        = 'WindowsServer'

            # Development can use plain text passwords for testing
            # NEVER use this in production!
            PSDscAllowPlainTextPassword = $true

            # Development-specific settings
            RebootNodeIfNeeded          = $false
            ConfigurationMode           = 'ApplyAndMonitor'
        }

        # Add development servers here
        # @{
        #     NodeName    = 'DEV-WEB-01'
        #     Environment = 'Development'
        #     Role        = 'WindowsServer'
        # }
        #endregion

        #region Staging Environment Nodes
        # @{
        #     NodeName    = 'STG-WEB-01'
        #     Environment = 'Staging'
        #     Role        = 'WindowsServer'
        #     Thumbprint  = 'STAGING-CERT-THUMBPRINT-HERE'
        # }
        #
        # @{
        #     NodeName    = 'STG-APP-01'
        #     Environment = 'Staging'
        #     Role        = 'WindowsServer'
        #     Thumbprint  = 'STAGING-CERT-THUMBPRINT-HERE'
        # }
        #endregion

        #region Production Environment Nodes
        # Production servers should have individual certificate thumbprints
        # for maximum security

        # @{
        #     NodeName    = 'PRD-WEB-01'
        #     Environment = 'Production'
        #     Role        = 'WindowsServer'
        #     Thumbprint  = 'PRODUCTION-CERT-THUMBPRINT-01'
        #
        #     # Production-specific overrides
        #     ConfigurationMode           = 'ApplyAndAutoCorrect'
        #     ConfigurationModeFrequencyMins = 15
        # }
        #
        # @{
        #     NodeName    = 'PRD-WEB-02'
        #     Environment = 'Production'
        #     Role        = 'WindowsServer'
        #     Thumbprint  = 'PRODUCTION-CERT-THUMBPRINT-02'
        # }
        #
        # @{
        #     NodeName    = 'PRD-DC-01'
        #     Environment = 'Production'
        #     Role        = 'DomainController'
        #     Thumbprint  = 'PRODUCTION-DC-CERT-THUMBPRINT'
        # }
        #endregion
    )
    #endregion

    #region NonNodeData - Common Configuration Settings
    # NonNodeData contains settings that apply across all nodes
    # These are not node-specific but configuration-wide values

    NonNodeData = @{

        #region Environment Configuration
        Environment = @{
            # Default environment if not specified per-node
            Default = 'Development'

            # Environment-specific settings
            Development = @{
                NtpServer           = 'time.windows.com'
                EnableDebugLogging  = $true
                StrictMode          = $false
            }

            Staging = @{
                NtpServer           = 'time.aws.com'
                EnableDebugLogging  = $true
                StrictMode          = $true
            }

            Production = @{
                NtpServer           = 'time.aws.com'
                EnableDebugLogging  = $false
                StrictMode          = $true
            }
        }
        #endregion

        #region Security Settings
        Security = @{
            # TLS/SSL Configuration
            TLS = @{
                # Minimum TLS version (1.2 recommended, 1.3 if supported)
                MinimumVersion      = '1.2'
                DisableSSL2         = $true
                DisableSSL3         = $true
                DisableTLS10        = $true
                DisableTLS11        = $true
                EnableTLS12         = $true
                EnableTLS13         = $true
            }

            # Password Policy (CIS Benchmark aligned)
            PasswordPolicy = @{
                MinimumLength       = 14
                PasswordHistory     = 24
                MaximumAge          = 365
                MinimumAge          = 1
                ComplexityEnabled   = $true
                ReversibleEncryption = $false
            }

            # Account Lockout Policy
            AccountLockout = @{
                Threshold           = 5
                Duration            = 15
                ResetCounter        = 15
            }

            # Accounts to disable
            DisabledAccounts = @(
                'Guest'
            )

            # Local Administrators Group Members
            # Define who should be in the local Administrators group
            LocalAdministrators = @(
                'BUILTIN\Administrators'
                # Add domain groups as needed:
                # 'DOMAIN\ServerAdmins'
                # 'DOMAIN\IT-Operations'
            )

            # Services to disable (reduces attack surface)
            DisabledServices = @(
                'Spooler'           # Print Spooler - disable if not needed
                'RemoteRegistry'    # Remote Registry
                'WerSvc'            # Windows Error Reporting
                'WSearch'           # Windows Search
                # Add more services as needed
            )

            # Services that must be running
            RequiredServices = @(
                'W32Time'           # Windows Time
                'EventLog'          # Windows Event Log
                'WinDefend'         # Windows Defender
                'MpsSvc'            # Windows Firewall
            )
        }
        #endregion

        #region Firewall Configuration
        Firewall = @{
            # Enable firewall for all profiles
            DomainProfile = @{
                Enabled             = $true
                DefaultInbound      = 'Block'
                DefaultOutbound     = 'Allow'
                LogDroppedPackets   = $true
                LogSuccessful       = $true
                LogFileSizeKB       = 16384
            }

            PrivateProfile = @{
                Enabled             = $true
                DefaultInbound      = 'Block'
                DefaultOutbound     = 'Allow'
                LogDroppedPackets   = $true
                LogSuccessful       = $false
                LogFileSizeKB       = 16384
            }

            PublicProfile = @{
                Enabled             = $true
                DefaultInbound      = 'Block'
                DefaultOutbound     = 'Allow'
                LogDroppedPackets   = $true
                LogSuccessful       = $false
                LogFileSizeKB       = 16384
            }
        }
        #endregion

        #region Audit Policy Configuration
        AuditPolicy = @{
            # Subcategories to audit (Success, Failure, or both)
            Categories = @{
                # Account Logon
                'Credential Validation'                 = 'Success and Failure'
                'Kerberos Authentication Service'       = 'Success and Failure'
                'Kerberos Service Ticket Operations'    = 'Success and Failure'

                # Account Management
                'Security Group Management'             = 'Success'
                'User Account Management'               = 'Success and Failure'

                # Logon/Logoff
                'Account Lockout'                       = 'Failure'
                'Logoff'                                = 'Success'
                'Logon'                                 = 'Success and Failure'
                'Special Logon'                         = 'Success'

                # Object Access
                'Removable Storage'                     = 'Success and Failure'

                # Policy Change
                'Authentication Policy Change'          = 'Success'
                'Authorization Policy Change'           = 'Success'
                'Audit Policy Change'                   = 'Success'

                # Privilege Use
                'Sensitive Privilege Use'               = 'Success and Failure'

                # System
                'Security State Change'                 = 'Success'
                'Security System Extension'             = 'Success'
                'System Integrity'                      = 'Success and Failure'

                # Detailed Tracking
                'Process Creation'                      = 'Success'
            }

            # Enable command line logging in process creation events
            ProcessCommandLine = $true
        }
        #endregion

        #region Event Log Configuration
        EventLogs = @{
            # Event log size and retention settings
            Security = @{
                MaxSizeKB           = 196608    # 192 MB
                RetentionDays       = 0         # Overwrite as needed
            }

            Application = @{
                MaxSizeKB           = 32768     # 32 MB
                RetentionDays       = 0
            }

            System = @{
                MaxSizeKB           = 32768     # 32 MB
                RetentionDays       = 0
            }

            Setup = @{
                MaxSizeKB           = 32768     # 32 MB
                RetentionDays       = 0
            }

            PowerShell = @{
                MaxSizeKB           = 32768     # 32 MB
                RetentionDays       = 0
            }
        }
        #endregion

        #region Time Synchronization
        TimeSync = @{
            # Primary NTP server (AWS time server recommended for AWS workloads)
            NtpServer           = 'time.aws.com'

            # Backup NTP servers
            BackupNtpServers    = @(
                'time.windows.com'
                '0.pool.ntp.org'
                '1.pool.ntp.org'
            )

            # Poll interval in seconds
            PollIntervalSeconds = 3600          # 1 hour

            # Sync type
            Type                = 'NTP'
        }
        #endregion

        #region PowerShell Configuration
        PowerShell = @{
            # Script block logging
            ScriptBlockLogging      = $true

            # Transcription
            Transcription = @{
                Enabled             = $true
                OutputDirectory     = 'C:\ProgramData\PowerShellTranscripts'
                IncludeInvocationHeader = $true
            }

            # Module logging
            ModuleLogging = @{
                Enabled             = $true
                # Modules to log (* for all)
                ModuleNames         = @('*')
            }
        }
        #endregion

        #region Windows Defender Configuration
        Defender = @{
            RealTimeProtection      = $true
            BehaviorMonitoring      = $true
            IOAVProtection          = $true
            ScriptScanning          = $true
            AntiSpyware             = $true

            # Potentially Unwanted Application (PUA) protection
            # 0 = Disabled, 1 = Block, 2 = Audit
            PUAProtection           = 1

            # Cloud protection level
            # 0 = Default, 1 = Moderate, 2 = High, 4 = High+, 6 = Zero tolerance
            CloudBlockLevel         = 2

            # Sample submission
            # 0 = Always prompt, 1 = Send safe samples, 2 = Never send, 3 = Send all
            SubmitSamplesConsent    = 1
        }
        #endregion

        #region Paths and Directories
        Paths = @{
            # PowerShell transcript output
            TranscriptOutput        = 'C:\ProgramData\PowerShellTranscripts'

            # DSC configuration output
            DscOutput               = 'C:\DscConfigurations'

            # Certificate storage
            Certificates            = 'C:\DscCertificates'

            # Firewall log directory
            FirewallLogs            = '%systemroot%\system32\logfiles\firewall'
        }
        #endregion

        #region Metadata
        Metadata = @{
            # Configuration version for tracking
            Version                 = '1.0.0'

            # Last updated date
            LastUpdated             = '2024-12-15'

            # Author/maintainer
            Author                  = 'Infrastructure Team'

            # Reference documentation
            CISBenchmark            = 'CIS Microsoft Windows Server 2022 Benchmark v2.0.0'

            # Project information
            Project                 = 'Hyperion Fleet Manager'
        }
        #endregion
    }
    #endregion
}
