BeforeAll {

    # NEW: Pre-Specify RegEx Matching Patterns
    $gitTagMatchRegEx   = 'tag:\s?.(\d+(\.\d+)*)' # NOTE - was 'tag:\s*(\d+(?:\.\d+)*)' previously
    $changelogTagMatchRegEx = "^##\s\[(?<Version>(\d+\.){1,3}\d+)\]"
    # $moduleName         = $env:BHProjectName
    $moduleName         = 'ScheduledTasksManager'
    # $manifest           = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $sourceManifestPath = Join-Path -Path $PSScriptRoot -ChildPath "..\$moduleName\$($moduleName).psd1"
    $manifest           = Import-PowerShellDataFile -Path $sourceManifestPath
    # $outputDir          = Join-Path -Path $ENV:BHProjectPath -ChildPath 'Output'
    $outputDir          = Join-Path -Path $PSScriptRoot -ChildPath '..\Output'
    $outputModDir       = Join-Path -Path $outputDir -ChildPath $moduleName
    $outputModVerDir    = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputManifestPath = Join-Path -Path $outputModVerDir -ChildPath "$($moduleName).psd1"
    $manifestParameters = @{
        Path          = $outputManifestPath
        Verbose       = $false
        ErrorAction   = 'Stop'
        WarningAction = 'SilentlyContinue'
    }
    $manifestData = Test-ModuleManifest @manifestParameters

    $changelogPath    = Join-Path -Path $PSScriptRoot -ChildPath '..\CHANGELOG.md'
    $changelogVersion = Get-Content $changelogPath | ForEach-Object {
        if ($_ -match $changelogTagMatchRegEx) {
            $changelogVersion = $matches.Version
            break
        }
    }

    $script:manifest    = $null
}
Describe 'Module manifest' {

    Context 'Validation' {

        It 'Has a valid root module' {
            $manifestData.RootModule | Should -Be "$($moduleName).psm1"
        }

        It 'Has a valid version in the manifest' {
            $manifestData.Version -as [Version] | Should -Not -BeNullOrEmpty
        }

        It 'Has a valid description' {
            $manifestData.Description | Should -Not -BeNullOrEmpty
        }

        It 'Has a valid author' {
            $manifestData.Author | Should -Not -BeNullOrEmpty
        }

        It 'Has a valid guid' {
            {[guid]::Parse($manifestData.Guid)} | Should -Not -Throw
        }

        It 'Has a valid copyright' {
            $manifestData.CopyRight | Should -Not -BeNullOrEmpty
        }

        It 'Has a valid version in the changelog' {
            $changelogVersion               | Should -Not -BeNullOrEmpty
            $changelogVersion -as [Version] | Should -Not -BeNullOrEmpty
        }

        It 'Changelog and manifest versions are the same' {
            $changelogVersion -as [Version] | Should -Be ( $manifestData.Version -as [Version] )
        }
    }
}

Describe 'Git tagging' -Skip {
    BeforeAll {
        $gitTagVersion = $null

        # Ensure to only pull in a single git executable (in case multiple git's are found on path).
        if ($git = (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)[0]) {
            $thisCommit = & $git log --decorate --oneline HEAD~1..HEAD
            if ($thisCommit -match $gitTagMatchRegEx) { $gitTagVersion = $matches[1] }
        }
    }

    It 'Is tagged with a valid version' {
        $gitTagVersion               | Should -Not -BeNullOrEmpty
        $gitTagVersion -as [Version] | Should -Not -BeNullOrEmpty
    }

    It 'Matches manifest version' {
        $manifestData.Version -as [Version] | Should -Be ( $gitTagVersion -as [Version])
    }
}
