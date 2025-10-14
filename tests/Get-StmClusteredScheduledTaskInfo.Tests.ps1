BeforeDiscovery {
    # Unload the module if it is loaded
    if (Get-Module -Name 'ScheduledTasksManager') {
        Remove-Module -Name 'ScheduledTasksManager' -Force
    }

    # Import the module or function being tested
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ScheduledTasksManager\ScheduledTasksManager.psd1'
    Import-Module -Name $ModulePath -Force
}

InModuleScope -ModuleName 'ScheduledTasksManager' {
    Describe 'Get-StmClusteredScheduledTaskInfo' {
        BeforeEach {
            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'this-is-a-mock-cim-session'
            }

            Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                $cimInstanceParameters = @{
                    TypeName     = 'Microsoft.Management.Infrastructure.CimInstance'
                    ArgumentList = @(
                        'MSFT_ScheduledTask'
                        'Root/Microsoft/Windows/TaskScheduler'
                    )
                }
                return [PSCustomObject]@{
                    TaskName                     = 'TestTask'
                    State                        = 'Ready'
                    ScheduledTaskObject          = New-Object @cimInstanceParameters
                    ClusteredScheduledTaskObject = [PSCustomObject]@{
                        TaskName     = 'TestTask'
                        CurrentOwner = 'OwnerNode'
                    }
                }
            }

            Mock -CommandName 'Get-ScheduledTaskInfo' -MockWith {
                param($TaskName)
                return [PSCustomObject]@{
                    TaskState = 'Ready'
                    TaskName  = $TaskName
                }
            }
        }

        Context 'When called with valid parameters' {
            It 'Should retrieve task information successfully' {
                $result = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -TaskName 'TestTask'
                $result | Should -Not -BeNullOrEmpty
                $result.TaskName | Should -Be 'TestTask'
            }
        }

        Context 'When task is running' {
            BeforeEach {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    $cimInstanceParameters = @{
                        TypeName     = 'Microsoft.Management.Infrastructure.CimInstance'
                        ArgumentList = @(
                            'MSFT_ScheduledTask'
                            'Root/Microsoft/Windows/TaskScheduler'
                        )
                    }
                    # ClusteredScheduledTaskObject returns enum-like value (int) for TaskState
                    return [PSCustomObject]@{
                        TaskName                     = 'RunningTask'
                        State                        = [Microsoft.PowerShell.Cmdletization.GeneratedTypes.ScheduledTask.StateEnum]::Running
                        ScheduledTaskObject          = New-Object @cimInstanceParameters
                        ClusteredScheduledTaskObject = [PSCustomObject]@{
                            TaskName     = 'RunningTask'
                            CurrentOwner = 'OwnerNode'
                            TaskState    = 4  # Running enum value
                        }
                    }
                }

                Mock -CommandName 'Get-ScheduledTaskInfo' -MockWith {
                    return [PSCustomObject]@{
                        TaskState    = 'Running'
                        TaskName     = 'RunningTask'
                        LastRunTime  = (Get-Date).AddMinutes(-15)
                    }
                }
            }

            It 'Should calculate RunningDuration when task is running' {
                $result = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -TaskName 'RunningTask'
                $result.RunningDuration | Should -Not -BeNullOrEmpty
                $result.RunningDuration | Should -BeOfType [TimeSpan]
            }

            It 'Should have RunningDuration greater than zero when task is running' {
                $result = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -TaskName 'RunningTask'
                $result.RunningDuration.TotalSeconds | Should -BeGreaterThan 0
            }

            It 'Should have RunningDuration approximately matching elapsed time since LastRunTime' {
                $startTime = (Get-Date).AddMinutes(-10)
                Mock -CommandName 'Get-ScheduledTaskInfo' -MockWith {
                    return [PSCustomObject]@{
                        TaskState    = 'Running'
                        TaskName     = 'RunningTask'
                        LastRunTime  = $startTime
                    }
                }

                $result = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -TaskName 'RunningTask'
                $expectedMinutes = ((Get-Date) - $startTime).TotalMinutes
                $result.RunningDuration.TotalMinutes | Should -BeGreaterOrEqual ($expectedMinutes - 1)
                $result.RunningDuration.TotalMinutes | Should -BeLessOrEqual ($expectedMinutes + 1)
            }
        }

        Context 'When task is not running' {
            BeforeEach {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    $cimInstanceParameters = @{
                        TypeName     = 'Microsoft.Management.Infrastructure.CimInstance'
                        ArgumentList = @(
                            'MSFT_ScheduledTask'
                            'Root/Microsoft/Windows/TaskScheduler'
                        )
                    }
                    return [PSCustomObject]@{
                        TaskName                     = 'ReadyTask'
                        State                        = [Microsoft.PowerShell.Cmdletization.GeneratedTypes.ScheduledTask.StateEnum]::Ready
                        ScheduledTaskObject          = New-Object @cimInstanceParameters
                        ClusteredScheduledTaskObject = [PSCustomObject]@{
                            TaskName     = 'ReadyTask'
                            CurrentOwner = 'OwnerNode'
                            TaskState    = 'Ready'
                        }
                    }
                }

                Mock -CommandName 'Get-ScheduledTaskInfo' -MockWith {
                    return [PSCustomObject]@{
                        TaskState    = 'Ready'
                        TaskName     = 'ReadyTask'
                        LastRunTime  = (Get-Date).AddHours(-1)
                    }
                }
            }

            It 'Should set RunningDuration to null when task is not running' {
                $result = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -TaskName 'ReadyTask'
                $result.RunningDuration | Should -BeNullOrEmpty
            }
        }

        Context 'When task has no LastRunTime' {
            BeforeEach {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    $cimInstanceParameters = @{
                        TypeName     = 'Microsoft.Management.Infrastructure.CimInstance'
                        ArgumentList = @(
                            'MSFT_ScheduledTask'
                            'Root/Microsoft/Windows/TaskScheduler'
                        )
                    }
                    return [PSCustomObject]@{
                        TaskName                     = 'NewTask'
                        State                        = [Microsoft.PowerShell.Cmdletization.GeneratedTypes.ScheduledTask.StateEnum]::Ready
                        ScheduledTaskObject          = New-Object @cimInstanceParameters
                        ClusteredScheduledTaskObject = [PSCustomObject]@{
                            TaskName     = 'NewTask'
                            CurrentOwner = 'OwnerNode'
                            TaskState    = 'Ready'
                        }
                    }
                }

                Mock -CommandName 'Get-ScheduledTaskInfo' -MockWith {
                    return [PSCustomObject]@{
                        TaskState   = 'Ready'
                        TaskName    = 'NewTask'
                        LastRunTime = $null
                    }
                }
            }

            It 'Should set RunningDuration to null when LastRunTime is null' {
                $result = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -TaskName 'NewTask'
                $result.RunningDuration | Should -BeNullOrEmpty
            }
        }
    }
}
