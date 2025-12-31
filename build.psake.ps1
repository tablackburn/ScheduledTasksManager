param()

# Allow end users to add their own custom psake tasks
$customPsakeFile = Join-Path -Path $PSScriptRoot -ChildPath 'custom.psake.ps1'
if (Test-Path -Path $customPsakeFile) {
    Include -FileNamePathToInclude $customPsakeFile
}

properties {
    # Set the default locale for help content (PowerShellBuild 0.7.3+)
    # The default is (Get-UICulture).Name so we set it to 'en-US' to ensure consistent help content
    # regardless of the system locale
    $PSBPreference.Help.DefaultLocale = 'en-US'

    # Set this to $true to create a module with a monolithic PSM1
    $PSBPreference.Build.CompileModule = $false

    # Test result configuration (PowerShellBuild 0.7.3+)
    # The output is used by the CI workflow in GitHub Actions
    $PSBPreference.Test.OutputFile = 'out/testResults.xml'
    $PSBPreference.Test.OutputFormat = 'NUnitXml'

    # Code coverage configuration (PowerShellBuild 0.7.3+)
    $PSBPreference.Test.CodeCoverage.Enabled = $true
    $PSBPreference.Test.CodeCoverage.OutputFile = '../coverage.xml'
    $PSBPreference.Test.CodeCoverage.OutputFormat = 'JaCoCo'
    $PSBPreference.Test.CodeCoverage.Files = '../ScheduledTasksManager/**/*.ps1'
    # WORKAROUND: PowerShellBuild 0.7.3 has a bug in Test-PSBuildPester.ps1 line 118
    # It uses [Math]::Truncate([int]$_.covered / $total) which truncates 0.886 to 0
    # instead of 88.6%. Setting threshold to 0 until bug is fixed.
    # See: https://github.com/psake/PowerShellBuild/issues (bug reported)
    $PSBPreference.Test.CodeCoverage.Threshold = 0.0

    # PSScriptAnalyzer configuration (PowerShellBuild 0.7.3+)
    # Disable built-in analysis due to PowerShellBuild 0.7.3 bug:
    # Test-PSBuildScriptAnalysis.ps1 line 32-34 has typo "$_Severity" instead of "$_.Severity"
    # causing null reference exception. We use a custom ScriptAnalysis task until fixed.
    $PSBPreference.Test.ScriptAnalysis.Enabled = $false
    $PSBPreference.Test.ScriptAnalysis.SettingsPath = Join-Path -Path $PSScriptRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'
}

Task -Name 'Default' -Depends 'Test'

Task -Name 'Init_Integration' -Description 'Load integration test environment variables from local.settings.ps1' {
    $localSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath 'tests/local.settings.ps1'
    if (Test-Path -Path $localSettingsPath) {
        Write-Host "Loading integration test settings from tests/local.settings.ps1" -ForegroundColor Cyan
        . $localSettingsPath
    } else {
        Write-Host "No local.settings.ps1 found - integration tests will use default configuration" -ForegroundColor Yellow
    }
}

# Custom Pester task that excludes Integration tests
# This replaces the PowerShellBuild Pester task via $PSBPesterDependency
$unitTestPreReqs = {
    $result = $true
    if (-not $PSBPreference.Test.Enabled) {
        Write-Warning 'Pester testing is not enabled.'
        $result = $false
    }
    if (-not (Get-Module -Name Pester -ListAvailable)) {
        Write-Warning 'Pester module is not installed'
        $result = $false
    }
    if (-not (Test-Path -Path $PSBPreference.Test.RootDir)) {
        Write-Warning "Test directory [$($PSBPreference.Test.RootDir)] not found"
        $result = $false
    }
    return $result
}

