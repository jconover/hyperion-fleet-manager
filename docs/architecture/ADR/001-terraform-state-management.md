# ADR 001: Terraform State Management Strategy

## Status

**Accepted** - 2024-11-15

## Context

Hyperion Fleet Manager uses Terraform to manage AWS infrastructure. Terraform requires persistent state storage to track resource mappings and metadata. The state file contains sensitive information and must be protected, shared among team members, and support concurrent operations safely.

### Decision Factors

1. **Team Collaboration**: Multiple engineers need to run Terraform operations
2. **State Security**: State contains sensitive data (resource IDs, configuration)
3. **Concurrency**: Prevent simultaneous modifications that could corrupt state
4. **Versioning**: Ability to recover from state corruption or mistakes
5. **Availability**: State must be highly available for CI/CD pipelines
6. **Cost**: Solution should be cost-effective
7. **Compliance**: Meet security and audit requirements

### Options Considered

#### Option 1: Local State Storage

**Pros:**
- Simple to implement
- No additional AWS costs
- Fast access

**Cons:**
- Cannot share state across team
- No built-in locking (corruption risk)
- No versioning or backup
- State stored with code (security risk)
- Does not support CI/CD

**Verdict:** Rejected - Not suitable for team collaboration

#### Option 2: Terraform Cloud

**Pros:**
- Managed service with built-in locking
- Version control and state history
- Role-based access control
- Integrated with VCS workflows
- No infrastructure to manage

**Cons:**
- Monthly cost per user ($20+/user for team plan)
- External dependency on third-party service
- Data stored outside AWS environment
- Limited customization

**Verdict:** Rejected - Unnecessary cost for self-managed AWS infrastructure

#### Option 3: S3 Backend with DynamoDB Locking

**Pros:**
- Native AWS service integration
- S3 versioning provides state history
- DynamoDB provides state locking
- Highly available (99.99% SLA)
- Cost-effective (~$1-5/month)
- Encryption at rest and in transit
- IAM-based access control
- Supports audit logging via CloudTrail

**Cons:**
- Requires manual setup of S3 bucket and DynamoDB table
- Team responsible for managing backend infrastructure
- Requires careful IAM permission management

**Verdict:** Selected - Best balance of features, cost, and AWS-native integration

## Decision

**We will use S3 backend with DynamoDB state locking for Terraform state management.**

### Implementation Details

#### S3 Bucket Configuration

```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "hyperion-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Terraform State Storage"
    Environment = "shared"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.terraform_state_logs.id
  target_prefix = "log/"
}
```

#### DynamoDB Table Configuration

```hcl
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "hyperion-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "shared"
    ManagedBy   = "terraform"
  }
}
```

#### Backend Configuration

```hcl
terraform {
  backend "s3" {
    bucket         = "hyperion-terraform-state-123456789012"
    key            = "environments/production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "hyperion-terraform-locks"

    # Optional: Use with assume role for cross-account access
    # role_arn = "arn:aws:iam::123456789012:role/TerraformStateRole"
  }
}
```

#### IAM Policy for Terraform Users

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateS3Access",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::hyperion-terraform-state-*",
        "arn:aws:s3:::hyperion-terraform-state-*/*"
      ]
    },
    {
      "Sid": "TerraformStateLockAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:*:table/hyperion-terraform-locks"
    }
  ]
}
```

### State Organization Strategy

State files are organized by environment and component:

```
s3://hyperion-terraform-state-123456789012/
├── environments/
│   ├── dev/
│   │   └── terraform.tfstate
│   ├── staging/
│   │   └── terraform.tfstate
│   └── prod/
│       └── terraform.tfstate
├── modules/
│   ├── networking/
│   │   └── terraform.tfstate
│   └── shared-services/
│       └── terraform.tfstate
└── global/
    └── terraform.tfstate
