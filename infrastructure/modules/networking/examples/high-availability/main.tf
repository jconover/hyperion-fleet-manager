# High Availability VPC Example
# Production-grade setup with NAT Gateway in each AZ

provider "aws" {
  region = "us-east-1"
}

module "networking" {
  source = "../../"

  name_prefix = "prod-ha-vpc"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # High availability: NAT Gateway per AZ
  enable_nat_gateway = true
  single_nat_gateway = false

  # Comprehensive Flow Logs
  enable_flow_logs         = true
  flow_logs_retention_days = 90
  flow_logs_traffic_type   = "ALL"

  # Network ACLs for defense in depth
  enable_network_acls = true

  # Auto-assign public IPs in public subnets
  map_public_ip_on_launch = true

  tags = {
    Environment = "production"
    Project     = "high-availability-example"
    ManagedBy   = "terraform"
    Criticality = "high"
    Compliance  = "required"
  }
}

# Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs (one per AZ)"
  value       = module.networking.nat_gateway_ids
}

output "nat_gateway_ips" {
  description = "Public IPs of NAT Gateways"
  value       = module.networking.nat_gateway_public_ips
}

output "flow_log_group" {
  description = "CloudWatch Log Group for VPC Flow Logs"
  value       = module.networking.flow_log_cloudwatch_log_group_name
}

output "high_availability_notes" {
  description = "HA configuration notes"
  value = {
    nat_gateways     = "3 NAT Gateways deployed (one per AZ)"
    failover         = "Automatic failover within each AZ"
    cross_az_traffic = "Private subnets use NAT Gateway in same AZ"
    monitoring       = "VPC Flow Logs enabled with 90-day retention"
  }
}
