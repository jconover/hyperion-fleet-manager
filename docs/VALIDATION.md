# Hyperion Fleet Manager - Phase 1 Validation Checklist

## Overview

This document provides a comprehensive validation checklist for verifying the Phase 1 deployment of Hyperion Fleet Manager. Use this checklist to ensure all components are properly configured, integrated, and functioning as expected before moving to Phase 2 or production deployment.

## Pre-Deployment Validation

### Environment Setup

- [ ] **AWS CLI configured and authenticated**
  ```bash
  aws sts get-caller-identity
  # Should return account ID, user ARN, and user ID
  ```

- [ ] **Terraform version >= 1.5.0**
  ```bash
  terraform version
  # Required: Terraform v1.5.0 or higher
  ```

- [ ] **AWS account has sufficient service quotas**
  ```bash
  aws service-quotas get-service-quota --service-code vpc --quota-code L-F678F1CE
  aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A
  ```

- [ ] **Required IAM permissions available**
  - VPC management (create VPC, subnets, route tables)
  - EC2 management (launch instances, create security groups)
  - KMS key creation and management
  - IAM role and policy creation
  - CloudWatch Logs and metrics access
  - Systems Manager access

### Backend Configuration

- [ ] **S3 bucket created for Terraform state**
  ```bash
  aws s3 ls s3://hyperion-terraform-state-$(aws sts get-caller-identity --query Account --output text)
  ```

- [ ] **S3 bucket versioning enabled**
  ```bash
  aws s3api get-bucket-versioning --bucket hyperion-terraform-state-$(aws sts get-caller-identity --query Account --output text)
  # Should show: "Status": "Enabled"
  ```

- [ ] **DynamoDB table created for state locking**
  ```bash
  aws dynamodb describe-table --table-name hyperion-terraform-locks
  # Should show: "TableStatus": "ACTIVE"
  ```

### Code Quality

- [ ] **Terraform format check passed**
  ```bash
  terraform fmt -check -recursive
  # Should exit with code 0
  ```

- [ ] **Terraform validation successful**
  ```bash
  terraform validate
  # Should show: Success! The configuration is valid.
  ```

- [ ] **No sensitive data in code**
  - No hardcoded credentials
  - No API keys in plain text
  - No secrets in version control

## Module-Level Validation

### Networking Module

#### Configuration Validation

- [ ] **Variables properly defined**
  ```bash
  cd infrastructure/modules/networking
  terraform validate
  ```

- [ ] **Naming convention followed**
  - Resources use snake_case
  - All resources have descriptive names
  - Name prefix applied consistently

#### Deployment Validation

- [ ] **VPC created successfully**
  ```bash
  terraform output vpc_id
  aws ec2 describe-vpcs --vpc-ids $(terraform output -raw vpc_id)
  ```
  - Expected: VPC with correct CIDR block
  - Expected: DNS hostnames enabled
  - Expected: DNS support enabled

- [ ] **Internet Gateway attached**
  ```bash
  terraform output internet_gateway_id
  aws ec2 describe-internet-gateways --internet-gateway-ids $(terraform output -raw internet_gateway_id)
  ```
  - Expected: IGW attached to VPC
  - Expected: State is "available"

- [ ] **Public subnets created across AZs**
  ```bash
  terraform output public_subnet_ids
  aws ec2 describe-subnets --subnet-ids $(terraform output -json public_subnet_ids | jq -r '.[]')
  ```
  - Expected: Subnets in different availability zones
  - Expected: MapPublicIpOnLaunch enabled
  - Expected: Correct CIDR blocks

- [ ] **Private subnets created across AZs**
  ```bash
  terraform output private_subnet_ids
  aws ec2 describe-subnets --subnet-ids $(terraform output -json private_subnet_ids | jq -r '.[]')
  ```
  - Expected: Subnets in different availability zones
  - Expected: MapPublicIpOnLaunch disabled
  - Expected: Correct CIDR blocks

