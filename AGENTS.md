# AGENTS.md

A comprehensive guide for AI coding agents working on the ScheduledTasksManager PowerShell module. This file consolidates all AI agent instructions, coding standards, and project-specific guidance.

## AI Agent Command Preferences

### Target Environment Context

**Primary Development Environment:**

- **Operating System**: Windows 11
- **Default Shell**: PowerShell 7+ (`pwsh.exe`)
- **Secondary Shells**: Windows PowerShell 5.1 (`powershell.exe`), Command Prompt (`cmd.exe`)
- **Project Type**: Windows-specific PowerShell module

### Command Preference Guidelines

**CRITICAL: When running on Windows systems, AI agents must prioritize and prefer Windows-native and PowerShell commands over Linux/Unix equivalents when suggesting commands in chat or code examples.**

**Preferred Command Mappings:**

| Instead of (Linux/Unix) | Use (Windows/PowerShell)             | Purpose              |
|-------------------------|--------------------------------------|----------------------|
| `grep`                  | `Select-String`                      | Text searching       |
| `find`                  | `Get-ChildItem`                      | File searching       |
| `ls`                    | `Get-ChildItem` or `dir`             | Directory listing    |
| `cat`                   | `Get-Content`                        | File content display |
| `head`                  | `Get-Content -First`                 | Show first lines     |
| `tail`                  | `Get-Content -Last`                  | Show last lines      |
| `wc -l`                 | `(Get-Content -Path file.txt).Count` | Line counting        |
| `ps`                    | `Get-Process`                        | Process listing      |
| `kill`                  | `Stop-Process`                       | Process termination  |
| `chmod`                 | `Set-ItemProperty`                   | Permission changes   |
| `sudo`                  | `Start-Process -Verb RunAs`          | Elevated execution   |

**Example Corrections:**

```powershell
# ❌ AVOID: Linux-style commands that fail on Windows
grep "error" logfile.txt
find . -name "*.ps1"
ls -la

# ✅ PREFER: PowerShell/Windows equivalents
Select-String -Pattern 'error' -Path logfile.txt
Get-ChildItem -Path . -Filter '*.ps1' -Recurse
Get-ChildItem -Force  # -Force shows hidden items like -la
```

**Shell-Specific Command Preferences:**

```powershell
# ✅ PREFERRED: PowerShell 7+ syntax
Get-ChildItem -Path 'tests/' -Filter '*.Tests.ps1' | Select-String -Pattern 'Describe'

# ✅ ACCEPTABLE: Windows Command Prompt when PowerShell not available
dir tests\*.Tests.ps1

# ❌ AVOID: Unix/Linux commands
find tests/ -name "*.Tests.ps1" -exec grep "Describe" {} \;
```

**Build and Development Commands:**

```powershell
# ✅ PREFERRED: Use project's build system
./build.ps1 -Task Test
./build.ps1 -Task Build

# ✅ ACCEPTABLE: Direct PowerShell module commands
Import-Module Pester
Invoke-Pester

# ❌ AVOID: Linux-style build commands
make test
npm run test (unless specifically for Node.js dependencies)
```

### PowerShell-Specific AI Agent Guidelines

**CRITICAL Command Preference Rules:**

AI agents working on this Windows PowerShell project must prioritize Windows-native and PowerShell commands over Linux/Unix equivalents when suggesting commands in chat or code examples.

**Advanced Command Mappings:**

| Task               | Instead of (Linux/Unix) | Use (Windows/PowerShell)                                  | Why                                              |
|--------------------|-------------------------|-----------------------------------------------------------|--------------------------------------------------|
| Text searching     | `grep`                  | `Select-String`                                           | Native PowerShell cmdlet with rich object output |
| File searching     | `find`                  | `Get-ChildItem`                                           | Supports PowerShell filtering and pipeline       |
| Directory listing  | `ls -la`                | `Get-ChildItem -Force`                                    | `-Force` shows hidden items like `-la`           |
| File content       | `cat`, `head`, `tail`   | `Get-Content`, `Get-Content -First`, `Get-Content -Last`  | Consistent PowerShell syntax                     |
| Process management | `ps`, `kill`            | `Get-Process`, `Stop-Process`                             | PowerShell object-based approach                 |
| Permission changes | `chmod`                 | `Set-ItemProperty`, `icacls`                              | Windows-appropriate permission handling          |

**PowerShell Idioms for AI Agents:**

**Function Design Patterns:**

- Always use `[CmdletBinding()]` for advanced function capabilities
- Implement `SupportsShouldProcess` for destructive operations
- Use `ValueFromPipeline` and `ValueFromPipelineByPropertyName` for pipeline support
- For advanced functions with pipeline input, use `begin`, `process`, and `end` blocks for proper pipeline processing
- For advanced functions without pipeline input, avoid `begin`, `process`, and `end` blocks (use simple function body)
- Follow approved PowerShell verbs (Get-Verb for verification)

**Parameter Validation Standards:**

- **All parameters MUST have validation attributes** - Every parameter should include appropriate validation to ensure data integrity and provide clear error messages
- Use `ValidateNotNullOrEmpty` for string parameters (instead of generic `ValidateNotNull`)
- Use `ValidateSet` for enumerated values and predefined choices
- Use `ValidateRange` for numeric parameters with min/max limits
- Use `ValidatePattern` for string format validation (regex patterns)
- Use `ValidateScript` for complex custom validation logic
- Use `ValidateLength` for string parameters with length requirements
- Use `ValidateCount` for array parameters with size constraints

**Error Handling Conventions:**

- Use `throw` for terminating errors
- Use `Write-Error` for non-terminating errors
- Implement try/catch blocks consistently with existing project patterns
- Use `$PSCmdlet.ThrowTerminatingError()` in advanced functions

**Output and Pipeline Best Practices:**

- Return rich objects, not formatted text
- Use `Write-Output` explicitly when needed
- Avoid `Write-Host` except for user interface messages
- Support pipeline input and output patterns established in the project

## Project Overview

ScheduledTasksManager is a PowerShell module for managing both local and clustered scheduled tasks on Windows systems. It supports operations in standalone environments as well as Windows Server Failover Clusters, extending the capabilities of the built-in `ScheduledTasks` module from Microsoft.

**Key Features:**

- Clustered Task Management: Register, enable, disable, start, and monitor scheduled tasks across failover cluster nodes
- Task Information & Monitoring: Retrieve detailed task information, run history, and cluster node details
- Configuration Management: Export and import task configurations for backup and deployment
- Advanced Filtering: Filter tasks by state, type, and ownership across cluster nodes
- Credential Management: Secure authentication with cluster nodes using credentials or CIM sessions

## AGENTS.md Maintenance Instructions

**CRITICAL: This file (AGENTS.md) serves as the single source of truth for AI coding agents working on this project. When making changes to the repository that affect agent behavior or project structure, AGENTS.md MUST be updated accordingly.**

### When to Update AGENTS.md

**Always update AGENTS.md when making changes to:**

- **Build System**: Changes to `build.ps1`, `psakeFile.ps1`, `requirements.psd1`, or VS Code tasks
- **Project Structure**: Adding/removing directories, changing file organization, or module structure
- **Development Tools**: Updates to VS Code configuration, extensions, linting rules, or debugging setup
- **Testing Framework**: Changes to Pester tests, test organization, or testing procedures
- **CI/CD Workflows**: Modifications to GitHub Actions, publishing processes, or deployment procedures
- **Dependencies**: Adding/removing PowerShell modules, Node.js packages, or external tools
- **Documentation Standards**: Changes to markdown rules, help generation, or documentation structure
- **Coding Standards**: Updates to PowerShell style guides, naming conventions, or best practices
- **Security Policies**: Changes to credential handling, authentication, or access control patterns

### Update Process

**Before committing changes that affect the above areas:**

1. **Review Impact**: Assess if your changes affect AI agent workflows or project understanding
2. **Update AGENTS.md**: Add, modify, or remove relevant sections to reflect your changes
3. **Test Instructions**: Verify that the updated instructions are accurate and complete
4. **Update Examples**: Ensure code examples and command references are current
5. **Validate Consistency**: Check that the entire AGENTS.md file remains internally consistent

### Specific Areas Requiring Updates

**Configuration File Changes:**

