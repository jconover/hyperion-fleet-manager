# Hyperion Fleet Manager - Phase 1 Integration Architecture

## Executive Summary

This document describes how all Phase 1 components of the Hyperion Fleet Manager integrate to provide a complete, production-ready Windows server fleet management platform on AWS. The architecture follows cloud best practices with defense-in-depth security, high availability, and comprehensive observability.

## Integration Overview

Phase 1 delivers four core infrastructure modules that work together to provide a complete fleet management solution:

1. **Networking Module**: Provides the foundational network infrastructure
2. **Security Module**: Implements security controls, encryption, and access management
3. **Compute Module**: Deploys and manages Windows Server 2022 EC2 fleets
4. **Observability Module**: Monitors, logs, and alerts on fleet health and performance

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AWS Account (Multi-AZ Region)                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  NETWORKING MODULE (VPC Layer)                                         │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐ │ │
│  │  │  VPC: 10.0.0.0/16                                                 │ │ │
│  │  │                                                                    │ │ │
│  │  │  Public Subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)          │ │ │
│  │  │  ├── Internet Gateway                                             │ │ │
│  │  │  ├── NAT Gateways (Multi-AZ) with Elastic IPs                    │ │ │
│  │  │  └── Bastion Host (Future Phase 2)                               │ │ │
│  │  │                                                                    │ │ │
│  │  │  Private Subnets (10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24)     │ │ │
│  │  │  ├── Windows Fleet Instances (via Compute Module)                │ │ │
│  │  │  ├── RDS PostgreSQL (Future Phase 2)                             │ │ │
│  │  │  └── VPC Flow Logs → CloudWatch                                  │ │ │
│  │  │                                                                    │ │ │
│  │  │  Network ACLs: Public (HTTP/HTTPS/SSH) | Private (VPC-only)     │ │ │
│  │  └──────────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                        │
│                                      ↓                                        │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  SECURITY MODULE (Defense-in-Depth)                                   │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  KMS Encryption Keys (with Auto-Rotation)                        ┃ │ │
│  │  ┃  ├── EBS Encryption Key → Compute Module                        ┃ │ │
│  │  ┃  ├── RDS Encryption Key → Future Database Module               ┃ │ │
│  │  ┃  ├── S3 Encryption Key → Backups & Logs                        ┃ │ │
│  │  ┃  └── Secrets Manager Key → Database Credentials                ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  Security Groups (Stateful Firewalls)                           ┃ │ │
│  │  ┃  ├── Windows Fleet SG                                           ┃ │ │
│  │  ┃  │   ├── Ingress: ALB → 8080/tcp                              ┃ │ │
│  │  ┃  │   ├── Ingress: Bastion → 3389/tcp (RDP)                   ┃ │ │
│  │  ┃  │   ├── Egress: 443/tcp → AWS Services (SSM, CloudWatch)    ┃ │ │
│  │  ┃  │   └── Egress: 5432/tcp → Database SG                      ┃ │ │
│  │  ┃  ├── Application Load Balancer SG                              ┃ │ │
│  │  ┃  │   ├── Ingress: 0.0.0.0/0 → 443/tcp (HTTPS)               ┃ │ │
│  │  ┃  │   └── Egress: Windows Fleet SG → 8080/tcp                 ┃ │ │
│  │  ┃  └── Database SG                                               ┃ │ │
│  │  ┃      └── Ingress: Windows Fleet SG → 5432/tcp                 ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  IAM Roles & Policies (Least Privilege)                         ┃ │ │
│  │  ┃  └── Windows Fleet Instance Profile                            ┃ │ │
│  │  ┃      ├── SSM Managed Instance Core (Session Manager)          ┃ │ │
│  │  ┃      ├── CloudWatch Agent Server Policy                       ┃ │ │
│  │  ┃      ├── S3 Access (Scoped to Fleet Buckets)                 ┃ │ │
│  │  ┃      ├── Secrets Manager (Database Credentials Only)          ┃ │ │
│  │  ┃      └── KMS Decrypt (Via Service Condition Keys)             ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  Secrets Management                                             ┃ │ │
│  │  ┃  └── AWS Secrets Manager                                       ┃ │ │
│  │  ┃      └── Database Credentials (Encrypted with KMS)             ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  Threat Detection & Compliance (Optional)                       ┃ │ │
│  │  ┃  ├── AWS Security Hub (CIS Benchmark, AWS Best Practices)     ┃ │ │
│  │  ┃  └── AWS GuardDuty (Malware Detection, Threat Intelligence)   ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                        │
│                                      ↓                                        │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  COMPUTE MODULE (Windows Fleet Management)                            │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  Launch Template (Windows Server 2022)                          ┃ │ │
│  │  ┃  ├── AMI: Latest AWS-managed Windows Server 2022               ┃ │ │
│  │  ┃  ├── Instance Types: t3.medium, t3.large, c5.xlarge (Mixed)    ┃ │ │
│  │  ┃  ├── IMDSv2: Required (SSRF Protection)                        ┃ │ │
│  │  ┃  ├── EBS Volumes: Encrypted with KMS (from Security Module)    ┃ │ │
│  │  ┃  ├── IAM Profile: From Security Module                         ┃ │ │
│  │  ┃  ├── Security Groups: From Security Module                     ┃ │ │
│  │  ┃  └── User Data: PowerShell Bootstrap Script                    ┃ │ │
│  │  ┃      ├── Configure SSM Agent                                   ┃ │ │
│  │  ┃      ├── Install CloudWatch Agent                             ┃ │ │
│  │  ┃      ├── Set NTP to AWS Time Sync                             ┃ │ │
│  │  ┃      ├── Configure Windows Firewall                           ┃ │ │
│  │  ┃      ├── Initialize Additional EBS Volumes                    ┃ │ │
│  │  ┃      └── Run Custom Application Setup                         ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  Auto Scaling Group (Multi-AZ)                                  ┃ │ │
│  │  ┃  ├── Subnets: Private subnets from Networking Module           ┃ │ │
│  │  ┃  ├── Capacity: Min=2, Desired=3, Max=10                        ┃ │ │
│  │  ┃  ├── Health Check: ELB + EC2 (5min grace period)              ┃ │ │
│  │  ┃  ├── Mixed Instances Policy (On-Demand + Spot)                ┃ │ │
│  │  ┃  └── Instance Refresh: Rolling updates (90% healthy)           ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  Auto Scaling Policies                                          ┃ │ │
│  │  ┃  ├── CPU Target Tracking: 70%                                  ┃ │ │
│  │  ┃  ├── Network In Target Tracking: 10MB/s                        ┃ │ │
│  │  ┃  └── ALB Request Count: 1000 req/target                        ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                        │
│                                      ↓                                        │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  OBSERVABILITY MODULE (Monitoring & Alerting)                         │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  CloudWatch Log Groups                                          ┃ │ │
│  │  ┃  ├── /hyperion/fleet/system (30 days retention)                ┃ │ │
│  │  ┃  ├── /hyperion/fleet/application (30 days retention)           ┃ │ │
│  │  ┃  ├── /hyperion/fleet/security (90 days retention)              ┃ │ │
│  │  ┃  └── /aws/vpc/flow-logs (from Networking Module)               ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  CloudWatch Metric Alarms                                       ┃ │ │
│  │  ┃  ├── High CPU: > 80% for 15 minutes                            ┃ │ │
│  │  ┃  ├── High Memory: > 85% for 15 minutes                         ┃ │ │
│  │  ┃  ├── Low Disk Space: < 15% free                                ┃ │ │
│  │  ┃  ├── Unhealthy Hosts: > 0 in Target Group                      ┃ │ │
│  │  ┃  ├── Application Errors: > 10 per minute                       ┃ │ │
│  │  ┃  ├── Security Events: Any critical event                       ┃ │ │
│  │  ┃  └── Composite Alarm: Critical System Health                   ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  CloudWatch Dashboard                                           ┃ │ │
│  │  ┃  └── Fleet Health Overview                                     ┃ │ │
│  │  ┃      ├── EC2 Metrics (CPU, Memory, Disk, Network)             ┃ │ │
│  │  ┃      ├── ASG Metrics (Capacity, Scaling Activities)           ┃ │ │
│  │  ┃      ├── ALB Metrics (Request Count, Response Times)          ┃ │ │
│  │  ┃      └── Log Insights Queries                                 ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  SNS Topic & Subscriptions                                     ┃ │ │
│  │  ┃  └── Fleet Alerts → Email, Slack, PagerDuty                   ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  EventBridge Rules                                              ┃ │ │
│  │  ┃  ├── Instance State Changes → SNS Notification                ┃ │ │
│  │  ┃  ├── Scheduled Health Checks (every 5 minutes)                ┃ │ │
│  │  ┃  └── Automated Backups (daily at 2 AM UTC)                    ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │ │
│  │  ┃  AWS X-Ray (Optional)                                           ┃ │ │
│  │  ┃  ├── Sampling Rules: 5% of requests                            ┃ │ │
│  │  ┃  ├── Insights: Automatic anomaly detection                     ┃ │ │
│  │  ┃  └── Service Map: Application dependency visualization         ┃ │ │
│  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### Instance Bootstrapping Flow

