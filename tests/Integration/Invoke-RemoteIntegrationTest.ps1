<#
.SYNOPSIS
    Manages integration tests on a remote Hyper-V server.

.DESCRIPTION
    Consolidated script for remote integration test operations:
    - Diagnose: Test connectivity to the remote server
    - Deploy: Copy lab management scripts to the remote server
    - Test: Copy module and run integration tests on the remote server
    - Cleanup: Remove temporary files from the remote server

.PARAMETER Action
    The action to perform: Diagnose, Deploy, Test, or Cleanup.

.PARAMETER TargetServer
    The remote server hostname. Defaults to config value.

.EXAMPLE
    .\Invoke-RemoteIntegrationTest.ps1 -Action Diagnose

.EXAMPLE
    .\Invoke-RemoteIntegrationTest.ps1 -Action Test
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Diagnose', 'Deploy', 'Test', 'Cleanup')]
    [string]$Action,

    [string]$TargetServer
)

$ErrorActionPreference = 'Stop'

# Load configuration
Import-Module "$PSScriptRoot\IntegrationTestConfig.psm1" -Force
$config = Get-IntegrationTestConfig -Required

if (-not $TargetServer) {
    $TargetServer = $config.remote.hostname
}

$labSetupPath = $config.remote.labSetupPath
$localModulePath = $config.remote.localModulePath
$labModulePath = $config.paths.labModulePath

# Helper function for UNC paths
function Get-UncPath {
    param([string]$Server, [string]$LocalPath)
    "\\$Server\c`$\$($LocalPath.TrimStart('C:\'))"
}

