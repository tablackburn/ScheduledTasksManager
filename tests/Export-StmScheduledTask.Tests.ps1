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
    Describe 'Export-StmScheduledTask' {
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
            Mock -CommandName 'Get-ScheduledTask' -MockWith {
                return $mockTask
            }
            Mock -CommandName 'Export-ScheduledTask' -MockWith {
                return $script:mockXml
            }
        }

        BeforeAll {
            $script:commonParameters = @{
                WarningAction = 'SilentlyContinue'
                InformationAction = 'SilentlyContinue'
            }
        }

        Context 'Function Attributes' {
            It 'Should not have SupportsShouldProcess' {
                $function = Get-Command -Name 'Export-StmScheduledTask'
                $function.Parameters.ContainsKey('WhatIf') | Should -Be $false
                $function.Parameters.ContainsKey('Confirm') | Should -Be $false
            }

            It 'Should have OutputType of string' {
                $function = Get-Command -Name 'Export-StmScheduledTask'
                $outputType = $function.OutputType | Where-Object { $_.Type -eq [string] }
                $outputType | Should -Not -BeNullOrEmpty
            }
        }

        Context 'Basic Functionality - Return XML' {
            It 'Should return XML when FilePath is not specified' {
                $result = Export-StmScheduledTask -TaskName 'TestTask1' @commonParameters

                $result | Should -Be $script:mockXml
                Should -Invoke 'Export-ScheduledTask' -Times 1
            }

            It 'Should use specified TaskPath' {
                Export-StmScheduledTask -TaskName 'TestTask1' -TaskPath '\Custom\Path\' @commonParameters

                Should -Invoke 'Get-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\Custom\Path\'
                }
                Should -Invoke 'Export-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\Custom\Path\'
                }
            }

            It 'Should use specified ComputerName' {
                Export-StmScheduledTask -TaskName 'TestTask1' -ComputerName 'Server01' @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01'
                }
            }

            It 'Should use provided credentials' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))
                Export-StmScheduledTask -TaskName 'TestTask1' -Credential $credential @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }
        }

        Context 'File Output' {
            It 'Should save to file when FilePath is specified' {
                $testFilePath = 'TestDrive:\task.xml'
                Export-StmScheduledTask -TaskName 'TestTask1' -FilePath $testFilePath @commonParameters

                $testFilePath | Should -Exist
            }

            It 'Should create directory if it does not exist' {
                $testFilePath = 'TestDrive:\NewFolder\task.xml'
                { Export-StmScheduledTask -TaskName 'TestTask1' -FilePath $testFilePath @commonParameters } | Should -Not -Throw

                $testFilePath | Should -Exist
            }

            It 'Should not return output when FilePath is specified' {
                $testFilePath = 'TestDrive:\task2.xml'
                $result = Export-StmScheduledTask -TaskName 'TestTask1' -FilePath $testFilePath @commonParameters

                $result | Should -BeNullOrEmpty
            }
        }

        Context 'Error Handling' {
            It 'Should throw terminating error when Get-ScheduledTask fails' {
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    throw 'Get-ScheduledTask failed'
                }

                { Export-StmScheduledTask -TaskName 'TestTask1' @commonParameters } | Should -Throw
            }

            It 'Should throw terminating error when Export-ScheduledTask fails' {
                Mock -CommandName 'Export-ScheduledTask' -MockWith {
                    throw 'Export-ScheduledTask failed'
                }

                { Export-StmScheduledTask -TaskName 'TestTask1' @commonParameters } | Should -Throw
            }

            It 'Should use New-StmError for error handling' {
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    throw 'Test error'
                }
                Mock -CommandName 'New-StmError' -MockWith {
                    return [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new('Test error'),
                        'ScheduledTaskExportFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        'TestTask1'
                    )
                }

                { Export-StmScheduledTask -TaskName 'TestTask1' @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'ScheduledTaskExportFailed'
                }
            }
        }

        Context 'CIM Session Management' {
            It 'Should create CIM session with correct parameters' {
                Export-StmScheduledTask -TaskName 'TestTask1' -ComputerName 'Server01' @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01' -and $ErrorAction -eq 'Stop'
                }
            }

            It 'Should pass CIM session to scheduled task cmdlets' {
                Export-StmScheduledTask -TaskName 'TestTask1' @commonParameters

                Should -Invoke 'Get-ScheduledTask' -Times 1
                Should -Invoke 'Export-ScheduledTask' -Times 1
            }
        }

        Context 'Verbose Output' {
            It 'Should write verbose messages during execution' {
                Mock -CommandName 'Write-Verbose' -MockWith {}

                Export-StmScheduledTask -TaskName 'TestTask1' -Verbose @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -eq 'Starting Export-StmScheduledTask'
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Exporting scheduled task*"
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Completed Export-StmScheduledTask*"
                }
            }
        }
    }
}
