BeforeDiscovery {
    # Unload the module if it is loaded
    if (Get-Module -Name 'ScheduledTasksManager') {
        Remove-Module -Name 'ScheduledTasksManager' -Force
    }

    # Import the module or function being tested
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ScheduledTasksManager\ScheduledTasksManager.psd1'
    Import-Module -Name $ModulePath -Force
}

InModuleScope 'ScheduledTasksManager' {
    Describe 'Enable-StmClusteredScheduledTask' {
        BeforeEach {
            # Mock external dependencies
            Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith {
                return @'
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <Settings>
        <Enabled>false</Enabled>
        <AllowStartOnDemand>true</AllowStartOnDemand>
    </Settings>
</Task>
'@
            }

            Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                return [PSCustomObject]@{
                    ClusteredScheduledTaskObject = [PSCustomObject]@{
                        TaskName = 'TestTask'
                        TaskType = 'ClusterWide'
                    }
                }
            }

            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'mock-cim-session'
            }

            Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith { }

            Mock -CommandName 'Register-StmClusteredScheduledTask' -MockWith { }

            Mock -CommandName 'Write-Warning' -MockWith { }
            Mock -CommandName 'Write-Verbose' -MockWith { }
            Mock -CommandName 'Write-Error' -MockWith { }
        }

        Context 'Parameter Validation' {
            It 'Should accept valid TaskName parameter' {
                { Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false } | Should -Not -Throw
            }

            It 'Should accept valid Cluster parameter' {
                { Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false } | Should -Not -Throw
            }

            It 'Should accept valid Credential parameter' {
                $securePassword = ConvertTo-SecureString -String 'TestPass' -AsPlainText -Force
                $credential = New-Object -TypeName 'PSCredential' -ArgumentList 'TestUser', $securePassword
                { Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Credential $credential -Confirm:$false } | Should -Not -Throw
            }

            It 'Should throw when TaskName is null or empty' {
                { Enable-StmClusteredScheduledTask -TaskName '' -Cluster 'TestCluster' -Confirm:$false } | Should -Throw
                { Enable-StmClusteredScheduledTask -TaskName $null -Cluster 'TestCluster' -Confirm:$false } | Should -Throw
            }

            It 'Should throw when Cluster is null or empty' {
                { Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster '' -Confirm:$false } | Should -Throw
                { Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster $null -Confirm:$false } | Should -Throw
            }
        }

        Context 'Task Export and XML Processing' {
            It 'Should export task XML before processing' {
                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                }
            }

            It 'Should handle export failure gracefully' {
                Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith { return $null }

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Write-Error' -Times 1 -ParameterFilter {
                    $Message -like '*Failed to export XML for task*'
                }
            }

            It 'Should modify XML to enable task when currently disabled' {
                Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith {
                    return @'
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <Settings>
        <Enabled>false</Enabled>
    </Settings>
</Task>
'@
                }

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<Enabled>true</Enabled>*'
                }
            }

            It 'Should not modify XML when task is already enabled' {
                Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith {
                    return @'
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <Settings>
        <Enabled>true</Enabled>
    </Settings>
</Task>
'@
                }

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                # Should write warning and not proceed with re-registration
                Should -Invoke 'Write-Warning' -Times 1 -ParameterFilter {
                    $Message -like '*already enabled*'
                }
                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 0
            }
        }

        Context 'Task Type Retrieval' {
            It 'Should retrieve original task type before re-registration' {
                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                }
            }

            It 'Should handle missing task type gracefully' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{
                        ClusteredScheduledTaskObject = [PSCustomObject]@{
                            TaskName = 'TestTask'
                            TaskType = $null
                        }
                    }
                }

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Write-Error' -Times 1 -ParameterFilter {
                    $Message -like '*Failed to retrieve original task type*'
                }
            }

            It 'Should pass correct task type to registration' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{
                        ClusteredScheduledTaskObject = [PSCustomObject]@{
                            TaskName = 'TestTask'
                            TaskType = 'ResourceSpecific'
                        }
                    }
                }

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskType -eq 'ResourceSpecific'
                }
            }
        }

        Context 'Task Unregistration and Re-registration' {
            It 'Should create CIM session for cluster operations' {
                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'TestCluster'
                }
            }

            It 'Should unregister task before re-registration' {
                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Unregister-ClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask'
                }
            }

            It 'Should re-register task with modified XML' {
                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                }
            }

            It 'Should handle unregistration failure' {
                Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith {
                    throw 'Unregister failed'
                }

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Write-Error' -Times 1 -ParameterFilter {
                    $Message -like '*Failed to enable clustered scheduled task*'
                }
            }

            It 'Should handle re-registration failure' {
                Mock -CommandName 'Register-StmClusteredScheduledTask' -MockWith {
                    throw 'Register failed'
                }

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Write-Error' -Times 1 -ParameterFilter {
                    $Message -like '*Failed to enable clustered scheduled task*'
                }
            }
        }

        Context 'Credential Handling' {
            It 'Should pass credentials to Export-StmClusteredScheduledTask' {
                $securePassword = ConvertTo-SecureString -String 'TestPass' -AsPlainText -Force
                $credential = New-Object -TypeName 'PSCredential' -ArgumentList 'TestUser', $securePassword

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Credential $credential -Confirm:$false

                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should pass credentials to Get-StmClusteredScheduledTask' {
                $securePassword = ConvertTo-SecureString -String 'TestPass' -AsPlainText -Force
                $credential = New-Object -TypeName PSCredential -ArgumentList 'TestUser', $securePassword

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Credential $credential -Confirm:$false

                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should pass credentials to New-StmCimSession' {
                $securePassword = ConvertTo-SecureString -String 'TestPass' -AsPlainText -Force
                $credential = New-Object -TypeName 'PSCredential' -ArgumentList 'TestUser', $securePassword

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Credential $credential -Confirm:$false

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should pass credentials to Register-StmClusteredScheduledTask' {
                $securePassword = ConvertTo-SecureString -String 'TestPass' -AsPlainText -Force
                $credential = New-Object -TypeName 'PSCredential' -ArgumentList 'TestUser', $securePassword

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Credential $credential -Confirm:$false

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should use empty credential as default' {
                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $null -eq $Credential -or $Credential -eq [PSCredential]::Empty
                }
            }
        }

        Context 'Verbose Messages' {
            It 'Should write verbose messages for key operations' {
                Mock -CommandName 'Write-Verbose' -MockWith { }

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Verbose -Confirm:$false

                Should -Invoke 'Write-Verbose' -Times 1
            }

            It 'Should write start message in begin block' {
                Mock -CommandName 'Write-Verbose' -MockWith { }

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Verbose -Confirm:$false

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like '*Starting Enable-StmClusteredScheduledTask*'
                }
            }

            It 'Should write completion message in end block' {
                Mock -CommandName 'Write-Verbose' -MockWith { }

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Verbose -Confirm:$false

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like '*Completed Enable-StmClusteredScheduledTask*'
                }
            }
        }

        Context 'Error Scenarios' {
            It 'Should handle invalid XML gracefully' {
                Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith {
                    return 'invalid-xml-content'
                }

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Write-Error' -Times 1 -ParameterFilter {
                    $Message -like '*Failed to enable clustered scheduled task*'
                }
            }

            It 'Should handle missing task gracefully' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return $null
                }

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Write-Error' -Times 1 -ParameterFilter {
                    $Message -like '*Failed to retrieve original task type*'
                }
            }

            It 'Should handle CIM session creation failure' {
                Mock -CommandName 'New-StmCimSession' -MockWith {
                    throw 'CIM session failed'
                }

                Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Write-Error' -Times 1 -ParameterFilter {
                    $Message -like '*Failed to enable clustered scheduled task*'
                }
            }
        }

        Context 'Integration Tests' {
            It 'Should complete full enable workflow successfully' {
                # Arrange - all mocks are set up in BeforeEach

                # Act & Assert
                { Enable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false } | Should -Not -Throw

                # Verify all steps were executed in correct order
                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 1
                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 1
                Should -Invoke 'New-StmCimSession' -Times 1
                Should -Invoke 'Unregister-ClusteredScheduledTask' -Times 1
                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1
            }

            It 'Should enable task that was previously disabled' {
                # Mock a disabled task
                Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith {
                    return @'
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <Settings>
        <Enabled>false</Enabled>
    </Settings>
</Task>
'@
                }

                Enable-StmClusteredScheduledTask -TaskName 'DisabledTask' -Cluster 'TestCluster' -Confirm:$false

                # Verify the XML was modified to enable the task
                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<Enabled>true</Enabled>*'
                }
            }

            It 'Should handle already enabled task correctly' {
                # Mock an already enabled task
                Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith {
                    return @'
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <Settings>
        <Enabled>true</Enabled>
    </Settings>
</Task>
'@
                }

                { Enable-StmClusteredScheduledTask -TaskName 'EnabledTask' -Cluster 'TestCluster' -Confirm:$false } | Should -Not -Throw

                # Should write warning and not proceed with re-registration when already enabled
                Should -Invoke 'Write-Warning' -Times 1 -ParameterFilter {
                    $Message -like '*already enabled*'
                }
                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 0
            }
        }
    }
}
