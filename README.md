# ScheduledTasksManager

[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/ScheduledTasksManager)](https://www.powershellgallery.com/packages/ScheduledTasksManager/)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/ScheduledTasksManager)](https://www.powershellgallery.com/packages/ScheduledTasksManager/)
[![CI](https://img.shields.io/github/actions/workflow/status/tablackburn/ScheduledTasksManager/CI.yaml?branch=main)](https://github.com/tablackburn/ScheduledTasksManager/actions/workflows/CI.yaml)
[![codecov](https://codecov.io/gh/tablackburn/ScheduledTasksManager/branch/main/graph/badge.svg)](https://codecov.io/gh/tablackburn/ScheduledTasksManager)
![Platform](https://img.shields.io/powershellgallery/p/ScheduledTasksManager)
[![AI Assisted](https://img.shields.io/badge/AI-Assisted-blue)](https://claude.ai)
[![License](https://img.shields.io/github/license/tablackburn/ScheduledTasksManager)](LICENSE)

`ScheduledTasksManager` is a PowerShell module for managing both local and clustered scheduled tasks on Windows systems. It supports operations in standalone environments as well as Windows Server Failover Clusters, extending the capabilities of the built-in `ScheduledTasks` module from Microsoft.

Documentation automatically updated at [tablackburn.github.io/ScheduledTasksManager](https://tablackburn.github.io/ScheduledTasksManager/)

## What This Project Does

ScheduledTasksManager provides comprehensive functions for managing scheduled tasks in Windows environments, with special focus on clustered scenarios:

- **Clustered Task Management**: Register, enable, disable, start, stop, and monitor scheduled tasks across failover cluster nodes
- **Task Information & Monitoring**: Retrieve detailed task information, run history, and cluster node details
- **Configuration Management**: Export and import task configurations for backup, migration, and deployment
- **Advanced Filtering**: Filter tasks by state, type, and ownership across cluster nodes
- **Credential Management**: Secure authentication with cluster nodes using credentials or CIM sessions

## Why This Project Is Useful

Managing scheduled tasks in Windows Server Failover Clusters can be complex and error-prone. This module addresses common challenges:

- **Simplified Cluster Operations**: Single functions handle cluster-aware task management
- **Reduced Administrative Overhead**: Automate task deployment and monitoring across multiple nodes
- **Enhanced Reliability**: Built-in error handling and validation for cluster operations
- **Standardized Workflows**: Consistent PowerShell function patterns for task management
- **Enterprise Ready**: Supports credential delegation and secure remote management

## Getting Started

### Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- Windows Server with Failover Clustering feature (for cluster functions)
- Appropriate permissions to manage scheduled tasks

### Installation

Install from PowerShell Gallery:

```powershell
Install-Module -Name ScheduledTasksManager -Repository PSGallery
```

### Quick Start

```powershell
# Import the module
Import-Module ScheduledTasksManager

# Get all clustered scheduled tasks
Get-StmClusteredScheduledTask -Cluster "MyCluster"

# Get detailed task information including run duration
Get-StmClusteredScheduledTaskInfo -Cluster "MyCluster" -TaskName "BackupTask"

# Start a clustered task and wait for completion
Start-StmClusteredScheduledTask -Cluster "MyCluster" -TaskName "BackupTask"
Wait-StmClusteredScheduledTask -Cluster "MyCluster" -TaskName "BackupTask" -Timeout 300

# Export task configuration for backup
Export-StmClusteredScheduledTask -Cluster "MyCluster" -TaskName "BackupTask" -FilePath ".\BackupTask.xml"

# Import task configuration to another cluster
Import-StmClusteredScheduledTask -Cluster "NewCluster" -Path ".\BackupTask.xml"
```

## Available Functions

### Clustered Task Management

| Function | Description |
|----------|-------------|
| `Get-StmClusteredScheduledTask` | Retrieve clustered scheduled tasks from a failover cluster |
| `Get-StmClusteredScheduledTaskInfo` | Get detailed task information including run times and duration |
| `Get-StmClusteredScheduledTaskRun` | Get task run history from all cluster nodes |
| `Register-StmClusteredScheduledTask` | Register a new clustered scheduled task |
| `Unregister-StmClusteredScheduledTask` | Remove a clustered scheduled task |
| `Enable-StmClusteredScheduledTask` | Enable a disabled clustered task |
| `Disable-StmClusteredScheduledTask` | Disable a clustered task (creates backup) |
| `Set-StmClusteredScheduledTask` | Modify clustered task properties (actions, triggers, settings) |
| `Start-StmClusteredScheduledTask` | Manually start a clustered task |
| `Stop-StmClusteredScheduledTask` | Stop a running clustered task |
| `Wait-StmClusteredScheduledTask` | Wait for a clustered task to complete |
| `Export-StmClusteredScheduledTask` | Export task configuration to XML |
| `Import-StmClusteredScheduledTask` | Import task configuration from XML |

### Local Task Management

| Function | Description |
|----------|-------------|
| `Get-StmScheduledTask` | Retrieve scheduled tasks from local or remote computers |
| `Get-StmScheduledTaskInfo` | Get detailed task information with run duration |
| `Get-StmScheduledTaskRun` | Get task run history with event details |
| `Disable-StmScheduledTask` | Disable a scheduled task on local or remote computers |
| `Enable-StmScheduledTask` | Enable a scheduled task on local or remote computers |
| `Set-StmScheduledTask` | Modify task properties (actions, triggers, settings) |
| `Export-StmScheduledTask` | Export task configuration to XML |
| `Import-StmScheduledTask` | Import task configuration from XML |
| `Register-StmScheduledTask` | Register a new scheduled task |
| `Unregister-StmScheduledTask` | Remove a scheduled task |
| `Start-StmScheduledTask` | Manually start a scheduled task |
| `Stop-StmScheduledTask` | Stop a running scheduled task |
| `Wait-StmScheduledTask` | Wait for a scheduled task to complete |

### Utilities

| Function | Description |
|----------|-------------|
| `Get-StmClusterNode` | Retrieve cluster node information |
| `Get-StmResultCodeMessage` | Translate result codes to human-readable messages |

## Usage Examples

### Working with Clustered Tasks

```powershell
# Get all tasks on a cluster
$tasks = Get-StmClusteredScheduledTask -Cluster "YOURCLUSTER"

# Filter by state
$runningTasks = Get-StmClusteredScheduledTask -Cluster "YOURCLUSTER" -TaskState Running

# Get task with credentials
$cred = Get-Credential
Get-StmClusteredScheduledTask -Cluster "YOURCLUSTER" -Credential $cred
```

### Monitoring Task Runs

```powershell
# Get recent task runs from all cluster nodes
Get-StmClusteredScheduledTaskRun -Cluster "YOURCLUSTER" -TaskName "BackupTask" -MaxRuns 10

# Get local task runs with detailed timing
Get-StmScheduledTaskRun -TaskName "MyTask" -MaxRuns 5
```

### Backup and Migration

```powershell
# Export all tasks from a cluster to a directory
$tasks = Get-StmClusteredScheduledTask -Cluster "OldCluster"
foreach ($task in $tasks) {
    Export-StmClusteredScheduledTask -Cluster "OldCluster" -TaskName $task.TaskName -FilePath ".\Backup\$($task.TaskName).xml"
}

# Import all tasks to a new cluster
Import-StmClusteredScheduledTask -Cluster "NewCluster" -DirectoryPath ".\Backup" -Force
```

### Error Handling

```powershell
# All functions support standard PowerShell error handling
try {
    Start-StmClusteredScheduledTask -Cluster "YOURCLUSTER" -TaskName "NonExistent" -ErrorAction Stop
}
catch {
    Write-Warning "Task failed: $($_.Exception.Message)"
}
```

## Getting Help

### Documentation

- **Module Help**: `Get-Help about_ScheduledTasksManager`
- **Function Help**: `Get-Help Get-StmClusteredScheduledTask -Full`
- **Online Docs**: [tablackburn.github.io/ScheduledTasksManager](https://tablackburn.github.io/ScheduledTasksManager/)
- **Examples**: Each function includes comprehensive examples

### Support

- **Issues**: Report bugs or request features on [GitHub Issues](https://github.com/tablackburn/ScheduledTasksManager/issues)
- **Questions**: Use GitHub Discussions for general questions
- **Documentation**: Check the `docs/` folder for detailed help files

### Community

- **PowerShell Gallery**: [ScheduledTasksManager](https://www.powershellgallery.com/packages/ScheduledTasksManager)
- **GitHub Repository**: [tablackburn/ScheduledTasksManager](https://github.com/tablackburn/ScheduledTasksManager)


## Acknowledgments

This project was developed with assistance from [Claude](https://claude.ai) by Anthropic.

## Project Maintenance

### Maintainer

**Trent Blackburn** - Primary developer and maintainer

### Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development

- **License**: See [LICENSE](LICENSE) file
- **Changelog**: See [CHANGELOG.md](CHANGELOG.md) for version history

### Testing

The module includes comprehensive Pester tests with 93%+ code coverage. Run tests with:

```powershell
./build.ps1 -Task Test
```
