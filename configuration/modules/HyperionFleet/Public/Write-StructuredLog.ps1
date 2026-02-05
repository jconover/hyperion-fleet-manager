function Write-StructuredLog {
    <#
    .SYNOPSIS
        Writes a structured log entry with correlation ID support.

    .DESCRIPTION
        Produces structured log output in multiple formats suitable for both
        human consumption (console) and machine processing (JSON for CloudWatch).
        Automatically includes correlation IDs, machine metadata, and context.

        Features:
        - ISO 8601 timestamps in UTC
        - Correlation ID for distributed tracing
        - Structured context data
        - Multiple output formats (JSON, Console)
        - Automatic metadata inclusion
        - Log level filtering
        - File and CloudWatch output support

    .PARAMETER Message
        The log message content.

    .PARAMETER Level
        Log severity level. Valid values: Verbose, Debug, Information, Warning, Error, Critical.
        Default: Information.

    .PARAMETER Context
        Hashtable containing additional structured context data to include in the log entry.
        Example: @{ InstanceId = 'i-1234'; Region = 'us-east-1' }

    .PARAMETER CorrelationId
        Correlation ID for distributed tracing. If not specified, uses the current
        context correlation ID (set via New-CorrelationId -SetAsCurrent).

    .PARAMETER OutputFormat
        Output format for the log entry. Valid values: Auto, Json, Console, Both.
        - Auto: Console for interactive sessions, JSON for non-interactive
        - Json: Always output JSON (for CloudWatch integration)
        - Console: Always output human-readable format
        - Both: Output both formats
        Default: Auto.

    .PARAMETER LogPath
        Path to log file. If specified, appends JSON log entries to the file.

    .PARAMETER SendToCloudWatch
        Send the log entry to CloudWatch Logs. Requires CloudWatch configuration.

    .PARAMETER Exception
        Exception object to include in the log entry. Automatically extracts
        message, type, and stack trace.

    .PARAMETER PassThru
        Return the LogEntry object instead of just writing output.

    .PARAMETER NoConsole
        Suppress console output (file/CloudWatch only).

    .PARAMETER FunctionName
        Name of the calling function. Auto-detected if not specified.

    .EXAMPLE
        Write-StructuredLog -Message "Starting fleet health check"
        Basic information log entry.

    .EXAMPLE
        Write-StructuredLog -Message "Instance check failed" -Level Error -Context @{
            InstanceId = 'i-1234567890abcdef0'
            ErrorCode = 'EC2_UNREACHABLE'
        }
        Error log with context data.

    .EXAMPLE
        $correlationId = New-CorrelationId -SetAsCurrent
        Write-StructuredLog -Message "Operation started" -Level Information
        Write-StructuredLog -Message "Processing..." -Level Debug
        Write-StructuredLog -Message "Operation completed" -Level Information
        Using correlation IDs for request tracing.

    .EXAMPLE
        try {
            Get-SomethingThatFails
        }
        catch {
            Write-StructuredLog -Message "Operation failed" -Level Error -Exception $_
        }
        Logging exceptions with full details.

    .EXAMPLE
        Write-StructuredLog -Message "Audit event" -OutputFormat Json -LogPath "/var/log/fleet.log"
        JSON output to file.

    .OUTPUTS
        LogEntry - When -PassThru is specified.
        None - By default, writes to appropriate output streams.

    .NOTES
        This function is backward compatible with Write-FleetLog and can be used
        as a drop-in replacement with enhanced functionality.
    #>
    [CmdletBinding()]
    [OutputType([LogEntry])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet('Verbose', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$Level = 'Information',

        [Parameter()]
        [hashtable]$Context = @{},

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CorrelationId,

        [Parameter()]
        [ValidateSet('Auto', 'Json', 'Console', 'Both')]
        [string]$OutputFormat = 'Auto',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath,

        [Parameter()]
        [switch]$SendToCloudWatch,

        [Parameter()]
        [System.Exception]$Exception,

        [Parameter()]
        [switch]$PassThru,

        [Parameter()]
        [switch]$NoConsole,

        [Parameter()]
        [string]$FunctionName
    )

    begin {
        # Log level numeric values for filtering
        $logLevelValues = @{
            'Verbose'     = 0
            'Debug'       = 1
            'Information' = 2
            'Warning'     = 3
            'Error'       = 4
            'Critical'    = 5
        }

        # Get configured minimum log level
        $configuredLevel = $script:ModuleConfig.LogLevel ?? 'Information'
        $minimumLevel = $logLevelValues[$configuredLevel]
    }

    process {
        try {
            # Check if this message should be logged based on level
            if ($logLevelValues[$Level] -lt $minimumLevel) {
                return
            }

            # Create log entry
            $logEntry = [LogEntry]::new()
            $logEntry.Message = $Message
            $logEntry.Level = [LogLevel]$Level

            # Set correlation ID (parameter > current context > none)
            if ($CorrelationId) {
                $logEntry.CorrelationId = $CorrelationId
            }
            elseif ($script:CurrentCorrelationContext) {
                $logEntry.CorrelationId = $script:CurrentCorrelationContext.CorrelationId
                $logEntry.ParentCorrelationId = $script:CurrentCorrelationContext.ParentCorrelationId
            }

            # Set scope name if in a logging scope
            if ($script:CurrentLogScope) {
                $logEntry.ScopeName = $script:CurrentLogScope.ScopeName
            }

            # Set context
            $logEntry.Context = $Context.Clone()

            # Add exception details to context if provided
            if ($Exception) {
                $logEntry.Context['exceptionType'] = $Exception.GetType().FullName
                $logEntry.Context['exceptionMessage'] = $Exception.Message
                if ($Exception.StackTrace) {
                    $logEntry.Context['stackTrace'] = $Exception.StackTrace
                }
                if ($Exception.InnerException) {
                    $logEntry.Context['innerException'] = $Exception.InnerException.Message
                }
            }

            # Set function name (auto-detect from call stack if not provided)
            if ($FunctionName) {
                $logEntry.FunctionName = $FunctionName
            }
            else {
                $callStack = Get-PSCallStack
                if ($callStack.Count -gt 1) {
                    # Get caller (skip Write-StructuredLog itself)
                    $caller = $callStack[1]
                    if ($caller.FunctionName -and $caller.FunctionName -ne '<ScriptBlock>') {
                        $logEntry.FunctionName = $caller.FunctionName
                    }
                    if ($caller.ScriptName) {
                        $logEntry.ScriptName = Split-Path -Path $caller.ScriptName -Leaf
                    }
                }
            }

            # Determine output format
            # If OutputFormat is 'Auto', check module configuration first
            $effectiveFormat = $OutputFormat
            if ($OutputFormat -eq 'Auto' -and $script:ModuleConfig.LogFormat -and $script:ModuleConfig.LogFormat -ne 'Auto') {
                $effectiveFormat = $script:ModuleConfig.LogFormat
            }

            $useJson = $false
            $useConsole = $false

            switch ($effectiveFormat) {
                'Auto' {
                    # Use console for interactive, JSON for non-interactive
                    if ([Environment]::UserInteractive -and -not $env:CI -and -not $env:GITHUB_ACTIONS) {
                        $useConsole = $true
                    }
                    else {
                        $useJson = $true
                    }
                }
                'JSON' { $useJson = $true }
                'Json' { $useJson = $true }
                'Console' { $useConsole = $true }
                'Both' { $useJson = $true; $useConsole = $true }
            }

            # Write to console if not suppressed
            if (-not $NoConsole -and $useConsole) {
                Write-LogToConsole -LogEntry $logEntry
            }

            # Write JSON to stdout for non-interactive (CI/CD) scenarios
            if (-not $NoConsole -and $useJson -and -not $useConsole) {
                Write-Output $logEntry.ToJson()
            }

            # Write to log file if specified
            if ($LogPath) {
                Write-LogToFile -LogEntry $logEntry -LogPath $LogPath
            }
            elseif ($script:DefaultLogPath) {
                Write-LogToFile -LogEntry $logEntry -LogPath $script:DefaultLogPath
            }

            # Send to CloudWatch if requested
            if ($SendToCloudWatch -or $script:ModuleConfig.CloudWatchLogging) {
                Add-LogToCloudWatchBuffer -LogEntry $logEntry
            }

            # Return log entry if PassThru
            if ($PassThru) {
                return $logEntry
            }
        }
        catch {
            # Fail silently to avoid log failures breaking operations
            # But write a warning if possible
            try {
                Write-Warning "Structured logging failed: $_"
            }
            catch {
                # Completely silent if even warning fails
            }
        }
    }
}

# Helper function to write log to console with appropriate cmdlet
function Write-LogToConsole {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [LogEntry]$LogEntry
    )

    $consoleMessage = $LogEntry.ToConsoleString()

    switch ($LogEntry.Level) {
        ([LogLevel]::Verbose) {
            Write-Verbose $consoleMessage
        }
        ([LogLevel]::Debug) {
            Write-Debug $consoleMessage
        }
        ([LogLevel]::Information) {
            Write-Information $consoleMessage -InformationAction Continue
        }
        ([LogLevel]::Warning) {
            Write-Warning $consoleMessage
        }
        ([LogLevel]::Error) {
            Write-Error $consoleMessage -ErrorAction Continue
        }
        ([LogLevel]::Critical) {
            Write-Error "CRITICAL: $consoleMessage" -ErrorAction Continue
        }
    }
}