Task -Name 'UnitTest' -Depends 'Build' -PreCondition $unitTestPreReqs -Description 'Execute Pester tests (excluding Integration)' {
    # Remove any previously imported project modules and import from the output dir
    $moduleManifest = Join-Path $PSBPreference.Build.ModuleOutDir "$($PSBPreference.General.ModuleName).psd1"
    Get-Module $PSBPreference.General.ModuleName | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module $moduleManifest -Force

    Push-Location -LiteralPath $PSBPreference.Test.RootDir

    try {
        $configuration = [PesterConfiguration]::Default
        $configuration.Output.Verbosity = 'Detailed'
        $configuration.Run.PassThru = $true
        $configuration.Run.SkipRemainingOnFailure = 'None'
        $configuration.Run.ExcludePath = @('**/Integration/**')  # Exclude integration tests
        $configuration.TestResult.Enabled = -not [string]::IsNullOrEmpty($PSBPreference.Test.OutputFile)
        $configuration.TestResult.OutputPath = $PSBPreference.Test.OutputFile
        $configuration.TestResult.OutputFormat = $PSBPreference.Test.OutputFormat

        if ($PSBPreference.Test.CodeCoverage.Enabled) {
            $configuration.CodeCoverage.Enabled = $true
            if ($PSBPreference.Test.CodeCoverage.Files.Count -gt 0) {
                $configuration.CodeCoverage.Path = $PSBPreference.Test.CodeCoverage.Files
            }
            $configuration.CodeCoverage.OutputPath = $PSBPreference.Test.CodeCoverage.OutputFile
            $configuration.CodeCoverage.OutputFormat = $PSBPreference.Test.CodeCoverage.OutputFormat
        }

        $testResult = Invoke-Pester -Configuration $configuration

        if ($testResult.FailedCount -gt 0) {
            throw 'One or more Pester tests failed'
        }
    }
    finally {
        Pop-Location
        Remove-Module $PSBPreference.General.ModuleName -ErrorAction SilentlyContinue
    }
}

# Custom ScriptAnalysis task to work around PowerShellBuild 0.7.3 bug
# Bug: Test-PSBuildScriptAnalysis.ps1 uses "$_Severity" instead of "$_.Severity" (missing dot)
# This causes null reference exception when PSScriptAnalyzer returns results
$scriptAnalysisPreReqs = {
    $result = $true
    if (-not (Get-Module -Name PSScriptAnalyzer -ListAvailable)) {
        Write-Warning 'PSScriptAnalyzer module is not installed'
        $result = $false
    }
    return $result
}

Task -Name 'ScriptAnalysis' -Depends 'Build' -PreCondition $scriptAnalysisPreReqs -Description 'Execute PSScriptAnalyzer' {
    # Get only .ps1 files (exclude .psd1 module manifests which are auto-generated)
    $ps1Files = Get-ChildItem -Path $PSBPreference.Build.ModuleOutDir -Filter '*.ps1' -Recurse

    $results = @()
    foreach ($file in $ps1Files) {
        $analysisParams = @{
            Path        = $file.FullName
            Settings    = $PSBPreference.Test.ScriptAnalysis.SettingsPath
            ErrorAction = 'SilentlyContinue'
        }
        $results += Invoke-ScriptAnalyzer @analysisParams
    }

    if ($results) {
        $results | Format-Table -AutoSize

        $errors = $results | Where-Object { $_.Severity -eq 'Error' }
        if ($errors) {
            throw "PSScriptAnalyzer found $($errors.Count) error(s)"
        }

        $warnings = $results | Where-Object { $_.Severity -eq 'Warning' }
        if ($warnings) {
            Write-Warning "PSScriptAnalyzer found $($warnings.Count) warning(s)"
        }
    }
    else {
        Write-Host 'PSScriptAnalyzer found no issues' -ForegroundColor Green
    }
}

# Use UnitTest and custom ScriptAnalysis instead of PowerShellBuild's built-in tasks
$PSBTestDependency = @('Init_Integration', 'UnitTest', 'ScriptAnalysis')
Task -Name 'Test' -FromModule 'PowerShellBuild' -MinimumVersion '0.7.3'

