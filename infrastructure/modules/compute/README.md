# Windows EC2 Fleet Terraform Module

Production-ready Terraform module for deploying and managing Windows Server 2022 EC2 fleets with Auto Scaling Groups on AWS.

## Features

- Auto Scaling Groups with mixed instance types support
- Windows Server 2022 with latest AWS managed AMIs
- Launch templates with PowerShell bootstrap scripts
- Encrypted EBS volumes using KMS
- SSM Agent pre-configured for remote management
- CloudWatch Agent for metrics and log collection
- IAM roles and instance profiles for AWS service integration
- Multiple health check options (EC2 and ELB)
- Target tracking scaling policies
- IMDSv2 enforcement for enhanced security
- Comprehensive tagging strategy
- Instance refresh capabilities
- CloudWatch alarms and SNS notifications

## Security Features

- IMDSv2 required (prevents SSRF attacks)
- EBS volumes encrypted with customer-managed KMS keys
- KMS key rotation enabled
- IAM least privilege access
- Security groups with restrictive rules
- SSM Session Manager for secure access (no SSH/RDP required)
- No hardcoded credentials
- HTTPS-only communication

## Requirements

- Terraform >= 1.5.0
- AWS Provider ~> 5.0
- VPC with subnets configured
- Appropriate IAM permissions

## Usage

### Basic Example

```hcl
module "windows_fleet" {
  source = "./modules/compute"

  fleet_name = "app-servers"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = [
    "subnet-0123456789abcdef0",
    "subnet-0123456789abcdef1",
    "subnet-0123456789abcdef2"
  ]

  instance_types   = ["t3.medium", "t3.large"]
  min_capacity     = 2
  max_capacity     = 10
  desired_capacity = 3

  tags = {
    Environment = "production"
    Role        = "application-server"
    ManagedBy   = "terraform"
  }
}
```

### Advanced Example with Load Balancer Integration

```hcl
module "windows_fleet" {
  source = "./modules/compute"

  fleet_name = "web-servers"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = [
    "subnet-0123456789abcdef0",
    "subnet-0123456789abcdef1",
    "subnet-0123456789abcdef2"
  ]

  # Instance configuration
  instance_types   = ["t3.medium", "t3.large", "c5.xlarge"]
  min_capacity     = 3
  max_capacity     = 20
  desired_capacity = 5

  # Storage configuration
  root_volume_size = 100
  root_volume_type = "gp3"

  data_volumes = [
    {
      device_name           = "xvdf"
      size                  = 200
      type                  = "gp3"
      delete_on_termination = true
      iops                  = 3000
      throughput            = 125
    }
  ]

  # Load balancer integration
  enable_load_balancer = true
  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  # Scaling policies
  enable_cpu_target_tracking = true
  cpu_target_value           = 70

  enable_alb_request_count_target_tracking = true
  alb_request_count_target_value           = 1000
  alb_target_group_resource_label          = "app/my-alb/1234567890/targetgroup/my-tg/1234567890"

  # Network security
  allowed_security_group_ids = [
    aws_security_group.alb.id
  ]

  # CloudWatch alarms
  enable_cloudwatch_alarms = true
  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  # ASG notifications
  enable_asg_notifications = true

  # Custom bootstrap script
  custom_user_data_script = <<-EOT
    Write-Output "Installing application..."
    # Add your custom PowerShell commands here
  EOT

  tags = {
    Environment = "production"
    Role        = "web-server"
    ManagedBy   = "terraform"
    Application = "web-app"
  }
}
```

### Spot Instances Example

```hcl
module "windows_fleet" {
  source = "./modules/compute"

  fleet_name = "batch-processors"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-0123456789abcdef0"]

  instance_types   = ["c5.xlarge", "c5.2xlarge", "c5a.xlarge"]
  min_capacity     = 0
  max_capacity     = 50
  desired_capacity = 10

  # Spot configuration
  on_demand_base_capacity                  = 2
  on_demand_percentage_above_base_capacity = 20
  spot_allocation_strategy                 = "capacity-optimized"
  spot_max_price                           = ""  # Use on-demand price as max

  tags = {
    Environment = "production"
    Role        = "batch-processor"
    ManagedBy   = "terraform"
  }
}
```

## Variables

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| fleet_name | Name of the Windows fleet | string |
| vpc_id | VPC ID where fleet will be deployed | string |
| subnet_ids | List of subnet IDs for Auto Scaling Group | list(string) |

### Optional Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| ami_id | Custom AMI ID (uses latest Windows Server 2022 if empty) | string | "" |
| instance_types | List of instance types | list(string) | ["t3.medium", "t3.large", "c5.xlarge"] |
| min_capacity | Minimum instances | number | 1 |
| max_capacity | Maximum instances | number | 10 |
| desired_capacity | Desired instances | number | 2 |
| root_volume_size | Root volume size in GB | number | 50 |
| root_volume_type | Root volume type | string | "gp3" |
| data_volumes | Additional data volumes | list(object) | [] |
| enable_cpu_target_tracking | Enable CPU scaling policy | bool | true |
| cpu_target_value | Target CPU percentage | number | 70 |
| enable_load_balancer | Enable ELB health checks | bool | false |
| target_group_arns | Load balancer target groups | list(string) | [] |
| rdp_cidr_blocks | CIDR blocks for RDP access | list(string) | [] |
| custom_user_data_script | Custom PowerShell script | string | "" |
| tags | Resource tags | map(string) | See variables.tf |

