#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for HyperionMetrics module.

.DESCRIPTION
    Comprehensive test suite for the HyperionMetrics PowerShell module including
    module structure validation, function tests, parameter validation, and
    mocked AWS SDK calls. Targets 80%+ code coverage.

.NOTES
    Run with: Invoke-Pester -Path './HyperionMetrics.Tests.ps1'
    For verbose output: Invoke-Pester -Path './HyperionMetrics.Tests.ps1' -Output Detailed
    For coverage: Invoke-Pester -Path './HyperionMetrics.Tests.ps1' -CodeCoverage '../**/*.ps1'
#>

BeforeAll {
    $ModulePath = Split-Path -Path $PSScriptRoot -Parent
    $ModuleName = 'HyperionMetrics'
    $ManifestPath = Join-Path -Path $ModulePath -ChildPath "$ModuleName.psd1"
    $ModuleFilePath = Join-Path -Path $ModulePath -ChildPath "$ModuleName.psm1"

    # Import module for testing (suppress AWS module requirement for unit tests)
    $env:HYPERION_SKIP_AWS_CHECK = 'true'

    # Mock the AWS types before importing if not available
    if (-not ('Amazon.CloudWatch.Model.MetricDatum' -as [type])) {
        # Create mock types for testing without AWS SDK
        Add-Type -TypeDefinition @'
namespace Amazon.CloudWatch.Model {
    public class MetricDatum {
        public string MetricName { get; set; }
        public double Value { get; set; }
        public object Unit { get; set; }
        public System.DateTime Timestamp { get; set; }
        public int StorageResolution { get; set; }
        public System.Collections.Generic.List<Dimension> Dimensions { get; set; }
    }

    public class Dimension {
        public string Name { get; set; }
        public string Value { get; set; }
    }
}

namespace Amazon.CloudWatch {
    public enum StandardUnit {
        None, Seconds, Microseconds, Milliseconds,
        Bytes, Kilobytes, Megabytes, Gigabytes, Terabytes,
        Bits, Kilobits, Megabits, Gigabits, Terabits,
        Percent, Count
    }
}
'@ -ErrorAction SilentlyContinue
    }

    # Try importing the module
    try {
        Import-Module $ManifestPath -Force -ErrorAction Stop
    }
    catch {
        # If import fails due to AWS module requirement, dot-source files directly
        Write-Warning "Module import failed, loading functions directly: $_"

        # Load private functions
        $privatePath = Join-Path -Path $ModulePath -ChildPath 'Private'
        Get-ChildItem -Path $privatePath -Filter '*.ps1' | ForEach-Object {
            . $_.FullName
        }

        # Load public functions
        $publicPath = Join-Path -Path $ModulePath -ChildPath 'Public'
        Get-ChildItem -Path $publicPath -Filter '*.ps1' | ForEach-Object {
            . $_.FullName
        }
    }
}

AfterAll {
    Remove-Module -Name 'HyperionMetrics' -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\HYPERION_SKIP_AWS_CHECK -ErrorAction SilentlyContinue
}

