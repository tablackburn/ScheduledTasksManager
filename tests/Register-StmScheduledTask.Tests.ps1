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
    Describe 'Register-StmScheduledTask' {
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
            Mock -CommandName 'Get-TaskNameFromXml' -MockWith {
                return 'TestTask1'
            }
            Mock -CommandName 'Test-Path' -MockWith { return $true }
            Mock -CommandName 'Get-Content' -MockWith { return $script:mockXml }
        }

        BeforeAll {
            $script:commonParameters = @{
                WarningAction = 'SilentlyContinue'
                InformationAction = 'SilentlyContinue'
            }
        }

        Context 'Function Attributes' {
            It 'Should have ConfirmImpact set to Medium' {
                $function = Get-Command -Name 'Register-StmScheduledTask'
                $confirmImpact = $function.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments | Where-Object {
                    $_.ArgumentName -eq 'ConfirmImpact'
                }
                $confirmImpact.Argument.Value | Should -Be 'Medium'
            }

            It 'Should support ShouldProcess' {
                $function = Get-Command -Name 'Register-StmScheduledTask'
                $function.Parameters.ContainsKey('WhatIf') | Should -Be $true
                $function.Parameters.ContainsKey('Confirm') | Should -Be $true
            }

            It 'Should have XmlString as default parameter set' {
                $function = Get-Command -Name 'Register-StmScheduledTask'
                $defaultParameterSet = $function.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments | Where-Object {
                    $_.ArgumentName -eq 'DefaultParameterSetName'
                }
                $defaultParameterSet.Argument.Value | Should -Be 'XmlString'
            }
        }

        Context 'Basic Functionality - XML String' {
            It 'Should register the task with provided XML' {
                $result = Register-StmScheduledTask -TaskName 'TestTask1' -Xml $script:mockXml -Confirm:$false @commonParameters

                $result | Should -Not -BeNullOrEmpty
                $result.TaskName | Should -Be 'TestTask1'
                Should -Invoke 'Register-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\'
                }
            }

            It 'Should use specified TaskPath' {
                Register-StmScheduledTask -TaskName 'TestTask1' -TaskPath '\Custom\Path\' -Xml $script:mockXml -Confirm:$false @commonParameters

                Should -Invoke 'Register-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\Custom\Path\'
                }
            }

            It 'Should use specified ComputerName' {
                Register-StmScheduledTask -TaskName 'TestTask1' -Xml $script:mockXml -ComputerName 'Server01' -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01'
                }
            }

            It 'Should use provided credentials' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))
                Register-StmScheduledTask -TaskName 'TestTask1' -Xml $script:mockXml -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should extract task name from XML if not provided' {
                Register-StmScheduledTask -Xml $script:mockXml -Confirm:$false @commonParameters

                Should -Invoke 'Get-TaskNameFromXml' -Times 1
                Should -Invoke 'Register-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1'
                }
            }
        }

        Context 'Basic Functionality - XML File' {
            It 'Should load XML from file' {
                Register-StmScheduledTask -TaskName 'TestTask1' -XmlPath 'C:\Temp\task.xml' -Confirm:$false @commonParameters

                Should -Invoke 'Test-Path' -Times 1 -ParameterFilter {
                    $Path -eq 'C:\Temp\task.xml'
                }
                Should -Invoke 'Get-Content' -Times 1 -ParameterFilter {
                    $Path -eq 'C:\Temp\task.xml'
                }
                Should -Invoke 'Register-ScheduledTask' -Times 1
            }

            It 'Should throw if XML file does not exist' {
                Mock -CommandName 'Test-Path' -MockWith { return $false }

                { Register-StmScheduledTask -TaskName 'TestTask1' -XmlPath 'C:\Temp\nonexistent.xml' -Confirm:$false @commonParameters } | Should -Throw
            }
        }

        Context 'Error Handling' {
            It 'Should throw terminating error when Register-ScheduledTask fails' {
                Mock -CommandName 'Register-ScheduledTask' -MockWith {
                    throw 'Register-ScheduledTask failed'
                }

                { Register-StmScheduledTask -TaskName 'TestTask1' -Xml $script:mockXml -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should use New-StmError for error handling' {
                Mock -CommandName 'Register-ScheduledTask' -MockWith {
                    throw 'Test error'
                }
                Mock -CommandName 'New-StmError' -MockWith {
                    return [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new('Test error'),
                        'ScheduledTaskRegisterFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        'TestTask1'
                    )
                }

                { Register-StmScheduledTask -TaskName 'TestTask1' -Xml $script:mockXml -Confirm:$false @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'ScheduledTaskRegisterFailed'
                }
            }
        }

        Context 'CIM Session Management' {
            It 'Should create CIM session with correct parameters' {
                Register-StmScheduledTask -TaskName 'TestTask1' -Xml $script:mockXml -ComputerName 'Server01' -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01' -and $ErrorAction -eq 'Stop'
                }
            }
        }

        Context 'Verbose Output' {
            It 'Should write verbose messages during execution' {
                Mock -CommandName 'Write-Verbose' -MockWith {}

                Register-StmScheduledTask -TaskName 'TestTask1' -Xml $script:mockXml -Confirm:$false -Verbose @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -eq 'Starting Register-StmScheduledTask'
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Registering scheduled task*"
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Completed Register-StmScheduledTask*"
                }
            }
        }

        Context 'WhatIf Support' {
            It 'Should not register task when WhatIf is specified' {
                Register-StmScheduledTask -TaskName 'TestTask1' -Xml $script:mockXml -WhatIf @commonParameters

                Should -Invoke 'Register-ScheduledTask' -Times 0
            }
        }
    }
}
