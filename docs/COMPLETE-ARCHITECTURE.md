# Aitherium Infrastructure Automation - Complete Architecture Documentation

## 🏗️ Project Architecture Overview

The Aitherium Infrastructure Automation project is a sophisticated PowerShell-based automation framework designed for infrastructure as code (IaC) development, testing, and deployment across multiple environments and fork chains.

### 🎯 Core Design Principles

1. **Cross-Platform Compatibility**: PowerShell 7.0+ with Linux/Windows/macOS support
2. **Dynamic Repository Detection**: Works seamlessly across fork chains (AitherZero → AitherLabs → Aitherium)
3. **Modular Architecture**: Loosely coupled modules with clear responsibilities
4. **Comprehensive Testing**: Bulletproof validation with multiple testing levels
5. **Developer Experience**: Rich VS Code integration with intelligent tasks and prompts

## 📁 Project Structure

```
AitherZero/                          # Development Fork (Your Workspace)
├── aither-core/                     # 🧠 Core Framework
│   ├── shared/                      # 🔧 Shared Utilities (NEW!)
│   │   ├── Find-ProjectRoot.ps1     # Universal project root detection
│   │   └── README.md                # Shared utilities documentation
│   ├── modules/                     # 📦 PowerShell Modules
│   │   ├── BackupManager/           # File backup and cleanup
│   │   ├── DevEnvironment/          # Development environment setup
│   │   ├── LabRunner/               # Lab automation orchestration
│   │   ├── Logging/                 # Centralized logging system
│   │   ├── ParallelExecution/       # Runspace-based parallel tasks
│   │   ├── PatchManager/            # 🎯 Git workflow automation (v2.1)
│   │   ├── ScriptManager/           # Script repository management
│   │   ├── TestingFramework/        # Pester test coordination
│   │   └── UnifiedMaintenance/      # Maintenance operations
│   ├── scripts/                     # 🛠️ Automation Scripts
│   └── core-runner.ps1              # Main entry point
├── tests/                           # 🧪 Comprehensive Test Suite
│   ├── unit/                        # Unit tests for all modules/scripts
│   ├── integration/                 # Cross-module integration tests
│   ├── config/                      # Pester configuration
│   └── Run-BulletproofValidation.ps1 # Master test runner
├── configs/                         # ⚙️ Configuration Files
│   ├── dynamic-repo-config.json    # Auto-generated repository config
│   └── *.json                      # Environment-specific configs
├── opentofu/                        # 🏗️ Infrastructure as Code
│   ├── infrastructure/              # Main Terraform/OpenTofu modules
│   └── examples/                    # Example configurations
├── docs/                           # 📚 Documentation
├── .vscode/                        # 🎨 VS Code Integration
│   ├── tasks.json                  # Rich task definitions
│   ├── settings.json               # Workspace settings
│   └── launch.json                 # Debug configurations
└── .github/                        # 🤖 GitHub Integration
    ├── copilot-instructions.md     # Main Copilot guidance
    ├── instructions/               # Detailed instruction files
    └── prompts/                    # Specialized prompts
```

## 🔄 Fork Chain Architecture

### Repository Flow
```
🔨 AitherZero (Development)    →    🌐 AitherLabs (Public)    →    💎 Aitherium (Premium)
   wizzense/AitherZero              Aitherium/AitherLabs           Aitherium/Aitherium
   Your development fork            Public staging repository      Premium/enterprise features
```

### Dynamic Repository Detection
All modules automatically detect the current repository context:

```powershell
# Automatic detection in any module
$repoInfo = Get-GitRepositoryInfo
# Returns: Owner, Name, Type, ForkChain, Remotes, etc.

# Cross-fork operations work automatically
Invoke-PatchWorkflow -Description "Fix across forks" -TargetFork "upstream" -CreatePR
```

## 🧩 Module Architecture Deep Dive

### Core Module Pattern
Every module follows this standardized pattern:

