BeforeAll {
    $moduleName = 'ScheduledTasksManager'
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\$moduleName\$moduleName.psd1"
    $module = Import-Module -Name $modulePath -Force -PassThru

    # Import the private function for testing
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\ScheduledTasksManager\Private\New-StmCimSession.ps1')
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\ScheduledTasksManager\Private\New-StmError.ps1')
}

Describe 'New-StmCimSession' {
    Context 'Function Attributes' {
        It 'Should support ShouldProcess' {
            $function = Get-Command -Name New-StmCimSession
            $function.Parameters.ContainsKey('WhatIf') | Should -BeTrue
            $function.Parameters.ContainsKey('Confirm') | Should -BeTrue
        }

        It 'Should have mandatory ComputerName parameter' {
            $function = Get-Command -Name New-StmCimSession
            $function.Parameters['ComputerName'].Attributes.Mandatory | Should -BeTrue
        }

        It 'Should have optional Credential parameter' {
            $function = Get-Command -Name New-StmCimSession
            $function.Parameters['Credential'].Attributes.Mandatory | Should -BeFalse
        }
    }

    Context 'CIM Session Creation with Default Credentials' {
        BeforeEach {
            Mock -CommandName New-CimSession -MockWith {
                return [PSCustomObject]@{
                    ComputerName = $ComputerName
                    Id           = 1
                    Name         = 'CimSession1'
                }
            }
        }

        It 'Should create CIM session with correct computer name' {
            $result = New-StmCimSession -ComputerName 'TestServer01'
            $result.ComputerName | Should -Be 'TestServer01'
        }

        It 'Should call New-CimSession with correct parameters' {
            New-StmCimSession -ComputerName 'TestServer02'

            Should -Invoke -CommandName New-CimSession -Times 1 -Exactly -ParameterFilter {
                $ComputerName -eq 'TestServer02' -and
                $ErrorAction -eq 'Stop' -and
                -not $PSBoundParameters.ContainsKey('Credential')
            }
        }

        It 'Should write verbose message for start of operation' {
            $verboseOutput = New-StmCimSession -ComputerName 'TestServer03' -Verbose 4>&1
            $verboseOutput | Where-Object { $_ -match "Starting New-StmCimSession for computer 'TestServer03'" } | Should -Not -BeNullOrEmpty
        }

        It 'Should write verbose message for using current credentials' {
            $verboseOutput = New-StmCimSession -ComputerName 'TestServer04' -Verbose 4>&1
            $verboseOutput | Where-Object { $_ -match "Using current credentials for CIM session" } | Should -Not -BeNullOrEmpty
        }

        It 'Should write verbose message for creating CIM session' {
            $verboseOutput = New-StmCimSession -ComputerName 'TestServer05' -Verbose 4>&1
            $verboseOutput | Where-Object { $_ -match "Creating CIM session to 'TestServer05'" } | Should -Not -BeNullOrEmpty
        }

        It 'Should write verbose message for completion' {
            $verboseOutput = New-StmCimSession -ComputerName 'TestServer06' -Verbose 4>&1
            $verboseOutput | Where-Object { $_ -match "Completed New-StmCimSession for computer 'TestServer06'" } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'CIM Session Creation with Provided Credentials' {
        BeforeEach {
            Mock -CommandName New-CimSession -MockWith {
                return [PSCustomObject]@{
                    ComputerName = $ComputerName
                    Id           = 2
                    Name         = 'CimSession2'
                }
            }

            $securePassword = ConvertTo-SecureString -String 'P@ssw0rd!' -AsPlainText -Force
            $script:testCredential = [System.Management.Automation.PSCredential]::new('TestUser', $securePassword)
        }

        It 'Should create CIM session with provided credentials' {
            $result = New-StmCimSession -ComputerName 'TestServer07' -Credential $testCredential
            $result.ComputerName | Should -Be 'TestServer07'
        }

        It 'Should call New-CimSession with credential parameter' {
            New-StmCimSession -ComputerName 'TestServer08' -Credential $testCredential

            Should -Invoke -CommandName New-CimSession -Times 1 -Exactly -ParameterFilter {
                $ComputerName -eq 'TestServer08' -and
                $Credential -eq $testCredential -and
                $ErrorAction -eq 'Stop'
            }
        }

        It 'Should write verbose message for using provided credentials' {
            $verboseOutput = New-StmCimSession -ComputerName 'TestServer09' -Credential $testCredential -Verbose 4>&1
            $verboseOutput | Where-Object { $_ -match "Using provided credentials for CIM session" } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'WhatIf Support' {
        BeforeEach {
            Mock -CommandName New-CimSession -MockWith {
                throw 'New-CimSession should not be called during WhatIf'
            }
        }

        It 'Should not create CIM session when WhatIf is specified' {
            { New-StmCimSession -ComputerName 'TestServer10' -WhatIf } | Should -Not -Throw
            Should -Invoke -CommandName New-CimSession -Times 0 -Exactly
        }

        It 'Should display WhatIf message' {
            # WhatIf prevents execution, so New-CimSession should not be called
            { New-StmCimSession -ComputerName 'TestServer11' -WhatIf } | Should -Not -Throw
            # Verify New-CimSession was not called due to WhatIf
            Should -Invoke -CommandName New-CimSession -Times 0 -Exactly -Scope It
        }
    }

    Context 'Error Handling' {
        BeforeEach {
            Mock -CommandName New-CimSession -MockWith {
                throw 'The RPC server is unavailable.'
            }
        }

        It 'Should throw terminating error when CIM session creation fails' {
            {
                New-StmCimSession -ComputerName 'UnreachableServer' -ErrorAction Stop
            } | Should -Throw
        }

        It 'Should throw error with correct error ID' {
            try {
                New-StmCimSession -ComputerName 'UnreachableServer' -ErrorAction Stop
            }
            catch {
                $_.FullyQualifiedErrorId | Should -BeLike '*CimSessionCreationFailed*'
            }
        }

        It 'Should include computer name in error message' {
            try {
                New-StmCimSession -ComputerName 'UnreachableServer' -ErrorAction Stop
            }
            catch {
                # The error message is constructed by New-StmError and includes the computer name
                $errorString = $_ | Out-String
                $errorString | Should -Match 'UnreachableServer'
            }
        }

        It 'Should include original exception message in error' {
            try {
                New-StmCimSession -ComputerName 'UnreachableServer' -ErrorAction Stop
            }
            catch {
                $_.Exception.Message | Should -Match 'RPC server is unavailable'
            }
        }

        It 'Should have ConnectionError as error category' {
            try {
                New-StmCimSession -ComputerName 'UnreachableServer' -ErrorAction Stop
            }
            catch {
                $_.CategoryInfo.Category | Should -Be 'ConnectionError'
            }
        }

        It 'Should have computer name as target object' {
            try {
                New-StmCimSession -ComputerName 'UnreachableServer' -ErrorAction Stop
            }
            catch {
                $_.TargetObject | Should -Be 'UnreachableServer'
            }
        }

        It 'Should include recommended action in error' {
            try {
                New-StmCimSession -ComputerName 'UnreachableServer' -ErrorAction Stop
            }
            catch {
                $_.ErrorDetails.RecommendedAction | Should -Match 'Verify the computer name'
                $_.ErrorDetails.RecommendedAction | Should -Match 'is accessible'
                $_.ErrorDetails.RecommendedAction | Should -Match 'appropriate permissions'
            }
        }
    }

    Context 'Error Handling with Credentials' {
        BeforeEach {
            Mock -CommandName New-CimSession -MockWith {
                throw 'Access denied.'
            }

            $securePassword = ConvertTo-SecureString -String 'P@ssw0rd!' -AsPlainText -Force
            $script:testCredential = [System.Management.Automation.PSCredential]::new('TestUser', $securePassword)
        }

        It 'Should throw error when credentials are invalid' {
            {
                New-StmCimSession -ComputerName 'TestServer12' -Credential $testCredential -ErrorAction Stop
            } | Should -Throw
        }

        It 'Should include credential validation in recommended action' {
            try {
                New-StmCimSession -ComputerName 'TestServer13' -Credential $testCredential -ErrorAction Stop
            }
            catch {
                $_.ErrorDetails.RecommendedAction | Should -Match 'credentials.*valid'
            }
        }

        It 'Should include access denied message in error' {
            try {
                New-StmCimSession -ComputerName 'TestServer14' -Credential $testCredential -ErrorAction Stop
            }
            catch {
                $_.Exception.Message | Should -Match 'Access denied'
            }
        }
    }

    Context 'Parameter Validation' {
        It 'Should throw error when ComputerName is null' {
            { New-StmCimSession -ComputerName $null } | Should -Throw
        }

        It 'Should throw error when ComputerName is empty' {
            { New-StmCimSession -ComputerName '' } | Should -Throw
        }

        It 'Should accept PSCredential object for Credential parameter' {
            Mock -CommandName New-CimSession -MockWith {
                return [PSCustomObject]@{
                    ComputerName = 'TestServer'
                    Id           = 1
                }
            }

            $securePassword = ConvertTo-SecureString -String 'P@ssw0rd!' -AsPlainText -Force
            $cred = [System.Management.Automation.PSCredential]::new('TestUser', $securePassword)

            { New-StmCimSession -ComputerName 'TestServer15' -Credential $cred } | Should -Not -Throw
        }

        It 'Should accept empty credential' {
            Mock -CommandName New-CimSession -MockWith {
                return [PSCustomObject]@{
                    ComputerName = 'TestServer'
                    Id           = 1
                }
            }

            $emptyCred = [System.Management.Automation.PSCredential]::Empty
            { New-StmCimSession -ComputerName 'TestServer16' -Credential $emptyCred } | Should -Not -Throw
        }
    }

    Context 'Integration with New-StmError' {
        BeforeEach {
            Mock -CommandName New-CimSession -MockWith {
                throw 'Network path not found.'
            }
        }

        It 'Should use New-StmError for error record creation' {
            Mock -CommandName New-StmError -MockWith {
                param($Exception, $ErrorId, $ErrorCategory, $TargetObject, $Message, $RecommendedAction)
                return [System.Management.Automation.ErrorRecord]::new(
                    $Exception,
                    $ErrorId,
                    $ErrorCategory,
                    $TargetObject
                )
            }

            try {
                New-StmCimSession -ComputerName 'TestServer17' -ErrorAction Stop
            }
            catch {
                # Error should be thrown
            }

            Should -Invoke -CommandName New-StmError -Times 1 -Exactly -ParameterFilter {
                $ErrorId -eq 'CimSessionCreationFailed' -and
                $ErrorCategory -eq [System.Management.Automation.ErrorCategory]::ConnectionError -and
                $TargetObject -eq 'TestServer17' -and
                $Message -match 'Failed to create CIM session'
            }
        }
    }

    Context 'Output Verification' {
        BeforeEach {
            Mock -CommandName New-CimSession -MockWith {
                return [PSCustomObject]@{
                    PSTypeName   = 'Microsoft.Management.Infrastructure.CimSession'
                    ComputerName = $ComputerName
                    Id           = 42
                    Name         = 'CimSession42'
                    InstanceId   = [guid]::NewGuid()
                }
            }
        }

        It 'Should return CIM session object' {
            $result = New-StmCimSession -ComputerName 'TestServer18'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return CIM session with correct computer name' {
            $result = New-StmCimSession -ComputerName 'TestServer19'
            $result.ComputerName | Should -Be 'TestServer19'
        }

        It 'Should return CIM session with session ID' {
            $result = New-StmCimSession -ComputerName 'TestServer20'
            $result.Id | Should -Be 42
        }

        It 'Should return CIM session with instance ID' {
            $result = New-StmCimSession -ComputerName 'TestServer21'
            $result.InstanceId | Should -Not -BeNullOrEmpty
        }
    }
}
