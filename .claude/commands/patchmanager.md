# /patchmanager

Execute PatchManager workflows for Git operations, automated patching, and PR creation.

## Usage
```
/patchmanager [action] [options]
```

## Actions

### `workflow` - Main patch workflow (default)
Create branches, apply changes, commit, and optionally create issues/PRs.

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

### `rollback` - Rollback operations
Undo recent changes or revert to previous state.

**Options:**
- `--type [LastCommit|LastBranch|ToCommit]` - Rollback type
- `--commit-hash "hash"` - Specific commit to rollback to
- `--create-backup` - Create backup before rollback

### `status` - Git status and guidance
Show current repository status with intelligent guidance.

### `consolidate` - PR consolidation
Consolidate multiple open pull requests.

**Options:**
- `--strategy [Compatible|RelatedFiles|SameAuthor|ByPriority|All]` - Consolidation strategy
- `--max-prs N` - Maximum PRs to consolidate (default: 5)

## Examples

```bash
# Basic patch workflow
/patchmanager workflow --description "Fix module loading issue" --operation "Get-Content module.ps1 | ForEach-Object { $_ -replace 'old', 'new' } | Set-Content module.ps1"

# Create patch with PR
/patchmanager workflow --description "Update configuration" --create-pr --priority High

# Cross-fork PR to upstream
/patchmanager workflow --description "Feature ready for staging" --create-pr --target-fork upstream

# Quick local fix (no issue)
/patchmanager workflow --description "Local fix" --create-issue:$false --operation "Fix-LocalIssue"

# Preview changes only
/patchmanager workflow --description "Test changes" --dry-run

# Rollback last commit
/patchmanager rollback --type LastCommit --create-backup

# Check status with guidance
/patchmanager status

# Consolidate open PRs
/patchmanager consolidate --strategy Compatible --max-prs 3
```

## Integration Notes

- Automatically handles cross-platform PowerShell execution
- Integrates with existing PatchManager module
- Supports automated and interactive modes
- Maintains git workflow consistency
- Includes unicode sanitization and validation