- `.vscode/tasks.json` → Update "Available VS Code Tasks" section
- `requirements.psd1` → Update "Dependencies and Requirements" section
- `psakeFile.ps1` → Update "PSake Build Configuration" section
- `.markdownlint.json` → Update "Markdown Documentation Standards" section

**Workflow Changes:**

- GitHub Actions files → Update "Automated Publishing" and "Git and Development Workflow" sections
- Build process changes → Update "Build Commands" and "Testing" sections
- New development tools → Update appropriate configuration sections

**Project Structure Changes:**

- New public functions → Update "Module-Specific Guidelines" and function lists
- Directory changes → Update "File Structure" section
- New development patterns → Add to relevant guidelines sections

### Quality Assurance

**After updating AGENTS.md:**

- Check for markdown issues using VS Code markdownlint extension (view Problems panel)
- Verify all internal links work correctly
- Ensure examples can be executed successfully
- Check that instructions are clear and unambiguous
- Test that AI agents can follow the updated guidance

**Remember: AGENTS.md is a living document that must evolve with the project to remain useful for AI coding agents.**

## AI Agent Interaction Guidelines

### Code Generation Principles

**Code Examples Must Follow Development Guidelines:**

- All PowerShell code examples in documentation must adhere to the PowerShell Development Guidelines section of this document
- Use single quotes for strings unless interpolation is needed
- Use named parameters when multiple parameters are specified
- Follow established formatting, naming conventions, and best practices outlined in this document

**Always Follow Project Patterns:**

- Analyze existing functions before creating new ones
- Match established parameter naming and validation patterns
- Follow the module's error handling conventions
- Use consistent comment-based help formatting

**PowerShell-Specific AI Guidance:**

- Generate functions with proper `[CmdletBinding()]` attributes
- Include `ValueFromPipeline` and `ValueFromPipelineByPropertyName` where appropriate
- Implement `SupportsShouldProcess` for destructive operations
- Use proper parameter validation attributes (`ValidateSet`, `ValidateNotNullOrEmpty`)
- Always include comment-based help with all required sections

**Testing Requirements:**

- Generate Pester tests for any new functions
- Follow the project's test structure hierarchy (`Describe`, `Context`, `It`)
- Use `BeforeAll` for function imports and setup
- Include both positive and negative test cases
- Mock external dependencies (CIM sessions, cluster operations)

**Documentation Standards:**

- Match the existing help format exactly
- Include practical examples in comment-based help
- Update changelog entries for user-facing changes
- **IMPORTANT**: Do NOT create files in `docs/` directory - all help documentation is automatically generated by the build process

**IMPORTANT:** All code examples in AGENTS.md must follow the instructions and standards defined in this document, unless they are intentionally demonstrating incorrect or discouraged patterns (which must be clearly marked as such).

### Codebase Analysis Workflow

**Before Making Changes:**

1. Run `./build.ps1 -Task Test` to understand current state
2. Examine existing similar functions for patterns
3. Check test files to understand expected behavior
4. Review module manifest for version and dependencies

**When Adding New Functions:**

1. Add to appropriate location (`Public/` or `Private/`)
2. Follow established naming convention (`Verb-StmNoun`)
3. Create corresponding test file in `tests/` directory
4. Update module manifest if adding new exported functions
5. Run build process to automatically generate help documentation (`./build.ps1 -Task Build`)

**Quality Validation:**

- Always run `./build.ps1 -Task Test` before submitting changes
- Use `./build.ps1 -Task Analyze` for PSScriptAnalyzer checks
- Verify that new functions appear in `Get-Command -Module ScheduledTasksManager`
- Test functions interactively to ensure they work as expected

### Cluster-Specific Considerations

**When Working with Clustered Functions:**

- Always support `-Cluster` parameter for cluster name specification
- Include proper credential handling with `-Credential` parameter
- Implement timeout handling for cluster operations
- Use CIM sessions for remote cluster node communication
- Include appropriate error handling for cluster connectivity issues
- Test with both standalone and clustered environments when possible

## Template-Based Code Generation Guidelines

### Function Creation Workflow

**Before Generating New Functions:**

1. **Analyze Existing Similar Functions**: Examine comparable functions in the `Public/` directory to understand established patterns
2. **Match Parameter Patterns**: Use identical validation attributes, parameter naming conventions, and structural organization
3. **Follow Error Handling Conventions**: Implement the same try/catch patterns and error message formatting used throughout the module
4. **Generate Corresponding Tests**: Create Pester tests following the exact structure and conventions found in existing test files
5. **Update Documentation**: Ensure comment-based help matches the project's established format and completeness standards

### Code Structure Requirements

**Parameter Declaration Standards:**

- Use consistent parameter validation attributes (`ValidateSet`, `ValidateNotNullOrEmpty`)
- Follow established parameter naming conventions (`TaskName`, `Cluster`, `Credential`)
- Implement proper pipeline support (`ValueFromPipeline`, `ValueFromPipelineByPropertyName`)
- Include appropriate `SupportsShouldProcess` for destructive operations

**Function Organization:**

- Place new public functions in `Public/` directory
- Place helper functions in `Private/` directory
- Follow the established file naming convention (`Verb-StmNoun.ps1`)
- Maintain consistent function structure (parameters, begin/process/end blocks, error handling)

### Testing Integration Requirements

**Mandatory Test Creation:**

- Generate corresponding test file in `tests/` directory
- Follow naming convention: `FunctionName.Tests.ps1`
- Use identical test structure hierarchy (`Describe`, `Context`, `It`) as existing tests
- Include both positive and negative test scenarios
- Mock all external dependencies (CIM sessions, cluster operations)

## AI Agent Development Workflow

### Discovery Phase

1. **Analyze Similar Functions** - Examine existing functions in `Public/` directory
2. **Review Test Patterns** - Study existing test files for structure and conventions
3. **Check Module Manifest** - Verify function export requirements
4. **Understand Project Context** - Review recent changes and project direction

### Implementation Phase

1. **Generate Function** - Create following established patterns
2. **Create Tests** - Generate comprehensive Pester tests
3. **Validate Build** - Run full build pipeline
4. **Interactive Test** - Manually verify function behavior
5. **Documentation Check** - Ensure auto-generated help is complete

### Validation Workflow

**Before Making Changes:**

1. Run `./build.ps1 -Task Test` to understand current state
2. Examine existing similar functions for patterns
3. Check test files to understand expected behavior
4. Review module manifest for version and dependencies

**Quality Validation:**

- Always run `./build.ps1 -Task Test` before submitting changes
- Use `./build.ps1 -Task Analyze` for PSScriptAnalyzer checks
- Verify that new functions appear in `Get-Command -Module ScheduledTasksManager`
- Test functions interactively to ensure they work as expected

### Release Management Workflow

**CRITICAL: AI agents must follow this exact sequence when managing releases:**

1. **Pre-Release Validation:**
   - Update module version in `ScheduledTasksManager.psd1`
   - Update `CHANGELOG.md` with complete release notes
   - Run `./build.ps1 -Task Test` locally to ensure all tests pass
   - Commit and push changes to trigger automated workflows

2. **Monitor Automated Publishing:**
   - **DO NOT create GitHub releases immediately**
   - Use `gh run list --limit 5` to monitor workflow status
   - Wait for both CI and "Publish Module to PowerShell Gallery" workflows to complete successfully
   - Check workflow details: `gh run view <run-id>` for any failures

3. **Verify PowerShell Gallery Publication:**
   - Confirm new version is available: `Find-Module -Name ScheduledTasksManager -Repository PSGallery`
   - Wait for PowerShell Gallery indexing (may take several minutes after workflow completion)
   - **Only proceed after confirming the new version is publicly available**

4. **Create GitHub Release (Final Step):**
   - Create and push git tag: `git tag -a v1.2.3 -m "Release v1.2.3" && git push origin v1.2.3`
   - Create GitHub release: `gh release create v1.2.3 --title "v1.2.3" --notes "[changelog-content]"`

**CRITICAL: GitHub Release Notes Formatting:**

When creating GitHub releases with `gh release create`, **always use single quotes** around the `--notes` parameter to prevent PowerShell from escaping backticks:

```powershell
# ✅ CORRECT: Use single quotes to preserve markdown code formatting
gh release create v1.2.3 --title "v1.2.3" --notes '## Added
- `Function-Name` - Description with proper code formatting'

# ❌ INCORRECT: Double quotes cause backtick escaping, showing \`Function-Name\` instead of `Function-Name`
gh release create v1.2.3 --title "v1.2.3" --notes "## Added
- `Function-Name` - Description with escaped backticks"
```

