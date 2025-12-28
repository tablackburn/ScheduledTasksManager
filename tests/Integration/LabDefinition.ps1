<#
.SYNOPSIS
    AutomatedLab definition for ScheduledTasksManager integration testing.

.DESCRIPTION
    Defines a minimal Windows Failover Cluster lab environment for testing
    clustered scheduled task functionality. Creates:
    - 1 Domain Controller
    - 2 Cluster Nodes

.NOTES
    This script is called by Initialize-IntegrationLab.ps1 and should not
    be run directly.

    Prerequisites:
    - Hyper-V enabled on the local machine
    - AutomatedLab module installed
    - Windows Server ISO available (will be downloaded if not present)
    - Administrator privileges
    - integration-test-config.json configured in repo root
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Load configuration
Import-Module "$PSScriptRoot\IntegrationTestConfig.psm1" -Force
$config = Get-IntegrationTestConfig -Required

# Get lab sources path
$labSources = Get-LabSourcesLocation

# Lab configuration (from config file)
$labName = $config.lab.name
$domainName = $config.lab.domainName
$adminUser = $config.lab.adminUser
$adminPassword = $config.lab.adminPassword
$addressSpace = $config.network.addressSpace
$clusterName = $config.cluster.name
$clusterIp = $config.network.clusterIp
$dcName = $config.virtualMachines.domainController
$clusterNodes = $config.virtualMachines.clusterNodes

# Detect available operating systems FIRST (before creating lab definition)
# This ensures we scan ISOs before AutomatedLab caches anything
Write-Host "  Scanning available operating systems..." -ForegroundColor Gray
$availableOS = Get-LabAvailableOperatingSystem -Path $labSources

# Prefer Server Core (smaller, faster, less RAM/storage) over Desktop Experience
# Prefer oldest version still under mainstream support (2022) for compatibility with most environments
$serverOS = $availableOS | Where-Object {
    $_.OperatingSystemName -match 'Windows Server.*(2019|2022|2025).*(Datacenter|Standard)' -and
    $_.OperatingSystemName -notmatch 'Essentials'
} | Sort-Object {
    $score = 0
    # Prefer oldest version still under mainstream support (most common in production)
    # Server 2019 mainstream ended Jan 2024, so prefer 2022 as baseline
    switch -Regex ($_.OperatingSystemName) {
        '2022' { $score += 30 }  # Oldest under mainstream support - most compatible
        '2025' { $score += 20 }  # Newest - fewer environments have this yet
        '2019' { $score += 10 }  # Extended support only - fallback
    }
    # Prefer Core over Desktop Experience (Core is smaller/faster)
    if ($_.OperatingSystemName -notmatch 'Desktop Experience|GUI') {
        $score += 5
    }
    # Prefer Datacenter over Standard
    if ($_.OperatingSystemName -match 'Datacenter') {
        $score += 2
    }
    $score
} -Descending | Select-Object -First 1

if (-not $serverOS) {
    $availableOSList = ($availableOS | Select-Object -ExpandProperty OperatingSystemName) -join "`n  - "
    throw @"
No suitable Windows Server OS found. Available operating systems:
  - $availableOSList

Please download a Windows Server evaluation ISO from:
  https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022
And place it in: $labSources\ISOs
"@
}

Write-Host "  Using OS: $($serverOS.OperatingSystemName)" -ForegroundColor Gray

# Check if lab already exists
$existingLab = Get-Lab -List | Where-Object { $_ -eq $labName }
if ($existingLab) {
    Write-Warning "Lab '$labName' already exists. Use Remove-IntegrationLab.ps1 to remove it first."
    return
}

Write-Host "Creating lab definition: $labName" -ForegroundColor Cyan

# Create lab definition
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV

# Domain definition
Add-LabDomainDefinition -Name $domainName -AdminUser $adminUser -AdminPassword $adminPassword

# Installation credentials
Set-LabInstallationCredential -Username $adminUser -Password $adminPassword

# Virtual network
Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace $addressSpace

# Default parameters for all machines
# Server Core requires less RAM than Desktop Experience
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:OperatingSystem' = $serverOS.OperatingSystemName
    'Add-LabMachineDefinition:Network'         = $labName
    'Add-LabMachineDefinition:DomainName'      = $domainName
    'Add-LabMachineDefinition:Memory'          = 1GB
    'Add-LabMachineDefinition:MinMemory'       = 512MB
    'Add-LabMachineDefinition:MaxMemory'       = 2GB
}

# Domain Controller
Write-Host "  Adding Domain Controller: $dcName" -ForegroundColor Gray
Add-LabMachineDefinition -Name $dcName -Roles RootDC

# Cluster nodes with FailoverNode role
$clusterRole = Get-LabMachineRoleDefinition -Role FailoverNode -Properties @{
    ClusterName = $clusterName
    ClusterIp   = $clusterIp
}

foreach ($nodeName in $clusterNodes) {
    Write-Host "  Adding Cluster Node: $nodeName" -ForegroundColor Gray
    Add-LabMachineDefinition -Name $nodeName -Roles $clusterRole
}

# Install the lab
Write-Host "`nInstalling lab (this may take 30-60 minutes)..." -ForegroundColor Yellow
Install-Lab

# Show summary
Show-LabDeploymentSummary

Write-Host "`nLab '$labName' deployment complete!" -ForegroundColor Green

# Return lab info for use by other scripts
[PSCustomObject]@{
    LabName      = $labName
    DomainName   = $domainName
    ClusterName  = $clusterName
    ClusterIp    = $clusterIp
    AdminUser    = "$domainName\$adminUser"
    DCName       = $dcName
    ClusterNodes = $clusterNodes
}
