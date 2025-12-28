<#
.SYNOPSIS
    Integration tests for clustered scheduled task functionality.

.DESCRIPTION
    Tests the ScheduledTasksManager module against a real Windows Failover Cluster.
    Requires the integration lab to be running (see Initialize-IntegrationLab.ps1).

    Tests are executed from INSIDE the lab (on STMNODE01) using Invoke-LabCommand
    because the cluster network is not routable from the host.

.NOTES
    Prerequisites:
    - Integration lab deployed and running
    - Run: .\Initialize-IntegrationLab.ps1 (first time)
    - Run: .\Start-IntegrationLab.ps1 (each test session)

    Run with file output:
    Invoke-Pester .\ClusteredScheduledTask.Integration.Tests.ps1 -Output Detailed |
        Tee-Object -FilePath .\out\test-output.txt
#>

BeforeDiscovery {
    # Check if we're in an integration test context
    $script:SkipIntegrationTests = $false

    # Load configuration module
    Import-Module "$PSScriptRoot\IntegrationTestConfig.psm1" -Force

    # Check if configuration exists
    if (-not (Test-IntegrationTestConfig)) {
        $script:SkipIntegrationTests = $true
        $script:SkipReason = "config-missing"
        Write-IntegrationTestSkipWarning
    }
    else {
        $script:Config = Get-IntegrationTestConfig
    }

    # Check if AutomatedLab is available
    if (-not $script:SkipIntegrationTests) {
        $alModule = Get-Module -Name AutomatedLab -ListAvailable
        if (-not $alModule) {
            $script:SkipIntegrationTests = $true
            $script:SkipReason = "AutomatedLab module not installed"
        }
    }

    # Check if lab exists
    if (-not $script:SkipIntegrationTests) {
        Import-Module AutomatedLab -Force -ErrorAction SilentlyContinue
        $labs = Get-Lab -List -ErrorAction SilentlyContinue
        $labName = $script:Config.lab.name
        if ($labName -notin $labs) {
            $script:SkipIntegrationTests = $true
            $script:SkipReason = "Integration lab '$labName' not deployed. Run Initialize-IntegrationLab.ps1 first."
        }
    }
}

BeforeAll {
    # Load config if not already loaded
    if (-not $script:Config -and -not $script:SkipIntegrationTests) {
        Import-Module "$PSScriptRoot\IntegrationTestConfig.psm1" -Force
        $script:Config = Get-IntegrationTestConfig
    }

    # Start the lab and get connection info
    if (-not $script:SkipIntegrationTests) {
        $script:LabInfo = & "$PSScriptRoot\Start-IntegrationLab.ps1"

        # Import AutomatedLab for Invoke-LabCommand
        Import-Module AutomatedLab -Force
        Import-Lab -Name $script:Config.lab.name -NoValidation

        # Copy module to the cluster node for testing
        $modulePath = Join-Path $PSScriptRoot '..\..\ScheduledTasksManager' -Resolve
        $labModulePath = $script:Config.paths.labModulePath
        $testNode = $script:Config.virtualMachines.clusterNodes[0]

        Write-Host "Copying module to lab node..." -ForegroundColor Yellow
        Copy-LabFileItem -Path $modulePath -DestinationFolderPath 'C:\' -ComputerName $testNode
        Write-Host "  [OK] Module copied to ${testNode}:$labModulePath" -ForegroundColor Green

        # Ensure output directory exists
        $outDir = Join-Path $PSScriptRoot 'out'
        if (-not (Test-Path $outDir)) {
            New-Item -Path $outDir -ItemType Directory -Force | Out-Null
        }
    }

    # Test task definition (from config)
    $script:TestTaskName = $script:Config.test.taskName
    $script:ClusterName = $script:Config.cluster.name
    $script:TestNode = $script:Config.virtualMachines.clusterNodes[0]
    $script:LabModulePath = $script:Config.paths.labModulePath

    # Simple task XML for testing
    $script:TestTaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Integration test task for ScheduledTasksManager</Description>
  </RegistrationInfo>
  <Triggers>
    <TimeTrigger>
      <StartBoundary>2099-01-01T00:00:00</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>cmd.exe</Command>
      <Arguments>/c echo Integration test</Arguments>
    </Exec>
  </Actions>
</Task>
"@
}