# Integration tests require AutomatedLab and a Hyper-V host
# Supports three modes:
#   - ci: GitHub Actions via Tailscale (auto-detected when HYPERV_* env vars are set)
#   - local: AutomatedLab on this machine (default)
#   - remote: AutomatedLab on a remote server (set lab.mode = "remote" in config)
Task -Name 'Integration' -Description 'Run integration tests against a real failover cluster' {
    $integrationTestPath = Join-Path $PSScriptRoot 'tests/Integration'

    # Check for CI environment (GitHub Actions with Tailscale)
    # CI mode is auto-detected when all HYPERV_* environment variables are set
    $isCIMode = $env:HYPERV_HOST -and $env:HYPERV_USER -and $env:HYPERV_PASS

    if ($isCIMode) {
        # CI mode: Connect to remote Hyper-V host using environment variable credentials
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host " CI Integration Tests" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Target Server: $env:HYPERV_HOST"
        Write-Host "Username: $env:HYPERV_USER"
        Write-Host "Restore Snapshot: $($Properties -and $Properties.RestoreSnapshot -eq $true)"
        Write-Host ""

        # Remote paths on Hyper-V host
        $LabSetupPath = 'C:\LabSetup'
        $LabModulePath = 'C:\ScheduledTasksManager'
        $ConfigPath = 'C:\integration-test-config.json'

        # Local paths
        $LocalModulePath = Join-Path $PSScriptRoot 'ScheduledTasksManager'
        $LocalConfigPath = Join-Path $PSScriptRoot 'integration-test-config.json'
        $OutputDir = Join-Path $integrationTestPath 'out'

        # Create credential and connect
        Write-Host "Connecting to remote host..." -ForegroundColor Yellow
        $securePassword = ConvertTo-SecureString -String $env:HYPERV_PASS -AsPlainText -Force -ErrorAction Stop
        $credential = [PSCredential]::new($env:HYPERV_USER, $securePassword)

        $session = $null
        try {
            $session = New-PSSession -ComputerName $env:HYPERV_HOST -Credential $credential -ErrorAction Stop
            Write-Host "  Connected to $env:HYPERV_HOST" -ForegroundColor Green

            # Prepare remote environment
            Write-Host ""
            Write-Host "Preparing remote environment..." -ForegroundColor Yellow

            Invoke-Command -Session $session -ScriptBlock {
                param($LabSetupPath, $LabModulePath)

                # Clean up any previous test artifacts
                if (Test-Path $LabModulePath) {
                    Remove-Item $LabModulePath -Recurse -Force
                }
                if (Test-Path $LabSetupPath) {
                    Remove-Item $LabSetupPath -Recurse -Force
                }

                # Create directories
                New-Item -Path $LabSetupPath -ItemType Directory -Force | Out-Null
            } -ArgumentList $LabSetupPath, $LabModulePath

            Write-Host "  Cleaned up previous artifacts" -ForegroundColor Gray

            # Copy files to remote host
            Write-Host ""
            Write-Host "Copying files to remote host..." -ForegroundColor Yellow

            # Copy module
            Write-Host "  Copying module..." -ForegroundColor Gray
            Copy-Item -Path $LocalModulePath -Destination 'C:\' -ToSession $session -Recurse -Force
            Write-Host "    -> $LabModulePath" -ForegroundColor Gray

            # Copy config file
            Write-Host "  Copying config..." -ForegroundColor Gray
            Copy-Item -Path $LocalConfigPath -Destination 'C:\' -ToSession $session -Force
            Write-Host "    -> $ConfigPath" -ForegroundColor Gray

            # Copy test infrastructure files
            Write-Host "  Copying test infrastructure..." -ForegroundColor Gray
            $testFiles = @(
                'ClusteredScheduledTask.Integration.Tests.ps1',
                'Start-IntegrationLab.ps1',
                'Stop-IntegrationLab.ps1',
                'IntegrationTestConfig.psm1'
            )
            foreach ($file in $testFiles) {
                $sourcePath = Join-Path $integrationTestPath $file
                if (Test-Path $sourcePath) {
                    Copy-Item -Path $sourcePath -Destination "$LabSetupPath\" -ToSession $session -Force
                    Write-Host "    -> $file" -ForegroundColor Gray
                }
            }

            Write-Host "  Files copied successfully" -ForegroundColor Green

            # Run tests on remote host
            Write-Host ""
            Write-Host "Running integration tests on remote host..." -ForegroundColor Yellow
            Write-Host ""

            $restoreSnapshot = $Properties -and $Properties.RestoreSnapshot -eq $true
            $testResult = Invoke-Command -Session $session -ScriptBlock {
                param($LabSetupPath, $RestoreSnapshot)

                Set-Location $LabSetupPath

                # Import AutomatedLab and start the lab
                Import-Module AutomatedLab -Force
                Import-Module "$LabSetupPath\IntegrationTestConfig.psm1" -Force

                $config = Get-IntegrationTestConfig
                $labName = $config.lab.name

                Write-Host "  Lab: $labName" -ForegroundColor Gray

                # Import lab
                Import-Lab -Name $labName -NoValidation

                # Optionally restore snapshot
                if ($RestoreSnapshot) {
                    Write-Host "  Restoring baseline snapshot..." -ForegroundColor Yellow
                    Restore-LabVMSnapshot -All -SnapshotName $config.test.snapshotName
                    Start-Sleep -Seconds 5
                }

                # Ensure VMs are running
                Write-Host "  Ensuring VMs are running..." -ForegroundColor Gray
                $vms = Get-LabVM
                foreach ($vm in $vms) {
                    if ($vm.State -ne 'Running') {
                        Start-LabVM -ComputerName $vm.Name -Wait
                    }
                }

                # Wait for VMs to be accessible
                Write-Host "  Waiting for VMs to be accessible..." -ForegroundColor Gray
                Wait-LabVM -ComputerName $config.virtualMachines.clusterNodes -TimeoutInMinutes 5

                # Copy module to cluster node
                Write-Host "  Copying module to cluster node..." -ForegroundColor Gray
                $testNode = $config.virtualMachines.clusterNodes[0]
                Copy-LabFileItem -Path 'C:\ScheduledTasksManager' -DestinationFolderPath 'C:\' -ComputerName $testNode

                # Run Pester tests
                Write-Host ""
                Write-Host "  Executing Pester tests..." -ForegroundColor Yellow
                Write-Host ""

                $pesterConfig = New-PesterConfiguration
                $pesterConfig.Run.Path = "$LabSetupPath\ClusteredScheduledTask.Integration.Tests.ps1"
                $pesterConfig.Run.PassThru = $true
                $pesterConfig.Output.Verbosity = 'Detailed'
                $pesterConfig.TestResult.Enabled = $true
                $pesterConfig.TestResult.OutputPath = "$LabSetupPath\testResults.xml"
                $pesterConfig.TestResult.OutputFormat = 'NUnitXml'

                $result = Invoke-Pester -Configuration $pesterConfig

                # Return serializable summary
                [PSCustomObject]@{
                    TotalCount      = $result.TotalCount
                    PassedCount     = $result.PassedCount
                    FailedCount     = $result.FailedCount
                    SkippedCount    = $result.SkippedCount
                    Duration        = $result.Duration.ToString()
                    TestResultsPath = "$LabSetupPath\testResults.xml"
                }
            } -ArgumentList $LabSetupPath, $restoreSnapshot

            # Retrieve test results
            Write-Host ""
            Write-Host "Retrieving test results..." -ForegroundColor Yellow

            # Ensure local output directory exists
            if (-not (Test-Path $OutputDir)) {
                New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
            }

            # Copy test results file
            $remoteResultsPath = $testResult.TestResultsPath
            $localResultsPath = Join-Path $OutputDir 'integrationTestResults.xml'

            try {
                Copy-Item -Path $remoteResultsPath -Destination $localResultsPath -FromSession $session -Force
                Write-Host "  Test results saved to: $localResultsPath" -ForegroundColor Gray
            }
            catch {
                Write-Host "  Could not retrieve test results file: $($_.Exception.Message)" -ForegroundColor Yellow
            }

            # Summary
            Write-Host ""
            Write-Host "=============================================" -ForegroundColor Cyan
            Write-Host " Test Results Summary" -ForegroundColor Cyan
            Write-Host "=============================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  Total:   $($testResult.TotalCount)"
            Write-Host "  Passed:  $($testResult.PassedCount)" -ForegroundColor Green
            if ($testResult.FailedCount -gt 0) {
                Write-Host "  Failed:  $($testResult.FailedCount)" -ForegroundColor Red
            } else {
                Write-Host "  Failed:  $($testResult.FailedCount)"
            }
            Write-Host "  Skipped: $($testResult.SkippedCount)" -ForegroundColor Yellow
            Write-Host "  Duration: $($testResult.Duration)"
            Write-Host ""

            # Fail build if tests failed
            if ($testResult.FailedCount -gt 0) {
                throw "$($testResult.FailedCount) integration test(s) failed."
            }
        }
        finally {
            Remove-PSSession $session -ErrorAction SilentlyContinue
        }
    }
    else {
        # Local or Remote mode: Use configuration file
        Import-Module "$integrationTestPath\IntegrationTestConfig.psm1" -Force
        if (-not (Test-IntegrationTestConfig)) {
            Write-Warning "Integration test configuration not found."
            Write-Warning "Copy integration-test-config.example.json to integration-test-config.json and update values."
            return
        }

        $config = Get-IntegrationTestConfig
        $labMode = if ($config.lab.mode) { $config.lab.mode } else { 'local' }

        Write-Host "Integration test mode: $labMode" -ForegroundColor Cyan

        if ($labMode -eq 'remote') {
            # Remote mode: Run tests on the remote server that has AutomatedLab
            $remoteHost = $config.remote.hostname
            Write-Host "Running integration tests on remote server: $remoteHost" -ForegroundColor Yellow

            & "$integrationTestPath\Invoke-RemoteIntegrationTest.ps1" -Action Test

            Write-Host "Remote integration tests completed." -ForegroundColor Green
        }
        else {
            # Local mode: AutomatedLab is on this machine
            $alModule = Get-Module -Name AutomatedLab -ListAvailable
            if (-not $alModule) {
                Write-Warning "AutomatedLab module not installed. Install it and run Initialize-IntegrationLab.ps1 first."
                Write-Warning "Install-Module -Name AutomatedLab -Scope CurrentUser"
                Write-Warning "Or set lab.mode to 'remote' in config to run tests on a remote server."
                return
            }

            Import-Module AutomatedLab -Force
            $labName = $config.lab.name
            $labs = Get-Lab -List -ErrorAction SilentlyContinue
            if ($labName -notin $labs) {
                Write-Warning "Integration lab '$labName' not deployed."
                Write-Warning "Run: $integrationTestPath\Initialize-IntegrationLab.ps1"
                return
            }

            # Start the lab
            Write-Host "Starting integration lab..." -ForegroundColor Cyan
            $labInfo = & "$integrationTestPath\Start-IntegrationLab.ps1"

            # Run integration tests
            Write-Host "Running integration tests..." -ForegroundColor Cyan
            $pesterConfig = New-PesterConfiguration
            $pesterConfig.Run.Path = "$integrationTestPath\*.Integration.Tests.ps1"
            $pesterConfig.Output.Verbosity = 'Detailed'
            $pesterConfig.TestResult.Enabled = $true
            $pesterConfig.TestResult.OutputPath = 'tests/Integration/out/integrationTestResults.xml'
            $pesterConfig.TestResult.OutputFormat = 'NUnitXml'

            $result = Invoke-Pester -Configuration $pesterConfig

            # Stop the lab
            Write-Host "Stopping integration lab..." -ForegroundColor Cyan
            & "$integrationTestPath\Stop-IntegrationLab.ps1"

            # Fail build if tests failed
            if ($result.FailedCount -gt 0) {
                throw "$($result.FailedCount) integration test(s) failed."
            }
        }
    }
}
