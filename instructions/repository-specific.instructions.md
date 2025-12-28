---
applyTo: '**/*'
description: 'Repository-specific instructions for the ScheduledTasksManager PowerShell module'
---

# ScheduledTasksManager Repository Instructions

## Project Overview

ScheduledTasksManager is a PowerShell module for managing both local and clustered scheduled
tasks on Windows systems. It supports operations in standalone environments as well as Windows
Server Failover Clusters, extending the capabilities of the built-in `ScheduledTasks` module
from Microsoft.

**Key Features:**

- Clustered Task Management: Register, enable, disable, start, and monitor scheduled tasks
  across failover cluster nodes
- Task Information and Monitoring: Retrieve detailed task information, run history, and cluster
  node details
- Configuration Management: Export and import task configurations for backup and deployment
- Advanced Filtering: Filter tasks by state, type, and ownership across cluster nodes
- Credential Management: Secure authentication with cluster nodes using credentials or CIM
  sessions

## Target Environment

- **Operating System**: Windows 11 / Windows Server
- **Default Shell**: PowerShell 7+ (`pwsh.exe`)
- **Secondary Shells**: Windows PowerShell 5.1 (`powershell.exe`)
- **Project Type**: Windows-specific PowerShell module

## Command Preferences

**CRITICAL: AI agents must prioritize Windows-native and PowerShell commands over Linux/Unix
equivalents.**

| Instead of (Linux) | Use (Windows/PowerShell)             |
| ------------------ | ------------------------------------ |
| `grep`             | `Select-String`                      |
| `find`             | `Get-ChildItem`                      |
| `ls`               | `Get-ChildItem` or `dir`             |
| `cat`              | `Get-Content`                        |
| `head`             | `Get-Content -First`                 |
| `tail`             | `Get-Content -Last`                  |
| `ps`               | `Get-Process`                        |
| `kill`             | `Stop-Process`                       |

## Module Naming Convention

All public functions use the `Stm` prefix (ScheduledTasksManager):

- `Get-StmClusteredScheduledTask`
- `Register-StmClusteredScheduledTask`
- `Start-StmClusteredScheduledTask`
- `Get-StmScheduledTaskRun`

## File Structure

```text
ScheduledTasksManager/
├── ScheduledTasksManager.psd1    # Module manifest
├── ScheduledTasksManager.psm1    # Main module file
├── Public/                       # Public functions (exported)
│   ├── Get-StmClusteredScheduledTask.ps1
│   ├── Register-StmClusteredScheduledTask.ps1
│   └── ...
├── Private/                      # Private functions (internal)
│   ├── New-StmCimSession.ps1
│   ├── New-StmError.ps1
│   └── ...
tests/                            # Pester tests
├── Get-StmClusteredScheduledTask.Tests.ps1
├── Help.tests.ps1
├── Manifest.tests.ps1
└── ...
docs/                             # Auto-generated documentation (DO NOT EDIT)
└── en-US/
    ├── Get-StmClusteredScheduledTask.md
    └── ...
instructions/                     # AI agent instructions (AIM)
└── *.instructions.md
```

## Build System

### Build Commands

```powershell
# Bootstrap dependencies (first time setup)
./build.ps1 -Bootstrap

# Run default build (includes tests)
./build.ps1

# Run specific tasks
./build.ps1 -Task Clean     # Clean output directory
./build.ps1 -Task Build     # Build module
./build.ps1 -Task Test      # Run all tests (unit + PSScriptAnalyzer)
./build.ps1 -Task UnitTest  # Run Pester tests only (excludes integration)
./build.ps1 -Task Analyze   # Run PSScriptAnalyzer only
./build.ps1 -Task Publish   # Publish to PowerShell Gallery
```

### Testing

**IMPORTANT: Always use the build system for testing instead of running Pester directly.**

```powershell
# Run all tests (PREFERRED METHOD)
./build.ps1 -Task Test

# Run only unit tests (excludes Integration folder)
./build.ps1 -Task UnitTest

# Run integration tests (requires admin + deployed lab)
./build.ps1 -Task Integration
```

**Why use the build system:**

- Ensures consistent test environment and dependencies
- Runs PSScriptAnalyzer for code quality checks
- Generates proper test coverage reports
- Handles module loading and cleanup automatically