AfterAll {
    # Cleanup: Remove test task if it exists
    if (-not $script:SkipIntegrationTests -and $script:LabInfo) {
        Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Cleanup: Unregister test task' -ScriptBlock {
            param($TaskName, $ClusterName, $ModulePath)
            Import-Module $ModulePath -Force

            # Only unregister if the task exists
            $task = Get-StmClusteredScheduledTask `
                -Cluster $ClusterName `
                -TaskName $TaskName `
                -ErrorAction SilentlyContinue `
                -WarningAction SilentlyContinue

            if ($task) {
                Unregister-StmClusteredScheduledTask `
                    -Cluster $ClusterName `
                    -TaskName $TaskName `
                    -Confirm:$false
            }
        } -ArgumentList @($script:TestTaskName, $script:ClusterName, $script:LabModulePath)
    }
}

Describe 'Clustered Scheduled Task Integration Tests' -Skip:$script:SkipIntegrationTests {

    Context 'Lab Environment' {

        It 'Should have a healthy cluster' {
            $script:LabInfo.IsHealthy | Should -BeTrue
        }

        It 'Should have the module available on the test node' {
            $result = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Check module exists' -ScriptBlock {
                param($ModulePath)
                Test-Path "$ModulePath\ScheduledTasksManager.psd1"
            } -ArgumentList $script:LabModulePath -PassThru
            $result | Should -BeTrue
        }

        It 'Should be able to import the module on the test node' {
            $result = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Import module' -ScriptBlock {
                param($ModulePath)
                try {
                    Import-Module $ModulePath -Force -ErrorAction Stop
                    $true
                }
                catch {
                    $false
                }
            } -ArgumentList $script:LabModulePath -PassThru
            $result | Should -BeTrue
        }
    }

    Context 'Get-StmClusterNode' {

        It 'Should return cluster nodes' {
            $nodes = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Get-StmClusterNode' -ScriptBlock {
                param($ModulePath, $ClusterName)
                Import-Module $ModulePath -Force
                Get-StmClusterNode -Cluster $ClusterName
            } -ArgumentList @($script:LabModulePath, $script:ClusterName) -PassThru

            $nodes | Should -Not -BeNullOrEmpty
            $nodes.Count | Should -BeGreaterOrEqual 2
        }

        It 'Should return nodes with expected properties' {
            $nodes = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Get-StmClusterNode (properties)' -ScriptBlock {
                param($ModulePath, $ClusterName)
                Import-Module $ModulePath -Force
                Get-StmClusterNode -Cluster $ClusterName
            } -ArgumentList @($script:LabModulePath, $script:ClusterName) -PassThru

            $nodes[0].Name | Should -Not -BeNullOrEmpty
            $nodes[0].State | Should -Be 'Up'
        }
    }

    Context 'Register-StmClusteredScheduledTask' {

        It 'Should register a new clustered scheduled task' {
            $result = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Register-StmClusteredScheduledTask' -ScriptBlock {
                param($ModulePath, $ClusterName, $TaskName, $TaskXml)
                Import-Module $ModulePath -Force
                Register-StmClusteredScheduledTask `
                    -Cluster $ClusterName `
                    -TaskName $TaskName `
                    -Xml $TaskXml `
                    -TaskType AnyNode
            } -ArgumentList @($script:LabModulePath, $script:ClusterName, $script:TestTaskName, $script:TestTaskXml) -PassThru

            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should be retrievable after registration' {
            $task = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Get-StmClusteredScheduledTask (after register)' -ScriptBlock {
                param($ModulePath, $ClusterName, $TaskName)
                Import-Module $ModulePath -Force
                Get-StmClusteredScheduledTask `
                    -Cluster $ClusterName `
                    -TaskName $TaskName
            } -ArgumentList @($script:LabModulePath, $script:ClusterName, $script:TestTaskName) -PassThru

            $task | Should -Not -BeNullOrEmpty
            $task.TaskName | Should -Be $script:TestTaskName
        }
    }

    Context 'Get-StmClusteredScheduledTask' {

        It 'Should return the test task' {
            $task = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Get-StmClusteredScheduledTask (by name)' -ScriptBlock {
                param($ModulePath, $ClusterName, $TaskName)
                Import-Module $ModulePath -Force
                Get-StmClusteredScheduledTask `
                    -Cluster $ClusterName `
                    -TaskName $TaskName
            } -ArgumentList @($script:LabModulePath, $script:ClusterName, $script:TestTaskName) -PassThru

            $task | Should -Not -BeNullOrEmpty
        }

        It 'Should return all clustered tasks when no filter specified' {
            $tasks = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Get-StmClusteredScheduledTask (all)' -ScriptBlock {
                param($ModulePath, $ClusterName)
                Import-Module $ModulePath -Force
                Get-StmClusteredScheduledTask -Cluster $ClusterName
            } -ArgumentList @($script:LabModulePath, $script:ClusterName) -PassThru

            $tasks | Should -Not -BeNullOrEmpty
            @($tasks).Count | Should -BeGreaterOrEqual 1
        }
    }

    Context 'Get-StmClusteredScheduledTaskInfo' {

        It 'Should return task info with state' {
            $info = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Get-StmClusteredScheduledTaskInfo' -ScriptBlock {
                param($ModulePath, $ClusterName, $TaskName)
                Import-Module $ModulePath -Force
                Get-StmClusteredScheduledTaskInfo `
                    -Cluster $ClusterName `
                    -TaskName $TaskName
            } -ArgumentList @($script:LabModulePath, $script:ClusterName, $script:TestTaskName) -PassThru

            $info | Should -Not -BeNullOrEmpty
            $info.State | Should -BeIn @('Ready', 'Disabled', 'Running')
        }
    }

    Context 'Start-StmClusteredScheduledTask' {

        It 'Should start the task' {
            # Start the task
            Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Start-StmClusteredScheduledTask' -ScriptBlock {
                param($ModulePath, $ClusterName, $TaskName)
                Import-Module $ModulePath -Force
                Start-StmClusteredScheduledTask `
                    -Cluster $ClusterName `
                    -TaskName $TaskName
            } -ArgumentList @($script:LabModulePath, $script:ClusterName, $script:TestTaskName)

            # Wait for task to complete
            Start-Sleep -Seconds 2

            # Verify it ran (state should be Ready after completion)
            $info = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Get-StmClusteredScheduledTaskInfo (after start)' -ScriptBlock {
                param($ModulePath, $ClusterName, $TaskName)
                Import-Module $ModulePath -Force
                Get-StmClusteredScheduledTaskInfo `
                    -Cluster $ClusterName `
                    -TaskName $TaskName
            } -ArgumentList @($script:LabModulePath, $script:ClusterName, $script:TestTaskName) -PassThru

            $info.State | Should -BeIn @('Ready', 'Running')
        }
    }

    Context 'Disable-StmClusteredScheduledTask' {
        # Note: Disable-StmClusteredScheduledTask actually UNREGISTERS the task (with backup).
        # This is by design - it's a "safe unregister" that creates a backup first.

        It 'Should disable (unregister with backup) the task' {
            # Disable (unregister) the task - suppress expected warning about irreversible action
            Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Disable-StmClusteredScheduledTask' -ScriptBlock {
                param($ModulePath, $ClusterName, $TaskName)
                Import-Module $ModulePath -Force
                Disable-StmClusteredScheduledTask `
                    -Cluster $ClusterName `
                    -TaskName $TaskName `
                    -Confirm:$false `
                    -WarningAction SilentlyContinue
            } -ArgumentList @($script:LabModulePath, $script:ClusterName, $script:TestTaskName)

            # Verify task no longer exists (Disable = Unregister)
            $task = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Get-StmClusteredScheduledTask (after disable)' -ScriptBlock {
                param($ModulePath, $ClusterName, $TaskName)
                Import-Module $ModulePath -Force
                Get-StmClusteredScheduledTask `
                    -Cluster $ClusterName `
                    -TaskName $TaskName `
                    -ErrorAction SilentlyContinue `
                    -WarningAction SilentlyContinue
            } -ArgumentList @($script:LabModulePath, $script:ClusterName, $script:TestTaskName) -PassThru

            $task | Should -BeNullOrEmpty
        }

        It 'Should have created a backup file' {
            $backupExists = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Check backup file exists' -ScriptBlock {
                param($TaskName, $ClusterName)
                $pattern = "${TaskName}_${ClusterName}_*.xml"
                $backupFiles = Get-ChildItem -Path $env:TEMP -Filter $pattern -ErrorAction SilentlyContinue
                $backupFiles.Count -gt 0
            } -ArgumentList @($script:TestTaskName, $script:ClusterName) -PassThru

            $backupExists | Should -BeTrue
        }
    }

    Context 'Enable-StmClusteredScheduledTask' {
        # Re-register the task first since Disable unregistered it
        BeforeAll {
            Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Re-register task for Enable test' -ScriptBlock {
                param($ModulePath, $ClusterName, $TaskName, $TaskXml)
                Import-Module $ModulePath -Force
                # Register with Enabled=false in XML for this test
                $disabledXml = $TaskXml -replace '<Enabled>true</Enabled>', '<Enabled>false</Enabled>'
                Register-StmClusteredScheduledTask `
                    -Cluster $ClusterName `
                    -TaskName $TaskName `
                    -Xml $disabledXml `
                    -TaskType AnyNode
            } -ArgumentList @($script:LabModulePath, $script:ClusterName, $script:TestTaskName, $script:TestTaskXml)
        }

        It 'Should enable the task' {
            # Enable the task
            Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Enable-StmClusteredScheduledTask' -ScriptBlock {
                param($ModulePath, $ClusterName, $TaskName)
                Import-Module $ModulePath -Force
                Enable-StmClusteredScheduledTask `
                    -Cluster $ClusterName `
                    -TaskName $TaskName `
                    -Confirm:$false
            } -ArgumentList @($script:LabModulePath, $script:ClusterName, $script:TestTaskName)

            # Verify it's enabled
            $info = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Get-StmClusteredScheduledTaskInfo (after enable)' -ScriptBlock {
                param($ModulePath, $ClusterName, $TaskName)
                Import-Module $ModulePath -Force
                Get-StmClusteredScheduledTaskInfo `
                    -Cluster $ClusterName `
                    -TaskName $TaskName
            } -ArgumentList @($script:LabModulePath, $script:ClusterName, $script:TestTaskName) -PassThru

            $info.State | Should -Be 'Ready'
        }
    }

    Context 'Unregister-StmClusteredScheduledTask' {

        It 'Should unregister the task' {
            # Unregister the task
            Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Unregister-StmClusteredScheduledTask' -ScriptBlock {
                param($ModulePath, $ClusterName, $TaskName)
                Import-Module $ModulePath -Force
                Unregister-StmClusteredScheduledTask `
                    -Cluster $ClusterName `
                    -TaskName $TaskName `
                    -Confirm:$false
            } -ArgumentList @($script:LabModulePath, $script:ClusterName, $script:TestTaskName)

            # Verify it's gone
            $task = Invoke-LabCommand -ComputerName $script:TestNode -NoDisplay -ActivityName 'Get-StmClusteredScheduledTask (after unregister)' -ScriptBlock {
                param($ModulePath, $ClusterName, $TaskName)
                Import-Module $ModulePath -Force
                Get-StmClusteredScheduledTask `
                    -Cluster $ClusterName `
                    -TaskName $TaskName `
                    -ErrorAction SilentlyContinue `
                    -WarningAction SilentlyContinue
            } -ArgumentList @($script:LabModulePath, $script:ClusterName, $script:TestTaskName) -PassThru

            $task | Should -BeNullOrEmpty
        }
    }
}
