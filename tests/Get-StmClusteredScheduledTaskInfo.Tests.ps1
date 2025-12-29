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

        Context 'Parameter Handling' {
            It 'Should retrieve all tasks when TaskName is not specified' {
                $verboseOutput = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'Retrieving all tasks on cluster'
            }

            It 'Should pass TaskType to Get-StmClusteredScheduledTask when specified' {
                Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -TaskType ClusterWide
                Should -Invoke -CommandName 'Get-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskType -eq 'ClusterWide'
                }
            }

            It 'Should write verbose message when TaskType is specified' {
                $verboseOutput = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -TaskType ClusterWide -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match "Filtering tasks by type.*ClusterWide"
            }

            It 'Should write verbose message when no TaskType filter applied' {
                $verboseOutput = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'No specific task type filter applied'
            }

            It 'Should pass TaskState to Get-StmClusteredScheduledTask when specified' {
                Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -TaskState Ready
                Should -Invoke -CommandName 'Get-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskState -eq 'Ready'
                }
            }

            It 'Should write verbose message when TaskState is specified' {
                $verboseOutput = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -TaskState Ready -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match "Filtering tasks by state.*Ready"
            }

            It 'Should write verbose message when no TaskState filter applied' {
                $verboseOutput = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'No specific task state filter applied'
            }
        }

        Context 'CimSession and Credential Handling' {
            It 'Should pass CimSession to Get-StmClusteredScheduledTask when specified' -Skip:$true {
                # CimSession requires an actual connection, skip in unit tests
            }

            It 'Should write verbose message when CimSession is provided' -Skip:$true {
                # CimSession requires an actual connection, skip in unit tests
            }

            It 'Should pass Credential to Get-StmClusteredScheduledTask when specified' {
                $testCredential = [PSCredential]::new(
                    'TestUser',
                    (ConvertTo-SecureString -String 'TestPassword' -AsPlainText -Force)
                )
                Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -Credential $testCredential
                Should -Invoke -CommandName 'Get-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $null -ne $Credential -and $Credential -ne [System.Management.Automation.PSCredential]::Empty
                }
            }

            It 'Should write verbose message when Credential is provided' {
                $testCredential = [PSCredential]::new(
                    'TestUser',
                    (ConvertTo-SecureString -String 'TestPassword' -AsPlainText -Force)
                )
                $verboseOutput = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -Credential $testCredential -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'Using provided credentials for cluster'
            }

            It 'Should write verbose message when no CimSession or Credential provided' {
                $verboseOutput = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'No CIM session or credentials provided, using default credentials'
            }
        }

        Context 'When no tasks are found' {
            BeforeEach {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return @()
                }
            }

            It 'Should write warning when no tasks are found' {
                $warningOutput = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' 3>&1
                $warningOutput | Should -Match 'No scheduled tasks found on cluster'
            }

            It 'Should return nothing when no tasks are found' {
                $result = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' 3>$null
                $result | Should -BeNullOrEmpty
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

            It 'Should write verbose message with running duration' {
                $verboseOutput = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -TaskName 'RunningTask' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'has been running for'
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

        Context 'Verbose Output' {
            It 'Should write start message' {
                $verboseOutput = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match "Starting Get-StmClusteredScheduledTaskInfo on cluster.*TestCluster"
            }

            It 'Should write completion message' {
                $verboseOutput = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match "Completed Get-StmClusteredScheduledTaskInfo for cluster.*TestCluster"
            }

            It 'Should write message about merging properties' {
                $verboseOutput = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'Merging properties from clustered scheduled task and task info'
            }

            It 'Should write verbose message when TaskName is specified' {
                $verboseOutput = Get-StmClusteredScheduledTaskInfo -Cluster 'TestCluster' -TaskName 'TestTask' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match "Filtering tasks by name.*TestTask"
            }
        }
    }
}
