# Configuration Management

This directory contains configuration management code for provisioning and configuring systems using Ansible and PowerShell DSC.

## Structure

```
configuration/
├── ansible/             # Ansible playbooks and roles
│   ├── inventories/    # Environment-specific inventories
│   ├── playbooks/      # Ansible playbooks
│   ├── roles/          # Reusable Ansible roles
│   ├── ansible.cfg     # Ansible configuration
│   └── requirements.yml # Galaxy role dependencies
├── dsc/                # PowerShell DSC configurations
├── modules/            # Custom configuration modules
└── scripts/            # Configuration helper scripts
```

## Ansible

### Playbooks

Located in `ansible/playbooks/`:

- `site.yml` - Main playbook that includes all others
- `common.yml` - Common configuration for all hosts
- `webservers.yml` - Web server configuration
- `databases.yml` - Database server configuration
- `monitoring.yml` - Monitoring agent setup

### Roles

Reusable roles in `ansible/roles/`:

- `common` - Base system configuration
- `security` - Security hardening
- `docker` - Docker installation and configuration
- `kubernetes` - Kubernetes node setup
- `monitoring` - Monitoring agent installation
- `backup` - Backup configuration

### Inventories

Environment-specific inventories in `ansible/inventories/`:

```
dev/
  hosts.yml
  group_vars/
    all.yml
    webservers.yml
  host_vars/
```

### Usage

Install dependencies:

```bash
ansible-galaxy install -r requirements.yml
```

Run playbook:

```bash
ansible-playbook -i inventories/dev playbooks/site.yml
```

Run in check mode:

```bash
ansible-playbook -i inventories/dev playbooks/site.yml --check
```

Run specific tags:

```bash
ansible-playbook -i inventories/dev playbooks/site.yml --tags "common,security"
```

Limit to specific hosts:

```bash
ansible-playbook -i inventories/dev playbooks/site.yml --limit webservers
```

## PowerShell DSC

PowerShell Desired State Configuration for Windows systems.

Located in `dsc/`:

- Configuration definitions
- DSC resources
- MOF compilation scripts
- LCM configuration

### Usage

Compile configuration:

```powershell
. .\dsc\WebServerConfig.ps1
WebServerConfig -OutputPath .\mof
```

Apply configuration:

```powershell
Start-DscConfiguration -Path .\mof -Wait -Verbose -Force
```

## Best Practices

### Ansible Best Practices

- Use roles for reusability
- Keep playbooks idempotent
- Use variables for flexibility
- Store secrets in Ansible Vault
- Tag tasks for selective execution
- Use handlers for service restarts
- Test with `--check` mode first
- Use `--diff` to see changes
- Document roles with README.md
- Use Galaxy roles when appropriate

### Security

- Encrypt sensitive data with Ansible Vault
- Use SSH keys for authentication
- Implement least privilege
- Rotate credentials regularly
- Audit configuration changes
- Use jump hosts for production

### Variable Precedence

Variables in order of precedence:

1. Extra vars (`-e`)
2. Task vars
3. Block vars
4. Role vars
5. Play vars
6. Host vars
7. Group vars
8. Inventory vars

## Testing

Test playbooks before deploying:

```bash
# Syntax check
ansible-playbook playbooks/site.yml --syntax-check

# Lint playbooks
ansible-lint playbooks/

# Check mode (dry run)
ansible-playbook -i inventories/dev playbooks/site.yml --check

# Diff mode
ansible-playbook -i inventories/dev playbooks/site.yml --check --diff
```

## Vault Management

Encrypt sensitive files:

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

Decrypt files:

```bash
ansible-vault decrypt group_vars/all/vault.yml
```

Edit encrypted files:

```bash
ansible-vault edit group_vars/all/vault.yml
```

Run playbook with vault:

```bash
ansible-playbook -i inventories/dev playbooks/site.yml --ask-vault-pass
```

## Modules

Custom modules in `modules/`:

- Python modules for custom functionality
- Module utilities
- Module documentation

## Scripts

Helper scripts in `scripts/`:

- Inventory generation scripts
- Dynamic inventory scripts
- Pre/post configuration hooks
- Validation scripts

## Dependencies

Managed in `ansible/requirements.yml`:

```yaml
roles:
  - name: geerlingguy.docker
    version: 4.1.0
  - name: geerlingguy.kubernetes
    version: 6.2.0
```

## Documentation

Each role should include:

- `README.md` - Role documentation
- `defaults/main.yml` - Default variables
- `meta/main.yml` - Role metadata
- Example playbook usage
