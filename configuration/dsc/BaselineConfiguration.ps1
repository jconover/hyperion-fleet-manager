#Requires -Version 7.0
#Requires -Modules PSDesiredStateConfiguration

<#
.SYNOPSIS
    Hyperion Fleet Manager - Windows Server 2022 DSC Baseline Configuration

.DESCRIPTION
    This DSC configuration implements security hardening for Windows Server 2022
    based on CIS Benchmark Level 2 controls. It configures:
    - TLS/SSL security settings (TLS 1.2 only)
    - Windows Firewall with advanced logging
    - Windows Defender settings
    - Audit policy for security events
    - Local account management
    - Password and account policies
    - User rights assignments
    - Service hardening
    - Registry-based security settings
    - Event log configuration
    - Time synchronization

.NOTES
    Project: Hyperion Fleet Manager
    Version: 1.0.0
    Author: Infrastructure Team
    License: MIT

    Required DSC Modules:
    - SecurityPolicyDsc (2.10.0)
    - AuditPolicyDsc (1.4.0)
    - ComputerManagementDsc (8.5.0)
    - NetworkingDsc (9.0.0)

.LINK
    https://www.cisecurity.org/benchmark/microsoft_windows_server
#>

# Import required DSC resources
# Note: These modules must be installed before compilation
Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -ModuleName SecurityPolicyDsc -ModuleVersion '2.10.0'
Import-DscResource -ModuleName AuditPolicyDsc -ModuleVersion '1.4.0'
Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion '8.5.0'
Import-DscResource -ModuleName NetworkingDsc -ModuleVersion '9.0.0'

