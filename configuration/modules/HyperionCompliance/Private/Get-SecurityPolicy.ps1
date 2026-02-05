function Get-SecurityPolicy {
    <#
    .SYNOPSIS
        Retrieves Windows security policy values.

    .DESCRIPTION
        Internal helper function that reads various Windows security policy settings
        including password policies, account lockout policies, and other security
        configuration values. Uses native Windows tools like 'net accounts' and
        'secedit' to retrieve values.

    .PARAMETER PolicyType
        The type of security policy to retrieve.
        Valid values: PasswordHistory, MaxPasswordAge, MinPasswordAge, MinPasswordLength,
                      PasswordComplexity, LockoutDuration, LockoutThreshold, LockoutWindow,
                      NetworkAccess

    .EXAMPLE
        Get-SecurityPolicy -PolicyType 'PasswordHistory'
        Returns the password history policy value.

    .EXAMPLE
        Get-SecurityPolicy -PolicyType 'LockoutThreshold'
        Returns the account lockout threshold value.

    .OUTPUTS
        PSCustomObject with Name and Value properties.

    .NOTES
        This is an internal function not exported from the module.
        Requires elevated privileges to read some policy values.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'PasswordHistory',
            'MaxPasswordAge',
            'MinPasswordAge',
            'MinPasswordLength',
            'PasswordComplexity',
            'LockoutDuration',
            'LockoutThreshold',
            'LockoutWindow',
            'NetworkAccess'
        )]
        [string]$PolicyType
    )

    begin {
        Write-ComplianceLog -Message "Retrieving security policy: $PolicyType" -Level 'Verbose'
    }

    process {
        try {
            $result = [PSCustomObject]@{
                Name  = $PolicyType
                Value = $null
                Raw   = $null
            }

            # Check if running on Windows
            if (-not $IsWindows) {
                Write-ComplianceLog -Message "Security policy retrieval requires Windows OS" -Level 'Warning'
                return $result
            }

            switch ($PolicyType) {
                'PasswordHistory' {
                    $output = net accounts 2>$null
                    $match = $output | Select-String -Pattern 'Length of password history maintained:\s*(\d+)'
                    if ($match) {
                        $result.Value = [int]$match.Matches[0].Groups[1].Value
                        $result.Raw = $match.Matches[0].Value
                    }
                }

                'MaxPasswordAge' {
                    $output = net accounts 2>$null
                    $match = $output | Select-String -Pattern 'Maximum password age \(days\):\s*(\d+|Unlimited)'
                    if ($match) {
                        $value = $match.Matches[0].Groups[1].Value
                        $result.Value = $value -eq 'Unlimited' ? 0 : [int]$value
                        $result.Raw = $match.Matches[0].Value
                    }
                }

                'MinPasswordAge' {
                    $output = net accounts 2>$null
                    $match = $output | Select-String -Pattern 'Minimum password age \(days\):\s*(\d+)'
                    if ($match) {
                        $result.Value = [int]$match.Matches[0].Groups[1].Value
                        $result.Raw = $match.Matches[0].Value
                    }
                }

                'MinPasswordLength' {
                    $output = net accounts 2>$null
                    $match = $output | Select-String -Pattern 'Minimum password length:\s*(\d+)'
                    if ($match) {
                        $result.Value = [int]$match.Matches[0].Groups[1].Value
                        $result.Raw = $match.Matches[0].Value
                    }
                }

                'PasswordComplexity' {
                    # Password complexity requires secedit export
                    $tempFile = Join-Path -Path $env:TEMP -ChildPath "secpol_$(Get-Random).cfg"
                    try {
                        $null = secedit /export /cfg $tempFile /quiet 2>$null
                        if (Test-Path -Path $tempFile) {
                            $content = Get-Content -Path $tempFile -Raw
                            $match = $content | Select-String -Pattern 'PasswordComplexity\s*=\s*(\d+)'
                            if ($match) {
                                $result.Value = [int]$match.Matches[0].Groups[1].Value
                                $result.Raw = $match.Matches[0].Value
                            }
                        }
                    }
                    finally {
                        if (Test-Path -Path $tempFile) {
                            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }

                'LockoutDuration' {
                    $output = net accounts 2>$null
                    $match = $output | Select-String -Pattern 'Lockout duration \(minutes\):\s*(\d+)'
                    if ($match) {
                        $result.Value = [int]$match.Matches[0].Groups[1].Value
                        $result.Raw = $match.Matches[0].Value
                    }
                }

                'LockoutThreshold' {
                    $output = net accounts 2>$null
                    $match = $output | Select-String -Pattern 'Lockout threshold:\s*(\d+|Never)'
                    if ($match) {
                        $value = $match.Matches[0].Groups[1].Value
                        $result.Value = $value -eq 'Never' ? 0 : [int]$value
                        $result.Raw = $match.Matches[0].Value
                    }
                }

                'LockoutWindow' {
                    $output = net accounts 2>$null
                    $match = $output | Select-String -Pattern 'Lockout observation window \(minutes\):\s*(\d+)'
                    if ($match) {
                        $result.Value = [int]$match.Matches[0].Groups[1].Value
                        $result.Raw = $match.Matches[0].Value
                    }
                }

                'NetworkAccess' {
                    # Requires secedit export for user rights assignment
                    $tempFile = Join-Path -Path $env:TEMP -ChildPath "secpol_$(Get-Random).cfg"
                    try {
                        $null = secedit /export /cfg $tempFile /quiet 2>$null
                        if (Test-Path -Path $tempFile) {
                            $content = Get-Content -Path $tempFile -Raw
                            $match = $content | Select-String -Pattern 'SeNetworkLogonRight\s*=\s*(.+)'
                            if ($match) {
                                $result.Value = $match.Matches[0].Groups[1].Value.Trim()
                                $result.Raw = $match.Matches[0].Value
                            }
                        }
                    }
                    finally {
                        if (Test-Path -Path $tempFile) {
                            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }

                default {
                    Write-ComplianceLog -Message "Unknown policy type: $PolicyType" -Level 'Warning'
                }
            }

            Write-ComplianceLog -Message "Retrieved $PolicyType = $($result.Value)" -Level 'Verbose'
            return $result
        }
        catch {
            Write-ComplianceLog -Message "Failed to retrieve security policy '$PolicyType': $_" -Level 'Error'
            return [PSCustomObject]@{
                Name  = $PolicyType
                Value = $null
                Raw   = $null
                Error = $_.Exception.Message
            }
        }
    }
}