```
ModuleName/
├── ModuleName.psd1              # Module manifest
├── ModuleName.psm1              # Main module file
├── Public/                      # Public functions (exported)
│   ├── Main-Function.ps1
│   └── Helper-Function.ps1
├── Private/                     # Internal functions
│   ├── Internal-Function.ps1
│   └── Utility-Function.ps1
├── Tests/                       # Module-specific tests
└── README.md                    # Module documentation
```

### Shared Utilities System (NEW!)
Located in `aither-core/shared/`, provides common functionality:

```powershell
# Import in any module/script
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Usage patterns for different locations:
# From modules: . "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
# From tests:  . "$PSScriptRoot/../../../aither-core/shared/Find-ProjectRoot.ps1"
# From core:   . "$PSScriptRoot/shared/Find-ProjectRoot.ps1"
```

## 🎯 PatchManager v2.1 - The Heart of Git Automation

### Core Functions (Only 4!)
1. **`Invoke-PatchWorkflow`** - Main entry point for ALL operations
2. **`New-PatchIssue`** - Create GitHub issues
3. **`New-PatchPR`** - Create pull requests
4. **`Invoke-PatchRollback`** - Rollback operations

### Revolutionary Features in v2.1

#### 🔄 Automatic Dirty Working Tree Handling
```powershell
# OLD: Required clean working tree (would fail)
git add .; git commit -m "Manual save"
Invoke-PatchWorkflow...

# NEW: Handles ANY state automatically
Invoke-PatchWorkflow -Description "Fix bug" -PatchOperation {
    # Your changes here - works with dirty tree!
}
# ✅ Auto-commits existing changes, creates branch, applies fix
```

#### 🎫 Issue Creation by Default
```powershell
# Issues created automatically for tracking
Invoke-PatchWorkflow -Description "Add feature" -PatchOperation { ... }
# ✅ Creates issue, branch, applies changes, all tracked

# Disable only if needed
Invoke-PatchWorkflow -Description "Quick fix" -CreateIssue:$false -PatchOperation { ... }
```

#### 🌉 Cross-Fork PR/Issue Creation
```powershell
# Automatically detects and targets correct repository
Invoke-PatchWorkflow -Description "Feature for upstream" -TargetFork "upstream" -CreatePR -PatchOperation {
    # Changes here
}
# ✅ Creates issue in AitherLabs, PR from AitherZero → AitherLabs
```

### Complete Usage Examples

#### 1. Quick Development Fix (Most Common)
```powershell
# Single command handles everything
Invoke-PatchWorkflow -PatchDescription "Fix module loading bug" -PatchOperation {
    $content = Get-Content "module.ps1" -Raw
    $content = $content -replace "Import-Module", "Import-Module -Force"
    Set-Content "module.ps1" -Value $content
}
# Result: Auto-commits pending changes → creates branch → creates issue → applies fix → commits
```

#### 2. Feature Development with Full Tracking
```powershell
Invoke-PatchWorkflow -PatchDescription "Add configuration validation" -PatchOperation {
    Add-Content "validators.ps1" -Value "function Test-Config { ... }"
} -CreatePR -TestCommands @("pwsh -File tests/validators.tests.ps1")
# Result: Issue + branch + changes + tests + PR, all linked
```

#### 3. Cross-Fork Contribution
```powershell
Invoke-PatchWorkflow -PatchDescription "Security improvement for upstream" -TargetFork "upstream" -PatchOperation {
    # Security enhancement
    Update-SecurityModule
} -CreatePR -Priority "High"
# Result: Issue in AitherLabs, PR from AitherZero → AitherLabs
```

#### 4. Emergency Hotfix
```powershell
Invoke-PatchWorkflow -PatchDescription "Critical auth vulnerability fix" -PatchOperation {
    Update-AuthModule -SecurityPatch
} -CreatePR -Priority "Critical" -TargetFork "root"
# Result: High-priority issue + PR to Aitherium/Aitherium for immediate attention
```

## 🧪 Testing Architecture

### Multi-Level Testing Strategy

