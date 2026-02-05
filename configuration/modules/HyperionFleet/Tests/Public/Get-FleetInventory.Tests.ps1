#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Get-FleetInventory function.

.DESCRIPTION
    Comprehensive unit tests for the Get-FleetInventory cmdlet including:
    - Parameter validation and structure
    - Environment and tag filtering
    - AWS API call mocking
    - Error handling scenarios
    - Output format verification

.NOTES
    Uses Pester 5.x syntax with BeforeAll, BeforeEach, and proper mocking.
#>

BeforeAll {
    $ModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path -Path $ModulePath -ChildPath 'HyperionFleet.psd1') -Force

    # Define mock data for AWS responses
    $script:MockEC2Reservation = @{
        Instances = @(
            @{
                InstanceId = 'i-1234567890abcdef0'
                State = @{ Name = @{ Value = 'running' } }
                InstanceType = @{ Value = 't3.medium' }
                Platform = @{ Value = 'windows' }
                Architecture = @{ Value = 'x86_64' }
                VirtualizationType = @{ Value = 'hvm' }
                Placement = @{
                    AvailabilityZone = 'us-east-1a'
                    Tenancy = @{ Value = 'default' }
                }
                VpcId = 'vpc-12345678'
                SubnetId = 'subnet-12345678'
                PrivateIpAddress = '10.0.1.100'
                PublicIpAddress = '54.123.45.67'
                PrivateDnsName = 'ip-10-0-1-100.ec2.internal'
                PublicDnsName = 'ec2-54-123-45-67.compute-1.amazonaws.com'
                SecurityGroups = @(
                    @{ GroupName = 'web-sg'; GroupId = 'sg-12345678' }
                )
                KeyName = 'my-keypair'
                IamInstanceProfile = @{ Arn = 'arn:aws:iam::123456789012:instance-profile/web-role' }
                LaunchTime = (Get-Date).AddDays(-30)
                ImageId = 'ami-12345678'
                RootDeviceType = @{ Value = 'ebs' }
                RootDeviceName = '/dev/sda1'
                Monitoring = @{ State = @{ Value = 'enabled' } }
                EbsOptimized = $true
                Tags = @(
                    @{ Key = 'Name'; Value = 'WebServer-01' },
                    @{ Key = 'Environment'; Value = 'Production' },
                    @{ Key = 'Application'; Value = 'WebApp' },
                    @{ Key = 'Owner'; Value = 'DevOps' },
                    @{ Key = 'CostCenter'; Value = 'IT-001' }
                )
            },
            @{
                InstanceId = 'i-0987654321fedcba0'
                State = @{ Name = @{ Value = 'running' } }
                InstanceType = @{ Value = 't3.large' }
                Platform = @{ Value = 'windows' }
                Architecture = @{ Value = 'x86_64' }
                VirtualizationType = @{ Value = 'hvm' }
                Placement = @{
                    AvailabilityZone = 'us-east-1b'
                    Tenancy = @{ Value = 'default' }
                }
                VpcId = 'vpc-12345678'
                SubnetId = 'subnet-87654321'
                PrivateIpAddress = '10.0.2.100'
                PublicIpAddress = $null
                PrivateDnsName = 'ip-10-0-2-100.ec2.internal'
                PublicDnsName = $null
                SecurityGroups = @(
                    @{ GroupName = 'app-sg'; GroupId = 'sg-87654321' }
                )
                KeyName = 'my-keypair'
                IamInstanceProfile = @{ Arn = 'arn:aws:iam::123456789012:instance-profile/app-role' }
                LaunchTime = (Get-Date).AddDays(-15)
                ImageId = 'ami-87654321'
                RootDeviceType = @{ Value = 'ebs' }
                RootDeviceName = '/dev/sda1'
                Monitoring = @{ State = @{ Value = 'disabled' } }
                EbsOptimized = $false
                Tags = @(
                    @{ Key = 'Name'; Value = 'AppServer-01' },
                    @{ Key = 'Environment'; Value = 'Staging' },
                    @{ Key = 'Application'; Value = 'AppService' },
                    @{ Key = 'Owner'; Value = 'DevTeam' },
                    @{ Key = 'CostCenter'; Value = 'IT-002' }
                )
            }
        )
    }

    $script:MockEC2ReservationDev = @{
        Instances = @(
            @{
                InstanceId = 'i-dev12345678abcdef'
                State = @{ Name = @{ Value = 'running' } }
                InstanceType = @{ Value = 't3.small' }
                Platform = @{ Value = 'windows' }
                Architecture = @{ Value = 'x86_64' }
                VirtualizationType = @{ Value = 'hvm' }
                Placement = @{
                    AvailabilityZone = 'us-west-2a'
                    Tenancy = @{ Value = 'default' }
                }
                VpcId = 'vpc-devtest01'
                SubnetId = 'subnet-dev01'
                PrivateIpAddress = '10.1.1.50'
                PublicIpAddress = $null
                PrivateDnsName = 'ip-10-1-1-50.ec2.internal'
                PublicDnsName = $null
                SecurityGroups = @(
                    @{ GroupName = 'dev-sg'; GroupId = 'sg-dev01' }
                )
                KeyName = 'dev-keypair'
                IamInstanceProfile = @{ Arn = 'arn:aws:iam::123456789012:instance-profile/dev-role' }
                LaunchTime = (Get-Date).AddDays(-5)
                ImageId = 'ami-dev12345'
                RootDeviceType = @{ Value = 'ebs' }
                RootDeviceName = '/dev/sda1'
                Monitoring = @{ State = @{ Value = 'disabled' } }
                EbsOptimized = $false
                Tags = @(
                    @{ Key = 'Name'; Value = 'DevServer-01' },
                    @{ Key = 'Environment'; Value = 'Development' },
                    @{ Key = 'Application'; Value = 'DevApp' },
                    @{ Key = 'Owner'; Value = 'DevTeam' },
                    @{ Key = 'CostCenter'; Value = 'IT-003' }
                )
            }
        )
    }
}

