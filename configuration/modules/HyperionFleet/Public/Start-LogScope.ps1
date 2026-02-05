function Start-LogScope {
    <#
    .SYNOPSIS
        Creates a logging scope with automatic correlation and duration tracking.

    .DESCRIPTION
        Creates a new logging scope that automatically:
        - Generates or inherits a correlation ID
        - Logs scope entry
        - Tracks duration
        - Logs scope exit with timing on disposal
        - Supports nested scopes with parent-child correlation

        The returned scope object implements IDisposable and can be used with
        PowerShell's using statement or manual Dispose() calls.

    .PARAMETER ScopeName
        Name for the logging scope. Used in log messages and for identification.
        Examples: 'HealthCheck', 'PatchOperation', 'InventoryScan'

    .PARAMETER Context
        Initial context hashtable to include in scope entry/exit logs.

    .PARAMETER CorrelationId
        Explicit correlation ID to use. If not provided, generates a new one
        or inherits from parent scope.

    .PARAMETER LogLevel
        Log level for scope entry/exit messages. Default: Information.

    .PARAMETER NoEntryLog
        Suppress the automatic scope entry log message.

    .PARAMETER NoExitLog
        Suppress the automatic scope exit log message.

    .PARAMETER PassThru
        Return the scope object. Default behavior returns the scope.

    .EXAMPLE
        $scope = Start-LogScope -ScopeName 'HealthCheck'
        try {
            # Do work here - all logs automatically get the correlation ID
            Write-StructuredLog -Message "Checking instances"
        }
        finally {
            $scope.Dispose()
        }

    .EXAMPLE
        # Using PowerShell 'using' statement equivalent
        $scope = Start-LogScope -ScopeName 'PatchOperation' -Context @{ Baseline = 'AWS-Windows' }
        try {
            Start-FleetPatch -Baseline 'AWS-Windows'
            $scope.AddContext('PatchCount', 15)
        }
        finally {
            $scope.Dispose()  # Automatically logs exit with duration
        }

    .EXAMPLE
        # Nested scopes
        $outerScope = Start-LogScope -ScopeName 'FleetOperation'
        try {
            foreach ($region in $regions) {
                $innerScope = Start-LogScope -ScopeName "RegionProcess-$region"
                try {
                    # Process region
                }
                finally {
                    $innerScope.Dispose()
                }
            }
        }
        finally {
            $outerScope.Dispose()
        }

    .OUTPUTS
        LogScope - A disposable scope object that tracks the operation.

    .NOTES
        Best Practice: Always use try/finally to ensure Dispose() is called,
        even if an exception occurs. This ensures exit logs are written with
        accurate duration.

        The scope stores context in $script:CurrentLogScope which is
        automatically read by Write-StructuredLog.
    #>
    [CmdletBinding()]
    [OutputType([LogScope])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ScopeName,

        [Parameter()]
        [hashtable]$Context = @{},

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CorrelationId,

        [Parameter()]
        [ValidateSet('Verbose', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$LogLevel = 'Information',

        [Parameter()]
        [switch]$NoEntryLog,

        [Parameter()]
        [switch]$NoExitLog,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        # Determine correlation ID
        $parentCorrelationId = $null

        if ($CorrelationId) {
            # Use provided correlation ID
            $scopeCorrelationId = $CorrelationId
        }
        elseif ($script:CurrentCorrelationContext) {
            # Create child of current correlation
            $parentCorrelationId = $script:CurrentCorrelationContext.CorrelationId
            $scopeCorrelationId = New-CorrelationId -ParentCorrelationId $parentCorrelationId -SetAsCurrent
        }
        else {
            # Create new root correlation
            $scopeCorrelationId = New-CorrelationId -SetAsCurrent
        }

        # Create the scope object
        $scope = [LogScope]::new($ScopeName, $scopeCorrelationId, $parentCorrelationId)
        $scope.Context = $Context.Clone()

        # Store current scope for Write-StructuredLog to access
        $previousScope = $script:CurrentLogScope
        $script:CurrentLogScope = $scope

        # Set up dispose callback
        $scope.SetDisposeCallback({
            param($disposingScope)

            # Restore previous scope
            $script:CurrentLogScope = $script:PreviousLogScope

            # Clear correlation if this was the root
            if (-not $disposingScope.ParentCorrelationId) {
                Clear-CorrelationId
            }
            else {
                # Pop to parent correlation
                Clear-CorrelationId
            }

            # Log scope exit with duration if not suppressed
            if (-not $script:SuppressScopeExitLog) {
                $exitContext = $disposingScope.Context.Clone()
                $exitContext['durationMs'] = [math]::Round($disposingScope.GetElapsed().TotalMilliseconds, 2)

                Write-StructuredLog `
                    -Message "Exiting scope: $($disposingScope.ScopeName)" `
                    -Level $script:ScopeLogLevel `
                    -Context $exitContext `
                    -CorrelationId $disposingScope.CorrelationId
            }
        })

        # Store references for the dispose callback
        $script:PreviousLogScope = $previousScope
        $script:SuppressScopeExitLog = $NoExitLog
        $script:ScopeLogLevel = $LogLevel

        # Log scope entry if not suppressed
        if (-not $NoEntryLog) {
            $entryContext = $Context.Clone()
            if ($parentCorrelationId) {
                $entryContext['parentCorrelationId'] = $parentCorrelationId
            }

            Write-StructuredLog `
                -Message "Entering scope: $ScopeName" `
                -Level $LogLevel `
                -Context $entryContext `
                -CorrelationId $scopeCorrelationId
        }

        # Return the scope (always, PassThru is for consistency)
        return $scope
    }
}

function Use-LogScope {
    <#
    .SYNOPSIS
        Executes a script block within a logging scope.

    .DESCRIPTION
        Provides a cleaner syntax for executing code within a logging scope,
        handling scope creation and disposal automatically. Equivalent to
        using Start-LogScope with try/finally but with less boilerplate.

    .PARAMETER ScopeName
        Name for the logging scope.

    .PARAMETER ScriptBlock
        The code to execute within the scope.

    .PARAMETER Context
        Initial context hashtable for the scope.

    .PARAMETER LogLevel
        Log level for scope entry/exit messages.

    .PARAMETER ArgumentList
        Arguments to pass to the script block.

    .EXAMPLE
        Use-LogScope -ScopeName 'HealthCheck' -ScriptBlock {
            Get-FleetHealth -Tag @{ Environment = 'Production' }
        }

    .EXAMPLE
        Use-LogScope 'PatchCycle' {
            param($baseline)
            Start-FleetPatch -Baseline $baseline
        } -ArgumentList 'AWS-Windows'

    .EXAMPLE
        $results = Use-LogScope 'InventoryScan' -Context @{ Region = 'us-east-1' } {
            Get-FleetInventory -Region 'us-east-1'
        }

    .OUTPUTS
        Any output from the script block.

    .NOTES
        The scope is automatically disposed even if the script block throws
        an exception. Exceptions are re-thrown after logging.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$ScopeName,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNull()]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [hashtable]$Context = @{},

        [Parameter()]
        [ValidateSet('Verbose', 'Debug', 'Information', 'Warning', 'Error', 'Critical')]
        [string]$LogLevel = 'Information',

        [Parameter()]
        [object[]]$ArgumentList
    )

    $scope = Start-LogScope -ScopeName $ScopeName -Context $Context -LogLevel $LogLevel

    try {
        if ($ArgumentList) {
            & $ScriptBlock @ArgumentList
        }
        else {
            & $ScriptBlock
        }
    }
    catch {
        # Log the error
        $scope.AddContext('errorMessage', $_.Exception.Message)
        $scope.AddContext('errorType', $_.Exception.GetType().FullName)

        Write-StructuredLog `
            -Message "Scope '$ScopeName' failed with error" `
            -Level Error `
            -Exception $_.Exception `
            -CorrelationId $scope.CorrelationId

        # Re-throw
        throw
    }
    finally {
        $scope.Dispose()
    }
}

function Get-CurrentLogScope {
    <#
    .SYNOPSIS
        Returns the current logging scope if one exists.

    .DESCRIPTION
        Retrieves the current active logging scope, useful for adding context
        or checking scope state.

    .EXAMPLE
        $scope = Get-CurrentLogScope
        if ($scope) {
            $scope.AddContext('ItemsProcessed', $count)
        }

    .OUTPUTS
        LogScope or $null if no scope is active.
    #>
    [CmdletBinding()]
    [OutputType([LogScope])]
    param()

    return $script:CurrentLogScope
}