# Helper function to write log to file
function Write-LogToFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [LogEntry]$LogEntry,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    try {
        # Ensure directory exists
        $logDir = Split-Path -Path $LogPath -Parent
        if ($logDir -and -not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }

        # Append JSON log entry
        $jsonLog = $LogEntry.ToJson()
        Add-Content -Path $LogPath -Value $jsonLog -Encoding UTF8 -ErrorAction Stop

        # Check for log rotation (>10MB)
        $logFile = Get-Item -Path $LogPath -ErrorAction SilentlyContinue
        if ($logFile -and $logFile.Length -gt 10MB) {
            $archivePath = "$LogPath.$([datetime]::UtcNow.ToString('yyyyMMdd-HHmmss')).old"
            Move-Item -Path $LogPath -Destination $archivePath -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        # Don't let file write failures break the caller
        Write-Verbose "Failed to write to log file '$LogPath': $_"
    }
}

# Helper function to add log to CloudWatch buffer
function Add-LogToCloudWatchBuffer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [LogEntry]$LogEntry
    )

    # Initialize buffer if needed
    if (-not $script:CloudWatchLogBuffer) {
        $script:CloudWatchLogBuffer = [System.Collections.Concurrent.ConcurrentQueue[LogEntry]]::new()
    }

    # Add to buffer
    $script:CloudWatchLogBuffer.Enqueue($LogEntry)

    # Flush if buffer is large enough or contains errors
    $bufferThreshold = $script:ModuleConfig.CloudWatchBufferSize ?? 25
    if ($script:CloudWatchLogBuffer.Count -ge $bufferThreshold -or $LogEntry.Level -ge [LogLevel]::Error) {
        # Async flush to avoid blocking
        $null = Start-ThreadJob -ScriptBlock {
            param($ModulePath)
            Import-Module $ModulePath -Force
            Send-LogToCloudWatch
        } -ArgumentList $script:ModuleRoot -ThrottleLimit 2
    }
}
