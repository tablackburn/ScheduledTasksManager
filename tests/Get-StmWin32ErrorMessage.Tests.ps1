BeforeAll {
    $projectRoot = Split-Path -Parent $PSScriptRoot
    $modulePath = Join-Path $projectRoot 'ScheduledTasksManager'
    Import-Module $modulePath -Force
}

Describe 'Get-StmWin32ErrorMessage' -Tag 'Unit' {
    Context 'Common Win32 Error Codes' {
        It 'Translates ERROR_SUCCESS (0)' {
            InModuleScope 'ScheduledTasksManager' {
                $result = Get-StmWin32ErrorMessage -ErrorCode 0
                $result | Should -Be 'The operation completed successfully.'
            }
        }

        It 'Translates ERROR_FILE_NOT_FOUND (2)' {
            InModuleScope 'ScheduledTasksManager' {
                $result = Get-StmWin32ErrorMessage -ErrorCode 2
                $result | Should -Be 'The system cannot find the file specified.'
            }
        }

        It 'Translates ERROR_PATH_NOT_FOUND (3)' {
            InModuleScope 'ScheduledTasksManager' {
                $result = Get-StmWin32ErrorMessage -ErrorCode 3
                $result | Should -Be 'The system cannot find the path specified.'
            }
        }

        It 'Translates ERROR_ACCESS_DENIED (5)' {
            InModuleScope 'ScheduledTasksManager' {
                $result = Get-StmWin32ErrorMessage -ErrorCode 5
                $result | Should -Be 'Access is denied.'
            }
        }

        It 'Translates ERROR_INVALID_HANDLE (6)' {
            InModuleScope 'ScheduledTasksManager' {
                $result = Get-StmWin32ErrorMessage -ErrorCode 6
                $result | Should -Be 'The handle is invalid.'
            }
        }
    }

    Context 'Return Type' {
        It 'Returns a string for valid error codes' {
            InModuleScope 'ScheduledTasksManager' {
                $result = Get-StmWin32ErrorMessage -ErrorCode 0
                $result | Should -BeOfType [string]
            }
        }

        It 'Returns non-empty string for known codes' {
            InModuleScope 'ScheduledTasksManager' {
                $result = Get-StmWin32ErrorMessage -ErrorCode 2
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Edge Cases' {
        It 'Handles large error codes' {
            InModuleScope 'ScheduledTasksManager' {
                # Win32Exception handles codes up to Int32.MaxValue
                $result = Get-StmWin32ErrorMessage -ErrorCode 10000
                $result | Should -Not -BeNullOrEmpty
            }
        }

        It 'Handles negative error codes' {
            InModuleScope 'ScheduledTasksManager' {
                # Negative codes are valid for Win32Exception
                $result = Get-StmWin32ErrorMessage -ErrorCode (-1)
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Verbose Output' {
        It 'Writes verbose message when translating' {
            InModuleScope 'ScheduledTasksManager' {
                $verboseOutput = Get-StmWin32ErrorMessage -ErrorCode 2 -Verbose 4>&1
                $verboseOutput -join ' ' | Should -Match 'Translating Win32 error code'
            }
        }

        It 'Writes verbose message with result' {
            InModuleScope 'ScheduledTasksManager' {
                $verboseOutput = Get-StmWin32ErrorMessage -ErrorCode 2 -Verbose 4>&1
                $verboseOutput -join ' ' | Should -Match 'Win32 translation result'
            }
        }
    }
}
