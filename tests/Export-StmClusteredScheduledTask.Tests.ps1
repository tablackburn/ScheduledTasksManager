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
    Describe 'Export-StmClusteredScheduledTask' {
        BeforeEach {
            $mockedScheduledTaskObjectParameters = @{
                TypeName = 'Microsoft.Management.Infrastructure.CimInstance'
                ArgumentList = @(
                    'MSFT_ScheduledTask'                   # Cim class name (Get using: (Get-ScheduledTask).get_CimClass())
                    'Root/Microsoft/Windows/TaskScheduler' # Cim namespace (Get using: (Get-ScheduledTask).CimSystemProperties)
                )
            }
            Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                return [PSCustomObject]@{
                    TaskName = 'TestTask'
                    ScheduledTaskObject = New-Object @mockedScheduledTaskObjectParameters
                }
            }

            Mock -CommandName 'Export-ScheduledTask' -MockWith {
                return '<TaskDefinition>MockTaskXML</TaskDefinition>'
            }
        }

        It 'should export a clustered scheduled task successfully' {
            $result = Export-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskName 'TestTask'
            $result | Should -Be '<TaskDefinition>MockTaskXML</TaskDefinition>'
        }

        It 'should complete successfully when FilePath is provided' {
            $testFilePath = 'TestDrive:\Task.xml'
            { Export-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskName 'TestTask' -FilePath $testFilePath } | Should -Not -Throw
        }

        It 'should not return output when FilePath is provided' {
            $testFilePath = 'TestDrive:\Task.xml'
            $result = Export-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskName 'TestTask' -FilePath $testFilePath

            $result | Should -BeNullOrEmpty
        }

        It 'should create the directory if it does not exist' {
            $testFilePath = 'TestDrive:\Test\Task.xml'
            $result = Export-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskName 'TestTask' -FilePath $testFilePath
            $result | Should -BeNullOrEmpty
            $testFilePath | Should -Exist
        }
    }
}
