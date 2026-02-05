# Security Module Architecture

This document describes the architecture and design decisions of the Security Module.

## Overview

The Security Module provides comprehensive security resources for the Hyperion Fleet Manager infrastructure, implementing defense-in-depth principles across IAM, network, encryption, and monitoring layers.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Internet / Users                                │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │ HTTPS (443)
                                 │
                    ┌────────────▼────────────┐
                    │  Application Load       │
                    │  Balancer               │
                    │  Security Group         │
                    │  - Ingress: 443         │
                    │  - Egress: 8080         │
                    └────────────┬────────────┘
                                 │ App Port
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        │  ┌─────────────────────▼─────────────────────┐ │
        │  │    Windows Fleet Instances                │ │
        │  │    Security Group                         │ │
        │  │    - Ingress: 3389 (from bastion)        │ │
        │  │    - Ingress: 8080 (from ALB)            │ │
        │  │    - Egress: 443 (to AWS services)       │ │
        │  │    - Egress: 5432 (to database)          │ │
        │  │                                           │ │
        │  │    IAM Instance Profile                  │ │
        │  │    - SSM Managed Instance Core           │ │
        │  │    - CloudWatch Agent                    │ │
        │  │    - S3 Access (with KMS)                │ │
        │  │    - Secrets Manager Access (with KMS)   │ │
        │  └───────────────────┬───────────────────────┘ │
        │                      │                          │
        │                      │ PostgreSQL (5432)        │
        │                      │                          │
        │  ┌───────────────────▼───────────────────────┐ │
        │  │    PostgreSQL RDS                         │ │
        │  │    Security Group                         │ │
        │  │    - Ingress: 5432 (from fleet only)     │ │
        │  │                                           │ │
        │  │    Encryption: RDS KMS Key               │ │
        │  └───────────────────────────────────────────┘ │
        │                                                 │
        │                 VPC Boundary                    │
        └─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                      AWS Security Services                               │
│                                                                          │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │  Security   │  │  GuardDuty   │  │  CloudWatch  │  │  CloudTrail │ │
│  │    Hub      │  │              │  │    Logs      │  │             │ │
│  └─────────────┘  └──────────────┘  └──────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                       KMS Keys (All with Rotation)                       │
│                                                                          │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │  EBS Key    │  │   RDS Key    │  │   S3 Key     │  │  Secrets    │ │
│  │  (EC2)      │  │  (Database)  │  │  (Buckets)   │  │  Manager    │ │
│  └─────────────┘  └──────────────┘  └──────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                        Secrets Manager                                   │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Database Credentials                                             │  │
│  │  - Username: dbadmin                                             │  │
│  │  - Password: auto-generated (32 chars)                           │  │
│  │  - Encryption: Secrets Manager KMS Key                           │  │
│  │  - Recovery Window: 7 days                                       │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Component Architecture

### 1. IAM Layer

```
┌──────────────────────────────────────────────────────────────┐
│                  IAM Role: Windows Fleet                      │
├──────────────────────────────────────────────────────────────┤
│  Trust Policy:                                                │
│  - Service: ec2.amazonaws.com                                │
│  - Condition: SourceAccount = current account                │
│  - Condition: SourceArn = ec2 instance ARN pattern           │
├──────────────────────────────────────────────────────────────┤
│  Managed Policies:                                            │
│  ✓ AmazonSSMManagedInstanceCore                              │
│  ✓ CloudWatchAgentServerPolicy                               │
├──────────────────────────────────────────────────────────────┤
│  Custom Policies:                                             │
│  ✓ S3 Access (with KMS)                                      │
│  │  - ListBucket, GetBucketLocation                          │
│  │  - GetObject, PutObject, DeleteObject                     │
│  │  - KMS: Decrypt, GenerateDataKey                          │
│  │  - Condition: Via S3 service                              │
│  ✓ Secrets Manager Access (with KMS)                         │
│  │  - GetSecretValue, DescribeSecret                         │
│  │  - KMS: Decrypt, DescribeKey                              │
│  │  - Condition: Via Secrets Manager service                 │
└──────────────────────────────────────────────────────────────┘
        │
        ├─> Attached to: EC2 Instance Profile
        │
        └─> Used by: Windows Fleet Instances
```

### 2. Network Security Layer

