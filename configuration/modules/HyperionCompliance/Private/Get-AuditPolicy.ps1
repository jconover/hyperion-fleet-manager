function Get-AuditPolicy {
    <#
    .SYNOPSIS
        Retrieves Windows advanced audit policy settings.

    .DESCRIPTION
        Internal helper function that reads Windows advanced audit policy settings
        using the auditpol.exe command-line tool. Returns whether Success and/or
        Failure auditing is enabled for specified subcategories.

    .PARAMETER Subcategory
        The audit policy subcategory to check.
        Examples: 'Credential Validation', 'Logon', 'Logoff', 'Account Lockout'

    .EXAMPLE
        Get-AuditPolicy -Subcategory 'Credential Validation'
        Returns audit settings for credential validation events.

    .EXAMPLE
        Get-AuditPolicy -Subcategory 'Logon'
        Returns audit settings for logon events.

    .OUTPUTS
        PSCustomObject with Subcategory, Success, Failure, and Raw properties.

    .NOTES
        This is an internal function not exported from the module.
        Requires elevated privileges to read audit policy values.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Subcategory
    )

    begin {
        Write-ComplianceLog -Message "Retrieving audit policy: $Subcategory" -Level 'Verbose'
    }

    process {
        try {
            $result = [PSCustomObject]@{
                Subcategory = $Subcategory
                Success     = $false
                Failure     = $false
                Raw         = $null
                Error       = $null
            }

            # Check if running on Windows
            if (-not $IsWindows) {
                Write-ComplianceLog -Message "Audit policy retrieval requires Windows OS" -Level 'Warning'
                $result.Error = 'Requires Windows OS'
                return $result
            }

            # Execute auditpol command
            $output = auditpol /get /subcategory:"$Subcategory" 2>&1

            if ($LASTEXITCODE -ne 0) {
                Write-ComplianceLog -Message "auditpol command failed for '$Subcategory'" -Level 'Warning'
                $result.Error = "auditpol failed with exit code $LASTEXITCODE"
                return $result
            }

            $result.Raw = $output -join "`n"

            # Parse the output
            # Output format varies but typically contains:
            # Subcategory                     GUID                                  Setting
            # Credential Validation           {0cce923f-69ae-11d9-bed3-505054503030} Success and Failure
            foreach ($line in $output) {
                if ($line -match $Subcategory) {
                    # Check for various audit settings
                    if ($line -match 'Success and Failure') {
                        $result.Success = $true
                        $result.Failure = $true
                    }
                    elseif ($line -match 'Success\s*$' -or $line -match '\s+Success\s+') {
                        $result.Success = $true
                    }
                    elseif ($line -match 'Failure\s*$' -or $line -match '\s+Failure\s+') {
                        $result.Failure = $true
                    }
                    elseif ($line -match 'No Auditing') {
                        $result.Success = $false
                        $result.Failure = $false
                    }
                    break
                }
            }

            Write-ComplianceLog -Message "Retrieved audit policy '$Subcategory': Success=$($result.Success), Failure=$($result.Failure)" -Level 'Verbose'
            return $result
        }
        catch {
            Write-ComplianceLog -Message "Failed to retrieve audit policy '$Subcategory': $_" -Level 'Error'
            return [PSCustomObject]@{
                Subcategory = $Subcategory
                Success     = $false
                Failure     = $false
                Raw         = $null
                Error       = $_.Exception.Message
            }
        }
    }
}


function Get-AllAuditPolicies {
    <#
    .SYNOPSIS
        Retrieves all Windows advanced audit policy settings.

    .DESCRIPTION
        Internal helper function that retrieves all audit policy settings
        from the system. Returns a collection of audit policy objects.

    .EXAMPLE
        Get-AllAuditPolicies
        Returns all audit policy settings.

    .OUTPUTS
        PSCustomObject[] with audit policy information.

    .NOTES
        This is an internal function not exported from the module.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    process {
        try {
            # Check if running on Windows
            if (-not $IsWindows) {
                Write-ComplianceLog -Message "Audit policy retrieval requires Windows OS" -Level 'Warning'
                return @()
            }

            $results = [System.Collections.Generic.List[PSCustomObject]]::new()

            # Get all audit policies
            $output = auditpol /get /category:* 2>&1

            if ($LASTEXITCODE -ne 0) {
                Write-ComplianceLog -Message "auditpol command failed" -Level 'Warning'
                return @()
            }

            $currentCategory = ''

            foreach ($line in $output) {
                # Skip empty lines and headers
                if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^Machine Name' -or $line -match '^Policy Target' -or $line -match '^Category/Subcategory') {
                    continue
                }

                # Check for category headers (no indentation)
                if ($line -match '^[A-Z]' -and $line -notmatch '\s{2,}') {
                    $currentCategory = $line.Trim()
                    continue
                }

                # Parse subcategory lines (indented)
                if ($line -match '^\s{2}(.+?)\s{2,}(\{[^}]+\})?\s*(Success and Failure|Success|Failure|No Auditing)') {
                    $subcategory = $Matches[1].Trim()
                    $setting = $Matches[3]

                    $auditResult = [PSCustomObject]@{
                        Category    = $currentCategory
                        Subcategory = $subcategory
                        Success     = $setting -match 'Success'
                        Failure     = $setting -match 'Failure'
                        Setting     = $setting
                    }

                    $results.Add($auditResult)
                }
            }

            return $results.ToArray()
        }
        catch {
            Write-ComplianceLog -Message "Failed to retrieve all audit policies: $_" -Level 'Error'
            return @()
        }
    }
}
