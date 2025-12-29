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
    Describe 'Wait-StmScheduledTask' {
        BeforeEach {
            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'this-is-a-mock-cim-session'
            }
            Mock -CommandName 'Start-Sleep' -MockWith {
                # Don't actually sleep in tests
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
                $function = Get-Command -Name 'Wait-StmScheduledTask'
                $function.Parameters.ContainsKey('WhatIf') | Should -Be $false
                $function.Parameters.ContainsKey('Confirm') | Should -Be $false
            }

            It 'Should have OutputType of bool' {
                $function = Get-Command -Name 'Wait-StmScheduledTask'
                $outputType = $function.OutputType | Where-Object { $_.Type -eq [bool] }
                $outputType | Should -Not -BeNullOrEmpty
            }
        }

        Context 'Basic Functionality - Task Not Running' {
            BeforeEach {
                $mockTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                    'MSFT_ScheduledTask',
                    'Root/Microsoft/Windows/TaskScheduler'
                )
                $mockStateProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                    'State',
                    'Ready',
                    [Microsoft.Management.Infrastructure.CimType]::String,
                    [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                        [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                )
                $mockTask.CimInstanceProperties.Add($mockStateProperty)

                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    return $mockTask
                }
            }

            It 'Should return true immediately when task is not running' {
                $result = Wait-StmScheduledTask -TaskName 'TestTask1' @commonParameters

                $result | Should -Be $true
                Should -Invoke 'Get-ScheduledTask' -Times 1
                Should -Invoke 'Start-Sleep' -Times 0
            }

            It 'Should use specified TaskPath' {
                Wait-StmScheduledTask -TaskName 'TestTask1' -TaskPath '\Custom\Path\' @commonParameters

                Should -Invoke 'Get-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\Custom\Path\'
                }
            }

            It 'Should use specified ComputerName' {
                Wait-StmScheduledTask -TaskName 'TestTask1' -ComputerName 'Server01' @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01'
                }
            }

            It 'Should use provided credentials' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))
                Wait-StmScheduledTask -TaskName 'TestTask1' -Credential $credential @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }
        }

        Context 'Basic Functionality - Task Running Then Completes' {
            It 'Should poll until task completes and return true' {
                $script:callCount = 0
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    $script:callCount++
                    $mockTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                        'MSFT_ScheduledTask',
                        'Root/Microsoft/Windows/TaskScheduler'
                    )
                    # First 2 calls return Running, then Ready
                    $state = if ($script:callCount -le 2) { 'Running' } else { 'Ready' }
                    $mockStateProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                        'State',
                        $state,
                        [Microsoft.Management.Infrastructure.CimType]::String,
                        [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                            [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                    )
                    $mockTask.CimInstanceProperties.Add($mockStateProperty)
                    return $mockTask
                }

                $result = Wait-StmScheduledTask -TaskName 'TestTask1' -PollingIntervalSeconds 1 @commonParameters

                $result | Should -Be $true
                Should -Invoke 'Get-ScheduledTask' -Times 3
                Should -Invoke 'Start-Sleep' -Times 2
            }
        }

        Context 'Timeout Behavior' {
            It 'Should return false when timeout is reached' {
                $mockTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                    'MSFT_ScheduledTask',
                    'Root/Microsoft/Windows/TaskScheduler'
                )
                $mockStateProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                    'State',
                    'Running',
                    [Microsoft.Management.Infrastructure.CimType]::String,
                    [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                        [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                )
                $mockTask.CimInstanceProperties.Add($mockStateProperty)

                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    return $mockTask
                }

                # Use a very short timeout to test timeout behavior
                $result = Wait-StmScheduledTask -TaskName 'TestTask1' -TimeoutSeconds 1 -PollingIntervalSeconds 1 @commonParameters

                $result | Should -Be $false
            }
        }

        Context 'Parameter Validation' {
            It 'Should use default polling interval of 5 seconds' {
                $function = Get-Command -Name 'Wait-StmScheduledTask'
                $param = $function.Parameters['PollingIntervalSeconds']
                $defaultValue = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.PSDefaultValueAttribute] }
                # Check if parameter has a default value in the function definition
                $function.ScriptBlock.ToString() | Should -Match 'PollingIntervalSeconds = 5'
            }

            It 'Should use default timeout of 300 seconds' {
                $function = Get-Command -Name 'Wait-StmScheduledTask'
                $function.ScriptBlock.ToString() | Should -Match 'TimeoutSeconds = 300'
            }

            It 'Should require PollingIntervalSeconds to be at least 1' {
                { Wait-StmScheduledTask -TaskName 'TestTask1' -PollingIntervalSeconds 0 } | Should -Throw
            }

            It 'Should require TimeoutSeconds to be at least 1' {
                { Wait-StmScheduledTask -TaskName 'TestTask1' -TimeoutSeconds 0 } | Should -Throw
            }
        }

        Context 'Error Handling' {
            It 'Should throw terminating error when Get-ScheduledTask fails' {
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    throw 'Get-ScheduledTask failed'
                }

                { Wait-StmScheduledTask -TaskName 'TestTask1' @commonParameters } | Should -Throw
            }

            It 'Should use New-StmError for error handling' {
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    throw 'Test error'
                }
                Mock -CommandName 'New-StmError' -MockWith {
                    return [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new('Test error'),
                        'ScheduledTaskWaitFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        'TestTask1'
                    )
                }

                { Wait-StmScheduledTask -TaskName 'TestTask1' @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'ScheduledTaskWaitFailed'
                }
            }
        }

        Context 'CIM Session Management' {
            BeforeEach {
                $mockTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                    'MSFT_ScheduledTask',
                    'Root/Microsoft/Windows/TaskScheduler'
                )
                $mockStateProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                    'State',
                    'Ready',
                    [Microsoft.Management.Infrastructure.CimType]::String,
                    [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                        [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                )
                $mockTask.CimInstanceProperties.Add($mockStateProperty)

                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    return $mockTask
                }
            }

            It 'Should create CIM session with correct parameters' {
                Wait-StmScheduledTask -TaskName 'TestTask1' -ComputerName 'Server01' @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01' -and $ErrorAction -eq 'Stop'
                }
            }
        }

        Context 'Verbose Output' {
            BeforeEach {
                $mockTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                    'MSFT_ScheduledTask',
                    'Root/Microsoft/Windows/TaskScheduler'
                )
                $mockStateProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                    'State',
                    'Ready',
                    [Microsoft.Management.Infrastructure.CimType]::String,
                    [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                        [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                )
                $mockTask.CimInstanceProperties.Add($mockStateProperty)

                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    return $mockTask
                }
            }

            It 'Should write verbose messages during execution' {
                Mock -CommandName 'Write-Verbose' -MockWith {}

                Wait-StmScheduledTask -TaskName 'TestTask1' -Verbose @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -eq 'Starting Wait-StmScheduledTask'
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Waiting for scheduled task*"
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Completed Wait-StmScheduledTask*"
                }
            }
        }
    }
}