- [ ] **NAT Gateways operational**
  ```bash
  terraform output nat_gateway_ids
  aws ec2 describe-nat-gateways --nat-gateway-ids $(terraform output -json nat_gateway_ids | jq -r '.[]')
  ```
  - Expected: State is "available"
  - Expected: One per AZ (or single if cost-optimized)
  - Expected: Elastic IPs assigned

- [ ] **Route tables configured correctly**
  ```bash
  terraform output public_route_table_id
  terraform output private_route_table_ids
  aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
  ```
  - Expected: Public route table has IGW route (0.0.0.0/0 → IGW)
  - Expected: Private route tables have NAT routes (0.0.0.0/0 → NAT)
  - Expected: Route table associations correct

- [ ] **VPC Flow Logs active**
  ```bash
  terraform output flow_log_id
  aws ec2 describe-flow-logs --filter "Name=resource-id,Values=$(terraform output -raw vpc_id)"
  aws logs describe-log-groups --log-group-name-prefix /aws/vpc/
  ```
  - Expected: Flow log in "ACTIVE" state
  - Expected: Log group exists
  - Expected: Logs appearing within 10-15 minutes

- [ ] **Network ACLs configured**
  ```bash
  terraform output public_network_acl_id
  terraform output private_network_acl_id
  aws ec2 describe-network-acls --network-acl-ids $(terraform output -raw public_network_acl_id)
  ```
  - Expected: Public NACL allows HTTP/HTTPS/SSH inbound
  - Expected: Private NACL allows VPC traffic inbound
  - Expected: All outbound traffic allowed

#### Network Connectivity Test

- [ ] **Internet connectivity from public subnet**
  ```bash
  # Test from bastion host (Phase 2) or test instance
  ping -c 4 8.8.8.8
  curl -I https://www.amazon.com
  ```
  - Expected: Successful ping and HTTP response

- [ ] **Internet connectivity from private subnet via NAT**
  ```bash
  # Test from private instance via SSM
  Test-NetConnection -ComputerName www.amazon.com -Port 443
  ```
  - Expected: TcpTestSucceeded: True

### Security Module

#### Configuration Validation

- [ ] **Variables properly defined**
  ```bash
  cd infrastructure/modules/security
  terraform validate
  ```

- [ ] **VPC ID reference correct**
  - Verify VPC ID matches networking module output

#### Deployment Validation

- [ ] **KMS keys created with rotation**
  ```bash
  terraform output kms_key_ebs_id
  terraform output kms_key_rds_id
  terraform output kms_key_s3_id
  terraform output kms_key_secrets_manager_id

  for key_id in $(terraform output -json kms_key_ids | jq -r '.[]'); do
    aws kms describe-key --key-id $key_id
    aws kms get-key-rotation-status --key-id $key_id
  done
  ```
  - Expected: All keys in "Enabled" state
  - Expected: KeyRotationEnabled: true
  - Expected: Unique keys for each service

- [ ] **KMS key policies configured**
  ```bash
  aws kms get-key-policy --key-id $(terraform output -raw kms_key_ebs_id) --policy-name default
  ```
  - Expected: Root account has full access
  - Expected: Service principals (EC2, RDS, S3) have encrypt/decrypt
  - Expected: Condition keys restrict service usage

- [ ] **Security groups created**
  ```bash
  terraform output security_group_ids
  aws ec2 describe-security-groups --group-ids $(terraform output -json security_group_ids | jq -r '.[]')
  ```
  - Expected: Windows Fleet SG exists
  - Expected: Load Balancer SG exists
  - Expected: Database SG exists

- [ ] **Windows Fleet security group rules correct**
  ```bash
  aws ec2 describe-security-group-rules \
    --filters "Name=group-id,Values=$(terraform output -raw windows_fleet_security_group_id)"
  ```
  - Expected: Ingress from ALB SG on application port
  - Expected: Ingress from Bastion SG on 3389 (RDP)
  - Expected: Egress HTTPS (443) to 0.0.0.0/0
  - Expected: Egress to Database SG on 5432

