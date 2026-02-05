#Requires -Modules Pester

<#
.SYNOPSIS
    Integration tests for HyperionFleet module.

.DESCRIPTION
    Integration tests that verify end-to-end functionality of the HyperionFleet module.
    These tests use TestDrive for file system operations and comprehensive mocks
    for AWS service calls.

    Integration tests are tagged and excluded from normal test runs. Run with:
    Invoke-Pester -Tag 'Integration'

.NOTES
    Uses Pester 5.x syntax.
    These tests require more setup but provide higher confidence in module behavior.
#>

BeforeAll {
    $ModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path -Path $ModulePath -ChildPath 'HyperionFleet.psd1') -Force

    # Create comprehensive mock data representing a realistic fleet
    $script:MockFleetData = @{
        Instances = @(
            @{
                InstanceId = 'i-prod-web-001'
                State = @{ Name = @{ Value = 'running' } }
                InstanceType = @{ Value = 't3.large' }
                Platform = @{ Value = 'windows' }
                Architecture = @{ Value = 'x86_64' }
                VirtualizationType = @{ Value = 'hvm' }
                Placement = @{
                    AvailabilityZone = 'us-east-1a'
                    Tenancy = @{ Value = 'default' }
                }
                VpcId = 'vpc-prod-001'
                SubnetId = 'subnet-prod-web-1a'
                PrivateIpAddress = '10.0.1.10'
                PublicIpAddress = '54.100.1.10'
                PrivateDnsName = 'ip-10-0-1-10.ec2.internal'
                PublicDnsName = 'ec2-54-100-1-10.compute-1.amazonaws.com'
                SecurityGroups = @(
                    @{ GroupName = 'prod-web-sg'; GroupId = 'sg-prod-web-001' }
                )
                KeyName = 'prod-keypair'
                IamInstanceProfile = @{ Arn = 'arn:aws:iam::123456789012:instance-profile/prod-web-role' }
                LaunchTime = (Get-Date).AddDays(-90)
                ImageId = 'ami-prod-windows-2022'
                RootDeviceType = @{ Value = 'ebs' }
                RootDeviceName = '/dev/sda1'
                Monitoring = @{ State = @{ Value = 'enabled' } }
                EbsOptimized = $true
                Tags = @(
                    @{ Key = 'Name'; Value = 'prod-web-001' },
                    @{ Key = 'Environment'; Value = 'Production' },
                    @{ Key = 'Application'; Value = 'WebFrontend' },
                    @{ Key = 'Owner'; Value = 'WebTeam' },
                    @{ Key = 'CostCenter'; Value = 'CC-PROD-001' },
                    @{ Key = 'PatchGroup'; Value = 'prod-web' }
                )
            },
            @{
                InstanceId = 'i-prod-web-002'
                State = @{ Name = @{ Value = 'running' } }
                InstanceType = @{ Value = 't3.large' }
                Platform = @{ Value = 'windows' }
                Architecture = @{ Value = 'x86_64' }
                VirtualizationType = @{ Value = 'hvm' }
                Placement = @{
                    AvailabilityZone = 'us-east-1b'
                    Tenancy = @{ Value = 'default' }
                }
                VpcId = 'vpc-prod-001'
                SubnetId = 'subnet-prod-web-1b'
                PrivateIpAddress = '10.0.2.10'
                PublicIpAddress = '54.100.2.10'
                PrivateDnsName = 'ip-10-0-2-10.ec2.internal'
                PublicDnsName = 'ec2-54-100-2-10.compute-1.amazonaws.com'
                SecurityGroups = @(
                    @{ GroupName = 'prod-web-sg'; GroupId = 'sg-prod-web-001' }
                )
                KeyName = 'prod-keypair'
                IamInstanceProfile = @{ Arn = 'arn:aws:iam::123456789012:instance-profile/prod-web-role' }
                LaunchTime = (Get-Date).AddDays(-90)
                ImageId = 'ami-prod-windows-2022'
                RootDeviceType = @{ Value = 'ebs' }
                RootDeviceName = '/dev/sda1'
                Monitoring = @{ State = @{ Value = 'enabled' } }
                EbsOptimized = $true
                Tags = @(
                    @{ Key = 'Name'; Value = 'prod-web-002' },
                    @{ Key = 'Environment'; Value = 'Production' },
                    @{ Key = 'Application'; Value = 'WebFrontend' },
                    @{ Key = 'Owner'; Value = 'WebTeam' },
                    @{ Key = 'CostCenter'; Value = 'CC-PROD-001' },
                    @{ Key = 'PatchGroup'; Value = 'prod-web' }
                )
            },
            @{
                InstanceId = 'i-prod-app-001'
                State = @{ Name = @{ Value = 'running' } }
                InstanceType = @{ Value = 'm5.xlarge' }
                Platform = @{ Value = 'windows' }
                Architecture = @{ Value = 'x86_64' }
                VirtualizationType = @{ Value = 'hvm' }
                Placement = @{
                    AvailabilityZone = 'us-east-1a'
                    Tenancy = @{ Value = 'default' }
                }
                VpcId = 'vpc-prod-001'
                SubnetId = 'subnet-prod-app-1a'
                PrivateIpAddress = '10.0.10.10'
                PublicIpAddress = $null
                PrivateDnsName = 'ip-10-0-10-10.ec2.internal'
                PublicDnsName = $null
                SecurityGroups = @(
                    @{ GroupName = 'prod-app-sg'; GroupId = 'sg-prod-app-001' }
                )
                KeyName = 'prod-keypair'
                IamInstanceProfile = @{ Arn = 'arn:aws:iam::123456789012:instance-profile/prod-app-role' }
                LaunchTime = (Get-Date).AddDays(-60)
                ImageId = 'ami-prod-windows-2022'
                RootDeviceType = @{ Value = 'ebs' }
                RootDeviceName = '/dev/sda1'
                Monitoring = @{ State = @{ Value = 'enabled' } }
                EbsOptimized = $true
                Tags = @(
                    @{ Key = 'Name'; Value = 'prod-app-001' },
                    @{ Key = 'Environment'; Value = 'Production' },
                    @{ Key = 'Application'; Value = 'AppService' },
                    @{ Key = 'Owner'; Value = 'AppTeam' },
                    @{ Key = 'CostCenter'; Value = 'CC-PROD-002' },
                    @{ Key = 'PatchGroup'; Value = 'prod-app' }
                )
            },
            @{
                InstanceId = 'i-stage-web-001'
                State = @{ Name = @{ Value = 'running' } }
                InstanceType = @{ Value = 't3.medium' }
                Platform = @{ Value = 'windows' }
                Architecture = @{ Value = 'x86_64' }
                VirtualizationType = @{ Value = 'hvm' }
                Placement = @{
                    AvailabilityZone = 'us-east-1a'
                    Tenancy = @{ Value = 'default' }
                }
                VpcId = 'vpc-stage-001'
                SubnetId = 'subnet-stage-web-1a'
                PrivateIpAddress = '10.1.1.10'
                PublicIpAddress = $null
                PrivateDnsName = 'ip-10-1-1-10.ec2.internal'
                PublicDnsName = $null
                SecurityGroups = @(
                    @{ GroupName = 'stage-web-sg'; GroupId = 'sg-stage-web-001' }
                )
                KeyName = 'stage-keypair'
                IamInstanceProfile = @{ Arn = 'arn:aws:iam::123456789012:instance-profile/stage-web-role' }
                LaunchTime = (Get-Date).AddDays(-30)
                ImageId = 'ami-stage-windows-2022'
                RootDeviceType = @{ Value = 'ebs' }
                RootDeviceName = '/dev/sda1'
                Monitoring = @{ State = @{ Value = 'disabled' } }
                EbsOptimized = $false
                Tags = @(
                    @{ Key = 'Name'; Value = 'stage-web-001' },
                    @{ Key = 'Environment'; Value = 'Staging' },
                    @{ Key = 'Application'; Value = 'WebFrontend' },
                    @{ Key = 'Owner'; Value = 'WebTeam' },
                    @{ Key = 'CostCenter'; Value = 'CC-STAGE-001' },
                    @{ Key = 'PatchGroup'; Value = 'stage-all' }
                )
            }
        )
    }

    # SSM Instance Information mock
    $script:MockSSMInstances = @(
        @{
            InstanceId = 'i-prod-web-001'
            PingStatus = 'Online'
            LastPingDateTime = (Get-Date).AddMinutes(-2)
            AgentVersion = '3.1.0.0'
            PlatformType = 'Windows'
            PlatformName = 'Microsoft Windows Server 2022 Datacenter'
            PlatformVersion = '10.0.20348'
            ComputerName = 'PROD-WEB-001'
        },
        @{
            InstanceId = 'i-prod-web-002'
            PingStatus = 'Online'
            LastPingDateTime = (Get-Date).AddMinutes(-1)
            AgentVersion = '3.1.0.0'
            PlatformType = 'Windows'
            PlatformName = 'Microsoft Windows Server 2022 Datacenter'
            PlatformVersion = '10.0.20348'
            ComputerName = 'PROD-WEB-002'
        },
        @{
            InstanceId = 'i-prod-app-001'
            PingStatus = 'Online'
            LastPingDateTime = (Get-Date).AddMinutes(-3)
            AgentVersion = '3.1.0.0'
            PlatformType = 'Windows'
            PlatformName = 'Microsoft Windows Server 2022 Datacenter'
            PlatformVersion = '10.0.20348'
            ComputerName = 'PROD-APP-001'
        },
        @{
            InstanceId = 'i-stage-web-001'
            PingStatus = 'Online'
            LastPingDateTime = (Get-Date).AddMinutes(-5)
            AgentVersion = '3.1.0.0'
            PlatformType = 'Windows'
            PlatformName = 'Microsoft Windows Server 2022 Datacenter'
            PlatformVersion = '10.0.20348'
            ComputerName = 'STAGE-WEB-001'
        }
    )
}

