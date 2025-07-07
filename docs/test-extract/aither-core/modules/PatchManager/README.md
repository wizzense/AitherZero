# PatchManager v3.0 - Atomic Git Workflow Automation

PatchManager v3.0 provides atomic, reliable Git workflow automation for AitherZero. It eliminates git stashing issues through atomic operations and provides intelligent automation for patch creation, feature development, and release management.

## 🚀 Key Features

### Atomic Operations
- **No Git Stashing**: Eliminates merge conflicts from git stashing
- **All-or-Nothing**: Operations either complete fully or rollback automatically
- **Conflict Detection**: Automatic detection and prevention of merge conflicts
- **State Preservation**: Captures and restores repository state on failure

### Smart Mode Detection
- **Automatic Analysis**: Intelligently determines the best approach for each operation
- **Risk Assessment**: Analyzes changes for security, complexity, and impact
- **Mode Recommendations**: Simple/Standard/Advanced mode selection
- **User Override**: Manual mode selection when needed

### Workflow Automation
- **Branch Management**: Automatic branch creation with consistent naming
- **PR Creation**: Intelligent pull request automation
- **Issue Tracking**: GitHub issue creation and linking
- **Release Management**: Complete release automation with tagging

## Module Overview

The PatchManager module is AitherZero's advanced Git workflow automation system that provides atomic, reliable patch management operations. Version 3.0 introduces a revolutionary atomic operations approach that eliminates git stashing issues while maintaining full backward compatibility with legacy functions.

### Primary Purpose and Architecture

- **Atomic Git operations** with automatic rollback on failure
- **Multi-mode operation system** (Simple, Standard, Advanced)
- **Smart mode detection** for optimal workflow selection
- **Cross-platform Git workflow automation** (Windows, Linux, macOS)
- **GitHub integration** for automated PR and issue creation
- **Release management** with automated tagging and versioning
- **Zero-conflict operations** by eliminating git stashing entirely

### Key Capabilities and Features

- **V3.0 Atomic Functions**: New-Patch, New-QuickFix, New-Feature, New-Hotfix
- **Intelligent mode detection** based on change analysis
- **Automatic PR/issue creation** with smart defaults
- **Cross-fork operations** for upstream contributions
- **Release workflow automation** with semantic versioning
- **Rollback and recovery** mechanisms
- **Repository documentation** auto-generation
- **Post-merge monitoring** and cleanup
- **Branch synchronization** and conflict resolution

### Integration Patterns

```powershell
# Import the module
Import-Module ./aither-core/modules/PatchManager -Force

# Simple atomic patch (v3.0)
New-Patch -Description "Fix configuration typo" -Changes {
    $config = Get-Content "config.json" | ConvertFrom-Json
    $config.database.server = "prod-db-01"  # was "prod-bd-01"
    $config | ConvertTo-Json | Set-Content "config.json"
}

# Feature development with automatic PR
New-Feature -Description "Add user dashboard" -Changes {
    New-UserDashboardComponent
    Update-NavigationMenu
    Add-DashboardTests
}

# Emergency hotfix
New-Hotfix -Description "Fix critical security vulnerability CVE-2024-1234" -Changes {
    Apply-SecurityPatch -CVE "CVE-2024-1234"
}

# Legacy compatibility
Invoke-PatchWorkflow -PatchDescription "Legacy syntax works" -PatchOperation {
    # Your changes
} -CreatePR
```

## Directory Structure

