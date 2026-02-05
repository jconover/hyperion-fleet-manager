# Hyperion Fleet Manager - Ansible Playbooks

This directory contains Ansible playbooks for managing the Windows server fleet in AWS.

## Prerequisites

- Ansible >= 2.14
- Python >= 3.9
- Required Ansible collections (install with `ansible-galaxy collection install -r ../requirements.yml`)
- WinRM configured on target Windows hosts
- AWS CLI installed on Windows hosts (for S3 uploads)

## Playbook Overview

| Playbook | Description | Tags |
|----------|-------------|------|
| `site.yml` | Master playbook - imports all others | `always` |
| `baseline.yml` | Apply baseline configuration | `baseline`, `common`, `windows_base`, `chocolatey`, `security_hardening` |
| `deploy_packages.yml` | Deploy/update Chocolatey packages | `packages`, `chocolatey`, `deploy` |
| `compliance_scan.yml` | Run compliance checks | `compliance`, `audit`, `scan` |
| `patch_management.yml` | Windows Update operations | `patching`, `updates`, `maintenance` |
| `fleet_health_check.yml` | Collect health status | `health`, `monitoring`, `status` |

## Quick Start

```bash
# Install required collections
ansible-galaxy collection install -r requirements.yml

# Run full configuration (dry run)
ansible-playbook -i inventories/dev playbooks/site.yml --check --diff

# Run full configuration
ansible-playbook -i inventories/dev playbooks/site.yml

# Run specific playbook
ansible-playbook -i inventories/production playbooks/fleet_health_check.yml

# Run with specific tags
ansible-playbook -i inventories/production playbooks/site.yml --tags baseline

# Limit to specific hosts
ansible-playbook -i inventories/production playbooks/baseline.yml --limit web_servers
```

## Playbook Details

### site.yml - Master Playbook

The main entry point that imports all other playbooks. Supports tag-based execution for selective configuration.

```bash
# Run everything
ansible-playbook -i inventories/production playbooks/site.yml

# Run only baseline configuration
ansible-playbook -i inventories/production playbooks/site.yml --tags baseline

# Skip patching
ansible-playbook -i inventories/production playbooks/site.yml --skip-tags patching
```

### baseline.yml - Baseline Configuration

Applies foundational configuration to Windows hosts:
- Windows base configuration (hostname, time, services, registry)
- Chocolatey package manager with common packages
- Security hardening (firewall, audit policies, TLS settings)

```bash
# Apply baseline to all hosts
ansible-playbook -i inventories/production playbooks/baseline.yml

# Only security hardening
ansible-playbook -i inventories/production playbooks/baseline.yml --tags security_hardening

# Dry run
ansible-playbook -i inventories/production playbooks/baseline.yml --check --diff
```

### deploy_packages.yml - Package Deployment

Manages Chocolatey package deployment with rolling updates.

```bash
# Deploy default packages
ansible-playbook -i inventories/production playbooks/deploy_packages.yml

# Deploy specific packages
ansible-playbook -i inventories/production playbooks/deploy_packages.yml \
  -e '{"deploy_packages": [{"name": "firefox", "state": "present"}, {"name": "vlc", "state": "present"}]}'

# Upgrade all packages
ansible-playbook -i inventories/production playbooks/deploy_packages.yml \
  -e "package_action=upgrade"

# Custom serial percentage
ansible-playbook -i inventories/production playbooks/deploy_packages.yml \
  -e "deploy_serial=10%"
```

### compliance_scan.yml - Compliance Scanning

Runs compliance checks using PowerShell DSC and security baseline validation.

```bash
# Run compliance scan
ansible-playbook -i inventories/production playbooks/compliance_scan.yml

# Upload reports to custom S3 bucket
ansible-playbook -i inventories/production playbooks/compliance_scan.yml \
  -e "compliance_s3_bucket=my-compliance-bucket"

# Fail on critical compliance issues
ansible-playbook -i inventories/production playbooks/compliance_scan.yml \
  -e "fail_on_critical=true"
```

Output reports include:
- DSC compliance status
- Security baseline compliance (password policy, firewall, audit, etc.)
- System configuration compliance
- Overall compliance score

### patch_management.yml - Patch Management

Handles Windows Update operations with pre/post validation.