```
1. Auto Scaling Group launches EC2 instance in private subnet
   └→ Launch Template specifies: AMI, instance type, IAM profile, user data

2. Instance receives private IP from subnet CIDR
   └→ Security groups attached: Windows Fleet SG

3. User data (PowerShell) executes on first boot:
   ├→ [Step 1] Configure PowerShell execution policy
   ├→ [Step 2] Configure Windows Time Service (AWS NTP)
   ├→ [Step 3] Set timezone to UTC
   ├→ [Step 4] Verify SSM Agent status (pre-installed in AMI)
   │   └→ Instance registers with Systems Manager
   ├→ [Step 5] Configure CloudWatch Agent
   │   ├→ Generate config from template
   │   ├→ Start agent
   │   └→ Begin sending metrics to CloudWatch
   ├→ [Step 6] Retrieve instance metadata (IMDSv2)
   │   └→ Store in registry for application use
   ├→ [Step 7] Configure Windows Firewall rules
   ├→ [Step 8] Initialize and format additional EBS volumes
   ├→ [Step 9] Optimize system (disable unnecessary services)
   ├→ [Step 10] Configure event log retention
   └→ [Step 11] Execute custom application setup script

4. Instance signals healthy to Auto Scaling Group
   └→ Health check grace period: 5 minutes

5. Instance ready to receive traffic from Application Load Balancer
```

