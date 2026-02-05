function Write-FleetLog {
    <#
    .SYNOPSIS
        Structured logging helper for HyperionFleet operations.

    .DESCRIPTION
        Internal logging function that writes structured log entries to file and/or
        console. Supports multiple log levels, JSON formatting, and log rotation.

    .PARAMETER Message
        Log message content.

    .PARAMETER Level
        Log level: Verbose, Information, Warning, Error, Critical.

    .PARAMETER Context
        Optional hashtable with additional context (instance IDs, regions, etc).

    .PARAMETER LogPath
        Path to log file. Defaults to module configuration.

    .PARAMETER PassThru
        Return the log entry object.

    .PARAMETER NoConsole
        Suppress console output (file only).

    .EXAMPLE
        Write-FleetLog -Message "Starting health check" -Level 'Information'

    .EXAMPLE
        Write-FleetLog -Message "Instance not found" -Level 'Warning' -Context @{InstanceId='i-1234567890'}

    .OUTPUTS
        PSCustomObject (if -PassThru is specified)

    .NOTES
        This is an internal function not exported from the module.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Verbose', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$Level = 'Information',

        [Parameter()]
        [hashtable]$Context = @{},

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = $script:DefaultLogPath,

        [Parameter()]
        [switch]$PassThru,

        [Parameter()]
        [switch]$NoConsole
    )

    begin {
        # Ensure log directory exists
        $logDir = Split-Path -Path $LogPath -Parent
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }

        # Log level numeric values for filtering
        $logLevels = @{
            'Verbose' = 0
            'Information' = 1
            'Warning' = 2
            'Error' = 3
            'Critical' = 4
        }

        $configuredLevel = $script:ModuleConfig.LogLevel
        $minimumLevel = $logLevels[$configuredLevel]
    }

    process {
        try {
            # Check if this message should be logged based on level
            if ($logLevels[$Level] -lt $minimumLevel) {
                return
            }

            # Build log entry
            $logEntry = [PSCustomObject]@{
                Timestamp = Get-Date -Format 'o'  # ISO 8601 format
                Level = $Level
                Message = $Message
                Module = $script:ModuleName
                Context = $Context
                User = $env:USER ?? $env:USERNAME
                Hostname = $env:HOSTNAME ?? $env:COMPUTERNAME
                ProcessId = $PID
            }

            # Convert to JSON for file logging
            $jsonLog = $logEntry | ConvertTo-Json -Compress -Depth 10

            # Write to log file (append)
            try {
                Add-Content -Path $LogPath -Value $jsonLog -Encoding UTF8 -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to write to log file '$LogPath': $_"
            }

            # Console output (if not suppressed)
            if (-not $NoConsole) {
                $consoleMessage = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level.ToUpper(), $Message

                if ($Context.Count -gt 0) {
                    $contextString = ($Context.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
                    $consoleMessage += " [$contextString]"
                }

                switch ($Level) {
                    'Verbose' {
                        Write-Verbose $consoleMessage
                    }
                    'Information' {
                        Write-Information $consoleMessage -InformationAction Continue
                    }
                    'Warning' {
                        Write-Warning $consoleMessage
                    }
                    'Error' {
                        Write-Error $consoleMessage
                    }
                    'Critical' {
                        Write-Error "CRITICAL: $consoleMessage"
                    }
                }
            }

            # Return log entry if PassThru
            if ($PassThru) {
                return $logEntry
            }
        }
        catch {
            Write-Warning "Logging failed: $_"
        }
    }

    end {
        # Implement log rotation if file is too large (>10MB)
        if (Test-Path -Path $LogPath) {
            $logFile = Get-Item -Path $LogPath
            if ($logFile.Length -gt 10MB) {
                $archivePath = "$LogPath.$((Get-Date -Format 'yyyyMMdd-HHmmss')).old"
                try {
                    Move-Item -Path $LogPath -Destination $archivePath -Force
                    Write-Verbose "Log file rotated to: $archivePath"
                }
                catch {
                    Write-Warning "Failed to rotate log file: $_"
                }
            }
        }
    }
}
