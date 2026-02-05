#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Get-AWSSession private function.

.DESCRIPTION
    Comprehensive unit tests for the Get-AWSSession internal helper function including:
    - Session creation and initialization
    - Credential validation
    - Region handling
    - Role assumption
    - Error handling

.NOTES
    Uses Pester 5.x syntax. Tests internal function by importing module with explicit function access.
#>

BeforeAll {
    $ModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

    # Import the module
    Import-Module (Join-Path -Path $ModulePath -ChildPath 'HyperionFleet.psd1') -Force

    # Get access to private function via InModuleScope
    $script:PrivateFunctionPath = Join-Path -Path $ModulePath -ChildPath 'Private/Get-AWSSession.ps1'

    # Mock STS caller identity response
    $script:MockCallerIdentity = @{
        Arn = 'arn:aws:iam::123456789012:user/test-user'
        UserId = 'AIDAEXAMPLEUSERID'
        Account = '123456789012'
    }

    # Mock assumed role response
    $script:MockAssumedRole = @{
        Credentials = @{
            AccessKeyId = 'ASIATESTACCESSKEY'
            SecretAccessKey = 'testsecretaccesskey123456789'
            SessionToken = 'testsessiontoken123456789'
            Expiration = (Get-Date).AddHours(1)
        }
        AssumedRoleUser = @{
            Arn = 'arn:aws:sts::123456789012:assumed-role/FleetManager/HyperionFleet-session'
            AssumedRoleId = 'AROAEXAMPLEROLE:HyperionFleet-session'
        }
    }
}

