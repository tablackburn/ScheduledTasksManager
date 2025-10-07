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
    $PSBPreference.Test.CodeCoverage.OutputFormat = 'CoverageGutters'
    $PSBPreference.Test.CodeCoverage.Files = '../ScheduledTasksManager/**/*.ps1'
}

Task -Name 'Default' -Depends 'Test'

Task -Name 'Test' -FromModule 'PowerShellBuild' -MinimumVersion '0.7.3'
