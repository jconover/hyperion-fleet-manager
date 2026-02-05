function Send-LogToCloudWatch {
    <#
    .SYNOPSIS
        Sends buffered log entries to AWS CloudWatch Logs.

    .DESCRIPTION
        Batches and sends log entries to CloudWatch Logs using the PutLogEvents API.
        Handles sequence token management, retries for throttling, and automatic
        log group/stream creation.

        This is an internal function called automatically by the logging system
        when CloudWatch integration is enabled.

    .PARAMETER LogGroupName
        CloudWatch Logs group name. Defaults to module configuration or
        environment variable HYPERION_LOG_GROUP.

    .PARAMETER LogStreamName
        CloudWatch Logs stream name. Defaults to hostname-date format.

    .PARAMETER Force
        Force immediate flush of all buffered logs, bypassing batch size checks.

    .PARAMETER Region
        AWS region for CloudWatch Logs. Defaults to module configuration.

    .PARAMETER ProfileName
        AWS credential profile to use.

    .EXAMPLE
        # Called automatically by Write-StructuredLog when CloudWatch is enabled
        Send-LogToCloudWatch

    .EXAMPLE
        # Force flush all buffered logs
        Send-LogToCloudWatch -Force

    .EXAMPLE
        # Send to specific log group
        Send-LogToCloudWatch -LogGroupName '/hyperion/fleet/operations' -Force

    .NOTES
        CloudWatch Logs Constraints:
        - Maximum batch size: 10,000 events or 1MB
        - Sequence token required for PutLogEvents
        - Events must be sorted by timestamp

        Retry Logic:
        - Exponential backoff for throttling (up to 3 retries)
        - Handles InvalidSequenceTokenException by fetching new token

        This function is not exported and should not be called directly.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogGroupName = ($script:ModuleConfig.CloudWatchLogGroup ?? $env:HYPERION_LOG_GROUP ?? '/hyperion/fleet/logs'),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogStreamName,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Region = $script:ModuleConfig.DefaultRegion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName
    )

    begin {
        # Check if CloudWatch logging is enabled
        if (-not $script:ModuleConfig.CloudWatchLogging -and -not $Force) {
            return
        }

        # Check if buffer exists and has entries
        if (-not $script:CloudWatchLogBuffer -or $script:CloudWatchLogBuffer.Count -eq 0) {
            return
        }

        # Generate log stream name if not provided
        if (-not $LogStreamName) {
            $hostname = $env:COMPUTERNAME ?? $env:HOSTNAME ?? [System.Net.Dns]::GetHostName()
            $dateStr = [datetime]::UtcNow.ToString('yyyy/MM/dd')
            $LogStreamName = "$hostname/$dateStr"
        }

        # CloudWatch Logs constraints
        $maxBatchSize = 10000
        $maxBatchBytes = 1048576  # 1MB

        # Retry configuration
        $maxRetries = 3
        $baseDelayMs = 100
    }

    process {
        try {
            # Ensure AWS.Tools.CloudWatchLogs is available
            if (-not (Get-Module -Name 'AWS.Tools.CloudWatchLogs' -ListAvailable)) {
                Write-Verbose "AWS.Tools.CloudWatchLogs module not available. Skipping CloudWatch logging."
                return
            }

            Import-Module -Name 'AWS.Tools.CloudWatchLogs' -ErrorAction Stop

            # Build common parameters
            $awsParams = @{
                Region = $Region
            }
            if ($ProfileName) {
                $awsParams['ProfileName'] = $ProfileName
            }

            # Ensure log group exists
            $logGroup = Get-CWLLogGroup -LogGroupNamePrefix $LogGroupName @awsParams -ErrorAction SilentlyContinue |
                Where-Object { $_.LogGroupName -eq $LogGroupName }

            if (-not $logGroup) {
                Write-Verbose "Creating CloudWatch log group: $LogGroupName"
                New-CWLLogGroup -LogGroupName $LogGroupName @awsParams -ErrorAction Stop

                # Set retention policy (optional, default 30 days)
                $retentionDays = $script:ModuleConfig.CloudWatchRetentionDays ?? 30
                Write-CWLRetentionPolicy -LogGroupName $LogGroupName -RetentionInDays $retentionDays @awsParams -ErrorAction SilentlyContinue
            }

            # Ensure log stream exists
            $logStream = Get-CWLLogStream -LogGroupName $LogGroupName -LogStreamNamePrefix $LogStreamName @awsParams -ErrorAction SilentlyContinue |
                Where-Object { $_.LogStreamName -eq $LogStreamName }

            if (-not $logStream) {
                Write-Verbose "Creating CloudWatch log stream: $LogStreamName"
                New-CWLLogStream -LogGroupName $LogGroupName -LogStreamName $LogStreamName @awsParams -ErrorAction Stop
            }

            # Get sequence token (required for PutLogEvents)
            $sequenceToken = $null
            $logStream = Get-CWLLogStream -LogGroupName $LogGroupName -LogStreamNamePrefix $LogStreamName @awsParams |
                Where-Object { $_.LogStreamName -eq $LogStreamName }

            if ($logStream) {
                $sequenceToken = $logStream.UploadSequenceToken
            }

            # Drain buffer and build batches
            $logEntries = [System.Collections.Generic.List[LogEntry]]::new()
            while ($script:CloudWatchLogBuffer.TryDequeue([ref]$entry)) {
                $logEntries.Add($entry)
            }

            if ($logEntries.Count -eq 0) {
                return
            }

            # Sort by timestamp (CloudWatch requirement)
            $sortedEntries = $logEntries | Sort-Object -Property Timestamp

            # Build batches respecting size constraints
            $batches = [System.Collections.Generic.List[System.Collections.Generic.List[object]]]::new()
            $currentBatch = [System.Collections.Generic.List[object]]::new()
            $currentBatchBytes = 0

            foreach ($logEntry in $sortedEntries) {
                $event = @{
                    Timestamp = [long]($logEntry.Timestamp.ToUniversalTime() - [datetime]'1970-01-01').TotalMilliseconds
                    Message   = $logEntry.ToJson()
                }

                # Calculate event size (message + 26 bytes overhead per event)
                $eventBytes = [System.Text.Encoding]::UTF8.GetByteCount($event.Message) + 26

                # Check if adding this event would exceed limits
                if ($currentBatch.Count -ge $maxBatchSize -or ($currentBatchBytes + $eventBytes) -gt $maxBatchBytes) {
                    if ($currentBatch.Count -gt 0) {
                        $batches.Add($currentBatch)
                    }
                    $currentBatch = [System.Collections.Generic.List[object]]::new()
                    $currentBatchBytes = 0
                }

                $currentBatch.Add($event)
                $currentBatchBytes += $eventBytes
            }

            # Add final batch
            if ($currentBatch.Count -gt 0) {
                $batches.Add($currentBatch)
            }

            # Send each batch with retry logic
            foreach ($batch in $batches) {
                $retryCount = 0
                $success = $false

                while (-not $success -and $retryCount -lt $maxRetries) {
                    try {
                        # Convert batch to CloudWatch log events
                        $logEvents = $batch | ForEach-Object {
                            [Amazon.CloudWatchLogs.Model.InputLogEvent]@{
                                Timestamp = [datetime]::UnixEpoch.AddMilliseconds($_.Timestamp)
                                Message   = $_.Message
                            }
                        }

                        # Send to CloudWatch
                        $putParams = @{
                            LogGroupName  = $LogGroupName
                            LogStreamName = $LogStreamName
                            LogEvent      = $logEvents
                        }

                        if ($sequenceToken) {
                            $putParams['SequenceToken'] = $sequenceToken
                        }

                        $result = Write-CWLLogEvent @putParams @awsParams -ErrorAction Stop

                        # Update sequence token for next batch
                        $sequenceToken = $result.NextSequenceToken

                        Write-Verbose "Sent $($batch.Count) log events to CloudWatch"
                        $success = $true
                    }
                    catch [Amazon.CloudWatchLogs.Model.InvalidSequenceTokenException] {
                        # Get correct sequence token and retry
                        Write-Verbose "Invalid sequence token, refreshing..."
                        $logStream = Get-CWLLogStream -LogGroupName $LogGroupName -LogStreamNamePrefix $LogStreamName @awsParams |
                            Where-Object { $_.LogStreamName -eq $LogStreamName }

                        $sequenceToken = $logStream.UploadSequenceToken
                        $retryCount++
                    }
                    catch [Amazon.CloudWatchLogs.Model.ServiceUnavailableException],
                          [Amazon.CloudWatchLogs.Model.ThrottlingException] {
                        # Exponential backoff for throttling
                        $delay = $baseDelayMs * [math]::Pow(2, $retryCount)
                        Write-Verbose "CloudWatch throttled, waiting ${delay}ms before retry..."
                        Start-Sleep -Milliseconds $delay
                        $retryCount++
                    }
                    catch {
                        Write-Warning "Failed to send logs to CloudWatch: $_"
                        $retryCount++

                        if ($retryCount -ge $maxRetries) {
                            # Re-queue events for later retry
                            foreach ($event in $batch) {
                                $requeued = [LogEntry]::new()
                                $requeued.Message = "REQUEUED: Failed to send to CloudWatch"
                                # Don't requeue to avoid infinite loops
                            }
                        }
                    }
                }
            }
        }
        catch {
            Write-Warning "CloudWatch logging failed: $_"
            # Don't throw - logging failures shouldn't break operations
        }
    }
}

