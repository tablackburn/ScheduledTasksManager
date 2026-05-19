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

        Context 'When a named task is not found in the cluster (Issue 1 / stage-A miss)' {
            BeforeEach {
                Mock -CommandName 'Get-ClusteredScheduledTask' -MockWith { return @() }
                # The outer BeforeEach mocks New-StmCimSession to return a string sentinel,
                # so Remove-CimSession in the end block would fail without this mock.
                Mock -CommandName 'Remove-CimSession' -MockWith {}
            }

            It 'Should write a structured non-terminating error (not a warning) when -TaskName is given' {
                $err = $null
                $warn = $null
                $namedParameters = @{
                    Cluster         = 'TestCluster'
                    TaskName        = 'NoSuchTask'
                    ErrorVariable   = 'err'
                    WarningVariable = 'warn'
                    ErrorAction     = 'SilentlyContinue'
                    WarningAction   = 'SilentlyContinue'
                }
                Get-StmClusteredScheduledTask @namedParameters

                $err.Count                    | Should -Be 1
                $err[0].FullyQualifiedErrorId | Should -Match 'ClusteredScheduledTaskNotFound'
                $err[0].CategoryInfo.Category | Should -Be 'ObjectNotFound'
                $err[0].TargetObject          | Should -Be 'NoSuchTask'
                $warn.Count                   | Should -Be 0
            }

            It 'Should still emit a warning (and no error) when -TaskName is omitted (bulk path)' {
                $err = $null
                $warn = $null
                $bulkParameters = @{
                    Cluster         = 'TestCluster'
                    ErrorVariable   = 'err'
                    WarningVariable = 'warn'
                    ErrorAction     = 'SilentlyContinue'
                    WarningAction   = 'SilentlyContinue'
                }
                Get-StmClusteredScheduledTask @bulkParameters

                $warn.Count      | Should -BeGreaterThan 0
                $warn[0].Message | Should -Match 'No clustered scheduled tasks found'
                $err.Count       | Should -Be 0
            }
        }

        Context 'When the cluster claims an owner but the owner does not return the task (Issue 1 / stage-B miss)' {
            BeforeEach {
                Mock -CommandName 'Get-ClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{
                        TaskName     = 'StragglerTask'
                        CurrentOwner = 'OwnerNode1'
                    }
                }
                # Owner returns no tasks for the requested name — the stage-B miss scenario
                Mock -CommandName 'Get-ScheduledTask' -MockWith { return @() }
                Mock -CommandName 'Remove-CimSession' -MockWith {}
            }

            It 'Should write a structured ClusteredScheduledTaskOwnerLookupFailed error' {
                $err = $null
                $stageBParameters = @{
                    Cluster       = 'TestCluster'
                    TaskName      = 'StragglerTask'
                    ErrorVariable = 'err'
                    ErrorAction   = 'SilentlyContinue'
                }
                Get-StmClusteredScheduledTask @stageBParameters

                $err.FullyQualifiedErrorId |
                    Should -Contain 'ClusteredScheduledTaskOwnerLookupFailed,Get-StmClusteredScheduledTask'
                $matchingErr = $err | Where-Object { $_.FullyQualifiedErrorId -match 'OwnerLookupFailed' }
                $matchingErr.TargetObject | Should -Be 'StragglerTask'
            }
        }
    }
}
