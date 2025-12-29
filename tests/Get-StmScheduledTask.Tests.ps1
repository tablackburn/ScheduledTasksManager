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
    Describe 'Get-StmScheduledTask' {
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
            Mock -CommandName 'Get-ScheduledTask' -MockWith {
                return @(
                    $mockTask
                )
            }

            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'this-is-a-mock-cim-session'
            }
        }

        Context 'Basic Functionality' {
            It 'should return the scheduled task' {
                $result = Get-StmScheduledTask -TaskName 'TestTask1'
                $result | Should -Not -BeNullOrEmpty
                $result.TaskName | Should -Be 'TestTask1'
            }

            It 'should filter tasks by TaskState' {
                $result = Get-StmScheduledTask -TaskState 'Ready'
                $result | Should -Not -BeNullOrEmpty
                $result.TaskName | Should -Be 'TestTask1'
                $result.State | Should -Be 'Ready'
            }

            It 'should retrieve all tasks when no TaskName is provided' {
                $result = Get-StmScheduledTask
                $result | Should -Not -BeNullOrEmpty
                Should -Invoke -CommandName 'Get-ScheduledTask' -Times 1
            }
        }

        Context 'TaskPath Parameter' {
            It 'should pass TaskPath to Get-ScheduledTask when specified' {
                Get-StmScheduledTask -TaskPath '\Microsoft\Windows\'
                Should -Invoke -CommandName 'Get-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskPath -eq '\Microsoft\Windows\'
                }
            }

            It 'should write verbose message when TaskPath is specified' {
                $verboseOutput = Get-StmScheduledTask -TaskPath '\Custom\' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match "Using provided task path.*\\Custom"
            }

            It 'should write verbose message when TaskPath is not specified' {
                $verboseOutput = Get-StmScheduledTask -Verbose 4>&1 | Out-String
                $verboseOutput | Should -Match 'No task path provided'
            }
        }

        Context 'ComputerName Parameter' {
            It 'should pass ComputerName to New-StmCimSession when specified' {
                Get-StmScheduledTask -ComputerName 'RemoteServer'
                Should -Invoke -CommandName 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'RemoteServer'
                }
            }

            It 'should write verbose message when ComputerName is specified' {
                $verboseOutput = Get-StmScheduledTask -ComputerName 'Server01' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match "Using provided computer name.*Server01"
            }

            It 'should use localhost as default when ComputerName is not specified' {
                Get-StmScheduledTask
                Should -Invoke -CommandName 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'localhost'
                }
            }

            It 'should write verbose message when using local computer' {
                $verboseOutput = Get-StmScheduledTask -Verbose 4>&1 | Out-String
                $verboseOutput | Should -Match 'Using local computer'
            }
        }

        Context 'Credential Parameter' {
            It 'should pass Credential to New-StmCimSession when specified' {
                $testCredential = [PSCredential]::new(
                    'TestUser',
                    (ConvertTo-SecureString -String 'TestPassword' -AsPlainText -Force)
                )
                Get-StmScheduledTask -Credential $testCredential
                Should -Invoke -CommandName 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $null -ne $Credential
                }
            }

            It 'should write verbose message when Credential is specified' {
                $testCredential = [PSCredential]::new(
                    'TestUser',
                    (ConvertTo-SecureString -String 'TestPassword' -AsPlainText -Force)
                )
                $verboseOutput = Get-StmScheduledTask -Credential $testCredential -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'Using provided credential'
            }

            It 'should write verbose message when using current user credentials' {
                $verboseOutput = Get-StmScheduledTask -Verbose 4>&1 | Out-String
                $verboseOutput | Should -Match 'Using current user credentials'
            }
        }

        Context 'Error Handling' {
            It 'should throw terminating error when Get-ScheduledTask fails' {
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    throw 'Access denied'
                }
                { Get-StmScheduledTask -TaskName 'NonExistent' } | Should -Throw
            }

            It 'should include original exception message in error' {
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    throw 'Access denied'
                }
                try {
                    Get-StmScheduledTask -TaskName 'NonExistent'
                }
                catch {
                    $_.Exception.Message | Should -Match 'Failed to retrieve scheduled tasks|Access denied'
                }
            }

            It 'should use New-StmError for error handling' {
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    throw 'Task not found'
                }
                Mock -CommandName 'New-StmError' -MockWith {
                    $record = [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new($Message),
                        $ErrorId,
                        $ErrorCategory,
                        $TargetObject
                    )
                    return $record
                }
                { Get-StmScheduledTask -TaskName 'NonExistent' } | Should -Throw
                Should -Invoke -CommandName 'New-StmError' -Times 1
            }
        }

        Context 'Verbose Output' {
            It 'should write start and finish verbose messages' {
                $verboseOutput = Get-StmScheduledTask -Verbose 4>&1 | Out-String
                $verboseOutput | Should -Match 'Starting Get-StmScheduledTask'
                $verboseOutput | Should -Match 'Finished Get-StmScheduledTask'
            }

            It 'should write verbose message with retrieved task count' {
                $verboseOutput = Get-StmScheduledTask -Verbose 4>&1 | Out-String
                $verboseOutput | Should -Match 'Retrieved \d+ task\(s\)'
            }

            It 'should write verbose message when TaskName is specified' {
                $verboseOutput = Get-StmScheduledTask -TaskName 'TestTask' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match "Using provided task name.*TestTask"
            }

            It 'should write verbose message when no TaskName is provided' {
                $verboseOutput = Get-StmScheduledTask -Verbose 4>&1 | Out-String
                $verboseOutput | Should -Match 'No task name provided'
            }
        }

        Context 'TaskState Filtering' {
            BeforeEach {
                $mockReadyTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                    'MSFT_ScheduledTask',
                    'Root/Microsoft/Windows/TaskScheduler'
                )
                $mockReadyTask.CimInstanceProperties.Add(
                    [Microsoft.Management.Infrastructure.CimProperty]::Create(
                        'TaskName', 'ReadyTask', [Microsoft.Management.Infrastructure.CimType]::String,
                        [Microsoft.Management.Infrastructure.CimFlags]::Property
                    )
                )
                $mockReadyTask.CimInstanceProperties.Add(
                    [Microsoft.Management.Infrastructure.CimProperty]::Create(
                        'State', 'Ready', [Microsoft.Management.Infrastructure.CimType]::String,
                        [Microsoft.Management.Infrastructure.CimFlags]::Property
                    )
                )

                $mockDisabledTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                    'MSFT_ScheduledTask',
                    'Root/Microsoft/Windows/TaskScheduler'
                )
                $mockDisabledTask.CimInstanceProperties.Add(
                    [Microsoft.Management.Infrastructure.CimProperty]::Create(
                        'TaskName', 'DisabledTask', [Microsoft.Management.Infrastructure.CimType]::String,
                        [Microsoft.Management.Infrastructure.CimFlags]::Property
                    )
                )
                $mockDisabledTask.CimInstanceProperties.Add(
                    [Microsoft.Management.Infrastructure.CimProperty]::Create(
                        'State', 'Disabled', [Microsoft.Management.Infrastructure.CimType]::String,
                        [Microsoft.Management.Infrastructure.CimFlags]::Property
                    )
                )

                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    return @($mockReadyTask, $mockDisabledTask)
                }
            }

            It 'should filter out tasks that do not match TaskState' {
                $result = Get-StmScheduledTask -TaskState 'Ready'
                $result.Count | Should -Be 1
                $result.TaskName | Should -Be 'ReadyTask'
            }

            It 'should write verbose message when filtering by TaskState' {
                $verboseOutput = Get-StmScheduledTask -TaskState 'Ready' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match "Filtering scheduled tasks by state.*Ready"
            }
        }
    }
}
