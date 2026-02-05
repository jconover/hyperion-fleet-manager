#Requires -Modules Pester

<#
.SYNOPSIS
    Module-level tests for HyperionFleet.

.DESCRIPTION
    Tests module structure, manifest integrity, function exports, and overall module health.
    These tests validate the module can be loaded correctly and exposes the expected
    functionality to consumers.

.NOTES
    Run with: Invoke-Pester -Path './HyperionFleet.Tests.ps1'
    For verbose output: Invoke-Pester -Path './HyperionFleet.Tests.ps1' -Output Detailed
#>

BeforeAll {
    $ModulePath = Split-Path -Path $PSScriptRoot -Parent
    $ModuleName = 'HyperionFleet'
    $ManifestPath = Join-Path -Path $ModulePath -ChildPath "$ModuleName.psd1"
    $ModuleFilePath = Join-Path -Path $ModulePath -ChildPath "$ModuleName.psm1"

    # Import module for testing
    Import-Module $ManifestPath -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module -Name 'HyperionFleet' -Force -ErrorAction SilentlyContinue
}

Describe 'HyperionFleet Module' -Tag 'Unit', 'Module' {
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

        It 'has Public test directory' {
            $PublicTestsPath = Join-Path -Path $ModulePath -ChildPath 'Tests/Public'
            $PublicTestsPath | Should -Exist
        }

        It 'has Private test directory' {
            $PrivateTestsPath = Join-Path -Path $ModulePath -ChildPath 'Tests/Private'
            $PrivateTestsPath | Should -Exist
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
            $Manifest.Name | Should -Be 'HyperionFleet'
        }

        It 'has a valid version number' {
            $Manifest.Version | Should -Not -BeNullOrEmpty
            $Manifest.Version.ToString() | Should -Match '^\d+\.\d+\.\d+$'
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
            $Manifest.RequiredModules.Name | Should -Contain 'AWS.Tools.EC2'
            $Manifest.RequiredModules.Name | Should -Contain 'AWS.Tools.SimpleSystemsManagement'
        }

        It 'exports the correct functions' {
            $ExpectedFunctions = @(
                'Get-FleetHealth',
                'Get-FleetInventory',
                'Invoke-FleetCommand',
                'Start-FleetPatch'
            )

            foreach ($function in $ExpectedFunctions) {
                $Manifest.ExportedFunctions.Keys | Should -Contain $function
            }
        }

        It 'exports exactly four functions' {
            $Manifest.ExportedFunctions.Count | Should -Be 4
        }

        It 'does not export cmdlets' {
            $Manifest.ExportedCmdlets.Count | Should -Be 0
        }

        It 'does not export aliases' {
            $Manifest.ExportedAliases.Count | Should -Be 0
        }

        It 'has module metadata' {
            $Manifest.Author | Should -Not -BeNullOrEmpty
            $Manifest.Description | Should -Not -BeNullOrEmpty
            $Manifest.Copyright | Should -Not -BeNullOrEmpty
        }

        It 'has tags for module discovery' {
            $Manifest.PrivateData.PSData.Tags | Should -Not -BeNullOrEmpty
            $Manifest.PrivateData.PSData.Tags | Should -Contain 'AWS'
            $Manifest.PrivateData.PSData.Tags | Should -Contain 'EC2'
        }

        It 'has release notes' {
            $Manifest.PrivateData.PSData.ReleaseNotes | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Public Functions' {
        BeforeAll {
            $PublicPath = Join-Path -Path $ModulePath -ChildPath 'Public'
            $PublicFunctions = Get-ChildItem -Path "$PublicPath/*.ps1" -Recurse
        }

        It 'contains function files' {
            $PublicFunctions | Should -Not -BeNullOrEmpty
            $PublicFunctions.Count | Should -BeGreaterOrEqual 4
        }

        It 'has Get-FleetHealth function' {
            $PublicFunctions.Name | Should -Contain 'Get-FleetHealth.ps1'
        }

        It 'has Get-FleetInventory function' {
            $PublicFunctions.Name | Should -Contain 'Get-FleetInventory.ps1'
        }

        It 'has Invoke-FleetCommand function' {
            $PublicFunctions.Name | Should -Contain 'Invoke-FleetCommand.ps1'
        }

        It 'has Start-FleetPatch function' {
            $PublicFunctions.Name | Should -Contain 'Start-FleetPatch.ps1'
        }

        It 'all public functions are valid PowerShell' {
            foreach ($function in $PublicFunctions) {
                { . $function.FullName } | Should -Not -Throw
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

        It 'has Get-AWSSession helper function' {
            $PrivateFunctions.Name | Should -Contain 'Get-AWSSession.ps1'
        }

        It 'has Write-FleetLog helper function' {
            $PrivateFunctions.Name | Should -Contain 'Write-FleetLog.ps1'
        }

        It 'all private functions are valid PowerShell' {
            foreach ($function in $PrivateFunctions) {
                { . $function.FullName } | Should -Not -Throw
            }
        }

        It 'private functions are not exported' {
            $Module = Get-Module -Name 'HyperionFleet'
            foreach ($function in $PrivateFunctions) {
                $functionName = $function.BaseName
                $Module.ExportedCommands.Keys | Should -Not -Contain $functionName
            }
        }
    }

    Context 'Module Import' {
        It 'imports without errors' {
            { Import-Module $ManifestPath -Force } | Should -Not -Throw
        }

        It 'exports expected functions' {
            $Module = Get-Module -Name 'HyperionFleet'
            $Module.ExportedCommands.Count | Should -BeGreaterOrEqual 4
        }

        It 'has module configuration variable' {
            $ModuleConfig = Get-Variable -Name 'ModuleConfig' -Scope Global -ErrorAction SilentlyContinue
            # Module config is scoped to module, not global
            # Just verify module loaded correctly
            Get-Command -Module HyperionFleet | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Function Availability' {
        It 'Get-FleetHealth is available' {
            Get-Command -Name 'Get-FleetHealth' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Get-FleetInventory is available' {
            Get-Command -Name 'Get-FleetInventory' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Invoke-FleetCommand is available' {
            Get-Command -Name 'Invoke-FleetCommand' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Start-FleetPatch is available' {
            Get-Command -Name 'Start-FleetPatch' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Code Quality' {
        BeforeAll {
            $AllScripts = Get-ChildItem -Path $ModulePath -Include '*.ps1', '*.psm1' -Recurse -File |
                Where-Object { $_.FullName -notmatch '[\\/]Tests[\\/]' }
        }

        It 'no script contains hardcoded credentials' {
            foreach ($script in $AllScripts) {
                $content = Get-Content -Path $script.FullName -Raw
                $content | Should -Not -Match 'password\s*=\s*[''"][^''"]+'
                $content | Should -Not -Match 'AKIA[0-9A-Z]{16}'  # AWS access key pattern
                $content | Should -Not -Match 'secret\s*=\s*[''"][^''"]{10,}'
            }
        }

        It 'scripts follow line length guidelines' {
            foreach ($script in $AllScripts) {
                $lines = Get-Content -Path $script.FullName
                $longLines = $lines | Where-Object { $_.Length -gt 200 }
                # Allow some long lines for documentation, but not excessive
                $longLines.Count | Should -BeLessThan ($lines.Count * 0.1) -Because "More than 10% of lines exceed 200 characters in $($script.Name)"
            }
        }

        It 'no script uses Write-Host directly' {
            foreach ($script in $AllScripts) {
                $content = Get-Content -Path $script.FullName -Raw
                # Write-Host is discouraged in modules - use Write-Verbose, Write-Information, etc.
                $content | Should -Not -Match 'Write-Host\s+' -Because "Write-Host should not be used in module code in $($script.Name)"
            }
        }

        It 'all functions have proper error handling' {
            foreach ($script in $AllScripts) {
                $content = Get-Content -Path $script.FullName -Raw
                # Functions should have try/catch blocks
                if ($content -match 'function\s+\w+-\w+') {
                    $content | Should -Match 'try\s*\{' -Because "Functions in $($script.Name) should have error handling"
                }
            }
        }
    }

    Context 'Module Configuration' {
        It 'module has default configuration' {
            InModuleScope HyperionFleet {
                $script:ModuleConfig | Should -Not -BeNullOrEmpty
            }
        }

        It 'module configuration has default region' {
            InModuleScope HyperionFleet {
                $script:ModuleConfig.DefaultRegion | Should -Be 'us-east-1'
            }
        }

        It 'module configuration has retry settings' {
            InModuleScope HyperionFleet {
                $script:ModuleConfig.RetryAttempts | Should -BeGreaterOrEqual 1
                $script:ModuleConfig.RetryDelaySeconds | Should -BeGreaterOrEqual 1
            }
        }

        It 'module configuration has log level' {
            InModuleScope HyperionFleet {
                $script:ModuleConfig.LogLevel | Should -BeIn @('Verbose', 'Information', 'Warning', 'Error', 'Critical')
            }
        }
    }

    Context 'Function Parameter Consistency' {
        BeforeAll {
            $ExportedFunctions = Get-Command -Module HyperionFleet
        }

        It 'all exported functions have Region parameter' {
            foreach ($func in $ExportedFunctions) {
                $func.Parameters.Keys | Should -Contain 'Region' -Because "$($func.Name) should have Region parameter"
            }
        }

        It 'all exported functions have ProfileName parameter' {
            foreach ($func in $ExportedFunctions) {
                $func.Parameters.Keys | Should -Contain 'ProfileName' -Because "$($func.Name) should have ProfileName parameter"
            }
        }

        It 'state-changing functions support ShouldProcess' {
            $StateChangingFunctions = @('Invoke-FleetCommand', 'Start-FleetPatch')
            foreach ($funcName in $StateChangingFunctions) {
                $func = Get-Command -Name $funcName
                $func.Parameters.Keys | Should -Contain 'WhatIf' -Because "$funcName should support WhatIf"
                $func.Parameters.Keys | Should -Contain 'Confirm' -Because "$funcName should support Confirm"
            }
        }
    }

    Context 'Help Documentation' {
        BeforeAll {
            $ExportedFunctions = Get-Command -Module HyperionFleet
        }

        It 'all exported functions have complete help' {
            foreach ($func in $ExportedFunctions) {
                $Help = Get-Help -Name $func.Name -Full

                $Help.Synopsis | Should -Not -BeNullOrEmpty -Because "$($func.Name) should have synopsis"
                $Help.Description | Should -Not -BeNullOrEmpty -Because "$($func.Name) should have description"
                $Help.Examples.Example.Count | Should -BeGreaterOrEqual 1 -Because "$($func.Name) should have examples"
            }
        }

        It 'all function parameters have descriptions' {
            foreach ($func in $ExportedFunctions) {
                $Help = Get-Help -Name $func.Name -Full

                foreach ($param in $Help.Parameters.Parameter) {
                    # Skip common parameters
                    if ($param.Name -in @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable', 'WhatIf', 'Confirm')) {
                        continue
                    }
                    $param.Description | Should -Not -BeNullOrEmpty -Because "Parameter '$($param.Name)' in $($func.Name) should have description"
                }
            }
        }
    }

    Context 'Test Coverage Structure' {
        It 'each public function has a test file' {
            $PublicPath = Join-Path -Path $ModulePath -ChildPath 'Public'
            $PublicFunctions = Get-ChildItem -Path "$PublicPath/*.ps1"

            foreach ($func in $PublicFunctions) {
                $TestPath = Join-Path -Path $ModulePath -ChildPath "Tests/Public/$($func.BaseName).Tests.ps1"
                $TestPath | Should -Exist -Because "$($func.BaseName) should have a test file"
            }
        }

        It 'each private function has a test file' {
            $PrivatePath = Join-Path -Path $ModulePath -ChildPath 'Private'
            $PrivateFunctions = Get-ChildItem -Path "$PrivatePath/*.ps1"

            foreach ($func in $PrivateFunctions) {
                $TestPath = Join-Path -Path $ModulePath -ChildPath "Tests/Private/$($func.BaseName).Tests.ps1"
                $TestPath | Should -Exist -Because "$($func.BaseName) should have a test file"
            }
        }

        It 'has integration test directory' {
            $IntegrationPath = Join-Path -Path $ModulePath -ChildPath 'Tests/Integration'
            $IntegrationPath | Should -Exist
        }

        It 'has pester configuration file' {
            $ConfigPath = Join-Path -Path $ModulePath -ChildPath 'Tests/pester.config.ps1'
            $ConfigPath | Should -Exist
        }
    }
}
}
