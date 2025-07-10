# Automatic Version Tagging in PatchManager v3.1

## Overview

PatchManager v3.1 introduces automatic version tagging functionality that creates Git tags when the VERSION file is changed. This completes the automation chain for releases:

**Complete Release Automation Flow:**
1. **VERSION file updated** → 2. **Automatic tag creation** → 3. **Release workflow triggered** → 4. **Build artifacts generated** → 5. **GitHub release published**

## Key Features

- ✅ **Automatic Detection**: Detects when the VERSION file changes in commits
- ✅ **Main Branch Only**: Only processes commits to the main branch for safety
- ✅ **Smart Integration**: Seamlessly integrates with existing PatchManager workflows
- ✅ **Comprehensive Validation**: Validates git state and VERSION file before tagging
- ✅ **Rollback Protection**: Atomic operations with automatic rollback on failure
- ✅ **Multiple Trigger Points**: Automatic integration with post-merge cleanup and monitoring
- ✅ **Manual Override**: Can be triggered manually when needed
- ✅ **Dry Run Support**: Preview functionality without making changes

## Functions Available

### Primary Functions

#### `Start-AutomaticVersionTagging`
**Convenience function for manual triggering**
```powershell
# Basic usage - check for VERSION changes and create tag
Start-AutomaticVersionTagging

# Force create tag even if it exists
Start-AutomaticVersionTagging -Force

# Preview what would be done
Start-AutomaticVersionTagging -DryRun

# Show detailed output
Start-AutomaticVersionTagging -ShowDetails
```

#### `Invoke-AutomaticVersionTagging`
**Comprehensive automatic tagging function**
```powershell
# Check specific commit for VERSION changes
Invoke-AutomaticVersionTagging -CommitSha "abc123def456"

# Force tag creation with silent output
Invoke-AutomaticVersionTagging -ForceTag -Silent

# Dry run with detailed output
Invoke-AutomaticVersionTagging -DryRun
```

### Convenience Aliases

```powershell
# These are aliases for Start-AutomaticVersionTagging
New-VersionTag -DryRun
Create-VersionTag -Force
```

## Integration Points

### Automatic Integration

The automatic version tagging is integrated at these points:

1. **Post-Merge Cleanup** (`Invoke-PostMergeCleanup`)
   - Automatically checks for VERSION file changes after PR merges
   - Creates tags as part of the standard cleanup process

2. **Post-Merge Monitoring** (`Start-PostMergeMonitor`)
   - Background monitoring jobs include automatic tagging
   - Ensures tags are created even if cleanup is run separately

3. **Manual Patch Creation** (`New-Patch`)
   - Can be enabled with `-AutoTag` parameter
   - Integrates with the atomic operation workflow

### Manual Integration

You can also manually trigger version tagging:

```powershell
# Import the module
Import-Module ./aither-core/modules/PatchManager -Force

# Check for VERSION changes and create tag
Start-AutomaticVersionTagging

# Or use aliases
New-VersionTag
Create-VersionTag -Force
```

## How It Works

### Detection Logic

1. **Branch Check**: Verifies current branch is `main` or `master`
2. **VERSION File Check**: Looks for changes to the VERSION file in the specified commit
3. **Version Reading**: Reads the new version from the VERSION file
4. **Tag Creation**: Creates a tag in the format `v{version}` (e.g., `v0.11.0`)
5. **Remote Push**: Pushes the tag to the remote repository
6. **Workflow Trigger**: The new tag triggers the GitHub Actions release workflow

### Tag Format

- **Tag Name**: `v{version}` (e.g., `v0.11.0`, `v1.2.3`)
- **Tag Message**: Includes version info, commit SHA, and automation attribution
- **Signed Tags**: Uses annotated tags with comprehensive metadata

### Example Tag Message
```
Automatic release tag v0.11.0

Version 0.11.0 release with automatic tagging.

Changes detected in VERSION file at commit abc123def456

🤖 Generated automatically by PatchManager v3.1

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Usage Examples

### Basic Usage

```powershell
# Check for VERSION file changes and create tag automatically
Start-AutomaticVersionTagging

# Result: Creates tag v0.11.0 if VERSION file contains "0.11.0" and was changed
```

### Force Tag Creation

```powershell
# Force create tag even if it already exists
Start-AutomaticVersionTagging -Force

# Result: Recreates the tag, useful for fixing tag issues
```

### Dry Run Mode

```powershell
# Preview what would be done without making changes
Start-AutomaticVersionTagging -DryRun

# Result: Shows what tag would be created without actually creating it
```

### Integration with Patch Workflows

```powershell
# Create a patch with automatic tagging enabled
New-Patch -Description "Update VERSION to 0.11.0" -AutoTag -Changes {
    "0.11.0" | Set-Content "VERSION"
}

# Result: Creates patch, commits changes, and automatically creates version tag
```

### Manual Post-Merge Tagging

```powershell
# After a PR is merged, check for VERSION changes and create tag
Invoke-PostMergeCleanup -BranchName "patch/update-version" -PullRequestNumber 123

