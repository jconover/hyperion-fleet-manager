# Quick Start Guide - Windows EC2 Fleet Module

This guide will help you deploy a Windows EC2 fleet in 5 minutes.

## Prerequisites

- Terraform >= 1.5.0 installed
- AWS CLI configured with appropriate credentials
- VPC and subnets already created
- Basic understanding of Auto Scaling Groups

## Step 1: Create Your Configuration

Create a new file `main.tf` in your project directory:

```hcl
terraform {
  required_version = ">= 1.5.0"

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

module "windows_fleet" {
  source = "./infrastructure/modules/compute"

  fleet_name = "my-app-fleet"
  vpc_id     = "vpc-xxxxxxxxxxxxx"  # Replace with your VPC ID
  subnet_ids = [
    "subnet-xxxxxxxxxxxxx",          # Replace with your subnet IDs
    "subnet-xxxxxxxxxxxxx"
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

# Output important information
output "asg_name" {
  value = module.windows_fleet.asg_name
}

output "security_group_id" {
  value = module.windows_fleet.security_group_id
}
```

## Step 2: Initialize Terraform

```bash
terraform init
```

This downloads the AWS provider and prepares your workspace.

## Step 3: Preview Changes

```bash
terraform plan
```

Review the resources that will be created:
- 1 Auto Scaling Group
- 1 Launch Template
- 1 IAM Role + Instance Profile
- 1 Security Group
- 1 KMS Key
- 1 Scaling Policy
- 2 CloudWatch Alarms (by default)

## Step 4: Deploy

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes approximately 5-10 minutes.

## Step 5: Verify Deployment

```bash
# Get the ASG name
export ASG_NAME=$(terraform output -raw asg_name)

# Check ASG status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]' \
  --output table

# List running instances
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState]' \
  --output table
```

## Step 6: Connect to Instances

### Option A: SSM Session Manager (Recommended)

```bash
# Get an instance ID
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

# Start SSM session
aws ssm start-session --target $INSTANCE_ID
```

### Option B: RDP (If Enabled)

```bash
# Get instance public IP
aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text

# Use RDP client to connect
```

## Step 7: View Bootstrap Logs

Once connected via SSM:

```powershell
# View bootstrap log
Get-Content C:\ProgramData\Bootstrap\bootstrap.log -Tail 50

# Check bootstrap completion
Test-Path C:\ProgramData\Bootstrap\bootstrap.complete
```

## Common Configurations

### Enable Load Balancer Integration

```hcl
module "windows_fleet" {
  # ... other configuration ...

  enable_load_balancer = true
  target_group_arns = [
    aws_lb_target_group.app.arn
  ]
}
```

### Add Data Volumes

```hcl
module "windows_fleet" {
  # ... other configuration ...

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
}
```

### Use Spot Instances

```hcl
module "windows_fleet" {
  # ... other configuration ...

  on_demand_base_capacity                  = 2
  on_demand_percentage_above_base_capacity = 20
  spot_allocation_strategy                 = "capacity-optimized"
}
```

### Add Custom Bootstrap Script

```hcl
module "windows_fleet" {
  # ... other configuration ...

  custom_user_data_script = <<-EOT
    Write-Output "Installing IIS..."
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools

    Write-Output "Configuring application..."
    # Your custom PowerShell commands here
  EOT
}
```

## Monitoring

### View CloudWatch Metrics

```bash
# CPU Utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Group Desired Capacity
aws cloudwatch get-metric-statistics \
  --namespace AWS/AutoScaling \
  --metric-name GroupDesiredCapacity \
  --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### View CloudWatch Logs

```bash
# List log streams
aws logs describe-log-streams \
  --log-group-name "/aws/ec2/windows/my-app-fleet/system" \
  --max-items 10

# View recent bootstrap logs
aws logs tail "/aws/ec2/windows/my-app-fleet/bootstrap" --follow
```

## Scaling Operations

### Manual Scaling

```bash
# Scale up
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $ASG_NAME \
  --desired-capacity 5

# Scale down
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $ASG_NAME \
  --desired-capacity 2
```

### Update Terraform Configuration

```bash
# Edit your main.tf to change desired_capacity
terraform apply
```

## Updating the Fleet

### Update AMI

```hcl
module "windows_fleet" {
  # ... other configuration ...

  ami_id = "ami-new123456789"  # Specify new AMI
}
```

```bash
terraform apply
```

Instance refresh will automatically roll out the new AMI.

### Update Instance Types

```hcl
module "windows_fleet" {
  # ... other configuration ...

  instance_types = ["t3.large", "t3.xlarge"]  # New types
}
```

```bash
terraform apply
```

## Troubleshooting

### Instances Not Starting

```bash
# Check ASG activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $ASG_NAME \
  --max-records 10

# Check launch template
aws ec2 describe-launch-template-versions \
  --launch-template-id $(terraform output -raw launch_template_id) \
  --versions '$Latest'
```

### SSM Not Working

```bash
# Verify SSM agent status
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID"

# Check IAM role
aws iam get-instance-profile \
  --instance-profile-name $(terraform output -raw instance_profile_name)
```

### High Costs

```bash
# Check instance types in use
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceType,InstanceId]' \
  --output table

# Consider using Spot instances (see configuration above)
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` when prompted. This will:
1. Terminate all instances
2. Delete the Auto Scaling Group
3. Delete the Launch Template
4. Remove IAM roles and policies
5. Delete Security Groups
6. Schedule KMS key deletion (30-day default)

## Next Steps

1. **Review Security**: Configure security groups appropriately
2. **Set Up Monitoring**: Create CloudWatch dashboards
3. **Configure Backups**: Implement EBS snapshot policies
4. **Document Runbooks**: Create operational procedures
5. **Test Disaster Recovery**: Validate recovery procedures

## Additional Resources

- [Full README](README.md) - Complete documentation
- [Examples](examples.tf) - Real-world usage examples
- [Variables](variables.tf) - All configuration options
- [Outputs](outputs.tf) - Available output values

## Support

For issues or questions:
1. Check the [README](README.md) troubleshooting section
2. Review [CHANGELOG](CHANGELOG.md) for recent changes
3. Validate your configuration with `terraform validate`
4. Review AWS CloudWatch logs for instance issues

## Cost Estimate

Estimated monthly costs for default configuration (2-3 t3.medium instances):

- EC2 Instances: ~$60-90/month
- EBS Storage (50GB per instance): ~$10-15/month
- Data Transfer: Variable
- CloudWatch Logs: ~$0.50/GB ingested
- **Total**: ~$70-120/month (excluding data transfer)

Use AWS Cost Explorer for precise costs in your environment.
