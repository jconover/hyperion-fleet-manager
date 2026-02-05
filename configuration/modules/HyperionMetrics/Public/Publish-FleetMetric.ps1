function Publish-FleetMetric {
    <#
    .SYNOPSIS
        Publishes custom metrics to Amazon CloudWatch.

    .DESCRIPTION
        Publishes one or more custom metrics to CloudWatch for Hyperion Fleet Manager.
        Supports batch publishing for efficiency and automatically includes standard
        dimensions for consistent metric organization.

    .PARAMETER MetricName
        The name of the metric to publish. Required when publishing a single metric.

    .PARAMETER Value
        The numeric value of the metric. Required when publishing a single metric.

    .PARAMETER Unit
        The CloudWatch unit for the metric. Valid values include:
        Seconds, Microseconds, Milliseconds, Bytes, Kilobytes, Megabytes, Gigabytes,
        Terabytes, Bits, Kilobits, Megabits, Gigabits, Terabits, Percent, Count,
        Bytes/Second, Kilobytes/Second, Megabytes/Second, Gigabytes/Second,
        Terabytes/Second, Bits/Second, Kilobits/Second, Megabits/Second,
        Gigabits/Second, Terabits/Second, Count/Second, None.
        Defaults to 'None'.

    .PARAMETER Dimensions
        A hashtable of custom dimension name-value pairs.

    .PARAMETER Namespace
        The CloudWatch namespace. Defaults to 'Hyperion/FleetManager'.

    .PARAMETER Environment
        The deployment environment. Used as a standard dimension.

    .PARAMETER Role
        The server role. Used as a standard dimension.

    .PARAMETER InstanceId
        The EC2 instance ID. Auto-detected if not provided.

    .PARAMETER Metrics
        An array of metric objects for batch publishing. Each object should
        contain MetricName, Value, and optionally Unit and Dimensions.

    .PARAMETER StorageResolution
        Storage resolution in seconds. Use 1 for high-resolution metrics,
        60 for standard resolution. Defaults to 60.

    .PARAMETER Region
        The AWS region to publish metrics to. Defaults to the current region.

    .PARAMETER ProfileName
        The AWS credential profile to use.

    .PARAMETER PassThru
        If specified, returns the published metric data.

    .EXAMPLE
        Publish-FleetMetric -MetricName 'RequestCount' -Value 100 -Unit 'Count' -Environment 'prod'

        Publishes a single RequestCount metric with value 100 to production environment.

    .EXAMPLE
        $metrics = @(
            @{ MetricName = 'CPUUsage'; Value = 75.5; Unit = 'Percent' }
            @{ MetricName = 'MemoryUsage'; Value = 8192; Unit = 'Megabytes' }
        )
        Publish-FleetMetric -Metrics $metrics -Environment 'prod' -Role 'WebServer'

        Publishes multiple metrics in a single batch operation.

    .EXAMPLE
        Publish-FleetMetric -MetricName 'CustomMetric' -Value 42 -Dimensions @{ Service = 'API'; Version = '2.0' }

        Publishes a metric with custom dimensions.

    .OUTPUTS
        System.Void
        By default, no output is returned.

        PSCustomObject[]
        If -PassThru is specified, returns the published metric data.

    .NOTES
        CloudWatch PutMetricData has a limit of 20 metrics per call.
        This function automatically batches larger sets of metrics.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Single', SupportsShouldProcess)]
    [OutputType([void], [PSCustomObject[]])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Single', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 255)]
        [string]$MetricName,

        [Parameter(Mandatory, ParameterSetName = 'Single', Position = 1)]
        [double]$Value,

        [Parameter(ParameterSetName = 'Single')]
        [ValidateSet(
            'Seconds', 'Microseconds', 'Milliseconds',
            'Bytes', 'Kilobytes', 'Megabytes', 'Gigabytes', 'Terabytes',
            'Bits', 'Kilobits', 'Megabits', 'Gigabits', 'Terabits',
            'Percent', 'Count', 'Bytes/Second', 'Kilobytes/Second',
            'Megabytes/Second', 'Gigabytes/Second', 'Terabytes/Second',
            'Bits/Second', 'Kilobits/Second', 'Megabits/Second',
            'Gigabits/Second', 'Terabits/Second', 'Count/Second', 'None'
        )]
        [string]$Unit = 'None',

        [Parameter()]
        [hashtable]$Dimensions = @{},

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 255)]
        [string]$Namespace = $script:DefaultNamespace,

        [Parameter()]
        [ValidateSet('dev', 'staging', 'prod', 'test')]
        [string]$Environment = 'dev',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Role = 'FleetServer',

        [Parameter()]
        [string]$InstanceId,

        [Parameter(Mandatory, ParameterSetName = 'Batch', ValueFromPipeline)]
        [ValidateNotNull()]
        [object[]]$Metrics,

        [Parameter()]
        [ValidateSet(1, 60)]
        [int]$StorageResolution = 60,

        [Parameter()]
        [string]$Region,

        [Parameter()]
        [string]$ProfileName,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        $allMetrics = [System.Collections.Generic.List[object]]::new()

        # Build standard dimensions
        $standardDimensions = Get-StandardDimensions `
            -Environment $Environment `
            -Role $Role `
            -InstanceId $InstanceId `
            -AdditionalDimensions $Dimensions

        # Build AWS command parameters
        $awsParams = @{}
        if ($Region) { $awsParams['Region'] = $Region }
        if ($ProfileName) { $awsParams['ProfileName'] = $ProfileName }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Single') {
            $metricObj = [PSCustomObject]@{
                MetricName        = $MetricName
                Value             = $Value
                Unit              = $Unit
                Dimensions        = $standardDimensions
                StorageResolution = $StorageResolution
                Timestamp         = (Get-Date).ToUniversalTime()
            }
            $allMetrics.Add($metricObj)
        }
        else {
            foreach ($metric in $Metrics) {
                # Handle both hashtables and PSCustomObjects
                $metricHash = if ($metric -is [hashtable]) {
                    $metric
                }
                else {
                    @{
                        MetricName        = $metric.MetricName
                        Value             = $metric.Value
                        Unit              = $metric.Unit ?? 'None'
                        Dimensions        = $metric.Dimensions ?? @{}
                        StorageResolution = $metric.StorageResolution ?? $StorageResolution
                        Timestamp         = $metric.Timestamp ?? (Get-Date).ToUniversalTime()
                    }
                }

                # Merge with standard dimensions
                $mergedDimensions = $standardDimensions.Clone()
                if ($metricHash.Dimensions) {
                    foreach ($key in $metricHash.Dimensions.Keys) {
                        $mergedDimensions[$key] = $metricHash.Dimensions[$key]
                    }
                }

                $metricObj = [PSCustomObject]@{
                    MetricName        = $metricHash.MetricName
                    Value             = $metricHash.Value
                    Unit              = $metricHash.Unit ?? 'None'
                    Dimensions        = $mergedDimensions
                    StorageResolution = $metricHash.StorageResolution ?? $StorageResolution
                    Timestamp         = $metricHash.Timestamp ?? (Get-Date).ToUniversalTime()
                }
                $allMetrics.Add($metricObj)
            }
        }
    }

    end {
        if ($allMetrics.Count -eq 0) {
            Write-Warning 'No metrics to publish.'
            return
        }

        # Convert to CloudWatch format
        $cwMetrics = Convert-MetricBatchToCloudWatchFormat -Metrics $allMetrics.ToArray()

        # Split into batches (CloudWatch limit is 20 per call)
        $batches = Split-MetricBatch -Metrics $cwMetrics -BatchSize $script:MetricBatchSize

        $publishedMetrics = [System.Collections.Generic.List[object]]::new()

        foreach ($batch in $batches) {
            $batchDescription = "Publish $($batch.Count) metric(s) to $Namespace"

            if ($PSCmdlet.ShouldProcess($batchDescription, 'Write-CWMetricData')) {
                try {
                    $params = @{
                        Namespace  = $Namespace
                        MetricData = $batch
                    } + $awsParams

                    Write-CWMetricData @params

                    Write-Verbose "Published $($batch.Count) metric(s) to CloudWatch namespace: $Namespace"

                    if ($PassThru) {
                        $publishedMetrics.AddRange($batch)
                    }
                }
                catch {
                    Write-Error "Failed to publish metrics to CloudWatch: $_"
                    throw
                }
            }
        }

        if ($PassThru) {
            return $publishedMetrics.ToArray()
        }
    }
}
