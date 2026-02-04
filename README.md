# Hyperion Fleet Manager

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com/jconover/hyperion-fleet-manager)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws)](https://aws.amazon.com/)

## Executive Summary

### What is Hyperion Fleet Manager?

Hyperion Fleet Manager is an enterprise-grade infrastructure automation platform designed to provision, manage, and orchestrate large-scale Windows server fleets in AWS. Built with Infrastructure as Code (IaC) principles, it provides a robust, repeatable, and auditable approach to cloud infrastructure management.

### Why Hyperion?

Managing distributed Windows server infrastructure at scale presents unique challenges: configuration drift, compliance requirements, security hardening, and operational overhead. Hyperion addresses these challenges by:

- **Automating Infrastructure Provisioning**: Eliminate manual configuration and reduce deployment time from days to minutes
- **Ensuring Consistency**: Deploy identical environments across development, staging, and production
- **Maintaining Compliance**: Built-in security controls, VPC isolation, and comprehensive logging
- **Reducing Operational Costs**: Optimize resource utilization with automated scaling and resource management
- **Enabling Rapid Recovery**: Infrastructure as Code enables quick disaster recovery and environment replication

### Who is it for?

- **DevOps Engineers** seeking to automate Windows fleet infrastructure
- **System Administrators** managing large-scale server deployments
- **IT Operations Teams** requiring consistent, repeatable infrastructure provisioning
- **Cloud Architects** designing resilient, scalable AWS environments
- **Organizations** migrating Windows workloads to AWS

## Architecture Overview

Hyperion Fleet Manager implements a modern, cloud-native architecture leveraging AWS services and Terraform for infrastructure automation. The platform is built on several key architectural principles:

### Core Components

1. **Network Layer**: Highly available VPC architecture with public and private subnets across multiple Availability Zones, providing network isolation and redundancy.

2. **Compute Layer**: EC2-based Windows server fleet with Auto Scaling Groups for elasticity and high availability.

3. **Security Layer**: Defense-in-depth security model with Security Groups, Network ACLs, IAM roles, and encryption at rest and in transit.

4. **Monitoring & Logging**: Integrated CloudWatch monitoring, VPC Flow Logs, and centralized logging for operational visibility.

5. **State Management**: Remote Terraform state stored in S3 with DynamoDB state locking for team collaboration.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (Multi-AZ)                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                     VPC (10.0.0.0/16)                         │ │
│  │                                                               │ │
│  │  ┌──────────────────┐         ┌──────────────────┐          │ │
│  │  │  AZ-1 (us-east-1a)│         │  AZ-2 (us-east-1b)│          │ │
│  │  ├──────────────────┤         ├──────────────────┤          │ │
│  │  │                  │         │                  │          │ │
│  │  │ Public Subnet    │         │ Public Subnet    │          │ │
│  │  │ ┌──────────────┐ │         │ ┌──────────────┐ │          │ │
│  │  │ │ NAT Gateway  │ │         │ │ NAT Gateway  │ │          │ │
│  │  │ │ (w/ EIP)     │ │         │ │ (w/ EIP)     │ │          │ │
│  │  │ └──────────────┘ │         │ └──────────────┘ │          │ │
│  │  │                  │         │                  │          │ │
│  │  ├──────────────────┤         ├──────────────────┤          │ │
│  │  │                  │         │                  │          │ │
│  │  │ Private Subnet   │         │ Private Subnet   │          │ │
│  │  │ ┌──────────────┐ │         │ ┌──────────────┐ │          │ │
│  │  │ │   Windows    │ │         │ │   Windows    │ │          │ │
│  │  │ │   Servers    │ │         │ │   Servers    │ │          │ │
│  │  │ │  (EC2 Fleet) │ │         │ │  (EC2 Fleet) │ │          │ │
│  │  │ └──────────────┘ │         │ └──────────────┘ │          │ │
│  │  │                  │         │                  │          │ │
│  │  └──────────────────┘         └──────────────────┘          │ │
│  │                                                               │ │
│  │  Internet Gateway ←→ Route Tables ←→ Security Groups        │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  Supporting Services                                          │ │
│  │  - CloudWatch (Monitoring & Logs)                             │ │
│  │  - VPC Flow Logs (Network Traffic Analysis)                   │ │
│  │  - Systems Manager (Configuration & Patching)                 │ │
│  │  - S3 (Terraform State, Artifacts, Backups)                   │ │
│  │  - DynamoDB (State Locking)                                   │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Design Patterns

- **Multi-AZ Deployment**: Resources distributed across Availability Zones for fault tolerance
- **Public/Private Subnet Isolation**: Internet-facing resources in public subnets, workloads in private subnets
- **NAT Gateway High Availability**: Separate NAT Gateways per AZ (configurable single NAT for cost optimization)
- **Infrastructure as Code**: All resources defined in version-controlled Terraform modules
- **Modular Design**: Reusable Terraform modules for networking, compute, security, and monitoring

## Features

### Network Infrastructure
- Multi-AZ VPC with configurable CIDR blocks
- Separate public and private subnets for security isolation
- Internet Gateway for outbound internet access
- NAT Gateways for private subnet internet connectivity (single or multi-NAT configurations)
- Custom route tables with automatic association
- VPC Flow Logs for network traffic analysis
- Network ACLs for additional subnet-level security

### Security & Compliance
- Defense-in-depth security model
- Security Groups for instance-level firewalling
- Network ACLs for subnet-level access control
- IAM roles with least-privilege principles
- VPC Flow Logs for audit and compliance
- Encryption support for data at rest and in transit
- Tagging strategy for resource organization and cost allocation

### High Availability & Resilience
- Multi-Availability Zone architecture
- Redundant NAT Gateways (optional)
- Auto Scaling Group support for EC2 fleets
- Automated health checks and recovery
- Disaster recovery capabilities through IaC

### Operational Excellence
- CloudWatch integration for monitoring and alerting
- Centralized logging with configurable retention
- Automated resource tagging
- Cost optimization through resource right-sizing
- Infrastructure drift detection

### Developer Experience
- Modular Terraform architecture
- Reusable infrastructure components
- Comprehensive variable configuration
- Clear separation of environments
- Validated and tested module outputs

## Quick Start Guide

### Prerequisites

Before deploying Hyperion Fleet Manager, ensure you have the following:

#### Required Tools
- **Terraform** >= 1.5.0 ([Installation Guide](https://developer.hashicorp.com/terraform/downloads))
- **AWS CLI** >= 2.0 ([Installation Guide](https://aws.amazon.com/cli/))
- **Git** for version control

#### AWS Requirements
- AWS Account with appropriate permissions
- AWS credentials configured (via `aws configure` or environment variables)
- Sufficient service quotas for VPCs, EC2 instances, and Elastic IPs

#### Recommended Knowledge
- Basic understanding of AWS services (VPC, EC2, IAM)
- Familiarity with Terraform syntax and workflows
- Understanding of networking concepts (CIDR, subnets, routing)

### AWS Credentials Setup

```bash
# Configure AWS credentials
aws configure

# Verify credentials
aws sts get-caller-identity

# Set environment variables (alternative method)
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### Deployment Steps

#### 1. Clone the Repository

```bash
git clone https://github.com/jconover/hyperion-fleet-manager.git
cd hyperion-fleet-manager
```

#### 2. Configure Terraform Backend

Create a backend configuration file for remote state management:

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket hyperion-terraform-state-$(aws sts get-caller-identity --query Account --output text) \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket hyperion-terraform-state-$(aws sts get-caller-identity --query Account --output text) \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name hyperion-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

#### 3. Initialize Terraform

```bash
cd infrastructure

# Initialize Terraform and download providers
terraform init

# Validate configuration
terraform validate
```

#### 4. Configure Variables

Create a `terraform.tfvars` file with your environment-specific values:

```hcl
# terraform.tfvars
name_prefix         = "hyperion-prod"
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]

enable_nat_gateway   = true
single_nat_gateway   = false  # Set to true for cost savings in non-prod
enable_flow_logs     = true
enable_network_acls  = true

tags = {
  Environment = "production"
  Project     = "hyperion-fleet-manager"
  ManagedBy   = "terraform"
  Owner       = "devops-team"
}
```

#### 5. Plan and Deploy

```bash
# Review the execution plan
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan

# Save outputs for reference
terraform output > outputs.txt
```

#### 6. Verify Deployment

```bash
# Verify VPC creation
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=hyperion-prod-vpc"

# Verify subnets
aws ec2 describe-subnets --filters "Name=tag:Name,Values=hyperion-prod-*"

# Check NAT Gateways
aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=hyperion-prod-*"
```

### Post-Deployment

After successful deployment:

1. Review CloudWatch Logs for VPC Flow Logs
2. Verify Security Group rules
3. Test network connectivity
4. Document the infrastructure outputs
5. Set up monitoring alerts

### Cleanup

To destroy the infrastructure (use with caution):

```bash
terraform destroy
```

## Technology Stack

### Infrastructure as Code
- **Terraform** (>= 1.5.0): Infrastructure provisioning and management
- **HCL**: HashiCorp Configuration Language for Terraform definitions

### Cloud Platform
- **Amazon Web Services (AWS)**: Primary cloud provider
  - **VPC**: Virtual Private Cloud for network isolation
  - **EC2**: Elastic Compute Cloud for Windows server instances
  - **S3**: Simple Storage Service for state and artifact storage
  - **DynamoDB**: State locking and coordination
  - **CloudWatch**: Monitoring, logging, and alerting
  - **IAM**: Identity and Access Management
  - **Systems Manager**: Configuration and patch management

### Security & Compliance
- **Security Groups**: Instance-level firewalling
- **Network ACLs**: Subnet-level access control
- **VPC Flow Logs**: Network traffic monitoring
- **IAM Roles**: Least-privilege access control

### Development & Operations
- **Git**: Version control
- **AWS CLI**: Command-line AWS management
- **CloudWatch Logs**: Centralized logging
- **Terraform State**: Remote state management with S3 backend

### Operating Systems
- **Windows Server**: Fleet workload operating system
- **Linux**: Build and deployment infrastructure

## Project Structure

```
hyperion-fleet-manager/
├── infrastructure/
│   ├── modules/
│   │   ├── networking/
│   │   │   ├── main.tf              # VPC, subnets, routing, NAT gateways
│   │   │   ├── variables.tf         # Module input variables
│   │   │   ├── outputs.tf           # Module outputs
│   │   │   └── README.md            # Module documentation
│   │   ├── compute/                 # EC2 instances and Auto Scaling
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── security/                # Security Groups, IAM roles
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   └── monitoring/              # CloudWatch, alerting
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── README.md
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── main.tf              # Development environment
│   │   │   ├── variables.tf
│   │   │   ├── terraform.tfvars
│   │   │   └── backend.tf
│   │   ├── staging/
│   │   │   ├── main.tf              # Staging environment
│   │   │   ├── variables.tf
│   │   │   ├── terraform.tfvars
│   │   │   └── backend.tf
│   │   └── prod/
│   │       ├── main.tf              # Production environment
│   │       ├── variables.tf
│   │       ├── terraform.tfvars
│   │       └── backend.tf
│   ├── main.tf                      # Root module
│   ├── variables.tf                 # Root variables
│   ├── outputs.tf                   # Root outputs
│   ├── backend.tf                   # Terraform backend configuration
│   └── terraform.tfvars.example     # Example variables file
├── scripts/
│   ├── deploy.sh                    # Deployment automation script
│   ├── destroy.sh                   # Infrastructure teardown script
│   ├── validate.sh                  # Pre-deployment validation
│   └── setup-backend.sh             # Terraform backend setup
├── docs/
│   ├── architecture/
│   │   ├── ARCHITECTURE.md          # Detailed architecture documentation
│   │   ├── diagrams/                # Architecture diagrams
│   │   └── ADR/                     # Architecture Decision Records
│   │       └── 001-terraform-state-management.md
│   ├── guides/
│   │   ├── deployment.md            # Deployment guide
│   │   ├── operations.md            # Operations manual
│   │   ├── troubleshooting.md       # Troubleshooting guide
│   │   └── security.md              # Security guidelines
│   └── CONTRIBUTING.md              # Contribution guidelines
├── tests/
│   ├── unit/                        # Terraform unit tests
│   └── integration/                 # Integration tests
├── .gitignore                       # Git ignore patterns
├── .terraform-version               # Required Terraform version
├── CHANGELOG.md                     # Version history
├── LICENSE                          # MIT License
├── README.md                        # This file
```

### Key Directories

- **infrastructure/modules**: Reusable Terraform modules for different infrastructure components
- **infrastructure/environments**: Environment-specific configurations (dev, staging, prod)
- **scripts**: Automation scripts for deployment, validation, and management
- **docs**: Comprehensive documentation including architecture, guides, and ADRs
- **tests**: Infrastructure testing and validation

## Development Guide

### Setting Up Development Environment

```bash
# Install pre-commit hooks (recommended)
pip install pre-commit
pre-commit install

# Install Terraform linting
brew install tflint  # macOS
# or
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Configure tflint
tflint --init
```

### Development Workflow

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/description
   ```

2. **Make Changes**
   - Update Terraform modules in `infrastructure/modules/`
   - Follow naming conventions and coding standards
   - Update module documentation

3. **Format and Validate**
   ```bash
   terraform fmt -recursive
   terraform validate
   tflint
   ```

4. **Test Locally**
   ```bash
   cd infrastructure/environments/dev
   terraform init
   terraform plan
   ```

5. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat: add description of changes"
   ```

6. **Push and Create Pull Request**
   ```bash
   git push origin feature/description
   ```

### Coding Standards

#### Terraform Best Practices

- Use consistent naming conventions (snake_case for resources and variables)
- Add descriptions to all variables
- Document module outputs
- Use tags on all resources
- Implement resource validation where possible
- Use data sources instead of hard-coded values
- Leverage Terraform modules for reusability

#### Example: Variable Definition

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
```

#### Example: Resource Tagging

```hcl
tags = merge(
  var.tags,
  {
    Name        = "${var.name_prefix}-resource-name"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
)
```

### Module Development

When creating new modules:

1. Create module directory structure
2. Define `variables.tf` with all inputs
3. Implement resources in `main.tf`
4. Export values in `outputs.tf`
5. Document module in `README.md`
6. Include examples in module documentation

## Testing

### Pre-Deployment Testing

```bash
# Format check
terraform fmt -check -recursive

# Validation
terraform validate

# Linting
tflint --recursive

# Security scanning
checkov -d infrastructure/
```

### Plan Review

```bash
# Generate and review plan
terraform plan -out=tfplan

# Show detailed plan
terraform show tfplan

# Analyze cost impact (using Infracost)
infracost breakdown --path .
```

### Post-Deployment Testing

```bash
# Verify VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=hyperion-*"

# Check connectivity
aws ec2 describe-route-tables

# Verify NAT Gateway functionality
# From private subnet instance
curl -I https://www.amazon.com

# Check Flow Logs
aws logs describe-log-groups --log-group-name-prefix /aws/vpc/
```

### Automated Testing

```bash
# Run Terraform tests (Terraform 1.6+)
terraform test

# Integration tests
cd tests/integration
go test -v ./...
```

## Contributing

We welcome contributions from the community! Please see our [Contributing Guide](docs/CONTRIBUTING.md) for details on:

- Code of Conduct
- Development workflow
- Coding standards
- Pull request process
- Issue reporting

### Quick Contribution Guide

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following our coding standards
4. Test your changes thoroughly
5. Commit your changes (`git commit -m 'feat: add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Documentation

- [Architecture Documentation](docs/architecture/ARCHITECTURE.md)
- [Architecture Decision Records](docs/architecture/ADR/)
- [Deployment Guide](docs/guides/deployment.md)
- [Operations Manual](docs/guides/operations.md)
- [Troubleshooting Guide](docs/guides/troubleshooting.md)
- [Security Guidelines](docs/guides/security.md)
- [Contributing Guide](docs/CONTRIBUTING.md)

## Support & Community

- Report bugs via [GitHub Issues](https://github.com/jconover/hyperion-fleet-manager/issues)
- Submit feature requests through issues
- Join discussions in GitHub Discussions
- Review the [Troubleshooting Guide](docs/guides/troubleshooting.md)

## Roadmap

### Planned Features

- [ ] Auto Scaling Group integration for EC2 fleets
- [ ] Enhanced monitoring with custom CloudWatch dashboards
- [ ] Automated backup and disaster recovery
- [ ] Multi-region support
- [ ] Kubernetes integration for container workloads
- [ ] Cost optimization recommendations
- [ ] Compliance reporting automation
- [ ] Integration with third-party monitoring tools

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2024 Hyperion Fleet Manager Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Acknowledgments

- AWS for providing comprehensive cloud infrastructure services
- HashiCorp for Terraform and infrastructure automation tools
- The open-source community for continuous inspiration and support

---

**Hyperion Fleet Manager** - Enterprise Infrastructure Automation for AWS
