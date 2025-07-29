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
                    [PSCustomObject]@{ Name = 'Node1'; State = 'Up' },
                    [PSCustomObject]@{ Name = 'Node2'; State = 'Down' }
                )
            }

            Mock -CommandName 'Invoke-Command' -MockWith {
                return @(
                    [PSCustomObject]@{ Name = 'Node1'; State = 'Up' }
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

        It 'Should throw an error when the cluster does not exist' {
            { Get-StmClusterNode -Cluster 'InvalidCluster' } | Should -Throw 'Cluster not found'
        }

        It 'Should use provided credentials when specified' {
            $credential = New-Object System.Management.Automation.PSCredential('user', (ConvertTo-SecureString 'password' -AsPlainText -Force))
            $result = Get-StmClusterNode -Cluster 'TestCluster' -Credential $credential
            $result | Should -Be $credential
        }
    }
}
