# Contributing to Hyperion Fleet Manager

Thank you for your interest in contributing to Hyperion Fleet Manager! This document provides guidelines and workflows for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)
- [Documentation](#documentation)
- [Community](#community)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors, regardless of background, experience level, or identity.

### Expected Behavior

- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Gracefully accept constructive criticism
- Focus on what is best for the project and community
- Show empathy towards other community members

### Unacceptable Behavior

- Harassment, discrimination, or exclusionary behavior
- Trolling, insulting comments, or personal attacks
- Publishing others' private information without permission
- Other conduct which could reasonably be considered inappropriate

### Reporting

If you experience or witness unacceptable behavior, please report it to the project maintainers.

## Getting Started

### Prerequisites

Before contributing, ensure you have:

1. **Development Tools:**
   - Git (>= 2.30)
   - Terraform (>= 1.5.0)
   - AWS CLI (>= 2.0)
   - Code editor (VS Code, IntelliJ, etc.)

2. **AWS Account:**
   - Access to AWS account for testing
   - Appropriate IAM permissions
   - AWS credentials configured

3. **Knowledge:**
   - Basic understanding of Terraform
   - Familiarity with AWS services (VPC, EC2, IAM)
   - Git workflow experience

### Setting Up Development Environment

```bash
# 1. Fork the repository on GitHub

# 2. Clone your fork
git clone https://github.com/jconover/hyperion-fleet-manager.git
cd hyperion-fleet-manager

# 3. Add upstream remote
git remote add upstream https://github.com/jconover/hyperion-fleet-manager.git

# 4. Install development tools
# On macOS
brew install terraform tflint pre-commit

# On Linux
# Follow installation guides for your distribution

# 5. Install pre-commit hooks
pre-commit install

# 6. Verify setup
terraform --version
tflint --version
aws --version
```

### Project Familiarization

1. Read the [README.md](../README.md)
2. Review the [Architecture Documentation](architecture/ARCHITECTURE.md)
3. Explore the existing Terraform modules
4. Check open issues and discussions

## Development Workflow

### 1. Select or Create an Issue

- Check [existing issues](https://github.com/jconover/hyperion-fleet-manager/issues)
- Comment on the issue to claim it
- For new features, create an issue first to discuss

### 2. Create a Feature Branch

```bash
# Sync with upstream
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

### Branch Naming Conventions

- **Features:** `feature/description-of-feature`
- **Bug fixes:** `fix/description-of-bug`
- **Documentation:** `docs/description-of-update`
- **Refactoring:** `refactor/description-of-refactor`
- **Performance:** `perf/description-of-improvement`
- **Tests:** `test/description-of-test`

### 3. Make Your Changes

Follow the coding standards and best practices outlined below.

### 4. Test Your Changes

```bash
# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Run linting
tflint --recursive

# Security scanning
checkov -d infrastructure/

# Test in development environment
cd infrastructure/environments/dev
terraform init
terraform plan
terraform apply
```

### 5. Commit Your Changes

We follow [Conventional Commits](https://www.conventionalcommits.org/) specification:

```bash
# Commit format
git commit -m "type(scope): description"

# Examples
git commit -m "feat(networking): add VPC flow logs support"
git commit -m "fix(compute): correct Auto Scaling health check"
git commit -m "docs(readme): update installation instructions"
git commit -m "refactor(modules): reorganize security module"
```

**Commit Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### 6. Push to Your Fork

```bash
git push origin feature/your-feature-name
```

### 7. Create Pull Request

1. Go to your fork on GitHub
2. Click "New Pull Request"
3. Select your feature branch
4. Fill out the PR template
5. Submit the pull request

## Coding Standards

### Terraform Style Guide

#### General Principles

1. **Readability First**: Code is read more than written
2. **Consistency**: Follow existing patterns
3. **Simplicity**: Prefer simple solutions over complex ones
4. **Documentation**: Comment complex logic

#### Formatting

```hcl
# Use terraform fmt for consistent formatting
terraform fmt -recursive

# Indentation: 2 spaces
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.vpc_name
  }
}
```

#### Naming Conventions

**Resources:**
```hcl
# Use snake_case for all identifiers
resource "aws_vpc" "main" { }
resource "aws_subnet" "private" { }
resource "aws_security_group" "web_server" { }
```

**Variables:**
```hcl
# Descriptive, snake_case names
variable "vpc_cidr" { }
variable "availability_zones" { }
variable "enable_nat_gateway" { }
```

**Outputs:**
```hcl
# Clear, descriptive output names
output "vpc_id" { }
output "private_subnet_ids" { }
output "nat_gateway_ips" { }
```

#### Variable Definitions

```hcl
variable "vpc_cidr" {
  description = "CIDR block for VPC. Must be a valid IPv4 CIDR block."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

# Always include:
# - description: What the variable is for
# - type: Variable type (string, number, bool, list, map, object)
# - default: Default value (if optional)
# - validation: Input validation (when applicable)
```

#### Resource Definitions

```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpc"
    }
  )
}

