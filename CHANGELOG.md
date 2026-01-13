# Change Log

<!-- Disable markdownlint's no-duplicate-header rule -->
<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.11.1] - 2026-01-12

### Changed

- Decomposed `Set-StmClusteredScheduledTask` into 5 private helper functions for better maintainability:
  - `Update-StmTaskActionXml` - Updates Actions in task XML
  - `Update-StmTaskTriggerXml` - Updates Triggers in task XML (with DaysOfWeek/WeeksInterval support for weekly triggers)
  - `Update-StmTaskSettingsXml` - Updates Settings in task XML
  - `Update-StmTaskPrincipalXml` - Updates Principal in task XML
  - `Update-StmTaskUserXml` - Updates UserId in task XML
- Removed script-scoped variables anti-pattern from `Set-StmScheduledTask`, `Get-StmClusteredScheduledTask`, and `ConvertTo-StmResultMessage`
  - Variables in `begin` block are naturally accessible in `process` and `end` blocks without `$script:` prefix

### Fixed

- `Set-StmClusteredScheduledTask`: Password parameter now throws a clear error explaining it's not supported for clustered tasks (native `Register-ClusteredScheduledTask` doesn't accept passwords)

## [0.11.0] - 2026-01-11

### Added

- `Get-StmResultCodeMessage` - Translate Windows Task Scheduler result codes to human-readable messages
  - Supports Task Scheduler codes (SCHED_S_*, SCHED_E_*), HRESULT/Win32 errors, and common COM errors
  - Returns detailed information including symbolic name, message, success/failure status, and HRESULT facility
  - Accepts integers, decimal strings, or hex strings (0x prefix) via pipeline or parameter
- `Get-StmScheduledTaskRun`: Added `ResultMessage` property with automatic translation of result codes
- `Get-StmClusteredScheduledTaskRun`: Inherits `ResultMessage` property from standalone variant

### Changed

- Extracted Win32 error translation to `Get-StmWin32ErrorMessage` private helper for better testability
- Improved code coverage from 96.99% to 99.19% for result code translation functions

## [0.10.7] - 2026-01-11

### Fixed

- `New-StmError`: Removed unnecessary `SupportsShouldProcess` attribute from factory function that only creates ErrorRecord objects

## [0.10.6] - 2026-01-11

### Changed

- `Get-StmScheduledTaskRun`: Replaced Stack with simple foreach loop for task processing (cleaner code)
- `Get-StmScheduledTaskRun`: Use `List<object>` instead of array concatenation for combining events (better performance)
- `Get-StmClusteredScheduledTask`: Use hashtable for O(1) task lookups instead of repeated Where-Object filtering
- `Get-WinEventXPathFilter`: Simplified keyword aggregation loop

## [0.10.5] - 2026-01-11

### Fixed

- `Stop-StmClusteredScheduledTask`: Fixed nested catch block that was masking the actual error source (stop vs retrieve errors now reported correctly)
- `Get-StmScheduledTaskRun`: Fixed collection modification issue and improved event processing efficiency by collecting and sorting events in a single pass
- `Get-StmScheduledTaskRun`: `ResultCode` property now always returns an array for consistent output type
- `Get-StmClusteredScheduledTaskInfo`: Refactored state property handling to avoid redundant enum-to-string conversions

## [0.10.4] - 2026-01-11

### Fixed

- `Get-StmClusteredScheduledTask`: Added cleanup of task owner CIM sessions when errors occur during task retrieval
- `Wait-StmClusteredScheduledTask`: Added error handling for transient cluster connectivity issues with automatic retry (up to 3 consecutive failures before throwing)

## [0.10.3] - 2026-01-10

### Fixed

- Fixed CIM session resource leaks across 18 cmdlets that were creating sessions without cleanup:
  - Standalone cmdlets: `Get-StmScheduledTask`, `Enable-StmScheduledTask`, `Disable-StmScheduledTask`, `Wait-StmScheduledTask`, `Unregister-StmScheduledTask`, `Start-StmScheduledTask`, `Stop-StmScheduledTask`, `Export-StmScheduledTask`, `Register-StmScheduledTask`, `Import-StmScheduledTask`
  - Clustered cmdlets: `Get-StmClusteredScheduledTask`, `Enable-StmClusteredScheduledTask`, `Disable-StmClusteredScheduledTask`, `Register-StmClusteredScheduledTask`, `Unregister-StmClusteredScheduledTask`, `Set-StmClusteredScheduledTask`, `Set-StmScheduledTask`, `Import-StmClusteredScheduledTask`
- Sessions are now properly cleaned up in `end` or `finally` blocks using `Remove-CimSession`

## [0.10.2] - 2026-01-10

### Fixed

- Corrected `Get-TaskNameFromXml` parameter name from `-Xml` to `-XmlContent` in three call sites:
  - `Import-StmScheduledTask.ps1` (lines 298 and 398)
  - `Register-StmScheduledTask.ps1` (line 159)
