#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Write-StructuredLog and related structured logging functions.

.DESCRIPTION
    Comprehensive unit tests for the structured logging system including:
    - Write-StructuredLog function
    - New-CorrelationId function
    - Start-LogScope function
    - LogEntry class
    - Log level filtering
    - Output formats (JSON, Console)
    - CloudWatch integration

.NOTES
    Uses Pester 5.x syntax.
#>

BeforeAll {
    $ModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

    # Import the module
    Import-Module (Join-Path -Path $ModulePath -ChildPath 'HyperionFleet.psd1') -Force

    # Store original log level
    $script:OriginalLogLevel = $script:ModuleConfig.LogLevel
}

AfterAll {
    # Restore original log level
    InModuleScope HyperionFleet {
        $script:ModuleConfig.LogLevel = $script:OriginalLogLevel
    }

    Remove-Module -Name 'HyperionFleet' -Force -ErrorAction SilentlyContinue
}

Describe 'Write-StructuredLog' -Tag 'Unit', 'Public', 'Logging' {
    BeforeAll {
        $script:TestLogPath = Join-Path -Path $TestDrive -ChildPath 'structured-test.log'
    }

    BeforeEach {
        # Clean up log file before each test
        if (Test-Path -Path $script:TestLogPath) {
            Remove-Item -Path $script:TestLogPath -Force
        }

        # Reset log level to Information
        InModuleScope HyperionFleet {
            $script:ModuleConfig.LogLevel = 'Information'
            $script:CurrentCorrelationContext = $null
            $script:CurrentLogScope = $null
        }
    }

    Context 'Function Structure' {
        It 'function is exported' {
            $Module = Get-Module -Name 'HyperionFleet'
            $Module.ExportedCommands.Keys | Should -Contain 'Write-StructuredLog'
        }

        It 'function has CmdletBinding attribute' {
            $Command = Get-Command -Name 'Write-StructuredLog' -Module 'HyperionFleet'
            $Command.CmdletBinding | Should -Be $true
        }

        It 'Message parameter is mandatory' {
            $Command = Get-Command -Name 'Write-StructuredLog' -Module 'HyperionFleet'
            $Command.Parameters['Message'].Attributes.Mandatory | Should -Contain $true
        }

        It 'Level parameter has valid values' {
            $Command = Get-Command -Name 'Write-StructuredLog' -Module 'HyperionFleet'
            $ValidateSet = $Command.Parameters['Level'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $ValidateSet.ValidValues | Should -Contain 'Verbose'
            $ValidateSet.ValidValues | Should -Contain 'Debug'
            $ValidateSet.ValidValues | Should -Contain 'Information'
            $ValidateSet.ValidValues | Should -Contain 'Warning'
            $ValidateSet.ValidValues | Should -Contain 'Error'
            $ValidateSet.ValidValues | Should -Contain 'Critical'
        }
    }

    Context 'Log Entry Creation' {
        It 'creates log entry with PassThru' {
            $Entry = Write-StructuredLog -Message 'Test message' -PassThru -NoConsole

            $Entry | Should -Not -BeNullOrEmpty
            $Entry.Message | Should -Be 'Test message'
        }

        It 'sets correct log level' {
            $Entry = Write-StructuredLog -Message 'Warning test' -Level 'Warning' -PassThru -NoConsole

            $Entry.Level | Should -Be ([LogLevel]::Warning)
        }

        It 'defaults to Information level' {
            $Entry = Write-StructuredLog -Message 'Default level' -PassThru -NoConsole

            $Entry.Level | Should -Be ([LogLevel]::Information)
        }

        It 'includes timestamp in UTC' {
            $Entry = Write-StructuredLog -Message 'Timestamp test' -PassThru -NoConsole

            $Entry.Timestamp | Should -Not -BeNullOrEmpty
            $Entry.Timestamp.Kind | Should -Be 'Utc'
        }

        It 'includes machine name' {
            $Entry = Write-StructuredLog -Message 'Machine test' -PassThru -NoConsole

            $Entry.MachineName | Should -Not -BeNullOrEmpty
        }

        It 'includes process ID' {
            $Entry = Write-StructuredLog -Message 'PID test' -PassThru -NoConsole

            $Entry.ProcessId | Should -Be $PID
        }

        It 'includes username' {
            $Entry = Write-StructuredLog -Message 'User test' -PassThru -NoConsole

            $Entry.Username | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Context Data' {
        It 'includes context hashtable' {
            $Context = @{
                InstanceId = 'i-1234567890abcdef0'
                Region = 'us-east-1'
            }
            $Entry = Write-StructuredLog -Message 'With context' -Context $Context -PassThru -NoConsole

            $Entry.Context | Should -Not -BeNullOrEmpty
            $Entry.Context.InstanceId | Should -Be 'i-1234567890abcdef0'
            $Entry.Context.Region | Should -Be 'us-east-1'
        }

        It 'handles empty context' {
            $Entry = Write-StructuredLog -Message 'Empty context' -Context @{} -PassThru -NoConsole

            $Entry.Context | Should -Not -BeNullOrEmpty
            $Entry.Context.Count | Should -Be 0
        }

        It 'includes exception details when provided' {
            try {
                throw 'Test exception'
            }
            catch {
                $Entry = Write-StructuredLog -Message 'Exception test' -Level Error -Exception $_.Exception -PassThru -NoConsole
            }

            $Entry.Context.exceptionType | Should -Not -BeNullOrEmpty
            $Entry.Context.exceptionMessage | Should -Be 'Test exception'
        }
    }

    Context 'Correlation ID Support' {
        It 'uses provided correlation ID' {
            $CorrelationId = [guid]::NewGuid().ToString()
            $Entry = Write-StructuredLog -Message 'Correlation test' -CorrelationId $CorrelationId -PassThru -NoConsole

            $Entry.CorrelationId | Should -Be $CorrelationId
        }

        It 'uses current context correlation ID when not provided' {
            $CorrelationId = New-CorrelationId -SetAsCurrent

            $Entry = Write-StructuredLog -Message 'Context correlation' -PassThru -NoConsole

            $Entry.CorrelationId | Should -Be $CorrelationId

            Clear-CorrelationId
        }

        It 'handles missing correlation ID gracefully' {
            Clear-CorrelationId -All

            $Entry = Write-StructuredLog -Message 'No correlation' -PassThru -NoConsole

            $Entry.CorrelationId | Should -BeNullOrEmpty
        }
    }

    Context 'JSON Output' {
        It 'produces valid JSON with ToJson method' {
            $Entry = Write-StructuredLog -Message 'JSON test' -PassThru -NoConsole
            $Json = $Entry.ToJson()

            { $Json | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'includes all required fields in JSON' {
            $Entry = Write-StructuredLog -Message 'JSON fields' -Level Warning -PassThru -NoConsole
            $JsonObj = $Entry.ToJson() | ConvertFrom-Json

            $JsonObj.timestamp | Should -Not -BeNullOrEmpty
            $JsonObj.level | Should -Be 'Warning'
            $JsonObj.message | Should -Be 'JSON fields'
            $JsonObj.metadata.machineName | Should -Not -BeNullOrEmpty
            $JsonObj.metadata.processId | Should -Be $PID
        }

        It 'uses ISO 8601 timestamp format' {
            $Entry = Write-StructuredLog -Message 'ISO timestamp' -PassThru -NoConsole
            $JsonObj = $Entry.ToJson() | ConvertFrom-Json

            $JsonObj.timestamp | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'
        }

        It 'includes correlation ID in JSON when present' {
            $CorrelationId = New-CorrelationId -SetAsCurrent
            $Entry = Write-StructuredLog -Message 'Correlation JSON' -PassThru -NoConsole
            $JsonObj = $Entry.ToJson() | ConvertFrom-Json

            $JsonObj.correlationId | Should -Be $CorrelationId

            Clear-CorrelationId
        }
    }

    Context 'Console Output' {
        It 'produces human-readable output with ToConsoleString' {
            $Entry = Write-StructuredLog -Message 'Console test' -PassThru -NoConsole
            $ConsoleStr = $Entry.ToConsoleString()

            $ConsoleStr | Should -Match '\[\d{4}-\d{2}-\d{2}'
            $ConsoleStr | Should -Match 'INFORMATION'
            $ConsoleStr | Should -Match 'Console test'
        }

        It 'includes correlation ID in console output' {
            $CorrelationId = New-CorrelationId -SetAsCurrent
            $Entry = Write-StructuredLog -Message 'Console correlation' -PassThru -NoConsole
            $ConsoleStr = $Entry.ToConsoleString()

            # Should include first 8 characters of correlation ID
            $ConsoleStr | Should -Match "\[$($CorrelationId.Substring(0, 8))\]"

            Clear-CorrelationId
        }

        It 'includes context in console output' {
            $Entry = Write-StructuredLog -Message 'Console context' -Context @{ Key = 'Value' } -PassThru -NoConsole
            $ConsoleStr = $Entry.ToConsoleString()

            $ConsoleStr | Should -Match 'Key=Value'
        }
    }

    Context 'Log Level Filtering' {
        It 'filters messages below configured level' {
            InModuleScope HyperionFleet {
                $script:ModuleConfig.LogLevel = 'Warning'
            }

            $Entry = Write-StructuredLog -Message 'Should be filtered' -Level 'Information' -PassThru -NoConsole

            $Entry | Should -BeNullOrEmpty
        }

        It 'allows messages at configured level' {
            InModuleScope HyperionFleet {
                $script:ModuleConfig.LogLevel = 'Warning'
            }

            $Entry = Write-StructuredLog -Message 'Should pass' -Level 'Warning' -PassThru -NoConsole

            $Entry | Should -Not -BeNullOrEmpty
        }

        It 'allows messages above configured level' {
            InModuleScope HyperionFleet {
                $script:ModuleConfig.LogLevel = 'Warning'
            }

            $Entry = Write-StructuredLog -Message 'Error passes' -Level 'Error' -PassThru -NoConsole

            $Entry | Should -Not -BeNullOrEmpty
        }
    }

    Context 'File Output' {
        It 'writes to log file when LogPath specified' {
            Write-StructuredLog -Message 'File test' -LogPath $script:TestLogPath -NoConsole

            $script:TestLogPath | Should -Exist
        }

        It 'writes JSON format to file' {
            Write-StructuredLog -Message 'JSON file test' -LogPath $script:TestLogPath -NoConsole

            $Content = Get-Content -Path $script:TestLogPath -Raw
            { $Content | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'appends to existing file' {
            Write-StructuredLog -Message 'First entry' -LogPath $script:TestLogPath -NoConsole
            Write-StructuredLog -Message 'Second entry' -LogPath $script:TestLogPath -NoConsole

            $Lines = Get-Content -Path $script:TestLogPath
            $Lines.Count | Should -Be 2
        }

        It 'creates parent directory if needed' {
            $NestedPath = Join-Path -Path $TestDrive -ChildPath 'nested/dir/test.log'

            Write-StructuredLog -Message 'Nested test' -LogPath $NestedPath -NoConsole

            $NestedPath | Should -Exist
        }
    }

    Context 'Pipeline Support' {
        It 'accepts message from pipeline' {
            'Pipeline message' | Write-StructuredLog -LogPath $script:TestLogPath -NoConsole

            $Content = Get-Content -Path $script:TestLogPath
            $Content | Should -Match 'Pipeline message'
        }
    }

    Context 'Error Handling' {
        It 'handles logging errors gracefully' {
            # Should not throw even if something goes wrong internally
            { Write-StructuredLog -Message 'Error handling test' -NoConsole } | Should -Not -Throw
        }
    }
}

Describe 'New-CorrelationId' -Tag 'Unit', 'Public', 'Logging' {
    BeforeEach {
        Clear-CorrelationId -All
    }

    AfterEach {
        Clear-CorrelationId -All
    }

    Context 'Function Structure' {
        It 'function is exported' {
            $Module = Get-Module -Name 'HyperionFleet'
            $Module.ExportedCommands.Keys | Should -Contain 'New-CorrelationId'
        }
    }

    Context 'ID Generation' {
        It 'generates valid GUID format' {
            $Id = New-CorrelationId

            { [guid]::Parse($Id) } | Should -Not -Throw
        }

        It 'generates unique IDs' {
            $Id1 = New-CorrelationId
            $Id2 = New-CorrelationId

            $Id1 | Should -Not -Be $Id2
        }

        It 'applies prefix when specified' {
            $Id = New-CorrelationId -Prefix 'fleet'

            $Id | Should -Match '^fleet-[a-f0-9]{8}-'
        }
    }

    Context 'Context Management' {
        It 'sets as current when SetAsCurrent is specified' {
            $Id = New-CorrelationId -SetAsCurrent

            $Current = Get-CorrelationId
            $Current | Should -Be $Id
        }

        It 'does not set as current without SetAsCurrent' {
            $null = New-CorrelationId

            $Current = Get-CorrelationId
            $Current | Should -BeNullOrEmpty
        }

        It 'returns context object with PassThru' {
            $Context = New-CorrelationId -PassThru

            $Context.PSTypeName | Should -Contain 'HyperionFleet.CorrelationContext'
            $Context.CorrelationId | Should -Not -BeNullOrEmpty
            $Context.CreatedAt | Should -Not -BeNullOrEmpty
        }

        It 'includes parent correlation ID in context' {
            $ParentId = New-CorrelationId
            $Context = New-CorrelationId -ParentCorrelationId $ParentId -PassThru

            $Context.ParentCorrelationId | Should -Be $ParentId
        }
    }

    Context 'Nested Scopes' {
        It 'supports correlation stack for nested scopes' {
            $Id1 = New-CorrelationId -SetAsCurrent
            $Id2 = New-CorrelationId -ParentCorrelationId $Id1 -SetAsCurrent

            $Current = Get-CorrelationId
            $Current | Should -Be $Id2

            Clear-CorrelationId  # Pop to parent
            $Current = Get-CorrelationId
            $Current | Should -Be $Id1
        }
    }
}

Describe 'Get-CorrelationId' -Tag 'Unit', 'Public', 'Logging' {
    BeforeEach {
        Clear-CorrelationId -All
    }

    AfterEach {
        Clear-CorrelationId -All
    }

    Context 'Retrieval' {
        It 'returns null when no correlation is set' {
            $Id = Get-CorrelationId

            $Id | Should -BeNullOrEmpty
        }

        It 'returns current correlation ID' {
            $ExpectedId = New-CorrelationId -SetAsCurrent

            $Id = Get-CorrelationId

            $Id | Should -Be $ExpectedId
        }

        It 'creates new ID when CreateIfMissing is specified' {
            $Id = Get-CorrelationId -CreateIfMissing

            $Id | Should -Not -BeNullOrEmpty
            { [guid]::Parse($Id) } | Should -Not -Throw
        }
    }
}

Describe 'Clear-CorrelationId' -Tag 'Unit', 'Public', 'Logging' {
    BeforeEach {
        Clear-CorrelationId -All
    }

    Context 'Clearing' {
        It 'clears current correlation' {
            $null = New-CorrelationId -SetAsCurrent
            Clear-CorrelationId

            $Id = Get-CorrelationId
            $Id | Should -BeNullOrEmpty
        }

        It 'clears all with -All switch' {
            $null = New-CorrelationId -SetAsCurrent
            $null = New-CorrelationId -SetAsCurrent
            Clear-CorrelationId -All

            $Id = Get-CorrelationId
            $Id | Should -BeNullOrEmpty
        }
    }
}

Describe 'Start-LogScope' -Tag 'Unit', 'Public', 'Logging' {
    BeforeAll {
        $script:TestLogPath = Join-Path -Path $TestDrive -ChildPath 'scope-test.log'
    }

    BeforeEach {
        Clear-CorrelationId -All
        if (Test-Path -Path $script:TestLogPath) {
            Remove-Item -Path $script:TestLogPath -Force
        }
    }

    AfterEach {
        Clear-CorrelationId -All
    }

    Context 'Function Structure' {
        It 'function is exported' {
            $Module = Get-Module -Name 'HyperionFleet'
            $Module.ExportedCommands.Keys | Should -Contain 'Start-LogScope'
        }

        It 'ScopeName parameter is mandatory' {
            $Command = Get-Command -Name 'Start-LogScope' -Module 'HyperionFleet'
            $Command.Parameters['ScopeName'].Attributes.Mandatory | Should -Contain $true
        }
    }

    Context 'Scope Creation' {
        It 'returns LogScope object' {
            $Scope = Start-LogScope -ScopeName 'TestScope' -NoEntryLog -NoExitLog

            try {
                $Scope | Should -Not -BeNullOrEmpty
                $Scope.GetType().Name | Should -Be 'LogScope'
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'sets scope name' {
            $Scope = Start-LogScope -ScopeName 'MyScope' -NoEntryLog -NoExitLog

            try {
                $Scope.ScopeName | Should -Be 'MyScope'
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'generates correlation ID' {
            $Scope = Start-LogScope -ScopeName 'CorrelationScope' -NoEntryLog -NoExitLog

            try {
                $Scope.CorrelationId | Should -Not -BeNullOrEmpty
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'uses provided correlation ID' {
            $ExplicitId = [guid]::NewGuid().ToString()
            $Scope = Start-LogScope -ScopeName 'ExplicitScope' -CorrelationId $ExplicitId -NoEntryLog -NoExitLog

            try {
                $Scope.CorrelationId | Should -Be $ExplicitId
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'inherits parent correlation ID' {
            $ParentId = New-CorrelationId -SetAsCurrent
            $Scope = Start-LogScope -ScopeName 'ChildScope' -NoEntryLog -NoExitLog

            try {
                $Scope.ParentCorrelationId | Should -Be $ParentId
            }
            finally {
                $Scope.Dispose()
            }
        }
    }

    Context 'Duration Tracking' {
        It 'tracks elapsed time' {
            $Scope = Start-LogScope -ScopeName 'DurationScope' -NoEntryLog -NoExitLog

            try {
                Start-Sleep -Milliseconds 50
                $Elapsed = $Scope.GetElapsed()

                $Elapsed.TotalMilliseconds | Should -BeGreaterThan 40
            }
            finally {
                $Scope.Dispose()
            }
        }
    }

    Context 'Disposal' {
        It 'is disposable' {
            $Scope = Start-LogScope -ScopeName 'DisposableScope' -NoEntryLog -NoExitLog

            $Scope.Dispose()

            $Scope.IsDisposed | Should -Be $true
        }
    }
}

Describe 'Use-LogScope' -Tag 'Unit', 'Public', 'Logging' {
    BeforeEach {
        Clear-CorrelationId -All
    }

    AfterEach {
        Clear-CorrelationId -All
    }

    Context 'Function Structure' {
        It 'function is exported' {
            $Module = Get-Module -Name 'HyperionFleet'
            $Module.ExportedCommands.Keys | Should -Contain 'Use-LogScope'
        }
    }

    Context 'Execution' {
        It 'executes script block' {
            $Executed = $false

            Use-LogScope -ScopeName 'ExecutionScope' -ScriptBlock {
                $script:Executed = $true
            }

            $script:Executed | Should -Be $true
        }

        It 'returns script block output' {
            $Result = Use-LogScope -ScopeName 'OutputScope' -ScriptBlock {
                'Test output'
            }

            $Result | Should -Be 'Test output'
        }

        It 'passes arguments to script block' {
            $Result = Use-LogScope -ScopeName 'ArgumentScope' -ScriptBlock {
                param($Value)
                $Value * 2
            } -ArgumentList 21

            $Result | Should -Be 42
        }

        It 'disposes scope even on error' {
            try {
                Use-LogScope -ScopeName 'ErrorScope' -ScriptBlock {
                    throw 'Test error'
                }
            }
            catch {
                # Expected
            }

            # Correlation should be cleared after scope disposal
            $Id = Get-CorrelationId
            $Id | Should -BeNullOrEmpty
        }
    }
}

Describe 'LogEntry Class' -Tag 'Unit', 'Class', 'Logging' {
    Context 'Construction' {
        It 'creates with default constructor' {
            $Entry = [LogEntry]::new()

            $Entry | Should -Not -BeNullOrEmpty
            $Entry.Level | Should -Be ([LogLevel]::Information)
        }

        It 'creates with message and level' {
            $Entry = [LogEntry]::new('Test message', [LogLevel]::Warning)

            $Entry.Message | Should -Be 'Test message'
            $Entry.Level | Should -Be ([LogLevel]::Warning)
        }

        It 'creates with full details' {
            $CorrelationId = [guid]::NewGuid().ToString()
            $Context = @{ Key = 'Value' }
            $Entry = [LogEntry]::new('Full test', [LogLevel]::Error, $CorrelationId, $Context)

            $Entry.Message | Should -Be 'Full test'
            $Entry.Level | Should -Be ([LogLevel]::Error)
            $Entry.CorrelationId | Should -Be $CorrelationId
            $Entry.Context.Key | Should -Be 'Value'
        }
    }

    Context 'ToJson Method' {
        It 'produces valid JSON' {
            $Entry = [LogEntry]::new('JSON test', [LogLevel]::Information)
            $Json = $Entry.ToJson()

            { $Json | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'includes required fields' {
            $Entry = [LogEntry]::new('Fields test', [LogLevel]::Warning)
            $Obj = $Entry.ToJson() | ConvertFrom-Json

            $Obj.timestamp | Should -Not -BeNullOrEmpty
            $Obj.level | Should -Be 'Warning'
            $Obj.message | Should -Be 'Fields test'
        }

        It 'includes duration when set' {
            $Entry = [LogEntry]::new('Duration test', [LogLevel]::Information)
            $Entry.Duration = [timespan]::FromMilliseconds(150)
            $Obj = $Entry.ToJson() | ConvertFrom-Json

            $Obj.durationMs | Should -Be 150
        }
    }

    Context 'ToConsoleString Method' {
        It 'produces readable output' {
            $Entry = [LogEntry]::new('Console test', [LogLevel]::Information)
            $Str = $Entry.ToConsoleString()

            $Str | Should -Match '\[\d{4}-\d{2}-\d{2}'
            $Str | Should -Match 'INFORMATION'
            $Str | Should -Match 'Console test'
        }

        It 'includes context' {
            $Entry = [LogEntry]::new('Context test', [LogLevel]::Information)
            $Entry.Context = @{ TestKey = 'TestValue' }
            $Str = $Entry.ToConsoleString()

            $Str | Should -Match 'TestKey=TestValue'
        }

        It 'includes duration' {
            $Entry = [LogEntry]::new('Duration test', [LogLevel]::Information)
            $Entry.Duration = [timespan]::FromMilliseconds(100.5)
            $Str = $Entry.ToConsoleString()

            $Str | Should -Match 'Duration:'
            $Str | Should -Match '100\.50'
        }
    }

    Context 'Clone Method' {
        It 'creates independent copy' {
            $Entry = [LogEntry]::new('Clone test', [LogLevel]::Information)
            $Entry.Context = @{ Key = 'Value' }
            $Clone = $Entry.Clone()

            $Clone.Message | Should -Be $Entry.Message
            $Clone.Context.Key | Should -Be 'Value'

            # Modify original, clone should not change
            $Entry.Message = 'Modified'
            $Clone.Message | Should -Be 'Clone test'
        }
    }
}

Describe 'LogLevel Enum' -Tag 'Unit', 'Class', 'Logging' {
    Context 'Values' {
        It 'has correct numeric values for ordering' {
            [int][LogLevel]::Verbose | Should -Be 0
            [int][LogLevel]::Debug | Should -Be 1
            [int][LogLevel]::Information | Should -Be 2
            [int][LogLevel]::Warning | Should -Be 3
            [int][LogLevel]::Error | Should -Be 4
            [int][LogLevel]::Critical | Should -Be 5
        }

        It 'supports comparison' {
            [LogLevel]::Error -gt [LogLevel]::Warning | Should -Be $true
            [LogLevel]::Verbose -lt [LogLevel]::Information | Should -Be $true
        }
    }
}

Describe 'CloudWatch Integration' -Tag 'Unit', 'Public', 'Logging', 'CloudWatch' {
    BeforeAll {
        $script:MockCloudWatchCalls = @()
    }

    BeforeEach {
        $script:MockCloudWatchCalls = @()

        # Reset CloudWatch configuration
        InModuleScope HyperionFleet {
            $script:ModuleConfig.CloudWatchLogging = $false
            $script:CloudWatchLogBuffer = $null
        }
    }

    Context 'CloudWatch Buffer Management' {
        It 'does not buffer when CloudWatch disabled' {
            InModuleScope HyperionFleet {
                $script:ModuleConfig.CloudWatchLogging = $false
            }

            Write-StructuredLog -Message 'No buffer test' -NoConsole

            InModuleScope HyperionFleet {
                $script:CloudWatchLogBuffer | Should -BeNullOrEmpty
            }
        }

        It 'buffers log entries when CloudWatch enabled' {
            InModuleScope HyperionFleet {
                $script:ModuleConfig.CloudWatchLogging = $true
                $script:CloudWatchLogBuffer = [System.Collections.Concurrent.ConcurrentQueue[LogEntry]]::new()
            }

            Write-StructuredLog -Message 'Buffer test' -NoConsole

            InModuleScope HyperionFleet {
                $script:CloudWatchLogBuffer.Count | Should -BeGreaterThan 0
            }
        }

        It 'adds to buffer with SendToCloudWatch switch' {
            InModuleScope HyperionFleet {
                $script:CloudWatchLogBuffer = [System.Collections.Concurrent.ConcurrentQueue[LogEntry]]::new()
            }

            Write-StructuredLog -Message 'Explicit CloudWatch test' -SendToCloudWatch -NoConsole

            InModuleScope HyperionFleet {
                $script:CloudWatchLogBuffer.Count | Should -BeGreaterThan 0
            }
        }
    }

    Context 'CloudWatch Event Format' {
        It 'creates valid CloudWatch event format' {
            $Entry = Write-StructuredLog -Message 'CloudWatch format test' -PassThru -NoConsole
            $CloudWatchEvent = $Entry.ToCloudWatchFormat()

            $CloudWatchEvent | Should -Not -BeNullOrEmpty
            $CloudWatchEvent.Timestamp | Should -BeOfType [long]
            $CloudWatchEvent.Message | Should -Not -BeNullOrEmpty
        }

        It 'CloudWatch timestamp is epoch milliseconds' {
            $Entry = [LogEntry]::new('Epoch test', [LogLevel]::Information)
            $Entry.Timestamp = [datetime]::Parse('2024-01-01T12:00:00Z')

            $CloudWatchEvent = $Entry.ToCloudWatchFormat()

            # Expected: 1704110400000 (2024-01-01 12:00:00 UTC in epoch ms)
            $CloudWatchEvent.Timestamp | Should -Be 1704110400000
        }

        It 'CloudWatch message contains JSON' {
            $Entry = Write-StructuredLog -Message 'JSON content test' -PassThru -NoConsole
            $CloudWatchEvent = $Entry.ToCloudWatchFormat()

            { $CloudWatchEvent.Message | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context 'Send-LogToCloudWatch Function' {
        BeforeAll {
            # Mock the AWS module check
            Mock -ModuleName HyperionFleet -CommandName Get-Module -MockWith {
                if ($Name -eq 'AWS.Tools.CloudWatchLogs' -and $ListAvailable) {
                    return $null  # Module not available
                }
            }
        }

        It 'handles missing AWS module gracefully' {
            InModuleScope HyperionFleet {
                $script:ModuleConfig.CloudWatchLogging = $true
                $script:CloudWatchLogBuffer = [System.Collections.Concurrent.ConcurrentQueue[LogEntry]]::new()

                $entry = [LogEntry]::new('Test message', [LogLevel]::Information)
                $script:CloudWatchLogBuffer.Enqueue($entry)

                # Should not throw when module is missing
                { Send-LogToCloudWatch -Force } | Should -Not -Throw
            }
        }

        It 'skips send when buffer is empty' {
            InModuleScope HyperionFleet {
                $script:ModuleConfig.CloudWatchLogging = $true
                $script:CloudWatchLogBuffer = [System.Collections.Concurrent.ConcurrentQueue[LogEntry]]::new()

                # Empty buffer - should return without error
                { Send-LogToCloudWatch -Force } | Should -Not -Throw
            }
        }

        It 'skips send when CloudWatch disabled and not forced' {
            InModuleScope HyperionFleet {
                $script:ModuleConfig.CloudWatchLogging = $false

                { Send-LogToCloudWatch } | Should -Not -Throw
            }
        }
    }

    Context 'Initialize-CloudWatchLogging Function' {
        It 'enables CloudWatch logging' {
            InModuleScope HyperionFleet {
                Initialize-CloudWatchLogging -Enable

                $script:ModuleConfig.CloudWatchLogging | Should -Be $true
            }
        }

        It 'disables CloudWatch logging' {
            InModuleScope HyperionFleet {
                $script:ModuleConfig.CloudWatchLogging = $true
                Initialize-CloudWatchLogging -Disable

                $script:ModuleConfig.CloudWatchLogging | Should -Be $false
            }
        }

        It 'sets custom log group name' {
            InModuleScope HyperionFleet {
                Initialize-CloudWatchLogging -LogGroupName '/custom/log/group'

                $script:ModuleConfig.CloudWatchLogGroup | Should -Be '/custom/log/group'
            }
        }

        It 'sets buffer size' {
            InModuleScope HyperionFleet {
                Initialize-CloudWatchLogging -BufferSize 100

                $script:ModuleConfig.CloudWatchBufferSize | Should -Be 100
            }
        }

        It 'sets retention days' {
            InModuleScope HyperionFleet {
                Initialize-CloudWatchLogging -RetentionDays 90

                $script:ModuleConfig.CloudWatchRetentionDays | Should -Be 90
            }
        }

        It 'initializes buffer on enable' {
            InModuleScope HyperionFleet {
                $script:CloudWatchLogBuffer = $null
                Initialize-CloudWatchLogging -Enable

                $script:CloudWatchLogBuffer | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Flush-CloudWatchLogs Function' {
        It 'handles empty buffer' {
            InModuleScope HyperionFleet {
                $script:CloudWatchLogBuffer = [System.Collections.Concurrent.ConcurrentQueue[LogEntry]]::new()

                { Flush-CloudWatchLogs } | Should -Not -Throw
            }
        }

        It 'handles null buffer' {
            InModuleScope HyperionFleet {
                $script:CloudWatchLogBuffer = $null

                { Flush-CloudWatchLogs } | Should -Not -Throw
            }
        }
    }
}

Describe 'Backward Compatibility' -Tag 'Integration', 'Logging' {
    Context 'Write-FleetLog Compatibility' {
        It 'Write-FleetLog function still exists' {
            # Write-FleetLog is a private function, check via InModuleScope
            InModuleScope HyperionFleet {
                { Get-Command -Name 'Write-FleetLog' -ErrorAction Stop } | Should -Not -Throw
            }
        }

        It 'existing code using Write-FleetLog continues to work' {
            $TestLogPath = Join-Path -Path $TestDrive -ChildPath 'compat-test.log'

            InModuleScope HyperionFleet -Parameters @{ TestLogPath = $TestLogPath } {
                param($TestLogPath)
                { Write-FleetLog -Message 'Compatibility test' -Level 'Information' -LogPath $TestLogPath -NoConsole } | Should -Not -Throw
            }
        }
    }
}

Describe 'LogEntry FromJson Static Method' -Tag 'Unit', 'Class', 'Logging' {
    Context 'Deserialization' {
        It 'deserializes valid JSON' {
            $OriginalEntry = [LogEntry]::new('Deserialize test', [LogLevel]::Warning)
            $OriginalEntry.CorrelationId = [guid]::NewGuid().ToString()
            $OriginalEntry.Context = @{ Key = 'Value' }

            $Json = $OriginalEntry.ToJson()
            $Restored = [LogEntry]::FromJson($Json)

            $Restored.Message | Should -Be 'Deserialize test'
            $Restored.Level | Should -Be ([LogLevel]::Warning)
            $Restored.CorrelationId | Should -Be $OriginalEntry.CorrelationId
        }

        It 'preserves timestamp' {
            $OriginalEntry = [LogEntry]::new('Timestamp preserve', [LogLevel]::Information)
            $OriginalTimestamp = $OriginalEntry.Timestamp

            $Json = $OriginalEntry.ToJson()
            $Restored = [LogEntry]::FromJson($Json)

            # Allow for small rounding differences in milliseconds
            $TimeDiff = [math]::Abs(($Restored.Timestamp - $OriginalTimestamp).TotalMilliseconds)
            $TimeDiff | Should -BeLessThan 1000
        }

        It 'preserves context data' {
            $OriginalEntry = [LogEntry]::new('Context preserve', [LogLevel]::Information)
            $OriginalEntry.Context = @{
                StringKey = 'StringValue'
                NumberKey = 42
                BoolKey = $true
            }

            $Json = $OriginalEntry.ToJson()
            $Restored = [LogEntry]::FromJson($Json)

            $Restored.Context.StringKey | Should -Be 'StringValue'
            $Restored.Context.NumberKey | Should -Be 42
            $Restored.Context.BoolKey | Should -Be $true
        }

        It 'preserves metadata' {
            $OriginalEntry = [LogEntry]::new('Metadata preserve', [LogLevel]::Information)

            $Json = $OriginalEntry.ToJson()
            $Restored = [LogEntry]::FromJson($Json)

            $Restored.MachineName | Should -Be $OriginalEntry.MachineName
            $Restored.ProcessId | Should -Be $OriginalEntry.ProcessId
            $Restored.Username | Should -Be $OriginalEntry.Username
        }

        It 'preserves duration when set' {
            $OriginalEntry = [LogEntry]::new('Duration preserve', [LogLevel]::Information)
            $OriginalEntry.Duration = [timespan]::FromMilliseconds(1234.56)

            $Json = $OriginalEntry.ToJson()
            $Restored = [LogEntry]::FromJson($Json)

            [math]::Round($Restored.Duration.TotalMilliseconds, 2) | Should -Be 1234.56
        }

        It 'preserves scope name' {
            $OriginalEntry = [LogEntry]::new('Scope preserve', [LogLevel]::Information)
            $OriginalEntry.ScopeName = 'TestScope'

            $Json = $OriginalEntry.ToJson()
            $Restored = [LogEntry]::FromJson($Json)

            $Restored.ScopeName | Should -Be 'TestScope'
        }

        It 'preserves function name' {
            $OriginalEntry = [LogEntry]::new('Function preserve', [LogLevel]::Information)
            $OriginalEntry.FunctionName = 'Test-Function'

            $Json = $OriginalEntry.ToJson()
            $Restored = [LogEntry]::FromJson($Json)

            $Restored.FunctionName | Should -Be 'Test-Function'
        }

        It 'throws on null input' {
            { [LogEntry]::FromJson($null) } | Should -Throw
        }

        It 'throws on empty string' {
            { [LogEntry]::FromJson('') } | Should -Throw
        }

        It 'throws on invalid JSON' {
            { [LogEntry]::FromJson('not valid json') } | Should -Throw
        }

        It 'handles missing optional fields' {
            $MinimalJson = '{"timestamp":"2024-01-01T12:00:00.000Z","level":"Information","message":"Minimal"}'

            $Entry = [LogEntry]::FromJson($MinimalJson)

            $Entry.Message | Should -Be 'Minimal'
            $Entry.Level | Should -Be ([LogLevel]::Information)
        }
    }

    Context 'Round-trip Serialization' {
        It 'round-trip preserves all fields' {
            $Original = [LogEntry]::new('Round trip', [LogLevel]::Error)
            $Original.CorrelationId = [guid]::NewGuid().ToString()
            $Original.ParentCorrelationId = [guid]::NewGuid().ToString()
            $Original.Context = @{ RoundTrip = $true }
            $Original.Duration = [timespan]::FromSeconds(5)
            $Original.ScopeName = 'RoundTripScope'
            $Original.FunctionName = 'Test-RoundTrip'
            $Original.ScriptName = 'Test.ps1'

            $Json = $Original.ToJson()
            $Restored = [LogEntry]::FromJson($Json)

            $Restored.Message | Should -Be $Original.Message
            $Restored.Level | Should -Be $Original.Level
            $Restored.CorrelationId | Should -Be $Original.CorrelationId
            $Restored.ParentCorrelationId | Should -Be $Original.ParentCorrelationId
            $Restored.ScopeName | Should -Be $Original.ScopeName
            $Restored.FunctionName | Should -Be $Original.FunctionName
        }
    }
}
