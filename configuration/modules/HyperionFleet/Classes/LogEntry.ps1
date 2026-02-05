#Requires -Version 7.4

<#
.SYNOPSIS
    PowerShell class definition for structured log entries.

.DESCRIPTION
    Defines the LogEntry class for structured logging with support for
    correlation IDs, context data, and multiple output formats (JSON for
    CloudWatch, console-friendly for human readers).

.NOTES
    Part of HyperionFleet structured logging system.
#>

# Enum for log levels with numeric values for filtering
enum LogLevel {
    Verbose = 0
    Debug = 1
    Information = 2
    Warning = 3
    Error = 4
    Critical = 5
}

# LogEntry class - Represents a structured log entry
class LogEntry {
    [datetime]$Timestamp
    [LogLevel]$Level
    [string]$Message
    [string]$CorrelationId
    [string]$ParentCorrelationId
    [hashtable]$Context
    [Nullable[timespan]]$Duration
    [string]$MachineName
    [int]$ProcessId
    [string]$Username
    [string]$ScriptName
    [string]$FunctionName
    [string]$Module
    [string]$ScopeName

    # Default constructor with validation
    LogEntry() {
        $this.Initialize()
    }

    # Constructor with message and level
    LogEntry([string]$message, [LogLevel]$level) {
        $this.Initialize()
        $this.ValidateMessage($message)
        $this.Message = $message
        $this.Level = $level
    }

    # Constructor with full details
    LogEntry(
        [string]$message,
        [LogLevel]$level,
        [string]$correlationId,
        [hashtable]$context
    ) {
        $this.Initialize()
        $this.ValidateMessage($message)
        $this.Message = $message
        $this.Level = $level
        $this.CorrelationId = $correlationId
        $this.Context = $context ?? @{}
    }

    # Private initialization method
    hidden [void] Initialize() {
        $this.Timestamp = [datetime]::UtcNow
        $this.Level = [LogLevel]::Information
        $this.Context = @{}
        $this.MachineName = $env:COMPUTERNAME ?? $env:HOSTNAME ?? [System.Net.Dns]::GetHostName()
        $this.ProcessId = [System.Diagnostics.Process]::GetCurrentProcess().Id
        $this.Username = $env:USERNAME ?? $env:USER ?? ([Environment]::UserName)
        $this.Module = 'HyperionFleet'
    }

    # Validation method for message
    hidden [void] ValidateMessage([string]$message) {
        if ([string]::IsNullOrWhiteSpace($message)) {
            throw [System.ArgumentException]::new('Message cannot be null or empty', 'message')
        }
        if ($message.Length -gt 262144) {
            # CloudWatch Logs max message size is 256KB
            throw [System.ArgumentException]::new('Message exceeds maximum length of 262144 characters', 'message')
        }
    }

    # Convert to JSON format (CloudWatch-compatible)
    [string] ToJson() {
        $logObject = [ordered]@{
            timestamp = $this.Timestamp.ToString('o')  # ISO 8601 format
            level = $this.Level.ToString()
            message = $this.Message
            correlationId = $this.CorrelationId
        }

        # Add optional fields only if they have values
        if ($this.ParentCorrelationId) {
            $logObject['parentCorrelationId'] = $this.ParentCorrelationId
        }

        if ($this.ScopeName) {
            $logObject['scopeName'] = $this.ScopeName
        }

        if ($this.Duration) {
            $logObject['durationMs'] = [math]::Round($this.Duration.TotalMilliseconds, 2)
        }

        if ($this.FunctionName) {
            $logObject['functionName'] = $this.FunctionName
        }

        if ($this.ScriptName) {
            $logObject['scriptName'] = $this.ScriptName
        }

        # Add context properties flattened into the log object
        if ($this.Context -and $this.Context.Count -gt 0) {
            $logObject['context'] = $this.Context
        }

        # Add metadata
        $logObject['metadata'] = [ordered]@{
            machineName = $this.MachineName
            processId = $this.ProcessId
            username = $this.Username
            module = $this.Module
        }

        return ($logObject | ConvertTo-Json -Compress -Depth 10)
    }

    # Convert to console-friendly string format
    [string] ToConsoleString() {
        $localTime = $this.Timestamp.ToLocalTime()
        $timeStr = $localTime.ToString('yyyy-MM-dd HH:mm:ss.fff')
        $levelStr = $this.Level.ToString().ToUpper().PadRight(11)

        # Build base message
        $output = "[$timeStr] [$levelStr] $($this.Message)"

        # Add correlation ID if present
        if ($this.CorrelationId) {
            $shortId = $this.CorrelationId.Substring(0, [Math]::Min(8, $this.CorrelationId.Length))
            $output = "[$timeStr] [$levelStr] [$shortId] $($this.Message)"
        }

        # Add scope name if present
        if ($this.ScopeName) {
            $output += " [Scope: $($this.ScopeName)]"
        }

        # Add duration if present
        if ($this.Duration) {
            $output += " [Duration: $($this.Duration.TotalMilliseconds.ToString('F2'))ms]"
        }

        # Add context if present
        if ($this.Context -and $this.Context.Count -gt 0) {
            $contextPairs = $this.Context.GetEnumerator() | ForEach-Object {
                "$($_.Key)=$($_.Value)"
            }
            $output += " {$($contextPairs -join ', ')}"
        }

        return $output
    }

    # Create a CloudWatch log event object
    [hashtable] ToCloudWatchEvent() {
        return @{
            Timestamp = $this.Timestamp
            Message   = $this.ToJson()
        }
    }

