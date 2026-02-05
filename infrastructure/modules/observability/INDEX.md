# Observability Module - Documentation Index

Welcome to the Observability Module documentation. This index helps you find the information you need quickly.

## Quick Navigation

### 🚀 Getting Started
- **[QUICKSTART.md](QUICKSTART.md)** - Get up and running in 5 minutes
- **[terraform.tfvars.example](terraform.tfvars.example)** - Example configuration
- **[validate.sh](validate.sh)** - Validate your configuration

### 📖 Core Documentation
- **[README.md](README.md)** - Complete module documentation (18KB)
  - Architecture overview
  - Feature descriptions
  - Usage examples (7 patterns)
  - Alarm configuration details
  - CloudWatch agent setup
  - Security best practices
  - Operational runbook
  - Troubleshooting guide
  - Cost considerations

### 📋 Reference Materials
- **[MODULE_SUMMARY.md](MODULE_SUMMARY.md)** - High-level overview
  - Module structure
  - Resources created
  - Configuration options
  - Integration points
  - Cost estimates

- **[CHANGELOG.md](CHANGELOG.md)** - Version history
  - Current version details
  - Feature breakdown
  - Known limitations
  - Future roadmap

### 💻 Code Files
- **[main.tf](main.tf)** - Main resource definitions
  - CloudWatch Log Groups
  - CloudWatch Alarms
  - SNS Topic and subscriptions
  - EventBridge Rules
  - X-Ray configuration
  - Dashboard creation

- **[variables.tf](variables.tf)** - Input variable definitions
  - 40+ configurable variables
  - Comprehensive validation
  - Default values
  - Type constraints

- **[outputs.tf](outputs.tf)** - Output definitions
  - Log group information
  - SNS topic details
  - Dashboard URLs
  - Alarm references
  - Monitoring summary

- **[versions.tf](versions.tf)** - Provider requirements
  - Terraform version >= 1.0
  - AWS provider >= 5.0

- **[examples.tf](examples.tf)** - Usage examples
  - Basic monitoring setup
  - Complete production setup
  - Multi-environment pattern
  - High-sensitivity monitoring
  - Cost-optimized monitoring
  - Security-focused monitoring
  - Infrastructure integration

### 🧪 Testing
- **[test/basic_test.tf](test/basic_test.tf)** - Terraform tests
  - Basic configuration tests
  - X-Ray enabled tests
  - Variable validation tests
  - Output verification tests

### 📊 Configuration Files
- **[cloudwatch-agent-config.json](cloudwatch-agent-config.json)** - CloudWatch agent setup
  - Memory metrics
  - Disk metrics
  - Network statistics
  - Log collection
  - Custom namespaces

- **[dashboards/fleet-health.json](dashboards/fleet-health.json)** - Dashboard definition
  - CPU/Memory widgets
  - Disk space widgets
  - Network/Disk I/O widgets
  - Target group health
  - HTTP response codes
  - Error logs
  - Security events

## Documentation by Use Case

### First-Time Users
1. Start with **[QUICKSTART.md](QUICKSTART.md)** for rapid deployment
2. Review **[MODULE_SUMMARY.md](MODULE_SUMMARY.md)** for overview
3. Reference **[terraform.tfvars.example](terraform.tfvars.example)** for configuration

### Production Deployment
1. Read **[README.md](README.md)** completely
2. Review security section for best practices
3. Check cost considerations section
4. Follow operational runbook
5. Use production example from **[examples.tf](examples.tf)**

### Troubleshooting
1. Check **[README.md](README.md)** troubleshooting section
2. Review **[QUICKSTART.md](QUICKSTART.md)** common issues
3. Run **[validate.sh](validate.sh)** for configuration issues
4. Check AWS CloudWatch documentation

### Development/Testing
1. Review **[test/basic_test.tf](test/basic_test.tf)** for test patterns
2. Use dev configuration from **[examples.tf](examples.tf)**
3. Run **[validate.sh](validate.sh)** before commits
4. Check **[CHANGELOG.md](CHANGELOG.md)** for changes