AfterAll {
    Remove-Module -Name 'HyperionFleet' -Force -ErrorAction SilentlyContinue
}

Describe 'HyperionFleet Integration Tests' -Tag 'Integration' {
    Context 'Fleet Inventory Workflow' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet

            Mock Get-EC2Instance {
                param($Region, $Filter)

                # Simulate filtering behavior
                $instances = $script:MockFleetData.Instances

                if ($Filter) {
                    foreach ($f in $Filter) {
                        if ($f.Name -match '^tag:(.+)$') {
                            $tagKey = $Matches[1]
                            $tagValue = $f.Values[0]
                            $instances = $instances | Where-Object {
                                ($_.Tags | Where-Object { $_.Key -eq $tagKey -and $_.Value -eq $tagValue })
                            }
                        }
                        elseif ($f.Name -eq 'instance-state-name') {
                            $instances = $instances | Where-Object {
                                $f.Values -contains $_.State.Name.Value
                            }
                        }
                    }
                }

                return @{ Instances = $instances }
            } -ModuleName HyperionFleet
        }

        It 'retrieves complete fleet inventory' {
            $Inventory = Get-FleetInventory -Region 'us-east-1'

            $Inventory | Should -Not -BeNullOrEmpty
            $Inventory.Count | Should -Be 4
        }

        It 'filters inventory by environment' {
            $ProdInventory = Get-FleetInventory -Region 'us-east-1' -Tag @{ Environment = 'Production' }

            $ProdInventory.Count | Should -Be 3
            $ProdInventory | ForEach-Object { $_.Environment | Should -Be 'Production' }
        }

        It 'filters inventory by application' {
            $WebInventory = Get-FleetInventory -Region 'us-east-1' -Tag @{ Application = 'WebFrontend' }

            $WebInventory.Count | Should -Be 3
            $WebInventory | ForEach-Object { $_.Application | Should -Be 'WebFrontend' }
        }

        It 'groups inventory by environment' {
            $Inventory = Get-FleetInventory -Region 'us-east-1' -GroupBy 'Environment'

            $ProdCount = ($Inventory | Where-Object { $_.GroupByValue -eq 'Production' }).Count
            $StageCount = ($Inventory | Where-Object { $_.GroupByValue -eq 'Staging' }).Count

            $ProdCount | Should -Be 3
            $StageCount | Should -Be 1
        }

        It 'exports inventory to CSV' {
            Mock Export-Csv { } -ModuleName HyperionFleet

            $ExportPath = Join-Path -Path $TestDrive -ChildPath 'inventory-export.csv'
            Get-FleetInventory -Region 'us-east-1' -ExportPath $ExportPath

            Should -Invoke -CommandName Export-Csv -ModuleName HyperionFleet -Times 1
        }
    }

    Context 'Fleet Health Check Workflow' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet

            Mock Get-EC2Instance {
                return $script:MockFleetData
            } -ModuleName HyperionFleet

            Mock Get-SSMInstanceInformation {
                return $script:MockSSMInstances
            } -ModuleName HyperionFleet

            Mock Get-EC2InstanceStatus {
                return @{
                    SystemStatus = @{ Status = @{ Value = 'ok' } }
                    InstanceStatus = @{ Status = @{ Value = 'ok' } }
                }
            } -ModuleName HyperionFleet
        }

        It 'retrieves health status for all instances' {
            $Health = Get-FleetHealth -Region 'us-east-1'

            $Health | Should -Not -BeNullOrEmpty
            $Health.Count | Should -Be 4
        }

        It 'includes SSM agent status in health report' {
            $Health = Get-FleetHealth -Region 'us-east-1'

            $Health | ForEach-Object {
                $_.SSMAgentStatus | Should -Not -BeNullOrEmpty
            }
        }

        It 'correctly identifies healthy instances' {
            $Health = Get-FleetHealth -Region 'us-east-1'

            $HealthyCount = ($Health | Where-Object { $_.Status -eq 'Healthy' }).Count
            $HealthyCount | Should -Be 4
        }

        It 'filters health check by instance ID' {
            Mock Get-EC2Instance {
                param($Filter)
                $instanceFilter = $Filter | Where-Object { $_.Name -eq 'instance-id' }
                if ($instanceFilter) {
                    $filteredInstances = $script:MockFleetData.Instances | Where-Object {
                        $instanceFilter.Values -contains $_.InstanceId
                    }
                    return @{ Instances = $filteredInstances }
                }
                return $script:MockFleetData
            } -ModuleName HyperionFleet

            $Health = Get-FleetHealth -InstanceId 'i-prod-web-001' -Region 'us-east-1'

            $Health.Count | Should -Be 1
            $Health[0].InstanceId | Should -Be 'i-prod-web-001'
        }
    }

    Context 'Fleet Command Execution Workflow' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet

            Mock Get-EC2Instance {
                param($Filter)
                $envFilter = $Filter | Where-Object { $_.Name -eq 'tag:Environment' }
                if ($envFilter -and $envFilter.Values -contains 'Production') {
                    return @{
                        Instances = $script:MockFleetData.Instances | Where-Object {
                            ($_.Tags | Where-Object { $_.Key -eq 'Environment' -and $_.Value -eq 'Production' })
                        }
                    }
                }
                return $script:MockFleetData
            } -ModuleName HyperionFleet

            Mock Get-SSMInstanceInformation {
                return $script:MockSSMInstances
            } -ModuleName HyperionFleet

            Mock Send-SSMCommand {
                return @{
                    CommandId = 'cmd-integration-test-001'
                    DocumentName = 'AWS-RunPowerShellScript'
                    Status = @{ Value = 'Pending' }
                    RequestedDateTime = Get-Date
                    TargetCount = 3
                    CompletedCount = 0
                    ErrorCount = 0
                    Comment = 'Integration test command'
                }
            } -ModuleName HyperionFleet
        }

        It 'executes command on fleet instances' {
            $Result = Invoke-FleetCommand -InstanceId 'i-prod-web-001' -Command 'Get-Date' -Confirm:$false

            $Result | Should -Not -BeNullOrEmpty
            $Result.CommandId | Should -Not -BeNullOrEmpty
        }

        It 'targets instances by tag' {
            $Result = Invoke-FleetCommand -Tag @{ Environment = 'Production' } -Command 'Get-Date' -Confirm:$false

            $Result | Should -Not -BeNullOrEmpty
        }

        It 'supports custom SSM documents' {
            $Result = Invoke-FleetCommand -InstanceId 'i-prod-web-001' -DocumentName 'AWS-ConfigureWindowsUpdate' -Parameter @{ Action = 'Scan' } -Confirm:$false

            Should -Invoke -CommandName Send-SSMCommand -ModuleName HyperionFleet -ParameterFilter {
                $DocumentName -eq 'AWS-ConfigureWindowsUpdate'
            }
        }
    }

    Context 'Fleet Patching Workflow' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/test' }
                }
            } -ModuleName HyperionFleet

            Mock Get-EC2Instance {
                param($Filter)
                $patchFilter = $Filter | Where-Object { $_.Name -eq 'tag:PatchGroup' }
                if ($patchFilter) {
                    $filteredInstances = $script:MockFleetData.Instances | Where-Object {
                        ($_.Tags | Where-Object { $_.Key -eq 'PatchGroup' -and $patchFilter.Values -contains $_.Value })
                    }
                    return @{ Instances = $filteredInstances }
                }
                return $script:MockFleetData
            } -ModuleName HyperionFleet

            Mock Get-SSMInstanceInformation {
                return $script:MockSSMInstances
            } -ModuleName HyperionFleet

            Mock Get-FleetHealth {
                return @(
                    [PSCustomObject]@{ InstanceId = 'i-prod-web-001'; Status = 'Healthy' },
                    [PSCustomObject]@{ InstanceId = 'i-prod-web-002'; Status = 'Healthy' }
                )
            } -ModuleName HyperionFleet

            Mock Invoke-FleetCommand {
                return [PSCustomObject]@{
                    CommandId = 'cmd-patch-001'
                    DocumentName = 'AWS-RunPatchBaseline'
                    Status = 'Success'
                    RequestedDateTime = Get-Date
                    TargetCount = 2
                    CompletedCount = 2
                    ErrorCount = 0
                    Outputs = @{
                        'i-prod-web-001' = @{ Status = 'Success'; StandardOutputContent = 'InstalledCount: 5' }
                        'i-prod-web-002' = @{ Status = 'Success'; StandardOutputContent = 'InstalledCount: 3' }
                    }
                }
            } -ModuleName HyperionFleet
        }

        It 'initiates patching for specified instances' {
            $Result = Start-FleetPatch -InstanceId 'i-prod-web-001', 'i-prod-web-002' -Operation 'Scan' -Confirm:$false

            $Result | Should -Not -BeNullOrEmpty
            $Result.Operation | Should -Be 'Scan'
        }

        It 'performs pre-patch health check' {
            Start-FleetPatch -InstanceId 'i-prod-web-001' -Confirm:$false

            Should -Invoke -CommandName Get-FleetHealth -ModuleName HyperionFleet -Times 1
        }

        It 'skips pre-check when specified' {
            Start-FleetPatch -InstanceId 'i-prod-web-001' -SkipPreCheck -Confirm:$false

            Should -Invoke -CommandName Get-FleetHealth -ModuleName HyperionFleet -Times 0
        }

        It 'targets instances by patch group tag' {
            Start-FleetPatch -Tag @{ PatchGroup = 'prod-web' } -Confirm:$false

            Should -Invoke -CommandName Get-EC2Instance -ModuleName HyperionFleet
        }

        It 'uses Install operation by default' {
            Start-FleetPatch -InstanceId 'i-prod-web-001' -Confirm:$false

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -ParameterFilter {
                $Parameter.Operation -eq 'Install'
            }
        }

        It 'respects NoReboot option' {
            Start-FleetPatch -InstanceId 'i-prod-web-001' -RebootOption 'NoReboot' -Confirm:$false

            Should -Invoke -CommandName Invoke-FleetCommand -ModuleName HyperionFleet -ParameterFilter {
                $Parameter.RebootOption -eq 'NoReboot'
            }
        }
    }

    Context 'End-to-End Fleet Management Scenario' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-AWSSession {
                return [PSCustomObject]@{
                    Region = 'us-east-1'
                    CallerIdentity = @{ Arn = 'arn:aws:iam::123456789012:user/admin' }
                }
            } -ModuleName HyperionFleet

            Mock Get-EC2Instance {
                return $script:MockFleetData
            } -ModuleName HyperionFleet

            Mock Get-SSMInstanceInformation {
                return $script:MockSSMInstances
            } -ModuleName HyperionFleet

            Mock Get-EC2InstanceStatus {
                return @{
                    SystemStatus = @{ Status = @{ Value = 'ok' } }
                    InstanceStatus = @{ Status = @{ Value = 'ok' } }
                }
            } -ModuleName HyperionFleet

            Mock Send-SSMCommand {
                return @{
                    CommandId = 'cmd-e2e-001'
                    DocumentName = 'AWS-RunPowerShellScript'
                    Status = @{ Value = 'Pending' }
                    RequestedDateTime = Get-Date
                    TargetCount = 3
                    CompletedCount = 0
                    ErrorCount = 0
                }
            } -ModuleName HyperionFleet
        }

        It 'can inventory, check health, and execute commands in sequence' {
            # Step 1: Get inventory
            $Inventory = Get-FleetInventory -Region 'us-east-1' -Tag @{ Environment = 'Production' }
            $Inventory.Count | Should -BeGreaterOrEqual 1

            # Step 2: Check health of production instances
            Mock Get-FleetHealth {
                return @(
                    [PSCustomObject]@{ InstanceId = 'i-prod-web-001'; Status = 'Healthy' },
                    [PSCustomObject]@{ InstanceId = 'i-prod-web-002'; Status = 'Healthy' },
                    [PSCustomObject]@{ InstanceId = 'i-prod-app-001'; Status = 'Healthy' }
                )
            } -ModuleName HyperionFleet

            $Health = Get-FleetHealth -Tag @{ Environment = 'Production' } -Region 'us-east-1'
            $Health.Count | Should -BeGreaterOrEqual 1

            # Step 3: Execute command on healthy instances
            $HealthyInstances = $Health | Where-Object { $_.Status -eq 'Healthy' } | Select-Object -ExpandProperty InstanceId
            $HealthyInstances | Should -Not -BeNullOrEmpty

            $CommandResult = Invoke-FleetCommand -InstanceId $HealthyInstances[0] -Command 'Get-Process' -Confirm:$false
            $CommandResult | Should -Not -BeNullOrEmpty
        }
    }

    Context 'TestDrive File Operations' {
        It 'creates working directory in TestDrive' {
            $WorkDir = Join-Path -Path $TestDrive -ChildPath 'fleet-work'
            New-Item -Path $WorkDir -ItemType Directory -Force | Should -Not -BeNullOrEmpty
            $WorkDir | Should -Exist
        }

        It 'writes inventory export to TestDrive' {
            Mock Write-FleetLog { } -ModuleName HyperionFleet
            Mock Get-EC2Instance { return $script:MockFleetData } -ModuleName HyperionFleet

            $ExportPath = Join-Path -Path $TestDrive -ChildPath 'test-inventory.csv'

            # Export will be mocked, but path should be valid
            Mock Export-Csv {
                param($Path)
                # Create the file to simulate export
                '' | Set-Content -Path $Path
            } -ModuleName HyperionFleet

            Get-FleetInventory -Region 'us-east-1' -ExportPath $ExportPath

            $ExportPath | Should -Exist
        }

        It 'creates log file in TestDrive' {
            $LogPath = Join-Path -Path $TestDrive -ChildPath 'fleet-test.log'

            InModuleScope HyperionFleet -Parameters @{ LogPath = $LogPath } {
                param($LogPath)
                Write-FleetLog -Message 'Integration test log entry' -LogPath $LogPath -NoConsole
            }

            $LogPath | Should -Exist
            Get-Content -Path $LogPath | Should -Match 'Integration test log entry'
        }
    }
}

