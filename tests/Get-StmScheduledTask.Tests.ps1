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
    Describe 'Get-StmScheduledTask' {
        BeforeEach {
            $mockTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                'MSFT_ScheduledTask',
                'Root/Microsoft/Windows/TaskScheduler'
            )
            $mockTaskNameProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                'TaskName',
                'TestTask1',
                [Microsoft.Management.Infrastructure.CimType]::String,
                [Microsoft.Management.Infrastructure.CimFlags]::Property -bor [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
            )
            $mockURIProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                'URI',
                '\TestTask1',
                [Microsoft.Management.Infrastructure.CimType]::String,
                [Microsoft.Management.Infrastructure.CimFlags]::Property -bor [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
            )
            $mockStateProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                'State',
                'Ready',
                [Microsoft.Management.Infrastructure.CimType]::String,
                [Microsoft.Management.Infrastructure.CimFlags]::Property -bor [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
            )
            $mockTask.CimInstanceProperties.Add($mockTaskNameProperty)
            $mockTask.CimInstanceProperties.Add($mockURIProperty)
            $mockTask.CimInstanceProperties.Add($mockStateProperty)
            Mock -CommandName 'Get-ScheduledTask' -MockWith {
                return @(
                    $mockTask
                )
            }

            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'this-is-a-mock-cim-session'
            }
        }

        It 'should return the scheduled task' {
            $result = Get-StmScheduledTask -TaskName 'TestTask1'
            $result | Should -Not -BeNullOrEmpty
            $result.TaskName | Should -Be 'TestTask1'
        }

        It 'should filter tasks by TaskState' {
            $result = Get-StmScheduledTask -TaskState 'Ready'
            $result | Should -Not -BeNullOrEmpty
            $result.TaskName | Should -Be 'TestTask1'
            $result.State | Should -Be 'Ready'
        }
    }
}
