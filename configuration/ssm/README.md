# AWS Systems Manager (SSM) Documents

This directory contains AWS SSM Automation Documents for the Hyperion Fleet Manager project. These documents provide automated configuration management, compliance scanning, patching, package management, and inventory collection for Windows server fleets.

## Directory Structure

```
ssm/
├── documents/
│   ├── ApplyDSCConfiguration.yml    # Apply PowerShell DSC configurations
│   ├── ComplianceScan.yml           # Run compliance scans and report results
│   ├── PatchInstance.yml            # Patch Windows instances with updates
│   ├── InstallChocolateyPackages.yml # Manage Chocolatey packages
│   └── CollectInventory.yml         # Collect system inventory
├── state-manager/
│   ├── DSCComplianceAssociation.yml # Hourly DSC compliance checks
│   └── InventoryAssociation.yml     # Daily inventory collection
└── README.md
```

## Documents Overview

### ApplyDSCConfiguration.yml

Applies PowerShell Desired State Configuration (DSC) to target Windows instances.

**Features:**
- Downloads DSC configurations from S3
- Installs required DSC modules from PSGallery or local cache
- Compiles configuration to MOF files
- Applies configuration using `Start-DscConfiguration`
- Verifies compliance with `Test-DscConfiguration`
- Reports results to CloudWatch metrics and logs

**Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| ConfigurationName | Yes | Name of the DSC configuration |
| Environment | Yes | Target environment (dev/staging/prod) |
| S3ConfigBucket | Yes | S3 bucket containing DSC configurations |
| TargetInstances | Yes | List of target instance IDs |
| RebootBehavior | No | How to handle reboots (RebootIfNeeded/NoReboot/ForceReboot) |

**Usage:**
```bash
aws ssm start-automation-execution \
  --document-name "HyperionFleet-ApplyDSCConfiguration" \
  --parameters "ConfigurationName=BaselineConfig,Environment=dev,S3ConfigBucket=my-config-bucket,TargetInstances=i-1234567890abcdef0"
```

### ComplianceScan.yml

Runs comprehensive compliance scans including DSC and CIS benchmark validation.

**Features:**
- Tests DSC configuration compliance
- Validates CIS benchmark controls (Level 1 and Level 2)
- Generates detailed JSON reports with remediation recommendations
- Uploads reports to S3
- Publishes compliance metrics to CloudWatch

**CIS Benchmark Categories:**
- Account Policies (password, lockout)
- Local Policies (user accounts, security options)
- Audit Policies
- Windows Firewall
- Windows Defender
- Network Security (SMBv1 disabled)

**Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| BucketName | Yes | S3 bucket for compliance reports |
| ReportPrefix | No | S3 key prefix (default: compliance-reports) |
| TargetInstances | Yes | List of target instance IDs |
| ScanType | No | Full/DSCOnly/CISOnly/SecurityOnly |
| CISBenchmarkLevel | No | Level1/Level2 |
| IncludeRemediationPlan | No | Include remediation recommendations |

### PatchInstance.yml

Patches Windows instances with comprehensive safety controls.

**Features:**
- Pre-patch health checks (disk space, services, pending reboots)
- EBS snapshot creation before patching
- Windows Update installation by classification
- Configurable reboot handling (immediate, scheduled, or suppressed)
- Post-patch validation
- Result reporting to CloudWatch

**Patch Classifications:**
- CriticalUpdates
- SecurityUpdates
- UpdateRollups
- Updates
- DefinitionUpdates
- Drivers
- FeaturePacks
- ServicePacks

**Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| TargetInstances | Yes | List of target instance IDs |
| PatchClassification | No | List of classifications to install |
| RebootOption | No | RebootIfNeeded/NoReboot/ScheduleReboot |
| CreateSnapshot | No | Create EBS snapshot before patching |
| DryRun | No | Perform dry run without installing |

### InstallChocolateyPackages.yml

Manages Chocolatey packages on Windows instances.

**Features:**
- Ensures Chocolatey is installed and configured
- Supports install, upgrade, and uninstall actions
- Custom package sources supported
- Prerelease package support
- Package verification
- Inventory of all installed packages

**Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| Packages | Yes | Comma-separated list of packages |
| Action | Yes | install/upgrade/uninstall |
| TargetInstances | Yes | List of target instance IDs |
| PackageSource | No | Custom Chocolatey source |
| AllowPrerelease | No | Allow prerelease versions |
| ForceReinstall | No | Force reinstallation |

**Usage:**
```bash
aws ssm start-automation-execution \
  --document-name "HyperionFleet-InstallChocolateyPackages" \
  --parameters "Packages=git,nodejs,python3,Action=install,TargetInstances=i-1234567890abcdef0"
```

### CollectInventory.yml

Collects comprehensive system inventory for fleet management.

**Inventory Types:**
- **System**: Hardware specs, OS info, disk, memory
- **Software**: Installed applications, hotfixes, Chocolatey packages
- **Features**: Windows Server features, optional features
- **Services**: All services with status and configuration
- **Network**: Network adapters, IP configuration
- **Security**: Windows Defender, Firewall, users, certificates

**Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| TargetInstances | Yes | List of target instance IDs |
| InventoryTypes | No | Types to collect (default: All) |
| UploadToS3 | No | Upload inventory to S3 |
| S3BucketName | No | S3 bucket for inventory storage |

