@{
    # CIS Microsoft Windows Server 2022 Benchmark Definitions
    # Based on CIS Benchmark v1.0.0

    BenchmarkVersion = '1.0.0'
    BenchmarkName    = 'CIS Microsoft Windows Server 2022 Benchmark'
    LastUpdated      = '2026-02-01'

    Controls = @(
        #region Level 1 - Account Policies
        @{
            ControlId         = 'CIS-1.1.1'
            Title             = 'Ensure Enforce password history is set to 24 or more password(s)'
            Description       = 'This policy setting determines the number of renewed, unique passwords that have to be associated with a user account before you can reuse an old password.'
            Level             = 1
            Category          = 'Account Policies'
            SubCategory       = 'Password Policy'
            Impact            = 'Medium'
            CheckScript       = {
                $policy = Get-SecurityPolicy -PolicyType 'PasswordHistory'
                $policy.Value -ge 24
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'net accounts /uniquepw:24'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = '24 or more passwords'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'net accounts'
        }

        @{
            ControlId         = 'CIS-1.1.2'
            Title             = 'Ensure Maximum password age is set to 365 or fewer days, but not 0'
            Description       = 'This policy setting defines how long a user can use their password before it expires.'
            Level             = 1
            Category          = 'Account Policies'
            SubCategory       = 'Password Policy'
            Impact            = 'Medium'
            CheckScript       = {
                $policy = Get-SecurityPolicy -PolicyType 'MaxPasswordAge'
                $policy.Value -gt 0 -and $policy.Value -le 365
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'net accounts /maxpwage:365'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = '1-365 days'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'net accounts'
        }

        @{
            ControlId         = 'CIS-1.1.3'
            Title             = 'Ensure Minimum password age is set to 1 or more day(s)'
            Description       = 'This policy setting determines the number of days that you must use a password before you can change it.'
            Level             = 1
            Category          = 'Account Policies'
            SubCategory       = 'Password Policy'
            Impact            = 'Low'
            CheckScript       = {
                $policy = Get-SecurityPolicy -PolicyType 'MinPasswordAge'
                $policy.Value -ge 1
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'net accounts /minpwage:1'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = '1 or more days'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'net accounts'
        }

        @{
            ControlId         = 'CIS-1.1.4'
            Title             = 'Ensure Minimum password length is set to 14 or more characters'
            Description       = 'This policy setting determines the least number of characters that make up a password for a user account.'
            Level             = 1
            Category          = 'Account Policies'
            SubCategory       = 'Password Policy'
            Impact            = 'Medium'
            CheckScript       = {
                $policy = Get-SecurityPolicy -PolicyType 'MinPasswordLength'
                $policy.Value -ge 14
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'net accounts /minpwlen:14'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = '14 or more characters'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'net accounts'
        }

        @{
            ControlId         = 'CIS-1.1.5'
            Title             = 'Ensure Password must meet complexity requirements is set to Enabled'
            Description       = 'This policy setting checks that all new passwords meet basic requirements for strong passwords.'
            Level             = 1
            Category          = 'Account Policies'
            SubCategory       = 'Password Policy'
            Impact            = 'Medium'
            CheckScript       = {
                $policy = Get-SecurityPolicy -PolicyType 'PasswordComplexity'
                $policy.Value -eq 1
            }
            RemediationScript = {
                param([switch]$WhatIf)
                if ($WhatIf) {
                    Write-Output 'WhatIf: Would enable password complexity via Local Security Policy'
                }
                else {
                    # Requires secedit or GPO modification
                    Write-Output 'Remediation requires Local Security Policy modification'
                }
            }
            ExpectedValue     = 'Enabled'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'secedit /export /cfg C:\temp\secpol.cfg'
        }

        @{
            ControlId         = 'CIS-1.2.1'
            Title             = 'Ensure Account lockout duration is set to 15 or more minutes'
            Description       = 'This policy setting determines the length of time that must pass before a locked account is unlocked.'
            Level             = 1
            Category          = 'Account Policies'
            SubCategory       = 'Account Lockout Policy'
            Impact            = 'Medium'
            CheckScript       = {
                $policy = Get-SecurityPolicy -PolicyType 'LockoutDuration'
                $policy.Value -ge 15
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'net accounts /lockoutduration:15'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = '15 or more minutes'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'net accounts'
        }

        @{
            ControlId         = 'CIS-1.2.2'
            Title             = 'Ensure Account lockout threshold is set to 5 or fewer invalid logon attempts'
            Description       = 'This policy setting determines the number of failed logon attempts before the account is locked.'
            Level             = 1
            Category          = 'Account Policies'
            SubCategory       = 'Account Lockout Policy'
            Impact            = 'Medium'
            CheckScript       = {
                $policy = Get-SecurityPolicy -PolicyType 'LockoutThreshold'
                $policy.Value -gt 0 -and $policy.Value -le 5
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'net accounts /lockoutthreshold:5'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = '1-5 attempts'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'net accounts'
        }

        @{
            ControlId         = 'CIS-1.2.3'
            Title             = 'Ensure Reset account lockout counter after is set to 15 or more minutes'
            Description       = 'This policy setting determines the length of time before the Account lockout threshold resets to zero.'
            Level             = 1
            Category          = 'Account Policies'
            SubCategory       = 'Account Lockout Policy'
            Impact            = 'Low'
            CheckScript       = {
                $policy = Get-SecurityPolicy -PolicyType 'LockoutWindow'
                $policy.Value -ge 15
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'net accounts /lockoutwindow:15'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = '15 or more minutes'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'net accounts'
        }
        #endregion

        #region Level 1 - Local Policies - Audit Policy
        @{
            ControlId         = 'CIS-17.1.1'
            Title             = 'Ensure Audit Credential Validation is set to Success and Failure'
            Description       = 'This subcategory reports the results of validation tests on credentials submitted for a user account logon request.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Audit Policy'
            Impact            = 'Low'
            CheckScript       = {
                $audit = Get-AuditPolicy -Subcategory 'Credential Validation'
                $audit.Success -and $audit.Failure
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = 'Success and Failure'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'auditpol /get /subcategory:"Credential Validation"'
        }

        @{
            ControlId         = 'CIS-17.2.1'
            Title             = 'Ensure Audit Application Group Management is set to Success and Failure'
            Description       = 'This subcategory reports when an application group is created or changed.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Audit Policy'
            Impact            = 'Low'
            CheckScript       = {
                $audit = Get-AuditPolicy -Subcategory 'Application Group Management'
                $audit.Success -and $audit.Failure
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'auditpol /set /subcategory:"Application Group Management" /success:enable /failure:enable'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = 'Success and Failure'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'auditpol /get /subcategory:"Application Group Management"'
        }

        @{
            ControlId         = 'CIS-17.2.2'
            Title             = 'Ensure Audit Security Group Management is set to include Success'
            Description       = 'This subcategory reports each event of security group management.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Audit Policy'
            Impact            = 'Low'
            CheckScript       = {
                $audit = Get-AuditPolicy -Subcategory 'Security Group Management'
                $audit.Success
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'auditpol /set /subcategory:"Security Group Management" /success:enable'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = 'Success'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'auditpol /get /subcategory:"Security Group Management"'
        }

        @{
            ControlId         = 'CIS-17.2.3'
            Title             = 'Ensure Audit User Account Management is set to Success and Failure'
            Description       = 'This subcategory reports each event of user account management.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Audit Policy'
            Impact            = 'Low'
            CheckScript       = {
                $audit = Get-AuditPolicy -Subcategory 'User Account Management'
                $audit.Success -and $audit.Failure
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = 'Success and Failure'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'auditpol /get /subcategory:"User Account Management"'
        }

        @{
            ControlId         = 'CIS-17.5.1'
            Title             = 'Ensure Audit Account Lockout is set to include Failure'
            Description       = 'This subcategory reports when a user account is locked out as a result of too many failed logon attempts.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Audit Policy'
            Impact            = 'Low'
            CheckScript       = {
                $audit = Get-AuditPolicy -Subcategory 'Account Lockout'
                $audit.Failure
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'auditpol /set /subcategory:"Account Lockout" /failure:enable'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = 'Failure'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'auditpol /get /subcategory:"Account Lockout"'
        }

        @{
            ControlId         = 'CIS-17.5.2'
            Title             = 'Ensure Audit Logoff is set to include Success'
            Description       = 'This subcategory reports when a user logs off from the system.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Audit Policy'
            Impact            = 'Low'
            CheckScript       = {
                $audit = Get-AuditPolicy -Subcategory 'Logoff'
                $audit.Success
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'auditpol /set /subcategory:"Logoff" /success:enable'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = 'Success'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'auditpol /get /subcategory:"Logoff"'
        }

        @{
            ControlId         = 'CIS-17.5.3'
            Title             = 'Ensure Audit Logon is set to Success and Failure'
            Description       = 'This subcategory reports when a user attempts to log on to the system.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Audit Policy'
            Impact            = 'Low'
            CheckScript       = {
                $audit = Get-AuditPolicy -Subcategory 'Logon'
                $audit.Success -and $audit.Failure
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'auditpol /set /subcategory:"Logon" /success:enable /failure:enable'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = 'Success and Failure'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'auditpol /get /subcategory:"Logon"'
        }

        @{
            ControlId         = 'CIS-17.5.4'
            Title             = 'Ensure Audit Special Logon is set to include Success'
            Description       = 'This subcategory reports when a special logon is used.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Audit Policy'
            Impact            = 'Low'
            CheckScript       = {
                $audit = Get-AuditPolicy -Subcategory 'Special Logon'
                $audit.Success
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $command = 'auditpol /set /subcategory:"Special Logon" /success:enable'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would execute - $command"
                }
                else {
                    Invoke-Expression $command
                }
            }
            ExpectedValue     = 'Success'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'auditpol /get /subcategory:"Special Logon"'
        }
        #endregion

        #region Level 1 - Security Options
        @{
            ControlId         = 'CIS-2.3.1.1'
            Title             = 'Ensure Accounts: Administrator account status is set to Disabled'
            Description       = 'This policy setting enables or disables the Administrator account during normal operation.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Security Options'
            Impact            = 'High'
            CheckScript       = {
                $admin = Get-LocalUser -Name 'Administrator' -ErrorAction SilentlyContinue
                $null -eq $admin -or -not $admin.Enabled
            }
            RemediationScript = {
                param([switch]$WhatIf)
                if ($WhatIf) {
                    Write-Output 'WhatIf: Would disable the built-in Administrator account'
                }
                else {
                    Disable-LocalUser -Name 'Administrator'
                }
            }
            ExpectedValue     = 'Disabled'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'Get-LocalUser -Name Administrator | Select-Object Enabled'
        }

        @{
            ControlId         = 'CIS-2.3.1.2'
            Title             = 'Ensure Accounts: Guest account status is set to Disabled'
            Description       = 'This policy setting determines whether the Guest account is enabled or disabled.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Security Options'
            Impact            = 'Medium'
            CheckScript       = {
                $guest = Get-LocalUser -Name 'Guest' -ErrorAction SilentlyContinue
                $null -eq $guest -or -not $guest.Enabled
            }
            RemediationScript = {
                param([switch]$WhatIf)
                if ($WhatIf) {
                    Write-Output 'WhatIf: Would disable the Guest account'
                }
                else {
                    Disable-LocalUser -Name 'Guest'
                }
            }
            ExpectedValue     = 'Disabled'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'Get-LocalUser -Name Guest | Select-Object Enabled'
        }

        @{
            ControlId         = 'CIS-2.3.7.1'
            Title             = 'Ensure Interactive logon: Do not display last user name is set to Enabled'
            Description       = 'This policy setting determines whether the account name of the last user to log on to the client computers in your organization will be displayed.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Security Options'
            Impact            = 'Low'
            CheckScript       = {
                $value = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'DontDisplayLastUserName' -ErrorAction SilentlyContinue
                $value.DontDisplayLastUserName -eq 1
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would set DontDisplayLastUserName to 1 at $path"
                }
                else {
                    Set-ItemProperty -Path $path -Name 'DontDisplayLastUserName' -Value 1 -Type DWord
                }
            }
            ExpectedValue     = '1 (Enabled)'
            RegistryPath      = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
            RegistryName      = 'DontDisplayLastUserName'
            AuditCommand      = 'Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name DontDisplayLastUserName'
        }

        @{
            ControlId         = 'CIS-2.3.7.2'
            Title             = 'Ensure Interactive logon: Machine inactivity limit is set to 900 or fewer seconds'
            Description       = 'This policy setting determines when the machine is inactive for the defined period of time, the screen saver will run.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Security Options'
            Impact            = 'Medium'
            CheckScript       = {
                $value = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'InactivityTimeoutSecs' -ErrorAction SilentlyContinue
                $null -ne $value.InactivityTimeoutSecs -and $value.InactivityTimeoutSecs -gt 0 -and $value.InactivityTimeoutSecs -le 900
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would set InactivityTimeoutSecs to 900 at $path"
                }
                else {
                    Set-ItemProperty -Path $path -Name 'InactivityTimeoutSecs' -Value 900 -Type DWord
                }
            }
            ExpectedValue     = '900 or fewer seconds (but not 0)'
            RegistryPath      = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
            RegistryName      = 'InactivityTimeoutSecs'
            AuditCommand      = 'Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name InactivityTimeoutSecs'
        }

        @{
            ControlId         = 'CIS-2.3.9.1'
            Title             = 'Ensure Microsoft network server: Digitally sign communications (always) is set to Enabled'
            Description       = 'This policy setting determines if the server side SMB service is required to perform SMB packet signing.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Security Options'
            Impact            = 'Medium'
            CheckScript       = {
                $value = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters' -Name 'RequireSecuritySignature' -ErrorAction SilentlyContinue
                $value.RequireSecuritySignature -eq 1
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $path = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would set RequireSecuritySignature to 1 at $path"
                }
                else {
                    Set-ItemProperty -Path $path -Name 'RequireSecuritySignature' -Value 1 -Type DWord
                }
            }
            ExpectedValue     = '1 (Enabled)'
            RegistryPath      = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters'
            RegistryName      = 'RequireSecuritySignature'
            AuditCommand      = 'Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" -Name RequireSecuritySignature'
        }
        #endregion

        #region Level 2 - Advanced Security
        @{
            ControlId         = 'CIS-18.4.1'
            Title             = 'Ensure MSS: (AutoAdminLogon) Enable Automatic Logon is set to Disabled'
            Description       = 'This policy setting determines if the AutoAdminLogon feature is enabled.'
            Level             = 2
            Category          = 'Administrative Templates'
            SubCategory       = 'MSS (Legacy)'
            Impact            = 'High'
            CheckScript       = {
                $value = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AutoAdminLogon' -ErrorAction SilentlyContinue
                $null -eq $value.AutoAdminLogon -or $value.AutoAdminLogon -eq '0'
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would set AutoAdminLogon to 0 at $path"
                }
                else {
                    Set-ItemProperty -Path $path -Name 'AutoAdminLogon' -Value '0' -Type String
                }
            }
            ExpectedValue     = '0 (Disabled)'
            RegistryPath      = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
            RegistryName      = 'AutoAdminLogon'
            AuditCommand      = 'Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon'
        }

        @{
            ControlId         = 'CIS-18.4.2'
            Title             = 'Ensure MSS: (DisableIPSourceRouting) IP source routing protection level is set to Highest protection'
            Description       = 'IP source routing is a mechanism that allows the sender to determine the IP route that a datagram should follow through the network.'
            Level             = 2
            Category          = 'Administrative Templates'
            SubCategory       = 'MSS (Legacy)'
            Impact            = 'Low'
            CheckScript       = {
                $value = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'DisableIPSourceRouting' -ErrorAction SilentlyContinue
                $value.DisableIPSourceRouting -eq 2
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $path = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would set DisableIPSourceRouting to 2 at $path"
                }
                else {
                    Set-ItemProperty -Path $path -Name 'DisableIPSourceRouting' -Value 2 -Type DWord
                }
            }
            ExpectedValue     = '2 (Highest protection)'
            RegistryPath      = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
            RegistryName      = 'DisableIPSourceRouting'
            AuditCommand      = 'Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name DisableIPSourceRouting'
        }

        @{
            ControlId         = 'CIS-18.4.3'
            Title             = 'Ensure MSS: (EnableICMPRedirect) Allow ICMP redirects to override OSPF generated routes is set to Disabled'
            Description       = 'ICMP redirects cause the stack to plumb host routes.'
            Level             = 2
            Category          = 'Administrative Templates'
            SubCategory       = 'MSS (Legacy)'
            Impact            = 'Low'
            CheckScript       = {
                $value = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'EnableICMPRedirect' -ErrorAction SilentlyContinue
                $value.EnableICMPRedirect -eq 0
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $path = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would set EnableICMPRedirect to 0 at $path"
                }
                else {
                    Set-ItemProperty -Path $path -Name 'EnableICMPRedirect' -Value 0 -Type DWord
                }
            }
            ExpectedValue     = '0 (Disabled)'
            RegistryPath      = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
            RegistryName      = 'EnableICMPRedirect'
            AuditCommand      = 'Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name EnableICMPRedirect'
        }

        @{
            ControlId         = 'CIS-18.5.1'
            Title             = 'Ensure Turn off multicast name resolution is set to Enabled'
            Description       = 'LLMNR is a secondary name resolution protocol used to resolve local names.'
            Level             = 2
            Category          = 'Administrative Templates'
            SubCategory       = 'DNS Client'
            Impact            = 'Medium'
            CheckScript       = {
                $value = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name 'EnableMulticast' -ErrorAction SilentlyContinue
                $value.EnableMulticast -eq 0
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would set EnableMulticast to 0 at $path"
                }
                else {
                    if (-not (Test-Path $path)) {
                        New-Item -Path $path -Force | Out-Null
                    }
                    Set-ItemProperty -Path $path -Name 'EnableMulticast' -Value 0 -Type DWord
                }
            }
            ExpectedValue     = '0 (Disabled)'
            RegistryPath      = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
            RegistryName      = 'EnableMulticast'
            AuditCommand      = 'Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name EnableMulticast'
        }

        @{
            ControlId         = 'CIS-18.9.1'
            Title             = 'Ensure Windows Firewall: Domain: Firewall state is set to On'
            Description       = 'Select On to have Windows Firewall with Advanced Security use the settings for this profile to filter network traffic.'
            Level             = 1
            Category          = 'Administrative Templates'
            SubCategory       = 'Windows Firewall'
            Impact            = 'Medium'
            CheckScript       = {
                $fw = Get-NetFirewallProfile -Name Domain -ErrorAction SilentlyContinue
                $fw.Enabled -eq $true
            }
            RemediationScript = {
                param([switch]$WhatIf)
                if ($WhatIf) {
                    Write-Output 'WhatIf: Would enable Windows Firewall for Domain profile'
                }
                else {
                    Set-NetFirewallProfile -Name Domain -Enabled True
                }
            }
            ExpectedValue     = 'On (True)'
            RegistryPath      = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile'
            RegistryName      = 'EnableFirewall'
            AuditCommand      = 'Get-NetFirewallProfile -Name Domain | Select-Object Enabled'
        }

        @{
            ControlId         = 'CIS-18.9.2'
            Title             = 'Ensure Windows Firewall: Private: Firewall state is set to On'
            Description       = 'Select On to have Windows Firewall with Advanced Security use the settings for this profile to filter network traffic.'
            Level             = 1
            Category          = 'Administrative Templates'
            SubCategory       = 'Windows Firewall'
            Impact            = 'Medium'
            CheckScript       = {
                $fw = Get-NetFirewallProfile -Name Private -ErrorAction SilentlyContinue
                $fw.Enabled -eq $true
            }
            RemediationScript = {
                param([switch]$WhatIf)
                if ($WhatIf) {
                    Write-Output 'WhatIf: Would enable Windows Firewall for Private profile'
                }
                else {
                    Set-NetFirewallProfile -Name Private -Enabled True
                }
            }
            ExpectedValue     = 'On (True)'
            RegistryPath      = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PrivateProfile'
            RegistryName      = 'EnableFirewall'
            AuditCommand      = 'Get-NetFirewallProfile -Name Private | Select-Object Enabled'
        }

        @{
            ControlId         = 'CIS-18.9.3'
            Title             = 'Ensure Windows Firewall: Public: Firewall state is set to On'
            Description       = 'Select On to have Windows Firewall with Advanced Security use the settings for this profile to filter network traffic.'
            Level             = 1
            Category          = 'Administrative Templates'
            SubCategory       = 'Windows Firewall'
            Impact            = 'Medium'
            CheckScript       = {
                $fw = Get-NetFirewallProfile -Name Public -ErrorAction SilentlyContinue
                $fw.Enabled -eq $true
            }
            RemediationScript = {
                param([switch]$WhatIf)
                if ($WhatIf) {
                    Write-Output 'WhatIf: Would enable Windows Firewall for Public profile'
                }
                else {
                    Set-NetFirewallProfile -Name Public -Enabled True
                }
            }
            ExpectedValue     = 'On (True)'
            RegistryPath      = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile'
            RegistryName      = 'EnableFirewall'
            AuditCommand      = 'Get-NetFirewallProfile -Name Public | Select-Object Enabled'
        }

        @{
            ControlId         = 'CIS-2.2.1'
            Title             = 'Ensure Access this computer from the network includes Administrators and Authenticated Users'
            Description       = 'This policy setting determines which users can connect to the computer from the network.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'User Rights Assignment'
            Impact            = 'High'
            CheckScript       = {
                $policy = Get-SecurityPolicy -PolicyType 'NetworkAccess'
                $policy.Value -match 'Administrators' -and $policy.Value -match 'Authenticated Users'
            }
            RemediationScript = {
                param([switch]$WhatIf)
                if ($WhatIf) {
                    Write-Output 'WhatIf: Would configure User Rights Assignment via Local Security Policy'
                }
                else {
                    Write-Output 'Remediation requires Local Security Policy or GPO modification'
                }
            }
            ExpectedValue     = 'Administrators, Authenticated Users'
            RegistryPath      = $null
            RegistryName      = $null
            AuditCommand      = 'secedit /export /cfg C:\temp\secpol.cfg'
        }

        @{
            ControlId         = 'CIS-2.3.10.1'
            Title             = 'Ensure Network access: Allow anonymous SID/Name translation is set to Disabled'
            Description       = 'This policy setting determines whether an anonymous user can request security identifier (SID) attributes for another user.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Security Options'
            Impact            = 'Medium'
            CheckScript       = {
                $value = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'TurnOffAnonymousBlock' -ErrorAction SilentlyContinue
                $null -eq $value.TurnOffAnonymousBlock -or $value.TurnOffAnonymousBlock -eq 0
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would set TurnOffAnonymousBlock to 0 at $path"
                }
                else {
                    Set-ItemProperty -Path $path -Name 'TurnOffAnonymousBlock' -Value 0 -Type DWord
                }
            }
            ExpectedValue     = '0 (Disabled)'
            RegistryPath      = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
            RegistryName      = 'TurnOffAnonymousBlock'
            AuditCommand      = 'Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name TurnOffAnonymousBlock'
        }

        @{
            ControlId         = 'CIS-2.3.10.2'
            Title             = 'Ensure Network access: Do not allow anonymous enumeration of SAM accounts is set to Enabled'
            Description       = 'This policy setting controls the ability of anonymous users to enumerate the accounts in the Security Accounts Manager (SAM).'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Security Options'
            Impact            = 'Medium'
            CheckScript       = {
                $value = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RestrictAnonymousSAM' -ErrorAction SilentlyContinue
                $value.RestrictAnonymousSAM -eq 1
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would set RestrictAnonymousSAM to 1 at $path"
                }
                else {
                    Set-ItemProperty -Path $path -Name 'RestrictAnonymousSAM' -Value 1 -Type DWord
                }
            }
            ExpectedValue     = '1 (Enabled)'
            RegistryPath      = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
            RegistryName      = 'RestrictAnonymousSAM'
            AuditCommand      = 'Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name RestrictAnonymousSAM'
        }

        @{
            ControlId         = 'CIS-2.3.11.1'
            Title             = 'Ensure Network security: Allow Local System to use computer identity for NTLM is set to Enabled'
            Description       = 'This policy setting determines whether Local System services that use Negotiate when reverting to NTLM authentication can use the computer identity.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Security Options'
            Impact            = 'Low'
            CheckScript       = {
                $value = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'UseMachineId' -ErrorAction SilentlyContinue
                $value.UseMachineId -eq 1
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would set UseMachineId to 1 at $path"
                }
                else {
                    Set-ItemProperty -Path $path -Name 'UseMachineId' -Value 1 -Type DWord
                }
            }
            ExpectedValue     = '1 (Enabled)'
            RegistryPath      = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
            RegistryName      = 'UseMachineId'
            AuditCommand      = 'Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name UseMachineId'
        }

        @{
            ControlId         = 'CIS-2.3.11.2'
            Title             = 'Ensure Network security: LAN Manager authentication level is set to Send NTLMv2 response only'
            Description       = 'LAN Manager (LM) authentication level determines which challenge/response authentication protocol is used for network logons.'
            Level             = 1
            Category          = 'Local Policies'
            SubCategory       = 'Security Options'
            Impact            = 'High'
            CheckScript       = {
                $value = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'LmCompatibilityLevel' -ErrorAction SilentlyContinue
                $value.LmCompatibilityLevel -ge 5
            }
            RemediationScript = {
                param([switch]$WhatIf)
                $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
                if ($WhatIf) {
                    Write-Output "WhatIf: Would set LmCompatibilityLevel to 5 at $path"
                }
                else {
                    Set-ItemProperty -Path $path -Name 'LmCompatibilityLevel' -Value 5 -Type DWord
                }
            }
            ExpectedValue     = '5 (Send NTLMv2 response only. Refuse LM and NTLM)'
            RegistryPath      = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
            RegistryName      = 'LmCompatibilityLevel'
            AuditCommand      = 'Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name LmCompatibilityLevel'
        }
        #endregion
    )

    # Category definitions for reporting
    Categories = @{
        'Account Policies'           = 'Password and account lockout policies'
        'Local Policies'             = 'Audit, user rights, and security options'
        'Administrative Templates'   = 'Registry-based policy settings'
        'Advanced Audit Policy'      = 'Fine-grained audit policy configuration'
    }

    # Subcategory definitions for reporting
    SubCategories = @{
        'Password Policy'            = 'Controls password requirements'
        'Account Lockout Policy'     = 'Controls account lockout behavior'
        'Audit Policy'               = 'Controls security event logging'
        'Security Options'           = 'Various security configuration settings'
        'User Rights Assignment'     = 'Controls user privilege assignments'
        'MSS (Legacy)'               = 'Microsoft Solutions for Security (legacy) settings'
        'DNS Client'                 = 'DNS client configuration settings'
        'Windows Firewall'           = 'Windows Firewall configuration'
    }
}
