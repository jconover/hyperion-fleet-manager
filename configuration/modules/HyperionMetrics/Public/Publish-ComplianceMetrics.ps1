function Publish-ComplianceMetrics {
    <#
    .SYNOPSIS
        Publishes compliance scan metrics to CloudWatch.

    .DESCRIPTION
        Publishes compliance-related metrics including compliance percentage,
        failed controls count, last scan timestamp, and remediation success rate.
        Integrates with HyperionCompliance module for scan data.

    .PARAMETER CompliancePercentage
        The overall compliance percentage (0-100).

    .PARAMETER FailedControlsCount
        The number of failed compliance controls.

    .PARAMETER TotalControlsCount
        The total number of compliance controls evaluated.

    .PARAMETER PassedControlsCount
        The number of passed compliance controls.

    .PARAMETER LastScanTimestamp
        The timestamp of the last compliance scan.

    .PARAMETER RemediationSuccessRate
        The percentage of successful remediations (0-100).

    .PARAMETER RemediationAttempts
        The total number of remediation attempts.

    .PARAMETER RemediationSuccesses
        The number of successful remediations.

    .PARAMETER ComplianceReport
        A compliance report object from Get-ComplianceReport or Test-Compliance.
        When provided, extracts metrics automatically.

    .PARAMETER Framework
        The compliance framework name (e.g., CIS, NIST, SOC2).

    .PARAMETER Environment
        The deployment environment.

    .PARAMETER Role
        The server role.

    .PARAMETER Namespace
        The CloudWatch namespace. Defaults to 'Hyperion/FleetManager'.

    .PARAMETER Region
        The AWS region to publish metrics to.

    .PARAMETER ProfileName
        The AWS credential profile to use.

    .EXAMPLE
        Publish-ComplianceMetrics -CompliancePercentage 95.5 -FailedControlsCount 3 -TotalControlsCount 67

        Publishes compliance metrics with explicit values.

    .EXAMPLE
        $report = Test-Compliance -Framework 'CIS'
        Publish-ComplianceMetrics -ComplianceReport $report

        Publishes compliance metrics from a compliance report object.

    .EXAMPLE
        Publish-ComplianceMetrics -CompliancePercentage 98 -RemediationSuccessRate 85 -Framework 'SOC2' -Environment 'prod'

        Publishes compliance and remediation metrics for a specific framework.

    .OUTPUTS
        System.Void
        No output by default.

        PSCustomObject[]
        If -PassThru is specified, returns the published metric data.

    .NOTES
        This function is designed to integrate with the HyperionCompliance module
        but can also accept manual metric values.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Manual', SupportsShouldProcess)]
    [OutputType([void], [PSCustomObject[]])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Manual')]
        [ValidateRange(0, 100)]
        [double]$CompliancePercentage,

        [Parameter(ParameterSetName = 'Manual')]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$FailedControlsCount = 0,

        [Parameter(ParameterSetName = 'Manual')]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$TotalControlsCount = 0,

        [Parameter(ParameterSetName = 'Manual')]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$PassedControlsCount,

        [Parameter()]
        [datetime]$LastScanTimestamp = (Get-Date).ToUniversalTime(),

        [Parameter()]
        [ValidateRange(0, 100)]
        [double]$RemediationSuccessRate,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$RemediationAttempts = 0,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$RemediationSuccesses = 0,

        [Parameter(Mandatory, ParameterSetName = 'Report', ValueFromPipeline)]
        [ValidateNotNull()]
        [PSCustomObject]$ComplianceReport,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Framework = 'Custom',

        [Parameter()]
        [ValidateSet('dev', 'staging', 'prod', 'test')]
        [string]$Environment = 'dev',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Role = 'FleetServer',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Namespace = $script:DefaultNamespace,

        [Parameter()]
        [string]$Region,

        [Parameter()]
        [string]$ProfileName,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        $metrics = [System.Collections.Generic.List[PSCustomObject]]::new()
        $timestamp = $LastScanTimestamp.ToUniversalTime()

        # Extract values from compliance report if provided
        if ($PSCmdlet.ParameterSetName -eq 'Report') {
            $CompliancePercentage = $ComplianceReport.CompliancePercentage ??
                                    $ComplianceReport.OverallCompliance ??
                                    0

            $FailedControlsCount = $ComplianceReport.FailedControls ??
                                   $ComplianceReport.FailedCount ??
                                   ($ComplianceReport.Results | Where-Object { $_.Status -eq 'Failed' }).Count ??
                                   0

            $PassedControlsCount = $ComplianceReport.PassedControls ??
                                   $ComplianceReport.PassedCount ??
                                   ($ComplianceReport.Results | Where-Object { $_.Status -eq 'Passed' }).Count ??
                                   0

            $TotalControlsCount = $ComplianceReport.TotalControls ??
                                  $ComplianceReport.TotalCount ??
                                  ($FailedControlsCount + $PassedControlsCount)

            if ($ComplianceReport.Framework) {
                $Framework = $ComplianceReport.Framework
            }

            if ($ComplianceReport.ScanTimestamp) {
                $timestamp = $ComplianceReport.ScanTimestamp.ToUniversalTime()
            }

            # Extract remediation data if available
            if ($ComplianceReport.RemediationResults) {
                $RemediationAttempts = $ComplianceReport.RemediationResults.Count
                $RemediationSuccesses = ($ComplianceReport.RemediationResults |
                    Where-Object { $_.Success -eq $true }).Count

                if ($RemediationAttempts -gt 0) {
                    $RemediationSuccessRate = [math]::Round(
                        ($RemediationSuccesses / $RemediationAttempts) * 100, 2
                    )
                }
            }
        }

        # Calculate passed controls if not provided
        if (-not $PSBoundParameters.ContainsKey('PassedControlsCount') -and
            $PSCmdlet.ParameterSetName -eq 'Manual') {
            $PassedControlsCount = $TotalControlsCount - $FailedControlsCount
        }

        # Build dimensions
        $baseDimensions = @{
            MetricType = 'Compliance'
            Framework  = $Framework
        }

        # Core compliance metrics
        $metrics.Add([PSCustomObject]@{
            MetricName = 'CompliancePercentage'
            Value      = [math]::Round($CompliancePercentage, 2)
            Unit       = 'Percent'
            Dimensions = $baseDimensions
            Timestamp  = $timestamp
        })

        $metrics.Add([PSCustomObject]@{
            MetricName = 'FailedControlsCount'
            Value      = $FailedControlsCount
            Unit       = 'Count'
            Dimensions = $baseDimensions
            Timestamp  = $timestamp
        })

        $metrics.Add([PSCustomObject]@{
            MetricName = 'PassedControlsCount'
            Value      = $PassedControlsCount
            Unit       = 'Count'
            Dimensions = $baseDimensions
            Timestamp  = $timestamp
        })

        $metrics.Add([PSCustomObject]@{
            MetricName = 'TotalControlsCount'
            Value      = $TotalControlsCount
            Unit       = 'Count'
            Dimensions = $baseDimensions
            Timestamp  = $timestamp
        })

        # Calculate and publish time since last scan (useful for alerting on stale scans)
        $hoursSinceLastScan = [math]::Round(
            ((Get-Date).ToUniversalTime() - $timestamp).TotalHours, 2
        )
        $metrics.Add([PSCustomObject]@{
            MetricName = 'HoursSinceLastScan'
            Value      = $hoursSinceLastScan
            Unit       = 'None'
            Dimensions = $baseDimensions
            Timestamp  = (Get-Date).ToUniversalTime()
        })

        # Remediation metrics (if available)
        if ($PSBoundParameters.ContainsKey('RemediationSuccessRate') -or $RemediationAttempts -gt 0) {
            $remediationDimensions = @{
                MetricType = 'Remediation'
                Framework  = $Framework
            }

            if ($PSBoundParameters.ContainsKey('RemediationSuccessRate')) {
                $metrics.Add([PSCustomObject]@{
                    MetricName = 'RemediationSuccessRate'
                    Value      = [math]::Round($RemediationSuccessRate, 2)
                    Unit       = 'Percent'
                    Dimensions = $remediationDimensions
                    Timestamp  = $timestamp
                })
            }

            if ($RemediationAttempts -gt 0) {
                $metrics.Add([PSCustomObject]@{
                    MetricName = 'RemediationAttempts'
                    Value      = $RemediationAttempts
                    Unit       = 'Count'
                    Dimensions = $remediationDimensions
                    Timestamp  = $timestamp
                })

                $metrics.Add([PSCustomObject]@{
                    MetricName = 'RemediationSuccesses'
                    Value      = $RemediationSuccesses
                    Unit       = 'Count'
                    Dimensions = $remediationDimensions
                    Timestamp  = $timestamp
                })

                $metrics.Add([PSCustomObject]@{
                    MetricName = 'RemediationFailures'
                    Value      = ($RemediationAttempts - $RemediationSuccesses)
                    Unit       = 'Count'
                    Dimensions = $remediationDimensions
                    Timestamp  = $timestamp
                })
            }
        }

        # Severity breakdown metrics (if available in report)
        if ($ComplianceReport -and $ComplianceReport.Results) {
            $severityCounts = $ComplianceReport.Results |
                Where-Object { $_.Status -eq 'Failed' } |
                Group-Object -Property Severity

            foreach ($severity in $severityCounts) {
                $severityDimensions = @{
                    MetricType = 'Compliance'
                    Framework  = $Framework
                    Severity   = $severity.Name
                }

                $metrics.Add([PSCustomObject]@{
                    MetricName = 'FailedControlsBySeverity'
                    Value      = $severity.Count
                    Unit       = 'Count'
                    Dimensions = $severityDimensions
                    Timestamp  = $timestamp
                })
            }
        }

        # Publish all metrics
        $publishParams = @{
            Metrics     = $metrics.ToArray()
            Namespace   = $Namespace
            Environment = $Environment
            Role        = $Role
        }

        if ($Region) { $publishParams['Region'] = $Region }
        if ($ProfileName) { $publishParams['ProfileName'] = $ProfileName }
        if ($PassThru) { $publishParams['PassThru'] = $true }

        $description = "Publish $($metrics.Count) compliance metric(s) for framework: $Framework"

        if ($PSCmdlet.ShouldProcess($description, 'Publish-FleetMetric')) {
            $result = Publish-FleetMetric @publishParams

            Write-Verbose "Published $($metrics.Count) compliance metrics for framework: $Framework"
            Write-Verbose "Compliance: $CompliancePercentage%, Failed: $FailedControlsCount, Passed: $PassedControlsCount"

            if ($PassThru) {
                return $result
            }
        }
    }
}
