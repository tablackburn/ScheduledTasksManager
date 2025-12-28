<#
.SYNOPSIS
    One-time initialization of the integration test lab environment.

.DESCRIPTION
    Sets up the AutomatedLab-based failover cluster for integration testing.
    This script should be run once before running integration tests.
    It will:
    1. Check prerequisites (Hyper-V, admin rights)
    2. Install AutomatedLab if not present
    3. Deploy the lab (DC + 2 cluster nodes)
    4. Configure file share witness on DC
    5. Create a baseline snapshot for fast restore

.PARAMETER SkipSnapshot
    Skip creating the baseline snapshot after deployment.

.PARAMETER Force
    Remove existing lab and redeploy from scratch.

.EXAMPLE
    .\Initialize-IntegrationLab.ps1

.EXAMPLE
    .\Initialize-IntegrationLab.ps1 -Force

.NOTES
    This process takes approximately 30-60 minutes depending on hardware.
    Requires Windows Server ISO (will be downloaded automatically if not present).
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [switch]$SkipSnapshot,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Load configuration
Import-Module "$PSScriptRoot\IntegrationTestConfig.psm1" -Force
$config = Get-IntegrationTestConfig -Required

$labName = $config.lab.name
$dcName = $config.virtualMachines.domainController
$clusterNodes = $config.virtualMachines.clusterNodes
$testNode = $clusterNodes[0]

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Integration Lab Initialization" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check Hyper-V (works on both Windows client and Server)
$hyperVEnabled = $false
# Try Windows Server method first
$hyperVFeature = Get-WindowsFeature -Name Hyper-V -ErrorAction SilentlyContinue
if ($hyperVFeature -and $hyperVFeature.Installed) {
    $hyperVEnabled = $true
}
# Try Windows client method
if (-not $hyperVEnabled) {
    $hyperVOptional = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
    if ($hyperVOptional -and $hyperVOptional.State -eq 'Enabled') {
        $hyperVEnabled = $true
    }
}
if (-not $hyperVEnabled) {
    throw "Hyper-V is not enabled. Please enable Hyper-V and restart before running this script."
}
Write-Host "  [OK] Hyper-V is enabled" -ForegroundColor Green

# Check/Install AutomatedLab
$alModule = Get-Module -Name AutomatedLab -ListAvailable
if (-not $alModule) {
    Write-Host "  [..] Installing AutomatedLab module..." -ForegroundColor Yellow
    Install-Module -Name AutomatedLab -Scope CurrentUser -Force -AllowClobber

    # AutomatedLab requires initial setup
    Write-Host "  [..] Running AutomatedLab initial setup..." -ForegroundColor Yellow
    Import-Module AutomatedLab

    # This creates required folders and downloads sample ISOs list
    if (-not (Test-Path -Path "$env:ProgramData\AutomatedLab")) {
        New-LabSourcesFolder -Drive C -Force
    }
}
# Skip hosts file modifications - we use Invoke-LabCommand (PowerShell Direct) which doesn't need it
# This avoids conflicts with Tailscale, antivirus, or other tools that manage the hosts file
# Must be set BEFORE importing AutomatedLab to take effect
Import-Module PSFramework -Force
Set-PSFConfig -FullName AutomatedLab.SkipHostFileModification -Value $true

Import-Module AutomatedLab -Force
Write-Host "  [OK] AutomatedLab module loaded" -ForegroundColor Green

# Check for existing lab
$existingLab = Get-Lab -List | Where-Object { $_ -eq $labName }
if ($existingLab) {
    if ($Force) {
        Write-Host "`nRemoving existing lab '$labName'..." -ForegroundColor Yellow
        Import-Lab -Name $labName -NoValidation
        Remove-Lab -Confirm:$false
        Write-Host "  [OK] Existing lab removed" -ForegroundColor Green
    }
    else {
        Write-Host "`nLab '$labName' already exists." -ForegroundColor Yellow
        Write-Host "Use -Force to remove and redeploy, or run Start-IntegrationLab.ps1 to use existing lab." -ForegroundColor Yellow
        return
    }
}

# Deploy the lab
Write-Host "`nDeploying lab environment..." -ForegroundColor Yellow
Write-Host "This will take approximately 30-60 minutes." -ForegroundColor Gray
Write-Host ""

$labInfo = & "$PSScriptRoot\LabDefinition.ps1"

