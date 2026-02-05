function Publish-ApplicationMetrics {
    <#
    .SYNOPSIS
        Publishes application health and performance metrics to CloudWatch.

    .DESCRIPTION
        Publishes custom application metrics including request count, error rate,
        latency, queue depth, and job status. Designed for monitoring application
        health in the Hyperion Fleet Manager environment.

    .PARAMETER ApplicationName
        The name of the application being monitored.

    .PARAMETER RequestCount
        The number of requests processed in the measurement period.

    .PARAMETER ErrorCount
        The number of errors encountered in the measurement period.

    .PARAMETER ErrorRate
        The error rate as a percentage (0-100). Calculated from RequestCount
        and ErrorCount if not provided.

    .PARAMETER LatencyMs
        The average request latency in milliseconds.

    .PARAMETER LatencyP50Ms
        The 50th percentile (median) latency in milliseconds.

    .PARAMETER LatencyP95Ms
        The 95th percentile latency in milliseconds.

    .PARAMETER LatencyP99Ms
        The 99th percentile latency in milliseconds.

    .PARAMETER QueueDepth
        The current depth of the application queue.

    .PARAMETER QueueOldestItemAge
        The age in seconds of the oldest item in the queue.

    .PARAMETER ActiveJobs
        The number of currently active/running jobs.

    .PARAMETER CompletedJobs
        The number of completed jobs in the measurement period.

    .PARAMETER FailedJobs
        The number of failed jobs in the measurement period.

    .PARAMETER SuccessRate
        The job success rate as a percentage (0-100).

    .PARAMETER HealthScore
        A custom health score (0-100) for the application.

    .PARAMETER ActiveConnections
        The number of active connections to the application.

    .PARAMETER ThreadPoolActive
        The number of active threads in the thread pool.

    .PARAMETER ThreadPoolAvailable
        The number of available threads in the thread pool.

    .PARAMETER CustomMetrics
        A hashtable of custom metric name-value pairs to publish.

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
        Publish-ApplicationMetrics -ApplicationName 'WebAPI' -RequestCount 1000 -ErrorCount 5 -LatencyMs 45

        Publishes basic application metrics for a web API.

    .EXAMPLE
        Publish-ApplicationMetrics -ApplicationName 'JobProcessor' -QueueDepth 150 -ActiveJobs 10 -CompletedJobs 500 -FailedJobs 2

        Publishes queue and job metrics for a job processor.

    .EXAMPLE
        $customMetrics = @{
            'CacheHitRate' = 0.95
            'DatabaseConnections' = 10
        }
        Publish-ApplicationMetrics -ApplicationName 'DataService' -CustomMetrics $customMetrics -HealthScore 98

        Publishes custom application metrics along with a health score.

    .OUTPUTS
        System.Void
        No output by default.

        PSCustomObject[]
        If -PassThru is specified, returns the published metric data.

    .NOTES
        This function is designed to be called periodically (e.g., every minute)
        to maintain continuous application monitoring in CloudWatch.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void], [PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 100)]
        [string]$ApplicationName,

        # Request/Response Metrics
        [Parameter()]
        [ValidateRange(0, [long]::MaxValue)]
        [long]$RequestCount,

        [Parameter()]
        [ValidateRange(0, [long]::MaxValue)]
        [long]$ErrorCount,

        [Parameter()]
        [ValidateRange(0, 100)]
        [double]$ErrorRate,

        # Latency Metrics
        [Parameter()]
        [ValidateRange(0, [double]::MaxValue)]
        [double]$LatencyMs,

        [Parameter()]
        [ValidateRange(0, [double]::MaxValue)]
        [double]$LatencyP50Ms,

        [Parameter()]
        [ValidateRange(0, [double]::MaxValue)]
        [double]$LatencyP95Ms,

        [Parameter()]
        [ValidateRange(0, [double]::MaxValue)]
        [double]$LatencyP99Ms,

        # Queue Metrics
        [Parameter()]
        [ValidateRange(0, [long]::MaxValue)]
        [long]$QueueDepth,

        [Parameter()]
        [ValidateRange(0, [long]::MaxValue)]
        [long]$QueueOldestItemAge,

        # Job Metrics
        [Parameter()]
        [ValidateRange(0, [long]::MaxValue)]
        [long]$ActiveJobs,

        [Parameter()]
        [ValidateRange(0, [long]::MaxValue)]
        [long]$CompletedJobs,

        [Parameter()]
        [ValidateRange(0, [long]::MaxValue)]
        [long]$FailedJobs,

        [Parameter()]
        [ValidateRange(0, 100)]
        [double]$SuccessRate,

        # Health Metrics
        [Parameter()]
        [ValidateRange(0, 100)]
        [double]$HealthScore,

        # Connection/Thread Metrics
        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$ActiveConnections,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$ThreadPoolActive,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$ThreadPoolAvailable,

        # Custom Metrics
        [Parameter()]
        [hashtable]$CustomMetrics,

        # Standard Parameters
        [Parameter()]
        [ValidateSet('dev', 'staging', 'prod', 'test')]
        [string]$Environment = 'dev',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Role = 'ApplicationServer',

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

    $metrics = [System.Collections.Generic.List[PSCustomObject]]::new()
    $timestamp = (Get-Date).ToUniversalTime()

    # Base dimensions for all application metrics
    $baseDimensions = @{
        MetricType  = 'Application'
        Application = $ApplicationName
    }

    #region Request/Response Metrics

    if ($PSBoundParameters.ContainsKey('RequestCount')) {
        $metrics.Add([PSCustomObject]@{
            MetricName = 'RequestCount'
            Value      = $RequestCount
            Unit       = 'Count'
            Dimensions = $baseDimensions
            Timestamp  = $timestamp
        })
    }

    if ($PSBoundParameters.ContainsKey('ErrorCount')) {
        $metrics.Add([PSCustomObject]@{
            MetricName = 'ErrorCount'
            Value      = $ErrorCount
            Unit       = 'Count'
            Dimensions = $baseDimensions
            Timestamp  = $timestamp
        })
    }

    # Calculate error rate if not provided but we have counts
    if (-not $PSBoundParameters.ContainsKey('ErrorRate') -and
        $PSBoundParameters.ContainsKey('RequestCount') -and
        $PSBoundParameters.ContainsKey('ErrorCount') -and
        $RequestCount -gt 0) {
        $ErrorRate = [math]::Round(($ErrorCount / $RequestCount) * 100, 2)
    }

    if ($PSBoundParameters.ContainsKey('ErrorRate') -or $ErrorRate) {
        $metrics.Add([PSCustomObject]@{
            MetricName = 'ErrorRate'
            Value      = $ErrorRate
            Unit       = 'Percent'
            Dimensions = $baseDimensions
            Timestamp  = $timestamp
        })
    }

    #endregion

    #region Latency Metrics

    if ($PSBoundParameters.ContainsKey('LatencyMs')) {
        $metrics.Add([PSCustomObject]@{
            MetricName = 'Latency'
            Value      = $LatencyMs
            Unit       = 'Milliseconds'
            Dimensions = $baseDimensions
            Timestamp  = $timestamp
        })
    }

    if ($PSBoundParameters.ContainsKey('LatencyP50Ms')) {
        $metrics.Add([PSCustomObject]@{
            MetricName = 'LatencyP50'
            Value      = $LatencyP50Ms
            Unit       = 'Milliseconds'
            Dimensions = $baseDimensions
            Timestamp  = $timestamp
        })
    }

    if ($PSBoundParameters.ContainsKey('LatencyP95Ms')) {
        $metrics.Add([PSCustomObject]@{
            MetricName = 'LatencyP95'
            Value      = $LatencyP95Ms
            Unit       = 'Milliseconds'
            Dimensions = $baseDimensions
            Timestamp  = $timestamp
        })
    }

    if ($PSBoundParameters.ContainsKey('LatencyP99Ms')) {
        $metrics.Add([PSCustomObject]@{
            MetricName = 'LatencyP99'
            Value      = $LatencyP99Ms
            Unit       = 'Milliseconds'
            Dimensions = $baseDimensions
            Timestamp  = $timestamp
        })
    }

    #endregion

    #region Queue Metrics

    if ($PSBoundParameters.ContainsKey('QueueDepth')) {
        $queueDimensions = @{
            MetricType  = 'Queue'
            Application = $ApplicationName
        }

        $metrics.Add([PSCustomObject]@{
            MetricName = 'QueueDepth'
            Value      = $QueueDepth
            Unit       = 'Count'
            Dimensions = $queueDimensions
            Timestamp  = $timestamp
        })
    }

    if ($PSBoundParameters.ContainsKey('QueueOldestItemAge')) {
        $queueDimensions = @{
            MetricType  = 'Queue'
            Application = $ApplicationName
        }

        $metrics.Add([PSCustomObject]@{
            MetricName = 'QueueOldestItemAge'
            Value      = $QueueOldestItemAge
            Unit       = 'Seconds'
            Dimensions = $queueDimensions
            Timestamp  = $timestamp
        })
    }

    #endregion

    #region Job Metrics

    $hasJobMetrics = $PSBoundParameters.ContainsKey('ActiveJobs') -or
                     $PSBoundParameters.ContainsKey('CompletedJobs') -or
                     $PSBoundParameters.ContainsKey('FailedJobs')

    if ($hasJobMetrics) {
        $jobDimensions = @{
            MetricType  = 'Jobs'
            Application = $ApplicationName
        }

        if ($PSBoundParameters.ContainsKey('ActiveJobs')) {
            $metrics.Add([PSCustomObject]@{
                MetricName = 'ActiveJobs'
                Value      = $ActiveJobs
                Unit       = 'Count'
                Dimensions = $jobDimensions
                Timestamp  = $timestamp
            })
        }

        if ($PSBoundParameters.ContainsKey('CompletedJobs')) {
            $metrics.Add([PSCustomObject]@{
                MetricName = 'CompletedJobs'
                Value      = $CompletedJobs
                Unit       = 'Count'
                Dimensions = $jobDimensions
                Timestamp  = $timestamp
            })
        }

        if ($PSBoundParameters.ContainsKey('FailedJobs')) {
            $metrics.Add([PSCustomObject]@{
                MetricName = 'FailedJobs'
                Value      = $FailedJobs
                Unit       = 'Count'
                Dimensions = $jobDimensions
                Timestamp  = $timestamp
            })
        }

        # Calculate success rate if not provided
        if (-not $PSBoundParameters.ContainsKey('SuccessRate') -and
            $PSBoundParameters.ContainsKey('CompletedJobs') -and
            $PSBoundParameters.ContainsKey('FailedJobs')) {
            $totalJobs = $CompletedJobs + $FailedJobs
            if ($totalJobs -gt 0) {
                $SuccessRate = [math]::Round(($CompletedJobs / $totalJobs) * 100, 2)
            }
        }

        if ($PSBoundParameters.ContainsKey('SuccessRate') -or $SuccessRate) {
            $metrics.Add([PSCustomObject]@{
                MetricName = 'JobSuccessRate'
                Value      = $SuccessRate
                Unit       = 'Percent'
                Dimensions = $jobDimensions
                Timestamp  = $timestamp
            })
        }
    }

    #endregion

    #region Health and Connection Metrics

    if ($PSBoundParameters.ContainsKey('HealthScore')) {
        $metrics.Add([PSCustomObject]@{
            MetricName = 'HealthScore'
            Value      = $HealthScore
            Unit       = 'None'
            Dimensions = $baseDimensions
            Timestamp  = $timestamp
        })
    }

    if ($PSBoundParameters.ContainsKey('ActiveConnections')) {
        $metrics.Add([PSCustomObject]@{
            MetricName = 'ActiveConnections'
            Value      = $ActiveConnections
            Unit       = 'Count'
            Dimensions = $baseDimensions
            Timestamp  = $timestamp
        })
    }

    if ($PSBoundParameters.ContainsKey('ThreadPoolActive')) {
        $threadDimensions = @{
            MetricType  = 'ThreadPool'
            Application = $ApplicationName
        }

        $metrics.Add([PSCustomObject]@{
            MetricName = 'ThreadPoolActive'
            Value      = $ThreadPoolActive
            Unit       = 'Count'
            Dimensions = $threadDimensions
            Timestamp  = $timestamp
        })
    }

    if ($PSBoundParameters.ContainsKey('ThreadPoolAvailable')) {
        $threadDimensions = @{
            MetricType  = 'ThreadPool'
            Application = $ApplicationName
        }

        $metrics.Add([PSCustomObject]@{
            MetricName = 'ThreadPoolAvailable'
            Value      = $ThreadPoolAvailable
            Unit       = 'Count'
            Dimensions = $threadDimensions
            Timestamp  = $timestamp
        })

        # Calculate thread pool utilization if we have both values
        if ($PSBoundParameters.ContainsKey('ThreadPoolActive')) {
            $totalThreads = $ThreadPoolActive + $ThreadPoolAvailable
            if ($totalThreads -gt 0) {
                $threadUtilization = [math]::Round(($ThreadPoolActive / $totalThreads) * 100, 2)
                $metrics.Add([PSCustomObject]@{
                    MetricName = 'ThreadPoolUtilization'
                    Value      = $threadUtilization
                    Unit       = 'Percent'
                    Dimensions = $threadDimensions
                    Timestamp  = $timestamp
                })
            }
        }
    }

    #endregion

    #region Custom Metrics

    if ($CustomMetrics -and $CustomMetrics.Count -gt 0) {
        $customDimensions = @{
            MetricType  = 'Custom'
            Application = $ApplicationName
        }

        foreach ($key in $CustomMetrics.Keys) {
            $value = $CustomMetrics[$key]

            # Try to determine the unit based on the metric name
            $unit = switch -Regex ($key) {
                'Rate$|Ratio$|Percentage$|Percent$' { 'Percent' }
                'Count$|Total$|Number$' { 'Count' }
                'Bytes$' { 'Bytes' }
                'Seconds$|Duration$|Time$' { 'Seconds' }
                'Milliseconds$|Ms$|Latency$' { 'Milliseconds' }
                default { 'None' }
            }

            $metrics.Add([PSCustomObject]@{
                MetricName = $key
                Value      = [double]$value
                Unit       = $unit
                Dimensions = $customDimensions
                Timestamp  = $timestamp
            })
        }
    }

    #endregion

    # Verify we have metrics to publish
    if ($metrics.Count -eq 0) {
        Write-Warning "No metrics specified for application: $ApplicationName"
        return
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

    $description = "Publish $($metrics.Count) application metric(s) for: $ApplicationName"

    if ($PSCmdlet.ShouldProcess($description, 'Publish-FleetMetric')) {
        $result = Publish-FleetMetric @publishParams

        Write-Verbose "Published $($metrics.Count) application metrics for: $ApplicationName"

        if ($PassThru) {
            return $result
        }
    }
}
