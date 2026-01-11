# Test-ResultCodeAccuracy.ps1
# Verifies result code translations against Microsoft documentation
# Live tests (creating actual tasks) require -Force and Administrator privileges

[CmdletBinding()]
param(
    [switch]$Force,  # Run live tests that create actual scheduled tasks
    [switch]$Cleanup
)

$ErrorActionPreference = 'Stop'

# Import the module
$modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'ScheduledTasksManager'
Import-Module $modulePath -Force

$testTaskFolder = '\StmResultCodeTest'
$testResults = @()

function Write-TestResult {
    param(
        [string]$TestName,
        [int64]$ExpectedCode,
        [string]$ExpectedHex,
        [string]$ExpectedConstant,
        [string]$ExpectedMessage,
        [object]$ActualResult,
        [bool]$Passed,
        [string]$Notes
    )

    $color = if ($Passed) { 'Green' } else { 'Red' }
    $status = if ($Passed) { 'PASS' } else { 'FAIL' }

    Write-Host "[$status] $TestName" -ForegroundColor $color
    if (-not $Passed) {
        Write-Host "  Expected: $ExpectedConstant ($ExpectedHex) - $ExpectedMessage" -ForegroundColor Yellow
        if ($ActualResult) {
            Write-Host "  Actual:   $($ActualResult.ConstantName) ($($ActualResult.HexCode)) - $($ActualResult.Message)" -ForegroundColor Yellow
        }
        if ($Notes) {
            Write-Host "  Notes:    $Notes" -ForegroundColor DarkYellow
        }
    }

    return [PSCustomObject]@{
        TestName         = $TestName
        ExpectedCode     = $ExpectedCode
        ExpectedHex      = $ExpectedHex
        ExpectedConstant = $ExpectedConstant
        ExpectedMessage  = $ExpectedMessage
        ActualHex        = $ActualResult.HexCode
        ActualConstant   = $ActualResult.ConstantName
        ActualMessage    = $ActualResult.Message
        Passed           = $Passed
        Notes            = $Notes
    }
}

function Remove-TestTasks {
    Write-Host 'Cleaning up test tasks...' -ForegroundColor Cyan
    try {
        $tasks = Get-ScheduledTask -TaskPath "$testTaskFolder\*" -ErrorAction SilentlyContinue
        foreach ($task in $tasks) {
            Unregister-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -Confirm:$false -ErrorAction SilentlyContinue
        }
        Write-Host '  Test folder cleaned up' -ForegroundColor Green
    }
    catch {
        Write-Warning "Cleanup error: $_"
    }
}

if ($Cleanup) {
    Remove-TestTasks
    return
}

Write-Host '=' * 80 -ForegroundColor Cyan
Write-Host 'RESULT CODE ACCURACY VERIFICATION' -ForegroundColor Cyan
Write-Host 'Source: https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-error-and-success-constants' -ForegroundColor DarkGray
Write-Host '=' * 80 -ForegroundColor Cyan
Write-Host ''

# ============================================================================
# STATIC VERIFICATION TESTS
# These verify our lookup table matches Microsoft documentation
# ============================================================================

Write-Host 'PART 1: STATIC VERIFICATION (Lookup Table vs Microsoft Docs)' -ForegroundColor Cyan
Write-Host '-' * 60 -ForegroundColor DarkGray
Write-Host ''