# Guidelines:
# - Alphabetize arguments (exceptions: count, for_each at top)
# - Use merge for tags to combine common and specific tags
# - Include descriptive Name tag
# - Group related arguments together
```

#### Data Sources

```hcl
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Use data sources instead of hard-coding values
```

#### Locals

```hcl
locals {
  # Group related local values
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "hyperion-fleet-manager"
  }

  # Use locals for computed values
  azs_count = length(var.availability_zones)
}
```

#### Comments

```hcl
# Use comments to explain "why", not "what"

# Calculate subnet mask for optimal IP allocation
# Based on expected instance count and growth projections
locals {
  subnet_newbits = ceil(log(var.max_instances_per_az, 2))
}

# Avoid obvious comments
# BAD: Create a VPC
resource "aws_vpc" "main" { }

# GOOD: VPC configured with DNS support for private Route53 zones
resource "aws_vpc" "main" { }
```

### Module Structure

```
module-name/
├── main.tf           # Primary resource definitions
├── variables.tf      # Input variable declarations
├── outputs.tf        # Output value declarations
├── versions.tf       # Terraform and provider version constraints
├── README.md         # Module documentation
├── examples/         # Usage examples
│   └── basic/
│       ├── main.tf
│       └── variables.tf
└── tests/            # Module tests
    └── basic_test.go
```

### Module Documentation

Every module should include a README.md with:

```markdown
# Module Name

Brief description of what the module does.

## Usage

```hcl
module "example" {
  source = "../../modules/module-name"

  vpc_cidr = "10.0.0.0/16"
  name     = "example"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpc_cidr | VPC CIDR block | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC identifier |
```

### Security Best Practices

1. **No Hardcoded Secrets:**
   ```hcl
   # BAD
   password = "MyPassword123"

   # GOOD
   password = data.aws_secretsmanager_secret_version.db_password.secret_string
   ```

2. **Use Least Privilege:**
   ```hcl
   # Minimal permissions, specific resources
   policy = jsonencode({
     Version = "2012-10-17"
     Statement = [
       {
         Effect = "Allow"
         Action = ["s3:GetObject"]
         Resource = "arn:aws:s3:::specific-bucket/*"
       }
     ]
   })
   ```

3. **Enable Encryption:**
   ```hcl
   # Always encrypt sensitive data
   resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
     bucket = aws_s3_bucket.example.id

     rule {
       apply_server_side_encryption_by_default {
         sse_algorithm = "AES256"
       }
     }
   }
   ```

4. **Validate Inputs:**
   ```hcl
   variable "instance_type" {
     type = string

     validation {
       condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
       error_message = "Instance type must be t3.micro, t3.small, or t3.medium."
     }
   }
   ```

## Testing Guidelines

### Pre-Deployment Checks

