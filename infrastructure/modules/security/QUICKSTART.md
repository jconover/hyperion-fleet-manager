# Security Module - Quick Start Guide

Get the Security Module up and running in 5 minutes.

## Prerequisites

- Terraform >= 1.6.0
- AWS CLI configured with appropriate credentials
- Existing VPC with subnets
- Bastion host security group ID

## Step 1: Basic Setup (2 minutes)

Create a new directory for your infrastructure:

```bash
mkdir -p infrastructure/environments/dev
cd infrastructure/environments/dev
```

Create `main.tf`:

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "security" {
  source = "../../modules/security"

  environment  = "dev"
  project_name = "hyperion-fleet-manager"
  vpc_id       = "vpc-xxxxxxxxxxxxx"  # Replace with your VPC ID

  bastion_security_group_id = "sg-xxxxxxxxxxxxx"  # Replace with bastion SG ID

  tags = {
    Environment = "Development"
    ManagedBy   = "terraform"
  }
}
```

## Step 2: Initialize Terraform (1 minute)

```bash
terraform init
```

This will download the required providers and initialize the backend.

## Step 3: Review the Plan (1 minute)

```bash
terraform plan
```

Review the resources that will be created:
- 1 IAM role
- 1 IAM instance profile
- 3 IAM policies
- 4 KMS keys
- 3 security groups
- 1 Secrets Manager secret
- Security Hub resources (if enabled)
- GuardDuty detector (if enabled)

## Step 4: Apply Configuration (1 minute)

```bash
terraform apply
```

Type `yes` when prompted.

## Step 5: Verify Outputs (30 seconds)

```bash
terraform output
```

You should see:
- IAM role ARN and name
- Instance profile ARN and name
- All KMS key IDs and ARNs
- Security group IDs
- Secrets Manager secret ARN

## Next Steps

### Use the Security Resources

#### Attach Instance Profile to EC2

```hcl
resource "aws_instance" "windows_fleet" {
  ami                    = "ami-xxxxxxxxxxxxx"
  instance_type          = "t3.medium"
  iam_instance_profile   = module.security.windows_fleet_instance_profile_name
  vpc_security_group_ids = [module.security.windows_fleet_security_group_id]

  root_block_device {
    encrypted  = true
    kms_key_id = module.security.kms_key_ebs_id
  }

  tags = {
    Name = "windows-fleet-instance"
  }
}
```

#### Create RDS with Security Resources

```hcl
resource "aws_db_instance" "main" {
  identifier     = "hyperion-db"
  engine         = "postgres"
  engine_version = "15.5"
  instance_class = "db.t3.medium"

  allocated_storage = 100
  storage_encrypted = true
  kms_key_id        = module.security.kms_key_rds_id

  vpc_security_group_ids = [module.security.database_security_group_id]

  username = "dbadmin"
  password = module.security.db_master_password

  tags = {
    Name = "hyperion-database"
  }
}
```

#### Create ALB with Security Group

```hcl
resource "aws_lb" "main" {
  name               = "hyperion-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.security.load_balancer_security_group_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "hyperion-alb"
  }
}
```

### Retrieve Database Credentials

From EC2 instance:

```powershell
# Using AWS CLI
aws secretsmanager get-secret-value --secret-id dev-hyperion-fleet-manager-db-credentials

# Using PowerShell with AWS Tools
$secret = Get-SECSecretValue -SecretId dev-hyperion-fleet-manager-db-credentials
$credentials = $secret.SecretString | ConvertFrom-Json
$credentials.password
```

From application code:

```python
import boto3
import json

client = boto3.client('secretsmanager')
response = client.get_secret_value(SecretId='dev-hyperion-fleet-manager-db-credentials')
credentials = json.loads(response['SecretString'])

username = credentials['username']
password = credentials['password']
```

## Common Configurations

### Production Environment

```hcl
module "security" {
  source = "../../modules/security"

  environment  = "prod"
  project_name = "hyperion-fleet-manager"
  vpc_id       = var.vpc_id

  bastion_security_group_id = var.bastion_sg_id
  fleet_s3_bucket_arns = [
    "arn:aws:s3:::hyperion-data-prod",
    "arn:aws:s3:::hyperion-logs-prod"
  ]

