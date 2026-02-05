# Script-level cache for metadata to avoid repeated API calls
$script:MetadataCache = @{
    InstanceId = $null
    Region = $null
    AvailabilityZone = $null
    InstanceType = $null
    Hostname = $null
    CacheTime = $null
    CacheDurationMinutes = 60
}

function Get-StandardDimensions {
    <#
    .SYNOPSIS
        Builds standard CloudWatch dimensions for Hyperion metrics.

    .DESCRIPTION
        Creates a hashtable of standard dimensions including Environment,
        InstanceId, Role, Project, and other common attributes used across all
        Hyperion Fleet Manager metrics. Caches EC2 instance metadata for
        performance optimization.

    .PARAMETER Environment
        The deployment environment (e.g., dev, staging, prod, test).

    .PARAMETER Role
        The server role or function (e.g., WebServer, Database, AppServer).

    .PARAMETER InstanceId
        The EC2 instance ID. If not provided, attempts to retrieve from
        instance metadata service (cached).

    .PARAMETER Project
        The project name. Defaults to 'hyperion-fleet-manager'.

    .PARAMETER AdditionalDimensions
        Additional custom dimensions to include.

    .PARAMETER SkipCache
        Skip the metadata cache and force a fresh lookup.

    .OUTPUTS
        System.Collections.Hashtable
        A hashtable of dimension name-value pairs.

    .EXAMPLE
        $dims = Get-StandardDimensions -Environment 'prod' -Role 'WebServer'

        Builds standard dimensions for production web server metrics.

    .EXAMPLE
        $dims = Get-StandardDimensions -Environment 'dev' -AdditionalDimensions @{ Service = 'API' }

        Builds standard dimensions with an additional custom dimension.

    .EXAMPLE
        $dims = Get-StandardDimensions -SkipCache

        Forces a fresh metadata lookup instead of using cached values.

    .NOTES
        This is a private function used internally by the HyperionMetrics module.
        Metadata is cached for 60 minutes to reduce API calls to the metadata service.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [ValidateSet('dev', 'staging', 'prod', 'test')]
        [string]$Environment = 'dev',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Role = 'Unknown',

        [Parameter()]
        [string]$InstanceId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Project = 'hyperion-fleet-manager',

        [Parameter()]
        [hashtable]$AdditionalDimensions = @{},

        [Parameter()]
        [switch]$SkipCache
    )

    # Build the base dimensions
    $dimensions = @{
        Environment = $Environment
        Role        = $Role
        Project     = $Project
    }

    # Get instance metadata (cached)
    $metadata = Get-CachedInstanceMetadata -SkipCache:$SkipCache

    # Use provided InstanceId or cached value
    $effectiveInstanceId = if (-not [string]::IsNullOrEmpty($InstanceId)) {
        $InstanceId
    }
    else {
        $metadata.InstanceId
    }

    if (-not [string]::IsNullOrEmpty($effectiveInstanceId)) {
        $dimensions['InstanceId'] = $effectiveInstanceId
    }

    # Add hostname (from cache or system)
    $hostname = if (-not [string]::IsNullOrEmpty($metadata.Hostname)) {
        $metadata.Hostname
    }
    else {
        [System.Net.Dns]::GetHostName()
    }
    $dimensions['Hostname'] = $hostname

    # Add region if available
    if (-not [string]::IsNullOrEmpty($metadata.Region)) {
        $dimensions['Region'] = $metadata.Region
    }

    # Add availability zone if available
    if (-not [string]::IsNullOrEmpty($metadata.AvailabilityZone)) {
        $dimensions['AvailabilityZone'] = $metadata.AvailabilityZone
    }

    # Add instance type if available
    if (-not [string]::IsNullOrEmpty($metadata.InstanceType)) {
        $dimensions['InstanceType'] = $metadata.InstanceType
    }

    # Merge any additional dimensions
    foreach ($key in $AdditionalDimensions.Keys) {
        if (-not [string]::IsNullOrEmpty($AdditionalDimensions[$key])) {
            $dimensions[$key] = $AdditionalDimensions[$key].ToString()
        }
    }

    return $dimensions
}

