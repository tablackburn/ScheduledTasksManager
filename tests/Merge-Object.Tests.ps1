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
    Describe 'Merge-Object' {
        BeforeAll {
            $script:commonParameters = @{
                WarningAction     = 'SilentlyContinue'
                InformationAction = 'SilentlyContinue'
            }
        }

        Context 'Basic Functionality with Named Parameters' {
            It 'Should merge two objects with unique properties' {
                $first = [PSCustomObject]@{ A = 1; B = 2 }
                $second = [PSCustomObject]@{ C = 3; D = 4 }

                $result = Merge-Object -FirstObject $first -SecondObject $second -AsHashtable

                $result['A'] | Should -Be 1
                $result['B'] | Should -Be 2
                $result['C'] | Should -Be 3
                $result['D'] | Should -Be 4
            }

            It 'Should merge objects with shared properties having same values' {
                $first = [PSCustomObject]@{ A = 1; Shared = 'same' }
                $second = [PSCustomObject]@{ B = 2; Shared = 'same' }

                $result = Merge-Object -FirstObject $first -SecondObject $second -AsHashtable

                $result['Shared'] | Should -Be 'same'
            }

            It 'Should handle shared properties with different values using named keys' {
                $first = [PSCustomObject]@{ A = 1; Shared = 'first-value' }
                $second = [PSCustomObject]@{ B = 2; Shared = 'second-value' }

                $result = Merge-Object -FirstObject $first -FirstObjectName 'Obj1' -SecondObject $second -SecondObjectName 'Obj2' -AsHashtable

                $result['Shared']['Obj1'] | Should -Be 'first-value'
                $result['Shared']['Obj2'] | Should -Be 'second-value'
            }

            It 'Should include original objects with named keys' {
                $first = [PSCustomObject]@{ A = 1 }
                $second = [PSCustomObject]@{ B = 2 }

                $result = Merge-Object -FirstObject $first -FirstObjectName 'MyFirst' -SecondObject $second -SecondObjectName 'MySecond' -AsHashtable

                $result['MyFirst'].A | Should -Be 1
                $result['MySecond'].B | Should -Be 2
            }
        }

        Context 'Default Key Names (No FirstObjectName/SecondObjectName)' {
            It 'Should use default FirstObject key when FirstObjectName not provided' {
                $first = [PSCustomObject]@{ A = 1 }
                $second = [PSCustomObject]@{ B = 2 }

                $result = Merge-Object -FirstObject $first -SecondObject $second -AsHashtable

                $result['FirstObject'].A | Should -Be 1
            }

            It 'Should use default SecondObject key when SecondObjectName not provided' {
                $first = [PSCustomObject]@{ A = 1 }
                $second = [PSCustomObject]@{ B = 2 }

                $result = Merge-Object -FirstObject $first -SecondObject $second -AsHashtable

                $result['SecondObject'].B | Should -Be 2
            }

            It 'Should use default keys for shared properties with different values' {
                $first = [PSCustomObject]@{ Shared = 'first-value' }
                $second = [PSCustomObject]@{ Shared = 'second-value' }

                $result = Merge-Object -FirstObject $first -SecondObject $second -AsHashtable

                $result['Shared']['FirstObject'] | Should -Be 'first-value'
                $result['Shared']['SecondObject'] | Should -Be 'second-value'
            }

            It 'Should use default keys when only FirstObjectName is provided' {
                $first = [PSCustomObject]@{ Shared = 'first-value' }
                $second = [PSCustomObject]@{ Shared = 'second-value' }

                $result = Merge-Object -FirstObject $first -FirstObjectName 'Named' -SecondObject $second -AsHashtable

                $result['Shared']['Named'] | Should -Be 'first-value'
                $result['Shared']['SecondObject'] | Should -Be 'second-value'
                $result['Named'].Shared | Should -Be 'first-value'
                $result['SecondObject'].Shared | Should -Be 'second-value'
            }

            It 'Should use default keys when only SecondObjectName is provided' {
                $first = [PSCustomObject]@{ Shared = 'first-value' }
                $second = [PSCustomObject]@{ Shared = 'second-value' }

                $result = Merge-Object -FirstObject $first -SecondObject $second -SecondObjectName 'Named' -AsHashtable

                $result['Shared']['FirstObject'] | Should -Be 'first-value'
                $result['Shared']['Named'] | Should -Be 'second-value'
                $result['FirstObject'].Shared | Should -Be 'first-value'
                $result['Named'].Shared | Should -Be 'second-value'
            }
        }

        Context 'Output Type - PSCustomObject (No AsHashtable)' {
            It 'Should return PSCustomObject when AsHashtable is not specified' {
                $first = [PSCustomObject]@{ A = 1 }
                $second = [PSCustomObject]@{ B = 2 }

                $result = Merge-Object -FirstObject $first -SecondObject $second

                $result | Should -BeOfType [PSCustomObject]
            }

            It 'Should have correct properties on PSCustomObject output' {
                $first = [PSCustomObject]@{ A = 1 }
                $second = [PSCustomObject]@{ B = 2 }

                $result = Merge-Object -FirstObject $first -SecondObject $second

                $result.A | Should -Be 1
                $result.B | Should -Be 2
                $result.FirstObject.A | Should -Be 1
                $result.SecondObject.B | Should -Be 2
            }

            It 'Should handle shared properties with different values as PSCustomObject' {
                $first = [PSCustomObject]@{ Shared = 'first' }
                $second = [PSCustomObject]@{ Shared = 'second' }

                $result = Merge-Object -FirstObject $first -SecondObject $second

                $result.Shared['FirstObject'] | Should -Be 'first'
                $result.Shared['SecondObject'] | Should -Be 'second'
            }

            It 'Should use named keys on PSCustomObject output' {
                $first = [PSCustomObject]@{ A = 1 }
                $second = [PSCustomObject]@{ B = 2 }

                $result = Merge-Object -FirstObject $first -FirstObjectName 'First' -SecondObject $second -SecondObjectName 'Second'

                $result.First.A | Should -Be 1
                $result.Second.B | Should -Be 2
            }
        }

        Context 'Output Type - Hashtable (AsHashtable specified)' {
            It 'Should return OrderedDictionary when AsHashtable is specified' {
                $first = [PSCustomObject]@{ A = 1 }
                $second = [PSCustomObject]@{ B = 2 }

                $result = Merge-Object -FirstObject $first -SecondObject $second -AsHashtable

                $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
            }
        }

        Context 'Edge Cases' {
            It 'Should handle objects with no overlapping properties' {
                $first = [PSCustomObject]@{ A = 1; B = 2 }
                $second = [PSCustomObject]@{ C = 3; D = 4 }

                $result = Merge-Object -FirstObject $first -SecondObject $second -AsHashtable

                $result.Keys | Should -Contain 'A'
                $result.Keys | Should -Contain 'B'
                $result.Keys | Should -Contain 'C'
                $result.Keys | Should -Contain 'D'
            }

            It 'Should handle objects with all overlapping properties (same values)' {
                $first = [PSCustomObject]@{ A = 1; B = 2 }
                $second = [PSCustomObject]@{ A = 1; B = 2 }

                $result = Merge-Object -FirstObject $first -SecondObject $second -AsHashtable

                $result['A'] | Should -Be 1
                $result['B'] | Should -Be 2
            }

            It 'Should handle objects with all overlapping properties (different values)' {
                $first = [PSCustomObject]@{ A = 1; B = 2 }
                $second = [PSCustomObject]@{ A = 10; B = 20 }

                $result = Merge-Object -FirstObject $first -SecondObject $second -AsHashtable

                $result['A']['FirstObject'] | Should -Be 1
                $result['A']['SecondObject'] | Should -Be 10
                $result['B']['FirstObject'] | Should -Be 2
                $result['B']['SecondObject'] | Should -Be 20
            }

            It 'Should handle null property values' {
                $first = [PSCustomObject]@{ A = $null }
                $second = [PSCustomObject]@{ B = $null }

                $result = Merge-Object -FirstObject $first -SecondObject $second -AsHashtable

                $result['A'] | Should -BeNullOrEmpty
                $result['B'] | Should -BeNullOrEmpty
            }

            It 'Should handle shared property where one is null and other has value' {
                $first = [PSCustomObject]@{ Shared = $null }
                $second = [PSCustomObject]@{ Shared = 'value' }

                $result = Merge-Object -FirstObject $first -SecondObject $second -AsHashtable

                $result['Shared']['FirstObject'] | Should -BeNullOrEmpty
                $result['Shared']['SecondObject'] | Should -Be 'value'
            }

            It 'Should handle complex nested objects as property values' {
                $first = [PSCustomObject]@{ Data = @{ Nested = 'value1' } }
                $second = [PSCustomObject]@{ Data = @{ Nested = 'value2' } }

                $result = Merge-Object -FirstObject $first -SecondObject $second -AsHashtable

                $result['Data']['FirstObject'].Nested | Should -Be 'value1'
                $result['Data']['SecondObject'].Nested | Should -Be 'value2'
            }
        }
    }
}
