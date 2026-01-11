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
    Describe 'Disable-StmScheduledTask' {
        BeforeEach {
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
            $mockURIProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                'URI',
                '\TestTask1',
                [Microsoft.Management.Infrastructure.CimType]::String,
                [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                    [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
            )
            $mockStateProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                'State',
                'Disabled',
                [Microsoft.Management.Infrastructure.CimType]::String,
                [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                    [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
            )
            $mockTask.CimInstanceProperties.Add($mockTaskNameProperty)
            $mockTask.CimInstanceProperties.Add($mockURIProperty)
            $mockTask.CimInstanceProperties.Add($mockStateProperty)

            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'this-is-a-mock-cim-session'
            }
            Mock -CommandName 'Disable-ScheduledTask' -MockWith {
                # Disable-ScheduledTask doesn't return anything
            }
            Mock -CommandName 'Get-ScheduledTask' -MockWith {
                return $mockTask
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
                $function = Get-Command -Name 'Disable-StmScheduledTask'
                $confirmImpact = $function.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments | Where-Object {
                    $_.ArgumentName -eq 'ConfirmImpact'
                }
                $confirmImpact.Argument.Value | Should -Be 'Medium'
            }

            It 'Should support ShouldProcess' {
                $function = Get-Command -Name 'Disable-StmScheduledTask'
                $function.Parameters.ContainsKey('WhatIf') | Should -Be $true
                $function.Parameters.ContainsKey('Confirm') | Should -Be $true
            }
        }

        Context 'Basic Functionality' {
            It 'Should disable the scheduled task successfully' {
                $result = Disable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                Should -Invoke 'Disable-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\'
                }
                Should -Invoke 'Get-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\'
                }
            }

            It 'Should use specified TaskPath' {
                $disableParameters = @{
                    TaskName = 'TestTask1'
                    TaskPath = '\Custom\Path\'
                    Confirm  = $false
                }
                Disable-StmScheduledTask @disableParameters @commonParameters

                Should -Invoke 'Disable-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\Custom\Path\'
                }
            }

            It 'Should use specified ComputerName' {
                $disableParameters = @{
                    TaskName     = 'TestTask1'
                    ComputerName = 'Server01'
                    Confirm      = $false
                }
                Disable-StmScheduledTask @disableParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01'
                }
            }

            It 'Should use provided credentials' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))
                Disable-StmScheduledTask -TaskName 'TestTask1' -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should verify task state after disabling' {
                Disable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                Should -Invoke 'Get-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1'
                }
            }
        }

        Context 'PassThru Functionality' {
            It 'Should return task object when PassThru is specified' {
                $result = Disable-StmScheduledTask -TaskName 'TestTask1' -PassThru -Confirm:$false @commonParameters

                $result | Should -Not -BeNullOrEmpty
                $result.TaskName | Should -Be 'TestTask1'
                Should -Invoke 'Disable-ScheduledTask' -Times 1
            }

            It 'Should not return task object when PassThru is not specified' {
                $result = Disable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                $result | Should -BeNullOrEmpty
                Should -Invoke 'Disable-ScheduledTask' -Times 1
            }
        }

        Context 'Error Handling' {
            It 'Should throw terminating error when Disable-ScheduledTask fails' {
                Mock -CommandName 'Disable-ScheduledTask' -MockWith {
                    throw 'Disable-ScheduledTask failed'
                }

                { Disable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should throw terminating error when task verification fails' {
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    throw 'Get-ScheduledTask failed'
                }

                { Disable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should throw error when task is not disabled successfully' {
                $cimInstanceParameters = @{
                    TypeName     = 'Microsoft.Management.Infrastructure.CimInstance'
                    ArgumentList = @(
                        'MSFT_ScheduledTask',
                        'Root/Microsoft/Windows/TaskScheduler'
                    )
                }
                $mockTaskStillEnabled = New-Object @cimInstanceParameters
                $mockTaskNameProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                    'TaskName',
                    'TestTask1',
                    [Microsoft.Management.Infrastructure.CimType]::String,
                    [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                        [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                )
                $mockStateProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                    'State',
                    'Ready',  # Still enabled
                    [Microsoft.Management.Infrastructure.CimType]::String,
                    [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                        [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                )
                $mockTaskStillEnabled.CimInstanceProperties.Add($mockTaskNameProperty)
                $mockTaskStillEnabled.CimInstanceProperties.Add($mockStateProperty)

                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    return $mockTaskStillEnabled
                }

                { Disable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should use New-StmError for error handling' {
                Mock -CommandName 'Disable-ScheduledTask' -MockWith {
                    throw 'Test error'
                }
                Mock -CommandName 'New-StmError' -MockWith {
                    return [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new('Test error'),
                        'ScheduledTaskDisableFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        'TestTask1'
                    )
                }

                { Disable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'ScheduledTaskDisableFailed'
                }
            }
        }

        Context 'CIM Session Management' {
            It 'Should create CIM session with correct parameters' {
                $disableParameters = @{
                    TaskName     = 'TestTask1'
                    ComputerName = 'Server01'
                    Confirm      = $false
                }
                Disable-StmScheduledTask @disableParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01' -and $ErrorAction -eq 'Stop'
                }
            }

            It 'Should pass CIM session to scheduled task cmdlets' {
                Disable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                Should -Invoke 'Disable-ScheduledTask' -Times 1
                Should -Invoke 'Get-ScheduledTask' -Times 1
            }
        }

        Context 'Verbose Output' {
            It 'Should write verbose messages during execution' {
                Mock -CommandName 'Write-Verbose' -MockWith {}

                Disable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false -Verbose @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -eq 'Starting Disable-StmScheduledTask'
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Disabling scheduled task*"
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Completed Disable-StmScheduledTask*"
                }
            }
        }

        Context 'WhatIf Support' {
            It 'Should not disable task when WhatIf is specified' {
                Disable-StmScheduledTask -TaskName 'TestTask1' -WhatIf @commonParameters

                Should -Invoke 'Disable-ScheduledTask' -Times 0
            }

            It 'Should write verbose cancellation message when WhatIf is specified' {
                $verboseOutput = Disable-StmScheduledTask -TaskName 'TestTask1' -WhatIf -Verbose @commonParameters 4>&1 |
                    ForEach-Object { $_.ToString() }

                $verboseOutput | Should -Contain 'Operation cancelled by user.'
            }
        }
    }
}