### Logging and Monitoring Flow

```
┌────────────────────────────────────────────────────────────────┐
│  Windows Fleet Instances                                       │
│  ├→ CloudWatch Agent                                           │
│  │   ├→ Collects: Windows Event Logs (System, Application)    │
│  │   ├→ Collects: Custom application logs                      │
│  │   ├→ Collects: Metrics (CPU, Memory, Disk)                 │
│  │   └→ Streams to CloudWatch Logs & Metrics                   │
│  └→ Application logs written to local files                    │
└────────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌────────────────────────────────────────────────────────────────┐
│  CloudWatch Logs                                               │
│  ├→ /hyperion/fleet/system                                     │
│  ├→ /hyperion/fleet/application                                │
│  ├→ /hyperion/fleet/security                                   │
│  └→ /aws/ec2/windows/{fleet-name}/{log-type}                   │
└────────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌────────────────────────────────────────────────────────────────┐
│  Log Metric Filters                                            │
│  ├→ Parse logs for ERROR patterns                              │
│  ├→ Parse logs for security events                             │
│  └→ Create custom metrics in CloudWatch                        │
└────────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌────────────────────────────────────────────────────────────────┐
│  CloudWatch Alarms                                             │
│  ├→ Evaluate metrics against thresholds                        │
│  ├→ Enter ALARM state when threshold breached                  │
│  └→ Trigger alarm actions                                      │
└────────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌────────────────────────────────────────────────────────────────┐
│  SNS Topic                                                     │
│  └→ Publish alarm notification                                 │
└────────────────────────────────────────────────────────────────┘
                            │
                            ↓
┌────────────────────────────────────────────────────────────────┐
│  SNS Subscriptions                                             │
│  ├→ Email: Send to operations team                            │
│  ├→ Lambda: Trigger automated remediation (Phase 2)           │
│  └→ Webhook: Send to Slack/PagerDuty (Phase 2)                │
└────────────────────────────────────────────────────────────────┘
```

