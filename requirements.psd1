@{
    PSDepend = @{
        Version = '0.3.8'
    }
    PSDependOptions = @{
        Target = 'CurrentUser'
    }
    'Pester' = @{
        Version = '5.7.1'
        Parameters = @{
            SkipPublisherCheck = $true
        }
    }
    'psake' = @{
        Version = '4.9.1'
    }
    'BuildHelpers' = @{
        Version = '2.0.16'
    }
    'PowerShellBuild' = @{
        Version = '0.7.3'
    }
    'PSScriptAnalyzer' = @{
        Version = '1.24.0'
    }

    # Optional: Integration tests only
    # AutomatedLab is required for running integration tests against a real failover cluster
    # It is NOT installed automatically - install manually if needed:
    #   Install-Module -Name AutomatedLab -Scope CurrentUser
    # Then run: tests/Integration/Initialize-IntegrationLab.ps1
}
