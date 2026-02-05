# Auto Scaling Group Outputs
output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.fleet.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.fleet.arn
}

output "asg_id" {
  description = "ID of the Auto Scaling Group"
  value       = aws_autoscaling_group.fleet.id
}

output "asg_availability_zones" {
  description = "Availability zones used by the Auto Scaling Group"
  value       = aws_autoscaling_group.fleet.availability_zones
}

output "asg_min_size" {
  description = "Minimum size of the Auto Scaling Group"
  value       = aws_autoscaling_group.fleet.min_size
}

output "asg_max_size" {
  description = "Maximum size of the Auto Scaling Group"
  value       = aws_autoscaling_group.fleet.max_size
}

output "asg_desired_capacity" {
  description = "Desired capacity of the Auto Scaling Group"
  value       = aws_autoscaling_group.fleet.desired_capacity
}

output "asg_health_check_type" {
  description = "Health check type of the Auto Scaling Group"
  value       = aws_autoscaling_group.fleet.health_check_type
}

# Launch Template Outputs
output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.fleet.id
}

output "launch_template_arn" {
  description = "ARN of the launch template"
  value       = aws_launch_template.fleet.arn
}

output "launch_template_name" {
  description = "Name of the launch template"
  value       = aws_launch_template.fleet.name
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.fleet.latest_version
}

output "launch_template_default_version" {
  description = "Default version of the launch template"
  value       = aws_launch_template.fleet.default_version
}

# IAM Outputs
output "instance_role_name" {
  description = "Name of the IAM role attached to instances"
  value       = aws_iam_role.instance.name
}

output "instance_role_arn" {
  description = "ARN of the IAM role attached to instances"
  value       = aws_iam_role.instance.arn
}

output "instance_profile_name" {
  description = "Name of the instance profile"
  value       = aws_iam_instance_profile.instance.name
}

output "instance_profile_arn" {
  description = "ARN of the instance profile"
  value       = aws_iam_instance_profile.instance.arn
}

# Security Group Outputs
output "security_group_id" {
  description = "ID of the security group for the fleet"
  value       = aws_security_group.fleet.id
}

output "security_group_arn" {
  description = "ARN of the security group for the fleet"
  value       = aws_security_group.fleet.arn
}

output "security_group_name" {
  description = "Name of the security group for the fleet"
  value       = aws_security_group.fleet.name
}

# KMS Outputs
output "kms_key_id" {
  description = "ID of the KMS key used for EBS encryption"
  value       = aws_kms_key.ebs.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for EBS encryption"
  value       = aws_kms_key.ebs.arn
}

output "kms_alias_name" {
  description = "Alias name of the KMS key"
  value       = aws_kms_alias.ebs.name
}

# Scaling Policy Outputs
output "cpu_scaling_policy_name" {
  description = "Name of the CPU target tracking scaling policy (if enabled)"
  value       = var.enable_cpu_target_tracking ? aws_autoscaling_policy.cpu_target[0].name : null
}

output "cpu_scaling_policy_arn" {
  description = "ARN of the CPU target tracking scaling policy (if enabled)"
  value       = var.enable_cpu_target_tracking ? aws_autoscaling_policy.cpu_target[0].arn : null
}

output "network_in_scaling_policy_name" {
  description = "Name of the network in target tracking scaling policy (if enabled)"
  value       = var.enable_network_in_target_tracking ? aws_autoscaling_policy.network_in_target[0].name : null
}

output "network_in_scaling_policy_arn" {
  description = "ARN of the network in target tracking scaling policy (if enabled)"
  value       = var.enable_network_in_target_tracking ? aws_autoscaling_policy.network_in_target[0].arn : null
}

output "alb_request_count_scaling_policy_name" {
  description = "Name of the ALB request count target tracking scaling policy (if enabled)"
  value       = var.enable_alb_request_count_target_tracking ? aws_autoscaling_policy.alb_request_count_target[0].name : null
}

output "alb_request_count_scaling_policy_arn" {
  description = "ARN of the ALB request count target tracking scaling policy (if enabled)"
  value       = var.enable_alb_request_count_target_tracking ? aws_autoscaling_policy.alb_request_count_target[0].arn : null
}

# CloudWatch Alarm Outputs
output "high_cpu_alarm_name" {
  description = "Name of the high CPU utilization alarm (if enabled)"
  value       = var.enable_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.high_cpu[0].alarm_name : null
}

output "high_cpu_alarm_arn" {
  description = "ARN of the high CPU utilization alarm (if enabled)"
  value       = var.enable_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.high_cpu[0].arn : null
}

output "unhealthy_hosts_alarm_name" {
  description = "Name of the unhealthy hosts alarm (if enabled)"
  value       = var.enable_cloudwatch_alarms && var.enable_load_balancer ? aws_cloudwatch_metric_alarm.unhealthy_hosts[0].alarm_name : null
}

output "unhealthy_hosts_alarm_arn" {
  description = "ARN of the unhealthy hosts alarm (if enabled)"
  value       = var.enable_cloudwatch_alarms && var.enable_load_balancer ? aws_cloudwatch_metric_alarm.unhealthy_hosts[0].arn : null
}

# SNS Topic Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic for ASG notifications (if enabled)"
  value       = var.enable_asg_notifications ? aws_sns_topic.asg_notifications[0].arn : null
}

output "sns_topic_name" {
  description = "Name of the SNS topic for ASG notifications (if enabled)"
  value       = var.enable_asg_notifications ? aws_sns_topic.asg_notifications[0].name : null
}

# AMI Information
output "ami_id" {
  description = "AMI ID used for the instances"
  value       = var.ami_id != "" ? var.ami_id : data.aws_ami.windows_2022[0].id
}

output "ami_name" {
  description = "Name of the AMI used (only available if using auto-discovered AMI)"
  value       = var.ami_id == "" ? data.aws_ami.windows_2022[0].name : null
}

# Configuration Outputs
output "instance_types" {
  description = "List of instance types configured for the fleet"
  value       = var.instance_types
}

output "fleet_name" {
  description = "Name of the Windows fleet"
  value       = var.fleet_name
}

output "vpc_id" {
  description = "VPC ID where the fleet is deployed"
  value       = var.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs used by the fleet"
  value       = var.subnet_ids
}
