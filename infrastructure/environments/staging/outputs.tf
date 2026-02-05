# Staging Environment Outputs

# General Information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

# Networking Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "nat_gateway_ips" {
  description = "Public IPs of NAT Gateways"
  value       = module.networking.nat_gateway_ips
}

# Security Outputs
output "app_security_group_id" {
  description = "ID of application security group"
  value       = module.security.app_security_group_id
}

output "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  value       = module.security.kms_key_arn
  sensitive   = true
}

# Compute Outputs
output "instance_ids" {
  description = "IDs of EC2 instances"
  value       = module.compute.instance_ids
}

output "instance_private_ips" {
  description = "Private IPs of EC2 instances"
  value       = module.compute.instance_private_ips
}

output "load_balancer_dns" {
  description = "DNS name of load balancer"
  value       = module.compute.load_balancer_dns
}

output "autoscaling_group_name" {
  description = "Name of auto scaling group"
  value       = module.compute.autoscaling_group_name
}

# Observability Outputs
output "log_group_name" {
  description = "Name of CloudWatch log group"
  value       = module.observability.log_group_name
}

output "alarm_arns" {
  description = "ARNs of CloudWatch alarms"
  value       = module.observability.alarm_arns
}

output "sns_topic_arn" {
  description = "ARN of SNS topic for notifications"
  value       = module.observability.sns_topic_arn
}
