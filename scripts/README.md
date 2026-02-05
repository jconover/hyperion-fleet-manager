# Scripts

Utility scripts for development, operations, and automation.

## Structure

```
scripts/
├── setup/              # Setup and installation scripts
├── deployment/         # Deployment automation scripts
├── maintenance/        # Maintenance and cleanup scripts
├── testing/           # Test helper scripts
└── utilities/         # General utility scripts
```

## Script Categories

### Setup Scripts

Development environment setup:

- `install-deps.sh` - Install all dependencies
- `setup-dev.sh` - Configure development environment
- `init-database.sh` - Initialize database
- `generate-certs.sh` - Generate SSL certificates

### Deployment Scripts

Automated deployment:

- `deploy.sh` - Main deployment script
- `rollback.sh` - Rollback deployment
- `blue-green-deploy.sh` - Blue/green deployment
- `canary-deploy.sh` - Canary deployment

### Maintenance Scripts

System maintenance:

- `backup.sh` - Database and configuration backup
- `cleanup.sh` - Clean up old resources
- `rotate-logs.sh` - Log rotation
- `vacuum-db.sh` - Database maintenance

### Testing Scripts

Test automation:

- `run-tests.sh` - Run all tests
- `integration-test.sh` - Integration test setup
- `load-test.sh` - Performance testing
- `wait-for-services.sh` - Wait for dependencies

### Utility Scripts

General utilities:

- `health-check.sh` - Health check script
- `generate-docs.sh` - Generate documentation
- `update-versions.sh` - Update version numbers
- `validate-config.sh` - Validate configurations

## Usage

### Make Scripts Executable

```bash
chmod +x scripts/**/*.sh
```

### Run Script

```bash
./scripts/setup/install-deps.sh
```

### With Arguments

```bash
./scripts/deployment/deploy.sh --environment prod --version v1.2.3
```

## Script Standards

### Shebang

Use bash shebang:

```bash
#!/usr/bin/env bash
```

### Error Handling

Enable strict mode:

```bash
set -euo pipefail
```

Explanation:
- `-e` - Exit on error
- `-u` - Error on undefined variable
- `-o pipefail` - Pipeline fails if any command fails

### Logging

Use consistent logging:

```bash
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

log "Starting deployment"
error "Deployment failed"
```

### Help Function

Include help:

```bash
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    -e, --environment ENV    Environment (dev/staging/prod)
    -v, --version VERSION    Version to deploy
    -h, --help              Show this help

Examples:
    $(basename "$0") -e prod -v v1.2.3
EOF
}
```

### Argument Parsing

Parse arguments properly:

```bash
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done
```

## Example Scripts

### Deploy Script

```bash
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-dev}"
VERSION="${2:-latest}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "Deploying version $VERSION to $ENVIRONMENT"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Invalid environment"
    exit 1
fi

# Deploy
cd infrastructure
terraform workspace select "$ENVIRONMENT"
terraform apply -var="version=$VERSION" -auto-approve

log "Deployment complete"
```

### Backup Script

```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/backup/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "Starting backup"

# Database backup
pg_dump hyperion > "$BACKUP_DIR/database.sql"

# Configuration backup
tar -czf "$BACKUP_DIR/config.tar.gz" configuration/

# Upload to S3
aws s3 sync "$BACKUP_DIR" s3://backups/$(date +%Y%m%d)/

log "Backup complete"
```

### Health Check Script

```bash
#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://localhost:8080}"

check_health() {
    local service=$1
    local url=$2
    
    if curl -sf "$url" > /dev/null; then
        echo "✓ $service is healthy"
        return 0
    else
        echo "✗ $service is unhealthy"
        return 1
    fi
}

check_health "API" "$API_URL/health"
check_health "Database" "$API_URL/health/db"
check_health "Cache" "$API_URL/health/cache"
```

## Best Practices

### Script Design

- Keep scripts simple and focused
- Use functions for reusability
- Include help/usage information
- Validate inputs
- Handle errors gracefully
- Make scripts idempotent
- Add comments for complex logic

### Security

- Never hardcode credentials
- Use environment variables
- Validate user input
- Avoid eval and command injection
- Use quotes around variables
- Set proper file permissions
- Log sensitive operations

### Error Handling

```bash
# Check command success
if ! command_that_might_fail; then
    error "Command failed"
    exit 1
fi

# Use trap for cleanup
cleanup() {
    rm -f /tmp/tempfile
}
trap cleanup EXIT

# Check file exists
if [[ ! -f "config.yaml" ]]; then
    error "Config file not found"
    exit 1
fi
```

### Testing Scripts

Test scripts before use:

```bash
# Shellcheck for linting
shellcheck script.sh

# Dry run
./script.sh --dry-run

# Test in development first
ENVIRONMENT=dev ./deploy.sh
```

## Environment Variables

Common environment variables:

```bash
# Application
export APP_ENV=production
export APP_VERSION=v1.2.3

# AWS
export AWS_REGION=us-east-1
export AWS_PROFILE=production

# Database
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=hyperion

# Paths
export PROJECT_ROOT=/opt/hyperion
export LOG_DIR=/var/log/hyperion
```

## Debugging Scripts

### Enable Debug Mode

```bash
# Verbose output
bash -x script.sh

# Or in script
set -x

# Debug specific section
set -x
# ... debug this section
set +x
```

### Common Issues

**Permission denied:**
```bash
chmod +x script.sh
```

**Script not found:**
```bash
# Use absolute path
/path/to/script.sh

# Or add to PATH
export PATH="$PATH:/path/to/scripts"
```

## Documentation

Document each script with:

- Purpose and description
- Prerequisites
- Arguments and options
- Environment variables
- Example usage
- Exit codes
- Known issues

## Maintenance

- Review scripts regularly
- Update for new requirements
- Remove obsolete scripts
- Keep dependencies updated
- Test after changes
- Version control all scripts

## Integration

Scripts integrate with:

- Makefile targets
- CI/CD pipelines
- Cron jobs
- Monitoring systems
- Deployment tools

## Resources

- [Bash Guide](https://mywiki.wooledge.org/BashGuide)
- [ShellCheck](https://www.shellcheck.net/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
