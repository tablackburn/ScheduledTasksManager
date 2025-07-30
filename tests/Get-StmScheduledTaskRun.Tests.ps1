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
                [Microsoft.Management.Infrastructure.CimFlags]::Property -bor [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
            )
            $mockURIProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                'URI',
                '\TestTask1',
                [Microsoft.Management.Infrastructure.CimType]::String,
                [Microsoft.Management.Infrastructure.CimFlags]::Property -bor [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
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
            $mockEventWithoutActivityId = New-MockObject -Type 'System.Diagnostics.Eventing.Reader.EventLogRecord' -Methods @{
                ToXml = {
                    return '<Event><EventData></EventData></Event>'
                }
            } -Properties @{
                RecordId = 2
                TimeCreated = [datetime]::Now.AddSeconds(1)
            }
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
    }
}
