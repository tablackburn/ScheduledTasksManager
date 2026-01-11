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
    Describe 'Set-StmScheduledTask' {
        BeforeEach {
            $mockTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                'MSFT_ScheduledTask',
                'Root/Microsoft/Windows/TaskScheduler'
            )
            $mockTaskNameProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                'TaskName',
                'TestTask1',
                [Microsoft.Management.Infrastructure.CimType]::String,
                [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                    [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
            )
            $mockTaskPathProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                'TaskPath',
                '\',
                [Microsoft.Management.Infrastructure.CimType]::String,
                [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                    [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
            )
            $mockURIProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                'URI',
                '\TestTask1',
                [Microsoft.Management.Infrastructure.CimType]::String,
                [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                    [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
            )
            $mockStateProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                'State',
                'Ready',
                [Microsoft.Management.Infrastructure.CimType]::String,
                [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                    [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
            )
            $mockTask.CimInstanceProperties.Add($mockTaskNameProperty)
            $mockTask.CimInstanceProperties.Add($mockTaskPathProperty)
            $mockTask.CimInstanceProperties.Add($mockURIProperty)
            $mockTask.CimInstanceProperties.Add($mockStateProperty)

            # Create properly typed Action using built-in cmdlet
            $mockAction = New-ScheduledTaskAction -Execute 'notepad.exe' -Argument '-test'

            # Create properly typed Trigger using built-in cmdlet
            $mockTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours(1)

            # Create properly typed Settings using built-in cmdlet
            $mockSettings = New-ScheduledTaskSettingsSet

            # Create properly typed Principal using built-in cmdlet
            $mockPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'this-is-a-mock-cim-session'
            }
            Mock -CommandName 'Set-ScheduledTask' -MockWith {
                return $mockTask
            }
        }

        BeforeAll {
            $script:commonParameters = @{
                WarningAction     = 'SilentlyContinue'
                InformationAction = 'SilentlyContinue'
            }
        }

        Context 'Function Attributes' {
            It 'Should have ConfirmImpact set to Medium' {
                $function = Get-Command -Name 'Set-StmScheduledTask'
                $confirmImpact = $function.ScriptBlock.Ast.Body.ParamBlock.Attributes.NamedArguments | Where-Object {
                    $_.ArgumentName -eq 'ConfirmImpact'
                }
                $confirmImpact.Argument.Value | Should -Be 'Medium'
            }

            It 'Should support ShouldProcess' {
                $function = Get-Command -Name 'Set-StmScheduledTask'
                $function.Parameters.ContainsKey('WhatIf') | Should -Be $true
                $function.Parameters.ContainsKey('Confirm') | Should -Be $true
            }

            It 'Should have correct parameter sets' {
                $function = Get-Command -Name 'Set-StmScheduledTask'
                $function.ParameterSets.Name | Should -Contain 'ByName'
                $function.ParameterSets.Name | Should -Contain 'ByInputObject'
            }

            It 'Should have ByName as default parameter set' {
                $function = Get-Command -Name 'Set-StmScheduledTask'
                $function.DefaultParameterSet | Should -Be 'ByName'
            }
        }

        Context 'Parameter Validation' {
            It 'Should throw when Principal and User are both specified' {
                {
                    Set-StmScheduledTask -TaskName 'TestTask1' -Principal $mockPrincipal -User 'TestUser' -Confirm:$false @commonParameters
                } | Should -Throw '*Principal parameter cannot be used with User or Password*'
            }

            It 'Should throw when Principal and Password are both specified' {
                {
                    Set-StmScheduledTask -TaskName 'TestTask1' -Principal $mockPrincipal -Password 'TestPass' -Confirm:$false @commonParameters
                } | Should -Throw '*Principal parameter cannot be used with User or Password*'
            }

            It 'Should throw when no modification parameter is specified' {
                {
                    Set-StmScheduledTask -TaskName 'TestTask1' -Confirm:$false @commonParameters
                } | Should -Throw '*At least one task property*must be specified*'
            }

            It 'Should accept TaskName as mandatory in ByName parameter set' {
                $function = Get-Command -Name 'Set-StmScheduledTask'
                $param = $function.Parameters['TaskName']
                $byNameAttr = $param.Attributes | Where-Object { $_.ParameterSetName -eq 'ByName' }
                $byNameAttr.Mandatory | Should -Be $true
            }

            It 'Should accept InputObject via pipeline in ByInputObject parameter set' {
                $function = Get-Command -Name 'Set-StmScheduledTask'
                $param = $function.Parameters['InputObject']
                $param.Attributes | Where-Object {
                    $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ValueFromPipeline
                } | Should -Not -BeNullOrEmpty
            }
        }

        Context 'Basic Functionality - Action Parameter' {
            It 'Should modify task Action successfully' {
                Set-StmScheduledTask -TaskName 'TestTask1' -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\' -and $null -ne $Action
                }
            }
        }

        Context 'Basic Functionality - Trigger Parameter' {
            It 'Should modify task Trigger successfully' {
                Set-StmScheduledTask -TaskName 'TestTask1' -Trigger $mockTrigger -Confirm:$false @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $null -ne $Trigger
                }
            }
        }

        Context 'Basic Functionality - Settings Parameter' {
            It 'Should modify task Settings successfully' {
                Set-StmScheduledTask -TaskName 'TestTask1' -Settings $mockSettings -Confirm:$false @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $null -ne $Settings
                }
            }
        }

        Context 'Basic Functionality - Principal Parameter' {
            It 'Should modify task Principal successfully' {
                Set-StmScheduledTask -TaskName 'TestTask1' -Principal $mockPrincipal -Confirm:$false @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $null -ne $Principal
                }
            }
        }

        Context 'Basic Functionality - User/Password Parameters' {
            It 'Should modify task User successfully' {
                Set-StmScheduledTask -TaskName 'TestTask1' -User 'TestUser' -Confirm:$false @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $User -eq 'TestUser'
                }
            }

            It 'Should modify task User and Password successfully' {
                Set-StmScheduledTask -TaskName 'TestTask1' -User 'TestUser' -Password 'TestPass' -Confirm:$false @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $User -eq 'TestUser' -and $Password -eq 'TestPass'
                }
            }
        }

        Context 'Basic Functionality - Multiple Parameters' {
            It 'Should modify multiple properties in single call' {
                Set-StmScheduledTask -TaskName 'TestTask1' -Action $mockAction -Trigger $mockTrigger -Settings $mockSettings -Confirm:$false @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $null -ne $Action -and $null -ne $Trigger -and $null -ne $Settings
                }
            }
        }

        Context 'Basic Functionality - TaskPath and ComputerName' {
            It 'Should use specified TaskPath' {
                $setParameters = @{
                    TaskName = 'TestTask1'
                    TaskPath = '\Custom\Path\'
                    Action   = $mockAction
                    Confirm  = $false
                }
                Set-StmScheduledTask @setParameters @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\Custom\Path\'
                }
            }

            It 'Should use specified ComputerName' {
                $setParameters = @{
                    TaskName     = 'TestTask1'
                    ComputerName = 'Server01'
                    Action       = $mockAction
                    Confirm      = $false
                }
                Set-StmScheduledTask @setParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01'
                }
            }

            It 'Should use provided credentials' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))
                Set-StmScheduledTask -TaskName 'TestTask1' -Action $mockAction -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }
        }

        Context 'Pipeline Support' {
            It 'Should accept CimInstance from pipeline' {
                $mockTask | Set-StmScheduledTask -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\'
                }
            }

            It 'Should default to localhost when InputObject has no PSComputerName' {
                # The mockTask in BeforeEach has no PSComputerName, so it defaults to localhost
                $mockTask | Set-StmScheduledTask -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'localhost'
                }
            }

            It 'Should pass Credential when using InputObject' {
                $credential = [PSCredential]::new('TestUser', ('TestPass' | ConvertTo-SecureString -AsPlainText -Force))

                # Use -InputObject explicitly to ensure ByInputObject parameter set is used
                Set-StmScheduledTask -InputObject $mockTask -Action $mockAction -Credential $credential -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $Credential -eq $credential
                }
            }

            It 'Should use PSComputerName from InputObject when present' {
                # Create a task with PSComputerName property (as NoteProperty, like PowerShell adds for remote objects)
                $remoteTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                    'MSFT_ScheduledTask',
                    'Root/Microsoft/Windows/TaskScheduler'
                )
                $remoteTask.CimInstanceProperties.Add(
                    [Microsoft.Management.Infrastructure.CimProperty]::Create(
                        'TaskName', 'RemoteTask', [Microsoft.Management.Infrastructure.CimType]::String,
                        [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                            [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                    )
                )
                $remoteTask.CimInstanceProperties.Add(
                    [Microsoft.Management.Infrastructure.CimProperty]::Create(
                        'TaskPath', '\', [Microsoft.Management.Infrastructure.CimType]::String,
                        [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                            [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                    )
                )
                # PSComputerName is added by PowerShell as a NoteProperty when objects come from remote sessions
                $remoteTask | Add-Member -NotePropertyName 'PSComputerName' -NotePropertyValue 'RemoteServer01' -Force

                # Use -InputObject explicitly to ensure ByInputObject parameter set is used
                # (Pipeline binding may prefer ByName due to ValueFromPipelineByPropertyName on TaskName)
                Set-StmScheduledTask -InputObject $remoteTask -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'RemoteServer01'
                }
            }

            It 'Should accept InputObject parameter directly (not via pipeline)' {
                Set-StmScheduledTask -InputObject $mockTask -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask1' -and $TaskPath -eq '\'
                }
            }

            It 'Should create CIM session in ByInputObject parameter set' {
                Set-StmScheduledTask -InputObject $mockTask -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'localhost' -and $ErrorAction -eq 'Stop'
                }
            }

            It 'Should cleanup CIM session in ByInputObject parameter set' {
                # Clear the module-scoped variable to ensure we test the ByInputObject cleanup path
                InModuleScope 'ScheduledTasksManager' {
                    $script:cimSession = $null
                }
                Mock -CommandName 'Remove-CimSession' -MockWith { }

                Set-StmScheduledTask -InputObject $mockTask -Action $mockAction -Confirm:$false @commonParameters

                # In ByInputObject, $script:cimSession is never set (null), so only line 394 should call Remove-CimSession
                Should -Invoke 'Remove-CimSession' -Times 1
            }

            It 'Should process multiple tasks from pipeline' {
                $mockTask2 = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                    'MSFT_ScheduledTask',
                    'Root/Microsoft/Windows/TaskScheduler'
                )
                $mockTask2NameProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                    'TaskName',
                    'TestTask2',
                    [Microsoft.Management.Infrastructure.CimType]::String,
                    [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                        [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                )
                $mockTask2PathProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                    'TaskPath',
                    '\',
                    [Microsoft.Management.Infrastructure.CimType]::String,
                    [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                        [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                )
                $mockTask2.CimInstanceProperties.Add($mockTask2NameProperty)
                $mockTask2.CimInstanceProperties.Add($mockTask2PathProperty)

                @($mockTask, $mockTask2) | Set-StmScheduledTask -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 2
            }

            It 'Should extract TaskName and TaskPath from InputObject' {
                $customPathTask = New-Object -TypeName 'Microsoft.Management.Infrastructure.CimInstance' -ArgumentList @(
                    'MSFT_ScheduledTask',
                    'Root/Microsoft/Windows/TaskScheduler'
                )
                $customTaskNameProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                    'TaskName',
                    'CustomTask',
                    [Microsoft.Management.Infrastructure.CimType]::String,
                    [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                        [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                )
                $customTaskPathProperty = [Microsoft.Management.Infrastructure.CimProperty]::Create(
                    'TaskPath',
                    '\Custom\Folder\',
                    [Microsoft.Management.Infrastructure.CimType]::String,
                    [Microsoft.Management.Infrastructure.CimFlags]::Property -bor
                        [Microsoft.Management.Infrastructure.CimFlags]::ReadOnly
                )
                $customPathTask.CimInstanceProperties.Add($customTaskNameProperty)
                $customPathTask.CimInstanceProperties.Add($customTaskPathProperty)

                $customPathTask | Set-StmScheduledTask -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'CustomTask' -and $TaskPath -eq '\Custom\Folder\'
                }
            }
        }

        Context 'PassThru Functionality' {
            It 'Should return task object when PassThru is specified' {
                $result = Set-StmScheduledTask -TaskName 'TestTask1' -Action $mockAction -PassThru -Confirm:$false @commonParameters

                $result | Should -Not -BeNullOrEmpty
                $result.TaskName | Should -Be 'TestTask1'
                Should -Invoke 'Set-ScheduledTask' -Times 1
            }

            It 'Should not return task object when PassThru is not specified' {
                $result = Set-StmScheduledTask -TaskName 'TestTask1' -Action $mockAction -Confirm:$false @commonParameters

                $result | Should -BeNullOrEmpty
                Should -Invoke 'Set-ScheduledTask' -Times 1
            }
        }

        Context 'Error Handling' {
            It 'Should throw terminating error when Set-ScheduledTask fails' {
                Mock -CommandName 'Set-ScheduledTask' -MockWith {
                    throw 'Set-ScheduledTask failed'
                }

                { Set-StmScheduledTask -TaskName 'TestTask1' -Action $mockAction -Confirm:$false @commonParameters } | Should -Throw
            }

            It 'Should use New-StmError for error handling' {
                Mock -CommandName 'Set-ScheduledTask' -MockWith {
                    throw 'Test error'
                }
                Mock -CommandName 'New-StmError' -MockWith {
                    return [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new('Test error'),
                        'ScheduledTaskSetFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        'TestTask1'
                    )
                }

                { Set-StmScheduledTask -TaskName 'TestTask1' -Action $mockAction -Confirm:$false @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'ScheduledTaskSetFailed'
                }
            }

            It 'Should include proper ErrorId in error records for validation errors' {
                Mock -CommandName 'New-StmError' -MockWith {
                    param($ErrorId)
                    return [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new('Test error'),
                        $ErrorId,
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $null
                    )
                }

                { Set-StmScheduledTask -TaskName 'TestTask1' -Principal $mockPrincipal -User 'TestUser' -Confirm:$false @commonParameters } | Should -Throw

                Should -Invoke 'New-StmError' -Times 1 -ParameterFilter {
                    $ErrorId -eq 'InvalidParameterCombination'
                }
            }
        }

        Context 'CIM Session Management' {
            It 'Should create CIM session with correct parameters' {
                $setParameters = @{
                    TaskName     = 'TestTask1'
                    ComputerName = 'Server01'
                    Action       = $mockAction
                    Confirm      = $false
                }
                Set-StmScheduledTask @setParameters @commonParameters

                Should -Invoke 'New-StmCimSession' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'Server01' -and $ErrorAction -eq 'Stop'
                }
            }

            It 'Should pass CIM session to Set-ScheduledTask' {
                Set-StmScheduledTask -TaskName 'TestTask1' -Action $mockAction -Confirm:$false @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 1
            }
        }

        Context 'WhatIf and Confirm Support' {
            It 'Should not modify task when WhatIf is specified' {
                Set-StmScheduledTask -TaskName 'TestTask1' -Action $mockAction -WhatIf @commonParameters

                Should -Invoke 'Set-ScheduledTask' -Times 0
            }
        }

        Context 'Verbose Output' {
            It 'Should write verbose messages during execution' {
                Mock -CommandName 'Write-Verbose' -MockWith {}

                Set-StmScheduledTask -TaskName 'TestTask1' -Action $mockAction -Confirm:$false -Verbose @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -eq 'Starting Set-StmScheduledTask'
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Modifying scheduled task*"
                }
                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like "*Completed Set-StmScheduledTask*"
                }
            }
        }
    }
}
