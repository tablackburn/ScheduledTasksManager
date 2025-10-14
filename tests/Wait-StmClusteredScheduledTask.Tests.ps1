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
    Describe 'Wait-StmClusteredScheduledTask' {
        BeforeEach {
            $script:waitCounter = 0
            Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                $script:waitCounter++
                if ($script:waitCounter -eq 2) {
                    return [PSCustomObject]@{
                        ScheduledTaskObject = [PSCustomObject]@{
                            State = 'SomethingOtherThanRunning'
                        }
                    }
                }
                else {
                    return [PSCustomObject]@{
                        ScheduledTaskObject = [PSCustomObject]@{
                            State = 'Running'
                        }
                    }
                }
            }
        }

        It 'Should wait for the clustered scheduled task to complete' {
            $parameters = @{
                TaskName               = 'TestTask'
                Cluster                = 'TestCluster'
                PollingIntervalSeconds = 1
            }
            { Wait-StmClusteredScheduledTask @parameters } | Should -Not -Throw
            Should -Invoke -CommandName 'Get-StmClusteredScheduledTask' -Times 2 -Exactly -ParameterFilter {
                $TaskName -eq $parameters.TaskName -and $Cluster -eq $parameters.Cluster
            }
        }

        It 'Should throw an error if the task does not complete within the timeout' {
            Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                return [PSCustomObject]@{
                    ScheduledTaskObject = [PSCustomObject]@{
                        State = 'Running'
                    }
                }
            }

            $parameters = @{
                TaskName               = 'TestTask'
                Cluster                = 'TestCluster'
                PollingIntervalSeconds = 1
                TimeoutSeconds         = 1
            }
            { Wait-StmClusteredScheduledTask @parameters } | Should -Throw

            # Verify that the function was called at least once with correct parameters
            Should -Invoke -CommandName 'Get-StmClusteredScheduledTask' -ParameterFilter {
                $TaskName -eq $parameters.TaskName -and $Cluster -eq $parameters.Cluster
            }
        }

        It 'Should throw a proper timeout exception with correct error details' {
            Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                return [PSCustomObject]@{
                    ScheduledTaskObject = [PSCustomObject]@{
                        State = 'Running'
                    }
                }
            }

            $parameters = @{
                TaskName               = 'TestTask'
                Cluster                = 'TestCluster'
                PollingIntervalSeconds = 1
                TimeoutSeconds         = 1
            }

            $errorThrown = $null
            try {
                Wait-StmClusteredScheduledTask @parameters
            }
            catch {
                $errorThrown = $_
            }

            # Verify error was thrown
            $errorThrown | Should -Not -BeNullOrEmpty

            # Verify error message contains expected text
            $errorThrown.Exception.Message | Should -BeLike "*Timeout reached while waiting for task 'TestTask' to complete*"

            # Verify error ID is correct
            $errorThrown.FullyQualifiedErrorId | Should -BeLike "TimeoutReached*"
        }
    }
}
