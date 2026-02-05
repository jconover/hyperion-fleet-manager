# Security Module - Security Documentation

This document outlines the security controls, best practices, and compliance considerations for the Security Module.

## Table of Contents

- [Security Controls](#security-controls)
- [Threat Model](#threat-model)
- [Compliance Frameworks](#compliance-frameworks)
- [Incident Response](#incident-response)
- [Security Hardening](#security-hardening)
- [Monitoring & Alerting](#monitoring--alerting)
- [Vulnerability Management](#vulnerability-management)

## Security Controls

### Identity & Access Management

#### IAM Roles & Policies

**Control**: Least privilege access for Windows fleet instances

**Implementation**:
- EC2 instance role with minimum required permissions
- Conditional assume role policy with source account and ARN validation
- Service-specific IAM policies (SSM, CloudWatch, S3, Secrets Manager)
- Time-limited session duration (1 hour)

**Validation**:
```bash
# Review effective permissions
aws iam get-role --role-name <role-name>
aws iam list-attached-role-policies --role-name <role-name>
```

#### Multi-Factor Authentication

**Recommendation**: Enforce MFA for all human access to AWS console
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Deny",
    "Action": "*",
    "Resource": "*",
    "Condition": {
      "BoolIfExists": {"aws:MultiFactorAuthPresent": "false"}
    }
  }]
}
```

### Encryption

#### Data at Rest

**KMS Key Configuration**:
- Customer-managed keys for all encryption
- Automatic key rotation enabled (365 days)
- Service-specific keys (EBS, RDS, S3, Secrets Manager)
- Key policies restrict access via ViaService condition

**Protected Resources**:
- EBS volumes on Windows fleet instances
- RDS PostgreSQL database
- S3 bucket objects
- Secrets Manager secrets

**Key Policy Review**:
```bash
aws kms get-key-policy --key-id <key-id> --policy-name default
aws kms get-key-rotation-status --key-id <key-id>
```

#### Data in Transit

**Controls**:
- TLS 1.2+ for all HTTPS communication
- VPC endpoints for AWS services (SSM, Secrets Manager, CloudWatch)
- Application Load Balancer with HTTPS listener
- RDS with SSL/TLS enforcement

**Validation**:
```bash
# Verify RDS SSL enforcement
aws rds describe-db-instances --db-instance-identifier <db-id> \
  --query 'DBInstances[0].DBParameterGroups'
```

### Network Security

#### Security Group Architecture

**Windows Fleet Security Group**:
- Ingress: RDP (3389) from bastion only
- Ingress: Application port from ALB only
- Egress: HTTPS (443) for AWS services
- Egress: PostgreSQL (5432) to database only

**Load Balancer Security Group**:
- Ingress: HTTPS (443) from specified CIDR blocks
- Egress: Application port to Windows fleet only

**Database Security Group**:
- Ingress: PostgreSQL (5432) from Windows fleet only
- No egress rules (database doesn't initiate connections)

#### Defense in Depth

```
Internet → ALB (HTTPS) → Windows Fleet (App Port) → Database (PostgreSQL)
           ↓
         Bastion → Windows Fleet (RDP)
```

**Network Segmentation**:
1. Public subnet: Application Load Balancer
2. Private subnet: Windows fleet instances
3. Private subnet: Database instances (no NAT)

#### VPC Flow Logs

**Recommendation**: Enable VPC Flow Logs for network monitoring
```hcl
resource "aws_flow_log" "security_vpc" {
  vpc_id          = var.vpc_id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
}
```

### Secrets Management

#### Secrets Manager Configuration

**Controls**:
- KMS encryption with dedicated key
- 7-day recovery window for accidental deletion
- IAM policies restrict access to specific secrets
- Version tracking for audit trail

**Secret Rotation**:
```hcl
resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  secret_id           = module.security.db_credentials_secret_arn
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

**Access Auditing**:
```bash
# Monitor secret access
aws cloudtrail lookup-events --lookup-attributes \
  AttributeKey=ResourceName,AttributeValue=<secret-arn> \
  --max-results 50
```

## Threat Model

### Assets

1. **Windows Fleet Instances**: Compute resources running applications
2. **PostgreSQL Database**: Persistent data storage
3. **Application Load Balancer**: Public-facing entry point
4. **S3 Buckets**: Data storage and backups
5. **Secrets Manager**: Credentials and sensitive configuration

### Threat Actors

- **External Attackers**: Unauthorized access via internet
- **Compromised Credentials**: Stolen or leaked access keys
- **Insider Threats**: Malicious or negligent employees
- **Automated Attacks**: Botnets, scanners, malware

### Attack Vectors

#### 1. Unauthorized Network Access

**Threat**: Direct access to Windows fleet or database from internet

**Mitigations**:
- Security groups restrict RDP to bastion only
- Database in private subnet with no internet route
- Application traffic through ALB only
- GuardDuty monitors for unusual network patterns

#### 2. Privilege Escalation

**Threat**: Instance role permissions exploited for lateral movement

**Mitigations**:
- Least privilege IAM policies
- Conditional assume role policies
- Service-specific KMS key policies
- Session duration limits

#### 3. Data Exfiltration

**Threat**: Unauthorized data extraction from database or S3

**Mitigations**:
- Database security group restricts connections
- S3 access limited to specific buckets
- VPC Flow Logs monitor egress traffic
- GuardDuty detects unusual API calls

#### 4. Credential Theft

**Threat**: Secrets Manager credentials stolen or leaked

**Mitigations**:
- KMS encryption for secrets at rest
- IAM policies restrict secret access
- CloudTrail logs all secret retrieval
- Secret rotation (manual or automatic)

#### 5. Ransomware

**Threat**: EBS or RDS encryption with attacker-controlled keys

**Mitigations**:
- EBS snapshots with retention policy
- RDS automated backups and point-in-time recovery
- GuardDuty malware detection
- Separate backup KMS keys

## Compliance Frameworks

### AWS Foundational Security Best Practices

Enabled via Security Hub. Key controls:

- **IAM.1**: IAM policies attached only to groups or roles
- **EC2.2**: VPC default security group restricts all traffic
- **RDS.3**: RDS instances encrypted at rest
- **S3.4**: S3 buckets have server-side encryption
- **SecretsManager.1**: Secrets have automatic rotation
- **KMS.1**: IAM policies don't allow full KMS access

### CIS AWS Foundations Benchmark

Optional standard in Security Hub. Key recommendations:

**Identity and Access Management**:
- 1.12: Root account has no access keys
- 1.14: Root account has MFA enabled
- 1.16: IAM policies attached to groups or roles

**Logging**:
- 2.1: CloudTrail enabled in all regions
- 2.2: CloudTrail log file validation enabled
- 2.5: CloudTrail logs encrypted with KMS

**Monitoring**:
- 3.1: Log metric filter for unauthorized API calls
- 3.2: Log metric filter for console sign-in without MFA
- 3.3: Log metric filter for root account usage

**Networking**:
- 4.1: No security groups allow ingress from 0.0.0.0/0 to port 22
- 4.2: No security groups allow ingress from 0.0.0.0/0 to port 3389
- 4.3: VPC default security group restricts all traffic

### SOC 2 Type II

Security controls mapped to SOC 2 trust service criteria:

**CC6.1 - Logical and Physical Access Controls**:
- IAM roles with least privilege
- MFA enforcement
- Network segmentation via security groups

**CC6.6 - Encryption**:
- KMS encryption for data at rest
- TLS for data in transit
- Key rotation policies

**CC6.7 - System Development Lifecycle**:
- Infrastructure as Code (Terraform)
- Version control and peer review
- Automated security scanning (Checkov)

**CC7.2 - Monitoring**:
- CloudTrail for audit logging
- GuardDuty for threat detection
- Security Hub for compliance monitoring

## Incident Response

### Detection

**GuardDuty Findings**:
```bash
# List high-severity findings
aws guardduty list-findings --detector-id <detector-id> \
  --finding-criteria '{"Criterion":{"severity":{"Gte":7}}}'
```

**Security Hub Findings**:
```bash
# List critical security findings
aws securityhub get-findings --filters '{"SeverityLabel":[{"Value":"CRITICAL","Comparison":"EQUALS"}]}'
```

**CloudTrail Events**:
```bash
# Investigate suspicious API calls
aws cloudtrail lookup-events --lookup-attributes \
  AttributeKey=EventName,AttributeValue=AssumeRole \
  --start-time <timestamp>
```

### Response Procedures

#### 1. Instance Compromise

**Indicators**:
- GuardDuty finding: "UnauthorizedAccess:EC2/SSHBruteForce"
- Unusual CloudWatch metrics (CPU, network)
- Unexpected IAM role usage

**Actions**:
1. Isolate instance by updating security group:
   ```bash
   aws ec2 modify-instance-attribute --instance-id <id> \
     --groups <isolation-sg-id>
   ```
2. Create forensics snapshot:
   ```bash
   aws ec2 create-snapshot --volume-id <vol-id> \
     --description "Forensics-$(date +%Y%m%d-%H%M%S)"
   ```
3. Terminate instance if necessary
4. Review IAM role usage via CloudTrail
5. Rotate credentials in Secrets Manager

#### 2. Credential Exposure

**Indicators**:
- GuardDuty finding: "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration"
- Secrets Manager access from unknown IP
- Unusual AWS API calls

**Actions**:
1. Disable affected IAM role:
   ```bash
   aws iam attach-role-policy --role-name <role> \
     --policy-arn arn:aws:iam::aws:policy/AWSDenyAll
   ```
2. Rotate all secrets:
   ```bash
   aws secretsmanager rotate-secret --secret-id <secret-id>
   ```
3. Review CloudTrail for unauthorized actions
4. Update security groups if necessary
5. Create incident report

#### 3. Data Exfiltration

**Indicators**:
- GuardDuty finding: "Exfiltration:S3/AnomalousBehavior"
- Unusual S3 GetObject API calls
- High egress network traffic

**Actions**:
1. Block suspicious IP addresses:
   ```bash
   aws ec2 create-network-acl-entry --network-acl-id <nacl-id> \
     --rule-number 100 --protocol -1 --rule-action deny \
     --cidr-block <suspicious-ip>/32
   ```
2. Review S3 access logs
3. Enable S3 Object Lock for critical data
4. Conduct forensic analysis
5. Notify stakeholders

### Escalation

**Severity Levels**:
- **P1 (Critical)**: Active breach, data exfiltration in progress
- **P2 (High)**: Confirmed compromise, no active data loss
- **P3 (Medium)**: Suspicious activity, investigation required
- **P4 (Low)**: Policy violation, no security impact

**Escalation Path**:
1. On-call Security Engineer
2. Security Team Lead
3. CISO / CTO
4. Legal (if customer data affected)

## Security Hardening

### Windows Fleet Instances

**Operating System Hardening**:
```powershell
# Disable unnecessary services
Set-Service -Name RemoteRegistry -StartupType Disabled
Set-Service -Name WinRM -StartupType Manual

# Enable Windows Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Configure audit policies
auditpol /set /category:"Account Logon" /success:enable /failure:enable
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
```

**SSM Hardening**:
- Disable Run Command public access
- Enable Session Manager logging
- Use Session Manager instead of RDP when possible

**CloudWatch Agent Configuration**:
```json
{
  "metrics": {
    "namespace": "HyperionFleet/Windows",
    "metrics_collected": {
      "Memory": {
        "measurement": [{"name": "% Committed Bytes In Use", "unit": "Percent"}]
      },
      "Processor": {
        "measurement": [{"name": "% Processor Time", "unit": "Percent"}]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "windows_events": {
        "collect_list": [
          {"event_name": "System", "event_levels": ["ERROR", "WARNING"]},
          {"event_name": "Security", "event_levels": ["ERROR", "WARNING"]}
        ]
      }
    }
  }
}
```

### Database Hardening

**RDS Configuration**:
```hcl
resource "aws_db_instance" "main" {
  # ... other configuration

  # Security hardening
  storage_encrypted             = true
  kms_key_id                    = module.security.kms_key_rds_id
  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  deletion_protection           = true
  backup_retention_period       = 30

  # Network isolation
  publicly_accessible = false
  vpc_security_group_ids = [module.security.database_security_group_id]

  # Parameter group with SSL enforcement
  parameter_group_name = aws_db_parameter_group.postgres_ssl.name
}

resource "aws_db_parameter_group" "postgres_ssl" {
  name   = "postgres-ssl-required"
  family = "postgres15"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }
}
```

### Application Load Balancer

**SSL/TLS Configuration**:
```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
```

## Monitoring & Alerting

### CloudWatch Alarms

**KMS Key Usage**:
```hcl
resource "aws_cloudwatch_metric_alarm" "kms_key_disabled" {
  alarm_name          = "${var.environment}-kms-key-disabled"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "KeyState"
  namespace           = "AWS/KMS"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "KMS key is not enabled"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}
```

**Unauthorized API Calls**:
```hcl
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "UnauthorizedAPICalls"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\")}"

  metric_transformation {
    name      = "UnauthorizedAPICalls"
    namespace = "Security/CloudTrail"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "UnauthorizedAPICalls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "Security/CloudTrail"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}
```

### EventBridge Rules

**GuardDuty High Severity Findings**:
```hcl
resource "aws_cloudwatch_event_rule" "guardduty_high_severity" {
  name        = "guardduty-high-severity-findings"
  description = "Capture GuardDuty findings with high severity"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [7, 7.0, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 8, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9]
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_high_severity.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}
```

**Security Hub Critical Findings**:
```hcl
resource "aws_cloudwatch_event_rule" "securityhub_critical" {
  name        = "securityhub-critical-findings"
  description = "Capture Security Hub critical findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["CRITICAL"]
        }
      }
    }
  })
}
```

## Vulnerability Management

### Scanning Strategy

**Infrastructure Scanning**:
1. **Checkov**: Terraform code scanning (pre-commit)
2. **AWS Inspector**: EC2 instance vulnerability assessment
3. **Security Hub**: Aggregated security findings
4. **Prowler**: AWS CIS benchmark compliance

**Application Scanning**:
1. **Container images**: Trivy, Clair
2. **Dependencies**: Dependabot, Snyk
3. **SAST**: SonarQube, CodeQL
4. **DAST**: OWASP ZAP, Burp Suite

### Remediation Workflow

1. **Detection**: Vulnerability identified by scanner
2. **Triage**: Assess severity and exploitability
3. **Prioritization**: CVSS score + business impact
4. **Remediation**: Patch, upgrade, or mitigate
5. **Validation**: Re-scan to confirm fix
6. **Documentation**: Update runbooks and lessons learned

### Patch Management

**Windows Fleet Instances**:
```hcl
resource "aws_ssm_patch_baseline" "windows" {
  name             = "${var.environment}-windows-baseline"
  operating_system = "WINDOWS"

  approval_rule {
    approve_after_days = 7
    compliance_level   = "CRITICAL"

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["CriticalUpdates", "SecurityUpdates"]
    }

    patch_filter {
      key    = "MSRC_SEVERITY"
      values = ["Critical", "Important"]
    }
  }
}

resource "aws_ssm_maintenance_window" "patching" {
  name     = "${var.environment}-patching-window"
  schedule = "cron(0 2 ? * SUN *)"  # 2 AM every Sunday
  duration = 4
  cutoff   = 1
}
```

**RDS Maintenance**:
- Enable automatic minor version upgrades
- Schedule maintenance windows during low-traffic periods
- Test upgrades in non-production environments first

### Security Advisories

Subscribe to security advisories:
- AWS Security Bulletins
- Microsoft Security Response Center
- PostgreSQL Security Announcements
- CVE feeds for third-party libraries

## Contact

For security concerns or to report vulnerabilities:
- Security Team: security@example.com
- Emergency Hotline: +1-555-SECURITY
- Bug Bounty Program: https://bugcrowd.com/example

## Review Schedule

This security documentation should be reviewed:
- Quarterly: Security controls and configurations
- Annually: Threat model and compliance mappings
- After incidents: Update response procedures
- After major changes: Re-assess risk posture
