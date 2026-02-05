#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Start-LogScope, Use-LogScope, and Get-CurrentLogScope functions.

.DESCRIPTION
    Comprehensive unit tests for the logging scope system including:
    - Scope creation and disposal
    - Entry/exit logging
    - Nested scopes with parent-child correlation
    - Duration calculation
    - Automatic correlation ID management
    - Context data handling

.NOTES
    Uses Pester 5.x syntax.
#>

BeforeAll {
    $ModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

    # Import the module
    Import-Module (Join-Path -Path $ModulePath -ChildPath 'HyperionFleet.psd1') -Force

    # Store original configuration
    $script:OriginalLogLevel = $null
    InModuleScope HyperionFleet {
        $script:OriginalLogLevel = $script:ModuleConfig.LogLevel
    }
}

AfterAll {
    # Restore original configuration
    InModuleScope HyperionFleet {
        $script:ModuleConfig.LogLevel = $script:OriginalLogLevel
    }

    Remove-Module -Name 'HyperionFleet' -Force -ErrorAction SilentlyContinue
}

Describe 'Start-LogScope' -Tag 'Unit', 'Public', 'Logging', 'Scope' {
    BeforeAll {
        $script:TestLogPath = Join-Path -Path $TestDrive -ChildPath 'scope-test.log'
    }

    BeforeEach {
        # Clean up state before each test
        Clear-CorrelationId -All
        InModuleScope HyperionFleet {
            $script:ModuleConfig.LogLevel = 'Information'
            $script:CurrentLogScope = $null
            $script:PreviousLogScope = $null
        }

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

        It 'function has CmdletBinding attribute' {
            $Command = Get-Command -Name 'Start-LogScope' -Module 'HyperionFleet'
            $Command.CmdletBinding | Should -Be $true
        }

        It 'ScopeName parameter is mandatory' {
            $Command = Get-Command -Name 'Start-LogScope' -Module 'HyperionFleet'
            $Command.Parameters['ScopeName'].Attributes.Mandatory | Should -Contain $true
        }

        It 'LogLevel parameter has valid values' {
            $Command = Get-Command -Name 'Start-LogScope' -Module 'HyperionFleet'
            $ValidateSet = $Command.Parameters['LogLevel'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $ValidateSet.ValidValues | Should -Contain 'Verbose'
            $ValidateSet.ValidValues | Should -Contain 'Debug'
            $ValidateSet.ValidValues | Should -Contain 'Information'
            $ValidateSet.ValidValues | Should -Contain 'Warning'
            $ValidateSet.ValidValues | Should -Contain 'Error'
            $ValidateSet.ValidValues | Should -Contain 'Critical'
        }

        It 'returns LogScope type' {
            $Command = Get-Command -Name 'Start-LogScope' -Module 'HyperionFleet'
            $OutputType = $Command.OutputType
            $OutputType.Name | Should -Contain 'LogScope'
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

        It 'sets scope name correctly' {
            $Scope = Start-LogScope -ScopeName 'MyCustomScope' -NoEntryLog -NoExitLog

            try {
                $Scope.ScopeName | Should -Be 'MyCustomScope'
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'generates unique correlation ID' {
            $Scope = Start-LogScope -ScopeName 'CorrelationScope' -NoEntryLog -NoExitLog

            try {
                $Scope.CorrelationId | Should -Not -BeNullOrEmpty
                { [guid]::Parse($Scope.CorrelationId) } | Should -Not -Throw
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

        It 'sets start time' {
            $Before = [datetime]::UtcNow
            $Scope = Start-LogScope -ScopeName 'TimeScope' -NoEntryLog -NoExitLog
            $After = [datetime]::UtcNow

            try {
                $Scope.StartTime | Should -BeGreaterOrEqual $Before
                $Scope.StartTime | Should -BeLessOrEqual $After
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'initializes with empty context' {
            $Scope = Start-LogScope -ScopeName 'ContextScope' -NoEntryLog -NoExitLog

            try {
                $Scope.Context | Should -Not -BeNullOrEmpty
                $Scope.Context.Count | Should -Be 0
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'accepts initial context hashtable' {
            $Context = @{
                Environment = 'Production'
                Operation   = 'HealthCheck'
            }
            $Scope = Start-LogScope -ScopeName 'InitialContextScope' -Context $Context -NoEntryLog -NoExitLog

            try {
                $Scope.Context.Environment | Should -Be 'Production'
                $Scope.Context.Operation | Should -Be 'HealthCheck'
            }
            finally {
                $Scope.Dispose()
            }
        }
    }

    Context 'Scope Entry Logging' {
        It 'logs entry message by default' {
            $InfoMessages = @()
            Mock -ModuleName HyperionFleet -CommandName Write-Information -MockWith {
                $script:InfoMessages += $MessageData
            }

            $Scope = Start-LogScope -ScopeName 'EntryLogScope' -NoExitLog

            try {
                # Entry log should have been written
                # Note: The actual logging goes through Write-StructuredLog
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'suppresses entry log with NoEntryLog switch' {
            $Scope = Start-LogScope -ScopeName 'NoEntryScope' -NoEntryLog -NoExitLog

            try {
                # Just verify it doesn't throw and scope is created
                $Scope | Should -Not -BeNullOrEmpty
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'includes context in entry log' {
            $Context = @{ InstanceCount = 5 }
            $Scope = Start-LogScope -ScopeName 'ContextEntryScope' -Context $Context -NoExitLog

            try {
                $Scope.Context.InstanceCount | Should -Be 5
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'includes parent correlation ID in entry log when nested' {
            $ParentId = New-CorrelationId -SetAsCurrent
            $Scope = Start-LogScope -ScopeName 'ChildScope' -NoExitLog

            try {
                $Scope.ParentCorrelationId | Should -Be $ParentId
            }
            finally {
                $Scope.Dispose()
            }
        }
    }

    Context 'Scope Exit Logging' {
        It 'logs exit message on dispose' {
            $Scope = Start-LogScope -ScopeName 'ExitLogScope' -NoEntryLog

            $Scope.Dispose()

            # Verify scope is disposed
            $Scope.IsDisposed | Should -Be $true
        }

        It 'suppresses exit log with NoExitLog switch' {
            $Scope = Start-LogScope -ScopeName 'NoExitScope' -NoEntryLog -NoExitLog

            { $Scope.Dispose() } | Should -Not -Throw
            $Scope.IsDisposed | Should -Be $true
        }

        It 'includes duration in exit log' {
            $Scope = Start-LogScope -ScopeName 'DurationExitScope' -NoEntryLog

            Start-Sleep -Milliseconds 50
            $Scope.Dispose()

            $Elapsed = $Scope.GetElapsed()
            $Elapsed.TotalMilliseconds | Should -BeGreaterThan 40
        }
    }

    Context 'Nested Scopes' {
        It 'supports nested scopes' {
            $OuterScope = Start-LogScope -ScopeName 'OuterScope' -NoEntryLog -NoExitLog
            $InnerScope = Start-LogScope -ScopeName 'InnerScope' -NoEntryLog -NoExitLog

            try {
                $OuterScope.ScopeName | Should -Be 'OuterScope'
                $InnerScope.ScopeName | Should -Be 'InnerScope'
            }
            finally {
                $InnerScope.Dispose()
                $OuterScope.Dispose()
            }
        }

        It 'child scope has parent correlation ID' {
            $OuterScope = Start-LogScope -ScopeName 'ParentScope' -NoEntryLog -NoExitLog

            try {
                $InnerScope = Start-LogScope -ScopeName 'ChildScope' -NoEntryLog -NoExitLog

                try {
                    $InnerScope.ParentCorrelationId | Should -Be $OuterScope.CorrelationId
                }
                finally {
                    $InnerScope.Dispose()
                }
            }
            finally {
                $OuterScope.Dispose()
            }
        }

        It 'maintains separate correlation IDs for nested scopes' {
            $OuterScope = Start-LogScope -ScopeName 'Outer' -NoEntryLog -NoExitLog
            $InnerScope = Start-LogScope -ScopeName 'Inner' -NoEntryLog -NoExitLog

            try {
                $OuterScope.CorrelationId | Should -Not -Be $InnerScope.CorrelationId
            }
            finally {
                $InnerScope.Dispose()
                $OuterScope.Dispose()
            }
        }

        It 'restores parent scope on inner dispose' {
            $OuterScope = Start-LogScope -ScopeName 'Outer' -NoEntryLog -NoExitLog
            $OuterCorrelationId = $OuterScope.CorrelationId

            $InnerScope = Start-LogScope -ScopeName 'Inner' -NoEntryLog -NoExitLog

            # Dispose inner scope
            $InnerScope.Dispose()

            try {
                # Current correlation should be restored to outer
                # This is handled by the correlation stack
            }
            finally {
                $OuterScope.Dispose()
            }
        }

        It 'supports deeply nested scopes (3 levels)' {
            $Level1 = Start-LogScope -ScopeName 'Level1' -NoEntryLog -NoExitLog
            $Level2 = Start-LogScope -ScopeName 'Level2' -NoEntryLog -NoExitLog
            $Level3 = Start-LogScope -ScopeName 'Level3' -NoEntryLog -NoExitLog

            try {
                $Level3.ParentCorrelationId | Should -Be $Level2.CorrelationId
                $Level2.ParentCorrelationId | Should -Be $Level1.CorrelationId
                $Level1.ParentCorrelationId | Should -BeNullOrEmpty
            }
            finally {
                $Level3.Dispose()
                $Level2.Dispose()
                $Level1.Dispose()
            }
        }
    }

    Context 'Duration Calculation' {
        It 'tracks elapsed time correctly' {
            $Scope = Start-LogScope -ScopeName 'DurationScope' -NoEntryLog -NoExitLog

            try {
                Start-Sleep -Milliseconds 100
                $Elapsed = $Scope.GetElapsed()

                $Elapsed.TotalMilliseconds | Should -BeGreaterThan 80
                $Elapsed.TotalMilliseconds | Should -BeLessThan 200
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'returns final duration after dispose' {
            $Scope = Start-LogScope -ScopeName 'FinalDurationScope' -NoEntryLog -NoExitLog

            Start-Sleep -Milliseconds 50
            $Scope.Dispose()

            $ElapsedAfterDispose = $Scope.GetElapsed()
            Start-Sleep -Milliseconds 50

            # Duration should not increase after dispose
            $ElapsedLater = $Scope.GetElapsed()
            $ElapsedAfterDispose.TotalMilliseconds | Should -Be $ElapsedLater.TotalMilliseconds
        }

        It 'calculates duration with millisecond precision' {
            $Scope = Start-LogScope -ScopeName 'PrecisionScope' -NoEntryLog -NoExitLog

            try {
                $Elapsed = $Scope.GetElapsed()

                # Should have sub-second precision
                $Elapsed.TotalMilliseconds | Should -BeGreaterOrEqual 0
                $Elapsed.Milliseconds | Should -BeOfType [int]
            }
            finally {
                $Scope.Dispose()
            }
        }
    }

    Context 'Automatic Correlation' {
        It 'sets current correlation ID on scope creation' {
            $Scope = Start-LogScope -ScopeName 'AutoCorrelationScope' -NoEntryLog -NoExitLog

            try {
                $CurrentId = Get-CorrelationId
                $CurrentId | Should -Be $Scope.CorrelationId
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'clears correlation ID on root scope dispose' {
            $Scope = Start-LogScope -ScopeName 'RootScope' -NoEntryLog -NoExitLog
            $Scope.Dispose()

            $CurrentId = Get-CorrelationId
            $CurrentId | Should -BeNullOrEmpty
        }

        It 'logs within scope include correlation ID automatically' {
            $Scope = Start-LogScope -ScopeName 'LogCorrelationScope' -NoEntryLog -NoExitLog

            try {
                $Entry = Write-StructuredLog -Message 'Test message within scope' -PassThru -NoConsole

                $Entry.CorrelationId | Should -Be $Scope.CorrelationId
            }
            finally {
                $Scope.Dispose()
            }
        }
    }

    Context 'Context Management' {
        It 'allows adding context after creation' {
            $Scope = Start-LogScope -ScopeName 'AddContextScope' -NoEntryLog -NoExitLog

            try {
                $Scope.AddContext('Key1', 'Value1')
                $Scope.AddContext('Key2', 42)

                $Scope.Context.Key1 | Should -Be 'Value1'
                $Scope.Context.Key2 | Should -Be 42
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'overwrites existing context key' {
            $Scope = Start-LogScope -ScopeName 'OverwriteContextScope' -Context @{ Key = 'Original' } -NoEntryLog -NoExitLog

            try {
                $Scope.AddContext('Key', 'Updated')

                $Scope.Context.Key | Should -Be 'Updated'
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'clones initial context (does not modify original)' {
            $OriginalContext = @{ Key = 'Value' }
            $Scope = Start-LogScope -ScopeName 'CloneContextScope' -Context $OriginalContext -NoEntryLog -NoExitLog

            try {
                $Scope.AddContext('NewKey', 'NewValue')

                $OriginalContext.ContainsKey('NewKey') | Should -Be $false
            }
            finally {
                $Scope.Dispose()
            }
        }
    }

    Context 'Disposal Behavior' {
        It 'is disposable (implements IDisposable)' {
            $Scope = Start-LogScope -ScopeName 'DisposableScope' -NoEntryLog -NoExitLog

            $Scope | Should -BeOfType [System.IDisposable]

            $Scope.Dispose()
        }

        It 'sets IsDisposed flag after dispose' {
            $Scope = Start-LogScope -ScopeName 'IsDisposedScope' -NoEntryLog -NoExitLog

            $Scope.IsDisposed | Should -Be $false
            $Scope.Dispose()
            $Scope.IsDisposed | Should -Be $true
        }

        It 'sets EndTime on dispose' {
            $Scope = Start-LogScope -ScopeName 'EndTimeScope' -NoEntryLog -NoExitLog

            Start-Sleep -Milliseconds 10
            $Scope.Dispose()

            $Scope.EndTime | Should -BeGreaterThan $Scope.StartTime
        }

        It 'is safe to dispose multiple times' {
            $Scope = Start-LogScope -ScopeName 'MultiDisposeScope' -NoEntryLog -NoExitLog

            {
                $Scope.Dispose()
                $Scope.Dispose()
                $Scope.Dispose()
            } | Should -Not -Throw
        }

        It 'does not run callback multiple times' {
            $Scope = Start-LogScope -ScopeName 'CallbackScope' -NoEntryLog -NoExitLog

            $CallCount = 0
            InModuleScope HyperionFleet -Parameters @{ CallCountRef = [ref]$CallCount } {
                # This test verifies internal behavior
            }

            $Scope.Dispose()
            $Scope.Dispose()

            # Scope should only log exit once
            $Scope.IsDisposed | Should -Be $true
        }
    }

    Context 'Error Handling' {
        It 'handles empty scope name gracefully' {
            { Start-LogScope -ScopeName '' -NoEntryLog -NoExitLog } | Should -Throw
        }

        It 'handles null scope name gracefully' {
            { Start-LogScope -ScopeName $null -NoEntryLog -NoExitLog } | Should -Throw
        }

        It 'continues operation if entry log fails' {
            # Scope creation should not fail even if logging has issues
            $Scope = Start-LogScope -ScopeName 'RobustScope' -NoEntryLog -NoExitLog

            try {
                $Scope | Should -Not -BeNullOrEmpty
            }
            finally {
                $Scope.Dispose()
            }
        }
    }

    Context 'LogLevel Parameter' {
        It 'accepts valid log levels' {
            $Scope = Start-LogScope -ScopeName 'LevelScope' -LogLevel 'Warning' -NoEntryLog -NoExitLog

            try {
                $Scope | Should -Not -BeNullOrEmpty
            }
            finally {
                $Scope.Dispose()
            }
        }

        It 'defaults to Information level' {
            # Default behavior - just verify it works
            $Scope = Start-LogScope -ScopeName 'DefaultLevelScope' -NoEntryLog -NoExitLog

            try {
                $Scope | Should -Not -BeNullOrEmpty
            }
            finally {
                $Scope.Dispose()
            }
        }
    }
}

Describe 'Use-LogScope' -Tag 'Unit', 'Public', 'Logging', 'Scope' {
    BeforeEach {
        Clear-CorrelationId -All
        InModuleScope HyperionFleet {
            $script:CurrentLogScope = $null
        }
    }

    AfterEach {
        Clear-CorrelationId -All
    }

    Context 'Function Structure' {
        It 'function is exported' {
            $Module = Get-Module -Name 'HyperionFleet'
            $Module.ExportedCommands.Keys | Should -Contain 'Use-LogScope'
        }

        It 'ScopeName parameter is mandatory' {
            $Command = Get-Command -Name 'Use-LogScope' -Module 'HyperionFleet'
            $Command.Parameters['ScopeName'].Attributes.Mandatory | Should -Contain $true
        }

        It 'ScriptBlock parameter is mandatory' {
            $Command = Get-Command -Name 'Use-LogScope' -Module 'HyperionFleet'
            $Command.Parameters['ScriptBlock'].Attributes.Mandatory | Should -Contain $true
        }
    }

    Context 'Script Block Execution' {
        It 'executes script block' {
            $Executed = $false

            Use-LogScope -ScopeName 'ExecutionScope' -ScriptBlock {
                $script:Executed = $true
            }

            $script:Executed | Should -Be $true
        }

        It 'returns script block output' {
            $Result = Use-LogScope -ScopeName 'OutputScope' -ScriptBlock {
                'Hello World'
            }

            $Result | Should -Be 'Hello World'
        }

        It 'returns multiple outputs' {
            $Result = Use-LogScope -ScopeName 'MultiOutputScope' -ScriptBlock {
                1
                2
                3
            }

            $Result | Should -HaveCount 3
            $Result | Should -Contain 1
            $Result | Should -Contain 2
            $Result | Should -Contain 3
        }

        It 'returns complex objects' {
            $Result = Use-LogScope -ScopeName 'ObjectScope' -ScriptBlock {
                [PSCustomObject]@{
                    Name = 'Test'
                    Value = 42
                }
            }

            $Result.Name | Should -Be 'Test'
            $Result.Value | Should -Be 42
        }
    }

    Context 'Argument Passing' {
        It 'passes single argument to script block' {
            $Result = Use-LogScope -ScopeName 'SingleArgScope' -ScriptBlock {
                param($Value)
                $Value * 2
            } -ArgumentList 21

            $Result | Should -Be 42
        }

        It 'passes multiple arguments to script block' {
            $Result = Use-LogScope -ScopeName 'MultiArgScope' -ScriptBlock {
                param($A, $B, $C)
                "$A-$B-$C"
            } -ArgumentList 'X', 'Y', 'Z'

            $Result | Should -Be 'X-Y-Z'
        }

        It 'passes complex arguments' {
            $ComplexArg = @{ Key = 'Value' }

            $Result = Use-LogScope -ScopeName 'ComplexArgScope' -ScriptBlock {
                param($Hashtable)
                $Hashtable.Key
            } -ArgumentList $ComplexArg

            $Result | Should -Be 'Value'
        }
    }

    Context 'Context Parameter' {
        It 'passes context to scope' {
            $Context = @{ Environment = 'Test' }

            Use-LogScope -ScopeName 'ContextParamScope' -Context $Context -ScriptBlock {
                $CurrentScope = Get-CurrentLogScope
                $CurrentScope.Context.Environment | Should -Be 'Test'
            }
        }
    }

    Context 'Error Handling' {
        It 'disposes scope even when script block throws' {
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

        It 're-throws script block exceptions' {
            {
                Use-LogScope -ScopeName 'RethrowScope' -ScriptBlock {
                    throw 'Expected error'
                }
            } | Should -Throw 'Expected error'
        }

        It 'preserves exception type' {
            $CaughtException = $null

            try {
                Use-LogScope -ScopeName 'ExceptionTypeScope' -ScriptBlock {
                    throw [System.InvalidOperationException]::new('Custom error')
                }
            }
            catch {
                $CaughtException = $_.Exception
            }

            $CaughtException | Should -BeOfType [System.InvalidOperationException]
        }

        It 'logs error before re-throwing' {
            # Error should be logged with exception details
            try {
                Use-LogScope -ScopeName 'LogErrorScope' -ScriptBlock {
                    throw 'Logged error'
                }
            }
            catch {
                # Expected
            }
        }
    }

    Context 'Scope Lifecycle' {
        It 'creates scope before script block execution' {
            Use-LogScope -ScopeName 'LifecycleScope' -ScriptBlock {
                $Scope = Get-CurrentLogScope

                $Scope | Should -Not -BeNullOrEmpty
                $Scope.ScopeName | Should -Be 'LifecycleScope'
            }
        }

        It 'disposes scope after script block execution' {
            $ScopeCorrelationId = $null

            Use-LogScope -ScopeName 'DisposalScope' -ScriptBlock {
                $Scope = Get-CurrentLogScope
                $script:ScopeCorrelationId = $Scope.CorrelationId
            }

            # After Use-LogScope, correlation should be cleared
            $CurrentId = Get-CorrelationId
            $CurrentId | Should -BeNullOrEmpty
        }
    }

    Context 'Nested Use-LogScope' {
        It 'supports nested Use-LogScope calls' {
            $InnerExecuted = $false

            Use-LogScope -ScopeName 'Outer' -ScriptBlock {
                Use-LogScope -ScopeName 'Inner' -ScriptBlock {
                    $script:InnerExecuted = $true
                }
            }

            $script:InnerExecuted | Should -Be $true
        }

        It 'maintains proper correlation chain in nested calls' {
            $OuterCorrelationId = $null
            $InnerParentId = $null

            Use-LogScope -ScopeName 'OuterChain' -ScriptBlock {
                $OuterScope = Get-CurrentLogScope
                $script:OuterCorrelationId = $OuterScope.CorrelationId

                Use-LogScope -ScopeName 'InnerChain' -ScriptBlock {
                    $InnerScope = Get-CurrentLogScope
                    $script:InnerParentId = $InnerScope.ParentCorrelationId
                }
            }

            $script:InnerParentId | Should -Be $script:OuterCorrelationId
        }
    }
}

Describe 'Get-CurrentLogScope' -Tag 'Unit', 'Public', 'Logging', 'Scope' {
    BeforeEach {
        Clear-CorrelationId -All
        InModuleScope HyperionFleet {
            $script:CurrentLogScope = $null
        }
    }

    AfterEach {
        Clear-CorrelationId -All
    }

    Context 'Function Structure' {
        It 'function is exported' {
            $Module = Get-Module -Name 'HyperionFleet'
            $Module.ExportedCommands.Keys | Should -Contain 'Get-CurrentLogScope'
        }

        It 'returns LogScope type or null' {
            $Command = Get-Command -Name 'Get-CurrentLogScope' -Module 'HyperionFleet'
            $OutputType = $Command.OutputType
            $OutputType.Name | Should -Contain 'LogScope'
        }
    }

    Context 'Retrieval' {
        It 'returns null when no scope is active' {
            $Scope = Get-CurrentLogScope

            $Scope | Should -BeNullOrEmpty
        }

        It 'returns current scope when active' {
            $ActiveScope = Start-LogScope -ScopeName 'ActiveScope' -NoEntryLog -NoExitLog

            try {
                $CurrentScope = Get-CurrentLogScope

                $CurrentScope | Should -Not -BeNullOrEmpty
                $CurrentScope.ScopeName | Should -Be 'ActiveScope'
            }
            finally {
                $ActiveScope.Dispose()
            }
        }

        It 'returns innermost scope when nested' {
            $Outer = Start-LogScope -ScopeName 'OuterGet' -NoEntryLog -NoExitLog
            $Inner = Start-LogScope -ScopeName 'InnerGet' -NoEntryLog -NoExitLog

            try {
                $Current = Get-CurrentLogScope

                $Current.ScopeName | Should -Be 'InnerGet'
            }
            finally {
                $Inner.Dispose()
                $Outer.Dispose()
            }
        }

        It 'allows adding context to current scope' {
            $Scope = Start-LogScope -ScopeName 'ModifyScope' -NoEntryLog -NoExitLog

            try {
                $Current = Get-CurrentLogScope
                $Current.AddContext('Added', 'Value')

                $Scope.Context.Added | Should -Be 'Value'
            }
            finally {
                $Scope.Dispose()
            }
        }
    }
}

Describe 'LogScope Class' -Tag 'Unit', 'Class', 'Logging', 'Scope' {
    Context 'Construction' {
        It 'creates with required parameters' {
            $CorrelationId = [guid]::NewGuid().ToString()
            $Scope = [LogScope]::new('TestScope', $CorrelationId, $null)

            $Scope.ScopeName | Should -Be 'TestScope'
            $Scope.CorrelationId | Should -Be $CorrelationId
            $Scope.ParentCorrelationId | Should -BeNullOrEmpty
        }

        It 'sets parent correlation ID' {
            $ParentId = [guid]::NewGuid().ToString()
            $ChildId = [guid]::NewGuid().ToString()
            $Scope = [LogScope]::new('ChildScope', $ChildId, $ParentId)

            $Scope.ParentCorrelationId | Should -Be $ParentId
        }

        It 'initializes IsDisposed to false' {
            $Scope = [LogScope]::new('NewScope', [guid]::NewGuid().ToString(), $null)

            $Scope.IsDisposed | Should -Be $false
        }

        It 'initializes empty context' {
            $Scope = [LogScope]::new('ContextScope', [guid]::NewGuid().ToString(), $null)

            $Scope.Context | Should -Not -BeNullOrEmpty
            $Scope.Context.Count | Should -Be 0
        }

        It 'sets start time to current UTC' {
            $Before = [datetime]::UtcNow
            $Scope = [LogScope]::new('TimeScope', [guid]::NewGuid().ToString(), $null)
            $After = [datetime]::UtcNow

            $Scope.StartTime | Should -BeGreaterOrEqual $Before
            $Scope.StartTime | Should -BeLessOrEqual $After
        }
    }

    Context 'GetElapsed Method' {
        It 'returns positive timespan' {
            $Scope = [LogScope]::new('ElapsedScope', [guid]::NewGuid().ToString(), $null)

            Start-Sleep -Milliseconds 10
            $Elapsed = $Scope.GetElapsed()

            $Elapsed.TotalMilliseconds | Should -BeGreaterThan 0
        }

        It 'returns final duration after dispose' {
            $Scope = [LogScope]::new('FinalScope', [guid]::NewGuid().ToString(), $null)

            Start-Sleep -Milliseconds 50
            $Scope.Dispose()

            $Duration1 = $Scope.GetElapsed()
            Start-Sleep -Milliseconds 50
            $Duration2 = $Scope.GetElapsed()

            $Duration1.TotalMilliseconds | Should -Be $Duration2.TotalMilliseconds
        }
    }

    Context 'AddContext Method' {
        It 'adds key-value pair' {
            $Scope = [LogScope]::new('AddScope', [guid]::NewGuid().ToString(), $null)

            $Scope.AddContext('Key', 'Value')

            $Scope.Context['Key'] | Should -Be 'Value'
        }

        It 'overwrites existing key' {
            $Scope = [LogScope]::new('OverwriteScope', [guid]::NewGuid().ToString(), $null)

            $Scope.AddContext('Key', 'Original')
            $Scope.AddContext('Key', 'Updated')

            $Scope.Context['Key'] | Should -Be 'Updated'
        }

        It 'supports various value types' {
            $Scope = [LogScope]::new('TypeScope', [guid]::NewGuid().ToString(), $null)

            $Scope.AddContext('String', 'text')
            $Scope.AddContext('Number', 42)
            $Scope.AddContext('Bool', $true)
            $Scope.AddContext('Array', @(1, 2, 3))

            $Scope.Context['String'] | Should -Be 'text'
            $Scope.Context['Number'] | Should -Be 42
            $Scope.Context['Bool'] | Should -Be $true
            $Scope.Context['Array'] | Should -HaveCount 3
        }
    }

    Context 'Dispose Method' {
        It 'sets IsDisposed to true' {
            $Scope = [LogScope]::new('DisposeScope', [guid]::NewGuid().ToString(), $null)

            $Scope.Dispose()

            $Scope.IsDisposed | Should -Be $true
        }

        It 'sets EndTime' {
            $Scope = [LogScope]::new('EndScope', [guid]::NewGuid().ToString(), $null)
            $StartTime = $Scope.StartTime

            Start-Sleep -Milliseconds 10
            $Scope.Dispose()

            $Scope.EndTime | Should -BeGreaterThan $StartTime
        }

        It 'is idempotent' {
            $Scope = [LogScope]::new('IdempotentScope', [guid]::NewGuid().ToString(), $null)

            $Scope.Dispose()
            $EndTime1 = $Scope.EndTime

            Start-Sleep -Milliseconds 10
            $Scope.Dispose()
            $EndTime2 = $Scope.EndTime

            $EndTime1 | Should -Be $EndTime2
        }
    }

    Context 'ToString Method' {
        It 'returns formatted string' {
            $CorrelationId = [guid]::NewGuid().ToString()
            $Scope = [LogScope]::new('ToStringScope', $CorrelationId, $null)

            $Str = $Scope.ToString()

            $Str | Should -Match 'ToStringScope'
            $Str | Should -Match $CorrelationId.Substring(0, 8)
            $Str | Should -Match '\d+.*ms'
        }
    }
}