- [ ] **IAM role created with correct trust policy**
  ```bash
  terraform output windows_fleet_role_name
  aws iam get-role --role-name $(terraform output -raw windows_fleet_role_name)
  ```
  - Expected: Principal is ec2.amazonaws.com
  - Expected: Condition keys enforce source account and ARN

- [ ] **IAM policies attached**
  ```bash
  aws iam list-attached-role-policies --role-name $(terraform output -raw windows_fleet_role_name)
  ```
  - Expected: AmazonSSMManagedInstanceCore attached
  - Expected: CloudWatchAgentServerPolicy attached
  - Expected: Custom S3 access policy attached
  - Expected: Custom Secrets Manager policy attached

- [ ] **IAM instance profile created**
  ```bash
  terraform output windows_fleet_instance_profile_name
  aws iam get-instance-profile --instance-profile-name $(terraform output -raw windows_fleet_instance_profile_name)
  ```
  - Expected: Role associated with profile

- [ ] **Secrets Manager secret created**
  ```bash
  terraform output db_credentials_secret_arn
  aws secretsmanager describe-secret --secret-id $(terraform output -raw db_credentials_secret_arn)
  aws secretsmanager get-secret-value --secret-id $(terraform output -raw db_credentials_secret_arn)
  ```
  - Expected: Secret encrypted with KMS
  - Expected: Recovery window configured
  - Expected: Secret contains username, password, engine, port

- [ ] **Security Hub enabled (if configured)**
  ```bash
  aws securityhub describe-hub
  ```
  - Expected: HubArn present
  - Expected: Standards subscribed (AWS Foundational, CIS)

- [ ] **GuardDuty enabled (if configured)**
  ```bash
  terraform output guardduty_detector_id
  aws guardduty get-detector --detector-id $(terraform output -raw guardduty_detector_id)
  ```
  - Expected: Status is "ENABLED"
  - Expected: DataSources configured

### Compute Module

#### Configuration Validation

- [ ] **Variables properly defined**
  ```bash
  cd infrastructure/modules/compute
  terraform validate
  ```

- [ ] **Subnet IDs reference private subnets**
  - Verify subnet IDs are from networking module private subnets

#### Deployment Validation

- [ ] **Launch template created**
  ```bash
  terraform output launch_template_id
  aws ec2 describe-launch-template-versions --launch-template-id $(terraform output -raw launch_template_id)
  ```
  - Expected: Latest version available
  - Expected: Windows Server 2022 AMI specified
  - Expected: IMDSv2 required
  - Expected: EBS encryption enabled

- [ ] **KMS key created for EBS**
  ```bash
  terraform output kms_key_arn
  aws kms describe-key --key-id $(terraform output -raw kms_key_id)
  ```
  - Expected: Key rotation enabled
  - Expected: Key state is "Enabled"

- [ ] **IAM role and instance profile created**
  ```bash
  terraform output instance_profile_name
  aws iam get-instance-profile --instance-profile-name $(terraform output -raw instance_profile_name)
  ```
  - Expected: Profile has role attached
  - Expected: Role has required policies

- [ ] **Security group created**
  ```bash
  terraform output security_group_id
  aws ec2 describe-security-groups --group-ids $(terraform output -raw security_group_id)
  ```
  - Expected: Egress all traffic allowed
  - Expected: Associated with VPC

- [ ] **Auto Scaling Group created**
  ```bash
  terraform output asg_name
  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $(terraform output -raw asg_name)
  ```
  - Expected: ASG in active state
  - Expected: Desired capacity matches configuration
  - Expected: Subnets are private subnets
  - Expected: Launch template referenced

- [ ] **Scaling policies configured**
  ```bash
  terraform output cpu_scaling_policy_name
  aws autoscaling describe-policies --auto-scaling-group-name $(terraform output -raw asg_name)
  ```
  - Expected: Target tracking policies created
  - Expected: Target values match configuration

- [ ] **CloudWatch alarms created**
  ```bash
  terraform output high_cpu_alarm_name
  aws cloudwatch describe-alarms --alarm-names $(terraform output -raw high_cpu_alarm_name)
  ```
  - Expected: Alarms in OK or ALARM state
  - Expected: Alarm actions configured

