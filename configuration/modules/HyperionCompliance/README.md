# HyperionCompliance PowerShell Module

CIS compliance benchmarking, remediation, and reporting module for Hyperion Fleet Manager.

## Overview

HyperionCompliance provides comprehensive CIS (Center for Internet Security) benchmark compliance checking, automated remediation, and reporting capabilities for Windows Server environments. The module integrates with AWS services for centralized compliance tracking and audit trails.

## Features

- **CIS Benchmark Checking**: Run Level 1 and Level 2 CIS benchmark checks against Windows Server systems
- **Multiple Report Formats**: Generate compliance reports in JSON, HTML, or CSV formats
- **Automated Remediation**: Auto-remediate compliance findings with WhatIf support
- **S3 Integration**: Upload compliance reports to AWS S3 for centralized storage
- **DSC Compliance**: Check Desired State Configuration compliance status
- **Comprehensive Logging**: Structured logging for all compliance operations

## Requirements

- PowerShell 7.4 or later
- Windows Server 2019/2022 (for compliance checks)
- AWS.Tools.SimpleSystemsManagement module
- AWS.Tools.S3 module
- Administrator privileges (for remediation operations)

## Installation

```powershell
# Clone or copy the module to a PowerShell module path
Copy-Item -Path ./HyperionCompliance -Destination $env:PSModulePath.Split(';')[0] -Recurse

# Import the module
Import-Module HyperionCompliance

# Verify installation
Get-Module HyperionCompliance
```

## Quick Start

### Run CIS Compliance Check

```powershell
# Run Level 1 checks and show only failures
Test-CISCompliance

# Run Level 1 checks and return all results
Test-CISCompliance -Level 1 -PassThru

# Run Level 2 checks (includes Level 1)
Test-CISCompliance -Level 2 -PassThru

# Check specific controls
Test-CISCompliance -ControlId 'CIS-1.1.1', 'CIS-1.1.2' -PassThru

# Filter by category
Test-CISCompliance -Category 'Account Policies' -PassThru

# Export results to file
Test-CISCompliance -Level 1 -OutputPath './compliance-results.json' -PassThru
```

### Generate Compliance Report

```powershell
# Generate JSON report
Get-ComplianceReport -Format JSON -OutputPath './report.json'

# Generate HTML report
Get-ComplianceReport -Format HTML -OutputPath './report.html'

# Generate CSV report with all controls
Get-ComplianceReport -Format CSV -IncludePassedControls

# Include remediation guidance
Get-ComplianceReport -Format HTML -IncludeRemediation

# Pipeline from compliance check
$results = Test-CISCompliance -Level 1 -PassThru
Get-ComplianceReport -ComplianceResults $results -Format HTML
```

### Auto-Remediate Compliance Issues

```powershell
# Preview remediations (WhatIf)
Invoke-ComplianceRemediation -WhatIf

# Remediate specific controls
Invoke-ComplianceRemediation -FindingIds 'CIS-1.1.1', 'CIS-1.1.2'

# Remediate with confirmation prompts
Invoke-ComplianceRemediation -Confirm

# Exclude high-impact controls
Invoke-ComplianceRemediation -ExcludeHighImpact

# Force remediation without prompts
Invoke-ComplianceRemediation -Force

# Pipeline from compliance check
Test-CISCompliance -Level 1 -PassThru |
    Where-Object { $_.Status -eq 'Fail' } |
    Invoke-ComplianceRemediation -WhatIf
```

### Export to S3

```powershell
# Upload compliance report to S3
$report = Get-ComplianceReport -Format JSON
Export-ComplianceToS3 -BucketName 'my-compliance-bucket' -ReportData $report -ReportType 'Compliance'

# Upload with KMS encryption
Export-ComplianceToS3 -BucketName 'secure-bucket' `
    -ReportData './report.json' `
    -ReportType 'Audit' `
    -ServerSideEncryption 'aws:kms' `
    -KmsKeyId 'alias/my-key'

# Add custom tags
Export-ComplianceToS3 -BucketName 'audit-bucket' `
    -ReportData $report `
    -ReportType 'Compliance' `
    -Tags @{ CostCenter = 'Security'; Team = 'DevOps' }
```

### Check DSC Compliance

```powershell
# Check local DSC compliance
Get-DSCComplianceStatus

# Get detailed resource-level information
Get-DSCComplianceStatus -Detailed

# Check remote computers
Get-DSCComplianceStatus -ComputerName 'Server01', 'Server02' -Credential $cred

