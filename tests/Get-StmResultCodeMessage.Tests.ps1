BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $ModulePath = Join-Path $ProjectRoot 'ScheduledTasksManager'
    Import-Module $ModulePath -Force
}

Describe 'Get-StmResultCodeMessage' {
    Context 'Parameter Validation' {
        It 'Has a mandatory ResultCode parameter' {
            $command = Get-Command Get-StmResultCodeMessage
            $param = $command.Parameters['ResultCode']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It 'Accepts ResultCode as positional parameter' {
            $command = Get-Command Get-StmResultCodeMessage
            $param = $command.Parameters['ResultCode']
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Position } | Should -Contain 0
        }

        It 'Accepts pipeline input' {
            $command = Get-Command Get-StmResultCodeMessage
            $param = $command.Parameters['ResultCode']
            $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.ValueFromPipeline } | Should -Contain $true
        }
    }

    Context 'Basic Translation' {
        It 'Translates success code 0' {
            $result = Get-StmResultCodeMessage -ResultCode 0
            $result.Message | Should -Be 'The operation completed successfully'
            $result.IsSuccess | Should -BeTrue
        }

        It 'Translates Task Scheduler success code' {
            $result = Get-StmResultCodeMessage -ResultCode 267009
            $result.ConstantName | Should -Be 'SCHED_S_TASK_RUNNING'
            $result.Message | Should -Be 'The task is currently running'
        }

        It 'Translates Task Scheduler error code' {
            $result = Get-StmResultCodeMessage -ResultCode 2147750687
            $result.ConstantName | Should -Be 'SCHED_E_ALREADY_RUNNING'
            $result.Message | Should -Be 'An instance of this task is already running'
        }

        It 'Translates Win32 HRESULT code' {
            $result = Get-StmResultCodeMessage -ResultCode 2147942402
            $result.HexCode | Should -Be '0x80070002'
            $result.Message | Should -BeLike '*file*'
        }
    }

    Context 'Pipeline Input' {
        It 'Accepts single value via pipeline' {
            $result = 267009 | Get-StmResultCodeMessage
            $result.ConstantName | Should -Be 'SCHED_S_TASK_RUNNING'
        }

        It 'Accepts multiple values via pipeline' {
            $results = @(0, 267009, 2147750687) | Get-StmResultCodeMessage
            $results.Count | Should -Be 3
            $results[0].ResultCode | Should -Be 0
            $results[1].ResultCode | Should -Be 267009
            $results[2].ResultCode | Should -Be 2147750687
        }

        It 'Handles mixed input types via pipeline' {
            $results = @(267009, '267011', '0x8004131F') | Get-StmResultCodeMessage
            $results.Count | Should -Be 3
            $results[0].ConstantName | Should -Be 'SCHED_S_TASK_RUNNING'
            $results[1].ConstantName | Should -Be 'SCHED_S_TASK_HAS_NOT_RUN'
            $results[2].ConstantName | Should -Be 'SCHED_E_ALREADY_RUNNING'
        }
    }

    Context 'Input Formats' {
        It 'Accepts integer' {
            $result = Get-StmResultCodeMessage -ResultCode 267009
            $result.ResultCode | Should -Be 267009
        }

        It 'Accepts decimal string' {
            $result = Get-StmResultCodeMessage -ResultCode '267009'
            $result.ResultCode | Should -Be 267009
        }

        It 'Accepts hex string with 0x prefix' {
            $result = Get-StmResultCodeMessage -ResultCode '0x00041301'
            $result.ResultCode | Should -Be 267009
        }

        It 'Accepts hex string with 0X prefix' {
            $result = Get-StmResultCodeMessage -ResultCode '0X00041301'
            $result.ResultCode | Should -Be 267009
        }
    }

    Context 'Output Structure' {
        It 'Returns PSCustomObject' {
            $result = Get-StmResultCodeMessage -ResultCode 0
            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Contains all expected properties' {
            $result = Get-StmResultCodeMessage -ResultCode 267009
            $result.ResultCode | Should -Be 267009
            $result.HexCode | Should -Be '0x00041301'
            $result.Message | Should -Not -BeNullOrEmpty
            $result.Source | Should -Be 'TaskScheduler'
            $result.ConstantName | Should -Be 'SCHED_S_TASK_RUNNING'
            $result.IsSuccess | Should -BeTrue
            $result.Facility | Should -Not -BeNullOrEmpty
            $result.FacilityCode | Should -Not -BeNullOrEmpty
            $result.Meanings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Verbose Output' {
        It 'Produces verbose output when requested' {
            $verboseOutput = Get-StmResultCodeMessage -ResultCode 267009 -Verbose 4>&1
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error Handling' {
        It 'Handles null input without throwing' {
            { Get-StmResultCodeMessage -ResultCode $null } | Should -Not -Throw
        }

        It 'Returns null for null input' {
            $result = Get-StmResultCodeMessage -ResultCode $null
            $result | Should -BeNullOrEmpty
        }

        It 'Handles invalid input gracefully' {
            $result = Get-StmResultCodeMessage -ResultCode 'not-a-number'
            $result.Source | Should -Be 'Unknown'
        }
    }

    Context 'Common Result Codes Documentation Accuracy' {
        # These tests verify that our translations match the documented behavior
        # from Microsoft: https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-error-and-success-constants

        It 'Code 0 means success' {
            $result = Get-StmResultCodeMessage -ResultCode 0
            $result.IsSuccess | Should -BeTrue
            $result.Message | Should -BeLike '*success*'
        }

        It 'Code 267009 (0x00041301) means task is running' {
            $result = Get-StmResultCodeMessage -ResultCode 267009
            $result.Message | Should -BeLike '*running*'
        }

        It 'Code 267011 (0x00041303) means task has not run' {
            $result = Get-StmResultCodeMessage -ResultCode 267011
            $result.Message | Should -BeLike '*not*run*'
        }

        It 'Code 2147750687 (0x8004131F) means already running' {
            $result = Get-StmResultCodeMessage -ResultCode 2147750687
            $result.Message | Should -BeLike '*already running*'
        }

        It 'Code 2147750677 (0x80041315) means service not running' {
            $result = Get-StmResultCodeMessage -ResultCode 2147750677
            $result.Message | Should -BeLike '*not running*'
        }

        It 'Code 2147942402 (0x80070002) means file not found' {
            $result = Get-StmResultCodeMessage -ResultCode 2147942402
            $result.Message | Should -BeLike '*file*'
        }

        It 'Code 2147942405 (0x80070005) means access denied' {
            $result = Get-StmResultCodeMessage -ResultCode 2147942405
            $result.Message | Should -BeLike '*access*denied*'
        }
    }
}