- While PowerShell's parameter abbreviation allowed the old code to work, using the correct parameter name is best practice and prevents issues if the function signature changes

## [0.10.1] - 2025-12-30

### Fixed

- PSScriptAnalyzer warnings across multiple cmdlets:
  - Fixed unused variable assignments (`$result` → `$null`)
  - Fixed long lines using array join pattern and splatting
  - Fixed brace placement in switch/if statements
  - Fixed hashtable alignment issues
  - Fixed indentation inconsistencies
- Files updated: `Set-StmClusteredScheduledTask`, `Set-StmScheduledTask`, `Export-StmScheduledTask`, `Register-StmScheduledTask`, `Unregister-StmScheduledTask`, `Wait-StmScheduledTask`

## [0.10.0] - 2025-12-29

### Added

- `Set-StmScheduledTask` - Modify scheduled task properties (Actions, Triggers, Settings, Principal) on local or remote computers
  - Two parameter sets: `ByName` for direct task identification, `ByInputObject` for pipeline input
  - Full credential support via CIM sessions
  - WhatIf/Confirm support with ConfirmImpact = Medium
  - PassThru parameter to return modified task object
- `Set-StmClusteredScheduledTask` - Modify clustered scheduled task properties in failover clusters
  - Same modification capabilities as standalone variant plus TaskType
  - Uses Export/Unregister/Register pattern (no native Set-ClusteredScheduledTask exists)
  - Pipeline support from Get-StmClusteredScheduledTask

## [0.9.0] - 2025-12-29

### Added

- 8 new standalone scheduled task cmdlets with built-in credential support for remote management:
  - `Enable-StmScheduledTask` - Enable scheduled tasks on local or remote computers
  - `Export-StmScheduledTask` - Export scheduled task configuration to XML
  - `Import-StmScheduledTask` - Import scheduled tasks from XML files
  - `Register-StmScheduledTask` - Register new scheduled tasks
  - `Start-StmScheduledTask` - Start scheduled tasks
  - `Stop-StmScheduledTask` - Stop running scheduled tasks
  - `Unregister-StmScheduledTask` - Remove scheduled tasks
  - `Wait-StmScheduledTask` - Wait for scheduled task completion
- These cmdlets provide a simpler interface than the native ScheduledTasks module by handling CIM session creation internally via `-Credential` parameter

## [0.8.2] - 2025-12-29

### Fixed

- Bug fix: Multiple result codes handling in `Get-StmScheduledTaskRun`
  - Removed incorrect `Select-Object -ExpandProperty 'ResultCode'` on string array
  - Now correctly returns multiple result codes as an array when present
- PSScriptAnalyzer warnings: Reformatted long `.EXAMPLE` lines using splatting

### Changed

- Build system: Updated ScriptAnalysis task to analyze only `.ps1` files
  - Excludes auto-generated `.psd1` module manifests from analysis
- Test coverage improved from 92.4% to 95.0%
  - Expanded `Get-StmClusteredScheduledTaskInfo` tests (6 → 25 tests)
  - Expanded `Get-StmScheduledTaskRun` tests with edge case coverage
  - Expanded `Import-StmClusteredScheduledTask` tests
- Improved README documentation with function tables and usage examples

## [0.8.1] - 2025-12-29

### Changed

- Updated private helper functions to follow coding standards
  - Added `[CmdletBinding()]` and `[OutputType()]` attributes to `Initialize-XPathFilter`, `Join-XPathFilter`
  - Moved comment-based help to correct location (before `param()` block)
  - Fixed variable naming to use camelCase in `Get-WinEventXPathFilter`
  - Fixed `$True`/`$False` to `$true`/`$false` per PowerShell conventions
- Fixed PSScriptAnalyzer warnings for line length and indentation in `Get-StmClusteredScheduledTask` and `Import-StmClusteredScheduledTask`

### Added

- Expanded test coverage for `Get-StmScheduledTask` and `Get-StmClusterNode` functions

## [0.8.0] - 2025-12-29

### Added

- `Import-StmClusteredScheduledTask` - Import clustered scheduled tasks from XML files, complementing `Export-StmClusteredScheduledTask`
  - Single file import with `-Path` parameter
  - XML string import with `-Xml` parameter
  - Bulk directory import with `-DirectoryPath` parameter (imports all .xml files)
  - Auto-extracts task name from XML `RegistrationInfo/URI` element
  - Optional `-TaskName` override for single imports
  - `-Force` parameter to overwrite existing tasks
  - Progress reporting for bulk imports
  - Continues on partial failures in bulk mode with summary report
- `Get-TaskNameFromXml` private helper function for XML task name extraction

### Fixed

