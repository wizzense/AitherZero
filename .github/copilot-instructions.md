# AitherZero AI Coding Agent Instructions

This file provides guidance for GitHub Copilot coding agents working on this repository. It includes architecture details, development patterns, testing procedures, and best practices specific to AitherZero.

## Project Overview

AitherZero is an infrastructure automation platform with a **number-based orchestration system** (0000-9999) for systematic script execution. The architecture uses a consolidated domain-based module system that loads through a single entry point.

## Essential Architecture Understanding

### Core Module Loading Flow
```
AitherZero.psd1 (Module Manifest)
    └── AitherZero.psm1 (Root Module)
        ├── Sets $env:AITHERZERO_ROOT and $env:AITHERZERO_INITIALIZED
        ├── Starts transcript logging (logs/transcript-*.log)
        ├── Loads critical modules first: Logging, Configuration
        └── Sequentially loads domain modules: experience → development → testing → reporting → automation → infrastructure
```

**Critical**: Always run `./Initialize-AitherEnvironment.ps1` first in new sessions - it loads the module manifest and sets up the environment.

### Number-Based Orchestration System

Scripts in `/automation-scripts/` follow numeric ranges:
- **0000-0099**: Environment prep (PowerShell 7, directories)
- **0100-0199**: Infrastructure (Hyper-V, certificates, networking)  
- **0200-0299**: Dev tools (Git, Node, Python, Docker, VS Code)
- **0400-0499**: Testing & validation
- **0500-0599**: Reporting & metrics
- **0700-0799**: Git automation & AI tools
- **9000-9999**: Maintenance & cleanup

Use the `az` wrapper for script execution: `az 0402` runs unit tests, `az 0404` runs PSScriptAnalyzer.

## Domain Structure (Consolidated Architecture v2.0)

