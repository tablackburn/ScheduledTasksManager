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
    Describe 'Stop-StmClusteredScheduledTask' {
        BeforeEach {
            $mockedScheduledTaskObjectParameters = @{
                TypeName     = 'Microsoft.Management.Infrastructure.CimInstance'
                ArgumentList = @(
                    'MSFT_ScheduledTask'                   # Cim class name (Get using: (Get-ScheduledTask).get_CimClass())
                    'Root/Microsoft/Windows/TaskScheduler' # Cim namespace (Get using: (Get-ScheduledTask).CimSystemProperties)
                )
            }
            $mockedScheduledTaskObject = New-Object @mockedScheduledTaskObjectParameters

            Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                return [PSCustomObject]@{
                    TaskName            = 'TestTask'
                    TaskState           = 'Running'
                    ScheduledTaskObject = $mockedScheduledTaskObject
                }
            } -ParameterFilter {
                $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
            }

            Mock -CommandName 'Stop-ScheduledTask' -MockWith {
                param(
                    [Parameter(ValueFromPipeline)]
                    $InputObject
                )
                process {
                    return $InputObject
                }
            } -ParameterFilter {
                $InputObject -eq $mockedScheduledTaskObject
            }

            Mock -CommandName 'New-StmError' -MockWith {
                param($Exception, $ErrorId, $ErrorCategory, $TargetObject)
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $Exception,
                    $ErrorId,
                    $ErrorCategory,
                    $TargetObject
                )
                return $errorRecord
            }
        }

        Context 'Parameter Validation' {
            It 'Should accept valid TaskName parameter' {
                { Stop-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -WhatIf } | Should -Not -Throw
            }

            It 'Should accept valid Cluster parameter' {
                { Stop-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -WhatIf } | Should -Not -Throw
            }

            It 'Should accept valid Credential parameter' {
                $mockCredential = [System.Management.Automation.PSCredential]::Empty
                { Stop-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Credential $mockCredential -WhatIf } | Should -Not -Throw
            }

            It 'Should reject null TaskName' {
                { Stop-StmClusteredScheduledTask -TaskName $null -Cluster 'TestCluster' } | Should -Throw
            }

            It 'Should reject empty TaskName' {
                { Stop-StmClusteredScheduledTask -TaskName '' -Cluster 'TestCluster' } | Should -Throw
            }

            It 'Should reject null Cluster' {
                { Stop-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster $null } | Should -Throw
            }

            It 'Should reject empty Cluster' {
                { Stop-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster '' } | Should -Throw
            }
        }

        Context 'Functionality' {
            It 'Should stop the clustered scheduled task successfully' {
                { Stop-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' } | Should -Not -Throw
                Should -Invoke -CommandName 'Get-StmClusteredScheduledTask' -Times 1 -Exactly
                Should -Invoke -CommandName 'Stop-ScheduledTask' -Times 1 -Exactly
            }

            It 'Should handle WhatIf parameter correctly' {
                Stop-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -WhatIf
                Should -Invoke -CommandName 'Get-StmClusteredScheduledTask' -Times 1 -Exactly
                Should -Invoke -CommandName 'Stop-ScheduledTask' -Times 0 -Exactly
            }

            It 'Should handle Confirm parameter correctly' {
                # This test verifies the ShouldProcess logic is in place
                Stop-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false
                Should -Invoke -CommandName 'Get-StmClusteredScheduledTask' -Times 1 -Exactly
                Should -Invoke -CommandName 'Stop-ScheduledTask' -Times 1 -Exactly
            }

            It 'Should provide verbose output' {
                Stop-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Verbose 4>$null
                Should -Invoke -CommandName 'Get-StmClusteredScheduledTask' -Times 1 -Exactly
                Should -Invoke -CommandName 'Stop-ScheduledTask' -Times 1 -Exactly
            }
        }

        Context 'Error Handling' {
            It 'Should handle task not found error' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return $null
                }

                { Stop-StmClusteredScheduledTask -TaskName 'NonExistentTask' -Cluster 'TestCluster' } | Should -Throw
                Should -Invoke -CommandName 'New-StmError' -Times 1 -Exactly
                Should -Invoke -CommandName 'Stop-ScheduledTask' -Times 0 -Exactly
            }

            It 'Should handle Get-StmClusteredScheduledTask failure' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    throw 'Connection failed'
                } -ParameterFilter {
                    $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                }

                { Stop-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' } | Should -Throw
                Should -Invoke -CommandName 'New-StmError' -Times 1 -Exactly
                Should -Invoke -CommandName 'Stop-ScheduledTask' -Times 0 -Exactly
            }

            It 'Should handle Stop-ScheduledTask failure' {
                Mock -CommandName 'Stop-ScheduledTask' -MockWith {
                    throw 'Cannot stop task'
                } -ParameterFilter {
                    $InputObject -eq $mockedScheduledTaskObject
                }

                { Stop-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' } | Should -Throw
                Should -Invoke -CommandName 'Get-StmClusteredScheduledTask' -Times 1 -Exactly
                Should -Invoke -CommandName 'Stop-ScheduledTask' -Times 1 -Exactly
                Should -Invoke -CommandName 'New-StmError' -Times 1 -Exactly
            }
        }

        Context 'Edge Cases' {
            It 'Should handle task in different states' {
                $testStates = @('Running', 'Ready', 'Disabled', 'Queued')

                foreach ($state in $testStates) {
                    Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                        return [PSCustomObject]@{
                            TaskName            = 'TestTask'
                            TaskState           = $state
                            ScheduledTaskObject = $mockedScheduledTaskObject
                        }
                    } -ParameterFilter {
                        $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                    }

                    if ($state -eq 'Running') {
                        { Stop-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -WhatIf } | Should -Not -Throw
                    }
                    else {
                        { Stop-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -WhatIf } | Should -Not -Throw
                    }
                }
            }
        }
    }
}
