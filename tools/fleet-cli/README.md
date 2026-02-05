# Fleet CLI

Command-line interface tool for managing Hyperion fleets.

## Structure

```
fleet-cli/
├── cmd/               # Command implementations
│   ├── root.go       # Root command
│   ├── list.go       # List resources
│   ├── create.go     # Create resources
│   ├── update.go     # Update resources
│   ├── delete.go     # Delete resources
│   ├── deploy.go     # Deployment commands
│   └── status.go     # Status commands
├── pkg/              # Shared packages
│   ├── api/         # API client
│   ├── config/      # Configuration
│   └── output/      # Output formatting
├── go.mod
├── go.sum
└── main.go
```

## Installation

### From Source

```bash
git clone https://github.com/hyperion/fleet-manager.git
cd fleet-manager/tools/fleet-cli
go build -o fleet-cli main.go
sudo mv fleet-cli /usr/local/bin/
```

### Using Make

```bash
make build-cli
sudo cp bin/fleet-cli /usr/local/bin/
```

### Using Go Install

```bash
go install github.com/hyperion/fleet-manager/tools/fleet-cli@latest
```

## Configuration

Configure CLI with:

```bash
fleet-cli config init
```

Configuration file: `~/.fleet-cli/config.yaml`

```yaml
api_endpoint: https://api.hyperion.example.com
api_key: your-api-key
default_environment: dev
output_format: table
timeout: 30s
```

## Usage

### Authentication

```bash
# Login
fleet-cli auth login

# Set API key
fleet-cli config set api-key <key>

# Logout
fleet-cli auth logout
```

### Fleet Management

```bash
# List fleets
fleet-cli list fleets

# Get fleet details
fleet-cli get fleet <fleet-id>

# Create fleet
fleet-cli create fleet --name my-fleet --region us-east-1

# Update fleet
fleet-cli update fleet <fleet-id> --size 10

# Delete fleet
fleet-cli delete fleet <fleet-id>
```

### Vehicle Management

```bash
# List vehicles
fleet-cli list vehicles

# Register vehicle
fleet-cli create vehicle --vin ABC123 --fleet <fleet-id>

# Get vehicle status
fleet-cli status vehicle <vehicle-id>

# Update vehicle
fleet-cli update vehicle <vehicle-id> --status active
```

### Deployment

```bash
# Deploy to environment
fleet-cli deploy --environment dev

# Deploy with auto-approve
fleet-cli deploy --environment staging --auto-approve

# Rollback deployment
fleet-cli rollback --environment prod --version v1.2.3
```

### Status and Health

```bash
# Overall system status
fleet-cli status

# Fleet health
fleet-cli health fleet <fleet-id>

# Component status
fleet-cli status api
fleet-cli status database
fleet-cli status cache
```

### Monitoring

```bash
# View metrics
fleet-cli metrics fleet <fleet-id>

# View logs
fleet-cli logs fleet <fleet-id> --follow

# View events
fleet-cli events fleet <fleet-id> --since 1h
```

## Output Formats

Supports multiple output formats:

```bash
# Table (default)
fleet-cli list fleets

# JSON
fleet-cli list fleets -o json

# YAML
fleet-cli list fleets -o yaml

# CSV
fleet-cli list fleets -o csv

# Wide (more details)
fleet-cli list fleets -o wide
```

## Global Flags

```bash
--config string        Config file (default: ~/.fleet-cli/config.yaml)
--debug                Enable debug logging
--output string        Output format (table|json|yaml|csv|wide)
--quiet                Suppress non-essential output
--timeout duration     Request timeout (default: 30s)
--verbose              Enable verbose output
```

## Examples

### List all fleets in JSON format

```bash
fleet-cli list fleets -o json
```

### Create fleet with specific configuration

```bash
fleet-cli create fleet \
  --name production-fleet \
  --region us-east-1 \
  --size 50 \
  --auto-scaling \
  --tags "env=prod,managed-by=terraform"
```

### Deploy with validation

```bash
fleet-cli deploy \
  --environment staging \
  --validate \
  --wait \
  --timeout 10m
```

### Watch fleet status

```bash
fleet-cli status fleet <fleet-id> --watch
```

### Export fleet configuration

```bash
fleet-cli get fleet <fleet-id> -o yaml > fleet-config.yaml
```

### Import fleet configuration

```bash
fleet-cli create fleet -f fleet-config.yaml
```

## Shell Completion

Enable shell completion:

```bash
# Bash
fleet-cli completion bash > /etc/bash_completion.d/fleet-cli

# Zsh
fleet-cli completion zsh > ~/.zsh/completion/_fleet-cli

# Fish
fleet-cli completion fish > ~/.config/fish/completions/fleet-cli.fish

# PowerShell
fleet-cli completion powershell > fleet-cli.ps1
```

## Development

### Building

```bash
# Build for current platform
go build -o fleet-cli main.go

# Build for all platforms
GOOS=linux GOARCH=amd64 go build -o fleet-cli-linux-amd64 main.go
GOOS=darwin GOARCH=amd64 go build -o fleet-cli-darwin-amd64 main.go
GOOS=windows GOARCH=amd64 go build -o fleet-cli-windows-amd64.exe main.go
```

### Testing

```bash
# Run tests
go test ./...

# Integration tests
go test -tags=integration ./...
```

## Troubleshooting

### Connection Issues

```bash
# Test API connectivity
fleet-cli ping

# Check configuration
fleet-cli config view

# Enable debug logging
fleet-cli --debug list fleets
```

### Authentication Issues

```bash
# Verify API key
fleet-cli auth verify

# Refresh token
fleet-cli auth refresh
```

## Best Practices

- Store API keys securely
- Use environment-specific configurations
- Enable debug mode for troubleshooting
- Use output formats for scripting
- Implement proper error handling
- Keep CLI updated