```
┌─────────────────────────────────────────────────────────────────┐
│                    Network Security Groups                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Windows Fleet SG                                         │  │
│  │  Purpose: Protect Windows EC2 instances                  │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  Ingress Rules:                                           │  │
│  │  - RDP (3389) ← Bastion SG                               │  │
│  │  - App Port (8080) ← ALB SG                              │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  Egress Rules:                                            │  │
│  │  - HTTPS (443) → 0.0.0.0/0 (AWS services)                │  │
│  │  - PostgreSQL (5432) → Database SG                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Load Balancer SG                                         │  │
│  │  Purpose: Protect Application Load Balancer              │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  Ingress Rules:                                           │  │
│  │  - HTTPS (443) ← Configured CIDR blocks                  │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  Egress Rules:                                            │  │
│  │  - App Port (8080) → Windows Fleet SG                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Database SG                                              │  │
│  │  Purpose: Protect PostgreSQL RDS instance                │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  Ingress Rules:                                           │  │
│  │  - PostgreSQL (5432) ← Windows Fleet SG                  │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  Egress Rules:                                            │  │
│  │  - None (database doesn't initiate connections)          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3. Encryption Layer

```
┌─────────────────────────────────────────────────────────────────┐
│                      KMS Key Architecture                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────┐  ┌────────────────────┐                │
│  │  EBS KMS Key       │  │  RDS KMS Key       │                │
│  ├────────────────────┤  ├────────────────────┤                │
│  │ Purpose:           │  │ Purpose:           │                │
│  │ EC2 EBS volumes    │  │ RDS database       │                │
│  │                    │  │                    │                │
│  │ Rotation: Enabled  │  │ Rotation: Enabled  │                │
│  │ Deletion: 30 days  │  │ Deletion: 30 days  │                │
│  │                    │  │                    │                │
│  │ Principals:        │  │ Principals:        │                │
│  │ - ec2.amazonaws    │  │ - rds.amazonaws    │                │
│  │ - autoscaling      │  │                    │                │
│  │                    │  │                    │                │
│  │ Alias:             │  │ Alias:             │                │
│  │ env-project-ebs    │  │ env-project-rds    │                │
│  └────────────────────┘  └────────────────────┘                │
│                                                                  │
│  ┌────────────────────┐  ┌────────────────────┐                │
│  │  S3 KMS Key        │  │ Secrets Mgr Key    │                │
│  ├────────────────────┤  ├────────────────────┤                │
│  │ Purpose:           │  │ Purpose:           │                │
│  │ S3 bucket objects  │  │ Secrets Manager    │                │
│  │                    │  │                    │                │
│  │ Rotation: Enabled  │  │ Rotation: Enabled  │                │
│  │ Deletion: 30 days  │  │ Deletion: 30 days  │                │
│  │                    │  │                    │                │
│  │ Principals:        │  │ Principals:        │                │
│  │ - s3.amazonaws     │  │ - secretsmanager   │                │
│  │ - cloudtrail       │  │                    │                │
│  │                    │  │                    │                │
│  │ Alias:             │  │ Alias:             │                │
│  │ env-project-s3     │  │ env-project-secrets│                │
│  └────────────────────┘  └────────────────────┘                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 4. Secrets Management Layer

```
┌─────────────────────────────────────────────────────────────────┐
│                    Secrets Manager Secret                        │
├─────────────────────────────────────────────────────────────────┤
│  Name: env-project-db-credentials                                │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  Secret Value (JSON):                                       │ │
│  │  {                                                          │ │
│  │    "username": "dbadmin",                                   │ │
│  │    "password": "auto-generated-32-char-password",           │ │
│  │    "engine": "postgres",                                    │ │
│  │    "port": 5432                                             │ │
│  │  }                                                          │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  Encryption: Secrets Manager KMS Key                            │
│  Recovery Window: 7 days                                        │
│  Rotation: Manual (lifecycle ignored for external rotation)    │
│                                                                  │
│  Access Control:                                                 │
│  - IAM Policy: Windows Fleet Role                               │
│  - Actions: GetSecretValue, DescribeSecret                      │
│  - KMS Policy: Decrypt via Secrets Manager service              │
│                                                                  │
│  Audit:                                                          │
│  - CloudTrail logs all secret access                            │
│  - CloudWatch metrics for access patterns                       │
└─────────────────────────────────────────────────────────────────┘
```

### 5. Security Monitoring Layer