# Result: Cleanup includes automatic version tagging if VERSION was changed
```

## Error Handling

The automatic version tagging includes comprehensive error handling:

### Common Scenarios

1. **Not on Main Branch**: Safely skips tagging with informational message
2. **VERSION File Not Changed**: Skips tagging with informational message
3. **Tag Already Exists**: Warns and skips unless `-Force` is used
4. **VERSION File Missing**: Throws error with clear message
5. **Git Command Failures**: Throws error with git command details
6. **Network Issues**: Throws error with push failure details

### Error Recovery

- **Atomic Operations**: If tag creation fails, no partial state is left
- **Rollback Support**: Failed operations are automatically cleaned up
- **Manual Recovery**: Clear error messages explain how to fix issues manually

## Best Practices

### For Developers

1. **Use Dry Run First**: Always test with `-DryRun` when learning
2. **Check Git State**: Ensure you're on main branch and have clean working directory
3. **Version Format**: Use semantic versioning format (e.g., `1.2.3`)
4. **Manual Verification**: Check that the tag was created and pushed correctly

### For Automation

1. **Integrate with Workflows**: Use automatic integration points for seamless automation
2. **Monitor Failures**: Set up monitoring for tag creation failures
3. **Backup Strategy**: Consider manual tagging procedures for critical releases
4. **Testing**: Test the complete flow in development environments

### For Release Management

1. **VERSION File Updates**: Always update VERSION file as part of release PRs
2. **Tag Verification**: Verify tags are created after PR merges
3. **Release Monitoring**: Monitor GitHub Actions release workflow after tag creation
4. **Documentation**: Document version changes in release notes

## Troubleshooting

### Common Issues

#### Tag Not Created
```powershell
# Check if you're on main branch
git branch --show-current

# Check if VERSION file was actually changed
git diff HEAD~1 HEAD --name-only

# Check if function detected the change
Start-AutomaticVersionTagging -DryRun -ShowDetails
```

#### Tag Already Exists
```powershell
# List existing tags
git tag -l "v*"

# Force recreate the tag
Start-AutomaticVersionTagging -Force
```

#### VERSION File Issues
```powershell
# Check VERSION file exists and has content
Test-Path "VERSION"
Get-Content "VERSION"

# Verify VERSION file format
$version = Get-Content "VERSION"
$version.Trim() -match '^\d+\.\d+\.\d+$'
```

### Debug Mode

Enable verbose logging for troubleshooting:

```powershell
# Enable verbose output
$VerbosePreference = "Continue"

# Run with detailed output
Start-AutomaticVersionTagging -ShowDetails

# Check comprehensive function
Invoke-AutomaticVersionTagging -DryRun
```

## Configuration

### Environment Variables

The automatic version tagging respects these environment variables:

- `PROJECT_ROOT`: Project root directory (auto-detected)
- `GITHUB_TOKEN`: GitHub authentication token (for gh CLI)

### Git Configuration

Ensure your Git configuration is set up correctly:

```bash
# Set up Git user (required for tag creation)
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Verify GitHub CLI authentication
gh auth status
```

## Advanced Usage

### Custom Commit Checking

```powershell
# Check specific commit for VERSION changes
Invoke-AutomaticVersionTagging -CommitSha "abc123def456"

# Check different branch (will skip if not main)
Invoke-AutomaticVersionTagging -BranchName "develop"
```

### Scripting Integration

```powershell
# Use in scripts with error handling
try {
    $result = Start-AutomaticVersionTagging
    if ($result.Success -and $result.TagCreated) {
        Write-Host "✅ Tag created: $($result.TagName)"
        # Proceed with additional automation
    }
} catch {
    Write-Error "Tag creation failed: $_"
    # Handle error appropriately
}
```

### Batch Operations

```powershell
# Process multiple commits
$commits = @("abc123", "def456", "ghi789")
foreach ($commit in $commits) {
    $result = Invoke-AutomaticVersionTagging -CommitSha $commit -Silent
    if ($result.TagCreated) {
        Write-Host "Created tag for commit $commit: $($result.TagName)"
    }
}
```

## Release Workflow Integration

### GitHub Actions Trigger

When a version tag is created, it automatically triggers the release workflow:

```yaml
# .github/workflows/release.yml
on:
  push:
    tags:
      - 'v*'
```

### Monitoring Release Progress

```powershell
# After tag creation, monitor the release
$tagName = "v0.11.0"
$repoUrl = "https://github.com/wizzense/AitherZero"

# Monitor Actions
Write-Host "Monitor build: $repoUrl/actions"

# Check release when ready
Write-Host "View release: $repoUrl/releases/tag/$tagName"
```

## Migration from Manual Tagging

### Before (Manual Process)
```powershell
# Old manual process
git tag -a "v0.11.0" -m "Release v0.11.0"
git push origin "v0.11.0"
```

### After (Automatic Process)
```powershell
# New automatic process
# 1. Update VERSION file in your PR
"0.11.0" | Set-Content "VERSION"

# 2. Merge PR (automatic tagging happens during post-merge cleanup)
# 3. Tag is created automatically
# 4. Release workflow triggers automatically
```

### Transition Strategy

1. **Phase 1**: Enable automatic tagging alongside manual process
2. **Phase 2**: Verify automatic tagging works for several releases
3. **Phase 3**: Disable manual tagging and rely on automatic process
4. **Phase 4**: Update documentation and train team on new process

## Security Considerations

### Access Control

- **Branch Protection**: Automatic tagging only works on main branch
- **Permission Requirements**: Requires push access to create and push tags
- **Audit Trail**: All tag creation is logged and attributed

### Validation

- **Input Validation**: VERSION file content is validated before tag creation
- **State Verification**: Git repository state is verified before operations
- **Rollback Protection**: Failed operations are automatically cleaned up

## Conclusion

The automatic version tagging feature in PatchManager v3.1 provides a complete automation solution for release management. By detecting VERSION file changes and automatically creating tags, it eliminates manual steps and ensures consistent release processes.

The feature is designed to be:
- **Safe**: Only operates on main branch with comprehensive validation
- **Reliable**: Atomic operations with automatic rollback
- **Flexible**: Can be used automatically or manually triggered
- **Transparent**: Comprehensive logging and error reporting

This completes the release automation chain, making it possible to go from VERSION file update to published GitHub release with zero manual intervention.