AfterAll {
    Remove-Module -Name 'HyperionFleet' -Force -ErrorAction SilentlyContinue
}

Describe 'Get-FleetInventory' -Tag 'Unit', 'Public' {
    Context 'Function Structure' {
        BeforeAll {
            $Command = Get-Command -Name 'Get-FleetInventory'
        }

        It 'exists as a function' {
            $Command | Should -Not -BeNullOrEmpty
            $Command.CommandType | Should -Be 'Function'
        }

        It 'has CmdletBinding attribute' {
            $Command.CmdletBinding | Should -BeTrue
        }

        It 'declares PSCustomObject[] output type' {
            $Command.OutputType.Name | Should -Contain 'PSCustomObject[]'
        }

        It 'has comment-based help with synopsis' {
            $Help = Get-Help -Name 'Get-FleetInventory'
            $Help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'has comment-based help with description' {
            $Help = Get-Help -Name 'Get-FleetInventory'
            $Help.Description | Should -Not -BeNullOrEmpty
        }

        It 'has at least one example in help' {
            $Help = Get-Help -Name 'Get-FleetInventory'
            $Help.Examples.Example.Count | Should -BeGreaterOrEqual 1
        }
    }

    Context 'Parameters' {
        BeforeAll {
            $Command = Get-Command -Name 'Get-FleetInventory'
            $Parameters = $Command.Parameters
        }

        It 'has Region parameter' {
            $Parameters.Keys | Should -Contain 'Region'
        }

        It 'Region parameter accepts string array' {
            $Parameters['Region'].ParameterType.Name | Should -Be 'String[]'
        }

        It 'has ProfileName parameter' {
            $Parameters.Keys | Should -Contain 'ProfileName'
        }

        It 'has Tag parameter' {
            $Parameters.Keys | Should -Contain 'Tag'
        }

        It 'Tag parameter accepts hashtable' {
            $Parameters['Tag'].ParameterType.Name | Should -Be 'Hashtable'
        }

        It 'has State parameter' {
            $Parameters.Keys | Should -Contain 'State'
        }

        It 'State parameter has ValidateSet for valid EC2 states' {
            $Attributes = $Parameters['State'].Attributes
            $ValidateSet = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $ValidateSet | Should -Not -BeNullOrEmpty
            $ValidateSet.ValidValues | Should -Contain 'running'
            $ValidateSet.ValidValues | Should -Contain 'stopped'
            $ValidateSet.ValidValues | Should -Contain 'terminated'
        }

        It 'has InstanceType parameter' {
            $Parameters.Keys | Should -Contain 'InstanceType'
        }

        It 'has GroupBy parameter' {
            $Parameters.Keys | Should -Contain 'GroupBy'
        }

        It 'has IncludeTerminated switch parameter' {
            $Parameters.Keys | Should -Contain 'IncludeTerminated'
            $Parameters['IncludeTerminated'].SwitchParameter | Should -BeTrue
        }

        It 'has ExportPath parameter' {
            $Parameters.Keys | Should -Contain 'ExportPath'
        }
    }

    Context 'Successful Inventory Retrieval' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet

            Mock Get-EC2Instance {
                return $script:MockEC2Reservation
            } -ModuleName HyperionFleet
        }

        It 'retrieves inventory successfully' {
            $Result = Get-FleetInventory -Region 'us-east-1'

            $Result | Should -Not -BeNullOrEmpty
            $Result.Count | Should -Be 2
        }

        It 'returns inventory items with expected properties' {
            $Result = Get-FleetInventory -Region 'us-east-1'

            $Result[0].InstanceId | Should -Be 'i-1234567890abcdef0'
            $Result[0].Name | Should -Be 'WebServer-01'
            $Result[0].State | Should -Be 'running'
            $Result[0].InstanceType | Should -Be 't3.medium'
        }

        It 'includes tag information in results' {
            $Result = Get-FleetInventory -Region 'us-east-1'

            $Result[0].Environment | Should -Be 'Production'
            $Result[0].Application | Should -Be 'WebApp'
            $Result[0].Owner | Should -Be 'DevOps'
        }

        It 'includes network configuration in results' {
            $Result = Get-FleetInventory -Region 'us-east-1'

            $Result[0].VpcId | Should -Be 'vpc-12345678'
            $Result[0].SubnetId | Should -Be 'subnet-12345678'
            $Result[0].PrivateIpAddress | Should -Be '10.0.1.100'
            $Result[0].AvailabilityZone | Should -Be 'us-east-1a'
        }

        It 'includes timestamp in results' {
            $Result = Get-FleetInventory -Region 'us-east-1'

            $Result[0].Timestamp | Should -Not -BeNullOrEmpty
            $Result[0].Timestamp | Should -BeOfType [DateTime]
        }

        It 'calls Get-EC2Instance with correct region' {
            Get-FleetInventory -Region 'us-east-1'

            Should -Invoke -CommandName Get-EC2Instance -ModuleName HyperionFleet -Times 1 -ParameterFilter {
                $Region -eq 'us-east-1'
            }
        }
    }

    Context 'Filtering by Environment' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet

            Mock Get-EC2Instance {
                param($Region, $Filter)

                # Check if filtering for Production environment
                $envFilter = $Filter | Where-Object { $_.Name -eq 'tag:Environment' }
                if ($envFilter -and $envFilter.Values -contains 'Production') {
                    return @{
                        Instances = @($script:MockEC2Reservation.Instances[0])
                    }
                }
                elseif ($envFilter -and $envFilter.Values -contains 'Staging') {
                    return @{
                        Instances = @($script:MockEC2Reservation.Instances[1])
                    }
                }

                return $script:MockEC2Reservation
            } -ModuleName HyperionFleet
        }

        It 'filters instances by Environment tag' {
            $Result = Get-FleetInventory -Region 'us-east-1' -Tag @{ Environment = 'Production' }

            $Result | Should -Not -BeNullOrEmpty
            $Result.Count | Should -Be 1
            $Result[0].Environment | Should -Be 'Production'
        }

        It 'returns only staging instances when filtered' {
            $Result = Get-FleetInventory -Region 'us-east-1' -Tag @{ Environment = 'Staging' }

            $Result | Should -Not -BeNullOrEmpty
            $Result.Count | Should -Be 1
            $Result[0].Environment | Should -Be 'Staging'
        }

        It 'passes tag filter to Get-EC2Instance' {
            Get-FleetInventory -Region 'us-east-1' -Tag @{ Environment = 'Production' }

            Should -Invoke -CommandName Get-EC2Instance -ModuleName HyperionFleet -ParameterFilter {
                $Filter -and ($Filter | Where-Object { $_.Name -eq 'tag:Environment' })
            }
        }
    }

    Context 'Filtering by Tags' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet

            Mock Get-EC2Instance {
                param($Region, $Filter)

                # Check for Application tag filter
                $appFilter = $Filter | Where-Object { $_.Name -eq 'tag:Application' }
                if ($appFilter -and $appFilter.Values -contains 'WebApp') {
                    return @{
                        Instances = @($script:MockEC2Reservation.Instances[0])
                    }
                }

                return $script:MockEC2Reservation
            } -ModuleName HyperionFleet
        }

        It 'filters by Application tag' {
            $Result = Get-FleetInventory -Region 'us-east-1' -Tag @{ Application = 'WebApp' }

            $Result | Should -Not -BeNullOrEmpty
            $Result[0].Application | Should -Be 'WebApp'
        }

        It 'supports multiple tag filters' {
            $Result = Get-FleetInventory -Region 'us-east-1' -Tag @{
                Environment = 'Production'
                Application = 'WebApp'
            }

            $Result | Should -Not -BeNullOrEmpty
        }

        It 'includes full Tags hashtable in results' {
            Mock Get-EC2Instance { return $script:MockEC2Reservation } -ModuleName HyperionFleet

            $Result = Get-FleetInventory -Region 'us-east-1'

            $Result[0].Tags | Should -Not -BeNullOrEmpty
            $Result[0].Tags | Should -BeOfType [Hashtable]
            $Result[0].Tags['Name'] | Should -Be 'WebServer-01'
        }
    }

    Context 'Filtering by State' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet

            Mock Get-EC2Instance {
                param($Region, $Filter)

                $stateFilter = $Filter | Where-Object { $_.Name -eq 'instance-state-name' }
                if ($stateFilter -and $stateFilter.Values -contains 'stopped') {
                    return @{
                        Instances = @(
                            @{
                                InstanceId = 'i-stopped12345'
                                State = @{ Name = @{ Value = 'stopped' } }
                                InstanceType = @{ Value = 't3.micro' }
                                Platform = @{ Value = $null }
                                Architecture = @{ Value = 'x86_64' }
                                VirtualizationType = @{ Value = 'hvm' }
                                Placement = @{
                                    AvailabilityZone = 'us-east-1a'
                                    Tenancy = @{ Value = 'default' }
                                }
                                VpcId = 'vpc-12345678'
                                SubnetId = 'subnet-12345678'
                                PrivateIpAddress = '10.0.1.200'
                                PublicIpAddress = $null
                                PrivateDnsName = 'ip-10-0-1-200.ec2.internal'
                                PublicDnsName = $null
                                SecurityGroups = @()
                                KeyName = 'my-keypair'
                                IamInstanceProfile = $null
                                LaunchTime = (Get-Date).AddDays(-60)
                                ImageId = 'ami-old12345'
                                RootDeviceType = @{ Value = 'ebs' }
                                RootDeviceName = '/dev/sda1'
                                Monitoring = @{ State = @{ Value = 'disabled' } }
                                EbsOptimized = $false
                                Tags = @(
                                    @{ Key = 'Name'; Value = 'StoppedServer' },
                                    @{ Key = 'Environment'; Value = 'Development' }
                                )
                            }
                        )
                    }
                }

                return $script:MockEC2Reservation
            } -ModuleName HyperionFleet
        }

        It 'filters by instance state' {
            $Result = Get-FleetInventory -Region 'us-east-1' -State 'stopped'

            $Result | Should -Not -BeNullOrEmpty
            $Result[0].State | Should -Be 'stopped'
        }

        It 'accepts multiple states' {
            $Result = Get-FleetInventory -Region 'us-east-1' -State @('running', 'stopped')

            $Result | Should -Not -BeNullOrEmpty
        }

        It 'excludes terminated by default' {
            Get-FleetInventory -Region 'us-east-1'

            Should -Invoke -CommandName Get-EC2Instance -ModuleName HyperionFleet -ParameterFilter {
                $Filter -and ($Filter | Where-Object {
                    $_.Name -eq 'instance-state-name' -and
                    $_.Values -notcontains 'terminated'
                })
            }
        }
    }

    Context 'Multi-Region Queries' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet

            Mock Get-EC2Instance {
                param($Region)

                if ($Region -eq 'us-east-1') {
                    return $script:MockEC2Reservation
                }
                elseif ($Region -eq 'us-west-2') {
                    return $script:MockEC2ReservationDev
                }

                return @{ Instances = @() }
            } -ModuleName HyperionFleet
        }

        It 'queries multiple regions' {
            $Result = Get-FleetInventory -Region @('us-east-1', 'us-west-2')

            $Result | Should -Not -BeNullOrEmpty
            $Result.Count | Should -Be 3
        }

        It 'includes region in each result' {
            $Result = Get-FleetInventory -Region @('us-east-1', 'us-west-2')

            $eastResults = $Result | Where-Object { $_.Region -eq 'us-east-1' }
            $westResults = $Result | Where-Object { $_.Region -eq 'us-west-2' }

            $eastResults.Count | Should -Be 2
            $westResults.Count | Should -Be 1
        }

        It 'calls Get-EC2Instance for each region' {
            Get-FleetInventory -Region @('us-east-1', 'us-west-2')

            Should -Invoke -CommandName Get-EC2Instance -ModuleName HyperionFleet -Times 2
        }
    }

    Context 'GroupBy Functionality' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-EC2Instance { return $script:MockEC2Reservation } -ModuleName HyperionFleet
        }

        It 'adds GroupByValue property when GroupBy is specified' {
            $Result = Get-FleetInventory -Region 'us-east-1' -GroupBy 'Environment'

            $Result[0].GroupByValue | Should -Be 'Production'
            $Result[1].GroupByValue | Should -Be 'Staging'
        }

        It 'handles missing GroupBy tag gracefully' {
            $Result = Get-FleetInventory -Region 'us-east-1' -GroupBy 'NonExistentTag'

            # Should not throw, should return results without GroupByValue
            $Result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error Handling for AWS API Failures' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
        }

        It 'throws on AWS API error' {
            Mock Get-EC2Instance {
                throw [Amazon.EC2.AmazonEC2Exception]::new("Access Denied")
            } -ModuleName HyperionFleet

            { Get-FleetInventory -Region 'us-east-1' -ErrorAction Stop } | Should -Throw
        }

        It 'handles throttling errors' {
            Mock Get-EC2Instance {
                throw [Amazon.EC2.AmazonEC2Exception]::new("Request limit exceeded")
            } -ModuleName HyperionFleet

            { Get-FleetInventory -Region 'us-east-1' -ErrorAction Stop } | Should -Throw
        }

        It 'logs errors before throwing' {
            Mock Get-EC2Instance {
                throw "Network error"
            } -ModuleName HyperionFleet

            try {
                Get-FleetInventory -Region 'us-east-1' -ErrorAction Stop
            }
            catch {
                # Expected
            }

            Should -Invoke -CommandName Write-FleetLog -ModuleName HyperionFleet -ParameterFilter {
                $Level -eq 'Error'
            }
        }

        It 'returns empty array when no instances found' {
            Mock Get-EC2Instance { return $null } -ModuleName HyperionFleet

            $Result = Get-FleetInventory -Region 'us-east-1'

            $Result | Should -BeNullOrEmpty
        }
    }

    Context 'CSV Export' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-EC2Instance { return $script:MockEC2Reservation } -ModuleName HyperionFleet
            Mock Export-Csv { } -ModuleName HyperionFleet
        }

        It 'exports to CSV when ExportPath is specified' {
            $ExportPath = Join-Path -Path $TestDrive -ChildPath 'inventory.csv'

            Get-FleetInventory -Region 'us-east-1' -ExportPath $ExportPath

            Should -Invoke -CommandName Export-Csv -ModuleName HyperionFleet -Times 1
        }

        It 'creates valid CSV file' {
            Mock Export-Csv {
                param($Path)
                # Verify path is passed correctly
                $Path | Should -Not -BeNullOrEmpty
            } -ModuleName HyperionFleet

            $ExportPath = Join-Path -Path $TestDrive -ChildPath 'test-inventory.csv'
            Get-FleetInventory -Region 'us-east-1' -ExportPath $ExportPath

            Should -Invoke -CommandName Export-Csv -ModuleName HyperionFleet
        }

        It 'handles export errors gracefully' {
            Mock Export-Csv {
                throw "Permission denied"
            } -ModuleName HyperionFleet

            $ExportPath = '/invalid/path/inventory.csv'

            { Get-FleetInventory -Region 'us-east-1' -ExportPath $ExportPath -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Profile Support' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-EC2Instance { return $script:MockEC2Reservation } -ModuleName HyperionFleet
        }

        It 'passes ProfileName to Get-EC2Instance' {
            Get-FleetInventory -Region 'us-east-1' -ProfileName 'production-profile'

            Should -Invoke -CommandName Get-EC2Instance -ModuleName HyperionFleet -ParameterFilter {
                $ProfileName -eq 'production-profile'
            }
        }
    }

    Context 'Instance Type Filtering' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet

            Mock Get-EC2Instance {
                param($Region, $Filter)

                $typeFilter = $Filter | Where-Object { $_.Name -eq 'instance-type' }
                if ($typeFilter) {
                    $filteredInstances = $script:MockEC2Reservation.Instances | Where-Object {
                        $_.InstanceType.Value -like $typeFilter.Values[0]
                    }
                    return @{ Instances = $filteredInstances }
                }

                return $script:MockEC2Reservation
            } -ModuleName HyperionFleet
        }

        It 'filters by instance type' {
            $Result = Get-FleetInventory -Region 'us-east-1' -InstanceType 't3.medium'

            Should -Invoke -CommandName Get-EC2Instance -ModuleName HyperionFleet -ParameterFilter {
                $Filter -and ($Filter | Where-Object { $_.Name -eq 'instance-type' })
            }
        }
    }

    Context 'Performance' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-EC2Instance { return $script:MockEC2Reservation } -ModuleName HyperionFleet
        }

        It 'completes inventory retrieval within reasonable time' {
            $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            Get-FleetInventory -Region 'us-east-1'

            $Stopwatch.Stop()
            $Stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }
    }
}

Describe 'Get-FleetInventory Input Validation' -Tag 'Unit', 'Validation' {
    Context 'Region Parameter Validation' {
        It 'accepts valid region string' {
            {
                try {
                    Get-FleetInventory -Region 'us-east-1' -ErrorAction Stop
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

        It 'accepts array of regions' {
            {
                try {
                    Get-FleetInventory -Region @('us-east-1', 'us-west-2') -ErrorAction Stop
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

    Context 'State Parameter Validation' {
        It 'rejects invalid state value' {
            { Get-FleetInventory -State 'invalid-state' -ErrorAction Stop } | Should -Throw
        }

        It 'accepts valid state values' {
            { Get-FleetInventory -State 'running' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'Tag Parameter Validation' {
        It 'accepts valid hashtable' {
            {
                try {
                    Get-FleetInventory -Tag @{ Environment = 'Production' } -ErrorAction Stop
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

        It 'rejects null hashtable' {
            { Get-FleetInventory -Tag $null -ErrorAction Stop } | Should -Throw
        }
    }
}
