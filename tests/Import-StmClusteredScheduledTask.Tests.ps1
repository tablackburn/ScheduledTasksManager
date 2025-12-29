BeforeDiscovery {
    # Unload the module if it is loaded
    if (Get-Module -Name 'ScheduledTasksManager') {
        Remove-Module -Name 'ScheduledTasksManager' -Force
    }

    # Import the module being tested
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\ScheduledTasksManager\ScheduledTasksManager.psd1'
    Import-Module -Name $modulePath -Force
}

InModuleScope -ModuleName 'ScheduledTasksManager' {
    Describe 'Import-StmClusteredScheduledTask' {
        BeforeEach {
            Mock -CommandName 'New-StmCimSession' -MockWith {
                return 'MockedCimSession'
            }

            Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                return $null
            }

            Mock -CommandName 'Unregister-StmClusteredScheduledTask' -MockWith {
                # Do nothing
            }

            Mock -CommandName 'Register-ClusteredScheduledTask' -MockWith {
                return [PSCustomObject]@{
                    TaskName = $TaskName
                    TaskType = 'AnyNode'
                }
            }

            $script:validXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\TestTask</URI>
  </RegistrationInfo>
  <Actions>
    <Exec>
      <Command>cmd.exe</Command>
    </Exec>
  </Actions>
</Task>
'@

            $script:validXmlWithNestedPath = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\Folder\SubFolder\NestedTask</URI>
  </RegistrationInfo>
  <Actions>
    <Exec>
      <Command>powershell.exe</Command>
    </Exec>
  </Actions>
</Task>
'@

            $script:xmlWithoutUri = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Task without URI</Description>
  </RegistrationInfo>
  <Actions>
    <Exec>
      <Command>cmd.exe</Command>
    </Exec>
  </Actions>
</Task>
'@
        }

        Context 'Function Attributes' {
            It 'Should support ShouldProcess' {
                $function = Get-Command -Name Import-StmClusteredScheduledTask
                $function.Parameters.ContainsKey('WhatIf') | Should -BeTrue
                $function.Parameters.ContainsKey('Confirm') | Should -BeTrue
            }

            It 'Should have XmlFile as default parameter set' {
                $function = Get-Command -Name Import-StmClusteredScheduledTask
                $function.DefaultParameterSet | Should -Be 'XmlFile'
            }

            It 'Should have mandatory Cluster parameter' {
                $function = Get-Command -Name Import-StmClusteredScheduledTask
                $function.Parameters['Cluster'].Attributes.Mandatory | Should -BeTrue
            }

            It 'Should have mandatory TaskType parameter' {
                $function = Get-Command -Name Import-StmClusteredScheduledTask
                $function.Parameters['TaskType'].Attributes.Mandatory | Should -BeTrue
            }

            It 'Should have optional Force parameter' {
                $function = Get-Command -Name Import-StmClusteredScheduledTask
                $function.Parameters['Force'].Attributes.Mandatory | Should -BeFalse
            }

            It 'Should have optional Credential parameter' {
                $function = Get-Command -Name Import-StmClusteredScheduledTask
                $function.Parameters['Credential'].Attributes.Mandatory | Should -BeFalse
            }
        }

        Context 'Single File Import (XmlFile Parameter Set)' {
            It 'Should import a task from XML file with task name extraction' {
                $xmlFilePath = Join-Path -Path 'TestDrive:\' -ChildPath 'TestTask.xml'
                Set-Content -Path $xmlFilePath -Value $script:validXml

                $parameters = @{
                    Path     = $xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                }
                $result = Import-StmClusteredScheduledTask @parameters

                $result.TaskName | Should -Be 'TestTask'
                Should -Invoke -CommandName Register-ClusteredScheduledTask -Times 1 -Exactly
            }

            It 'Should extract task name from nested path URI' {
                $xmlFilePath = Join-Path -Path 'TestDrive:\' -ChildPath 'NestedTask.xml'
                Set-Content -Path $xmlFilePath -Value $script:validXmlWithNestedPath

                $parameters = @{
                    Path     = $xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                }
                $result = Import-StmClusteredScheduledTask @parameters

                $result.TaskName | Should -Be 'NestedTask'
            }

            It 'Should use TaskName override when provided' {
                $xmlFilePath = Join-Path -Path 'TestDrive:\' -ChildPath 'TestTask.xml'
                Set-Content -Path $xmlFilePath -Value $script:validXml

                $parameters = @{
                    Path     = $xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                    TaskName = 'CustomTaskName'
                }
                $result = Import-StmClusteredScheduledTask @parameters

                $result.TaskName | Should -Be 'CustomTaskName'
            }

            It 'Should throw error when file does not exist' {
                $parameters = @{
                    Path     = 'C:\NonExistent\Task.xml'
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                }

                { Import-StmClusteredScheduledTask @parameters } | Should -Throw
            }

            It 'Should throw error when XML lacks URI element and no TaskName provided' {
                $xmlFilePath = Join-Path -Path 'TestDrive:\' -ChildPath 'NoUri.xml'
                Set-Content -Path $xmlFilePath -Value $script:xmlWithoutUri

                $parameters = @{
                    Path     = $xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                }

                { Import-StmClusteredScheduledTask @parameters -ErrorAction Stop } | Should -Throw
            }
        }

        Context 'XML String Import (XmlString Parameter Set)' {
            It 'Should import a task from XML string' {
                $parameters = @{
                    Xml      = $script:validXml
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                }
                $result = Import-StmClusteredScheduledTask @parameters

                $result.TaskName | Should -Be 'TestTask'
                Should -Invoke -CommandName Register-ClusteredScheduledTask -Times 1 -Exactly
            }

            It 'Should use TaskName override with XML string' {
                $parameters = @{
                    Xml      = $script:validXml
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                    TaskName = 'OverriddenName'
                }
                $result = Import-StmClusteredScheduledTask @parameters

                $result.TaskName | Should -Be 'OverriddenName'
            }
        }

        Context 'Directory Import (Directory Parameter Set)' {
            BeforeEach {
                # Create test directory with XML files
                $script:testDir = Join-Path -Path 'TestDrive:\' -ChildPath 'TasksDir'
                New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null

                # Create multiple XML files
                Set-Content -Path (Join-Path -Path $script:testDir -ChildPath 'Task1.xml') -Value $script:validXml
                Set-Content -Path (Join-Path -Path $script:testDir -ChildPath 'Task2.xml') -Value $script:validXmlWithNestedPath
            }

            It 'Should import all XML files from directory' {
                $parameters = @{
                    DirectoryPath = $script:testDir
                    Cluster       = 'TestCluster'
                    TaskType      = 'AnyNode'
                }
                $result = Import-StmClusteredScheduledTask @parameters

                $result.TotalFiles | Should -Be 2
                $result.SuccessCount | Should -Be 2
                $result.FailureCount | Should -Be 0
                $result.ImportedTasks | Should -Contain 'TestTask'
                $result.ImportedTasks | Should -Contain 'NestedTask'
            }

            It 'Should return summary object for directory import' {
                $parameters = @{
                    DirectoryPath = $script:testDir
                    Cluster       = 'TestCluster'
                    TaskType      = 'AnyNode'
                }
                $result = Import-StmClusteredScheduledTask @parameters

                $result.PSObject.Properties.Name | Should -Contain 'TotalFiles'
                $result.PSObject.Properties.Name | Should -Contain 'SuccessCount'
                $result.PSObject.Properties.Name | Should -Contain 'FailureCount'
                $result.PSObject.Properties.Name | Should -Contain 'ImportedTasks'
                $result.PSObject.Properties.Name | Should -Contain 'FailedTasks'
            }

            It 'Should return empty summary when directory contains no XML files' {
                $emptyDir = Join-Path -Path 'TestDrive:\' -ChildPath 'EmptyDir'
                New-Item -Path $emptyDir -ItemType Directory -Force | Out-Null

                $parameters = @{
                    DirectoryPath = $emptyDir
                    Cluster       = 'TestCluster'
                    TaskType      = 'AnyNode'
                }
                $result = Import-StmClusteredScheduledTask @parameters 3>&1

                $result.TotalFiles | Should -Be 0
                $result.SuccessCount | Should -Be 0
            }

            It 'Should throw error when TaskName is used with DirectoryPath' {
                $parameters = @{
                    DirectoryPath = $script:testDir
                    Cluster       = 'TestCluster'
                    TaskType      = 'AnyNode'
                    TaskName      = 'ShouldNotWork'
                }

                { Import-StmClusteredScheduledTask @parameters -ErrorAction Stop } | Should -Throw
            }

            It 'Should throw error when directory does not exist' {
                $parameters = @{
                    DirectoryPath = 'C:\NonExistent\Directory'
                    Cluster       = 'TestCluster'
                    TaskType      = 'AnyNode'
                }

                { Import-StmClusteredScheduledTask @parameters } | Should -Throw
            }

            It 'Should continue on partial failures and report them' {
                # Add a file with invalid XML (no URI)
                Set-Content -Path (Join-Path -Path $script:testDir -ChildPath 'BadTask.xml') -Value $script:xmlWithoutUri

                $parameters = @{
                    DirectoryPath = $script:testDir
                    Cluster       = 'TestCluster'
                    TaskType      = 'AnyNode'
                }
                $result = Import-StmClusteredScheduledTask @parameters 3>&1

                $result.TotalFiles | Should -Be 3
                $result.SuccessCount | Should -Be 2
                $result.FailureCount | Should -Be 1
                $result.FailedTasks.Count | Should -Be 1
                $result.FailedTasks[0].FileName | Should -Be 'BadTask.xml'
            }
        }

        Context 'Force Parameter Behavior' {
            BeforeEach {
                $xmlFilePath = Join-Path -Path 'TestDrive:\' -ChildPath 'ExistingTask.xml'
                Set-Content -Path $xmlFilePath -Value $script:validXml
                $script:xmlFilePath = $xmlFilePath
            }

            It 'Should throw error when task exists and Force not specified' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{ TaskName = 'TestTask' }
                }

                $parameters = @{
                    Path     = $script:xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                }

                { Import-StmClusteredScheduledTask @parameters -ErrorAction Stop } | Should -Throw
            }

            It 'Should have ResourceExists error category when task exists' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{ TaskName = 'TestTask' }
                }

                $parameters = @{
                    Path     = $script:xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                }

                try {
                    Import-StmClusteredScheduledTask @parameters -ErrorAction Stop
                }
                catch {
                    $_.CategoryInfo.Category | Should -Be 'ResourceExists'
                }
            }

            It 'Should unregister existing task when Force is specified' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{ TaskName = 'TestTask' }
                }

                $parameters = @{
                    Path     = $script:xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                    Force    = $true
                }

                Import-StmClusteredScheduledTask @parameters

                Should -Invoke -CommandName Unregister-StmClusteredScheduledTask -Times 1 -Exactly
                Should -Invoke -CommandName Register-ClusteredScheduledTask -Times 1 -Exactly
            }

            It 'Should not call Unregister when task does not exist' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return $null
                }

                $parameters = @{
                    Path     = $script:xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                    Force    = $true
                }

                Import-StmClusteredScheduledTask @parameters

                Should -Invoke -CommandName Unregister-StmClusteredScheduledTask -Times 0 -Exactly
                Should -Invoke -CommandName Register-ClusteredScheduledTask -Times 1 -Exactly
            }
        }

        Context 'Credential Handling' {
            BeforeEach {
                $xmlFilePath = Join-Path -Path 'TestDrive:\' -ChildPath 'Task.xml'
                Set-Content -Path $xmlFilePath -Value $script:validXml
                $script:xmlFilePath = $xmlFilePath

                $securePassword = ConvertTo-SecureString -String 'P@ssw0rd!' -AsPlainText -Force
                $script:testCredential = [System.Management.Automation.PSCredential]::new('TestUser', $securePassword)
            }

            It 'Should pass credentials to New-StmCimSession' {
                $parameters = @{
                    Path       = $script:xmlFilePath
                    Cluster    = 'TestCluster'
                    TaskType   = 'AnyNode'
                    Credential = $script:testCredential
                }

                Import-StmClusteredScheduledTask @parameters

                Should -Invoke -CommandName New-StmCimSession -Times 1 -Exactly -ParameterFilter {
                    $Credential -eq $script:testCredential
                }
            }
        }

        Context 'WhatIf Support' {
            BeforeEach {
                $xmlFilePath = Join-Path -Path 'TestDrive:\' -ChildPath 'Task.xml'
                Set-Content -Path $xmlFilePath -Value $script:validXml
                $script:xmlFilePath = $xmlFilePath
            }

            It 'Should not register task when WhatIf is specified' {
                $parameters = @{
                    Path     = $script:xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                    WhatIf   = $true
                }

                Import-StmClusteredScheduledTask @parameters

                Should -Invoke -CommandName Register-ClusteredScheduledTask -Times 0 -Exactly
            }

            It 'Should not unregister existing task when WhatIf is specified with Force' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{ TaskName = 'TestTask' }
                }

                $parameters = @{
                    Path     = $script:xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                    Force    = $true
                    WhatIf   = $true
                }

                Import-StmClusteredScheduledTask @parameters

                Should -Invoke -CommandName Unregister-StmClusteredScheduledTask -Times 0 -Exactly
            }
        }

        Context 'Error Handling' {
            BeforeEach {
                $xmlFilePath = Join-Path -Path 'TestDrive:\' -ChildPath 'Task.xml'
                Set-Content -Path $xmlFilePath -Value $script:validXml
                $script:xmlFilePath = $xmlFilePath
            }

            It 'Should throw error with correct ErrorId when task already exists' {
                Mock -CommandName 'Get-StmClusteredScheduledTask' -MockWith {
                    return [PSCustomObject]@{ TaskName = 'TestTask' }
                }

                $parameters = @{
                    Path     = $script:xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                }

                try {
                    Import-StmClusteredScheduledTask @parameters -ErrorAction Stop
                }
                catch {
                    $_.FullyQualifiedErrorId | Should -BeLike '*TaskAlreadyExists*'
                }
            }

            It 'Should throw error with correct ErrorId when task name cannot be determined' {
                $noUriPath = Join-Path -Path 'TestDrive:\' -ChildPath 'NoUri.xml'
                Set-Content -Path $noUriPath -Value $script:xmlWithoutUri

                $parameters = @{
                    Path     = $noUriPath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                }

                try {
                    Import-StmClusteredScheduledTask @parameters -ErrorAction Stop
                }
                catch {
                    $_.FullyQualifiedErrorId | Should -BeLike '*TaskNameNotFound*'
                }
            }

            It 'Should throw error when registration fails' {
                Mock -CommandName 'Register-ClusteredScheduledTask' -MockWith {
                    throw 'Registration failed'
                }

                $parameters = @{
                    Path     = $script:xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                }

                try {
                    Import-StmClusteredScheduledTask @parameters -ErrorAction Stop
                }
                catch {
                    $_.FullyQualifiedErrorId | Should -BeLike '*TaskRegistrationFailed*'
                }
            }
        }

        Context 'Verbose Logging' {
            BeforeEach {
                $xmlFilePath = Join-Path -Path 'TestDrive:\' -ChildPath 'Task.xml'
                Set-Content -Path $xmlFilePath -Value $script:validXml
                $script:xmlFilePath = $xmlFilePath
            }

            It 'Should write verbose message for start of operation' {
                $parameters = @{
                    Path     = $script:xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                }

                $verboseOutput = Import-StmClusteredScheduledTask @parameters -Verbose 4>&1

                $verboseOutput | Where-Object { $_ -match 'Starting Import-StmClusteredScheduledTask' } | Should -Not -BeNullOrEmpty
            }

            It 'Should write verbose message for completion' {
                $parameters = @{
                    Path     = $script:xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                }

                $verboseOutput = Import-StmClusteredScheduledTask @parameters -Verbose 4>&1

                $verboseOutput | Where-Object { $_ -match 'Completed Import-StmClusteredScheduledTask' } | Should -Not -BeNullOrEmpty
            }

            It 'Should write verbose message for extracted task name' {
                $parameters = @{
                    Path     = $script:xmlFilePath
                    Cluster  = 'TestCluster'
                    TaskType = 'AnyNode'
                }

                $verboseOutput = Import-StmClusteredScheduledTask @parameters -Verbose 4>&1

                $verboseOutput | Where-Object { $_ -match "Extracted task name from XML: 'TestTask'" } | Should -Not -BeNullOrEmpty
            }
        }
    }
}
