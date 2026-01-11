BeforeAll {
    $moduleName = 'ScheduledTasksManager'
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\$moduleName\$moduleName.psd1"
    Import-Module -Name $modulePath -Force

    # Import the private function for testing
    . (Join-Path -Path $PSScriptRoot -ChildPath "..\ScheduledTasksManager\Private\Update-StmTaskSettingsXml.ps1")

    # Base XML template with some settings
    $script:baseXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><URI>\TestTask</URI></RegistrationInfo>
  <Triggers></Triggers>
  <Principals><Principal><UserId>SYSTEM</UserId></Principal></Principals>
  <Settings>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
  </Settings>
  <Actions><Exec><Command>cmd.exe</Command></Exec></Actions>
</Task>
'@

    # Base XML template with minimal settings (need at least one child for PowerShell XML handling)
    $script:minimalSettingsXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><URI>\TestTask</URI></RegistrationInfo>
  <Triggers></Triggers>
  <Principals><Principal><UserId>SYSTEM</UserId></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
  </Settings>
  <Actions><Exec><Command>cmd.exe</Command></Exec></Actions>
</Task>
'@
}

Describe 'Update-StmTaskSettingsXml' {
    Context 'Function Attributes' {
        It 'Should have mandatory TaskXml parameter' {
            $function = Get-Command -Name Update-StmTaskSettingsXml
            $function.Parameters['TaskXml'].Attributes.Mandatory | Should -BeTrue
        }

        It 'Should have mandatory Settings parameter' {
            $function = Get-Command -Name Update-StmTaskSettingsXml
            $function.Parameters['Settings'].Attributes.Mandatory | Should -BeTrue
        }
    }

    Context 'Boolean Settings' {
        BeforeEach {
            $script:taskXml = [xml]$baseXml
        }

        It 'Should update AllowStartOnDemand (mapped from AllowDemandStart)' {
            $mockSettings = [PSCustomObject]@{
                AllowDemandStart = $true
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.AllowStartOnDemand | Should -Be 'true'
        }

        It 'Should update Hidden setting' {
            $mockSettings = [PSCustomObject]@{
                Hidden = $true
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.Hidden | Should -Be 'true'
        }

        It 'Should update Enabled setting' {
            $mockSettings = [PSCustomObject]@{
                Enabled = $false
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.Enabled | Should -Be 'false'
        }

        It 'Should update WakeToRun setting' {
            $mockSettings = [PSCustomObject]@{
                WakeToRun = $true
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.WakeToRun | Should -Be 'true'
        }

        It 'Should update RunOnlyIfNetworkAvailable setting' {
            $mockSettings = [PSCustomObject]@{
                RunOnlyIfNetworkAvailable = $true
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.RunOnlyIfNetworkAvailable | Should -Be 'true'
        }

        It 'Should update DisallowStartIfOnBatteries setting' {
            $mockSettings = [PSCustomObject]@{
                DisallowStartIfOnBatteries = $true
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.DisallowStartIfOnBatteries | Should -Be 'true'
        }

        It 'Should convert boolean to lowercase string' {
            $mockSettings = [PSCustomObject]@{
                Hidden = $true
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.Hidden | Should -BeExactly 'true'
            $taskXml.Task.Settings.Hidden | Should -Not -BeExactly 'True'
        }
    }

    Context 'Creating Missing Settings' {
        It 'Should create setting element when it does not exist in XML' {
            $taskXml = [xml]$minimalSettingsXml
            $mockSettings = [PSCustomObject]@{
                WakeToRun = $true
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.WakeToRun | Should -Be 'true'
        }

        It 'Should update existing setting element when it exists' {
            $taskXml = [xml]$baseXml
            $mockSettings = [PSCustomObject]@{
                Hidden = $true
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.Hidden | Should -Be 'true'
        }
    }

    Context 'Priority Setting' {
        BeforeEach {
            $script:taskXml = [xml]$baseXml
        }

        It 'Should update Priority when specified' {
            $mockSettings = [PSCustomObject]@{
                Priority = 7
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.Priority | Should -Be '7'
        }

        It 'Should create Priority element when it does not exist' {
            $taskXml = [xml]$minimalSettingsXml
            $mockSettings = [PSCustomObject]@{
                Priority = 5
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.Priority | Should -Be '5'
        }
    }

    Context 'ExecutionTimeLimit Setting' {
        BeforeEach {
            $script:taskXml = [xml]$baseXml
        }

        It 'Should update ExecutionTimeLimit when specified' {
            $mockSettings = [PSCustomObject]@{
                ExecutionTimeLimit = 'PT1H'
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.ExecutionTimeLimit | Should -Be 'PT1H'
        }

        It 'Should create ExecutionTimeLimit element when it does not exist' {
            $taskXml = [xml]$minimalSettingsXml
            $mockSettings = [PSCustomObject]@{
                ExecutionTimeLimit = 'PT2H'
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.ExecutionTimeLimit | Should -Be 'PT2H'
        }
    }

    Context 'Null Values' {
        It 'Should skip settings with null values' {
            $taskXml = [xml]$baseXml
            $originalHidden = $taskXml.Task.Settings.Hidden

            $mockSettings = [PSCustomObject]@{
                Hidden    = $null
                WakeToRun = $true
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $taskXml.Task.Settings.Hidden | Should -Be $originalHidden
            $taskXml.Task.Settings.WakeToRun | Should -Be 'true'
        }
    }

    Context 'XML Namespace' {
        It 'Should create elements with correct namespace' {
            $taskXml = [xml]$minimalSettingsXml
            $mockSettings = [PSCustomObject]@{
                WakeToRun = $true
            }

            Update-StmTaskSettingsXml -TaskXml $taskXml -Settings $mockSettings

            $expectedNs = 'http://schemas.microsoft.com/windows/2004/02/mit/task'
            $wakeNode = $taskXml.Task.Settings.SelectSingleNode('*[local-name()="WakeToRun"]')
            $wakeNode.NamespaceURI | Should -Be $expectedNs
        }
    }
}