**Why This Matters:**

- PowerShell treats backticks as escape characters in double-quoted strings
- This causes `Function-Name` to display as \`Function-Name\` in GitHub release notes
- Single quotes prevent PowerShell from interpreting backticks, preserving proper markdown formatting
- Users see clean, properly formatted release notes with correct code highlighting

**Why This Order Matters:**

- Users expect to immediately install any version referenced in a GitHub release
- Creating GitHub releases before PowerShell Gallery publication causes confusion and support issues
- The automated workflow handles version validation and publishing reliably
- Manual verification ensures the release process completed successfully

## Setup and Build Commands

### Prerequisites

- Windows Server with Failover Clustering feature installed
- PowerShell 6.0 or later
- Appropriate permissions to manage clustered scheduled tasks

### Environment Setup

```powershell
# Bootstrap PowerShell dependencies (first time setup)
./build.ps1 -Bootstrap

# Install PowerShell module dependencies
./build.ps1 -Task Init -Bootstrap
```

### Build Commands

```powershell
# Run default build (includes tests)
./build.ps1

# Run specific tasks
./build.ps1 -Task Clean    # Clean output directory
./build.ps1 -Task Build    # Build module
./build.ps1 -Task Test     # Run all tests
./build.ps1 -Task Pester   # Run Pester tests only
./build.ps1 -Task Analyze  # Run PSScriptAnalyzer
./build.ps1 -Task Publish  # Publish to PowerShell Gallery
```

### Available VS Code Tasks

- **Clean**: Clean output directory
- **Build**: Build the module (default build task)
- **Test**: Run all tests (default test task)
- **Pester**: Run Pester tests only
- **Analyze**: Run PSScriptAnalyzer only
- **Publish**: Publish to PowerShell Gallery
- **Bootstrap**: Initialize build environment

### Testing

**IMPORTANT: Always use the build system for testing instead of running Pester directly.**

```powershell
# Run all tests (PREFERRED METHOD)
./build.ps1 -Task Test

# Run only Pester tests (when PSScriptAnalyzer is not needed)
./build.ps1 -Task Pester

# Run code analysis only
./build.ps1 -Task Analyze

# AVOID: Running Pester directly (use build system instead)
# Invoke-Pester -Path 'tests/Get-StmClusteredScheduledTask.Tests.ps1'
```

**Why use the build system:**

- Ensures consistent test environment and dependencies
- Runs PSScriptAnalyzer for code quality checks
- Generates proper test coverage reports
- Handles module loading and cleanup automatically
- Provides standardized output formatting
- Integrates with CI/CD pipelines

**Test Output:**

- Test coverage is output to `coverage.xml`
- Test results are output to `testResults.xml`
- PSScriptAnalyzer results included in test output
- Markdown linting handled by VS Code extension (check Problems panel for issues)

**AI Agent Testing Best Practices:**

- **Follow Existing Test Patterns**: Examine existing test files in the `tests/` directory to understand the established structure and conventions
- **Always Import Functions in BeforeAll**: Use `BeforeAll { . $PSScriptRoot/../Public/FunctionName.ps1 }` pattern
- **Mock External Dependencies**: Mock CIM sessions, cluster cmdlets, and external services following existing mock patterns
- **Test Both Success and Failure Scenarios**: Include positive tests, error conditions, and edge cases as demonstrated in current tests
- **Use Descriptive Test Names**: Follow "Should [expected behavior] when [condition]" pattern consistent with existing tests
- **Implement Proper Setup/Teardown**: Use `BeforeEach`/`AfterEach` for test isolation matching project conventions
- **Match Project Test Structure**: Use the same `Describe`, `Context`, and `It` hierarchy patterns found in existing test files

### Enhanced Testing Requirements for AI Agents

**Test Generation Standards:**

- **Always Generate Tests**: Every new function must have corresponding Pester tests
- **Follow Project Test Structure**: Use existing test files as templates for structure and organization
- **Mock External Dependencies**: All CIM sessions, cluster operations, and external services must be mocked
- **Test Both Success and Failure**: Include positive tests, error conditions, and edge cases
- **Validate Output Objects**: Test that returned objects have expected properties and types
- **Test Parameter Validation**: Verify that parameter validation attributes work correctly
- **Pipeline Testing**: Test both pipeline input and parameter input scenarios where applicable

**Test Coverage Requirements:**

- **Minimum Coverage**: Aim for comprehensive coverage of all function branches and error paths
- **Integration Testing**: Test functions work together as expected in realistic scenarios
- **Mocking Strategy**: Use consistent mocking patterns established in existing tests
- **Error Scenarios**: Test all documented error conditions and exception handling
- **Boundary Testing**: Test edge cases, null inputs, empty collections, and limit conditions

**Test Organization Standards:**

- **File Naming**: Follow `FunctionName.Tests.ps1` convention exactly
- **Test Structure**: Use `Describe` → `Context` → `It` hierarchy consistently
- **Setup Blocks**: Use `BeforeAll` for one-time setup, `BeforeEach` for per-test setup
- **Cleanup**: Implement proper cleanup in `AfterEach`/`AfterAll` blocks when needed
- **Test Data**: Create realistic test data that matches actual cluster environments
- **Assertion Clarity**: Use clear, descriptive assertions that explain what is being tested

## Quality Assurance Framework

### Pre-Commit Validation Requirements

**CRITICAL: All AI agents must complete these checks before suggesting changes:**

1. **Build System Validation**: Code must work with `./build.ps1 -Task Build`
2. **Comprehensive Testing**: Use `./build.ps1 -Task Test` instead of direct Pester execution
3. **Code Analysis**: Run `./build.ps1 -Task Analyze` for PSScriptAnalyzer checks
4. **Interactive Testing**: Test functions manually to ensure they work as expected
5. **Documentation Generation**: Verify help documentation generates correctly

### AI Agent Quality Gates

**Validation Process for Generated Code:**

- **Pattern Analysis**: Examine similar existing functions before code generation
- **Consistency Verification**: Match established parameter naming, validation, and structural patterns
- **Error Handling Review**: Implement the same error handling patterns used throughout the module
- **Integration Verification**: Confirm the function integrates properly with the module
- **Performance Consideration**: Evaluate pipeline support and performance implications

**Testing Requirements:**

- **Comprehensive Coverage**: Test positive, negative, and edge cases
- **Mock Strategy**: Mock all external dependencies (CIM sessions, cluster operations)
- **Pipeline Testing**: Test both parameter and pipeline input scenarios where applicable
- **Error Condition Testing**: Test all documented error conditions and exception handling
- **Boundary Testing**: Test edge cases, null inputs, empty collections, and limit conditions

## PowerShell Development Guidelines

### Naming Conventions

**Functions and Cmdlets:**

- Use approved PowerShell verbs (Get-Verb)
- Follow Verb-Noun format with singular nouns
- Use PascalCase for both verb and noun
- Avoid special characters and spaces
- Use PascalCase for acronyms (e.g., `Get-HttpResponse`)
- Avoid abbreviations unless well-known (e.g., `Get-UserProfile` instead of `Get-UP`)
- Exception: Maintain consistency with existing cmdlets when they use abbreviations (e.g., `Get-ADUser`)

**Parameters:**

- Use PascalCase
- Choose clear, descriptive names
- Use singular form unless always multiple
- Follow PowerShell standard names (`Path`, `Name`, `Force`, `Credential`)

**Variables:**

- Use PascalCase for public variables
- Use camelCase for private variables
- Avoid abbreviations
- Use meaningful names

### Parameter Design Patterns

Follow the parameter design patterns established in existing functions. Examine functions in the `Public/` directory to understand parameter structure, validation attributes, and naming conventions used throughout the module.

**Key Parameter Rules:**

- Use common parameter names (`Path`, `Name`, `Force`, `Credential`)
- Use `switch` data type for boolean flags (not `$true/$false` parameters)
- Default switches to `$false` when omitted
- Implement proper validation (`ValidateSet`, `ValidateNotNullOrEmpty`)
- Enable tab completion where possible
- Use `ValueFromPipeline` and `ValueFromPipelineByPropertyName` appropriately

### Advanced Function Requirements

**Mandatory Standards for All Functions:**

- **Always use `[CmdletBinding()]`** - Every function should be an advanced function for consistent behavior
- **Pipeline Support by Default** - Consider `ValueFromPipeline` and `ValueFromPipelineByPropertyName` for maximum flexibility
- **Proper Block Structure** - Use `begin`, `process`, `end` blocks when parameters support pipeline input
- **ShouldProcess Implementation** - Add `-WhatIf` and `-Confirm` for destructive operations using `SupportsShouldProcess`

**Parameter Design Excellence:**

- **Strong Typing Always** - Use specific types rather than generic objects (`[string]` not `[object]`)
- **Comprehensive Validation** - Use `ValidateSet`, `ValidateNotNullOrEmpty`, `ValidatePattern`, `ValidateScript`
- **Pipeline-Friendly Aliases** - Use parameter aliases for common property names (`[Alias('ComputerName')]`)
- **Help Text for Mandatory** - Always include `HelpMessage` for mandatory parameters
- **Default Parameter Sets** - Define logical parameter sets for complex functions
- **Parameter Name Formatting** - **CRITICAL**: Always place parameter names on their own line, separate from type declarations and validation attributes

### Pipeline and Output Patterns

**Pipeline Input:**

Follow the pipeline input patterns used in existing functions. Examine how `ValueFromPipeline` and `ValueFromPipelineByPropertyName` are implemented in current module functions.

**Pipeline Block Structure:**

- **With Pipeline Input**: Use `begin`, `process`, and `end` blocks when parameters support `ValueFromPipeline` or `ValueFromPipelineByPropertyName`
- **Without Pipeline Input**: Use simple function body structure when no pipeline input is supported

**Output Objects:**

- Return rich objects, not formatted text
- Use `PSCustomObject` for structured data
- Avoid `Write-Host` for data output
- Use `Write-Output` for returning objects
- Set `OutputType` attribute for cmdlets
- Avoid the `return` keyword for outputting objects

**PassThru Pattern:**

Follow the PassThru implementation patterns used in existing functions that support the `-PassThru` parameter.

### Error Handling and Safety

**ShouldProcess Implementation:**

Follow the ShouldProcess implementation patterns used in existing functions that support the `-WhatIf` and `-Confirm` parameters. Examine functions like `Enable-StmClusteredScheduledTask`, `Disable-StmClusteredScheduledTask`, and `Stop-StmClusteredScheduledTask` for established patterns.

**Error Handling Pattern:**

Follow the error handling patterns established in existing functions throughout the module. Examine functions in the `Public/` directory to understand the consistent approach to try/catch blocks, error messages, and exception handling used throughout the project.

**Message Streams:**

- `Write-Verbose` for operational details with `-Verbose`
- `Write-Warning` for warning conditions
- `Write-Error` for non-terminating errors
- `throw` for terminating errors
- Avoid `Write-Host` except for user interface text

### Code Style and Formatting

**Consistent Formatting:**

- Use proper indentation (4 spaces recommended)
- Opening braces on same line as statement
- Closing braces on new line
- Use line breaks after pipeline operators
- PascalCase for function and parameter names
- **Line Length**: Lines should not exceed 120 characters. See the "Line Length and Wrapping" section for detailed examples.
- Use single quotes for strings unless interpolation is needed
- Prefer string interpolation over the format operator (-f) for simple variable insertion; use -f only when
   specific formatting is required (numeric precision, padding, alignment).
  - Example: "This is $($message)"
- Align parameter attributes vertically for readability
- Align key/value pairs in hashtables for readability

### Line Length and Wrapping

To maintain readability, all PowerShell code and documentation should adhere to a **120-character line limit**. When a line exceeds this limit, use the following standard techniques for wrapping, ensuring that **indentation and vertical alignment are maintained** for clarity.

#### Code Wrapping with Splatting

For function calls with many parameters, **use splatting with a hashtable**. This is the standard and most readable method for handling complex command invocations. Aligning the `=` signs in the hashtable is required.

**❌ AVOID:** A long, single line that is hard to read and maintain.

```powershell
Get-StmClusteredScheduledTask -TaskName "My Very Long Task Name That Exceeds The Line Limit" -Cluster "MyCluster" -Credential (Get-Credential) -TaskPath "\Some\Very\Long\Path\That\Also\Exceeds\The\Limit"
```

**✅ PREFER:** Splatting parameters for superior clarity and maintainability, with vertical alignment.

```powershell
$taskParameters = @{
    TaskName   = "My Very Long Task Name That Exceeds The Line Limit"
    Cluster    = "MyCluster"
    Credential = (Get-Credential)
    TaskPath   = "\Some\Very\Long\Path\That\Also\Exceeds\The\Limit"
}
Get-StmClusteredScheduledTask @taskParameters
```

#### Pipeline Wrapping

When chaining commands with pipelines, break the line **after the pipe `|` character** and indent the next line to align with the start of the previous command.

```powershell
Get-ChildItem -Path '.\Public' -Filter '*.ps1' |
    Select-String -Pattern 'CmdletBinding' |
    Measure-Object