    # Convert to CloudWatch-specific format with epoch timestamp
    [hashtable] ToCloudWatchFormat() {
        # CloudWatch requires timestamp in milliseconds since Unix epoch
        $epochMs = [long](($this.Timestamp.ToUniversalTime() - [datetime]'1970-01-01').TotalMilliseconds)

        return @{
            Timestamp = $epochMs
            Message   = $this.ToJson()
        }
    }

    # Static method to deserialize from JSON
    static [LogEntry] FromJson([string]$json) {
        if ([string]::IsNullOrWhiteSpace($json)) {
            throw [System.ArgumentException]::new('JSON string cannot be null or empty', 'json')
        }

        $obj = $null
        try {
            $obj = $json | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            $errorRecord = $_
            throw [System.ArgumentException]::new("Invalid JSON format: $($errorRecord.Exception.Message)", 'json', $errorRecord.Exception)
        }

        $entry = [LogEntry]::new()

        # Parse timestamp (ISO 8601 format)
        if ($obj.timestamp) {
            $entry.Timestamp = [datetime]::Parse($obj.timestamp, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        }

        # Parse log level
        if ($obj.level) {
            $entry.Level = [LogLevel]$obj.level
        }

        # Set message
        if ($obj.message) {
            $entry.Message = $obj.message
        }

        # Set correlation IDs
        if ($obj.correlationId) {
            $entry.CorrelationId = $obj.correlationId
        }
        if ($obj.parentCorrelationId) {
            $entry.ParentCorrelationId = $obj.parentCorrelationId
        }

        # Set scope name
        if ($obj.scopeName) {
            $entry.ScopeName = $obj.scopeName
        }

        # Set duration if present
        if ($null -ne $obj.durationMs) {
            $entry.Duration = [timespan]::FromMilliseconds($obj.durationMs)
        }

        # Set function/script names
        if ($obj.functionName) {
            $entry.FunctionName = $obj.functionName
        }
        if ($obj.scriptName) {
            $entry.ScriptName = $obj.scriptName
        }

        # Parse context using foreach loop instead of ForEach-Object for class compatibility
        if ($obj.context) {
            $entry.Context = @{}
            foreach ($prop in $obj.context.PSObject.Properties) {
                $entry.Context[$prop.Name] = $prop.Value
            }
        }

        # Parse metadata
        if ($obj.metadata) {
            if ($obj.metadata.machineName) {
                $entry.MachineName = $obj.metadata.machineName
            }
            if ($obj.metadata.processId) {
                $entry.ProcessId = $obj.metadata.processId
            }
            if ($obj.metadata.username) {
                $entry.Username = $obj.metadata.username
            }
            if ($obj.metadata.module) {
                $entry.Module = $obj.metadata.module
            }
        }

        return $entry
    }

    # String representation
    [string] ToString() {
        return $this.ToConsoleString()
    }

    # Clone the log entry
    [LogEntry] Clone() {
        $clone = [LogEntry]::new()
        $clone.Timestamp = $this.Timestamp
        $clone.Level = $this.Level
        $clone.Message = $this.Message
        $clone.CorrelationId = $this.CorrelationId
        $clone.ParentCorrelationId = $this.ParentCorrelationId
        $clone.Context = $this.Context.Clone()
        $clone.Duration = $this.Duration
        $clone.MachineName = $this.MachineName
        $clone.ProcessId = $this.ProcessId
        $clone.Username = $this.Username
        $clone.ScriptName = $this.ScriptName
        $clone.FunctionName = $this.FunctionName
        $clone.Module = $this.Module
        $clone.ScopeName = $this.ScopeName
        return $clone
    }
}

# LogScope class - Represents a logging scope for automatic correlation
class LogScope : System.IDisposable {
    [string]$ScopeName
    [string]$CorrelationId
    [string]$ParentCorrelationId
    [datetime]$StartTime
    [datetime]$EndTime
    [bool]$IsDisposed
    [hashtable]$Context
    hidden [scriptblock]$OnDispose

    # Constructor
    LogScope([string]$scopeName, [string]$correlationId, [string]$parentCorrelationId) {
        $this.ScopeName = $scopeName
        $this.CorrelationId = $correlationId
        $this.ParentCorrelationId = $parentCorrelationId
        $this.StartTime = [datetime]::UtcNow
        $this.IsDisposed = $false
        $this.Context = @{}
    }

    # Get elapsed time
    [timespan] GetElapsed() {
        if ($this.IsDisposed -and $this.EndTime) {
            return $this.EndTime - $this.StartTime
        }
        return [datetime]::UtcNow - $this.StartTime
    }

    # Add context to scope
    [void] AddContext([string]$key, [object]$value) {
        $this.Context[$key] = $value
    }

    # Set the dispose callback
    [void] SetDisposeCallback([scriptblock]$callback) {
        $this.OnDispose = $callback
    }

    # Dispose implementation
    [void] Dispose() {
        if (-not $this.IsDisposed) {
            $this.EndTime = [datetime]::UtcNow
            $this.IsDisposed = $true

            if ($this.OnDispose) {
                try {
                    & $this.OnDispose $this
                }
                catch {
                    # Silently ignore dispose callback errors to avoid masking original exceptions
                }
            }
        }
    }

    # String representation
    [string] ToString() {
        $elapsed = $this.GetElapsed()
        return "$($this.ScopeName) [$($this.CorrelationId.Substring(0, 8))] - $($elapsed.TotalMilliseconds.ToString('F2'))ms"
    }
}

# Export classes (PowerShell 7+)
# Classes are automatically available when the file is dot-sourced
