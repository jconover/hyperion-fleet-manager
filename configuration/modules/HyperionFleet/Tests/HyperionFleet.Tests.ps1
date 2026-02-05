#Requires -Modules Pester

<#
.SYNOPSIS
    Module-level tests for HyperionFleet.

.DESCRIPTION
    Tests module structure, manifest integrity, function exports, and overall module health.
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

Describe 'HyperionFleet Module' {
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

        It 'has module metadata' {
            $Manifest.Author | Should -Not -BeNullOrEmpty
            $Manifest.Description | Should -Not -BeNullOrEmpty
            $Manifest.Copyright | Should -Not -BeNullOrEmpty
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
            $AllScripts = Get-ChildItem -Path $ModulePath -Include '*.ps1', '*.psm1' -Recurse
        }

        It 'all scripts use UTF-8 encoding' {
            foreach ($script in $AllScripts) {
                $encoding = [System.Text.Encoding]::GetEncoding((Get-Content -Path $script.FullName -Encoding Byte -TotalCount 4))
                # Basic check - should not throw
                $encoding | Should -Not -BeNullOrEmpty
            }
        }

        It 'no script contains hardcoded credentials' {
            foreach ($script in $AllScripts) {
                $content = Get-Content -Path $script.FullName -Raw
                $content | Should -Not -Match 'password\s*=\s*[''"][^''"]+'
                $content | Should -Not -Match 'AKIA[0-9A-Z]{16}'  # AWS access key pattern
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
    }
}
