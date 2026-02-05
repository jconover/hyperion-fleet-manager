# Hyperion Fleet Manager - Infrastructure as Code

This repository contains the Terraform infrastructure code for the Hyperion Fleet Manager project. The infrastructure is organized into reusable modules and environment-specific configurations with a robust backend for state management.

## Table of Contents

- [Directory Structure](#directory-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Backend Configuration](#backend-configuration)
- [Multi-Environment Workflow](#multi-environment-workflow)
- [Module Usage](#module-usage)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Directory Structure

```
infrastructure/
├── global/                      # Global backend resources (S3 + DynamoDB)
│   ├── main.tf                 # Backend infrastructure
│   ├── variables.tf            # Global variables
│   ├── outputs.tf              # Global outputs
│   └── terraform.tfvars        # Global configuration values
│
├── environments/               # Environment-specific configurations
│   ├── dev/                   # Development environment
│   │   ├── backend.tf         # Backend configuration
│   │   ├── main.tf            # Module compositions
│   │   ├── variables.tf       # Variable definitions
│   │   ├── terraform.tfvars   # Environment values
│   │   └── outputs.tf         # Environment outputs
│   ├── staging/               # Staging environment
│   └── prod/                  # Production environment
│
├── modules/                    # Reusable Terraform modules
│   ├── networking/            # VPC, subnets, NAT gateways
│   ├── security/              # Security groups, KMS, IAM
│   ├── compute/               # EC2, ASG, ALB
│   └── observability/         # CloudWatch, alarms, logs
│
└── scripts/                    # Helper scripts
    ├── init-backend.sh        # Initialize backend resources
    ├── switch-env.sh          # Switch between environments
    ├── plan-all.sh            # Plan all environments
    └── validate-all.sh        # Validate all configurations
```

## Prerequisites

Before using this infrastructure code, ensure you have:

1. **Terraform** >= 1.6.0
   ```bash
   terraform --version
   ```

2. **AWS CLI** configured with appropriate credentials
   ```bash
   aws configure
   aws sts get-caller-identity
   ```

3. **IAM Permissions** - Your AWS user/role needs:
   - S3 bucket creation and management
   - DynamoDB table creation and management
   - KMS key management
   - EC2, VPC, and related service permissions
   - IAM policy creation

4. **SSH Key Pair** (optional) - For EC2 instance access
   ```bash
   aws ec2 create-key-pair --key-name dev-key --query 'KeyMaterial' --output text > ~/.ssh/dev-key.pem
   chmod 400 ~/.ssh/dev-key.pem
   ```

## Quick Start

### Step 1: Initialize Backend Resources

The first time you use this infrastructure, you need to create the S3 bucket and DynamoDB table for state management:

```bash
# Navigate to the infrastructure directory
cd infrastructure

# Run the backend initialization script
./scripts/init-backend.sh
```

This script will:
- Create an S3 bucket for state storage with versioning and encryption
- Create a DynamoDB table for state locking
- Configure logging and lifecycle policies
- Initialize backends for all environments

### Step 2: Deploy an Environment

After the backend is initialized, you can deploy to any environment:

```bash
# Navigate to the desired environment
cd environments/dev

# Initialize Terraform (if not already done)
terraform init

# Review the planned changes
terraform plan

# Apply the changes
terraform apply
```

### Step 3: Verify Deployment

```bash
# View outputs
terraform output

# Check state
terraform state list

# Verify resources in AWS Console
```

## Backend Configuration

### S3 State Storage

State files are stored in S3 with the following features:

- **Versioning**: Enabled to track state history
- **Encryption**: Server-side encryption (AES256)
- **Lifecycle Policies**: Old versions expire after 90 days
- **Access Logging**: All access is logged for audit trail
- **Public Access**: Blocked at the bucket level

### DynamoDB State Locking

State locking prevents concurrent modifications:

- **Lock Table**: `hyperion-fleet-terraform-lock`
- **Billing Mode**: Pay-per-request (cost-effective)
- **Encryption**: Server-side encryption enabled
- **Point-in-Time Recovery**: Enabled for disaster recovery

### Backend Configuration Files

Each environment has its own state file:

- **Dev**: `s3://hyperion-fleet-terraform-state/environments/dev/terraform.tfstate`
- **Staging**: `s3://hyperion-fleet-terraform-state/environments/staging/terraform.tfstate`
- **Production**: `s3://hyperion-fleet-terraform-state/environments/prod/terraform.tfstate`

## Multi-Environment Workflow

### Environment Isolation

Each environment is completely isolated:

- **Separate State Files**: Each environment has its own state
- **Different VPC CIDR Blocks**: No IP overlap between environments
- **Environment-Specific Tags**: All resources are tagged
- **Independent Scaling**: Each environment can scale independently

### Environment Differences

| Feature | Dev | Staging | Production |
|---------|-----|---------|------------|
| VPC CIDR | 10.0.0.0/16 | 10.10.0.0/16 | 10.20.0.0/16 |
| Availability Zones | 2 | 3 | 3 |
| NAT Gateways | 1 (single) | 3 (per AZ) | 3 (per AZ) |
| Instance Type | t3.medium | t3.large | m5.xlarge |
| Instance Count | 2 | 3 | 6 |
| ASG Min/Max | 1-4 | 2-8 | 3-12 |
| Log Retention | 7 days | 30 days | 90 days |
| CPU Alarm Threshold | 80% | 75% | 70% |

### Promoting Changes Between Environments

1. **Test in Dev First**
   ```bash
   cd environments/dev
   terraform plan
   terraform apply
   # Verify functionality
   ```

2. **Deploy to Staging**
   ```bash
   cd environments/staging
   terraform plan
   terraform apply
   # Run integration tests
   ```

3. **Deploy to Production**
   ```bash
   cd environments/prod
   terraform plan
   # Review changes carefully
   terraform apply
   # Monitor closely
   ```

### Using Helper Scripts

#### Switch Between Environments
```bash
./scripts/switch-env.sh dev
```

#### Validate All Environments
```bash
./scripts/validate-all.sh
```

#### Plan All Environments
```bash
./scripts/plan-all.sh
```

## Module Usage

### Networking Module

Creates VPC, subnets, NAT gateways, and routing:

```hcl
module "networking" {
  source = "../../modules/networking"

  environment     = "dev"
  vpc_cidr        = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}
```

### Security Module

Creates security groups, KMS keys, and IAM policies:

```hcl
module "security" {
  source = "../../modules/security"

  environment         = "dev"
  vpc_id              = module.networking.vpc_id
  allowed_cidr_blocks = ["10.0.0.0/8"]

  enable_kms_encryption = true
}
```

### Compute Module

Creates EC2 instances, Auto Scaling Groups, and Load Balancers:

```hcl
module "compute" {
  source = "../../modules/compute"

  environment        = "dev"
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids

  instance_type       = "t3.medium"
  enable_auto_scaling = true
  min_size            = 1
  max_size            = 4
}
```

### Observability Module

Creates CloudWatch logs, metrics, and alarms:

```hcl
module "observability" {
  source = "../../modules/observability"

  environment            = "dev"
  log_retention_days     = 7
  enable_cpu_alarm       = true
  cpu_threshold          = 80
  alarm_email            = "team@example.com"
}
```

## Best Practices

### State Management

1. **Never Commit State Files** - State files contain secrets
2. **Use Remote State** - Always use S3 backend
3. **Enable State Locking** - Prevent concurrent modifications
4. **Regular Backups** - S3 versioning provides automatic backups

### Security

1. **Use KMS Encryption** - Encrypt sensitive data at rest
2. **Least Privilege IAM** - Grant minimum required permissions
3. **Secret Management** - Never commit secrets to git
4. **Security Groups** - Follow principle of least access

### Code Organization

1. **Use Modules** - Promote reusability and maintainability
2. **Version Pinning** - Pin provider versions
3. **Variable Validation** - Add validation rules
4. **Consistent Naming** - Follow naming conventions

### Workflow

1. **Plan Before Apply** - Always review changes
2. **Small Changes** - Make incremental updates
3. **Test in Dev** - Validate in lower environments first
4. **Document Changes** - Keep good commit messages

### Cost Optimization

1. **Right-Sizing** - Use appropriate instance types per environment
2. **Auto Scaling** - Scale based on demand
3. **NAT Gateway** - Use single NAT in dev, multiple in prod
4. **Log Retention** - Shorter retention in dev environments

## Common Commands

### Initialize
```bash
terraform init
```

### Plan
```bash
terraform plan
terraform plan -out=tfplan
```

### Apply
```bash
terraform apply
terraform apply tfplan
```

### Destroy
```bash
terraform destroy
terraform destroy -target=module.compute
```

### State Management
```bash
terraform state list
terraform state show aws_instance.example
terraform state mv old_name new_name
terraform state rm resource_to_remove
```

### Import Existing Resources
```bash
terraform import aws_instance.example i-1234567890abcdef0
```

### Workspace Management
```bash
terraform workspace list
terraform workspace new dev
terraform workspace select dev
```

### Format and Validate
```bash
terraform fmt -recursive
terraform validate
```

### Output Management
```bash
terraform output
terraform output vpc_id
terraform output -json
```

## Troubleshooting

### State Lock Issues

If you encounter a state lock error:

```bash
# List locks
aws dynamodb scan --table-name hyperion-fleet-terraform-lock

# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Backend Initialization Errors

If backend initialization fails:

```bash
# Reconfigure backend
terraform init -reconfigure

# Migrate state
terraform init -migrate-state
```

### State Drift Detection

Check for configuration drift:

```bash
terraform plan -refresh-only
```

### Module Errors

If module errors occur:

```bash
# Reinitialize modules
terraform init -upgrade

# Get latest modules
terraform get -update
```

### Provider Issues

If provider errors occur:

```bash
# Upgrade providers
terraform init -upgrade

# Lock provider versions
terraform providers lock
```

## Disaster Recovery

### State File Recovery

State files are versioned in S3:

```bash
# List versions
aws s3api list-object-versions \
  --bucket hyperion-fleet-terraform-state \
  --prefix environments/prod/terraform.tfstate

# Restore a previous version
aws s3api get-object \
  --bucket hyperion-fleet-terraform-state \
  --key environments/prod/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.backup
```

### Backend Migration

To migrate to a new backend:

```bash
# Update backend configuration in backend.tf
# Run migration
terraform init -migrate-state
```

## Security Considerations

1. **AWS Credentials** - Never commit AWS credentials
2. **State Files** - Contain sensitive data, always encrypted
3. **tfvars Files** - Add `*.tfvars` to `.gitignore` for sensitive values
4. **Secrets** - Use AWS Secrets Manager or Parameter Store
5. **Access Control** - Use IAM roles and policies
6. **Audit Logging** - Enable CloudTrail for all API calls

## CI/CD Integration

This infrastructure can be integrated with CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
name: Terraform

on:
  pull_request:
    paths:
      - 'infrastructure/**'

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: terraform init
      - run: terraform validate
      - run: terraform plan
```

## Additional Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

## Support

For issues or questions:

1. Check this README
2. Review Terraform documentation
3. Check AWS service documentation
4. Contact the platform team

## License

Internal use only.