Configuration HyperionBaselineConfiguration {
    <#
    .SYNOPSIS
        Main DSC configuration for Hyperion Fleet Manager Windows Server baseline.
    #>

    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]$LocalAdminCredential,

        [Parameter(Mandatory = $false)]
        [string]$NtpServer = 'time.aws.com',

        [Parameter(Mandatory = $false)]
        [string]$Environment = 'Production'
    )

    # Import configuration data
    # AllNodes and NonNodeData are automatically available from ConfigurationData

    Node $AllNodes.Where({ $_.Role -eq 'WindowsServer' }).NodeName {

        #region Certificate Configuration
        # Certificates are used for encrypting credentials in MOF files
        # The certificate thumbprint should be specified in ConfigurationData
        #endregion

        #region TLS/SSL Security Settings
        # CIS Control: Ensure TLS 1.2 is enabled and older protocols are disabled
        # Reference: CIS Windows Server 2022 Benchmark - Section 18.4

        # Disable SSL 2.0
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

        # Disable SSL 3.0
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

        # Disable TLS 1.0
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

        # Disable TLS 1.1
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

        # Enable TLS 1.3 (if supported)
        Registry EnableTLS13Server {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry EnableTLS13Client {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '1'
        }

        # Configure .NET Framework to use strong crypto
        Registry DotNetStrongCrypto32 {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
            ValueName = 'SchUseStrongCrypto'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry DotNetStrongCrypto64 {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'
            ValueName = 'SchUseStrongCrypto'
            ValueType = 'DWord'
            ValueData = '1'
        }
        #endregion

        #region Windows Firewall Configuration
        # CIS Control: Ensure Windows Firewall is enabled for all profiles
        # Reference: CIS Windows Server 2022 Benchmark - Section 9

        # Domain Profile
        Registry FirewallDomainEnabled {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile'
            ValueName = 'EnableFirewall'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry FirewallDomainInbound {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile'
            ValueName = 'DefaultInboundAction'
            ValueType = 'DWord'
            ValueData = '1'  # Block
        }

        Registry FirewallDomainOutbound {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile'
            ValueName = 'DefaultOutboundAction'
            ValueType = 'DWord'
            ValueData = '0'  # Allow
        }

        # Private Profile
        Registry FirewallPrivateEnabled {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PrivateProfile'
            ValueName = 'EnableFirewall'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry FirewallPrivateInbound {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PrivateProfile'
            ValueName = 'DefaultInboundAction'
            ValueType = 'DWord'
            ValueData = '1'  # Block
        }

        # Public Profile
        Registry FirewallPublicEnabled {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile'
            ValueName = 'EnableFirewall'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry FirewallPublicInbound {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile'
            ValueName = 'DefaultInboundAction'
            ValueType = 'DWord'
            ValueData = '1'  # Block
        }

        # Firewall Logging Configuration
        Registry FirewallDomainLogDropped {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile\Logging'
            ValueName = 'LogDroppedPackets'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry FirewallDomainLogSuccessful {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile\Logging'
            ValueName = 'LogSuccessfulConnections'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry FirewallDomainLogPath {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile\Logging'
            ValueName = 'LogFilePath'
            ValueType = 'String'
            ValueData = '%systemroot%\system32\logfiles\firewall\domainfw.log'
        }

        Registry FirewallDomainLogSize {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile\Logging'
            ValueName = 'LogFileSize'
            ValueType = 'DWord'
            ValueData = '16384'  # 16 MB
        }

        Registry FirewallPublicLogDropped {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile\Logging'
            ValueName = 'LogDroppedPackets'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry FirewallPublicLogPath {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile\Logging'
            ValueName = 'LogFilePath'
            ValueType = 'String'
            ValueData = '%systemroot%\system32\logfiles\firewall\publicfw.log'
        }
        #endregion

        #region Windows Defender Configuration
        # CIS Control: Configure Windows Defender Antivirus
        # Reference: CIS Windows Server 2022 Benchmark - Section 18.9.47

        Registry DefenderRealtimeProtection {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
            ValueName = 'DisableRealtimeMonitoring'
            ValueType = 'DWord'
            ValueData = '0'  # 0 = Enabled
        }

        Registry DefenderBehaviorMonitoring {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
            ValueName = 'DisableBehaviorMonitoring'
            ValueType = 'DWord'
            ValueData = '0'  # 0 = Enabled
        }

        Registry DefenderIOAVProtection {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
            ValueName = 'DisableIOAVProtection'
            ValueType = 'DWord'
            ValueData = '0'  # 0 = Enabled
        }

        Registry DefenderScriptScanning {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
            ValueName = 'DisableScriptScanning'
            ValueType = 'DWord'
            ValueData = '0'  # 0 = Enabled
        }

        Registry DefenderSpywareProtection {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
            ValueName = 'DisableAntiSpyware'
            ValueType = 'DWord'
            ValueData = '0'  # 0 = Enabled
        }

        Registry DefenderPUA {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
            ValueName = 'PUAProtection'
            ValueType = 'DWord'
            ValueData = '1'  # 1 = Block
        }

        Registry DefenderCloudProtection {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'
            ValueName = 'SpynetReporting'
            ValueType = 'DWord'
            ValueData = '2'  # 2 = Advanced
        }

        Registry DefenderSampleSubmission {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'
            ValueName = 'SubmitSamplesConsent'
            ValueType = 'DWord'
            ValueData = '1'  # 1 = Send safe samples automatically
        }
        #endregion

        #region Audit Policy Configuration
        # CIS Control: Configure audit policies for security monitoring
        # Reference: CIS Windows Server 2022 Benchmark - Section 17

        # Account Logon Events
        AuditPolicySubcategory AuditCredentialValidation {
            Name      = 'Credential Validation'
            AuditFlag = 'Success and Failure'
            Ensure    = 'Present'
        }

        AuditPolicySubcategory AuditKerberosAuthentication {
            Name      = 'Kerberos Authentication Service'
            AuditFlag = 'Success and Failure'
            Ensure    = 'Present'
        }

        AuditPolicySubcategory AuditKerberosTicket {
            Name      = 'Kerberos Service Ticket Operations'
            AuditFlag = 'Success and Failure'
            Ensure    = 'Present'
        }

        # Account Management
        AuditPolicySubcategory AuditSecurityGroupManagement {
            Name      = 'Security Group Management'
            AuditFlag = 'Success'
            Ensure    = 'Present'
        }

        AuditPolicySubcategory AuditUserAccountManagement {
            Name      = 'User Account Management'
            AuditFlag = 'Success and Failure'
            Ensure    = 'Present'
        }

        # Logon/Logoff
        AuditPolicySubcategory AuditAccountLockout {
            Name      = 'Account Lockout'
            AuditFlag = 'Failure'
            Ensure    = 'Present'
        }

        AuditPolicySubcategory AuditLogoff {
            Name      = 'Logoff'
            AuditFlag = 'Success'
            Ensure    = 'Present'
        }

        AuditPolicySubcategory AuditLogon {
            Name      = 'Logon'
            AuditFlag = 'Success and Failure'
            Ensure    = 'Present'
        }

        AuditPolicySubcategory AuditSpecialLogon {
            Name      = 'Special Logon'
            AuditFlag = 'Success'
            Ensure    = 'Present'
        }

        # Object Access
        AuditPolicySubcategory AuditRemovableStorage {
            Name      = 'Removable Storage'
            AuditFlag = 'Success and Failure'
            Ensure    = 'Present'
        }

        # Policy Change
        AuditPolicySubcategory AuditAuthenticationPolicyChange {
            Name      = 'Authentication Policy Change'
            AuditFlag = 'Success'
            Ensure    = 'Present'
        }

        AuditPolicySubcategory AuditAuthorizationPolicyChange {
            Name      = 'Authorization Policy Change'
            AuditFlag = 'Success'
            Ensure    = 'Present'
        }

        AuditPolicySubcategory AuditAuditPolicyChange {
            Name      = 'Audit Policy Change'
            AuditFlag = 'Success'
            Ensure    = 'Present'
        }

        # Privilege Use
        AuditPolicySubcategory AuditSensitivePrivilegeUse {
            Name      = 'Sensitive Privilege Use'
            AuditFlag = 'Success and Failure'
            Ensure    = 'Present'
        }

        # System
        AuditPolicySubcategory AuditSecurityStateChange {
            Name      = 'Security State Change'
            AuditFlag = 'Success'
            Ensure    = 'Present'
        }

        AuditPolicySubcategory AuditSecuritySystemExtension {
            Name      = 'Security System Extension'
            AuditFlag = 'Success'
            Ensure    = 'Present'
        }

        AuditPolicySubcategory AuditSystemIntegrity {
            Name      = 'System Integrity'
            AuditFlag = 'Success and Failure'
            Ensure    = 'Present'
        }

        # Detailed Tracking - Process Creation
        AuditPolicySubcategory AuditProcessCreation {
            Name      = 'Process Creation'
            AuditFlag = 'Success'
            Ensure    = 'Present'
        }

        # Enable command line in process creation events
        Registry AuditProcessCommandLine {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
            ValueName = 'ProcessCreationIncludeCmdLine_Enabled'
            ValueType = 'DWord'
            ValueData = '1'
        }
        #endregion

        #region Local Account Management
        # CIS Control: Configure local accounts
        # Reference: CIS Windows Server 2022 Benchmark - Section 2.3

        # Disable Guest Account
        User DisableGuestAccount {
            UserName = 'Guest'
            Disabled = $true
            Ensure   = 'Present'
        }

        # Rename Administrator Account (if specified in configuration data)
        # Note: This is handled via SecurityOption below

        # Configure Local Administrators Group
        # Members are defined in ConfigurationData
        #endregion

        #region Password and Account Policies
        # CIS Control: Configure password policies
        # Reference: CIS Windows Server 2022 Benchmark - Section 1.1

        AccountPolicy PasswordPolicies {
            Name                                        = 'PasswordPolicies'
            # Minimum password length: 14 characters (CIS 1.1.4)
            Minimum_Password_Length                     = 14
            # Password history: 24 passwords (CIS 1.1.1)
            Enforce_password_history                    = 24
            # Maximum password age: 365 days (CIS 1.1.2)
            Maximum_Password_Age                        = 365
            # Minimum password age: 1 day (CIS 1.1.3)
            Minimum_Password_Age                        = 1
            # Password complexity enabled (CIS 1.1.5)
            Password_must_meet_complexity_requirements  = 'Enabled'
            # Store passwords using reversible encryption: Disabled (CIS 1.1.6)
            Store_passwords_using_reversible_encryption = 'Disabled'
            # Account lockout threshold: 5 attempts (CIS 1.2.1)
            Account_lockout_threshold                   = 5
            # Account lockout duration: 15 minutes (CIS 1.2.2)
            Account_lockout_duration                    = 15
            # Reset account lockout counter: 15 minutes (CIS 1.2.3)
            Reset_account_lockout_counter_after         = 15
        }
        #endregion

        #region Security Options
        # CIS Control: Configure security options
        # Reference: CIS Windows Server 2022 Benchmark - Section 2.3

        SecurityOption SecurityOptions {
            Name = 'SecurityOptions'

            # Accounts: Administrator account status (CIS 2.3.1.1)
            # Note: Leave enabled but rename
            Accounts_Administrator_account_status = 'Enabled'

            # Accounts: Guest account status (CIS 2.3.1.3)
            Accounts_Guest_account_status = 'Disabled'

            # Accounts: Limit local account use of blank passwords (CIS 2.3.1.4)
            Accounts_Limit_local_account_use_of_blank_passwords_to_console_logon_only = 'Enabled'

            # Interactive logon: Do not display last user name (CIS 2.3.7.1)
            Interactive_logon_Do_not_display_last_user_name = 'Enabled'

            # Interactive logon: Do not require CTRL+ALT+DEL (CIS 2.3.7.2)
            Interactive_logon_Do_not_require_CTRL_ALT_DEL = 'Disabled'

            # Interactive logon: Machine inactivity limit (CIS 2.3.7.3)
            Interactive_logon_Machine_inactivity_limit = '900'

            # Microsoft network client: Digitally sign communications (always) (CIS 2.3.8.1)
            Microsoft_network_client_Digitally_sign_communications_always = 'Enabled'

            # Microsoft network client: Send unencrypted password to third-party SMB servers (CIS 2.3.8.3)
            Microsoft_network_client_Send_unencrypted_password_to_third_party_SMB_servers = 'Disabled'

            # Microsoft network server: Digitally sign communications (always) (CIS 2.3.9.1)
            Microsoft_network_server_Digitally_sign_communications_always = 'Enabled'

            # Network access: Do not allow anonymous enumeration of SAM accounts (CIS 2.3.10.2)
            Network_access_Do_not_allow_anonymous_enumeration_of_SAM_accounts = 'Enabled'

            # Network access: Do not allow anonymous enumeration of SAM accounts and shares (CIS 2.3.10.3)
            Network_access_Do_not_allow_anonymous_enumeration_of_SAM_accounts_and_shares = 'Enabled'

            # Network access: Restrict anonymous access to Named Pipes and Shares (CIS 2.3.10.9)
            Network_access_Restrict_anonymous_access_to_Named_Pipes_and_Shares = 'Enabled'

            # Network security: LAN Manager authentication level (CIS 2.3.11.7)
            Network_security_LAN_Manager_authentication_level = 'Send NTLMv2 responses only. Refuse LM & NTLM'

            # Network security: Minimum session security for NTLM SSP based clients (CIS 2.3.11.9)
            Network_security_Minimum_session_security_for_NTLM_SSP_based_including_secure_RPC_clients = 'Require NTLMv2 session security, Require 128-bit encryption'

            # Network security: Minimum session security for NTLM SSP based servers (CIS 2.3.11.10)
            Network_security_Minimum_session_security_for_NTLM_SSP_based_including_secure_RPC_servers = 'Require NTLMv2 session security, Require 128-bit encryption'

            # Shutdown: Allow system to be shut down without having to log on (CIS 2.3.13.1)
            Shutdown_Allow_system_to_be_shut_down_without_having_to_log_on = 'Disabled'

            # User Account Control: Admin Approval Mode for Built-in Administrator (CIS 2.3.17.1)
            User_Account_Control_Admin_Approval_Mode_for_the_Built_in_Administrator_account = 'Enabled'

            # User Account Control: Behavior of elevation prompt for administrators (CIS 2.3.17.2)
            User_Account_Control_Behavior_of_the_elevation_prompt_for_administrators_in_Admin_Approval_Mode = 'Prompt for consent on the secure desktop'

            # User Account Control: Behavior of elevation prompt for standard users (CIS 2.3.17.3)
            User_Account_Control_Behavior_of_the_elevation_prompt_for_standard_users = 'Automatically deny elevation requests'

            # User Account Control: Detect application installations (CIS 2.3.17.4)
            User_Account_Control_Detect_application_installations_and_prompt_for_elevation = 'Enabled'

            # User Account Control: Only elevate UIAccess applications in secure locations (CIS 2.3.17.5)
            User_Account_Control_Only_elevate_UIAccess_applications_that_are_installed_in_secure_locations = 'Enabled'

            # User Account Control: Run all administrators in Admin Approval Mode (CIS 2.3.17.6)
            User_Account_Control_Run_all_administrators_in_Admin_Approval_Mode = 'Enabled'

            # User Account Control: Virtualize file and registry write failures (CIS 2.3.17.8)
            User_Account_Control_Virtualize_file_and_registry_write_failures_to_per_user_locations = 'Enabled'
        }
        #endregion

        #region User Rights Assignment
        # CIS Control: Configure user rights assignments
        # Reference: CIS Windows Server 2022 Benchmark - Section 2.2

        UserRightsAssignment AccessComputerFromNetwork {
            Policy   = 'Access_this_computer_from_the_network'
            Identity = @('Administrators', 'Authenticated Users')
        }

        UserRightsAssignment DenyAccessFromNetwork {
            Policy   = 'Deny_access_to_this_computer_from_the_network'
            Identity = @('Guests')
        }

        UserRightsAssignment DenyLogonLocally {
            Policy   = 'Deny_log_on_locally'
            Identity = @('Guests')
        }

        UserRightsAssignment DenyLogonRemoteDesktop {
            Policy   = 'Deny_log_on_through_Remote_Desktop_Services'
            Identity = @('Guests')
        }

        UserRightsAssignment ManageAuditingSecurityLog {
            Policy   = 'Manage_auditing_and_security_log'
            Identity = @('Administrators')
        }

        UserRightsAssignment TakeOwnership {
            Policy   = 'Take_ownership_of_files_or_other_objects'
            Identity = @('Administrators')
        }

        UserRightsAssignment ActAsPartOfOS {
            Policy   = 'Act_as_part_of_the_operating_system'
            Identity = @()  # Should be empty - no one needs this right
        }

        UserRightsAssignment CreateTokenObject {
            Policy   = 'Create_a_token_object'
            Identity = @()  # Should be empty
        }

        UserRightsAssignment DebugPrograms {
            Policy   = 'Debug_programs'
            Identity = @('Administrators')
        }

        UserRightsAssignment LoadUnloadDrivers {
            Policy   = 'Load_and_unload_device_drivers'
            Identity = @('Administrators')
        }
        #endregion

        #region Service Configuration
        # CIS Control: Disable unnecessary services
        # Reference: CIS Windows Server 2022 Benchmark - Section 5

        # Disable Print Spooler (if not needed)
        Service DisablePrintSpooler {
            Name        = 'Spooler'
            State       = 'Stopped'
            StartupType = 'Disabled'
        }

        # Disable Remote Registry
        Service DisableRemoteRegistry {
            Name        = 'RemoteRegistry'
            State       = 'Stopped'
            StartupType = 'Disabled'
        }

        # Disable SNMP (if not needed)
        # Note: May not be installed by default
        # Service DisableSNMP {
        #     Name        = 'SNMP'
        #     State       = 'Stopped'
        #     StartupType = 'Disabled'
        # }

        # Disable Windows Error Reporting
        Service DisableWerSvc {
            Name        = 'WerSvc'
            State       = 'Stopped'
            StartupType = 'Disabled'
        }

        # Disable Xbox services (Server Core may not have these)
        # XblAuthManager, XblGameSave, XboxGipSvc, XboxNetApiSvc

        # Ensure Windows Time service is running
        Service EnableW32Time {
            Name        = 'W32Time'
            State       = 'Running'
            StartupType = 'Automatic'
        }

        # Ensure Windows Event Log service is running
        Service EnableEventLog {
            Name        = 'EventLog'
            State       = 'Running'
            StartupType = 'Automatic'
        }

        # Ensure Windows Defender service is running
        Service EnableWinDefend {
            Name        = 'WinDefend'
            State       = 'Running'
            StartupType = 'Automatic'
        }

        # Ensure Windows Firewall service is running
        Service EnableMpsSvc {
            Name        = 'MpsSvc'
            State       = 'Running'
            StartupType = 'Automatic'
        }
        #endregion

        #region Registry Security Hardening
        # Additional security hardening via registry

        # Disable AutoPlay for all drives (CIS 18.9.8.3)
        Registry DisableAutoPlay {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
            ValueName = 'NoDriveTypeAutoRun'
            ValueType = 'DWord'
            ValueData = '255'  # Disable for all drives
        }

        # Disable AutoRun (CIS 18.9.8.1)
        Registry DisableAutoRun {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
            ValueName = 'NoAutorun'
            ValueType = 'DWord'
            ValueData = '1'
        }

        # Enable Safe DLL Search Mode (CIS 18.4.9)
        Registry SafeDllSearchMode {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
            ValueName = 'SafeDllSearchMode'
            ValueType = 'DWord'
            ValueData = '1'
        }

        # Disable Remote Assistance (CIS 18.8.36.1)
        Registry DisableRemoteAssistance {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
            ValueName = 'fAllowToGetHelp'
            ValueType = 'DWord'
            ValueData = '0'
        }

        # Enable Structured Exception Handling Overwrite Protection (SEHOP)
        Registry EnableSEHOP {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel'
            ValueName = 'DisableExceptionChainValidation'
            ValueType = 'DWord'
            ValueData = '0'
        }

        # Disable WDigest Authentication (CIS 18.4.7)
        Registry DisableWDigest {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest'
            ValueName = 'UseLogonCredential'
            ValueType = 'DWord'
            ValueData = '0'
        }

        # Configure SMB Signing
        Registry SMBClientSigningRequired {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'
            ValueName = 'RequireSecuritySignature'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry SMBServerSigningRequired {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
            ValueName = 'RequireSecuritySignature'
            ValueType = 'DWord'
            ValueData = '1'
        }

        # Disable SMBv1 Client (CIS 18.4.14.1)
        Registry DisableSMBv1Client {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10'
            ValueName = 'Start'
            ValueType = 'DWord'
            ValueData = '4'  # 4 = Disabled
        }

        # Disable SMBv1 Server (CIS 18.4.14.2)
        Registry DisableSMBv1Server {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
            ValueName = 'SMB1'
            ValueType = 'DWord'
            ValueData = '0'
        }

        # Enable LSA Protection (RunAsPPL)
        Registry LSAProtection {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
            ValueName = 'RunAsPPL'
            ValueType = 'DWord'
            ValueData = '1'
        }

        # Disable LLMNR (CIS 18.6.4.1)
        Registry DisableLLMNR {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
            ValueName = 'EnableMulticast'
            ValueType = 'DWord'
            ValueData = '0'
        }

        # Disable NetBIOS over TCP/IP
        # Note: This is typically done per network adapter, but we can set policy
        Registry DisableNetBIOSNodeType {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters'
            ValueName = 'NodeType'
            ValueType = 'DWord'
            ValueData = '2'  # P-node (peer-to-peer)
        }

        # Enable Credential Guard prerequisites
        Registry CredentialGuardVBS {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
            ValueName = 'EnableVirtualizationBasedSecurity'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry CredentialGuardLsaCfg {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
            ValueName = 'LsaCfgFlags'
            ValueType = 'DWord'
            ValueData = '1'  # 1 = Enabled with UEFI lock
        }

        # Configure PowerShell Script Block Logging (CIS 18.9.100.1)
        Registry PowerShellScriptBlockLogging {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
            ValueName = 'EnableScriptBlockLogging'
            ValueType = 'DWord'
            ValueData = '1'
        }

        # Configure PowerShell Transcription
        Registry PowerShellTranscription {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription'
            ValueName = 'EnableTranscripting'
            ValueType = 'DWord'
            ValueData = '1'
        }

        Registry PowerShellTranscriptionDirectory {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription'
            ValueName = 'OutputDirectory'
            ValueType = 'String'
            ValueData = 'C:\ProgramData\PowerShellTranscripts'
        }
        #endregion

        #region Event Log Configuration
        # CIS Control: Configure event log settings
        # Reference: CIS Windows Server 2022 Benchmark - Section 18.9.27

        # Security Log - Maximum size 196608 KB (192 MB) (CIS 18.9.27.2.1)
        Registry SecurityLogMaxSize {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security'
            ValueName = 'MaxSize'
            ValueType = 'DWord'
            ValueData = '196608'
        }

        Registry SecurityLogRetention {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security'
            ValueName = 'Retention'
            ValueType = 'String'
            ValueData = '0'  # Overwrite events as needed
        }

        # Application Log - Maximum size 32768 KB (32 MB) (CIS 18.9.27.1.1)
        Registry ApplicationLogMaxSize {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Application'
            ValueName = 'MaxSize'
            ValueType = 'DWord'
            ValueData = '32768'
        }

        # System Log - Maximum size 32768 KB (32 MB) (CIS 18.9.27.4.1)
        Registry SystemLogMaxSize {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\System'
            ValueName = 'MaxSize'
            ValueType = 'DWord'
            ValueData = '32768'
        }

        # Setup Log - Maximum size 32768 KB (32 MB) (CIS 18.9.27.3.1)
        Registry SetupLogMaxSize {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Setup'
            ValueName = 'MaxSize'
            ValueType = 'DWord'
            ValueData = '32768'
        }

        # PowerShell Operational Log
        Registry PowerShellLogMaxSize {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Microsoft-Windows-PowerShell/Operational'
            ValueName = 'MaxSize'
            ValueType = 'DWord'
            ValueData = '32768'
        }
        #endregion

        #region Time Synchronization
        # CIS Control: Configure Windows Time Service
        # Reference: CIS Windows Server 2022 Benchmark - Section 18.8.5

        # Configure NTP Server
        Registry NtpServer {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters'
            ValueName = 'NtpServer'
            ValueType = 'String'
            ValueData = "$NtpServer,0x9"  # 0x9 = SpecialPollInterval
        }

        Registry NtpType {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters'
            ValueName = 'Type'
            ValueType = 'String'
            ValueData = 'NTP'
        }

        Registry NtpSpecialPollInterval {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient'
            ValueName = 'SpecialPollInterval'
            ValueType = 'DWord'
            ValueData = '3600'  # Poll every hour
        }

        Registry NtpClientEnabled {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient'
            ValueName = 'Enabled'
            ValueType = 'DWord'
            ValueData = '1'
        }
        #endregion

        #region Additional Security Hardening

        # Disable Windows Search indexing service (reduces attack surface)
        Service DisableWSearch {
            Name        = 'WSearch'
            State       = 'Stopped'
            StartupType = 'Disabled'
        }

        # Configure Windows Update to use WSUS or Microsoft Update
        # Note: This is typically configured via Group Policy in enterprise environments

        # Enable Data Execution Prevention (DEP)
        Registry EnableDEP {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
            ValueName = 'NoDataExecutionPrevention'
            ValueType = 'DWord'
            ValueData = '0'
        }

        # Disable IPv6 transition technologies (if IPv6 not used)
        Registry DisableTeredo {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
            ValueName = 'DisabledComponents'
            ValueType = 'DWord'
            ValueData = '255'  # Disable all IPv6 components
        }

        # Restrict NTLM: Outgoing NTLM traffic to remote servers
        Registry RestrictNTLMOutgoing {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0'
            ValueName = 'RestrictSendingNTLMTraffic'
            ValueType = 'DWord'
            ValueData = '2'  # Deny all
        }

        # Configure Windows Remote Management (WinRM)
        Registry WinRMBasicAuth {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service'
            ValueName = 'AllowBasic'
            ValueType = 'DWord'
            ValueData = '0'  # Disable Basic authentication
        }

        Registry WinRMUnencrypted {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service'
            ValueName = 'AllowUnencryptedTraffic'
            ValueType = 'DWord'
            ValueData = '0'  # Require encryption
        }
        #endregion

        #region Local Group Policy
        # Note: Some settings may need to be applied via Local Group Policy
        # These registry entries configure the same settings

        # Disable anonymous SID/Name translation (CIS 2.3.10.1)
        Registry AnonymousSidNameTranslation {
            Ensure    = 'Present'
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
            ValueName = 'TurnOffAnonymousBlock'
            ValueType = 'DWord'
            ValueData = '1'
        }

        # Prevent the computer from joining a homegroup
        Registry NoHomeGroup {
            Ensure    = 'Present'
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\HomeGroup'
            ValueName = 'DisableHomeGroup'
            ValueType = 'DWord'
            ValueData = '1'
        }
        #endregion
    }

    # Configuration for specific node types can be added here
    # Example: Web servers, database servers, domain controllers

    Node $AllNodes.Where({ $_.Role -eq 'DomainController' }).NodeName {
        # Domain Controller specific settings
        # Additional hardening for DCs would go here
    }
}

# Export the configuration function
Export-ModuleMember -Function HyperionBaselineConfiguration -ErrorAction SilentlyContinue
