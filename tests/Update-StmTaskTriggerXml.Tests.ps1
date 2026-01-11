BeforeAll {
    $moduleName = 'ScheduledTasksManager'
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\$moduleName\$moduleName.psd1"
    Import-Module -Name $modulePath -Force

    # Import the private function for testing
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\ScheduledTasksManager\Private\Update-StmTaskTriggerXml.ps1")

    # Base XML template with existing trigger
    $script:baseXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><URI>\TestTask</URI></RegistrationInfo>
  <Triggers>
    <TimeTrigger>
      <StartBoundary>2024-01-01T00:00:00</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
  </Triggers>
  <Principals><Principal><UserId>SYSTEM</UserId></Principal></Principals>
  <Settings><Enabled>true</Enabled></Settings>
  <Actions><Exec><Command>cmd.exe</Command></Exec></Actions>
</Task>
'@

    # Helper function to create mock trigger with CimClass
    function New-MockTrigger {
        param (
            [string]$TriggerType,
            [string]$StartBoundary,
            [bool]$Enabled = $true,
            [int]$DaysInterval = 0,
            [int]$WeeksInterval = 0,
            [DayOfWeek[]]$DaysOfWeek = @()
        )

        $trigger = [PSCustomObject]@{
            StartBoundary = $StartBoundary
            Enabled       = $Enabled
            DaysInterval  = $DaysInterval
            WeeksInterval = $WeeksInterval
        }

        # Convert DaysOfWeek array to flags value (Windows Task Scheduler bit flags)
        if ($DaysOfWeek.Count -gt 0) {
            $dayFlagMap = @{
                [DayOfWeek]::Sunday    = 1
                [DayOfWeek]::Monday    = 2
                [DayOfWeek]::Tuesday   = 4
                [DayOfWeek]::Wednesday = 8
                [DayOfWeek]::Thursday  = 16
                [DayOfWeek]::Friday    = 32
                [DayOfWeek]::Saturday  = 64
            }
            $daysFlag = 0
            foreach ($day in $DaysOfWeek) {
                $daysFlag = $daysFlag -bor $dayFlagMap[$day]
            }
            $trigger | Add-Member -NotePropertyName 'DaysOfWeek' -NotePropertyValue $daysFlag
        }

        $trigger | Add-Member -NotePropertyName 'CimClass' -NotePropertyValue ([PSCustomObject]@{
            CimClassName = $TriggerType
        })

        return $trigger
    }
}