switch ($Action) {
    'Diagnose' {
        Write-Host "=== Remote Connection Diagnostics ===" -ForegroundColor Cyan
        Write-Host "Target: $TargetServer"
        Write-Host ""

        # Test 1: Ping
        Write-Host "1. Testing ping..." -ForegroundColor Yellow
        $ping = Test-Connection -ComputerName $TargetServer -Count 1 -ErrorAction SilentlyContinue
        if ($ping) {
            Write-Host "   PASS: Ping successful ($($ping.Address))" -ForegroundColor Green
        } else {
            Write-Host "   FAIL: Cannot ping $TargetServer" -ForegroundColor Red
        }

        # Test 2: WinRM port
        Write-Host ""
        Write-Host "2. Testing WinRM port (5985)..." -ForegroundColor Yellow
        $tcp = Test-NetConnection -ComputerName $TargetServer -Port 5985 -WarningAction SilentlyContinue
        if ($tcp.TcpTestSucceeded) {
            Write-Host "   PASS: Port 5985 is open" -ForegroundColor Green
        } else {
            Write-Host "   FAIL: Port 5985 is not accessible" -ForegroundColor Red
        }

        # Test 3: TrustedHosts
        Write-Host ""
        Write-Host "3. Checking TrustedHosts..." -ForegroundColor Yellow
        $trusted = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
        Write-Host "   Current value: $trusted"
        if ($trusted -eq '*' -or $trusted -match $TargetServer) {
            Write-Host "   PASS: $TargetServer is trusted" -ForegroundColor Green
        } else {
            Write-Host "   WARN: $TargetServer may not be in TrustedHosts" -ForegroundColor Yellow
        }

        # Test 4: SMB access
        Write-Host ""
        Write-Host "4. Testing SMB access..." -ForegroundColor Yellow
        $uncPath = "\\$TargetServer\c`$"
        if (Test-Path $uncPath -ErrorAction SilentlyContinue) {
            Write-Host "   PASS: SMB access to $uncPath" -ForegroundColor Green
        } else {
            Write-Host "   FAIL: Cannot access $uncPath" -ForegroundColor Red
        }

        # Test 5: PSSession
        Write-Host ""
        Write-Host "5. Testing PowerShell remoting..." -ForegroundColor Yellow
        try {
            $session = New-PSSession -ComputerName $TargetServer -ErrorAction Stop
            $info = Invoke-Command -Session $session -ScriptBlock {
                "$env:COMPUTERNAME - PowerShell $($PSVersionTable.PSVersion)"
            }
            Write-Host "   PASS: Connected to $info" -ForegroundColor Green
            Remove-PSSession $session
        } catch {
            Write-Host "   FAIL: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "   TIP: You may need to run with explicit credentials" -ForegroundColor Gray
        }

        Write-Host ""
        Write-Host "=== Diagnostics Complete ===" -ForegroundColor Cyan
    }

    'Deploy' {
        Write-Host "=== Deploying Lab Scripts to $TargetServer ===" -ForegroundColor Cyan

        $destPath = Get-UncPath -Server $TargetServer -LocalPath $labSetupPath
        New-Item -Path $destPath -ItemType Directory -Force | Out-Null

        # Copy lab management scripts
        $sourceDir = $PSScriptRoot
        $scripts = @(
            'IntegrationTestConfig.psm1',
            'Initialize-IntegrationLab.ps1',
            'LabDefinition.ps1',
            'Start-IntegrationLab.ps1',
            'Stop-IntegrationLab.ps1',
            'Remove-IntegrationLab.ps1'
        )

        foreach ($script in $scripts) {
            $sourcePath = Join-Path $sourceDir $script
            if (Test-Path $sourcePath) {
                Copy-Item $sourcePath -Destination $destPath -Force
                Write-Host "  Copied: $script" -ForegroundColor Gray
            }
        }

        # Copy config file to remote root
        $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $configFile = Join-Path $repoRoot 'integration-test-config.json'
        if (Test-Path $configFile) {
            $remoteRoot = "\\$TargetServer\c`$"
            Copy-Item $configFile -Destination $remoteRoot -Force
            Write-Host "  Copied: integration-test-config.json -> C:\" -ForegroundColor Gray
        }

        Write-Host ""
        Write-Host "Deployed to ${TargetServer}:$labSetupPath" -ForegroundColor Green
        Get-ChildItem $destPath | Format-Table Name, Length -AutoSize
    }

    'Test' {
        Write-Host "=== Running Integration Tests on $TargetServer ===" -ForegroundColor Cyan

        $session = New-PSSession -ComputerName $TargetServer

        # Copy module
        Write-Host "Copying module..." -ForegroundColor Yellow
        Invoke-Command -Session $session -ScriptBlock {
            param($ModulePath)
            if (Test-Path $ModulePath) {
                Remove-Item $ModulePath -Recurse -Force
            }
        } -ArgumentList $labModulePath
        Copy-Item -Path "$localModulePath\ScheduledTasksManager" -Destination 'C:\' -ToSession $session -Recurse -Force
        Write-Host "  Module copied to $labModulePath" -ForegroundColor Gray

        # Ensure remote directory exists
        Invoke-Command -Session $session -ScriptBlock {
            param($Path)
            if (-not (Test-Path $Path)) {
                New-Item -Path $Path -ItemType Directory -Force | Out-Null
            }
        } -ArgumentList $labSetupPath

        # Copy test files
        Write-Host "Copying test files..." -ForegroundColor Yellow
        $testFiles = @(
            'ClusteredScheduledTask.Integration.Tests.ps1',
            'Start-IntegrationLab.ps1',
            'IntegrationTestConfig.psm1'
        )
        foreach ($file in $testFiles) {
            Copy-Item -Path "$PSScriptRoot\$file" -Destination "$labSetupPath\" -ToSession $session -Force
            Write-Host "  Copied: $file" -ForegroundColor Gray
        }

        # Copy config file
        $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $configFile = Join-Path $repoRoot 'integration-test-config.json'
        if (Test-Path $configFile) {
            Copy-Item -Path $configFile -Destination 'C:\' -ToSession $session -Force
            Write-Host "  Copied: integration-test-config.json -> C:\" -ForegroundColor Gray
        }

        # Run tests and capture results
        Write-Host ""
        Write-Host "Running Pester tests..." -ForegroundColor Yellow
        Write-Host ""

        $testResult = Invoke-Command -Session $session -ScriptBlock {
            param($LabSetupPath)
            Set-Location $LabSetupPath

            $pesterConfig = New-PesterConfiguration
            $pesterConfig.Run.Path = "$LabSetupPath\ClusteredScheduledTask.Integration.Tests.ps1"
            $pesterConfig.Run.PassThru = $true
            $pesterConfig.Output.Verbosity = 'Detailed'

            $result = Invoke-Pester -Configuration $pesterConfig

            # Return summary that can be serialized across the remote session
            [PSCustomObject]@{
                TotalCount   = $result.TotalCount
                PassedCount  = $result.PassedCount
                FailedCount  = $result.FailedCount
                SkippedCount = $result.SkippedCount
                Duration     = $result.Duration.ToString()
            }
        } -ArgumentList $labSetupPath

        Remove-PSSession $session

        Write-Host ""
        Write-Host "=== Test Run Complete ===" -ForegroundColor Cyan
        $resultColor = if ($testResult.FailedCount -gt 0) { 'Red' } else { 'Green' }
        Write-Host "  Passed: $($testResult.PassedCount) | Failed: $($testResult.FailedCount) | Skipped: $($testResult.SkippedCount)" -ForegroundColor $resultColor

        # Fail if tests failed
        if ($testResult.FailedCount -gt 0) {
            throw "$($testResult.FailedCount) integration test(s) failed on remote server $TargetServer."
        }
    }

    'Cleanup' {
        Write-Host "=== Cleaning Up $TargetServer ===" -ForegroundColor Cyan

        $destPath = Get-UncPath -Server $TargetServer -LocalPath $labSetupPath

        if (Test-Path $destPath) {
            Write-Host "Removing $labSetupPath..." -ForegroundColor Yellow
            Remove-Item $destPath -Recurse -Force
            Write-Host "  Removed: $labSetupPath" -ForegroundColor Gray
        } else {
            Write-Host "  $labSetupPath not found (already clean)" -ForegroundColor Gray
        }

        # Remove config from root
        $remoteConfig = "\\$TargetServer\c`$\integration-test-config.json"
        if (Test-Path $remoteConfig) {
            Remove-Item $remoteConfig -Force
            Write-Host "  Removed: C:\integration-test-config.json" -ForegroundColor Gray
        }

        # Remove module copy
        $remoteModule = Get-UncPath -Server $TargetServer -LocalPath $labModulePath
        if (Test-Path $remoteModule) {
            Remove-Item $remoteModule -Recurse -Force
            Write-Host "  Removed: $labModulePath" -ForegroundColor Gray
        }

        Write-Host ""
        Write-Host "Cleanup complete." -ForegroundColor Green
    }
}
