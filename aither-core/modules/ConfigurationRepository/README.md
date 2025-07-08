# ConfigurationRepository Module

## Test Status
- **Last Run**: 2025-07-08 18:50:21 UTC
- **Status**: ✅ PASSING (49/49 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 49/49 | 0% | 3.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 6/6 | 0% | 1.3s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ❌ FAIL | 43/49 | 0% | 3.4s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.4s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ❌ FAIL | 43/49 | 0% | 3.6s |

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
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Module Overview

The ConfigurationRepository module provides Git-based configuration management for AitherZero, enabling teams to version control, share, and
synchronize their infrastructure configurations. It transforms configuration management into a collaborative, auditable, and scalable process.

### Primary Purpose and Functionality
- Creates and manages Git repositories for AitherZero configurations
- Provides templates for different configuration scenarios
- Enables configuration synchronization across teams and environments
- Validates configuration repository structure and content
- Integrates with GitHub/GitLab for remote repository management

### Key Features and Capabilities
- **Repository Creation**: Generate new configuration repositories from templates
- **Template System**: Pre-built templates for minimal, enterprise, and custom setups
- **Git Integration**: Full Git workflow support with branching and merging
- **Synchronization**: Pull/push/sync operations for configuration updates
- **Validation Framework**: Ensures repository structure compliance
- **Multi-Environment Support**: Separate configurations per environment

### Integration Points with Other Modules
- **ConfigurationCarousel Module**: Repositories can be added as configuration sets
- **PatchManager Module**: Leverages GitHub operations for repository creation
- **Logging Module**: Provides detailed operation logging
- **All Core Modules**: Configuration repositories provide settings for all modules

## Directory Structure

```
ConfigurationRepository/
├── ConfigurationRepository.psd1    # Module manifest
├── ConfigurationRepository.psm1    # Main module implementation
├── README.md                       # This documentation
└── [Created Repositories]
    └── [RepositoryName]/
        ├── .git/                   # Git repository data
        ├── .gitignore              # Git ignore rules
        ├── README.md               # Repository documentation
        ├── configs/                # Main configuration files
        │   ├── app-config.json     # Application settings
        │   └── module-config.json  # Module settings
        ├── environments/           # Environment-specific configs
        │   ├── dev/                # Development settings
        │   ├── staging/            # Staging settings
        │   └── prod/               # Production settings
        ├── templates/              # Configuration templates
        └── scripts/                # Custom automation scripts
```

## Key Functions

### New-ConfigurationRepository
Creates a new Git repository with AitherZero configuration structure.

**Parameters:**
- `-RepositoryName` [string] (Mandatory): Name for the new repository
- `-LocalPath` [string] (Mandatory): Local directory path for the repository
- `-Provider` [string]: Git provider ('github', 'gitlab', 'local') - default: 'github'
- `-Template` [string]: Template type ('default', 'minimal', 'enterprise', 'custom') - default: 'default'
- `-Private` [switch]: Create as private repository - default: $true
- `-Description` [string]: Repository description
- `-GitHubOrg` [string]: GitHub organization (if not personal repo)
- `-Environments` [string[]]: Supported environments - default: @('dev', 'staging', 'prod')
- `-CustomSettings` [hashtable]: Custom settings for the template

**Returns:** Hashtable with Success, RepositoryName, LocalPath, Template, Environments, Provider, RemoteUrl, and TemplateResult

**Example:**
```powershell
# Create a new GitHub repository
New-ConfigurationRepository -RepositoryName "company-aither-config" `
    -LocalPath "./configs/company" `
    -Description "Company-wide AitherZero configuration" `
    -Template "enterprise" `
    -GitHubOrg "mycompany"

# Create a local-only repository
New-ConfigurationRepository -RepositoryName "local-dev-config" `
    -LocalPath "./configs/local-dev" `
    -Provider "local" `
    -Template "minimal" `
    -Environments @('dev', 'test')

# Create with custom settings
$customSettings = @{
    verbosity = "detailed"
    auditEnabled = $true
    modules = @{
        autoLoad = @('Logging', 'PatchManager')
    }
}
New-ConfigurationRepository -RepositoryName "custom-config" `
    -LocalPath "./configs/custom" `
    -Template "custom" `
    -CustomSettings $customSettings
```

### Clone-ConfigurationRepository
Clones an existing configuration repository and validates its structure.

**Parameters:**
- `-RepositoryUrl` [string] (Mandatory): Git repository URL
- `-LocalPath` [string] (Mandatory): Local directory for cloning
- `-Branch` [string]: Branch to clone - default: 'main'
- `-Validate` [switch]: Validate repository structure - default: $true
- `-SetupLocalSettings` [switch]: Create local settings file

**Returns:** Hashtable with Success, RepositoryUrl, LocalPath, Branch, and ValidationResult

**Example:**
```powershell
# Clone from GitHub
Clone-ConfigurationRepository `
    -RepositoryUrl "https://github.com/myteam/aither-configs.git" `
    -LocalPath "./team-configs"

# Clone specific branch without validation
Clone-ConfigurationRepository `
    -RepositoryUrl "git@github.com:company/aither-prod.git" `
    -LocalPath "./prod-configs" `
    -Branch "release/v2.0" `
    -Validate:$false

# Clone and setup local settings
Clone-ConfigurationRepository `
    -RepositoryUrl "https://github.com/dev/test-config.git" `
    -LocalPath "./test" `
    -SetupLocalSettings
```

### Sync-ConfigurationRepository
Synchronizes a configuration repository with its remote.

**Parameters:**
- `-Path` [string] (Mandatory): Path to the repository
- `-Operation` [string]: Sync operation ('pull', 'push', 'sync') - default: 'sync'
- `-Branch` [string]: Branch to sync - default: 'main'
- `-Force` [switch]: Force operation despite conflicts
- `-CreateBackup` [switch]: Create backup before sync - default: $true

**Returns:** Hashtable with Success, Operation, BackupPath, Changes array, and Error (if failed)

**Example:**
```powershell
# Full synchronization (pull, merge, push)
Sync-ConfigurationRepository -Path "./configs/team-config"

# Pull only latest changes
Sync-ConfigurationRepository -Path "./configs/team-config" `
    -Operation "pull"

# Push local changes
Sync-ConfigurationRepository -Path "./configs/team-config" `
    -Operation "push" `
    -Branch "feature/new-settings"

# Force sync without backup
Sync-ConfigurationRepository -Path "./configs/prod-config" `
    -Operation "sync" `
    -Force `
    -CreateBackup:$false
```

### Validate-ConfigurationRepository
Validates the structure and content of a configuration repository.

**Parameters:**
- `-Path` [string] (Mandatory): Path to the repository to validate

**Returns:** Hashtable with IsValid, Errors array, Warnings array, Info array, and RepositoryPath

**Example:**
```powershell
# Validate repository structure
$validation = Validate-ConfigurationRepository -Path "./configs/my-config"

if ($validation.IsValid) {
    Write-Host "Repository is valid!"
    $validation.Info | ForEach-Object { Write-Host "✓ $_" }
} else {
    Write-Host "Repository has issues:"
    $validation.Errors | ForEach-Object { Write-Error $_ }
    $validation.Warnings | ForEach-Object { Write-Warning $_ }
}

# Use validation in automation
$repos = Get-ChildItem "./configs" -Directory
foreach ($repo in $repos) {
    $result = Validate-ConfigurationRepository -Path $repo.FullName
    if (-not $result.IsValid) {
        Send-Alert "Invalid config repo: $($repo.Name)"
    }
}
```

## Configuration

### Template Types

#### Default Template
Standard configuration with balanced settings:
```json
{
    "version": "1.0",
    "name": "AitherZero Custom Configuration",
    "environments": ["dev", "staging", "prod"],
    "settings": {
        "verbosity": "normal",
        "autoUpdate": true,
        "telemetryEnabled": false
    },
    "modules": {
        "enabledByDefault": ["Logging", "PatchManager", "LabRunner"],
        "autoLoad": true
    }
}
```

#### Minimal Template
Lightweight configuration for simple setups:
```json
{
    "version": "1.0",
    "name": "Minimal AitherZero Configuration",
    "environments": ["dev", "staging", "prod"],
    "settings": {
        "verbosity": "silent"
    }
}
```

#### Enterprise Template
Full-featured configuration with security and compliance:
```json
{
    "version": "1.0",
    "name": "Enterprise AitherZero Configuration",
    "environments": ["dev", "staging", "prod"],
    "settings": {
        "verbosity": "detailed",
        "auditEnabled": true,
        "securityEnforced": true,
        "complianceMode": true
    },
    "security": {
        "requireApproval": true,
        "multiFactorAuth": true,
        "encryptionRequired": true
    },
    "compliance": {
        "retentionPeriod": "7y",
        "auditTrail": true
    }
}
```

### Repository Structure Requirements
- **Required Directories**: `configs/`, `environments/`
- **Recommended Files**: `README.md`, `.gitignore`, `configs/app-config.json`
- **Environment Directories**: One per supported environment
- **Valid JSON**: All `.json` files must be valid JSON

### Git Configuration
The module automatically:
- Initializes Git repositories
- Creates initial commits
- Sets up remote origins
- Configures default branch as 'main'

## Usage Examples

### Complete Repository Lifecycle
```powershell
# Import the module
Import-Module ./aither-core/modules/ConfigurationRepository -Force

# 1. Create new repository
$newRepo = New-ConfigurationRepository `
    -RepositoryName "team-infrastructure" `
    -LocalPath "./configs/team-infra" `
    -Template "default" `
    -Description "Team infrastructure configuration"

# 2. Make configuration changes
$configPath = Join-Path $newRepo.LocalPath "configs/app-config.json"
$config = Get-Content $configPath | ConvertFrom-Json
$config.settings.verbosity = "detailed"
$config | ConvertTo-Json -Depth 5 | Set-Content $configPath

# 3. Sync changes
Sync-ConfigurationRepository -Path $newRepo.LocalPath -Operation "push"

# 4. Validate repository
$validation = Validate-ConfigurationRepository -Path $newRepo.LocalPath
```

### Team Collaboration Workflow
```powershell
# Team member 1: Create and share configuration
New-ConfigurationRepository `
    -RepositoryName "shared-config" `
    -LocalPath "./shared" `
    -GitHubOrg "ourteam" `
    -Template "default"

# Team member 2: Clone and modify
Clone-ConfigurationRepository `
    -RepositoryUrl "https://github.com/ourteam/shared-config.git" `
    -LocalPath "./my-shared"

# Make changes...
# Then sync back
Sync-ConfigurationRepository -Path "./my-shared" -Operation "push"

# Team member 1: Pull updates
Sync-ConfigurationRepository -Path "./shared" -Operation "pull"
```

### Multi-Environment Configuration
```powershell
# Create repository with custom environments
$environments = @('development', 'qa', 'uat', 'production')
$repo = New-ConfigurationRepository `
    -RepositoryName "multi-env-config" `
    -LocalPath "./multi-env" `
    -Environments $environments `
    -Template "enterprise"

# Add environment-specific settings
foreach ($env in $environments) {
    $envPath = Join-Path $repo.LocalPath "environments/$env"
    $envConfig = @{
        environment = $env
        settings = @{
            maxConnections = switch ($env) {
                'development' { 10 }
                'qa' { 50 }
                'uat' { 100 }
                'production' { 500 }
            }
        }
    }
    $envConfig | ConvertTo-Json | Set-Content "$envPath/env-config.json"
}

# Commit and push
Push-Location $repo.LocalPath
git add .
git commit -m "Add environment-specific settings"
git push
Pop-Location
```

### Integration with ConfigurationCarousel
```powershell
# Create repository
$repo = New-ConfigurationRepository `
    -RepositoryName "carousel-config" `
    -LocalPath "./carousel-cfg" `
    -Template "default"

# Import ConfigurationCarousel
Import-Module ./aither-core/modules/ConfigurationCarousel -Force

# Add repository to carousel
Add-ConfigurationRepository `
    -Name "carousel-config" `
    -Source $repo.LocalPath `
    -SourceType "local" `
    -SetAsCurrent

# Now you can switch to this configuration
Switch-ConfigurationSet -ConfigurationName "carousel-config"
```

### Backup and Restore Operations
```powershell
# Before major changes, sync with backup
$syncResult = Sync-ConfigurationRepository `
    -Path "./configs/production" `
    -Operation "sync" `
    -CreateBackup $true

Write-Host "Backup created at: $($syncResult.BackupPath)"

# If something goes wrong, restore from backup
if ($syncResult.BackupPath) {
    Copy-Item -Path $syncResult.BackupPath `
        -Destination "./configs/production-restored" `
        -Recurse -Force
}
```

## Integration with Other Modules

### With PatchManager Module
```powershell
# ConfigurationRepository uses PatchManager for GitHub operations
# Ensure PatchManager is available for full GitHub integration
Import-Module ./aither-core/modules/PatchManager -Force

# Now repository creation can use GitHub CLI
$repo = New-ConfigurationRepository `
    -RepositoryName "github-integrated" `
    -LocalPath "./github-cfg" `
    -Provider "github" `
    -GitHubOrg "myorg"
```

### With Logging Module
```powershell
# All operations are logged through the Logging module
# Enable verbose logging
$VerbosePreference = 'Continue'

# Operations will show detailed logs
New-ConfigurationRepository -RepositoryName "logged-config" `
    -LocalPath "./logged" -Verbose
```

## Dependencies

### Required PowerShell Modules
- **Logging Module**: For operation logging (has built-in fallback)
- **PatchManager Module**: For GitHub operations (optional)

### External Tool Requirements
- **Git**: Required for all repository operations
  - Minimum version: 2.25.0
  - Must be in PATH
- **GitHub CLI (gh)**: Required for GitHub provider
  - Install: https://cli.github.com/
  - Authenticate: `gh auth login`

### Version Requirements
- PowerShell: 7.0 or higher
- Module Version: Included with AitherZero core
- No specific licensing requirements

## Best Practices

### Repository Naming
- Use descriptive names: `company-prod-config`, `team-dev-settings`
- Include purpose or environment in name
- Follow Git repository naming conventions
- Avoid spaces and special characters

### Template Selection
- **minimal**: Quick prototypes, development testing
- **default**: Most common use cases, balanced features
- **enterprise**: Production environments with compliance needs
- **custom**: When specific requirements don't fit other templates

### Synchronization Strategy
- Always backup before syncing production configs
- Use pull-only for read-only team members
- Implement branch protection for main/production branches
- Regular sync schedules for team configurations

### Security Considerations
- Use private repositories for sensitive configurations
- Never commit secrets or credentials
- Use environment variables for sensitive data
- Implement access controls on Git repositories
- Review changes before syncing to production

## Troubleshooting

### Common Issues

1. **Git Not Found**
   ```powershell
   # Check Git installation
   git --version

   # Add Git to PATH if needed
   $env:PATH += ";C:\Program Files\Git\bin"
   ```

2. **GitHub CLI Authentication**
   ```powershell
   # Check GitHub CLI status
   gh auth status

   # Login if needed
   gh auth login

   # Use personal access token
   gh auth login --with-token < token.txt
   ```

3. **Repository Already Exists**
   ```powershell
   # Check if path exists
   Test-Path "./configs/myrepo"

   # Remove if needed (careful!)
   Remove-Item "./configs/myrepo" -Recurse -Force

   # Or use different path
   New-ConfigurationRepository -RepositoryName "myrepo" `
       -LocalPath "./configs/myrepo-v2"
   ```

4. **Sync Conflicts**
   ```powershell
   # Check repository status
   Push-Location "./configs/myrepo"
   git status
   git stash list

   # Resolve conflicts manually
   git stash pop
   # Fix conflicts in files
   git add .
   git commit -m "Resolved conflicts"
   Pop-Location

   # Then retry sync
   Sync-ConfigurationRepository -Path "./configs/myrepo"
   ```

5. **Validation Failures**
   ```powershell
   # Get detailed validation
   $v = Validate-ConfigurationRepository -Path "./configs/myrepo"

   # Check JSON files
   Get-ChildItem "./configs/myrepo" -Filter "*.json" -Recurse |
       ForEach-Object {
           try {
               $null = Get-Content $_.FullName | ConvertFrom-Json
               Write-Host "✓ Valid: $($_.Name)"
           } catch {
               Write-Error "✗ Invalid: $($_.Name) - $_"
           }
       }
   ```

### Debug Mode
```powershell
# Enable debug output
$DebugPreference = 'Continue'
$VerbosePreference = 'Continue'

# Run operations with full output
New-ConfigurationRepository -RepositoryName "debug-test" `
    -LocalPath "./debug" -Debug -Verbose
```