# Export DSC status to file
Get-DSCComplianceStatus -Detailed -OutputPath './dsc-status.json'
```

## Public Functions

### Test-CISCompliance

Runs CIS benchmark compliance checks against the local system.

| Parameter | Type | Description |
|-----------|------|-------------|
| Level | Int | CIS benchmark level (1 or 2). Default: 1 |
| Category | String | Filter by category |
| ControlId | String[] | Specific control IDs to check |
| OutputPath | String | Path to save results |
| IncludeLevel2 | Switch | Include Level 2 when Level 1 is specified |
| PassThru | Switch | Return all results (not just failures) |
| Quiet | Switch | Suppress console output |

### Get-ComplianceReport

Generates compliance reports from CIS check results.

| Parameter | Type | Description |
|-----------|------|-------------|
| ComplianceResults | PSObject[] | Results from Test-CISCompliance |
| Format | String | Output format: JSON, HTML, CSV. Default: JSON |
| OutputPath | String | Path to save report |
| IncludeRemediation | Switch | Include remediation guidance |
| IncludePassedControls | Switch | Include passed controls in report |
| Title | String | Custom report title |

### Invoke-ComplianceRemediation

Automatically remediates CIS compliance findings.

| Parameter | Type | Description |
|-----------|------|-------------|
| FindingIds | String[] | Specific control IDs to remediate |
| ComplianceResults | PSObject[] | Results to use for remediation |
| ExcludeHighImpact | Switch | Skip high-impact controls |
| Force | Switch | Skip confirmation prompts |
| WhatIf | Switch | Preview changes without applying |
| Confirm | Switch | Prompt before each remediation |

### Export-ComplianceToS3

Uploads compliance reports to AWS S3.

| Parameter | Type | Description |
|-----------|------|-------------|
| BucketName | String | Target S3 bucket name (required) |
| ReportData | Object | Report data or file path (required) |
| ReportType | String | Type: Compliance, Remediation, Audit, Summary |
| KeyPrefix | String | S3 key prefix. Default: 'compliance-reports' |
| ServerSideEncryption | String | Encryption: None, AES256, aws:kms |
| KmsKeyId | String | KMS key ID for encryption |
| Tags | Hashtable | Additional S3 object tags |

### Get-DSCComplianceStatus

Retrieves DSC configuration compliance status.

| Parameter | Type | Description |
|-----------|------|-------------|
| Detailed | Switch | Include resource-level details |
| ComputerName | String[] | Remote computer names |
| Credential | PSCredential | Credentials for remote access |
| OutputPath | String | Path to save results |

## CIS Benchmark Controls

The module includes definitions for CIS Microsoft Windows Server 2022 Benchmark controls:

### Level 1 Controls (Recommended for all systems)
- Account Policies (Password Policy, Account Lockout)
- Local Policies (Audit Policy, Security Options)
- Windows Firewall configuration

### Level 2 Controls (Enhanced security)
- Advanced security options
- Network configuration hardening
- Legacy protocol restrictions

### Categories
- **Account Policies**: Password and account lockout settings
- **Local Policies**: Audit, user rights, and security options
- **Administrative Templates**: Registry-based policy settings
- **Advanced Audit Policy**: Fine-grained audit configuration

## Logging

All operations are logged to structured JSON log files:

- Main log: `$env:TEMP/HyperionCompliance.log`
- Remediation log: `$env:TEMP/HyperionCompliance-remediation.log`

Log entries include:
- Timestamp (ISO 8601)
- Log level (Verbose, Information, Warning, Error, Critical)
- Operation type (Check, Remediation, Report, Export)
- Context information (control IDs, categories, etc.)

## Testing

Run Pester tests:

```powershell
# Run all tests
Invoke-Pester -Path ./Tests/HyperionCompliance.Tests.ps1 -Output Detailed

# Run with code coverage
Invoke-Pester -Path ./Tests -CodeCoverage ./Public/*.ps1,./Private/*.ps1

# Run only integration tests
Invoke-Pester -Path ./Tests -Tag 'Integration'
```

## Configuration

Module configuration is available via the `$ModuleConfig` variable:

```powershell
# View current configuration
$ModuleConfig

# Configuration options:
# - DefaultRegion: AWS region (default: us-east-1)
# - LogLevel: Minimum log level (default: Information)
# - DefaultCISLevel: Default CIS level (default: 1)
# - RemediationLogPath: Path for remediation logs
# - ReportOutputPath: Default report output directory
# - MaxConcurrentChecks: Parallel check limit
# - ComplianceThreshold: Minimum compliance percentage
```

## Security Considerations

- **Elevated Privileges**: Remediation requires Administrator rights
- **Audit Trail**: All remediations are logged for audit purposes
- **WhatIf Mode**: Always test with `-WhatIf` before applying changes
- **High-Impact Controls**: Use `-ExcludeHighImpact` for safer automation
- **Secrets**: Never store credentials in scripts; use AWS IAM roles or Secrets Manager

## Troubleshooting

### Common Issues

1. **Module not loading**
   - Ensure PowerShell 7.4+ is installed
   - Check module path with `$env:PSModulePath`

2. **Compliance checks failing**
   - Run PowerShell as Administrator
   - Verify Windows Server OS version

3. **S3 export errors**
   - Verify AWS credentials are configured
   - Check bucket permissions (s3:PutObject, s3:PutObjectTagging)
   - Ensure AWS.Tools.S3 module is installed

4. **DSC status unavailable**
   - Ensure DSC is configured on the system
   - Check WinRM for remote systems

### Debug Mode

Enable verbose logging:

```powershell
$VerbosePreference = 'Continue'
Test-CISCompliance -Level 1 -PassThru -Verbose
```

## Contributing

See the main project CONTRIBUTING.md for guidelines.

## License

MIT License - See LICENSE file in the project root.

## Version History

### 1.0.0 (2026-02-05)
- Initial release
- CIS benchmark compliance checking (Level 1 and 2)
- Report generation (JSON, HTML, CSV)
- Automated remediation with WhatIf support
- S3 export with encryption support
- DSC compliance status checking