function Initialize-CloudWatchLogging {
    <#
    .SYNOPSIS
        Initializes CloudWatch logging for the module.

    .DESCRIPTION
        Sets up CloudWatch logging configuration including log group,
        stream naming, and buffer settings. Call this during module
        initialization or when changing CloudWatch settings.

    .PARAMETER LogGroupName
        CloudWatch Logs group name to use.

    .PARAMETER Enable
        Enable CloudWatch logging.

    .PARAMETER Disable
        Disable CloudWatch logging.

    .PARAMETER BufferSize
        Number of log entries to buffer before flushing to CloudWatch.

    .PARAMETER RetentionDays
        Log retention period in days.

    .EXAMPLE
        Initialize-CloudWatchLogging -LogGroupName '/hyperion/fleet' -Enable -BufferSize 50

    .NOTES
        This is an internal function for module configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$LogGroupName,

        [Parameter()]
        [switch]$Enable,

        [Parameter()]
        [switch]$Disable,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$BufferSize = 25,

        [Parameter()]
        [ValidateSet(1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653)]
        [int]$RetentionDays = 30
    )

    if ($LogGroupName) {
        $script:ModuleConfig.CloudWatchLogGroup = $LogGroupName
    }

    if ($Enable) {
        $script:ModuleConfig.CloudWatchLogging = $true
    }

    if ($Disable) {
        $script:ModuleConfig.CloudWatchLogging = $false
    }

    $script:ModuleConfig.CloudWatchBufferSize = $BufferSize
    $script:ModuleConfig.CloudWatchRetentionDays = $RetentionDays

    # Initialize buffer
    if (-not $script:CloudWatchLogBuffer) {
        $script:CloudWatchLogBuffer = [System.Collections.Concurrent.ConcurrentQueue[LogEntry]]::new()
    }

    Write-Verbose "CloudWatch logging $(if ($script:ModuleConfig.CloudWatchLogging) {'enabled'} else {'disabled'})"
}

function Flush-CloudWatchLogs {
    <#
    .SYNOPSIS
        Flushes all buffered log entries to CloudWatch.

    .DESCRIPTION
        Forces immediate sending of all buffered log entries to CloudWatch Logs.
        Useful during module unload or at end of operations to ensure all logs
        are persisted.

    .EXAMPLE
        Flush-CloudWatchLogs

    .NOTES
        This is an internal function. Called automatically on module unload.
    #>
    [CmdletBinding()]
    param()

    if ($script:CloudWatchLogBuffer -and $script:CloudWatchLogBuffer.Count -gt 0) {
        Send-LogToCloudWatch -Force
    }
}
