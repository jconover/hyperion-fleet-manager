# Testing Guide

This document outlines how to test the AWS Networking Terraform module.

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account with permissions to create VPC resources
- `terraform-docs` for documentation generation (optional)
- `tflint` for linting (optional)

## Local Testing

### 1. Format Check

```bash
terraform fmt -check -recursive
```

Fix formatting issues:
```bash
terraform fmt -recursive
```

### 2. Validation

```bash
cd examples/basic
terraform init
terraform validate
```

### 3. Linting (Optional)

Install tflint:
```bash
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
```

Create `.tflint.hcl`:
```hcl
plugin "aws" {
  enabled = true
  version = "0.21.1"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
```

Run linting:
```bash
tflint --init
tflint
```

### 4. Security Scanning

Using Checkov:
```bash
pip install checkov
checkov -d .
```

Using tfsec:
```bash
# Install tfsec
brew install tfsec  # macOS
# or
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Run scan
tfsec .
```

### 5. Cost Estimation

Using Infracost:
```bash
# Install Infracost
brew install infracost  # macOS

# Authenticate
infracost auth login

# Generate cost estimate
infracost breakdown --path examples/basic
infracost breakdown --path examples/cost-optimized
infracost breakdown --path examples/high-availability
```

## Integration Testing

### Test Deployment

1. **Deploy Basic Example**
```bash
cd examples/basic
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

2. **Verify Resources**
```bash
# Check VPC
aws ec2 describe-vpcs --vpc-ids $(terraform output -raw vpc_id)

# Check Subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"

# Check NAT Gateways
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$(terraform output -raw vpc_id)"

# Check Route Tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"

# Check Flow Logs
aws ec2 describe-flow-logs --filter "Name=resource-id,Values=$(terraform output -raw vpc_id)"
```

3. **Connectivity Testing**

Create a test EC2 instance in private subnet:
```hcl
resource "aws_instance" "test" {
  ami           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2
  instance_type = "t2.micro"
  subnet_id     = module.networking.private_subnet_ids[0]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    curl -I https://www.google.com
  EOF
}
```

Verify NAT Gateway connectivity:
```bash
# SSH to instance (via bastion) and test internet access
curl -I https://www.google.com
# Should succeed if NAT Gateway is working
```

4. **Clean Up**
```bash
terraform destroy -auto-approve
```

## Automated Testing

### Using Terratest (Go)

Create `test/networking_test.go`:
```go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestNetworkingModule(t *testing.T) {
    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../examples/basic",
    })

    defer terraform.Destroy(t, terraformOptions)

    terraform.InitAndApply(t, terraformOptions)

    vpcId := terraform.Output(t, terraformOptions, "vpc_id")
    assert.NotEmpty(t, vpcId)

    publicSubnetIds := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
    assert.Equal(t, 3, len(publicSubnetIds))

    privateSubnetIds := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
    assert.Equal(t, 3, len(privateSubnetIds))
}
```

Run tests:
```bash
cd test
go mod init networking-test
go mod tidy
go test -v -timeout 30m
```

### Using Kitchen-Terraform (Ruby)

Create `.kitchen.yml`:
```yaml
---
driver:
  name: terraform

provisioner:
  name: terraform

platforms:
  - name: aws

verifier:
  name: terraform
  systems:
    - name: basic
      backend: aws

suites:
  - name: basic
    driver:
      root_module_directory: examples/basic
    verifier:
      systems:
        - name: basic
          backend: aws
          controls:
            - vpc_exists
            - subnets_exist
```

## Validation Checklist

- [ ] All required variables have appropriate validation
- [ ] Outputs provide all necessary information
- [ ] Tags are applied to all resources
- [ ] NAT Gateway deployment options work (single vs multiple)
- [ ] VPC Flow Logs are created and logging
- [ ] Network ACLs are properly configured
- [ ] Route tables have correct associations
- [ ] Internet Gateway is attached
- [ ] DNS support and hostnames are enabled
- [ ] Resources are created in correct AZs
- [ ] No security vulnerabilities detected
- [ ] Cost estimates are reasonable

## Performance Testing

### Deployment Time

Measure typical deployment times:
```bash
time terraform apply -auto-approve
```

Expected times:
- Basic deployment: 3-5 minutes
- With NAT Gateways: 5-8 minutes
- Complete HA setup: 8-12 minutes

### Resource Limits

Test with maximum supported configuration:
- 6 public subnets
- 6 private subnets
- 6 NAT Gateways
- All features enabled

## Troubleshooting Tests

### Common Issues

1. **NAT Gateway timeout**
   - NAT Gateway creation can take 2-3 minutes
   - Ensure depends_on is properly set

2. **Route table association conflicts**
   - Verify subnet count matches route table count
   - Check single_nat_gateway logic

3. **Flow Logs IAM permissions**
   - IAM role must trust vpc-flow-logs.amazonaws.com
   - Policy must allow logs:* actions

4. **CIDR block overlaps**
   - Verify subnet CIDRs don't overlap
   - Ensure subnets fit within VPC CIDR

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Terraform Validation

on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Terraform Format
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init
        working-directory: examples/basic

      - name: Terraform Validate
        run: terraform validate
        working-directory: examples/basic

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.0

      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
```

## Documentation Testing

Verify documentation is up to date:
```bash
terraform-docs markdown table . > README_TEST.md
diff README.md README_TEST.md
```

## Compliance Testing

### CIS AWS Foundations Benchmark

Verify compliance with CIS benchmarks:
- VPC Flow Logs enabled (2.9)
- Network ACLs configured (5.1)
- Default security groups restricted (5.3)

### AWS Well-Architected Framework

Test against pillars:
- **Operational Excellence**: Tags, monitoring
- **Security**: Network ACLs, Flow Logs
- **Reliability**: Multi-AZ deployment
- **Performance Efficiency**: Appropriate resource sizing
- **Cost Optimization**: Single NAT Gateway option

## Test Environments

### Development
- Single NAT Gateway
- 7-day log retention
- Minimal subnets

### Staging
- Multiple NAT Gateways
- 30-day log retention
- Full subnet deployment

### Production
- Multiple NAT Gateways
- 90-day log retention
- Full features enabled
- Additional monitoring

## Reporting

Generate test report:
```bash
terraform plan -out=tfplan
terraform show -json tfplan > plan.json

# Use tools like terraform-compliance or Open Policy Agent
# to validate plan against policies
```

## Next Steps

After testing:
1. Document any issues found
2. Update test cases for new features
3. Add regression tests for bug fixes
4. Update this testing guide
5. Share results with team