```
PatchManager/
├── PatchManager.psd1           # Module manifest
├── PatchManager.psm1           # Core module logic and v3.0 functions
├── README.md                   # This documentation
├── Public/                     # Public functions (25+ functions)
│   ├── New-Patch.ps1           # V3.0 main atomic patch function
│   ├── New-QuickFix.ps1        # V3.0 simple fixes without branching
│   ├── New-Feature.ps1         # V3.0 feature development workflow
│   ├── New-Hotfix.ps1          # V3.0 emergency fix workflow
│   ├── Invoke-PatchWorkflow.ps1 # Legacy main function (compatibility)
│   ├── Sync-GitBranch.ps1      # Branch synchronization
│   ├── Invoke-ReleaseWorkflow.ps1 # Release automation
│   ├── New-PatchPR.ps1         # PR creation utilities
│   ├── New-PatchIssue.ps1      # Issue creation utilities
│   ├── Invoke-PatchRollback.ps1 # Rollback operations
│   ├── Get-PatchStatus.ps1     # Status monitoring
│   ├── Enable-AutoMerge.ps1    # Auto-merge configuration
│   ├── Watch-ReleasePR.ps1     # Release monitoring
│   ├── Find-MissingReleaseTags.ps1 # Tag management
│   └── (20+ additional functions)
├── Private/                    # Internal helper functions
│   ├── Get-SmartOperationMode.ps1 # Mode detection logic
│   ├── Invoke-AtomicOperation.ps1 # Atomic operation wrapper
│   ├── Invoke-MultiModeOperation.ps1 # Multi-mode dispatcher
│   ├── Get-GitRepositoryInfo.ps1 # Repository analysis
│   ├── Initialize-CrossPlatformEnvironment.ps1 # Platform setup
│   └── (10+ additional helpers)
└── Legacy/                     # Legacy implementation files
    ├── BranchStrategy.ps1      # Legacy branching logic
    ├── GitOperations.ps1       # Legacy Git operations
    ├── ErrorHandling.ps1       # Legacy error handling
    └── (25+ legacy files)
```

### Module Organization

