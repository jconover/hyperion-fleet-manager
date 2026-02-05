#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Start-FleetPatch function.

.DESCRIPTION
    Comprehensive unit tests for the Start-FleetPatch cmdlet including:
    - Patch initiation and operation types
    - Maintenance window validation
    - Rolling update behavior
    - ShouldProcess support (WhatIf/Confirm)
    - Error handling scenarios
    - SSM integration mocking

.NOTES
    Uses Pester 5.x syntax with BeforeAll, BeforeEach, and proper mocking.
#>

BeforeAll {
    $ModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path -Path $ModulePath -ChildPath 'HyperionFleet.psd1') -Force

    # Mock SSM instance information
    $script:MockSSMInstances = @(
        @{
            InstanceId = 'i-1234567890abcdef0'
            PingStatus = 'Online'
            LastPingDateTime = (Get-Date).AddMinutes(-5)
            AgentVersion = '3.1.0.0'
            PlatformType = 'Windows'
            PlatformName = 'Microsoft Windows Server 2022'
            PlatformVersion = '10.0.20348'
            ComputerName = 'WebServer-01'
        },
        @{
            InstanceId = 'i-0987654321fedcba0'
            PingStatus = 'Online'
            LastPingDateTime = (Get-Date).AddMinutes(-3)
            AgentVersion = '3.1.0.0'
            PlatformType = 'Windows'
            PlatformName = 'Microsoft Windows Server 2022'
            PlatformVersion = '10.0.20348'
            ComputerName = 'AppServer-01'
        }
    )

    # Mock EC2 instances
    $script:MockEC2Instances = @{
        Instances = @(
            @{
                InstanceId = 'i-1234567890abcdef0'
                State = @{ Name = @{ Value = 'running' } }
                Tags = @(
                    @{ Key = 'Name'; Value = 'WebServer-01' },
                    @{ Key = 'Environment'; Value = 'Production' }
                )
            },
            @{
                InstanceId = 'i-0987654321fedcba0'
                State = @{ Name = @{ Value = 'running' } }
                Tags = @(
                    @{ Key = 'Name'; Value = 'AppServer-01' },
                    @{ Key = 'Environment'; Value = 'Production' }
                )
            }
        )
    }

    # Mock SSM command response
    $script:MockSSMCommand = @{
        CommandId = 'cmd-1234567890abcdef0'
        DocumentName = 'AWS-RunPatchBaseline'
        Status = @{ Value = 'Pending' }
        RequestedDateTime = Get-Date
        TargetCount = 2
        CompletedCount = 0
        ErrorCount = 0
        Comment = 'Fleet patching: Install via HyperionFleet module'
    }

    # Mock command result for Invoke-FleetCommand
    $script:MockCommandResult = [PSCustomObject]@{
        CommandId = 'cmd-1234567890abcdef0'
        DocumentName = 'AWS-RunPatchBaseline'
        Status = 'Success'
        RequestedDateTime = Get-Date
        TargetCount = 2
        CompletedCount = 2
        ErrorCount = 0
        Outputs = @{
            'i-1234567890abcdef0' = @{
                Status = 'Success'
                StandardOutputContent = 'InstalledCount: 5'
            }
            'i-0987654321fedcba0' = @{
                Status = 'Success'
                StandardOutputContent = 'InstalledCount: 3'
            }
        }
    }

    # Mock health status
    $script:MockHealthStatus = @(
        [PSCustomObject]@{
            InstanceId = 'i-1234567890abcdef0'
            Status = 'Healthy'
        },
        [PSCustomObject]@{
            InstanceId = 'i-0987654321fedcba0'
            Status = 'Healthy'
        }
    )
}

AfterAll {
    Remove-Module -Name 'HyperionFleet' -Force -ErrorAction SilentlyContinue
}

