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
# Supports two modes:
#   - local: AutomatedLab on this machine (default)
#   - remote: AutomatedLab on a remote server (set lab.mode = "remote" in config)
Task -Name 'Integration' -Description 'Run integration tests against a real failover cluster' {
    $integrationTestPath = Join-Path $PSScriptRoot 'tests/Integration'

    # Load configuration to determine mode
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
