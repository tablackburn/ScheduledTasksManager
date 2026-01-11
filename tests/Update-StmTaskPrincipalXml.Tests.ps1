BeforeAll {
    $moduleName = 'ScheduledTasksManager'
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\$moduleName\$moduleName.psd1"
    Import-Module -Name $modulePath -Force

    # Import the private function for testing
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\ScheduledTasksManager\Private\Update-StmTaskPrincipalXml.ps1")

    # Base XML template with full Principal
    $script:baseXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><URI>\TestTask</URI></RegistrationInfo>
  <Triggers></Triggers>
  <Principals>
    <Principal>
      <UserId>SYSTEM</UserId>
      <LogonType>ServiceAccount</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings><Enabled>true</Enabled></Settings>
  <Actions><Exec><Command>cmd.exe</Command></Exec></Actions>
</Task>
'@

    # Base XML template without UserId, LogonType, RunLevel but with GroupId to ensure Principal is an element
    $script:minimalPrincipalXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><URI>\TestTask</URI></RegistrationInfo>
  <Triggers></Triggers>
  <Principals>
    <Principal id="Author">
      <GroupId>S-1-5-32-545</GroupId>
    </Principal>
  </Principals>
  <Settings><Enabled>true</Enabled></Settings>
  <Actions><Exec><Command>cmd.exe</Command></Exec></Actions>
</Task>
'@
}

Describe 'Update-StmTaskPrincipalXml' {
    Context 'Function Attributes' {
        It 'Should have mandatory TaskXml parameter' {
            $function = Get-Command -Name Update-StmTaskPrincipalXml
            $function.Parameters['TaskXml'].Attributes.Mandatory | Should -BeTrue
        }

        It 'Should have mandatory Principal parameter' {
            $function = Get-Command -Name Update-StmTaskPrincipalXml
            $function.Parameters['Principal'].Attributes.Mandatory | Should -BeTrue
        }
    }

    Context 'UserId' {
        It 'Should update existing UserId element' {
            $taskXml = [xml]$baseXml
            $mockPrincipal = [PSCustomObject]@{
                UserId = 'DOMAIN\NewUser'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.UserId | Should -Be 'DOMAIN\NewUser'
        }

        It 'Should create UserId element when it does not exist' {
            $taskXml = [xml]$minimalPrincipalXml
            $mockPrincipal = [PSCustomObject]@{
                UserId = 'DOMAIN\NewUser'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.UserId | Should -Be 'DOMAIN\NewUser'
        }
    }

    Context 'LogonType Mapping' {
        BeforeEach {
            $script:taskXml = [xml]$baseXml
        }

        It "Should map 'Password' to 'Password'" {
            $mockPrincipal = [PSCustomObject]@{
                LogonType = 'Password'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.LogonType | Should -Be 'Password'
        }

        It "Should map 'S4U' to 'S4U'" {
            $mockPrincipal = [PSCustomObject]@{
                LogonType = 'S4U'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.LogonType | Should -Be 'S4U'
        }

        It "Should map 'Interactive' to 'InteractiveToken'" {
            $mockPrincipal = [PSCustomObject]@{
                LogonType = 'Interactive'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.LogonType | Should -Be 'InteractiveToken'
        }

        It "Should map 'InteractiveOrPassword' to 'InteractiveTokenOrPassword'" {
            $mockPrincipal = [PSCustomObject]@{
                LogonType = 'InteractiveOrPassword'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.LogonType | Should -Be 'InteractiveTokenOrPassword'
        }

        It "Should map 'ServiceAccount' to 'ServiceAccount'" {
            $mockPrincipal = [PSCustomObject]@{
                LogonType = 'ServiceAccount'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.LogonType | Should -Be 'ServiceAccount'
        }

        It 'Should use original value for unknown LogonType' {
            $mockPrincipal = [PSCustomObject]@{
                LogonType = 'CustomLogonType'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.LogonType | Should -Be 'CustomLogonType'
        }
    }

    Context 'RunLevel Mapping' {
        BeforeEach {
            $script:taskXml = [xml]$baseXml
        }

        It "Should map 'Highest' to 'HighestAvailable'" {
            $mockPrincipal = [PSCustomObject]@{
                RunLevel = 'Highest'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.RunLevel | Should -Be 'HighestAvailable'
        }

        It "Should map 'Limited' to 'LeastPrivilege'" {
            $mockPrincipal = [PSCustomObject]@{
                RunLevel = 'Limited'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.RunLevel | Should -Be 'LeastPrivilege'
        }

        It 'Should use original value for unknown RunLevel' {
            $mockPrincipal = [PSCustomObject]@{
                RunLevel = 'CustomRunLevel'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.RunLevel | Should -Be 'CustomRunLevel'
        }
    }

    Context 'Creating Missing Elements' {
        It 'Should create LogonType element when it does not exist' {
            $taskXml = [xml]$minimalPrincipalXml
            $mockPrincipal = [PSCustomObject]@{
                LogonType = 'Interactive'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.LogonType | Should -Be 'InteractiveToken'
        }

        It 'Should create RunLevel element when it does not exist' {
            $taskXml = [xml]$minimalPrincipalXml
            $mockPrincipal = [PSCustomObject]@{
                RunLevel = 'Highest'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.RunLevel | Should -Be 'HighestAvailable'
        }
    }

    Context 'Multiple Properties' {
        It 'Should update all properties when all are specified' {
            $taskXml = [xml]$baseXml
            $mockPrincipal = [PSCustomObject]@{
                UserId    = 'DOMAIN\Admin'
                LogonType = 'Interactive'
                RunLevel  = 'Highest'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $taskXml.Task.Principals.Principal.UserId | Should -Be 'DOMAIN\Admin'
            $taskXml.Task.Principals.Principal.LogonType | Should -Be 'InteractiveToken'
            $taskXml.Task.Principals.Principal.RunLevel | Should -Be 'HighestAvailable'
        }
    }

    Context 'XML Namespace' {
        It 'Should create elements with correct namespace' {
            $taskXml = [xml]$minimalPrincipalXml
            $mockPrincipal = [PSCustomObject]@{
                UserId = 'TestUser'
            }

            Update-StmTaskPrincipalXml -TaskXml $taskXml -Principal $mockPrincipal

            $expectedNs = 'http://schemas.microsoft.com/windows/2004/02/mit/task'
            $userIdNode = $taskXml.Task.Principals.Principal.SelectSingleNode('*[local-name()="UserId"]')
            $userIdNode.NamespaceURI | Should -Be $expectedNs
        }
    }
}