### Cost Optimization
1. Read cost considerations in **[README.md](README.md)**
2. Review cost-optimized example in **[examples.tf](examples.tf)**
3. Check **[MODULE_SUMMARY.md](MODULE_SUMMARY.md)** cost section
4. Adjust retention periods in **[terraform.tfvars.example](terraform.tfvars.example)**

### Security Hardening
1. Review security best practices in **[README.md](README.md)**
2. Use security-focused example in **[examples.tf](examples.tf)**
3. Enable KMS encryption via variables
4. Extend security log retention

### Multi-Environment Setup
1. Review multi-environment example in **[examples.tf](examples.tf)**
2. Check **[README.md](README.md)** for environment patterns
3. Use workspace strategies from **[MODULE_SUMMARY.md](MODULE_SUMMARY.md)**

## File Reference

### Terraform Files
| File | Purpose | Lines |
|------|---------|-------|
| main.tf | Resource definitions | ~470 |
| variables.tf | Input variables | ~330 |
| outputs.tf | Output definitions | ~170 |
| versions.tf | Provider versions | ~5 |
| examples.tf | Usage examples | ~350 |

### Documentation Files
| File | Purpose | Size |
|------|---------|------|
| README.md | Complete documentation | 18KB |
| QUICKSTART.md | Quick start guide | 10KB |
| MODULE_SUMMARY.md | High-level overview | 16KB |
| CHANGELOG.md | Version history | 7KB |
| INDEX.md | This file | 4KB |

### Configuration Files
| File | Purpose | Size |
|------|---------|------|
| cloudwatch-agent-config.json | Agent configuration | 6KB |
| dashboards/fleet-health.json | Dashboard layout | 9KB |
| terraform.tfvars.example | Example variables | 4KB |

### Utility Files
| File | Purpose | Executable |
|------|---------|------------|
| validate.sh | Validation script | Yes |
| .terraform-docs.yml | Docs generation | No |
| .gitignore | Git exclusions | No |

## Key Concepts

### CloudWatch Log Groups
Location: **[main.tf](main.tf)** lines 9-54
Documentation: **[README.md](README.md)** "CloudWatch Log Groups" section

Three log groups for different log types:
- `/hyperion/fleet/system` - System logs
- `/hyperion/fleet/application` - Application logs
- `/hyperion/fleet/security` - Security audit logs

### CloudWatch Alarms
Location: **[main.tf](main.tf)** lines 125-345
Documentation: **[README.md](README.md)** "Alarm Configurations" section

Multiple alarm types with configurable thresholds:
- CPU utilization (default: 80%)
- Memory utilization (default: 85%)
- Disk space (default: <15% free)
- Unhealthy hosts (default: >0)
- Application errors (default: >10/min)
- Security events (default: >0)

### SNS Notifications
Location: **[main.tf](main.tf)** lines 72-104
Documentation: **[README.md](README.md)** "SNS Configuration" section

Alert delivery via email with:
- Topic policy for CloudWatch/EventBridge
- Email subscription management
- Automatic retry logic

### EventBridge Rules
Location: **[main.tf](main.tf)** lines 376-430
Documentation: **[README.md](README.md)** "EventBridge Automation" section

Automation triggers for:
- EC2 instance state changes
- Scheduled health checks
- Automated backups

### X-Ray Tracing
Location: **[main.tf](main.tf)** lines 453-497
Documentation: **[README.md](README.md)** "X-Ray Tracing" section

Distributed tracing with:
- Sampling rules
- Trace groups
- Insights enabled
- Anomaly notifications

### CloudWatch Dashboard
Location: **[dashboards/fleet-health.json](dashboards/fleet-health.json)**
Documentation: **[README.md](README.md)** "Dashboard" section

Comprehensive visualization with:
- CPU and memory trends
- Disk space monitoring
- Network and disk I/O
- HTTP response codes
- Error and security logs
- Active alarm status

## Variable Reference

### Core Variables
- `environment` - Environment name (required)
- `alert_email_addresses` - Email list for alerts
- `instance_ids` - EC2 instances to monitor
- `target_group_arn_suffix` - Target group ARN suffix
- `load_balancer_arn_suffix` - Load balancer ARN suffix

### Threshold Variables
- `cpu_threshold_percent` - CPU alarm threshold
- `memory_threshold_percent` - Memory alarm threshold
- `disk_free_threshold_percent` - Disk space threshold
- `unhealthy_host_threshold` - Unhealthy host count
- `error_rate_threshold` - Error rate per minute

