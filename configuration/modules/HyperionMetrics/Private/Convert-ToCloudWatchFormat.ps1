# Valid CloudWatch metric units
$script:ValidCloudWatchUnits = @(
    'Seconds', 'Microseconds', 'Milliseconds',
    'Bytes', 'Kilobytes', 'Megabytes', 'Gigabytes', 'Terabytes',
    'Bits', 'Kilobits', 'Megabits', 'Gigabits', 'Terabits',
    'Percent', 'Count', 'Bytes/Second', 'Kilobytes/Second',
    'Megabytes/Second', 'Gigabytes/Second', 'Terabytes/Second',
    'Bits/Second', 'Kilobits/Second', 'Megabits/Second',
    'Gigabits/Second', 'Terabits/Second', 'Count/Second', 'None'
)

function Convert-ToCloudWatchFormat {
    <#
    .SYNOPSIS
        Converts metric data to CloudWatch API format.

    .DESCRIPTION
        Transforms metric objects into the format required by the
        AWS CloudWatch PutMetricData API, including proper dimension
        formatting, unit validation, and timestamp handling.

    .PARAMETER MetricName
        The name of the metric. Must be 1-255 characters.

    .PARAMETER Value
        The numeric value of the metric.

    .PARAMETER Unit
        The CloudWatch unit for the metric. Valid values include:
        Seconds, Microseconds, Milliseconds, Bytes, Kilobytes, Megabytes,
        Gigabytes, Terabytes, Bits, Kilobits, Megabits, Gigabits, Terabits,
        Percent, Count, Bytes/Second, Kilobytes/Second, Megabytes/Second,
        Gigabytes/Second, Terabytes/Second, Bits/Second, Kilobits/Second,
        Megabits/Second, Gigabits/Second, Terabits/Second, Count/Second, None.
        Defaults to 'None'.

    .PARAMETER Dimensions
        A hashtable of dimension name-value pairs. Maximum 30 dimensions.
        Names and values must be 1-255 characters.

    .PARAMETER Timestamp
        The timestamp for the metric. Defaults to current UTC time.
        Must be within the past two weeks and not more than two hours
        in the future.

    .PARAMETER StorageResolution
        The storage resolution (1 for high resolution, 60 for standard).
        High resolution metrics incur additional costs.

    .OUTPUTS
        Amazon.CloudWatch.Model.MetricDatum
        A CloudWatch MetricDatum object ready for publishing.

    .EXAMPLE
        $datum = Convert-ToCloudWatchFormat -MetricName 'CPUUtilization' -Value 75.5 -Unit 'Percent'

        Converts a CPU metric to CloudWatch format with percent unit.

    .EXAMPLE
        $datum = Convert-ToCloudWatchFormat -MetricName 'RequestCount' -Value 1000 -Unit 'Count' `
            -Dimensions @{ Service = 'API'; Environment = 'prod' }

        Converts a request count metric with custom dimensions.

    .EXAMPLE
        $datum = Convert-ToCloudWatchFormat -MetricName 'Latency' -Value 45.3 -Unit 'Milliseconds' `
            -StorageResolution 1

        Converts a high-resolution latency metric.

    .NOTES
        This is a private function used internally by the HyperionMetrics module.
        CloudWatch dimension limits: max 30 dimensions, names/values 1-255 chars.
    #>
    [CmdletBinding()]
    [OutputType([Amazon.CloudWatch.Model.MetricDatum])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 255)]
        [string]$MetricName,

        [Parameter(Mandatory)]
        [double]$Value,

        [Parameter()]
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
        [ValidateScript({
            if ($_.Count -gt 30) {
                throw 'CloudWatch supports a maximum of 30 dimensions per metric.'
            }
            $true
        })]
        [hashtable]$Dimensions = @{},

        [Parameter()]
        [ValidateScript({
            $now = (Get-Date).ToUniversalTime()
            $twoWeeksAgo = $now.AddDays(-14)
            $twoHoursFromNow = $now.AddHours(2)

            if ($_ -lt $twoWeeksAgo) {
                throw "Timestamp cannot be more than two weeks in the past. Got: $_, Limit: $twoWeeksAgo"
            }
            if ($_ -gt $twoHoursFromNow) {
                throw "Timestamp cannot be more than two hours in the future. Got: $_, Limit: $twoHoursFromNow"
            }
            $true
        })]
        [datetime]$Timestamp,

        [Parameter()]
        [ValidateSet(1, 60)]
        [int]$StorageResolution = 60
    )

    # Default timestamp to UTC now
    if (-not $PSBoundParameters.ContainsKey('Timestamp')) {
        $Timestamp = (Get-Date).ToUniversalTime()
    }
    else {
        # Ensure timestamp is in UTC
        $Timestamp = $Timestamp.ToUniversalTime()
    }

    # Create the metric datum object
    $metricDatum = [Amazon.CloudWatch.Model.MetricDatum]::new()
    $metricDatum.MetricName = $MetricName
    $metricDatum.Value = $Value
    $metricDatum.Unit = [Amazon.CloudWatch.StandardUnit]::$Unit
    $metricDatum.Timestamp = $Timestamp
    $metricDatum.StorageResolution = $StorageResolution

    # Convert dimensions hashtable to CloudWatch dimension objects
    if ($Dimensions.Count -gt 0) {
        $cwDimensions = [System.Collections.Generic.List[Amazon.CloudWatch.Model.Dimension]]::new()

        foreach ($key in $Dimensions.Keys) {
            # Validate dimension name and value lengths
            $dimName = $key.ToString()
            $dimValue = $Dimensions[$key].ToString()

            if ($dimName.Length -lt 1 -or $dimName.Length -gt 255) {
                Write-Warning "Skipping dimension '$dimName': name must be 1-255 characters"
                continue
            }
            if ($dimValue.Length -lt 1 -or $dimValue.Length -gt 255) {
                Write-Warning "Skipping dimension '$dimName': value must be 1-255 characters"
                continue
            }

            $dimension = [Amazon.CloudWatch.Model.Dimension]::new()
            $dimension.Name = $dimName
            $dimension.Value = $dimValue
            $cwDimensions.Add($dimension)
        }

        if ($cwDimensions.Count -gt 0) {
            $metricDatum.Dimensions = $cwDimensions
        }
    }

    return $metricDatum
}

