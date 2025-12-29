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
    Describe 'Get-StmClusterNode' {
        BeforeEach {
            Mock -CommandName 'Invoke-Command' -MockWith {
                return @(
                    [PSCustomObject]@{
                        Name  = 'Node1'
                        State = 'Up'
                    },
                    [PSCustomObject]@{
                        Name  = 'Node2'
                        State = 'Down'
                    }
                )
            }

            Mock -CommandName 'Invoke-Command' -MockWith {
                return @(
                    [PSCustomObject]@{
                        Name  = 'Node1'
                        State = 'Up'
                    }
                )
            } -ParameterFilter {
                $ArgumentList.Name -eq 'Node1'
            }

            Mock -CommandName 'Invoke-Command' -MockWith { throw 'Cluster not found' } -ParameterFilter {
                $ArgumentList.Cluster -eq 'InvalidCluster'
            }

            # Mock Invoke-Command to simulate credential usage and return the credential object
            Mock -CommandName 'Invoke-Command' -MockWith {
                param([System.Management.Automation.PSCredential] $Credential)
                return $Credential
            } -ParameterFilter {
                $null -ne $Credential -and $Credential -ne [System.Management.Automation.PSCredential]::Empty
            }
        }

        Context 'Basic Functionality' {
            It 'Should retrieve all cluster nodes when NodeName is not specified' {
                $result = Get-StmClusterNode -Cluster 'TestCluster'
                $result | Should -Not -BeNullOrEmpty
                $result.Count | Should -Be 2
                $result[0].Name | Should -Be 'Node1'
                $result[1].Name | Should -Be 'Node2'
            }

            It 'Should retrieve specific cluster node when NodeName is specified' {
                $result = Get-StmClusterNode -Cluster 'TestCluster' -NodeName 'Node1'
                $result | Should -Not -BeNullOrEmpty
                $result.Count | Should -Be 1
                $result[0].Name | Should -Be 'Node1'
            }

            It 'Should use provided credentials when specified' {
                $securePassword = ConvertTo-SecureString 'password' -AsPlainText -Force
                $credentialParameters = @{
                    TypeName     = 'System.Management.Automation.PSCredential'
                    ArgumentList = ('user', $securePassword)
                }
                $credential = New-Object @credentialParameters
                $result = Get-StmClusterNode -Cluster 'TestCluster' -Credential $credential
                $result | Should -Be $credential
            }
        }

        Context 'Error Handling' {
            It 'Should throw an error when the cluster does not exist' {
                { Get-StmClusterNode -Cluster 'InvalidCluster' } | Should -Throw
            }

            It 'Should throw error with node-specific message when NodeName is specified' {
                Mock -CommandName 'Invoke-Command' -MockWith {
                    throw 'Node not found'
                } -ParameterFilter {
                    $ArgumentList.Name -eq 'NonExistentNode'
                }
                { Get-StmClusterNode -Cluster 'TestCluster' -NodeName 'NonExistentNode' } |
                    Should -Throw
            }

            It 'Should throw error with cluster-specific message when NodeName is not specified' {
                Mock -CommandName 'Invoke-Command' -MockWith {
                    throw 'Cluster unreachable'
                }
                { Get-StmClusterNode -Cluster 'UnreachableCluster' } | Should -Throw
            }

            It 'Should use New-StmError for error handling' {
                Mock -CommandName 'Invoke-Command' -MockWith {
                    throw 'Connection failed'
                }
                Mock -CommandName 'New-StmError' -MockWith {
                    $record = [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new($Message),
                        $ErrorId,
                        $ErrorCategory,
                        $TargetObject
                    )
                    return $record
                }
                { Get-StmClusterNode -Cluster 'FailingCluster' } | Should -Throw
                Should -Invoke -CommandName 'New-StmError' -Times 1
            }
        }

        Context 'Verbose Output' {
            It 'Should write verbose message for start of operation' {
                $verboseOutput = Get-StmClusterNode -Cluster 'TestCluster' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'Starting Get-StmClusterNode for cluster'
            }

            It 'Should write verbose message for completion' {
                $verboseOutput = Get-StmClusterNode -Cluster 'TestCluster' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'Completed Get-StmClusterNode for cluster'
            }

            It 'Should write verbose message when retrieving all nodes' {
                $verboseOutput = Get-StmClusterNode -Cluster 'TestCluster' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'Retrieving information for all nodes in the cluster'
            }

            It 'Should write verbose message when retrieving specific node' {
                $verboseOutput = Get-StmClusterNode -Cluster 'TestCluster' -NodeName 'Node1' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match "Retrieving information for specific node.*Node1"
            }

            It 'Should write verbose message when credentials are provided' {
                $securePassword = ConvertTo-SecureString 'password' -AsPlainText -Force
                $credential = [PSCredential]::new('user', $securePassword)
                $verboseOutput = Get-StmClusterNode -Cluster 'TestCluster' -Credential $credential -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'Using provided credentials for the remote command'
            }

            It 'Should write verbose message for executing command' {
                $verboseOutput = Get-StmClusterNode -Cluster 'TestCluster' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'Executing command to retrieve cluster node information'
            }

            It 'Should write verbose message with node count' {
                $verboseOutput = Get-StmClusterNode -Cluster 'TestCluster' -Verbose 4>&1 |
                    Out-String
                $verboseOutput | Should -Match 'Successfully retrieved information for \d+ cluster node'
            }
        }

        Context 'Parameter Validation' {
            It 'Should require Cluster parameter' {
                { Get-StmClusterNode } | Should -Throw
            }

            It 'Should pass NodeName to Invoke-Command when specified' {
                Get-StmClusterNode -Cluster 'TestCluster' -NodeName 'Node1'
                Should -Invoke -CommandName 'Invoke-Command' -Times 1 -ParameterFilter {
                    $ArgumentList.Name -eq 'Node1'
                }
            }

            It 'Should pass Cluster to Invoke-Command' {
                Get-StmClusterNode -Cluster 'TestCluster'
                Should -Invoke -CommandName 'Invoke-Command' -Times 1 -ParameterFilter {
                    $ComputerName -eq 'TestCluster'
                }
            }
        }
    }
}