### Security Flow: Instance Access via Systems Manager

```
┌──────────────────────────────────────────────────────────────┐
│  Operator                                                     │
│  └→ aws ssm start-session --target i-1234567890abcdef0       │
└──────────────────────────────────────────────────────────────┘
                        │
                        ↓
┌──────────────────────────────────────────────────────────────┐
│  AWS Systems Manager Service                                 │
│  ├→ Validates IAM permissions                                │
│  ├→ Checks instance SSM agent status                         │
│  └→ Establishes secure session                               │
└──────────────────────────────────────────────────────────────┘
                        │
                        ↓
┌──────────────────────────────────────────────────────────────┐
│  VPC Private Subnet (no inbound internet access)             │
│  └→ Windows Fleet Instance                                   │
│      ├→ Security Group: ALLOWS egress 443 to 0.0.0.0/0      │
│      ├→ Instance Profile: SSM permissions                    │
│      └→ SSM Agent: Establishes outbound connection           │
└──────────────────────────────────────────────────────────────┘
                        │
                        ↓
┌──────────────────────────────────────────────────────────────┐
│  Secure Shell Session (Encrypted)                            │
│  ├→ All commands logged to CloudWatch Logs                   │
│  ├→ No RDP credentials required                              │
│  ├→ No inbound firewall rules required                       │
│  └→ No bastion host required                                 │
└──────────────────────────────────────────────────────────────┘
```

## Module Dependencies

### Dependency Graph

```
networking (no dependencies)
    │
    ├→ provides: vpc_id, subnet_ids, security_group_ids, flow_log_group
    │
    ↓
security (depends on: networking)
    │
    ├→ requires: vpc_id, bastion_security_group_id
    ├→ provides: kms_keys, iam_roles, security_groups, secrets
    │
    ↓
compute (depends on: networking, security)
    │
    ├→ requires: vpc_id, subnet_ids, security_group_id, kms_key_arn, iam_instance_profile
    ├→ provides: asg_name, instance_ids, launch_template_id
    │
    ↓
observability (depends on: compute, security)
    │
    ├→ requires: instance_ids, kms_key_id, target_group_arn
    ├→ provides: dashboard_url, sns_topic_arn, alarm_names
```

### Module Interface Compatibility

#### Networking → Security

**Networking Outputs:**
```hcl
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}
```

**Security Inputs:**
```hcl
variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}
```

**Integration:** Direct pass-through of VPC ID for security group creation.

#### Security → Compute

**Security Outputs:**
```hcl
output "kms_key_ebs_arn" {
  description = "ARN of the KMS key for EBS encryption"
  value       = aws_kms_key.ebs.arn
}

output "windows_fleet_instance_profile_arn" {
  description = "ARN of the instance profile for Windows fleet instances"
  value       = aws_iam_instance_profile.windows_fleet.arn
}

output "windows_fleet_security_group_id" {
  description = "ID of the security group for Windows fleet instances"
  value       = aws_security_group.windows_fleet.id
}
```

