function Get-ComplianceReport {
    <#
    .SYNOPSIS
        Generates a comprehensive compliance report from CIS check results.

    .DESCRIPTION
        Creates formatted compliance reports from Test-CISCompliance results.
        Supports multiple output formats including JSON, HTML, and CSV.
        Reports include summary statistics, detailed findings, and remediation guidance.

    .PARAMETER ComplianceResults
        Compliance check results from Test-CISCompliance. If not provided,
        runs Test-CISCompliance to generate fresh results.

    .PARAMETER Format
        Output format for the report. Valid values: JSON, HTML, CSV.
        Default: JSON

    .PARAMETER OutputPath
        Path to save the report file. If not specified, outputs to the default
        report directory with a timestamp-based filename.

    .PARAMETER IncludeRemediation
        Include detailed remediation guidance in the report.

    .PARAMETER IncludePassedControls
        Include passed controls in the report. By default, only failed controls
        are included to reduce report size.

    .PARAMETER Title
        Custom title for the report. Defaults to 'CIS Compliance Report'.

    .PARAMETER Level
        If generating new compliance results, specifies the CIS level to check.

    .PARAMETER Category
        If generating new compliance results, filters by category.

    .EXAMPLE
        Get-ComplianceReport -Format HTML -OutputPath 'C:\Reports\compliance.html'
        Generates an HTML compliance report.

    .EXAMPLE
        $results = Test-CISCompliance -Level 1 -PassThru
        Get-ComplianceReport -ComplianceResults $results -Format JSON

    .EXAMPLE
        Get-ComplianceReport -Format CSV -IncludePassedControls -IncludeRemediation

    .EXAMPLE
        Get-ComplianceReport -Format HTML -Title 'Production Server Compliance' -Level 2

    .OUTPUTS
        PSCustomObject with report metadata and file path.

    .NOTES
        HTML reports include CSS styling for professional presentation.
        JSON reports can be imported into other tools for further analysis.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [PSCustomObject[]]$ComplianceResults,

        [Parameter()]
        [ValidateSet('JSON', 'HTML', 'CSV')]
        [string]$Format = 'JSON',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [switch]$IncludeRemediation,

        [Parameter()]
        [switch]$IncludePassedControls,

        [Parameter()]
        [string]$Title = 'CIS Compliance Report',

        [Parameter()]
        [ValidateSet(1, 2)]
        [int]$Level = 1,

        [Parameter()]
        [ValidateSet('Account Policies', 'Local Policies', 'Administrative Templates', 'Advanced Audit Policy')]
        [string]$Category
    )

    begin {
        Write-ComplianceLog -Message "Generating compliance report" -Level 'Information' -Operation 'Report' -Context @{
            Format = $Format
        }

        $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()
        $startTime = Get-Date
    }

    process {
        # Collect pipeline results
        if ($ComplianceResults) {
            foreach ($result in $ComplianceResults) {
                $allResults.Add($result)
            }
        }
    }

    end {
        try {
            # If no results provided, run compliance check
            if ($allResults.Count -eq 0) {
                Write-ComplianceLog -Message "No results provided, running compliance check" -Level 'Information' -Operation 'Report'

                $checkParams = @{
                    Level    = $Level
                    PassThru = $true
                    Quiet    = $true
                }
                if ($Category) {
                    $checkParams['Category'] = $Category
                }

                $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()
                $checkResults = Test-CISCompliance @checkParams
                foreach ($result in $checkResults) {
                    $allResults.Add($result)
                }
            }

            # Filter results if not including passed
            $reportResults = if ($IncludePassedControls) {
                $allResults
            }
            else {
                $allResults | Where-Object { $_.Status -ne 'Pass' }
            }

            # Calculate summary statistics
            $summary = @{
                TotalControls    = $allResults.Count
                PassedControls   = ($allResults | Where-Object { $_.Status -eq 'Pass' }).Count
                FailedControls   = ($allResults | Where-Object { $_.Status -eq 'Fail' }).Count
                ErrorControls    = ($allResults | Where-Object { $_.Status -eq 'Error' }).Count
                SkippedControls  = ($allResults | Where-Object { $_.Status -eq 'Skipped' }).Count
                ComplianceRate   = 0
                ByCategory       = @{}
                ByLevel          = @{}
                ByImpact         = @{}
            }

            if ($summary.TotalControls -gt 0) {
                $summary.ComplianceRate = [math]::Round(($summary.PassedControls / $summary.TotalControls) * 100, 2)
            }

            # Group by category
            $allResults | Group-Object -Property Category | ForEach-Object {
                $catPassed = ($_.Group | Where-Object { $_.Status -eq 'Pass' }).Count
                $catTotal = $_.Group.Count
                $summary.ByCategory[$_.Name] = @{
                    Total          = $catTotal
                    Passed         = $catPassed
                    Failed         = ($_.Group | Where-Object { $_.Status -eq 'Fail' }).Count
                    ComplianceRate = $catTotal -gt 0 ? [math]::Round(($catPassed / $catTotal) * 100, 2) : 0
                }
            }

            # Group by level
            $allResults | Group-Object -Property Level | ForEach-Object {
                $lvlPassed = ($_.Group | Where-Object { $_.Status -eq 'Pass' }).Count
                $lvlTotal = $_.Group.Count
                $summary.ByLevel["Level $($_.Name)"] = @{
                    Total          = $lvlTotal
                    Passed         = $lvlPassed
                    Failed         = ($_.Group | Where-Object { $_.Status -eq 'Fail' }).Count
                    ComplianceRate = $lvlTotal -gt 0 ? [math]::Round(($lvlPassed / $lvlTotal) * 100, 2) : 0
                }
            }

            # Group by impact
            $allResults | Group-Object -Property Impact | ForEach-Object {
                $impactFailed = ($_.Group | Where-Object { $_.Status -eq 'Fail' }).Count
                $summary.ByImpact[$_.Name] = @{
                    Total  = $_.Group.Count
                    Failed = $impactFailed
                }
            }

            # Determine output path
            if (-not $OutputPath) {
                $extension = switch ($Format) {
                    'JSON' { 'json' }
                    'HTML' { 'html' }
                    'CSV'  { 'csv' }
                }
                $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                $OutputPath = Join-Path -Path $script:ModuleConfig.ReportOutputPath -ChildPath "compliance-report-$timestamp.$extension"
            }

            # Ensure output directory exists
            $outputDir = Split-Path -Path $OutputPath -Parent
            if ($outputDir -and -not (Test-Path -Path $outputDir)) {
                New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
            }

            # Generate report based on format
            switch ($Format) {
                'JSON' {
                    $report = @{
                        Title           = $Title
                        GeneratedAt     = Get-Date -Format 'o'
                        GeneratedBy     = $env:USER ?? $env:USERNAME ?? 'Unknown'
                        Hostname        = $env:HOSTNAME ?? $env:COMPUTERNAME ?? 'Unknown'
                        BenchmarkInfo   = @{
                            Name    = $script:CISBenchmarks.BenchmarkName
                            Version = $script:CISBenchmarks.BenchmarkVersion
                        }
                        Summary         = $summary
                        Findings        = @($reportResults | ForEach-Object {
                            $finding = @{
                                ControlId     = $_.ControlId
                                Title         = $_.Title
                                Description   = $_.Description
                                Level         = $_.Level
                                Category      = $_.Category
                                SubCategory   = $_.SubCategory
                                Impact        = $_.Impact
                                Status        = $_.Status
                                ExpectedValue = $_.ExpectedValue
                                ActualValue   = $_.ActualValue
                                Message       = $_.Message
                            }
                            if ($IncludeRemediation -and $_.RemediationAvailable) {
                                $control = $script:CISBenchmarks.Controls | Where-Object { $_.ControlId -eq $_.ControlId }
                                if ($control) {
                                    $finding['RemediationGuidance'] = Get-RemediationGuidance -Control $control
                                }
                            }
                            $finding
                        })
                    }
                    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
                }

                'HTML' {
                    $htmlContent = Get-HtmlReport -Title $Title -Summary $summary -Results $reportResults -IncludeRemediation:$IncludeRemediation
                    $htmlContent | Set-Content -Path $OutputPath -Encoding UTF8
                }

                'CSV' {
                    $csvData = $reportResults | Select-Object -Property @(
                        'ControlId',
                        'Title',
                        'Level',
                        'Category',
                        'SubCategory',
                        'Impact',
                        'Status',
                        'ExpectedValue',
                        'ActualValue',
                        'Message'
                    )
                    $csvData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }

            $duration = (Get-Date) - $startTime

            Write-ComplianceLog -Message "Compliance report generated" -Level 'Information' -Operation 'Report' -Context @{
                Format   = $Format
                Path     = $OutputPath
                Duration = $duration.TotalSeconds
            }

            # Return report metadata
            return [PSCustomObject]@{
                PSTypeName       = 'HyperionCompliance.ReportMetadata'
                Title            = $Title
                Format           = $Format
                OutputPath       = $OutputPath
                GeneratedAt      = Get-Date
                Duration         = $duration
                Summary          = $summary
                TotalFindings    = $reportResults.Count
            }
        }
        catch {
            Write-ComplianceLog -Message "Failed to generate compliance report: $_" -Level 'Error' -Operation 'Report'
            throw
        }
    }
}