**Test Output:**

- Test results: `out/testResults.xml`
- Code coverage: `coverage.xml`

## Common Parameters

Consistently implement these parameters across functions:

- `Cluster` - Target cluster name
- `TaskName` - Scheduled task name
- `TaskPath` - Task path (default to `\`)
- `Credential` - Authentication credentials
- `ComputerName` - Target computer name
- `Force` - Skip confirmations
- `WhatIf` and `Confirm` - ShouldProcess support

## Cluster-Specific Patterns

When working with clustered functions:

- Always support `-Cluster` parameter for cluster name specification
- Include proper credential handling with `-Credential` parameter
- Implement timeout handling for cluster operations
- Use CIM sessions for remote cluster node communication
- Include appropriate error handling for cluster connectivity issues

## Documentation

**IMPORTANT**: Do NOT create files in `docs/` directory. All help documentation is automatically
generated by the build process when running `./build.ps1 -Task Build`.

All public functions must have complete comment-based help including:

- `.SYNOPSIS` - Brief description
- `.DESCRIPTION` - Detailed explanation
- `.PARAMETER` - Description for each parameter
- `.EXAMPLE` - Practical usage examples (multiple recommended)
- `.INPUTS` - Type of pipeline input
- `.OUTPUTS` - Type of output returned
- `.NOTES` - Additional information

## CI/CD Workflows

### Publishing to PowerShell Gallery

The module is automatically published via GitHub Actions when:

- Push to `main` branch with changes in `ScheduledTasksManager/ScheduledTasksManager.psd1`
- Manual workflow dispatch

**Prerequisites:**

1. Version in `ScheduledTasksManager.psd1` must be incremented
2. CI tests must pass
3. `PS_GALLERY_KEY` secret must be configured

### Release Process

1. Update module version in `ScheduledTasksManager/ScheduledTasksManager.psd1`
2. Update `CHANGELOG.md` with release notes
3. Run `./build.ps1 -Task Test` locally
4. Commit and push to `main` branch
5. **Wait for GitHub Actions to complete successfully**
6. **Verify PowerShell Gallery publication**: `Find-Module -Name ScheduledTasksManager`
7. **Only after confirmation**, create GitHub release:

   ```powershell
   git tag -a v1.2.3 -m "Release v1.2.3"
   git push origin v1.2.3
   gh release create v1.2.3 --title "v1.2.3" --generate-notes
   ```

**IMPORTANT: Do not create GitHub releases until PowerShell Gallery publication is confirmed.**

## Dependencies

**Configuration File:** `build.depend.psd1`

The project uses PSDepend for dependency management with pinned versions:

- Pester (testing framework)
- psake (build automation)
- BuildHelpers (build utilities)
- PowerShellBuild (module building)
- PSScriptAnalyzer (code analysis)

Install dependencies: `./build.ps1 -Task Init -Bootstrap`

## MkDocs Documentation

The project uses MkDocs for documentation site generation:

- **Configuration**: `mkdocs.yml`
- **Live site**: [tablackburn.github.io/ScheduledTasksManager](https://tablackburn.github.io/ScheduledTasksManager/)
- **Auto-deployment**: On push to `main` with changes in `docs/`, `mkdocs.yml`, or `README.md`

## Security Considerations

- Always validate input parameters
- Use secure credential handling with `[PSCredential]`
- Implement proper error handling to avoid information disclosure
- Support `-WhatIf` for destructive operations
- Use appropriate `ConfirmImpact` levels
- Never hardcode credentials or sensitive data

## VS Code Configuration

The project includes:

- Pre-configured debugging sessions (`.vscode/launch.json`)
- Recommended extensions (`.vscode/extensions.json`)
- Spell checking configuration (`.vscode/cspell.json`)

**Recommended Extensions:**

- `ms-vscode.PowerShell` - Official PowerShell extension
- `DavidAnson.vscode-markdownlint` - Markdown linting

## Quality Gates

Before committing changes:

1. Run `./build.ps1 -Task Test` - All tests must pass
2. Run `./build.ps1 -Task Analyze` - No PSScriptAnalyzer errors
3. Check VS Code Problems panel for markdown issues
4. Verify new functions appear in `Get-Command -Module ScheduledTasksManager`
