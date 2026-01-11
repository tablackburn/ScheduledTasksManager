<#
.SYNOPSIS
    Integration tests for result code translation using real scheduled tasks.

.DESCRIPTION
    Tests the result code translation functionality by creating actual scheduled
    tasks in the AutomatedLab environment and verifying that result codes are
    translated correctly.

    These tests use actual module functions (Register-StmScheduledTask,
    Wait-StmScheduledTask, etc.) to ensure we're testing real module behavior.

    Tests are executed INSIDE the lab (on STMNODE01) using Invoke-LabCommand
    because the cluster network is not routable from the host.

    Note: Task XML is intentionally duplicated in each test rather than extracted
    to a shared variable. This is because tests run inside Invoke-LabCommand
    scriptblocks which cannot access variables from the outer scope. The
    duplication ensures test isolation and makes each test self-contained.

.NOTES
    Prerequisites:
    - Integration lab deployed and running
    - Run: .\Initialize-IntegrationLab.ps1 (first time)
    - Run: .\Start-IntegrationLab.ps1 (each test session)
#>

BeforeDiscovery {
    $script:SkipIntegrationTests = $false

    # Load configuration module
    Import-Module "$PSScriptRoot\IntegrationTestConfig.psm1" -Force

    # Check if configuration exists
    if (-not (Test-IntegrationTestConfig)) {
        $script:SkipIntegrationTests = $true
        $script:SkipReason = 'config-missing'
        Write-IntegrationTestSkipWarning
    }
    else {
        $script:Config = Get-IntegrationTestConfig
    }

    # Check if AutomatedLab is available
    if (-not $script:SkipIntegrationTests) {
        $alModule = Get-Module -Name AutomatedLab -ListAvailable
        if (-not $alModule) {
            $script:SkipIntegrationTests = $true
            $script:SkipReason = 'AutomatedLab module not installed'
        }
    }

    # Check if lab exists
    if (-not $script:SkipIntegrationTests) {
        Import-Module AutomatedLab -Force -ErrorAction SilentlyContinue
        $labs = Get-Lab -List -ErrorAction SilentlyContinue
        $labName = $script:Config.lab.name
        if ($labName -notin $labs) {
            $script:SkipIntegrationTests = $true
            $script:SkipReason = "Integration lab '$labName' not deployed. Run Initialize-IntegrationLab.ps1 first."
        }
    }
}

BeforeAll {
    # Load config if not already loaded
    if (-not $script:Config -and -not $script:SkipIntegrationTests) {
        Import-Module "$PSScriptRoot\IntegrationTestConfig.psm1" -Force
        $script:Config = Get-IntegrationTestConfig
    }

    # Start the lab and get connection info
    if (-not $script:SkipIntegrationTests) {
        $script:LabInfo = & "$PSScriptRoot\Start-IntegrationLab.ps1"

        # Import AutomatedLab for Invoke-LabCommand
        Import-Module AutomatedLab -Force
        Import-Lab -Name $script:Config.lab.name -NoValidation

        # Copy module to the test node
        $modulePath = Join-Path $PSScriptRoot '..\..\ScheduledTasksManager' -Resolve
        $labModulePath = $script:Config.paths.labModulePath
        $testNode = $script:Config.virtualMachines.clusterNodes[0]

        Write-Host 'Copying module to lab node...' -ForegroundColor Yellow
        Copy-LabFileItem -Path $modulePath -DestinationFolderPath 'C:\' -ComputerName $testNode
        Write-Host "  [OK] Module copied to ${testNode}:$labModulePath" -ForegroundColor Green
    }

    $script:TestTaskFolder = '\StmResultCodeTests'

    # Only set config-dependent variables if config is available
    if ($script:Config) {
        $script:TestNode = $script:Config.virtualMachines.clusterNodes[0]
        $script:LabModulePath = $script:Config.paths.labModulePath
    }
}

AfterAll {
    # Cleanup: Remove all test tasks
    if (-not $script:SkipIntegrationTests -and $script:LabInfo) {
        Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Cleanup: Remove all result code test tasks' -ScriptBlock {
            param($TaskFolder)
            $tasks = Get-ScheduledTask -TaskPath "$TaskFolder\*" -ErrorAction SilentlyContinue
            foreach ($task in $tasks) {
                if ($task.State -eq 'Running') {
                    Stop-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -ErrorAction SilentlyContinue
                }
                Unregister-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -Confirm:$false -ErrorAction SilentlyContinue
            }
        } -ArgumentList @($script:TestTaskFolder)
    }
}