- Build system now works around PowerShellBuild 0.7.3 bug in `Test-PSBuildScriptAnalysis.ps1` (typo: `$_Severity` instead of `$_.Severity` causing null reference exception)
- Added custom `ScriptAnalysis` task until PowerShellBuild releases a fix

## [0.7.0] - 2025-10-15

### Added

- `Get-StmScheduledTaskInfo` - Retrieve detailed information about scheduled tasks including last run time, next run time, last task result, and running duration for both local and remote computers

## [0.6.0] - 2025-10-14

### Added

- `Get-StmClusteredScheduledTaskInfo` now includes `RunningDuration` property showing how long a clustered task has been running
- `RunningDuration` returns a TimeSpan object for easy formatting and is null when task is not running

## [0.5.1] - 2025-10-14

### Fixed

- Fixed `Wait-StmClusteredScheduledTask` timeout exception error where null exception parameter caused "Cannot bind argument to parameter 'Exception' because it is null" error
- Changed timeout error category from `WriteError` to `OperationTimeout` for better semantic accuracy
- Added comprehensive test coverage for timeout exception handling

## [0.5.0] - 2025-10-02

### Added

- `Disable-StmScheduledTask` - Disable scheduled tasks on local or remote computers with credential support
- Comprehensive AI agent guidelines in `AGENTS.md` for development best practices
- Markdown linting configuration with `.markdownlint.json` and `.markdownlintignore`
- Enhanced VS Code settings for improved markdown editing experience

### Changed

- Simplified GitHub contributing guidelines format for better clarity
- Improved README.md formatting and badge consistency

### Removed

- Legacy `.cursor` rules files (markdown.mdc, powershell.mdc)
- Unused GitHub issue and pull request templates

## [0.4.0] - 2025-08-21

### Added

- `Get-StmClusteredScheduledTaskRun` - Get task runs in a cluster
- `Stop-StmClusteredScheduledTask` - Stop a running clustered scheduled task

## [0.3.1] - 2025-08-20

### Fixed

- Fixed credential passing in `Get-ClusteredScheduledTaskInfo`

## [0.3.0] - 2025-08-11

### Added

- `Get-StmScheduledTask` - New function to retrieve scheduled tasks from local or remote computers with credential support and consistent error handling
- `TaskPath` parameter to `Get-StmScheduledTaskRun` for filtering by task path location
- Comprehensive comment-based help documentation for `Get-StmScheduledTask` with detailed examples and parameter descriptions
- Unit tests for `Get-StmScheduledTask` to validate task retrieval functionality
- Help documentation file for `Get-StmScheduledTask` following module standards

### Changed

- Module version bumped to 0.3.0 in manifest
- Updated `Get-StmScheduledTaskRun` example to use `$credentials` variable name for consistency
- Improved verbose messaging in `Get-StmScheduledTaskRun` for better clarity
- Updated help documentation for `Get-StmScheduledTaskRun` to reflect new `TaskPath` parameter

## [0.2.0] - 2025-07-30

### Added

- `MaxRuns` parameter to `Get-StmScheduledTaskRun` for limiting task run retrieval
- Unit tests for `Get-StmScheduledTaskRun` to validate task retrieval, event handling, and XML conversion
- Additional examples and parameters details for `Get-StmScheduledTaskRun`
- `Register-StmClusteredScheduledTask` now supports `ShouldProcess` with `-WhatIf` and `-Confirm` parameters for improved safety during task registration
- Verbose output for XML content usage in `Register-StmClusteredScheduledTask`
- Error handling in `Export-StmClusteredScheduledTask` to check for null scheduled task retrieval

## [0.1.0] - 2025-07-29

### Added

- Initial release of ScheduledTasksManager PowerShell module
- Support for managing clustered scheduled tasks in Windows Server Failover Clusters
- `Get-StmClusteredScheduledTask` - Retrieve clustered scheduled tasks with filtering capabilities
- `Get-StmClusteredScheduledTaskInfo` - Get detailed information about clustered scheduled tasks
- `Get-StmClusterNode` - Retrieve cluster node information
- `Get-StmScheduledTaskRun` - Get scheduled task run history
- `Register-StmClusteredScheduledTask` - Register new clustered scheduled tasks
- `Unregister-StmClusteredScheduledTask` - Remove clustered scheduled tasks
- `Enable-StmClusteredScheduledTask` - Enable clustered scheduled tasks
- `Disable-StmClusteredScheduledTask` - Disable clustered scheduled tasks
- `Start-StmClusteredScheduledTask` - Manually start clustered scheduled tasks
- `Wait-StmClusteredScheduledTask` - Wait for clustered scheduled task completion
- `Export-StmClusteredScheduledTask` - Export clustered scheduled task configurations
- Comprehensive help documentation for all cmdlets
- Support for credential-based authentication to clusters
- CIM session management for cluster connections
- Task state and type filtering capabilities
- Integration with Microsoft's ScheduledTasks module