Describe 'HyperionFleet Mock Infrastructure Tests' -Tag 'Integration', 'MockInfra' {
    Context 'Simulated Multi-Region Deployment' {
        BeforeAll {
            Mock Write-FleetLog { } -ModuleName HyperionFleet

            # Simulate instances in multiple regions
            $script:MultiRegionData = @{
                'us-east-1' = @{
                    Instances = @(
                        @{
                            InstanceId = 'i-east-001'
                            State = @{ Name = @{ Value = 'running' } }
                            InstanceType = @{ Value = 't3.medium' }
                            Platform = @{ Value = 'windows' }
                            Architecture = @{ Value = 'x86_64' }
                            VirtualizationType = @{ Value = 'hvm' }
                            Placement = @{ AvailabilityZone = 'us-east-1a'; Tenancy = @{ Value = 'default' } }
                            VpcId = 'vpc-east'
                            SubnetId = 'subnet-east-1a'
                            PrivateIpAddress = '10.0.1.10'
                            PublicIpAddress = $null
                            PrivateDnsName = 'ip-10-0-1-10.ec2.internal'
                            PublicDnsName = $null
                            SecurityGroups = @()
                            KeyName = 'east-key'
                            IamInstanceProfile = $null
                            LaunchTime = (Get-Date).AddDays(-30)
                            ImageId = 'ami-east-001'
                            RootDeviceType = @{ Value = 'ebs' }
                            RootDeviceName = '/dev/sda1'
                            Monitoring = @{ State = @{ Value = 'disabled' } }
                            EbsOptimized = $false
                            Tags = @(
                                @{ Key = 'Name'; Value = 'east-server-001' },
                                @{ Key = 'Environment'; Value = 'Production' },
                                @{ Key = 'Region'; Value = 'us-east-1' }
                            )
                        }
                    )
                }
                'us-west-2' = @{
                    Instances = @(
                        @{
                            InstanceId = 'i-west-001'
                            State = @{ Name = @{ Value = 'running' } }
                            InstanceType = @{ Value = 't3.medium' }
                            Platform = @{ Value = 'windows' }
                            Architecture = @{ Value = 'x86_64' }
                            VirtualizationType = @{ Value = 'hvm' }
                            Placement = @{ AvailabilityZone = 'us-west-2a'; Tenancy = @{ Value = 'default' } }
                            VpcId = 'vpc-west'
                            SubnetId = 'subnet-west-2a'
                            PrivateIpAddress = '10.1.1.10'
                            PublicIpAddress = $null
                            PrivateDnsName = 'ip-10-1-1-10.ec2.internal'
                            PublicDnsName = $null
                            SecurityGroups = @()
                            KeyName = 'west-key'
                            IamInstanceProfile = $null
                            LaunchTime = (Get-Date).AddDays(-15)
                            ImageId = 'ami-west-001'
                            RootDeviceType = @{ Value = 'ebs' }
                            RootDeviceName = '/dev/sda1'
                            Monitoring = @{ State = @{ Value = 'disabled' } }
                            EbsOptimized = $false
                            Tags = @(
                                @{ Key = 'Name'; Value = 'west-server-001' },
                                @{ Key = 'Environment'; Value = 'Production' },
                                @{ Key = 'Region'; Value = 'us-west-2' }
                            )
                        }
                    )
                }
            }

            Mock Get-EC2Instance {
                param($Region)
                if ($script:MultiRegionData.ContainsKey($Region)) {
                    return $script:MultiRegionData[$Region]
                }
                return @{ Instances = @() }
            } -ModuleName HyperionFleet
        }

        It 'aggregates inventory from multiple regions' {
            $Inventory = Get-FleetInventory -Region @('us-east-1', 'us-west-2')

            $Inventory.Count | Should -Be 2

            $EastInstances = $Inventory | Where-Object { $_.Region -eq 'us-east-1' }
            $WestInstances = $Inventory | Where-Object { $_.Region -eq 'us-west-2' }

            $EastInstances.Count | Should -Be 1
            $WestInstances.Count | Should -Be 1
        }

        It 'includes correct region in each instance record' {
            $Inventory = Get-FleetInventory -Region @('us-east-1', 'us-west-2')

            $Inventory | ForEach-Object {
                $_.Region | Should -BeIn @('us-east-1', 'us-west-2')
            }
        }
    }
}