# Import the lab for further configuration
Import-Lab -Name $labName

# Configure file share witness on DC
Write-Host "`nConfiguring file share witness..." -ForegroundColor Yellow
$witnessPath = "\\$dcName\ClusterWitness`$"

Invoke-LabCommand -ComputerName $dcName -ActivityName 'Create Witness Share' -ScriptBlock {
    $witnessFolder = 'C:\ClusterWitness'

    # Create folder if it doesn't exist
    if (-not (Test-Path $witnessFolder)) {
        New-Item -Path $witnessFolder -ItemType Directory -Force | Out-Null
    }

    # Create hidden share if it doesn't exist
    $share = Get-SmbShare -Name 'ClusterWitness$' -ErrorAction SilentlyContinue
    if (-not $share) {
        New-SmbShare -Name 'ClusterWitness$' -Path $witnessFolder -FullAccess 'Everyone' | Out-Null
    }

    # Set NTFS permissions
    $acl = Get-Acl $witnessFolder
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        'Everyone', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
    )
    $acl.SetAccessRule($rule)
    Set-Acl $witnessFolder $acl
}

# Configure cluster quorum with file share witness
Invoke-LabCommand -ComputerName $testNode -ActivityName 'Configure Cluster Quorum' -ScriptBlock {
    param($WitnessPath)

    # Wait for cluster to be fully formed
    $cluster = $null
    $attempts = 0
    while (-not $cluster -and $attempts -lt 30) {
        $cluster = Get-Cluster -ErrorAction SilentlyContinue
        if (-not $cluster) {
            Start-Sleep -Seconds 10
            $attempts++
        }
    }

    if ($cluster) {
        # Set file share witness
        Set-ClusterQuorum -FileShareWitness $WitnessPath -ErrorAction SilentlyContinue
        Write-Host "Cluster quorum configured with file share witness: $WitnessPath"
    }
    else {
        Write-Warning "Could not find cluster after 5 minutes. Quorum may need manual configuration."
    }
} -ArgumentList $witnessPath

Write-Host "  [OK] File share witness configured" -ForegroundColor Green

# Validate cluster health
Write-Host "`nValidating cluster health..." -ForegroundColor Yellow
$clusterStatus = Invoke-LabCommand -ComputerName $testNode -ActivityName 'Check Cluster' -ScriptBlock {
    $cluster = Get-Cluster -ErrorAction SilentlyContinue
    if ($cluster) {
        $nodes = Get-ClusterNode
        [PSCustomObject]@{
            Name   = $cluster.Name
            Nodes  = $nodes.Name -join ', '
            State  = ($nodes | Where-Object State -eq 'Up').Count -eq $nodes.Count
            Quorum = (Get-ClusterQuorum).QuorumResource.Name
        }
    }
} -PassThru

if ($clusterStatus -and $clusterStatus.State) {
    Write-Host "  [OK] Cluster '$($clusterStatus.Name)' is healthy" -ForegroundColor Green
    Write-Host "       Nodes: $($clusterStatus.Nodes)" -ForegroundColor Gray
    Write-Host "       Quorum: $($clusterStatus.Quorum)" -ForegroundColor Gray
}
else {
    Write-Warning "Cluster may not be fully healthy. Check cluster status manually."
}

# Create baseline snapshot
if (-not $SkipSnapshot) {
    Write-Host "`nCreating baseline snapshot..." -ForegroundColor Yellow
    Checkpoint-LabVM -All -SnapshotName 'IntegrationTestBaseline'
    Write-Host "  [OK] Baseline snapshot created" -ForegroundColor Green
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host " Lab Initialization Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Lab Name:     $labName" -ForegroundColor White
Write-Host "Domain:       $($config.lab.domainName)" -ForegroundColor White
Write-Host "Cluster:      $($config.cluster.name) ($($config.network.clusterIp))" -ForegroundColor White
Write-Host "Nodes:        $($clusterNodes -join ', ')" -ForegroundColor White
Write-Host "DC:           $dcName" -ForegroundColor White
Write-Host "Admin:        $($config.lab.domainName)\$($config.lab.adminUser)" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run integration tests: Invoke-Pester .\tests\Integration\" -ForegroundColor Gray
Write-Host "  2. Or start lab manually: .\Start-IntegrationLab.ps1" -ForegroundColor Gray
Write-Host ""

# Return lab info
$labInfo
