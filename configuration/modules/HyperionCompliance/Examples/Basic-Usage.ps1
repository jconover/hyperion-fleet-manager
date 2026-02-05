#Requires -Version 7.4
#Requires -Modules HyperionCompliance

<#
.SYNOPSIS
    Basic usage examples for the HyperionCompliance module.

.DESCRIPTION
    This script demonstrates common usage patterns for the HyperionCompliance
    module including compliance checking, report generation, remediation,
    and S3 export.

.NOTES
    Run these examples interactively or adapt them for your automation needs.
    Some operations require Administrator privileges.
#>

#region Module Import
# Import the module (if not auto-loaded)
Import-Module HyperionCompliance -Force -ErrorAction Stop

Write-Host "HyperionCompliance module loaded successfully" -ForegroundColor Green
Write-Host "Module Version: $((Get-Module HyperionCompliance).Version)" -ForegroundColor Cyan
Write-Host ""
#endregion

#region Example 1: Basic Compliance Check
Write-Host "=" * 60 -ForegroundColor Yellow
Write-Host "Example 1: Basic CIS Compliance Check" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Yellow

# Run Level 1 compliance checks
Write-Host "Running Level 1 CIS compliance checks..."
$complianceResults = Test-CISCompliance -Level 1 -PassThru -Quiet

# Display summary
$passed = ($complianceResults | Where-Object { $_.Status -eq 'Pass' }).Count
$failed = ($complianceResults | Where-Object { $_.Status -eq 'Fail' }).Count
$total = $complianceResults.Count
$complianceRate = [math]::Round(($passed / $total) * 100, 1)

Write-Host ""
Write-Host "Results:" -ForegroundColor Cyan
Write-Host "  Total Controls: $total"
Write-Host "  Passed: $passed" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor Red
Write-Host "  Compliance Rate: $complianceRate%"
Write-Host ""

# Show failed controls
if ($failed -gt 0) {
    Write-Host "Failed Controls:" -ForegroundColor Red
    $complianceResults |
        Where-Object { $_.Status -eq 'Fail' } |
        Select-Object ControlId, Title, Impact |
        Format-Table -AutoSize
}
#endregion

#region Example 2: Filter by Category
Write-Host "=" * 60 -ForegroundColor Yellow
Write-Host "Example 2: Filter Compliance Check by Category" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Yellow

# Check only Account Policies
Write-Host "Checking Account Policies only..."
$accountPolicyResults = Test-CISCompliance -Level 1 -Category 'Account Policies' -PassThru -Quiet

Write-Host "Account Policy Results:"
$accountPolicyResults | Format-Table ControlId, Title, Status, Impact -AutoSize
#endregion

#region Example 3: Check Specific Controls
Write-Host "=" * 60 -ForegroundColor Yellow
Write-Host "Example 3: Check Specific Controls" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Yellow

# Check specific control IDs
$controlsToCheck = @('CIS-1.1.1', 'CIS-1.1.4', 'CIS-1.2.2')
Write-Host "Checking controls: $($controlsToCheck -join ', ')..."

$specificResults = Test-CISCompliance -ControlId $controlsToCheck -PassThru -Quiet

$specificResults | Format-Table ControlId, Title, ExpectedValue, ActualValue, Status -AutoSize
#endregion

#region Example 4: Generate HTML Report
Write-Host "=" * 60 -ForegroundColor Yellow
Write-Host "Example 4: Generate HTML Compliance Report" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Yellow

# Generate HTML report
$reportPath = Join-Path -Path $env:TEMP -ChildPath "compliance-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"

Write-Host "Generating HTML report..."
$reportMetadata = Get-ComplianceReport -ComplianceResults $complianceResults `
    -Format HTML `
    -OutputPath $reportPath `
    -IncludeRemediation `
    -Title 'CIS Compliance Assessment'

Write-Host "Report generated successfully!" -ForegroundColor Green
Write-Host "  Path: $($reportMetadata.OutputPath)"
Write-Host "  Format: $($reportMetadata.Format)"
Write-Host "  Findings: $($reportMetadata.TotalFindings)"
Write-Host "  Duration: $([math]::Round($reportMetadata.Duration.TotalSeconds, 2)) seconds"
Write-Host ""

# Open report in default browser (optional)
# Start-Process $reportMetadata.OutputPath
#endregion

#region Example 5: Generate JSON Report
Write-Host "=" * 60 -ForegroundColor Yellow
Write-Host "Example 5: Generate JSON Compliance Report" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Yellow

$jsonReportPath = Join-Path -Path $env:TEMP -ChildPath "compliance-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

