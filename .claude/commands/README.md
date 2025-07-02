# Claude Commands for AitherZero

This directory contains helper scripts to streamline the release process after PR merges.

## 🚀 Quick Start

After your PR has been merged to main:

```powershell
# One command to create and push release tag
./.claude/commands/quick-release.ps1
```

That's it! The script will:
1. Switch to main branch
2. Pull latest changes
3. Read version from VERSION file
4. Create annotated tag
5. Push tag to trigger release build

## 📚 Available Commands

### quick-release.ps1
The simplest way to create a release after PR merge:
```powershell
./.claude/commands/quick-release.ps1
```

### create-release-tag.ps1
More control over the release process:
```powershell
# Use VERSION file
./.claude/commands/create-release-tag.ps1

# Specify version
./.claude/commands/create-release-tag.ps1 -Version "1.4.3"

# Custom message
./.claude/commands/create-release-tag.ps1 -Version "1.4.3" -Message "Custom release notes"
```

### monitor-release.ps1
Watch the build pipeline progress:
```powershell
# Monitor current version
./.claude/commands/monitor-release.ps1

# Monitor specific version
./.claude/commands/monitor-release.ps1 -Version "1.4.2"
```

## 🔄 Typical Workflow

1. **Create changes with PatchManager**:
   ```powershell
   Import-Module ./aither-core/modules/PatchManager -Force
   Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Your changes"
   ```

2. **After PR merges**, create release tag:
   ```powershell
   ./.claude/commands/quick-release.ps1
   ```

3. **Monitor the build** (optional):
   ```powershell
   ./.claude/commands/monitor-release.ps1
   ```

## 📋 Requirements

- PowerShell 7.0+
- Git
- GitHub CLI (`gh`) - optional but recommended for monitoring

## 🛠️ What These Scripts Do

1. **Ensure you're on main branch** with latest changes
2. **Create annotated Git tag** with proper format
3. **Push tag to GitHub** to trigger release pipeline
4. **Monitor build progress** (if gh CLI installed)

## 💡 Tips

- Always ensure your PR is merged before running these scripts
- The VERSION file should already be updated by PatchManager
- Tags follow the format `v1.2.3` (with 'v' prefix)
- Release builds are triggered automatically by tags
- Check GitHub Actions for build status

## 🚨 Troubleshooting

If a tag already exists:
- The script will ask if you want to recreate it
- Choose 'y' only if you need to rebuild the release

If build doesn't trigger:
- Check GitHub Actions workflows are enabled
- Verify the tag was pushed: `git push origin v1.4.2`
- Check workflow file `.github/workflows/build-release.yml`

## 🤖 Integration with Claude

These scripts are designed to work seamlessly with Claude Code's PatchManager workflow:

1. Claude creates PR with version bump
2. You merge the PR
3. Run `quick-release.ps1` to finish
4. GitHub Actions handles the rest

Simple, automated, and reliable! 🎉