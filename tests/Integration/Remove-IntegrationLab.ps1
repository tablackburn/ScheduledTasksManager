<#
.SYNOPSIS
    Removes the integration test lab completely.

.DESCRIPTION
    Removes all VMs, VHDXs, and virtual networks associated with the
    integration test lab. Use this to free up disk space or start fresh.

.PARAMETER Force
    Skip confirmation prompt.

.EXAMPLE
    .\Remove-IntegrationLab.ps1

.EXAMPLE
    .\Remove-IntegrationLab.ps1 -Force
#>

#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Load configuration
Import-Module "$PSScriptRoot\IntegrationTestConfig.psm1" -Force
$config = Get-IntegrationTestConfig -Required

$labName = $config.lab.name
$dcName = $config.virtualMachines.domainController
$clusterNodes = $config.virtualMachines.clusterNodes

Write-Host "Removing integration lab..." -ForegroundColor Cyan

# Import AutomatedLab
Import-Module AutomatedLab -Force

# Check if lab exists
$existingLab = Get-Lab -List | Where-Object { $_ -eq $labName }
if (-not $existingLab) {
    Write-Host "Lab '$labName' not found. Nothing to remove." -ForegroundColor Yellow
    return
}

# Confirm removal
if (-not $Force) {
    $allVMs = @($dcName) + $clusterNodes
    Write-Host ""
    Write-Host "WARNING: This will permanently delete:" -ForegroundColor Yellow
    Write-Host "  - All VMs ($($allVMs -join ', '))" -ForegroundColor Gray
    Write-Host "  - All virtual hard disks" -ForegroundColor Gray
    Write-Host "  - Virtual network '$labName'" -ForegroundColor Gray
    Write-Host ""

    $confirmation = Read-Host "Are you sure you want to remove the lab? (yes/no)"
    if ($confirmation -ne 'yes') {
        Write-Host "Removal cancelled." -ForegroundColor Yellow
        return
    }
}

# Import and remove the lab
Write-Host "  Importing lab..." -ForegroundColor Yellow
Import-Lab -Name $labName -NoValidation

Write-Host "  Removing lab (this may take a few minutes)..." -ForegroundColor Yellow
Remove-Lab -Confirm:$false

Write-Host "`n[OK] Lab '$labName' removed successfully." -ForegroundColor Green
Write-Host "Run Initialize-IntegrationLab.ps1 to recreate." -ForegroundColor Gray
