# Security Module

Production-ready Terraform module for AWS security resources including IAM roles, KMS keys, security groups, Secrets Manager, Security Hub, and GuardDuty integration for the Hyperion Fleet Manager infrastructure.

## Features

- **IAM Roles & Policies**: Least privilege IAM roles for Windows fleet instances with SSM, CloudWatch, S3, and Secrets Manager access
- **KMS Encryption**: Customer-managed KMS keys for EBS, RDS, S3, and Secrets Manager with automatic key rotation
- **Security Groups**: Network security controls for Windows fleet, Application Load Balancer, and PostgreSQL database
- **Secrets Management**: AWS Secrets Manager integration for secure credential storage
- **Security Hub**: Centralized security posture management with AWS Foundational Security Best Practices and CIS benchmarks
- **GuardDuty**: Optional threat detection and continuous monitoring

## Architecture

### IAM Resources

- **Windows Fleet Role**: EC2 instance role with least privilege permissions
- **Instance Profile**: EC2 instance profile for Windows fleet instances
- **Managed Policies**:
  - AmazonSSMManagedInstanceCore (SSM access)
  - CloudWatchAgentServerPolicy (CloudWatch metrics/logs)
- **Custom Policies**:
  - S3 access with KMS encryption support
  - Secrets Manager access with KMS decryption

### KMS Keys

Four separate KMS keys with automatic rotation enabled:

1. **EBS Encryption**: For encrypting EC2 EBS volumes
2. **RDS Encryption**: For encrypting PostgreSQL database
3. **S3 Encryption**: For encrypting S3 bucket objects
4. **Secrets Manager**: For encrypting secrets at rest

All keys include:
- 30-day deletion window (configurable)
- Service-specific key policies
- Automatic key rotation
- KMS aliases for easy reference

### Security Groups

#### Windows Fleet Security Group
- **Ingress**: RDP (3389) from bastion security group only
- **Ingress**: Application port from load balancer
- **Egress**: HTTPS (443) for AWS services
- **Egress**: PostgreSQL (5432) to database security group

#### Load Balancer Security Group
- **Ingress**: HTTPS (443) from configurable CIDR blocks
- **Egress**: Application port to Windows fleet security group

#### Database Security Group
- **Ingress**: PostgreSQL (5432) from Windows fleet security group only

### Secrets Manager

Stores database credentials with:
- KMS encryption using dedicated key
- Configurable recovery window (7-30 days)
- JSON format for structured credential storage
- Automatic secret rotation support (lifecycle ignored for manual rotation)

## Usage

### Basic Usage

```hcl
module "security" {
  source = "./modules/security"

  environment    = "prod"
  project_name   = "hyperion-fleet-manager"
  vpc_id         = "vpc-0123456789abcdef0"

  bastion_security_group_id = "sg-0123456789abcdef0"
  fleet_s3_bucket_arns      = ["arn:aws:s3:::my-fleet-bucket"]

  fleet_application_port = 8080
  alb_ingress_cidr_blocks = ["10.0.0.0/8"]

  tags = {
    Project     = "Hyperion Fleet Manager"
    Owner       = "Platform Team"
    CostCenter  = "Engineering"
  }
}
```

### Advanced Configuration

```hcl
module "security" {
  source = "./modules/security"

  # Core Configuration
  environment  = "prod"
  project_name = "hyperion-fleet-manager"
  vpc_id       = "vpc-0123456789abcdef0"

  # Security Group Configuration
  bastion_security_group_id = "sg-0123456789abcdef0"
  fleet_application_port    = 8443
  alb_ingress_cidr_blocks   = [
    "10.0.0.0/8",      # Corporate network
    "203.0.113.0/24"   # External access
  ]

  # S3 Access Configuration
  fleet_s3_bucket_arns = [
    "arn:aws:s3:::fleet-data-prod",
    "arn:aws:s3:::fleet-logs-prod",
    "arn:aws:s3:::fleet-backups-prod"
  ]

  # KMS Configuration
  kms_deletion_window = 30

  # Secrets Manager Configuration
  db_master_username     = "dbadmin"
  secret_recovery_window = 7

  # Security Services
  enable_security_hub  = true
  enable_cis_benchmark = true
  enable_guardduty     = true
  guardduty_finding_frequency = "FIFTEEN_MINUTES"

  tags = {
    Project     = "Hyperion Fleet Manager"
    Environment = "Production"
    Owner       = "Platform Team"
    Compliance  = "SOC2"
  }
}
```

### Integration with Other Modules

```hcl
# VPC Module
module "vpc" {
  source = "./modules/vpc"
  # ... vpc configuration
}

# Security Module
module "security" {
  source = "./modules/security"

  vpc_id = module.vpc.vpc_id
  bastion_security_group_id = module.vpc.bastion_sg_id
  # ... other configuration
}

# Compute Module
module "compute" {
  source = "./modules/compute"

  instance_profile_name = module.security.windows_fleet_instance_profile_name
  security_group_ids    = [module.security.windows_fleet_security_group_id]
  ebs_kms_key_id        = module.security.kms_key_ebs_id
  # ... other configuration
}

# Database Module
module "database" {
  source = "./modules/database"

  security_group_ids = [module.security.database_security_group_id]
  kms_key_id         = module.security.kms_key_rds_id
  master_username    = "dbadmin"
  master_password    = module.security.db_master_password
  # ... other configuration
}

# Load Balancer Module
module "load_balancer" {
  source = "./modules/load_balancer"

  security_group_ids = [module.security.load_balancer_security_group_id]
  target_security_group_id = module.security.windows_fleet_security_group_id
  # ... other configuration
}
```

