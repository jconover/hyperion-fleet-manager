# Terraform Multi-Environment Workflow

## Overview

This document describes the workflow for managing infrastructure across multiple environments using Terraform with S3 backend and state locking.

## Architecture

### Backend Infrastructure

```
┌─────────────────────────────────────────────────────────┐
│                    Global Resources                      │
│                                                          │
│  ┌──────────────────┐      ┌──────────────────┐        │
│  │   S3 Bucket      │      │  DynamoDB Table  │        │
│  │  (State Store)   │      │  (State Lock)    │        │
│  │                  │      │                  │        │
│  │  - Versioning    │      │  - PAY_PER_REQ   │        │
│  │  - Encryption    │      │  - Encryption    │        │
│  │  - Lifecycle     │      │  - PITR          │        │
│  └──────────────────┘      └──────────────────┘        │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Environment Isolation

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│     Dev      │    │   Staging    │    │     Prod     │
│              │    │              │    │              │
│ VPC:         │    │ VPC:         │    │ VPC:         │
│ 10.0.0.0/16  │    │ 10.10.0.0/16 │    │ 10.20.0.0/16 │
│              │    │              │    │              │
│ State:       │    │ State:       │    │ State:       │
│ env/dev/     │    │ env/staging/ │    │ env/prod/    │
│ tfstate      │    │ tfstate      │    │ tfstate      │
└──────────────┘    └──────────────┘    └──────────────┘
```

## Workflows

### 1. Initial Setup (One-Time)

```
┌─────────────────────────────────────────────────────────┐
│  Step 1: Bootstrap Backend                              │
│  $ ./scripts/init-backend.sh                            │
│                                                          │
│  Creates:                                               │
│  ✓ S3 bucket with versioning                           │
│  ✓ DynamoDB table for locking                          │
│  ✓ KMS key for encryption                              │
│  ✓ IAM policy for access                               │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Step 2: Initialize Environment Backends                │
│  $ cd environments/dev && terraform init                │
│  $ cd environments/staging && terraform init            │
│  $ cd environments/prod && terraform init               │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Step 3: Verify Setup                                   │
│  $ ./scripts/validate-all.sh                            │
└─────────────────────────────────────────────────────────┘
```

### 2. Development Workflow

```
┌─────────────────────────────────────────────────────────┐
│  1. Make Changes to Code                                │
│     - Update module code                                │
│     - Modify environment configs                        │
│     - Update tfvars as needed                          │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  2. Format and Validate                                 │
│  $ terraform fmt -recursive                             │
│  $ terraform validate                                   │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  3. Plan Changes in Dev                                 │
│  $ cd environments/dev                                  │
│  $ terraform plan -out=tfplan                           │
│                                                          │
│  Review:                                                │
│  - Resources to be added                               │
│  - Resources to be changed                             │
│  - Resources to be destroyed                           │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  4. Apply to Dev                                        │
│  $ terraform apply tfplan                               │
│                                                          │
│  State Management:                                      │
│  ┌──────────────┐                                      │
│  │ Acquire Lock │  → Apply Changes → Release Lock      │
│  │  (DynamoDB)  │                                      │
│  └──────────────┘                                      │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  5. Test and Verify                                     │
│  - Functional testing                                   │
│  - Integration testing                                  │
│  - Performance testing                                  │
└─────────────────────────────────────────────────────────┘
```

### 3. Promotion Workflow (Dev → Staging → Prod)

```
┌─────────────────────────────────────────────────────────┐
│  Dev Environment                                        │
│  ✓ Changes tested and verified                         │
│  ✓ All tests passing                                    │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Apply to Staging                                       │
│  $ cd environments/staging                              │
│  $ terraform plan                                       │
│  $ terraform apply                                      │
│                                                          │
│  Testing:                                               │
│  - Integration tests                                    │
│  - Load tests                                          │
│  - Security scans                                      │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Production Approval                                    │
│  - Team review                                         │
│  - Change management approval                          │
│  - Maintenance window scheduled                        │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Apply to Production                                    │
│  $ cd environments/prod                                 │
│  $ terraform plan                                       │
│  $ # Carefully review the plan                         │
│  $ terraform apply                                      │
│                                                          │
│  Monitoring:                                            │
│  - Watch CloudWatch metrics                            │
│  - Monitor alarms                                      │
│  - Check application health                            │
└─────────────────────────────────────────────────────────┘
```

