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
    Describe 'Unregister-StmClusteredScheduledTask' {
        BeforeEach {
            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'mock-cim-session'
            }

            Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith {}

            Mock -CommandName 'New-StmError' -MockWith {
                param($Exception, $ErrorId, $ErrorCategory, $TargetObject, $Message, $RecommendedAction)
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $Exception,
                    $ErrorId,
                    $ErrorCategory,
                    $TargetObject
                )
                return $errorRecord
            }

            Mock -CommandName 'Write-Verbose' -MockWith {}
        }

        Context 'Successful unregistration' {
            It 'Should unregister the clustered scheduled task successfully' {
                { Unregister-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' } |
                    Should -Not -Throw

                Should -Invoke -CommandName 'New-StmCimSession' -Times 1 -Exactly
                Should -Invoke -CommandName 'Unregister-ClusteredScheduledTask' -Times 1 -Exactly
            }

            It 'Should pass correct parameters to New-StmCimSession' {
                Unregister-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster'

                Should -Invoke -CommandName 'New-StmCimSession' -Times 1 -Exactly -ParameterFilter {
                    $ComputerName -eq 'TestCluster' -and
                    $Credential -eq [System.Management.Automation.PSCredential]::Empty
                }
            }

            It 'Should pass correct parameters to Unregister-ClusteredScheduledTask' {
                Unregister-StmClusteredScheduledTask -TaskName 'MyTask' -Cluster 'MyCluster'

                Should -Invoke -CommandName 'Unregister-ClusteredScheduledTask' -Times 1 -Exactly
            }

            It 'Should accept credentials parameter' {
                $credential = [System.Management.Automation.PSCredential]::new(
                    'TestUser',
                    (ConvertTo-SecureString -String 'TestPassword' -AsPlainText -Force)
                )

                Unregister-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Credential $credential

                Should -Invoke -CommandName 'New-StmCimSession' -Times 1 -Exactly -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should write verbose messages when -Verbose is used' {
                Unregister-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Verbose

                Should -Invoke 'Write-Verbose' -Times 5 -Exactly
            }
        }

        Context 'WhatIf and Confirm support' {
            It 'Should support -WhatIf parameter' {
                Unregister-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -WhatIf

                Should -Invoke -CommandName 'New-StmCimSession' -Times 1 -Exactly
                Should -Invoke -CommandName 'Unregister-ClusteredScheduledTask' -Times 0 -Exactly
            }

            It 'Should not unregister task when WhatIf is specified' {
                Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith {
                    throw 'Should not be called with -WhatIf'
                }

                { Unregister-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -WhatIf } |
                    Should -Not -Throw
            }
        }

        Context 'CIM session creation failures' {
            It 'Should throw when CIM session creation fails' {
                Mock -CommandName 'New-StmCimSession' -MockWith {
                    throw 'Connection failed'
                }

                { Unregister-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' } |
                    Should -Throw

                Should -Invoke -CommandName 'Unregister-ClusteredScheduledTask' -Times 0 -Exactly
            }

            It 'Should call New-StmError when CIM session creation fails' {
                Mock -CommandName 'New-StmCimSession' -MockWith {
                    throw 'Network error'
                }

                { Unregister-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'BadCluster' } |
                    Should -Throw

                Should -Invoke -CommandName 'New-StmError' -Times 1 -Exactly -ParameterFilter {
                    $ErrorId -eq 'CimSessionCreationFailed' -and
                    $ErrorCategory -eq [System.Management.Automation.ErrorCategory]::ConnectionError -and
                    $TargetObject -eq 'BadCluster'
                }
            }

            It 'Should include helpful error message when CIM session creation fails' {
                Mock -CommandName 'New-StmCimSession' -MockWith {
                    throw 'Access denied'
                }

                { Unregister-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' } |
                    Should -Throw

                Should -Invoke -CommandName 'New-StmError' -Times 1 -Exactly -ParameterFilter {
                    $Message -like "*Failed to create CIM session to cluster 'TestCluster'*" -and
                    $RecommendedAction -like "*Verify the cluster name*"
                }
            }
        }

        Context 'Task unregistration failures' {
            It 'Should throw when task unregistration fails' {
                Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith {
                    throw 'Task not found'
                }

                { Unregister-StmClusteredScheduledTask -TaskName 'NonExistentTask' -Cluster 'TestCluster' } |
                    Should -Throw
            }

            It 'Should call New-StmError when task unregistration fails' {
                Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith {
                    throw 'Access denied'
                }

                { Unregister-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' } |
                    Should -Throw

                Should -Invoke -CommandName 'New-StmError' -Times 1 -Exactly -ParameterFilter {
                    $ErrorId -eq 'ClusteredTaskUnregistrationFailed' -and
                    $ErrorCategory -eq [System.Management.Automation.ErrorCategory]::OperationStopped -and
                    $TargetObject -eq 'TestTask'
                }
            }

            It 'Should include helpful error message when task unregistration fails' {
                Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith {
                    throw 'Permission denied'
                }

                { Unregister-StmClusteredScheduledTask -TaskName 'ProtectedTask' -Cluster 'MyCluster' } |
                    Should -Throw

                Should -Invoke -CommandName 'New-StmError' -Times 1 -Exactly -ParameterFilter {
                    $Message -like "*Failed to unregister clustered scheduled task 'ProtectedTask'*" -and
                    $Message -like "*on cluster 'MyCluster'*" -and
                    $RecommendedAction -like "*Ensure the task name*"
                }
            }

            It 'Should handle task not found error gracefully' {
                Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith {
                    $exception = [System.Exception]::new('Task does not exist')
                    throw $exception
                }

                { Unregister-StmClusteredScheduledTask -TaskName 'MissingTask' -Cluster 'TestCluster' } |
                    Should -Throw

                Should -Invoke -CommandName 'New-StmError' -Times 1 -Exactly
            }
        }
    }
}
