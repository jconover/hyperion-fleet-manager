function Write-ComplianceLog {
    <#
    .SYNOPSIS
        Structured logging helper for HyperionCompliance operations.

    .DESCRIPTION
        Internal logging function that writes structured log entries to file and/or
        console. Supports multiple log levels, JSON formatting, and log rotation.
        Designed for compliance audit trails and remediation tracking.

    .PARAMETER Message
        Log message content.

    .PARAMETER Level
        Log level: Verbose, Information, Warning, Error, Critical.

    .PARAMETER Context
        Optional hashtable with additional context (control IDs, categories, etc).

    .PARAMETER LogPath
        Path to log file. Defaults to module configuration.

    .PARAMETER PassThru
        Return the log entry object.

    .PARAMETER NoConsole
        Suppress console output (file only).

    .PARAMETER Operation
        Optional operation type for audit purposes: Check, Remediation, Report, Export.

    .EXAMPLE
        Write-ComplianceLog -Message "Starting CIS compliance check" -Level 'Information'

    .EXAMPLE
        Write-ComplianceLog -Message "Control CIS-1.1.1 failed" -Level 'Warning' -Context @{ControlId='CIS-1.1.1'; Category='Password Policy'}

    .EXAMPLE
        Write-ComplianceLog -Message "Remediation applied" -Level 'Information' -Operation 'Remediation' -Context @{ControlId='CIS-2.3.1.1'}

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
        [switch]$NoConsole,

        [Parameter()]
        [ValidateSet('Check', 'Remediation', 'Report', 'Export', 'General')]
        [string]$Operation = 'General'
    )

    begin {
        # Ensure log directory exists
        $logDir = Split-Path -Path $LogPath -Parent
        if ($logDir -and -not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }

        # Log level numeric values for filtering
        $logLevels = @{
            'Verbose'     = 0
            'Information' = 1
            'Warning'     = 2
            'Error'       = 3
            'Critical'    = 4
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
                Timestamp  = Get-Date -Format 'o'  # ISO 8601 format
                Level      = $Level
                Operation  = $Operation
                Message    = $Message
                Module     = $script:ModuleName
                Context    = $Context
                User       = $env:USER ?? $env:USERNAME ?? 'Unknown'
                Hostname   = $env:HOSTNAME ?? $env:COMPUTERNAME ?? 'Unknown'
                ProcessId  = $PID
                PSVersion  = $PSVersionTable.PSVersion.ToString()
            }

            # Convert to JSON for file logging
            $jsonLog = $logEntry | ConvertTo-Json -Compress -Depth 10

            # Write to log file (append)
            if ($LogPath) {
                try {
                    Add-Content -Path $LogPath -Value $jsonLog -Encoding UTF8 -ErrorAction Stop
                }
                catch {
                    # Fallback - don't fail if logging fails
                    Write-Warning "Failed to write to log file '$LogPath': $_"
                }
            }

            # Console output (if not suppressed)
            if (-not $NoConsole) {
                $consoleMessage = "[{0}] [{1}] [{2}] {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level.ToUpper().PadRight(11), $Operation.PadRight(11), $Message

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
        if ($LogPath -and (Test-Path -Path $LogPath)) {
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


function Write-RemediationLog {
    <#
    .SYNOPSIS
        Specialized logging for remediation operations.

    .DESCRIPTION
        Internal helper function that logs remediation actions with additional
        context specific to compliance remediation operations.

    .PARAMETER ControlId
        The CIS control ID being remediated.

    .PARAMETER Action
        The remediation action being performed.

    .PARAMETER Result
        The result of the remediation: Success, Failed, Skipped, WhatIf.

    .PARAMETER Details
        Additional details about the remediation.

    .PARAMETER WhatIf
        Indicates if this was a WhatIf operation.

    .EXAMPLE
        Write-RemediationLog -ControlId 'CIS-1.1.1' -Action 'Set password history' -Result 'Success'

    .NOTES
        This is an internal function not exported from the module.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ControlId,

        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [ValidateSet('Success', 'Failed', 'Skipped', 'WhatIf')]
        [string]$Result,

        [Parameter()]
        [string]$Details = '',

        [Parameter()]
        [switch]$WhatIf
    )

    process {
        $level = switch ($Result) {
            'Success' { 'Information' }
            'Failed'  { 'Error' }
            'Skipped' { 'Warning' }
            'WhatIf'  { 'Information' }
        }

        $message = "Remediation [$Result]: $ControlId - $Action"
        if ($Details) {
            $message += " - $Details"
        }

        $context = @{
            ControlId = $ControlId
            Action    = $Action
            Result    = $Result
            WhatIf    = $WhatIf.IsPresent
        }

        $logPath = $script:ModuleConfig.RemediationLogPath ?? $script:DefaultLogPath

        Write-ComplianceLog -Message $message -Level $level -Context $context -Operation 'Remediation' -LogPath $logPath
    }
}