- **PatchManager.psd1**: Module manifest defining PowerShell 7.0+ requirement and dependencies
- **PatchManager.psm1**: Core module with v3.0 atomic functions and legacy compatibility
- **Public/**: Exported functions with comprehensive Git workflow automation
- **Private/**: Internal helper functions for operation optimization
- **Legacy/**: Previous implementation maintained for reference and compatibility

## API Reference

### V3.0 Main Functions (Recommended)

#### New-Patch
The primary atomic patch creation function replacing Invoke-PatchWorkflow.

```powershell
New-Patch -Description <string> [-Changes <scriptblock>] [-Mode <string>]
         [-CreatePR] [-CreateIssue <object>] [-TargetFork <string>]
         [-DryRun] [-Force]
```

**Parameters:**
- `Description` (string, required): Clear description of the patch
- `Changes` (scriptblock): Script block containing the changes to apply
- `Mode` (string): Operation mode - Simple, Standard, Advanced, Auto. Default: Auto
- `CreatePR` (switch): Create pull request (auto-determined if not specified)
- `CreateIssue` (object): Create GitHub issue - true, false, or auto
- `TargetFork` (string): Target fork - current, upstream, root. Default: current
- `DryRun` (switch): Preview changes without execution
- `Force` (switch): Override safety checks

**Returns:** Operation result object with status and details

**Example:**
```powershell
# Smart mode detection - will use Simple mode for minor changes
New-Patch -Description "Fix typo in error message" -Changes {
    $file = Get-Content "src/errors.ps1"
    $file = $file -replace "occured", "occurred"
    Set-Content "src/errors.ps1" -Value $file
}

# Explicit Standard mode with PR creation
New-Patch -Description "Implement user preference caching" -Mode "Standard" -CreatePR -Changes {
    Add-UserPreferenceCache
    Update-UserService
    Add-CacheTests
}

# Dry run to preview
New-Patch -Description "Large refactoring" -DryRun -Changes {
    Rename-ComponentFiles
    Update-ImportStatements
}
```

#### New-QuickFix
Simple fixes without branch overhead - ideal for typos, formatting, minor updates.

```powershell
New-QuickFix -Description <string> [-Changes <scriptblock>] [-DryRun]
```

**Parameters:**
- `Description` (string, required): Description of the quick fix
- `Changes` (scriptblock): Changes to apply
- `DryRun` (switch): Preview without execution

**Returns:** Operation result object

**Example:**
```powershell
New-QuickFix -Description "Fix comment spelling" -Changes {
    (Get-Content "module.ps1") -replace "# Proccess", "# Process" | Set-Content "module.ps1"
}
```

#### New-Feature
Full feature development workflow with automatic branching and PR creation.

```powershell
New-Feature -Description <string> [-Changes <scriptblock>] [-TargetFork <string>]
           [-DryRun] [-Force]
```

**Parameters:**
- `Description` (string, required): Feature description
- `Changes` (scriptblock): Feature implementation
- `TargetFork` (string): Target repository for cross-fork features
- `DryRun` (switch): Preview feature changes
- `Force` (switch): Override safety checks

**Returns:** Operation result with branch and PR details

**Example:**
```powershell
New-Feature -Description "Add export functionality to dashboard" -Changes {
    # Create export component
    New-ExportComponent -Type "CSV,PDF,Excel"
    
    # Update dashboard to include export options
    Update-DashboardControls -AddExport
    
    # Add export service
    Add-ExportService
    
    # Write tests
    Add-ExportTests
}
```

#### New-Hotfix
Emergency fixes with high priority processing and automatic notifications.

```powershell
New-Hotfix -Description <string> [-Changes <scriptblock>] [-Urgent] [-DryRun]
```

**Parameters:**
- `Description` (string, required): Hotfix description (should reference issue/CVE)
- `Changes` (scriptblock): Critical fix implementation
- `Urgent` (switch): Mark as urgent for expedited processing
- `DryRun` (switch): Preview hotfix changes

**Returns:** Operation result with urgency tracking

**Example:**
```powershell
New-Hotfix -Description "Fix SQL injection vulnerability in user search" -Urgent -Changes {
    # Apply parameterized query fix
    Update-UserSearchQuery -UseParameterizedQueries
    
    # Add input validation
    Add-InputValidation -Function "Search-Users"
    
    # Update security tests
    Add-SecurityTests -Coverage "SQLInjection"
}
```

### Legacy Functions (Backward Compatibility)

#### Invoke-PatchWorkflow
Legacy main function - now internally uses New-Patch for atomic operations.

```powershell
Invoke-PatchWorkflow -PatchDescription <string> -PatchOperation <scriptblock>
                    [-CreatePR] [-CreateIssue <object>] [-TargetFork <string>]
```

**Note:** This function is maintained for backward compatibility and internally uses the new atomic operations system.

### Git Management Functions

#### Sync-GitBranch
Synchronizes branches with remote repositories and resolves conflicts.

```powershell
Sync-GitBranch [-BranchName <string>] [-Force] [-AutoResolve]
```

**Parameters:**
- `BranchName` (string): Branch to sync (default: current)
- `Force` (switch): Force synchronization
- `AutoResolve` (switch): Attempt automatic conflict resolution

**Example:**
```powershell
# Sync current branch
Sync-GitBranch -Force

# Sync specific branch
Sync-GitBranch -BranchName "feature/new-auth" -AutoResolve
```

#### Invoke-ReleaseWorkflow
Automates release creation with versioning and tagging.

```powershell
Invoke-ReleaseWorkflow [-ReleaseType <string>] [-Description <string>]
                      [-Version <string>] [-DryRun]
```

**Parameters:**
- `ReleaseType` (string): patch, minor, major. Default: patch
- `Description` (string): Release description
- `Version` (string): Specific version (overrides type-based calculation)
- `DryRun` (switch): Preview release without creation

**Example:**
```powershell
# Automatic patch release
Invoke-ReleaseWorkflow -Description "Bug fixes and performance improvements"

# Minor release with new features
Invoke-ReleaseWorkflow -ReleaseType "minor" -Description "New dashboard and export features"

# Major release with breaking changes
Invoke-ReleaseWorkflow -ReleaseType "major" -Description "API v2.0 with breaking changes"
```

### Pull Request and Issue Management

#### New-PatchPR
Creates pull requests with intelligent templates and metadata.

```powershell
New-PatchPR -Title <string> -Description <string> [-Branch <string>]
           [-TargetBranch <string>] [-Labels <string[]>] [-Reviewers <string[]>]
```

#### New-PatchIssue
Creates GitHub issues with proper labeling and project assignment.

```powershell
New-PatchIssue -Title <string> -Description <string> [-Labels <string[]>]
              [-Assignees <string[]>] [-Milestone <string>]
```

### Monitoring and Status Functions

#### Get-PatchStatus
Retrieves status of patches, PRs, and releases.

```powershell
Get-PatchStatus [-Type <string>] [-Filter <string>] [-Detailed]
```

**Parameters:**
- `Type` (string): patches, prs, releases, all. Default: all
- `Filter` (string): Filter criteria
- `Detailed` (switch): Include detailed information

#### Watch-ReleasePR
Monitors release PRs for completion and automatically handles post-merge actions.

```powershell
Watch-ReleasePR [-PRNumber <int>] [-AutoTag] [-NotifyOnComplete]
```

### Rollback and Recovery

#### Invoke-PatchRollback
Safely rolls back patches with various rollback strategies.

```powershell
Invoke-PatchRollback [-RollbackType <string>] [-TargetCommit <string>]
                    [-CreateBackup] [-Force]
```

**Parameters:**
- `RollbackType` (string): LastCommit, LastPatch, ToCommit, ToTag
- `TargetCommit` (string): Specific commit to rollback to
- `CreateBackup` (switch): Create backup before rollback
- `Force` (switch): Force rollback without confirmation

## Core Concepts

### Atomic Operations (V3.0)

The revolutionary feature of PatchManager v3.0 is atomic operations that eliminate git stashing:

#### How Atomic Operations Work
1. **State Snapshot**: Current repository state is captured
2. **Change Isolation**: Changes are applied in isolated context
3. **Validation**: Changes are validated before commit
4. **All-or-Nothing**: Either all changes succeed or everything is rolled back
5. **No Stashing**: Eliminates the root cause of merge conflicts

#### Benefits
- **Zero git stashing conflicts**
- **Predictable behavior** in all scenarios
- **Automatic rollback** on any failure
- **Safe parallelization** of patch operations
- **Audit trail** of all operations

### Smart Modes

PatchManager v3.0 introduces intelligent mode detection:

#### Simple Mode
- **When**: Minor changes (typos, formatting, comments)
- **Behavior**: Direct commits without branching
- **PR Creation**: Automatic skip
- **Use Cases**: Quick fixes, documentation updates

#### Standard Mode  
- **When**: Regular features and significant changes
- **Behavior**: Full branch workflow with PR creation
- **PR Creation**: Automatic
- **Use Cases**: Feature development, bug fixes

#### Advanced Mode
- **When**: Cross-fork operations, enterprise workflows
- **Behavior**: Multi-repository operations
- **PR Creation**: Cross-fork PRs
- **Use Cases**: Upstream contributions, complex workflows

### Git Workflows

The module supports multiple Git workflow patterns:

#### Feature Branch Workflow
```powershell
New-Feature -Description "Add analytics dashboard" -Changes {
    # Feature implementation
}
# Automatically creates: feature/add-analytics-dashboard branch
# Creates PR: "Add analytics dashboard"
# Handles merge and cleanup
```

#### Hotfix Workflow
```powershell
New-Hotfix -Description "Fix critical authentication bug" -Changes {
    # Fix implementation
}
# Creates: hotfix/fix-critical-authentication-bug
# High priority PR with security labels
# Fast-track review process
```

#### Release Workflow
```powershell
Invoke-ReleaseWorkflow -ReleaseType "minor" -Description "Q1 feature release"
# Creates release branch
# Updates version numbers
# Creates release PR
# Handles tagging after merge
```

## Usage Patterns

### Common Usage Scenarios

#### Daily Development Workflow
```powershell
# Morning: Sync with remote
Sync-GitBranch -Force

# Feature work
New-Feature -Description "Implement user notifications" -Changes {
    Add-NotificationService
    Update-UserInterface -AddNotifications
    Add-NotificationTests
}

# Quick fixes during development
New-QuickFix -Description "Fix test setup typo" -Changes {
    (Get-Content "tests/Setup.ps1") -replace "Initalize", "Initialize" | Set-Content "tests/Setup.ps1"
}

# End of day: Check status
Get-PatchStatus -Type "prs" -Detailed
```

#### Release Management
```powershell
# Prepare release
$status = Get-PatchStatus -Type "all"
if ($status.PendingPRs -eq 0) {
    # Create release
    Invoke-ReleaseWorkflow -ReleaseType "minor" -Description "New features and improvements"
    
    # Monitor release PR
    Watch-ReleasePR -AutoTag -NotifyOnComplete
} else {
    Write-Host "Cannot release: $($status.PendingPRs) PRs pending"
}
```

#### Emergency Response
```powershell
# Critical security fix
New-Hotfix -Description "Fix SQL injection in user search endpoint CVE-2024-5678" -Urgent -Changes {
    # Apply security patch
    Update-UserSearchEndpoint -UseParameterizedQueries
    Add-InputValidation -Endpoint "UserSearch"
    Update-SecurityTests
}

# If something goes wrong, rollback
if ($result.Success -eq $false) {
    Invoke-PatchRollback -RollbackType "LastPatch" -CreateBackup
}
```

### Integration Examples

#### With CI/CD Pipelines
```powershell
# Automated patch creation from CI
if ($env:CI_COMMIT_MESSAGE -match "auto-fix") {
    New-QuickFix -Description "Automated linting fixes" -Changes {
        Invoke-Linter -Fix -Path "./src"
    }
}

# Release automation
if ($env:GITHUB_REF -eq "refs/heads/release") {
    Invoke-ReleaseWorkflow -ReleaseType "auto" -Description "Automated release"
}
```

#### With Testing Frameworks
```powershell
# Test-driven patch creation
New-Feature -Description "Add data validation" -Changes {
    # Write tests first
    Add-ValidationTests
    
    # Run tests to see them fail
    $testResult = Invoke-Pester -Path "./tests/Validation.Tests.ps1"
    
    # Implement feature
    if ($testResult.FailedCount -gt 0) {
        Add-DataValidation
    }
    
    # Verify tests pass
    $finalResult = Invoke-Pester -Path "./tests/Validation.Tests.ps1"
    if ($finalResult.FailedCount -gt 0) {
        throw "Tests still failing after implementation"
    }
}
```

#### With Monitoring Systems
```powershell
# Monitor patch status
$status = Get-PatchStatus -Detailed
if ($status.FailedPatches -gt 0) {
    Send-Alert -Message "Patch failures detected" -Severity "High"
}

# Release monitoring
Start-Job {
    Watch-ReleasePR -PRNumber $prNumber -NotifyOnComplete
}
```

### Best Practices

1. **Use descriptive patch descriptions** that explain the "why" not just "what"
2. **Let smart mode detection work** - only override when necessary
3. **Use New-QuickFix for minor changes** to avoid unnecessary PR overhead
4. **Test with -DryRun first** for complex operations
5. **Sync branches regularly** to avoid conflicts
6. **Monitor patch status** to catch issues early
7. **Use atomic operations** for reliable, rollback-safe changes
8. **Group related changes** in single patches
9. **Use appropriate functions** (QuickFix vs Feature vs Hotfix)
10. **Leverage automation** for routine operations

## Advanced Features

### Multi-Mode Operation System

The v3.0 system automatically selects the optimal mode:

```powershell
# Automatic mode detection
New-Patch -Description "Update documentation" -Changes { ... }
# Detects: Simple mode (no PR needed)

New-Patch -Description "Add new API endpoint" -Changes { ... }
# Detects: Standard mode (PR needed)

New-Patch -Description "Contribute to upstream project" -TargetFork "upstream" -Changes { ... }
# Detects: Advanced mode (cross-fork PR)
```

### Cross-Fork Operations

Support for complex repository relationships:

```powershell
# Contribute to upstream
New-Feature -Description "Add Windows support" -TargetFork "upstream" -Changes {
    Add-WindowsCompatibility
    Update-Documentation
}

# Work with organization forks
New-Patch -Description "Custom enterprise features" -TargetFork "root" -Changes {
    Add-EnterpriseFeatures
}
```

### Repository Analysis and Intelligence

Smart analysis of repository state:

```powershell
# Get repository information
$repoInfo = Get-GitRepositoryInfo
Write-Host "Fork chain: $($repoInfo.ForkChain -join ' → ')"
Write-Host "Open PRs: $($repoInfo.OpenPRs)"
Write-Host "Pending releases: $($repoInfo.PendingReleases)"
```

### Advanced Release Management

Sophisticated release workflows:

```powershell
# Semantic version calculation
Invoke-ReleaseWorkflow -ReleaseType "auto" -Description "Automatic semantic versioning"

# Pre-release versions
Invoke-ReleaseWorkflow -Version "2.1.0-beta.1" -Description "Beta release for testing"

# Hotfix releases
Invoke-ReleaseWorkflow -ReleaseType "patch" -Hotfix -Description "Critical security patch"
```

### Error Recovery and Rollback

Comprehensive recovery mechanisms:

```powershell
# Automatic rollback on operation failure
New-Patch -Description "Risky changes" -Changes {
    try {
        Make-RiskyChanges
    } catch {
        # Automatic rollback triggered
        throw
    }
}

# Manual rollback options
Invoke-PatchRollback -RollbackType "LastCommit" -CreateBackup
Invoke-PatchRollback -RollbackType "ToTag" -TargetCommit "v1.2.3"
Invoke-PatchRollback -RollbackType "ToCommit" -TargetCommit "abc123def"
```

## Configuration

### Module-Specific Settings

Configure PatchManager behavior via environment variables or configuration files:

```powershell
# Environment variables
$env:PATCHMANAGER_DEFAULT_MODE = "Standard"
$env:PATCHMANAGER_AUTO_PR = "true"
$env:PATCHMANAGER_AUTO_ISSUE = "false"
$env:PATCHMANAGER_BRANCH_PREFIX = "feature/"
$env:PATCHMANAGER_DEFAULT_REVIEWERS = "team-leads"

# Configuration via function
Set-PatchManagerConfig -DefaultMode "Standard" -AutoCreatePR $true -BranchPrefix "patch/"
```

### Customization Options

1. **Branch naming conventions** via templates
2. **PR templates** for consistent descriptions
3. **Issue templates** for tracking
4. **Custom reviewers** based on file patterns
5. **Automated labeling** based on change types
6. **Release notes** generation from commits
7. **Cross-platform** Git command handling

### Performance Tuning Parameters

Optimize for different environments:

```powershell
# High-performance Git operations
Set-PatchManagerConfig -FastMode $true -ParallelOperations $true

# Conservative settings for CI/CD
Set-PatchManagerConfig -SafeMode $true -AlwaysCreateBackup $true

# Enterprise settings
Set-PatchManagerConfig -RequireReview $true -EnforcePolicy $true
```

## Error Handling and Recovery

### Atomic Operation Guarantees

V3.0 provides strong guarantees:

1. **All-or-nothing operations**: Either complete success or complete rollback
2. **State consistency**: Repository never left in intermediate state  
3. **Conflict prevention**: No git stashing means no merge conflicts
4. **Audit trails**: Complete operation history for debugging
5. **Recovery options**: Multiple rollback strategies available

### Error Categories and Responses

#### Git Operation Errors
```powershell
try {
    New-Patch -Description "Feature" -Changes { ... }
} catch {
    # Automatic rollback already occurred
    Write-Host "Patch failed but repository state is clean"
    
    # Check specific error type
    if ($_.Exception.Message -match "merge conflict") {
        Write-Host "Sync branch and retry"
        Sync-GitBranch -Force
    }
}
```

#### Network/GitHub Errors
```powershell
# Robust GitHub operations with retry
$retryCount = 0
do {
    try {
        New-Feature -Description "Network-dependent feature" -Changes { ... }
        $success = $true
    } catch {
        $retryCount++
        Start-Sleep -Seconds (5 * $retryCount)
    }
} while (-not $success -and $retryCount -lt 3)
```

#### Validation Errors
```powershell
# Pre-validation prevents atomic operation waste
$validation = Test-PatchValidity -Changes { ... }
if ($validation.IsValid) {
    New-Patch -Description "Validated changes" -Changes { ... }
} else {
    Write-Host "Validation failed: $($validation.Errors -join ', ')"
}
```

## Testing and Quality Assurance

### Testing Patch Operations

```powershell
# Test patches in isolation
$testResult = New-Patch -Description "Test patch" -DryRun -Changes {
    Add-TestFeature
}

if ($testResult.WouldSucceed) {
    # Apply the actual patch
    New-Patch -Description "Test patch" -Changes {
        Add-TestFeature
    }
}
```

### Quality Gates

```powershell
# Automated quality checks
New-Feature -Description "Quality-assured feature" -Changes {
    Add-NewFeature
    
    # Run tests
    $testResult = Invoke-Pester
    if ($testResult.FailedCount -gt 0) {
        throw "Tests failed: $($testResult.FailedCount) failures"
    }
    
    # Run linting
    $lintResult = Invoke-ScriptAnalyzer -Path ./src -Recurse
    if ($lintResult.Count -gt 0) {
        throw "Linting failed: $($lintResult.Count) issues"
    }
    
    # Security scan
    $securityResult = Test-SecurityVulnerabilities
    if ($securityResult.HasIssues) {
        throw "Security issues detected"
    }
}
```

### Continuous Integration Integration

```powershell
# CI-friendly patch operations
if ($env:CI -eq "true") {
    # Use appropriate settings for CI
    New-Patch -Description "CI patch" -Force -Changes {
        Update-CIConfiguration
    }
    
    # Verify CI still passes
    $ciResult = Test-CIPipeline
    if (-not $ciResult.Success) {
        Invoke-PatchRollback -RollbackType "LastCommit"
        throw "CI pipeline broken by patch"
    }
}
```

## Migration from Legacy Versions

### Upgrading from PatchManager v2.x

```powershell
# Old syntax (still works via compatibility layer)
Invoke-PatchWorkflow -PatchDescription "Legacy syntax" -PatchOperation {
    # Changes
} -CreatePR

# New v3.0 syntax (recommended)
New-Patch -Description "Modern syntax" -Changes {
    # Same changes
}  # PR creation automatically determined
```

### Breaking Changes

- **Git stashing eliminated**: Operations that relied on stashing behavior need updates
- **Mode system**: Explicit mode selection may behave differently
- **Default behaviors**: Some defaults changed for better security and reliability

### Compatibility Layer

The v3.0 module maintains full backward compatibility:
- All v2.x functions still work
- Internal implementation updated to use atomic operations
- Same parameter names and return values
- Gradual migration path available

## Examples and Templates

### Complete Feature Development Example

```powershell
# Full feature development lifecycle
Import-Module ./aither-core/modules/PatchManager -Force

# Start feature development
$featureResult = New-Feature -Description "Add user profile management" -Changes {
    # 1. Create model
    Add-UserProfileModel
    
    # 2. Create service layer
    Add-UserProfileService
    
    # 3. Create API endpoints
    Add-UserProfileAPI
    
    # 4. Create UI components
    Add-UserProfileUI
    
    # 5. Add comprehensive tests
    Add-UserProfileTests
    
    # 6. Update documentation
    Update-APIDocumentation -AddUserProfile
}

Write-Host "Feature branch created: $($featureResult.BranchName)"
Write-Host "Pull request: $($featureResult.PullRequestUrl)"

# Monitor the PR
Watch-ReleasePR -PRNumber $featureResult.PRNumber -NotifyOnComplete

# After PR approval and merge, clean up
if ($featureResult.MergeStatus -eq "Merged") {
    Invoke-PostMergeCleanup -BranchName $featureResult.BranchName
}
```

### Release Management Example

```powershell
# Complete release workflow
Import-Module ./aither-core/modules/PatchManager -Force

# Check if ready for release
$status = Get-PatchStatus -Type "all"
if ($status.PendingPRs -eq 0 -and $status.FailedChecks -eq 0) {
    
    # Create release
    $release = Invoke-ReleaseWorkflow -ReleaseType "minor" -Description "Q2 2024 Feature Release" -Changes {
        # Update changelogs
        Update-Changelog -Version "2.1.0"
        
        # Update version files
        Update-ModuleVersion -Version "2.1.0"
        
        # Generate release notes
        $releaseNotes = Generate-ReleaseNotes -FromTag "v2.0.0" -ToTag "HEAD"
        Set-Content "RELEASE_NOTES.md" -Value $releaseNotes
    }
    
    Write-Host "Release PR created: $($release.PullRequestUrl)"
    
    # Automated monitoring
    $monitoring = Start-Job {
        param($prNumber)
        Watch-ReleasePR -PRNumber $prNumber -AutoTag -NotifyOnComplete
    } -ArgumentList $release.PRNumber
    
    Write-Host "Release monitoring job started: $($monitoring.Id)"
    
} else {
    Write-Warning "Not ready for release:"
    Write-Warning "  Pending PRs: $($status.PendingPRs)"
    Write-Warning "  Failed checks: $($status.FailedChecks)"
}
```

### Emergency Hotfix Example

```powershell
# Critical security hotfix workflow
Import-Module ./aither-core/modules/PatchManager -Force

# Emergency response
$hotfix = New-Hotfix -Description "Fix critical XSS vulnerability in user comments" -Urgent -Changes {
    # 1. Apply immediate fix
    Update-CommentSanitization -EnableXSSProtection
    
    # 2. Add input validation
    Add-InputValidation -Component "UserComments" -Rules @("NoScript", "HTMLEncode")
    
    # 3. Update security tests
    Add-SecurityTest -Type "XSS" -Component "UserComments"
    
    # 4. Audit existing data
    $auditResult = Invoke-CommentAudit -CheckForXSS
    if ($auditResult.SuspiciousComments -gt 0) {
        Write-Warning "Found $($auditResult.SuspiciousComments) suspicious comments"
        Clean-SuspiciousComments -Comments $auditResult.SuspiciousComments
    }
}

Write-Host "Hotfix created: $($hotfix.BranchName)"
Write-Host "Priority PR: $($hotfix.PullRequestUrl)"

# Fast-track the hotfix
Enable-AutoMerge -PRNumber $hotfix.PRNumber -RequireReviews 1

# Monitor for immediate deployment
Watch-ReleasePR -PRNumber $hotfix.PRNumber -AutoTag -NotifyOnComplete -Urgent

# Create incident report
New-PatchIssue -Title "Post-incident review: XSS vulnerability" -Description @"
## Incident Summary
Critical XSS vulnerability found in user comments component.

## Resolution
- Hotfix PR: $($hotfix.PullRequestUrl)
- Fix applied: Enhanced input sanitization
- Audit completed: $($auditResult.SuspiciousComments) suspicious comments cleaned

## Follow-up Actions
- [ ] Security code review of all user input components
- [ ] Penetration testing
- [ ] Security training for development team
"@ -Labels @("security", "incident", "high-priority")
```