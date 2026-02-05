# Ansible Role: windows_base

Base Windows Server configuration role for Hyperion Fleet Manager.

## Description

This role provides comprehensive Windows Server configuration for fleet management, including:

- Windows feature installation (Telnet-Client, SNMP, etc.)
- Windows Firewall configuration
- Timezone configuration (UTC by default)
- Windows Update settings
- PowerShell remoting and execution policy
- WinRM configuration with HTTPS support
- DSC module installation
- Standard directory structure creation
- Scheduled health reporting tasks
- Event log retention configuration
- Service management
- NTP time synchronization
- Security hardening (SMB, LDAP signing, password policies)

## Requirements

### Ansible Version

- Ansible >= 2.14

### Collections

This role requires the following Ansible collections:

```bash
ansible-galaxy collection install ansible.windows
ansible-galaxy collection install community.windows
```

Or add to `requirements.yml`:

```yaml
collections:
  - name: ansible.windows
    version: ">=1.14.0"
  - name: community.windows
    version: ">=1.13.0"
```

### Target Systems

- Windows Server 2019
- Windows Server 2022

### WinRM Prerequisites

Target Windows servers must have WinRM configured for Ansible connectivity. For initial setup:

```powershell
# Run on target Windows server (as Administrator)
winrm quickconfig -quiet
Enable-PSRemoting -Force
```

## Role Variables

### Timezone Configuration

```yaml
windows_timezone: "UTC"
```

### Windows Features

```yaml
windows_features:
  - name: Telnet-Client
    state: present
  - name: SNMP-Service
    state: present
  - name: Web-Mgmt-Tools
    state: present
  - name: NET-Framework-45-Core
    state: present
  - name: PowerShell-ISE
    state: present
  - name: RSAT-AD-PowerShell
    state: present
```

### Firewall Configuration

```yaml
windows_firewall_enabled: true

windows_firewall_rules:
  - name: "Hyperion-WinRM-HTTPS"
    localport: 5986
    protocol: tcp
    direction: in
    action: allow
    enabled: true
    description: "Allow WinRM over HTTPS for Ansible management"

  - name: "Hyperion-RDP"
    localport: 3389
    protocol: tcp
    direction: in
    action: allow
    enabled: true
    description: "Allow RDP access for administration"
```

### WinRM Configuration

```yaml
winrm_enable_https: true
winrm_enable_http: false
winrm_https_port: 5986
winrm_http_port: 5985
winrm_max_memory_per_shell_mb: 1024
winrm_max_processes_per_shell: 25
winrm_max_shells_per_user: 30
winrm_idle_timeout_ms: 7200000
winrm_allow_unencrypted: false
winrm_cert_validity_days: 1095
```

### Standard Directories

```yaml
hyperion_base_directory: "C:\\Hyperion"

windows_standard_directories:
  - path: "C:\\Hyperion"
    description: "Hyperion base directory"
  - path: "C:\\Hyperion\\Logs"
    description: "Application and system logs"
  - path: "C:\\Hyperion\\Scripts"
    description: "PowerShell and automation scripts"
  - path: "C:\\Hyperion\\Config"
    description: "Configuration files"
  - path: "C:\\Hyperion\\Temp"
    description: "Temporary files"
  - path: "C:\\Hyperion\\Backup"
    description: "Local backup storage"
  - path: "C:\\Hyperion\\Reports"
    description: "Health and status reports"
```

### DSC Modules

```yaml
windows_dsc_modules:
  - name: ComputerManagementDsc
    version: "8.5.0"
  - name: NetworkingDsc
    version: "9.0.0"
  - name: SecurityPolicyDsc
    version: "2.10.0.0"
  - name: AuditPolicyDsc
    version: "1.4.0.0"
```

### Windows Update

```yaml
windows_update_enabled: true
windows_update_auto_download: true
windows_update_auto_install: false
windows_update_scheduled_install_day: 0  # 0 = Every day
windows_update_scheduled_install_time: 3  # 3 AM
windows_update_no_auto_reboot: true
```

### Event Logs

```yaml
windows_event_logs:
  - name: Application
    maximum_size_kb: 102400
    retention_days: 30
    overflow_action: OverwriteAsNeeded
  - name: Security
    maximum_size_kb: 204800
    retention_days: 90
    overflow_action: OverwriteAsNeeded
  - name: System
    maximum_size_kb: 102400
    retention_days: 30
    overflow_action: OverwriteAsNeeded
```

### Health Reporting

```yaml
windows_health_reporting_enabled: true
windows_health_report_interval_minutes: 15
windows_health_report_output_path: "C:\\Hyperion\\Reports"
```

### NTP Configuration

```yaml
windows_ntp_enabled: true
windows_ntp_servers:
  - "169.254.169.123"  # AWS Time Sync Service
  - "time.windows.com"
```

### Security Hardening

```yaml
windows_disable_smb1: true
windows_enable_smb_signing: true
windows_enable_ldap_signing: true

windows_password_policy:
  minimum_length: 14
  complexity_enabled: true
  maximum_age_days: 90
  minimum_age_days: 1
  history_count: 24

windows_lockout_policy:
  threshold: 5
  duration_minutes: 30
  reset_minutes: 30
```

### Services

```yaml
windows_services_to_enable:
  - name: WinRM
    start_mode: auto
  - name: SNMP
    start_mode: auto
  - name: W32Time
    start_mode: auto

windows_services_to_disable:
  - name: XblAuthManager
    start_mode: disabled
  - name: XblGameSave
    start_mode: disabled
```

