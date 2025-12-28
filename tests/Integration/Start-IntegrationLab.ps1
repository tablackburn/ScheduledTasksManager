<#
.SYNOPSIS
    Starts the integration test lab and ensures it's ready for testing.

.DESCRIPTION
    Prepares the lab environment for integration testing by:
    1. Restoring from baseline snapshot (optional)
    2. Starting VMs if stopped
    3. Waiting for VMs to be accessible
    4. Validating cluster health
    5. Returning connection info for tests

.PARAMETER RestoreSnapshot
    Restore from the baseline snapshot before starting.
    Use this for a clean test environment.

.PARAMETER SnapshotName
    Name of the snapshot to restore. Defaults to 'IntegrationTestBaseline'.

.PARAMETER TimeoutMinutes
    Maximum time to wait for VMs to be accessible. Defaults to 10 minutes.

.EXAMPLE
    $labInfo = .\Start-IntegrationLab.ps1
    # Use $labInfo.ClusterName, $labInfo.Credential, etc.

.EXAMPLE
    .\Start-IntegrationLab.ps1 -RestoreSnapshot

.OUTPUTS
    PSCustomObject with lab connection information.
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [switch]$RestoreSnapshot,

    [string]$SnapshotName = 'IntegrationTestBaseline',

    [int]$TimeoutMinutes = 10
)

$ErrorActionPreference = 'Stop'

# Load configuration
Import-Module "$PSScriptRoot\IntegrationTestConfig.psm1" -Force
$config = Get-IntegrationTestConfig -Required

$labName = $config.lab.name
$testNode = $config.virtualMachines.clusterNodes[0]
$progressActivity = 'Starting Integration Lab'
$progressId = 1

# Step 1: Import lab
Write-Progress -Id $progressId -Activity $progressActivity -Status 'Importing lab...' -PercentComplete 0

Import-Module AutomatedLab -Force

$existingLab = Get-Lab -List | Where-Object { $_ -eq $labName }
if (-not $existingLab) {
    Write-Progress -Id $progressId -Activity $progressActivity -Completed
    throw "Lab '$labName' not found. Run Initialize-IntegrationLab.ps1 first."
}

Import-Lab -Name $labName -NoValidation -NoDisplay

Write-Progress -Id $progressId -Activity $progressActivity -Status 'Lab imported' -PercentComplete 10

# Step 2: Restore snapshot if requested
if ($RestoreSnapshot) {
    Write-Progress -Id $progressId -Activity $progressActivity -Status "Restoring snapshot '$SnapshotName'..." -PercentComplete 15

    $snapshots = Get-LabVMSnapshot -All
    $baselineSnapshot = $snapshots | Where-Object { $_.Name -eq $SnapshotName }

    if (-not $baselineSnapshot) {
        Write-Warning "Snapshot '$SnapshotName' not found. Skipping restore."
    }
    else {
        Restore-LabVMSnapshot -All -SnapshotName $SnapshotName
    }
}

# Step 3: Start VMs
Write-Progress -Id $progressId -Activity $progressActivity -Status 'Starting VMs...' -PercentComplete 25

$vms = Get-LabVM
$vmCount = $vms.Count
$vmIndex = 0

foreach ($vm in $vms) {
    $vmIndex++
    $vmPercent = 25 + [int](($vmIndex / $vmCount) * 25)
    Write-Progress -Id $progressId -Activity $progressActivity -Status "Starting VM: $($vm.Name)" -PercentComplete $vmPercent

    $vmState = (Get-VM -Name $vm.Name -ErrorAction SilentlyContinue).State
    if ($vmState -ne 'Running') {
        Start-LabVM -ComputerName $vm.Name -Wait -NoNewLine
    }
}

# Step 4: Wait for VMs to be accessible
Write-Progress -Id $progressId -Activity $progressActivity -Status 'Waiting for VMs to be accessible...' -PercentComplete 55

$timeout = (Get-Date).AddMinutes($TimeoutMinutes)
$allAccessible = $false
$checkCount = 0

while (-not $allAccessible -and (Get-Date) -lt $timeout) {
    $checkCount++
    $accessible = @()

    foreach ($vm in $vms) {
        $session = New-LabPSSession -ComputerName $vm.Name -ErrorAction SilentlyContinue
        if ($session) {
            $accessible += $vm.Name
            Remove-PSSession $session -ErrorAction SilentlyContinue
        }
    }

    $accessiblePercent = 55 + [int](($accessible.Count / $vms.Count) * 20)
    Write-Progress -Id $progressId -Activity $progressActivity -Status "VMs accessible: $($accessible.Count)/$($vms.Count)" -PercentComplete $accessiblePercent

    if ($accessible.Count -eq $vms.Count) {
        $allAccessible = $true
    }
    else {
        Start-Sleep -Seconds 10
    }
}

if (-not $allAccessible) {
    Write-Progress -Id $progressId -Activity $progressActivity -Completed
    throw "Timeout waiting for VMs to be accessible after $TimeoutMinutes minutes."
}

# Step 5: Validate cluster health
Write-Progress -Id $progressId -Activity $progressActivity -Status 'Validating cluster health...' -PercentComplete 80

$clusterStatus = Invoke-LabCommand -ComputerName $testNode -NoDisplay -ScriptBlock {
    $cluster = Get-Cluster -ErrorAction SilentlyContinue
    if ($cluster) {
        $nodes = Get-ClusterNode
        $upNodes = $nodes | Where-Object State -eq 'Up'
        [PSCustomObject]@{
            Name      = $cluster.Name
            Nodes     = $nodes.Name
            UpNodes   = $upNodes.Name
            IsHealthy = $upNodes.Count -eq $nodes.Count
            Quorum    = (Get-ClusterQuorum).QuorumResource.Name
        }
    }
    else {
        [PSCustomObject]@{
            Name      = $null
            IsHealthy = $false
        }
    }
} -PassThru

if (-not $clusterStatus -or -not $clusterStatus.IsHealthy) {
    Write-Warning "Cluster is not fully healthy. Some tests may fail."
    Write-Warning "  Nodes up: $($clusterStatus.UpNodes -join ', ')"
}

# Build credentials
$domainName = $config.lab.domainName
$adminUser = $config.lab.adminUser
$adminPassword = $config.lab.adminPassword
$securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("$domainName\$adminUser", $securePassword)

# Return lab info
$labInfo = [PSCustomObject]@{
    LabName       = $labName
    DomainName    = $domainName
    ClusterName   = $config.cluster.name
    ClusterIp     = $config.network.clusterIp
    DCName        = $config.virtualMachines.domainController
    ClusterNodes  = $config.virtualMachines.clusterNodes
    AdminUser     = "$domainName\$adminUser"
    Credential    = $credential
    IsHealthy     = $clusterStatus.IsHealthy
}

# Complete progress and show summary
Write-Progress -Id $progressId -Activity $progressActivity -Status 'Lab ready!' -PercentComplete 100
Write-Progress -Id $progressId -Activity $progressActivity -Completed

Write-Host "Lab ready for testing!" -ForegroundColor Green
Write-Host "  Cluster: $($labInfo.ClusterName) | Nodes: $($labInfo.ClusterNodes -join ', ') | Healthy: $($labInfo.IsHealthy)" -ForegroundColor Gray

$labInfo
