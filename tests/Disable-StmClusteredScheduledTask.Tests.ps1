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
                if ($PesterBoundParameters.ContainsKey('FilePath')) {
                    # When FilePath is provided, write to the file
                    $mockXml = '<TaskDefinition>MockTaskXML</TaskDefinition>'
                    $outFileParameters = @{
                        FilePath = $PesterBoundParameters.FilePath
                        Encoding = ([System.Text.Encoding]::Unicode)
                    }
                    $mockXml | Out-File @outFileParameters
                } else {
                    # When no FilePath, return the XML
                    return '<TaskDefinition>MockTaskXML</TaskDefinition>'
                }
            }
            Mock -CommandName 'Join-Path' -MockWith {
                # Call the real Join-Path with the provided ChildPath
                $joinPathCmd = Get-Command -CommandType 'Cmdlet' -Name 'Join-Path'
                & $joinPathCmd -Path 'TestDrive:\' -ChildPath $PesterBoundParameters.ChildPath
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
                InformationAction = 'SilentlyContinue'
            }
        }

        Context 'Function Attributes' {
            It 'Should have ConfirmImpact set to High' {
                $function = Get-Command -Name 'Disable-StmClusteredScheduledTask'
                $confirmImpact = $function.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments | Where-Object {
                    $_.ArgumentName -eq 'ConfirmImpact'
                }
                $confirmImpact.Argument.Value | Should -Be 'High'
            }

            It 'Should support ShouldProcess' {
                $function = Get-Command -Name 'Disable-StmClusteredScheduledTask'
                $function.Parameters.ContainsKey('WhatIf') | Should -Be $true
                $function.Parameters.ContainsKey('Confirm') | Should -Be $true
            }
        }

        Context 'Backup Functionality' {
            It 'Should create backup before disabling task' {
                $disableParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                Disable-StmClusteredScheduledTask @disableParameters @commonParameters

                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                }
                Should -Invoke 'Out-File' -Times 1
            }

            It 'Should generate unique backup filename with timestamp' {
                Mock Get-Date { return [DateTime]::new(2025, 1, 18, 15, 30, 45) }

                $disableParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                Disable-StmClusteredScheduledTask @disableParameters @commonParameters

                Should -Invoke 'Join-Path' -Times 1 -ParameterFilter {
                    $ChildPath -like 'TestTask_TestCluster_20250118153045.xml'
                }
            }

            It 'Should throw error if backup fails' {
                Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith { throw 'Export failed' }
                Mock -CommandName 'New-StmError' -MockWith {
                    # Call the real New-StmError with bound parameters
                    & (Get-Command -CommandType 'Function' -Name 'New-StmError') @PesterBoundParameters
                }

                $disableParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                { Disable-StmClusteredScheduledTask @disableParameters @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'BackupFailed'
                }
            }

            It 'Should throw error if backup file is empty' {
                Mock -CommandName 'Get-Content' -MockWith { return @() }  # Empty file

                $disableParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                { Disable-StmClusteredScheduledTask @disableParameters @commonParameters } | Should -Throw
            }
        }

        Context 'Task Unregistration' {
            It 'Should create CIM session for cluster operations' {
                $disableParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                Disable-StmClusteredScheduledTask @disableParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'TestCluster'
                }
            }

            It 'Should call Unregister-ClusteredScheduledTask with correct parameters' {
                $disableParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                Disable-StmClusteredScheduledTask @disableParameters @commonParameters

                Should -Invoke 'Unregister-ClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                }
            }

            It 'Should verify task removal after unregistration' {
                # Task successfully removed
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith { return $null }

                $disableParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                Disable-StmClusteredScheduledTask @disableParameters @commonParameters

                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                }
            }

            It 'Should throw error if task still exists after unregistration' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{
                        TaskName = 'TestTask'
                        Cluster  = 'TestCluster'
                    }
                }

                $disableParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                { Disable-StmClusteredScheduledTask @disableParameters @commonParameters } | Should -Throw
            }

            It 'Should throw error if unregistration fails' {
                Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith { throw 'Unregister failed' }
                Mock -CommandName 'New-StmError' -MockWith {
                    # Call the real New-StmError with bound parameters
                    & (Get-Command -CommandType 'Function' -Name 'New-StmError') @PesterBoundParameters
                }

                $disableParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                { Disable-StmClusteredScheduledTask @disableParameters @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'UnregisterFailed'
                }
            }
        }

        Context 'Credential Handling' {
            It 'Should pass credentials to Export-StmClusteredScheduledTask' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))

                $disableParameters = @{
                    TaskName   = 'TestTask'
                    Cluster    = 'TestCluster'
                    Credential = $credential
                    Confirm    = $false
                }
                Disable-StmClusteredScheduledTask @disableParameters @commonParameters

                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should pass credentials to New-StmCimSession' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))

                $disableParameters = @{
                    TaskName   = 'TestTask'
                    Cluster    = 'TestCluster'
                    Credential = $credential
                    Confirm    = $false
                }
                Disable-StmClusteredScheduledTask @disableParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should use empty credential as default' {
                $disableParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                Disable-StmClusteredScheduledTask @disableParameters @commonParameters

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

                $disableParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                    Verbose  = $true
                }
                Disable-StmClusteredScheduledTask @disableParameters @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1
            }
        }

        Context 'WhatIf Support' {
            It 'Should not disable task when WhatIf is specified' {
                Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -WhatIf @commonParameters

                Should -Invoke 'Unregister-ClusteredScheduledTask' -Times 0
            }

            It 'Should write verbose cancellation message when WhatIf is specified' {
                $verboseOutput = Disable-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -WhatIf -Verbose @commonParameters 4>&1 |
                    ForEach-Object { $_.ToString() }

                $verboseOutput | Should -Contain 'Operation cancelled by user.'
            }
        }

        Context 'Integration Tests' {
            It 'Should complete full disable workflow successfully' {
                # Arrange
                Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith {
                    if ($PesterBoundParameters.ContainsKey('FilePath')) {
                        # When FilePath is provided, write to the file
                        $mockXml = '<TaskDefinition>MockTaskXML</TaskDefinition>'
                        $outFileParameters = @{
                            FilePath = $PesterBoundParameters.FilePath
                            Encoding = ([System.Text.Encoding]::Unicode)
                        }
                        $mockXml | Out-File @outFileParameters
                    }
                    else {
                        # When no FilePath, return the XML
                        return '<TaskDefinition>MockTaskXML</TaskDefinition>'
                    }
                }
                Mock -CommandName 'Test-Path' -MockWith {
                    return $true
                }
                Mock -CommandName 'Get-Content' -MockWith {
                    return @('line1', 'line2', 'line3')
                }
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    # Task removed successfully
                    return $null
                }

                # Act & Assert
                $disableParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                { Disable-StmClusteredScheduledTask @disableParameters @commonParameters } | Should -Not -Throw

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