For complete variable documentation, see [variables.tf](variables.tf).

## Outputs

| Name | Description |
|------|-------------|
| asg_name | Auto Scaling Group name |
| asg_arn | Auto Scaling Group ARN |
| launch_template_id | Launch template ID |
| instance_role_arn | IAM role ARN for instances |
| instance_profile_arn | Instance profile ARN |
| security_group_id | Security group ID |
| kms_key_arn | KMS key ARN for EBS encryption |

For complete output documentation, see [outputs.tf](outputs.tf).

## Bootstrap Script

The module includes a comprehensive PowerShell bootstrap script that:

- Configures PowerShell execution policy
- Sets up Windows Time Service with AWS NTP
- Configures timezone to UTC
- Verifies and starts SSM Agent
- Installs and configures CloudWatch Agent
- Configures Windows Firewall
- Initializes and formats additional EBS volumes
- Optimizes system performance
- Configures Windows Update settings
- Sets up event log retention
- Executes custom user data scripts
- Logs all activities to `C:\ProgramData\Bootstrap\bootstrap.log`

## CloudWatch Integration

The module automatically configures CloudWatch Agent to collect:

### Logs
- System Event Log (errors, warnings, critical)
- Application Event Log (errors, warnings, critical)
- Bootstrap execution logs

### Metrics
- CPU utilization
- Memory utilization
- Disk free space

All logs are organized by fleet name: `/aws/ec2/windows/{fleet_name}/{log_type}`

## Scaling Policies

### CPU Target Tracking
Automatically scales based on average CPU utilization across the fleet.

### Network In Target Tracking
Scales based on network traffic (bytes received).

### ALB Request Count Target Tracking
Scales based on requests per target when using Application Load Balancer.

## Security Best Practices

1. **Use SSM Session Manager** instead of RDP for remote access
2. **Keep `rdp_cidr_blocks` empty** unless absolutely necessary
3. **Enable CloudWatch logging** for audit trails
4. **Rotate AMIs regularly** by updating `ami_id`
5. **Use private subnets** and set `associate_public_ip = false`
6. **Review IAM policies** regularly for least privilege
7. **Enable KMS key rotation** (enabled by default)
8. **Monitor CloudWatch alarms** and configure SNS notifications

## Cost Optimization

1. **Use Spot Instances** for fault-tolerant workloads
2. **Enable multiple instance types** for better Spot availability
3. **Right-size instances** based on CloudWatch metrics
4. **Use gp3 volumes** instead of gp2 for better price/performance
5. **Configure appropriate scaling policies** to avoid over-provisioning
6. **Use on-demand base capacity** for critical workloads only

## Operational Procedures

### Updating AMI

```hcl
module "windows_fleet" {
  source = "./modules/compute"

  ami_id = "ami-new123456"  # Specify new AMI

  # Instance refresh will automatically roll out new AMI
  instance_refresh_min_healthy_percentage = 90
  instance_refresh_instance_warmup        = 300
}
```

### Scaling the Fleet

```bash
# Increase desired capacity
terraform apply -var="desired_capacity=5"

# Or use AWS CLI
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name {asg_name} \
  --desired-capacity 5
```

### Viewing Bootstrap Logs

```bash
# Using SSM Session Manager
aws ssm start-session --target {instance_id}

# Then view logs
Get-Content C:\ProgramData\Bootstrap\bootstrap.log
```

### Troubleshooting

1. **Instances not launching**: Check IAM permissions and subnet configurations
2. **SSM not working**: Verify instance profile and SSM endpoints
3. **CloudWatch Agent not sending data**: Check IAM permissions and agent configuration
4. **Health checks failing**: Review security group rules and target group settings

## Module Structure

```
compute/
├── main.tf           # Main resources (ASG, launch template, IAM, KMS)
├── variables.tf      # Input variables with validation
├── outputs.tf        # Output values
├── user_data.ps1     # PowerShell bootstrap script
└── README.md         # This file
```

## Compliance

This module follows AWS best practices and supports compliance with:

- CIS AWS Foundations Benchmark
- NIST Cybersecurity Framework
- AWS Well-Architected Framework
- SOC 2 requirements

## Support and Maintenance

### Version Compatibility

| Module Version | Terraform Version | AWS Provider |
|---------------|-------------------|--------------|
| 1.x.x         | >= 1.5.0          | ~> 5.0       |

### Updates

This module is actively maintained. Regular updates include:
- Latest Windows Server 2022 AMI support
- Security patches and improvements
- New AWS features integration
- Performance optimizations

## License

This module is provided as-is for use in your infrastructure projects.

## Examples

See the `examples/` directory for additional usage examples:
- Basic fleet deployment
- Multi-tier application architecture
- Spot instance configuration
- Blue-green deployments
- Disaster recovery setup

## Contributing

When contributing improvements:
1. Follow Terraform best practices
2. Update documentation
3. Add variable validation
4. Include examples
5. Test thoroughly in multiple environments

## Resources Created

This module creates the following AWS resources:

- Auto Scaling Group
- Launch Template
- IAM Role and Instance Profile
- IAM Role Policies
- Security Group and Rules
- KMS Key and Alias
- CloudWatch Alarms (optional)
- SNS Topic (optional)
- Auto Scaling Policies

## Related Modules

- Load Balancer Module (for target groups)
- VPC Module (for networking)
- Monitoring Module (for centralized observability)
- Backup Module (for EBS snapshots)