## Input Variables

### Required Variables

| Name | Description | Type | Example |
|------|-------------|------|---------|
| `environment` | Environment name (dev, staging, prod, test) | `string` | `"prod"` |
| `project_name` | Project name for resource naming | `string` | `"hyperion-fleet-manager"` |
| `vpc_id` | VPC ID for security groups | `string` | `"vpc-0123456789"` |
| `bastion_security_group_id` | Bastion SG ID for RDP access | `string` | `"sg-0123456789"` |

### Optional Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `fleet_s3_bucket_arns` | S3 bucket ARNs for fleet access | `list(string)` | `[]` |
| `fleet_application_port` | Application port for fleet instances | `number` | `8080` |
| `alb_ingress_cidr_blocks` | CIDR blocks for ALB HTTPS access | `list(string)` | `["0.0.0.0/0"]` |
| `kms_deletion_window` | KMS key deletion window (7-30 days) | `number` | `30` |
| `db_master_username` | Database master username | `string` | `"dbadmin"` |
| `secret_recovery_window` | Secret recovery window (0 or 7-30) | `number` | `7` |
| `enable_security_hub` | Enable Security Hub | `bool` | `true` |
| `enable_cis_benchmark` | Enable CIS benchmark in Security Hub | `bool` | `true` |
| `enable_guardduty` | Enable GuardDuty | `bool` | `false` |
| `guardduty_finding_frequency` | GuardDuty finding frequency | `string` | `"FIFTEEN_MINUTES"` |
| `tags` | Additional resource tags | `map(string)` | `{}` |

## Outputs

### IAM Outputs

| Name | Description |
|------|-------------|
| `windows_fleet_role_arn` | ARN of the Windows fleet IAM role |
| `windows_fleet_role_name` | Name of the Windows fleet IAM role |
| `windows_fleet_instance_profile_arn` | ARN of the instance profile |
| `windows_fleet_instance_profile_name` | Name of the instance profile |

### KMS Outputs

| Name | Description |
|------|-------------|
| `kms_key_ebs_arn` | ARN of the EBS KMS key |
| `kms_key_ebs_id` | ID of the EBS KMS key |
| `kms_key_rds_arn` | ARN of the RDS KMS key |
| `kms_key_rds_id` | ID of the RDS KMS key |
| `kms_key_s3_arn` | ARN of the S3 KMS key |
| `kms_key_s3_id` | ID of the S3 KMS key |
| `kms_key_secrets_manager_arn` | ARN of the Secrets Manager KMS key |
| `kms_key_secrets_manager_id` | ID of the Secrets Manager KMS key |
| `kms_key_arns` | Map of all KMS key ARNs |
| `kms_key_ids` | Map of all KMS key IDs |

### Security Group Outputs

| Name | Description |
|------|-------------|
| `windows_fleet_security_group_id` | ID of the Windows fleet security group |
| `load_balancer_security_group_id` | ID of the load balancer security group |
| `database_security_group_id` | ID of the database security group |
| `security_group_ids` | Map of all security group IDs |

### Secrets Manager Outputs

| Name | Description |
|------|-------------|
| `db_credentials_secret_arn` | ARN of the database credentials secret |
| `db_credentials_secret_name` | Name of the database credentials secret |
| `db_master_password` | Database master password (sensitive) |

### Security Services Outputs

| Name | Description |
|------|-------------|
| `security_hub_account_id` | Security Hub account ID |
| `security_hub_enabled` | Whether Security Hub is enabled |
| `guardduty_detector_id` | GuardDuty detector ID |
| `guardduty_enabled` | Whether GuardDuty is enabled |

## Security Considerations

### Least Privilege IAM

All IAM policies follow the principle of least privilege:
- EC2 assume role includes conditions for source account and instance ARN
- S3 access limited to specific buckets via variable
- Secrets Manager access restricted to specific secret ARN
- KMS access scoped via ViaService conditions

### Network Security

Security groups implement defense in depth:
- RDP access restricted to bastion host only
- Database access limited to application tier
- No direct internet access for database tier
- Application tier accessed only through load balancer

### Encryption

All data encrypted at rest and in transit:
- EBS volumes encrypted with customer-managed KMS keys
- RDS encrypted with dedicated KMS key
- S3 buckets use KMS encryption
- Secrets Manager uses KMS encryption
- All KMS keys have automatic rotation enabled

### Compliance

Module designed for compliance frameworks:
- Security Hub with AWS Foundational Security Best Practices
- Optional CIS AWS Foundations Benchmark
- GuardDuty for threat detection
- Audit logging enabled through CloudTrail integration
- Resource tagging for governance

