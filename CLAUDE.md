# Claude Code Instructions

## Project Overview

ScheduledTasksManager is a PowerShell module for managing Windows Scheduled Tasks across standalone machines and Windows Failover Clusters.

## Build System

All build and test operations use `build.ps1` with psake tasks:

```powershell
# Bootstrap dependencies (first time)
./build.ps1 -Bootstrap

# Run unit tests (default)
./build.ps1

# List available tasks
./build.ps1 -Help
```

### Available Tasks

| Task | Description |
|------|-------------|
| `Default` | Runs `Test` |
| `Build` | Compiles the module |
| `Test` | Runs unit tests + script analysis |
| `UnitTest` | Runs Pester unit tests (excludes Integration) |
| `ScriptAnalysis` | Runs PSScriptAnalyzer |
| `Integration` | Runs integration tests (auto-detects local/remote/CI mode) |

## Testing

### Unit Tests

Located in `tests/*.Tests.ps1`. Run with:

```powershell
./build.ps1 UnitTest
```

Unit tests mock all external dependencies (cluster cmdlets, CIM sessions, etc.).

### Integration Tests

Located in `tests/Integration/`. Require a live Windows Failover Cluster via AutomatedLab.

The `Integration` task supports three modes (auto-detected):

| Mode | Detection | Description |
|------|-----------|-------------|
| **CI** | `HYPERV_HOST`, `HYPERV_USER`, `HYPERV_PASS` env vars set | Connects to remote Hyper-V host via WinRM |
| **Remote** | `lab.mode = "remote"` in config | Uses `Invoke-RemoteIntegrationTest.ps1` |
| **Local** | Default (no env vars, config mode = "local") | AutomatedLab on local machine |

**Local execution:**
```powershell
./build.ps1 Integration
```

**CI execution:** Runs automatically on PRs via GitHub Actions using Tailscale to connect to a remote Hyper-V host. The CI mode is auto-detected when `HYPERV_HOST`, `HYPERV_USER`, and `HYPERV_PASS` environment variables are set. See `.github/workflows/Integration.yaml`.

Integration tests are "best effort" - they run when the lab is available but don't block PRs if unavailable.

## Code Style

- Follow PSScriptAnalyzer rules in `PSScriptAnalyzerSettings.psd1`
- Use approved PowerShell verbs for function names
- Include comment-based help for all public functions
- Prefix internal/private functions appropriately

## CI/CD

### Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `CI.yaml` | Push/PR to main | Unit tests, script analysis, code coverage |
| `Integration.yaml` | PR to main | Integration tests via Tailscale (best-effort) |

### Integration Test Infrastructure

The integration tests connect via Tailscale to a Hyper-V host running AutomatedLab with a 3-node Windows Failover Cluster:

- STMDC01: Domain Controller + File Share Witness
- STMNODE01: Cluster Node 1
- STMNODE02: Cluster Node 2

See `tests/Integration/README.md` for setup details.

## Module Structure

```
ScheduledTasksManager/
├── Public/           # Exported cmdlets
├── Private/          # Internal helper functions
├── Classes/          # PowerShell classes
└── ScheduledTasksManager.psd1  # Module manifest
```

## Common Tasks

### Adding a new cmdlet

1. Create function in `ScheduledTasksManager/Public/`
2. Add to `FunctionsToExport` in `.psd1` manifest
3. Add unit tests in `tests/`
4. Add comment-based help with examples

### Running specific tests

```powershell
# Run tests for a specific file
Invoke-Pester ./tests/Get-StmClusteredScheduledTask.Tests.ps1 -Output Detailed

# Run with code coverage
Invoke-Pester ./tests/ -CodeCoverage ./ScheduledTasksManager/**/*.ps1
```
