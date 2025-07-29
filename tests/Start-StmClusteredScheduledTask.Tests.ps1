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
    Describe 'Start-StmClusteredScheduledTask' {
        BeforeEach {
            $mockedScheduledTaskObjectParameters = @{
                TypeName     = 'Microsoft.Management.Infrastructure.CimInstance'
                ArgumentList = @(
                    'MSFT_ScheduledTask'                   # Cim class name (Get using: (Get-ScheduledTask).get_CimClass())
                    'Root/Microsoft/Windows/TaskScheduler' # Cim namespace (Get using: (Get-ScheduledTask).CimSystemProperties)
                )
            }
            $mockedScheduledTaskObject = New-Object @mockedScheduledTaskObjectParameters
            Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                return [PSCustomObject]@{
                    TaskName = 'TestTask'
                    ScheduledTaskObject = $mockedScheduledTaskObject
                }
            } -ParameterFilter {
                $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
            }

            Mock -CommandName 'Start-ScheduledTask' -MockWith {
                param(
                    [Parameter(ValueFromPipeline)]
                    $InputObject
                )
                return $InputObject
            } -ParameterFilter {
                $InputObject -eq $mockedScheduledTaskObject
            }
        }

        It 'Should start the clustered scheduled task' {
            { Start-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' } | Should -Not -Throw
            Should -Invoke -CommandName 'Get-StmClusteredScheduledTask' -Times 1 -Exactly
            Should -Invoke -CommandName 'Start-ScheduledTask' -Times 1 -Exactly
        }
    }
}