```bash
# Check for available updates (no install)
ansible-playbook -i inventories/production playbooks/patch_management.yml \
  -e "patch_check_only=true"

# Install security updates only
ansible-playbook -i inventories/production playbooks/patch_management.yml \
  -e "patch_categories=['SecurityUpdates']"

# Allow automatic reboot
ansible-playbook -i inventories/production playbooks/patch_management.yml \
  -e "patch_allow_reboot=true"

# Custom batch size (10% at a time)
ansible-playbook -i inventories/production playbooks/patch_management.yml \
  -e "patch_serial=10%"
```

Patch categories available:
- `SecurityUpdates`
- `CriticalUpdates`
- `UpdateRollups`
- `Updates`
- `DefinitionUpdates`
- `Drivers`
- `FeaturePacks`
- `ServicePacks`

### fleet_health_check.yml - Health Monitoring

Collects comprehensive health information from all hosts.

```bash
# Run full health check
ansible-playbook -i inventories/production playbooks/fleet_health_check.yml

# Quick check (essential metrics only)
ansible-playbook -i inventories/production playbooks/fleet_health_check.yml \
  --tags quick_check

# Upload to S3
ansible-playbook -i inventories/production playbooks/fleet_health_check.yml \
  -e "health_upload_s3=true"
```

Collected metrics:
- System information (OS, hardware, network)
- Service status
- Disk space utilization
- Memory usage
- CPU utilization
- Windows Update status
- Network connectivity

## Variables

### Common Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `hyperion_environment` | Environment name | Required |
| `hyperion_allow_reboot` | Allow automatic reboots | `false` |
| `hyperion_timezone` | Windows timezone | `UTC` |
| `hyperion_ntp_servers` | NTP server list | `time.aws.com` |

### Baseline Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `baseline_apply_windows_base` | Apply Windows base config | `true` |
| `baseline_apply_chocolatey` | Install Chocolatey and packages | `true` |
| `baseline_apply_security_hardening` | Apply security hardening | `true` |
| `baseline_common_packages` | List of packages to install | See defaults |

### Patch Management Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `patch_categories` | Update categories to install | `['SecurityUpdates', 'CriticalUpdates', 'UpdateRollups']` |
| `patch_check_only` | Only check, don't install | `false` |
| `patch_allow_reboot` | Allow reboot after patching | `false` |
| `patch_serial` | Batch size for rolling updates | `20%` |
| `patch_reboot_timeout` | Reboot timeout in seconds | `1800` |

### Health Check Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `health_upload_s3` | Upload reports to S3 | `false` |
| `health_s3_bucket` | S3 bucket for reports | `hyperion-health-reports` |
| `disk_warning_threshold` | Disk free % warning | `20` |
| `disk_critical_threshold` | Disk free % critical | `10` |
| `memory_warning_threshold` | Memory usage % warning | `80` |
| `memory_critical_threshold` | Memory usage % critical | `90` |

## Report Locations

All reports are stored locally on Windows hosts:

| Report Type | Location |
|-------------|----------|
| Baseline status | `C:\Hyperion\Config\baseline_complete.json` |
| Package deployment | `C:\Hyperion\Logs\PackageDeployment\` |
| Compliance reports | `C:\Hyperion\Compliance\` |
| Patch reports | `C:\Hyperion\Reports\Patching\` |
| Health reports | `C:\Hyperion\Reports\Health\` |

## Error Handling

All playbooks include:
- Pre-task validation (OS check, prerequisites)
- Error handling with meaningful messages
- Post-task status reporting
- Optional failure on critical issues

## Best Practices

1. **Always test in dev first**: Use `inventories/dev` before production
2. **Use check mode**: Run with `--check --diff` to preview changes
3. **Limit scope**: Use `--limit` to target specific hosts
4. **Use tags**: Run specific components with `--tags`
5. **Review reports**: Check JSON reports after execution
6. **Schedule maintenance**: Run patching during maintenance windows

## Troubleshooting

### WinRM Connection Issues

```bash
# Test WinRM connectivity
ansible -i inventories/dev -m win_ping all

# Verbose output
ansible-playbook -i inventories/dev playbooks/site.yml -vvv
```

### Common Issues

1. **WinRM timeout**: Increase `ansible_winrm_operation_timeout_sec`
2. **Authentication failure**: Verify credentials in inventory
3. **Permission denied**: Ensure `become_user` has admin rights
4. **Package install failure**: Check Chocolatey source availability

## Contributing

1. Test changes in development environment
2. Use `ansible-lint` to validate playbooks
3. Follow existing code style and conventions
4. Update documentation when adding features
