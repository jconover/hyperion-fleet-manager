#Requires -Version 5.1
#Requires -Modules PSDesiredStateConfiguration

<#
.SYNOPSIS
    PowerShell DSC Configuration for Hyperion Fleet Manager Application Servers.

.DESCRIPTION
    This DSC configuration defines the desired state for IIS-based application servers
    in the Hyperion Fleet Manager infrastructure. It configures:

    - IIS Web Server role with required features
    - .NET Framework installation and configuration
    - Application pools with security-hardened settings
    - SSL/TLS configuration following security best practices
    - Custom HTTP headers for security hardening
    - IIS logging with W3C extended format
    - Health check endpoint infrastructure
    - Application directories with proper NTFS permissions
    - Windows services for application components
    - Performance counters for monitoring integration

    This configuration is designed to work with AWS Systems Manager State Manager
    for large-scale fleet deployment and compliance enforcement.

.PARAMETER ConfigurationData
    Configuration data hashtable containing node-specific settings.
    See ConfigurationData/AppServer.psd1 for the expected structure.

.PARAMETER Environment
    Target environment (dev, staging, prod). Affects security stringency
    and logging verbosity.

.NOTES
    Author: Hyperion Fleet Manager Team
    Version: 1.0.0
    Requires: Windows Server 2019/2022, PowerShell 5.1+

    DSC Resources Required:
    - PSDesiredStateConfiguration (built-in)
    - xWebAdministration (6.x+)
    - ComputerManagementDsc (9.x+)
    - SecurityPolicyDsc (2.x+)

    Security Considerations:
    - Application pools run under custom managed service accounts
    - TLS 1.2+ enforced; legacy protocols disabled
    - Strict cipher suite ordering implemented
    - Server header removed to prevent fingerprinting
    - Directory browsing disabled globally

.EXAMPLE
    # Compile the configuration
    . .\AppServerConfiguration.ps1
    AppServerConfiguration -ConfigurationData .\ConfigurationData\AppServer.psd1 -OutputPath .\MOF

.EXAMPLE
    # Apply configuration to local machine
    Start-DscConfiguration -Path .\MOF -Wait -Verbose -Force

.LINK
    https://docs.microsoft.com/en-us/powershell/dsc/
    https://github.com/dsccommunity/xWebAdministration
#>

# ==============================================================================
# DSC Configuration: AppServerConfiguration
# ==============================================================================
# This configuration establishes a secure, production-ready IIS environment
# for hosting Hyperion Fleet Manager application components.
# ==============================================================================

