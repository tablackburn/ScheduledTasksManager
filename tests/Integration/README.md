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

## CI/CD Integration (GitHub Actions)

Integration tests can run automatically on pull requests via GitHub Actions using Tailscale to connect to a remote Hyper-V host.

### Architecture

```
GitHub Runner ──[Tailscale]──> Hyper-V Host ──[AutomatedLab]──> Cluster VMs
```

### Setup

1. **Create Tailscale OAuth Client**
   - Go to https://login.tailscale.com/admin/settings/oauth
   - Create OAuth client with **Devices - Write** scope
   - Assign tag: `tag:ci`

2. **Configure GitHub Secrets**

   | Secret | Description |
   |--------|-------------|
   | `TS_OAUTH_CLIENT_ID` | Tailscale OAuth client ID |
   | `TS_OAUTH_SECRET` | Tailscale OAuth client secret |
   | `TS_HYPER_V_HOST` | Tailscale hostname (e.g., `myhost.tail12345.ts.net`) |
   | `HYPERV_USERNAME` | Windows username for remoting |
   | `HYPERV_PASSWORD` | Windows password |

3. **Ensure Prerequisites**
   - Hyper-V host has Tailscale installed and connected
   - PowerShell Remoting (WinRM) enabled on host
   - Lab deployed and running (or set to auto-start)
   - Tailscale ACLs allow `tag:ci` to reach the host

### Behavior

| Lab Status | PR Result |
|------------|-----------|
| Lab available | Integration tests run, results reported |
| Lab unavailable | Warning shown, **PR not blocked** |

Integration tests are "best effort" - they run when the lab is available but don't block PRs if the lab is down.

### Manual Trigger

The workflow can also be triggered manually from the Actions tab with an option to restore the baseline snapshot.

### Scripts

| Script | Purpose |
|--------|---------|
| `Invoke-CIIntegrationTest.ps1` | CI runner (called by GitHub Actions) |
| `Invoke-RemoteIntegrationTest.ps1` | Manual remote testing |

## AutomatedLab Resources

- [AutomatedLab Documentation](https://automatedlab.org/)
- [Failover Clustering Role](https://automatedlab.org/en/stable/Wiki/Roles/failoverclustering/)
- [GitHub Repository](https://github.com/AutomatedLab/AutomatedLab)