  fleet_application_port = 8443
  alb_ingress_cidr_blocks = ["10.0.0.0/8"]

  # Production KMS settings
  kms_deletion_window = 30

  # Production secrets settings
  db_master_username     = "dbadmin"
  secret_recovery_window = 30

  # Enable all security services
  enable_security_hub  = true
  enable_cis_benchmark = true
  enable_guardduty     = true
  guardduty_finding_frequency = "FIFTEEN_MINUTES"

  tags = {
    Environment = "Production"
    Compliance  = "SOC2"
    ManagedBy   = "terraform"
  }
}
```

### Multi-Tier Application

```hcl
module "security" {
  source = "../../modules/security"

  environment  = "prod"
  project_name = "hyperion-fleet-manager"
  vpc_id       = var.vpc_id

  bastion_security_group_id = var.bastion_sg_id

  # S3 buckets for different purposes
  fleet_s3_bucket_arns = [
    "arn:aws:s3:::hyperion-application-data",
    "arn:aws:s3:::hyperion-user-uploads",
    "arn:aws:s3:::hyperion-audit-logs",
    "arn:aws:s3:::hyperion-backups"
  ]

  # Custom application port
  fleet_application_port = 8080

  # Restrict ALB access to corporate network + VPN
  alb_ingress_cidr_blocks = [
    "10.0.0.0/8",      # Corporate network
    "172.16.0.0/12",   # VPN users
    "203.0.113.0/24"   # Partner network
  ]

  tags = {
    Environment = "Production"
    Application = "Fleet Manager"
    Tier        = "Web"
  }
}
```

### Multiple Environments

```hcl
# Development
module "security_dev" {
  source = "../../modules/security"

  environment  = "dev"
  project_name = "hyperion-fleet-manager"
  vpc_id       = module.vpc_dev.vpc_id

  bastion_security_group_id = module.vpc_dev.bastion_sg_id
  fleet_s3_bucket_arns      = ["arn:aws:s3:::hyperion-dev"]

  # Development: Cost optimization
  kms_deletion_window = 7
  enable_guardduty    = false

  tags = { Environment = "Development" }
}

# Staging
module "security_staging" {
  source = "../../modules/security"

  environment  = "staging"
  project_name = "hyperion-fleet-manager"
  vpc_id       = module.vpc_staging.vpc_id

  bastion_security_group_id = module.vpc_staging.bastion_sg_id
  fleet_s3_bucket_arns      = ["arn:aws:s3:::hyperion-staging"]

  # Staging: Balanced settings
  kms_deletion_window = 14
  enable_guardduty    = true

  tags = { Environment = "Staging" }
}

# Production
module "security_prod" {
  source = "../../modules/security"

  environment  = "prod"
  project_name = "hyperion-fleet-manager"
  vpc_id       = module.vpc_prod.vpc_id

  bastion_security_group_id = module.vpc_prod.bastion_sg_id
  fleet_s3_bucket_arns = [
    "arn:aws:s3:::hyperion-data-prod",
    "arn:aws:s3:::hyperion-logs-prod"
  ]

  # Production: Maximum security
  kms_deletion_window         = 30
  enable_security_hub         = true
  enable_cis_benchmark        = true
  enable_guardduty            = true
  guardduty_finding_frequency = "FIFTEEN_MINUTES"

  tags = { Environment = "Production" }
}
```

## Validation

### Verify IAM Role

```bash
# Check role exists
aws iam get-role --role-name dev-hyperion-fleet-manager-windows-fleet-role

# Check attached policies
aws iam list-attached-role-policies --role-name dev-hyperion-fleet-manager-windows-fleet-role
```

### Verify KMS Keys

```bash
# List KMS keys
aws kms list-aliases | grep hyperion

# Check key rotation
aws kms get-key-rotation-status --key-id <key-id>
```

### Verify Security Groups

```bash
# Check security group
aws ec2 describe-security-groups --group-ids <sg-id>

# Check security group rules
aws ec2 describe-security-group-rules --filters "Name=group-id,Values=<sg-id>"
```

### Verify Secrets Manager

```bash
# Check secret exists
aws secretsmanager describe-secret --secret-id dev-hyperion-fleet-manager-db-credentials