### Log Variables
- `log_retention_days` - Standard log retention
- `security_log_retention_days` - Security log retention
- `kms_key_id` - KMS key for encryption

### Feature Toggle Variables
- `enable_instance_alarms` - Enable per-instance alarms
- `enable_target_group_alarms` - Enable target group alarms
- `enable_xray` - Enable X-Ray tracing

**Complete variable list**: See **[variables.tf](variables.tf)**

## Output Reference

### Log Group Outputs
- `log_group_names` - Map of log group names
- `log_group_arns` - Map of log group ARNs

### Alert Outputs
- `sns_topic_arn` - SNS topic ARN
- `alarm_names` - Map of alarm names
- `alarm_arns` - Map of alarm ARNs

### Dashboard Outputs
- `dashboard_name` - Dashboard name
- `dashboard_url` - Direct console link

**Complete output list**: See **[outputs.tf](outputs.tf)**

## Common Tasks

### Deploy Module
```bash
terraform init
terraform plan
terraform apply
```
See: **[QUICKSTART.md](QUICKSTART.md)** Step 3-4

### Update Thresholds
Edit **[terraform.tfvars](terraform.tfvars.example)**, then:
```bash
terraform apply
```
See: **[QUICKSTART.md](QUICKSTART.md)** "Update Alarm Thresholds"

### Add Email Recipients
Edit `alert_email_addresses` in **[terraform.tfvars](terraform.tfvars.example)**
See: **[QUICKSTART.md](QUICKSTART.md)** "Add More Email Recipients"

### Install CloudWatch Agent
```bash
sudo yum install amazon-cloudwatch-agent -y
```
See: **[QUICKSTART.md](QUICKSTART.md)** "CloudWatch Agent Setup"

### View Dashboard
Get URL from:
```bash
terraform output dashboard_url
```
See: **[QUICKSTART.md](QUICKSTART.md)** "Accessing Your Dashboard"

### Test Alarms
See: **[QUICKSTART.md](QUICKSTART.md)** "Testing Alarms" section

### Troubleshoot Issues
See: **[QUICKSTART.md](QUICKSTART.md)** "Troubleshooting" section
See: **[README.md](README.md)** "Troubleshooting" section

## Support Resources

### AWS Documentation
- [CloudWatch User Guide](https://docs.aws.amazon.com/cloudwatch/)
- [X-Ray Developer Guide](https://docs.aws.amazon.com/xray/)
- [EventBridge User Guide](https://docs.aws.amazon.com/eventbridge/)
- [SNS Developer Guide](https://docs.aws.amazon.com/sns/)

### Terraform Documentation
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Language Documentation](https://www.terraform.io/language)

### Module Information
- **Module Path**: `/home/justin/Projects/hyperion-fleet-manager/infrastructure/modules/observability/`
- **Version**: 1.0.0
- **Created**: 2026-02-04
- **Terraform Version**: >= 1.0
- **AWS Provider Version**: >= 5.0

## Quick Commands

```bash
# Navigate to module
cd /home/justin/Projects/hyperion-fleet-manager/infrastructure/modules/observability/

# Validate configuration
./validate.sh

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# View outputs
terraform output

# Format code
terraform fmt -recursive

# Run tests
cd test && terraform test
```

## Getting Help

1. **Check documentation** - Most answers are in README.md
2. **Run validation** - Use validate.sh to check configuration
3. **Review examples** - Check examples.tf for patterns
4. **Check AWS console** - Verify resources in CloudWatch
5. **Review logs** - Check agent logs on EC2 instances

## Contributing

To contribute improvements:
1. Review documentation thoroughly
2. Follow Terraform best practices
3. Add tests for new features
4. Update relevant documentation files
5. Run validate.sh before submitting
6. Update CHANGELOG.md with changes

See: **[CHANGELOG.md](CHANGELOG.md)** "Contributing" section

---

**Welcome to the Observability Module!**

Start with **[QUICKSTART.md](QUICKSTART.md)** for rapid deployment or **[README.md](README.md)** for comprehensive documentation.

Module status: ✅ Production Ready
