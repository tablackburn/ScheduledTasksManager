BeforeDiscovery {
    # Unload the module if it is loaded
    if (Get-Module -Name 'ScheduledTasksManager') {
        Remove-Module -Name 'ScheduledTasksManager' -Force
    }

    # Import the module or function being tested
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ScheduledTasksManager\ScheduledTasksManager.psd1'
    Import-Module -Name $modulePath -Force
}

InModuleScope -ModuleName 'ScheduledTasksManager' {
    Describe 'Get-StmClusteredScheduledTask' {
        BeforeEach {
            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'this-is-a-mock-cim-session'
            }

            Mock -CommandName 'Get-ClusteredScheduledTask' -MockWith {
                param($TaskName)
                if ($TaskName) {
                    return [PSCustomObject]@{
                        TaskName     = $TaskName
                        CurrentOwner = 'OwnerNode'
                    }
                }
                else {
                    return @(
                        [PSCustomObject]@{
                            TaskName     = 'TestTask1'
                            CurrentOwner = 'OwnerNode1'
                        },
                        [PSCustomObject]@{
                            TaskName     = 'TestTask2'
                            CurrentOwner = 'OwnerNode2'
                        }
                    )
                }
            }

            Mock -CommandName 'Get-ScheduledTask' -MockWith {
                param($TaskName)
                return [PSCustomObject]@{
                    State    = 'Ready'
                    TaskName = $TaskName
                }
            }
        }

        Context 'When called with valid parameters' {
            It 'Should retrieve tasks from the specified cluster' {
                $result = Get-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskName 'TestTask1'
                $result | Should -Not -BeNullOrEmpty
                $result.TaskName | Should -Be 'TestTask1'
            }

            It 'Should handle multiple tasks correctly' {
                $result = Get-StmClusteredScheduledTask -Cluster 'TestCluster'
                $result | Should -Not -BeNullOrEmpty
                $result.Count | Should -Be 2
            }

            It 'Should filter tasks by state if specified' {
                $result = Get-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskState 'Ready'
                $result | Should -Not -BeNullOrEmpty
                $uniqueStates = $result | Select-Object -ExpandProperty 'State' -Unique
                $uniqueStates | Should -Be 'Ready'
            }

            It 'Should retrieve tasks from the specified owner' {
                $result = Get-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskName 'TestTask1'
                $result | Should -Not -BeNullOrEmpty
                $result.CurrentOwner | Should -Be 'OwnerNode'
            }
        }

        Context 'When no tasks are found' {
            It 'Should return an empty result' {
                Mock -CommandName 'Get-ClusteredScheduledTask' -MockWith { return @() }
                $result = Get-StmClusteredScheduledTask -Cluster 'TestCluster'
                $result | Should -BeNullOrEmpty
            }

            It 'Should issue a warning when no tasks are found' {
                Mock -CommandName 'Get-ClusteredScheduledTask' -MockWith { return @() }
                Mock -CommandName 'Write-Warning' -MockWith {}
                $result = Get-StmClusteredScheduledTask -Cluster 'TestCluster'
                Should -Invoke -CommandName 'Write-Warning' -Times 1 -Exactly
                $result | Should -BeNullOrEmpty
            }
        }

        Context 'When no owners are found' {
            It 'Should write an error' {
                Mock -CommandName 'Get-ClusteredScheduledTask' -MockWith {
                    return @([PSCustomObject]@{
                        TaskName     = 'TestTask1'
                        CurrentOwner = $null
                    })
                }
                Mock -CommandName 'Write-Error' -MockWith {}
                $result = Get-StmClusteredScheduledTask -Cluster 'TestCluster'
                Should -Invoke -CommandName 'Write-Error' -Times 1 -Exactly
                $result | Should -BeNullOrEmpty
            }
        }

        Context 'When a task owner is empty' {
            It 'Should skip the owner and continue processing' {
                Mock -CommandName 'Get-ClusteredScheduledTask' -MockWith {
                    return @(
                        [PSCustomObject]@{
                            TaskName     = 'TestTask1'
                            CurrentOwner = ''
                        },
                        [PSCustomObject]@{
                            TaskName     = 'TestTask2'
                            CurrentOwner = 'OwnerNode2'
                        }
                    )
                }
                $result = Get-StmClusteredScheduledTask -Cluster 'TestCluster'
                $result.Count | Should -Be 1
            }
        }

        Context 'CimSession parameter' {
            It 'Should use provided CimSession instead of creating new one' -Skip {
                # This test is skipped because CimSession cannot be easily mocked
                # The CimSession parameter requires a real Microsoft.Management.Infrastructure.CimSession object
                # which cannot be constructed in tests without actual connectivity
            }
        }

        Context 'TaskType parameter' {
            It 'Should pass TaskType to Get-ClusteredScheduledTask' {
                Mock -CommandName 'Get-ClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{
                        TaskName     = 'TestTask1'
                        CurrentOwner = 'OwnerNode1'
                        TaskType     = 'ClusterWide'
                    }
                }

                Get-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskType ClusterWide

                Should -Invoke 'Get-ClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskType -eq 'ClusterWide'
                }
            }
        }

        Context 'Error handling' {
            It 'Should warn when no matching clustered task found for scheduled task' {
                Mock -CommandName 'Get-ClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{
                        TaskName     = 'ClusteredTask1'
                        CurrentOwner = 'OwnerNode1'
                    }
                }
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    return [PSCustomObject]@{
                        TaskName = 'DifferentTask'
                        State    = 'Ready'
                    }
                }
                Mock -CommandName 'Write-Warning' -MockWith {}

                Get-StmClusteredScheduledTask -Cluster 'TestCluster'

                Should -Invoke 'Write-Warning' -Times 1 -ParameterFilter {
                    $Message -like '*No matching clustered task found*'
                }
            }

            It 'Should write error when retrieving tasks from owner fails' {
                Mock -CommandName 'Get-ClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{
                        TaskName     = 'TestTask1'
                        CurrentOwner = 'OwnerNode1'
                    }
                }
                Mock -CommandName 'New-StmCimSession' -MockWith {
                    param($ComputerName)
                    if ($ComputerName -eq 'OwnerNode1') {
                        throw 'Connection failed'
                    }
                    return 'mock-session'
                }
                Mock -CommandName 'Write-Error' -MockWith {}

                Get-StmClusteredScheduledTask -Cluster 'TestCluster'

                Should -Invoke 'Write-Error' -Times 1 -ParameterFilter {
                    $Message -like "*Failed to retrieve tasks from owner*"
                }
            }

            It 'Should warn when Merge-Object fails' {
                Mock -CommandName 'Get-ClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{
                        TaskName     = 'TestTask1'
                        CurrentOwner = 'OwnerNode1'
                    }
                }
                Mock -CommandName 'Merge-Object' -MockWith {
                    throw 'Merge failed'
                }
                Mock -CommandName 'Write-Warning' -MockWith {}

                Get-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskName 'TestTask1'

                Should -Invoke 'Write-Warning' -Times 1 -ParameterFilter {
                    $Message -like '*Failed to merge objects*'
                }
            }

            It 'Should cleanup task owner CIM session when Get-ScheduledTask fails' {
                $script:sessionCreationCount = 0
                Mock -CommandName 'Get-ClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{
                        TaskName     = 'TestTask1'
                        CurrentOwner = 'OwnerNode1'
                    }
                }
                Mock -CommandName 'New-StmCimSession' -MockWith {
                    $script:sessionCreationCount++
                    return "mock-session-$($script:sessionCreationCount)"
                }
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    throw 'Failed to retrieve scheduled task'
                }
                Mock -CommandName 'Remove-CimSession' -MockWith {}
                Mock -CommandName 'Write-Error' -MockWith {}

                Get-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskName 'TestTask1'

                # Two sessions created: cluster session (1) and task owner session (2)
                # Task owner session (2) should be cleaned up on error
                # Cluster session (1) should be cleaned up in end block
                # So Remove-CimSession should be called at least twice
                Should -Invoke 'Remove-CimSession' -Times 2 -Exactly
            }
        }
    }
}