- [ ] **SNS topic created (if enabled)**
  ```bash
  terraform output sns_topic_arn
  aws sns get-topic-attributes --topic-arn $(terraform output -raw sns_topic_arn)
  ```
  - Expected: Topic exists
  - Expected: Subscriptions configured

#### Instance Validation

- [ ] **Instances launched successfully**
  ```bash
  aws autoscaling describe-auto-scaling-instances --query "AutoScalingInstances[?AutoScalingGroupName=='$(terraform output -raw asg_name)']"
  ```
  - Expected: Instances in "InService" state
  - Expected: Count matches desired capacity

- [ ] **Instance metadata configuration**
  ```bash
  INSTANCE_ID=$(aws autoscaling describe-auto-scaling-instances --query "AutoScalingInstances[?AutoScalingGroupName=='$(terraform output -raw asg_name)'].InstanceId | [0]" --output text)
  aws ec2 describe-instances --instance-ids $INSTANCE_ID
  ```
  - Expected: IMDSv2 required (HttpTokens: required)
  - Expected: Private IP assigned
  - Expected: No public IP (in private subnet)
  - Expected: IAM instance profile attached

- [ ] **EBS volumes encrypted**
  ```bash
  aws ec2 describe-volumes --filters "Name=attachment.instance-id,Values=$INSTANCE_ID"
  ```
  - Expected: Encrypted: true
  - Expected: KmsKeyId matches compute module KMS key

- [ ] **SSM agent connected**
  ```bash
  aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_ID"
  ```
  - Expected: PingStatus: Online
  - Expected: PlatformType: Windows

- [ ] **SSM Session Manager access working**
  ```bash
  aws ssm start-session --target $INSTANCE_ID
  # Should open interactive PowerShell session
  ```
  - Expected: Session established
  - Expected: PowerShell prompt appears

- [ ] **Bootstrap script executed**
  ```powershell
  # Inside SSM session
  Test-Path C:\ProgramData\Bootstrap\bootstrap.log
  Test-Path C:\ProgramData\Bootstrap\bootstrap.complete
  Get-Content C:\ProgramData\Bootstrap\bootstrap.log -Tail 50
  ```
  - Expected: bootstrap.log exists with complete log
  - Expected: bootstrap.complete marker exists
  - Expected: No errors in log

- [ ] **CloudWatch Agent installed and running**
  ```powershell
  Get-Service AmazonCloudWatchAgent
  Test-Path 'C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent.exe'
  & 'C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1' -a query -m ec2 -c default -s
  ```
  - Expected: Service Status: Running
  - Expected: Agent status: running

- [ ] **System configuration correct**
  ```powershell
  Get-TimeZone  # Should be UTC
  w32tm /query /status  # Should show AWS NTP
  Get-ExecutionPolicy  # Should be RemoteSigned
  Get-Disk | Where-Object PartitionStyle -eq "RAW"  # Should be empty (all disks initialized)
  ```
  - Expected: All configurations as per user_data.ps1 script

### Observability Module

#### Configuration Validation

- [ ] **Variables properly defined**
  ```bash
  cd infrastructure/modules/observability
  terraform validate
  ```

#### Deployment Validation

- [ ] **CloudWatch Log Groups created**
  ```bash
  terraform output log_group_names
  aws logs describe-log-groups --log-group-name-prefix /hyperion/fleet/
  ```
  - Expected: system, application, security log groups exist
  - Expected: Retention configured correctly
  - Expected: KMS encryption enabled

- [ ] **Log streams appearing**
  ```bash
  aws logs describe-log-streams \
    --log-group-name /hyperion/fleet/system \
    --order-by LastEventTime --descending --max-items 5
  ```
  - Expected: Log streams created (one per instance)
  - Expected: Recent log events present

- [ ] **SNS topic created**
  ```bash
  terraform output sns_topic_arn
  aws sns get-topic-attributes --topic-arn $(terraform output -raw sns_topic_arn)
  ```
  - Expected: Topic exists
  - Expected: KMS encryption enabled

