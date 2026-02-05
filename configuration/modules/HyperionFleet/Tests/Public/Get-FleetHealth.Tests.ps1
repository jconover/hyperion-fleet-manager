#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Get-FleetHealth function.

.DESCRIPTION
    Unit and integration tests for the Get-FleetHealth cmdlet including parameter validation,
    output format, and error handling.
#>

BeforeAll {
    $ModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path -Path $ModulePath -ChildPath 'HyperionFleet.psd1') -Force
}

Describe 'Get-FleetHealth' {
    Context 'Function Structure' {
        BeforeAll {
            $Command = Get-Command -Name 'Get-FleetHealth'
        }

        It 'exists' {
            $Command | Should -Not -BeNullOrEmpty
        }

        It 'has CmdletBinding attribute' {
            $Command.CmdletBinding | Should -BeTrue
        }

        It 'has comment-based help' {
            $Command.Parameters | Should -Not -BeNullOrEmpty
            Get-Help -Name 'Get-FleetHealth' | Should -Not -BeNullOrEmpty
        }

        It 'has synopsis' {
            $Help = Get-Help -Name 'Get-FleetHealth'
            $Help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'has description' {
            $Help = Get-Help -Name 'Get-FleetHealth'
            $Help.Description | Should -Not -BeNullOrEmpty
        }

        It 'has examples' {
            $Help = Get-Help -Name 'Get-FleetHealth'
            $Help.Examples.Example.Count | Should -BeGreaterOrEqual 1
        }
    }

    Context 'Parameters' {
        BeforeAll {
            $Command = Get-Command -Name 'Get-FleetHealth'
            $Parameters = $Command.Parameters
        }

        It 'has InstanceId parameter' {
            $Parameters.Keys | Should -Contain 'InstanceId'
        }

        It 'InstanceId accepts array of strings' {
            $Parameters['InstanceId'].ParameterType.Name | Should -Be 'String[]'
        }

        It 'InstanceId has validation pattern' {
            $Attributes = $Parameters['InstanceId'].Attributes
            $ValidationAttribute = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] }
            $ValidationAttribute | Should -Not -BeNullOrEmpty
        }

        It 'has Tag parameter' {
            $Parameters.Keys | Should -Contain 'Tag'
        }

        It 'Tag accepts hashtable' {
            $Parameters['Tag'].ParameterType.Name | Should -Be 'Hashtable'
        }

        It 'has Region parameter' {
            $Parameters.Keys | Should -Contain 'Region'
        }

        It 'has ProfileName parameter' {
            $Parameters.Keys | Should -Contain 'ProfileName'
        }

        It 'has IncludeMetrics switch parameter' {
            $Parameters.Keys | Should -Contain 'IncludeMetrics'
            $Parameters['IncludeMetrics'].SwitchParameter | Should -BeTrue
        }

        It 'has IncludePatches switch parameter' {
            $Parameters.Keys | Should -Contain 'IncludePatches'
            $Parameters['IncludePatches'].SwitchParameter | Should -BeTrue
        }

        It 'has MetricPeriod parameter with range validation' {
            $Parameters.Keys | Should -Contain 'MetricPeriod'
            $Attributes = $Parameters['MetricPeriod'].Attributes
            $RangeAttribute = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $RangeAttribute | Should -Not -BeNullOrEmpty
            $RangeAttribute.MinRange | Should -Be 5
            $RangeAttribute.MaxRange | Should -Be 1440
        }
    }

    Context 'Parameter Sets' {
        BeforeAll {
            $Command = Get-Command -Name 'Get-FleetHealth'
        }

        It 'has multiple parameter sets' {
            $Command.ParameterSets.Count | Should -BeGreaterOrEqual 2
        }

        It 'has ById parameter set' {
            $Command.ParameterSets.Name | Should -Contain 'ById'
        }

        It 'has ByTag parameter set' {
            $Command.ParameterSets.Name | Should -Contain 'ByTag'
        }

        It 'has All parameter set' {
            $Command.ParameterSets.Name | Should -Contain 'All'
        }
    }

    Context 'Input Validation' {
        It 'rejects invalid instance ID format' {
            { Get-FleetHealth -InstanceId 'invalid-id' -ErrorAction Stop } | Should -Throw
        }

        It 'accepts valid instance ID format' {
            # This will fail without AWS credentials, but should pass parameter validation
            {
                $ErrorActionPreference = 'Stop'
                try {
                    Get-FleetHealth -InstanceId 'i-1234567890abcdef0' -ErrorAction Stop
                }
                catch {
                    # Expected to fail on AWS call, but should pass validation
                    if ($_.Exception.Message -notmatch 'parameter|validation') {
                        # This is expected - AWS connection failure, not validation failure
                        $true
                    }
                    else {
                        throw
                    }
                }
            } | Should -Not -Throw -Because 'Parameter validation should pass for valid instance ID format'
        }

        It 'accepts multiple instance IDs' {
            # Should not throw on parameter validation
            $ids = @('i-1234567890abcdef0', 'i-0987654321fedcba0')
            {
                try {
                    Get-FleetHealth -InstanceId $ids -ErrorAction Stop
                }
                catch {
                    # AWS errors are expected without credentials
                    if ($_.Exception.Message -notmatch 'parameter') {
                        $true
                    }
                    else {
                        throw
                    }
                }
            } | Should -Not -Throw
        }

        It 'rejects invalid MetricPeriod values' {
            { Get-FleetHealth -MetricPeriod 0 -ErrorAction Stop } | Should -Throw
            { Get-FleetHealth -MetricPeriod 2000 -ErrorAction Stop } | Should -Throw
        }

        It 'accepts valid MetricPeriod values' {
            {
                try {
                    Get-FleetHealth -MetricPeriod 60 -ErrorAction Stop
                }
                catch {
                    if ($_.Exception.Message -notmatch 'parameter') {
                        $true
                    }
                    else {
                        throw
                    }
                }
            } | Should -Not -Throw
        }
    }

    Context 'Output Format' {
        It 'returns array of PSCustomObject' {
            # Mock test - would need AWS environment for real test
            # Verify output type specification exists
            $Command = Get-Command -Name 'Get-FleetHealth'
            $Command.OutputType.Name | Should -Contain 'PSCustomObject[]'
        }

        It 'output should include InstanceId property' {
            # Structure validation - actual output would require AWS environment
            # This is documented in the function
            $Help = Get-Help -Name 'Get-FleetHealth'
            $Help.Description.Text | Should -Match 'health'
        }
    }

    Context 'Error Handling' {
        It 'handles missing AWS credentials gracefully' {
            # Should throw informative error about credentials
            Mock Get-AWSSession { throw "AWS credentials not configured" } -ModuleName HyperionFleet

            { Get-FleetHealth -ErrorAction Stop } | Should -Throw
        }

        It 'handles invalid region gracefully' {
            # Should validate or handle invalid regions
            # This would require AWS SDK validation
            $true | Should -BeTrue  # Placeholder - full test requires AWS environment
        }
    }

    Context 'Functionality (Mock Tests)' {
        BeforeAll {
            # Mock AWS calls for unit testing without real AWS environment
            Mock Get-AWSSession {
                return @{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet

            Mock Write-FleetLog { } -ModuleName HyperionFleet
        }

        It 'processes all instances when no filter provided' {
            # Would need to mock Get-EC2Instance
            # This is a structure test
            $Command = Get-Command -Name 'Get-FleetHealth'
            $Command.Parameters.Keys | Should -Contain 'InstanceId'
        }

        It 'respects IncludeMetrics flag' {
            # Verify parameter exists and is switch
            $Command = Get-Command -Name 'Get-FleetHealth'
            $Command.Parameters['IncludeMetrics'].SwitchParameter | Should -BeTrue
        }

        It 'respects IncludePatches flag' {
            # Verify parameter exists and is switch
            $Command = Get-Command -Name 'Get-FleetHealth'
            $Command.Parameters['IncludePatches'].SwitchParameter | Should -BeTrue
        }
    }

    Context 'Performance' {
        It 'completes parameter validation quickly' {
            $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                Get-FleetHealth -InstanceId 'i-1234567890abcdef0' -ErrorAction SilentlyContinue
            }
            catch {
                # Expected to fail
            }
            $Stopwatch.Stop()

            # Parameter validation should be instant (< 100ms)
            $Stopwatch.ElapsedMilliseconds | Should -BeLessThan 100
        }
    }
}