```
┌─────────────────────────────────────────────────────────────────┐
│                   Security Hub Architecture                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Security Hub                                             │  │
│  │  - Control Finding Generator: SECURITY_CONTROL            │  │
│  │  - Auto Enable Controls: true                             │  │
│  └──────────────────┬───────────────────────────────────────┘  │
│                     │                                            │
│         ┌───────────┴───────────┬─────────────────┐            │
│         ▼                       ▼                 ▼             │
│  ┌──────────────┐      ┌──────────────┐  ┌──────────────┐    │
│  │ AWS Found.   │      │ CIS Bench.   │  │  GuardDuty   │    │
│  │ Security     │      │ v1.2.0       │  │  Findings    │    │
│  │ Best Pract.  │      │ (Optional)   │  │  (Optional)  │    │
│  └──────────────┘      └──────────────┘  └──────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   GuardDuty Architecture                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  GuardDuty Detector (Optional)                            │  │
│  │  - Finding Frequency: FIFTEEN_MINUTES                     │  │
│  └──────────────┬───────────────────────────────────────────┘  │
│                 │                                                │
│         ┌───────┴───────┬─────────────────┐                    │
│         ▼               ▼                 ▼                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │ S3 Logs      │  │ Malware Scan │  │  Kubernetes  │        │
│  │ Protection   │  │ (EBS)        │  │  (Disabled)  │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Instance Startup Flow

```
1. EC2 Instance Launch
   │
   ├─> Attaches IAM Instance Profile
   │   └─> Assumes Windows Fleet Role
   │       └─> Validates source account + instance ARN
   │
   ├─> Attaches Windows Fleet Security Group
   │   └─> Allows RDP from bastion
   │   └─> Allows traffic from ALB
   │
   ├─> Attaches EBS Volume
   │   └─> Encrypted with EBS KMS Key
   │       └─> Key policy allows EC2/AutoScaling
   │
   ├─> Connects to Systems Manager
   │   └─> Via HTTPS (security group egress)
   │   └─> Using SSMManagedInstanceCore policy
   │
   ├─> Retrieves Database Credentials
   │   └─> Calls Secrets Manager GetSecretValue
   │       ├─> IAM policy allows GetSecretValue
   │       └─> KMS policy allows Decrypt via SM
   │
   └─> Sends Metrics to CloudWatch
       └─> Via HTTPS (security group egress)
       └─> Using CloudWatchAgentServerPolicy
```

### 2. Application Request Flow

```
1. External User Request
   │
   ├─> HTTPS (443) to ALB
   │   └─> ALB SG allows ingress from CIDR
   │
   ├─> ALB forwards to Fleet Instance
   │   └─> App port (8080)
   │   └─> ALB SG allows egress to Fleet SG
   │   └─> Fleet SG allows ingress from ALB SG
   │
   ├─> Fleet Instance processes request
   │   │
   │   ├─> Reads from S3 (if needed)
   │   │   └─> S3 policy allows GetObject
   │   │   └─> KMS policy allows Decrypt via S3
   │   │
   │   └─> Queries Database
   │       └─> PostgreSQL (5432) to RDS
   │       └─> Fleet SG allows egress to DB SG
   │       └─> DB SG allows ingress from Fleet SG
   │       └─> TLS connection (rds.force_ssl=1)
   │       └─> RDS encrypted with RDS KMS Key
   │
   └─> Response returned to user
```

### 3. Monitoring & Security Flow

```
All Resources
   │
   ├─> CloudTrail Logging
   │   └─> All API calls logged
   │   └─> Encrypted with S3 KMS Key
   │   └─> Stored in S3 bucket
   │
   ├─> GuardDuty Analysis (if enabled)
   │   ├─> Analyzes CloudTrail logs
   │   ├─> Analyzes VPC Flow Logs
   │   ├─> Analyzes DNS logs
   │   └─> Findings sent to Security Hub
   │
   ├─> Security Hub Aggregation
   │   ├─> Receives GuardDuty findings
   │   ├─> Runs security checks
   │   ├─> Evaluates compliance standards
   │   └─> Generates security score
   │
   └─> CloudWatch Metrics
       ├─> KMS key usage
       ├─> Secret access
       ├─> Security group changes
       └─> IAM role assumptions
