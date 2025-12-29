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
    Describe 'Enable-StmScheduledTask' {
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
                'Ready',
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
            Mock -CommandName 'Enable-ScheduledTask' -MockWith {
                # Enable-ScheduledTask doesn't return anything
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
            It 'Should have ConfirmImpact set to High' {
                $function = Get-Command -Name 'Enable-StmScheduledTask'
                $confirmImpact = $function.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments | Where-Object {
                    $_.ArgumentName -eq 'ConfirmImpact'
                }
                $confirmImpact.Argument.Value | Should -Be 'High'
            }

            It 'Should support ShouldProcess' {
                $function = Get-Command -Name 'Enable-StmScheduledTask'
                $function.Parameters.ContainsKey('WhatIf') | Should -Be $true
                $function.Parameters.ContainsKey('Confirm') | Should -Be $true
            }
        }

        Context 'Basic Functionality' {
            It 'Should enable the scheduled task successfully' {
                $result = Enable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                Should -Invoke 'Enable-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\'
                }
                Should -Invoke 'Get-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\'
                }
            }

            It 'Should use specified TaskPath' {
                $enableParameters = @{
                    TaskName = 'TestTask1'
                    TaskPath = '\Custom\Path\'
                    Confirm  = $false
                }
                Enable-StmScheduledTask @enableParameters @commonParameters

                Should -Invoke 'Enable-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\Custom\Path\'
                }
            }

            It 'Should use specified ComputerName' {
                $enableParameters = @{
                    TaskName     = 'TestTask1'
                    ComputerName = 'Server01'
                    Confirm      = $false
                }
                Enable-StmScheduledTask @enableParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01'
                }
            }

            It 'Should use provided credentials' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))
                Enable-StmScheduledTask -TaskName 'TestTask1' -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should verify task state after enabling' {
                Enable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                Should -Invoke 'Get-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1'
                }
            }
        }

        Context 'PassThru Functionality' {
            It 'Should return task object when PassThru is specified' {
                $result = Enable-StmScheduledTask -TaskName 'TestTask1' -PassThru -Confirm:$false @commonParameters

                $result | Should -Not -BeNullOrEmpty
                $result.TaskName | Should -Be 'TestTask1'
                Should -Invoke 'Enable-ScheduledTask' -Times 1
            }

            It 'Should not return task object when PassThru is not specified' {
                $result = Enable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                $result | Should -BeNullOrEmpty
                Should -Invoke 'Enable-ScheduledTask' -Times 1
            }
        }

        Context 'Error Handling' {
            It 'Should throw terminating error when Enable-ScheduledTask fails' {
                Mock -CommandName 'Enable-ScheduledTask' -MockWith {
                    throw 'Enable-ScheduledTask failed'
                }

                { Enable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should throw terminating error when task verification fails' {
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    throw 'Get-ScheduledTask failed'
                }

                { Enable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should throw error when task is not enabled successfully' {
                $cimInstanceParameters = @{
                    TypeName     = 'Microsoft.Management.Infrastructure.CimInstance'
                    ArgumentList = @(
                        'MSFT_ScheduledTask',
                        'Root/Microsoft/Windows/TaskScheduler'
                    )
                }
                $mockTaskStillDisabled = New-Object @cimInstanceParameters
                $mockTaskNameProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                    'TaskName',
                    'TestTask1',
                    [Microsoft.Management.Infrastructure.CimType]::String,
                    [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                        [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                )
                $mockStateProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                    'State',
                    'Disabled',  # Still disabled
                    [Microsoft.Management.Infrastructure.CimType]::String,
                    [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                        [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                )
                $mockTaskStillDisabled.CimInstanceProperties.Add($mockTaskNameProperty)
                $mockTaskStillDisabled.CimInstanceProperties.Add($mockStateProperty)

                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    return $mockTaskStillDisabled
                }

                { Enable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should use New-StmError for error handling' {
                Mock -CommandName 'Enable-ScheduledTask' -MockWith {
                    throw 'Test error'
                }
                Mock -CommandName 'New-StmError' -MockWith {
                    return [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new('Test error'),
                        'ScheduledTaskEnableFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        'TestTask1'
                    )
                }

                { Enable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'ScheduledTaskEnableFailed'
                }
            }
        }

        Context 'CIM Session Management' {
            It 'Should create CIM session with correct parameters' {
                $enableParameters = @{
                    TaskName     = 'TestTask1'
                    ComputerName = 'Server01'
                    Confirm      = $false
                }
                Enable-StmScheduledTask @enableParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01' -and $ErrorAction -eq 'Stop'
                }
            }

            It 'Should pass CIM session to scheduled task cmdlets' {
                Enable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters

                Should -Invoke 'Enable-ScheduledTask' -Times 1
                Should -Invoke 'Get-ScheduledTask' -Times 1
            }
        }

        Context 'Verbose Output' {
            It 'Should write verbose messages during execution' {
                Mock -CommandName 'Write-Verbose' -MockWith {}

                Enable-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false -Verbose @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -eq 'Starting Enable-StmScheduledTask'
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Enabling scheduled task*"
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Completed Enable-StmScheduledTask*"
                }
            }
        }
    }
}
