# Archived Release Scripts

This directory contains legacy release scripts that have been replaced by the unified `AitherRelease.ps1` script.

## Archived Scripts

- `release.ps1.legacy` - The old simple release script that directly pushed to main (incompatible with branch protection)

## Migration Guide

All release functionality has been consolidated into:

```powershell
# Use the new unified release script:
./AitherRelease.ps1 -Version 1.2.3 -Message "Release description"

# Or use PatchManager's New-Release function:
Import-Module ./aither-core/modules/PatchManager -Force
New-Release -Version 1.2.3 -Message "Release description"
```

The new release process:
1. Creates a PR to update VERSION (respects branch protection)
2. Waits for CI checks to pass
3. Auto-merges the PR
4. Monitors release workflow
5. Reports when release is published

This approach ensures releases work consistently with branch protection rules and CI requirements.