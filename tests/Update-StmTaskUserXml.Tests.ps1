BeforeAll {
    $moduleName = 'ScheduledTasksManager'
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\$moduleName\$moduleName.psd1"
    Import-Module -Name $modulePath -Force

    # Import the private function for testing
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\ScheduledTasksManager\Private\Update-StmTaskUserXml.ps1")

    # Base XML template with existing UserId
    $script:baseXmlWithUserId = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><URI>\TestTask</URI></RegistrationInfo>
  <Triggers></Triggers>
  <Principals>
    <Principal>
      <UserId>SYSTEM</UserId>
      <LogonType>ServiceAccount</LogonType>
    </Principal>
  </Principals>
  <Settings><Enabled>true</Enabled></Settings>
  <Actions><Exec><Command>cmd.exe</Command></Exec></Actions>
</Task>
'@

    # Base XML template without UserId
    $script:baseXmlWithoutUserId = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><URI>\TestTask</URI></RegistrationInfo>
  <Triggers></Triggers>
  <Principals>
    <Principal>
      <LogonType>ServiceAccount</LogonType>
    </Principal>
  </Principals>
  <Settings><Enabled>true</Enabled></Settings>
  <Actions><Exec><Command>cmd.exe</Command></Exec></Actions>
</Task>
'@

    # Base XML template without LogonType
    $script:baseXmlWithoutLogonType = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><URI>\TestTask</URI></RegistrationInfo>
  <Triggers></Triggers>
  <Principals>
    <Principal>
      <UserId>SYSTEM</UserId>
    </Principal>
  </Principals>
  <Settings><Enabled>true</Enabled></Settings>
  <Actions><Exec><Command>cmd.exe</Command></Exec></Actions>
</Task>
'@
}

Describe 'Update-StmTaskUserXml' {
    Context 'Function Attributes' {
        It 'Should have mandatory TaskXml parameter' {
            $function = Get-Command -Name Update-StmTaskUserXml
            $function.Parameters['TaskXml'].Attributes.Mandatory | Should -BeTrue
        }

        It 'Should have mandatory User parameter' {
            $function = Get-Command -Name Update-StmTaskUserXml
            $function.Parameters['User'].Attributes.Mandatory | Should -BeTrue
        }

        It 'Should have optional SetPasswordLogonType switch' {
            $function = Get-Command -Name Update-StmTaskUserXml
            $function.Parameters['SetPasswordLogonType'].Attributes.Mandatory | Should -BeFalse
            $function.Parameters['SetPasswordLogonType'].SwitchParameter | Should -BeTrue
        }
    }

    Context 'User Update' {
        It 'Should update existing UserId element' {
            $taskXml = [xml]$baseXmlWithUserId

            Update-StmTaskUserXml -TaskXml $taskXml -User 'DOMAIN\NewUser'

            $taskXml.Task.Principals.Principal.UserId | Should -Be 'DOMAIN\NewUser'
        }

        It 'Should create UserId element when it does not exist' {
            $taskXml = [xml]$baseXmlWithoutUserId

            Update-StmTaskUserXml -TaskXml $taskXml -User 'DOMAIN\NewUser'

            $taskXml.Task.Principals.Principal.UserId | Should -Be 'DOMAIN\NewUser'
        }
    }

    Context 'Password LogonType' {
        It 'Should set LogonType to Password when SetPasswordLogonType is specified' {
            $taskXml = [xml]$baseXmlWithUserId

            Update-StmTaskUserXml -TaskXml $taskXml -User 'DOMAIN\ServiceAccount' -SetPasswordLogonType

            $taskXml.Task.Principals.Principal.LogonType | Should -Be 'Password'
        }

        It 'Should not modify LogonType when SetPasswordLogonType is not specified' {
            $taskXml = [xml]$baseXmlWithUserId

            Update-StmTaskUserXml -TaskXml $taskXml -User 'DOMAIN\NewUser'

            $taskXml.Task.Principals.Principal.LogonType | Should -Be 'ServiceAccount'
        }

        It 'Should create LogonType element when it does not exist and SetPasswordLogonType specified' {
            $taskXml = [xml]$baseXmlWithoutLogonType

            Update-StmTaskUserXml -TaskXml $taskXml -User 'DOMAIN\ServiceAccount' -SetPasswordLogonType

            $taskXml.Task.Principals.Principal.LogonType | Should -Be 'Password'
        }
    }

    Context 'XML Namespace' {
        It 'Should create UserId element with correct namespace when missing' {
            $taskXml = [xml]$baseXmlWithoutUserId

            Update-StmTaskUserXml -TaskXml $taskXml -User 'TestUser'

            $expectedNs = 'http://schemas.microsoft.com/windows/2004/02/mit/task'
            $userIdNode = $taskXml.Task.Principals.Principal.SelectSingleNode('*[local-name()="UserId"]')
            $userIdNode.NamespaceURI | Should -Be $expectedNs
        }
    }
}
