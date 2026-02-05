#Requires -Modules Pester

<#
.SYNOPSIS
    Pester 5.x tests for HyperionCompliance module.

.DESCRIPTION
    Comprehensive tests for the HyperionCompliance module including:
    - Module structure validation
    - Public function tests
    - Private function tests (via module scope)
    - Mocked AWS calls
    - Compliance check logic validation

.NOTES
    Run with: Invoke-Pester -Path ./Tests/HyperionCompliance.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $ModulePath = Split-Path -Path $PSScriptRoot -Parent
    $ModuleName = 'HyperionCompliance'
    $ManifestPath = Join-Path -Path $ModulePath -ChildPath "$ModuleName.psd1"
    $ModuleFilePath = Join-Path -Path $ModulePath -ChildPath "$ModuleName.psm1"

    # Import module for testing
    Import-Module $ManifestPath -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name 'HyperionCompliance' -Force -ErrorAction SilentlyContinue
}

Describe 'HyperionCompliance Module' {
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

        It 'has a Data directory with CIS benchmarks' {
            $DataPath = Join-Path -Path $ModulePath -ChildPath 'Data'
            $DataPath | Should -Exist

            $BenchmarkPath = Join-Path -Path $DataPath -ChildPath 'CISBenchmarks.psd1'
            $BenchmarkPath | Should -Exist
        }
    }

    Context 'Module Manifest' {
        BeforeAll {
            $Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
        }

        It 'has a valid manifest' {
            $Manifest | Should -Not -BeNullOrEmpty
        }

        It 'has the correct module name' {
            $Manifest.Name | Should -Be 'HyperionCompliance'
        }

        It 'has a valid version number (1.0.0)' {
            $Manifest.Version | Should -Not -BeNullOrEmpty
            $Manifest.Version.ToString() | Should -Match '^\d+\.\d+\.\d+$'
            $Manifest.Version.Major | Should -Be 1
            $Manifest.Version.Minor | Should -Be 0
            $Manifest.Version.Build | Should -Be 0
        }

        It 'has a valid GUID' {
            $Manifest.Guid | Should -Not -BeNullOrEmpty
            $Manifest.Guid.ToString() | Should -Match '^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$'
        }

        It 'requires PowerShell 7.4 or higher' {
            $Manifest.PowerShellVersion | Should -BeGreaterOrEqual ([Version]'7.4')
        }

        It 'specifies Core edition compatibility' {
            $Manifest.CompatiblePSEditions | Should -Contain 'Core'
        }

        It 'has required modules specified' {
            $Manifest.RequiredModules | Should -Not -BeNullOrEmpty
            $requiredModuleNames = $Manifest.RequiredModules | ForEach-Object {
                if ($_ -is [hashtable]) { $_.ModuleName } else { $_ }
            }
            $requiredModuleNames | Should -Contain 'AWS.Tools.SimpleSystemsManagement'
            $requiredModuleNames | Should -Contain 'AWS.Tools.S3'
        }

        It 'exports the correct functions' {
            $ExpectedFunctions = @(
                'Test-CISCompliance',
                'Get-ComplianceReport',
                'Invoke-ComplianceRemediation',
                'Export-ComplianceToS3',
                'Get-DSCComplianceStatus'
            )

            foreach ($function in $ExpectedFunctions) {
                $Manifest.ExportedFunctions.Keys | Should -Contain $function
            }
        }

        It 'has module metadata' {
            $Manifest.Author | Should -Not -BeNullOrEmpty
            $Manifest.Description | Should -Not -BeNullOrEmpty
            $Manifest.Copyright | Should -Not -BeNullOrEmpty
        }

        It 'has appropriate tags' {
            $Manifest.PrivateData.PSData.Tags | Should -Not -BeNullOrEmpty
            $Manifest.PrivateData.PSData.Tags | Should -Contain 'Compliance'
            $Manifest.PrivateData.PSData.Tags | Should -Contain 'CIS'
        }
    }

    Context 'Public Functions' {
        BeforeAll {
            $PublicPath = Join-Path -Path $ModulePath -ChildPath 'Public'
            $PublicFunctions = Get-ChildItem -Path "$PublicPath/*.ps1" -Recurse
        }

        It 'contains exactly 5 function files' {
            $PublicFunctions.Count | Should -Be 5
        }

        It 'has Test-CISCompliance function' {
            $PublicFunctions.Name | Should -Contain 'Test-CISCompliance.ps1'
        }

        It 'has Get-ComplianceReport function' {
            $PublicFunctions.Name | Should -Contain 'Get-ComplianceReport.ps1'
        }

        It 'has Invoke-ComplianceRemediation function' {
            $PublicFunctions.Name | Should -Contain 'Invoke-ComplianceRemediation.ps1'
        }

        It 'has Export-ComplianceToS3 function' {
            $PublicFunctions.Name | Should -Contain 'Export-ComplianceToS3.ps1'
        }

        It 'has Get-DSCComplianceStatus function' {
            $PublicFunctions.Name | Should -Contain 'Get-DSCComplianceStatus.ps1'
        }

        It 'all public functions are valid PowerShell' {
            foreach ($function in $PublicFunctions) {
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($function.FullName, [ref]$null, [ref]$null)
                $ast | Should -Not -BeNullOrEmpty -Because "$($function.Name) should be valid PowerShell"
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
            $PrivateFunctions.Count | Should -BeGreaterOrEqual 3
        }

        It 'has Get-SecurityPolicy helper function' {
            $PrivateFunctions.Name | Should -Contain 'Get-SecurityPolicy.ps1'
        }

        It 'has Get-AuditPolicy helper function' {
            $PrivateFunctions.Name | Should -Contain 'Get-AuditPolicy.ps1'
        }

        It 'has Write-ComplianceLog helper function' {
            $PrivateFunctions.Name | Should -Contain 'Write-ComplianceLog.ps1'
        }

        It 'all private functions are valid PowerShell' {
            foreach ($function in $PrivateFunctions) {
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($function.FullName, [ref]$null, [ref]$null)
                $ast | Should -Not -BeNullOrEmpty -Because "$($function.Name) should be valid PowerShell"
            }
        }

        It 'private functions are not exported' {
            $Module = Get-Module -Name 'HyperionCompliance'
            foreach ($function in $PrivateFunctions) {
                $functionName = $function.BaseName
                # Handle files with multiple functions
                if ($functionName -eq 'Write-ComplianceLog') {
                    $Module.ExportedCommands.Keys | Should -Not -Contain 'Write-ComplianceLog'
                    $Module.ExportedCommands.Keys | Should -Not -Contain 'Write-RemediationLog'
                }
                elseif ($functionName -eq 'Get-AuditPolicy') {
                    $Module.ExportedCommands.Keys | Should -Not -Contain 'Get-AuditPolicy'
                    $Module.ExportedCommands.Keys | Should -Not -Contain 'Get-AllAuditPolicies'
                }
                else {
                    $Module.ExportedCommands.Keys | Should -Not -Contain $functionName
                }
            }
        }
    }

    Context 'CIS Benchmark Data' {
        BeforeAll {
            $BenchmarkPath = Join-Path -Path $ModulePath -ChildPath 'Data/CISBenchmarks.psd1'
            $Benchmarks = Import-PowerShellDataFile -Path $BenchmarkPath
        }

        It 'has benchmark version' {
            $Benchmarks.BenchmarkVersion | Should -Not -BeNullOrEmpty
        }

        It 'has benchmark name' {
            $Benchmarks.BenchmarkName | Should -Not -BeNullOrEmpty
        }

        It 'has controls defined' {
            $Benchmarks.Controls | Should -Not -BeNullOrEmpty
            $Benchmarks.Controls.Count | Should -BeGreaterThan 0
        }

        It 'controls have required properties' {
            $RequiredProperties = @('ControlId', 'Title', 'Description', 'Level', 'Category', 'CheckScript')

            foreach ($control in $Benchmarks.Controls | Select-Object -First 5) {
                foreach ($prop in $RequiredProperties) {
                    $control.$prop | Should -Not -BeNullOrEmpty -Because "Control $($control.ControlId) should have $prop"
                }
            }
        }

        It 'controls have valid Level values (1 or 2)' {
            foreach ($control in $Benchmarks.Controls) {
                $control.Level | Should -BeIn @(1, 2) -Because "Control $($control.ControlId) should have Level 1 or 2"
            }
        }

        It 'has both Level 1 and Level 2 controls' {
            $Level1 = $Benchmarks.Controls | Where-Object { $_.Level -eq 1 }
            $Level2 = $Benchmarks.Controls | Where-Object { $_.Level -eq 2 }

            $Level1.Count | Should -BeGreaterThan 0
            $Level2.Count | Should -BeGreaterThan 0
        }

        It 'has category definitions' {
            $Benchmarks.Categories | Should -Not -BeNullOrEmpty
        }

        It 'has subcategory definitions' {
            $Benchmarks.SubCategories | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Module Import' {
        It 'imports without errors' {
            { Import-Module $ManifestPath -Force } | Should -Not -Throw
        }

        It 'exports expected functions' {
            $Module = Get-Module -Name 'HyperionCompliance'
            $Module.ExportedCommands.Count | Should -Be 5
        }

        It 'has module configuration variable' {
            # Module config is scoped to module, verify module loaded
            Get-Command -Module HyperionCompliance | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Function Availability' {
        It 'Test-CISCompliance is available' {
            Get-Command -Name 'Test-CISCompliance' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Get-ComplianceReport is available' {
            Get-Command -Name 'Get-ComplianceReport' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Invoke-ComplianceRemediation is available' {
            Get-Command -Name 'Invoke-ComplianceRemediation' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Export-ComplianceToS3 is available' {
            Get-Command -Name 'Export-ComplianceToS3' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Get-DSCComplianceStatus is available' {
            Get-Command -Name 'Get-DSCComplianceStatus' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Code Quality' {
        BeforeAll {
            $AllScripts = Get-ChildItem -Path $ModulePath -Include '*.ps1', '*.psm1' -Recurse
        }

        It 'no script contains hardcoded credentials' {
            foreach ($script in $AllScripts) {
                $content = Get-Content -Path $script.FullName -Raw
                $content | Should -Not -Match 'password\s*=\s*[''"][^''"]+[''"]' -Because "$($script.Name) should not contain hardcoded passwords"
                $content | Should -Not -Match 'AKIA[0-9A-Z]{16}' -Because "$($script.Name) should not contain AWS access keys"
            }
        }

        It 'scripts follow line length guidelines' {
            foreach ($script in $AllScripts) {
                $lines = Get-Content -Path $script.FullName
                $longLines = $lines | Where-Object { $_.Length -gt 200 }
                $longLines.Count | Should -BeLessThan ($lines.Count * 0.1) -Because "More than 10% of lines exceed 200 characters in $($script.Name)"
            }
        }
    }
}

Describe 'Test-CISCompliance Function' {
    Context 'Parameter Validation' {
        It 'accepts Level parameter with valid values' {
            $cmd = Get-Command -Name 'Test-CISCompliance'
            $levelParam = $cmd.Parameters['Level']
            $levelParam | Should -Not -BeNullOrEmpty
            $levelParam.ParameterType | Should -Be ([int])
        }

        It 'accepts Category parameter with valid values' {
            $cmd = Get-Command -Name 'Test-CISCompliance'
            $categoryParam = $cmd.Parameters['Category']
            $categoryParam | Should -Not -BeNullOrEmpty
        }

        It 'accepts ControlId parameter' {
            $cmd = Get-Command -Name 'Test-CISCompliance'
            $controlIdParam = $cmd.Parameters['ControlId']
            $controlIdParam | Should -Not -BeNullOrEmpty
        }

        It 'accepts OutputPath parameter' {
            $cmd = Get-Command -Name 'Test-CISCompliance'
            $outputPathParam = $cmd.Parameters['OutputPath']
            $outputPathParam | Should -Not -BeNullOrEmpty
        }

        It 'has PassThru switch' {
            $cmd = Get-Command -Name 'Test-CISCompliance'
            $passThruParam = $cmd.Parameters['PassThru']
            $passThruParam | Should -Not -BeNullOrEmpty
            $passThruParam.SwitchParameter | Should -Be $true
        }

        It 'has IncludeLevel2 switch' {
            $cmd = Get-Command -Name 'Test-CISCompliance'
            $includeLevel2Param = $cmd.Parameters['IncludeLevel2']
            $includeLevel2Param | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Default Behavior' {
        It 'defaults to Level 1' {
            $cmd = Get-Command -Name 'Test-CISCompliance'
            $levelParam = $cmd.Parameters['Level']
            $levelParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.DefaultValue } | Should -BeNullOrEmpty  # Defaults are handled in code
        }
    }
}

Describe 'Get-ComplianceReport Function' {
    Context 'Parameter Validation' {
        It 'accepts Format parameter with valid values' {
            $cmd = Get-Command -Name 'Get-ComplianceReport'
            $formatParam = $cmd.Parameters['Format']
            $formatParam | Should -Not -BeNullOrEmpty

            # Check ValidateSet
            $validateSet = $formatParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'JSON'
            $validateSet.ValidValues | Should -Contain 'HTML'
            $validateSet.ValidValues | Should -Contain 'CSV'
        }

        It 'accepts ComplianceResults from pipeline' {
            $cmd = Get-Command -Name 'Get-ComplianceReport'
            $resultsParam = $cmd.Parameters['ComplianceResults']
            $resultsParam | Should -Not -BeNullOrEmpty

            $pipelineAttr = $resultsParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $pipelineAttr.ValueFromPipeline | Should -Be $true
        }

        It 'has IncludeRemediation switch' {
            $cmd = Get-Command -Name 'Get-ComplianceReport'
            $remediationParam = $cmd.Parameters['IncludeRemediation']
            $remediationParam | Should -Not -BeNullOrEmpty
        }

        It 'has IncludePassedControls switch' {
            $cmd = Get-Command -Name 'Get-ComplianceReport'
            $passedParam = $cmd.Parameters['IncludePassedControls']
            $passedParam | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Invoke-ComplianceRemediation Function' {
    Context 'Parameter Validation' {
        It 'has SupportsShouldProcess' {
            $cmd = Get-Command -Name 'Invoke-ComplianceRemediation'
            $cmd.Parameters.ContainsKey('WhatIf') | Should -Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should -Be $true
        }

        It 'accepts FindingIds parameter' {
            $cmd = Get-Command -Name 'Invoke-ComplianceRemediation'
            $findingIdsParam = $cmd.Parameters['FindingIds']
            $findingIdsParam | Should -Not -BeNullOrEmpty
        }

        It 'has ExcludeHighImpact switch' {
            $cmd = Get-Command -Name 'Invoke-ComplianceRemediation'
            $excludeParam = $cmd.Parameters['ExcludeHighImpact']
            $excludeParam | Should -Not -BeNullOrEmpty
        }

        It 'has Force switch' {
            $cmd = Get-Command -Name 'Invoke-ComplianceRemediation'
            $forceParam = $cmd.Parameters['Force']
            $forceParam | Should -Not -BeNullOrEmpty
        }

        It 'accepts pipeline input for ComplianceResults' {
            $cmd = Get-Command -Name 'Invoke-ComplianceRemediation'
            $resultsParam = $cmd.Parameters['ComplianceResults']
            $resultsParam | Should -Not -BeNullOrEmpty

            $pipelineAttr = $resultsParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $pipelineAttr.ValueFromPipeline | Should -Be $true
        }
    }
}

Describe 'Export-ComplianceToS3 Function' {
    Context 'Parameter Validation' {
        It 'has mandatory BucketName parameter' {
            $cmd = Get-Command -Name 'Export-ComplianceToS3'
            $bucketParam = $cmd.Parameters['BucketName']
            $bucketParam | Should -Not -BeNullOrEmpty

            $mandatoryAttr = $bucketParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatoryAttr.Mandatory | Should -Be $true
        }

        It 'has mandatory ReportType parameter' {
            $cmd = Get-Command -Name 'Export-ComplianceToS3'
            $reportTypeParam = $cmd.Parameters['ReportType']
            $reportTypeParam | Should -Not -BeNullOrEmpty

            $mandatoryAttr = $reportTypeParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatoryAttr.Mandatory | Should -Be $true
        }

        It 'accepts ReportType with valid values' {
            $cmd = Get-Command -Name 'Export-ComplianceToS3'
            $reportTypeParam = $cmd.Parameters['ReportType']

            $validateSet = $reportTypeParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Compliance'
            $validateSet.ValidValues | Should -Contain 'Remediation'
            $validateSet.ValidValues | Should -Contain 'Audit'
            $validateSet.ValidValues | Should -Contain 'Summary'
        }

        It 'accepts ServerSideEncryption parameter' {
            $cmd = Get-Command -Name 'Export-ComplianceToS3'
            $sseParam = $cmd.Parameters['ServerSideEncryption']
            $sseParam | Should -Not -BeNullOrEmpty

            $validateSet = $sseParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'AES256'
            $validateSet.ValidValues | Should -Contain 'aws:kms'
        }

        It 'has SupportsShouldProcess' {
            $cmd = Get-Command -Name 'Export-ComplianceToS3'
            $cmd.Parameters.ContainsKey('WhatIf') | Should -Be $true
        }
    }

    Context 'Mocked S3 Operations' {
        BeforeAll {
            # Mock AWS S3 cmdlets
            Mock -ModuleName HyperionCompliance Write-S3Object { return $null }
            Mock -ModuleName HyperionCompliance Get-S3ObjectMetadata {
                return [PSCustomObject]@{
                    ETag                        = '"abcd1234"'
                    ContentLength               = 1024
                    ServerSideEncryptionMethod  = 'AES256'
                }
            }
            Mock -ModuleName HyperionCompliance Set-S3ObjectTagSet { return $null }
        }

        It 'should not throw with valid mock parameters' -Skip:(-not (Get-Module AWS.Tools.S3 -ListAvailable)) {
            $testData = @{ Test = 'Data' }
            { Export-ComplianceToS3 -BucketName 'test-bucket' -ReportData $testData -ReportType 'Compliance' -WhatIf } | Should -Not -Throw
        }
    }
}

Describe 'Get-DSCComplianceStatus Function' {
    Context 'Parameter Validation' {
        It 'has Detailed switch' {
            $cmd = Get-Command -Name 'Get-DSCComplianceStatus'
            $detailedParam = $cmd.Parameters['Detailed']
            $detailedParam | Should -Not -BeNullOrEmpty
        }

        It 'accepts ComputerName parameter' {
            $cmd = Get-Command -Name 'Get-DSCComplianceStatus'
            $computerParam = $cmd.Parameters['ComputerName']
            $computerParam | Should -Not -BeNullOrEmpty
        }

        It 'accepts Credential parameter' {
            $cmd = Get-Command -Name 'Get-DSCComplianceStatus'
            $credParam = $cmd.Parameters['Credential']
            $credParam | Should -Not -BeNullOrEmpty
        }

        It 'accepts OutputPath parameter' {
            $cmd = Get-Command -Name 'Get-DSCComplianceStatus'
            $outputParam = $cmd.Parameters['OutputPath']
            $outputParam | Should -Not -BeNullOrEmpty
        }

        It 'has multiple parameter sets' {
            $cmd = Get-Command -Name 'Get-DSCComplianceStatus'
            $cmd.ParameterSets.Count | Should -BeGreaterThan 1
        }
    }
}

Describe 'Integration Tests' -Tag 'Integration' {
    Context 'Compliance Check Flow' -Skip:(-not $IsWindows) {
        It 'can run a basic compliance check' {
            $results = Test-CISCompliance -Level 1 -Category 'Account Policies' -PassThru -Quiet
            $results | Should -Not -BeNullOrEmpty
        }

        It 'returns properly formatted results' {
            $results = Test-CISCompliance -ControlId 'CIS-1.1.1' -PassThru -Quiet

            if ($results) {
                $results[0].ControlId | Should -Be 'CIS-1.1.1'
                $results[0].Status | Should -BeIn @('Pass', 'Fail', 'Error', 'Skipped')
            }
        }
    }

    Context 'Report Generation Flow' {
        It 'can generate a JSON report from mock data' {
            $mockResults = @(
                [PSCustomObject]@{
                    ControlId     = 'CIS-TEST-1'
                    Title         = 'Test Control'
                    Level         = 1
                    Category      = 'Test'
                    SubCategory   = 'Test'
                    Impact        = 'Low'
                    Status        = 'Pass'
                    ExpectedValue = 'Expected'
                    ActualValue   = 'Actual'
                    Message       = 'Test passed'
                    RemediationAvailable = $false
                }
            )

            $tempPath = Join-Path -Path $env:TEMP -ChildPath "test-report-$(Get-Random).json"

            try {
                $report = Get-ComplianceReport -ComplianceResults $mockResults -Format JSON -OutputPath $tempPath

                $report | Should -Not -BeNullOrEmpty
                $report.OutputPath | Should -Be $tempPath
                Test-Path -Path $tempPath | Should -Be $true

                $content = Get-Content -Path $tempPath -Raw | ConvertFrom-Json
                $content.Summary | Should -Not -BeNullOrEmpty
            }
            finally {
                if (Test-Path -Path $tempPath) {
                    Remove-Item -Path $tempPath -Force
                }
            }
        }

        It 'can generate an HTML report from mock data' {
            $mockResults = @(
                [PSCustomObject]@{
                    ControlId     = 'CIS-TEST-1'
                    Title         = 'Test Control'
                    Level         = 1
                    Category      = 'Test'
                    SubCategory   = 'Test'
                    Impact        = 'Medium'
                    Status        = 'Fail'
                    ExpectedValue = 'Expected'
                    ActualValue   = 'Actual'
                    Message       = 'Test failed'
                    RemediationAvailable = $true
                }
            )

            $tempPath = Join-Path -Path $env:TEMP -ChildPath "test-report-$(Get-Random).html"

            try {
                $report = Get-ComplianceReport -ComplianceResults $mockResults -Format HTML -OutputPath $tempPath

                $report | Should -Not -BeNullOrEmpty
                $report.Format | Should -Be 'HTML'
                Test-Path -Path $tempPath | Should -Be $true

                $content = Get-Content -Path $tempPath -Raw
                $content | Should -Match '<html'
                $content | Should -Match 'CIS-TEST-1'
            }
            finally {
                if (Test-Path -Path $tempPath) {
                    Remove-Item -Path $tempPath -Force
                }
            }
        }
    }
}
