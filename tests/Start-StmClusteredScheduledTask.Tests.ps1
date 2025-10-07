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
    Describe 'Start-StmClusteredScheduledTask' {
        BeforeEach {
            # Create mock scheduled task CIM object
            $mockedScheduledTaskObjectParameters = @{
                TypeName     = 'Microsoft.Management.Infrastructure.CimInstance'
                ArgumentList = @(
                    # Cim class name (Get using: (Get-ScheduledTask).get_CimClass())
                    'MSFT_ScheduledTask'
                    # Cim namespace (Get using: (Get-ScheduledTask).CimSystemProperties)
                    'Root/Microsoft/Windows/TaskScheduler'
                )
            }
            $script:mockedScheduledTaskObject = New-Object @mockedScheduledTaskObjectParameters

            # Mock Get-StmClusteredScheduledTask
            Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                return [PSCustomObject]@{
                    TaskName            = $TaskName
                    Cluster             = $Cluster
                    ScheduledTaskObject = $script:mockedScheduledTaskObject
                }
            }

            # Mock Start-ScheduledTask
            Mock -CommandName 'Start-ScheduledTask' -MockWith {
                param(
                    [Parameter(ValueFromPipeline)]
                    $InputObject
                )
                # Return nothing, as the actual cmdlet doesn't return output
            }

            # Mock common cmdlets
            Mock -CommandName 'Write-Verbose' -MockWith { }
            Mock -CommandName 'Write-Warning' -MockWith { }
            Mock -CommandName 'Write-Error' -MockWith { }
        }

        BeforeAll {
            $script:commonParameters = @{
                WarningAction     = 'SilentlyContinue'
                InformationAction = 'SilentlyContinue'
            }
        }

        Context 'Function Attributes' {
            It 'Should have CmdletBinding attribute' {
                $function = Get-Command -Name 'Start-StmClusteredScheduledTask'
                $function.CmdletBinding | Should -Be $true
            }

            It 'Should support ShouldProcess' {
                $function = Get-Command -Name 'Start-StmClusteredScheduledTask'
                $function.Parameters.ContainsKey('WhatIf') | Should -Be $true
                $function.Parameters.ContainsKey('Confirm') | Should -Be $true
            }
        }

        Context 'Parameter Validation' {
            It 'Should require TaskName parameter' {
                $function = Get-Command -Name 'Start-StmClusteredScheduledTask'
                $function.Parameters['TaskName'].Attributes.Mandatory | Should -Contain $true
            }

            It 'Should require Cluster parameter' {
                $function = Get-Command -Name 'Start-StmClusteredScheduledTask'
                $function.Parameters['Cluster'].Attributes.Mandatory | Should -Contain $true
            }

            It 'Should not require Credential parameter' {
                $function = Get-Command -Name 'Start-StmClusteredScheduledTask'
                $function.Parameters['Credential'].Attributes.Mandatory | Should -Not -Contain $true
            }

            It 'Should reject null or empty TaskName' {
                $startParameters = @{
                    TaskName = ''
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                { Start-StmClusteredScheduledTask @startParameters @commonParameters } | Should -Throw
            }

            It 'Should reject null or empty Cluster' {
                $startParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = ''
                    Confirm  = $false
                }
                { Start-StmClusteredScheduledTask @startParameters @commonParameters } | Should -Throw
            }
        }

        Context 'Task Retrieval' {
            It 'Should retrieve the clustered scheduled task' {
                $startParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                Start-StmClusteredScheduledTask @startParameters @commonParameters

                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask' -and $Cluster -eq 'TestCluster'
                }
            }

            It 'Should pass Credential parameter to Get-StmClusteredScheduledTask' {
                $mockCredential = [PSCredential]::new(
                    'TestUser',
                    (ConvertTo-SecureString -String 'TestPassword' -AsPlainText -Force)
                )
                $startParameters = @{
                    TaskName   = 'TestTask'
                    Cluster    = 'TestCluster'
                    Credential = $mockCredential
                    Confirm    = $false
                }
                Start-StmClusteredScheduledTask @startParameters @commonParameters

                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'TestTask' -and
                    $Cluster -eq 'TestCluster' -and
                    $Credential -eq $mockCredential
                }
            }

            It 'Should throw error when task retrieval fails' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    throw 'Task not found'
                }

                $startParameters = @{
                    TaskName = 'NonExistentTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                { Start-StmClusteredScheduledTask @startParameters @commonParameters } | Should -Throw
            }
        }

        Context 'Task Starting' {
            It 'Should start the scheduled task' {
                $startParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                Start-StmClusteredScheduledTask @startParameters @commonParameters

                Should -Invoke 'Start-ScheduledTask' -Times 1
            }

            It 'Should pass the correct scheduled task object to Start-ScheduledTask' {
                $startParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                Start-StmClusteredScheduledTask @startParameters @commonParameters

                Should -Invoke 'Start-ScheduledTask' -Times 1 -ParameterFilter {
                    $InputObject -eq $script:mockedScheduledTaskObject
                }
            }

            It 'Should handle Start-ScheduledTask failure' {
                Mock -CommandName 'Start-ScheduledTask' -MockWith {
                    throw 'Failed to start task'
                }

                $startParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                { Start-StmClusteredScheduledTask @startParameters @commonParameters } | Should -Throw
            }
        }

        Context 'ShouldProcess Support' {
            It 'Should not start task when WhatIf is specified' {
                $startParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    WhatIf   = $true
                }
                Start-StmClusteredScheduledTask @startParameters @commonParameters

                Should -Invoke 'Start-ScheduledTask' -Times 0
            }

            It 'Should retrieve task even when WhatIf is specified' {
                $startParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    WhatIf   = $true
                }
                Start-StmClusteredScheduledTask @startParameters @commonParameters

                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 1
            }

            It 'Should respect Confirm parameter' {
                $startParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                { Start-StmClusteredScheduledTask @startParameters @commonParameters } | Should -Not -Throw
            }
        }

        Context 'Verbose Output' {
            It 'Should write verbose output at start' {
                $startParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                Start-StmClusteredScheduledTask @startParameters @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like '*Starting Start-StmClusteredScheduledTask*'
                }
            }

            It 'Should write verbose output at completion' {
                $startParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                Start-StmClusteredScheduledTask @startParameters @commonParameters

                Should -Invoke 'Write-Verbose' -Times 1 -ParameterFilter {
                    $Message -like '*Completed Start-StmClusteredScheduledTask*'
                }
            }
        }

        Context 'Integration Scenarios' {
            It 'Should handle multiple task start operations' {
                $tasks = @('Task1', 'Task2', 'Task3')
                foreach ($task in $tasks) {
                    $startParameters = @{
                        TaskName = $task
                        Cluster  = 'TestCluster'
                        Confirm  = $false
                    }
                    Start-StmClusteredScheduledTask @startParameters @commonParameters
                }

                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 3
                Should -Invoke 'Start-ScheduledTask' -Times 3
            }

            It 'Should work with FQDN cluster names' {
                $startParameters = @{
                    TaskName = 'TestTask'
                    Cluster  = 'TestCluster.contoso.com'
                    Confirm  = $false
                }
                Start-StmClusteredScheduledTask @startParameters @commonParameters

                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $Cluster -eq 'TestCluster.contoso.com'
                }
            }

            It 'Should handle tasks with special characters in name' {
                $startParameters = @{
                    TaskName = 'Test-Task_2025'
                    Cluster  = 'TestCluster'
                    Confirm  = $false
                }
                Start-StmClusteredScheduledTask @startParameters @commonParameters

                Should -Invoke 'Get-StmClusteredScheduledTask' -Times 1 -ParameterFilter {
                    $TaskName -eq 'Test-Task_2025'
                }
            }
        }
    }
}