Describe 'Update-StmTaskTriggerXml' {
    Context 'Function Attributes' {
        It 'Should have mandatory TaskXml parameter' {
            $function = Get-Command -Name Update-StmTaskTriggerXml
            $function.Parameters['TaskXml'].Attributes.Mandatory | Should -BeTrue
        }

        It 'Should have mandatory Trigger parameter' {
            $function = Get-Command -Name Update-StmTaskTriggerXml
            $function.Parameters['Trigger'].Attributes.Mandatory | Should -BeTrue
        }

        It 'Should have ValidateNotNullOrEmpty on Trigger parameter' {
            $function = Get-Command -Name Update-StmTaskTriggerXml
            $function.Parameters['Trigger'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateNotNullOrEmptyAttribute] } |
                Should -Not -BeNullOrEmpty
        }

        It 'Should reject empty array for Trigger parameter' {
            $taskXml = [xml]$baseXml
            { Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @() } |
                Should -Throw '*cannot validate argument*empty*'
        }
    }

    Context 'Trigger Clearing' {
        It 'Should remove all existing triggers' {
            $taskXml = [xml]$baseXml
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskDailyTrigger' -StartBoundary '2024-06-01T08:00:00'

            # Verify there's an existing trigger
            $taskXml.Task.Triggers.ChildNodes.Count | Should -BeGreaterThan 0

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            # Should only have the new trigger
            $taskXml.Task.Triggers.ChildNodes.Count | Should -Be 1
        }
    }

    Context 'Daily Trigger' {
        BeforeEach {
            $script:taskXml = [xml]$baseXml
        }

        It 'Should create CalendarTrigger element for Daily trigger' {
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskDailyTrigger' -StartBoundary '2024-06-01T08:00:00'

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $taskXml.Task.Triggers.CalendarTrigger | Should -Not -BeNullOrEmpty
        }

        It 'Should create ScheduleByDay child element' {
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskDailyTrigger' -StartBoundary '2024-06-01T08:00:00'

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $taskXml.Task.Triggers.CalendarTrigger.ScheduleByDay | Should -Not -BeNullOrEmpty
        }

        It 'Should set DaysInterval to trigger value' {
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskDailyTrigger' -StartBoundary '2024-06-01T08:00:00' -DaysInterval 3

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $taskXml.Task.Triggers.CalendarTrigger.ScheduleByDay.DaysInterval | Should -Be '3'
        }

        It 'Should default DaysInterval to 1 when not specified' {
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskDailyTrigger' -StartBoundary '2024-06-01T08:00:00' -DaysInterval 0

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $taskXml.Task.Triggers.CalendarTrigger.ScheduleByDay.DaysInterval | Should -Be '1'
        }
    }

    Context 'Weekly Trigger' {
        BeforeEach {
            $script:taskXml = [xml]$baseXml
        }

        It 'Should create CalendarTrigger element for Weekly trigger' {
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskWeeklyTrigger' -StartBoundary '2024-06-01T08:00:00'

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $taskXml.Task.Triggers.CalendarTrigger | Should -Not -BeNullOrEmpty
        }

        It 'Should create ScheduleByWeek child element' {
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskWeeklyTrigger' -StartBoundary '2024-06-01T08:00:00'

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $calTrigger = $taskXml.Task.Triggers.SelectSingleNode('*[local-name()="CalendarTrigger"]')
            $calTrigger.SelectSingleNode('*[local-name()="ScheduleByWeek"]') | Should -Not -BeNullOrEmpty
        }

        It 'Should set WeeksInterval to trigger value' {
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskWeeklyTrigger' -StartBoundary '2024-06-01T08:00:00' -WeeksInterval 2

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $calTrigger = $taskXml.Task.Triggers.SelectSingleNode('*[local-name()="CalendarTrigger"]')
            $schedByWeek = $calTrigger.SelectSingleNode('*[local-name()="ScheduleByWeek"]')
            $schedByWeek.SelectSingleNode('*[local-name()="WeeksInterval"]').InnerText | Should -Be '2'
        }

        It 'Should default WeeksInterval to 1 when not specified' {
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskWeeklyTrigger' -StartBoundary '2024-06-01T08:00:00'

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $calTrigger = $taskXml.Task.Triggers.SelectSingleNode('*[local-name()="CalendarTrigger"]')
            $schedByWeek = $calTrigger.SelectSingleNode('*[local-name()="ScheduleByWeek"]')
            $schedByWeek.SelectSingleNode('*[local-name()="WeeksInterval"]').InnerText | Should -Be '1'
        }

        It 'Should create DaysOfWeek element with specified days' {
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskWeeklyTrigger' -StartBoundary '2024-06-01T08:00:00' -DaysOfWeek @([DayOfWeek]::Monday, [DayOfWeek]::Wednesday, [DayOfWeek]::Friday)

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $calTrigger = $taskXml.Task.Triggers.SelectSingleNode('*[local-name()="CalendarTrigger"]')
            $schedByWeek = $calTrigger.SelectSingleNode('*[local-name()="ScheduleByWeek"]')
            $daysOfWeek = $schedByWeek.SelectSingleNode('*[local-name()="DaysOfWeek"]')
            $daysOfWeek | Should -Not -BeNullOrEmpty
            $daysOfWeek.SelectSingleNode('*[local-name()="Monday"]') | Should -Not -BeNullOrEmpty
            $daysOfWeek.SelectSingleNode('*[local-name()="Wednesday"]') | Should -Not -BeNullOrEmpty
            $daysOfWeek.SelectSingleNode('*[local-name()="Friday"]') | Should -Not -BeNullOrEmpty
            $daysOfWeek.SelectSingleNode('*[local-name()="Tuesday"]') | Should -BeNullOrEmpty
        }
    }

    Context 'Once Trigger' {
        It 'Should create TimeTrigger element for Once trigger' {
            $taskXml = [xml]$baseXml
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskTimeTrigger' -StartBoundary '2024-06-01T08:00:00'

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $taskXml.Task.Triggers.TimeTrigger | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Logon Trigger' {
        It 'Should create LogonTrigger element for Logon trigger' {
            $taskXml = [xml]$baseXml
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskLogonTrigger' -StartBoundary '2024-06-01T08:00:00'

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $taskXml.Task.Triggers.LogonTrigger | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Boot Trigger' {
        It 'Should create BootTrigger element for Boot trigger' {
            $taskXml = [xml]$baseXml
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskBootTrigger' -StartBoundary '2024-06-01T08:00:00'

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $taskXml.Task.Triggers.BootTrigger | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Unknown Trigger Type' {
        It 'Should default to TimeTrigger for unknown types' {
            $taskXml = [xml]$baseXml
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskUnknownTrigger' -StartBoundary '2024-06-01T08:00:00'

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger) -WarningAction SilentlyContinue

            $taskXml.Task.Triggers.TimeTrigger | Should -Not -BeNullOrEmpty
        }

        It 'Should write warning for unknown trigger types' {
            $taskXml = [xml]$baseXml
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskUnknownTrigger' -StartBoundary '2024-06-01T08:00:00'

            $warnings = Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger) -WarningVariable warningOutput 3>&1

            $warningOutput | Should -Not -BeNullOrEmpty
            $warningOutput[0] | Should -BeLike "*Unknown trigger type*MSFT_TaskUnknownTrigger*"
        }
    }

    Context 'Trigger Properties' {
        BeforeEach {
            $script:taskXml = [xml]$baseXml
        }

        It 'Should add StartBoundary when present on trigger' {
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskTimeTrigger' -StartBoundary '2024-12-25T10:30:00'

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $taskXml.Task.Triggers.TimeTrigger.StartBoundary | Should -Be '2024-12-25T10:30:00'
        }

        It 'Should set Enabled to true by default' {
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskTimeTrigger' -StartBoundary '2024-06-01T08:00:00' -Enabled $true

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $taskXml.Task.Triggers.TimeTrigger.Enabled | Should -Be 'true'
        }

        It 'Should set Enabled to false when trigger.Enabled is false' {
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskTimeTrigger' -StartBoundary '2024-06-01T08:00:00' -Enabled $false

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $taskXml.Task.Triggers.TimeTrigger.Enabled | Should -Be 'false'
        }
    }

    Context 'Multiple Triggers' {
        It 'Should handle multiple triggers of different types' {
            $taskXml = [xml]$baseXml
            $triggers = @(
                (New-MockTrigger -TriggerType 'MSFT_TaskDailyTrigger' -StartBoundary '2024-06-01T08:00:00')
                (New-MockTrigger -TriggerType 'MSFT_TaskLogonTrigger' -StartBoundary '2024-06-01T09:00:00')
                (New-MockTrigger -TriggerType 'MSFT_TaskBootTrigger' -StartBoundary '2024-06-01T10:00:00')
            )

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger $triggers

            $taskXml.Task.Triggers.ChildNodes.Count | Should -Be 3
            $taskXml.Task.Triggers.CalendarTrigger | Should -Not -BeNullOrEmpty
            $taskXml.Task.Triggers.LogonTrigger | Should -Not -BeNullOrEmpty
            $taskXml.Task.Triggers.BootTrigger | Should -Not -BeNullOrEmpty
        }
    }

    Context 'XML Namespace' {
        It 'Should create elements with correct namespace URI' {
            $taskXml = [xml]$baseXml
            $mockTrigger = New-MockTrigger -TriggerType 'MSFT_TaskTimeTrigger' -StartBoundary '2024-06-01T08:00:00'

            Update-StmTaskTriggerXml -TaskXml $taskXml -Trigger @($mockTrigger)

            $expectedNs = 'http://schemas.microsoft.com/windows/2004/02/mit/task'
            $taskXml.Task.Triggers.TimeTrigger.NamespaceURI | Should -Be $expectedNs
        }
    }
}
