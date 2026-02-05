# Hyperion Fleet Manager - Architecture Documentation

## Table of Contents

- [Overview](#overview)
- [Architecture Principles](#architecture-principles)
- [System Architecture](#system-architecture)
- [Network Architecture](#network-architecture)
- [Security Architecture](#security-architecture)
- [Compute Architecture](#compute-architecture)
- [Data Flow](#data-flow)
- [High Availability & Disaster Recovery](#high-availability--disaster-recovery)
- [Monitoring & Observability](#monitoring--observability)
- [Scalability](#scalability)
- [Cost Optimization](#cost-optimization)
- [Technology Stack](#technology-stack)
- [Design Patterns](#design-patterns)

## Overview

Hyperion Fleet Manager is designed as a cloud-native, highly available infrastructure platform for managing Windows server fleets in AWS. The architecture follows AWS Well-Architected Framework principles across five pillars: Operational Excellence, Security, Reliability, Performance Efficiency, and Cost Optimization.

### Architecture Goals

1. **Scalability**: Support fleets from 10 to 10,000+ Windows servers
2. **High Availability**: Multi-AZ deployment with automatic failover
3. **Security**: Defense-in-depth with multiple security layers
4. **Automation**: Infrastructure as Code for consistent, repeatable deployments
5. **Observability**: Comprehensive monitoring and logging
6. **Cost Efficiency**: Optimized resource utilization and right-sizing

## Architecture Principles

### 1. Infrastructure as Code (IaC)

All infrastructure is defined in version-controlled Terraform code, enabling:

- Reproducible deployments
- Version control and audit trails
- Collaboration through code review
- Automated testing and validation
- Disaster recovery through code re-deployment

### 2. Modularity

The architecture uses composable Terraform modules:

- **Networking Module**: VPC, subnets, routing, NAT gateways
- **Security Module**: Security groups, IAM roles, Network ACLs
- **Compute Module**: EC2 instances, Auto Scaling Groups
- **Monitoring Module**: CloudWatch, alarms, dashboards

Benefits:
- Reusability across environments
- Easier testing and maintenance
- Clear separation of concerns
- Simplified upgrades and changes

### 3. Defense in Depth

Multiple security layers protect the infrastructure:

1. Network isolation (VPC, subnets)
2. Network ACLs (subnet-level filtering)
3. Security Groups (instance-level firewalls)
4. IAM roles (least-privilege access)
5. Encryption (data at rest and in transit)
6. Logging and monitoring (audit trails)

### 4. High Availability

Architecture designed for resilience:

- Multi-AZ deployment (2+ Availability Zones)
- Redundant NAT Gateways
- Auto Scaling Groups for compute
- Health checks and automatic recovery
- No single points of failure

### 5. Operational Excellence

Designed for ease of operation:

- Automated deployments
- Comprehensive logging
- Monitoring and alerting
- Infrastructure testing
- Documentation and runbooks

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           AWS Organization                              │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         AWS Account (Production)                        │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                    Hyperion Fleet Manager VPC                     │ │
│  │                          (10.0.0.0/16)                            │ │
│  │                                                                   │ │
│  │  ┌────────────────────────────────────────────────────────────┐  │ │
│  │  │               Availability Zone us-east-1a                 │  │ │
│  │  │                                                            │  │ │
│  │  │  Public Subnet (10.0.1.0/24)                              │  │ │
│  │  │  ┌──────────────────────────────────────────────────────┐ │  │ │
│  │  │  │  Internet Gateway → NAT Gateway (EIP: 203.0.113.10)  │ │  │ │
│  │  │  │  Load Balancers (if applicable)                      │ │  │ │
│  │  │  └──────────────────────────────────────────────────────┘ │  │ │
│  │  │                                                            │  │ │
│  │  │  Private Subnet (10.0.10.0/24)                            │  │ │
│  │  │  ┌──────────────────────────────────────────────────────┐ │  │ │
│  │  │  │  Windows Server Fleet                                │ │  │ │
│  │  │  │  - EC2 Instances (Auto Scaling Group)                │ │  │ │
│  │  │  │  - Security Groups: RDP, Custom Ports                │ │  │ │
│  │  │  │  - IAM Instance Profile                              │ │  │ │
│  │  │  │  - CloudWatch Agent                                  │ │  │ │
│  │  │  └──────────────────────────────────────────────────────┘ │  │ │
│  │  └────────────────────────────────────────────────────────────┘  │ │
│  │                                                                   │ │
│  │  ┌────────────────────────────────────────────────────────────┐  │ │
│  │  │               Availability Zone us-east-1b                 │  │ │
│  │  │                                                            │  │ │
│  │  │  Public Subnet (10.0.2.0/24)                              │  │ │
│  │  │  ┌──────────────────────────────────────────────────────┐ │  │ │
│  │  │  │  NAT Gateway (EIP: 203.0.113.20)                     │ │  │ │
│  │  │  │  Load Balancers (if applicable)                      │ │  │ │
│  │  │  └──────────────────────────────────────────────────────┘ │  │ │
│  │  │                                                            │  │ │
│  │  │  Private Subnet (10.0.20.0/24)                            │  │ │
│  │  │  ┌──────────────────────────────────────────────────────┐ │  │ │
│  │  │  │  Windows Server Fleet                                │ │  │ │
│  │  │  │  - EC2 Instances (Auto Scaling Group)                │ │  │ │
│  │  │  │  - Security Groups: RDP, Custom Ports                │ │  │ │
│  │  │  │  - IAM Instance Profile                              │ │  │ │
│  │  │  │  - CloudWatch Agent                                  │ │  │ │
│  │  │  └──────────────────────────────────────────────────────┘ │  │ │
│  │  └────────────────────────────────────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                      AWS Supporting Services                      │ │
│  │                                                                   │ │
│  │  CloudWatch         │  Systems Manager  │  S3 Storage            │ │
│  │  - Logs             │  - State Manager  │  - Terraform State     │ │
│  │  - Metrics          │  - Patch Manager  │  - Artifacts           │ │
│  │  - Alarms           │  - Session Mgr    │  - Backups             │ │
│  │  - Dashboards       │  - Run Command    │  - Logs Archive        │ │
│  │                     │                   │                        │ │
│  │  DynamoDB           │  IAM              │  VPC Flow Logs         │ │
│  │  - State Locking    │  - Roles          │  - CloudWatch Logs     │ │
│  │  - Configuration    │  - Policies       │  - Network Analysis    │ │
│  └───────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

### Component Breakdown

#### 1. VPC (Virtual Private Cloud)

The foundation of network isolation:

- **CIDR Block**: 10.0.0.0/16 (65,536 IP addresses)
- **DNS Hostnames**: Enabled for instance hostname resolution
- **DNS Support**: Enabled for Route53 private hosted zones
- **Tenancy**: Default (shared hardware for cost efficiency)

#### 2. Subnets

Logical network segments within the VPC:

**Public Subnets** (Internet-accessible):
- Purpose: NAT Gateways, Load Balancers, Bastion Hosts
- Internet access: Direct via Internet Gateway
- IP Assignment: Auto-assign public IPs enabled
- CIDR Examples: 10.0.1.0/24 (AZ-1), 10.0.2.0/24 (AZ-2)

**Private Subnets** (Internal only):
- Purpose: Windows server fleet, application servers, databases
- Internet access: Via NAT Gateway in public subnet
- IP Assignment: Private IPs only
- CIDR Examples: 10.0.10.0/24 (AZ-1), 10.0.20.0/24 (AZ-2)

#### 3. Internet Gateway

Provides internet connectivity:
- One per VPC
- Highly available (AWS-managed)
- Attached to VPC for public internet access

#### 4. NAT Gateways

Enable private subnet internet access:

**High Availability Configuration** (Recommended for Production):
- One NAT Gateway per Availability Zone
- Each with dedicated Elastic IP
- Independent failure domains
- Higher cost, maximum resilience

**Cost-Optimized Configuration** (Development/Staging):
- Single NAT Gateway in one AZ
- All private subnets route through single NAT
- Lower cost, single point of failure

## Network Architecture

### Routing Architecture

#### Public Route Table

Routes traffic from public subnets:

| Destination  | Target          | Purpose                    |
|--------------|-----------------|----------------------------|
| 10.0.0.0/16  | local           | VPC internal routing       |
| 0.0.0.0/0    | Internet Gateway| Internet-bound traffic     |

Associated with: All public subnets

#### Private Route Tables

Routes traffic from private subnets:

**Configuration A: Multi-NAT (High Availability)**

Private Route Table 1 (AZ-1):
| Destination  | Target          | Purpose                    |
|--------------|-----------------|----------------------------|
| 10.0.0.0/16  | local           | VPC internal routing       |
| 0.0.0.0/0    | NAT Gateway 1   | Internet via NAT in AZ-1   |

Private Route Table 2 (AZ-2):
| Destination  | Target          | Purpose                    |
|--------------|-----------------|----------------------------|
| 10.0.0.0/16  | local           | VPC internal routing       |
| 0.0.0.0/0    | NAT Gateway 2   | Internet via NAT in AZ-2   |

**Configuration B: Single NAT (Cost Optimized)**

Private Route Table (Shared):
| Destination  | Target          | Purpose                    |
|--------------|-----------------|----------------------------|
| 10.0.0.0/16  | local           | VPC internal routing       |
| 0.0.0.0/0    | NAT Gateway 1   | Internet via single NAT    |

### Network Flow Diagrams

#### Inbound Traffic Flow (Public to Private)

```
Internet → Internet Gateway → Public Subnet → Load Balancer →
Security Group → Private Subnet → Windows Server
```

#### Outbound Traffic Flow (Private to Internet)

```
Windows Server → Security Group → Private Subnet →
Route Table → NAT Gateway → Internet Gateway → Internet
```

#### VPC Internal Communication

```
Instance A (10.0.10.5) → Security Group → Local Route (10.0.0.0/16) →
Security Group → Instance B (10.0.20.10)
```

## Security Architecture

### Network Security Layers

#### Layer 1: Network ACLs (Stateless)

Subnet-level firewall rules:

**Public Subnet NACL:**

Inbound Rules:
| Rule # | Type   | Protocol | Port Range | Source      | Action |
|--------|--------|----------|------------|-------------|--------|
| 100    | HTTP   | TCP      | 80         | 0.0.0.0/0   | ALLOW  |
| 110    | HTTPS  | TCP      | 443        | 0.0.0.0/0   | ALLOW  |
| 120    | SSH    | TCP      | 22         | 0.0.0.0/0   | ALLOW  |
| 130    | Custom | TCP      | 1024-65535 | 0.0.0.0/0   | ALLOW  |
| *      | All    | All      | All        | 0.0.0.0/0   | DENY   |

Outbound Rules:
| Rule # | Type   | Protocol | Port Range | Destination | Action |
|--------|--------|----------|------------|-------------|--------|
| 100    | All    | All      | All        | 0.0.0.0/0   | ALLOW  |
| *      | All    | All      | All        | 0.0.0.0/0   | DENY   |

**Private Subnet NACL:**

Inbound Rules:
| Rule # | Type   | Protocol | Port Range | Source      | Action |
|--------|--------|----------|------------|-------------|--------|
| 100    | All    | All      | All        | 10.0.0.0/16 | ALLOW  |
| 110    | Custom | TCP      | 1024-65535 | 0.0.0.0/0   | ALLOW  |
| *      | All    | All      | All        | 0.0.0.0/0   | DENY   |

Outbound Rules:
| Rule # | Type   | Protocol | Port Range | Destination | Action |
|--------|--------|----------|------------|-------------|--------|
| 100    | All    | All      | All        | 0.0.0.0/0   | ALLOW  |
| *      | All    | All      | All        | 0.0.0.0/0   | DENY   |

#### Layer 2: Security Groups (Stateful)

Instance-level firewall rules:

**Windows Server Security Group:**

Inbound Rules:
| Type       | Protocol | Port Range | Source                    | Description              |
|------------|----------|------------|---------------------------|--------------------------|
| RDP        | TCP      | 3389       | Bastion Security Group    | Remote Desktop           |
| HTTP       | TCP      | 80         | Load Balancer SG          | Application traffic      |
| HTTPS      | TCP      | 443        | Load Balancer SG          | Secure app traffic       |
| Custom TCP | TCP      | 8080       | Internal (10.0.0.0/16)    | Internal services        |
| All ICMP   | ICMP     | All        | Internal (10.0.0.0/16)    | Network diagnostics      |

Outbound Rules:
| Type       | Protocol | Port Range | Destination  | Description              |
|------------|----------|------------|--------------|--------------------------|
| All        | All      | All        | 0.0.0.0/0    | All outbound allowed     |

#### Layer 3: IAM Security

**EC2 Instance Role:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::hyperion-artifacts/*",
        "arn:aws:s3:::hyperion-artifacts"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "cloudwatch:GetMetricData",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/ec2/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:UpdateInstanceInformation",
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "*"
    }
  ]
}
```

### VPC Flow Logs

Network traffic monitoring and security analysis:

**Configuration:**
- Traffic Type: ALL (Accept and Reject)
- Destination: CloudWatch Logs
- Log Format: Default AWS format
- Retention: 7 days (configurable)

**Use Cases:**
- Security incident investigation
- Network troubleshooting
- Compliance auditing
- Anomaly detection
- Cost optimization

**Example Log Entry:**
```
2 123456789012 eni-1234abcd 10.0.10.5 203.0.113.1 443 49152 6 10 840 1620000000 1620000060 ACCEPT OK
```

## Compute Architecture

### EC2 Instance Strategy

#### Instance Types

**Windows Server Workloads:**
- **t3.medium**: Development/testing environments
- **m5.large**: General-purpose production workloads
- **c5.xlarge**: Compute-intensive applications
- **r5.large**: Memory-intensive applications

#### Auto Scaling Groups

**Configuration:**
```hcl
resource "aws_autoscaling_group" "windows_fleet" {
  name                = "hyperion-windows-fleet-asg"
  vpc_zone_identifier = [subnet-1, subnet-2]
  min_size            = 2
  max_size            = 10
  desired_capacity    = 4

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.windows.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "hyperion-windows-server"
    propagate_at_launch = true
  }
}
```

**Scaling Policies:**
- Scale out: CPU > 70% for 5 minutes
- Scale in: CPU < 30% for 10 minutes
- Cooldown period: 300 seconds

#### Launch Template

**Key Components:**
- AMI: Latest Windows Server 2022
- Instance type: Configurable via variables
- IAM instance profile: EC2 role with required permissions
- User data: Bootstrap script for configuration
- EBS volumes: Encrypted GP3 volumes
- Network interfaces: Private subnet placement
- Security groups: Application-specific rules

### Instance Lifecycle

```
Launch → Initialize → Configure → Register → Healthy → In Service
                                                           ↓
                                      Unhealthy ← Health Check
                                         ↓
                                    Terminate
```

## Data Flow

### Deployment Flow

```
Developer Workstation
        ↓
    Git Push
        ↓
Version Control (GitHub)
        ↓
    CI/CD Pipeline (Optional)
        ↓
Terraform Apply
        ↓
    AWS API
        ↓
Infrastructure Provisioning
        ↓
    Deployed Resources
```

### Traffic Flow

#### User Access Flow

```
User → VPN/Direct Connect → Private Subnet → RDP → Windows Server
```

#### Application Traffic Flow

```
Internet → Route53 → CloudFront (Optional) → ALB →
Target Group → Windows Servers (Round Robin)
```

#### Logging Flow

```
Windows Server → CloudWatch Agent → CloudWatch Logs →
S3 Archive (Long-term) / Lambda (Analysis)
```

## High Availability & Disaster Recovery

### High Availability Design

**Multi-AZ Deployment:**
- Resources distributed across 2+ Availability Zones
- Independent infrastructure per AZ
- Automatic failover between AZs

**Component Availability:**

| Component       | HA Strategy                        | Availability    |
|-----------------|------------------------------------|-----------------|
| VPC             | Regional (AWS-managed)             | 99.99%          |
| Subnets         | AZ-specific, multi-AZ design       | 99.99%          |
| NAT Gateway     | One per AZ (or single for cost)    | 99.95% per AZ   |
| Internet Gateway| Regional (AWS-managed)             | 99.99%          |
| EC2 Instances   | Auto Scaling across multiple AZs   | 99.99% (fleet)  |
| Load Balancers  | Multi-AZ by default                | 99.99%          |

### Disaster Recovery

**RTO (Recovery Time Objective):** 15-30 minutes
**RPO (Recovery Point Objective):** 5 minutes

**Recovery Strategies:**

1. **Infrastructure Recovery:**
   - Terraform state stored in S3 with versioning
   - Re-deploy infrastructure from code
   - Automated recovery scripts

2. **Data Recovery:**
   - EBS snapshots (automated daily)
   - S3 versioning for critical data
   - Cross-region replication for critical buckets

3. **Application Recovery:**
   - Immutable infrastructure pattern
   - AMI-based deployments
   - Configuration management via Systems Manager

**Recovery Procedure:**

```bash
# 1. Verify Terraform state
terraform state list

# 2. Reinitialize if needed
terraform init -reconfigure

# 3. Deploy infrastructure
terraform apply -var-file=prod.tfvars

# 4. Restore data from backups
aws s3 sync s3://backup-bucket/ s3://production-bucket/ --region us-east-1

# 5. Verify deployment
./scripts/validate.sh
```

## Monitoring & Observability

### CloudWatch Metrics

**VPC Metrics:**
- VPC Flow Logs analysis
- Network throughput
- Packet loss rates

**EC2 Metrics:**
- CPU Utilization
- Network In/Out
- Disk Read/Write
- Status Check Failed

**Custom Application Metrics:**
- Application response time
- Request rate
- Error rate
- Business metrics

### CloudWatch Alarms

**Critical Alarms:**
- EC2 instance status check failure
- Auto Scaling Group capacity
- NAT Gateway packet drop rate
- High CPU utilization (> 85%)

**Warning Alarms:**
- Moderate CPU utilization (> 70%)
- Network errors
- Disk space utilization (> 80%)

### Logging Strategy

**Log Aggregation:**
```
Windows Event Logs → CloudWatch Agent → CloudWatch Logs →
[Real-time Analysis: CloudWatch Insights]
[Long-term Storage: S3 Archive]
```

**Log Types:**
- VPC Flow Logs
- Application logs
- Windows Event Logs
- Security logs
- Audit logs

**Retention Policy:**
- Real-time logs: 7 days in CloudWatch
- Compliance logs: 90 days in CloudWatch, 7 years in S3
- Debug logs: 1 day in CloudWatch

## Scalability

### Horizontal Scaling

Auto Scaling Group automatically adjusts fleet size:

**Scale-Out Triggers:**
- CPU > 70% for 5 minutes
- Memory > 80% for 5 minutes
- Custom application metric threshold

**Scale-In Triggers:**
- CPU < 30% for 10 minutes
- Low application load

**Scaling Limits:**
- Minimum: 2 instances (HA requirement)
- Maximum: 100 instances (service quota)
- Desired: Dynamic based on load

### Vertical Scaling

Instance type changes through Launch Template updates:

```bash
# Update launch template with larger instance type
terraform apply -var="instance_type=m5.xlarge"

# Initiate instance refresh
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name hyperion-windows-fleet-asg
```

## Cost Optimization

### Cost Optimization Strategies

1. **NAT Gateway Optimization:**
   - Single NAT for non-production (saves ~$100/month)
   - VPC endpoints for S3/DynamoDB (avoid NAT charges)

2. **EC2 Optimization:**
   - Right-size instances based on CloudWatch metrics
   - Reserved Instances for baseline capacity (up to 72% savings)
   - Spot Instances for fault-tolerant workloads (up to 90% savings)

3. **Storage Optimization:**
   - GP3 instead of GP2 EBS volumes (20% cost savings)
   - S3 Intelligent-Tiering for long-term data
   - Lifecycle policies for log archival

4. **Network Optimization:**
   - VPC endpoints to avoid data transfer charges
   - CloudFront for static content distribution

### Cost Monitoring

**AWS Cost Explorer Integration:**
- Tagged resources for cost allocation
- Department/project cost breakdowns
- Budget alerts at 80%, 100% thresholds

**Monthly Cost Estimate (Sample):**

| Resource Type      | Quantity | Unit Cost  | Monthly Cost |
|--------------------|----------|------------|--------------|
| EC2 (m5.large)     | 4        | $70        | $280         |
| NAT Gateway (2 AZ) | 2        | $32        | $64          |
| NAT Data Transfer  | 1TB      | $45        | $45          |
| EBS (GP3)          | 400GB    | $0.08/GB   | $32          |
| CloudWatch Logs    | 10GB     | $0.50/GB   | $5           |
| **Total**          |          |            | **$426**     |

## Technology Stack

### Infrastructure Layer

- **Terraform**: 1.5+ (Infrastructure as Code)
- **AWS Provider**: 5.0+ (AWS resource management)

### Cloud Services

- **Compute**: EC2, Auto Scaling
- **Networking**: VPC, Subnets, NAT Gateway, Internet Gateway
- **Security**: Security Groups, NACLs, IAM
- **Monitoring**: CloudWatch, VPC Flow Logs
- **Storage**: S3, EBS
- **Database**: DynamoDB (state locking)
- **Management**: Systems Manager

### Operating Systems

- **Windows Server 2022**: Primary OS for fleet
- **Amazon Linux 2**: Bastion hosts (if needed)

## Design Patterns

### 1. Immutable Infrastructure

Servers are never updated in place; instead:
- New AMI created with updates
- New instances launched from updated AMI
- Old instances terminated
- Ensures consistency and repeatability

### 2. Cattle, Not Pets

Instances are disposable and interchangeable:
- No manual configuration
- Automated provisioning
- Easy replacement
- Horizontal scaling

### 3. Infrastructure as Code

All infrastructure defined in code:
- Version controlled
- Peer reviewed
- Automated testing
- Documented through code

### 4. Defense in Depth

Multiple security layers:
- Network isolation (VPC)
- Subnet segmentation
- Network ACLs
- Security Groups
- IAM policies
- Encryption

### 5. Everything Fails

Design assuming failures will occur:
- Multi-AZ redundancy
- Auto Scaling for recovery
- Health checks
- Automated failover
- Backup and restore procedures

---

## References

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [Architecture Decision Records](./ADR/)

---

**Document Version:** 1.0
**Last Updated:** 2024-12-15
**Maintained By:** DevOps Team
