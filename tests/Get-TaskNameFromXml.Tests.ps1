BeforeAll {
    $moduleName = 'ScheduledTasksManager'
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\$moduleName\$moduleName.psd1"
    $module = Import-Module -Name $modulePath -Force -PassThru

    # Import the private function for testing
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\ScheduledTasksManager\Private\Get-TaskNameFromXml.ps1')
}

Describe 'Get-TaskNameFromXml' {
    Context 'Function Attributes' {
        It 'Should have mandatory XmlContent parameter' {
            $function = Get-Command -Name Get-TaskNameFromXml
            $function.Parameters['XmlContent'].Attributes.Mandatory | Should -BeTrue
        }

        It 'Should have ValidateNotNullOrEmpty on XmlContent parameter' {
            $function = Get-Command -Name Get-TaskNameFromXml
            $function.Parameters['XmlContent'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateNotNullOrEmptyAttribute] } |
                Should -Not -BeNullOrEmpty
        }

        It 'Should have OutputType of string' {
            $function = Get-Command -Name Get-TaskNameFromXml
            $function.OutputType.Type.Name | Should -Contain 'String'
        }
    }

    Context 'Task Name Extraction from Simple URI' {
        BeforeEach {
            $script:simpleXml = @'
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
        }

        It 'Should extract task name from simple URI' {
            $result = Get-TaskNameFromXml -XmlContent $simpleXml
            $result | Should -Be 'TestTask'
        }

        It 'Should write verbose message for extracted task name' {
            $verboseOutput = Get-TaskNameFromXml -XmlContent $simpleXml -Verbose 4>&1
            $verboseOutput | Where-Object { $_ -match "Extracted task name: 'TestTask'" } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Task Name Extraction from Nested Path URI' {
        BeforeEach {
            $script:nestedXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\MyFolder\SubFolder\BackupTask</URI>
  </RegistrationInfo>
  <Actions>
    <Exec>
      <Command>powershell.exe</Command>
    </Exec>
  </Actions>
</Task>
'@
        }

        It 'Should extract task name from nested path URI' {
            $result = Get-TaskNameFromXml -XmlContent $nestedXml
            $result | Should -Be 'BackupTask'
        }

        It 'Should handle deeply nested folder structure' {
            $deepXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\Level1\Level2\Level3\Level4\DeepTask</URI>
  </RegistrationInfo>
  <Actions>
    <Exec>
      <Command>cmd.exe</Command>
    </Exec>
  </Actions>
</Task>
'@
            $result = Get-TaskNameFromXml -XmlContent $deepXml
            $result | Should -Be 'DeepTask'
        }
    }

    Context 'Missing or Empty URI Element' {
        It 'Should return null when URI element is missing' {
            $noUriXml = @'
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
            $result = Get-TaskNameFromXml -XmlContent $noUriXml
            $result | Should -BeNullOrEmpty
        }

        It 'Should return null when URI element is empty' {
            $emptyUriXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI></URI>
  </RegistrationInfo>
  <Actions>
    <Exec>
      <Command>cmd.exe</Command>
    </Exec>
  </Actions>
</Task>
'@
            $result = Get-TaskNameFromXml -XmlContent $emptyUriXml
            $result | Should -BeNullOrEmpty
        }

        It 'Should return null when RegistrationInfo is missing' {
            $noRegInfoXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Actions>
    <Exec>
      <Command>cmd.exe</Command>
    </Exec>
  </Actions>
</Task>
'@
            $result = Get-TaskNameFromXml -XmlContent $noRegInfoXml
            $result | Should -BeNullOrEmpty
        }

        It 'Should write verbose message when URI not found' {
            $noUriXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Task without URI</Description>
  </RegistrationInfo>
</Task>
'@
            $verboseOutput = Get-TaskNameFromXml -XmlContent $noUriXml -Verbose 4>&1
            $verboseOutput | Where-Object { $_ -match 'No URI found' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Invalid XML Content' {
        It 'Should return null for invalid XML' {
            $invalidXml = 'This is not valid XML content'
            $result = Get-TaskNameFromXml -XmlContent $invalidXml
            $result | Should -BeNullOrEmpty
        }

        It 'Should return null for malformed XML' {
            $malformedXml = '<Task><RegistrationInfo><URI>NoClosingTag'
            $result = Get-TaskNameFromXml -XmlContent $malformedXml
            $result | Should -BeNullOrEmpty
        }

        It 'Should write verbose message on XML parse failure' {
            $invalidXml = 'Not valid XML'
            $verboseOutput = Get-TaskNameFromXml -XmlContent $invalidXml -Verbose 4>&1
            $verboseOutput | Where-Object { $_ -match 'Failed to parse XML' } | Should -Not -BeNullOrEmpty
        }

        It 'Should not throw exception for invalid XML' {
            $invalidXml = 'Not valid XML'
            { Get-TaskNameFromXml -XmlContent $invalidXml } | Should -Not -Throw
        }
    }

    Context 'Parameter Validation' {
        It 'Should throw error when XmlContent is null' {
            { Get-TaskNameFromXml -XmlContent $null } | Should -Throw
        }

        It 'Should throw error when XmlContent is empty string' {
            { Get-TaskNameFromXml -XmlContent '' } | Should -Throw
        }
    }

    Context 'Edge Cases' {
        It 'Should handle task name with spaces' {
            $spacesXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\My Task With Spaces</URI>
  </RegistrationInfo>
</Task>
'@
            $result = Get-TaskNameFromXml -XmlContent $spacesXml
            $result | Should -Be 'My Task With Spaces'
        }

        It 'Should handle task name with special characters' {
            $specialXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\Task-Name_123</URI>
  </RegistrationInfo>
</Task>
'@
            $result = Get-TaskNameFromXml -XmlContent $specialXml
            $result | Should -Be 'Task-Name_123'
        }

        It 'Should handle URI with only backslash' {
            $rootXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\</URI>
  </RegistrationInfo>
</Task>
'@
            $result = Get-TaskNameFromXml -XmlContent $rootXml
            $result | Should -BeNullOrEmpty
        }

        It 'Should handle whitespace-only URI' {
            $whitespaceXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>   </URI>
  </RegistrationInfo>
</Task>
'@
            $result = Get-TaskNameFromXml -XmlContent $whitespaceXml
            $result | Should -BeNullOrEmpty
        }

        It 'Should handle URI with double backslash' {
            # URI '\\' passes the root check (not exactly '\') but Split-Path -Leaf returns empty
            $doubleSlashXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\\</URI>
  </RegistrationInfo>
</Task>
'@
            $result = Get-TaskNameFromXml -XmlContent $doubleSlashXml
            $result | Should -BeNullOrEmpty
        }

        It 'Should write verbose message when Split-Path returns empty' {
            $doubleSlashXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\\</URI>
  </RegistrationInfo>
</Task>
'@
            $verboseOutput = Get-TaskNameFromXml -XmlContent $doubleSlashXml -Verbose 4>&1
            $verboseOutput | Where-Object { $_ -match 'Could not extract task name from URI' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Verbose Logging' {
        BeforeEach {
            $script:validXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\TestTask</URI>
  </RegistrationInfo>
</Task>
'@
        }

        It 'Should write verbose message for start of operation' {
            $verboseOutput = Get-TaskNameFromXml -XmlContent $validXml -Verbose 4>&1
            $verboseOutput | Where-Object { $_ -match 'Starting Get-TaskNameFromXml' } | Should -Not -BeNullOrEmpty
        }

        It 'Should write verbose message for completion' {
            $verboseOutput = Get-TaskNameFromXml -XmlContent $validXml -Verbose 4>&1
            $verboseOutput | Where-Object { $_ -match 'Completed Get-TaskNameFromXml' } | Should -Not -BeNullOrEmpty
        }
    }
}
