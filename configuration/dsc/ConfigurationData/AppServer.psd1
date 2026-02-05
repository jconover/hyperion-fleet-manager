<#
.SYNOPSIS
    Configuration Data for Hyperion Fleet Manager App Server DSC Configuration.

.DESCRIPTION
    This PowerShell Data file (.psd1) contains all configuration settings for
    the AppServerConfiguration DSC configuration. It defines:

    - Node-specific settings for different environments
    - Application pool configurations
    - Certificate thumbprints and paths
    - Directory paths and naming conventions
    - Feature toggles and operational parameters

    The data is organized by environment (dev, staging, prod) with common
    settings inherited through the AllNodes structure.

.NOTES
    Author: Hyperion Fleet Manager Team
    Version: 1.0.0

    Security Note:
    - Certificate thumbprints should be retrieved from AWS Secrets Manager
      or Parameter Store in production deployments
    - Sensitive values marked with placeholders should be replaced during
      deployment via the Deploy-AppServerConfiguration.ps1 script

.EXAMPLE
    # Load configuration data
    $configData = Import-PowerShellDataFile -Path .\ConfigurationData\AppServer.psd1

    # Access node settings
    $configData.AllNodes | Where-Object { $_.Environment -eq 'prod' }

.LINK
    AppServerConfiguration.ps1
    Deploy-AppServerConfiguration.ps1
#>

