# Change Log

<!-- Disable markdownlint's no-duplicate-header rule -->
<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.2.0] - 2025-07-30

### Added

- `MaxRuns` parameter to `Get-StmScheduledTaskRun` for limiting task run
  retrieval
- Unit tests for `Get-StmScheduledTaskRun` to validate task retrieval, event
  handling, and XML conversion
- Additional examples and parameters details for `Get-StmScheduledTaskRun`
- `Register-StmClusteredScheduledTask` now supports `ShouldProcess` with
  `-WhatIf` and `-Confirm` parameters for improved safety during task
  registration
- Verbose output for XML content usage in `Register-StmClusteredScheduledTask`
- Error handling in `Export-StmClusteredScheduledTask` to check for null
  scheduled task retrieval

## [0.1.0] - 2025-07-29

### Added

- Initial release of ScheduledTasksManager PowerShell module
- Support for managing clustered scheduled tasks in Windows Server Failover
  Clusters
- `Get-StmClusteredScheduledTask` - Retrieve clustered scheduled tasks with
  filtering capabilities
- `Get-StmClusteredScheduledTaskInfo` - Get detailed information about
  clustered scheduled tasks
- `Get-StmClusterNode` - Retrieve cluster node information
- `Get-StmScheduledTaskRun` - Get scheduled task run history
- `Register-StmClusteredScheduledTask` - Register new clustered scheduled
  tasks
- `Unregister-StmClusteredScheduledTask` - Remove clustered scheduled tasks
- `Enable-StmClusteredScheduledTask` - Enable clustered scheduled tasks
- `Disable-StmClusteredScheduledTask` - Disable clustered scheduled tasks
- `Start-StmClusteredScheduledTask` - Manually start clustered scheduled
  tasks
- `Wait-StmClusteredScheduledTask` - Wait for clustered scheduled task
  completion
- `Export-StmClusteredScheduledTask` - Export clustered scheduled task
  configurations
- Comprehensive help documentation for all cmdlets
- Support for credential-based authentication to clusters
- CIM session management for cluster connections
- Task state and type filtering capabilities
- Integration with Microsoft's ScheduledTasks module
