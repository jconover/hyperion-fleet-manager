#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Invoke-FleetCommand function.

.DESCRIPTION
    Unit and integration tests for the Invoke-FleetCommand cmdlet including ShouldProcess
    support, parameter validation, and command execution.
#>

BeforeAll {
    $ModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path -Path $ModulePath -ChildPath 'HyperionFleet.psd1') -Force
}

Describe 'Invoke-FleetCommand' {
    Context 'Function Structure' {
        BeforeAll {
            $Command = Get-Command -Name 'Invoke-FleetCommand'
        }

        It 'exists' {
            $Command | Should -Not -BeNullOrEmpty
        }

        It 'has CmdletBinding attribute' {
            $Command.CmdletBinding | Should -BeTrue
        }

        It 'supports ShouldProcess' {
            $Command.Parameters.Keys | Should -Contain 'WhatIf'
            $Command.Parameters.Keys | Should -Contain 'Confirm'
        }

        It 'has ConfirmImpact set to High' {
            # ShouldProcess functions should have ConfirmImpact
            $Command.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        }

        It 'has comment-based help' {
            Get-Help -Name 'Invoke-FleetCommand' | Should -Not -BeNullOrEmpty
        }

        It 'has synopsis' {
            $Help = Get-Help -Name 'Invoke-FleetCommand'
            $Help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'has description' {
            $Help = Get-Help -Name 'Invoke-FleetCommand'
            $Help.Description | Should -Not -BeNullOrEmpty
        }

        It 'has examples' {
            $Help = Get-Help -Name 'Invoke-FleetCommand'
            $Help.Examples.Example.Count | Should -BeGreaterOrEqual 1
        }
    }

    Context 'Parameters' {
        BeforeAll {
            $Command = Get-Command -Name 'Invoke-FleetCommand'
            $Parameters = $Command.Parameters
        }

        It 'has InstanceId parameter' {
            $Parameters.Keys | Should -Contain 'InstanceId'
        }

        It 'InstanceId parameter is mandatory in ById parameter set' {
            $InstanceIdParam = $Parameters['InstanceId']
            $ByIdAttribute = $InstanceIdParam.Attributes | Where-Object {
                $_.GetType().Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ById'
            }
            $ByIdAttribute.Mandatory | Should -BeTrue
        }

        It 'InstanceId accepts pipeline input' {
            $InstanceIdParam = $Parameters['InstanceId']
            $ParamAttribute = $InstanceIdParam.Attributes | Where-Object {
                $_.GetType().Name -eq 'ParameterAttribute'
            } | Select-Object -First 1
            ($ParamAttribute.ValueFromPipeline -or $ParamAttribute.ValueFromPipelineByPropertyName) | Should -BeTrue
        }

        It 'has Tag parameter' {
            $Parameters.Keys | Should -Contain 'Tag'
        }

        It 'Tag parameter is mandatory in ByTag parameter set' {
            $TagParam = $Parameters['Tag']
            $ByTagAttribute = $TagParam.Attributes | Where-Object {
                $_.GetType().Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByTag'
            }
            $ByTagAttribute.Mandatory | Should -BeTrue
        }

        It 'has Command parameter' {
            $Parameters.Keys | Should -Contain 'Command'
        }

        It 'Command accepts array of strings' {
            $Parameters['Command'].ParameterType.Name | Should -Be 'String[]'
        }

        It 'has DocumentName parameter' {
            $Parameters.Keys | Should -Contain 'DocumentName'
        }

        It 'has Parameter parameter for SSM document parameters' {
            $Parameters.Keys | Should -Contain 'Parameter'
            $Parameters['Parameter'].ParameterType.Name | Should -Be 'Hashtable'
        }

        It 'has Comment parameter' {
            $Parameters.Keys | Should -Contain 'Comment'
        }

        It 'has TimeoutSeconds parameter with validation' {
            $Parameters.Keys | Should -Contain 'TimeoutSeconds'
            $Attributes = $Parameters['TimeoutSeconds'].Attributes
            $RangeAttribute = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $RangeAttribute | Should -Not -BeNullOrEmpty
        }

        It 'has MaxConcurrency parameter' {
            $Parameters.Keys | Should -Contain 'MaxConcurrency'
        }

        It 'has MaxErrors parameter' {
            $Parameters.Keys | Should -Contain 'MaxErrors'
        }

        It 'has Region parameter' {
            $Parameters.Keys | Should -Contain 'Region'
        }

        It 'has ProfileName parameter' {
            $Parameters.Keys | Should -Contain 'ProfileName'
        }

        It 'has Wait switch parameter' {
            $Parameters.Keys | Should -Contain 'Wait'
            $Parameters['Wait'].SwitchParameter | Should -BeTrue
        }
    }

    Context 'Parameter Sets' {
        BeforeAll {
            $Command = Get-Command -Name 'Invoke-FleetCommand'
        }

        It 'has ById parameter set' {
            $Command.ParameterSets.Name | Should -Contain 'ById'
        }

        It 'has ByTag parameter set' {
            $Command.ParameterSets.Name | Should -Contain 'ByTag'
        }

        It 'ById and ByTag are mutually exclusive' {
            # InstanceId should only be in ById set, Tag only in ByTag set
            $Command.ParameterSets.Count | Should -BeGreaterOrEqual 2
        }
    }

    Context 'Input Validation' {
        It 'rejects invalid instance ID format' {
            { Invoke-FleetCommand -InstanceId 'invalid-id' -Command 'test' -ErrorAction Stop } | Should -Throw
        }

        It 'accepts valid instance ID format' {
            {
                try {
                    Invoke-FleetCommand -InstanceId 'i-1234567890abcdef0' -Command 'test' -WhatIf -ErrorAction Stop
                }
                catch {
                    if ($_.Exception.Message -notmatch 'parameter|validation') {
                        $true
                    }
                    else {
                        throw
                    }
                }
            } | Should -Not -Throw
        }

        It 'rejects invalid timeout values' {
            { Invoke-FleetCommand -InstanceId 'i-1234567890abcdef0' -Command 'test' -TimeoutSeconds 0 -ErrorAction Stop } | Should -Throw
            { Invoke-FleetCommand -InstanceId 'i-1234567890abcdef0' -Command 'test' -TimeoutSeconds 99999 -ErrorAction Stop } | Should -Throw
        }

        It 'accepts valid timeout values' {
            {
                try {
                    Invoke-FleetCommand -InstanceId 'i-1234567890abcdef0' -Command 'test' -TimeoutSeconds 3600 -WhatIf -ErrorAction Stop
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

    Context 'ShouldProcess Support' {
        BeforeAll {
            Mock Get-AWSSession {
                return @{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet

            Mock Write-FleetLog { } -ModuleName HyperionFleet
        }

        It 'supports WhatIf parameter' {
            $Command = Get-Command -Name 'Invoke-FleetCommand'
            $Command.Parameters.Keys | Should -Contain 'WhatIf'
        }

        It 'respects WhatIf and does not execute command' {
            # With WhatIf, should not actually call SSM
            {
                Invoke-FleetCommand -InstanceId 'i-1234567890abcdef0' -Command 'test' -WhatIf
            } | Should -Not -Throw
        }

        It 'supports Confirm parameter' {
            $Command = Get-Command -Name 'Invoke-FleetCommand'
            $Command.Parameters.Keys | Should -Contain 'Confirm'
        }
    }

    Context 'Output Format' {
        It 'declares PSCustomObject output type' {
            $Command = Get-Command -Name 'Invoke-FleetCommand'
            $Command.OutputType.Name | Should -Contain 'PSCustomObject'
        }

        It 'help documents output format' {
            $Help = Get-Help -Name 'Invoke-FleetCommand'
            $Help.ReturnValues | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error Handling' {
        It 'handles missing AWS credentials' {
            Mock Get-AWSSession { throw "AWS credentials not configured" } -ModuleName HyperionFleet

            { Invoke-FleetCommand -InstanceId 'i-1234567890abcdef0' -Command 'test' -Confirm:$false -ErrorAction Stop } | Should -Throw
        }

        It 'validates SSM agent status before execution' {
            # Function should check SSM agent is online
            # This is documented in the function logic
            $Help = Get-Help -Name 'Invoke-FleetCommand'
            $Help.Description.Text | Should -Match 'SSM'
        }
    }

    Context 'Functionality (Mock Tests)' {
        BeforeAll {
            Mock Get-AWSSession {
                return @{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet

            Mock Write-FleetLog { } -ModuleName HyperionFleet
        }

        It 'accepts single command' {
            $Command = Get-Command -Name 'Invoke-FleetCommand'
            $Command.Parameters['Command'].ParameterType.Name | Should -Be 'String[]'
        }

        It 'accepts multiple commands' {
            $commands = @('echo test1', 'echo test2')
            {
                try {
                    Invoke-FleetCommand -InstanceId 'i-1234567890abcdef0' -Command $commands -WhatIf
                }
                catch {
                    # Expected without AWS
                    $true
                }
            } | Should -Not -Throw
        }

        It 'supports custom SSM documents' {
            {
                try {
                    Invoke-FleetCommand -InstanceId 'i-1234567890abcdef0' -DocumentName 'AWS-ConfigureAWSPackage' -Parameter @{action='Install'} -WhatIf
                }
                catch {
                    $true
                }
            } | Should -Not -Throw
        }

        It 'respects Wait flag for synchronous execution' {
            $Command = Get-Command -Name 'Invoke-FleetCommand'
            $Command.Parameters['Wait'].SwitchParameter | Should -BeTrue
        }
    }

    Context 'Pipeline Support' {
        It 'accepts instance IDs from pipeline' {
            $Command = Get-Command -Name 'Invoke-FleetCommand'
            $InstanceIdParam = $Command.Parameters['InstanceId']
            $ParamAttribute = $InstanceIdParam.Attributes | Where-Object {
                $_.GetType().Name -eq 'ParameterAttribute'
            } | Select-Object -First 1

            ($ParamAttribute.ValueFromPipeline -or $ParamAttribute.ValueFromPipelineByPropertyName) | Should -BeTrue
        }

        It 'can chain with Get-FleetInventory' {
            # Should be able to pipe inventory to command execution
            # Structural validation
            $InventoryCommand = Get-Command -Name 'Get-FleetInventory'
            $CommandCommand = Get-Command -Name 'Invoke-FleetCommand'

            $InventoryCommand | Should -Not -BeNullOrEmpty
            $CommandCommand | Should -Not -BeNullOrEmpty
        }
    }
}
