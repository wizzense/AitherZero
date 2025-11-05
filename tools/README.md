# Tools Directory

This directory contains utility scripts for repository management and maintenance tasks.

## Invoke-ReleaseCleanup.ps1

**Purpose**: Removes all GitHub releases and tags except v1.0.0.0 to make it the official first release.

**Requirements**:
- PowerShell 7.0+
- GitHub CLI (`gh`) installed and authenticated
- Repository write permissions

**Usage**:

```powershell
# Preview what would be deleted (safe, makes no changes)
./Invoke-ReleaseCleanup.ps1 -DryRun

# Execute the cleanup (requires confirmation)
./Invoke-ReleaseCleanup.ps1
```

**What it does**:
1. Deletes all GitHub releases except v1.0.0.0
2. Removes all local tags except v1.0.0.0
3. Pushes tag deletions to remote repository
4. Provides detailed progress and summary

**Safety features**:
- Dry-run mode to preview changes
- User confirmation required before deletion
- Detailed logging of all operations
- Error handling and reporting

**Alternative**: Use the GitHub Actions workflow `.github/workflows/release-cleanup-v1.yml` for a safer, automated approach.

## Related Documentation

See `/docs/RELEASE-1.0.0-CLEANUP.md` for complete documentation of the cleanup process.