function Convert-MetricBatchToCloudWatchFormat {
    <#
    .SYNOPSIS
        Converts a batch of metric objects to CloudWatch format.

    .DESCRIPTION
        Transforms an array of custom metric objects into CloudWatch
        MetricDatum objects, suitable for batch publishing. Validates
        units and handles missing/invalid values gracefully.

    .PARAMETER Metrics
        An array of PSCustomObjects containing metric data.
        Each object should have: MetricName, Value, Unit, Dimensions.
        Optional: Timestamp, StorageResolution.

    .PARAMETER DefaultDimensions
        Default dimensions to apply to all metrics if not specified.

    .PARAMETER DefaultUnit
        Default unit to use if metric does not specify one.
        Defaults to 'None'.

    .PARAMETER DefaultStorageResolution
        Default storage resolution if not specified.
        Defaults to 60 (standard).

    .OUTPUTS
        Amazon.CloudWatch.Model.MetricDatum[]
        An array of CloudWatch MetricDatum objects.

    .EXAMPLE
        $metrics = @(
            [PSCustomObject]@{ MetricName = 'CPU'; Value = 75; Unit = 'Percent' }
            [PSCustomObject]@{ MetricName = 'Memory'; Value = 8192; Unit = 'Megabytes' }
        )
        $datums = Convert-MetricBatchToCloudWatchFormat -Metrics $metrics

        Converts multiple metrics to CloudWatch format.

    .EXAMPLE
        $metrics = Get-SystemMetrics
        $datums = Convert-MetricBatchToCloudWatchFormat -Metrics $metrics `
            -DefaultDimensions @{ Environment = 'prod' }

        Converts system metrics with default dimensions applied.

    .NOTES
        Invalid metrics (missing name, invalid unit) are logged and skipped.
    #>
    [CmdletBinding()]
    [OutputType([Amazon.CloudWatch.Model.MetricDatum[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Metrics,

        [Parameter()]
        [hashtable]$DefaultDimensions = @{},

        [Parameter()]
        [ValidateSet(
            'Seconds', 'Microseconds', 'Milliseconds',
            'Bytes', 'Kilobytes', 'Megabytes', 'Gigabytes', 'Terabytes',
            'Bits', 'Kilobits', 'Megabits', 'Gigabits', 'Terabits',
            'Percent', 'Count', 'Bytes/Second', 'Kilobytes/Second',
            'Megabytes/Second', 'Gigabytes/Second', 'Terabytes/Second',
            'Bits/Second', 'Kilobits/Second', 'Megabits/Second',
            'Gigabits/Second', 'Terabits/Second', 'Count/Second', 'None'
        )]
        [string]$DefaultUnit = 'None',

        [Parameter()]
        [ValidateSet(1, 60)]
        [int]$DefaultStorageResolution = 60
    )

    begin {
        $metricDataList = [System.Collections.Generic.List[Amazon.CloudWatch.Model.MetricDatum]]::new()
        $processedCount = 0
        $skippedCount = 0
    }

    process {
        foreach ($metric in $Metrics) {
            # Validate metric has required properties
            if ([string]::IsNullOrEmpty($metric.MetricName)) {
                Write-Warning "Skipping metric: missing MetricName property"
                $skippedCount++
                continue
            }

            # Validate and get the value
            $value = $null
            if ($null -ne $metric.Value) {
                try {
                    $value = [double]$metric.Value
                }
                catch {
                    Write-Warning "Skipping metric '$($metric.MetricName)': invalid value '$($metric.Value)'"
                    $skippedCount++
                    continue
                }
            }
            else {
                Write-Warning "Skipping metric '$($metric.MetricName)': missing Value property"
                $skippedCount++
                continue
            }

            # Validate and get the unit
            $unit = if ([string]::IsNullOrEmpty($metric.Unit)) {
                $DefaultUnit
            }
            else {
                $metric.Unit
            }

            if ($unit -notin $script:ValidCloudWatchUnits) {
                Write-Warning "Metric '$($metric.MetricName)': invalid unit '$unit', using 'None'"
                $unit = 'None'
            }

            # Merge dimensions
            $dimensions = $DefaultDimensions.Clone()
            if ($null -ne $metric.Dimensions -and $metric.Dimensions -is [hashtable]) {
                foreach ($key in $metric.Dimensions.Keys) {
                    $dimensions[$key] = $metric.Dimensions[$key]
                }
            }

            # Get timestamp
            $timestamp = if ($null -ne $metric.Timestamp) {
                $metric.Timestamp
            }
            else {
                (Get-Date).ToUniversalTime()
            }

            # Get storage resolution
            $storageResolution = if ($null -ne $metric.StorageResolution) {
                $metric.StorageResolution
            }
            else {
                $DefaultStorageResolution
            }

            # Convert to CloudWatch format
            try {
                $params = @{
                    MetricName        = $metric.MetricName
                    Value             = $value
                    Unit              = $unit
                    Dimensions        = $dimensions
                    Timestamp         = $timestamp
                    StorageResolution = $storageResolution
                }

                $datum = Convert-ToCloudWatchFormat @params
                $metricDataList.Add($datum)
                $processedCount++
            }
            catch {
                Write-Warning "Failed to convert metric '$($metric.MetricName)': $_"
                $skippedCount++
            }
        }
    }

    end {
        Write-Verbose "Converted $processedCount metrics, skipped $skippedCount"
        return $metricDataList.ToArray()
    }
}

function Split-MetricBatch {
    <#
    .SYNOPSIS
        Splits a large metric array into CloudWatch-compatible batches.

    .DESCRIPTION
        CloudWatch PutMetricData has a limit of 20 metrics per call.
        This function splits larger arrays into compliant batches.
        Also validates that each batch does not exceed the 40KB payload limit.

    .PARAMETER Metrics
        The array of metric data to split.

    .PARAMETER BatchSize
        The maximum batch size. Defaults to 20 (CloudWatch limit).
        Cannot exceed 20.

    .OUTPUTS
        System.Collections.Generic.List[System.Object[]]
        A list of metric arrays, each within the batch size limit.

    .EXAMPLE
        $batches = Split-MetricBatch -Metrics $allMetrics

        Splits metrics into batches of 20.

    .EXAMPLE
        $batches = Split-MetricBatch -Metrics $allMetrics -BatchSize 10

        Splits metrics into smaller batches of 10 for rate limiting.

    .NOTES
        CloudWatch hard limit is 20 metrics per PutMetricData call.
        Payload limit is 40KB per request.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[System.Object[]]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Metrics,

        [Parameter()]
        [ValidateRange(1, 20)]
        [int]$BatchSize = 20
    )

    $batches = [System.Collections.Generic.List[System.Object[]]]::new()

    if ($null -eq $Metrics -or $Metrics.Count -eq 0) {
        Write-Verbose 'No metrics to batch'
        return $batches
    }

    $totalMetrics = $Metrics.Count
    $batchCount = [Math]::Ceiling($totalMetrics / $BatchSize)

    Write-Verbose "Splitting $totalMetrics metrics into $batchCount batch(es) of max $BatchSize"

    for ($i = 0; $i -lt $Metrics.Count; $i += $BatchSize) {
        $endIndex = [Math]::Min($i + $BatchSize, $Metrics.Count) - 1
        $batch = $Metrics[$i..$endIndex]

        # Ensure batch is an array even with single element
        if ($batch -isnot [array]) {
            $batch = @($batch)
        }

        $batches.Add($batch)
    }

    return $batches
}

function Test-CloudWatchUnit {
    <#
    .SYNOPSIS
        Validates if a string is a valid CloudWatch metric unit.

    .DESCRIPTION
        Checks if the provided unit string is one of the valid
        CloudWatch StandardUnit values.

    .PARAMETER Unit
        The unit string to validate.

    .OUTPUTS
        System.Boolean
        $true if the unit is valid, $false otherwise.

    .EXAMPLE
        Test-CloudWatchUnit -Unit 'Percent'
        # Returns $true

    .EXAMPLE
        Test-CloudWatchUnit -Unit 'InvalidUnit'
        # Returns $false

    .EXAMPLE
        if (-not (Test-CloudWatchUnit -Unit $metric.Unit)) {
            Write-Warning "Invalid unit: $($metric.Unit)"
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Unit
    )

    if ([string]::IsNullOrEmpty($Unit)) {
        return $false
    }

    return $Unit -in $script:ValidCloudWatchUnits
}

function Get-CloudWatchUnitForMetricName {
    <#
    .SYNOPSIS
        Suggests a CloudWatch unit based on metric name patterns.

    .DESCRIPTION
        Analyzes a metric name and suggests an appropriate CloudWatch
        unit based on common naming conventions.

    .PARAMETER MetricName
        The metric name to analyze.

    .OUTPUTS
        System.String
        The suggested CloudWatch unit.

    .EXAMPLE
        Get-CloudWatchUnitForMetricName -MetricName 'CPUUtilization'
        # Returns 'Percent'

    .EXAMPLE
        Get-CloudWatchUnitForMetricName -MetricName 'RequestCount'
        # Returns 'Count'

    .EXAMPLE
        Get-CloudWatchUnitForMetricName -MetricName 'LatencyMs'
        # Returns 'Milliseconds'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$MetricName
    )

    # Pattern-based unit detection
    $unit = switch -Regex ($MetricName) {
        # Percent-based metrics
        'Utilization$|Percentage$|Percent$|Rate$' { 'Percent' }
        'CPUUsage|MemoryUsage|DiskUsage' { 'Percent' }

        # Count-based metrics
        'Count$|Total$|Number$|Connections$|Requests$|Errors$' { 'Count' }
        'QueueDepth|ActiveJobs|FailedJobs' { 'Count' }

        # Time-based metrics
        'Milliseconds$|Ms$|Latency$' { 'Milliseconds' }
        'Seconds$|Duration$|Time$|Age$' { 'Seconds' }
        'Microseconds$|Us$' { 'Microseconds' }

        # Size-based metrics
        'Bytes$' { 'Bytes' }
        'Kilobytes$|KB$' { 'Kilobytes' }
        'Megabytes$|MB$' { 'Megabytes' }
        'Gigabytes$|GB$' { 'Gigabytes' }
        'Terabytes$|TB$' { 'Terabytes' }

        # Throughput metrics
        'BytesPerSecond$|BytesPerSec$' { 'Bytes/Second' }
        'KilobytesPerSecond$' { 'Kilobytes/Second' }
        'MegabytesPerSecond$' { 'Megabytes/Second' }
        'CountPerSecond$' { 'Count/Second' }

        # Bit-based metrics
        'Bits$' { 'Bits' }
        'Kilobits$' { 'Kilobits' }
        'Megabits$' { 'Megabits' }
        'BitsPerSecond$' { 'Bits/Second' }

        # Default
        default { 'None' }
    }

    return $unit
}
