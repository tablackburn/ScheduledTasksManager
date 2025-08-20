# Change Log

<!-- Disable markdownlint's no-duplicate-header rule -->
<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.3.1] - 2025-08-20

### Fixed

- Fixed credential passing in `Get-ClusteredScheduledTaskInfo`

## [0.3.0] - 2025-08-11

### Added

- `Get-StmScheduledTask` - New function to retrieve scheduled tasks from local
  or remote computers with credential support and consistent error handling
- `TaskPath` parameter to `Get-StmScheduledTaskRun` for filtering by task path
  location
- Comprehensive comment-based help documentation for `Get-StmScheduledTask`
  with detailed examples and parameter descriptions
- Unit tests for `Get-StmScheduledTask` to validate task retrieval
  functionality
- Help documentation file for `Get-StmScheduledTask` following module
  standards

### Changed

- Module version bumped to 0.3.0 in manifest
- Updated `Get-StmScheduledTaskRun` example to use `$credentials` variable
  name for consistency
- Improved verbose messaging in `Get-StmScheduledTaskRun` for better clarity
- Updated help documentation for `Get-StmScheduledTaskRun` to reflect new
  `TaskPath` parameter

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
