# Making v1.0.0.0 the Official Release

> **Quick Start**: See [`QUICKSTART-RELEASE-CLEANUP.md`](./QUICKSTART-RELEASE-CLEANUP.md) for a 2-minute guide.

This document describes the process of making v1.0.0.0 the official first release of AitherZero by removing all other tags and releases.

## Background

The AitherZero repository had accumulated 46 tags and 40 releases during development. To establish a clean version history and mark the official 1.0.0 release, all previous development tags and releases needed to be removed.

## What Was Done

### 1. Version File Update
- The VERSION file already contained `1.0.0.0`, confirming this as the target version.

### 2. Tags and Releases Cleanup
The following tags and releases were identified for removal:

**Development Tags (6)**:
- vdev-9ad2748
- vdev-0727a8b
- vdev-ce297e2
- vdev-da820a7
- vdev-e781469
- vdev-fd8f282

**Pre-release Versions (39)**:
- v0.0.0.0
- v0.5-beta through v0.7.4
- v1.0.4 and v1.0.7 (created after v1.0.0.0)

**Kept**:
- v1.0.0.0 (Official 1.0.0 Release)

### 3. Cleanup Script
Created `/tools/Invoke-ReleaseCleanup.ps1` to automate the cleanup process:

```powershell
# Dry run to see what would be deleted
./tools/Invoke-ReleaseCleanup.ps1 -DryRun

# Execute the cleanup
./tools/Invoke-ReleaseCleanup.ps1
```

The script:
- Deletes all GitHub releases except v1.0.0.0
- Removes all local tags except v1.0.0.0
- Pushes tag deletions to remote repository
- Provides detailed progress and summary information
- Includes safety confirmation before executing deletions

## Execution Instructions

There are two ways to complete the cleanup:

### Option 1: GitHub Actions Workflow (Recommended)

The safest and easiest method is to use the GitHub Actions workflow:

1. **Navigate to Actions tab**:
   - Go to https://github.com/wizzense/AitherZero/actions
   - Select "Cleanup Old Releases and Tags" workflow

2. **Run in dry-run mode first** (to preview changes):
   - Click "Run workflow"
   - Leave "Dry run mode" checked
   - Click "Run workflow" button
   - Review the output to see what would be deleted

3. **Execute the cleanup**:
   - Click "Run workflow" again
   - **Uncheck** "Dry run mode"
   - Type `CONFIRM` in the confirmation field
   - Click "Run workflow" button

4. **Verify the cleanup**:
   - Check the workflow output for success messages
   - Verify only v1.0.0.0 remains in releases and tags

### Option 2: PowerShell Script (Manual)

For local execution, a repository administrator with appropriate permissions can run:

1. **Authenticate with GitHub CLI**:
   ```bash
   gh auth login
   ```

2. **Run the cleanup script**:
   ```bash
   cd /path/to/AitherZero
   
   # Dry run first
   pwsh ./tools/Invoke-ReleaseCleanup.ps1 -DryRun
   
   # Execute cleanup
   pwsh ./tools/Invoke-ReleaseCleanup.ps1
   ```

3. **Verify the cleanup**:
   ```bash
   # Check remaining tags
   git tag --list
   
   # Check remaining releases
   gh release list --repo wizzense/AitherZero
   ```

## Expected Results

After successful execution:
- **Tags**: Only `v1.0.0.0` remains
- **Releases**: Only the v1.0.0.0 release remains
- **Version History**: Clean slate from 1.0.0 forward

## Safety Features

The cleanup script includes:
- Dry-run mode to preview changes
- User confirmation before deletion
- Detailed logging of all operations
- Error handling and reporting
- No modifications to actual code or commit history

## Notes

- This operation is **irreversible** for releases (tags can be recreated if needed)
- The commit history remains unchanged; only tags and releases are affected
- The v1.0.0.0 release points to commit `b41403f65adf9861c707b1e00ce751b5a1f22c3b`
- All deleted tags can be recreated later if needed by referencing their commit SHAs

## Related Files

- `/VERSION` - Contains the official version number (1.0.0.0)
- `/tools/Invoke-ReleaseCleanup.ps1` - Automated cleanup script (manual execution)
- `/.github/workflows/release-cleanup-v1.yml` - GitHub Actions workflow (recommended)
- `/.github/workflows/release.yml` - Release automation workflow

## References

- [GitHub Releases Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Git Tag Management](https://git-scm.com/book/en/v2/Git-Basics-Tagging)
- [Semantic Versioning](https://semver.org/)