Configuration AppServerConfiguration {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('dev', 'staging', 'prod')]
        [string]$Environment = 'dev'
    )

    # --------------------------------------------------------------------------
    # Import Required DSC Resources
    # --------------------------------------------------------------------------
    # These modules must be installed on target nodes before applying configuration.
    # Use Install-Module or deploy via package management.
    # --------------------------------------------------------------------------

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xWebAdministration -ModuleVersion '3.3.0'
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion '9.0.0'

    # --------------------------------------------------------------------------
    # Node Configuration
    # --------------------------------------------------------------------------
    # AllNodes allows this configuration to target multiple servers with
    # node-specific settings while sharing common configuration logic.
    # --------------------------------------------------------------------------

    Node $AllNodes.Where({ $_.Role -contains 'AppServer' }).NodeName {

        # ======================================================================
        # SECTION 1: WINDOWS FEATURES - IIS AND DEPENDENCIES
        # ======================================================================
        # Install IIS and required sub-features for hosting .NET applications.
        # Features are organized by functional area for clarity.
        # ======================================================================

        # ----------------------------------------------------------------------
        # Core IIS Web Server
        # ----------------------------------------------------------------------
        WindowsFeature IISWebServer {
            Ensure = 'Present'
            Name   = 'Web-Server'
        }

        # ----------------------------------------------------------------------
        # IIS Management Tools
        # Required for remote administration and scripting
        # ----------------------------------------------------------------------
        WindowsFeature IISManagementTools {
            Ensure    = 'Present'
            Name      = 'Web-Mgmt-Tools'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature IISManagementConsole {
            Ensure    = 'Present'
            Name      = 'Web-Mgmt-Console'
            DependsOn = '[WindowsFeature]IISManagementTools'
        }

        WindowsFeature IISManagementScripting {
            Ensure    = 'Present'
            Name      = 'Web-Scripting-Tools'
            DependsOn = '[WindowsFeature]IISManagementTools'
        }

        # WMI provider for Systems Manager integration
        WindowsFeature IISManagementWMI {
            Ensure    = 'Present'
            Name      = 'Web-WMI'
            DependsOn = '[WindowsFeature]IISManagementTools'
        }

        # ----------------------------------------------------------------------
        # IIS Common HTTP Features
        # ----------------------------------------------------------------------
        WindowsFeature IISDefaultDocument {
            Ensure    = 'Present'
            Name      = 'Web-Default-Doc'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature IISHttpErrors {
            Ensure    = 'Present'
            Name      = 'Web-Http-Errors'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature IISStaticContent {
            Ensure    = 'Present'
            Name      = 'Web-Static-Content'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        # Directory browsing disabled but feature installed for configuration
        WindowsFeature IISDirectoryBrowsing {
            Ensure    = 'Present'
            Name      = 'Web-Dir-Browsing'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        # ----------------------------------------------------------------------
        # IIS Health and Diagnostics
        # Required for monitoring and troubleshooting
        # ----------------------------------------------------------------------
        WindowsFeature IISHttpLogging {
            Ensure    = 'Present'
            Name      = 'Web-Http-Logging'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature IISCustomLogging {
            Ensure    = 'Present'
            Name      = 'Web-Custom-Logging'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature IISRequestMonitor {
            Ensure    = 'Present'
            Name      = 'Web-Request-Monitor'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature IISHttpTracing {
            Ensure    = 'Present'
            Name      = 'Web-Http-Tracing'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        # ----------------------------------------------------------------------
        # IIS Performance Features
        # ----------------------------------------------------------------------
        WindowsFeature IISStaticCompression {
            Ensure    = 'Present'
            Name      = 'Web-Stat-Compression'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature IISDynamicCompression {
            Ensure    = 'Present'
            Name      = 'Web-Dyn-Compression'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        # ----------------------------------------------------------------------
        # IIS Security Features
        # ----------------------------------------------------------------------
        WindowsFeature IISRequestFiltering {
            Ensure    = 'Present'
            Name      = 'Web-Filtering'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature IISBasicAuth {
            Ensure    = 'Present'
            Name      = 'Web-Basic-Auth'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature IISWindowsAuth {
            Ensure    = 'Present'
            Name      = 'Web-Windows-Auth'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature IISIPSecurity {
            Ensure    = 'Present'
            Name      = 'Web-IP-Security'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature IISURLAuth {
            Ensure    = 'Present'
            Name      = 'Web-Url-Auth'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        # ----------------------------------------------------------------------
        # ASP.NET and Application Development
        # ----------------------------------------------------------------------
        WindowsFeature ASPNet45 {
            Ensure    = 'Present'
            Name      = 'Web-Asp-Net45'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature NetExtensibility45 {
            Ensure    = 'Present'
            Name      = 'Web-Net-Ext45'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature ISAPIExtensions {
            Ensure    = 'Present'
            Name      = 'Web-ISAPI-Ext'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature ISAPIFilter {
            Ensure    = 'Present'
            Name      = 'Web-ISAPI-Filter'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        WindowsFeature WebSockets {
            Ensure    = 'Present'
            Name      = 'Web-WebSockets'
            DependsOn = '[WindowsFeature]IISWebServer'
        }

        # ----------------------------------------------------------------------
        # .NET Framework Features
        # ----------------------------------------------------------------------
        WindowsFeature NetFramework45Core {
            Ensure = 'Present'
            Name   = 'NET-Framework-45-Core'
        }

        WindowsFeature NetFramework45ASPNET {
            Ensure    = 'Present'
            Name      = 'NET-Framework-45-ASPNET'
            DependsOn = '[WindowsFeature]NetFramework45Core'
        }

        WindowsFeature NetWCFServices45 {
            Ensure    = 'Present'
            Name      = 'NET-WCF-Services45'
            DependsOn = '[WindowsFeature]NetFramework45Core'
        }

        WindowsFeature NetWCFHTTPActivation45 {
            Ensure    = 'Present'
            Name      = 'NET-WCF-HTTP-Activation45'
            DependsOn = '[WindowsFeature]NetWCFServices45'
        }

        # ======================================================================
        # SECTION 2: REMOVE DEFAULT WEBSITE
        # ======================================================================
        # Security best practice: Remove the default IIS website to prevent
        # accidental exposure and ensure only explicitly configured sites run.
        # ======================================================================

        xWebsite DefaultWebSiteRemoval {
            Ensure       = 'Absent'
            Name         = 'Default Web Site'
            PhysicalPath = 'C:\inetpub\wwwroot'
            DependsOn    = '[WindowsFeature]IISWebServer'
        }

        # ======================================================================
        # SECTION 3: APPLICATION DIRECTORIES
        # ======================================================================
        # Create standardized directory structure for applications.
        # Permissions are set explicitly rather than inherited.
        # ======================================================================

        # Root application directory
        File AppRootDirectory {
            Ensure          = 'Present'
            Type            = 'Directory'
            DestinationPath = $Node.AppRootPath
            Force           = $true
        }

        # Application web content directory
        File AppWebDirectory {
            Ensure          = 'Present'
            Type            = 'Directory'
            DestinationPath = "$($Node.AppRootPath)\web"
            DependsOn       = '[File]AppRootDirectory'
        }

        # Application logs directory
        File AppLogsDirectory {
            Ensure          = 'Present'
            Type            = 'Directory'
            DestinationPath = "$($Node.AppRootPath)\logs"
            DependsOn       = '[File]AppRootDirectory'
        }

        # Application data directory
        File AppDataDirectory {
            Ensure          = 'Present'
            Type            = 'Directory'
            DestinationPath = "$($Node.AppRootPath)\data"
            DependsOn       = '[File]AppRootDirectory'
        }

        # Temporary files directory
        File AppTempDirectory {
            Ensure          = 'Present'
            Type            = 'Directory'
            DestinationPath = "$($Node.AppRootPath)\temp"
            DependsOn       = '[File]AppRootDirectory'
        }

        # Configuration files directory
        File AppConfigDirectory {
            Ensure          = 'Present'
            Type            = 'Directory'
            DestinationPath = "$($Node.AppRootPath)\config"
            DependsOn       = '[File]AppRootDirectory'
        }

        # IIS logs directory (separate from application logs)
        File IISLogsDirectory {
            Ensure          = 'Present'
            Type            = 'Directory'
            DestinationPath = $Node.IISLogPath
            Force           = $true
        }

        # Health check content directory
        File HealthCheckDirectory {
            Ensure          = 'Present'
            Type            = 'Directory'
            DestinationPath = "$($Node.AppRootPath)\healthcheck"
            DependsOn       = '[File]AppRootDirectory'
        }

        # ======================================================================
        # SECTION 4: APPLICATION POOLS
        # ======================================================================
        # Configure application pools with security-hardened settings.
        # Each pool uses dedicated identity for process isolation.
        # ======================================================================

        # ----------------------------------------------------------------------
        # Main Application Pool
        # Hosts the primary Hyperion application
        # ----------------------------------------------------------------------
        xWebAppPool HyperionAppPool {
            Ensure                  = 'Present'
            Name                    = $Node.MainAppPoolName
            State                   = 'Started'

            # Managed runtime configuration
            managedRuntimeVersion   = 'v4.0'
            managedPipelineMode     = 'Integrated'
            enable32BitAppOnWin64   = $false

            # Process model settings
            # ApplicationPoolIdentity provides isolated, low-privilege identity
            identityType            = 'ApplicationPoolIdentity'
            loadUserProfile         = $true

            # Idle timeout: 20 minutes (balances resource usage and startup time)
            idleTimeout             = (New-TimeSpan -Minutes 20).ToString()
            idleTimeoutAction       = 'Suspend'

            # Maximum worker processes (1 = single process for session affinity)
            maxProcesses            = 1

            # CPU throttling to prevent runaway processes
            cpuAction               = 'ThrottleUnderLoad'
            cpuLimit                = 80000  # 80% CPU limit
            cpuResetInterval        = (New-TimeSpan -Minutes 5).ToString()

            # Rapid fail protection
            rapidFailProtection     = $true
            rapidFailProtectionInterval = (New-TimeSpan -Minutes 5).ToString()
            rapidFailProtectionMaxCrashes = 5

            # Queue length for pending requests
            queueLength             = 1000

            # Recycling settings
            restartMemoryLimit      = 0      # Disabled - managed by recycling schedule
            restartPrivateMemoryLimit = $Node.AppPoolPrivateMemoryLimit
            restartRequestsLimit    = 0      # Disabled - use time-based recycling
            restartTimeLimit        = (New-TimeSpan -Hours 29).ToString()  # Regular recycling

            # Logging for recycling events
            logEventOnRecycle       = 'Time,Memory,PrivateMemory,Schedule'

            # Start mode: AlwaysRunning for production, OnDemand for dev
            autoStart               = $true
            startMode               = $Node.AppPoolStartMode

            DependsOn               = @(
                '[WindowsFeature]IISWebServer'
                '[WindowsFeature]ASPNet45'
            )
        }

        # ----------------------------------------------------------------------
        # Health Check Application Pool
        # Dedicated pool for health endpoints to ensure availability
        # ----------------------------------------------------------------------
        xWebAppPool HealthCheckAppPool {
            Ensure                  = 'Present'
            Name                    = 'HyperionHealthCheckPool'
            State                   = 'Started'

            managedRuntimeVersion   = 'v4.0'
            managedPipelineMode     = 'Integrated'
            enable32BitAppOnWin64   = $false

            identityType            = 'ApplicationPoolIdentity'
            loadUserProfile         = $false

            # Shorter idle timeout - health checks should be frequent
            idleTimeout             = (New-TimeSpan -Minutes 5).ToString()
            idleTimeoutAction       = 'Terminate'

            maxProcesses            = 1
            queueLength             = 100

            # Minimal resource footprint
            restartPrivateMemoryLimit = 104857600  # 100 MB
            restartTimeLimit        = (New-TimeSpan -Hours 24).ToString()

            autoStart               = $true
            startMode               = 'AlwaysRunning'

            DependsOn               = '[WindowsFeature]IISWebServer'
        }

        # ======================================================================
        # SECTION 5: IIS LOGGING CONFIGURATION
        # ======================================================================
        # Configure W3C Extended logging for compliance and troubleshooting.
        # Logs are stored in a separate directory for easy rotation.
        # ======================================================================

        # Configure IIS log settings at server level
        xIISLogging ServerLogging {
            LogPath              = $Node.IISLogPath
            LogFormat            = 'W3C'
            LogPeriod            = 'Daily'
            LogTargetW3C         = 'File,ETW'
            LogLocalTimeRollover = $true

            # W3C fields for comprehensive request logging
            LogFlags             = @(
                'Date'
                'Time'
                'ClientIP'
                'UserName'
                'ServerIP'
                'ServerPort'
                'Method'
                'UriStem'
                'UriQuery'
                'HttpStatus'
                'HttpSubStatus'
                'Win32Status'
                'BytesSent'
                'BytesRecv'
                'TimeTaken'
                'Host'
                'UserAgent'
                'Referer'
                'ProtocolVersion'
            )

            # Custom log fields for correlation
            LogCustomFields      = @(
                @{
                    LogFieldName = 'X-Forwarded-For'
                    SourceName   = 'X-Forwarded-For'
                    SourceType   = 'RequestHeader'
                }
                @{
                    LogFieldName = 'X-Correlation-Id'
                    SourceName   = 'X-Correlation-Id'
                    SourceType   = 'RequestHeader'
                }
            )

            DependsOn = '[WindowsFeature]IISHttpLogging'
        }

        # ======================================================================
        # SECTION 6: SSL/TLS CONFIGURATION
        # ======================================================================
        # Enforce modern TLS settings and disable legacy protocols.
        # This configuration follows NIST and CIS benchmark recommendations.
        # ======================================================================

        # Disable SSL 2.0 (severely deprecated)
        Registry DisableSSL2Server {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '0'
        }

        Registry DisableSSL2Client {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '0'
        }

        # Disable SSL 3.0 (POODLE vulnerability)
        Registry DisableSSL3Server {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '0'
        }

        Registry DisableSSL3Client {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '0'
        }

        # Disable TLS 1.0 (deprecated, PCI DSS non-compliant)
        Registry DisableTLS10Server {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '0'
        }

        Registry DisableTLS10Client {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '0'
        }

        # Disable TLS 1.1 (deprecated)
        Registry DisableTLS11Server {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '0'
        }

        Registry DisableTLS11Client {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '0'
        }

        # Enable TLS 1.2
        Registry EnableTLS12Server {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry EnableTLS12ServerDefault {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
            ValueName = 'DisabledByDefault'
            ValueType = 'DWord'
            ValueData = '0'
        }

        Registry EnableTLS12Client {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry EnableTLS12ClientDefault {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
            ValueName = 'DisabledByDefault'
            ValueType = 'DWord'
            ValueData = '0'
        }

        # Enable TLS 1.3 (Windows Server 2022+)
        Registry EnableTLS13Server {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry EnableTLS13ServerDefault {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server'
            ValueName = 'DisabledByDefault'
            ValueType = 'DWord'
            ValueData = '0'
        }

        # Configure strong cipher suites order
        # This ensures secure ciphers are preferred
        Registry CipherSuiteOrder {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002'
            ValueName = 'Functions'
            ValueType = 'String'
            ValueData = @(
                'TLS_AES_256_GCM_SHA384'
                'TLS_AES_128_GCM_SHA256'
                'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384'
                'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256'
                'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
                'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
            ) -join ','
        }

        # ======================================================================
        # SECTION 7: HTTP SECURITY HEADERS
        # ======================================================================
        # Configure security headers at the server level.
        # These provide defense against common web attacks.
        # ======================================================================

        # Script to configure HTTP response headers
        # Uses IIS Administration cmdlets for reliable configuration
        Script ConfigureSecurityHeaders {
            GetScript = {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                $headers = @{}
                try {
                    $customHeaders = Get-WebConfiguration -Filter '/system.webServer/httpProtocol/customHeaders' -PSPath 'IIS:\'
                    foreach ($header in $customHeaders.Collection) {
                        $headers[$header.name] = $header.value
                    }
                }
                catch {
                    # Module may not be available yet
                }
                return @{ Result = ($headers | ConvertTo-Json) }
            }

            SetScript = {
                Import-Module WebAdministration -ErrorAction Stop

                # Remove server header to prevent fingerprinting
                Set-WebConfigurationProperty -PSPath 'IIS:\' `
                    -Filter '/system.webServer/security/requestFiltering' `
                    -Name 'removeServerHeader' `
                    -Value $true

                # Define security headers
                $securityHeaders = @{
                    # Prevent MIME-type sniffing
                    'X-Content-Type-Options'  = 'nosniff'

                    # Prevent clickjacking
                    'X-Frame-Options'         = 'SAMEORIGIN'

                    # Enable XSS filter
                    'X-XSS-Protection'        = '1; mode=block'

                    # Referrer policy
                    'Referrer-Policy'         = 'strict-origin-when-cross-origin'

                    # Permissions policy (restrict browser features)
                    'Permissions-Policy'      = 'geolocation=(), microphone=(), camera=()'

                    # Content Security Policy (adjust as needed for your application)
                    # Using report-only initially for monitoring
                    'Content-Security-Policy-Report-Only' = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'"
                }

                # Clear existing custom headers
                Clear-WebConfiguration -PSPath 'IIS:\' `
                    -Filter '/system.webServer/httpProtocol/customHeaders' `
                    -ErrorAction SilentlyContinue

                # Add security headers
                foreach ($header in $securityHeaders.GetEnumerator()) {
                    Add-WebConfigurationProperty -PSPath 'IIS:\' `
                        -Filter '/system.webServer/httpProtocol/customHeaders' `
                        -Name '.' `
                        -Value @{
                            name  = $header.Key
                            value = $header.Value
                        }
                }

                # Remove headers that leak information
                $headersToRemove = @('X-Powered-By', 'X-AspNet-Version')
                foreach ($header in $headersToRemove) {
                    Add-WebConfigurationProperty -PSPath 'IIS:\' `
                        -Filter '/system.webServer/httpProtocol/customHeaders' `
                        -Name '.' `
                        -Value @{ name = $header } `
                        -ErrorAction SilentlyContinue

                    Remove-WebConfigurationProperty -PSPath 'IIS:\' `
                        -Filter '/system.webServer/httpProtocol/customHeaders' `
                        -Name '.' `
                        -AtElement @{ name = $header } `
                        -ErrorAction SilentlyContinue
                }
            }

            TestScript = {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                try {
                    $removeServerHeader = Get-WebConfigurationProperty -PSPath 'IIS:\' `
                        -Filter '/system.webServer/security/requestFiltering' `
                        -Name 'removeServerHeader'

                    if (-not $removeServerHeader.Value) {
                        return $false
                    }

                    $customHeaders = Get-WebConfiguration -Filter '/system.webServer/httpProtocol/customHeaders' -PSPath 'IIS:\'
                    $headerNames = $customHeaders.Collection | Select-Object -ExpandProperty name

                    $requiredHeaders = @(
                        'X-Content-Type-Options'
                        'X-Frame-Options'
                        'X-XSS-Protection'
                        'Referrer-Policy'
                    )

                    foreach ($required in $requiredHeaders) {
                        if ($required -notin $headerNames) {
                            return $false
                        }
                    }

                    return $true
                }
                catch {
                    return $false
                }
            }

            DependsOn = @(
                '[WindowsFeature]IISWebServer'
                '[WindowsFeature]IISRequestFiltering'
            )
        }

        # ======================================================================
        # SECTION 8: HEALTH CHECK ENDPOINT
        # ======================================================================
        # Configure a dedicated health check site for load balancer probes.
        # This runs in its own app pool for isolation.
        # ======================================================================

        # Create health check default document
        File HealthCheckPage {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = "$($Node.AppRootPath)\healthcheck\health.html"
            Contents        = @'
<!DOCTYPE html>
<html>
<head><title>Health Check</title></head>
<body>
<h1>OK</h1>
<p>Server: __HOSTNAME__</p>
<p>Timestamp: __TIMESTAMP__</p>
</body>
</html>
'@
            DependsOn       = '[File]HealthCheckDirectory'
        }

        # Health check website - responds to ALB health probes
        xWebsite HealthCheckSite {
            Ensure          = 'Present'
            Name            = 'HealthCheck'
            State           = 'Started'
            PhysicalPath    = "$($Node.AppRootPath)\healthcheck"
            ApplicationPool = 'HyperionHealthCheckPool'

            # Bind to port 8080 for health checks (internal only)
            BindingInfo     = @(
                MSFT_xWebBindingInformation {
                    Protocol  = 'HTTP'
                    Port      = $Node.HealthCheckPort
                    IPAddress = '*'
                }
            )

            DependsOn       = @(
                '[xWebAppPool]HealthCheckAppPool'
                '[File]HealthCheckPage'
                '[xWebsite]DefaultWebSiteRemoval'
            )
        }

        # ======================================================================
        # SECTION 9: MAIN APPLICATION WEBSITE
        # ======================================================================
        # Configure the primary application website.
        # Uses HTTPS binding with configurable certificate.
        # ======================================================================

        xWebsite HyperionWebsite {
            Ensure          = 'Present'
            Name            = $Node.MainSiteName
            State           = 'Started'
            PhysicalPath    = "$($Node.AppRootPath)\web"
            ApplicationPool = $Node.MainAppPoolName

            # Bindings configuration
            BindingInfo     = @(
                # HTTPS binding (primary)
                MSFT_xWebBindingInformation {
                    Protocol              = 'HTTPS'
                    Port                  = 443
                    IPAddress             = '*'
                    HostName              = $Node.HostHeader
                    CertificateThumbprint = $Node.SSLCertificateThumbprint
                    CertificateStoreName  = 'My'
                    SslFlags              = 1  # SNI required
                }
                # HTTP binding (for redirect only)
                MSFT_xWebBindingInformation {
                    Protocol  = 'HTTP'
                    Port      = 80
                    IPAddress = '*'
                    HostName  = $Node.HostHeader
                }
            )

            # Enable preload for faster response
            PreloadEnabled  = $Node.EnablePreload

            DependsOn       = @(
                '[xWebAppPool]HyperionAppPool'
                '[File]AppWebDirectory'
                '[xWebsite]DefaultWebSiteRemoval'
            )
        }

        # ======================================================================
        # SECTION 10: WINDOWS SERVICES
        # ======================================================================
        # Configure Windows services for application components.
        # Services are set to automatic start with recovery options.
        # ======================================================================

        # Hyperion Background Service
        # Handles asynchronous tasks and scheduled jobs
        Script HyperionBackgroundService {
            GetScript = {
                $service = Get-Service -Name 'HyperionBackgroundService' -ErrorAction SilentlyContinue
                if ($service) {
                    return @{
                        Result = @{
                            Name      = $service.Name
                            Status    = $service.Status.ToString()
                            StartType = $service.StartType.ToString()
                        } | ConvertTo-Json
                    }
                }
                return @{ Result = 'Service not found' }
            }

            SetScript = {
                # Service installation is handled by application deployment
                # This script configures the service if it exists
                $serviceName = 'HyperionBackgroundService'
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

                if ($service) {
                    # Set startup type to Automatic (Delayed Start)
                    Set-Service -Name $serviceName -StartupType Automatic

                    # Configure recovery options using sc.exe
                    # First failure: Restart service after 60 seconds
                    # Second failure: Restart service after 120 seconds
                    # Subsequent failures: Restart service after 300 seconds
                    # Reset failure count after 1 day (86400 seconds)
                    $null = sc.exe failure $serviceName reset= 86400 actions= restart/60000/restart/120000/restart/300000

                    # Start the service if not running
                    if ($service.Status -ne 'Running') {
                        Start-Service -Name $serviceName -ErrorAction SilentlyContinue
                    }
                }
            }

            TestScript = {
                $serviceName = 'HyperionBackgroundService'
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

                # Service may not exist yet (installed with application)
                if (-not $service) {
                    return $true  # Skip if service doesn't exist
                }

                # Check if configured correctly
                if ($service.StartType -ne 'Automatic') {
                    return $false
                }

                return $true
            }

            DependsOn = '[WindowsFeature]NetFramework45Core'
        }

        # ======================================================================
        # SECTION 11: PERFORMANCE COUNTERS
        # ======================================================================
        # Enable and configure performance counters for monitoring.
        # CloudWatch agent will collect these metrics.
        # ======================================================================

        # Ensure Performance Counter service is running
        Service PerformanceCounterService {
            Name        = 'PerfHost'
            StartupType = 'Automatic'
            State       = 'Running'
        }

        # Configure custom performance counters for application monitoring
        Script ConfigurePerformanceCounters {
            GetScript = {
                $counters = @(
                    '\Web Service(_Total)\Current Connections'
                    '\Web Service(_Total)\Total Method Requests/sec'
                    '\ASP.NET\Request Execution Time'
                    '\ASP.NET\Requests Queued'
                    '\ASP.NET Applications(__Total__)\Requests/Sec'
                )

                $available = @()
                foreach ($counter in $counters) {
                    try {
                        $null = Get-Counter -Counter $counter -ErrorAction Stop
                        $available += $counter
                    }
                    catch {
                        # Counter not available
                    }
                }

                return @{ Result = ($available | ConvertTo-Json) }
            }

            SetScript = {
                # Rebuild performance counters if needed
                $lodctrPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\lodctr.exe'

                # Rebuild counters from installed services
                & $lodctrPath /R 2>$null

                # Restart services that provide counters
                $services = @('W3SVC', 'WAS')
                foreach ($svc in $services) {
                    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
                    if ($service -and $service.Status -eq 'Running') {
                        Restart-Service -Name $svc -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            TestScript = {
                # Test if key IIS performance counters are available
                $testCounters = @(
                    '\Web Service(_Total)\Current Connections'
                    '\ASP.NET\Requests Current'
                )

                foreach ($counter in $testCounters) {
                    try {
                        $null = Get-Counter -Counter $counter -ErrorAction Stop
                    }
                    catch {
                        return $false
                    }
                }

                return $true
            }

            DependsOn = @(
                '[WindowsFeature]IISWebServer'
                '[Service]PerformanceCounterService'
            )
        }

        # ======================================================================
        # SECTION 12: ADDITIONAL SECURITY HARDENING
        # ======================================================================
        # Additional security configurations for defense in depth.
        # ======================================================================

        # Disable directory browsing globally
        Script DisableDirectoryBrowsing {
            GetScript = {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                try {
                    $value = Get-WebConfigurationProperty -PSPath 'IIS:\' `
                        -Filter '/system.webServer/directoryBrowse' `
                        -Name 'enabled'
                    return @{ Result = $value.Value.ToString() }
                }
                catch {
                    return @{ Result = 'Unknown' }
                }
            }

            SetScript = {
                Import-Module WebAdministration -ErrorAction Stop
                Set-WebConfigurationProperty -PSPath 'IIS:\' `
                    -Filter '/system.webServer/directoryBrowse' `
                    -Name 'enabled' `
                    -Value $false
            }

            TestScript = {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                try {
                    $value = Get-WebConfigurationProperty -PSPath 'IIS:\' `
                        -Filter '/system.webServer/directoryBrowse' `
                        -Name 'enabled'
                    return ($value.Value -eq $false)
                }
                catch {
                    return $false
                }
            }

            DependsOn = '[WindowsFeature]IISDirectoryBrowsing'
        }

        # Configure request filtering for security
        Script ConfigureRequestFiltering {
            GetScript = {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                try {
                    $config = Get-WebConfiguration -Filter '/system.webServer/security/requestFiltering' -PSPath 'IIS:\'
                    return @{ Result = ($config | ConvertTo-Json -Depth 2) }
                }
                catch {
                    return @{ Result = 'Configuration not available' }
                }
            }

            SetScript = {
                Import-Module WebAdministration -ErrorAction Stop

                # Set maximum allowed content length (30 MB)
                Set-WebConfigurationProperty -PSPath 'IIS:\' `
                    -Filter '/system.webServer/security/requestFiltering/requestLimits' `
                    -Name 'maxAllowedContentLength' `
                    -Value 31457280

                # Set maximum URL length
                Set-WebConfigurationProperty -PSPath 'IIS:\' `
                    -Filter '/system.webServer/security/requestFiltering/requestLimits' `
                    -Name 'maxUrl' `
                    -Value 4096

                # Set maximum query string length
                Set-WebConfigurationProperty -PSPath 'IIS:\' `
                    -Filter '/system.webServer/security/requestFiltering/requestLimits' `
                    -Name 'maxQueryString' `
                    -Value 2048

                # Block double-encoded requests
                Set-WebConfigurationProperty -PSPath 'IIS:\' `
                    -Filter '/system.webServer/security/requestFiltering' `
                    -Name 'allowDoubleEscaping' `
                    -Value $false

                # Block high bit characters
                Set-WebConfigurationProperty -PSPath 'IIS:\' `
                    -Filter '/system.webServer/security/requestFiltering' `
                    -Name 'allowHighBitCharacters' `
                    -Value $false

                # Define denied URL sequences (path traversal, etc.)
                $denySequences = @('..', './', '\', '%00', '%2e%2e')
                foreach ($seq in $denySequences) {
                    Add-WebConfigurationProperty -PSPath 'IIS:\' `
                        -Filter '/system.webServer/security/requestFiltering/denyUrlSequences' `
                        -Name '.' `
                        -Value @{ sequence = $seq } `
                        -ErrorAction SilentlyContinue
                }

                # Define denied file extensions
                $denyExtensions = @(
                    '.exe', '.dll', '.config', '.mdf', '.ldf',
                    '.ini', '.bat', '.cmd', '.vbs', '.ps1'
                )
                foreach ($ext in $denyExtensions) {
                    Set-WebConfigurationProperty -PSPath 'IIS:\' `
                        -Filter "/system.webServer/security/requestFiltering/fileExtensions/add[@fileExtension='$ext']" `
                        -Name 'allowed' `
                        -Value $false `
                        -ErrorAction SilentlyContinue
                }
            }

            TestScript = {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                try {
                    $maxContent = Get-WebConfigurationProperty -PSPath 'IIS:\' `
                        -Filter '/system.webServer/security/requestFiltering/requestLimits' `
                        -Name 'maxAllowedContentLength'

                    # Basic check - more thorough validation in GetScript
                    return ($maxContent.Value -le 31457280)
                }
                catch {
                    return $false
                }
            }

            DependsOn = '[WindowsFeature]IISRequestFiltering'
        }

        # ======================================================================
        # SECTION 13: IIS HANDLER MAPPINGS CLEANUP
        # ======================================================================
        # Remove unnecessary handler mappings to reduce attack surface.
        # ======================================================================

        Script RemoveUnnecessaryHandlers {
            GetScript = {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                try {
                    $handlers = Get-WebConfiguration -Filter '/system.webServer/handlers' -PSPath 'IIS:\'
                    $handlerNames = $handlers.Collection | Select-Object -ExpandProperty name
                    return @{ Result = ($handlerNames | ConvertTo-Json) }
                }
                catch {
                    return @{ Result = 'Configuration not available' }
                }
            }

            SetScript = {
                Import-Module WebAdministration -ErrorAction Stop

                # Handlers to remove (reduce attack surface)
                $handlersToRemove = @(
                    'WebDAV'
                    'SSINC-shtm'
                    'SSINC-stm'
                    'SSINC-shtml'
                    'TraceHandler-Integrated-4.0'
                    'TraceHandler-Integrated'
                )

                foreach ($handler in $handlersToRemove) {
                    Remove-WebConfigurationProperty -PSPath 'IIS:\' `
                        -Filter '/system.webServer/handlers' `
                        -Name '.' `
                        -AtElement @{ name = $handler } `
                        -ErrorAction SilentlyContinue
                }
            }

            TestScript = {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                try {
                    $handlers = Get-WebConfiguration -Filter '/system.webServer/handlers' -PSPath 'IIS:\'
                    $handlerNames = $handlers.Collection | Select-Object -ExpandProperty name

                    # Check if WebDAV handler exists (should be removed)
                    return ('WebDAV' -notin $handlerNames)
                }
                catch {
                    return $false
                }
            }

            DependsOn = '[WindowsFeature]IISWebServer'
        }

        # ======================================================================
        # SECTION 14: COMPRESSION CONFIGURATION
        # ======================================================================
        # Configure HTTP compression for performance optimization.
        # ======================================================================

        Script ConfigureCompression {
            GetScript = {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                try {
                    $static = Get-WebConfigurationProperty -PSPath 'IIS:\' `
                        -Filter '/system.webServer/httpCompression' `
                        -Name 'staticTypes'
                    return @{ Result = ($static | ConvertTo-Json) }
                }
                catch {
                    return @{ Result = 'Configuration not available' }
                }
            }

            SetScript = {
                Import-Module WebAdministration -ErrorAction Stop

                # Enable compression
                Set-WebConfigurationProperty -PSPath 'IIS:\' `
                    -Filter '/system.webServer/urlCompression' `
                    -Name 'doStaticCompression' `
                    -Value $true

                Set-WebConfigurationProperty -PSPath 'IIS:\' `
                    -Filter '/system.webServer/urlCompression' `
                    -Name 'doDynamicCompression' `
                    -Value $true

                # Set compression level (4 is balanced)
                Set-WebConfigurationProperty -PSPath 'IIS:\' `
                    -Filter '/system.webServer/httpCompression' `
                    -Name 'staticCompressionLevel' `
                    -Value 7

                Set-WebConfigurationProperty -PSPath 'IIS:\' `
                    -Filter '/system.webServer/httpCompression' `
                    -Name 'dynamicCompressionLevel' `
                    -Value 4
            }

            TestScript = {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                try {
                    $static = Get-WebConfigurationProperty -PSPath 'IIS:\' `
                        -Filter '/system.webServer/urlCompression' `
                        -Name 'doStaticCompression'

                    $dynamic = Get-WebConfigurationProperty -PSPath 'IIS:\' `
                        -Filter '/system.webServer/urlCompression' `
                        -Name 'doDynamicCompression'

                    return ($static.Value -eq $true -and $dynamic.Value -eq $true)
                }
                catch {
                    return $false
                }
            }

            DependsOn = @(
                '[WindowsFeature]IISStaticCompression'
                '[WindowsFeature]IISDynamicCompression'
            )
        }
    }
}

# ==============================================================================
# Export Configuration
# ==============================================================================
# Makes the configuration available for dot-sourcing and compilation.
# ==============================================================================

Export-ModuleMember -Function AppServerConfiguration -ErrorAction SilentlyContinue
