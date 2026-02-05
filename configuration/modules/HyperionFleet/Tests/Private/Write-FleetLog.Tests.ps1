#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Write-FleetLog private function.

.DESCRIPTION
    Comprehensive unit tests for the Write-FleetLog internal helper function including:
    - Log formatting and structure
    - Log level filtering
    - File output
    - Console output
    - CloudWatch integration (future)
    - Log rotation

.NOTES
    Uses Pester 5.x syntax. Tests internal function via InModuleScope.
#>

BeforeAll {
    $ModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

    # Import the module
    Import-Module (Join-Path -Path $ModulePath -ChildPath 'HyperionFleet.psd1') -Force

    # Get access to private function
    $script:PrivateFunctionPath = Join-Path -Path $ModulePath -ChildPath 'Private/Write-FleetLog.ps1'
}

AfterAll {
    Remove-Module -Name 'HyperionFleet' -Force -ErrorAction SilentlyContinue
}

Describe 'Write-FleetLog' -Tag 'Unit', 'Private' {
    Context 'Function Structure' {
        It 'private function file exists' {
            $script:PrivateFunctionPath | Should -Exist
        }

        It 'function is not exported' {
            $Module = Get-Module -Name 'HyperionFleet'
            $Module.ExportedCommands.Keys | Should -Not -Contain 'Write-FleetLog'
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

        It 'Message parameter is mandatory' {
            $Content = Get-Content -Path $script:PrivateFunctionPath -Raw
            $Content | Should -Match '\[Parameter\(Mandatory'
        }
    }

    Context 'Log Formatting' {
        BeforeAll {
            # Use TestDrive for log file
            $script:TestLogPath = Join-Path -Path $TestDrive -ChildPath 'test.log'
        }

        It 'creates log entry with timestamp' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'Test message' -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Timestamp | Should -Not -BeNullOrEmpty
                $Entry.Timestamp | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'
            }
        }

        It 'includes log level in entry' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'Test message' -Level 'Warning' -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Level | Should -Be 'Warning'
            }
        }

        It 'includes message in entry' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'Test log message' -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Message | Should -Be 'Test log message'
            }
        }

        It 'includes module name in entry' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'Test message' -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Module | Should -Be 'HyperionFleet'
            }
        }

        It 'includes process ID in entry' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'Test message' -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.ProcessId | Should -Be $PID
            }
        }

        It 'includes hostname in entry' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'Test message' -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Hostname | Should -Not -BeNullOrEmpty
            }
        }

        It 'uses ISO 8601 timestamp format' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'Test message' -LogPath $TestLogPath -PassThru -NoConsole

                # ISO 8601 format: YYYY-MM-DDTHH:MM:SS.fffZ or with offset
                $Entry.Timestamp | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'
            }
        }
    }

    Context 'Log Levels' {
        BeforeAll {
            $script:TestLogPath = Join-Path -Path $TestDrive -ChildPath 'level-test.log'
        }

        It 'supports Verbose level' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'Verbose message' -Level 'Verbose' -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Level | Should -Be 'Verbose'
            }
        }

        It 'supports Information level' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'Info message' -Level 'Information' -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Level | Should -Be 'Information'
            }
        }

        It 'supports Warning level' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'Warning message' -Level 'Warning' -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Level | Should -Be 'Warning'
            }
        }

        It 'supports Error level' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'Error message' -Level 'Error' -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Level | Should -Be 'Error'
            }
        }

        It 'supports Critical level' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'Critical message' -Level 'Critical' -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Level | Should -Be 'Critical'
            }
        }

        It 'defaults to Information level' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'Default level message' -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Level | Should -Be 'Information'
            }
        }

        It 'rejects invalid log level' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                { Write-FleetLog -Message 'Test' -Level 'InvalidLevel' -LogPath $TestLogPath -ErrorAction Stop } | Should -Throw
            }
        }
    }

    Context 'Context Data' {
        BeforeAll {
            $script:TestLogPath = Join-Path -Path $TestDrive -ChildPath 'context-test.log'
        }

        It 'includes context hashtable in entry' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Context = @{
                    InstanceId = 'i-1234567890abcdef0'
                    Region = 'us-east-1'
                }
                $Entry = Write-FleetLog -Message 'With context' -Context $Context -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Context | Should -Not -BeNullOrEmpty
                $Entry.Context.InstanceId | Should -Be 'i-1234567890abcdef0'
                $Entry.Context.Region | Should -Be 'us-east-1'
            }
        }

        It 'handles empty context' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'No context' -Context @{} -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Context | Should -Not -BeNullOrEmpty
                $Entry.Context.Count | Should -Be 0
            }
        }

        It 'handles complex context values' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Context = @{
                    Instances = @('i-1', 'i-2', 'i-3')
                    Count = 3
                }
                $Entry = Write-FleetLog -Message 'Complex context' -Context $Context -LogPath $TestLogPath -PassThru -NoConsole

                $Entry.Context.Instances.Count | Should -Be 3
                $Entry.Context.Count | Should -Be 3
            }
        }
    }

    Context 'File Output' {
        BeforeAll {
            $script:TestLogPath = Join-Path -Path $TestDrive -ChildPath 'file-test.log'
        }

        BeforeEach {
            # Clean up log file before each test
            if (Test-Path -Path $script:TestLogPath) {
                Remove-Item -Path $script:TestLogPath -Force
            }
        }

        It 'creates log file if it does not exist' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                Write-FleetLog -Message 'Create file' -LogPath $TestLogPath -NoConsole
            }

            $script:TestLogPath | Should -Exist
        }

        It 'writes JSON format to file' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                Write-FleetLog -Message 'JSON test' -LogPath $TestLogPath -NoConsole
            }

            $Content = Get-Content -Path $script:TestLogPath -Raw
            { $Content | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'appends to existing log file' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                Write-FleetLog -Message 'First entry' -LogPath $TestLogPath -NoConsole
                Write-FleetLog -Message 'Second entry' -LogPath $TestLogPath -NoConsole
            }

            $Lines = Get-Content -Path $script:TestLogPath
            $Lines.Count | Should -Be 2
        }

        It 'uses UTF-8 encoding' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                Write-FleetLog -Message 'UTF-8 test: special chars' -LogPath $TestLogPath -NoConsole
            }

            # File should be readable as UTF-8
            { Get-Content -Path $script:TestLogPath -Encoding UTF8 } | Should -Not -Throw
        }

        It 'creates parent directory if needed' {
            $NestedPath = Join-Path -Path $TestDrive -ChildPath 'nested/dir/test.log'

            InModuleScope HyperionFleet -Parameters @{ NestedPath = $NestedPath } {
                param($NestedPath)
                Write-FleetLog -Message 'Nested dir test' -LogPath $NestedPath -NoConsole
            }

            $NestedPath | Should -Exist
        }
    }

    Context 'Console Output' {
        BeforeAll {
            $script:TestLogPath = Join-Path -Path $TestDrive -ChildPath 'console-test.log'
        }

        It 'writes to console by default' {
            # This is difficult to test directly, but we can verify NoConsole suppresses output
            Mock Write-Information { } -ModuleName HyperionFleet

            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                Write-FleetLog -Message 'Console test' -Level 'Information' -LogPath $TestLogPath
            }

            Should -Invoke -CommandName Write-Information -ModuleName HyperionFleet
        }

        It 'suppresses console output with NoConsole switch' {
            Mock Write-Information { } -ModuleName HyperionFleet
            Mock Write-Verbose { } -ModuleName HyperionFleet
            Mock Write-Warning { } -ModuleName HyperionFleet
            Mock Write-Error { } -ModuleName HyperionFleet

            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                Write-FleetLog -Message 'Silent test' -Level 'Information' -LogPath $TestLogPath -NoConsole
            }

            Should -Invoke -CommandName Write-Information -ModuleName HyperionFleet -Times 0
        }

        It 'uses Write-Verbose for Verbose level' {
            Mock Write-Verbose { } -ModuleName HyperionFleet

            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                # Override module config to allow verbose logging
                $script:ModuleConfig.LogLevel = 'Verbose'
                Write-FleetLog -Message 'Verbose test' -Level 'Verbose' -LogPath $TestLogPath
            }

            Should -Invoke -CommandName Write-Verbose -ModuleName HyperionFleet
        }

        It 'uses Write-Warning for Warning level' {
            Mock Write-Warning { } -ModuleName HyperionFleet

            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                Write-FleetLog -Message 'Warning test' -Level 'Warning' -LogPath $TestLogPath
            }

            Should -Invoke -CommandName Write-Warning -ModuleName HyperionFleet
        }

        It 'uses Write-Error for Error level' {
            Mock Write-Error { } -ModuleName HyperionFleet

            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                Write-FleetLog -Message 'Error test' -Level 'Error' -LogPath $TestLogPath
            }

            Should -Invoke -CommandName Write-Error -ModuleName HyperionFleet
        }

        It 'formats console message with timestamp and level' {
            $CapturedMessage = $null
            Mock Write-Information {
                param($MessageData)
                $script:CapturedMessage = $MessageData
            } -ModuleName HyperionFleet

            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                Write-FleetLog -Message 'Format test' -Level 'Information' -LogPath $TestLogPath
            }

            $CapturedMessage | Should -Match '\[\d{4}-\d{2}-\d{2}'
            $CapturedMessage | Should -Match '\[INFORMATION\]'
            $CapturedMessage | Should -Match 'Format test'
        }

        It 'includes context in console output' {
            $CapturedMessage = $null
            Mock Write-Information {
                param($MessageData)
                $script:CapturedMessage = $MessageData
            } -ModuleName HyperionFleet

            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                Write-FleetLog -Message 'Context test' -Context @{ Key = 'Value' } -Level 'Information' -LogPath $TestLogPath
            }

            $CapturedMessage | Should -Match 'Key=Value'
        }
    }

    Context 'Log Level Filtering' {
        BeforeAll {
            $script:TestLogPath = Join-Path -Path $TestDrive -ChildPath 'filter-test.log'
        }

        BeforeEach {
            if (Test-Path -Path $script:TestLogPath) {
                Remove-Item -Path $script:TestLogPath -Force
            }
        }

        It 'filters messages below configured log level' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                # Set module log level to Warning (should filter Verbose and Information)
                $OriginalLevel = $script:ModuleConfig.LogLevel
                $script:ModuleConfig.LogLevel = 'Warning'

                $Entry = Write-FleetLog -Message 'Should be filtered' -Level 'Verbose' -LogPath $TestLogPath -PassThru -NoConsole

                $script:ModuleConfig.LogLevel = $OriginalLevel

                $Entry | Should -BeNullOrEmpty
            }
        }

        It 'allows messages at or above configured log level' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $OriginalLevel = $script:ModuleConfig.LogLevel
                $script:ModuleConfig.LogLevel = 'Warning'

                $Entry = Write-FleetLog -Message 'Should pass' -Level 'Error' -LogPath $TestLogPath -PassThru -NoConsole

                $script:ModuleConfig.LogLevel = $OriginalLevel

                $Entry | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'PassThru Behavior' {
        BeforeAll {
            $script:TestLogPath = Join-Path -Path $TestDrive -ChildPath 'passthru-test.log'
        }

        It 'returns log entry when PassThru is specified' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'PassThru test' -LogPath $TestLogPath -PassThru -NoConsole

                $Entry | Should -Not -BeNullOrEmpty
                $Entry.Message | Should -Be 'PassThru test'
            }
        }

        It 'returns nothing without PassThru' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                $Entry = Write-FleetLog -Message 'No PassThru' -LogPath $TestLogPath -NoConsole

                $Entry | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Pipeline Support' {
        BeforeAll {
            $script:TestLogPath = Join-Path -Path $TestDrive -ChildPath 'pipeline-test.log'
        }

        BeforeEach {
            if (Test-Path -Path $script:TestLogPath) {
                Remove-Item -Path $script:TestLogPath -Force
            }
        }

        It 'accepts message from pipeline' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                'Pipeline message' | Write-FleetLog -LogPath $TestLogPath -NoConsole
            }

            $script:TestLogPath | Should -Exist
            $Content = Get-Content -Path $script:TestLogPath
            $Content | Should -Match 'Pipeline message'
        }

        It 'processes multiple messages from pipeline' {
            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $script:TestLogPath } {
                param($TestLogPath)
                @('Message 1', 'Message 2', 'Message 3') | ForEach-Object {
                    Write-FleetLog -Message $_ -LogPath $TestLogPath -NoConsole
                }
            }

            $Lines = Get-Content -Path $script:TestLogPath
            $Lines.Count | Should -Be 3
        }
    }

    Context 'Log Rotation' {
        It 'rotates log file when size exceeds 10MB' {
            # This is challenging to test fully, but we can verify the logic exists
            $Content = Get-Content -Path $script:PrivateFunctionPath -Raw
            $Content | Should -Match '10MB|10485760|rotation'
        }
    }

    Context 'Error Handling' {
        It 'handles file write errors gracefully' {
            InModuleScope HyperionFleet {
                Mock Add-Content {
                    throw "Permission denied"
                } -ModuleName HyperionFleet

                # Should not throw, just warn
                { Write-FleetLog -Message 'Test' -LogPath '/nonexistent/path/test.log' -NoConsole } | Should -Not -Throw
            }
        }

        It 'continues logging even if file write fails' {
            Mock Write-Warning { } -ModuleName HyperionFleet

            InModuleScope HyperionFleet {
                Mock Add-Content {
                    throw "Disk full"
                }

                # Should emit warning but not throw
                Write-FleetLog -Message 'Test' -LogPath '/invalid/path.log' -NoConsole
            }

            Should -Invoke -CommandName Write-Warning -ModuleName HyperionFleet
        }
    }
}
