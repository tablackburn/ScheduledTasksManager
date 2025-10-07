BeforeAll {
    . $PSScriptRoot/../ScheduledTasksManager/Private/Get-WinEventXPathFilter.ps1
    . $PSScriptRoot/../ScheduledTasksManager/Private/Initialize-XPathFilter.ps1
    . $PSScriptRoot/../ScheduledTasksManager/Private/Join-XPathFilter.ps1
}

Describe 'Get-WinEventXPathFilter' {
    Context 'EventID Filter' {
        It 'Should create XPath filter for single event ID' {
            $result = Get-WinEventXPathFilter -ID '4624'
            $result | Should -Be '*[System[EventID=4624]]'
        }

        It 'Should create XPath filter for multiple event IDs' {
            $result = Get-WinEventXPathFilter -ID '4624', '4625'
            $result | Should -Match 'EventID=4624'
            $result | Should -Match 'EventID=4625'
            $result | Should -Match '\*\[System\['
        }

        It 'Should use OR logic for multiple event IDs' {
            $result = Get-WinEventXPathFilter -ID '4624', '4625', '4626'
            # XPath uses nested parentheses for grouping multiple OR conditions
            $result | Should -Be '*[System[((EventID=4624) or (EventID=4625)) or (EventID=4626)]]'
        }
    }

    Context 'ExcludeID Filter' {
        It 'Should create XPath filter to exclude single event ID' {
            $result = Get-WinEventXPathFilter -ExcludeID '4624'
            $result | Should -Be '*[System[EventID!=4624]]'
        }

        It 'Should create XPath filter to exclude multiple event IDs' {
            $result = Get-WinEventXPathFilter -ExcludeID '4624', '4625'
            $result | Should -Match 'EventID!=4624'
            $result | Should -Match 'EventID!=4625'
        }

        It 'Should use OR logic for multiple excluded event IDs' {
            $result = Get-WinEventXPathFilter -ExcludeID '4624', '4625'
            # XPath uses parentheses for grouping OR conditions
            $result | Should -Match '\(EventID!=4624\) or \(EventID!=4625\)'
        }
    }

    Context 'StartTime Filter' {
        It 'Should create XPath filter for StartTime' {
            $startTime = (Get-Date).AddHours(-1)
            $result = Get-WinEventXPathFilter -StartTime $startTime
            $result | Should -Match 'TimeCreated\[timediff\(@SystemTime\) <= \d+\]'
        }

        It 'Should calculate correct milliseconds for StartTime' {
            $startTime = (Get-Date).AddHours(-2)
            $result = Get-WinEventXPathFilter -StartTime $startTime
            # Should be approximately 7,200,000 milliseconds (2 hours)
            $result | Should -Match 'timediff\(@SystemTime\) <= 7\d{6}'
        }
    }

    Context 'EndTime Filter' {
        It 'Should create XPath filter for EndTime' {
            $endTime = (Get-Date).AddHours(-1)
            $result = Get-WinEventXPathFilter -EndTime $endTime
            $result | Should -Match 'TimeCreated\[timediff\(@SystemTime\) >= \d+\]'
        }

        It 'Should calculate correct milliseconds for EndTime' {
            $endTime = (Get-Date).AddHours(-3)
            $result = Get-WinEventXPathFilter -EndTime $endTime
            # Should be approximately 10,800,000 milliseconds (3 hours)
            $result | Should -Match 'timediff\(@SystemTime\) >= 1\d{7}'
        }
    }

    Context 'StartTime and EndTime Combined' {
        It 'Should create XPath filter with both StartTime and EndTime' {
            $startTime = (Get-Date).AddHours(-2)
            $endTime = (Get-Date).AddHours(-1)
            $result = Get-WinEventXPathFilter -StartTime $startTime -EndTime $endTime
            $result | Should -Match 'timediff\(@SystemTime\) <= \d+'
            $result | Should -Match 'timediff\(@SystemTime\) >= \d+'
        }
    }

    Context 'Data Filter' {
        It 'Should create XPath filter for single data value' {
            $result = Get-WinEventXPathFilter -Data 'TestData'
            $result | Should -Be "*[EventData[Data='TestData']]"
        }

        It 'Should create XPath filter for multiple data values' {
            $result = Get-WinEventXPathFilter -Data 'Data1', 'Data2'
            $result | Should -Match "Data='Data1'"
            $result | Should -Match "Data='Data2'"
        }

        It 'Should use OR logic for multiple data values' {
            $result = Get-WinEventXPathFilter -Data 'Data1', 'Data2'
            # XPath uses parentheses for grouping OR conditions
            $result | Should -Match "\(Data='Data1'\) or \(Data='Data2'\)"
        }
    }

    Context 'ProviderName Filter' {
        It 'Should create XPath filter for single provider name' {
            $result = Get-WinEventXPathFilter -ProviderName 'Microsoft-Windows-Security-Auditing'
            $result | Should -Be "*[System[Provider[@Name='Microsoft-Windows-Security-Auditing']]]"
        }

        It 'Should create XPath filter for multiple provider names' {
            $result = Get-WinEventXPathFilter -ProviderName 'Provider1', 'Provider2'
            $result | Should -Match "@Name='Provider1'"
            $result | Should -Match "@Name='Provider2'"
        }
    }

    Context 'Level Filter' {
        It 'Should create XPath filter for Critical level' {
            $result = Get-WinEventXPathFilter -Level 'Critical'
            $result | Should -Be '*[System[Level=1]]'
        }

        It 'Should create XPath filter for Error level' {
            $result = Get-WinEventXPathFilter -Level 'Error'
            $result | Should -Be '*[System[Level=2]]'
        }

        It 'Should create XPath filter for Warning level' {
            $result = Get-WinEventXPathFilter -Level 'Warning'
            $result | Should -Be '*[System[Level=3]]'
        }

        It 'Should create XPath filter for Informational level' {
            $result = Get-WinEventXPathFilter -Level 'Informational'
            $result | Should -Be '*[System[Level=4]]'
        }

        It 'Should create XPath filter for Verbose level' {
            $result = Get-WinEventXPathFilter -Level 'Verbose'
            $result | Should -Be '*[System[Level=5]]'
        }

        It 'Should create XPath filter for multiple levels' {
            $result = Get-WinEventXPathFilter -Level 'Error', 'Warning'
            $result | Should -Match 'Level=2'
            $result | Should -Match 'Level=3'
        }
    }

    Context 'Keywords Filter' {
        It 'Should create XPath filter for single keyword' {
            $result = Get-WinEventXPathFilter -Keywords 4611686018427387904
            $result | Should -Match 'band\(Keywords,4611686018427387904\)'
        }

        It 'Should combine multiple keywords with binary OR' {
            $result = Get-WinEventXPathFilter -Keywords 4611686018427387904, 9007199254740992
            # Keywords should be combined with binary OR
            $result | Should -Match 'band\(Keywords,\d+\)'
        }
    }

    Context 'UserID Filter with SID' {
        It 'Should create XPath filter for valid SID' {
            # Use a well-known SID (Local System)
            $result = Get-WinEventXPathFilter -UserID 'S-1-5-18'
            $result | Should -Match "@UserID='S-1-5-18'"
        }

        It 'Should create XPath filter for multiple SIDs' {
            $result = Get-WinEventXPathFilter -UserID 'S-1-5-18', 'S-1-5-19'
            $result | Should -Match "@UserID='S-1-5-18'"
            $result | Should -Match "@UserID='S-1-5-19'"
        }
    }

    Context 'UserID Filter with Account Name' {
        It 'Should translate account name to SID' {
            # Skip this test as it requires valid domain account resolution
            # Testing with actual accounts is environment-dependent
            Set-ItResult -Skipped -Because 'Account name translation is environment-dependent'
        }

        It 'Should handle multiple account names' {
            # Skip this test as it requires valid domain account resolution
            # Testing with actual accounts is environment-dependent
            Set-ItResult -Skipped -Because 'Account name translation is environment-dependent'
        }
    }

    Context 'UserID Filter Error Handling' {
        It 'Should throw error for invalid SID' {
            { Get-WinEventXPathFilter -UserID 'InvalidSID' } | Should -Throw
        }

        It 'Should throw error for non-existent account' {
            { Get-WinEventXPathFilter -UserID 'NonExistentDomain\NonExistentUser' } | Should -Throw
        }
    }

    Context 'NamedDataFilter' {
        It 'Should create XPath filter for single named data field with single value' {
            $result = Get-WinEventXPathFilter -NamedDataFilter @{'SubjectUserName' = 'john.doe' }
            $result | Should -Match "Data\[@Name='SubjectUserName'\] = 'john.doe'"
        }

        It 'Should create XPath filter for single named data field with multiple values' {
            $result = Get-WinEventXPathFilter -NamedDataFilter @{'SubjectUserName' = ('john.doe', 'jane.doe') }
            $result | Should -Match "Data\[@Name='SubjectUserName'\]"
            $result | Should -Match "'john.doe'"
            $result | Should -Match "'jane.doe'"
        }

        It 'Should create XPath filter for multiple named data fields' {
            $result = Get-WinEventXPathFilter -NamedDataFilter @{
                'SubjectUserName' = 'john.doe'
                'TargetUserName'  = 'jane.doe'
            }
            $result | Should -Match "Data\[@Name='SubjectUserName'\] = 'john.doe'"
            $result | Should -Match "Data\[@Name='TargetUserName'\] = 'jane.doe'"
        }

        It 'Should create XPath filter for multiple hash tables (OR logic)' {
            $result = Get-WinEventXPathFilter -NamedDataFilter (
                @{'SubjectUserName' = 'john.doe' },
                @{'TargetUserName' = 'jane.doe' }
            )
            $result | Should -Match "Data\[@Name='SubjectUserName'\] = 'john.doe'"
            $result | Should -Match "Data\[@Name='TargetUserName'\] = 'jane.doe'"
        }

        It 'Should create XPath filter for named data field without value (existence check)' {
            $result = Get-WinEventXPathFilter -NamedDataFilter @{'SubjectUserName' = $null }
            $result | Should -Match "Data\[@Name='SubjectUserName'\]"
            $result | Should -Not -Match "Data\[@Name='SubjectUserName'\] ="
        }
    }

    Context 'NamedDataExcludeFilter' {
        It 'Should create XPath filter to exclude named data field with single value' {
            $result = Get-WinEventXPathFilter -NamedDataExcludeFilter @{'SubjectUserName' = 'john.doe' }
            $result | Should -Match "Data\[@Name='SubjectUserName'\] != 'john.doe'"
        }

        It 'Should create XPath filter to exclude multiple named data fields' {
            $result = Get-WinEventXPathFilter -NamedDataExcludeFilter @{
                'SubjectUserName' = 'john.doe'
                'TargetUserName'  = 'jane.doe'
            }
            $result | Should -Match "Data\[@Name='SubjectUserName'\] != 'john.doe'"
            $result | Should -Match "Data\[@Name='TargetUserName'\] != 'jane.doe'"
        }
    }

    Context 'Combined Filters' {
        It 'Should combine ID and Level filters' {
            $result = Get-WinEventXPathFilter -ID '4624' -Level 'Informational'
            $result | Should -Match 'EventID=4624'
            $result | Should -Match 'Level=4'
        }

        It 'Should combine ID, StartTime, and ProviderName filters' {
            $startTime = (Get-Date).AddHours(-1)
            $result = Get-WinEventXPathFilter -ID '4624' -StartTime $startTime -ProviderName 'TestProvider'
            $result | Should -Match 'EventID=4624'
            $result | Should -Match 'timediff'
            $result | Should -Match "@Name='TestProvider'"
        }

        It 'Should combine multiple filter types' {
            $result = Get-WinEventXPathFilter -ID '4624', '4625' -Level 'Error', 'Warning' -Data 'TestData'
            $result | Should -Match 'EventID=4624'
            $result | Should -Match 'EventID=4625'
            $result | Should -Match 'Level=2'
            $result | Should -Match 'Level=3'
            $result | Should -Match "Data='TestData'"
        }
    }

    Context 'Output Format' {
        It 'Should return a string' {
            $result = Get-WinEventXPathFilter -ID '4624'
            $result | Should -BeOfType [string]
        }

        It 'Should return empty string when no parameters provided' {
            $result = Get-WinEventXPathFilter
            $result | Should -Be ''
        }

        It 'Should return valid XPath syntax' {
            $result = Get-WinEventXPathFilter -ID '4624'
            $result | Should -Match '^\*\[System\['
            $result | Should -Match '\]\]$'
        }
    }

    Context 'Edge Cases' {
        It 'Should handle empty array for ID parameter' {
            $result = Get-WinEventXPathFilter -ID @()
            $result | Should -Be ''
        }

        It 'Should handle single-element arrays' {
            $result = Get-WinEventXPathFilter -ID @('4624')
            $result | Should -Be '*[System[EventID=4624]]'
        }

        It 'Should handle special characters in data values' {
            $result = Get-WinEventXPathFilter -Data "Data'With'Quotes"
            $result | Should -Match "Data='Data'With'Quotes'"
        }
    }
}
