BeforeDiscovery {
    # Unload the module if it is loaded
    if (Get-Module -Name 'ScheduledTasksManager') {
        Remove-Module -Name 'ScheduledTasksManager' -Force
    }

    # Import the module
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ScheduledTasksManager\ScheduledTasksManager.psd1'
    Import-Module -Name $ModulePath -Force
}

InModuleScope -ModuleName 'ScheduledTasksManager' {
    Describe 'Get-StmScheduledTaskInfo' {
    Context 'When retrieving task info using parameters' {
        BeforeEach {
            Mock -CommandName Get-StmScheduledTask -MockWith {
                $mockTask = [PSCustomObject]@{
                    TaskName     = 'TestTask'
                    TaskPath     = '\TestPath\'
                    State        = 'Ready'
                    Description  = 'Test Description'
                    URI          = '\TestPath\TestTask'
                    Author       = 'TestAuthor'
                }
                $mockTask.PSObject.TypeNames.Insert(0, 'Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask')
                return $mockTask
            }

            Mock -CommandName Get-ScheduledTaskInfo -MockWith {
                param($TaskName, $TaskPath)
                $mockInfo = [PSCustomObject]@{
                    LastRunTime      = (Get-Date).AddHours(-1)
                    LastTaskResult   = 0
                    NextRunTime      = (Get-Date).AddHours(1)
                    NumberOfMissedRuns = 0
                }
                $mockInfo.PSObject.TypeNames.Insert(0, 'Microsoft.Management.Infrastructure.CimInstance#MSFT_TaskDynamicInfo')
                return $mockInfo
            }

            Mock -CommandName Merge-Object -MockWith {
                param($FirstObject, $SecondObject, $FirstObjectName, $SecondObjectName, $AsHashtable)
                @{
                    TaskName              = $FirstObject.TaskName
                    TaskPath              = $FirstObject.TaskPath
                    State                 = $FirstObject.State
                    LastRunTime           = $SecondObject.LastRunTime
                    LastTaskResult        = $SecondObject.LastTaskResult
                    NextRunTime           = $SecondObject.NextRunTime
                    NumberOfMissedRuns    = $SecondObject.NumberOfMissedRuns
                    ScheduledTaskObject   = $FirstObject
                    ScheduledTaskInfoObject = $SecondObject
                }
            }

            # The Issue-3 fix creates a CIM session for remote ComputerName values. Without
            # mocking these, tests that pass -ComputerName 'Server01' would try to reach the
            # real (nonexistent) host. New-MockObject returns a properly-typed CimSession
            # so the patched code's -CimSession parameter binding succeeds.
            Mock -CommandName New-StmCimSession -MockWith {
                return (New-MockObject -Type 'Microsoft.Management.Infrastructure.CimSession')
            }
            Mock -CommandName Remove-CimSession -MockWith {}
        }

        It 'Should retrieve task info without parameters' {
            $result = Get-StmScheduledTaskInfo

            $result | Should -Not -BeNullOrEmpty
            $result.TaskName | Should -Be 'TestTask'
            Should -Invoke Get-StmScheduledTask -Times 1 -Exactly
            Should -Invoke Get-ScheduledTaskInfo -Times 1 -Exactly
        }

        It 'Should retrieve task info with TaskName parameter' {
            $result = Get-StmScheduledTaskInfo -TaskName 'TestTask'

            $result | Should -Not -BeNullOrEmpty
            $result.TaskName | Should -Be 'TestTask'
            Should -Invoke Get-StmScheduledTask -Times 1 -Exactly -ParameterFilter {
                $TaskName -eq 'TestTask'
            }
        }

        It 'Should retrieve task info with TaskPath parameter' {
            $result = Get-StmScheduledTaskInfo -TaskPath '\TestPath\'

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Get-StmScheduledTask -Times 1 -Exactly -ParameterFilter {
                $TaskPath -eq '\TestPath\'
            }
        }

        It 'Should retrieve task info with TaskState parameter' {
            $result = Get-StmScheduledTaskInfo -TaskState 'Ready'

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Get-StmScheduledTask -Times 1 -Exactly -ParameterFilter {
                $TaskState -eq 'Ready'
            }
        }

        It 'Should retrieve task info with ComputerName parameter' {
            $result = Get-StmScheduledTaskInfo -ComputerName 'Server01'

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Get-StmScheduledTask -Times 1 -Exactly -ParameterFilter {
                $ComputerName -eq 'Server01'
            }
        }

        It 'Should retrieve task info with Credential parameter' {
            $credential = New-Object System.Management.Automation.PSCredential(
                'TestUser',
                (ConvertTo-SecureString 'TestPassword' -AsPlainText -Force)
            )
            $result = Get-StmScheduledTaskInfo -Credential $credential

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Get-StmScheduledTask -Times 1 -Exactly -ParameterFilter {
                $null -ne $Credential
            }
        }

        It 'Should merge properties from both task and info objects' {
            $result = Get-StmScheduledTaskInfo -TaskName 'TestTask'

            $result.TaskName | Should -Be 'TestTask'
            $result.TaskPath | Should -Be '\TestPath\'
            $result.State | Should -Be 'Ready'
            $result.LastRunTime | Should -Not -BeNullOrEmpty
            $result.LastTaskResult | Should -Be 0
            $result.NextRunTime | Should -Not -BeNullOrEmpty
            $result.NumberOfMissedRuns | Should -Be 0
        }

        It 'Should calculate RunningDuration for running tasks' {
            Mock -CommandName Get-StmScheduledTask -MockWith {
                $mockTask = [PSCustomObject]@{
                    TaskName     = 'RunningTask'
                    TaskPath     = '\TestPath\'
                    State        = 'Running'
                }
                $mockTask.PSObject.TypeNames.Insert(0, 'Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask')
                return $mockTask
            }

            Mock -CommandName Get-ScheduledTaskInfo -MockWith {
                param($TaskName, $TaskPath)
                $mockInfo = [PSCustomObject]@{
                    LastRunTime      = (Get-Date).AddMinutes(-30)
                    LastTaskResult   = 0
                    NextRunTime      = (Get-Date).AddHours(1)
                    NumberOfMissedRuns = 0
                }
                $mockInfo.PSObject.TypeNames.Insert(0, 'Microsoft.Management.Infrastructure.CimInstance#MSFT_TaskDynamicInfo')
                return $mockInfo
            }

            Mock -CommandName Merge-Object -MockWith {
                param($FirstObject, $SecondObject)
                @{
                    TaskName              = $FirstObject.TaskName
                    State                 = $FirstObject.State
                    LastRunTime           = $SecondObject.LastRunTime
                    LastTaskResult        = $SecondObject.LastTaskResult
                    NextRunTime           = $SecondObject.NextRunTime
                    NumberOfMissedRuns    = $SecondObject.NumberOfMissedRuns
                    ScheduledTaskObject   = $FirstObject
                    ScheduledTaskInfoObject = $SecondObject
                }
            }

            $result = Get-StmScheduledTaskInfo -TaskName 'RunningTask'

            $result.RunningDuration | Should -Not -BeNullOrEmpty
            $result.RunningDuration | Should -BeOfType [TimeSpan]
            $result.RunningDuration.TotalMinutes | Should -BeGreaterThan 29
        }

        It 'Should set RunningDuration to null for non-running tasks' {
            $result = Get-StmScheduledTaskInfo -TaskName 'TestTask'

            $result.RunningDuration | Should -BeNullOrEmpty
        }

        It 'Should warn when no tasks are found' {
            Mock -CommandName Get-StmScheduledTask -MockWith {
                return @()
            }

            $result = Get-StmScheduledTaskInfo -TaskName 'NonExistentTask' -WarningVariable warnings 3>$null

            $result | Should -BeNullOrEmpty
            Should -Invoke Get-StmScheduledTask -Times 1 -Exactly
            Should -Invoke Get-ScheduledTaskInfo -Times 0 -Exactly
        }
    }

    Context 'When retrieving task info using pipeline input' {
        BeforeEach {
            # Build a real MSFT_ScheduledTask CimInstance so pipeline ByValue binding to
            # Get-ScheduledTaskInfo's -InputObject succeeds. A faux PSCustomObject with an
            # inserted type name does NOT bind by value, and Get-ScheduledTaskInfo's
            # TaskName/TaskPath are not pipeline-by-property-name parameters. The task
            # fields the function reads after the pipe are set as real CIM properties (the
            # way an actual scheduled-task instance exposes them) rather than ETS members,
            # which collide with CimInstance's built-in 'State' ScriptProperty.
            function New-StmTestTaskCimInstance {
                param($TaskName, $TaskPath = '\TestPath\', $State = 'Ready')
                $newInstanceParameters = @{
                    TypeName     = 'Microsoft.Management.Infrastructure.CimInstance'
                    ArgumentList = @('MSFT_ScheduledTask', 'Root/Microsoft/Windows/TaskScheduler')
                }
                $instance = New-Object @newInstanceParameters
                $cimPropertyValues = [ordered]@{
                    TaskName = $TaskName
                    TaskPath = $TaskPath
                    State    = $State
                }
                foreach ($propertyName in $cimPropertyValues.Keys) {
                    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                        $propertyName,
                        $cimPropertyValues[$propertyName],
                        [Microsoft.Management.Infrastructure.CimType]::String,
                        [Microsoft.Management.Infrastructure.CimFlags]::Property
                    )
                    $instance.CimInstanceProperties.Add($property)
                }
                return $instance
            }

            Mock -CommandName Get-ScheduledTaskInfo -MockWith {
                param($TaskName, $TaskPath)
                $mockInfo = [PSCustomObject]@{
                    LastRunTime      = (Get-Date).AddHours(-1)
                    LastTaskResult   = 0
                    NextRunTime      = (Get-Date).AddHours(1)
                    NumberOfMissedRuns = 0
                }
                $mockInfo.PSObject.TypeNames.Insert(0, 'Microsoft.Management.Infrastructure.CimInstance#MSFT_TaskDynamicInfo')
                return $mockInfo
            }

            Mock -CommandName Merge-Object -MockWith {
                param($FirstObject, $SecondObject, $FirstObjectName, $SecondObjectName, $AsHashtable)
                @{
                    TaskName              = $FirstObject.TaskName
                    TaskPath              = $FirstObject.TaskPath
                    State                 = $FirstObject.State
                    LastRunTime           = $SecondObject.LastRunTime
                    LastTaskResult        = $SecondObject.LastTaskResult
                    NextRunTime           = $SecondObject.NextRunTime
                    NumberOfMissedRuns    = $SecondObject.NumberOfMissedRuns
                    ScheduledTaskObject   = $FirstObject
                    ScheduledTaskInfoObject = $SecondObject
                }
            }
        }

        It 'Should accept pipeline input from Get-StmScheduledTask' {
            $mockTask = New-StmTestTaskCimInstance -TaskName 'PipelineTask'

            $result = $mockTask | Get-StmScheduledTaskInfo

            $result | Should -Not -BeNullOrEmpty
            $result.TaskName | Should -Be 'PipelineTask'
            Should -Invoke Get-ScheduledTaskInfo -Times 1 -Exactly
            # The piped task must reach Get-ScheduledTaskInfo as -InputObject so its
            # originating CIM session is reused, rather than being rebuilt by TaskName
            # (which would fall back to the local Task Scheduler for a remote task).
            Should -Invoke Get-ScheduledTaskInfo -Times 1 -ParameterFilter {
                $null -ne $InputObject
            }
        }

        It 'Should accept multiple tasks from pipeline' {
            $mockTasks = @(
                New-StmTestTaskCimInstance -TaskName 'Task1' -TaskPath '\Path1\'
                New-StmTestTaskCimInstance -TaskName 'Task2' -TaskPath '\Path2\'
            )

            $result = $mockTasks | Get-StmScheduledTaskInfo

            $result | Should -HaveCount 2
            $result[0].TaskName | Should -Be 'Task1'
            $result[1].TaskName | Should -Be 'Task2'
            Should -Invoke Get-ScheduledTaskInfo -Times 2 -Exactly
        }

        It 'Should warn when empty pipeline input is provided' {
            $result = @() | Get-StmScheduledTaskInfo -WarningVariable warnings 3>$null

            $result | Should -BeNullOrEmpty
            Should -Invoke Get-ScheduledTaskInfo -Times 0 -Exactly
        }
    }

    Context 'When handling errors' {
        BeforeEach {
            Mock -CommandName Get-StmScheduledTask -MockWith {
                $mockTask = [PSCustomObject]@{
                    TaskName     = 'ErrorTask'
                    TaskPath     = '\TestPath\'
                    State        = 'Ready'
                }
                $mockTask.PSObject.TypeNames.Insert(0, 'Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask')
                return $mockTask
            }

            Mock -CommandName New-StmError -MockWith {
                param($Exception, $ErrorId, $ErrorCategory, $TargetObject, $Message, $RecommendedAction)
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $Exception,
                    $ErrorId,
                    $ErrorCategory,
                    $TargetObject
                )
                return $errorRecord
            }
        }

        It 'Should write a non-terminating error (not throw) when Get-ScheduledTaskInfo fails' {
            Mock -CommandName Get-ScheduledTaskInfo -MockWith {
                throw 'Access Denied'
            }

            Mock -CommandName Merge-Object -MockWith {
                @{
                    TaskName = 'ErrorTask'
                }
            }

            # Calling directly (not via { } | Should -Not -Throw) for two reasons:
            #   1. If the cmdlet throws, this It fails with the exception — which is what
            #      we want for a regression of the original ThrowTerminatingError bug.
            #   2. A scriptblock wrapper would scope -ErrorVariable away from the outer $err.
            $err = $null
            $invokeParameters = @{
                TaskName      = 'ErrorTask'
                ErrorVariable = 'err'
                ErrorAction   = 'SilentlyContinue'
            }
            Get-StmScheduledTaskInfo @invokeParameters

            Should -Invoke Get-ScheduledTaskInfo -Times 1 -Exactly
            Should -Invoke New-StmError -Times 1 -Exactly

            # Filtered-match-count instead of total-count: Pester mock framework adds extra raw
            # error records to $err when the mock body throws.
            $structuredErrors = $err |
                Where-Object { $_.FullyQualifiedErrorId -match 'ScheduledTaskInfoRetrievalFailed' }
            @($structuredErrors).Count | Should -Be 1
        }

        It 'Should include task name in error message' {
            Mock -CommandName Get-ScheduledTaskInfo -MockWith {
                throw 'Test error'
            }

            Mock -CommandName Merge-Object -MockWith {
                @{
                    TaskName = 'ErrorTask'
                }
            }

            $invokeParameters = @{
                TaskName    = 'ErrorTask'
                ErrorAction = 'SilentlyContinue'
            }
            Get-StmScheduledTaskInfo @invokeParameters

            Should -Invoke New-StmError -Times 1 -Exactly -ParameterFilter {
                $Message -like "*ErrorTask*"
            }
        }
    }

    Context 'When handling TaskName property conflicts' {
        BeforeEach {
            Mock -CommandName Get-StmScheduledTask -MockWith {
                $mockTask = [PSCustomObject]@{
                    TaskName   = 'ConflictTask'
                    TaskPath   = '\TestPath\'
                    State      = 'Ready'
                }
                $mockTask.PSObject.TypeNames.Insert(0, 'Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask')
                return $mockTask
            }

            Mock -CommandName Get-ScheduledTaskInfo -MockWith {
                param($TaskName, $TaskPath)
                $mockInfo = [PSCustomObject]@{
                    LastRunTime      = (Get-Date).AddHours(-1)
                    LastTaskResult   = 0
                    NextRunTime      = (Get-Date).AddHours(1)
                    NumberOfMissedRuns = 0
                }
                $mockInfo.PSObject.TypeNames.Insert(0, 'Microsoft.Management.Infrastructure.CimInstance#MSFT_TaskDynamicInfo')
                return $mockInfo
            }
        }

        It 'Should add TaskName property when missing from merged hashtable' {
            Mock -CommandName Merge-Object -MockWith {
                param($FirstObject, $SecondObject)
                @{
                    ScheduledTaskObject   = $FirstObject
                    ScheduledTaskInfoObject = $SecondObject
                    LastRunTime           = $SecondObject.LastRunTime
                }
            }

            $result = Get-StmScheduledTaskInfo -TaskName 'ConflictTask'

            $result.TaskName | Should -Be 'ConflictTask'
        }

        It 'Should resolve TaskName property when it is a hashtable' {
            Mock -CommandName Merge-Object -MockWith {
                param($FirstObject, $SecondObject)
                @{
                    TaskName              = @{ Key = 'Value' }
                    ScheduledTaskObject   = $FirstObject
                    ScheduledTaskInfoObject = $SecondObject
                    LastRunTime           = $SecondObject.LastRunTime
                }
            }

            $result = Get-StmScheduledTaskInfo -TaskName 'ConflictTask'

            $result.TaskName | Should -Be 'ConflictTask'
            $result.TaskName | Should -Not -BeOfType [hashtable]
        }
    }

    Context 'Remote-host CIM session plumbing (Issue 3 fix a)' {
        BeforeEach {
            Mock -CommandName Get-StmScheduledTask -MockWith {
                $t = [PSCustomObject]@{
                    TaskName = 'RemoteTask'
                    TaskPath = '\'
                    State    = 'Ready'
                }
                $t.PSObject.TypeNames.Insert(0, 'Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask')
                return $t
            }
            Mock -CommandName New-StmCimSession -MockWith {
                # New-MockObject yields a properly-typed CimSession so the patched code's
                # -CimSession parameter binding on Get-ScheduledTaskInfo succeeds.
                return (New-MockObject -Type 'Microsoft.Management.Infrastructure.CimSession')
            }
            Mock -CommandName Get-ScheduledTaskInfo -MockWith {
                return [PSCustomObject]@{
                    LastRunTime        = (Get-Date).AddHours(-1)
                    LastTaskResult     = 0
                    NextRunTime        = (Get-Date).AddHours(1)
                    NumberOfMissedRuns = 0
                }
            }
            Mock -CommandName Merge-Object -MockWith {
                param($FirstObject, $SecondObject)
                @{ TaskName = $FirstObject.TaskName; State = 'Ready' }
            }
            Mock -CommandName Remove-CimSession -MockWith {}
        }

        It 'Should pass -CimSession to Get-ScheduledTaskInfo when ComputerName is a remote host' {
            Get-StmScheduledTaskInfo -ComputerName 'RemoteServer' -TaskName 'RemoteTask' | Out-Null
            Should -Invoke Get-ScheduledTaskInfo -Times 1 -ParameterFilter {
                $null -ne $CimSession
            }
        }

        It 'Should NOT pass -CimSession to Get-ScheduledTaskInfo when ComputerName is localhost' {
            Get-StmScheduledTaskInfo -ComputerName 'localhost' -TaskName 'RemoteTask' | Out-Null
            Should -Invoke Get-ScheduledTaskInfo -Times 1 -ParameterFilter {
                -not $PSBoundParameters.ContainsKey('CimSession')
            }
        }

        It 'Should forward the supplied Credential to New-StmCimSession for a remote host' {
            $credential = [System.Management.Automation.PSCredential]::new(
                'TestUser',
                (ConvertTo-SecureString 'TestPassword' -AsPlainText -Force)
            )
            $invokeParameters = @{
                ComputerName = 'RemoteServer'
                TaskName     = 'RemoteTask'
                Credential   = $credential
            }
            Get-StmScheduledTaskInfo @invokeParameters | Out-Null

            Should -Invoke New-StmCimSession -Times 1 -Exactly -ParameterFilter {
                $Credential -eq $credential
            }
            # The remote session created for the lookup is torn down in the end block.
            Should -Invoke Remove-CimSession -Times 1 -Exactly
        }
    }

    Context 'Loop continues on per-task failure (Issue 3 fix b)' {
        BeforeEach {
            Mock -CommandName Get-StmScheduledTask -MockWith {
                1..3 | ForEach-Object {
                    $t = [PSCustomObject]@{
                        TaskName = "Task$_"
                        TaskPath = '\'
                        State    = 'Ready'
                    }
                    $t.PSObject.TypeNames.Insert(0, 'Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask')
                    $t
                }
            }
            # Use Write-Error -ErrorAction Stop instead of bare `throw` — a Pester mock body's
            # `throw` behaves unpredictably (the exception was being captured many times via
            # -ErrorVariable instead of going through the cmdlet's try/catch).
            Mock -CommandName Get-ScheduledTaskInfo -ParameterFilter {
                $TaskName -eq 'Task2'
            } -MockWith {
                Write-Error 'simulated CIM failure on Task2' -ErrorAction Stop
            }
            Mock -CommandName Get-ScheduledTaskInfo -MockWith {
                return [PSCustomObject]@{
                    LastRunTime        = (Get-Date).AddHours(-1)
                    LastTaskResult     = 0
                    NextRunTime        = (Get-Date).AddHours(1)
                    NumberOfMissedRuns = 0
                }
            }
            Mock -CommandName Merge-Object -MockWith {
                param($FirstObject, $SecondObject)
                @{ TaskName = $FirstObject.TaskName; State = 'Ready' }
            }
        }

        It 'Should process remaining tasks (and write a per-task error) when one task fails' {
            $err = $null
            $loopParameters = @{
                TaskName      = 'Task*'
                ErrorVariable = 'err'
                ErrorAction   = 'SilentlyContinue'
            }
            $results = Get-StmScheduledTaskInfo @loopParameters

            # Core contract: loop did not abort, output contains the surviving tasks
            @($results).Count                            | Should -Be 2
            @($results | ForEach-Object { $_.TaskName }) | Should -Be @('Task1', 'Task3')

            # And: the failing task surfaced as a structured error with the right attribution.
            # We assert filtered-match-count rather than total-count because Pester's mock
            # framework can add extra raw error records to $err that aren't ours.
            $structuredErrors = $err |
                Where-Object { $_.FullyQualifiedErrorId -match 'ScheduledTaskInfoRetrievalFailed' }
            @($structuredErrors).Count | Should -Be 1
            $structuredErrors[0].TargetObject | Should -Be 'Task2'
        }
    }
    }
}
