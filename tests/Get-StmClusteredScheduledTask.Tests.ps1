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
                Mock -CommandName 'Get-ClusteredScheduledTask' -MockWith { return @([PSCustomObject]@{ TaskName = 'TestTask1'; CurrentOwner = $null }) }
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

        Context 'Parameter validation' {
            BeforeAll {
                $command = Get-Command -Name 'Get-StmClusteredScheduledTask'
            }

            It 'Should require a cluster name' {
                $command.Parameters['Cluster'].ParameterSets.Values.IsMandatory | Should -Not -Contain $false
            }

            It 'Should require a task name if specified' {
                { Get-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskName '' } | Should -Throw
            }

            It 'Should not require a task name' {
                $command.Parameters['TaskName'].ParameterSets.Values.IsMandatory | Should -Not -Contain $true
            }

            It 'Should accept a valid cluster name' {
                { Get-StmClusteredScheduledTask -Cluster 'TestCluster' } | Should -Not -Throw
            }

            It 'Should throw an error for an invalid cluster name' {
                { Get-StmClusteredScheduledTask -Cluster '' } | Should -Throw
            }

            It 'Should accept a valid task state' {
                { Get-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskState 'Ready' } | Should -Not -Throw
            }

            It 'Should throw an error for an invalid task state' {
                { Get-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskState 'InvalidState' } | Should -Throw
            }

            It 'Should accept a valid task type' {
                { Get-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskType 'AnyNode' } | Should -Not -Throw
            }

            It 'Should throw an error for an invalid task type' {
                { Get-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskType 'InvalidType' } | Should -Throw
            }

            It 'Should accept a valid credential' {
                $credential = New-Object -TypeName 'System.Management.Automation.PSCredential' -ArgumentList ('user', (ConvertTo-SecureString 'password' -AsPlainText -Force))
                { Get-StmClusteredScheduledTask -Cluster 'TestCluster' -Credential $credential } | Should -Not -Throw
            }

            It 'Should not throw an error if no credential is provided' {
                { Get-StmClusteredScheduledTask -Cluster 'TestCluster' } | Should -Not -Throw
            }

            It 'Should accept a valid CIM session' {
                $cimSession = New-MockObject -Type 'Microsoft.Management.Infrastructure.CimSession'
                { Get-StmClusteredScheduledTask -Cluster 'TestCluster' -CimSession $cimSession } | Should -Not -Throw
            }
        }
    }
}
