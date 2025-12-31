<#
.SYNOPSIS
    Runs integration tests from GitHub Actions CI via Tailscale.

.DESCRIPTION
    This script is called by the GitHub Actions Integration workflow.
    It connects to the Hyper-V host via Tailscale and runs the integration
    tests using the existing AutomatedLab infrastructure.

    Environment variables required:
    - HYPERV_HOST: Tailscale hostname of the Hyper-V host
    - HYPERV_USER: Windows username for remoting
    - HYPERV_PASS: Windows password for remoting

.PARAMETER RestoreSnapshot
    If specified, restores the lab to the baseline snapshot before testing.

.EXAMPLE
    $env:HYPERV_HOST = 'myhost.tail12345.ts.net'
    $env:HYPERV_USER = 'Administrator'
    $env:HYPERV_PASS = 'MyPassword'
    .\Invoke-CIIntegrationTest.ps1
#>

[CmdletBinding()]
param(
    [switch]$RestoreSnapshot
)

$ErrorActionPreference = 'Stop'

# =============================================================================
# Configuration
# =============================================================================

$TargetServer = $env:HYPERV_HOST
$Username = $env:HYPERV_USER
$Password = $env:HYPERV_PASS

if ([string]::IsNullOrEmpty($TargetServer)) {
    throw "HYPERV_HOST environment variable is not set"
}
if ([string]::IsNullOrEmpty($Username)) {
    throw "HYPERV_USER environment variable is not set"
}
if ([string]::IsNullOrEmpty($Password)) {
    throw "HYPERV_PASS environment variable is not set"
}

# Paths on the remote Hyper-V host
$LabSetupPath = 'C:\LabSetup'
$LabModulePath = 'C:\ScheduledTasksManager'
$ConfigPath = 'C:\integration-test-config.json'

# Local paths
$LocalModulePath = Join-Path $PSScriptRoot '..\..\ScheduledTasksManager' | Resolve-Path
$LocalConfigPath = Join-Path $PSScriptRoot '..\..\integration-test-config.json' | Resolve-Path
$OutputDir = Join-Path $PSScriptRoot 'out'

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " CI Integration Tests" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target Server: $TargetServer"
Write-Host "Username: $Username"
Write-Host "Restore Snapshot: $RestoreSnapshot"
Write-Host ""

# =============================================================================
# Create Credential and Connect
# =============================================================================

Write-Host "Connecting to remote host..." -ForegroundColor Yellow

$securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
$credential = [PSCredential]::new($Username, $securePassword)

try {
    $session = New-PSSession -ComputerName $TargetServer -Credential $credential -ErrorAction Stop
    Write-Host "  Connected to $TargetServer" -ForegroundColor Green
}
catch {
    Write-Host "  Failed to connect: $($_.Exception.Message)" -ForegroundColor Red
    throw
}

# =============================================================================
# Prepare Remote Environment
# =============================================================================

Write-Host ""
Write-Host "Preparing remote environment..." -ForegroundColor Yellow

# Ensure remote directories exist
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

# =============================================================================
# Copy Files to Remote Host
# =============================================================================

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
    $sourcePath = Join-Path $PSScriptRoot $file
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination "$LabSetupPath\" -ToSession $session -Force
        Write-Host "    -> $file" -ForegroundColor Gray
    }
}

Write-Host "  Files copied successfully" -ForegroundColor Green

# =============================================================================
# Run Tests on Remote Host
# =============================================================================

Write-Host ""
Write-Host "Running integration tests on remote host..." -ForegroundColor Yellow
Write-Host ""

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
} -ArgumentList $LabSetupPath, $RestoreSnapshot

# =============================================================================
# Retrieve Test Results
# =============================================================================

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

# =============================================================================
# Cleanup and Summary
# =============================================================================

Remove-PSSession $session

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

# Exit with appropriate code
if ($testResult.FailedCount -gt 0) {
    Write-Host "Integration tests FAILED" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "Integration tests PASSED" -ForegroundColor Green
    exit 0
}