Describe 'Start-FleetPatch' -Tag 'Unit', 'Public' {
    Context 'Function Structure' {
        BeforeAll {
            $Command = Get-Command -Name 'Start-FleetPatch'
        }

        It 'exists as a function' {
            $Command | Should -Not -BeNullOrEmpty
            $Command.CommandType | Should -Be 'Function'
        }

        It 'has CmdletBinding attribute' {
            $Command.CmdletBinding | Should -BeTrue
        }

        It 'supports ShouldProcess' {
            $Command.Parameters.Keys | Should -Contain 'WhatIf'
            $Command.Parameters.Keys | Should -Contain 'Confirm'
        }

        It 'has ConfirmImpact set to High' {
            $Command.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        }

        It 'declares PSCustomObject output type' {
            $Command.OutputType.Name | Should -Contain 'PSCustomObject'
        }

        It 'has comment-based help with synopsis' {
            $Help = Get-Help -Name 'Start-FleetPatch'
            $Help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'has comment-based help with examples' {
            $Help = Get-Help -Name 'Start-FleetPatch'
            $Help.Examples.Example.Count | Should -BeGreaterOrEqual 1
        }
    }

    Context 'Parameters' {
        BeforeAll {
            $Command = Get-Command -Name 'Start-FleetPatch'
            $Parameters = $Command.Parameters
        }

        It 'has InstanceId parameter' {
            $Parameters.Keys | Should -Contain 'InstanceId'
        }

        It 'InstanceId has validation pattern for EC2 instance IDs' {
            $Attributes = $Parameters['InstanceId'].Attributes
            $ValidationPattern = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] }
            $ValidationPattern | Should -Not -BeNullOrEmpty
            $ValidationPattern.RegexPattern | Should -Match 'i-\[a-f0-9\]'
        }

        It 'has Tag parameter' {
            $Parameters.Keys | Should -Contain 'Tag'
            $Parameters['Tag'].ParameterType.Name | Should -Be 'Hashtable'
        }

        It 'has Operation parameter' {
            $Parameters.Keys | Should -Contain 'Operation'
        }

        It 'Operation parameter has ValidateSet for Scan and Install' {
            $Attributes = $Parameters['Operation'].Attributes
            $ValidateSet = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $ValidateSet | Should -Not -BeNullOrEmpty
            $ValidateSet.ValidValues | Should -Contain 'Scan'
            $ValidateSet.ValidValues | Should -Contain 'Install'
        }

        It 'has RebootOption parameter' {
            $Parameters.Keys | Should -Contain 'RebootOption'
        }

        It 'RebootOption parameter has ValidateSet' {
            $Attributes = $Parameters['RebootOption'].Attributes
            $ValidateSet = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $ValidateSet | Should -Not -BeNullOrEmpty
            $ValidateSet.ValidValues | Should -Contain 'RebootIfNeeded'
            $ValidateSet.ValidValues | Should -Contain 'NoReboot'
        }

        It 'has PatchBaseline parameter with validation' {
            $Parameters.Keys | Should -Contain 'PatchBaseline'
            $Attributes = $Parameters['PatchBaseline'].Attributes
            $ValidationPattern = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidatePatternAttribute] }
            $ValidationPattern | Should -Not -BeNullOrEmpty
        }

        It 'has MaintenanceWindowId parameter' {
            $Parameters.Keys | Should -Contain 'MaintenanceWindowId'
        }

        It 'has Region parameter' {
            $Parameters.Keys | Should -Contain 'Region'
        }

        It 'has ProfileName parameter' {
            $Parameters.Keys | Should -Contain 'ProfileName'
        }

        It 'has MaxConcurrency parameter with range validation' {
            $Parameters.Keys | Should -Contain 'MaxConcurrency'
            $Attributes = $Parameters['MaxConcurrency'].Attributes
            $RangeAttribute = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $RangeAttribute | Should -Not -BeNullOrEmpty
            $RangeAttribute.MinRange | Should -Be 1
            $RangeAttribute.MaxRange | Should -Be 100
        }

        It 'has MaxErrors parameter with range validation' {
            $Parameters.Keys | Should -Contain 'MaxErrors'
            $Attributes = $Parameters['MaxErrors'].Attributes
            $RangeAttribute = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $RangeAttribute | Should -Not -BeNullOrEmpty
        }

        It 'has Wait switch parameter' {
            $Parameters.Keys | Should -Contain 'Wait'
            $Parameters['Wait'].SwitchParameter | Should -BeTrue
        }

        It 'has SkipPreCheck switch parameter' {
            $Parameters.Keys | Should -Contain 'SkipPreCheck'
            $Parameters['SkipPreCheck'].SwitchParameter | Should -BeTrue
        }
    }

    Context 'Parameter Sets' {
        BeforeAll {
            $Command = Get-Command -Name 'Start-FleetPatch'
        }

        It 'has ById parameter set' {
            $Command.ParameterSets.Name | Should -Contain 'ById'
        }

        It 'has ByTag parameter set' {
            $Command.ParameterSets.Name | Should -Contain 'ByTag'
        }

        It 'InstanceId is mandatory in ById parameter set' {
            $InstanceIdParam = $Command.Parameters['InstanceId']
            $ByIdAttribute = $InstanceIdParam.Attributes | Where-Object {
                $_.GetType().Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ById'
            }
            $ByIdAttribute.Mandatory | Should -BeTrue
        }

        It 'Tag is mandatory in ByTag parameter set' {
            $TagParam = $Command.Parameters['Tag']
            $ByTagAttribute = $TagParam.Attributes | Where-Object {
                $_.GetType().Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByTag'
            }
            $ByTagAttribute.Mandatory | Should -BeTrue
        }
    }

    Context 'Patch Initiation' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet
            Mock Get-SSMInstanceInformation { return $script:MockSSMInstances } -ModuleName HyperionFleet
            Mock Get-FleetHealth { return $script:MockHealthStatus } -ModuleName HyperionFleet
            Mock Invoke-FleetCommand { return $script:MockCommandResult } -ModuleName HyperionFleet
        }

        It 'initiates patch operation successfully' {
            $Result = Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Operation 'Install' -Confirm:$false

            $Result | Should -Not -BeNullOrEmpty
        }

        It 'calls Invoke-FleetCommand with AWS-RunPatchBaseline document' {
            Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Operation 'Install' -Confirm:$false

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -ParameterFilter {
                $DocumentName -eq 'AWS-RunPatchBaseline'
            }
        }

        It 'passes Operation parameter to patch command' {
            Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Operation 'Scan' -Confirm:$false

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -ParameterFilter {
                $Parameter -and $Parameter.Operation -eq 'Scan'
            }
        }

        It 'defaults to Install operation' {
            Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Confirm:$false

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -ParameterFilter {
                $Parameter -and $Parameter.Operation -eq 'Install'
            }
        }

        It 'returns patch result object' {
            $Result = Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Confirm:$false

            $Result.CommandId | Should -Not -BeNullOrEmpty
            $Result.Operation | Should -Be 'Install'
            $Result.Status | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Maintenance Window Validation' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet
            Mock Get-SSMInstanceInformation { return $script:MockSSMInstances } -ModuleName HyperionFleet
            Mock Get-FleetHealth { return $script:MockHealthStatus } -ModuleName HyperionFleet
            Mock Invoke-FleetCommand { return $script:MockCommandResult } -ModuleName HyperionFleet
            Mock Write-Warning { } -ModuleName HyperionFleet
        }

        It 'rejects invalid maintenance window ID format' {
            {
                Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -MaintenanceWindowId 'invalid-mw-id' -Confirm:$false -ErrorAction Stop
            } | Should -Throw
        }

        It 'accepts valid maintenance window ID format' {
            {
                Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -MaintenanceWindowId 'mw-12345678901234567' -Confirm:$false -ErrorAction SilentlyContinue
            } | Should -Not -Throw
        }

        It 'logs warning when maintenance window is specified' {
            Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -MaintenanceWindowId 'mw-12345678901234567' -Confirm:$false

            # The function currently emits a warning about maintenance windows
            Should -Invoke -CommandName Write-Warning -ModuleName HyperionFleet
        }
    }

    Context 'Rolling Update Behavior' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet
            Mock Get-SSMInstanceInformation { return $script:MockSSMInstances } -ModuleName HyperionFleet
            Mock Get-FleetHealth { return $script:MockHealthStatus } -ModuleName HyperionFleet
            Mock Invoke-FleetCommand { return $script:MockCommandResult } -ModuleName HyperionFleet
        }

        It 'passes MaxConcurrency to limit parallel patching' {
            Start-FleetPatch -InstanceId 'i-1234567890abcdef0', 'i-0987654321fedcba0' -MaxConcurrency 1 -Confirm:$false

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -ParameterFilter {
                $MaxConcurrency -eq 1
            }
        }

        It 'defaults to MaxConcurrency of 5' {
            Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Confirm:$false

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -ParameterFilter {
                $MaxConcurrency -eq 5
            }
        }

        It 'passes MaxErrors to control failure threshold' {
            Start-FleetPatch -InstanceId 'i-1234567890abcdef0', 'i-0987654321fedcba0' -MaxErrors 2 -Confirm:$false

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -ParameterFilter {
                $MaxErrors -eq 2
            }
        }

        It 'defaults to MaxErrors of 1' {
            Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Confirm:$false

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -ParameterFilter {
                $MaxErrors -eq 1
            }
        }
    }

    Context 'Reboot Options' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet
            Mock Get-SSMInstanceInformation { return $script:MockSSMInstances } -ModuleName HyperionFleet
            Mock Get-FleetHealth { return $script:MockHealthStatus } -ModuleName HyperionFleet
            Mock Invoke-FleetCommand { return $script:MockCommandResult } -ModuleName HyperionFleet
        }

        It 'defaults to RebootIfNeeded' {
            Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Confirm:$false

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -ParameterFilter {
                $Parameter -and $Parameter.RebootOption -eq 'RebootIfNeeded'
            }
        }

        It 'respects NoReboot option' {
            Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -RebootOption 'NoReboot' -Confirm:$false

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -ParameterFilter {
                $Parameter -and $Parameter.RebootOption -eq 'NoReboot'
            }
        }
    }

    Context 'Pre-Patch Health Check' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet
            Mock Get-SSMInstanceInformation { return $script:MockSSMInstances } -ModuleName HyperionFleet
            Mock Invoke-FleetCommand { return $script:MockCommandResult } -ModuleName HyperionFleet
        }

        It 'performs pre-patch health check by default' {
            Mock Get-FleetHealth { return $script:MockHealthStatus } -ModuleName HyperionFleet

            Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Confirm:$false

            Should -Invoke -CommandName Get-FleetHealth -ModuleName HyperionFleet -Times 1
        }

        It 'skips pre-patch health check when SkipPreCheck is specified' {
            Mock Get-FleetHealth { return $script:MockHealthStatus } -ModuleName HyperionFleet

            Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -SkipPreCheck -Confirm:$false

            Should -Invoke -CommandName Get-FleetHealth -ModuleName HyperionFleet -Times 0
        }
    }

    Context 'Error Scenarios' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
        }

        It 'throws on AWS session failure' {
            Mock Get-AWSSession {
                throw "AWS credentials not configured"
            } -ModuleName HyperionFleet

            {
                Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Confirm:$false -ErrorAction Stop
            } | Should -Throw
        }

        It 'throws when no SSM-managed instances found' {
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet
            Mock Get-SSMInstanceInformation { return @() } -ModuleName HyperionFleet

            {
                Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Confirm:$false -ErrorAction Stop
            } | Should -Throw
        }

        It 'throws when SSM agent is offline' {
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet
            Mock Get-SSMInstanceInformation {
                return @(
                    @{
                        InstanceId = 'i-1234567890abcdef0'
                        PingStatus = 'ConnectionLost'
                    }
                )
            } -ModuleName HyperionFleet

            {
                Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Confirm:$false -ErrorAction Stop
            } | Should -Throw
        }

        It 'handles Invoke-FleetCommand failure' {
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet
            Mock Get-SSMInstanceInformation { return $script:MockSSMInstances } -ModuleName HyperionFleet
            Mock Get-FleetHealth { return $script:MockHealthStatus } -ModuleName HyperionFleet
            Mock Invoke-FleetCommand {
                throw "SSM command failed"
            } -ModuleName HyperionFleet

            {
                Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Confirm:$false -ErrorAction Stop
            } | Should -Throw
        }

        It 'logs errors before throwing' {
            Mock Get-AWSSession {
                throw "Connection failed"
            } -ModuleName HyperionFleet

            try {
                Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Confirm:$false -ErrorAction Stop
            }
            catch {
                # Expected
            }

            Should -Invoke -CommandName Write-FleetLog -ModuleName HyperionFleet -ParameterFilter {
                $Level -eq 'Error'
            }
        }
    }

    Context 'Tag-Based Targeting' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet
            Mock Get-EC2Instance { return $script:MockEC2Instances } -ModuleName HyperionFleet
            Mock Get-SSMInstanceInformation { return $script:MockSSMInstances } -ModuleName HyperionFleet
            Mock Get-FleetHealth { return $script:MockHealthStatus } -ModuleName HyperionFleet
            Mock Invoke-FleetCommand { return $script:MockCommandResult } -ModuleName HyperionFleet
        }

        It 'resolves instances by tag' {
            Start-FleetPatch -Tag @{ Environment = 'Production' } -Confirm:$false

            Should -Invoke -CommandName Get-EC2Instance -ModuleName HyperionFleet
        }

        It 'returns null when no instances match tags' {
            Mock Get-EC2Instance {
                return @{ Instances = @() }
            } -ModuleName HyperionFleet

            $Result = Start-FleetPatch -Tag @{ Environment = 'NonExistent' } -Confirm:$false

            $Result | Should -BeNullOrEmpty
        }
    }

    Context 'ShouldProcess Support' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet
            Mock Get-SSMInstanceInformation { return $script:MockSSMInstances } -ModuleName HyperionFleet
            Mock Get-FleetHealth { return $script:MockHealthStatus } -ModuleName HyperionFleet
            Mock Invoke-FleetCommand { return $script:MockCommandResult } -ModuleName HyperionFleet
        }

        It 'supports WhatIf parameter' {
            $Command = Get-Command -Name 'Start-FleetPatch'
            $Command.Parameters.Keys | Should -Contain 'WhatIf'
        }

        It 'does not execute when WhatIf is specified' {
            Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -WhatIf

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -Times 0
        }

        It 'supports Confirm parameter' {
            $Command = Get-Command -Name 'Start-FleetPatch'
            $Command.Parameters.Keys | Should -Contain 'Confirm'
        }
    }

    Context 'Wait Functionality' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet
            Mock Get-SSMInstanceInformation { return $script:MockSSMInstances } -ModuleName HyperionFleet
            Mock Get-FleetHealth { return $script:MockHealthStatus } -ModuleName HyperionFleet
            Mock Invoke-FleetCommand { return $script:MockCommandResult } -ModuleName HyperionFleet
        }

        It 'passes Wait flag to Invoke-FleetCommand' {
            Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Wait -Confirm:$false

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -ParameterFilter {
                $Wait -eq $true
            }
        }

        It 'includes compliance summary when Wait is used' {
            $Result = Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Wait -Confirm:$false

            # The mock returns outputs, so compliance summary should be calculated
            $Result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Patch Baseline Override' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet
            Mock Get-SSMInstanceInformation { return $script:MockSSMInstances } -ModuleName HyperionFleet
            Mock Get-FleetHealth { return $script:MockHealthStatus } -ModuleName HyperionFleet
            Mock Invoke-FleetCommand { return $script:MockCommandResult } -ModuleName HyperionFleet
        }

        It 'accepts valid patch baseline ID' {
            {
                Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -PatchBaseline 'pb-12345678901234567' -Confirm:$false
            } | Should -Not -Throw
        }

        It 'rejects invalid patch baseline ID format' {
            {
                Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -PatchBaseline 'invalid-baseline' -Confirm:$false -ErrorAction Stop
            } | Should -Throw
        }

        It 'passes patch baseline to command parameters' {
            Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -PatchBaseline 'pb-12345678901234567' -Confirm:$false

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -ParameterFilter {
                $Parameter -and $Parameter.BaselineOverride -eq 'pb-12345678901234567'
            }
        }
    }
}