1. **Unit Tests** - Individual function validation
2. **Integration Tests** - Cross-module interactions
3. **Bulletproof Validation** - End-to-end workflows
4. **Performance Tests** - Load and stress testing
5. **Cross-Platform Tests** - Windows/Linux/macOS compatibility

### Bulletproof Validation System
```powershell
# Quick validation (30 seconds)
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick"

# Standard validation (2-5 minutes)
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Standard"

# Complete validation (10-15 minutes)
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Complete"

# CI/CD optimized
pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Standard" -CI -FailFast
```

### Test Categories
- **PatchManager Tests**: Cross-fork operations, Git workflows, issue/PR creation
- **Module Tests**: Individual module functionality and integration
- **Script Tests**: Automation script validation and parameter testing
- **Infrastructure Tests**: OpenTofu/Terraform validation
- **Performance Tests**: Parallel execution and resource usage

## 🎨 VS Code Integration

### Intelligent Task System
Over 30 pre-configured tasks for common operations:

```json
{
  "🚀 Bulletproof Validation - Quick": "Fast validation suite",
  "🔧 PatchManager: Create Feature Patch": "Interactive patch creation",
  "⚡ Tests: Intelligent Test Discovery": "Smart test execution",
  "🎯 CoreRunner: Auto Mode with WhatIf": "Safe automation preview"
}
```

### Task Categories
- **🚀 Bulletproof Validation**: Various test levels and configurations
- **🔧 PatchManager Operations**: All patch workflows and rollbacks
- **⚡ Testing Operations**: Test discovery, execution, and reporting
- **🎯 CoreRunner**: Automation execution and environment setup
- **🧹 Maintenance**: Cleanup, validation, and housekeeping

### Usage Patterns
```
Ctrl+Shift+P → Tasks: Run Task → "🚀 Bulletproof Validation - Quick"
Ctrl+Shift+P → Tasks: Run Task → "🔧 PatchManager: Create Feature Patch"
Ctrl+Shift+P → Tasks: Run Task → "⚡ Tests: Intelligent Test Discovery"
```

## 🤖 GitHub Copilot Integration

### Layered Instruction System
1. **Main Instructions** (`.github/copilot-instructions.md`) - Core standards and patterns
2. **Module Guidelines** (`instructions/modules.instructions.md`) - Module usage and imports
3. **Testing Workflows** (`instructions/testing-workflows.instructions.md`) - Test patterns
4. **PatchManager Workflows** (`instructions/patchmanager-workflows.instructions.md`) - Git automation

### Specialized Prompts
- **PowerShell Development** - Module creation and best practices
- **Infrastructure Code** - OpenTofu/Terraform guidance
- **Testing Scenarios** - Comprehensive test generation
- **Troubleshooting** - Error diagnosis and resolution

### Code Generation Patterns
```powershell
# Copilot automatically follows project patterns:

# ✅ Correct module import
Import-Module './aither-core/modules/PatchManager' -Force

# ✅ Proper error handling with logging
try {
    # Operation
    Write-CustomLog -Level 'INFO' -Message "Operation started"
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Error: $($_.Exception.Message)"
    throw
}

# ✅ Cross-platform path handling
Join-Path $projectRoot "aither-core/modules"

# ✅ Shared utility usage
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
```

## 🔧 Configuration Management

### Dynamic Configuration System
All configurations are automatically updated based on repository context:

```json
// configs/dynamic-repo-config.json (auto-generated)
{
  "currentRepository": {
    "owner": "wizzense",
    "name": "AitherZero",
    "type": "Development",
    "githubRepo": "wizzense/AitherZero"
  },
  "forkChain": [
    {
      "name": "origin",
      "repo": "wizzense/AitherZero",
      "type": "Development"
    },
    {
      "name": "upstream",
      "repo": "Aitherium/AitherLabs",
      "type": "Public"
    },
    {
      "name": "root",
      "repo": "Aitherium/Aitherium",
      "type": "Premium"
    }
  ]
}
```

