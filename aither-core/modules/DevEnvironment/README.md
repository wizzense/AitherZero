# DevEnvironment Module

## Test Status
- **Last Run**: 2025-07-08 17:29:43 UTC
- **Status**: ✅ PASSING (10/10 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 10/10 | 0% | 1s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 0.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ❌ PASS | 0/0 | 0% | N/A |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Module Overview

The DevEnvironment module provides comprehensive development environment setup and management for AitherZero. It automates the installation
and configuration of development tools, VS Code extensions, Git hooks, and workspace settings to ensure a consistent and productive
development experience across all team members.

### Primary Purpose and Functionality
- Automated development environment initialization and setup
- VS Code workspace and extension management
- Git pre-commit hook installation and configuration
- Development tool dependency management
- Environment health monitoring and status reporting
- Integration with AI development tools and Claude Code dependencies

### Key Features and Capabilities
- **One-Command Setup**: Initialize complete development environment
- **VS Code Integration**: Automated workspace file creation and extension installation
- **Git Hook Management**: Pre-commit hooks for code quality and security
- **Dependency Resolution**: Automatic installation of required development tools
- **Health Monitoring**: Environment status checking and issue resolution
- **Cross-Platform Support**: Works on Windows, Linux, and macOS
- **AI Tools Integration**: Setup for Claude Code and other AI development tools

### Integration Points with Other Modules
- **AIToolsIntegration Module**: Installs and configures AI development tools
- **Logging Module**: Provides centralized logging for all setup operations
- **SetupWizard Module**: Integrates with installation profiles and first-time setup
- **PatchManager Module**: Configures Git workflows and repository management
- **All Core Modules**: Ensures proper development environment for module development

## Directory Structure

```
DevEnvironment/
├── DevEnvironment.psd1              # Module manifest
├── DevEnvironment.psm1              # Main module loader
├── README.md                        # This documentation
└── Public/                          # Public functions directory
    ├── Get-DevEnvironmentStatus.ps1           # Environment status checking
    ├── Initialize-DevEnvironment.ps1          # Main environment initialization
    ├── Initialize-DevelopmentEnvironment.ps1  # Legacy initialization function
    ├── Initialize-VSCodeWorkspace.ps1         # VS Code workspace setup
    ├── Install-ClaudeCodeDependencies.ps1     # Claude Code requirements
    ├── Install-ClaudeRequirementsSystem.ps1   # Claude system requirements
    ├── Install-CodexCLIDependencies.ps1       # Codex CLI dependencies
    ├── Install-GeminiCLIDependencies.ps1      # Gemini CLI dependencies
    ├── Install-PreCommitHook.ps1              # Git pre-commit hook setup
    ├── Install-VSCodeExtensions.ps1           # VS Code extension management
    ├── New-VSCodeWorkspaceFile.ps1            # Workspace file creation
    ├── Resolve-ModuleImportIssues.ps1         # Module import troubleshooting
    ├── Test-VSCodeIntegration.ps1             # VS Code integration testing
    └── Update-VSCodeSettings.ps1              # VS Code settings management
```

### Function Organization
- **Public/**: All exported functions available to users
- **Private/**: Internal helper functions (directory exists but may be empty)
- **Module Loader**: Automatically imports all public functions

## Key Functions

### Initialize-DevEnvironment
Main function for setting up the development environment.

**Parameters:**
- `-ConfigurationPath` [string]: Path to configuration files
- `-Force` [switch]: Force re-initialization even if already configured

**Returns:** Hashtable with Status, Message, and Initialized properties

**Example:**
```powershell
# Basic initialization
Initialize-DevEnvironment

# Force re-initialization with custom config
Initialize-DevEnvironment -ConfigurationPath "./my-dev-config" -Force

# With confirmation prompts
Initialize-DevEnvironment -WhatIf
```

### Get-DevEnvironmentStatus
Retrieves comprehensive status information about the development environment.

**Parameters:**
- `-IncludeMetrics` [switch]: Include performance and usage metrics

**Returns:** Hashtable with Timestamp, Environment, Modules, and Health information

**Example:**
```powershell
# Get basic status
$status = Get-DevEnvironmentStatus
Write-Host "PowerShell Version: $($status.Environment.PowerShellVersion)"
Write-Host "Loaded Modules: $($status.Modules.Loaded.Count)"

# Get detailed metrics
$detailedStatus = Get-DevEnvironmentStatus -IncludeMetrics
$detailedStatus.Environment | Format-Table

# Check health status
if ($status.Health -ne 'Healthy') {
    Write-Warning "Development environment needs attention"
}
```

### Initialize-VSCodeWorkspace
Sets up VS Code workspace configuration for AitherZero development.

**Parameters:**
- Various workspace configuration parameters

**Example:**
```powershell
# Initialize VS Code workspace
Initialize-VSCodeWorkspace

# Creates .vscode/ directory with:
# - workspace settings
# - recommended extensions
# - task configurations
# - debug configurations
```

### Install-VSCodeExtensions
Installs recommended VS Code extensions for AitherZero development.

**Parameters:**
- Extension installation parameters

**Example:**
```powershell
# Install all recommended extensions
Install-VSCodeExtensions

# Extensions typically include:
# - PowerShell extension
# - GitLens
# - Prettier
# - JSON tools
# - Markdown tools
```

### Install-PreCommitHook
Installs Git pre-commit hooks for code quality and security.

**Parameters:**
- Git hook configuration parameters

**Example:**
```powershell
# Install pre-commit hooks
Install-PreCommitHook

# Hooks typically include:
# - PowerShell script analysis
# - JSON validation
# - Markdown linting
# - Security scanning
```

### Install-ClaudeCodeDependencies
Installs dependencies required for Claude Code integration.

**Parameters:**
- Claude Code specific configuration parameters

**Example:**
```powershell
# Install Claude Code dependencies
Install-ClaudeCodeDependencies

# Installs and configures:
# - Node.js and npm (if needed)
# - Claude Code CLI
# - Integration settings
```

### Install-GeminiCLIDependencies
Installs dependencies for Google Gemini CLI integration.

**Parameters:**
- Gemini CLI specific parameters

**Example:**
```powershell
# Install Gemini CLI dependencies
Install-GeminiCLIDependencies

# Platform-specific installation
# Configuration for API access
```

### New-VSCodeWorkspaceFile
Creates a VS Code workspace file with AitherZero-specific settings.

**Parameters:**
- Workspace file configuration parameters

**Example:**
```powershell
# Create workspace file
New-VSCodeWorkspaceFile

# Generates .vscode/aitherzero.code-workspace with:
# - Folder configurations
# - Settings
# - Extensions
# - Tasks
```

### Test-VSCodeIntegration
Tests VS Code integration and identifies any issues.

**Parameters:**
- Integration test parameters

**Example:**
```powershell
# Test VS Code integration
$testResult = Test-VSCodeIntegration

if ($testResult.Success) {
    Write-Host "VS Code integration is working correctly"
} else {
    Write-Warning "VS Code integration issues found: $($testResult.Issues -join ', ')"
}
```

### Resolve-ModuleImportIssues
Diagnoses and resolves common module import problems.

**Parameters:**
- Module resolution parameters

**Example:**
```powershell
# Resolve import issues
Resolve-ModuleImportIssues

# Common fixes:
# - PowerShell execution policy
# - Module path configuration
# - Permission issues
# - Dependency conflicts
```

### Update-VSCodeSettings
Updates VS Code settings for optimal AitherZero development.

**Parameters:**
- Settings update parameters

**Example:**
```powershell
# Update VS Code settings
Update-VSCodeSettings

# Updates settings.json with:
# - PowerShell configuration
# - File associations
# - Formatter settings
# - Git integration
```

## Configuration

### Development Environment Requirements
- **PowerShell 7.0+**: Core requirement for all AitherZero development
- **Git**: Version control and repository management
- **VS Code**: Recommended editor with extensive integration
- **Node.js**: Required for AI tools and some extensions

### Default VS Code Extensions
```json
{
    "recommendations": [
        "ms-vscode.powershell",
        "eamodio.gitlens",
        "esbenp.prettier-vscode",
        "ms-vscode.vscode-json",
        "yzhang.markdown-all-in-one",
        "streetsidesoftware.code-spell-checker"
    ]
}
```

### Pre-Commit Hook Configuration
```bash
#!/bin/sh
# AitherZero pre-commit hook
echo "Running AitherZero pre-commit checks..."

# PowerShell script analysis
pwsh -NoProfile -Command "Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning"

# JSON validation
find . -name "*.json" -not -path "./.git/*" | xargs -I {} sh -c 'cat {} | jq empty'

# Exit with appropriate code
exit $?
```

### Workspace Settings
```json
{
    "powershell.codeFormatting.preset": "OTBS",
    "powershell.scriptAnalysis.enable": true,
    "files.eol": "\n",
    "editor.insertSpaces": true,
    "editor.tabSize": 4,
    "git.enableSmartCommit": true,
    "git.confirmSync": false
}
```

## Usage Examples

### Complete Development Environment Setup
```powershell
# Import the module
Import-Module ./aither-core/modules/DevEnvironment -Force

# Initialize complete development environment
Initialize-DevEnvironment -Force

# This will:
# 1. Check PowerShell version and requirements
# 2. Set up VS Code workspace and extensions
# 3. Install Git pre-commit hooks
# 4. Configure development tools
# 5. Install AI tool dependencies
# 6. Validate the setup

# Check the result
$status = Get-DevEnvironmentStatus -IncludeMetrics
$status | ConvertTo-Json -Depth 3
```

### VS Code Integration Setup
```powershell
# Set up complete VS Code integration
Initialize-VSCodeWorkspace
Install-VSCodeExtensions
New-VSCodeWorkspaceFile
Update-VSCodeSettings

# Test the integration
$testResult = Test-VSCodeIntegration
if (-not $testResult.Success) {
    Write-Host "Issues found:"
    $testResult.Issues | ForEach-Object { Write-Host "  - $_" }
}
```

### AI Development Tools Setup
```powershell
# Install dependencies for AI tools
Install-ClaudeCodeDependencies
Install-GeminiCLIDependencies

# Import AI tools module for actual installation
Import-Module ./aither-core/modules/AIToolsIntegration -Force
Install-ClaudeCode
Install-GeminiCLI

# Verify AI tools are working
Get-AIToolsStatus
```

### Git Development Workflow Setup
```powershell
# Install pre-commit hooks
Install-PreCommitHook

# Test the hooks
git add .
git commit -m "Test commit to trigger hooks"

# If hooks fail, they'll prevent the commit
# Fix issues and try again
```

### Environment Health Monitoring
```powershell
# Regular health check
$status = Get-DevEnvironmentStatus
switch ($status.Health) {
    'Healthy' {
        Write-Host "✅ Development environment is healthy" -ForegroundColor Green
    }
    'Warning' {
        Write-Host "⚠️ Development environment has warnings" -ForegroundColor Yellow
    }
    'Critical' {
        Write-Host "❌ Development environment has critical issues" -ForegroundColor Red
        # Trigger remediation
        Initialize-DevEnvironment -Force
    }
}
```

### Integration with SetupWizard
```powershell
# During AitherZero setup with developer profile
./Start-AitherZero.ps1 -Setup -InstallationProfile developer

# This automatically calls DevEnvironment functions:
# - Initialize-DevEnvironment
# - Install-ClaudeCodeDependencies
# - Initialize-VSCodeWorkspace
# - Install-PreCommitHook
```

### Custom Configuration Path
```powershell
# Use custom development configuration
$customConfig = @{
    VSCodeExtensions = @(
        'ms-vscode.powershell',
        'github.copilot',
        'custom.extension'
    )
    GitHooks = @{
        PreCommit = $true
        PrePush = $true
    }
    AITools = @{
        Claude = $true
        Gemini = $false
    }
}

$customConfig | ConvertTo-Json | Set-Content "./my-dev-config.json"
Initialize-DevEnvironment -ConfigurationPath "./my-dev-config.json"
```

### Troubleshooting and Issue Resolution
```powershell
# Diagnose and fix common issues
Resolve-ModuleImportIssues

# Common issues resolved:
# - PowerShell execution policy
# - Module path problems
# - Permission issues
# - Missing dependencies

# Test specific integrations
$vsCodeTest = Test-VSCodeIntegration
$moduleTest = Test-Path "./aither-core/modules"
$gitTest = git --version

Write-Host "VS Code: $(if($vsCodeTest.Success){'✅'}else{'❌'})"
Write-Host "Modules: $(if($moduleTest){'✅'}else{'❌'})"
Write-Host "Git: $(if($gitTest){'✅'}else{'❌'})"
```

## Integration with Other Modules

### With AIToolsIntegration Module
```powershell
# DevEnvironment installs dependencies
Install-ClaudeCodeDependencies

# Then AIToolsIntegration does the actual installation
Import-Module ./aither-core/modules/AIToolsIntegration -Force
Install-ClaudeCode
```

### With SetupWizard Module
```powershell
# SetupWizard calls DevEnvironment during setup
# Different profiles enable different features:

# Minimal profile: Basic environment only
# Developer profile: Full environment + AI tools
# Full profile: Everything including advanced tools
```

### With PatchManager Module
```powershell
# DevEnvironment sets up Git hooks
# PatchManager provides Git workflow automation

# Pre-commit hooks validate code before commits
# PatchManager creates and manages patches/PRs
```

## Dependencies

### Required PowerShell Modules
- **Logging Module**: For consistent logging output (has fallback)

### External Tool Requirements
- **PowerShell 7.0+**: Core requirement for AitherZero
- **Git**: Version control operations and hooks
- **VS Code**: Development environment (optional but recommended)
- **Node.js & npm**: For AI tools and extensions

### Platform-Specific Requirements
- **Windows**:
  - Windows PowerShell 5.1+ (for some legacy operations)
  - Windows Package Manager (winget) recommended
- **macOS**:
  - Homebrew package manager
  - Xcode Command Line Tools
- **Linux**:
  - Package manager (apt, yum, etc.)
  - Build tools for native modules

### Version Requirements
- PowerShell: 7.0 or higher (specified in manifest)
- Module Version: Included with AitherZero core
- No specific licensing requirements

## Best Practices

### Environment Consistency
- Use Initialize-DevEnvironment on all development machines
- Standardize VS Code settings across team
- Use same Git hooks for all contributors
- Regular environment status checks

### Version Control Integration
- Always install pre-commit hooks
- Use consistent code formatting
- Enable script analysis for PowerShell
- Validate JSON files before commits

### AI Tools Configuration
- Install Claude Code for enhanced development
- Configure API keys securely (not in code)
- Use AI tools for code review and suggestions
- Keep AI tools updated

### Performance Optimization
- Install only necessary VS Code extensions
- Use workspace-specific settings
- Optimize Git hook performance
- Monitor environment health regularly

## Troubleshooting

### Common Issues

1. **PowerShell Execution Policy**
   ```powershell
   # Check current policy
   Get-ExecutionPolicy

   # Set for current user
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

   # Or bypass for specific session
   powershell -ExecutionPolicy Bypass
   ```

2. **VS Code Not Found**
   ```powershell
   # Check VS Code installation
   code --version

   # Add to PATH if needed (Windows)
   $env:PATH += ";C:\Users\$env:USERNAME\AppData\Local\Programs\Microsoft VS Code\bin"

   # Install VS Code if missing
   # Windows: winget install Microsoft.VisualStudioCode
   # macOS: brew install --cask visual-studio-code
   # Linux: snap install code --classic
   ```

3. **Git Hooks Not Working**
   ```powershell
   # Check Git hooks directory
   ls .git/hooks/

   # Verify hook permissions (Linux/macOS)
   chmod +x .git/hooks/pre-commit

   # Test hook manually
   ./.git/hooks/pre-commit
   ```

4. **Node.js Dependencies**
   ```powershell
   # Check Node.js and npm
   node --version
   npm --version

   # Install if missing
   # Windows: winget install OpenJS.NodeJS
   # macOS: brew install node
   # Linux: NodeSource repository or package manager
   ```

5. **Module Import Issues**
   ```powershell
   # Use built-in resolver
   Resolve-ModuleImportIssues

   # Manual checks
   $env:PSModulePath -split ';'
   Get-Module -ListAvailable
   Test-Path "./aither-core/modules/DevEnvironment"
   ```

### Debug Mode
```powershell
# Enable detailed logging
$VerbosePreference = 'Continue'
$DebugPreference = 'Continue'

# Run with full output
Initialize-DevEnvironment -Verbose -Debug

# Check individual components
Get-DevEnvironmentStatus -IncludeMetrics -Verbose
```

### Environment Validation
```powershell
# Comprehensive environment check
function Test-DevEnvironmentComplete {
    $results = @{}

    # PowerShell version
    $results.PowerShell = $PSVersionTable.PSVersion -ge [Version]'7.0'

    # Git availability
    $results.Git = $null -ne (Get-Command git -ErrorAction SilentlyContinue)

    # VS Code availability
    $results.VSCode = $null -ne (Get-Command code -ErrorAction SilentlyContinue)

    # Node.js availability
    $results.NodeJS = $null -ne (Get-Command node -ErrorAction SilentlyContinue)

    # Pre-commit hook
    $results.PreCommitHook = Test-Path ".git/hooks/pre-commit"

    # VS Code workspace
    $results.VSCodeWorkspace = Test-Path ".vscode"

    return $results
}

$envCheck = Test-DevEnvironmentComplete
$envCheck | Format-Table
```