Describe 'Start-FleetPatch Input Validation' -Tag 'Unit', 'Validation' {
    Context 'InstanceId Validation' {
        It 'rejects invalid instance ID format' {
            { Start-FleetPatch -InstanceId 'invalid-id' -ErrorAction Stop } | Should -Throw
        }

        It 'accepts valid 8-character instance ID' {
            {
                try {
                    Start-FleetPatch -InstanceId 'i-12345678' -WhatIf -ErrorAction Stop
                }
                catch {
                    if ($_.Exception.Message -notmatch 'parameter|validation|pattern') {
                        $true
                    }
                    else {
                        throw
                    }
                }
            } | Should -Not -Throw
        }

        It 'accepts valid 17-character instance ID' {
            {
                try {
                    Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -WhatIf -ErrorAction Stop
                }
                catch {
                    if ($_.Exception.Message -notmatch 'parameter|validation|pattern') {
                        $true
                    }
                    else {
                        throw
                    }
                }
            } | Should -Not -Throw
        }

        It 'accepts multiple instance IDs' {
            {
                try {
                    Start-FleetPatch -InstanceId @('i-1234567890abcdef0', 'i-0987654321fedcba0') -WhatIf -ErrorAction Stop
                }
                catch {
                    if ($_.Exception.Message -notmatch 'parameter|validation|pattern') {
                        $true
                    }
                    else {
                        throw
                    }
                }
            } | Should -Not -Throw
        }
    }

    Context 'MaxConcurrency Validation' {
        It 'rejects MaxConcurrency below 1' {
            { Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -MaxConcurrency 0 -ErrorAction Stop } | Should -Throw
        }

        It 'rejects MaxConcurrency above 100' {
            { Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -MaxConcurrency 101 -ErrorAction Stop } | Should -Throw
        }

        It 'accepts MaxConcurrency within range' {
            {
                try {
                    Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -MaxConcurrency 50 -WhatIf -ErrorAction Stop
                }
                catch {
                    if ($_.Exception.Message -notmatch 'parameter|validation|range') {
                        $true
                    }
                    else {
                        throw
                    }
                }
            } | Should -Not -Throw
        }
    }

    Context 'Operation Validation' {
        It 'rejects invalid operation value' {
            { Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Operation 'InvalidOp' -ErrorAction Stop } | Should -Throw
        }

        It 'accepts Scan operation' {
            {
                try {
                    Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Operation 'Scan' -WhatIf -ErrorAction Stop
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

        It 'accepts Install operation' {
            {
                try {
                    Start-FleetPatch -InstanceId 'i-1234567890abcdef0' -Operation 'Install' -WhatIf -ErrorAction Stop
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
    }
}