```

#### Comment-Based Help Wrapping

Comment-based help sections like `.DESCRIPTION`, `.PARAMETER`, and `.EXAMPLE` must also be wrapped at 120 characters. When wrapping, always match the indentation of the block. For example, if the block uses 8 spaces, every wrapped line must also use 8 spaces. Do not reduce indentation for wrapped lines; maintain visual alignment and consistency throughout the block. Only break lines at logical points (such as after a complete phrase or sentence), and avoid splitting words or breaking up parameter names.

**❌ AVOID:** Long, unwrapped help text that requires horizontal scrolling.

```powershell
<#
.DESCRIPTION
   This is a very long and detailed description for a function that does many complicated things and this single line of text is extremely difficult to read in a standard editor because it goes on and on forever without any line breaks.
#>
```

**✅ PREFER:** Manually wrapped help text for readability, matching the block's indentation.

```powershell
<#
.DESCRIPTION
   This is a very long and detailed description for a function that does many
   complicated things. Manually wrapping the text makes it much easier to read
   in any editor without requiring horizontal scrolling.
#>
```

**Parameter Declaration Format:**

Follow the parameter declaration patterns established in existing functions. Examine functions in the `Public/` directory to understand the consistent formatting for parameter attributes, validation, and documentation alignment.

**CRITICAL: Parameter names must be on their own line, separate from type declarations and validation attributes for maximum readability and PowerShell best practices.**

**Parameter Attribute Formatting:** When a parameter attribute has multiple arguments, each argument should be placed on its own line for improved readability and maintainability.

**Parameter Separation:** Always separate individual parameter declarations with a blank line for improved readability and visual organization.

```powershell
# ✅ CORRECT: Each parameter has its own validation attribute, and all attributes and types are on separate lines.
# Separate each parameter block with a blank line for clarity.
[Parameter(
   Mandatory = $true,
   ValueFromPipeline = $true,
   ValueFromPipelineByPropertyName = $true
)]
[ValidateNotNullOrEmpty()]
[string]
$TaskName,

[Parameter(Mandatory = $false)]
[ValidateNotNullOrEmpty()]
[string]
$TaskPath = '\',

[Parameter(Mandatory = $false)]
[ValidateNotNull()]
[System.Management.Automation.PSCredential]
$Credential