**Compute Inputs:**
```hcl
# From compute module variables.tf
variable "vpc_id" { ... }
variable "subnet_ids" { ... }

# Compute module internally creates its own KMS key and IAM roles
# But can optionally accept external security group IDs
variable "additional_security_group_ids" {
  description = "Additional security group IDs to attach"
  type        = list(string)
  default     = []
}
```

**Integration Note:** The compute module creates its own KMS key and IAM roles for self-contained operation. For integration with the security module, use the security module's outputs as additional security groups and update the compute module to accept external KMS keys in Phase 2.

#### Compute → Observability

**Compute Outputs:**
```hcl
output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.fleet.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for EBS encryption"
  value       = aws_kms_key.ebs.arn
}
```

**Observability Inputs:**
```hcl
variable "instance_ids" {
  description = "List of EC2 instance IDs to monitor"
  type        = list(string)
  default     = []
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting CloudWatch Logs"
  type        = string
  default     = null
}
```

**Integration:** Use AWS CLI or data source to retrieve instance IDs from ASG, pass KMS key for log encryption.

## Environment Configuration Strategy

### Variable Naming Consistency

All modules follow consistent variable naming patterns:

- **Environment:** `environment` (dev, staging, prod)
- **Name Prefix:** `name_prefix` or `project_name` or `fleet_name`
- **VPC Reference:** `vpc_id`
- **Tags:** `tags` (map of strings)

### Recommended Root Module Structure

```hcl
# infrastructure/environments/prod/main.tf

module "networking" {
  source = "../../modules/networking"

  name_prefix = "hyperion-prod"
  vpc_cidr    = "10.0.0.0/16"

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

  enable_nat_gateway  = true
  single_nat_gateway  = false  # Multi-AZ for production
  enable_flow_logs    = true
  enable_network_acls = true

  tags = local.common_tags
}

module "security" {
  source = "../../modules/security"

  environment  = "prod"
  project_name = "hyperion"
  vpc_id       = module.networking.vpc_id

  # Bastion SG will be created in Phase 2
  bastion_security_group_id = "sg-placeholder"  # Temporary

  fleet_s3_bucket_arns = [
    "arn:aws:s3:::hyperion-prod-artifacts",
    "arn:aws:s3:::hyperion-prod-backups"
  ]

  alb_ingress_cidr_blocks = ["0.0.0.0/0"]  # HTTPS from internet
  fleet_application_port  = 8080

  enable_security_hub = true
  enable_guardduty    = true

  tags = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  fleet_name = "hyperion-prod"
  vpc_id     = module.networking.vpc_id
  subnet_ids = module.networking.private_subnet_ids

  instance_types   = ["t3.medium", "t3.large", "c5.xlarge"]
  min_capacity     = 2
  max_capacity     = 10
  desired_capacity = 3

  # Use security module's security groups as additional groups
  additional_security_group_ids = [
    module.security.windows_fleet_security_group_id
  ]

  enable_load_balancer = true
  # target_group_arns will be added in Phase 2 when ALB is created

  enable_cpu_target_tracking = true
  cpu_target_value           = 70

  enable_cloudwatch_alarms = true

  tags = merge(local.common_tags, {
    Role = "compute"
  })
}

module "observability" {
  source = "../../modules/observability"

  environment = "prod"

  # Log configuration
  log_retention_days          = 30
  security_log_retention_days = 90
  kms_key_id                  = module.security.kms_key_s3_arn

  # Instance monitoring
  instance_ids           = []  # Will be populated from ASG
  enable_instance_alarms = true

  # Target group monitoring (Phase 2)
  target_group_arn_suffix = ""
  load_balancer_arn_suffix = ""
  enable_target_group_alarms = false

  # Alert configuration
  alert_email_addresses = [
    "ops-team@example.com",
    "oncall@example.com"
  ]

  # Alarm thresholds
  cpu_threshold_percent       = 80
  memory_threshold_percent    = 85
  disk_free_threshold_percent = 15

  # EventBridge schedules
  health_check_schedule = "rate(5 minutes)"
  backup_schedule       = "cron(0 2 * * ? *)"

  # X-Ray (optional for distributed tracing)
  enable_xray = false

  tags = local.common_tags
}

locals {
  common_tags = {
    Environment = "production"
    Project     = "hyperion-fleet-manager"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
  }
}

# Outputs for reference
output "vpc_id" {
  value = module.networking.vpc_id
}

output "asg_name" {
  value = module.compute.asg_name
}

output "dashboard_url" {
  value = module.observability.dashboard_url
}

output "sns_topic_arn" {
  value = module.observability.sns_topic_arn
}
```

