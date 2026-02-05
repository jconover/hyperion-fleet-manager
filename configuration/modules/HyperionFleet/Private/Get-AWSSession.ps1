function Get-AWSSession {
    <#
    .SYNOPSIS
        Manages AWS credential and session configuration.

    .DESCRIPTION
        Internal helper function that validates and retrieves AWS credentials,
        region configuration, and session parameters. Supports multiple credential
        sources including environment variables, profiles, and IAM roles.

    .PARAMETER ProfileName
        AWS credential profile name. If not specified, uses default profile or instance role.

    .PARAMETER Region
        AWS region to use for the session. Defaults to module configuration or us-east-1.

    .PARAMETER RoleArn
        Optional IAM role ARN to assume for cross-account operations.

    .PARAMETER SessionName
        Session name for assumed role credentials. Defaults to timestamped session.

    .EXAMPLE
        $session = Get-AWSSession -Region 'us-west-2'
        Returns session configuration for us-west-2 region.

    .EXAMPLE
        $session = Get-AWSSession -ProfileName 'production' -RoleArn 'arn:aws:iam::123456789012:role/FleetManager'
        Returns session with assumed role credentials.

    .OUTPUTS
        PSCustomObject with Region, ProfileName, Credential, and SessionToken properties.

    .NOTES
        This is an internal function not exported from the module.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Region = $script:ModuleConfig.DefaultRegion,

        [Parameter()]
        [ValidatePattern('^arn:aws:iam::\d{12}:role/[\w+=,.@-]+$')]
        [string]$RoleArn,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SessionName = "HyperionFleet-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    )

    begin {
        Write-FleetLog -Message "Initializing AWS session" -Level 'Verbose'
    }

    process {
        try {
            # Build session configuration
            $sessionConfig = @{
                Region = $Region
            }

            # Add profile if specified
            if ($ProfileName) {
                $sessionConfig['ProfileName'] = $ProfileName
                Write-FleetLog -Message "Using AWS profile: $ProfileName" -Level 'Verbose'
            }

            # Verify AWS credentials are available
            try {
                if ($ProfileName) {
                    $callerIdentity = Get-STSCallerIdentity -ProfileName $ProfileName -Region $Region -ErrorAction Stop
                }
                else {
                    $callerIdentity = Get-STSCallerIdentity -Region $Region -ErrorAction Stop
                }

                Write-FleetLog -Message "Authenticated as: $($callerIdentity.Arn)" -Level 'Information'
            }
            catch {
                Write-FleetLog -Message "Failed to verify AWS credentials: $_" -Level 'Error'
                throw "AWS credentials not configured or invalid. Configure with 'Set-AWSCredential' or set environment variables."
            }

            # Assume role if specified
            if ($RoleArn) {
                Write-FleetLog -Message "Assuming role: $RoleArn" -Level 'Information'

                try {
                    $assumeRoleParams = @{
                        RoleArn = $RoleArn
                        RoleSessionName = $SessionName
                        Region = $Region
                    }

                    if ($ProfileName) {
                        $assumeRoleParams['ProfileName'] = $ProfileName
                    }

                    $roleCredential = Use-STSRole @assumeRoleParams -ErrorAction Stop

                    $sessionConfig['Credential'] = $roleCredential.Credentials
                    $sessionConfig['AssumedRoleArn'] = $RoleArn
                    $sessionConfig['SessionExpiration'] = $roleCredential.Credentials.Expiration

                    Write-FleetLog -Message "Role assumed successfully. Session expires: $($roleCredential.Credentials.Expiration)" -Level 'Information'
                }
                catch {
                    Write-FleetLog -Message "Failed to assume role: $_" -Level 'Error'
                    throw "Failed to assume role '$RoleArn': $_"
                }
            }

            # Create session object
            $session = [PSCustomObject]@{
                PSTypeName = 'HyperionFleet.AWSSession'
                Region = $sessionConfig.Region
                ProfileName = $sessionConfig.ProfileName
                Credential = $sessionConfig.Credential
                CallerIdentity = $callerIdentity
                AssumedRoleArn = $sessionConfig.AssumedRoleArn
                SessionExpiration = $sessionConfig.SessionExpiration
                Timestamp = Get-Date
            }

            Write-FleetLog -Message "AWS session initialized successfully" -Level 'Verbose'
            return $session
        }
        catch {
            Write-FleetLog -Message "Failed to initialize AWS session: $_" -Level 'Error'
            throw
        }
    }
}
