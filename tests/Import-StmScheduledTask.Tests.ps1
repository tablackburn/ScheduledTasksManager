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
    Describe 'Import-StmScheduledTask' {
        BeforeEach {
            $script:mockXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\TestTask1</URI>
  </RegistrationInfo>
</Task>
'@

            $mockTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                'MSFT_ScheduledTask',
                'Root/Microsoft/Windows/TaskScheduler'
            )
            $mockTaskNameProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                'TaskName',
                'TestTask1',
                [Microsoft.Management.Infrastructure.CimType]::String,
                [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                    [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
            )
            $mockTask.CimInstanceProperties.Add($mockTaskNameProperty)

            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'this-is-a-mock-cim-session'
            }
            Mock -CommandName 'Register-ScheduledTask' -MockWith {
                return $mockTask
            }
            Mock -CommandName 'Unregister-ScheduledTask' -MockWith {}
            Mock -CommandName 'Get-ScheduledTask' -MockWith {
                throw 'Task not found'
            }
            Mock -CommandName 'Get-TaskNameFromXml' -MockWith {
                return 'TestTask1'
            }
            Mock -CommandName 'Test-Path' -MockWith { return $true } -ParameterFilter { $Path -notlike '*Directory*' }
            Mock -CommandName 'Get-Content' -MockWith { return $script:mockXml }
        }

        BeforeAll {
            $script:commonParameters = @{
                WarningAction = 'SilentlyContinue'
                InformationAction = 'SilentlyContinue'
            }
        }

        Context 'Function Attributes' {
            It 'Should support ShouldProcess' {
                $function = Get-Command -Name 'Import-StmScheduledTask'
                $function.Parameters.ContainsKey('WhatIf') | Should -Be $true
                $function.Parameters.ContainsKey('Confirm') | Should -Be $true
            }

            It 'Should have XmlFile as default parameter set' {
                $function = Get-Command -Name 'Import-StmScheduledTask'
                $defaultParameterSet = $function.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments | Where-Object {
                    $_.ArgumentName -eq 'DefaultParameterSetName'
                }
                $defaultParameterSet.Argument.Value | Should -Be 'XmlFile'
            }
        }

        Context 'Basic Functionality - XML String' {
            It 'Should import the task with provided XML' {
                $result = Import-StmScheduledTask -Xml $script:mockXml -Confirm:$false @commonParameters

                $result | Should -Not -BeNullOrEmpty
                $result.TaskName | Should -Be 'TestTask1'
                Should -Invoke 'Register-ScheduledTask' -Times 1
            }

            It 'Should use specified TaskPath' {
                Import-StmScheduledTask -Xml $script:mockXml -TaskPath '\Custom\Path\' -Confirm:$false @commonParameters

                Should -Invoke 'Register-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskPath -eq '\Custom\Path\'
                }
            }

            It 'Should use specified ComputerName' {
                Import-StmScheduledTask -Xml $script:mockXml -ComputerName 'Server01' -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01'
                }
            }

            It 'Should extract task name from XML if not provided' {
                Import-StmScheduledTask -Xml $script:mockXml -Confirm:$false @commonParameters

                Should -Invoke 'Get-TaskNameFromXml' -Times 1
            }

            It 'Should use provided TaskName instead of extracting from XML' {
                Import-StmScheduledTask -Xml $script:mockXml -TaskName 'CustomName' -Confirm:$false @commonParameters

                Should -Invoke 'Register-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'CustomName'
                }
            }
        }

        Context 'Basic Functionality - XML File' {
            It 'Should load XML from file' {
                Import-StmScheduledTask -XmlPath 'C:\Temp\task.xml' -Confirm:$false @commonParameters

                Should -Invoke 'Get-Content' -Times 1 -ParameterFilter {
                    $Path -eq 'C:\Temp\task.xml'
                }
                Should -Invoke 'Register-ScheduledTask' -Times 1
            }

            It 'Should throw if XML file does not exist' {
                Mock -CommandName 'Test-Path' -MockWith { return $false } -ParameterFilter { $Path -eq 'C:\Temp\nonexistent.xml' }

                { Import-StmScheduledTask -XmlPath 'C:\Temp\nonexistent.xml' -Confirm:$false @commonParameters } | Should -Throw
            }
        }

        Context 'Force Parameter' {
            BeforeEach {
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    $mockTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                        'MSFT_ScheduledTask',
                        'Root/Microsoft/Windows/TaskScheduler'
                    )
                    $mockTaskNameProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                        'TaskName',
                        'TestTask1',
                        [Microsoft.Management.Infrastructure.CimType]::String,
                        [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                            [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                    )
                    $mockTask.CimInstanceProperties.Add($mockTaskNameProperty)
                    return $mockTask
                }
            }

            It 'Should throw when task exists and Force is not specified' {
                { Import-StmScheduledTask -Xml $script:mockXml -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should unregister existing task and import new one when Force is specified' {
                Import-StmScheduledTask -Xml $script:mockXml -Force -Confirm:$false @commonParameters

                Should -Invoke 'Unregister-ScheduledTask' -Times 1
                Should -Invoke 'Register-ScheduledTask' -Times 1
            }
        }

        Context 'Directory Import' {
            BeforeEach {
                Mock -CommandName 'Test-Path' -MockWith { return $true } -ParameterFilter { $PathType -eq 'Container' }
                Mock -CommandName 'Get-ChildItem' -MockWith {
                    return @(
                        [PSCustomObject]@{ Name = 'task1.xml'; FullName = 'C:\Tasks\task1.xml' }
                        [PSCustomObject]@{ Name = 'task2.xml'; FullName = 'C:\Tasks\task2.xml' }
                    )
                }
                Mock -CommandName 'Write-Progress' -MockWith {}
            }

            It 'Should process all XML files in directory' {
                $result = Import-StmScheduledTask -DirectoryPath 'C:\Tasks' -Confirm:$false @commonParameters

                $result.TotalFiles | Should -Be 2
                Should -Invoke 'Get-ChildItem' -Times 1 -ParameterFilter {
                    $Path -eq 'C:\Tasks' -and $Filter -eq '*.xml'
                }
            }

            It 'Should not allow TaskName with DirectoryPath' {
                { Import-StmScheduledTask -DirectoryPath 'C:\Tasks' -TaskName 'Invalid' -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should return summary object for directory import' {
                $result = Import-StmScheduledTask -DirectoryPath 'C:\Tasks' -Confirm:$false @commonParameters

                $result.PSObject.Properties.Name | Should -Contain 'TotalFiles'
                $result.PSObject.Properties.Name | Should -Contain 'SuccessCount'
                $result.PSObject.Properties.Name | Should -Contain 'FailureCount'
                $result.PSObject.Properties.Name | Should -Contain 'ImportedTasks'
                $result.PSObject.Properties.Name | Should -Contain 'FailedTasks'
            }

            It 'Should show progress during directory import' {
                Import-StmScheduledTask -DirectoryPath 'C:\Tasks' -Confirm:$false @commonParameters

                Should -Invoke 'Write-Progress' -Times 3  # 2 files + 1 completed
            }
        }

        Context 'Error Handling' {
            It 'Should throw terminating error when Register-ScheduledTask fails' {
                Mock -CommandName 'Register-ScheduledTask' -MockWith {
                    throw 'Register-ScheduledTask failed'
                }

                { Import-StmScheduledTask -Xml $script:mockXml -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should use New-StmError for error handling' {
                Mock -CommandName 'Register-ScheduledTask' -MockWith {
                    throw 'Test error'
                }
                Mock -CommandName 'New-StmError' -MockWith {
                    return [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new('Test error'),
                        'TaskRegistrationFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        'TestTask1'
                    )
                }

                { Import-StmScheduledTask -Xml $script:mockXml -Confirm:$false @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'TaskRegistrationFailed'
                }
            }
        }

        Context 'Verbose Output' {
            It 'Should write verbose messages during execution' {
                Mock -CommandName 'Write-Verbose' -MockWith {}

                Import-StmScheduledTask -Xml $script:mockXml -Confirm:$false -Verbose @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Starting Import-StmScheduledTask*"
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Completed Import-StmScheduledTask*"
                }
            }
        }

        Context 'WhatIf Support' {
            It 'Should not import task when WhatIf is specified' {
                Import-StmScheduledTask -Xml $script:mockXml -WhatIf @commonParameters

                Should -Invoke 'Register-ScheduledTask' -Times 0
            }
        }
    }
}