function Get-CachedInstanceMetadata {
    <#
    .SYNOPSIS
        Retrieves EC2 instance metadata with caching support.

    .DESCRIPTION
        Gets instance metadata from the EC2 instance metadata service (IMDS)
        with intelligent caching to reduce API calls. Supports both IMDSv1
        and IMDSv2 (token-based).

    .PARAMETER SkipCache
        Force a fresh metadata lookup, bypassing the cache.

    .OUTPUTS
        System.Collections.Hashtable
        A hashtable containing InstanceId, Region, AvailabilityZone,
        InstanceType, and Hostname.

    .NOTES
        Cache duration is controlled by $script:MetadataCache.CacheDurationMinutes.
        Default is 60 minutes.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [switch]$SkipCache
    )

    # Check if cache is valid
    $cacheValid = $false
    if (-not $SkipCache -and $null -ne $script:MetadataCache.CacheTime) {
        $cacheAge = (Get-Date) - $script:MetadataCache.CacheTime
        if ($cacheAge.TotalMinutes -lt $script:MetadataCache.CacheDurationMinutes) {
            $cacheValid = $true
        }
    }

    if ($cacheValid) {
        Write-Verbose 'Using cached instance metadata'
        return @{
            InstanceId       = $script:MetadataCache.InstanceId
            Region           = $script:MetadataCache.Region
            AvailabilityZone = $script:MetadataCache.AvailabilityZone
            InstanceType     = $script:MetadataCache.InstanceType
            Hostname         = $script:MetadataCache.Hostname
        }
    }

    Write-Verbose 'Fetching fresh instance metadata from IMDS'

    # Initialize result
    $result = @{
        InstanceId       = $null
        Region           = $null
        AvailabilityZone = $null
        InstanceType     = $null
        Hostname         = [System.Net.Dns]::GetHostName()
    }

    # Try to get metadata from EC2 IMDS
    $metadataUri = 'http://169.254.169.254'
    $tokenTtl = 21600  # 6 hours
    $timeout = 2

    try {
        # Try IMDSv2 first (more secure, token-based)
        $token = Get-IMDSv2Token -MetadataUri $metadataUri -TokenTtl $tokenTtl -Timeout $timeout

        if ($token) {
            $headers = @{ 'X-aws-ec2-metadata-token' = $token }

            # Get instance ID
            $result.InstanceId = Get-IMDSValue -MetadataUri $metadataUri `
                -Path '/latest/meta-data/instance-id' `
                -Headers $headers `
                -Timeout $timeout

            # Get availability zone (region can be derived from this)
            $result.AvailabilityZone = Get-IMDSValue -MetadataUri $metadataUri `
                -Path '/latest/meta-data/placement/availability-zone' `
                -Headers $headers `
                -Timeout $timeout

            # Derive region from availability zone
            if (-not [string]::IsNullOrEmpty($result.AvailabilityZone)) {
                # Region is AZ minus the last character (e.g., us-east-1a -> us-east-1)
                $result.Region = $result.AvailabilityZone -replace '.$', ''
            }

            # Get instance type
            $result.InstanceType = Get-IMDSValue -MetadataUri $metadataUri `
                -Path '/latest/meta-data/instance-type' `
                -Headers $headers `
                -Timeout $timeout
        }
    }
    catch {
        Write-Verbose "IMDSv2 failed, trying IMDSv1: $_"

        # Fall back to IMDSv1
        try {
            $result.InstanceId = Get-IMDSValue -MetadataUri $metadataUri `
                -Path '/latest/meta-data/instance-id' `
                -Timeout $timeout

            $result.AvailabilityZone = Get-IMDSValue -MetadataUri $metadataUri `
                -Path '/latest/meta-data/placement/availability-zone' `
                -Timeout $timeout

            if (-not [string]::IsNullOrEmpty($result.AvailabilityZone)) {
                $result.Region = $result.AvailabilityZone -replace '.$', ''
            }

            $result.InstanceType = Get-IMDSValue -MetadataUri $metadataUri `
                -Path '/latest/meta-data/instance-type' `
                -Timeout $timeout
        }
        catch {
            Write-Verbose "IMDSv1 also failed. Not running on EC2 or IMDS not available: $_"
        }
    }

    # Update cache
    $script:MetadataCache.InstanceId = $result.InstanceId
    $script:MetadataCache.Region = $result.Region
    $script:MetadataCache.AvailabilityZone = $result.AvailabilityZone
    $script:MetadataCache.InstanceType = $result.InstanceType
    $script:MetadataCache.Hostname = $result.Hostname
    $script:MetadataCache.CacheTime = Get-Date

    return $result
}

function Get-IMDSv2Token {
    <#
    .SYNOPSIS
        Gets an IMDSv2 session token.

    .DESCRIPTION
        Retrieves a session token from the EC2 Instance Metadata Service v2.
        This token is required for all subsequent IMDSv2 requests.

    .PARAMETER MetadataUri
        The base URI of the metadata service (typically http://169.254.169.254).

    .PARAMETER TokenTtl
        The token time-to-live in seconds (max 21600 = 6 hours).

    .PARAMETER Timeout
        Request timeout in seconds.

    .OUTPUTS
        System.String
        The session token, or $null if token acquisition fails.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$MetadataUri,

        [Parameter()]
        [int]$TokenTtl = 21600,

        [Parameter()]
        [int]$Timeout = 2
    )

    try {
        $tokenParams = @{
            Uri         = "$MetadataUri/latest/api/token"
            Method      = 'PUT'
            Headers     = @{ 'X-aws-ec2-metadata-token-ttl-seconds' = $TokenTtl }
            TimeoutSec  = $Timeout
            ErrorAction = 'Stop'
        }

        return Invoke-RestMethod @tokenParams
    }
    catch {
        Write-Verbose "Failed to get IMDSv2 token: $_"
        return $null
    }
}

function Get-IMDSValue {
    <#
    .SYNOPSIS
        Gets a value from the EC2 Instance Metadata Service.

    .DESCRIPTION
        Retrieves a specific metadata value from the EC2 IMDS.
        Supports both IMDSv1 (no headers) and IMDSv2 (with token header).

    .PARAMETER MetadataUri
        The base URI of the metadata service.

    .PARAMETER Path
        The metadata path to retrieve (e.g., /latest/meta-data/instance-id).

    .PARAMETER Headers
        Optional headers to include (required for IMDSv2).

    .PARAMETER Timeout
        Request timeout in seconds.

    .OUTPUTS
        System.String
        The metadata value, or $null if retrieval fails.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$MetadataUri,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [hashtable]$Headers,

        [Parameter()]
        [int]$Timeout = 2
    )

    try {
        $params = @{
            Uri         = "$MetadataUri$Path"
            TimeoutSec  = $Timeout
            ErrorAction = 'Stop'
        }

        if ($Headers) {
            $params['Headers'] = $Headers
        }

        return Invoke-RestMethod @params
    }
    catch {
        Write-Verbose "Failed to get metadata from $Path : $_"
        return $null
    }
}

function Clear-MetadataCache {
    <#
    .SYNOPSIS
        Clears the instance metadata cache.

    .DESCRIPTION
        Resets the cached EC2 instance metadata, forcing a fresh
        lookup on the next request.

    .EXAMPLE
        Clear-MetadataCache

        Clears the metadata cache.

    .NOTES
        This function is useful when instance metadata may have changed
        or for troubleshooting caching issues.
    #>
    [CmdletBinding()]
    param()

    $script:MetadataCache.InstanceId = $null
    $script:MetadataCache.Region = $null
    $script:MetadataCache.AvailabilityZone = $null
    $script:MetadataCache.InstanceType = $null
    $script:MetadataCache.Hostname = $null
    $script:MetadataCache.CacheTime = $null

    Write-Verbose 'Instance metadata cache cleared'
}
