# AWS Networking Terraform Module

Production-ready Terraform module for creating a secure, highly-available AWS VPC with public and private subnets, NAT Gateways, VPC Flow Logs, and Network ACLs.

## Features

- **Multi-AZ VPC**: Subnets distributed across multiple availability zones for high availability
- **Public and Private Subnets**: Separate network tiers for internet-facing and internal resources
- **NAT Gateway**: Configurable NAT Gateway deployment (one per AZ or single for cost optimization)
- **Internet Gateway**: Public internet connectivity for public subnets
- **VPC Flow Logs**: Network traffic logging to CloudWatch for security monitoring
- **Network ACLs**: Additional network-level security layer (defense in depth)
- **Route Tables**: Properly configured routing for public and private subnets
- **Tagging**: Comprehensive resource tagging support

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                            VPC (10.0.0.0/16)                     │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  us-east-1a  │  │  us-east-1b  │  │  us-east-1c  │         │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤         │
│  │   Public     │  │   Public     │  │   Public     │         │
│  │ 10.0.1.0/24  │  │ 10.0.2.0/24  │  │ 10.0.3.0/24  │         │
│  │              │  │              │  │              │         │
│  │  NAT Gateway │  │  NAT Gateway │  │  NAT Gateway │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                 │                 │                  │
│         └─────────────────┴─────────────────┘                  │
│                           │                                     │
│                    Internet Gateway                             │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Private    │  │   Private    │  │   Private    │         │
│  │ 10.0.11.0/24 │  │ 10.0.12.0/24 │  │ 10.0.13.0/24 │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "networking" {
  source = "./modules/networking"

  name_prefix = "my-app"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### High Availability Example (Multiple NAT Gateways)

```hcl
module "networking" {
  source = "./modules/networking"

  name_prefix = "prod-app"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

  enable_nat_gateway = true
  single_nat_gateway = false  # One NAT Gateway per AZ for HA

  enable_flow_logs           = true
  flow_logs_retention_days   = 30
  flow_logs_traffic_type     = "ALL"

  enable_network_acls = true

  tags = {
    Environment = "production"
    Project     = "app-platform"
    ManagedBy   = "terraform"
  }
}
```

### Cost-Optimized Example (Single NAT Gateway)

```hcl
module "networking" {
  source = "./modules/networking"

  name_prefix = "dev-app"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b"]

  enable_nat_gateway = true
  single_nat_gateway = true  # Single NAT Gateway for cost savings

  enable_flow_logs        = true
  flow_logs_retention_days = 7  # Shorter retention for dev

  tags = {
    Environment = "development"
    ManagedBy   = "terraform"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0 |

## Resources

| Name | Type |
|------|------|
| aws_vpc.main | resource |
| aws_internet_gateway.main | resource |
| aws_subnet.public | resource |
| aws_subnet.private | resource |
| aws_eip.nat | resource |
| aws_nat_gateway.main | resource |
| aws_route_table.public | resource |
| aws_route_table.private | resource |
| aws_route.public_internet_gateway | resource |
| aws_route.private_nat_gateway | resource |
| aws_route_table_association.public | resource |
| aws_route_table_association.private | resource |
| aws_flow_log.main | resource |
| aws_cloudwatch_log_group.flow_logs | resource |
| aws_iam_role.flow_logs | resource |
| aws_iam_role_policy.flow_logs | resource |
| aws_network_acl.public | resource |
| aws_network_acl.private | resource |
| aws_network_acl_rule.* | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name_prefix | Prefix to be used for resource names | `string` | n/a | yes |
| vpc_cidr | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |
| public_subnet_cidrs | List of CIDR blocks for public subnets | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]` | no |
| private_subnet_cidrs | List of CIDR blocks for private subnets | `list(string)` | `["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]` | no |
| availability_zones | List of availability zones for subnet distribution | `list(string)` | `["us-east-1a", "us-east-1b", "us-east-1c"]` | no |
| enable_dns_hostnames | Enable DNS hostnames in the VPC | `bool` | `true` | no |
| enable_dns_support | Enable DNS support in the VPC | `bool` | `true` | no |
| enable_nat_gateway | Enable NAT Gateway for private subnets | `bool` | `true` | no |
| single_nat_gateway | Use a single NAT Gateway for all private subnets | `bool` | `false` | no |
| map_public_ip_on_launch | Auto-assign public IPs to instances in public subnets | `bool` | `true` | no |
| enable_flow_logs | Enable VPC Flow Logs to CloudWatch | `bool` | `true` | no |
| flow_logs_traffic_type | Type of traffic to log (ACCEPT, REJECT, or ALL) | `string` | `"ALL"` | no |
| flow_logs_retention_days | Number of days to retain VPC Flow Logs | `number` | `30` | no |
| enable_network_acls | Enable custom Network ACLs for defense in depth | `bool` | `true` | no |
| tags | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| vpc_cidr | The CIDR block of the VPC |
| vpc_arn | The ARN of the VPC |
| internet_gateway_id | The ID of the Internet Gateway |
| public_subnet_ids | List of IDs of public subnets |
| public_subnet_cidrs | List of CIDR blocks of public subnets |
| public_subnet_arns | List of ARNs of public subnets |
| public_subnet_availability_zones | List of availability zones of public subnets |
| private_subnet_ids | List of IDs of private subnets |
| private_subnet_cidrs | List of CIDR blocks of private subnets |
| private_subnet_arns | List of ARNs of private subnets |
| private_subnet_availability_zones | List of availability zones of private subnets |
| nat_gateway_ids | List of NAT Gateway IDs |
| nat_gateway_public_ips | List of public Elastic IPs created for NAT Gateways |
| public_route_table_id | ID of the public route table |
| private_route_table_ids | List of IDs of private route tables |
| flow_log_id | The ID of the VPC Flow Log |
| flow_log_cloudwatch_log_group_name | The name of the CloudWatch Log Group for VPC Flow Logs |
| flow_log_cloudwatch_log_group_arn | The ARN of the CloudWatch Log Group for VPC Flow Logs |
| public_network_acl_id | ID of the public network ACL |
| private_network_acl_id | ID of the private network ACL |
| availability_zones | List of availability zones used |
| nat_gateway_count | Number of NAT Gateways created |

## Security Considerations

### VPC Flow Logs
- Enabled by default to capture network traffic metadata
- Logs stored in CloudWatch with configurable retention
- Monitor for security analysis and troubleshooting

### Network ACLs
- Stateless firewall layer for defense in depth
- Public subnets: Allow HTTP/HTTPS/SSH inbound, ephemeral ports for return traffic
- Private subnets: Allow VPC traffic inbound, all outbound
- Additional security layer beyond security groups

### NAT Gateway Security
- Private subnets route outbound traffic through NAT Gateway
- No inbound connections from internet to private subnets
- NAT Gateway automatically scales and is highly available within an AZ

### Best Practices Implemented
- DNS hostname and support enabled for service discovery
- Multi-AZ deployment for high availability
- Separate public and private subnet tiers
- Comprehensive tagging for resource management
- Input validation for all variables

## Cost Optimization

### NAT Gateway Costs
NAT Gateways are one of the more expensive AWS networking components:

- **Multiple NAT Gateways** (default: `single_nat_gateway = false`)
  - Provides high availability across AZs
  - Higher cost: ~$0.045/hour per NAT Gateway + data processing
  - Best for: Production environments requiring HA

- **Single NAT Gateway** (`single_nat_gateway = true`)
  - Lower cost: One NAT Gateway for all private subnets
  - Single point of failure if NAT Gateway or AZ fails
  - Best for: Development/staging environments

### VPC Flow Logs Costs
- CloudWatch Logs storage and ingestion charges apply
- Adjust `flow_logs_retention_days` based on requirements
- Consider S3 destination for long-term log archival (manual implementation)

## Migration Guide

### From Existing VPC
If migrating an existing VPC to this module:

1. Import existing resources:
```bash
terraform import module.networking.aws_vpc.main vpc-xxxxx
terraform import module.networking.aws_subnet.public[0] subnet-xxxxx
# ... continue for all resources
```

2. Use `terraform plan` to verify no unexpected changes
3. Apply incrementally with targeted applies if needed

## Troubleshooting

### NAT Gateway Issues
- Verify EIP allocation and attachment
- Check route table associations for private subnets
- Ensure security groups allow outbound traffic

### VPC Flow Logs Not Appearing
- Verify IAM role permissions
- Check CloudWatch Log Group exists
- Allow 10-15 minutes for initial logs to appear

### Subnet CIDR Conflicts
- Ensure subnet CIDRs don't overlap
- Verify subnets fit within VPC CIDR block
- Use CIDR calculator for planning

## Examples

See the `examples/` directory for complete working examples:
- Basic VPC setup
- High availability configuration
- Cost-optimized deployment
- Custom CIDR ranges
- Integration with other modules

## Module Dependencies

This module can be used with:
- **ECS/EKS modules**: Deploy container workloads in private subnets
- **RDS modules**: Database instances in private subnets
- **Application Load Balancer**: ALB in public subnets
- **EC2 instances**: Bastion hosts in public, apps in private
- **Lambda functions**: VPC-attached functions in private subnets

## Testing

Recommended testing approach:
1. `terraform fmt -check` - Verify formatting
2. `terraform validate` - Validate configuration
3. `tflint` - Lint Terraform code
4. `terraform plan` - Review planned changes
5. `terraform apply` - Deploy to test environment
6. Verify connectivity and security rules
7. Review VPC Flow Logs for traffic patterns

## License

This module is provided as-is for infrastructure provisioning.

## Authors

Terraform module created for production AWS networking infrastructure.

## Changelog

### Version 1.0.0
- Initial release
- Multi-AZ VPC with public and private subnets
- NAT Gateway with HA and cost-optimization options
- VPC Flow Logs to CloudWatch
- Network ACLs for defense in depth
- Comprehensive input validation
- Full output exposure for downstream modules
