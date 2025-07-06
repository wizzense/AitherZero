# /patchmanager

Execute PatchManager v3.0 workflows with atomic operations and smart auto-detection.

## Usage
```
/patchmanager [action] [options]
```

## Actions (v3.0 API)

### `quickfix` - Quick fixes for minor changes
Minor changes with no branching needed (typos, formatting, documentation).

**Options:**
- `--description "text"` - Description of the fix (required)
- `--changes "scriptblock"` - PowerShell code to execute 
- `--dry-run` - Preview without making changes

### `feature` - Feature development workflow  
New functionality with automatic branching and PR creation.

**Options:**
- `--description "text"` - Description of the feature (required)
- `--changes "scriptblock"` - PowerShell code to execute
- `--target-fork [current|upstream|root]` - PR target (default: current)
- `--dry-run` - Preview without making changes

### `hotfix` - Emergency hotfixes
Critical fixes with high priority and automatic PR creation.

**Options:**
- `--description "text"` - Description of the hotfix (required)
- `--changes "scriptblock"` - PowerShell code to execute
- `--dry-run` - Preview without making changes

### `patch` - Smart patch with auto-detection (default)
Automatically chooses the best approach based on change analysis.

**Options:**
- `--description "text"` - Description of the patch (required)
- `--changes "scriptblock"` - PowerShell code to execute
- `--mode [Simple|Standard|Advanced]` - Force specific mode
- `--create-pr` - Force PR creation
- `--dry-run` - Preview without making changes

### `rollback` - Rollback operations
Undo recent changes or revert to previous state.

**Options:**
- `--type [LastCommit|LastBranch|ToCommit]` - Rollback type
- `--commit-hash "hash"` - Specific commit to rollback to
- `--create-backup` - Create backup before rollback

### `status` - Git status and guidance
Show current repository status with intelligent guidance.

### `sync` - Git branch synchronization
Synchronize local branches with remote to prevent conflicts.

**Options:**
- `--branch "name"` - Specific branch to sync (default: current)
- `--force` - Force reset if branches have diverged
- `--cleanup` - Remove orphaned branches
- `--validate-tags` - Check for duplicate tags

### `release` - Automated release workflow
Create releases with automatic conflict prevention and tag management.

**Options:**
- `--type [patch|minor|major]` - Release type for version bump
- `--version "x.y.z"` - Specific version (overrides type)
- `--description "text"` - Release description (required)
- `--auto-merge` - Enable auto-merge for release PR
- `--skip-pr` - Skip PR and create tag directly (emergency releases)

### `fix-divergence` - Fix Git divergence issues
Automatically fix Git branch divergence and conflicts.

**Options:**
- `--force` - Fix without confirmation prompts
- `--backup-path "path"` - Custom backup location

### `consolidate` - PR consolidation
Consolidate multiple open pull requests.

**Options:**
- `--strategy [Compatible|RelatedFiles|SameAuthor|ByPriority|All]` - Consolidation strategy
- `--max-prs N` - Maximum PRs to consolidate (default: 5)

## Examples (v3.0 API)

```bash
# Quick fix for typos or minor changes
/patchmanager quickfix --description "Fix typo in comment" --changes "Get-Content file.ps1 | ForEach-Object { $_ -replace 'teh', 'the' } | Set-Content file.ps1"

# Feature development with automatic PR
/patchmanager feature --description "Add authentication module" --changes "New-AuthenticationModule"

# Emergency security fix
/patchmanager hotfix --description "Fix critical security vulnerability" --changes "Apply-SecurityPatch"

# Smart patch with auto-detection
/patchmanager patch --description "Update configuration system" --changes "Update-ConfigurationSystem"

# Cross-fork feature for upstream
/patchmanager feature --description "Upstream feature" --target-fork upstream --changes "Add-UpstreamFeature"

# Preview changes without executing
/patchmanager patch --description "Test changes" --dry-run --changes "Test-NewFeature"

# Force specific mode
/patchmanager patch --description "Complex change" --mode Standard --create-pr --changes "Implement-ComplexFeature"

# Legacy API support (still works)
/patchmanager rollback --type LastCommit --create-backup
/patchmanager status
/patchmanager sync --force --cleanup
```

## Integration Notes (v3.0)

- **Atomic Operations**: All-or-nothing operations with automatic rollback on failure
- **Smart Mode Detection**: Automatically chooses the best approach for changes
- **No Git Stashing**: Eliminates the root cause of merge conflicts
- **Cross-platform Support**: Works on Windows, Linux, and macOS
- **Legacy Compatibility**: Old v2.x syntax automatically translated to v3.0
- **Error Recovery**: Automatic recovery with smart error categorization
- **Multi-Mode System**: Simple/Standard/Advanced modes for different needs

## Key v3.0 Improvements

- **Breakthrough**: Eliminates git stashing issues through atomic operations
- **Smart Analysis**: Automatically determines Simple vs Standard vs Advanced mode
- **No Manual Cleanup**: Atomic operations handle cleanup automatically
- **Enhanced Safety**: Failed operations restore previous state automatically
- **Simplified API**: Cleaner function names (New-Patch vs Invoke-PatchWorkflow)
- **Better Error Handling**: Categorized errors with suggested solutions