- [ ] **SNS subscriptions configured**
  ```bash
  aws sns list-subscriptions-by-topic --topic-arn $(terraform output -raw sns_topic_arn)
  ```
  - Expected: Email subscriptions confirmed
  - Expected: Other subscriptions as configured

- [ ] **CloudWatch metric filters created**
  ```bash
  aws logs describe-metric-filters --log-group-name /hyperion/fleet/application
  ```
  - Expected: ErrorCount filter exists
  - Expected: SecurityEvents filter exists
  - Expected: Correct filter patterns

- [ ] **CloudWatch alarms created**
  ```bash
  terraform output alarm_names
  aws cloudwatch describe-alarms --alarm-name-prefix "$(terraform output -json alarm_names | jq -r 'to_entries[0].value')"
  ```
  - Expected: All configured alarms exist
  - Expected: Alarm actions point to SNS topic
  - Expected: Thresholds match configuration

- [ ] **CloudWatch dashboard created**
  ```bash
  terraform output dashboard_name
  aws cloudwatch get-dashboard --dashboard-name $(terraform output -raw dashboard_name)
  ```
  - Expected: Dashboard exists
  - Expected: Widgets configured for all key metrics

- [ ] **Dashboard accessible**
  ```bash
  terraform output dashboard_url
  # Open URL in browser
  ```
  - Expected: Dashboard loads in AWS Console
  - Expected: Widgets show data

- [ ] **EventBridge rules created**
  ```bash
  terraform output eventbridge_rule_names
  aws events list-rules --name-prefix "$(terraform output -json eventbridge_rule_names | jq -r 'to_entries[0].value')"
  ```
  - Expected: Instance state change rule exists
  - Expected: Scheduled health check rule exists
  - Expected: Backup trigger rule exists
  - Expected: Rules are enabled

- [ ] **EventBridge targets configured**
  ```bash
  RULE_NAME=$(terraform output -json eventbridge_rule_names | jq -r '.instance_state_change')
  aws events list-targets-by-rule --rule $RULE_NAME
  ```
  - Expected: SNS topic configured as target
  - Expected: Input transformation configured

- [ ] **X-Ray configured (if enabled)**
  ```bash
  terraform output xray_sampling_rule_id
  aws xray get-sampling-rules
  ```
  - Expected: Sampling rule created
  - Expected: X-Ray group configured

#### Monitoring Validation

- [ ] **Metrics flowing to CloudWatch**
  ```bash
  aws cloudwatch list-metrics --namespace FleetManager
  aws cloudwatch list-metrics --namespace AWS/EC2
  ```
  - Expected: Custom metrics present
  - Expected: Standard EC2 metrics present

- [ ] **Test metric alarm**
  ```bash
  # Put a test metric to trigger alarm
  aws cloudwatch put-metric-data \
    --namespace FleetManager \
    --metric-name TestMetric \
    --value 100 \
    --dimensions Environment=test

  # Check alarm state
  aws cloudwatch describe-alarms --alarm-names test-alarm-name --query 'MetricAlarms[0].StateValue'
  ```
  - Expected: Alarm transitions to ALARM state
  - Expected: SNS notification sent

- [ ] **Log insights queries working**
  ```bash
  # Query recent errors
  aws logs start-query \
    --log-group-name /hyperion/fleet/application \
    --start-time $(date -u -d '1 hour ago' +%s) \
    --end-time $(date -u +%s) \
    --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20'
  ```
  - Expected: Query starts successfully
  - Expected: Results show recent errors (if any)

## Integration Validation

### Cross-Module Integration

- [ ] **Networking → Security integration**
  - Security groups created in correct VPC
  - Security group rules reference correct subnets

- [ ] **Security → Compute integration**
  - Compute instances use security module's IAM roles (if configured)
  - Compute instances use security module's KMS keys (if configured)
  - Compute instances use security module's security groups (if configured)

