# Changelog

All notable changes to this Windows EC2 Fleet Terraform module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-04

### Added

#### Core Features
- Auto Scaling Group with mixed instances policy support
- Launch template configuration for Windows Server 2022
- Support for multiple instance types (t3.medium, t3.large, c5.xlarge)
- Automatic latest Windows Server 2022 AMI discovery
- Custom AMI support

#### Security Features
- IMDSv2 enforcement for enhanced security
- KMS key creation and management for EBS encryption
- Automatic KMS key rotation
- IAM roles and instance profiles with least privilege access
- Security group with configurable ingress/egress rules
- Support for RDP and WinRM access controls (optional)
- SSM Session Manager support for secure remote access

#### Storage Features
- Encrypted root EBS volumes with KMS
- Support for additional encrypted data volumes
- Configurable volume types (gp3, gp2, io1, io2)
- IOPS and throughput configuration for high-performance volumes
- Automatic disk initialization and formatting via user data

#### Scaling Features
- Target tracking scaling policy for CPU utilization
- Target tracking scaling policy for network traffic
- Target tracking scaling policy for ALB request count
- Configurable min/max/desired capacity
- Instance refresh capabilities
- Mixed instances policy for on-demand and Spot instances
- Multiple Spot allocation strategies

#### Monitoring Features
- CloudWatch Agent automatic installation and configuration
- System and Application event log collection
- Custom metrics collection (CPU, Memory, Disk)
- CloudWatch alarms for high CPU utilization
- CloudWatch alarms for unhealthy hosts
- SNS topic for Auto Scaling notifications
- Comprehensive bootstrap logging

#### Load Balancer Integration
- Application Load Balancer target group support
- Network Load Balancer support
- ELB health check integration
- Configurable health check grace period

#### Operational Features
- Comprehensive PowerShell bootstrap script
- Windows Time Service configuration with AWS NTP
- Automatic SSM Agent verification and startup
- Windows Update configuration
- System performance optimization
- Event log retention configuration
- Custom user data script injection support
- Instance metadata retrieval and storage

#### Documentation
- Comprehensive README with usage examples
- Variable validation with helpful error messages
- Complete input/output documentation
- Security best practices guide
- Cost optimization recommendations
- Operational procedures
- Troubleshooting guide
- Multiple real-world examples

#### Configuration Management
- Extensive variable validation
- Sensible defaults for all optional variables
- Support for complex object variables
- Tag propagation to all resources
- Required tags enforcement (Environment, Role, ManagedBy)

### Technical Details

#### IAM Policies
- AmazonSSMManagedInstanceCore for Systems Manager
- CloudWatchAgentServerPolicy for metrics and logs
- Custom KMS policy for encryption access

#### User Data Script Features
- PowerShell execution policy configuration
- Windows Time Service synchronization
- Timezone configuration (UTC)
- Firewall rule configuration
- SSM Agent management
- CloudWatch Agent setup with JSON configuration
- Instance metadata retrieval with IMDSv2
- Windows Update settings
- Service optimization
- Additional disk initialization
- Event log configuration
- Computer description setting
- Custom script execution
- Comprehensive logging

#### CloudWatch Metrics
- Logical Disk % Free Space
- Memory % Committed Bytes In Use
- Processor % Processor Time

#### CloudWatch Log Groups
- System event logs: `/aws/ec2/windows/{fleet_name}/system`
- Application event logs: `/aws/ec2/windows/{fleet_name}/application`
- Bootstrap logs: `/aws/ec2/windows/{fleet_name}/bootstrap`

#### Resource Tags
All resources tagged with:
- Name (resource-specific)
- Environment (from variable)
- Role (from variable)
- ManagedBy (from variable)
- Custom tags (from variable)

### Requirements
- Terraform >= 1.5.0
- AWS Provider ~> 5.0
- VPC with subnets configured
- Appropriate IAM permissions

### Compliance
- CIS AWS Foundations Benchmark compliant
- Supports NIST Cybersecurity Framework
- AWS Well-Architected Framework aligned
- SOC 2 requirements supported

### Known Limitations
- Windows Server 2022 only (by default)
- Single region deployment per module instance
- Requires existing VPC and subnets

### Future Enhancements
Planned for future releases:
- Support for Windows Server 2019
- Cross-region AMI copying
- Automated backup integration
- Enhanced monitoring dashboards
- Custom metric filters
- Integration with AWS Config
- Support for AWS Systems Manager Patch Manager
- Automated security scanning
- Cost anomaly detection
- Multi-region deployment support

## Version History

- **1.0.0** - Initial production release with comprehensive features

---

## Release Notes Template

When creating new releases, use this template:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes to existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security updates and fixes
```

## Upgrade Guide

### Upgrading to 1.0.0

This is the initial release. No upgrade steps required.

For future upgrades, specific instructions will be provided here.

## Support

For issues, questions, or contributions, please refer to the module documentation.