# ❌ INCORRECT (for contrast only): Attributes and types on the same line, no validation for all parameters, no blank lines.
[Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$TaskName,
[Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] [string]$TaskPath = '\',
[Parameter(Mandatory = $false)] [System.Management.Automation.PSCredential]$Credential
```

**Hash Table Format:**

Match the hashtable formatting style used throughout existing PowerShell functions in the module.

**AI-Specific Code Quality Guidelines:**

- **Self-Documenting Code**: Prioritize clear naming and structure over extensive comments
- **Defensive Programming**: Always validate inputs and handle edge cases explicitly
- **Resource Management**: Use proper disposal patterns for CIM sessions and external resources
- **Performance Awareness**: Consider pipeline streaming for large data sets
- **Security First**: Never hardcode credentials or sensitive data
- **Testability**: Write code that can be easily unit tested with Pester

**Best Practices:**

- **Avoid Shorthand and Abbreviations**: Always use full, descriptive words instead of shorthand. For example, use `Parameters` instead of `Params`, `Configuration` instead of `Config`, and `Properties` instead of `Props`. This improves clarity and reduces ambiguity.
- Use named parameters when calling functions or cmdlets with multiple parameters
- Positional parameters are acceptable for single parameter calls or well-known cases (`-Message` parameter)
- Use `#region` and `#endregion` for logical grouping with descriptive titles
- Capitalize the first letter of comments
- Avoid abbreviated words: Use `Configuration` not `Config`, `Information` not `Info`, `Parameters` not `Params`
- Never use backticks (`) for line continuation; use parentheses or splatting
- Avoid semicolons; use separate lines for better readability and PowerShell idiomatic style
- Prefer `foreach` over `ForEach-Object` for better performance
- Add `else` blocks for clarity in conditional statements
- Use `switch` statements for multiple conditions
- Explicitly define attribute values (`SupportsShouldProcess = $true`, `Mandatory = $true`)

**Additional Best Practices:**

- Remove trailing whitespace from all lines in code and documentation. Trailing spaces can cause unnecessary diffs and reduce readability.
- Use single quotes for all strings unless variable interpolation or escape sequences are required.
- Use full sentences for comments, starting with a capital letter and ending with a period. Avoid redundant comments that restate what the code does.
- Each file should contain only one function, and the file name should match the function name.
- Use `Write-Verbose` for operational details, `Write-Warning` for non-critical issues, and `Write-Error` for errors. Avoid `Write-Host` except for user-facing output.
- Avoid global variables or state unless absolutely necessary. Prefer passing data explicitly via parameters or return values.
- Format all error messages consistently, including the function name and relevant parameter values for easier debugging.
- Always use [Get-Verb](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands) for function names and avoid custom verbs.
- Use early return patterns to handle errors and edge cases, reducing nesting and improving code clarity.
- If a function supports pipeline input, ensure it also supports pipeline output, and document both in the help section.
- Default to the most secure and least-permissive settings for credentials, file access, and network operations.
- Order parameters as: required first, then optional, then switches, then common parameters (e.g., `-Verbose`, `-WhatIf`).
- Use `#region` and `#endregion` to logically group related code sections in large files for easier navigation.
- Every public function must have complete comment-based help, including `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.INPUTS`, `.OUTPUTS`, `.NOTES`, and `.LINK`.

### Documentation Requirements

**Comment-Based Help Pattern:**

Follow the exact comment-based help format used in existing functions in the `Public/` directory. Examine functions like `Get-StmClusteredScheduledTask.ps1` for the established help documentation patterns and formatting conventions.

**Required Help Sections:**

- `.SYNOPSIS` - Brief description
- `.DESCRIPTION` - Detailed explanation
- `.EXAMPLE` - Practical usage examples (multiple recommended)
- `.PARAMETER` - Description for each parameter
- `.INPUTS` - Type of pipeline input
- `.OUTPUTS` - Type of output returned
- `.NOTES` - Additional information
- `.LINK` - URLs only (no internal references)

**IMPORTANT**: Do NOT create files in `docs/` directory - all help documentation is automatically generated by the build process

### Testing Guidelines

**Pester Test Structure:**

Follow the test structure and organization patterns established in existing test files in the `tests/` directory. Examine test files to understand the consistent hierarchy, naming conventions, and setup/teardown patterns used throughout the project.

**Testing Best Practices:**

- Use Pester for unit testing
- Test cmdlet functionality and edge cases
- Mock external dependencies
- Validate output objects and properties
- Use `It`, `Should`, and `Describe` blocks for clarity
- Never use `param` blocks in mock script blocks
- Run tests with `./build.ps1 -Task Test`

## Module-Specific Guidelines

### Function Naming Convention

All public functions should use the `Stm` prefix (ScheduledTasksManager):

- `Get-StmClusteredScheduledTask`
- `Register-StmClusteredScheduledTask`
- `Start-StmClusteredScheduledTask`

### Cluster Management Patterns

When working with clustered scheduled tasks:

- Always support `-Cluster` parameter for cluster name
- Include `-Credential` parameter for authentication
- Implement proper error handling for cluster connectivity
- Use CIM sessions for remote operations
- Support pipeline input for task names
- Run `./build.ps1 -Task Build` to automatically generate documentation after adding functions

### Common Parameters

Consistently implement these parameters across functions:

- `Cluster` - Target cluster name
- `TaskName` - Scheduled task name
- `TaskPath` - Task path (default to "\")
- `Credential` - Authentication credentials
- `ComputerName` - Target computer name
- `Force` - Skip confirmations
- `WhatIf` and `Confirm` - ShouldProcess support

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
tests/                           # Pester tests
├── Get-StmClusteredScheduledTask.Tests.ps1
├── Help.tests.ps1
├── Manifest.tests.ps1
└── ...
docs/                           # Auto-generated documentation (DO NOT EDIT)
└── en-US/
    ├── Get-StmClusteredScheduledTask.md
    └── ...
```

## Security Considerations

- Always validate input parameters
- Use secure credential handling
- Implement proper error handling to avoid information disclosure
- Support `-WhatIf` for destructive operations
- Use appropriate `ConfirmImpact` levels
- Implement proper access control checks

## Markdown Documentation Standards

When creating or editing markdown files:

**Structure:**

- Use H2 (`##`) and H3 (`###`) headings for hierarchy
- Avoid H1 headings (generated from title)
- Use proper bullet points (`-`) and numbered lists
- Limit line length to 120 characters for readability

**Content:**

- Use fenced code blocks with language specification
- Include alt text for images
- Use proper markdown syntax for links
- Include descriptive link text
- Use tables for tabular data with proper alignment

**Validation:**

- Follow markdownlint rules (configured in `.markdownlint.json`)
- Auto-generated docs (in `docs/` folder) are excluded from linting via `.markdownlintignore`
- Use appropriate whitespace for readability
- **Required**: Use the VS Code markdownlint extension (`davidanson.vscode-markdownlint`) for markdown linting
- Check for issues in VS Code Problems panel or run `get_errors` tool to see markdownlint violations
- The extension respects the project's `.markdownlint.json` configuration file
- Run `./build.ps1 -Task Analyze` to run PSScriptAnalyzer checks

**VS Code markdown linting workflow:**

- Install the markdownlint extension (`davidanson.vscode-markdownlint`) for real-time linting in VS Code
- View markdown issues in the VS Code Problems panel
- The extension automatically uses the project's `.markdownlint.json` configuration
- Use the extension's auto-fix feature (Ctrl+Shift+P → "markdownlint: Fix all supported markdownlint violations in document")

## Badge and Status Display Standards

The project follows consistent standards for displaying project status and metrics through GitHub badges.

### Badge Configuration

**Location:** `README.md`

**Standard Badges:**

```markdown
[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/ScheduledTasksManager)](https://www.powershellgallery.com/packages/ScheduledTasksManager/)
![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/ScheduledTasksManager)
![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/tablackburn/ScheduledTasksManager/.github/workflows/CI.yaml?branch=main)
![PowerShell Gallery](https://img.shields.io/powershellgallery/p/ScheduledTasksManager)
```

### Badge Categories

**PowerShell Gallery Integration:**

- **Download Count**: Shows total downloads from PowerShell Gallery
- **Version Display**: Current published version on PowerShell Gallery
- **Platform Compatibility**: Supported PowerShell platforms

**Build and CI Status:**

- **GitHub Actions Status**: Real-time build status from CI workflow
- **Branch-Specific**: Status specifically for the main branch
- **Workflow-Specific**: Links to specific workflow file for transparency

### Badge Best Practices

- **Clickable Links**: All badges link to relevant pages (PowerShell Gallery, GitHub Actions)
- **Real-Time Updates**: Badges automatically update with current status
- **Consistent Formatting**: Use shields.io for consistent badge appearance
- **Logical Ordering**: Place most important badges (downloads, version) first
- **Accessibility**: Include meaningful alt text for screen readers

## Project Documentation Structure Standards

The project follows a structured approach to documentation that provides clear guidance for users and contributors.

### README Structure

**Required Sections:**

1. **Project Title and Description**: Clear, concise project overview
2. **Badge Display**: Status and metric badges for quick project assessment
3. **Documentation Link**: Direct link to comprehensive documentation site
4. **What This Project Does**: Detailed feature overview with bullet points
5. **Why This Project Is Useful**: Value proposition and problem-solving focus
6. **Getting Started**: Prerequisites, installation, and quick start examples
7. **Available Functions**: Complete function list with brief descriptions
8. **Getting Help**: Documentation, support, and community resources
9. **Project Maintenance**: Maintainer information and contribution guidelines

### Documentation Standards

**Consistency Requirements:**

- Use H2 (`##`) for main sections, H3 (`###`) for subsections
- Include code examples with proper syntax highlighting
- Provide practical, working examples in quick start sections
- Link to comprehensive help and documentation resources
- Maintain professional tone while being accessible to new users

**Content Guidelines:**

- **Feature Lists**: Use bullet points for easy scanning
- **Code Examples**: Include realistic, working examples
- **External Links**: Link to PowerShell Gallery, GitHub resources, and documentation
- **Version Information**: Keep version references current and accurate
- **Community Resources**: Provide clear paths for getting help and contributing

## GitHub Funding Configuration

The project supports community funding through GitHub Sponsors to help maintain and improve the module.

### Funding Configuration

**Location:** `.github/FUNDING.yml`

The funding configuration enables GitHub Sponsors integration for the project maintainer.

### Purpose

- Enables GitHub Sponsors button on the repository
- Allows community members to support project development
- Helps sustain long-term maintenance and feature development
- Provides transparent funding mechanism for contributors

### Usage

Community members can:

1. Click the "Sponsor" button on the GitHub repository
2. Choose from available sponsorship tiers
3. Support the project through recurring or one-time contributions
4. Help fund feature development and maintenance efforts

## Git and Development Workflow

**Commit Messages:**

- Use conventional commit format when possible
- Be descriptive and concise
- Reference issues when applicable

**Branch Management:**

- Work on feature branches
- Use meaningful branch names
- Keep commits focused and atomic

**Pull Requests:**

- Run all tests before submitting (`./build.ps1 -Task Test`)
- Include appropriate documentation updates
- Follow the contribution guidelines in `CONTRIBUTING.md`

**Automated Publishing:**

The module is automatically published to the PowerShell Gallery using GitHub workflows when specific conditions are met:

**Publishing Workflow (`PublishModuleToPowerShellGallery.yaml`):**

- **Trigger Conditions:**
  - Push to `main` branch with changes in `ScheduledTasksManager/**` directory
  - Manual workflow dispatch (can be triggered manually from GitHub Actions tab)

- **Prerequisites for Publishing:**
  1. **Version Bump Required:** The module version in `ScheduledTasksManager.psd1` must be incremented to a version that doesn't already exist on PowerShell Gallery
  2. **CI Tests Must Pass:** The CI workflow must complete successfully (runs automatically on pushes and pull requests)
  3. **Repository Secrets:** `ps_gallery_key` secret must be configured with a valid PowerShell Gallery API key

- **Publishing Process:**
  1. Workflow checks out the code and bootstraps the build environment
  2. Compares the current module version with PowerShell Gallery to determine if version was bumped
  3. If version is new, runs `./build.ps1 -Task 'Publish'` to publish to PowerShell Gallery
  4. If version already exists, publishing is skipped

**CI Workflow (`CI.yaml`):**

- Runs on pushes to `main` and pull requests
- Executes `./build.ps1 -Task 'Test'` which includes:
  - Pester unit tests
  - PSScriptAnalyzer code quality checks
  - Test result artifacts are uploaded for review

**Documentation Workflow (`PublishMkDocsToGitHubPages.yaml`):**

- **Trigger Conditions:**
  - Push to `main` branch with changes in `docs/`, `mkdocs.yml`, or `README.md`
  - Manual workflow dispatch (can be triggered manually from GitHub Actions tab)

- **Publishing Process:**
  1. Checks out the code from the main branch
  2. Copies `README.md` to `docs/index.md` to serve as the documentation homepage
  3. Deploys the MkDocs site to GitHub Pages using the `docs/` folder content
  4. Updates the live documentation at [tablackburn.github.io/ScheduledTasksManager](https://tablackburn.github.io/ScheduledTasksManager/)

### MkDocs Configuration

**Configuration File:** `mkdocs.yml`

The project uses MkDocs for documentation site generation with ReadTheDocs theme and automated navigation generation.

**Key Features:**

- **Automatic Navigation**: The `include_dir_to_nav` plugin automatically generates navigation from the `docs/en-US/` directory structure
- **External Links**: Direct links to the GitHub repository's changelog
- **Search Integration**: Built-in search functionality across all documentation
- **ReadTheDocs Theme**: Professional documentation theme for consistency

**Documentation Requirements:**

- Python requirements specified in `docs/requirements.txt`
- Auto-generated PowerShell help files in `docs/en-US/` (excluded from markdown linting)
- `README.md` is automatically copied to `docs/index.md` during deployment

**Steps to Publish a New Version:**

1. Update module version in `ScheduledTasksManager/ScheduledTasksManager.psd1`
2. Update `CHANGELOG.md` with release notes
3. Ensure all tests pass locally: `./build.ps1 -Task Test`
4. Commit and push changes to `main` branch to trigger automated workflows
5. **CRITICAL: Wait for GitHub Actions to complete successfully before proceeding**
   - Monitor GitHub Actions workflows: `gh run list --limit 5`
   - Verify CI workflow passes: `gh run view <run-id>`
   - Verify PowerShell Gallery publishing workflow completes: `gh run view <publish-run-id>`
6. **Verify PowerShell Gallery Publication:**
   - Check that the new version is available: `Find-Module -Name ScheduledTasksManager -Repository PSGallery`
   - Wait for PowerShell Gallery to update (may take a few minutes after workflow completion)
7. **Only after successful PowerShell Gallery publication:**
   - Create git tag: `git tag -a v1.2.3 -m "Release v1.2.3"`
   - Push tag: `git push origin v1.2.3`
   - Create GitHub release: `gh release create v1.2.3 --title "v1.2.3" --notes '[changelog-content]'`

**IMPORTANT: Do not create GitHub releases until PowerShell Gallery publication is confirmed. This ensures users can immediately install the version referenced in the GitHub release.**

**CRITICAL: Use single quotes around --notes parameter to prevent PowerShell from escaping backticks in markdown code formatting (e.g., `Function-Name`). Double quotes cause backticks to display as \`Function-Name\` instead of proper code formatting.**

**Git Tagging:**

The project follows semantic versioning for git tags with a `v` prefix format (e.g., `v1.2.3`). Tags should be created after successful publication to PowerShell Gallery.

**Tag Creation Process:**

1. Ensure the module has been successfully published to PowerShell Gallery
2. Create an annotated git tag with the version number:

   ```powershell
   git tag -a v1.2.3 -m "Release v1.2.3"
   ```

3. Push the tag to the remote repository:

   ```powershell
   git push origin v1.2.3
   ```

4. Create a GitHub release from the tag with release notes:

   ```powershell
   gh release create v1.2.3 --title "v1.2.3" --notes "[changelog-content]"
   ```

**Tag Naming Convention:**

- Use semantic versioning: `vMAJOR.MINOR.PATCH`
- **Major** (v2.0.0): Breaking changes
- **Minor** (v1.2.0): New features, backward compatible
- **Patch** (v1.1.1): Bug fixes, backward compatible
- Match the version in `ScheduledTasksManager.psd1` exactly

**Alternative GitHub Release Creation:**

You can also create releases through the GitHub web interface:

1. Go to the repository's Releases page
2. Click "Create a new release"
3. Select the tag or create a new one
4. Use the changelog content for release notes
5. Publish the release

## Changelog Management

**IMPORTANT: Always update `CHANGELOG.md` when making changes that affect users.**

### When to Update the Changelog

Update the changelog for:

- New features or functions
- Bug fixes
- Breaking changes
- Deprecated functionality
- Security fixes
- Performance improvements
- Documentation changes that affect user experience

**Do NOT update for:**

- Internal refactoring without user impact
- Test updates
- Build system changes
- Development tooling changes

### Changelog Format

The project follows [Keep a Changelog](http://keepachangelog.com/) format with [Semantic Versioning](http://semver.org/):

```markdown
## [Unreleased]

### Added
- New features and functionality

### Changed
- Changes to existing functionality

### Deprecated
- Features that will be removed in future versions

### Removed
- Features removed in this version

### Fixed
- Bug fixes

### Security
- Security-related changes
```

### Changelog Workflow

1. **During Development:**
   - Add changes to the `[Unreleased]` section immediately when making user-facing changes
   - Use present tense and be descriptive: "Add support for credential authentication"
   - Include function names in backticks: `` `Get-StmClusteredScheduledTask` ``

2. **Before Release:**
   - Move items from `[Unreleased]` to a new version section
   - Use the format: `## [X.Y.Z] - YYYY-MM-DD`
   - Remove empty subsections
   - Ensure version matches the module manifest version

3. **Version Numbering:**
   - **Major** (X.0.0): Breaking changes
   - **Minor** (0.X.0): New features, backward compatible
   - **Patch** (0.0.X): Bug fixes, backward compatible

### Example Changelog Entry

```markdown
## [Unreleased]

### Added
- `Wait-StmClusteredScheduledTask` - Wait for clustered scheduled task completion
- Support for custom timeout values in cluster operations

### Fixed
- Fixed credential validation in `Get-StmClusteredScheduledTaskInfo`
- Resolved pipeline input handling for task names with spaces
```

## Dependencies and Requirements

### Build Dependencies

**Configuration File:** `requirements.psd1`

The project uses PSDepend for dependency management with pinned versions for essential PowerShell modules including Pester, psake, BuildHelpers, PowerShellBuild, and PSScriptAnalyzer.

**Dependency Management Best Practices:**

- **Version Pinning**: All dependencies specify exact versions for reproducible builds
- **Publisher Check Skipping**: Pester module skips publisher verification for automated installs
- **CurrentUser Scope**: Dependencies installed at user level to avoid permission issues
- **Bootstrap Process**: `./build.ps1 -Bootstrap` automatically installs all dependencies

### Dependency Version Monitoring

**Monthly Dependency Review:**

AI agents should check for updated dependency versions monthly and inform users about available updates without automatically updating them.

**Review Process:**

1. **Check Current Versions**: Compare `requirements.psd1` versions against PowerShell Gallery
2. **Identify Updates**: Report any newer stable versions available
3. **Inform Only**: Notify the user about updates but do not automatically modify `requirements.psd1`
4. **Update Tracking**: Update the "Last Dependency Check" date below after each review

**Last Dependency Check:** October 2, 2025 (All dependencies current as of this date)

### PSake Build Configuration

**Configuration File:** `psakeFile.ps1`

**Build Preferences:**

The psake configuration defines build preferences including module compilation settings, help localization, and test output formatting for CI integration.

**Custom Build Tasks:**

- **Test Output**: JUnit XML format for CI integration
- **Modular Structure**: Non-monolithic PSM1 for better development experience
- **Markdown Linting**: Handled by VS Code extension for real-time feedback

### Runtime Requirements

- PowerShell 6.0 or later
- Windows Server with Failover Clustering (for cluster operations)
- Appropriate administrative permissions

## VS Code Configuration

The project includes comprehensive VS Code configuration for optimal PowerShell development experience.

### Debugging Configuration

**Configuration File:** `.vscode/launch.json`

The project includes pre-configured debugging sessions for build tasks:

**Available Debug Configurations:**

- **Run Build and Debug**: Standard debugging with integrated console
- **Run Build and Debug (Temp Console)**: Debugging with temporary console for isolation

**Usage:**

1. Set breakpoints in PowerShell files
2. Press `F5` or use Debug panel
3. Select appropriate debug configuration
4. Debug through build process and tests

### Extension Recommendations

**Configuration File:** `.vscode/extensions.json`

**Recommended Extensions:**

- `ms-vscode.PowerShell` - Official PowerShell extension for VS Code
- `DavidAnson.vscode-markdownlint` - Markdown linting and formatting

**Installation:**

VS Code will automatically prompt to install recommended extensions when opening the workspace, or you can install them manually:

1. Open Command Palette (`Ctrl+Shift+P`)
2. Run "Extensions: Show Recommended Extensions"
3. Install the suggested extensions

### Development Features

The VS Code configuration provides:

- PowerShell formatting settings with custom rules
- Code completion and IntelliSense
- Integrated debugging with breakpoint support
- Task execution through Command Palette
- Spell checking integration
- Markdown linting via markdownlint extension with project-specific rules

Use the predefined tasks in VS Code for common operations like building, testing, and publishing the module.

## Local GitHub Actions Testing with Act

The project supports local testing of GitHub Actions workflows using [Act](https://nektosact.com/), which allows you to run workflows locally before pushing changes.

### Act Configuration

**Configuration File:** `.actrc`

The Act configuration specifies platform runners for local GitHub Actions testing, using appropriate images for Ubuntu workflows and self-hosted configuration for Windows workflows.

### Setup and Usage

**Prerequisites:**

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- [Act](https://nektosact.com/installation/index.html) installed

**Installation:**

```powershell
# Install Act using winget (Windows)
winget install nektos.act

# Or using Chocolatey
choco install act-cli

# Or using Scoop
scoop install act
```

**Usage Examples:**

```powershell
# List available workflows
act -l

# Run the CI workflow
act -W .github/workflows/CI.yaml

# Run a specific job in a workflow
act -W .github/workflows/CI.yaml -j test

# Run with verbose output
act -W .github/workflows/CI.yaml -v

# Dry run (show what would be executed)
act -W .github/workflows/CI.yaml -n
```

**Important Notes:**

- Windows workflows (`windows-latest`) are configured to use self-hosted runners due to Act limitations with Windows containers
- Ubuntu workflows will use the specified Act runner image
- Some GitHub-specific features may not work identically in local Act runs
- Use Act primarily for testing workflow logic and PowerShell script execution

## Spell Checking Configuration

The project includes comprehensive spell checking configuration to maintain documentation quality and prevent common spelling errors.

### Configuration File

**Location:** `.vscode/cspell.json`

### Custom Word Lists

The spell checker includes PowerShell and project-specific terms that should always be considered correct:

- `Cmdletization` - PowerShell cmdlet generation process
- `Contoso` - Microsoft's standard example company name
- `hashtable`/`hashtables` - PowerShell data structures
- `ParamBlock` - PowerShell parameter block
- `psake` - Build automation tool
- `taskschd.dll` - Windows Task Scheduler library
- `timediff` - Time difference calculations
- `unregistration` - Task removal process

### Flagged Words

The following words are flagged to prevent common abbreviations and promote consistent terminology:

- `auth` → Use "authentication" or "authorize"
- `config`/`configs` → Use "configuration"
- `creds` → Use "credentials"
- `param`/`params` → Use "parameter" or "parameters"
- `repo`/`repos` → Use "repository"
- `hte` → Common typo for "the"

### Regular Expression Patterns

The spell checker ignores PowerShell-specific syntax patterns:

- `param\s?\(` - Ignores PowerShell parameter declarations

### VS Code Integration

The spell checking configuration works automatically with VS Code's built-in spell checker and integrates with the Code Spell Checker extension if installed. Spelling errors will appear with squiggly underlines in the editor.

## Git Ignore Patterns

The project uses comprehensive git ignore patterns to exclude build artifacts, temporary files, and development tools from version control.

### Git Ignore Configuration

**Configuration File:** `.gitignore`

**Based on:** PowerShell community standards (adapted from PnP PowerShell project)

**Key Exclusion Categories:**

- **Build Results**: `[Dd]ebug/`, `[Rr]elease/`, `x64/`, `x86/`, `bld/`, `[Bb]in/`, `[Oo]bj/`
- **Visual Studio**: `.vs/`, `*.suo`, `*.user`, `*.userosscache`, `*.sln.docstates`
- **Test Results**: `[Tt]est[Rr]esult*/`, `[Bb]uild[Ll]og.*`, `TestResult.xml`
- **Development Tools**: User-specific files, cache directories, temporary files
- **PowerShell Specific**: Build outputs, module artifacts, test coverage files

### Markdown Lint Ignore

**Configuration File:** `.markdownlintignore`

```ignore
# Exclude documentation files from linting as they are auto-generated cmdlet help
docs/**/*.md
```

**Purpose:**

- Excludes auto-generated PowerShell help documentation from markdown linting
- Prevents linting errors on generated content that doesn't follow markdown standards
- Focuses linting on manually authored documentation

## Cross-Platform Command Execution

**File Path Handling:**

```powershell
# Use Join-Path for cross-platform path handling
$configPath = if ($IsWindows) {
    Join-Path -Path $env:ProgramData -ChildPath 'ScheduledTasksManager'
} else {
    Join-Path -Path '/etc' -ChildPath 'scheduledtasksmanager'
}
```

## Effective AI Prompting for ScheduledTasksManager

### Prompt Engineering Best Practices

**For Function Generation:**

```text
Create a PowerShell function following the ScheduledTasksManager module patterns:
- Function name: [Verb-StmNoun format]
- Purpose: [Clear description of what it does]
- Parameters: [List required and optional parameters]
- Pipeline support: [Specify if it should accept pipeline input]
- Error handling: [Mention cluster connectivity, validation requirements]
- Testing: [Request Pester tests with specific scenarios]

Example: "Create Get-StmClusteredScheduledTaskHistory that retrieves task run history
from cluster nodes, accepts TaskName from pipeline, includes proper credential handling,
and has comprehensive Pester tests."
```

**For Code Reviews:**

```text
Review this PowerShell function for ScheduledTasksManager compliance:
- Check naming conventions and parameter design
- Validate comment-based help completeness
- Ensure proper error handling for cluster operations
- Verify pipeline support implementation
- Confirm test coverage requirements
- Check for security considerations (credential handling)
```

**For Debugging:**

```text
Debug this ScheduledTasksManager issue:
- Environment: [Standalone/Clustered]
- Error message: [Full error text]
- Function: [Specific function having issues]
- Expected behavior: [What should happen]
- Context: [Build system, manual testing, etc.]

Please suggest troubleshooting steps following the project's debugging patterns.
```

### Context-Aware Prompting

**Always Provide Project Context:**

- Mention that this is a Windows PowerShell module for scheduled tasks
- Specify if working with clustered or standalone scenarios
- Reference existing similar functions for pattern matching
- Include relevant error messages or build output
- Specify the target PowerShell version (6.0+)

**Effective Prompt Patterns:**

- **Chain-of-Thought**: "First analyze the existing Get-StmClusteredScheduledTask function, then create a similar function for..."
- **Few-Shot Examples**: "Following the pattern used in Enable-StmClusteredScheduledTask, create a function that..."
- **Role-Based**: "As a PowerShell module maintainer familiar with failover clustering, help me..."

## Community Standards Integration

### Reference Materials

**PowerShell Community Standards:**

- **PoshCode PowerShell Practice and Style** - [PowerShell Best Practices and Style Guide](https://github.com/PoshCode/PowerShellPracticeAndStyle)
- **Microsoft Guidelines** - PowerShell Team coding standards from PowerShell/PowerShell repository
- **Best Practices Focus** - Emphasizes readability, maintainability, and security

### Alignment Principles

**Community Consistency:**

- **Follow Established Patterns** - Match PowerShell community conventions for naming, structure, and documentation
- **Microsoft Alignment** - Use patterns consistent with official PowerShell modules and Microsoft practices
- **Industry Standards** - Implement security, performance, and maintainability best practices

**PowerShell-Specific Adoption:**

- **Approved Verbs** - Always use `Get-Verb` approved verbs for function names
- **Parameter Conventions** - Follow standard parameter names (`Path`, `Name`, `Credential`, `Force`)
- **Pipeline Design** - Support pipeline input/output following PowerShell conventions
- **Error Handling** - Use PowerShell-appropriate error handling patterns
- **Help Documentation** - Provide complete comment-based help following PowerShell standards

### Integration with Project Standards

**Alignment Strategy:**

- **Project First** - When project patterns conflict with general community standards, follow project patterns for consistency
- **Community Enhancement** - When no project-specific guidance exists, adopt community best practices
- **Continuous Improvement** - Regularly evaluate project patterns against evolving community standards

## Staying Current with AI Development Best Practices

### GitHub Awesome Copilot Resource

#### Regular Review Required

AI coding agents working on this project should regularly check the [GitHub Awesome Copilot](https://github.com/github/awesome-copilot) repository for:

- **Latest AI Development Patterns**: New best practices for AI-assisted development
- **Emerging Tools and Techniques**: Updated tooling that could improve the development workflow
- **Community Standards**: Evolving standards for AI agent interaction and code generation
- **Performance Improvements**: New approaches to optimize AI-assisted coding efficiency
- **Integration Opportunities**: Tools and practices that could enhance this project's development experience

**Recommended Actions:**

- Check the repository monthly for significant updates
- Evaluate new tools and practices for potential integration into this project
- Suggest improvements to the AGENTS.md file based on discovered best practices
- Consider contributing project-specific patterns back to the community when appropriate
- Update project tooling and configuration when beneficial improvements are identified

**Review Schedule:**

- Monthly review of new additions and changes
- Quarterly assessment of project integration opportunities
- Annual comprehensive review of all practices and tools

**Last Checked:** *Not yet reviewed* (Update this date when checking the repository)

## Agent-Specific Error Patterns and Troubleshooting

### Common AI Agent Issues and Solutions

**PowerShell Module Loading Errors:**

```powershell
# ❌ AVOID: Import errors due to missing dependencies
Import-Module ScheduledTasksManager

# ✅ PREFER: Use build system for testing
./build.ps1 -Task Test  # Properly loads module with dependencies
```

**Test Execution Patterns:**

```powershell
# ❌ AVOID: Running tests without proper module context
Invoke-Pester -Path 'tests/Get-StmClusteredScheduledTask.Tests.ps1'

# ✅ PREFER: Use build system for consistent environment
./build.ps1 -Task Pester  # Ensures proper module loading and cleanup
```

**Path Resolution Issues:**

```powershell
# ❌ AVOID: Hardcoded paths that fail in different environments
$configPath = 'C:\ScheduledTasksManager\config.json'

# ✅ PREFER: Use relative paths from module root
$configPath = Join-Path -Path $PSScriptRoot -ChildPath 'config\settings.json'
```

**Parameter Validation Failures:**

```powershell
# ❌ AVOID: Generic parameter validation and poor formatting
[ValidateNotNull()]
[string]$TaskName

# ✅ PREFER: Specific validation with proper formatting
[ValidateNotNullOrEmpty()]
[ValidatePattern('^[^\\/:*?"<>|]*$')]  # No invalid filename characters
[string]
$TaskName
```

### Debugging and Development Patterns

**VS Code Debugging Setup:**

- Use F5 to start debugging with pre-configured launch configurations
- Set breakpoints in PowerShell files before running build tasks
- Use "Run Build and Debug" configuration for interactive development
- Debug through build process and tests with integrated console

**Common Development Workflow Issues:**

```powershell
# Issue: Module not reloading during development
# Solution: Use build system which handles module cleanup
./build.ps1 -Task Clean
./build.ps1 -Task Build

# Issue: Test failures due to stale module state
# Solution: Always use build system for testing
./build.ps1 -Task Test  # Ensures fresh module load
```

## Pre-Commit Quality Gates

### Mandatory Checks Before Committing

**CRITICAL: All contributors must run these checks before committing:**

1. **Code Quality and Tests:**

   ```powershell
   ./build.ps1 -Task Test  # Runs Pester tests AND PSScriptAnalyzer
   ```

## AI Agent Behavior Guidelines

### Interaction Patterns

- **Ask First, Act Later**: For destructive operations, always confirm with user before execution
- **Explain Your Actions**: Provide clear reasoning for code suggestions and architectural decisions
- **Progressive Disclosure**: Start with simple solutions, offer complexity when needed
- **Context Awareness**: Always consider the existing codebase patterns and project conventions
- **Confirmation First**: Ask before making destructive changes or major refactoring
- **Pattern Matching**: Always analyze similar existing functions before creating new ones
- **Consistency First**: Match established parameter naming, validation, and structural patterns

### AI Agent Development Standards

- **Test-Driven**: Generate comprehensive Pester tests alongside new functions
- **Documentation-Complete**: Include full comment-based help with practical examples
- **Security-Conscious**: Never hardcode credentials or sensitive data
- **Performance-Aware**: Consider pipeline streaming for large data sets
- **Defensive Programming**: Always validate inputs and handle edge cases explicitly

### Error Handling and Recovery

- When code generation fails, provide specific error analysis and alternative approaches
- Always test suggestions against project patterns before proposing
- If uncertain about PowerShell best practices, reference the project's established patterns
- Provide multiple solution approaches when encountering complex problems
- Reference specific sections of this AGENTS.md file when explaining standards

- Avoid conflicting, redundant, duplicated, or similar instructions. Consolidate guidance to a single, clear location to ensure clarity and maintainability.