@{
    # ==========================================================================
    # All Nodes Configuration
    # ==========================================================================
    # Settings defined here apply to all nodes unless overridden.
    # Node-specific settings are defined in the individual node blocks.
    # ==========================================================================

    AllNodes = @(

        # ======================================================================
        # Common Settings (Inherited by All Nodes)
        # ======================================================================
        @{
            # Node identifier - '*' means these settings apply to all nodes
            NodeName                    = '*'

            # ----------------------------------------------------------------------
            # Environment-Independent Settings
            # ----------------------------------------------------------------------

            # Roles assigned to this node type
            # Used for filtering in configuration: $AllNodes.Where({ $_.Role -contains 'AppServer' })
            Role                        = @('AppServer')

            # Application root directory (standardized across all environments)
            AppRootPath                 = 'D:\Applications\Hyperion'

            # IIS log directory (separate drive for log isolation)
            IISLogPath                  = 'D:\Logs\IIS'

            # Main application pool name
            MainAppPoolName             = 'HyperionAppPool'

            # Main website name in IIS
            MainSiteName                = 'HyperionFleetManager'

            # Health check endpoint port (internal, not exposed externally)
            HealthCheckPort             = 8080

            # Application pool memory limit (bytes) - 2 GB default
            # Triggers recycling when exceeded to prevent memory leaks
            AppPoolPrivateMemoryLimit   = 2147483648

            # ----------------------------------------------------------------------
            # SSL/TLS Certificate Configuration
            # ----------------------------------------------------------------------
            # Certificate thumbprint - MUST be replaced with actual value
            # Retrieve from AWS Secrets Manager or Parameter Store
            # Example: aws secretsmanager get-secret-value --secret-id hyperion/ssl-cert
            SSLCertificateThumbprint    = 'PLACEHOLDER_CERTIFICATE_THUMBPRINT'

            # Certificate store location
            CertificateStoreName        = 'My'

            # ----------------------------------------------------------------------
            # PSDscAllowPlainTextPassword / PSDscAllowDomainUser
            # ----------------------------------------------------------------------
            # SECURITY: These are set to $false for production security
            # If credentials are needed, use certificates for encryption
            PSDscAllowPlainTextPassword = $false
            PSDscAllowDomainUser        = $false

            # ----------------------------------------------------------------------
            # Reboot Handling
            # ----------------------------------------------------------------------
            # Allow DSC to request reboots if needed (Windows features may require)
            RebootNodeIfNeeded          = $true
        },

        # ======================================================================
        # Development Environment Nodes
        # ======================================================================
        @{
            # Node identifier for dev environment
            # Can be a specific hostname or a pattern matched during deployment
            NodeName                    = 'hyperion-app-dev-*'

            # Environment identifier
            Environment                 = 'dev'

            # ----------------------------------------------------------------------
            # Dev-Specific Application Settings
            # ----------------------------------------------------------------------

            # Host header for IIS binding (internal DNS)
            HostHeader                  = 'hyperion-dev.internal.example.com'

            # App pool start mode: OnDemand for dev (saves resources)
            AppPoolStartMode            = 'OnDemand'

            # Preloading disabled in dev (faster deployments)
            EnablePreload               = $false

            # Reduced memory limit for dev (500 MB)
            AppPoolPrivateMemoryLimit   = 524288000

            # ----------------------------------------------------------------------
            # Dev SSL Certificate
            # ----------------------------------------------------------------------
            # Use self-signed or internal CA certificate for dev
            SSLCertificateThumbprint    = 'DEV_CERTIFICATE_THUMBPRINT_PLACEHOLDER'

            # ----------------------------------------------------------------------
            # Dev-Specific Feature Flags
            # ----------------------------------------------------------------------

            # Enable detailed error pages in dev
            EnableDetailedErrors        = $true

            # Enable application initialization module
            EnableAppInitialization     = $false

            # Logging verbosity (debug level for dev)
            LoggingLevel                = 'Debug'

            # Allow credential prompts in dev (for testing)
            PSDscAllowPlainTextPassword = $true
        },

        # ======================================================================
        # Staging Environment Nodes
        # ======================================================================
        @{
            NodeName                    = 'hyperion-app-staging-*'
            Environment                 = 'staging'

            # ----------------------------------------------------------------------
            # Staging-Specific Application Settings
            # ----------------------------------------------------------------------

            HostHeader                  = 'hyperion-staging.internal.example.com'

            # AlwaysRunning for staging (mirrors production behavior)
            AppPoolStartMode            = 'AlwaysRunning'

            # Enable preloading for staging (test warm-up behavior)
            EnablePreload               = $true

            # Production-like memory limit (1.5 GB)
            AppPoolPrivateMemoryLimit   = 1610612736

            # ----------------------------------------------------------------------
            # Staging SSL Certificate
            # ----------------------------------------------------------------------
            SSLCertificateThumbprint    = 'STAGING_CERTIFICATE_THUMBPRINT_PLACEHOLDER'

            # ----------------------------------------------------------------------
            # Staging-Specific Feature Flags
            # ----------------------------------------------------------------------

            EnableDetailedErrors        = $false
            EnableAppInitialization     = $true
            LoggingLevel                = 'Information'
        },

        # ======================================================================
        # Production Environment Nodes
        # ======================================================================
        @{
            NodeName                    = 'hyperion-app-prod-*'
            Environment                 = 'prod'

            # ----------------------------------------------------------------------
            # Production-Specific Application Settings
            # ----------------------------------------------------------------------

            # Production host header (public or internal load balancer target)
            HostHeader                  = 'hyperion.example.com'

            # Always running for production (warm instances)
            AppPoolStartMode            = 'AlwaysRunning'

            # Full preloading enabled for production
            EnablePreload               = $true

            # Full memory allocation (2 GB)
            AppPoolPrivateMemoryLimit   = 2147483648

            # ----------------------------------------------------------------------
            # Production SSL Certificate
            # ----------------------------------------------------------------------
            # IMPORTANT: Replace with actual certificate thumbprint
            # Retrieved from AWS Certificate Manager or Secrets Manager
            SSLCertificateThumbprint    = 'PROD_CERTIFICATE_THUMBPRINT_PLACEHOLDER'

            # ----------------------------------------------------------------------
            # Production-Specific Feature Flags
            # ----------------------------------------------------------------------

            # Detailed errors DISABLED in production (security)
            EnableDetailedErrors        = $false

            # Application initialization ENABLED (warm-up on recycle)
            EnableAppInitialization     = $true

            # Warning level logging only in production
            LoggingLevel                = 'Warning'

            # ----------------------------------------------------------------------
            # Production High Availability Settings
            # ----------------------------------------------------------------------

            # Rapid fail protection thresholds (stricter in prod)
            RapidFailProtectionMaxCrashes   = 3
            RapidFailProtectionInterval     = '00:05:00'

            # Queue length (higher for production traffic)
            AppPoolQueueLength              = 2000

            # CPU throttling (stricter in production)
            CpuLimit                        = 70000  # 70%
        }
    )

    # ==========================================================================
    # Non-Node Data
    # ==========================================================================
    # Global settings not specific to any node. Accessed via $ConfigurationData
    # in the DSC configuration.
    # ==========================================================================

    NonNodeData = @{

        # ----------------------------------------------------------------------
        # Application Pool Definitions
        # ----------------------------------------------------------------------
        # Defines additional application pools beyond the main HyperionAppPool.
        # These can be created dynamically based on deployment requirements.
        # ----------------------------------------------------------------------
        ApplicationPools = @{

            # API Application Pool
            HyperionAPIPool = @{
                ManagedRuntimeVersion     = 'v4.0'
                ManagedPipelineMode       = 'Integrated'
                Enable32BitAppOnWin64     = $false
                IdentityType              = 'ApplicationPoolIdentity'
                IdleTimeout               = '00:20:00'
                MaxProcesses              = 2        # Multiple workers for API load
                PrivateMemoryLimit        = 1073741824  # 1 GB
                RecycleTime               = '02:00:00'  # 2 AM recycle
            }

            # Background Jobs Pool
            HyperionJobsPool = @{
                ManagedRuntimeVersion     = 'v4.0'
                ManagedPipelineMode       = 'Integrated'
                Enable32BitAppOnWin64     = $false
                IdentityType              = 'ApplicationPoolIdentity'
                IdleTimeout               = '00:00:00'  # Never idle (always processing)
                MaxProcesses              = 1
                PrivateMemoryLimit        = 536870912   # 512 MB
                RecycleTime               = '03:00:00'  # 3 AM recycle
            }

            # Static Content Pool
            HyperionStaticPool = @{
                ManagedRuntimeVersion     = ''          # No managed code
                ManagedPipelineMode       = 'Integrated'
                Enable32BitAppOnWin64     = $false
                IdentityType              = 'ApplicationPoolIdentity'
                IdleTimeout               = '00:05:00'
                MaxProcesses              = 1
                PrivateMemoryLimit        = 268435456   # 256 MB
            }
        }

        # ----------------------------------------------------------------------
        # IIS Site Definitions
        # ----------------------------------------------------------------------
        # Additional IIS sites that may be deployed alongside the main site.
        # ----------------------------------------------------------------------
        Sites = @{

            # API Site
            HyperionAPI = @{
                PhysicalPath        = 'D:\Applications\Hyperion\api'
                ApplicationPool     = 'HyperionAPIPool'
                Bindings            = @(
                    @{ Protocol = 'HTTPS'; Port = 443; HostHeader = 'api.hyperion.example.com' }
                )
            }

            # Admin Portal Site
            HyperionAdmin = @{
                PhysicalPath        = 'D:\Applications\Hyperion\admin'
                ApplicationPool     = 'HyperionAppPool'
                Bindings            = @(
                    @{ Protocol = 'HTTPS'; Port = 443; HostHeader = 'admin.hyperion.example.com' }
                )
            }
        }

        # ----------------------------------------------------------------------
        # Security Headers Configuration
        # ----------------------------------------------------------------------
        # HTTP security headers applied to all responses.
        # These values are used by the ConfigureSecurityHeaders script resource.
        # ----------------------------------------------------------------------
        SecurityHeaders = @{
            'X-Content-Type-Options'            = 'nosniff'
            'X-Frame-Options'                   = 'SAMEORIGIN'
            'X-XSS-Protection'                  = '1; mode=block'
            'Referrer-Policy'                   = 'strict-origin-when-cross-origin'
            'Permissions-Policy'                = 'geolocation=(), microphone=(), camera=()'
            'Strict-Transport-Security'         = 'max-age=31536000; includeSubDomains'
            'Content-Security-Policy'           = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'"
        }

        # ----------------------------------------------------------------------
        # Logging Configuration
        # ----------------------------------------------------------------------
        LoggingSettings = @{
            # Log retention (days)
            RetentionDays           = 30

            # Maximum log file size (bytes) - 100 MB
            MaxLogFileSize          = 104857600

            # Log fields to capture
            W3CLogFields            = @(
                'Date', 'Time', 'ClientIP', 'UserName', 'ServerIP', 'ServerPort',
                'Method', 'UriStem', 'UriQuery', 'HttpStatus', 'HttpSubStatus',
                'Win32Status', 'BytesSent', 'BytesRecv', 'TimeTaken', 'Host',
                'UserAgent', 'Referer', 'ProtocolVersion'
            )

            # Custom fields for AWS integration
            CustomLogFields         = @(
                @{ Name = 'X-Forwarded-For'; Source = 'X-Forwarded-For'; Type = 'RequestHeader' }
                @{ Name = 'X-Correlation-Id'; Source = 'X-Correlation-Id'; Type = 'RequestHeader' }
                @{ Name = 'X-Amzn-Trace-Id'; Source = 'X-Amzn-Trace-Id'; Type = 'RequestHeader' }
            )
        }

        # ----------------------------------------------------------------------
        # Request Filtering Settings
        # ----------------------------------------------------------------------
        RequestFiltering = @{
            # Maximum content length (30 MB)
            MaxAllowedContentLength = 31457280

            # Maximum URL length
            MaxUrl                  = 4096

            # Maximum query string length
            MaxQueryString          = 2048

            # Denied URL sequences (security)
            DenyUrlSequences        = @('..', './', '\', '%00', '%2e%2e')

            # Denied file extensions
            DenyFileExtensions      = @(
                '.exe', '.dll', '.config', '.mdf', '.ldf',
                '.ini', '.bat', '.cmd', '.vbs', '.ps1', '.psm1'
            )

            # Denied HTTP verbs
            DenyVerbs               = @('TRACE', 'TRACK', 'DEBUG')
        }

        # ----------------------------------------------------------------------
        # Windows Services Configuration
        # ----------------------------------------------------------------------
        WindowsServices = @{

            # Background processing service
            HyperionBackgroundService = @{
                DisplayName         = 'Hyperion Background Service'
                Description         = 'Handles asynchronous tasks and scheduled jobs for Hyperion Fleet Manager'
                StartupType         = 'Automatic'
                # Path is set during application deployment
                BinaryPath          = 'D:\Applications\Hyperion\services\HyperionBackgroundService.exe'

                # Recovery options
                FirstFailureAction  = 'Restart'
                SecondFailureAction = 'Restart'
                SubsequentAction    = 'Restart'
                ResetPeriodDays     = 1
                RestartDelayMs      = 60000
            }

            # Health monitoring agent
            HyperionHealthAgent = @{
                DisplayName         = 'Hyperion Health Agent'
                Description         = 'Collects health metrics and reports to CloudWatch'
                StartupType         = 'Automatic'
                BinaryPath          = 'D:\Applications\Hyperion\services\HyperionHealthAgent.exe'

                FirstFailureAction  = 'Restart'
                SecondFailureAction = 'Restart'
                SubsequentAction    = 'Restart'
                ResetPeriodDays     = 1
                RestartDelayMs      = 30000
            }
        }

        # ----------------------------------------------------------------------
        # Performance Monitoring Settings
        # ----------------------------------------------------------------------
        PerformanceCounters = @{

            # IIS Counters
            IISCounters = @(
                '\Web Service(_Total)\Current Connections'
                '\Web Service(_Total)\Total Method Requests/sec'
                '\Web Service(_Total)\Get Requests/sec'
                '\Web Service(_Total)\Post Requests/sec'
                '\Web Service(_Total)\Bytes Sent/sec'
                '\Web Service(_Total)\Bytes Received/sec'
            )

            # ASP.NET Counters
            ASPNETCounters = @(
                '\ASP.NET\Application Restarts'
                '\ASP.NET\Request Execution Time'
                '\ASP.NET\Requests Queued'
                '\ASP.NET\Requests Rejected'
                '\ASP.NET\Request Wait Time'
                '\ASP.NET Applications(__Total__)\Requests/Sec'
                '\ASP.NET Applications(__Total__)\Errors Total/Sec'
            )

            # Application Pool Counters
            AppPoolCounters = @(
                '\Process(w3wp*)\% Processor Time'
                '\Process(w3wp*)\Private Bytes'
                '\Process(w3wp*)\Virtual Bytes'
                '\Process(w3wp*)\Handle Count'
                '\Process(w3wp*)\Thread Count'
            )

            # System Counters
            SystemCounters = @(
                '\Processor(_Total)\% Processor Time'
                '\Memory\Available MBytes'
                '\Memory\% Committed Bytes In Use'
                '\LogicalDisk(D:)\% Free Space'
                '\LogicalDisk(D:)\Avg. Disk Queue Length'
            )
        }

        # ----------------------------------------------------------------------
        # TLS Configuration
        # ----------------------------------------------------------------------
        TLSSettings = @{
            # Protocols to disable
            DisabledProtocols       = @('SSL 2.0', 'SSL 3.0', 'TLS 1.0', 'TLS 1.1')

            # Protocols to enable
            EnabledProtocols        = @('TLS 1.2', 'TLS 1.3')

            # Preferred cipher suites (in order of preference)
            CipherSuites            = @(
                'TLS_AES_256_GCM_SHA384'
                'TLS_AES_128_GCM_SHA256'
                'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384'
                'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256'
                'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
                'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
            )
        }

        # ----------------------------------------------------------------------
        # Directory Permissions
        # ----------------------------------------------------------------------
        DirectoryPermissions = @{
            # Application root - IIS_IUSRS needs read
            AppRoot         = @{ Principal = 'IIS_IUSRS'; Rights = 'Read' }

            # Web content - IIS_IUSRS needs read/execute
            WebContent      = @{ Principal = 'IIS_IUSRS'; Rights = 'ReadAndExecute' }

            # Logs directory - IIS_IUSRS needs modify for writing logs
            Logs            = @{ Principal = 'IIS_IUSRS'; Rights = 'Modify' }

            # Temp directory - IIS_IUSRS needs full control for temp files
            Temp            = @{ Principal = 'IIS_IUSRS'; Rights = 'FullControl' }

            # Config directory - restricted to administrators
            Config          = @{ Principal = 'Administrators'; Rights = 'FullControl' }
        }
    }
}
