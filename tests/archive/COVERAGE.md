# Code Coverage Configuration for AitherZero

This document describes the code coverage setup and usage for the AitherZero project.

## Overview

AitherZero uses Pester 5.x for testing and code coverage analysis. The project targets:
- **80% minimum overall coverage**
- **80% function coverage**
- **75% line coverage**

## Coverage Tools

### 1. Run-CodeCoverage.ps1
Comprehensive coverage analysis with multiple output formats.

```powershell
# Full codebase coverage
./tests/Run-CodeCoverage.ps1 -Scope Full -ShowDetails

# Module-specific coverage
./tests/Run-CodeCoverage.ps1 -Scope Module -Module Logging -ShowDetails

# CI mode with threshold enforcement
./tests/Run-CodeCoverage.ps1 -CI -EnforceThresholds
```

### 2. Check-Coverage.ps1
Quick coverage check for development.

```powershell
# Quick check all modules
./tests/Check-Coverage.ps1

# Check specific module with uncovered items
./tests/Check-Coverage.ps1 -Module PatchManager -ShowUncovered
```

### 3. Test Runners with Coverage

All test runners now support coverage:

```powershell
# Bulletproof validation with coverage
./tests/Run-BulletproofValidation.ps1 -CodeCoverage -EnforceCoverageThresholds

# All module tests with coverage
./tests/Run-AllModuleTests.ps1 -CodeCoverage -CoverageFormat JaCoCo

# Quick module check with coverage (adds ~10-20s)
./Quick-ModuleCheck.ps1 -IncludeCoverage
```

## Coverage Configuration

### PesterConfiguration.psd1
Located at `tests/config/PesterConfiguration.psd1`:
- Enabled by default
- Excludes test files
- Outputs JaCoCo format for CI/CD
- Targets 80% coverage

### Output Formats

1. **JaCoCo** - Primary format for CI/CD integration
2. **Cobertura** - Alternative XML format
3. **CoverageGutters** - VS Code extension support
4. **Console** - Human-readable output

## VS Code Integration

New VS Code tasks available:
- `🔬 Run Code Coverage - Full` - Complete codebase coverage
- `🔬 Run Code Coverage - Module` - Module-specific coverage
- `🔬 Quick Coverage Check` - Fast coverage analysis
- `🔬 Coverage with Enforcement` - Fails if below thresholds
- `📊 All Module Tests with Coverage` - All tests with coverage
- `🛡️ Bulletproof Validation with Coverage` - Validation with coverage

Access via: `Ctrl+Shift+P → Tasks: Run Task`

## CI/CD Integration

### GitHub Actions
The `.github/workflows/code-coverage.yml` workflow:
- Runs on main/develop branches and PRs
- Enforces coverage thresholds
- Uploads to Codecov
- Comments on PRs with coverage changes

### Local CI Mode
```powershell
# Simulate CI coverage check
./tests/Run-CodeCoverage.ps1 -CI -EnforceThresholds -OutputFormat JaCoCo,Cobertura
```

## Coverage Reports

Reports are generated in `tests/results/`:
- `coverage.jacoco` - JaCoCo XML format
- `coverage.cobertura` - Cobertura XML format
- `coverage.coveragegutters` - VS Code extension format

## Viewing Coverage

### Console Output
Default output shows:
- Overall coverage percentage
- Commands analyzed/executed/missed
- Per-file breakdown (with -ShowDetails)

### VS Code
Install the "Coverage Gutters" extension to visualize coverage inline:
1. Run coverage with CoverageGutters format
2. Use `Ctrl+Shift+7` to toggle coverage display

### Web Reports
Use ReportGenerator for HTML reports:
```powershell
# Install ReportGenerator
dotnet tool install -g dotnet-reportgenerator-globaltool

# Generate HTML report
reportgenerator -reports:tests/results/coverage.cobertura -targetdir:tests/results/coverage-html
```

## Best Practices

1. **Before Commits**: Run quick coverage check
   ```powershell
   ./tests/Check-Coverage.ps1 -Quick
   ```

2. **Before PRs**: Run standard validation with coverage
   ```powershell
   ./tests/Run-BulletproofValidation.ps1 -ValidationLevel Standard -CodeCoverage
   ```

3. **Module Development**: Check module coverage frequently
   ```powershell
   ./tests/Run-CodeCoverage.ps1 -Module YourModule -ShowDetails
   ```

4. **CI/CD**: Always enforce thresholds
   ```powershell
   ./tests/Run-CodeCoverage.ps1 -CI -EnforceThresholds
   ```

## Troubleshooting

### Coverage Not Working
1. Ensure Pester 5.x is installed: `Install-Module Pester -MinimumVersion 5.0`
2. Check PowerShell version: `$PSVersionTable` (requires 7.0+)
3. Verify test files exist and pass

### Performance Issues
- Use `-Quick` flag for faster results
- Disable coverage for rapid testing: Run tests without `-CodeCoverage`
- Use module-specific coverage instead of full coverage

### Incorrect Coverage
- Ensure all source files use `.ps1` extension
- Check that test files are excluded (`ExcludeTests = $true`)
- Verify coverage paths in configuration