## State Manager Associations

### DSCComplianceAssociation.yml

Automated hourly DSC compliance checks.

**Schedule:** Every hour (`rate(1 hour)`)

**Targets:** Instances with tags:
- `ManagedBy: hyperion-fleet-manager`
- `DSCEnabled: true`

### InventoryAssociation.yml

Automated daily inventory collection.

**Schedule:** Daily at 4 AM UTC (`cron(0 4 * * ? *)`)

**Targets:** Instances with tags:
- `ManagedBy: hyperion-fleet-manager`

## Deployment

### Register Documents

```bash
# Register all documents
for doc in documents/*.yml; do
  name=$(basename "$doc" .yml)
  aws ssm create-document \
    --name "HyperionFleet-$name" \
    --document-type Automation \
    --content "file://$doc" \
    --document-format YAML \
    --tags "Key=Project,Value=hyperion-fleet-manager"
done
```

### Create State Manager Associations

```bash
# DSC Compliance (hourly)
aws ssm create-association \
  --name "HyperionFleet-ApplyDSCConfiguration" \
  --association-name "HyperionFleet-DSCCompliance-Hourly" \
  --targets "Key=tag:ManagedBy,Values=hyperion-fleet-manager" \
  --schedule-expression "rate(1 hour)" \
  --parameters "ConfigurationName=BaselineConfig,Environment=dev,S3ConfigBucket=my-config-bucket,RebootBehavior=NoReboot"

# Inventory Collection (daily)
aws ssm create-association \
  --name "HyperionFleet-CollectInventory" \
  --association-name "HyperionFleet-Inventory-Daily" \
  --targets "Key=tag:ManagedBy,Values=hyperion-fleet-manager" \
  --schedule-expression "cron(0 4 * * ? *)" \
  --parameters "InventoryTypes=All,UploadToS3=true,S3BucketName=my-inventory-bucket"
```

## Required IAM Permissions

### Automation Role

The SSM Automation assume role needs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:SendCommand",
        "ssm:ListCommands",
        "ssm:ListCommandInvocations",
        "ssm:GetCommandInvocation",
        "ssm:PutInventory"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSnapshot",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshots",
        "ec2:CreateTags"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::config-bucket/*",
        "arn:aws:s3:::logs-bucket/*",
        "arn:aws:s3:::inventory-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "cloudwatch:PutMetricData",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/hyperion-fleet/*"
    }
  ]
}
```

### Instance Role

EC2 instances need:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:UpdateInstanceInformation",
        "ssm:PutInventory",
        "ssm:GetDocument",
        "ssm:DescribeDocument",
        "ssmmessages:*",
        "ec2messages:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::config-bucket/*",
        "arn:aws:s3:::logs-bucket/*",
        "arn:aws:s3:::inventory-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "cloudwatch:PutMetricData",
      "Resource": "*"
    }
  ]
}
```

## CloudWatch Metrics

All documents publish metrics to these namespaces:

| Namespace | Metrics |
|-----------|---------|
| HyperionFleet/DSC | CompliancePercentage, CompliantResources, NonCompliantResources, InDesiredState |
| HyperionFleet/Compliance | OverallCompliancePercentage, DSCCompliancePercentage, CISCompliancePercentage |
| HyperionFleet/Patching | UpdatesInstalled, UpdatesFailed, PatchSuccess |
| HyperionFleet/Chocolatey | PackagesProcessed, PackagesSuccessful, PackagesFailed, TotalInstalledPackages |
| HyperionFleet/Inventory | TotalApplications, TotalServices |

## Local Paths on Instances

All documents store data in a consistent location:

```
C:\HyperionFleet\
├── DSC\
│   ├── Configurations\
│   ├── Modules\
│   ├── MOF\
│   ├── LCM\
│   ├── Reports\
│   └── Logs\
├── Compliance\
│   ├── Reports\
│   └── Logs\
├── Patching\
│   ├── Reports\
│   └── Logs\
├── Chocolatey\
│   ├── Cache\
│   ├── Reports\
│   └── Logs\
└── Inventory\
    ├── Data\
    └── Logs\
```

## Best Practices

1. **Testing**: Always test documents in a dev environment first
2. **Tagging**: Use consistent tags for targeting instances
3. **Monitoring**: Set up CloudWatch alarms for compliance metrics
4. **Snapshots**: Always enable snapshots for patching in production
5. **Scheduling**: Use maintenance windows for disruptive operations
6. **Logging**: Enable S3 output locations for troubleshooting
7. **Concurrency**: Adjust MaxConcurrency based on fleet size

## Troubleshooting

### View Execution History

```bash
aws ssm describe-automation-executions \
  --filters "Key=DocumentNamePrefix,Values=HyperionFleet"
```

### Get Execution Details

```bash
aws ssm get-automation-execution \
  --automation-execution-id "execution-id"
```

### View Command Output

```bash
aws ssm get-command-invocation \
  --command-id "command-id" \
  --instance-id "i-1234567890abcdef0"
```

### Check Instance Logs

On the instance, check:
- `C:\HyperionFleet\*\Logs\*.log`
- Windows Event Log: Applications and Services > Microsoft > Windows > PowerShell