### 4. State Management Workflow

```
┌─────────────────────────────────────────────────────────┐
│  Terraform Operation Starts                             │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  1. Acquire State Lock                                  │
│     - Write lock to DynamoDB                           │
│     - Lock contains: ID, Operation, Who, When          │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  2. Download State from S3                              │
│     - Fetch current state file                         │
│     - Decrypt using KMS                                │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  3. Execute Terraform Operation                         │
│     - Plan: Compare state to desired                   │
│     - Apply: Make changes to infrastructure            │
│     - Destroy: Remove resources                        │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  4. Upload Updated State to S3                          │
│     - Encrypt using KMS                                │
│     - Create new version in S3                         │
│     - Old versions retained per lifecycle policy       │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  5. Release State Lock                                  │
│     - Remove lock from DynamoDB                        │
└─────────────────────────────────────────────────────────┘
```

### 5. Disaster Recovery Workflow

```
┌─────────────────────────────────────────────────────────┐
│  Scenario: State File Corrupted or Lost                │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  1. List Available State Versions                       │
│  $ aws s3api list-object-versions \                     │
│      --bucket hyperion-fleet-terraform-state \          │
│      --prefix environments/prod/terraform.tfstate       │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  2. Identify Last Good Version                          │
│     - Check version timestamps                         │
│     - Review change history                            │
│     - Consult with team                                │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  3. Restore State File                                  │
│  $ aws s3api get-object \                               │
│      --bucket hyperion-fleet-terraform-state \          │
│      --key environments/prod/terraform.tfstate \        │
│      --version-id <VERSION_ID> \                        │
│      terraform.tfstate.restored                         │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  4. Verify and Test                                     │
│  $ terraform plan -refresh-only                         │
│  $ # Check for drift                                    │
└─────────────────────────────────────────────────────────┘
```

### 6. Module Development Workflow

```
┌─────────────────────────────────────────────────────────┐
│  1. Create/Update Module                                │
│  $ cd modules/new-module                                │
│  $ # Edit main.tf, variables.tf, outputs.tf            │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  2. Validate Module                                     │
│  $ terraform init -backend=false                        │
│  $ terraform validate                                   │
│  $ terraform fmt                                        │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  3. Test Module in Dev                                  │
│  $ cd ../../environments/dev                            │
│  $ # Update main.tf to use new module                  │
│  $ terraform init -upgrade                              │
│  $ terraform plan                                       │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  4. Document Module                                     │
│  $ # Update README.md                                   │
│  $ # Add examples                                       │
│  $ # Document variables and outputs                    │
└─────────────────────────────────────────────────────────┘
```

## State Locking Details

### Lock Acquisition Flow

```
Terraform Apply
      ↓
Check DynamoDB for existing lock
      ↓
Lock exists? ─→ Yes ─→ Wait/Fail
      ↓
     No
      ↓
Create lock record in DynamoDB
      ↓
Lock Record:
  - LockID: {bucket}/{key}
  - Info: Operation details
  - Who: User/Role
  - Version: State version
  - Created: Timestamp
      ↓
Proceed with operation
      ↓
Delete lock record
```

### Handling Lock Conflicts

```
┌─────────────────────────────────────────────────────────┐
│  Lock Already Exists                                    │
│  Error: Error locking state: ConditionalCheckFailed    │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  1. Check Lock Status                                   │
│  $ aws dynamodb scan \                                  │
│      --table-name hyperion-fleet-terraform-lock         │
│                                                          │
│  Information shown:                                     │
│  - Who has the lock                                    │
│  - When was it acquired                                │
│  - What operation                                      │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  2. Verify if Still Active                              │
│  - Contact the person with lock                        │
│  - Check if process is still running                   │
│  - Determine if stale lock                             │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  3a. Wait (if active)                                   │
│      Let other operation complete                       │
│                                                          │
│  3b. Force Unlock (if stale)                           │
│  $ terraform force-unlock <LOCK_ID>                     │
│                                                          │
│  ⚠️  Only do this if certain lock is stale!            │
└─────────────────────────────────────────────────────────┘
```

## Best Practices

### 1. Change Management Process