```

### State Locking Mechanism

DynamoDB provides distributed locking:

1. **Lock Acquisition**: Before state modification, Terraform writes a lock entry to DynamoDB
2. **Lock Information**: Contains operator ID, timestamp, operation type
3. **Lock Release**: Automatically released after operation completes
4. **Lock Timeout**: Configurable timeout prevents stuck locks
5. **Force Unlock**: Manual override available for emergency situations

**Lock Entry Example:**
```json
{
  "LockID": "hyperion-terraform-state-123456789012/environments/prod/terraform.tfstate-md5",
  "Info": {
    "ID": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "Operation": "OperationTypeApply",
    "Who": "john.doe@example.com",
    "Created": "2024-11-15T10:30:00Z",
    "Path": "environments/prod/terraform.tfstate"
  }
}
```

### State Version Management

S3 versioning provides state recovery:

```bash
# List state versions
aws s3api list-object-versions \
  --bucket hyperion-terraform-state-123456789012 \
  --prefix environments/prod/terraform.tfstate

# Restore previous version
aws s3api copy-object \
  --bucket hyperion-terraform-state-123456789012 \
  --copy-source hyperion-terraform-state-123456789012/environments/prod/terraform.tfstate?versionId=VERSION_ID \
  --key environments/prod/terraform.tfstate
```

### Backup and Recovery

**Automated Backup Strategy:**
1. S3 versioning maintains all state history
2. S3 lifecycle policy archives old versions to Glacier after 90 days
3. Cross-region replication to disaster recovery region
4. CloudTrail logs all state file access

**Recovery Procedure:**

```bash
# 1. Identify corrupted state version
terraform state list

# 2. List available versions
aws s3api list-object-versions \
  --bucket hyperion-terraform-state-123456789012 \
  --prefix environments/prod/terraform.tfstate

# 3. Restore known-good version
aws s3api get-object \
  --bucket hyperion-terraform-state-123456789012 \
  --key environments/prod/terraform.tfstate \
  --version-id PREVIOUS_VERSION_ID \
  terraform.tfstate.backup

# 4. Validate restored state
terraform plan

# 5. If valid, copy back to S3
aws s3 cp terraform.tfstate.backup \
  s3://hyperion-terraform-state-123456789012/environments/prod/terraform.tfstate
```

## Consequences

### Positive

1. **Team Collaboration**: All team members can access shared state
2. **State Protection**: Locking prevents concurrent modifications
3. **Version History**: S3 versioning enables state recovery
4. **Security**: Encryption at rest and in transit, IAM access control
5. **Cost Effective**: ~$1-5/month for typical usage
6. **High Availability**: 99.99% availability SLA from S3
7. **Audit Trail**: CloudTrail logs all state access
8. **AWS Native**: No external dependencies

### Negative

1. **Initial Setup**: Requires bootstrapping S3 and DynamoDB
2. **Chicken and Egg**: Backend resources must exist before Terraform can use them
3. **Management Overhead**: Team responsible for backend infrastructure
4. **Network Dependency**: Requires internet/AWS connectivity for state operations
5. **IAM Complexity**: Must manage permissions carefully

### Mitigation Strategies

**Bootstrap Problem:**
- Create backend resources using AWS CLI or Console initially
- Document bootstrap process in repository
- Provide automation script for setup

**Network Dependency:**
- Cache state locally when working offline (read-only mode)
- Document offline workflow procedures

**IAM Management:**
- Use least-privilege IAM policies
- Document required permissions
- Use IAM roles instead of user credentials where possible

## References

- [Terraform S3 Backend Documentation](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [DynamoDB State Locking](https://www.terraform.io/docs/language/settings/backends/s3.html#dynamodb-state-locking)
- [Terraform State Management Best Practices](https://www.terraform.io/docs/language/state/index.html)

## Revision History

| Version | Date       | Author      | Description           |
|---------|------------|-------------|-----------------------|
| 1.0     | 2024-11-15 | DevOps Team | Initial decision      |

## Review Schedule

This ADR should be reviewed annually or when:
- Terraform introduces significant backend changes
- Team size significantly increases (>20 engineers)
- Security or compliance requirements change
- Cost becomes a significant concern
- Multi-region requirements emerge
