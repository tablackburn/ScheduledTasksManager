<#
.SYNOPSIS
    Stops the integration test lab VMs.

.DESCRIPTION
    Gracefully shuts down all VMs in the integration test lab.
    The lab remains in place for future test runs.

.PARAMETER CreateSnapshot
    Create a snapshot before stopping. Useful for preserving test state.

.PARAMETER SnapshotName
    Name for the snapshot. Defaults to timestamp-based name.

.EXAMPLE
    .\Stop-IntegrationLab.ps1

.EXAMPLE
    .\Stop-IntegrationLab.ps1 -CreateSnapshot -SnapshotName 'AfterTestRun'
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [switch]$CreateSnapshot,

    [string]$SnapshotName
)

$ErrorActionPreference = 'Stop'

# Load configuration
Import-Module "$PSScriptRoot\IntegrationTestConfig.psm1" -Force
$config = Get-IntegrationTestConfig -Required

$labName = $config.lab.name

Write-Host "Stopping integration lab..." -ForegroundColor Cyan

# Import AutomatedLab
Import-Module AutomatedLab -Force

# Check if lab exists
$existingLab = Get-Lab -List | Where-Object { $_ -eq $labName }
if (-not $existingLab) {
    Write-Warning "Lab '$labName' not found. Nothing to stop."
    return
}

# Import the lab
Import-Lab -Name $labName -NoValidation

# Create snapshot if requested
if ($CreateSnapshot) {
    if (-not $SnapshotName) {
        $SnapshotName = "TestRun_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }
    Write-Host "  Creating snapshot '$SnapshotName'..." -ForegroundColor Yellow
    Checkpoint-LabVM -All -SnapshotName $SnapshotName
    Write-Host "  [OK] Snapshot created" -ForegroundColor Green
}

# Stop VMs
Write-Host "  Stopping VMs..." -ForegroundColor Yellow
Stop-LabVM -All -Wait
Write-Host "  [OK] All VMs stopped" -ForegroundColor Green

Write-Host "`nLab stopped. VMs preserved for next test run." -ForegroundColor Green
Write-Host "Run Start-IntegrationLab.ps1 to start again." -ForegroundColor Gray