```

## Security Principles

### 1. Defense in Depth

Multiple layers of security:
- **Network Layer**: Security groups, NACLs, VPC
- **Application Layer**: ALB with HTTPS, WAF (optional)
- **Data Layer**: KMS encryption, Secrets Manager
- **Identity Layer**: IAM roles, least privilege
- **Monitoring Layer**: Security Hub, GuardDuty, CloudTrail

### 2. Least Privilege

Every component has minimal required permissions:
- IAM roles scoped to specific resources
- Security groups allow only required traffic
- KMS key policies restrict to specific services
- Conditional policies enforce additional constraints

### 3. Encryption Everywhere

All data encrypted at rest and in transit:
- **EBS volumes**: Customer-managed KMS key
- **RDS database**: Customer-managed KMS key
- **S3 objects**: Customer-managed KMS key
- **Secrets**: Customer-managed KMS key
- **Transit**: TLS 1.2+ for all connections

### 4. Zero Trust Network

No implicit trust between components:
- Security groups reference each other, not CIDR blocks
- RDP access only from bastion (no direct internet)
- Database isolated in private subnet
- All service communication authenticated

### 5. Continuous Monitoring

Real-time security monitoring:
- CloudTrail for audit logging
- GuardDuty for threat detection
- Security Hub for compliance
- CloudWatch for operational metrics

## Design Decisions

### Why Customer-Managed KMS Keys?

**Decision**: Use customer-managed keys instead of AWS-managed keys

**Rationale**:
- Full control over key policies
- Enable/disable keys as needed
- Cross-account access if required
- Compliance requirements (HIPAA, PCI-DSS)
- Audit trail via CloudTrail

**Trade-off**: Additional management overhead

### Why Separate KMS Keys per Service?

**Decision**: Use separate KMS keys for EBS, RDS, S3, and Secrets Manager

**Rationale**:
- Principle of least privilege
- Limit blast radius if key compromised
- Service-specific key policies
- Independent key rotation schedules
- Granular access control

**Trade-off**: More keys to manage

### Why Security Group References?

**Decision**: Use security group references instead of CIDR blocks

**Rationale**:
- Dynamic: Instances added/removed automatically
- More secure: No need to track IP addresses
- Better documentation: Clear relationships
- Easier maintenance: Update one place

**Trade-off**: Requires all security groups in same module

### Why IAM Conditions on Assume Role?

**Decision**: Add SourceAccount and SourceArn conditions to assume role policy

**Rationale**:
- Prevents confused deputy problem
- Validates request origin
- Additional security layer
- Best practice per AWS

**Trade-off**: More complex policy

### Why GuardDuty Optional?

**Decision**: Make GuardDuty toggleable via variable

**Rationale**:
- Cost consideration for non-prod environments
- Not all organizations use GuardDuty
- Easy to enable when ready
- Allows gradual rollout

**Trade-off**: Security reduced when disabled

## Scalability

### Horizontal Scaling

Module designed for horizontal scaling:
- Security groups support unlimited instances
- IAM roles can be assumed by multiple instances
- KMS keys support high request rates
- Secrets Manager scales automatically

### Multi-Region

To deploy in multiple regions:
```hcl
module "security_us_east_1" {
  source = "./modules/security"
  providers = {
    aws = aws.us_east_1
  }
  # ... configuration
}

module "security_eu_west_1" {
  source = "./modules/security"
  providers = {
    aws = aws.eu_west_1
  }
  # ... configuration
}
```

**Note**: KMS keys are regional; secrets can be replicated

### Multi-Account

For multi-account deployments:
1. Deploy module in each account
2. Configure cross-account KMS key access
3. Use AWS Organizations for centralized Security Hub
4. Enable GuardDuty in delegated admin account

## Performance Considerations

### KMS Key Performance

- **Throughput**: 10,000 requests/second (adjustable)
- **Latency**: < 10ms for cryptographic operations
- **Cost**: $1/month per key + $0.03 per 10,000 requests

**Optimization**:
- Use data keys for bulk encryption
- Cache credentials from Secrets Manager
- Use VPC endpoints to reduce latency

### Security Group Rules

- **Limits**: 60 inbound + 60 outbound rules per SG
- **Evaluation**: All rules evaluated simultaneously
- **Performance**: Negligible impact on network performance

**Optimization**:
- Combine rules where possible
- Use security group references
- Monitor rule count via CloudWatch

## Disaster Recovery

### KMS Keys

**Backup**: KMS key metadata backed up automatically
**Recovery**: 7-30 day deletion window allows recovery
```bash
aws kms cancel-key-deletion --key-id <key-id>
```

### Secrets Manager

**Backup**: Secrets versioned automatically
**Recovery**: 7-30 day recovery window
```bash
aws secretsmanager restore-secret --secret-id <secret-id>
```

### Security Groups

**Backup**: Export rules via API or Terraform state
**Recovery**: Recreate from Terraform configuration
**Best Practice**: Version control Terraform code

### IAM Roles

**Backup**: Policies stored in Terraform state
**Recovery**: Recreate from Terraform configuration
**Best Practice**: Export policies to JSON for reference

## Cost Optimization

### KMS Keys

- **Fixed**: $1/month per key = $4/month
- **Variable**: $0.03 per 10,000 requests
- **Optimization**: Use data key caching

### GuardDuty

- **CloudTrail**: $4.40 per 1M events
- **VPC Flow Logs**: $1.50 per GB
- **S3 Logs**: $0.80 per 1M events
- **Malware Scanning**: $0.15 per GB scanned
- **Optimization**: Disable in non-prod environments

### Security Hub

- **Checks**: $0.0010 per check
- **Findings**: $0.00003 per finding ingested
- **Standards**: ~$1-2 per account/month
- **Optimization**: Disable non-essential standards

### Secrets Manager

- **Storage**: $0.40 per secret per month
- **API Calls**: $0.05 per 10,000 calls
- **Optimization**: Cache secret values

**Estimated Monthly Cost**:
- KMS Keys: $4
- Security Hub: $2
- GuardDuty (optional): $50-200 (variable)
- Secrets Manager: $1
- **Total**: ~$7-207 per month

## References

- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [AWS Well-Architected Framework - Security Pillar](https://wa.aws.amazon.com/wat.pillar.security.en.html)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