Located in `/domains/` (legacy references may point to `aither-core/`):
- **infrastructure/**: Lab automation, OpenTofu/Terraform, VM management (57 functions)
- **configuration/**: Config management with environment switching (36 functions)  
- **utilities/**: Logging, maintenance, cross-platform helpers (24 functions)
- **security/**: Credentials, certificates (41 functions)
- **experience/**: UI components, menus, wizards (22 functions)
- **automation/**: Orchestration engine, workflows (16 functions)

## Critical Development Patterns

### Module Scope Issues
Functions in scriptblocks may lose module scope. Call directly:
```powershell
# Wrong - may fail in scriptblocks
Show-UISpinner { Write-CustomLog "Processing..." }

# Right - call functions directly  
Write-CustomLog "Processing..."
Show-UISpinner { Start-Process $command }
```

### Cross-Platform Paths
Always check platform variables:
```powershell
$path = if ($IsWindows) { 'C:/temp' } else { "$HOME/.aitherzero/temp" }
```

### Logging Pattern
Check for command availability:
```powershell
if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
    Write-CustomLog -Message "..." -Level 'Information'
} else {
    Write-Verbose "..."
}
```

## Key Commands & Workflows

### Essential Commands
```powershell
# Environment setup (always first)
./Initialize-AitherEnvironment.ps1

# Main interactive entry
./Start-AitherZero.ps1

# Run numbered scripts
az 0402              # Unit tests
az 0404              # PSScriptAnalyzer  
az 0407              # Syntax validation
az 0510 -ShowAll     # Project report

# Git workflow automation
az 0701 -Type feature -Name "my-feature"     # Create branch
az 0702 -Type feat -Message "add feature"    # Commit
az 0703 -Title "Add feature"                 # PR creation
```

### Testing Commands
```powershell
# Run specific test
Invoke-Pester -Path "./tests/unit/Configuration.Tests.ps1" -Output Detailed

# Domain tests with coverage
Invoke-Pester -Path "./tests/domains/configuration" -CodeCoverage "./domains/configuration/*.psm1"

# All tests
Invoke-Pester -Path "./tests"
```

### Orchestration & Playbooks
```powershell
# Run playbook sequences
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick   # Fast validation
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-full    # Complete tests

# Direct sequence execution  
Invoke-OrchestrationSequence -Sequence "0000-0099" -Configuration $Config
```

## Configuration System

Hierarchical config loading:
1. Default values in code
2. `/config.json` file  
3. Playbook variables
4. Command-line parameters

Key sections:
- `Core.Profile`: Minimal, Standard, Developer, Full
- `Automation.MaxConcurrency`: Parallel execution limit  
- `Testing.Profile`: Quick, Standard, Full, CI

## Common Issues & Solutions

### Module Loading Errors
- Ensure `Logging.psm1` loads first (other modules depend on Write-CustomLog)
- `BetterMenu.psm1` must load before `UserInterface.psm1`
- Functions must be in `Export-ModuleMember` lists

### Parameter Errors
- Variables in playbooks shouldn't be script parameters unless accepted
- Use approved PowerShell verbs (`Get-Verb` to check)
- Initialize timing variables before try blocks

### UI Component Issues
- `Write-UIText` requires `[AllowEmptyString()]` for empty messages
- `Show-UIMenu` doesn't have `-UseInteractive` parameter (legacy)

## File Locations to Know

- **Main entry**: `/Start-AitherZero.ps1`
- **Environment setup**: `/Initialize-AitherEnvironment.ps1` 
- **Module manifest**: `/AitherZero.psd1`
- **Scripts**: `/automation-scripts/` (numbered 0000-9999)
- **Config**: `/config.json`
- **Tests**: `/tests/` (organized by domain)
- **Playbooks**: `/orchestration/playbooks/`

## Platform Differences

Use platform checks for Windows-specific features:
- Hyper-V: Windows only
- WSL2: Windows only  
- Certificate Authority: Windows only
- All other tools: Cross-platform (PowerShell 7+)

Check exit codes: 0=success, 1=error, 3010=restart required

## Before Making Changes

1. Run `./Initialize-AitherEnvironment.ps1` 
2. Validate with `az 0404` (PSScriptAnalyzer)
3. Test with appropriate domain tests
4. Check transcript logs in `logs/transcript-*.log` for errors

## Acceptance Criteria

All code changes must meet these requirements:
- **Tests**: All existing tests must pass. Add new tests for new functionality.
- **Linting**: Code must pass PSScriptAnalyzer validation (`az 0404`)
- **Syntax**: PowerShell syntax must be valid (`az 0407`)
- **Documentation**: Update relevant documentation for public API changes
- **Module Exports**: New functions must be added to `Export-ModuleMember` lists
- **Logging**: Use `Write-CustomLog` for all log messages (with error handling)
- **Cross-Platform**: Verify compatibility on Windows, Linux, and macOS where applicable
- **No Breaking Changes**: Maintain backward compatibility unless explicitly required

## Security and Privacy Guidelines

### Sensitive Data Handling
- **Never commit secrets**: No API keys, passwords, tokens, or credentials in code
- **Use credential management**: Leverage the `security/` domain for secure credential storage
- **Certificate handling**: All certificate operations must use the certificate management domain
- **Environment variables**: Use `.env` files (excluded from git) for sensitive configuration

### Code Security
- **Input validation**: Validate all external inputs and user-provided parameters
- **Error messages**: Don't expose sensitive information in error messages or logs
- **File permissions**: Set appropriate permissions on generated files (especially credentials)
- **Audit logging**: Security-related operations should be logged to transcript files

### Infrastructure Security
- **Network isolation**: Lab VMs should be on isolated networks by default
- **Admin rights**: Minimize operations requiring elevated privileges
- **Resource cleanup**: Always clean up resources (VMs, certificates) when no longer needed

## Communication Guidelines

### Working with Issues
- Read issue descriptions carefully and understand requirements before starting
- Ask clarifying questions if requirements are ambiguous
- Break down large tasks into smaller, manageable steps
- Report progress frequently with clear status updates

### Pull Request Standards
- Keep PRs focused on a single issue or feature
- Write clear, descriptive commit messages following conventional commits format
- Include test results and validation steps in PR description
- Reference the issue number in commit messages and PR description

### Code Review Expectations
- Address all review comments or explain why changes weren't made
- Run full test suite before marking PR as ready for review
- Update documentation to reflect code changes
- Ensure CI/CD pipelines pass before requesting review

## Task Workflow Guidelines

### Planning Phase
1. **Understand**: Read and comprehend the full issue/task
2. **Research**: Review related code, tests, and documentation
3. **Plan**: Outline approach and identify affected components
4. **Validate**: Confirm plan addresses all requirements

### Implementation Phase
1. **Small Changes**: Make minimal, focused changes to accomplish the goal
2. **Test Often**: Run tests after each significant change
3. **Validate Early**: Use linting and syntax checking frequently
4. **Document**: Update comments and docs as you code

### Verification Phase
1. **Self-Review**: Review your own changes for quality and completeness
2. **Test Coverage**: Verify all code paths have test coverage
3. **Integration**: Test with related components and workflows
4. **Documentation**: Ensure all docs are updated and accurate

### Completion Phase
1. **Final Tests**: Run complete test suite including PSScriptAnalyzer
2. **Clean Code**: Remove debug code, commented code, and temporary files
3. **PR Description**: Write comprehensive description of changes and testing
4. **Handoff**: Ensure reviewer has all context needed

This consolidated architecture ensures reliable module loading and provides powerful orchestration capabilities through the number-based system.

## GitHub Copilot Integration

AitherZero includes comprehensive GitHub Copilot enhancement features to make AI-assisted development more effective.

### Custom Agent Routing

The repository uses `.github/copilot.yaml` to route work to specialized agents based on expertise:

- **Maya** (Infrastructure): Hyper-V, OpenTofu/Terraform, networking, VM management
- **Sarah** (Security): Certificates, credentials, compliance, vulnerability scanning
- **Jessica** (Testing): Pester, test automation, quality assurance
- **Emma** (Frontend/UX): Console UI, menus, wizards, user experience
- **Marcus** (Backend): PowerShell modules, APIs, performance optimization
- **Olivia** (Documentation): Technical writing, guides, documentation
- **Rachel** (PowerShell): Scripting, automation, orchestration
- **David** (Project Manager): Planning, coordination, releases

**Usage**: Agents are auto-suggested based on file patterns. Invoke manually with `/agent-name` or `@agent-name` in Copilot Chat.

### Model Context Protocol (MCP) Servers

MCP servers provide enhanced context and capabilities. Configuration in `.github/mcp-servers.json`:

- **filesystem**: Repository navigation and file operations
- **github**: Issues, PRs, repository metadata via GitHub API
- **git**: Version control operations and history
- **powershell-docs**: PowerShell best practices and documentation
- **sequential-thinking**: Complex problem-solving and planning

**Setup**: Requires Node.js 18+ and `GITHUB_TOKEN` environment variable. See [docs/COPILOT-MCP-SETUP.md](../docs/COPILOT-MCP-SETUP.md) for details.

### Development Environment

Optimized VS Code and DevContainer configurations available:

- **`.devcontainer/`**: Pre-configured development container with all tools
- **`.vscode/settings.json`**: PowerShell, Copilot, and editor settings
- **`.vscode/tasks.json`**: Common operations (test, lint, validate, report)
- **`.vscode/launch.json`**: Debug configurations for scripts and tests
- **`.vscode/extensions.json`**: Recommended extensions list

**Quick Start**: Open in VS Code and use "Reopen in Container" or install recommended extensions for local setup.

See [docs/COPILOT-DEV-ENVIRONMENT.md](../docs/COPILOT-DEV-ENVIRONMENT.md) for complete setup guide.

### Effective Copilot Usage

**Leverage agents for specialized work**:
```
/infrastructure Help design a VM network topology
@sarah Review certificate storage security
@jessica Create Pester tests for new module
```

**Use MCP servers for context**:
```
@workspace Show recent commits to testing domain
@workspace What's PowerShell best practice for error handling?
@workspace Create issue for documentation update
```

**Provide architectural context**:
```
@workspace Following AitherZero patterns, create a new utility 
function with proper logging, error handling, and cross-platform support
```

### AI Development Guidelines

When using AI assistance:

1. **Always reference architecture**: Mention number-based system, domain structure
2. **Specify quality requirements**: Logging, error handling, tests, cross-platform
3. **Use appropriate agents**: Route to specialist for better results
4. **Validate AI suggestions**: Run linters, tests, and manual verification
5. **Iterate incrementally**: Make small changes, test frequently
6. **Document decisions**: Update comments and docs for AI context