### Environment-Specific Configurations

#### Development Environment

```hcl
# infrastructure/environments/dev/terraform.tfvars

# Networking
name_prefix = "hyperion-dev"
vpc_cidr    = "10.1.0.0/16"
single_nat_gateway = true  # Cost savings: single NAT

# Compute
min_capacity     = 1
max_capacity     = 3
desired_capacity = 1
instance_types   = ["t3.medium"]  # Smaller instances

# Monitoring
cpu_threshold_percent = 90  # Higher threshold for dev
log_retention_days    = 7   # Shorter retention

# Security
enable_guardduty = false  # Optional for dev
```

#### Production Environment

```hcl
# infrastructure/environments/prod/terraform.tfvars

# Networking
name_prefix = "hyperion-prod"
vpc_cidr    = "10.0.0.0/16"
single_nat_gateway = false  # High availability: multi-AZ NAT

# Compute
min_capacity     = 3
max_capacity     = 20
desired_capacity = 5
instance_types   = ["t3.large", "c5.xlarge", "c5.2xlarge"]

# Monitoring
cpu_threshold_percent = 70
log_retention_days    = 30
security_log_retention_days = 90

# Security
enable_security_hub = true
enable_guardduty    = true
enable_cis_benchmark = true
```

## Testing Strategy

### Module Testing Checklist

#### Networking Module
- [ ] VPC created with correct CIDR
- [ ] Subnets created in specified AZs
- [ ] Internet Gateway attached
- [ ] NAT Gateways operational (test internet from private subnet)
- [ ] Route tables correctly associated
- [ ] VPC Flow Logs appearing in CloudWatch
- [ ] Network ACLs allowing expected traffic

```bash
# Validation commands
terraform validate
terraform plan -out=tfplan

# Post-deployment tests
aws ec2 describe-vpcs --vpc-ids $(terraform output -raw vpc_id)
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
aws logs tail /aws/vpc/hyperion-prod-flow-logs --follow
```

#### Security Module
- [ ] KMS keys created with rotation enabled
- [ ] Security groups have correct rules
- [ ] IAM roles follow least privilege
- [ ] Secrets Manager secret created
- [ ] Security Hub enabled (if configured)
- [ ] GuardDuty detector active (if configured)

```bash
# Validation commands
aws kms describe-key --key-id $(terraform output -raw kms_key_ebs_id)
aws ec2 describe-security-groups --group-ids $(terraform output -raw windows_fleet_security_group_id)
aws iam get-role --role-name $(terraform output -raw windows_fleet_role_name)
aws secretsmanager describe-secret --secret-id $(terraform output -raw db_credentials_secret_name)
```

#### Compute Module
- [ ] Launch template created with correct configuration
- [ ] Auto Scaling Group operational
- [ ] Instances launching successfully
- [ ] IMDSv2 enforced
- [ ] EBS volumes encrypted
- [ ] SSM Agent responding
- [ ] CloudWatch Agent sending metrics
- [ ] User data script executed successfully

```bash
# Validation commands
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $(terraform output -raw asg_name)
aws ec2 describe-instances --filters "Name=tag:aws:autoscaling:groupName,Values=$(terraform output -raw asg_name)"

# Connect via SSM (no SSH required)
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-instances --query "AutoScalingInstances[0].InstanceId" --output text)
aws ssm start-session --target $INSTANCE_ID

# Inside session, check bootstrap log
Get-Content C:\ProgramData\Bootstrap\bootstrap.log
```