Write-Host "Generating JSON report..."
$jsonReport = Get-ComplianceReport -ComplianceResults $complianceResults `
    -Format JSON `
    -OutputPath $jsonReportPath `
    -IncludePassedControls

Write-Host "JSON report saved to: $jsonReportPath" -ForegroundColor Green
Write-Host ""
#endregion

#region Example 6: Preview Remediation (WhatIf)
Write-Host "=" * 60 -ForegroundColor Yellow
Write-Host "Example 6: Preview Remediation Actions (WhatIf)" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Yellow

Write-Host "Previewing remediation actions (no changes will be made)..."
Write-Host ""

# Preview what would be remediated
$failedControls = $complianceResults | Where-Object { $_.Status -eq 'Fail' }

if ($failedControls.Count -gt 0) {
    # Use WhatIf to preview without making changes
    $remediationPreview = Invoke-ComplianceRemediation `
        -ComplianceResults $failedControls `
        -ExcludeHighImpact `
        -WhatIf

    Write-Host ""
    Write-Host "Remediation Preview Results:" -ForegroundColor Cyan
    $remediationPreview | Format-Table ControlId, Title, Status, Message -AutoSize
}
else {
    Write-Host "No failed controls to remediate!" -ForegroundColor Green
}
#endregion

#region Example 7: Check DSC Compliance
Write-Host "=" * 60 -ForegroundColor Yellow
Write-Host "Example 7: Check DSC Compliance Status" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Yellow

Write-Host "Checking DSC compliance status..."

# Check DSC status (may return NotApplicable on non-Windows or if no DSC config)
$dscStatus = Get-DSCComplianceStatus

Write-Host ""
Write-Host "DSC Status:" -ForegroundColor Cyan
$dscStatus | Format-List ComputerName, Status, InDesiredState, ConfigurationName, CompliancePercentage
#endregion

#region Example 8: Export to S3 (Simulated)
Write-Host "=" * 60 -ForegroundColor Yellow
Write-Host "Example 8: Export to S3 (Simulated with WhatIf)" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Yellow

Write-Host "Simulating S3 export (requires AWS credentials)..."
Write-Host ""

# Note: This will fail without proper AWS credentials, but demonstrates the pattern
try {
    # Check if AWS module is available
    if (Get-Module -Name 'AWS.Tools.S3' -ListAvailable) {
        # Use WhatIf to simulate
        Export-ComplianceToS3 `
            -BucketName 'example-compliance-bucket' `
            -ReportData $jsonReport `
            -ReportType 'Compliance' `
            -KeyPrefix 'compliance-reports/production' `
            -Tags @{ Environment = 'Production'; Team = 'Security' } `
            -WhatIf
    }
    else {
        Write-Host "AWS.Tools.S3 module not installed. Skipping S3 export example." -ForegroundColor Yellow
        Write-Host "Install with: Install-Module AWS.Tools.S3 -Scope CurrentUser" -ForegroundColor Gray
    }
}
catch {
    Write-Host "S3 export simulation: $_" -ForegroundColor Yellow
}
#endregion

#region Example 9: Pipeline Usage
Write-Host "=" * 60 -ForegroundColor Yellow
Write-Host "Example 9: Pipeline Usage Pattern" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Yellow

Write-Host "Demonstrating pipeline patterns..."
Write-Host ""

# Pattern 1: Check -> Filter -> Report
Write-Host "Pattern 1: Check high-impact failures only"
$highImpactFailures = Test-CISCompliance -Level 1 -PassThru -Quiet |
    Where-Object { $_.Status -eq 'Fail' -and $_.Impact -eq 'High' }

Write-Host "  High-impact failures: $($highImpactFailures.Count)"
Write-Host ""

# Pattern 2: Check -> Group -> Summarize
Write-Host "Pattern 2: Group results by category"
Test-CISCompliance -Level 1 -PassThru -Quiet |
    Group-Object -Property Category |
    Select-Object Name, Count, @{N='Failed';E={($_.Group | Where-Object Status -eq 'Fail').Count}} |
    Format-Table -AutoSize

# Pattern 3: Check -> Export to multiple formats
Write-Host "Pattern 3: Export to multiple formats"
$results = Test-CISCompliance -Level 1 -PassThru -Quiet

$csvPath = Join-Path -Path $env:TEMP -ChildPath "compliance-$(Get-Date -Format 'yyyyMMdd').csv"
Get-ComplianceReport -ComplianceResults $results -Format CSV -OutputPath $csvPath | Out-Null
Write-Host "  CSV exported to: $csvPath"
#endregion

#region Summary
Write-Host ""
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "Examples Complete!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

Write-Host ""
Write-Host "Generated Files:" -ForegroundColor Cyan
Write-Host "  HTML Report: $reportPath"
Write-Host "  JSON Report: $jsonReportPath"
Write-Host "  CSV Report:  $csvPath"

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Review the HTML report in a browser"
Write-Host "  2. Use -Confirm or -Force for actual remediation"
Write-Host "  3. Configure AWS credentials for S3 export"
Write-Host "  4. Schedule regular compliance checks with Task Scheduler or cron"
Write-Host ""
#endregion
