# Integration Tests

This directory contains integration tests for the ScheduledTasksManager module. These tests run against a real Windows Failover Cluster deployed on local Hyper-V using [AutomatedLab](https://github.com/AutomatedLab/AutomatedLab).

## Prerequisites

- **Windows 10/11 Pro or Windows Server** with Hyper-V enabled
- **Administrator privileges** for lab deployment
- **~30GB free disk space** for VMs (Server Core is smaller)
- **~3GB RAM** available for VMs (1GB per VM × 3, using dynamic memory)
- **Internet connection** for Windows Server ISO download (first run only)

## Quick Start

### First Time Setup (~30-60 minutes)

```powershell
# Run as Administrator
.\Initialize-IntegrationLab.ps1
```

This will:
1. Install AutomatedLab if not present
2. Download Windows Server 2022 evaluation ISO
3. Create 3 VMs: Domain Controller + 2 Cluster Nodes
4. Configure the failover cluster
5. Create a baseline snapshot

### Running Tests

```powershell
# Start the lab (restores from snapshot)
.\Start-IntegrationLab.ps1

# Run integration tests
Invoke-Pester .\ClusteredScheduledTask.Integration.Tests.ps1 -Output Detailed

# Stop the lab when done
.\Stop-IntegrationLab.ps1
```

### Clean Slate

```powershell
# Start with restored baseline snapshot
.\Start-IntegrationLab.ps1 -RestoreSnapshot
```

### Remove Lab Completely

```powershell
# Free up disk space
.\Remove-IntegrationLab.ps1
```

## Lab Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Local Hyper-V Host                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   STMDC01   │  │  STMNODE01  │  │  STMNODE02  │             │
│  │ Domain Ctrl │  │ Cluster Node│  │ Cluster Node│             │
│  │ File Witness│  │             │  │             │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│         │                │                │                     │
│         └────────────────┼────────────────┘                     │
│                  StmTestLab (Internal)                          │
└─────────────────────────────────────────────────────────────────┘
```

| VM | Role | IP |
|----|------|-----|
| STMDC01 | Domain Controller, File Share Witness | DHCP |
| STMNODE01 | Cluster Node 1 | DHCP |
| STMNODE02 | Cluster Node 2 | DHCP |

**Cluster**: STMCLUSTER (192.168.100.50)
**Domain**: stmtest.local
**Admin**: stmtest.local\Install (P@ssw0rd1)

## Scripts

| Script | Purpose |
|--------|---------|
| `LabDefinition.ps1` | AutomatedLab lab definition (called by Initialize) |
| `Initialize-IntegrationLab.ps1` | One-time lab deployment |
| `Start-IntegrationLab.ps1` | Start lab and prepare for testing |
| `Stop-IntegrationLab.ps1` | Gracefully stop lab VMs |
| `Remove-IntegrationLab.ps1` | Delete lab and free disk space |

## Troubleshooting

### "Lab not found" error
Run `Initialize-IntegrationLab.ps1` first to deploy the lab.

### Cluster not healthy
```powershell
# Check cluster status manually
Import-Lab -Name StmTestLab
Invoke-LabCommand -ComputerName STMNODE01 -ScriptBlock { Get-ClusterNode }
```

### VMs won't start
Ensure Hyper-V is enabled and you have enough RAM available.

### Tests timeout waiting for VMs
Increase timeout: `.\Start-IntegrationLab.ps1 -TimeoutMinutes 15`

### Need to start fresh
```powershell
.\Remove-IntegrationLab.ps1 -Force
.\Initialize-IntegrationLab.ps1
```

## Snapshot Management

```powershell
# List snapshots
Import-Lab -Name StmTestLab
Get-LabVMSnapshot -All

# Restore to baseline
.\Start-IntegrationLab.ps1 -RestoreSnapshot

# Create custom snapshot
Import-Lab -Name StmTestLab
Checkpoint-LabVM -All -SnapshotName 'MySnapshot'
```

## AutomatedLab Resources

- [AutomatedLab Documentation](https://automatedlab.org/)
- [Failover Clustering Role](https://automatedlab.org/en/stable/Wiki/Roles/failoverclustering/)
- [GitHub Repository](https://github.com/AutomatedLab/AutomatedLab)
