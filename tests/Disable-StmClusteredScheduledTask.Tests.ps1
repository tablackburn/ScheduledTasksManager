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
    Describe 'Disable-StmClusteredScheduledTask' {
        BeforeEach {
            Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith {
                return '<TaskDefinition>MockTaskXML</TaskDefinition>'
            }
            Mock -CommandName 'Join-Path' -MockWith {
                # Call the real Join-Path with the provided ChildPath
                & (Get-Command -CommandType 'Cmdlet' -Name 'Join-Path') -Path 'TestDrive:\' -ChildPath $PesterBoundParameters.ChildPath
            }
            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'this-is-a-mock-cim-session'
            }
            Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith {}
            Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith { return $null }  # Task removed successfully
            Mock -CommandName 'Out-File' -MockWith {
                # Call real Out-File with bound parameters
                & (Get-Command -CommandType 'Cmdlet' -Name 'Out-File') @PesterBoundParameters
            }
        }

        BeforeAll {
            $script:commonParameters = @{
                WarningAction = 'SilentlyContinue'
            }
        }

        Context 'Parameter Validation' {
            It 'Should accept valid TaskName parameter' {
                { Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -WhatIf @commonParameters } | Should -Not -Throw
            }

            It 'Should accept valid Cluster parameter' {
                { Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -WhatIf @commonParameters } | Should -Not -Throw
            }

            It 'Should accept valid Credential parameter' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))
                { Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Credential $credential -WhatIf @commonParameters } | Should -Not -Throw
            }

            It 'Should throw when TaskName is null or empty' {
                { Disable-StmClusteredScheduledTask -TaskName '' -Cluster 'TestCluster' -WhatIf @commonParameters } | Should -Throw
                { Disable-StmClusteredScheduledTask -TaskName $null -Cluster 'TestCluster' -WhatIf @commonParameters } | Should -Throw
            }

            It 'Should throw when Cluster is null or empty' {
                { Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster '' -WhatIf @commonParameters } | Should -Throw
                { Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster $null -WhatIf @commonParameters } | Should -Throw
            }
        }

        Context 'ShouldProcess Support' {
            It 'Should support -WhatIf parameter' {
                { Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -WhatIf @commonParameters } | Should -Not -Throw

                # Verify that actual operations are not performed in WhatIf mode
                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 0
                Should -Invoke 'Unregister-ClusteredScheduledTask' -Times 0
            }

            It 'Should have ConfirmImpact set to High' {
                $function = Get-Command -Name 'Disable-StmClusteredScheduledTask'
                $confirmImpact = $function.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments | Where-Object {
                    $_.ArgumentName -eq 'ConfirmImpact'
                }
                $confirmImpact.Argument.Value | Should -Be 'High'
            }
        }

        Context 'Backup Functionality' {
            It 'Should create backup before disabling task' {
                Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false @commonParameters

                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                }
                Should -Invoke 'Out-File' -Times 1
            }

            It 'Should generate unique backup filename with timestamp' {
                Mock Get-Date { return [DateTime]::new(2025, 1, 18, 15, 30, 45) }

                Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false @commonParameters

                Should -Invoke Join-Path -Times 1 -ParameterFilter {
                    $ChildPath -like 'TestTask_TestCluster_20250118153045.xml'
                }
            }

            It 'Should throw error if backup fails' {
                Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith { throw 'Export failed' }
                Mock -CommandName 'New-StmError' -MockWith {
                    # Call the real New-StmError with bound parameters
                    & (Get-Command -CommandType 'Function' -Name 'New-StmError') @PesterBoundParameters
                }

                { Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'BackupFailed'
                }
            }

            It 'Should throw error if backup file is empty' {
                Mock -CommandName 'Get-Content' -MockWith { return @() }  # Empty file

                { Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false @commonParameters } | Should -Throw
            }
        }

        Context 'Task Unregistration' {
            It 'Should create CIM session for cluster operations' {
                Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'TestCluster'
                }
            }

            It 'Should call Unregister-ClusteredScheduledTask with correct parameters' {
                Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false @commonParameters

                Should -Invoke 'Unregister-ClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                }
            }

            It 'Should verify task removal after unregistration' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith { return $null }  # Task successfully removed

                Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false @commonParameters

                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                }
            }

            It 'Should throw error if task still exists after unregistration' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{ TaskName = 'TestTask'; Cluster = 'TestCluster' }
                }

                { Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should throw error if unregistration fails' {
                Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith { throw 'Unregister failed' }
                Mock -CommandName 'New-StmError' -MockWith {
                    # Call the real New-StmError with bound parameters
                    & (Get-Command -CommandType 'Function' -Name 'New-StmError') @PesterBoundParameters
                }

                { Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'UnregisterFailed'
                }
            }
        }

        Context 'Credential Handling' {
            It 'Should pass credentials to Export-StmClusteredScheduledTask' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))

                Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should pass credentials to New-StmCimSession' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))

                Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should use empty credential as default' {
                Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false @commonParameters

                Should -Invoke Export-StmClusteredScheduledTask -Times 1 -ParameterFilter {
                    $Credential -eq [PSCredential]::Empty
                }
            }
        }

        Context 'Warning and Verbose Messages' {
            It 'Should display warning about irreversible action' {
                Mock -CommandName 'Write-Warning' -MockWith { }

                Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false

                Should -Invoke 'Write-Warning' -Times 1
            }

            It 'Should write verbose messages for key operations' {
                Mock -CommandName 'Write-Verbose' -MockWith { }

                Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false -Verbose @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1
            }
        }

        Context 'Integration Tests' {
            It 'Should complete full disable workflow successfully' {
                # Arrange
                Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith {
                    return '<TaskDefinition>MockTaskXML</TaskDefinition>'
                }
                Mock -CommandName 'Test-Path' -MockWith {
                    return $true
                }
                Mock -CommandName 'Get-Content' -MockWith {
                    return @('line1', 'line2', 'line3')
                }
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return $null
                }  # Task removed successfully

                # Act & Assert
                { Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false @commonParameters } | Should -Not -Throw

                # Verify all steps were executed
                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 1
                Should -Invoke 'Out-File' -Times 1
                Should -Invoke 'New-StmCimSession' -Times 1
                Should -Invoke 'Unregister-ClusteredScheduledTask' -Times 1
                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 1
            }
        }
    }
}