# Test data from Microsoft documentation
# https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-error-and-success-constants
$microsoftDocs = @(
    @{ Code = 0;          Hex = '0x00000000'; Constant = 'ERROR_SUCCESS';                Message = 'The operation completed successfully'; IsSuccess = $true }
    @{ Code = 267008;     Hex = '0x00041300'; Constant = 'SCHED_S_TASK_READY';           Message = 'The task is ready to run at its next scheduled time'; IsSuccess = $true }
    @{ Code = 267009;     Hex = '0x00041301'; Constant = 'SCHED_S_TASK_RUNNING';         Message = 'The task is currently running'; IsSuccess = $true }
    @{ Code = 267010;     Hex = '0x00041302'; Constant = 'SCHED_S_TASK_DISABLED';        Message = 'The task will not run at the scheduled times because it has been disabled'; IsSuccess = $true }
    @{ Code = 267011;     Hex = '0x00041303'; Constant = 'SCHED_S_TASK_HAS_NOT_RUN';     Message = 'The task has not yet run'; IsSuccess = $true }
    @{ Code = 267012;     Hex = '0x00041304'; Constant = 'SCHED_S_TASK_NO_MORE_RUNS';    Message = 'There are no more runs scheduled for this task'; IsSuccess = $true }
    @{ Code = 267013;     Hex = '0x00041305'; Constant = 'SCHED_S_TASK_NOT_SCHEDULED';   Message = 'One or more of the properties needed to run this task on a schedule have not been set'; IsSuccess = $true }
    @{ Code = 267014;     Hex = '0x00041306'; Constant = 'SCHED_S_TASK_TERMINATED';      Message = 'The last run of the task was terminated by the user'; IsSuccess = $true }
    @{ Code = 267015;     Hex = '0x00041307'; Constant = 'SCHED_S_TASK_NO_VALID_TRIGGERS'; Message = 'Either the task has no triggers or the existing triggers are disabled or not set'; IsSuccess = $true }
    @{ Code = 267016;     Hex = '0x00041308'; Constant = 'SCHED_S_EVENT_TRIGGER';        Message = 'Event triggers do not have set run times'; IsSuccess = $true }
    @{ Code = 2147750665; Hex = '0x80041309'; Constant = 'SCHED_E_TRIGGER_NOT_FOUND';    Message = 'Trigger not found'; IsSuccess = $false }
    @{ Code = 2147750666; Hex = '0x8004130A'; Constant = 'SCHED_E_TASK_NOT_READY';       Message = 'One or more of the properties needed to run this task have not been set'; IsSuccess = $false }
    @{ Code = 2147750667; Hex = '0x8004130B'; Constant = 'SCHED_E_TASK_NOT_RUNNING';     Message = 'There is no running instance of the task'; IsSuccess = $false }
    @{ Code = 2147750671; Hex = '0x8004130F'; Constant = 'SCHED_E_ACCOUNT_INFORMATION_NOT_SET'; Message = 'No account information could be found in the Task Scheduler security database for the task indicated'; IsSuccess = $false }
    @{ Code = 2147750672; Hex = '0x80041310'; Constant = 'SCHED_E_ACCOUNT_NAME_NOT_FOUND'; Message = 'Unable to establish existence of the account specified'; IsSuccess = $false }
    @{ Code = 2147750677; Hex = '0x80041315'; Constant = 'SCHED_E_SERVICE_NOT_RUNNING';  Message = 'The Task Scheduler Service is not running'; IsSuccess = $false }
    @{ Code = 2147750687; Hex = '0x8004131F'; Constant = 'SCHED_E_ALREADY_RUNNING';      Message = 'An instance of this task is already running'; IsSuccess = $false }
    @{ Code = 2147750688; Hex = '0x80041320'; Constant = 'SCHED_E_USER_NOT_LOGGED_ON';   Message = 'The task will not run because the user is not logged on'; IsSuccess = $false }
    @{ Code = 2147750689; Hex = '0x80041321'; Constant = 'SCHED_E_INVALID_TASK_HASH';    Message = 'The task image is corrupt or has been tampered with'; IsSuccess = $false }
    @{ Code = 2147750694; Hex = '0x80041326'; Constant = 'SCHED_E_TASK_DISABLED';        Message = 'The task is disabled'; IsSuccess = $false }
)

foreach ($doc in $microsoftDocs) {
    $result = Get-StmResultCodeMessage -ResultCode $doc.Code

    # Check if translation matches documentation
    $constantMatch = ($result.ConstantName -eq $doc.Constant) -or
                     ($doc.Constant -eq 'ERROR_SUCCESS' -and $result.ConstantName -eq 'ERROR_SUCCESS')
    $messageMatch = $result.Message -eq $doc.Message
    $hexMatch = $result.HexCode -eq $doc.Hex
    $successMatch = $result.IsSuccess -eq $doc.IsSuccess

    $passed = $constantMatch -and $messageMatch -and $hexMatch -and $successMatch

    $notes = @()
    if (-not $constantMatch) { $notes += "Constant mismatch" }
    if (-not $messageMatch) { $notes += "Message mismatch" }
    if (-not $hexMatch) { $notes += "Hex mismatch" }
    if (-not $successMatch) { $notes += "IsSuccess mismatch" }

    $testResults += Write-TestResult `
        -TestName "$($doc.Constant) ($($doc.Code))" `
        -ExpectedCode $doc.Code `
        -ExpectedHex $doc.Hex `
        -ExpectedConstant $doc.Constant `
        -ExpectedMessage $doc.Message `
        -ActualResult $result `
        -Passed $passed `
        -Notes ($notes -join ', ')
}

# ============================================================================
# HRESULT FACILITY_WIN32 TESTS
# Verify that HRESULT-wrapped Win32 codes are decoded correctly
# ============================================================================

Write-Host ''
Write-Host 'PART 2: HRESULT FACILITY_WIN32 VERIFICATION' -ForegroundColor Cyan
Write-Host '-' * 60 -ForegroundColor DarkGray
Write-Host ''