### Repository-Specific Updates
```powershell
# Update all documentation and configs for current repo
Update-RepositoryDocumentation -DryRun  # Preview changes
Update-RepositoryDocumentation          # Apply updates

# Results:
# - README.md updated with correct clone URLs
# - Quick start instructions match current repository
# - Configuration files use correct repository references
# - Dynamic config file generated/updated
```

## 🚀 Development Workflows

### Standard Development Cycle
1. **Clone and Setup**
   ```bash
   git clone https://github.com/wizzense/AitherZero.git
   cd AitherZero
   pwsh -File "core-runner/setup-test-env.ps1"
   ```

2. **Feature Development**
   ```powershell
   # Create feature with full tracking
   Invoke-PatchWorkflow -Description "New feature" -PatchOperation {
       # Implementation
   } -CreatePR -TestCommands @("tests/feature.tests.ps1")
   ```

3. **Testing and Validation**
   ```powershell
   # Quick validation
   pwsh -File "tests/Run-BulletproofValidation.ps1" -ValidationLevel "Quick"

   # Module-specific tests
   Invoke-Pester -Path "tests/unit/modules/MyModule"
   ```

4. **Cross-Fork Contribution**
   ```powershell
   # Contribute to upstream
   Invoke-PatchWorkflow -Description "Improvement for upstream" -TargetFork "upstream" -CreatePR -PatchOperation {
       # Changes for upstream repository
   }
   ```

### Emergency Procedures
```powershell
# Emergency rollback
Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup

# Emergency fix
Invoke-PatchWorkflow -Description "Critical fix" -Priority "Critical" -CreatePR -PatchOperation {
    # Critical fix
}
```

## 📊 Performance and Monitoring

### Parallel Execution
```powershell
# Built-in parallel processing
Import-Module './aither-core/modules/ParallelExecution' -Force
Invoke-ParallelOperation -Operations $operationList -MaxParallelJobs 4
```

### Logging and Monitoring
```powershell
# Centralized logging system
Import-Module './aither-core/modules/Logging' -Force
Write-CustomLog -Level 'INFO' -Message "Operation started"
Write-CustomLog -Level 'ERROR' -Message "Error occurred"
```

### Log File Locations
- `logs/patchmanager-operations-{date}.log` - PatchManager operations
- `logs/automated-error-tracking.json` - Error tracking database
- `logs/bulletproof-validation/` - Test execution logs

## 🔐 Security and Best Practices

### Credential Management
- Never hardcode credentials in source code
- Use secure strings and credential objects
- Leverage environment variables for sensitive data
- Follow principle of least privilege

### Input Validation
- Validate all user inputs and external data
- Use parameter validation attributes
- Implement comprehensive error handling
- Audit log all significant operations

### Code Quality
- PSScriptAnalyzer integration
- Comprehensive test coverage
- Consistent coding standards (OTBS)
- Regular security reviews

## 🌟 Key Innovations

### 1. Universal Project Root Detection
- Works from any directory within project
- Multiple fallback strategies
- Cross-platform compatible
- Cached for performance

### 2. Dynamic Repository Awareness
- Automatic fork chain detection
- Context-aware operations
- Cross-fork PR/issue creation
- Repository-specific configurations

### 3. Bulletproof Testing Framework
- Multiple validation levels
- Intelligent test discovery
- Performance monitoring
- CI/CD optimized

### 4. Rich Developer Experience
- 30+ VS Code tasks
- GitHub Copilot integration
- Intelligent error handling
- Comprehensive documentation

## 🎯 Best Practices Summary

1. **Always use shared utilities** for common operations like project root detection
2. **Import modules with -Force** to ensure latest versions
3. **Use cross-platform paths** with forward slashes and Join-Path
4. **Implement comprehensive error handling** with logging
5. **Follow module patterns** for consistency and maintainability
6. **Use PatchManager workflows** for all Git operations
7. **Run bulletproof validation** before major changes
8. **Leverage VS Code tasks** for common operations
9. **Keep configurations dynamic** using repository detection
10. **Document everything** for team collaboration

---

*This architecture enables seamless development across the entire fork chain while maintaining consistency, quality, and developer productivity.*