AfterAll {
    Remove-Module -Name 'HyperionFleet' -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AWSSession' -Tag 'Unit', 'Private' {
    Context 'Function Structure' {
        It 'private function file exists' {
            $script:PrivateFunctionPath | Should -Exist
        }

        It 'function is not exported' {
            $Module = Get-Module -Name 'HyperionFleet'
            $Module.ExportedCommands.Keys | Should -Not -Contain 'Get-AWSSession'
        }

        It 'function has CmdletBinding attribute' {
            $Content = Get-Content -Path $script:PrivateFunctionPath -Raw
            $Content | Should -Match '\[CmdletBinding\('
        }

        It 'function has OutputType attribute' {
            $Content = Get-Content -Path $script:PrivateFunctionPath -Raw
            $Content | Should -Match '\[OutputType\('
        }

        It 'function has comment-based help' {
            $Content = Get-Content -Path $script:PrivateFunctionPath -Raw
            $Content | Should -Match '\.SYNOPSIS'
            $Content | Should -Match '\.DESCRIPTION'
        }
    }

    Context 'Session Creation' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-STSCallerIdentity { return $script:MockCallerIdentity } -ModuleName HyperionFleet
        }

        It 'creates session with default region' {
            InModuleScope HyperionFleet {
                $Session = Get-AWSSession

                $Session | Should -Not -BeNullOrEmpty
                $Session.Region | Should -Be 'us-east-1'
            }
        }

        It 'creates session with specified region' {
            InModuleScope HyperionFleet {
                $Session = Get-AWSSession -Region 'us-west-2'

                $Session.Region | Should -Be 'us-west-2'
            }
        }

        It 'returns session object with expected properties' {
            InModuleScope HyperionFleet {
                $Session = Get-AWSSession -Region 'us-east-1'

                $Session.PSObject.Properties.Name | Should -Contain 'Region'
                $Session.PSObject.Properties.Name | Should -Contain 'CallerIdentity'
                $Session.PSObject.Properties.Name | Should -Contain 'Timestamp'
            }
        }

        It 'includes caller identity in session' {
            InModuleScope HyperionFleet {
                $Session = Get-AWSSession -Region 'us-east-1'

                $Session.CallerIdentity | Should -Not -BeNullOrEmpty
                $Session.CallerIdentity.Arn | Should -Match 'arn:aws:iam::'
            }
        }

        It 'sets timestamp on session' {
            InModuleScope HyperionFleet {
                $Before = Get-Date
                $Session = Get-AWSSession -Region 'us-east-1'
                $After = Get-Date

                $Session.Timestamp | Should -BeGreaterOrEqual $Before
                $Session.Timestamp | Should -BeLessOrEqual $After
            }
        }
    }

    Context 'Credential Validation' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
        }

        It 'validates credentials by calling Get-STSCallerIdentity' {
            Mock Get-STSCallerIdentity { return $script:MockCallerIdentity } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                Get-AWSSession -Region 'us-east-1'
            }

            Should -Invoke -CommandName Get-STSCallerIdentity -ModuleName HyperionFleet -Times 1
        }

        It 'throws when credentials are invalid' {
            Mock Get-STSCallerIdentity {
                throw [Amazon.SecurityToken.AmazonSecurityTokenServiceException]::new("The security token included in the request is invalid")
            } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                { Get-AWSSession -Region 'us-east-1' -ErrorAction Stop } | Should -Throw
            }
        }

        It 'throws informative error message on credential failure' {
            Mock Get-STSCallerIdentity {
                throw "Unable to find credentials"
            } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                { Get-AWSSession -Region 'us-east-1' -ErrorAction Stop } | Should -Throw -ExpectedMessage '*credential*'
            }
        }

        It 'logs authentication success' {
            Mock Get-STSCallerIdentity { return $script:MockCallerIdentity } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                Get-AWSSession -Region 'us-east-1'
            }

            Should -Invoke -CommandName Write-FleetLog -ModuleName HyperionFleet -ParameterFilter {
                $Message -match 'Authenticated'
            }
        }
    }

    Context 'Profile Support' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-STSCallerIdentity { return $script:MockCallerIdentity } -ModuleName HyperionFleet
        }

        It 'passes ProfileName to STS call' {
            InModuleScope HyperionFleet {
                Get-AWSSession -ProfileName 'production' -Region 'us-east-1'
            }

            Should -Invoke -CommandName Get-STSCallerIdentity -ModuleName HyperionFleet -ParameterFilter {
                $ProfileName -eq 'production'
            }
        }

        It 'includes ProfileName in session object' {
            InModuleScope HyperionFleet {
                $Session = Get-AWSSession -ProfileName 'production' -Region 'us-east-1'

                $Session.ProfileName | Should -Be 'production'
            }
        }

        It 'logs profile usage' {
            InModuleScope HyperionFleet {
                Get-AWSSession -ProfileName 'production' -Region 'us-east-1'
            }

            Should -Invoke -CommandName Write-FleetLog -ModuleName HyperionFleet -ParameterFilter {
                $Message -match 'profile'
            }
        }
    }

    Context 'Region Handling' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-STSCallerIdentity { return $script:MockCallerIdentity } -ModuleName HyperionFleet
        }

        It 'uses module default region when not specified' {
            InModuleScope HyperionFleet {
                $Session = Get-AWSSession

                # Module default is us-east-1
                $Session.Region | Should -Be $script:ModuleConfig.DefaultRegion
            }
        }

        It 'accepts valid AWS region' {
            InModuleScope HyperionFleet {
                $Session = Get-AWSSession -Region 'eu-west-1'

                $Session.Region | Should -Be 'eu-west-1'
            }
        }

        It 'passes region to STS call' {
            InModuleScope HyperionFleet {
                Get-AWSSession -Region 'ap-northeast-1'
            }

            Should -Invoke -CommandName Get-STSCallerIdentity -ModuleName HyperionFleet -ParameterFilter {
                $Region -eq 'ap-northeast-1'
            }
        }
    }

    Context 'Role Assumption' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-STSCallerIdentity { return $script:MockCallerIdentity } -ModuleName HyperionFleet
        }

        It 'calls Use-STSRole when RoleArn is specified' {
            Mock Use-STSRole { return $script:MockAssumedRole } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                Get-AWSSession -RoleArn 'arn:aws:iam::123456789012:role/FleetManager' -Region 'us-east-1'
            }

            Should -Invoke -CommandName Use-STSRole -ModuleName HyperionFleet -Times 1
        }

        It 'passes RoleArn to Use-STSRole' {
            Mock Use-STSRole { return $script:MockAssumedRole } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                Get-AWSSession -RoleArn 'arn:aws:iam::123456789012:role/FleetManager' -Region 'us-east-1'
            }

            Should -Invoke -CommandName Use-STSRole -ModuleName HyperionFleet -ParameterFilter {
                $RoleArn -eq 'arn:aws:iam::123456789012:role/FleetManager'
            }
        }

        It 'includes assumed role credentials in session' {
            Mock Use-STSRole { return $script:MockAssumedRole } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                $Session = Get-AWSSession -RoleArn 'arn:aws:iam::123456789012:role/FleetManager' -Region 'us-east-1'

                $Session.Credential | Should -Not -BeNullOrEmpty
                $Session.AssumedRoleArn | Should -Be 'arn:aws:iam::123456789012:role/FleetManager'
            }
        }

        It 'includes session expiration for assumed role' {
            Mock Use-STSRole { return $script:MockAssumedRole } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                $Session = Get-AWSSession -RoleArn 'arn:aws:iam::123456789012:role/FleetManager' -Region 'us-east-1'

                $Session.SessionExpiration | Should -Not -BeNullOrEmpty
            }
        }

        It 'throws on role assumption failure' {
            Mock Use-STSRole {
                throw [Amazon.SecurityToken.AmazonSecurityTokenServiceException]::new("Access denied")
            } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                {
                    Get-AWSSession -RoleArn 'arn:aws:iam::123456789012:role/FleetManager' -Region 'us-east-1' -ErrorAction Stop
                } | Should -Throw
            }
        }

        It 'logs role assumption' {
            Mock Use-STSRole { return $script:MockAssumedRole } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                Get-AWSSession -RoleArn 'arn:aws:iam::123456789012:role/FleetManager' -Region 'us-east-1'
            }

            Should -Invoke -CommandName Write-FleetLog -ModuleName HyperionFleet -ParameterFilter {
                $Message -match 'Assuming role'
            }
        }
    }

    Context 'RoleArn Validation' {
        It 'rejects invalid RoleArn format' {
            InModuleScope HyperionFleet {
                { Get-AWSSession -RoleArn 'invalid-role-arn' -ErrorAction Stop } | Should -Throw
            }
        }

        It 'accepts valid RoleArn format' {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-STSCallerIdentity { return $script:MockCallerIdentity } -ModuleName HyperionFleet
            Mock Use-STSRole { return $script:MockAssumedRole } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                {
                    Get-AWSSession -RoleArn 'arn:aws:iam::123456789012:role/FleetManager' -Region 'us-east-1'
                } | Should -Not -Throw
            }
        }
    }

    Context 'Session Name' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-STSCallerIdentity { return $script:MockCallerIdentity } -ModuleName HyperionFleet
            Mock Use-STSRole { return $script:MockAssumedRole } -ModuleName HyperionFleet
        }

        It 'uses default session name when not specified' {
            InModuleScope HyperionFleet {
                Get-AWSSession -RoleArn 'arn:aws:iam::123456789012:role/FleetManager' -Region 'us-east-1'
            }

            Should -Invoke -CommandName Use-STSRole -ModuleName HyperionFleet -ParameterFilter {
                $RoleSessionName -match '^HyperionFleet-\d{8}-\d{6}$'
            }
        }

        It 'accepts custom session name' {
            InModuleScope HyperionFleet {
                Get-AWSSession -RoleArn 'arn:aws:iam::123456789012:role/FleetManager' -SessionName 'CustomSession' -Region 'us-east-1'
            }

            Should -Invoke -CommandName Use-STSRole -ModuleName HyperionFleet -ParameterFilter {
                $RoleSessionName -eq 'CustomSession'
            }
        }
    }

    Context 'Error Handling' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
        }

        It 'logs errors before throwing' {
            Mock Get-STSCallerIdentity {
                throw "Network error"
            } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                try {
                    Get-AWSSession -Region 'us-east-1' -ErrorAction Stop
                }
                catch {
                    # Expected
                }
            }

            Should -Invoke -CommandName Write-FleetLog -ModuleName HyperionFleet -ParameterFilter {
                $Level -eq 'Error'
            }
        }

        It 'handles network timeouts gracefully' {
            Mock Get-STSCallerIdentity {
                throw [System.Net.WebException]::new("The operation has timed out")
            } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                { Get-AWSSession -Region 'us-east-1' -ErrorAction Stop } | Should -Throw
            }
        }
    }

    Context 'Verbose Output' {
        BeforeAll {
            Mock Get-STSCallerIdentity { return $script:MockCallerIdentity } -ModuleName HyperionFleet
        }

        It 'logs verbose messages for session initialization' {
            Mock Write-FleetLog { } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                Get-AWSSession -Region 'us-east-1'
            }

            Should -Invoke -CommandName Write-FleetLog -ModuleName HyperionFleet -ParameterFilter {
                $Level -eq 'Verbose'
            }
        }
    }
}
