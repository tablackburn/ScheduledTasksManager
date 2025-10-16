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
            $mockTask = [PSCustomObject]@{
                TaskName     = 'PipelineTask'
                TaskPath     = '\TestPath\'
                State        = 'Ready'
            }
            $mockTask.PSObject.TypeNames.Insert(0, 'Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask')

            $result = $mockTask | Get-StmScheduledTaskInfo

            $result | Should -Not -BeNullOrEmpty
            $result.TaskName | Should -Be 'PipelineTask'
            Should -Invoke Get-ScheduledTaskInfo -Times 1 -Exactly
        }

        It 'Should accept multiple tasks from pipeline' {
            $mockTask1 = [PSCustomObject]@{
                TaskName   = 'Task1'
                TaskPath   = '\Path1\'
                State      = 'Ready'
            }
            $mockTask1.PSObject.TypeNames.Insert(0, 'Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask')

            $mockTask2 = [PSCustomObject]@{
                TaskName   = 'Task2'
                TaskPath   = '\Path2\'
                State      = 'Ready'
            }
            $mockTask2.PSObject.TypeNames.Insert(0, 'Microsoft.Management.Infrastructure.CimInstance#MSFT_ScheduledTask')

            $mockTasks = @($mockTask1, $mockTask2)

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

        It 'Should throw terminating error when Get-ScheduledTaskInfo fails' {
            Mock -CommandName Get-ScheduledTaskInfo -MockWith {
                throw 'Access Denied'
            }

            Mock -CommandName Merge-Object -MockWith {
                @{
                    TaskName = 'ErrorTask'
                }
            }

            {
                Get-StmScheduledTaskInfo -TaskName 'ErrorTask'
            } | Should -Throw

            Should -Invoke Get-ScheduledTaskInfo -Times 1 -Exactly
            Should -Invoke New-StmError -Times 1 -Exactly
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

            {
                Get-StmScheduledTaskInfo -TaskName 'ErrorTask'
            } | Should -Throw

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
    }
}
