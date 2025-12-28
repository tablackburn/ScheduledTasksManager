<#
.SYNOPSIS
    Helper module for loading integration test configuration.

.DESCRIPTION
    Provides functions to load and validate the integration test configuration
    from the JSON config file at the repository root.
#>

$script:ConfigFileName = 'integration-test-config.json'
$script:ExampleConfigFileName = 'integration-test-config.example.json'

function Get-IntegrationTestConfigPath {
    <#
    .SYNOPSIS
        Gets the path to the integration test config file.
    #>
    [CmdletBinding()]
    param()

    # Find repo root by looking for .git folder
    $searchPath = $PSScriptRoot
    while ($searchPath -and -not (Test-Path (Join-Path $searchPath '.git'))) {
        $searchPath = Split-Path $searchPath -Parent
    }

    if (-not $searchPath) {
        # Fallback: assume two levels up from tests/Integration
        $searchPath = Join-Path $PSScriptRoot '..\..' | Resolve-Path
    }

    Join-Path $searchPath $script:ConfigFileName
}

function Test-IntegrationTestConfig {
    <#
    .SYNOPSIS
        Tests whether the integration test config file exists.

    .OUTPUTS
        Boolean indicating whether config exists.
    #>
    [CmdletBinding()]
    param()

    $configPath = Get-IntegrationTestConfigPath
    Test-Path $configPath
}

function Get-IntegrationTestConfig {
    <#
    .SYNOPSIS
        Loads the integration test configuration from JSON.

    .DESCRIPTION
        Reads the integration-test-config.json file from the repository root
        and returns it as a PowerShell object.

    .PARAMETER Required
        If specified, throws an error when config is missing instead of returning $null.

    .OUTPUTS
        PSCustomObject with configuration, or $null if not found (unless -Required).

    .EXAMPLE
        $config = Get-IntegrationTestConfig
        if ($config) {
            Write-Host "Lab name: $($config.lab.name)"
        }
    #>
    [CmdletBinding()]
    param(
        [switch]$Required
    )

    $configPath = Get-IntegrationTestConfigPath

    if (-not (Test-Path $configPath)) {
        if ($Required) {
            $examplePath = Join-Path (Split-Path $configPath -Parent) $script:ExampleConfigFileName
            throw @"
Integration test configuration not found.

To run integration tests:
  1. Copy '$script:ExampleConfigFileName' to '$script:ConfigFileName'
  2. Update the values for your environment

Expected config path: $configPath
"@
        }
        return $null
    }

    try {
        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
        return $config
    }
    catch {
        throw "Failed to parse integration test config at '$configPath': $_"
    }
}

function Write-IntegrationTestSkipWarning {
    <#
    .SYNOPSIS
        Writes a warning message explaining why integration tests are being skipped.
    #>
    [CmdletBinding()]
    param()

    Write-Warning @"
SKIPPED: Integration tests require configuration.
  Copy $script:ExampleConfigFileName to $script:ConfigFileName
  and update values for your environment.
"@
}

Export-ModuleMember -Function @(
    'Get-IntegrationTestConfigPath'
    'Test-IntegrationTestConfig'
    'Get-IntegrationTestConfig'
    'Write-IntegrationTestSkipWarning'
)