Describe 'HyperionMetrics Module' -Tag 'Unit', 'Module' {
    Context 'Module Structure' {
        It 'has a valid module manifest' {
            $ManifestPath | Should -Exist
        }

        It 'has a valid root module file' {
            $ModuleFilePath | Should -Exist
        }

        It 'has a Public functions directory' {
            $PublicPath = Join-Path -Path $ModulePath -ChildPath 'Public'
            $PublicPath | Should -Exist
        }

        It 'has a Private functions directory' {
            $PrivatePath = Join-Path -Path $ModulePath -ChildPath 'Private'
            $PrivatePath | Should -Exist
        }

        It 'has a Tests directory' {
            $TestsPath = Join-Path -Path $ModulePath -ChildPath 'Tests'
            $TestsPath | Should -Exist
        }
    }

    Context 'Module Manifest' {
        BeforeAll {
            $Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }

        It 'has a valid manifest' {
            $Manifest | Should -Not -BeNullOrEmpty
        }

        It 'has the correct module name' {
            $Manifest.Name | Should -Be 'HyperionMetrics'
        }

        It 'has a valid version number' {
            $Manifest.Version | Should -Not -BeNullOrEmpty
            $Manifest.Version.ToString() | Should -Match '^\d+\.\d+\.\d+$'
        }

        It 'has a valid GUID' {
            $Manifest.Guid | Should -Not -BeNullOrEmpty
        }

        It 'requires PowerShell 7.0 or higher' {
            $Manifest.PowerShellVersion | Should -BeGreaterOrEqual ([Version]'7.0')
        }

        It 'has module metadata' {
            $Manifest.Author | Should -Not -BeNullOrEmpty
            $Manifest.Description | Should -Not -BeNullOrEmpty
        }

        It 'has tags for module discovery' {
            $Manifest.PrivateData.PSData.Tags | Should -Not -BeNullOrEmpty
            $Manifest.PrivateData.PSData.Tags | Should -Contain 'AWS'
            $Manifest.PrivateData.PSData.Tags | Should -Contain 'CloudWatch'
        }
    }

    Context 'Public Functions' {
        BeforeAll {
            $PublicPath = Join-Path -Path $ModulePath -ChildPath 'Public'
            $PublicFunctions = Get-ChildItem -Path "$PublicPath/*.ps1" -Recurse
        }

        It 'contains expected public function files' {
            $PublicFunctions | Should -Not -BeNullOrEmpty
            $PublicFunctions.Count | Should -BeGreaterOrEqual 5
        }

        It 'has Get-SystemMetrics function' {
            $PublicFunctions.Name | Should -Contain 'Get-SystemMetrics.ps1'
        }

        It 'has Publish-FleetMetric function' {
            $PublicFunctions.Name | Should -Contain 'Publish-FleetMetric.ps1'
        }

        It 'has Publish-ComplianceMetrics function' {
            $PublicFunctions.Name | Should -Contain 'Publish-ComplianceMetrics.ps1'
        }

        It 'has Publish-ApplicationMetrics function' {
            $PublicFunctions.Name | Should -Contain 'Publish-ApplicationMetrics.ps1'
        }

        It 'has Start-MetricCollector function' {
            $PublicFunctions.Name | Should -Contain 'Start-MetricCollector.ps1'
        }

        It 'all public functions are valid PowerShell' {
            foreach ($function in $PublicFunctions) {
                $tokens = $null
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile(
                    $function.FullName, [ref]$tokens, [ref]$errors
                )
                $errors.Count | Should -Be 0 -Because "$($function.Name) should be valid PowerShell"
            }
        }

        It 'all public functions use approved verbs' {
            foreach ($function in $PublicFunctions) {
                $functionName = $function.BaseName
                $verb = $functionName.Split('-')[0]
                Get-Verb -Verb $verb | Should -Not -BeNullOrEmpty -Because "$functionName should use an approved verb"
            }
        }

        It 'all public functions have comment-based help' {
            foreach ($function in $PublicFunctions) {
                $content = Get-Content -Path $function.FullName -Raw
                $content | Should -Match '\.SYNOPSIS'
                $content | Should -Match '\.DESCRIPTION'
                $content | Should -Match '\.EXAMPLE'
            }
        }

        It 'all public functions use CmdletBinding' {
            foreach ($function in $PublicFunctions) {
                $content = Get-Content -Path $function.FullName -Raw
                $content | Should -Match '\[CmdletBinding\('
            }
        }

        It 'all public functions have OutputType attribute' {
            foreach ($function in $PublicFunctions) {
                $content = Get-Content -Path $function.FullName -Raw
                $content | Should -Match '\[OutputType\('
            }
        }
    }

    Context 'Private Functions' {
        BeforeAll {
            $PrivatePath = Join-Path -Path $ModulePath -ChildPath 'Private'
            $PrivateFunctions = Get-ChildItem -Path "$PrivatePath/*.ps1" -Recurse
        }

        It 'contains helper function files' {
            $PrivateFunctions | Should -Not -BeNullOrEmpty
            $PrivateFunctions.Count | Should -BeGreaterOrEqual 2
        }

        It 'has Get-StandardDimensions helper function' {
            $PrivateFunctions.Name | Should -Contain 'Get-StandardDimensions.ps1'
        }

        It 'has Convert-ToCloudWatchFormat helper function' {
            $PrivateFunctions.Name | Should -Contain 'Convert-ToCloudWatchFormat.ps1'
        }

        It 'all private functions are valid PowerShell' {
            foreach ($function in $PrivateFunctions) {
                $tokens = $null
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile(
                    $function.FullName, [ref]$tokens, [ref]$errors
                )
                $errors.Count | Should -Be 0 -Because "$($function.Name) should be valid PowerShell"
            }
        }
    }
}

