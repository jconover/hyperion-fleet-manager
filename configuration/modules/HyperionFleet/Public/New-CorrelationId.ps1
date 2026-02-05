function New-CorrelationId {
    <#
    .SYNOPSIS
        Generates a unique correlation ID for distributed tracing.

    .DESCRIPTION
        Creates a new GUID-based correlation ID for tracing operations across
        distributed systems. Supports parent correlation IDs for hierarchical
        tracing and thread-safe storage in script scope for automatic propagation.

        Correlation IDs are essential for:
        - Tracing requests across multiple services
        - Correlating logs from different components
        - Debugging distributed operations
        - Performance analysis and monitoring

    .PARAMETER ParentCorrelationId
        Optional parent correlation ID for distributed tracing. When provided,
        establishes a parent-child relationship for hierarchical tracing.

    .PARAMETER SetAsCurrent
        Store the generated correlation ID as the current context correlation ID.
        This enables automatic inclusion in subsequent log entries.

    .PARAMETER Prefix
        Optional prefix to add to the correlation ID for easier identification.
        For example, 'fleet' would produce 'fleet-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'.

    .PARAMETER PassThru
        Return a correlation context object with both the correlation ID and
        parent correlation ID instead of just the string ID.

    .EXAMPLE
        $correlationId = New-CorrelationId
        Generates a new correlation ID.

    .EXAMPLE
        $correlationId = New-CorrelationId -SetAsCurrent
        Generates a correlation ID and sets it as the current context.

    .EXAMPLE
        $childId = New-CorrelationId -ParentCorrelationId $parentId -SetAsCurrent
        Creates a child correlation ID linked to a parent.

    .EXAMPLE
        $context = New-CorrelationId -ParentCorrelationId $parentId -PassThru
        Returns a context object with CorrelationId and ParentCorrelationId properties.

    .EXAMPLE
        $correlationId = New-CorrelationId -Prefix 'patch-op'
        Generates: 'patch-op-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

    .OUTPUTS
        System.String - The generated correlation ID.
        PSCustomObject - When -PassThru is specified, returns an object with
                        CorrelationId and ParentCorrelationId properties.

    .NOTES
        Thread Safety: Uses [System.Threading.Interlocked] for atomic operations
        when updating the current correlation context.

        The correlation ID is stored in $script:CurrentCorrelationContext which
        is automatically read by Write-StructuredLog.
    #>
    [CmdletBinding()]
    [OutputType([string], [PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$ParentCorrelationId,

        [Parameter()]
        [switch]$SetAsCurrent,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9\-_]+$')]
        [ValidateLength(1, 32)]
        [string]$Prefix,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        # Generate new GUID-based correlation ID
        $newId = [System.Guid]::NewGuid().ToString('D')

        # Apply prefix if specified
        if ($Prefix) {
            $newId = "$Prefix-$newId"
        }

        # Create correlation context
        $context = [PSCustomObject]@{
            PSTypeName          = 'HyperionFleet.CorrelationContext'
            CorrelationId       = $newId
            ParentCorrelationId = $ParentCorrelationId
            CreatedAt           = [datetime]::UtcNow
            ThreadId            = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }

        # Store as current if requested (thread-safe)
        if ($SetAsCurrent) {
            # Use a lock object for thread safety
            if (-not $script:CorrelationLock) {
                $script:CorrelationLock = [object]::new()
            }

            [System.Threading.Monitor]::Enter($script:CorrelationLock)
            try {
                # Store current context
                $script:CurrentCorrelationContext = $context

                # Maintain a stack for nested scopes
                if (-not $script:CorrelationStack) {
                    $script:CorrelationStack = [System.Collections.Generic.Stack[PSCustomObject]]::new()
                }
                $script:CorrelationStack.Push($context)
            }
            finally {
                [System.Threading.Monitor]::Exit($script:CorrelationLock)
            }
        }

        # Return appropriate output
        if ($PassThru) {
            return $context
        }

        return $newId
    }
}

function Get-CorrelationId {
    <#
    .SYNOPSIS
        Retrieves the current correlation ID from context.

    .DESCRIPTION
        Returns the current correlation ID from the script-scoped context.
        If no correlation ID has been set, optionally creates a new one.

    .PARAMETER CreateIfMissing
        If no current correlation ID exists, create a new one and set it as current.

    .EXAMPLE
        $correlationId = Get-CorrelationId
        Gets the current correlation ID or $null if none is set.

    .EXAMPLE
        $correlationId = Get-CorrelationId -CreateIfMissing
        Gets or creates a correlation ID.

    .OUTPUTS
        System.String - The current correlation ID or $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [switch]$CreateIfMissing
    )

    # Return current correlation ID if set
    if ($script:CurrentCorrelationContext) {
        return $script:CurrentCorrelationContext.CorrelationId
    }

    # Create new if requested
    if ($CreateIfMissing) {
        return New-CorrelationId -SetAsCurrent
    }

    return $null
}

function Clear-CorrelationId {
    <#
    .SYNOPSIS
        Clears the current correlation ID context.

    .DESCRIPTION
        Removes the current correlation ID from context. When nested scopes
        are in use, pops the current scope and restores the parent context.

    .PARAMETER All
        Clear all correlation IDs including the entire scope stack.

    .EXAMPLE
        Clear-CorrelationId
        Clears the current correlation scope, restoring the parent if nested.

    .EXAMPLE
        Clear-CorrelationId -All
        Clears all correlation contexts.

    .OUTPUTS
        None
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$All
    )

    if (-not $script:CorrelationLock) {
        $script:CorrelationLock = [object]::new()
    }

    [System.Threading.Monitor]::Enter($script:CorrelationLock)
    try {
        if ($All -or -not $script:CorrelationStack -or $script:CorrelationStack.Count -le 1) {
            # Clear everything
            $script:CurrentCorrelationContext = $null
            $script:CorrelationStack = $null
        }
        else {
            # Pop current and restore parent
            $null = $script:CorrelationStack.Pop()
            if ($script:CorrelationStack.Count -gt 0) {
                $script:CurrentCorrelationContext = $script:CorrelationStack.Peek()
            }
            else {
                $script:CurrentCorrelationContext = $null
            }
        }
    }
    finally {
        [System.Threading.Monitor]::Exit($script:CorrelationLock)
    }
}
