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
    Describe 'Unregister-StmClusteredScheduledTask' {
        BeforeEach {
            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'mock-cim-session'
            }

            Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith {} -ParameterFilter {
                $TaskName -eq 'TestTask'
            }
        }

        It 'Should unregister the clustered scheduled task' {
            { Unregister-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' } | Should -Not -Throw
            Should -Invoke -CommandName 'New-StmCimSession' -Times 1 -Exactly
            Should -Invoke -CommandName 'Unregister-ClusteredScheduledTask' -Times 1 -Exactly
        }
    }
}
