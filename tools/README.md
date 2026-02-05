# Tools

CLI tools and utilities for managing Hyperion Fleet Manager.

## Structure

```
tools/
└── fleet-cli/         # Fleet management CLI
```

## Fleet CLI

Command-line interface for fleet operations.

See [fleet-cli/README.md](fleet-cli/README.md) for detailed documentation.

### Installation

```bash
# Build from source
cd tools/fleet-cli
go build -o fleet-cli main.go

# Using Makefile
make build-cli

# Install globally
sudo cp bin/fleet-cli /usr/local/bin/
```

### Quick Start

```bash
# Configure
fleet-cli config init

# Authenticate
fleet-cli auth login

# List fleets
fleet-cli list fleets

# Get help
fleet-cli --help
```

## Future Tools

Planned CLI tools:

- **fleet-migration** - Migration utility
- **fleet-backup** - Backup and restore tool
- **fleet-debug** - Debugging utilities
- **fleet-monitor** - Monitoring CLI

## Development

### Building Tools

```bash
# Build all tools
make build

# Build specific tool
cd tools/fleet-cli && go build
```

### Testing

```bash
# Test all tools
go test ./tools/...

# Test specific tool
cd tools/fleet-cli && go test ./...
```

## Contributing

To add new tools:

1. Create tool directory
2. Add README with usage
3. Implement with Go
4. Add tests
5. Update this README
6. Add to Makefile

## Standards

All tools should:

- Use Cobra for CLI framework
- Support JSON/YAML output
- Include comprehensive help
- Handle errors gracefully
- Use consistent formatting
- Support configuration files
- Include shell completion
