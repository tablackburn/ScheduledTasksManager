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
    Describe 'Unregister-StmScheduledTask' {
        BeforeEach {
            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'this-is-a-mock-cim-session'
            }
            Mock -CommandName 'Unregister-ScheduledTask' -MockWith {
                # Unregister-ScheduledTask doesn't return anything
            }
        }

        BeforeAll {
            $script:commonParameters = @{
                WarningAction = 'SilentlyContinue'
                InformationAction = 'SilentlyContinue'
            }
        }

        Context 'Function Attributes' {
            It 'Should have ConfirmImpact set to High' {
                $function = Get-Command -Name 'Unregister-StmScheduledTask'
                $confirmImpact = $function.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments | Where-Object {
                    $_.ArgumentName -eq 'ConfirmImpact'
                }
                $confirmImpact.Argument.Value | Should -Be 'High'
            }

            It 'Should support ShouldProcess' {
                $function = Get-Command -Name 'Unregister-StmScheduledTask'
                $function.Parameters.ContainsKey('WhatIf') | Should -Be $true
                $function.Parameters.ContainsKey('Confirm') | Should -Be $true
            }
        }

        Context 'Basic Functionality' {
            It 'Should unregister the scheduled task successfully' {
                Unregister-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                Should -Invoke 'Unregister-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\'
                }
            }

            It 'Should use specified TaskPath' {
                $unregisterParameters = @{
                    TaskName = 'TestTask1'
                    TaskPath = '\Custom\Path\'
                    Confirm  = $false
                }
                Unregister-StmScheduledTask @unregisterParameters @commonParameters

                Should -Invoke 'Unregister-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\Custom\Path\'
                }
            }

            It 'Should use specified ComputerName' {
                $unregisterParameters = @{
                    TaskName     = 'TestTask1'
                    ComputerName = 'Server01'
                    Confirm      = $false
                }
                Unregister-StmScheduledTask @unregisterParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01'
                }
            }

            It 'Should use provided credentials' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))
                Unregister-StmScheduledTask -TaskName 'TestTask1' -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should not return any output' {
                $result = Unregister-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                $result | Should -BeNullOrEmpty
            }

            It 'Should pass Confirm:$false to underlying cmdlet to avoid double confirmation' {
                Unregister-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                Should -Invoke 'Unregister-ScheduledTask' -Times 1 -ParameterFilter {
                    $Confirm -eq $false
                }
            }
        }

        Context 'Error Handling' {
            It 'Should throw terminating error when Unregister-ScheduledTask fails' {
                Mock -CommandName 'Unregister-ScheduledTask' -MockWith {
                    throw 'Unregister-ScheduledTask failed'
                }

                { Unregister-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should use New-StmError for error handling' {
                Mock -CommandName 'Unregister-ScheduledTask' -MockWith {
                    throw 'Test error'
                }
                Mock -CommandName 'New-StmError' -MockWith {
                    return [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new('Test error'),
                        'ScheduledTaskUnregisterFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        'TestTask1'
                    )
                }

                { Unregister-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'ScheduledTaskUnregisterFailed'
                }
            }
        }

        Context 'CIM Session Management' {
            It 'Should create CIM session with correct parameters' {
                $unregisterParameters = @{
                    TaskName     = 'TestTask1'
                    ComputerName = 'Server01'
                    Confirm      = $false
                }
                Unregister-StmScheduledTask @unregisterParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01' -and $ErrorAction -eq 'Stop'
                }
            }

            It 'Should pass CIM session to Unregister-ScheduledTask' {
                Unregister-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                Should -Invoke 'Unregister-ScheduledTask' -Times 1
            }
        }

        Context 'Verbose Output' {
            It 'Should write verbose messages during execution' {
                Mock -CommandName 'Write-Verbose' -MockWith {}

                Unregister-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false -Verbose @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -eq 'Starting Unregister-StmScheduledTask'
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Unregistering scheduled task*"
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Completed Unregister-StmScheduledTask*"
                }
            }
        }

        Context 'WhatIf Support' {
            It 'Should not unregister task when WhatIf is specified' {
                Unregister-StmScheduledTask -TaskName 'TestTask1' -WhatIf @commonParameters

                Should -Invoke 'Unregister-ScheduledTask' -Times 0
            }
        }
    }
}