Describe 'Result Code Integration Tests' -Skip:$script:SkipIntegrationTests {

    Context 'Lab Environment' {

        It 'Should have a healthy lab' {
            $script:LabInfo.IsHealthy | Should -BeTrue
        }

        It 'Should have the module available' {
            $result = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Check module exists' -ScriptBlock {
                param($ModulePath)
                Test-Path "$ModulePath\ScheduledTasksManager.psd1"
            } -ArgumentList $script:LabModulePath -PassThru
            $result | Should -BeTrue
        }
    }

    Context 'Success Codes' {

        It 'Should translate code 0 (ERROR_SUCCESS) from successful task' {
            $result = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Test: Success code 0' -ScriptBlock {
                param($ModulePath, $TaskFolder)
                Import-Module $ModulePath -Force

                $taskName = "STM-RC-Success0-$([DateTime]::Now.Ticks)"

                # Task XML that runs cmd /c exit 0
                $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Result code test - Success</Description>
  </RegistrationInfo>
  <Triggers>
    <TimeTrigger>
      <StartBoundary>2099-01-01T00:00:00</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>cmd.exe</Command>
      <Arguments>/c exit 0</Arguments>
    </Exec>
  </Actions>
</Task>
"@

                try {
                    # Register task using module function
                    Register-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Xml $taskXml | Out-Null

                    # Start task using module function
                    Start-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder

                    # Wait for completion using module function
                    Wait-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -TimeoutSeconds 30 | Out-Null

                    # Get task info and translate result code
                    $taskInfo = Get-StmScheduledTaskInfo -TaskName $taskName -TaskPath $TaskFolder
                    $translated = Get-StmResultCodeMessage -ResultCode $taskInfo.LastTaskResult

                    [PSCustomObject]@{
                        LastTaskResult = $taskInfo.LastTaskResult
                        HexCode        = $translated.HexCode
                        IsSuccess      = $translated.IsSuccess
                        Message        = $translated.Message
                    }
                }
                finally {
                    Unregister-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Confirm:$false -ErrorAction SilentlyContinue
                }
            } -ArgumentList @($script:LabModulePath, $script:TestTaskFolder) -PassThru

            $result.LastTaskResult | Should -Be 0
            $result.HexCode | Should -Be '0x00000000'
            $result.IsSuccess | Should -BeTrue
        }

        It 'Should translate custom exit code 42' {
            $result = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Test: Exit code 42' -ScriptBlock {
                param($ModulePath, $TaskFolder)
                Import-Module $ModulePath -Force

                $taskName = "STM-RC-Exit42-$([DateTime]::Now.Ticks)"

                $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><TimeTrigger><StartBoundary>2099-01-01T00:00:00</StartBoundary><Enabled>true</Enabled></TimeTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><ExecutionTimeLimit>PT1H</ExecutionTimeLimit></Settings>
  <Actions Context="Author"><Exec><Command>cmd.exe</Command><Arguments>/c exit 42</Arguments></Exec></Actions>
</Task>
"@

                try {
                    Register-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Xml $taskXml | Out-Null
                    Start-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder
                    Wait-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -TimeoutSeconds 30 | Out-Null

                    $taskInfo = Get-StmScheduledTaskInfo -TaskName $taskName -TaskPath $TaskFolder
                    $translated = Get-StmResultCodeMessage -ResultCode $taskInfo.LastTaskResult

                    [PSCustomObject]@{
                        LastTaskResult = $taskInfo.LastTaskResult
                        HexCode        = $translated.HexCode
                    }
                }
                finally {
                    Unregister-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Confirm:$false -ErrorAction SilentlyContinue
                }
            } -ArgumentList @($script:LabModulePath, $script:TestTaskFolder) -PassThru

            $result.LastTaskResult | Should -Be 42
            $result.HexCode | Should -Be '0x0000002A'
        }

        It 'Should translate custom exit code 255' {
            $result = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Test: Exit code 255' -ScriptBlock {
                param($ModulePath, $TaskFolder)
                Import-Module $ModulePath -Force

                $taskName = "STM-RC-Exit255-$([DateTime]::Now.Ticks)"

                $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><TimeTrigger><StartBoundary>2099-01-01T00:00:00</StartBoundary><Enabled>true</Enabled></TimeTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><ExecutionTimeLimit>PT1H</ExecutionTimeLimit></Settings>
  <Actions Context="Author"><Exec><Command>cmd.exe</Command><Arguments>/c exit 255</Arguments></Exec></Actions>
</Task>
"@

                try {
                    Register-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Xml $taskXml | Out-Null
                    Start-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder
                    Wait-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -TimeoutSeconds 30 | Out-Null

                    $taskInfo = Get-StmScheduledTaskInfo -TaskName $taskName -TaskPath $TaskFolder
                    $translated = Get-StmResultCodeMessage -ResultCode $taskInfo.LastTaskResult

                    [PSCustomObject]@{
                        LastTaskResult = $taskInfo.LastTaskResult
                        HexCode        = $translated.HexCode
                    }
                }
                finally {
                    Unregister-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Confirm:$false -ErrorAction SilentlyContinue
                }
            } -ArgumentList @($script:LabModulePath, $script:TestTaskFolder) -PassThru

            $result.LastTaskResult | Should -Be 255
            $result.HexCode | Should -Be '0x000000FF'
        }
    }

    Context 'File/Path Errors' {

        It 'Should translate ERROR_FILE_NOT_FOUND from non-existent executable' {
            $result = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Test: File not found' -ScriptBlock {
                param($ModulePath, $TaskFolder)
                Import-Module $ModulePath -Force

                $taskName = "STM-RC-FileNotFound-$([DateTime]::Now.Ticks)"

                $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><TimeTrigger><StartBoundary>2099-01-01T00:00:00</StartBoundary><Enabled>true</Enabled></TimeTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><ExecutionTimeLimit>PT1H</ExecutionTimeLimit></Settings>
  <Actions Context="Author"><Exec><Command>C:\NonExistent\FakeProgram.exe</Command></Exec></Actions>
</Task>
"@

                try {
                    Register-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Xml $taskXml | Out-Null
                    Start-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder
                    Wait-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -TimeoutSeconds 30 | Out-Null

                    $taskInfo = Get-StmScheduledTaskInfo -TaskName $taskName -TaskPath $TaskFolder
                    $translated = Get-StmResultCodeMessage -ResultCode $taskInfo.LastTaskResult

                    [PSCustomObject]@{
                        LastTaskResult = $taskInfo.LastTaskResult
                        HexCode        = $translated.HexCode
                        Message        = $translated.Message
                        IsSuccess      = $translated.IsSuccess
                    }
                }
                finally {
                    Unregister-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Confirm:$false -ErrorAction SilentlyContinue
                }
            } -ArgumentList @($script:LabModulePath, $script:TestTaskFolder) -PassThru

            # Could be 2 (plain Win32) or 2147942402 (0x80070002 HRESULT) depending on Windows version
            $result.LastTaskResult | Should -BeIn @(2, 2147942402)
            $result.Message | Should -Match 'file|not found|cannot find'
            $result.IsSuccess | Should -BeFalse
        }
    }

    Context 'Task State Codes' {

        It 'Should translate SCHED_S_TASK_HAS_NOT_RUN (267011) for unrun task' {
            $result = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Test: Task has not run' -ScriptBlock {
                param($ModulePath, $TaskFolder)
                Import-Module $ModulePath -Force

                $taskName = "STM-RC-HasNotRun-$([DateTime]::Now.Ticks)"

                $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><TimeTrigger><StartBoundary>2099-01-01T00:00:00</StartBoundary><Enabled>true</Enabled></TimeTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><ExecutionTimeLimit>PT1H</ExecutionTimeLimit></Settings>
  <Actions Context="Author"><Exec><Command>cmd.exe</Command><Arguments>/c echo test</Arguments></Exec></Actions>
</Task>
"@

                try {
                    # Register task but do NOT run it
                    Register-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Xml $taskXml | Out-Null

                    # Get task info immediately (before any run)
                    $taskInfo = Get-StmScheduledTaskInfo -TaskName $taskName -TaskPath $TaskFolder
                    $translated = Get-StmResultCodeMessage -ResultCode $taskInfo.LastTaskResult

                    [PSCustomObject]@{
                        LastTaskResult = $taskInfo.LastTaskResult
                        HexCode        = $translated.HexCode
                        ConstantName   = $translated.ConstantName
                        Message        = $translated.Message
                        IsSuccess      = $translated.IsSuccess
                    }
                }
                finally {
                    Unregister-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Confirm:$false -ErrorAction SilentlyContinue
                }
            } -ArgumentList @($script:LabModulePath, $script:TestTaskFolder) -PassThru

            $result.LastTaskResult | Should -Be 267011
            $result.HexCode | Should -Be '0x00041303'
            $result.ConstantName | Should -Be 'SCHED_S_TASK_HAS_NOT_RUN'
            $result.IsSuccess | Should -BeTrue
        }

        It 'Should translate SCHED_S_TASK_DISABLED (267010) for disabled task' {
            $result = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Test: Task disabled' -ScriptBlock {
                param($ModulePath, $TaskFolder)
                Import-Module $ModulePath -Force

                $taskName = "STM-RC-Disabled-$([DateTime]::Now.Ticks)"

                # Create a disabled task (Enabled=false)
                $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><TimeTrigger><StartBoundary>2099-01-01T00:00:00</StartBoundary><Enabled>true</Enabled></TimeTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><AllowStartOnDemand>true</AllowStartOnDemand><Enabled>false</Enabled><ExecutionTimeLimit>PT1H</ExecutionTimeLimit></Settings>
  <Actions Context="Author"><Exec><Command>cmd.exe</Command><Arguments>/c echo test</Arguments></Exec></Actions>
</Task>
"@

                try {
                    Register-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Xml $taskXml | Out-Null

                    $taskInfo = Get-StmScheduledTaskInfo -TaskName $taskName -TaskPath $TaskFolder
                    $task = Get-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder
                    $translated = Get-StmResultCodeMessage -ResultCode $taskInfo.LastTaskResult

                    [PSCustomObject]@{
                        TaskState      = $task.State
                        LastTaskResult = $taskInfo.LastTaskResult
                        HexCode        = $translated.HexCode
                        ConstantName   = $translated.ConstantName
                        IsSuccess      = $translated.IsSuccess
                    }
                }
                finally {
                    Unregister-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Confirm:$false -ErrorAction SilentlyContinue
                }
            } -ArgumentList @($script:LabModulePath, $script:TestTaskFolder) -PassThru

            $result.TaskState | Should -Be 'Disabled'
            # Disabled tasks report SCHED_S_TASK_HAS_NOT_RUN initially (before any trigger fires)
            $result.LastTaskResult | Should -BeIn @(267010, 267011)
            $result.IsSuccess | Should -BeTrue
        }
    }

    Context 'Running Task Codes' {

        It 'Should translate SCHED_S_TASK_RUNNING (267009) for active task' {
            $result = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Test: Task running' -ScriptBlock {
                param($ModulePath, $TaskFolder)
                Import-Module $ModulePath -Force

                $taskName = "STM-RC-Running-$([DateTime]::Now.Ticks)"

                # Long-running task (ping for 30 seconds)
                $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><TimeTrigger><StartBoundary>2099-01-01T00:00:00</StartBoundary><Enabled>true</Enabled></TimeTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><ExecutionTimeLimit>PT1H</ExecutionTimeLimit></Settings>
  <Actions Context="Author"><Exec><Command>ping.exe</Command><Arguments>-n 30 localhost</Arguments></Exec></Actions>
</Task>
"@

                try {
                    Register-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Xml $taskXml | Out-Null

                    # Start the task
                    Start-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder

                    # Poll until task is running (max 10 seconds)
                    $timeout = [DateTime]::Now.AddSeconds(10)
                    do {
                        Start-Sleep -Milliseconds 500
                        $task = Get-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder
                    } while ($task.State -ne 'Running' -and [DateTime]::Now -lt $timeout)

                    # Get task info while running
                    $taskInfo = Get-StmScheduledTaskInfo -TaskName $taskName -TaskPath $TaskFolder
                    $translated = Get-StmResultCodeMessage -ResultCode $taskInfo.LastTaskResult

                    [PSCustomObject]@{
                        TaskState      = $task.State
                        LastTaskResult = $taskInfo.LastTaskResult
                        HexCode        = $translated.HexCode
                        ConstantName   = $translated.ConstantName
                        IsSuccess      = $translated.IsSuccess
                    }
                }
                finally {
                    # Stop the task before cleanup
                    Stop-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    Unregister-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Confirm:$false -ErrorAction SilentlyContinue
                }
            } -ArgumentList @($script:LabModulePath, $script:TestTaskFolder) -PassThru

            $result.TaskState | Should -Be 'Running'
            $result.LastTaskResult | Should -Be 267009
            $result.HexCode | Should -Be '0x00041301'
            $result.ConstantName | Should -Be 'SCHED_S_TASK_RUNNING'
            $result.IsSuccess | Should -BeTrue
        }
    }

    Context 'Concurrency Codes' {

        It 'Should handle starting an already-running task with IgnoreNew policy' {
            $result = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Test: Already running' -ScriptBlock {
                param($ModulePath, $TaskFolder)
                Import-Module $ModulePath -Force

                $taskName = "STM-RC-AlreadyRunning-$([DateTime]::Now.Ticks)"
                $secondStartResult = $null

                # Single-instance long-running task
                $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><TimeTrigger><StartBoundary>2099-01-01T00:00:00</StartBoundary><Enabled>true</Enabled></TimeTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><ExecutionTimeLimit>PT1H</ExecutionTimeLimit></Settings>
  <Actions Context="Author"><Exec><Command>ping.exe</Command><Arguments>-n 30 localhost</Arguments></Exec></Actions>
</Task>
"@

                try {
                    Register-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Xml $taskXml | Out-Null

                    # Start the task
                    Start-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder

                    # Poll until task is running (max 10 seconds)
                    $timeout = [DateTime]::Now.AddSeconds(10)
                    do {
                        Start-Sleep -Milliseconds 500
                        $task = Get-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder
                    } while ($task.State -ne 'Running' -and [DateTime]::Now -lt $timeout)

                    # Try to start it again
                    try {
                        Start-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -ErrorAction Stop
                        $secondStartResult = 'Success-IgnoreNew'
                    }
                    catch {
                        $secondStartResult = "Error: $($_.Exception.Message)"
                    }

                    # Check task state
                    $task = Get-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder

                    [PSCustomObject]@{
                        TaskState         = $task.State
                        SecondStartResult = $secondStartResult
                    }
                }
                finally {
                    Stop-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    Unregister-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Confirm:$false -ErrorAction SilentlyContinue
                }
            } -ArgumentList @($script:LabModulePath, $script:TestTaskFolder) -PassThru

            # With IgnoreNew, the second start is silently ignored (no error thrown)
            # The task should still be running
            $result.TaskState | Should -Be 'Running'
            # Second start either succeeds silently (IgnoreNew policy) or errors
            $result.SecondStartResult | Should -Match 'success|ignorenew|already running'
        }
    }

    Context 'Translation Accuracy' {

        It 'Should match Microsoft documentation for SCHED_S_TASK_READY (267008)' {
            $result = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Test: Documentation match' -ScriptBlock {
                param($ModulePath, $TaskFolder)
                Import-Module $ModulePath -Force

                $taskName = "STM-RC-DocMatch-$([DateTime]::Now.Ticks)"

                $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><TimeTrigger><StartBoundary>2099-01-01T00:00:00</StartBoundary><Enabled>true</Enabled></TimeTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><ExecutionTimeLimit>PT1H</ExecutionTimeLimit></Settings>
  <Actions Context="Author"><Exec><Command>cmd.exe</Command><Arguments>/c exit 0</Arguments></Exec></Actions>
</Task>
"@

                try {
                    Register-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Xml $taskXml | Out-Null
                    Start-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder
                    Wait-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -TimeoutSeconds 30 | Out-Null

                    # After completion, task should be Ready
                    $task = Get-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder

                    # Translate 267008 (SCHED_S_TASK_READY)
                    $translated = Get-StmResultCodeMessage -ResultCode 267008

                    [PSCustomObject]@{
                        TaskState         = $task.State
                        TranslatedCode    = $translated.ResultCode
                        HexCode           = $translated.HexCode
                        ConstantName      = $translated.ConstantName
                        Message           = $translated.Message
                        ExpectedMessage   = 'The task is ready to run at its next scheduled time'
                    }
                }
                finally {
                    Unregister-StmScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Confirm:$false -ErrorAction SilentlyContinue
                }
            } -ArgumentList @($script:LabModulePath, $script:TestTaskFolder) -PassThru

            $result.TaskState | Should -Be 'Ready'
            $result.HexCode | Should -Be '0x00041300'
            $result.ConstantName | Should -Be 'SCHED_S_TASK_READY'
            $result.Message | Should -Be $result.ExpectedMessage
        }
    }
}
