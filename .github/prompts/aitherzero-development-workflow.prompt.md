# AitherZero Development Workflow Prompt

You are assisting with the AitherZero Infrastructure Automation project, a PowerShell-based framework for lab environments using OpenTofu/Terraform.

## Key Context

**Project Type**: PowerShell 7.0+ infrastructure automation framework
**Architecture**: Modular design with 16+ specialized modules
**Testing**: Bulletproof validation system with three levels (Quick/Standard/Complete)
**Git Workflow**: PatchManager v2.1 with automated workflows
**Platform**: Cross-platform (Windows/Linux/macOS) with Windows primary development

## Current Module Ecosystem

When suggesting solutions, prioritize these existing modules:

### Core Infrastructure

- **LabRunner**: Main orchestration engine for automation workflows
- **Logging**: Centralized logging with DEBUG/INFO/WARN/ERROR/SUCCESS levels
- **DevEnvironment**: Development environment setup and validation
- **UnifiedMaintenance**: Entry point for maintenance operations

### Enterprise Features

- **SecureCredentials**: Enterprise credential management
- **RemoteConnection**: Secure remote connection management
- **ISOManager**: Enterprise ISO download and management
- **ISOCustomizer**: ISO customization with autounattend generation
- **OpenTofuProvider**: OpenTofu/Terraform provider integration

### Development Tools

- **PatchManager**: Git workflow automation (4 core functions only)
- **TestingFramework**: Bulletproof testing wrapper
- **ScriptManager**: Script templates and management
- **ParallelExecution**: Runspace-based parallel processing
- **BackupManager**: File backup and cleanup operations
- **RepoSync**: Cross-fork repository synchronization

## Recommended Workflows

### For Bug Fixes

```powershell
# Use PatchManager single-step workflow
Invoke-PatchWorkflow -PatchDescription "Fix [clear description]" -PatchOperation {
    # Your fix here
} -CreatePR -TestCommands @("pwsh -File tests/Run-BulletproofValidation.ps1 -ValidationLevel Quick")
```

### For Feature Development

```powershell
# Include comprehensive testing
Invoke-PatchWorkflow -PatchDescription "Add [feature description]" -PatchOperation {
    # Feature implementation
} -CreatePR -TestCommands @(
    "pwsh -File tests/Run-BulletproofValidation.ps1 -ValidationLevel Standard",
    "Import-Module '$env:PWSH_MODULES_PATH/NewModule' -Force"
)
```

### For Testing

```powershell
# Always use bulletproof validation
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick"    # 30 seconds
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Standard" # 2-5 minutes
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Complete" # 10-15 minutes
```

## Code Standards

### Module Import Pattern

```powershell
# Always use environment variable for module paths
Import-Module "$env:PWSH_MODULES_PATH/ModuleName" -Force
```

### Path Construction

```powershell
# Always use Join-Path for cross-platform compatibility
$configPath = Join-Path $env:PROJECT_ROOT "configs/default.json"
$modulePath = Join-Path $env:PWSH_MODULES_PATH "LabRunner"
```

### Error Handling

```powershell
try {
    # Operation
    Write-CustomLog -Level 'INFO' -Message "Operation started"
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Error: $($_.Exception.Message)"
    throw
}
```

### Function Structure

```powershell
function Verb-Noun {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RequiredParam
    )
    
    begin {
        Write-CustomLog -Level 'DEBUG' -Message "Starting $($MyInvocation.MyCommand.Name)"
    }
    
    process {
        try {
            if ($PSCmdlet.ShouldProcess($RequiredParam, "Verb-Noun")) {
                # Implementation
            }
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Error in $($MyInvocation.MyCommand.Name): $($_.Exception.Message)"
            throw
        }
    }
    
    end {
        Write-CustomLog -Level 'DEBUG' -Message "Completed $($MyInvocation.MyCommand.Name)"
    }
}
```

## VS Code Integration

### Available Tasks (Use Ctrl+Shift+P → Tasks: Run Task)

- **🚀 Bulletproof Validation - Quick**: 30-second validation
- **🔥 Bulletproof Validation - Standard**: 2-5 minute comprehensive validation
- **🎯 Bulletproof Validation - Complete**: 10-15 minute full validation
- **PatchManager: Create Feature Patch**: Guided patch creation
- **🔧 Development: Setup Complete Environment**: Full dev setup
- **📦 Local Build: Create Windows Package**: Build local release package
- **🏗️ Architecture: Validate Complete System**: System validation

### Testing Tasks

- **Tests: Run Bulletproof Validation**: Configurable validation levels
- **Tests: Run Non-Interactive Validation**: Core runner testing
- **Tests: Intelligent Test Discovery**: Smart test selection

## Common Scenarios

### Module Development

1. Create module structure following standardized pattern
2. Use shared utilities from `aither-core/shared/`
3. Import existing modules rather than reimplementing
4. Add comprehensive Pester tests
5. Use PatchManager for Git workflow

### Bug Investigation

1. Use bulletproof validation to identify scope
2. Check logs in `logs/` directory
3. Use VS Code debugging tasks
4. Test with non-interactive mode validation

### Release Preparation

1. Run complete bulletproof validation
2. Use local build tasks to create packages
3. Validate cross-platform compatibility
4. Use PatchManager for release workflow

## Cross-Platform Considerations

- Always use `Join-Path` for file paths
- Test on Windows (primary) and Linux/macOS when possible
- Use PowerShell 7.0+ features consistently
- Avoid platform-specific commands without fallbacks
- Use `$IsWindows`, `$IsLinux`, `$IsMacOS` for platform detection

## Security Guidelines

- Never hardcode credentials or secrets
- Use SecureCredentials module for credential management
- Validate all user inputs
- Log security-relevant operations
- Follow principle of least privilege

Remember: This project prioritizes reliability, cross-platform compatibility, and automated testing. Always suggest solutions that integrate with existing modules and follow established patterns.