# Get secret value (be careful with output!)
aws secretsmanager get-secret-value --secret-id dev-hyperion-fleet-manager-db-credentials
```

### Verify Security Hub

```bash
# Check Security Hub status
aws securityhub describe-hub

# List enabled standards
aws securityhub get-enabled-standards
```

### Verify GuardDuty

```bash
# List detectors
aws guardduty list-detectors

# Get detector details
aws guardduty get-detector --detector-id <detector-id>
```

## Troubleshooting

### Issue: Terraform Apply Fails

**Error**: `Error creating IAM Role`

**Solution**: Check AWS credentials and permissions
```bash
aws sts get-caller-identity
aws iam get-user
```

### Issue: KMS Key Creation Fails

**Error**: `You have exceeded the limit for KMS keys`

**Solution**: Check KMS key limits
```bash
aws service-quotas get-service-quota \
  --service-code kms \
  --quota-code L-5A5F8E4F
```

### Issue: Security Group Creation Fails

**Error**: `InvalidGroup.Duplicate`

**Solution**: Check for existing security groups
```bash
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=dev-hyperion-fleet-manager-*"
```

### Issue: Cannot Retrieve Secret

**Error**: `AccessDenied when calling GetSecretValue`

**Solution**: Check IAM permissions
```bash
aws iam simulate-principal-policy \
  --policy-source-arn <role-arn> \
  --action-names secretsmanager:GetSecretValue \
  --resource-arns <secret-arn>
```

### Issue: GuardDuty Already Enabled

**Error**: `BadRequestException: Account is already a member`

**Solution**: Import existing GuardDuty detector
```bash
# Find detector ID
DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)

# Import to Terraform
terraform import module.security.aws_guardduty_detector.main[0] $DETECTOR_ID
```

## Security Checks

Run security validation:

```bash
# Format check
terraform fmt -check -recursive

# Validation
terraform validate

# Checkov scan
checkov -d . --framework terraform

# TFLint
tflint --recursive
```

## Clean Up

To destroy resources:

```bash
# Verify what will be destroyed
terraform plan -destroy

# Destroy resources
terraform destroy

# Confirm by typing: yes
```

**Warning**: Destroying KMS keys will schedule them for deletion. They cannot be used during the deletion window (7-30 days).

To recover deleted KMS keys:

```bash
aws kms cancel-key-deletion --key-id <key-id>
```

## Getting Help

- **Documentation**: See [README.md](README.md) for full documentation
- **Architecture**: See [ARCHITECTURE.md](ARCHITECTURE.md) for design details
- **Security**: See [SECURITY.md](SECURITY.md) for security information
- **Issues**: Open an issue in the repository
- **Support**: Contact the Platform Team

## Additional Resources

### AWS Documentation

- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [KMS Developer Guide](https://docs.aws.amazon.com/kms/latest/developerguide/)
- [Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/)
- [Security Hub](https://docs.aws.amazon.com/securityhub/latest/userguide/)
- [GuardDuty](https://docs.aws.amazon.com/guardduty/latest/ug/)

### Terraform Documentation

- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Modules](https://www.terraform.io/language/modules)
- [State Management](https://www.terraform.io/language/state)

### Security Tools

- [Checkov](https://www.checkov.io/) - Security scanning
- [TFLint](https://github.com/terraform-linters/tflint) - Linting
- [terraform-docs](https://terraform-docs.io/) - Documentation generation
- [pre-commit](https://pre-commit.com/) - Git hooks

## What's Next?

After setting up the security module:

1. **Deploy Compute Resources**: Use the IAM instance profile and security groups
2. **Deploy Database**: Use the database security group and KMS key
3. **Deploy Load Balancer**: Use the load balancer security group
4. **Configure Monitoring**: Set up CloudWatch alarms and dashboards
5. **Implement Secret Rotation**: Add Lambda function for automatic rotation
6. **Review Security Hub Findings**: Address any security issues
7. **Configure GuardDuty Notifications**: Set up SNS topics for alerts

## Examples

See the [test](test/) directory for working examples:

```bash
cd test
terraform init
terraform plan
```

## Contributing

To contribute improvements:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Submit a pull request

## License

This module is part of the Hyperion Fleet Manager infrastructure.