## Dependencies

This role has no dependencies on other Ansible Galaxy roles.

## Example Playbook

### Basic Usage

```yaml
---
- name: Configure Windows servers with Hyperion base settings
  hosts: windows_servers
  gather_facts: true

  roles:
    - role: windows_base
```

### Custom Configuration

```yaml
---
- name: Configure Windows servers with custom settings
  hosts: windows_servers
  gather_facts: true

  vars:
    windows_timezone: "Eastern Standard Time"

    windows_features:
      - name: Telnet-Client
        state: present
      - name: SNMP-Service
        state: present
      - name: Web-Server
        state: present

    windows_firewall_rules:
      - name: "Custom-HTTP"
        localport: 80
        protocol: tcp
        direction: in
        action: allow
        enabled: true
        description: "Allow HTTP traffic"
      - name: "Custom-HTTPS"
        localport: 443
        protocol: tcp
        direction: in
        action: allow
        enabled: true
        description: "Allow HTTPS traffic"

    winrm_max_memory_per_shell_mb: 2048

    windows_ntp_servers:
      - "10.0.0.1"
      - "10.0.0.2"

  roles:
    - role: windows_base
```

### Using Tags

Run specific tasks:

```bash
# Configure only firewall
ansible-playbook playbook.yml --tags firewall

# Configure only WinRM
ansible-playbook playbook.yml --tags winrm

# Configure security hardening only
ansible-playbook playbook.yml --tags security

# Skip health reporting
ansible-playbook playbook.yml --skip-tags health
```

Available tags:
- `always` - Pre-flight checks and validation
- `timezone` - Timezone configuration
- `features` - Windows feature installation
- `powershell` - PowerShell configuration
- `winrm` - WinRM configuration
- `firewall` - Firewall configuration
- `windows_update` - Windows Update settings
- `directories` - Directory creation
- `event_logs` - Event log configuration
- `services` - Service management
- `dsc` - DSC module installation
- `ntp` - NTP configuration
- `security` - Security hardening
- `health` - Health reporting
- `validation` - Configuration validation

## Handlers

The following handlers are available:

- `Restart WinRM` - Restarts the WinRM service
- `Restart SNMP` - Restarts the SNMP service
- `Restart Windows Time` - Restarts the W32Time service
- `Sync time` - Forces NTP time synchronization
- `Restart Firewall` - Restarts the Windows Firewall service
- `Flush DNS cache` - Clears the DNS client cache
- `Update Group Policy` - Forces a Group Policy update
- `Reboot Windows` - Reboots the Windows server

## Generated Files

This role creates the following files on target systems:

| Path | Description |
|------|-------------|
| `C:\Hyperion\.hyperion` | Directory marker file |
| `C:\Hyperion\Scripts\Configure-WinRM.ps1` | WinRM configuration script |
| `C:\Hyperion\Scripts\Invoke-HealthReport.ps1` | Health reporting script |
| `C:\Hyperion\Config\LCMConfig\` | DSC Local Configuration Manager settings |
| `C:\Hyperion\Reports\validation_report.json` | Configuration validation report |
| `C:\Hyperion\Reports\health_report_latest.json` | Latest health report |

## Health Reporting

The role configures a scheduled task that generates health reports every 15 minutes (configurable). Reports include:

- System information (hostname, OS, uptime)
- CPU utilization
- Memory usage
- Disk space
- Network adapter status
- Critical service status
- Event log summary (errors/warnings in last 24 hours)
- Windows Update status

Reports are saved as JSON files in `C:\Hyperion\Reports\` and are automatically cleaned up after 7 days.

## Security Considerations

This role implements the following security measures:

1. **WinRM Security**: HTTPS-only by default, with certificate-based authentication
2. **SMBv1**: Disabled by default
3. **SMB Signing**: Enabled and required
4. **LDAP Signing**: Enabled
5. **LLMNR**: Disabled
6. **NetBIOS over TCP/IP**: Disabled
7. **Password Policy**: Minimum 14 characters, complexity required
8. **Account Lockout**: 5 attempts, 30-minute lockout
9. **Audit Logging**: Enabled for logon, process creation, privilege use

## Troubleshooting

### WinRM Connection Issues

```powershell
# Test WinRM on target
winrm get winrm/config

# Verify HTTPS listener
winrm enumerate winrm/config/Listener

# Check certificate
Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.FriendlyName -like "*WinRM*" }
```

### Feature Installation Failures

```powershell
# Check available features
Get-WindowsFeature | Where-Object { $_.InstallState -eq 'Available' }

# Check feature installation status
Get-WindowsFeature -Name Telnet-Client
```

### Health Report Issues

```powershell
# Run health report manually
& "C:\Hyperion\Scripts\Invoke-HealthReport.ps1" -Verbose

# Check scheduled task
Get-ScheduledTask -TaskPath "\Hyperion\" -TaskName "Hyperion-Health-Report"
```

## License

MIT

## Author Information

Hyperion Fleet Manager Team

## Changelog

### 1.0.0

- Initial release
- Windows feature installation
- Firewall configuration
- WinRM with HTTPS support
- Timezone configuration
- Windows Update settings
- DSC module installation
- Standard directory creation
- Health reporting scheduled task
- Event log configuration
- Service management
- NTP configuration
- Security hardening
