# Basic Deployment Example
# This is a minimal, working configuration for testing the module
# Replace the placeholder values with your actual AWS resources

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
  region = "us-east-1" # Change to your preferred region
}

# IMPORTANT: Replace these values with your actual AWS resource IDs
locals {
  # Replace with your VPC ID
  vpc_id = "vpc-xxxxxxxxxxxxx"

  # Replace with your subnet IDs (at least 2 for high availability)
  subnet_ids = [
    "subnet-xxxxxxxxxxxxx",
    "subnet-xxxxxxxxxxxxx"
  ]

  # Optional: SNS topic ARN for alerts
  # sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:alerts"
}

# Deploy the Windows fleet
module "windows_fleet" {
  source = "../" # Points to parent directory (the module)

  # Required: Basic configuration
  fleet_name = "test-windows-fleet"
  vpc_id     = local.vpc_id
  subnet_ids = local.subnet_ids

  # Instance configuration
  instance_types   = ["t3.medium"] # Start small for testing
  min_capacity     = 1             # Minimum for cost control
  max_capacity     = 3             # Limited for testing
  desired_capacity = 1             # Start with one instance

  # Use latest Windows Server 2022 AMI
  ami_id = "" # Empty string uses latest AWS managed AMI

  # Storage configuration
  root_volume_size = 50   # Default size in GB
  root_volume_type = "gp3" # Best price/performance

  # Network configuration
  associate_public_ip = false # Use private IPs (more secure)

  # No RDP access by default (use SSM Session Manager)
  rdp_cidr_blocks   = []
  winrm_cidr_blocks = []

  # Scaling configuration
  enable_cpu_target_tracking = true
  cpu_target_value           = 70 # Scale when CPU > 70%

  # Monitoring
  enable_cloudwatch_alarms = true
  # Uncomment to enable SNS notifications
  # alarm_actions = [local.sns_topic_arn]

  # ASG notifications (optional)
  enable_asg_notifications = false

  # Optional: Custom bootstrap script
  custom_user_data_script = <<-EOT
    # Add your custom PowerShell commands here
    Write-Output "Custom configuration starting..."

    # Example: Install a Windows feature
    # Install-WindowsFeature -Name Web-Server -IncludeManagementTools

    Write-Output "Custom configuration completed"
  EOT

  # Tags (required)
  tags = {
    Environment = "development"
    Role        = "test-server"
    ManagedBy   = "terraform"
    Project     = "windows-fleet-test"
  }
}

# Outputs for easy access to important information
output "asg_name" {
  description = "Auto Scaling Group name"
  value       = module.windows_fleet.asg_name
}

output "asg_arn" {
  description = "Auto Scaling Group ARN"
  value       = module.windows_fleet.asg_arn
}

output "launch_template_id" {
  description = "Launch Template ID"
  value       = module.windows_fleet.launch_template_id
}

output "security_group_id" {
  description = "Security Group ID for the fleet"
  value       = module.windows_fleet.security_group_id
}

output "instance_role_arn" {
  description = "IAM Role ARN for instances"
  value       = module.windows_fleet.instance_role_arn
}

output "kms_key_arn" {
  description = "KMS Key ARN for EBS encryption"
  value       = module.windows_fleet.kms_key_arn
}

output "ami_id" {
  description = "AMI ID used for instances"
  value       = module.windows_fleet.ami_id
}

# Usage Instructions:
# 1. Update locals block with your VPC and subnet IDs
# 2. Run: terraform init
# 3. Run: terraform plan
# 4. Run: terraform apply
# 5. Wait ~5-10 minutes for instance to launch
# 6. Connect via SSM: aws ssm start-session --target <instance-id>
# 7. View logs: Get-Content C:\ProgramData\Bootstrap\bootstrap.log
# 8. Cleanup: terraform destroy
