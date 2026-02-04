# Cost-Optimized VPC Example
# Uses single NAT Gateway and minimal subnets for cost savings

provider "aws" {
  region = "us-east-1"
}

module "networking" {
  source = "../../"

  name_prefix = "cost-optimized-vpc"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b"]

  # Single NAT Gateway for cost optimization
  enable_nat_gateway = true
  single_nat_gateway = true

  # Reduced Flow Logs retention
  enable_flow_logs         = true
  flow_logs_retention_days = 7
  flow_logs_traffic_type   = "REJECT" # Only log rejected traffic

  # Enable Network ACLs
  enable_network_acls = true

  tags = {
    Environment = "development"
    Project     = "cost-optimized-example"
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
  }
}

# Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.networking.vpc_id
}

output "nat_gateway_count" {
  description = "Number of NAT Gateways (should be 1)"
  value       = module.networking.nat_gateway_count
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    nat_gateway_hours = "~$32.40 (1 NAT Gateway @ $0.045/hour)"
    nat_gateway_data  = "Variable based on data processed (~$0.045/GB)"
    flow_logs         = "Variable based on log volume"
    total_fixed       = "~$32.40/month + variable costs"
  }
}