# Helper function to generate HTML report
function Get-HtmlReport {
    [CmdletBinding()]
    param(
        [string]$Title,
        [hashtable]$Summary,
        [PSCustomObject[]]$Results,
        [switch]$IncludeRemediation
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $hostname = $env:HOSTNAME ?? $env:COMPUTERNAME ?? 'Unknown'

    $statusColors = @{
        'Pass'    = '#28a745'
        'Fail'    = '#dc3545'
        'Error'   = '#ffc107'
        'Skipped' = '#6c757d'
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$Title</title>
    <style>
        :root {
            --primary-color: #2c3e50;
            --success-color: #28a745;
            --danger-color: #dc3545;
            --warning-color: #ffc107;
            --secondary-color: #6c757d;
            --background-color: #f8f9fa;
            --card-background: #ffffff;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background-color: var(--background-color);
            color: var(--primary-color);
            line-height: 1.6;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }

        header {
            background-color: var(--primary-color);
            color: white;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 8px;
        }

        header h1 {
            font-size: 24px;
            margin-bottom: 10px;
        }

        .metadata {
            font-size: 14px;
            opacity: 0.9;
        }

        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .summary-card {
            background-color: var(--card-background);
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            text-align: center;
        }

        .summary-card h3 {
            font-size: 14px;
            text-transform: uppercase;
            color: var(--secondary-color);
            margin-bottom: 10px;
        }

        .summary-card .value {
            font-size: 36px;
            font-weight: bold;
        }

        .summary-card.passed .value { color: var(--success-color); }
        .summary-card.failed .value { color: var(--danger-color); }
        .summary-card.compliance .value { color: var(--primary-color); }

        .section {
            background-color: var(--card-background);
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px;
            overflow: hidden;
        }

        .section-header {
            background-color: var(--primary-color);
            color: white;
            padding: 15px 20px;
        }

        .section-header h2 {
            font-size: 18px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #e9ecef;
        }

        th {
            background-color: #f8f9fa;
            font-weight: 600;
            font-size: 14px;
            text-transform: uppercase;
        }

        tr:hover {
            background-color: #f8f9fa;
        }

        .status-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
        }

        .status-pass { background-color: #d4edda; color: #155724; }
        .status-fail { background-color: #f8d7da; color: #721c24; }
        .status-error { background-color: #fff3cd; color: #856404; }
        .status-skipped { background-color: #e2e3e5; color: #383d41; }

        .impact-high { color: var(--danger-color); font-weight: bold; }
        .impact-medium { color: var(--warning-color); font-weight: bold; }
        .impact-low { color: var(--success-color); }

        .finding-details {
            background-color: #f8f9fa;
            padding: 15px;
            margin: 10px 15px;
            border-radius: 4px;
            font-size: 14px;
        }

        .finding-details dt {
            font-weight: 600;
            margin-top: 10px;
        }

        .finding-details dd {
            margin-left: 0;
            color: var(--secondary-color);
        }

        .category-breakdown {
            padding: 20px;
        }

        .category-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 10px 0;
            border-bottom: 1px solid #e9ecef;
        }

        .category-item:last-child {
            border-bottom: none;
        }

        .progress-bar {
            width: 200px;
            height: 8px;
            background-color: #e9ecef;
            border-radius: 4px;
            overflow: hidden;
        }

        .progress-fill {
            height: 100%;
            background-color: var(--success-color);
            transition: width 0.3s ease;
        }

        footer {
            text-align: center;
            padding: 20px;
            color: var(--secondary-color);
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>$Title</h1>
            <div class="metadata">
                Generated: $timestamp | Host: $hostname | Benchmark: $($script:CISBenchmarks.BenchmarkName) v$($script:CISBenchmarks.BenchmarkVersion)
            </div>
        </header>

        <div class="summary-grid">
            <div class="summary-card compliance">
                <h3>Compliance Rate</h3>
                <div class="value">$($Summary.ComplianceRate)%</div>
            </div>
            <div class="summary-card passed">
                <h3>Passed</h3>
                <div class="value">$($Summary.PassedControls)</div>
            </div>
            <div class="summary-card failed">
                <h3>Failed</h3>
                <div class="value">$($Summary.FailedControls)</div>
            </div>
            <div class="summary-card">
                <h3>Total Controls</h3>
                <div class="value">$($Summary.TotalControls)</div>
            </div>
        </div>

        <div class="section">
            <div class="section-header">
                <h2>Compliance by Category</h2>
            </div>
            <div class="category-breakdown">
"@

    foreach ($category in $Summary.ByCategory.Keys | Sort-Object) {
        $catData = $Summary.ByCategory[$category]
        $html += @"
                <div class="category-item">
                    <span>$category</span>
                    <span>$($catData.Passed)/$($catData.Total) ($($catData.ComplianceRate)%)</span>
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: $($catData.ComplianceRate)%"></div>
                    </div>
                </div>
"@
    }

    $html += @"
            </div>
        </div>

        <div class="section">
            <div class="section-header">
                <h2>Findings ($($Results.Count))</h2>
            </div>
            <table>
                <thead>
                    <tr>
                        <th>Control ID</th>
                        <th>Title</th>
                        <th>Level</th>
                        <th>Category</th>
                        <th>Impact</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
"@

    foreach ($result in $Results | Sort-Object -Property ControlId) {
        $statusClass = "status-$($result.Status.ToLower())"
        $impactClass = "impact-$($result.Impact.ToLower())"

        $html += @"
                    <tr>
                        <td><strong>$($result.ControlId)</strong></td>
                        <td>$($result.Title)</td>
                        <td>Level $($result.Level)</td>
                        <td>$($result.Category)</td>
                        <td class="$impactClass">$($result.Impact)</td>
                        <td><span class="status-badge $statusClass">$($result.Status)</span></td>
                    </tr>
"@

        if ($IncludeRemediation -and $result.Status -eq 'Fail') {
            $html += @"
                    <tr>
                        <td colspan="6">
                            <div class="finding-details">
                                <dl>
                                    <dt>Expected Value</dt>
                                    <dd>$($result.ExpectedValue)</dd>
                                    <dt>Actual Value</dt>
                                    <dd>$($result.ActualValue)</dd>
                                    <dt>Description</dt>
                                    <dd>$($result.Description)</dd>
                                </dl>
                            </div>
                        </td>
                    </tr>
"@
        }
    }

    $html += @"
                </tbody>
            </table>
        </div>

        <footer>
            <p>Generated by HyperionCompliance Module | Hyperion Fleet Manager</p>
        </footer>
    </div>
</body>
</html>
"@

    return $html
}


# Helper function to get remediation guidance
function Get-RemediationGuidance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Control
    )

    $guidance = @{
        ControlId   = $Control.ControlId
        Title       = $Control.Title
        Description = $Control.Description
        Impact      = $Control.Impact
        AuditCommand = $Control.AuditCommand
        RegistryPath = $Control.RegistryPath
        RegistryName = $Control.RegistryName
        ExpectedValue = $Control.ExpectedValue
        AutoRemediationAvailable = $null -ne $Control.RemediationScript
    }

    if ($Control.RegistryPath) {
        $guidance['ManualRemediation'] = "Set registry value '$($Control.RegistryName)' at '$($Control.RegistryPath)' to the expected value."
    }

    return $guidance
}
