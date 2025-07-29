# ScheduledTasksManager

`ScheduledTasksManager` is a PowerShell module for managing both local and
clustered scheduled tasks on Windows systems. It supports operations in
standalone environments as well as Windows Server Failover Clusters, extending
the capabilities of the built-in `ScheduledTasks` module from Microsoft.

## What This Project Does

ScheduledTasksManager provides comprehensive functions for managing scheduled
tasks in Windows environments, with special focus on clustered scenarios:

- **Clustered Task Management**: Register, enable, disable, start, and monitor
  scheduled tasks across failover cluster nodes
- **Task Information & Monitoring**: Retrieve detailed task information, run
  history, and cluster node details
- **Configuration Management**: Export and import task configurations for backup
  and deployment
- **Advanced Filtering**: Filter tasks by state, type, and ownership across
  cluster nodes
- **Credential Management**: Secure authentication with cluster nodes using
  credentials or CIM sessions

## Why This Project Is Useful

Managing scheduled tasks in Windows Server Failover Clusters can be complex and
error-prone. This module addresses common challenges:

- **Simplified Cluster Operations**: Single functions handle cluster-aware task
  management
- **Reduced Administrative Overhead**: Automate task deployment and monitoring
  across multiple nodes
- **Enhanced Reliability**: Built-in error handling and validation for cluster
  operations
- **Standardized Workflows**: Consistent PowerShell function patterns for task
  management
- **Enterprise Ready**: Supports credential delegation and secure remote
  management

## Getting Started

### Prerequisites

- Windows Server with Failover Clustering feature installed
- PowerShell 6.0 or later
- Appropriate permissions to manage clustered scheduled tasks

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

# Register a new clustered task
Register-StmClusteredScheduledTask -Cluster "MyCluster" -TaskName "BackupTask" -TaskType "ClusterWide"

# Start a clustered task
Start-StmClusteredScheduledTask -Cluster "MyCluster" -TaskName "BackupTask"
```

### Available Functions

- `Get-StmClusteredScheduledTask` - Retrieve clustered scheduled tasks
- `Get-StmClusteredScheduledTaskInfo` - Get detailed task information
- `Get-StmClusterNode` - Retrieve cluster node information
- `Get-StmScheduledTaskRun` - Get task run history
- `Register-StmClusteredScheduledTask` - Register new clustered tasks
- `Unregister-StmClusteredScheduledTask` - Remove clustered tasks
- `Enable-StmClusteredScheduledTask` - Enable clustered tasks
- `Disable-StmClusteredScheduledTask` - Disable clustered tasks
- `Start-StmClusteredScheduledTask` - Manually start tasks
- `Wait-StmClusteredScheduledTask` - Wait for task completion
- `Export-StmClusteredScheduledTask` - Export task configurations

## Getting Help

### Documentation

- **Module Help**: `Get-Help about_ScheduledTasksManager`
- **Function Help**: `Get-Help Get-StmClusteredScheduledTask -Full`
- **Examples**: Each function includes comprehensive examples

### Support

- **Issues**: Report bugs or request features on
  [GitHub Issues](https://github.com/tablackburn/ScheduledTasksManager/issues)
- **Questions**: Use GitHub Discussions for general questions
- **Documentation**: Check the `docs/` folder for detailed help files

### Community

- **PowerShell Gallery**:
  [ScheduledTasksManager](https://www.powershellgallery.com/packages/ScheduledTasksManager)
- **GitHub Repository**:
  [tabblackburn/ScheduledTasksManager](https://github.com/tablackburn/ScheduledTasksManager)

## Project Maintenance

### Maintainer

**Trent Blackburn** - Primary developer and maintainer

### Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major
changes, please open an issue first to discuss what you would like to change.

### Development

- **Version**: 0.1.0
- **License**: See [LICENSE](LICENSE) file
- **Changelog**: See [CHANGELOG.md](CHANGELOG.md) for version history

### Testing

The module includes comprehensive Pester tests. Run tests with:

```powershell
./build.ps1 -Task Test
```
