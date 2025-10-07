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
    Describe 'Get-StmClusteredScheduledTaskRun' {
        BeforeEach {
            # Mock cluster nodes
            $mockClusterNodes = @(
                [PSCustomObject]@{
                    Name = 'Node1'
                    State = 'Up'
                },
                [PSCustomObject]@{
                    Name = 'Node2'
                    State = 'Up'
                }
            )

            # Mock task runs
            $mockTaskRun1 = [PSCustomObject]@{
                TaskName = 'TestTask1'
                ComputerName = 'Node1'
                StartTime = [DateTime]::Now.AddMinutes(-5)
                EndTime = [DateTime]::Now.AddMinutes(-4)
                Result = 0
            }

            $mockTaskRun2 = [PSCustomObject]@{
                TaskName = 'TestTask1'
                ComputerName = 'Node2'
                StartTime = [DateTime]::Now.AddMinutes(-3)
                EndTime = [DateTime]::Now.AddMinutes(-2)
                Result = 0
            }

            # Mock Get-StmClusterNode
            Mock -CommandName 'Get-StmClusterNode' -MockWith {
                return $mockClusterNodes
            }

            # Mock Get-StmScheduledTaskRun
            Mock -CommandName 'Get-StmScheduledTaskRun' -MockWith {
                if ($ComputerName -eq 'Node1') {
                    return $mockTaskRun1
                } else {
                    return $mockTaskRun2
                }
            }

            # Mock Write-Error
            Mock -CommandName 'Write-Error' -MockWith { }
        }

        Context 'Function Execution' {
            BeforeEach {
                # Mock setup will be added here
            }

            It 'Should return task runs from all cluster nodes' {
                $results = Get-StmClusteredScheduledTaskRun -TaskName 'TestTask1' -Cluster 'TestCluster'
                $results | Should -Not -BeNullOrEmpty
                $results | Where-Object { $_.ComputerName -eq 'Node1' } | Should -Not -BeNullOrEmpty
                $results | Where-Object { $_.ComputerName -eq 'Node2' } | Should -Not -BeNullOrEmpty
                Should -Invoke -CommandName 'Get-StmScheduledTaskRun' -Times 2 -Exactly
            }

            It 'Should handle empty cluster node list' {
                Mock -CommandName 'Get-StmClusterNode' -MockWith { return $null }

                $results = Get-StmClusteredScheduledTaskRun -TaskName 'TestTask1' -Cluster 'TestCluster'
                $results | Should -BeNullOrEmpty
                Should -Invoke -CommandName 'Write-Error' -Times 1 -ParameterFilter {
                    $Message -eq "No cluster nodes found for cluster 'TestCluster'"
                }
            }

            It 'Should pass credentials when specified' {
                $testCred = [System.Management.Automation.PSCredential]::new(
                    'testuser',
                    ('testpass' | ConvertTo-SecureString -AsPlainText -Force)
                )

                Get-StmClusteredScheduledTaskRun -TaskName 'TestTask1' -Cluster 'TestCluster' -Credential $testCred

                Should -Invoke -CommandName 'Get-StmClusterNode' -Times 1 -ParameterFilter {
                    $null -ne $Credential -and $Credential.UserName -eq 'testuser'
                }
            }

            It 'Should pass TaskPath when specified' {
                Get-StmClusteredScheduledTaskRun -TaskName 'TestTask1' -Cluster 'TestCluster' -TaskPath '\Test\Path'

                Should -Invoke -CommandName 'Get-StmScheduledTaskRun' -Times 2 -ParameterFilter {
                    $TaskPath -eq '\Test\Path'
                }
        }

        Context 'Error Handling' {
            It 'Should write an error when no cluster nodes are found' {
                # Test implementation will be added here
            }

            It 'Should handle errors from Get-StmScheduledTaskRun' {
                Mock -CommandName 'Get-StmScheduledTaskRun' -MockWith {
                    throw [System.InvalidOperationException]::new('Failed to get task runs')
                }

                { Get-StmClusteredScheduledTaskRun -TaskName 'TestTask1' -Cluster 'TestCluster' } |
                    Should -Throw -ExceptionType ([System.InvalidOperationException])
            }
        }
    }
}
}