$win32HResults = @(
    @{ Code = 2147942402; Hex = '0x80070002'; Win32Code = 2;  Description = 'ERROR_FILE_NOT_FOUND'; MessagePattern = '*file*' }
    @{ Code = 2147942405; Hex = '0x80070005'; Win32Code = 5;  Description = 'ERROR_ACCESS_DENIED'; MessagePattern = '*access*denied*' }
    @{ Code = 2147942401; Hex = '0x80070001'; Win32Code = 1;  Description = 'ERROR_INVALID_FUNCTION'; MessagePattern = '*' }
    @{ Code = 2147942403; Hex = '0x80070003'; Win32Code = 3;  Description = 'ERROR_PATH_NOT_FOUND'; MessagePattern = '*path*' }
    @{ Code = 2147943467; Hex = '0x8007042B'; Win32Code = 1067; Description = 'ERROR_PROCESS_ABORTED'; MessagePattern = '*process*' }
)

foreach ($hr in $win32HResults) {
    $result = Get-StmResultCodeMessage -ResultCode $hr.Code

    $hexMatch = $result.HexCode -eq $hr.Hex
    $facilityMatch = $result.Facility -eq 'FACILITY_WIN32'
    $messageMatch = $result.Message -like $hr.MessagePattern

    $passed = $hexMatch -and $facilityMatch -and $messageMatch

    $notes = @()
    if (-not $hexMatch) { $notes += "Hex mismatch" }
    if (-not $facilityMatch) { $notes += "Facility not WIN32" }
    if (-not $messageMatch) { $notes += "Message doesn't match pattern '$($hr.MessagePattern)'" }

    $testResults += Write-TestResult `
        -TestName "HRESULT $($hr.Description) ($($hr.Hex))" `
        -ExpectedCode $hr.Code `
        -ExpectedHex $hr.Hex `
        -ExpectedConstant $hr.Description `
        -ExpectedMessage "(pattern: $($hr.MessagePattern))" `
        -ActualResult $result `
        -Passed $passed `
        -Notes ($notes -join ', ')
}

# ============================================================================
# INPUT FORMAT VERIFICATION
# Verify that different input formats produce the same result
# ============================================================================

Write-Host ''
Write-Host 'PART 3: INPUT FORMAT VERIFICATION' -ForegroundColor Cyan
Write-Host '-' * 60 -ForegroundColor DarkGray
Write-Host ''

$inputTests = @(
    @{ Input = 267009;        Expected = 267009; Description = 'Integer' }
    @{ Input = '267009';      Expected = 267009; Description = 'Decimal string' }
    @{ Input = '0x00041301';  Expected = 267009; Description = 'Hex string (lowercase x)' }
    @{ Input = '0X00041301';  Expected = 267009; Description = 'Hex string (uppercase X)' }
    @{ Input = '0x8004131F';  Expected = 2147750687; Description = 'Hex string (error code)' }
    @{ Input = [int64]267009; Expected = 267009; Description = 'Int64' }
    @{ Input = [uint32]267009; Expected = 267009; Description = 'UInt32' }
)

foreach ($test in $inputTests) {
    $result = Get-StmResultCodeMessage -ResultCode $test.Input
    $passed = $result.ResultCode -eq $test.Expected

    $testResults += Write-TestResult `
        -TestName "Input: $($test.Description)" `
        -ExpectedCode $test.Expected `
        -ExpectedHex '' `
        -ExpectedConstant '' `
        -ExpectedMessage '' `
        -ActualResult $result `
        -Passed $passed `
        -Notes "Input was: $($test.Input) (Type: $($test.Input.GetType().Name)), Got ResultCode: $($result.ResultCode)"
}

# ============================================================================
# LIVE TESTS (Requires -Force and Administrator)
# ============================================================================