- [ ] **Compute → Observability integration**
  - CloudWatch alarms monitor compute instances
  - Log groups receive instance logs
  - Metrics from compute instances visible

### End-to-End Validation

- [ ] **Complete request flow test**
  ```
  User → Application Load Balancer → Windows Fleet Instances → Database
                                    ↓
                            CloudWatch Logs & Metrics
  ```
  - Note: ALB and Database are Phase 2 components

- [ ] **Logging flow test**
  ```bash
  # Generate test log entry
  aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunPowerShellScript" \
    --parameters 'commands=["Write-EventLog -LogName Application -Source Application -EntryType Error -EventId 1 -Message \"Test error for validation\""]'

  # Wait 2-3 minutes, then check CloudWatch Logs
  aws logs tail /hyperion/fleet/application --follow --since 5m
  ```
  - Expected: Test log entry appears in CloudWatch

- [ ] **Monitoring flow test**
  ```bash
  # Trigger CPU alarm by generating high CPU load
  aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunPowerShellScript" \
    --parameters 'commands=["1..100 | ForEach-Object { Start-Job -ScriptBlock { while($true){} } }; Start-Sleep -Seconds 300; Get-Job | Stop-Job"]'

  # Check alarm status
  watch -n 10 'aws cloudwatch describe-alarms --alarm-name-prefix hyperion --state-value ALARM'
  ```
  - Expected: CPU alarm triggers
  - Expected: SNS notification sent
  - Expected: Email received (if configured)

- [ ] **Security flow test**
  ```bash
  # Verify instance can access S3 (with IAM role)
  aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunPowerShellScript" \
    --parameters 'commands=["aws s3 ls"]'

  # Verify instance can retrieve secret
  aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunPowerShellScript" \
    --parameters 'commands=["aws secretsmanager get-secret-value --secret-id $(terraform output -raw db_credentials_secret_arn)"]'
  ```
  - Expected: S3 list succeeds (if buckets configured)
  - Expected: Secret retrieval succeeds

## Security Validation

### Encryption Validation

- [ ] **EBS volumes encrypted at rest**
  ```bash
  aws ec2 describe-volumes --filters "Name=encrypted,Values=false"
  # Should return empty or only non-fleet volumes
  ```

- [ ] **CloudWatch Logs encrypted**
  ```bash
  aws logs describe-log-groups --query 'logGroups[?kmsKeyId==`null`]'
  # Should return empty for fleet log groups
  ```

- [ ] **SNS topic encrypted**
  ```bash
  aws sns get-topic-attributes --topic-arn $(terraform output -raw sns_topic_arn) --query 'Attributes.KmsMasterKeyId'
  # Should return KMS key ARN
  ```

- [ ] **Secrets Manager encrypted**
  ```bash
  aws secretsmanager describe-secret --secret-id $(terraform output -raw db_credentials_secret_arn) --query 'KmsKeyId'
  # Should return KMS key ARN
  ```

### Network Security Validation

- [ ] **No public IPs on private instances**
  ```bash
  aws ec2 describe-instances \
    --filters "Name=subnet-id,Values=$(terraform output -json private_subnet_ids | jq -r '.[]')" \
    --query 'Reservations[].Instances[?PublicIpAddress!=`null`]'
  # Should return empty
  ```

- [ ] **Security groups follow least privilege**
  ```bash
  # Check for overly permissive rules (0.0.0.0/0 ingress)
  aws ec2 describe-security-group-rules \
    --filters "Name=cidr-ipv4,Values=0.0.0.0/0" "Name=is-egress,Values=false"
  ```
  - Expected: Only ALB security group allows 0.0.0.0/0 ingress on 443

- [ ] **IMDSv2 enforced on all instances**
  ```bash
  aws ec2 describe-instances \
    --query 'Reservations[].Instances[?MetadataOptions.HttpTokens==`optional`].InstanceId'
  # Should return empty for fleet instances
  ```

- [ ] **VPC Flow Logs capturing traffic**
  ```bash
  aws logs tail /aws/vpc/$(terraform output -raw flow_log_cloudwatch_log_group_name) --follow --since 5m
  ```
  - Expected: Flow log entries appearing
  - Expected: Traffic patterns visible

