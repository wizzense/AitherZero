# AitherZero Release Guide

Simple, straightforward process for creating AitherZero releases.

## Quick Release

```powershell
# Create a patch release
./release.ps1 -Type patch -Message "Bug fixes"

# Create a minor release
./release.ps1 -Type minor -Message "New features"

# Create a major release
./release.ps1 -Type major -Message "Breaking changes"
```

That's it! The script handles everything else.

## What Happens

1. **Version Update**: Automatically increments version based on type
2. **Git Commit**: Commits the VERSION file change
3. **Tag Creation**: Creates annotated tag (e.g., `v1.2.3`)
4. **Push**: Pushes commit and tag to GitHub
5. **Automated Build**: GitHub Actions builds packages for all platforms
6. **Release Publication**: Creates GitHub release with downloads

## Release Types

### Patch Release (x.x.X)
For bug fixes and minor improvements:
```powershell
./release.ps1 -Type patch -Message "Fixed startup issue on Linux"
```

### Minor Release (x.X.0)
For new features that don't break compatibility:
```powershell
./release.ps1 -Type minor -Message "Added cloud provider integration"
```

### Major Release (X.0.0)
For breaking changes or major rewrites:
```powershell
./release.ps1 -Type major -Message "Complete module system overhaul"
```

## Manual Version Control

If you need to set a specific version:
```powershell
# Set exact version
./release.ps1 -Version 2.1.0 -Message "Security update"

# Preview what will happen
./release.ps1 -Version 2.1.0 -Message "Test release" -DryRun
```

## Pre-Release Checklist

Before creating a release:

1. **Run Tests**
   ```powershell
   ./tests/Run-Tests.ps1 -All
   ```

2. **Update Documentation**
   - Update CHANGELOG.md with release notes
   - Check README.md is current
   - Verify QUICKSTART.md works

3. **Verify Build**
   ```powershell
   ./build/Build-Package.ps1
   ```

4. **Check Branch**
   - Must be on `main` branch
   - Must be up to date with origin

## Release Notes

Good release messages are:
- **Concise**: One line summary
- **Clear**: What changed for users
- **Actionable**: What users need to do

Examples:
- ✅ "Fixed PowerShell 5.1 compatibility issues"
- ✅ "Added progress indicators during module loading"
- ✅ "Breaking: Removed legacy module system"
- ❌ "Various fixes" (too vague)
- ❌ "Updated stuff" (unclear)

## After Release

Once the release is created:

1. **Monitor Build**: Check [GitHub Actions](https://github.com/wizzense/AitherZero/actions)
2. **Verify Release**: Check [Releases Page](https://github.com/wizzense/AitherZero/releases)
3. **Test Download**: Download and test one package
4. **Announce**: Update any external documentation or announcements

## Troubleshooting

### Tag Already Exists
```
Error: Tag v1.2.3 already exists!
```
**Solution**: The version was already released. Increment to next version.

### Not on Main Branch
```
Warning: Not on main branch (current: feature-xyz)
Switch to main branch? (y/N)
```
**Solution**: Type 'y' to switch to main, or manually checkout main first.

### Behind Origin
```
Failed to pull latest changes. Resolve conflicts and try again.
```
**Solution**: Manually pull and resolve any conflicts:
```bash
git pull origin main
# Resolve conflicts if any
git add .
git commit -m "Resolved conflicts"
```

### Build Failures

If GitHub Actions fails to build:
1. Check the [Actions log](https://github.com/wizzense/AitherZero/actions)
2. Fix any issues
3. Push fixes to main
4. Re-run the failed workflow

## Manual Release Process

If automation fails, you can manually:

1. **Update VERSION**
   ```powershell
   Set-Content -Path VERSION -Value "1.2.3" -NoNewline
   ```

2. **Commit and Tag**
   ```bash
   git add VERSION
   git commit -m "Release v1.2.3 - Bug fixes"
   git tag -a v1.2.3 -m "Release v1.2.3"
   ```

3. **Push**
   ```bash
   git push origin main
   git push origin v1.2.3
   ```

4. **Trigger Build**
   - Go to [Actions](https://github.com/wizzense/AitherZero/actions)
   - Select "Release" workflow
   - Click "Run workflow"

## Release Schedule

AitherZero follows a flexible release schedule:
- **Patches**: As needed for critical fixes
- **Minor**: Monthly or when features are ready
- **Major**: Annually or for significant changes

No fixed dates - we release when it's ready and tested.

## Questions?

- Check existing [releases](https://github.com/wizzense/AitherZero/releases) for examples
- Review the [release.ps1](./release.ps1) script source
- Open an [issue](https://github.com/wizzense/AitherZero/issues) for help