```bash
# 1. Format check
terraform fmt -check -recursive

# 2. Validation
terraform validate

# 3. Linting
tflint --recursive

# 4. Security scanning
checkov -d infrastructure/

# 5. Plan review
terraform plan -out=tfplan
terraform show tfplan
```

### Test Environments

Always test in non-production environments:

1. **Development Environment:**
   - Use for active development
   - Can be destroyed/recreated frequently
   - Lower-cost configuration

2. **Staging Environment:**
   - Production-like configuration
   - Integration testing
   - Pre-production validation

3. **Production Environment:**
   - Only deploy after thorough testing
   - Require peer review
   - Use terraform plan before apply

### Manual Testing Checklist

- [ ] Resources created successfully
- [ ] Tags applied correctly
- [ ] Network connectivity verified
- [ ] Security groups function as expected
- [ ] IAM roles have correct permissions
- [ ] Monitoring and logging operational
- [ ] No unexpected costs
- [ ] Resources can be destroyed cleanly

## Pull Request Process

### Before Submitting

1. **Self-Review:**
   - Review your own code changes
   - Ensure all tests pass
   - Update documentation
   - Follow coding standards

2. **Documentation:**
   - Update README if functionality changes
   - Add/update inline comments
   - Update CHANGELOG.md

3. **Testing:**
   - Test in development environment
   - Verify plan output
   - Check for unintended changes

### Pull Request Template

```markdown
## Description
Brief description of the changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Related Issue
Fixes #(issue number)

## Changes Made
- Change 1
- Change 2
- Change 3

## Testing
Describe testing performed:
- [ ] terraform fmt
- [ ] terraform validate
- [ ] tflint
- [ ] Manual testing in dev environment

## Screenshots (if applicable)
Add screenshots of plan output or infrastructure changes

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests pass
```

### Review Process

1. **Automated Checks:**
   - CI/CD pipeline runs automatically
   - Format, validation, linting checks
   - Security scanning

2. **Peer Review:**
   - At least one approval required
   - Address all feedback
   - Resolve all conversations

3. **Approval:**
   - Maintainer approval required
   - All checks must pass
   - Documentation complete

4. **Merge:**
   - Squash and merge (preferred)
   - Rebase and merge (for clean history)
   - Delete branch after merge

## Issue Reporting

### Bug Reports

Use the bug report template:

```markdown
## Bug Description
Clear description of the bug

## Steps to Reproduce
1. Step 1
2. Step 2
3. Step 3

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- Terraform version:
- AWS provider version:
- OS:

## Additional Context
Add any other context, logs, or screenshots
```

### Feature Requests

Use the feature request template:

```markdown
## Feature Description
Clear description of the proposed feature

## Use Case
Why is this feature needed?

## Proposed Solution
How should it work?

## Alternatives Considered
What other approaches did you consider?

## Additional Context
Any other relevant information
```

## Documentation

### Documentation Standards

1. **Keep Documentation Updated:**
   - Update docs with code changes
   - Document all public interfaces
   - Include usage examples

2. **Documentation Locations:**
   - README.md: Project overview
   - docs/: Detailed documentation
   - Module READMEs: Module-specific docs
   - Inline comments: Complex logic

3. **Writing Style:**
   - Clear and concise
   - Use examples
   - Assume reader familiarity with basics
   - Link to external resources

### Documentation Updates

When updating documentation:

```bash
# Create docs branch
git checkout -b docs/update-architecture-docs

# Make changes
# Edit files

# Commit
git commit -m "docs(architecture): update VPC diagram"

# Submit PR
git push origin docs/update-architecture-docs
```

## Community

### Getting Help

- **GitHub Discussions:** Ask questions, share ideas
- **Issues:** Report bugs, request features
- **Pull Requests:** Contribute code
- **Documentation:** Check docs first

### Recognition

Contributors will be recognized in:
- CHANGELOG.md
- Repository contributors page
- Release notes

## License

By contributing to Hyperion Fleet Manager, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to Hyperion Fleet Manager!