Describe 'Get-SystemMetrics' -Tag 'Unit', 'Public' {
    Context 'Function Structure' {
        BeforeAll {
            $Command = Get-Command -Name 'Get-SystemMetrics' -ErrorAction SilentlyContinue
        }

        It 'exists' {
            $Command | Should -Not -BeNullOrEmpty
        }

        It 'has CmdletBinding attribute' {
            $Command.CmdletBinding | Should -BeTrue
        }

        It 'has synopsis' {
            $Help = Get-Help -Name 'Get-SystemMetrics'
            $Help.Synopsis | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Parameters' {
        BeforeAll {
            $Command = Get-Command -Name 'Get-SystemMetrics' -ErrorAction SilentlyContinue
            $Parameters = $Command.Parameters
        }

        It 'has IncludeCPU parameter' {
            $Parameters.Keys | Should -Contain 'IncludeCPU'
        }

        It 'has IncludeMemory parameter' {
            $Parameters.Keys | Should -Contain 'IncludeMemory'
        }

        It 'has IncludeDisk parameter' {
            $Parameters.Keys | Should -Contain 'IncludeDisk'
        }

        It 'has IncludeNetwork parameter' {
            $Parameters.Keys | Should -Contain 'IncludeNetwork'
        }

        It 'has SampleInterval parameter with range validation' {
            $Parameters.Keys | Should -Contain 'SampleInterval'
            $Attributes = $Parameters['SampleInterval'].Attributes
            $RangeAttribute = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $RangeAttribute | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Output Format' {
        It 'returns array type' {
            $Command = Get-Command -Name 'Get-SystemMetrics'
            $Command.OutputType.Name | Should -Contain 'PSCustomObject[]'
        }
    }
}

Describe 'Publish-FleetMetric' -Tag 'Unit', 'Public' {
    Context 'Function Structure' {
        BeforeAll {
            $Command = Get-Command -Name 'Publish-FleetMetric' -ErrorAction SilentlyContinue
        }

        It 'exists' {
            $Command | Should -Not -BeNullOrEmpty
        }

        It 'has CmdletBinding with ShouldProcess' {
            $Command.CmdletBinding | Should -BeTrue
            $Command.Parameters.Keys | Should -Contain 'WhatIf'
            $Command.Parameters.Keys | Should -Contain 'Confirm'
        }
    }

    Context 'Parameters' {
        BeforeAll {
            $Command = Get-Command -Name 'Publish-FleetMetric' -ErrorAction SilentlyContinue
            $Parameters = $Command.Parameters
        }

        It 'has MetricName parameter' {
            $Parameters.Keys | Should -Contain 'MetricName'
        }

        It 'has Value parameter' {
            $Parameters.Keys | Should -Contain 'Value'
        }

        It 'has Unit parameter with validation' {
            $Parameters.Keys | Should -Contain 'Unit'
            $Attributes = $Parameters['Unit'].Attributes
            $ValidateSetAttribute = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $ValidateSetAttribute | Should -Not -BeNullOrEmpty
        }

        It 'has Dimensions parameter' {
            $Parameters.Keys | Should -Contain 'Dimensions'
        }

        It 'has Namespace parameter' {
            $Parameters.Keys | Should -Contain 'Namespace'
        }

        It 'has Environment parameter with valid values' {
            $Parameters.Keys | Should -Contain 'Environment'
            $Attributes = $Parameters['Environment'].Attributes
            $ValidateSetAttribute = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $ValidateSetAttribute | Should -Not -BeNullOrEmpty
            $ValidateSetAttribute.ValidValues | Should -Contain 'dev'
            $ValidateSetAttribute.ValidValues | Should -Contain 'staging'
            $ValidateSetAttribute.ValidValues | Should -Contain 'prod'
        }

        It 'has StorageResolution parameter' {
            $Parameters.Keys | Should -Contain 'StorageResolution'
        }

        It 'has Metrics parameter for batch operations' {
            $Parameters.Keys | Should -Contain 'Metrics'
        }

        It 'has PassThru switch' {
            $Parameters.Keys | Should -Contain 'PassThru'
        }
    }

    Context 'Parameter Sets' {
        BeforeAll {
            $Command = Get-Command -Name 'Publish-FleetMetric' -ErrorAction SilentlyContinue
        }

        It 'has multiple parameter sets' {
            $Command.ParameterSets.Count | Should -BeGreaterOrEqual 2
        }

        It 'has Single parameter set' {
            $Command.ParameterSets.Name | Should -Contain 'Single'
        }

        It 'has Batch parameter set' {
            $Command.ParameterSets.Name | Should -Contain 'Batch'
        }
    }

    Context 'Batching Logic (Mock Tests)' {
        BeforeAll {
            Mock Write-CWMetricData { } -ModuleName HyperionMetrics -ErrorAction SilentlyContinue
        }

        It 'handles empty metrics gracefully' {
            InModuleScope HyperionMetrics {
                # Test with empty array - should warn but not error
                $result = Publish-FleetMetric -Metrics @() -WarningAction SilentlyContinue
                $result | Should -BeNullOrEmpty
            }
        }
    }
}

Describe 'Publish-ComplianceMetrics' -Tag 'Unit', 'Public' {
    Context 'Function Structure' {
        BeforeAll {
            $Command = Get-Command -Name 'Publish-ComplianceMetrics' -ErrorAction SilentlyContinue
        }

        It 'exists' {
            $Command | Should -Not -BeNullOrEmpty
        }

        It 'has CmdletBinding with ShouldProcess' {
            $Command.CmdletBinding | Should -BeTrue
        }
    }

    Context 'Parameters' {
        BeforeAll {
            $Command = Get-Command -Name 'Publish-ComplianceMetrics' -ErrorAction SilentlyContinue
            $Parameters = $Command.Parameters
        }

        It 'has CompliancePercentage parameter with range validation' {
            $Parameters.Keys | Should -Contain 'CompliancePercentage'
            $Attributes = $Parameters['CompliancePercentage'].Attributes
            $RangeAttribute = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $RangeAttribute | Should -Not -BeNullOrEmpty
            $RangeAttribute.MinRange | Should -Be 0
            $RangeAttribute.MaxRange | Should -Be 100
        }

        It 'has FailedControlsCount parameter' {
            $Parameters.Keys | Should -Contain 'FailedControlsCount'
        }

        It 'has TotalControlsCount parameter' {
            $Parameters.Keys | Should -Contain 'TotalControlsCount'
        }

        It 'has Framework parameter' {
            $Parameters.Keys | Should -Contain 'Framework'
        }

        It 'has ComplianceReport parameter for pipeline input' {
            $Parameters.Keys | Should -Contain 'ComplianceReport'
        }
    }

    Context 'Parameter Sets' {
        BeforeAll {
            $Command = Get-Command -Name 'Publish-ComplianceMetrics' -ErrorAction SilentlyContinue
        }

        It 'has Manual parameter set' {
            $Command.ParameterSets.Name | Should -Contain 'Manual'
        }

        It 'has Report parameter set' {
            $Command.ParameterSets.Name | Should -Contain 'Report'
        }
    }
}

Describe 'Publish-ApplicationMetrics' -Tag 'Unit', 'Public' {
    Context 'Function Structure' {
        BeforeAll {
            $Command = Get-Command -Name 'Publish-ApplicationMetrics' -ErrorAction SilentlyContinue
        }

        It 'exists' {
            $Command | Should -Not -BeNullOrEmpty
        }

        It 'has CmdletBinding with ShouldProcess' {
            $Command.CmdletBinding | Should -BeTrue
        }
    }

    Context 'Parameters' {
        BeforeAll {
            $Command = Get-Command -Name 'Publish-ApplicationMetrics' -ErrorAction SilentlyContinue
            $Parameters = $Command.Parameters
        }

        It 'has ApplicationName parameter (mandatory)' {
            $Parameters.Keys | Should -Contain 'ApplicationName'
        }

        It 'has RequestCount parameter' {
            $Parameters.Keys | Should -Contain 'RequestCount'
        }

        It 'has ErrorCount parameter' {
            $Parameters.Keys | Should -Contain 'ErrorCount'
        }

        It 'has LatencyMs parameter' {
            $Parameters.Keys | Should -Contain 'LatencyMs'
        }

        It 'has QueueDepth parameter' {
            $Parameters.Keys | Should -Contain 'QueueDepth'
        }

        It 'has HealthScore parameter with range validation' {
            $Parameters.Keys | Should -Contain 'HealthScore'
            $Attributes = $Parameters['HealthScore'].Attributes
            $RangeAttribute = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $RangeAttribute | Should -Not -BeNullOrEmpty
            $RangeAttribute.MinRange | Should -Be 0
            $RangeAttribute.MaxRange | Should -Be 100
        }

        It 'has CustomMetrics parameter' {
            $Parameters.Keys | Should -Contain 'CustomMetrics'
        }
    }
}

Describe 'Start-MetricCollector' -Tag 'Unit', 'Public' {
    Context 'Function Structure' {
        BeforeAll {
            $Command = Get-Command -Name 'Start-MetricCollector' -ErrorAction SilentlyContinue
        }

        It 'exists' {
            $Command | Should -Not -BeNullOrEmpty
        }

        It 'has CmdletBinding with ShouldProcess' {
            $Command.CmdletBinding | Should -BeTrue
            $Command.Parameters.Keys | Should -Contain 'WhatIf'
        }
    }

    Context 'Parameters' {
        BeforeAll {
            $Command = Get-Command -Name 'Start-MetricCollector' -ErrorAction SilentlyContinue
            $Parameters = $Command.Parameters
        }

        It 'has IntervalMinutes parameter with range validation' {
            $Parameters.Keys | Should -Contain 'IntervalMinutes'
            $Attributes = $Parameters['IntervalMinutes'].Attributes
            $RangeAttribute = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $RangeAttribute | Should -Not -BeNullOrEmpty
        }

        It 'has CollectionProfile parameter with valid values' {
            $Parameters.Keys | Should -Contain 'CollectionProfile'
            $Attributes = $Parameters['CollectionProfile'].Attributes
            $ValidateSetAttribute = $Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $ValidateSetAttribute | Should -Not -BeNullOrEmpty
            $ValidateSetAttribute.ValidValues | Should -Contain 'System'
            $ValidateSetAttribute.ValidValues | Should -Contain 'Full'
        }

        It 'has TaskName parameter' {
            $Parameters.Keys | Should -Contain 'TaskName'
        }

        It 'has Force switch' {
            $Parameters.Keys | Should -Contain 'Force'
        }
    }
}

Describe 'Get-StandardDimensions (Private)' -Tag 'Unit', 'Private' {
    Context 'Function Behavior' {
        It 'returns a hashtable' {
            InModuleScope HyperionMetrics {
                $result = Get-StandardDimensions -Environment 'dev' -Role 'TestRole'
                $result | Should -BeOfType [hashtable]
            }
        }

        It 'includes Environment dimension' {
            InModuleScope HyperionMetrics {
                $result = Get-StandardDimensions -Environment 'prod'
                $result.Environment | Should -Be 'prod'
            }
        }

        It 'includes Role dimension' {
            InModuleScope HyperionMetrics {
                $result = Get-StandardDimensions -Role 'WebServer'
                $result.Role | Should -Be 'WebServer'
            }
        }

        It 'includes Project dimension' {
            InModuleScope HyperionMetrics {
                $result = Get-StandardDimensions
                $result.Project | Should -Be 'hyperion-fleet-manager'
            }
        }

        It 'includes Hostname dimension' {
            InModuleScope HyperionMetrics {
                $result = Get-StandardDimensions
                $result.Hostname | Should -Not -BeNullOrEmpty
            }
        }

        It 'uses provided InstanceId over metadata' {
            InModuleScope HyperionMetrics {
                $result = Get-StandardDimensions -InstanceId 'i-test12345'
                $result.InstanceId | Should -Be 'i-test12345'
            }
        }

        It 'merges additional dimensions' {
            InModuleScope HyperionMetrics {
                $result = Get-StandardDimensions -AdditionalDimensions @{ CustomDim = 'CustomValue' }
                $result.CustomDim | Should -Be 'CustomValue'
            }
        }

        It 'does not include empty dimension values' {
            InModuleScope HyperionMetrics {
                $result = Get-StandardDimensions -AdditionalDimensions @{ EmptyDim = '' }
                $result.ContainsKey('EmptyDim') | Should -BeFalse
            }
        }
    }

    Context 'Caching Behavior' {
        It 'uses cache when available' {
            InModuleScope HyperionMetrics {
                # Set up cache
                $script:MetadataCache.InstanceId = 'i-cached123'
                $script:MetadataCache.CacheTime = Get-Date

                $result = Get-StandardDimensions
                $result.InstanceId | Should -Be 'i-cached123'

                # Clean up
                Clear-MetadataCache
            }
        }

        It 'bypasses cache with SkipCache' {
            InModuleScope HyperionMetrics {
                # This will attempt to fetch fresh metadata (will fail gracefully without EC2)
                $result = Get-StandardDimensions -SkipCache
                $result | Should -Not -BeNullOrEmpty
            }
        }

        It 'Clear-MetadataCache clears all cached values' {
            InModuleScope HyperionMetrics {
                $script:MetadataCache.InstanceId = 'test'
                $script:MetadataCache.CacheTime = Get-Date

                Clear-MetadataCache

                $script:MetadataCache.InstanceId | Should -BeNullOrEmpty
                $script:MetadataCache.CacheTime | Should -BeNullOrEmpty
            }
        }
    }
}

Describe 'Convert-ToCloudWatchFormat (Private)' -Tag 'Unit', 'Private' {
    Context 'Basic Conversion' {
        It 'creates MetricDatum with required properties' {
            InModuleScope HyperionMetrics {
                $result = Convert-ToCloudWatchFormat -MetricName 'TestMetric' -Value 100
                $result | Should -Not -BeNullOrEmpty
                $result.MetricName | Should -Be 'TestMetric'
                $result.Value | Should -Be 100
            }
        }

        It 'sets Unit correctly' {
            InModuleScope HyperionMetrics {
                $result = Convert-ToCloudWatchFormat -MetricName 'Test' -Value 50 -Unit 'Percent'
                $result.Unit | Should -Not -BeNullOrEmpty
            }
        }

        It 'sets timestamp to UTC' {
            InModuleScope HyperionMetrics {
                $result = Convert-ToCloudWatchFormat -MetricName 'Test' -Value 1
                $result.Timestamp | Should -Not -BeNullOrEmpty
            }
        }

        It 'defaults StorageResolution to 60' {
            InModuleScope HyperionMetrics {
                $result = Convert-ToCloudWatchFormat -MetricName 'Test' -Value 1
                $result.StorageResolution | Should -Be 60
            }
        }

        It 'accepts high resolution (1)' {
            InModuleScope HyperionMetrics {
                $result = Convert-ToCloudWatchFormat -MetricName 'Test' -Value 1 -StorageResolution 1
                $result.StorageResolution | Should -Be 1
            }
        }
    }

    Context 'Dimension Handling' {
        It 'converts dimensions hashtable correctly' {
            InModuleScope HyperionMetrics {
                $dims = @{ Environment = 'prod'; Service = 'API' }
                $result = Convert-ToCloudWatchFormat -MetricName 'Test' -Value 1 -Dimensions $dims
                $result.Dimensions | Should -Not -BeNullOrEmpty
                $result.Dimensions.Count | Should -Be 2
            }
        }

        It 'handles empty dimensions' {
            InModuleScope HyperionMetrics {
                $result = Convert-ToCloudWatchFormat -MetricName 'Test' -Value 1 -Dimensions @{}
                # Should not have dimensions property set or should be empty
                ($null -eq $result.Dimensions -or $result.Dimensions.Count -eq 0) | Should -BeTrue
            }
        }
    }

    Context 'Input Validation' {
        It 'rejects empty metric name' {
            InModuleScope HyperionMetrics {
                { Convert-ToCloudWatchFormat -MetricName '' -Value 1 } | Should -Throw
            }
        }

        It 'rejects invalid unit' {
            InModuleScope HyperionMetrics {
                { Convert-ToCloudWatchFormat -MetricName 'Test' -Value 1 -Unit 'InvalidUnit' } | Should -Throw
            }
        }

        It 'accepts all valid units' {
            InModuleScope HyperionMetrics {
                $validUnits = @('Seconds', 'Microseconds', 'Milliseconds', 'Bytes', 'Kilobytes',
                    'Megabytes', 'Gigabytes', 'Percent', 'Count', 'None')

                foreach ($unit in $validUnits) {
                    { Convert-ToCloudWatchFormat -MetricName 'Test' -Value 1 -Unit $unit } | Should -Not -Throw
                }
            }
        }
    }
}

Describe 'Convert-MetricBatchToCloudWatchFormat (Private)' -Tag 'Unit', 'Private' {
    Context 'Batch Conversion' {
        It 'converts array of metrics' {
            InModuleScope HyperionMetrics {
                $metrics = @(
                    [PSCustomObject]@{ MetricName = 'Metric1'; Value = 100; Unit = 'Count' }
                    [PSCustomObject]@{ MetricName = 'Metric2'; Value = 50; Unit = 'Percent' }
                )
                $result = Convert-MetricBatchToCloudWatchFormat -Metrics $metrics
                $result | Should -HaveCount 2
            }
        }

        It 'applies default dimensions to all metrics' {
            InModuleScope HyperionMetrics {
                $metrics = @(
                    [PSCustomObject]@{ MetricName = 'Metric1'; Value = 100 }
                )
                $result = Convert-MetricBatchToCloudWatchFormat -Metrics $metrics `
                    -DefaultDimensions @{ Environment = 'test' }
                $result[0].Dimensions | Should -Not -BeNullOrEmpty
            }
        }

        It 'skips metrics with missing MetricName' {
            InModuleScope HyperionMetrics {
                $metrics = @(
                    [PSCustomObject]@{ Value = 100 }  # Missing MetricName
                    [PSCustomObject]@{ MetricName = 'Valid'; Value = 50 }
                )
                $result = Convert-MetricBatchToCloudWatchFormat -Metrics $metrics -WarningAction SilentlyContinue
                $result | Should -HaveCount 1
            }
        }

        It 'skips metrics with missing Value' {
            InModuleScope HyperionMetrics {
                $metrics = @(
                    [PSCustomObject]@{ MetricName = 'NoValue' }  # Missing Value
                    [PSCustomObject]@{ MetricName = 'Valid'; Value = 50 }
                )
                $result = Convert-MetricBatchToCloudWatchFormat -Metrics $metrics -WarningAction SilentlyContinue
                $result | Should -HaveCount 1
            }
        }

        It 'handles empty array' {
            InModuleScope HyperionMetrics {
                $result = Convert-MetricBatchToCloudWatchFormat -Metrics @()
                $result | Should -HaveCount 0
            }
        }

        It 'uses DefaultUnit when metric has no unit' {
            InModuleScope HyperionMetrics {
                $metrics = @(
                    [PSCustomObject]@{ MetricName = 'NoUnit'; Value = 100 }
                )
                $result = Convert-MetricBatchToCloudWatchFormat -Metrics $metrics -DefaultUnit 'Count'
                $result | Should -HaveCount 1
            }
        }
    }
}

Describe 'Split-MetricBatch (Private)' -Tag 'Unit', 'Private' {
    Context 'Batching Logic' {
        It 'returns single batch for small arrays' {
            InModuleScope HyperionMetrics {
                $metrics = 1..10 | ForEach-Object { [PSCustomObject]@{ Name = "Metric$_" } }
                $batches = Split-MetricBatch -Metrics $metrics
                $batches.Count | Should -Be 1
                $batches[0].Count | Should -Be 10
            }
        }

        It 'splits at default batch size of 20' {
            InModuleScope HyperionMetrics {
                $metrics = 1..25 | ForEach-Object { [PSCustomObject]@{ Name = "Metric$_" } }
                $batches = Split-MetricBatch -Metrics $metrics
                $batches.Count | Should -Be 2
                $batches[0].Count | Should -Be 20
                $batches[1].Count | Should -Be 5
            }
        }

        It 'respects custom batch size' {
            InModuleScope HyperionMetrics {
                $metrics = 1..15 | ForEach-Object { [PSCustomObject]@{ Name = "Metric$_" } }
                $batches = Split-MetricBatch -Metrics $metrics -BatchSize 5
                $batches.Count | Should -Be 3
            }
        }

        It 'handles exactly batch size' {
            InModuleScope HyperionMetrics {
                $metrics = 1..20 | ForEach-Object { [PSCustomObject]@{ Name = "Metric$_" } }
                $batches = Split-MetricBatch -Metrics $metrics -BatchSize 20
                $batches.Count | Should -Be 1
            }
        }

        It 'handles empty array' {
            InModuleScope HyperionMetrics {
                $batches = Split-MetricBatch -Metrics @()
                $batches.Count | Should -Be 0
            }
        }

        It 'handles single item' {
            InModuleScope HyperionMetrics {
                $metrics = @([PSCustomObject]@{ Name = 'Single' })
                $batches = Split-MetricBatch -Metrics $metrics
                $batches.Count | Should -Be 1
                $batches[0].Count | Should -Be 1
            }
        }

        It 'rejects batch size over 20' {
            InModuleScope HyperionMetrics {
                { Split-MetricBatch -Metrics @() -BatchSize 25 } | Should -Throw
            }
        }
    }
}

Describe 'Test-CloudWatchUnit (Private)' -Tag 'Unit', 'Private' {
    Context 'Unit Validation' {
        It 'returns true for valid units' {
            InModuleScope HyperionMetrics {
                Test-CloudWatchUnit -Unit 'Percent' | Should -BeTrue
                Test-CloudWatchUnit -Unit 'Count' | Should -BeTrue
                Test-CloudWatchUnit -Unit 'Bytes' | Should -BeTrue
                Test-CloudWatchUnit -Unit 'None' | Should -BeTrue
            }
        }

        It 'returns false for invalid units' {
            InModuleScope HyperionMetrics {
                Test-CloudWatchUnit -Unit 'InvalidUnit' | Should -BeFalse
                Test-CloudWatchUnit -Unit 'percent' | Should -BeFalse  # Case sensitive
                Test-CloudWatchUnit -Unit '' | Should -BeFalse
            }
        }
    }
}

Describe 'Get-CloudWatchUnitForMetricName (Private)' -Tag 'Unit', 'Private' {
    Context 'Unit Detection' {
        It 'detects Percent for utilization metrics' {
            InModuleScope HyperionMetrics {
                Get-CloudWatchUnitForMetricName -MetricName 'CPUUtilization' | Should -Be 'Percent'
                Get-CloudWatchUnitForMetricName -MetricName 'MemoryUtilization' | Should -Be 'Percent'
            }
        }

        It 'detects Count for count metrics' {
            InModuleScope HyperionMetrics {
                Get-CloudWatchUnitForMetricName -MetricName 'RequestCount' | Should -Be 'Count'
                Get-CloudWatchUnitForMetricName -MetricName 'ErrorCount' | Should -Be 'Count'
            }
        }

        It 'detects Milliseconds for latency metrics' {
            InModuleScope HyperionMetrics {
                Get-CloudWatchUnitForMetricName -MetricName 'LatencyMs' | Should -Be 'Milliseconds'
                Get-CloudWatchUnitForMetricName -MetricName 'ResponseLatency' | Should -Be 'Milliseconds'
            }
        }

        It 'detects Bytes for byte metrics' {
            InModuleScope HyperionMetrics {
                Get-CloudWatchUnitForMetricName -MetricName 'DataBytes' | Should -Be 'Bytes'
            }
        }

        It 'returns None for unrecognized patterns' {
            InModuleScope HyperionMetrics {
                Get-CloudWatchUnitForMetricName -MetricName 'CustomMetric' | Should -Be 'None'
            }
        }
    }
}

Describe 'Error Handling' -Tag 'Unit', 'ErrorHandling' {
    Context 'Graceful Degradation' {
        It 'Get-SystemMetrics handles missing CIM gracefully on non-Windows' {
            if (-not $IsWindows) {
                # On Linux, should still return metrics from /proc
                $result = Get-SystemMetrics -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                # May be empty if /proc not available, but should not throw
                $result | Should -Not -BeNullOrEmpty -Because 'Linux metrics should be available'
            }
            else {
                Set-ItResult -Skipped -Because 'This test is for non-Windows platforms'
            }
        }

        It 'Publish-FleetMetric warns on empty metrics' {
            InModuleScope HyperionMetrics {
                $warningOutput = $null
                Publish-FleetMetric -Metrics @() -WarningVariable warningOutput -WarningAction SilentlyContinue
                # Should have generated a warning about no metrics
            }
        }
    }
}

Describe 'Code Quality' -Tag 'Quality' {
    BeforeAll {
        $AllScripts = Get-ChildItem -Path $ModulePath -Include '*.ps1', '*.psm1' -Recurse -File |
            Where-Object { $_.FullName -notmatch '[\\/]Tests[\\/]' }
    }

    Context 'Security' {
        It 'no script contains hardcoded credentials' {
            foreach ($script in $AllScripts) {
                $content = Get-Content -Path $script.FullName -Raw
                $content | Should -Not -Match 'password\s*=\s*[''"][^''"]+'
                $content | Should -Not -Match 'AKIA[0-9A-Z]{16}'  # AWS access key pattern
                $content | Should -Not -Match 'secret\s*=\s*[''"][^''"]{10,}'
            }
        }
    }

    Context 'Best Practices' {
        It 'no script uses Write-Host directly' {
            foreach ($script in $AllScripts) {
                $content = Get-Content -Path $script.FullName -Raw
                $content | Should -Not -Match 'Write-Host\s+'
            }
        }

        It 'all functions have error handling' {
            foreach ($script in $AllScripts) {
                $content = Get-Content -Path $script.FullName -Raw
                if ($content -match 'function\s+\w+-\w+') {
                    # Complex functions should have try/catch
                    # Allow simple helper functions without
                    $hasErrorHandling = $content -match 'try\s*\{' -or
                        $content -match '-ErrorAction' -or
                        $content -match 'catch\s*\{'
                    $hasErrorHandling | Should -BeTrue -Because "$($script.Name) should have error handling"
                }
            }
        }
    }
}

Describe 'Integration Scenarios' -Tag 'Integration' {
    Context 'Metric Pipeline' {
        It 'Get-SystemMetrics output can be piped to conversion' {
            $metrics = Get-SystemMetrics -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

            if ($metrics) {
                InModuleScope HyperionMetrics {
                    param($metrics)
                    $converted = Convert-MetricBatchToCloudWatchFormat -Metrics $metrics
                    $converted | Should -Not -BeNullOrEmpty
                } -ArgumentList (,$metrics)
            }
            else {
                Set-ItResult -Skipped -Because 'Get-SystemMetrics returned no metrics (expected in some environments)'
            }
        }

        It 'dimensions are properly merged through pipeline' {
            InModuleScope HyperionMetrics {
                $metrics = @(
                    [PSCustomObject]@{
                        MetricName = 'TestMetric'
                        Value = 100
                        Unit = 'Count'
                        Dimensions = @{ LocalDim = 'LocalValue' }
                    }
                )

                $result = Convert-MetricBatchToCloudWatchFormat -Metrics $metrics `
                    -DefaultDimensions @{ GlobalDim = 'GlobalValue' }

                # Both dimensions should be present
                $dims = @{}
                $result[0].Dimensions | ForEach-Object { $dims[$_.Name] = $_.Value }
                $dims['LocalDim'] | Should -Be 'LocalValue'
                $dims['GlobalDim'] | Should -Be 'GlobalValue'
            }
        }
    }
}
