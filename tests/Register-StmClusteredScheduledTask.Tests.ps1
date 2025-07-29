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
    Describe 'Register-StmClusteredScheduledTask' {
        BeforeEach {
            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'MockedCimSession'
            }

            Mock -CommandName 'Register-ClusteredScheduledTask' -MockWith {
                return @{
                    TaskName = 'MockedTaskName'
                }
            }

            $script:xmlFromFileContent = '<TaskXmlFile></TaskXmlFile>'
            Mock -CommandName 'Register-ClusteredScheduledTask' -MockWith {
                return [PSCustomObject]@{
                    TaskName = 'MockedTaskNameFromXmlFile'
                }
            } -ParameterFilter {
                # Check if the XML content matches the mocked file content
                # Use -match because Get-Content returns a string with newlines
                $Xml -match $script:xmlFromFileContent
            }
        }

        It 'Should register a clustered scheduled task with XML string' {
            $parameters = @{
                TaskName   = 'TestTask'
                Cluster    = 'TestCluster'
                Xml        = '<Task></Task>'
                TaskType   = 'AnyNode'
            }
            $result = Register-StmClusteredScheduledTask @parameters
            $result.TaskName | Should -Be 'MockedTaskName'
        }

        It 'Should register a clustered scheduled task with XML file' {
            $xmlFilePath = Join-Path -Path 'TestDrive:\' -ChildPath 'TestXml.xml'
            Set-Content -Path $xmlFilePath -Value $script:xmlFromFileContent

            $parameters = @{
                TaskName   = 'TestTask'
                Cluster    = 'TestCluster'
                XmlPath    = $xmlFilePath
                TaskType   = 'AnyNode'
            }
            $result = Register-StmClusteredScheduledTask @parameters
            $result.TaskName | Should -Be 'MockedTaskNameFromXmlFile'
        }
    }
}
