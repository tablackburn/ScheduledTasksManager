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
    Describe 'Set-StmClusteredScheduledTask' {
        BeforeEach {
            # Create properly typed Action using built-in cmdlet
            $script:mockAction = New-ScheduledTaskAction -Execute 'notepad.exe' -Argument '-test'

            # Create properly typed Trigger using built-in cmdlet
            $script:mockTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours(1)

            # Create properly typed Settings using built-in cmdlet
            $script:mockSettings = New-ScheduledTaskSettingsSet

            # Create properly typed Principal using built-in cmdlet
            $script:mockPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

            # Create mock InputObject (clustered task)
            $script:mockClusteredTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                'MSFT_ClusteredScheduledTask',
                'Root/Microsoft/Windows/TaskScheduler'
            )
            $mockTaskNameProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                'TaskName',
                'TestClusteredTask',
                [Microsoft.Management.Infrastructure.CimType]::String,
                [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                    [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
            )
            $script:mockClusteredTask.CimInstanceProperties.Add($mockTaskNameProperty)

            # Mock external dependencies
            Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith {
                return @'
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <Actions>
        <Exec>
            <Command>cmd.exe</Command>
            <Arguments>/c echo test</Arguments>
        </Exec>
    </Actions>
    <Triggers>
        <TimeTrigger>
            <StartBoundary>2024-01-01T00:00:00</StartBoundary>
            <Enabled>true</Enabled>
        </TimeTrigger>
    </Triggers>
    <Principals>
        <Principal>
            <UserId>SYSTEM</UserId>
            <LogonType>ServiceAccount</LogonType>
            <RunLevel>HighestAvailable</RunLevel>
        </Principal>
    </Principals>
    <Settings>
        <Enabled>true</Enabled>
        <AllowStartOnDemand>true</AllowStartOnDemand>
        <Hidden>false</Hidden>
    </Settings>
</Task>
'@
            }

            Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                return [PSCustomObject]@{
                    TaskName                     = 'TestClusteredTask'
                    ClusteredScheduledTaskObject = [PSCustomObject]@{
                        TaskName = 'TestClusteredTask'
                        TaskType = 'ClusterWide'
                    }
                }
            }

            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'mock-cim-session'
            }

            Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith { }

            Mock -CommandName 'Register-StmClusteredScheduledTask' -MockWith {
                return [PSCustomObject]@{
                    TaskName = 'TestClusteredTask'
                }
            }

            Mock -CommandName 'Write-Warning' -MockWith { }
            Mock -CommandName 'Write-Verbose' -MockWith { }
        }

        BeforeAll {
            $script:commonParameters = @{
                WarningAction     = 'SilentlyContinue'
                InformationAction = 'SilentlyContinue'
            }
        }

        Context 'Function Attributes' {
            It 'Should have ConfirmImpact set to Medium' {
                $function = Get-Command -Name 'Set-StmClusteredScheduledTask'
                $confirmImpact = $function.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments | Where-Object {
                    $_.ArgumentName -eq 'ConfirmImpact'
                }
                $confirmImpact.Argument.Value | Should -Be 'Medium'
            }

            It 'Should support ShouldProcess' {
                $function = Get-Command -Name 'Set-StmClusteredScheduledTask'
                $function.Parameters.ContainsKey('WhatIf') | Should -Be $true
                $function.Parameters.ContainsKey('Confirm') | Should -Be $true
            }

            It 'Should have correct parameter sets' {
                $function = Get-Command -Name 'Set-StmClusteredScheduledTask'
                $function.ParameterSets.Name | Should -Contain 'ByName'
                $function.ParameterSets.Name | Should -Contain 'ByInputObject'
            }

            It 'Should have ByName as default parameter set' {
                $function = Get-Command -Name 'Set-StmClusteredScheduledTask'
                $function.DefaultParameterSet | Should -Be 'ByName'
            }
        }

        Context 'Parameter Validation' {
            It 'Should throw when Principal and User are both specified' {
                {
                    Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Principal $mockPrincipal -User 'TestUser' -Confirm:$false @commonParameters
                } | Should -Throw '*Principal parameter cannot be used with the User parameter*'
            }

            It 'Should throw when Password parameter is specified with User' {
                {
                    Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -User 'TestUser' -Password 'TestPass' -Confirm:$false @commonParameters
                } | Should -Throw '*Password parameter is not supported for clustered scheduled tasks*'
            }

            It 'Should throw when Password parameter is specified with Action' {
                {
                    Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Password 'TestPass' -Confirm:$false @commonParameters
                } | Should -Throw '*Password parameter is not supported for clustered scheduled tasks*'
            }

            It 'Should throw when no modification parameter is specified' {
                {
                    Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Confirm:$false @commonParameters
                } | Should -Throw '*At least one task property*must be specified*'
            }

            It 'Should require Cluster parameter' {
                $function = Get-Command -Name 'Set-StmClusteredScheduledTask'
                $param = $function.Parameters['Cluster']
                $param.Attributes | Where-Object {
                    $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory
                } | Should -Not -BeNullOrEmpty
            }
        }

        Context 'Task Export and XML Processing' {
            It 'Should export task XML before processing' {
                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                }
            }

            It 'Should throw terminating error when export fails' {
                Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith { return $null }

                {
                    Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Confirm:$false @commonParameters
                } | Should -Throw
            }
        }

        Context 'Action Modification' {
            It 'Should modify Actions in task XML when Action parameter is specified' {
                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<Command>notepad.exe</Command>*'
                }
            }

            It 'Should include Arguments in task XML when Action has Arguments' {
                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<Arguments>-test</Arguments>*'
                }
            }

            It 'Should include WorkingDirectory in task XML when Action has WorkingDirectory' {
                $actionWithWorkingDir = New-ScheduledTaskAction -Execute 'notepad.exe' -WorkingDirectory 'C:\Temp'

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $actionWithWorkingDir -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<WorkingDirectory>C:\Temp</WorkingDirectory>*'
                }
            }
        }

        Context 'Trigger Modification' {
            It 'Should modify Triggers in task XML when Trigger parameter is specified' {
                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Trigger $mockTrigger -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1
            }

            It 'Should handle Daily trigger type' {
                $dailyTrigger = New-ScheduledTaskTrigger -Daily -At '3:00 AM'

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Trigger $dailyTrigger -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<CalendarTrigger*' -and $Xml -like '*<ScheduleByDay*' -and $Xml -like '*<DaysInterval>*'
                }
            }

            It 'Should handle Weekly trigger type' {
                $weeklyTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At '3:00 AM'

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Trigger $weeklyTrigger -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<CalendarTrigger*' -and $Xml -like '*<ScheduleByWeek*'
                }
            }

            It 'Should handle Once trigger type (TimeTrigger)' {
                $onceTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours(1)

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Trigger $onceTrigger -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<TimeTrigger*'
                }
            }

            It 'Should handle AtLogon trigger type' {
                $logonTrigger = New-ScheduledTaskTrigger -AtLogon

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Trigger $logonTrigger -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<LogonTrigger*'
                }
            }

            It 'Should handle AtStartup trigger type' {
                $bootTrigger = New-ScheduledTaskTrigger -AtStartup

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Trigger $bootTrigger -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<BootTrigger*'
                }
            }

            It 'Should set trigger Enabled status to false when trigger is disabled' {
                $disabledTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours(1)
                $disabledTrigger.Enabled = $false

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Trigger $disabledTrigger -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<Enabled>false</Enabled>*'
                }
            }

            It 'Should include StartBoundary when trigger has StartBoundary' {
                $triggerWithStart = New-ScheduledTaskTrigger -Once -At '2024-06-15T10:00:00'

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Trigger $triggerWithStart -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<StartBoundary>*'
                }
            }
        }

        Context 'Settings Modification' {
            It 'Should modify Settings in task XML when Settings parameter is specified' {
                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Settings $mockSettings -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1
            }

            It 'Should handle Priority setting' {
                $settingsWithPriority = New-ScheduledTaskSettingsSet -Priority 5

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Settings $settingsWithPriority -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<Priority>5</Priority>*'
                }
            }

            It 'Should handle ExecutionTimeLimit setting' {
                $settingsWithLimit = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2)

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Settings $settingsWithLimit -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<ExecutionTimeLimit>*'
                }
            }

            It 'Should handle boolean settings properties' {
                $settingsWithBools = New-ScheduledTaskSettingsSet -Hidden -WakeToRun -RunOnlyIfNetworkAvailable

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Settings $settingsWithBools -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1
            }
        }

        Context 'Principal Modification' {
            It 'Should modify Principal UserId in task XML' {
                $principal = New-ScheduledTaskPrincipal -UserId 'DOMAIN\AdminUser' -LogonType Password

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Principal $principal -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<UserId>DOMAIN\AdminUser</UserId>*'
                }
            }

            It 'Should handle S4U LogonType' {
                $principal = New-ScheduledTaskPrincipal -UserId 'DOMAIN\User' -LogonType S4U

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Principal $principal -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<LogonType>S4U</LogonType>*'
                }
            }

            It 'Should handle Interactive LogonType' {
                $principal = New-ScheduledTaskPrincipal -UserId 'DOMAIN\User' -LogonType Interactive

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Principal $principal -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<LogonType>InteractiveToken</LogonType>*'
                }
            }

            It 'Should handle InteractiveOrPassword LogonType' {
                $principal = New-ScheduledTaskPrincipal -UserId 'DOMAIN\User' -LogonType InteractiveOrPassword

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Principal $principal -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<LogonType>InteractiveTokenOrPassword</LogonType>*'
                }
            }

            It 'Should handle ServiceAccount LogonType' {
                $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Principal $principal -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<LogonType>ServiceAccount</LogonType>*'
                }
            }

            It 'Should handle Highest RunLevel' {
                $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Principal $principal -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<RunLevel>HighestAvailable</RunLevel>*'
                }
            }

            It 'Should handle Limited RunLevel' {
                $principal = New-ScheduledTaskPrincipal -UserId 'DOMAIN\User' -LogonType Password -RunLevel Limited

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Principal $principal -Confirm:$false @commonParameters

                # Verify registration was called (RunLevel is handled internally)
                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1
            }
        }

        Context 'User Modification' {
            It 'Should modify User in task XML when User parameter is specified' {
                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -User 'DOMAIN\TestUser' -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<UserId>DOMAIN\TestUser</UserId>*'
                }
            }

            It 'Should create new UserId node when not present in XML' {
                # Use mock XML without UserId node
                Mock -CommandName 'Export-StmClusteredScheduledTask' -MockWith {
                    return @'
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <Actions>
        <Exec>
            <Command>cmd.exe</Command>
        </Exec>
    </Actions>
    <Triggers>
        <TimeTrigger>
            <StartBoundary>2024-01-01T00:00:00</StartBoundary>
            <Enabled>true</Enabled>
        </TimeTrigger>
    </Triggers>
    <Principals>
        <Principal>
            <LogonType>ServiceAccount</LogonType>
        </Principal>
    </Principals>
    <Settings>
        <Enabled>true</Enabled>
    </Settings>
</Task>
'@
                }

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -User 'NewUser' -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Xml -like '*<UserId>NewUser</UserId>*'
                }
            }
        }

        Context 'TaskType Modification' {
            It 'Should preserve original TaskType when not specified' {
                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskType -eq 'ClusterWide'
                }
            }

            It 'Should use specified TaskType when provided' {
                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -TaskType 'AnyNode' -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskType -eq 'AnyNode'
                }
            }
        }

        Context 'Pipeline Support' {
            It 'Should accept CimInstance from pipeline' {
                $mockClusteredTask | Set-StmClusteredScheduledTask -Cluster 'TestCluster' -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestClusteredTask'
                }
            }

            It 'Should extract TaskName from InputObject' {
                $mockClusteredTask | Set-StmClusteredScheduledTask -Cluster 'TestCluster' -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestClusteredTask'
                }
            }
        }

        Context 'Task Unregistration and Re-registration' {
            It 'Should create CIM session for cluster operations' {
                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'TestCluster'
                }
            }

            It 'Should unregister task before re-registration' {
                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Unregister-ClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask'
                }
            }

            It 'Should re-register task with modified XML' {
                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                }
            }
        }

        Context 'PassThru Functionality' {
            It 'Should return task object when PassThru is specified' {
                $result = Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -PassThru -Confirm:$false @commonParameters

                $result | Should -Not -BeNullOrEmpty
            }

            It 'Should not return task object when PassThru is not specified' {
                $result = Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Confirm:$false @commonParameters

                $result | Should -BeNullOrEmpty
            }

            It 'Should call Get-StmClusteredScheduledTask for PassThru result' {
                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -PassThru -Confirm:$false @commonParameters

                # Get is called twice: once for TaskType retrieval, once for PassThru
                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 2
            }
        }

        Context 'Credential Handling' {
            It 'Should pass credentials to Export-StmClusteredScheduledTask' {
                $securePassword = ConvertTo-SecureString -String 'TestPass' -AsPlainText -Force
                $credential = New-Object -TypeName 'PSCredential' -ArgumentList 'TestUser', $securePassword

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should pass credentials to Get-StmClusteredScheduledTask' {
                $securePassword = ConvertTo-SecureString -String 'TestPass' -AsPlainText -Force
                $credential = New-Object -TypeName PSCredential -ArgumentList 'TestUser', $securePassword

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should pass credentials to New-StmCimSession' {
                $securePassword = ConvertTo-SecureString -String 'TestPass' -AsPlainText -Force
                $credential = New-Object -TypeName 'PSCredential' -ArgumentList 'TestUser', $securePassword

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should pass credentials to Register-StmClusteredScheduledTask' {
                $securePassword = ConvertTo-SecureString -String 'TestPass' -AsPlainText -Force
                $credential = New-Object -TypeName 'PSCredential' -ArgumentList 'TestUser', $securePassword

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }
        }

        Context 'Error Handling' {
            It 'Should throw terminating error when Set fails' {
                Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith {
                    throw 'Unregister failed'
                }

                {
                    Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Confirm:$false @commonParameters
                } | Should -Throw
            }

            It 'Should use New-StmError for error handling' {
                Mock -CommandName 'Unregister-ClusteredScheduledTask' -MockWith {
                    throw 'Test error'
                }
                Mock -CommandName 'New-StmError' -MockWith {
                    return [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new('Test error'),
                        'ClusteredScheduledTaskSetFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        'TestTask'
                    )
                }

                { Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Confirm:$false @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'ClusteredScheduledTaskSetFailed'
                }
            }
        }

        Context 'WhatIf and Confirm Support' {
            It 'Should not modify task when WhatIf is specified' {
                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -WhatIf @commonParameters

                Should -Invoke 'Unregister-ClusteredScheduledTask' -Times 0
                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 0
            }
        }

        Context 'Verbose Output' {
            It 'Should write verbose messages for key operations' {
                Mock -CommandName 'Write-Verbose' -MockWith { }

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Verbose -Confirm:$false @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -eq 'Starting Set-StmClusteredScheduledTask'
                }
            }

            It 'Should write completion message in end block' {
                Mock -CommandName 'Write-Verbose' -MockWith { }

                Set-StmClusteredScheduledTask -TaskName 'TestTask' -Cluster 'TestCluster' -Action $mockAction -Verbose -Confirm:$false @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like '*Completed Set-StmClusteredScheduledTask*'
                }
            }
        }

        Context 'Integration Tests' {
            It 'Should complete full set workflow successfully' {
                $setParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Action   = $mockAction
                    Confirm  = $false
                }
                { Set-StmClusteredScheduledTask @setParameters @commonParameters } | Should -Not -Throw

                # Verify all steps were executed in correct order
                Should -Invoke 'Export-StmClusteredScheduledTask' -Times 1
                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 1
                Should -Invoke 'New-StmCimSession' -Times 1
                Should -Invoke 'Unregister-ClusteredScheduledTask' -Times 1
                Should -Invoke 'Register-StmClusteredScheduledTask' -Times 1
            }
        }
    }
}
