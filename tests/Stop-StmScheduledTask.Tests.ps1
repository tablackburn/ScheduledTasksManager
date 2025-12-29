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
    Describe 'Stop-StmScheduledTask' {
        BeforeEach {
            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'this-is-a-mock-cim-session'
            }
            Mock -CommandName 'Stop-ScheduledTask' -MockWith {
                # Stop-ScheduledTask doesn't return anything
            }
        }

        BeforeAll {
            $script:commonParameters = @{
                WarningAction = 'SilentlyContinue'
                InformationAction = 'SilentlyContinue'
            }
        }

        Context 'Function Attributes' {
            It 'Should have ConfirmImpact set to Medium' {
                $function = Get-Command -Name 'Stop-StmScheduledTask'
                $confirmImpact = $function.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments | Where-Object {
                    $_.ArgumentName -eq 'ConfirmImpact'
                }
                $confirmImpact.Argument.Value | Should -Be 'Medium'
            }

            It 'Should support ShouldProcess' {
                $function = Get-Command -Name 'Stop-StmScheduledTask'
                $function.Parameters.ContainsKey('WhatIf') | Should -Be $true
                $function.Parameters.ContainsKey('Confirm') | Should -Be $true
            }
        }

        Context 'Basic Functionality' {
            It 'Should stop the scheduled task successfully' {
                Stop-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                Should -Invoke 'Stop-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\'
                }
            }

            It 'Should use specified TaskPath' {
                $stopParameters = @{
                    TaskName = 'TestTask1'
                    TaskPath = '\Custom\Path\'
                    Confirm  = $false
                }
                Stop-StmScheduledTask @stopParameters @commonParameters

                Should -Invoke 'Stop-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\Custom\Path\'
                }
            }

            It 'Should use specified ComputerName' {
                $stopParameters = @{
                    TaskName     = 'TestTask1'
                    ComputerName = 'Server01'
                    Confirm      = $false
                }
                Stop-StmScheduledTask @stopParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01'
                }
            }

            It 'Should use provided credentials' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))
                Stop-StmScheduledTask -TaskName 'TestTask1' -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should not return any output' {
                $result = Stop-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                $result | Should -BeNullOrEmpty
            }
        }

        Context 'Error Handling' {
            It 'Should throw terminating error when Stop-ScheduledTask fails' {
                Mock -CommandName 'Stop-ScheduledTask' -MockWith {
                    throw 'Stop-ScheduledTask failed'
                }

                { Stop-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should use New-StmError for error handling' {
                Mock -CommandName 'Stop-ScheduledTask' -MockWith {
                    throw 'Test error'
                }
                Mock -CommandName 'New-StmError' -MockWith {
                    return [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new('Test error'),
                        'ScheduledTaskStopFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        'TestTask1'
                    )
                }

                { Stop-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'ScheduledTaskStopFailed'
                }
            }
        }

        Context 'CIM Session Management' {
            It 'Should create CIM session with correct parameters' {
                $stopParameters = @{
                    TaskName     = 'TestTask1'
                    ComputerName = 'Server01'
                    Confirm      = $false
                }
                Stop-StmScheduledTask @stopParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01' -and $ErrorAction -eq 'Stop'
                }
            }

            It 'Should pass CIM session to Stop-ScheduledTask' {
                Stop-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                Should -Invoke 'Stop-ScheduledTask' -Times 1
            }
        }

        Context 'Verbose Output' {
            It 'Should write verbose messages during execution' {
                Mock -CommandName 'Write-Verbose' -MockWith {}

                Stop-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false -Verbose @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -eq 'Starting Stop-StmScheduledTask'
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Stopping scheduled task*"
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Completed Stop-StmScheduledTask*"
                }
            }
        }

        Context 'WhatIf Support' {
            It 'Should not stop task when WhatIf is specified' {
                Stop-StmScheduledTask -TaskName 'TestTask1' -WhatIf @commonParameters

                Should -Invoke 'Stop-ScheduledTask' -Times 0
            }
        }
    }
}
