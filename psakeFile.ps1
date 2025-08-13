Properties {
    # Set this to $true to create a module with a monolithic PSM1
    $PSBPreference.Build.CompileModule = $false
    $PSBPreference.Help.DefaultLocale = 'en-US'
    $PSBPreference.Test.OutputFile = 'out/testResults.xml'
    $PSBPreference.Test.OutputFormat = 'JUnitXml'
}

Task -Name 'Default' -Depends 'Test'

Task -Name 'Test' -FromModule 'PowerShellBuild' -MinimumVersion '0.7.3'
