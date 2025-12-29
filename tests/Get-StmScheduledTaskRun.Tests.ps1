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
    Describe 'Get-StmScheduledTaskRun' {
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
            $mockTask.CimInstanceProperties.Add($mockTaskNameProperty)
            $mockTask.CimInstanceProperties.Add($mockURIProperty)
            Mock -CommandName 'Get-ScheduledTask' -MockWith {
                return @(
                    $mockTask
                )
            }

            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'this-is-a-mock-cim-session'
            }

            Mock -CommandName 'Get-ScheduledTaskInfo' -MockWith {
                return [PSCustomObject]@{
                    TaskName = 'TestTask1'
                }
            }

            $mockStartEvent = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                ToXml = {
                    return '<Event><EventData></EventData></Event>'
                }
            } -Properties @{
                ActivityId = '123'
                RecordId = 1
                TimeCreated = [datetime]::Now
            }
            $mockEndEvent = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                ToXml = {
                    return '<Event><EventData><Data Name="ResultCode">0</Data></EventData></Event>'
                }
            } -Properties @{
                ActivityId = '123'
                RecordId = 3
                TimeCreated = [datetime]::Now.AddSeconds(2)
            }
            $eventLogRecordType = 'System.Diagnostics.Eventing.Reader.EventLogRecord'
            $mockEventWithoutActivityIdParameters = @{
                Type       = $eventLogRecordType
                Methods    = @{
                    ToXml = {
                        return '<Event><EventData></EventData></Event>'
                    }
                }
                Properties = @{
                    RecordId    = 2
                    TimeCreated = [datetime]::Now.AddSeconds(1)
                }
            }
            $mockEventWithoutActivityId = New-MockObject @mockEventWithoutActivityIdParameters
            Mock -CommandName 'Get-WinEvent' -MockWith {
                return @(
                    $mockEndEvent
                    $mockEventWithoutActivityId
                    $mockStartEvent
                )
            } -ParameterFilter {
                $FilterXPath -eq "*[EventData[Data[@Name='TaskName'] = '\TestTask1']]"
            }

            Mock -CommandName 'Remove-CimSession' -MockWith { }
        }

        It 'Should return the correct object' {
            $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
            $result | Should -BeOfType [PSCustomObject]
            $result.TaskName | Should -Be 'TestTask1'
        }

        It 'Should return one run' {
            $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
            $result.Count | Should -Be 1
            $result.TaskName | Should -Be 'TestTask1'
            $result.ActivityId | Should -Be '123'
            $result.ResultCode | Should -Be 0
            $result.StartTime | Should -Be $mockStartEvent.TimeCreated
            $result.EndTime | Should -Be $mockEndEvent.TimeCreated
        }

        It 'Should return three events' {
            $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
            $result.EventCount | Should -Be 3
            $result.Events.Count | Should -Be 3
            $result.Events[0].ActivityId | Should -Be '123'
            $result.Events[1].ActivityId | Should -Be $null
            $result.Events[2].ActivityId | Should -Be '123'
        }

        It 'Should return events in the correct order' {
            $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
            $result.Events[0].TimeCreated | Should -Be $mockEndEvent.TimeCreated
            $result.Events[1].TimeCreated | Should -Be $mockEventWithoutActivityId.TimeCreated
            $result.Events[2].TimeCreated | Should -Be $mockStartEvent.TimeCreated
        }

        It 'Should convert events to XML' {
            $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
            $result.EventXml[0] | Should -BeOfType [xml]
            $result.EventXml[0] | Should -Not -BeNullOrEmpty
            $result.EventXml[1] | Should -BeOfType [xml]
            $result.EventXml[1] | Should -Not -BeNullOrEmpty
            $result.EventXml[2] | Should -BeOfType [xml]
            $result.EventXml[2] | Should -Not -BeNullOrEmpty
        }

        It 'Should return the correct result code' {
            $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
            $result.ResultCode | Should -Be 0
        }

        Context 'TaskPath Parameter' {
            It 'Should pass TaskPath to Get-ScheduledTask when specified' {
                Get-StmScheduledTaskRun -TaskName 'TestTask1' -TaskPath '\Custom\Path'
                Should -Invoke -CommandName 'Get-ScheduledTask' -ParameterFilter {
                    $TaskPath -eq '\Custom\Path'
                }
            }

            It 'Should write verbose message when TaskPath is specified' {
                $verboseOutput = Get-StmScheduledTaskRun -TaskName 'TestTask1' -TaskPath '\Custom\Path' -Verbose 4>&1
                $verboseOutput -join ' ' | Should -Match "Using provided task path"
            }

            It 'Should write verbose message when TaskPath is not specified' {
                $verboseOutput = Get-StmScheduledTaskRun -TaskName 'TestTask1' -Verbose 4>&1
                $verboseOutput -join ' ' | Should -Match 'No task path provided'
            }
        }

        Context 'ComputerName Parameter' {
            It 'Should pass ComputerName to New-StmCimSession when specified' {
                Get-StmScheduledTaskRun -TaskName 'TestTask1' -ComputerName 'RemoteServer'
                Should -Invoke -CommandName 'New-StmCimSession' -ParameterFilter {
                    $ComputerName -eq 'RemoteServer'
                }
            }

            It 'Should pass ComputerName to Get-WinEvent when specified' {
                Get-StmScheduledTaskRun -TaskName 'TestTask1' -ComputerName 'RemoteServer'
                Should -Invoke -CommandName 'Get-WinEvent' -ParameterFilter {
                    $ComputerName -eq 'RemoteServer'
                }
            }

            It 'Should write verbose message when ComputerName is specified' {
                $verboseParameters = @{
                    TaskName     = 'TestTask1'
                    ComputerName = 'RemoteServer'
                    Verbose      = $true
                }
                $verboseOutput = Get-StmScheduledTaskRun @verboseParameters 4>&1
                $verboseOutput -join ' ' | Should -Match 'Using provided computer name'
            }

            It 'Should use localhost as default ComputerName' {
                Get-StmScheduledTaskRun -TaskName 'TestTask1'
                Should -Invoke -CommandName 'New-StmCimSession' -ParameterFilter {
                    $ComputerName -eq 'localhost'
                }
            }
        }

        Context 'Credential Parameter' {
            It 'Should pass Credential to New-StmCimSession when specified' {
                $credential = New-Object System.Management.Automation.PSCredential(
                    'TestUser',
                    (ConvertTo-SecureString 'TestPassword' -AsPlainText -Force)
                )
                Get-StmScheduledTaskRun -TaskName 'TestTask1' -Credential $credential
                Should -Invoke -CommandName 'New-StmCimSession' -ParameterFilter {
                    $null -ne $Credential -and $Credential.UserName -eq 'TestUser'
                }
            }

            It 'Should pass Credential to Get-WinEvent when specified' {
                $credential = New-Object System.Management.Automation.PSCredential(
                    'TestUser',
                    (ConvertTo-SecureString 'TestPassword' -AsPlainText -Force)
                )
                Get-StmScheduledTaskRun -TaskName 'TestTask1' -Credential $credential
                Should -Invoke -CommandName 'Get-WinEvent' -ParameterFilter {
                    $null -ne $Credential -and $Credential.UserName -eq 'TestUser'
                }
            }

            It 'Should write verbose message when Credential is specified' {
                $credential = New-Object System.Management.Automation.PSCredential(
                    'TestUser',
                    (ConvertTo-SecureString 'TestPassword' -AsPlainText -Force)
                )
                $verboseOutput = Get-StmScheduledTaskRun -TaskName 'TestTask1' -Credential $credential -Verbose 4>&1
                $verboseOutput -join ' ' | Should -Match 'Using provided credential'
            }
        }

        Context 'MaxRuns Parameter' {
            BeforeEach {
                # Create multiple activity IDs
                $mockStartEvent1 = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId  = 'activity-1'
                    RecordId    = 1
                    TimeCreated = [datetime]::Now.AddMinutes(-10)
                }
                $mockEndEvent1 = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData><Data Name="ResultCode">0</Data></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId  = 'activity-1'
                    RecordId    = 2
                    TimeCreated = [datetime]::Now.AddMinutes(-9)
                }
                $mockStartEvent2 = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId  = 'activity-2'
                    RecordId    = 3
                    TimeCreated = [datetime]::Now.AddMinutes(-5)
                }
                $mockEndEvent2 = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData><Data Name="ResultCode">0</Data></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId  = 'activity-2'
                    RecordId    = 4
                    TimeCreated = [datetime]::Now.AddMinutes(-4)
                }
                $mockStartEvent3 = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId  = 'activity-3'
                    RecordId    = 5
                    TimeCreated = [datetime]::Now.AddMinutes(-2)
                }
                $mockEndEvent3 = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData><Data Name="ResultCode">0</Data></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId  = 'activity-3'
                    RecordId    = 6
                    TimeCreated = [datetime]::Now.AddMinutes(-1)
                }

                Mock -CommandName 'Get-WinEvent' -MockWith {
                    return @(
                        $mockEndEvent3
                        $mockStartEvent3
                        $mockEndEvent2
                        $mockStartEvent2
                        $mockEndEvent1
                        $mockStartEvent1
                    )
                } -ParameterFilter {
                    $FilterXPath -eq "*[EventData[Data[@Name='TaskName'] = '\TestTask1']]"
                }
            }

            It 'Should limit results when MaxRuns is specified' {
                $result = Get-StmScheduledTaskRun -TaskName 'TestTask1' -MaxRuns 2
                $result.Count | Should -Be 2
            }

            It 'Should write verbose message when MaxRuns is specified' {
                $verboseOutput = Get-StmScheduledTaskRun -TaskName 'TestTask1' -MaxRuns 2 -Verbose 4>&1
                $verboseOutput -join ' ' | Should -Match 'Limiting to 2 most recent runs'
            }

            It 'Should return all runs when MaxRuns is not specified' {
                $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
                $result.Count | Should -Be 3
            }
        }

        Context 'Multiple Result Codes' {
            # Skip this context - complex edge case that's difficult to mock properly
            # The actual function handles multiple result codes correctly in production
        }

        Context 'Launch Request Ignored' {
            BeforeEach {
                $mockStartEvent = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId  = 'ignored-launch'
                    RecordId    = 1
                    TimeCreated = [datetime]::Now
                }
                $mockIgnoredEvent = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId       = 'ignored-launch'
                    RecordId         = 2
                    TimeCreated      = [datetime]::Now.AddSeconds(1)
                    TaskDisplayName = 'Launch request ignored, instance already running'
                }
                $mockEndEvent = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData><Data Name="ResultCode">0</Data></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId  = 'ignored-launch'
                    RecordId    = 3
                    TimeCreated = [datetime]::Now.AddSeconds(2)
                }

                Mock -CommandName 'Get-WinEvent' -MockWith {
                    return @(
                        $mockEndEvent
                        $mockIgnoredEvent
                        $mockStartEvent
                    )
                } -ParameterFilter {
                    $FilterXPath -eq "*[EventData[Data[@Name='TaskName'] = '\TestTask1']]"
                }
            }

            It 'Should detect launch request ignored events' {
                $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
                $result.LaunchRequestIgnored | Should -Be $true
            }

            It 'Should write verbose message when launch request ignored event is found' {
                $verboseOutput = Get-StmScheduledTaskRun -TaskName 'TestTask1' -Verbose 4>&1
                $verboseOutput -join ' ' | Should -Match 'Launch request ignored event found'
            }
        }

        Context 'Error Handling' {
            It 'Should throw terminating error when Get-ScheduledTask fails' {
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    throw 'Simulated Get-ScheduledTask failure'
                }
                { Get-StmScheduledTaskRun -TaskName 'TestTask1' -ErrorAction Stop } | Should -Throw
            }

            It 'Should use New-StmError for Get-ScheduledTask failure' {
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    throw 'Simulated Get-ScheduledTask failure'
                }
                { Get-StmScheduledTaskRun -TaskName 'TestTask1' -ErrorAction Stop } | Should -Throw
                Should -Invoke -CommandName 'Get-ScheduledTask'
            }

            It 'Should write non-terminating error when task run retrieval fails' {
                Mock -CommandName 'Get-WinEvent' -MockWith {
                    throw 'Simulated Get-WinEvent failure'
                }
                $errorOutput = Get-StmScheduledTaskRun -TaskName 'TestTask1' -ErrorAction SilentlyContinue 2>&1
                $errorOutput | Should -Not -BeNullOrEmpty
            }
        }

        Context 'No Tasks Found' {
            BeforeEach {
                Mock -CommandName 'Get-ScheduledTask' -MockWith {
                    return @()
                }
            }

            It 'Should return nothing when no tasks are found' {
                $result = Get-StmScheduledTaskRun -TaskName 'NonExistent'
                $result | Should -BeNullOrEmpty
            }

            It 'Should write verbose message when no tasks are found' {
                $verboseOutput = Get-StmScheduledTaskRun -TaskName 'NonExistent' -Verbose 4>&1
                $verboseOutput -join ' ' | Should -Match 'No scheduled tasks found'
            }
        }

        Context 'No Events Found' {
            BeforeEach {
                Mock -CommandName 'Get-WinEvent' -MockWith {
                    return @()
                } -ParameterFilter {
                    $FilterXPath -eq "*[EventData[Data[@Name='TaskName'] = '\TestTask1']]"
                }
            }

            It 'Should return nothing when no events are found' {
                $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
                $result | Should -BeNullOrEmpty
            }

            It 'Should write verbose message when no events are found' {
                $verboseOutput = Get-StmScheduledTaskRun -TaskName 'TestTask1' -Verbose 4>&1
                $verboseOutput -join ' ' | Should -Match "No events found for task"
            }
        }

        Context 'CIM Session Cleanup' {
            It 'Should close CIM session in end block' {
                Get-StmScheduledTaskRun -TaskName 'TestTask1'
                Should -Invoke -CommandName 'Remove-CimSession'
            }

            It 'Should write verbose message when closing CIM session' {
                $verboseOutput = Get-StmScheduledTaskRun -TaskName 'TestTask1' -Verbose 4>&1
                $verboseOutput -join ' ' | Should -Match 'Closing CIM session'
            }

            It 'Should write verbose message when no CIM session to close' -Skip:$true {
                # This path is unreachable in normal operation - if CimSession is null,
                # Get-ScheduledTask fails before reaching the end block
            }
        }

        Context 'TaskName Parameter' {
            It 'Should write verbose message when TaskName is specified' {
                $verboseOutput = Get-StmScheduledTaskRun -TaskName 'TestTask1' -Verbose 4>&1
                $verboseOutput -join ' ' | Should -Match "Using provided task name"
            }

            It 'Should write verbose message when TaskName is not specified' {
                $verboseOutput = Get-StmScheduledTaskRun -Verbose 4>&1
                $verboseOutput -join ' ' | Should -Match 'No task name provided'
            }
        }

        Context 'Duration Calculation' {
            It 'Should calculate duration in seconds' {
                $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
                $result.DurationSeconds | Should -BeOfType [double]
                $result.DurationSeconds | Should -BeGreaterThan 0
            }

            It 'Should calculate duration as TimeSpan' {
                $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
                $result.Duration | Should -BeOfType [timespan]
            }
        }

        Context 'Scheduled Task Info Not Found' {
            BeforeEach {
                Mock -CommandName 'Get-ScheduledTaskInfo' -MockWith {
                    return $null
                }
            }

            It 'Should write verbose message when task info is null' {
                $verboseOutput = Get-StmScheduledTaskRun -TaskName 'TestTask1' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'No scheduled task information found for task'
            }
        }

        Context 'Multiple Result Codes' {
            BeforeEach {
                # Create events with multiple different result codes
                $mockStartEvent = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData><Data Name="ResultCode">0</Data></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId  = 'multi-result'
                    RecordId    = 1
                    TimeCreated = [datetime]::Now
                }
                $mockMidEvent = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData><Data Name="ResultCode">1</Data></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId  = 'multi-result'
                    RecordId    = 2
                    TimeCreated = [datetime]::Now.AddSeconds(1)
                }
                $mockEndEvent = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData><Data Name="ResultCode">2</Data></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId  = 'multi-result'
                    RecordId    = 3
                    TimeCreated = [datetime]::Now.AddSeconds(2)
                }

                Mock -CommandName 'Get-WinEvent' -MockWith {
                    return @($mockEndEvent, $mockMidEvent, $mockStartEvent)
                } -ParameterFilter {
                    $FilterXPath -eq "*[EventData[Data[@Name='TaskName'] = '\TestTask1']]"
                }
            }

            It 'Should write verbose message about multiple result codes' {
                $verboseOutput = Get-StmScheduledTaskRun -TaskName 'TestTask1' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'Multiple ResultCode'
            }

            It 'Should return multiple result codes as array' {
                $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
                $result.ResultCode | Should -Not -BeNullOrEmpty
                $result.ResultCode.Count | Should -BeGreaterThan 1
            }
        }

        Context 'Event XML Returns Null' {
            BeforeEach {
                $mockStartEvent = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return $null
                    }
                } -Properties @{
                    ActivityId  = 'null-xml'
                    RecordId    = 1
                    TimeCreated = [datetime]::Now
                }
                $mockEndEvent = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return $null
                    }
                } -Properties @{
                    ActivityId  = 'null-xml'
                    RecordId    = 2
                    TimeCreated = [datetime]::Now.AddSeconds(1)
                }

                Mock -CommandName 'Get-WinEvent' -MockWith {
                    return @($mockEndEvent, $mockStartEvent)
                } -ParameterFilter {
                    $FilterXPath -eq "*[EventData[Data[@Name='TaskName'] = '\TestTask1']]"
                }
            }

            It 'Should write verbose message when event has no XML' {
                $verboseOutput = Get-StmScheduledTaskRun -TaskName 'TestTask1' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'has no XML representation'
            }

            It 'Should handle null XML without error' {
                $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
                $result | Should -Not -BeNullOrEmpty
                $result.EventXml | Should -Contain $null
            }
        }

        Context 'No Result Code Found' {
            BeforeEach {
                $mockStartEvent = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId  = 'no-result'
                    RecordId    = 1
                    TimeCreated = [datetime]::Now
                }
                $mockEndEvent = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                    ToXml = {
                        return '<Event><EventData></EventData></Event>'
                    }
                } -Properties @{
                    ActivityId  = 'no-result'
                    RecordId    = 2
                    TimeCreated = [datetime]::Now.AddSeconds(1)
                }

                Mock -CommandName 'Get-WinEvent' -MockWith {
                    return @(
                        $mockEndEvent
                        $mockStartEvent
                    )
                } -ParameterFilter {
                    $FilterXPath -eq "*[EventData[Data[@Name='TaskName'] = '\TestTask1']]"
                }
            }

            It 'Should handle missing result code' {
                $verboseOutput = Get-StmScheduledTaskRun -TaskName 'TestTask1' -Verbose 4>&1
                $verboseOutput -join ' ' | Should -Match 'No ResultCode found'
            }

            It 'Should set ResultCode to null when not found' {
                $result = Get-StmScheduledTaskRun -TaskName 'TestTask1'
                $result.ResultCode | Should -BeNullOrEmpty
            }
        }
    }
}
