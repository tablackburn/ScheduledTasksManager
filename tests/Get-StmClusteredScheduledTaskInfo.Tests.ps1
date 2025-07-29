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
                return [PSCustomObject]@{
                    TaskName = 'TestTask'
                    ScheduledTaskObject = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                        'MSFT_ScheduledTask'
                        'Root/Microsoft/Windows/TaskScheduler'
                    )
                    ClusteredScheduledTaskObject = [PSCustomObject]@{
                        TaskName     = 'TestTask'
                        CurrentOwner = 'OwnerNode'
                    }
                }
            }

            Mock -CommandName 'Get-ScheduledTaskInfo' -MockWith {
                param($TaskName)
                return [PSCustomObject]@{
                    State    = 'Ready'
                    TaskName = $TaskName
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

        Context 'Parameter validation' {
            BeforeAll {
                $script:command = Get-Command -Name 'Get-StmClusteredScheduledTaskInfo'
            }

            It 'Should require a cluster name' {
                $command.Parameters['Cluster'].ParameterSets.Values.IsMandatory | Should -Not -Contain $false
            }

            It 'Should not require a task name' {
                $command.Parameters['TaskName'].ParameterSets.Values.IsMandatory | Should -Not -Contain $true
            }
        }
    }
}
