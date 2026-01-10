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
                    # Cim class name (Get using: (Get-ScheduledTask).get_CimClass())
                    'MSFT_ScheduledTask'
                    # Cim namespace (Get using: (Get-ScheduledTask).CimSystemProperties)
                    'Root/Microsoft/Windows/TaskScheduler'
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
            $exportParameters = @{
                Cluster  = 'TestCluster'
                TaskName = 'TestTask'
                FilePath = $testFilePath
            }
            { Export-StmClusteredScheduledTask @exportParameters } | Should -Not -Throw
        }

        It 'should not return output when FilePath is provided' {
            $testFilePath = 'TestDrive:\Task.xml'
            $exportParameters = @{
                Cluster  = 'TestCluster'
                TaskName = 'TestTask'
                FilePath = $testFilePath
            }
            $result = Export-StmClusteredScheduledTask @exportParameters

            $result | Should -BeNullOrEmpty
        }

        It 'should create the directory if it does not exist' {
            $testFilePath = 'TestDrive:\Test\Task.xml'
            $exportParameters = @{
                Cluster  = 'TestCluster'
                TaskName = 'TestTask'
                FilePath = $testFilePath
            }
            $result = Export-StmClusteredScheduledTask @exportParameters
            $result | Should -BeNullOrEmpty
            $testFilePath | Should -Exist
        }

        Context 'Error Handling' {
            It 'should write error when task retrieval returns null' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return $null
                }

                $result = Export-StmClusteredScheduledTask -Cluster 'TestCluster' -TaskName 'NonExistentTask' -ErrorVariable exportError -ErrorAction SilentlyContinue

                $result | Should -BeNullOrEmpty
                $exportError | Should -Not -BeNullOrEmpty
                $exportError[0].Exception.Message | Should -BeLike "*Failed to retrieve scheduled task*"
            }

            It 'should throw when file export fails' {
                Mock -CommandName 'Export-ScheduledTask' -MockWith {
                    throw 'Export failed'
                }

                $testFilePath = 'TestDrive:\FailExport.xml'
                $exportParameters = @{
                    Cluster     = 'TestCluster'
                    TaskName    = 'TestTask'
                    FilePath    = $testFilePath
                    ErrorAction = 'Stop'
                }

                { Export-StmClusteredScheduledTask @exportParameters } | Should -Throw
            }

            It 'should write error message when file export fails' {
                Mock -CommandName 'Export-ScheduledTask' -MockWith {
                    throw 'Simulated export failure'
                }
                Mock -CommandName 'Write-Error' -MockWith {}

                $testFilePath = 'TestDrive:\FailExport.xml'
                $exportParameters = @{
                    Cluster     = 'TestCluster'
                    TaskName    = 'TestTask'
                    FilePath    = $testFilePath
                    ErrorAction = 'SilentlyContinue'
                }

                try {
                    Export-StmClusteredScheduledTask @exportParameters
                }
                catch {
                    # Expected to throw
                }

                Should -Invoke 'Write-Error' -Times 1 -ParameterFilter {
                    $Message -like "*Failed to export task to file*"
                }
            }
        }
    }
}