#### Observability Module
- [ ] CloudWatch log groups created
- [ ] SNS topic and subscriptions configured
- [ ] CloudWatch alarms created
- [ ] Dashboard visible in console
- [ ] EventBridge rules active
- [ ] Test alarm triggers correctly

```bash
# Validation commands
aws logs describe-log-groups --log-group-name-prefix /hyperion/fleet/
aws sns list-subscriptions-by-topic --topic-arn $(terraform output -raw sns_topic_arn)
aws cloudwatch describe-alarms --alarm-name-prefix hyperion-prod
aws events list-rules --name-prefix hyperion-prod

# Test alarm (simulate high CPU)
aws cloudwatch put-metric-data --namespace FleetManager --metric-name CPUUtilization --value 95
```

### Integration Testing

```bash
#!/bin/bash
# infrastructure/scripts/integration-test.sh

echo "=== Phase 1 Integration Test ==="

# Test 1: Networking connectivity
echo "Testing private subnet internet access via NAT..."
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-instances --query "AutoScalingInstances[0].InstanceId" --output text)
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Test-NetConnection -ComputerName www.amazon.com -Port 443"]'

# Test 2: Security - verify encryption
echo "Verifying EBS encryption..."
aws ec2 describe-volumes --filters "Name=attachment.instance-id,Values=$INSTANCE_ID" \
  --query "Volumes[*].[VolumeId,Encrypted,KmsKeyId]" --output table

# Test 3: Monitoring - check metrics
echo "Checking CloudWatch metrics..."
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Test 4: Logging - verify log streams
echo "Verifying log streams..."
aws logs describe-log-streams \
  --log-group-name /hyperion/fleet/system \
  --order-by LastEventTime \
  --descending --max-items 5

echo "=== Integration Test Complete ==="
```

## Troubleshooting Guide

### Common Integration Issues

#### Issue: Compute Module Can't Create Instances

**Symptoms:**
- Auto Scaling Group shows 0 instances
- EC2 console shows failed launch attempts

**Diagnosis:**
```bash
# Check ASG activities
aws autoscaling describe-scaling-activities --auto-scaling-group-name <asg-name> --max-records 5

# Check IAM instance profile
aws iam get-instance-profile --instance-profile-name <profile-name>
```

**Resolution:**
- Verify subnet IDs are correct and exist
- Ensure security group allows required egress traffic
- Check service quotas for EC2 instances
- Verify AMI exists in the region

#### Issue: CloudWatch Logs Not Appearing

**Symptoms:**
- Log groups exist but no log streams
- Metrics not showing in dashboard

**Diagnosis:**
```bash
# Connect to instance via SSM
aws ssm start-session --target <instance-id>

# Check CloudWatch Agent status
& 'C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1' -a query -m ec2 -c default -s

# Check agent logs
Get-Content 'C:\ProgramData\Amazon\AmazonCloudWatchAgent\Logs\amazon-cloudwatch-agent.log' -Tail 50
```

**Resolution:**
- Verify IAM role has CloudWatchAgentServerPolicy
- Check CloudWatch Agent configuration is valid JSON
- Ensure security group allows HTTPS egress to CloudWatch endpoints

#### Issue: SSM Session Manager Not Working

**Symptoms:**
- `aws ssm start-session` fails with "TargetNotConnected"

**Diagnosis:**
```bash
# Check SSM agent status
aws ssm describe-instance-information --filters "Key=InstanceIds,Values=<instance-id>"

# Verify instance has correct IAM profile
aws ec2 describe-instances --instance-ids <instance-id> --query 'Reservations[0].Instances[0].IamInstanceProfile'
```

**Resolution:**
- Verify instance profile has AmazonSSMManagedInstanceCore policy
- Ensure instance can reach SSM endpoints (check security groups, NACLs, NAT)
- Confirm SSM Agent is running on the instance
- Check VPC endpoints if using private subnets without NAT

