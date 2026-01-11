BeforeAll {
    $moduleName = 'ScheduledTasksManager'
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\$moduleName\$moduleName.psd1"
    Import-Module -Name $modulePath -Force

    # Import the private function for testing
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\ScheduledTasksManager\Private\Update-StmTaskActionXml.ps1")

    # Base XML template for tests
    $script:baseXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><URI>\TestTask</URI></RegistrationInfo>
  <Triggers></Triggers>
  <Principals><Principal><UserId>SYSTEM</UserId></Principal></Principals>
  <Settings><Enabled>true</Enabled></Settings>
  <Actions>
    <Exec>
      <Command>cmd.exe</Command>
      <Arguments>/c echo existing</Arguments>
    </Exec>
  </Actions>
</Task>
'@
}

Describe 'Update-StmTaskActionXml' {
    Context 'Function Attributes' {
        It 'Should have mandatory TaskXml parameter' {
            $function = Get-Command -Name Update-StmTaskActionXml
            $function.Parameters['TaskXml'].Attributes.Mandatory | Should -BeTrue
        }

        It 'Should have mandatory Action parameter' {
            $function = Get-Command -Name Update-StmTaskActionXml
            $function.Parameters['Action'].Attributes.Mandatory | Should -BeTrue
        }

        It 'Should have ValidateNotNull on TaskXml parameter' {
            $function = Get-Command -Name Update-StmTaskActionXml
            $function.Parameters['TaskXml'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateNotNullAttribute] } |
                Should -Not -BeNullOrEmpty
        }

        It 'Should have ValidateNotNullOrEmpty on Action parameter' {
            $function = Get-Command -Name Update-StmTaskActionXml
            $function.Parameters['Action'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateNotNullOrEmptyAttribute] } |
                Should -Not -BeNullOrEmpty
        }

        It 'Should reject empty array for Action parameter' {
            $taskXml = [xml]$baseXml
            { Update-StmTaskActionXml -TaskXml $taskXml -Action @() } |
                Should -Throw '*cannot validate argument*empty*'
        }
    }

    Context 'Action Replacement' {
        BeforeEach {
            $script:taskXml = [xml]$baseXml
        }

        It 'Should remove existing Exec actions from XML' {
            $mockAction = [PSCustomObject]@{
                Execute = 'powershell.exe'
            }

            Update-StmTaskActionXml -TaskXml $taskXml -Action @($mockAction)

            $execNodes = @($taskXml.Task.Actions.ChildNodes | Where-Object { $_.LocalName -eq 'Exec' })
            $execNodes.Count | Should -Be 1
            $execNodes[0].Command | Should -Be 'powershell.exe'
        }

        It 'Should add new Exec action with Command element' {
            $mockAction = [PSCustomObject]@{
                Execute = 'notepad.exe'
            }

            Update-StmTaskActionXml -TaskXml $taskXml -Action @($mockAction)

            $taskXml.Task.Actions.Exec.Command | Should -Be 'notepad.exe'
        }

        It 'Should add Arguments element when provided' {
            $mockAction = [PSCustomObject]@{
                Execute   = 'powershell.exe'
                Arguments = '-File C:\Scripts\Test.ps1'
            }

            Update-StmTaskActionXml -TaskXml $taskXml -Action @($mockAction)

            $taskXml.Task.Actions.Exec.Arguments | Should -Be '-File C:\Scripts\Test.ps1'
        }

        It 'Should add WorkingDirectory element when provided' {
            $mockAction = [PSCustomObject]@{
                Execute          = 'powershell.exe'
                WorkingDirectory = 'C:\Scripts'
            }

            Update-StmTaskActionXml -TaskXml $taskXml -Action @($mockAction)

            $taskXml.Task.Actions.Exec.WorkingDirectory | Should -Be 'C:\Scripts'
        }

        It 'Should omit Arguments element when not provided' {
            $mockAction = [PSCustomObject]@{
                Execute = 'notepad.exe'
            }

            Update-StmTaskActionXml -TaskXml $taskXml -Action @($mockAction)

            $taskXml.Task.Actions.Exec.Arguments | Should -BeNullOrEmpty
        }

        It 'Should omit WorkingDirectory element when not provided' {
            $mockAction = [PSCustomObject]@{
                Execute = 'notepad.exe'
            }

            Update-StmTaskActionXml -TaskXml $taskXml -Action @($mockAction)

            $taskXml.Task.Actions.Exec.WorkingDirectory | Should -BeNullOrEmpty
        }
    }

    Context 'Multiple Actions' {
        BeforeEach {
            $script:taskXml = [xml]$baseXml
        }

        It 'Should handle multiple actions in array' {
            $mockActions = @(
                [PSCustomObject]@{ Execute = 'first.exe' }
                [PSCustomObject]@{ Execute = 'second.exe' }
                [PSCustomObject]@{ Execute = 'third.exe' }
            )

            Update-StmTaskActionXml -TaskXml $taskXml -Action $mockActions

            $execNodes = @($taskXml.Task.Actions.ChildNodes | Where-Object { $_.LocalName -eq 'Exec' })
            $execNodes.Count | Should -Be 3
        }

        It 'Should preserve action order' {
            $mockActions = @(
                [PSCustomObject]@{ Execute = 'first.exe' }
                [PSCustomObject]@{ Execute = 'second.exe' }
                [PSCustomObject]@{ Execute = 'third.exe' }
            )

            Update-StmTaskActionXml -TaskXml $taskXml -Action $mockActions

            $execNodes = @($taskXml.Task.Actions.ChildNodes | Where-Object { $_.LocalName -eq 'Exec' })
            $execNodes[0].Command | Should -Be 'first.exe'
            $execNodes[1].Command | Should -Be 'second.exe'
            $execNodes[2].Command | Should -Be 'third.exe'
        }
    }

    Context 'XML Namespace' {
        BeforeEach {
            $script:taskXml = [xml]$baseXml
        }

        It 'Should create elements with correct namespace URI' {
            $mockAction = [PSCustomObject]@{
                Execute   = 'test.exe'
                Arguments = '-test'
            }

            Update-StmTaskActionXml -TaskXml $taskXml -Action @($mockAction)

            $expectedNs = 'http://schemas.microsoft.com/windows/2004/02/mit/task'
            $execNode = $taskXml.Task.Actions.SelectSingleNode('*[local-name()="Exec"]')
            $execNode.NamespaceURI | Should -Be $expectedNs
            $cmdNode = $execNode.SelectSingleNode('*[local-name()="Command"]')
            $cmdNode.NamespaceURI | Should -Be $expectedNs
        }
    }
}