```
┌──────────────┐
│ Make Changes │
└──────────────┘
      ↓
┌──────────────┐
│ Code Review  │
└──────────────┘
      ↓
┌──────────────┐
│ Test in Dev  │
└──────────────┘
      ↓
┌──────────────┐
│ Staging Test │
└──────────────┘
      ↓
┌──────────────┐
│ Team Review  │
└──────────────┘
      ↓
┌──────────────┐
│ Prod Deploy  │
└──────────────┘
      ↓
┌──────────────┐
│ Monitor      │
└──────────────┘
```

### 2. Safety Checklist

Before applying to production:

- [ ] Changes tested in dev
- [ ] Changes tested in staging
- [ ] Terraform plan reviewed
- [ ] Team approval obtained
- [ ] Backup verified
- [ ] Rollback plan documented
- [ ] Monitoring in place
- [ ] On-call engineer available

### 3. State File Hygiene

```
Daily:
  ✓ Verify state lock is released
  ✓ Check for state drift (plan -refresh-only)

Weekly:
  ✓ Review state file versions in S3
  ✓ Verify backups are accessible
  ✓ Check DynamoDB table health

Monthly:
  ✓ Review lifecycle policy effectiveness
  ✓ Test state recovery procedure
  ✓ Audit access to state bucket
```

## Troubleshooting Guide

### Problem: State Lock Stuck

**Symptoms**: Cannot acquire lock, error message about existing lock

**Solution**:
```bash
# 1. Check who has the lock
aws dynamodb scan --table-name hyperion-fleet-terraform-lock

# 2. Verify if process is still running
# 3. If stale, force unlock
terraform force-unlock <LOCK_ID>
```

### Problem: State Drift Detected

**Symptoms**: Plan shows unexpected changes

**Solution**:
```bash
# 1. Refresh and check drift
terraform plan -refresh-only

# 2. Review what changed outside Terraform
# 3. Import resources if needed
terraform import <resource> <id>

# 4. Update code to match actual state
```

### Problem: Module Not Found

**Symptoms**: Module source not found error

**Solution**:
```bash
# 1. Reinitialize with upgrade
terraform init -upgrade

# 2. Get latest modules
terraform get -update

# 3. Clear cache if needed
rm -rf .terraform
terraform init
```

## Security Considerations

### Access Control

```
┌─────────────────────────────────────────────────────────┐
│  IAM Permissions Required                               │
│                                                          │
│  State Bucket (S3):                                     │
│    - s3:GetObject                                       │
│    - s3:PutObject                                       │
│    - s3:DeleteObject                                    │
│    - s3:ListBucket                                      │
│                                                          │
│  Lock Table (DynamoDB):                                 │
│    - dynamodb:GetItem                                   │
│    - dynamodb:PutItem                                   │
│    - dynamodb:DeleteItem                                │
│                                                          │
│  Encryption (KMS):                                      │
│    - kms:Decrypt                                        │
│    - kms:Encrypt                                        │
│    - kms:DescribeKey                                    │
│    - kms:GenerateDataKey                                │
└─────────────────────────────────────────────────────────┘
```

### Audit Trail

```
All operations are logged:
  ├── CloudTrail (API calls)
  ├── S3 Access Logs (state file access)
  ├── DynamoDB Streams (lock operations)
  └── Terraform logs (operation details)
```

## Performance Optimization

### State File Size Management

```
Keep state files small:
  ✓ Use separate states per environment
  ✓ Split large deployments into modules
  ✓ Avoid storing large data in state
  ✓ Use data sources instead of resources where possible
```

### Lock Contention

```
Reduce lock contention:
  ✓ Keep operations short
  ✓ Use separate states for independent resources
  ✓ Coordinate team deployments
  ✓ Use resource targeting when possible
```

## Monitoring and Alerting

### Key Metrics to Monitor

```
S3 State Bucket:
  - Access patterns
  - Version count growth
  - Storage usage

DynamoDB Lock Table:
  - Lock duration
  - Failed lock attempts
  - Table capacity usage

Terraform Operations:
  - Plan/Apply duration
  - Resource changes
  - Error rates
```

## Additional Resources

- [Main README](README.md)
- [Quick Reference](QUICK_REFERENCE.md)
- [Terraform Documentation](https://www.terraform.io/docs)