### IAM Security Validation

- [ ] **No inline policies with broad permissions**
  ```bash
  aws iam list-role-policies --role-name $(terraform output -raw instance_role_name)
  # Review any inline policies for overly broad permissions
  ```

- [ ] **Service-linked roles use condition keys**
  ```bash
  aws iam get-role --role-name $(terraform output -raw windows_fleet_role_name) --query 'Role.AssumeRolePolicyDocument'
  ```
  - Expected: Condition keys present (StringEquals, ArnLike)

- [ ] **No wildcard resources in policies**
  ```bash
  aws iam list-attached-role-policies --role-name $(terraform output -raw instance_role_name)
  # Review policies for "Resource": "*"
  ```

### Compliance Validation

- [ ] **Security Hub findings reviewed**
  ```bash
  aws securityhub get-findings --max-items 20
  ```
  - Expected: Critical and high findings addressed
  - Expected: Documentation for accepted findings

- [ ] **GuardDuty findings reviewed**
  ```bash
  aws guardduty list-findings --detector-id $(terraform output -raw guardduty_detector_id)
  ```
  - Expected: No critical threats detected
  - Expected: Investigation plan for any findings

## Performance Validation

### Compute Performance

- [ ] **Instance types appropriate for workload**
  - Development: t3.small/medium
  - Production: t3.large, c5.xlarge, or larger

- [ ] **Auto Scaling working correctly**
  ```bash
  # Generate load to trigger scaling
  # Monitor scaling activities
  aws autoscaling describe-scaling-activities --auto-scaling-group-name $(terraform output -raw asg_name) --max-records 5
  ```
  - Expected: Scale-out triggered when CPU > 70%
  - Expected: Scale-in triggered when CPU < 70% sustained

- [ ] **Instance warmup time acceptable**
  - Expected: < 10 minutes from launch to InService
  - Expected: Bootstrap script completes in < 5 minutes

### Network Performance

- [ ] **NAT Gateway throughput sufficient**
  ```bash
  aws cloudwatch get-metric-statistics \
    --namespace AWS/NATGateway \
    --metric-name BytesOutToSource \
    --dimensions Name=NatGatewayId,Value=$(terraform output -json nat_gateway_ids | jq -r '.[0]') \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum
  ```
  - Expected: Throughput within NAT Gateway limits

- [ ] **VPC Flow Logs not causing performance issues**
  ```bash
  aws logs describe-log-streams --log-group-name $(terraform output -raw flow_log_cloudwatch_log_group_name) --max-items 10
  ```
  - Expected: Log streams active
  - Expected: No throttling errors

## Cost Validation

### Resource Cost Review

- [ ] **NAT Gateway costs acceptable**
  - Single NAT: ~$32/month + data processing
  - Multi-AZ NAT: ~$32/month per AZ + data processing
  - Consider NAT instances for very high traffic

- [ ] **CloudWatch Logs costs acceptable**
  - Log ingestion: $0.50/GB
  - Log storage: $0.03/GB/month
  - Review retention policies

- [ ] **EBS volume costs appropriate**
  - gp3: $0.08/GB/month
  - Snapshots: $0.05/GB/month
  - Review unused volumes

- [ ] **EC2 instance costs optimized**
  ```bash
  aws ce get-cost-and-usage \
    --time-period Start=2024-02-01,End=2024-02-04 \
    --granularity DAILY \
    --metrics BlendedCost \
    --group-by Type=SERVICE
  ```
  - Consider Reserved Instances for baseline capacity
  - Consider Spot Instances for flexible workloads

### Cost Optimization Opportunities

- [ ] **Development environment uses cost-optimized settings**
  - Single NAT Gateway
  - Smaller instance types
  - Shorter log retention
  - Reduced scaling limits

- [ ] **Tags configured for cost allocation**
  ```bash
  aws ec2 describe-tags --filters "Name=resource-type,Values=instance"
  ```
  - Expected: CostCenter tag present
  - Expected: Environment tag present
  - Expected: Project tag present