## Best Practices

### Tagging Strategy

Always include comprehensive tags:

```hcl
tags = {
  Environment = "prod"
  Project     = "Hyperion Fleet Manager"
  Owner       = "platform-team@example.com"
  CostCenter  = "engineering"
  Compliance  = "SOC2"
  Terraform   = "true"
  Repository  = "github.com/jconover/hyperion-fleet-manager"
}
```

### KMS Key Rotation

- Automatic key rotation enabled for all keys
- 30-day deletion window provides recovery time
- Use KMS aliases in application code, not key IDs
- Monitor key usage through CloudWatch metrics

### Secrets Rotation

Secrets Manager secrets should be rotated regularly:

```hcl
resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  secret_id           = module.security.db_credentials_secret_arn
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

### Security Group Rules

- Use security group references instead of CIDR blocks when possible
- Document all rules with clear descriptions
- Review and audit rules quarterly
- Use VPC Flow Logs to monitor traffic patterns

### GuardDuty Configuration

Enable GuardDuty in production environments:

```hcl
enable_guardduty = true
guardduty_finding_frequency = "FIFTEEN_MINUTES"
```

Set up SNS notifications for findings:

```hcl
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "guardduty-findings"
  description = "Capture GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })
}
```

## Compliance & Security Scanning

### Checkov Compliance

This module is designed to pass Checkov security scanning. Key compliance features:

- ✅ KMS keys with automatic rotation enabled
- ✅ Security group rules with descriptions
- ✅ IAM policies with conditions and restrictions
- ✅ Secrets Manager with encryption and recovery window
- ✅ Security Hub with default standards enabled
- ✅ GuardDuty with malware protection

Run Checkov to verify compliance:

```bash
checkov -d infrastructure/modules/security/
```

### Security Hub Standards

Enabled standards:
- AWS Foundational Security Best Practices v1.0.0
- CIS AWS Foundations Benchmark v1.2.0 (optional)

### Monitoring & Alerting

Set up CloudWatch alarms for security events:

```hcl
resource "aws_cloudwatch_metric_alarm" "kms_key_disabled" {
  alarm_name          = "${var.environment}-kms-key-disabled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UserErrorCount"
  namespace           = "AWS/KMS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when KMS key is disabled"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}
```

## Testing

### Unit Tests

Test module with different configurations:

```bash
cd tests/security
terraform init
terraform plan -var-file=test.tfvars
```

### Integration Tests

Use Terratest for automated testing:

```go
func TestSecurityModule(t *testing.T) {
    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../../modules/security",
        VarFiles:     []string{"test.tfvars"},
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    // Verify outputs
    roleArn := terraform.Output(t, terraformOptions, "windows_fleet_role_arn")
    assert.Contains(t, roleArn, "arn:aws:iam::")
}
```

## Troubleshooting

### Common Issues

**Issue**: KMS key policy prevents deletion
```
Error: KMS key is pending deletion
```
**Solution**: Wait for deletion window to expire or restore key:
```bash
aws kms cancel-key-deletion --key-id <key-id>
```

**Issue**: Security group has dependencies
```
Error: resource has a dependent object
```
**Solution**: Check for EC2 instances or ENIs using the security group:
```bash
aws ec2 describe-network-interfaces --filters Name=group-id,Values=<sg-id>
```

**Issue**: Secrets Manager secret in use
```
Error: cannot delete secret with versions
```
**Solution**: Use recovery window or force deletion:
```hcl
secret_recovery_window = 0  # Force immediate deletion (not recommended)
```

## Maintenance

### Quarterly Reviews

- Review IAM policies for unused permissions
- Audit security group rules
- Check KMS key usage and costs
- Review GuardDuty findings
- Update Security Hub compliance status

### Annual Tasks

- Rotate KMS keys manually if needed
- Review and update secret rotation policies
- Update compliance standards to latest versions
- Conduct security audit and penetration testing

## Migration Guide

### Importing Existing Resources

Import existing IAM roles:
```bash
terraform import module.security.aws_iam_role.windows_fleet my-existing-role
```

Import existing KMS keys:
```bash
terraform import module.security.aws_kms_key.ebs <key-id>
```

Import existing security groups:
```bash
terraform import module.security.aws_security_group.windows_fleet sg-0123456789
```

## Version History

- **v1.0.0**: Initial production release
  - IAM roles with least privilege
  - KMS keys for EBS, RDS, S3, Secrets Manager
  - Security groups for Windows fleet, ALB, database
  - Secrets Manager integration
  - Security Hub and GuardDuty support

## Contributing

When contributing to this module:

1. Follow Terraform best practices
2. Ensure Checkov compliance
3. Add tests for new features
4. Update documentation
5. Use semantic versioning

## License

This module is part of the Hyperion Fleet Manager infrastructure.

## Support

For issues or questions:
- Create an issue in the repository
- Contact the Platform Team
- Review AWS documentation for service-specific questions

## References

- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [AWS Security Hub](https://docs.aws.amazon.com/securityhub/)
- [AWS GuardDuty](https://docs.aws.amazon.com/guardduty/)
