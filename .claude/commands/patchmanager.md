# /patchmanager

Execute PatchManager workflows for Git operations, automated patching, and PR creation with enhanced conflict prevention.

## Usage
```
/patchmanager [action] [options]
```

## Actions

### `workflow` - Main patch workflow (default)
Create branches, apply changes, commit, and optionally create issues/PRs with automatic synchronization.

**Options:**
- `--description "text"` - Description of the patch (required)
- `--operation "scriptblock"` - PowerShell code to execute 
- `--create-issue` - Create GitHub issue (default: true)
- `--create-pr` - Create pull request (default: false)
- `--target-fork [current|upstream|root]` - PR target (default: current)
- `--priority [Low|Medium|High|Critical]` - Issue priority (default: Medium)
- `--dry-run` - Preview without making changes
- `--force` - Force operation on dirty working tree
- `--auto-consolidate` - Auto-consolidate open PRs
- `--test "command"` - Test command to run
- `--sync` - Force Git synchronization before operations (automatic)

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

## Examples

```bash
# Basic patch workflow with automatic sync
/patchmanager workflow --description "Fix module loading issue" --operation "Get-Content module.ps1 | ForEach-Object { $_ -replace 'old', 'new' } | Set-Content module.ps1"

# Create patch with PR and sync
/patchmanager workflow --description "Update configuration" --create-pr --priority High --sync

# Cross-fork PR to upstream
/patchmanager workflow --description "Feature ready for staging" --create-pr --target-fork upstream

# Quick local fix (no issue)
/patchmanager workflow --description "Local fix" --create-issue:$false --operation "Fix-LocalIssue"

# Preview changes only
/patchmanager workflow --description "Test changes" --dry-run

# Sync branches to prevent conflicts
/patchmanager sync --force --cleanup

# Create patch release
/patchmanager release --type patch --description "Bug fixes and improvements"

# Emergency release (skip PR)
/patchmanager release --version "1.2.15" --description "Critical security fix" --skip-pr

# Fix Git divergence issues
/patchmanager fix-divergence --force

# Rollback last commit
/patchmanager rollback --type LastCommit --create-backup

# Check status with guidance
/patchmanager status

# Consolidate open PRs
/patchmanager consolidate --strategy Compatible --max-prs 3
```

## Integration Notes

- **PowerShell Compatibility**: Automatically handles PowerShell 5.1 → 7 transitions
- **Conflict Prevention**: Automatic Git synchronization before all operations
- **Cross-platform Support**: Works on Windows, Linux, and macOS
- **Release Automation**: Complete release workflow with tag management
- **Rollback Safety**: Comprehensive backup and rollback capabilities
- **Unicode Sanitization**: Automatic cleanup of problematic characters
- **Workflow Consistency**: Maintains consistent Git workflows across all operations

## Key Improvements

- **Automatic Sync**: All operations now include automatic remote synchronization
- **Conflict Detection**: Proactive detection and resolution of merge conflicts
- **Branch Divergence Fix**: Automatic detection and repair of diverged branches
- **Release Workflow**: One-command release process with automated tag creation
- **PowerShell Bootstrap**: Seamless PowerShell version handling