# Changelog

All notable changes to the Security Module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Automatic secret rotation Lambda function
- VPC endpoint support for AWS services
- Network ACL management
- AWS WAF integration for ALB
- CloudTrail integration for enhanced logging
- AWS Config rules for compliance monitoring
- SNS topics for security alerts
- Lambda function for GuardDuty finding automation

## [1.0.0] - 2026-02-04

### Added

#### IAM Resources
- Windows fleet IAM role with least privilege permissions
- EC2 instance profile for Windows fleet instances
- Custom IAM policies for S3 access with KMS encryption
- Custom IAM policies for Secrets Manager access with KMS decryption
- Attached managed policies for SSM and CloudWatch
- Conditional assume role policy with source account and ARN validation

#### KMS Keys
- Customer-managed KMS key for EBS volume encryption
- Customer-managed KMS key for RDS database encryption
- Customer-managed KMS key for S3 bucket encryption
- Customer-managed KMS key for Secrets Manager encryption
- Automatic key rotation enabled for all keys
- Service-specific key policies with ViaService conditions
- KMS aliases for easy reference

#### Security Groups
- Windows fleet security group with least privilege rules
  - RDP ingress from bastion security group only
  - Application port ingress from ALB
  - HTTPS egress for AWS services
  - PostgreSQL egress to database security group
- Application Load Balancer security group
  - HTTPS ingress from configurable CIDR blocks
  - Application port egress to Windows fleet
- Database security group
  - PostgreSQL ingress from Windows fleet only

#### Secrets Manager
- Database credentials secret with KMS encryption
- Initial secret version with auto-generated password
- Configurable recovery window (7-30 days)
- Lifecycle management for secret rotation

#### Security Services
- AWS Security Hub integration
  - AWS Foundational Security Best Practices standard
  - Optional CIS AWS Foundations Benchmark
  - Auto-enable controls
  - Control finding generator
- AWS GuardDuty integration (optional)
  - S3 protection
  - EBS malware scanning
  - Configurable finding frequency

#### Documentation
- Comprehensive README.md with usage examples
- SECURITY.md with security controls and incident response
- CHANGELOG.md for version tracking
- Example tfvars file
- JSON policy document templates
- Inline code documentation

#### Testing & Validation
- Test configuration with mock resources
- Makefile for common operations
- Pre-commit hooks configuration
- Checkov configuration for security scanning
- TFLint configuration for code quality

#### CI/CD Support
- .checkov.yaml for security scanning
- .tflint.hcl for linting rules
- .pre-commit-config.yaml for Git hooks
- Makefile targets for CI/CD pipelines

### Security Features
- All KMS keys use customer-managed keys (not AWS-managed)
- Automatic key rotation enabled
- Least privilege IAM policies
- Network segmentation via security groups
- Encryption at rest for all data
- Encryption in transit via TLS
- Security group rules use references instead of CIDR blocks
- Conditional IAM policies for enhanced security
- GuardDuty malware protection for EBS volumes
- Security Hub compliance monitoring

### Compliance Features
- Input variable validation
- Resource tagging strategy
- KMS key policies follow AWS best practices
- Security group descriptions for all rules
- Checkov compliance for security scanning
- CIS AWS Foundations Benchmark support
- SOC 2 control mappings

### Outputs
- IAM role ARNs and names
- Instance profile ARN and name
- All KMS key ARNs and IDs
- KMS key aliases
- All security group IDs and ARNs
- Secrets Manager secret ARN and name
- Security Hub account ID
- GuardDuty detector ID
- Consolidated maps for convenience

### Variables
- Environment validation (dev, staging, prod, test)
- Project name validation (lowercase, numbers, hyphens)
- VPC ID validation
- Bastion security group ID validation
- S3 bucket ARN validation
- Application port validation (1024-65535)
- CIDR block validation
- KMS deletion window validation (7-30 days)
- Secret recovery window validation (0 or 7-30 days)
- GuardDuty frequency validation
- Tag count validation (max 50)

## [0.9.0] - Development Phase

### Development Milestones

#### Phase 1: Core IAM (Completed)
- Basic IAM role structure
- SSM and CloudWatch policies
- Instance profile creation

#### Phase 2: KMS Implementation (Completed)
- EBS encryption key
- RDS encryption key
- S3 encryption key
- Secrets Manager encryption key
- Key policies and rotation

#### Phase 3: Network Security (Completed)
- Windows fleet security group
- Load balancer security group
- Database security group
- Security group rules with references

#### Phase 4: Secrets Management (Completed)
- Secrets Manager secret creation
- KMS encryption integration
- Initial secret version
- Password generation

#### Phase 5: Security Services (Completed)
- Security Hub integration
- GuardDuty integration
- Standards subscription
- Finding configuration

#### Phase 6: Documentation (Completed)
- README with examples
- Security documentation
- Policy templates
- Testing guide

#### Phase 7: Testing & Validation (Completed)
- Test configuration
- Checkov compliance
- TFLint validation
- Pre-commit hooks

## Version History

### Versioning Strategy

This module follows semantic versioning:
- **MAJOR**: Incompatible API changes
- **MINOR**: Backwards-compatible new features
- **PATCH**: Backwards-compatible bug fixes

### Upgrade Path

#### From 0.x to 1.0.0
No migration needed - initial release

### Deprecation Policy

Deprecated features will be:
1. Marked as deprecated in documentation
2. Maintained for at least 2 minor versions
3. Removed in the next major version

Example:
- v1.5.0: Feature deprecated
- v1.6.0: Still supported with warnings
- v1.7.0: Still supported with warnings
- v2.0.0: Feature removed

## Contributing

When contributing, please:
1. Update this CHANGELOG with your changes
2. Follow semantic versioning
3. Add tests for new features
4. Update documentation
5. Ensure Checkov compliance

### Changelog Categories

Use these categories:
- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security improvements

### Example Entry

```markdown
## [1.1.0] - 2026-03-15

### Added
- VPC endpoint support for SSM, Secrets Manager, and CloudWatch
- Network ACL management for enhanced network security
- SNS topic for security alerts

### Changed
- Updated KMS key policies to support VPC endpoints
- Enhanced security group rules with additional descriptions

### Fixed
- Fixed issue with secret rotation lifecycle
- Corrected GuardDuty detector tagging

### Security
- Added AWS WAF integration for ALB
- Enhanced IAM policies with additional conditions
```

## Release Process

1. Update version in this CHANGELOG
2. Update version in README badges (if applicable)
3. Create git tag: `git tag -a v1.0.0 -m "Release v1.0.0"`
4. Push tag: `git push origin v1.0.0`
5. Create GitHub release with changelog excerpt
6. Update Terraform Registry (if published)

## Support

For questions about changes or upgrades:
- Check the README for migration guides
- Review test configurations for examples
- Open an issue for support
- Contact the Platform Team

## Links

- [Repository](https://github.com/example/hyperion-fleet-manager)
- [Issue Tracker](https://github.com/example/hyperion-fleet-manager/issues)
- [Security Policy](SECURITY.md)
- [Contributing Guide](../../../CONTRIBUTING.md)
