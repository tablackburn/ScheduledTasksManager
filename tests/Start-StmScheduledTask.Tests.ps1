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
    Describe 'Start-StmScheduledTask' {
        BeforeEach {
            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'this-is-a-mock-cim-session'
            }
            Mock -CommandName 'Start-ScheduledTask' -MockWith {
                # Start-ScheduledTask doesn't return anything
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
                $function = Get-Command -Name 'Start-StmScheduledTask'
                $confirmImpact = $function.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments | Where-Object {
                    $_.ArgumentName -eq 'ConfirmImpact'
                }
                $confirmImpact.Argument.Value | Should -Be 'Medium'
            }

            It 'Should support ShouldProcess' {
                $function = Get-Command -Name 'Start-StmScheduledTask'
                $function.Parameters.ContainsKey('WhatIf') | Should -Be $true
                $function.Parameters.ContainsKey('Confirm') | Should -Be $true
            }
        }

        Context 'Basic Functionality' {
            It 'Should start the scheduled task successfully' {
                Start-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                Should -Invoke 'Start-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\'
                }
            }

            It 'Should use specified TaskPath' {
                $startParameters = @{
                    TaskName = 'TestTask1'
                    TaskPath = '\Custom\Path\'
                    Confirm  = $false
                }
                Start-StmScheduledTask @startParameters @commonParameters

                Should -Invoke 'Start-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\Custom\Path\'
                }
            }

            It 'Should use specified ComputerName' {
                $startParameters = @{
                    TaskName     = 'TestTask1'
                    ComputerName = 'Server01'
                    Confirm      = $false
                }
                Start-StmScheduledTask @startParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01'
                }
            }

            It 'Should use provided credentials' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))
                Start-StmScheduledTask -TaskName 'TestTask1' -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should not return any output' {
                $result = Start-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                $result | Should -BeNullOrEmpty
            }
        }

        Context 'Error Handling' {
            It 'Should throw terminating error when Start-ScheduledTask fails' {
                Mock -CommandName 'Start-ScheduledTask' -MockWith {
                    throw 'Start-ScheduledTask failed'
                }

                { Start-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should use New-StmError for error handling' {
                Mock -CommandName 'Start-ScheduledTask' -MockWith {
                    throw 'Test error'
                }
                Mock -CommandName 'New-StmError' -MockWith {
                    return [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new('Test error'),
                        'ScheduledTaskStartFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        'TestTask1'
                    )
                }

                { Start-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'ScheduledTaskStartFailed'
                }
            }
        }

        Context 'CIM Session Management' {
            It 'Should create CIM session with correct parameters' {
                $startParameters = @{
                    TaskName     = 'TestTask1'
                    ComputerName = 'Server01'
                    Confirm      = $false
                }
                Start-StmScheduledTask @startParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01' -and $ErrorAction -eq 'Stop'
                }
            }

            It 'Should pass CIM session to Start-ScheduledTask' {
                Start-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                Should -Invoke 'Start-ScheduledTask' -Times 1
            }
        }

        Context 'Verbose Output' {
            It 'Should write verbose messages during execution' {
                Mock -CommandName 'Write-Verbose' -MockWith {}

                Start-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false -Verbose @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -eq 'Starting Start-StmScheduledTask'
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Starting scheduled task*"
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Completed Start-StmScheduledTask*"
                }
            }
        }

        Context 'WhatIf Support' {
            It 'Should not start task when WhatIf is specified' {
                Start-StmScheduledTask -TaskName 'TestTask1' -WhatIf @commonParameters

                Should -Invoke 'Start-ScheduledTask' -Times 0
            }
        }
    }
}
