# Terraform Quick Reference Guide

## Initial Setup (One Time Only)

### 1. Bootstrap Backend Infrastructure

```bash
cd /home/justin/Projects/hyperion-fleet-manager/infrastructure
./scripts/init-backend.sh
```

This creates:
- S3 bucket: `hyperion-fleet-terraform-state`
- DynamoDB table: `hyperion-fleet-terraform-lock`
- KMS key for encryption
- IAM policy for backend access

### 2. Verify Backend Creation

```bash
aws s3 ls | grep hyperion-fleet-terraform-state
aws dynamodb list-tables | grep hyperion-fleet-terraform-lock
```

## Daily Workflow

### Working with Environments

```bash
# Navigate to environment
cd environments/dev

# Initialize Terraform (first time or after module changes)
terraform init

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# View outputs
terraform output

# Destroy resources (careful!)
terraform destroy
```

## Helper Scripts

### Validate All Environments

```bash
./scripts/validate-all.sh
```

Validates:
- Global backend configuration
- All modules
- All environments

### Plan All Environments

```bash
./scripts/plan-all.sh
```

Runs `terraform plan` for dev, staging, and prod.

### Switch Environment

```bash
./scripts/switch-env.sh dev
```

Opens a new shell in the specified environment directory.

## Common Tasks

### Check State

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show module.networking.aws_vpc.main

# Pull current state
terraform state pull
```

### Import Existing Resource

```bash
terraform import aws_instance.example i-1234567890abcdef0
```

### Move Resource in State

```bash
terraform state mv aws_instance.old aws_instance.new
```

### Remove Resource from State

```bash
terraform state rm aws_instance.example
```

### Target Specific Resources

```bash
# Plan only specific module
terraform plan -target=module.networking

# Apply only specific resource
terraform apply -target=module.compute.aws_instance.app
```

### Refresh State

```bash
terraform refresh
```

### Check for Drift

```bash
terraform plan -refresh-only
```

## Environment-Specific Commands

### Development

```bash
cd environments/dev
terraform workspace select dev
terraform plan
terraform apply
```

### Staging

```bash
cd environments/staging
terraform workspace select staging
terraform plan
terraform apply
```

### Production

```bash
cd environments/prod
terraform workspace select prod
terraform plan
# Always review carefully!
terraform apply
```

## Module Testing

### Test a Single Module

```bash
cd modules/networking
terraform init -backend=false
terraform validate
terraform fmt -check
```

## Backend Management

### View State Locks

```bash
aws dynamodb scan --table-name hyperion-fleet-terraform-lock
```

### Force Unlock (Emergency Only)

```bash
terraform force-unlock <LOCK_ID>
```

### List State File Versions

```bash
aws s3api list-object-versions \
  --bucket hyperion-fleet-terraform-state \
  --prefix environments/dev/terraform.tfstate
```

### Download State Backup

```bash
aws s3 cp \
  s3://hyperion-fleet-terraform-state/environments/dev/terraform.tfstate \
  ./backup-$(date +%Y%m%d).tfstate
```

## Troubleshooting

### Provider Lock Issues

```bash
terraform providers lock -platform=linux_amd64 -platform=darwin_amd64
```

### Module Cache Issues

```bash
rm -rf .terraform
terraform init -upgrade
```

### Backend Reconfiguration

```bash
terraform init -reconfigure
```

### State Migration

```bash
terraform init -migrate-state
```

## Security Checks

### Scan for Secrets

```bash
# Before committing
grep -r "aws_access_key" .
grep -r "aws_secret_key" .
grep -r "password" *.tfvars
```

### Verify Encryption

```bash
# Check S3 bucket encryption
aws s3api get-bucket-encryption --bucket hyperion-fleet-terraform-state

# Check DynamoDB encryption
aws dynamodb describe-table --table-name hyperion-fleet-terraform-lock
```

## Cost Estimation

### Using Infracost (if installed)

```bash
infracost breakdown --path .
```

### Manual Cost Check

```bash
terraform plan -out=tfplan
# Review resource counts and types
```

## Environment Variables

### AWS Credentials

```bash
export AWS_PROFILE=default
export AWS_REGION=us-east-1
```

### Terraform Logging

```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform.log
```

### Backend Configuration

```bash
export TF_CLI_ARGS_init="-backend-config=key=custom/path/terraform.tfstate"
```

## File Structure Quick Reference

```
infrastructure/
├── global/              # Backend resources (S3 + DynamoDB)
├── environments/        # Environment configs
│   ├── dev/            # Development: 2 AZs, t3.medium
│   ├── staging/        # Staging: 3 AZs, t3.large
│   └── prod/           # Production: 3 AZs, m5.xlarge
├── modules/            # Reusable modules
│   ├── networking/     # VPC, subnets, routing
│   ├── security/       # Security groups, KMS
│   ├── compute/        # EC2, ASG, ALB
│   └── observability/  # CloudWatch, alarms
└── scripts/            # Helper scripts
```

## Important Files

### Backend Configuration
- `global/main.tf` - Backend infrastructure
- `environments/*/backend.tf` - Backend config per environment

### Environment Configuration
- `environments/*/main.tf` - Module compositions
- `environments/*/variables.tf` - Variable definitions
- `environments/*/terraform.tfvars` - Environment values
- `environments/*/outputs.tf` - Output definitions

## Version Information

- Terraform: >= 1.6.0
- AWS Provider: ~> 5.0
- Kubernetes Provider: ~> 2.23

## Useful AWS CLI Commands

### Check Current Identity

```bash
aws sts get-caller-identity
```

### List Resources by Tag

```bash
aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev"
```

### Check Security Groups

```bash
aws ec2 describe-security-groups --filters "Name=tag:Environment,Values=dev"
```

### View CloudWatch Logs

```bash
aws logs describe-log-groups --log-group-name-prefix hyperion-fleet
```

## Best Practices Checklist

- [ ] Always run `terraform plan` before `apply`
- [ ] Test in dev before promoting to staging/prod
- [ ] Review state lock status before force-unlock
- [ ] Keep modules versioned and documented
- [ ] Use meaningful commit messages
- [ ] Never commit `.tfstate` files
- [ ] Never commit secrets in `.tfvars` files
- [ ] Use KMS encryption for sensitive data
- [ ] Tag all resources consistently
- [ ] Enable CloudTrail for audit logging

## Emergency Procedures

### Rollback After Bad Apply

```bash
# 1. Identify the last good state version
aws s3api list-object-versions \
  --bucket hyperion-fleet-terraform-state \
  --prefix environments/prod/terraform.tfstate

# 2. Download the previous version
aws s3api get-object \
  --bucket hyperion-fleet-terraform-state \
  --key environments/prod/terraform.tfstate \
  --version-id <PREVIOUS_VERSION_ID> \
  terraform.tfstate.rollback

# 3. Replace current state (EXTREME CAUTION)
# Only do this after team approval
```

### Recover from Corrupted State

```bash
# 1. Backup current state
terraform state pull > corrupted-state-backup.json

# 2. Try to recover specific resources
terraform state rm <problematic_resource>
terraform import <resource_address> <resource_id>

# 3. If needed, reinitialize
terraform init -reconfigure
```

## Support Contacts

- Infrastructure Team: platform-team@example.com
- AWS Account Issues: cloud-ops@example.com
- Emergency: on-call rotation

## Additional Resources

- [Main README](/home/justin/Projects/hyperion-fleet-manager/infrastructure/README.md)
- [Terraform Docs](https://www.terraform.io/docs)
- [AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