if ($Force) {
    Write-Host ''
    Write-Host 'PART 4: LIVE TESTS (Creating Actual Tasks)' -ForegroundColor Cyan
    Write-Host '-' * 60 -ForegroundColor DarkGray
    Write-Host ''

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
    if (-not $isAdmin) {
        Write-Host '[SKIP] Live tests require Administrator privileges' -ForegroundColor Yellow
        Write-Host '       Run PowerShell as Administrator and use -Force' -ForegroundColor Yellow
    }
    else {
        # Test: Successful task
        try {
            $taskName = 'TestSuccess'
            $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument '/c exit 0'
            $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(60)
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

            Register-ScheduledTask -TaskPath $testTaskFolder -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
            Start-ScheduledTask -TaskPath $testTaskFolder -TaskName $taskName
            Start-Sleep -Seconds 3

            $taskInfo = Get-ScheduledTaskInfo -TaskPath $testTaskFolder -TaskName $taskName
            $liveResult = Get-StmResultCodeMessage -ResultCode $taskInfo.LastTaskResult

            $passed = $taskInfo.LastTaskResult -eq 0 -and $liveResult.IsSuccess -eq $true

            $testResults += Write-TestResult `
                -TestName 'Live: Successful task (exit 0)' `
                -ExpectedCode 0 `
                -ExpectedHex '0x00000000' `
                -ExpectedConstant 'ERROR_SUCCESS' `
                -ExpectedMessage 'The operation completed successfully' `
                -ActualResult $liveResult `
                -Passed $passed `
                -Notes "Task returned: $($taskInfo.LastTaskResult)"

            Unregister-ScheduledTask -TaskPath $testTaskFolder -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        }
        catch {
            Write-Host "[FAIL] Live: Successful task - Exception: $_" -ForegroundColor Red
        }

        # Test: Non-existent executable (should return file not found)
        try {
            $taskName = 'TestFileNotFound'
            $action = New-ScheduledTaskAction -Execute 'C:\NonExistent\FakeProgram.exe'
            $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(60)
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

            Register-ScheduledTask -TaskPath $testTaskFolder -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
            Start-ScheduledTask -TaskPath $testTaskFolder -TaskName $taskName
            Start-Sleep -Seconds 3

            $taskInfo = Get-ScheduledTaskInfo -TaskPath $testTaskFolder -TaskName $taskName
            $liveResult = Get-StmResultCodeMessage -ResultCode $taskInfo.LastTaskResult

            # Could be 2 (plain Win32) or 2147942402 (HRESULT) depending on Windows version
            $passed = ($taskInfo.LastTaskResult -eq 2 -or $taskInfo.LastTaskResult -eq 2147942402) -and
                      $liveResult.Message -like '*file*'

            $testResults += Write-TestResult `
                -TestName 'Live: Non-existent executable (file not found)' `
                -ExpectedCode 2147942402 `
                -ExpectedHex '0x80070002' `
                -ExpectedConstant 'ERROR_FILE_NOT_FOUND' `
                -ExpectedMessage '*file*' `
                -ActualResult $liveResult `
                -Passed $passed `
                -Notes "Task returned: $($taskInfo.LastTaskResult) ($($liveResult.HexCode))"

            Unregister-ScheduledTask -TaskPath $testTaskFolder -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        }
        catch {
            Write-Host "[FAIL] Live: Non-existent executable - Exception: $_" -ForegroundColor Red
        }

        # Cleanup
        Remove-TestTasks
    }
}
else {
    Write-Host ''
    Write-Host 'PART 4: LIVE TESTS (Skipped)' -ForegroundColor Yellow
    Write-Host '-' * 60 -ForegroundColor DarkGray
    Write-Host 'Run with -Force as Administrator to execute live tests' -ForegroundColor DarkYellow
    Write-Host ''
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ''
Write-Host '=' * 80 -ForegroundColor Cyan
Write-Host 'TEST SUMMARY' -ForegroundColor Cyan
Write-Host '=' * 80 -ForegroundColor Cyan

$passed = ($testResults | Where-Object { $_.Passed }).Count
$failed = ($testResults | Where-Object { -not $_.Passed }).Count
$total = $testResults.Count

Write-Host ''
Write-Host "Total Tests: $total" -ForegroundColor White
Write-Host "Passed:      $passed" -ForegroundColor Green
Write-Host "Failed:      $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
Write-Host ''

if ($failed -gt 0) {
    Write-Host 'FAILED TESTS:' -ForegroundColor Red
    $testResults | Where-Object { -not $_.Passed } | ForEach-Object {
        Write-Host "  - $($_.TestName)" -ForegroundColor Red
        Write-Host "    Expected: $($_.ExpectedConstant) ($($_.ExpectedHex)) - $($_.ExpectedMessage)" -ForegroundColor Yellow
        Write-Host "    Actual:   $($_.ActualConstant) ($($_.ActualHex)) - $($_.ActualMessage)" -ForegroundColor Yellow
        if ($_.Notes) {
            Write-Host "    Notes:    $($_.Notes)" -ForegroundColor DarkYellow
        }
    }
}

$passRate = if ($total -gt 0) { [math]::Round(($passed / $total) * 100, 1) } else { 0 }
Write-Host ''
Write-Host "Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -eq 100) { 'Green' } elseif ($passRate -ge 90) { 'Yellow' } else { 'Red' })
Write-Host ''
Write-Host '=' * 80 -ForegroundColor Cyan

# Return results for further analysis
return $testResults