#### Issue: KMS Encryption Failures

**Symptoms:**
- EBS volumes fail to attach
- Secrets Manager access denied

**Diagnosis:**
```bash
# Check KMS key policy
aws kms get-key-policy --key-id <key-id> --policy-name default

# Test decryption permission
aws kms decrypt --key-id <key-id> --ciphertext-blob fileb://test.encrypted
```

**Resolution:**
- Verify KMS key policy allows EC2 and Auto Scaling services
- Add service-linked roles if missing
- Check condition keys in IAM policies

## Best Practices

### Terraform State Management

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "hyperion-terraform-state-123456789012"
    key            = "prod/hyperion-fleet/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    dynamodb_table = "hyperion-terraform-locks"
  }
}
```

### Tagging Strategy

```hcl
locals {
  common_tags = {
    Environment = var.environment
    Project     = "hyperion-fleet-manager"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
    Compliance  = "sox"
    DataClass   = "internal"
  }
}
```

### Security Hardening Checklist

- [x] IMDSv2 required on all instances
- [x] All EBS volumes encrypted with KMS
- [x] Security groups follow least privilege
- [x] IAM roles use condition keys for service restrictions
- [x] VPC Flow Logs enabled
- [x] CloudWatch Logs encrypted
- [x] Secrets Manager for credentials
- [x] Security Hub and GuardDuty enabled
- [x] Network ACLs for defense in depth
- [x] Private subnets for workloads
- [x] No hardcoded credentials
- [x] SSM Session Manager for access (no RDP)

### Cost Optimization

1. **Development Environment:**
   - Single NAT Gateway
   - t3.small/medium instances
   - Reduced log retention
   - Disable GuardDuty

2. **Production Environment:**
   - Multi-AZ NAT (or NAT instances for very high traffic)
   - Spot instances for non-critical workloads
   - Reserved Instances for baseline capacity
   - Automated scaling policies
   - S3 lifecycle policies for logs

### Monitoring and Alerting

1. **Critical Alarms (Page oncall):**
   - Unhealthy host count > 0
   - Application error rate spike
   - Security event detected

2. **Warning Alarms (Email ops team):**
   - High CPU sustained > 80%
   - Low disk space < 15%
   - Instance state changes

3. **Info Notifications:**
   - Scaling activities
   - Scheduled backup completion
   - Weekly cost reports

## Deployment Sequence

### Initial Deployment

```bash
# 1. Deploy networking
cd infrastructure/modules/networking
terraform init
terraform plan
terraform apply

# 2. Deploy security (requires VPC ID from networking)
cd ../security
terraform init
terraform plan -var="vpc_id=<vpc-id>"
terraform apply

# 3. Deploy compute (requires networking and security outputs)
cd ../compute
terraform init
terraform plan
terraform apply

# 4. Deploy observability (requires compute instance IDs)
cd ../observability
terraform init
terraform plan
terraform apply

# 5. Verify integration
cd ../../scripts
./integration-test.sh
```

### Using Root Module (Recommended)

```bash
cd infrastructure/environments/prod
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Phase 2 Integration Preview

The Phase 1 architecture is designed to integrate seamlessly with Phase 2 components:

- **Application Load Balancer**: Will connect to compute module's ASG
- **RDS PostgreSQL**: Will use security module's KMS keys and security groups
- **Bastion Host**: Will reference networking module's public subnets
- **S3 Buckets**: Will use security module's KMS keys for encryption
- **Lambda Functions**: Will use security module's IAM roles

## Conclusion

The Phase 1 architecture provides a solid, production-ready foundation for Windows fleet management on AWS. All modules are designed to work together seamlessly while maintaining clear boundaries and interfaces. The architecture follows AWS Well-Architected Framework principles and implements security best practices throughout.

---

**Document Version:** 1.0
**Last Updated:** 2024-02-04
**Maintained By:** Platform Engineering Team
