# Basic VPC Example
# Creates a simple VPC with public and private subnets across 3 AZs

provider "aws" {
  region = "us-east-1"
}

module "networking" {
  source = "../../"

  name_prefix = "basic-vpc"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # Enable NAT Gateway for private subnet internet access
  enable_nat_gateway = true
  single_nat_gateway = false

  # Enable VPC Flow Logs
  enable_flow_logs         = true
  flow_logs_retention_days = 30

  # Enable Network ACLs
  enable_network_acls = true

  tags = {
    Environment = "development"
    Project     = "basic-example"
    ManagedBy   = "terraform"
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

output "nat_gateway_ips" {
  description = "Public IPs of NAT Gateways"
  value       = module.networking.nat_gateway_public_ips
}
