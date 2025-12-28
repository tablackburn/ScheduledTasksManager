Properties {
    # Set the default locale for help content (PowerShellBuild 0.7.3+)
    # The default is (Get-UICulture).Name so we set it to 'en-US' to ensure consistent help content
    # regardless of the system locale
    $PSBPreference.Help.DefaultLocale = 'en-US'

    # Test result configuration (PowerShellBuild 0.7.3+)
    # The output is used by the CI workflow in GitHub Actions
    $PSBPreference.Test.OutputFile = 'out/testResults.xml'
    $PSBPreference.Test.OutputFormat = 'JUnitXml'

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
    # Override default to use project-specific PSScriptAnalyzer settings
    # Default is PowerShellBuild's own settings file, but we want to use ours
    $PSBPreference.Test.ScriptAnalysis.SettingsPath = 'PSScriptAnalyzerSettings.psd1'
}

Task -Name 'Default' -Depends 'Test'

Task -Name 'Test' -FromModule 'PowerShellBuild' -MinimumVersion '0.7.3'

# Integration tests require AutomatedLab and a Hyper-V host
# Run Initialize-IntegrationLab.ps1 first to deploy the test lab
Task -Name 'Integration' -Description 'Run integration tests against a real failover cluster' {
    $integrationTestPath = Join-Path $PSScriptRoot 'tests/Integration'

    # Check if lab is available
    $alModule = Get-Module -Name AutomatedLab -ListAvailable
    if (-not $alModule) {
        Write-Warning "AutomatedLab module not installed. Install it and run Initialize-IntegrationLab.ps1 first."
        Write-Warning "Install-Module -Name AutomatedLab -Scope CurrentUser"
        return
    }

    Import-Module AutomatedLab -Force
    $labs = Get-Lab -List -ErrorAction SilentlyContinue
    if ('StmTestLab' -notin $labs) {
        Write-Warning "Integration lab 'StmTestLab' not deployed."
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
    $pesterConfig.TestResult.OutputFormat = 'JUnitXml'

    $result = Invoke-Pester -Configuration $pesterConfig

    # Stop the lab
    Write-Host "Stopping integration lab..." -ForegroundColor Cyan
    & "$integrationTestPath\Stop-IntegrationLab.ps1"

    # Fail build if tests failed
    if ($result.FailedCount -gt 0) {
        throw "$($result.FailedCount) integration test(s) failed."
    }
}
