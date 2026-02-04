# Quick Start Guide

Get up and running with the AWS Networking module in 5 minutes.

## Step 1: Review Requirements

Ensure you have:
- Terraform >= 1.0 installed
- AWS credentials configured (`aws configure`)
- AWS account with VPC creation permissions

## Step 2: Create Your Configuration

Create a new directory and `main.tf`:

```bash
mkdir my-vpc-deployment
cd my-vpc-deployment
```

Create `main.tf`:

```hcl
provider "aws" {
  region = "us-east-1"
}

module "networking" {
  source = "../modules/networking"

  name_prefix = "my-app"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

  tags = {
    Environment = "development"
    ManagedBy   = "terraform"
  }
}

output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnets" {
  value = module.networking.public_subnet_ids
}

output "private_subnets" {
  value = module.networking.private_subnet_ids
}
```

## Step 3: Initialize Terraform

```bash
terraform init
```

This will download the AWS provider and initialize the module.

## Step 4: Plan Your Infrastructure

```bash
terraform plan
```

Review the planned changes. You should see approximately 30+ resources to be created:
- 1 VPC
- 1 Internet Gateway
- 6 Subnets (3 public, 3 private)
- 3 NAT Gateways (or 1 if using single_nat_gateway)
- 3 Elastic IPs
- Route tables and associations
- VPC Flow Logs resources
- Network ACLs

## Step 5: Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted. The deployment takes approximately 5-8 minutes.

## Step 6: Verify Deployment

Check the outputs:
```bash
terraform output
```

Verify in AWS Console:
```bash
# Get VPC ID
VPC_ID=$(terraform output -raw vpc_id)

# View VPC details
aws ec2 describe-vpcs --vpc-ids $VPC_ID

# View subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID"

# View NAT Gateways
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID"
```

## Common Customizations

### Cost Optimization (Single NAT Gateway)

Add to your module configuration:
```hcl
module "networking" {
  # ... other configuration ...

  single_nat_gateway = true  # Use only 1 NAT Gateway
}
```

**Savings**: ~$65/month (reduces from 3 to 1 NAT Gateway)

### Disable NAT Gateway (Public-Only VPC)

For completely public workloads:
```hcl
module "networking" {
  # ... other configuration ...

  enable_nat_gateway = false  # No NAT Gateways
}
```

**Savings**: ~$97/month (no NAT Gateway costs)

### Reduce Flow Logs Retention

```hcl
module "networking" {
  # ... other configuration ...

  flow_logs_retention_days = 7  # Keep logs for 7 days instead of 30
}
```

### Disable Network ACLs

If using only security groups:
```hcl
module "networking" {
  # ... other configuration ...

  enable_network_acls = false  # Use default NACLs
}
```

## Using the VPC with Other Resources

### Launch EC2 Instance in Private Subnet

```hcl
resource "aws_instance" "app_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  subnet_id     = module.networking.private_subnet_ids[0]

  tags = {
    Name = "app-server"
  }
}
```

### Create Application Load Balancer

```hcl
resource "aws_lb" "app" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = module.networking.public_subnet_ids

  tags = {
    Name = "app-lb"
  }
}
```

### RDS Database in Private Subnet

```hcl
resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = module.networking.private_subnet_ids

  tags = {
    Name = "main-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  allocated_storage    = 20
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  db_subnet_group_name = aws_db_subnet_group.main.name
  # ... other configuration ...
}
```

## Cleanup

When you're done:

```bash
terraform destroy
```

Type `yes` to confirm. This will delete all created resources.

**Warning**: This is irreversible. Ensure you've backed up any data.

## Next Steps

1. **Review the full README**: `/home/justin/Projects/hyperion-fleet-manager/infrastructure/modules/networking/README.md`
2. **Check examples**: See `examples/` directory for more configurations
3. **Add security groups**: Create security groups for your applications
4. **Set up monitoring**: Configure CloudWatch alarms for network metrics
5. **Review costs**: Use AWS Cost Explorer to monitor spending

## Troubleshooting

### "Insufficient IAM permissions"

Ensure your AWS credentials have these permissions:
- ec2:CreateVpc
- ec2:CreateSubnet
- ec2:CreateInternetGateway
- ec2:CreateNatGateway
- ec2:AllocateAddress
- logs:CreateLogGroup
- iam:CreateRole

### "NAT Gateway creation timeout"

NAT Gateways can take 2-3 minutes to create. This is normal. If it fails:
1. Check EIP quota (default: 5 per region)
2. Verify Internet Gateway is attached
3. Ensure subnet is in available state

### "CIDR block overlap"

Verify your subnet CIDRs:
- Don't overlap with each other
- Fit within the VPC CIDR block
- Use a CIDR calculator if needed

### "Flow Logs not appearing"

Wait 10-15 minutes after creation for logs to appear in CloudWatch. Flow logs have a natural delay.

## Support

For issues or questions:
1. Check the TESTING.md guide
2. Review example configurations
3. Verify AWS service quotas
4. Check Terraform and AWS provider versions

## Estimated Costs

**Base configuration** (3 NAT Gateways):
- NAT Gateway hours: ~$97/month (3 × $0.045/hour)
- NAT Gateway data: ~$0.045/GB processed
- Flow Logs: Variable, typically $5-20/month
- **Total**: ~$100-120/month

**Cost-optimized** (1 NAT Gateway):
- NAT Gateway hours: ~$32/month
- NAT Gateway data: ~$0.045/GB processed
- Flow Logs: $5-20/month
- **Total**: ~$35-55/month

VPC, subnets, route tables, and Internet Gateway are free.
