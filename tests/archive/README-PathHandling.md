# Path Handling in AitherZero Test Infrastructure

## Overview

This document explains the cross-platform path handling approach used in the AitherZero test coverage infrastructure.

## Path Resolution Strategy

### ✅ **Proper Patterns Used**

#### 1. PowerShell Scripts (Dynamic Path Resolution)
All PowerShell scripts use the established project pattern:

```powershell
# ✅ CORRECT: Dynamic path resolution
. "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot
$modulePath = Join-Path $projectRoot 'aither-core' 'modules' $ModuleName
```

**Files using this pattern:**
- `tests/Run-CodeCoverage.ps1`
- `tests/Check-Coverage.ps1`
- `tests/config/New-PesterConfiguration.ps1`
- `tests/unit/modules/CoreApp/AitherCore.Tests.ps1`

#### 2. Static Configuration Files (Documented Assumptions)
Configuration files that must use static paths are clearly documented:

```powershell
# NOTE: This configuration assumes execution from the project root directory.
# For dynamic path resolution, use New-PesterConfiguration.ps1 instead.
```

**Files using this pattern:**
- `tests/config/PesterConfiguration.psd1`

#### 3. CI/CD Workflows (Relative Paths with Validation)
GitHub Actions workflows use relative paths with validation:

```yaml
# Ensure we're in the project root
Write-Host "Working directory: $(Get-Location)"
./tests/Run-CodeCoverage.ps1 -Scope Full
```

**Files using this pattern:**
- `.github/workflows/code-coverage.yml`

### ❌ **Patterns to Avoid**

#### Hardcoded Absolute Paths
```powershell
# ❌ WRONG: Platform/environment specific
$path = "/workspaces/AitherZero/tests/results"
$path = "C:\AitherZero\tests\results"
```

#### Hardcoded Relative Paths in Scripts
```powershell
# ❌ WRONG: Assumes specific working directory
$resultsPath = "tests/results"  # Without using Find-ProjectRoot
```

## Alternative Solutions

### Dynamic Configuration Generator
For cases where static configuration is insufficient, use the dynamic generator:

```powershell
# Generate configuration with proper paths
$config = & "$projectRoot/tests/config/New-PesterConfiguration.ps1" -BulletproofMode
```

### Environment-Aware Path Building
```powershell
# Build paths that work across environments
$testPaths = @(
    Join-Path $projectRoot 'tests' 'unit',
    Join-Path $projectRoot 'tests' 'integration'
)
```

## Validation

### Manual Testing
```powershell
# Test from different working directories
cd /tmp
pwsh /path/to/AitherZero/tests/Run-CodeCoverage.ps1 -Module Logging

cd /home/user
pwsh /path/to/AitherZero/tests/Check-Coverage.ps1 -Quick
```

### Automated Testing
The CI/CD pipeline validates path handling across different environments automatically.

## Key Benefits

1. **Cross-Platform Compatibility**: Works on Windows, Linux, and macOS
2. **Environment Independence**: Works regardless of installation location
3. **Developer Flexibility**: Works from any working directory
4. **CI/CD Reliability**: Consistent behavior in automated environments

## Migration Guide

If you find hardcoded paths in existing files:

1. **PowerShell Scripts**: Add `Find-ProjectRoot` and use `Join-Path`
2. **Configuration Files**: Document assumptions or use dynamic generators
3. **Tests**: Use `$PSScriptRoot` for relative positioning
4. **CI/CD**: Use relative paths with validation

This approach ensures the test infrastructure remains portable and reliable across different development environments and deployment scenarios.