## Documentation Validation

### Code Documentation

- [ ] **README files present in all modules**
  - networking/README.md
  - security/README.md
  - compute/README.md
  - observability/README.md

- [ ] **README files are comprehensive**
  - Module description
  - Usage examples
  - Input variables documented
  - Output variables documented
  - Requirements listed

- [ ] **Variables have descriptions**
  ```bash
  grep -r "description =" infrastructure/modules/*/variables.tf
  # All variables should have descriptions
  ```

- [ ] **Outputs have descriptions**
  ```bash
  grep -r "description =" infrastructure/modules/*/outputs.tf
  # All outputs should have descriptions
  ```

### Architecture Documentation

- [ ] **INTEGRATION.md complete and accurate**
  - Architecture diagrams present
  - Data flow described
  - Module dependencies documented
  - Integration instructions provided

- [ ] **VALIDATION.md (this document) complete**
  - All validation steps documented
  - Test commands provided
  - Expected outputs specified

### Runbook Documentation

- [ ] **Common operations documented**
  - Deployment procedure
  - Update procedure
  - Rollback procedure
  - Disaster recovery procedure

- [ ] **Troubleshooting guide available**
  - Common issues documented
  - Resolution steps provided
  - Escalation paths defined

## Phase 1 Completion Criteria

### Critical Requirements (Must Have)

- [x] All Terraform modules deploy successfully
- [x] No Terraform validation errors
- [x] All resources created in correct VPC/subnets
- [x] Security groups configured with least privilege
- [x] All EBS volumes encrypted
- [x] IAM roles follow least privilege
- [x] SSM Session Manager access working
- [x] CloudWatch Logs receiving data
- [x] CloudWatch Alarms configured and tested
- [x] VPC Flow Logs active
- [x] Bootstrap script executes successfully
- [x] No hardcoded credentials in code

### Important Requirements (Should Have)

- [x] CloudWatch Dashboard created and functional
- [x] SNS notifications configured
- [x] EventBridge rules active
- [x] Auto Scaling policies working
- [x] All modules have comprehensive README
- [x] Integration documentation complete
- [x] Cost tags applied consistently
- [x] Security Hub enabled (optional)
- [x] GuardDuty enabled (optional)

### Nice to Have

- [ ] X-Ray tracing configured
- [ ] Custom CloudWatch dashboards
- [ ] Automated testing scripts
- [ ] CI/CD pipeline setup
- [ ] Cost reports automated

## Sign-Off Checklist

### Technical Lead Review

- [ ] All critical requirements met
- [ ] Architecture follows AWS best practices
- [ ] Security controls appropriate for workload
- [ ] Performance meets requirements
- [ ] Cost within budget
- [ ] Documentation complete and accurate
- [ ] Ready for Phase 2 development

### Security Review

- [ ] All encryption requirements met
- [ ] IAM roles follow least privilege
- [ ] Network isolation implemented
- [ ] Security Hub findings acceptable
- [ ] GuardDuty findings acceptable
- [ ] Compliance requirements satisfied

### Operations Review

- [ ] Monitoring and alerting adequate
- [ ] Runbooks available and tested
- [ ] Backup and recovery procedures documented
- [ ] Disaster recovery plan in place
- [ ] On-call procedures defined
- [ ] Training completed

## Next Steps

Upon successful validation:

1. **Production Deployment:**
   - Deploy to production environment
   - Update DNS records
   - Enable production monitoring
   - Begin operational support

2. **Phase 2 Planning:**
   - Application Load Balancer
   - RDS PostgreSQL database
   - Bastion host
   - S3 buckets for artifacts
   - Lambda functions for automation

3. **Continuous Improvement:**
   - Monitor metrics and logs
   - Optimize costs
   - Enhance security posture
   - Improve automation

---

**Document Version:** 1.0
**Last Updated:** 2024-02-04
**Maintained By:** Platform Engineering Team
**Review Frequency:** After each deployment
