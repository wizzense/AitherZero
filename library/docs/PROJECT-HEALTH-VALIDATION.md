# Project Health Validation Guide

## Overview

This document explains how to run the same validation checks locally that GitHub Actions runs in CI/CD pipelines.

## Quick Start

### Option 1: Run Complete Health Check (Recommended)

```powershell
# Run comprehensive health check matching all GitHub Actions workflows
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook project-health-check
```

**Duration**: 15-30 minutes  
**Checks**: Syntax, Code Quality, Component Quality, Unit Tests, Integration Tests, Config Validation, Test Coverage, Project Report

### Option 2: Run Individual Checks

```powershell
# 1. Syntax Validation (matches quick-health-check.yml)
./library/automation-scripts/0407_Validate-Syntax.ps1 -All
# Duration: ~2 seconds
# Validates: PowerShell syntax for all 505 files

# 2. Code Quality (matches pr-validation.yml)  
./library/automation-scripts/0404_Run-PSScriptAnalyzer.ps1
# Duration: ~60-90 seconds
# Validates: PSScriptAnalyzer rules for all PowerShell files

# 3. Component Quality (matches quality-validation.yml)
./library/automation-scripts/0420_Validate-ComponentQuality.ps1 -Path ./domains -Recursive
# Duration: ~2-5 minutes
# Validates: Error handling, logging, tests, UI integration

# 4. Unit Tests (matches parallel-testing.yml)
./library/automation-scripts/0402_Run-UnitTests.ps1
# Duration: ~45-60 seconds
# Runs: All Pester unit tests

# 5. Integration Tests
./library/automation-scripts/0403_Run-IntegrationTests.ps1
# Duration: ~2-3 minutes
# Runs: Integration test suites

# 6. Config Validation
./library/automation-scripts/0413_Validate-ConfigManifest.ps1
# Duration: ~5 seconds
# Validates: config.psd1 structure and integrity

# 7. Test Coverage Check
./library/automation-scripts/0426_Validate-TestScriptSync.ps1
# Duration: ~10 seconds
# Validates: All automation scripts have corresponding tests

# 8. Project Report
./library/automation-scripts/0510_Generate-ProjectReport.ps1 -ShowAll
# Duration: ~30 seconds
# Generates: Comprehensive project statistics and health metrics
```

### Option 3: Use Global Wrapper (After Bootstrap)

```powershell
# After running bootstrap.ps1, you can use the 'aitherzero' command
aitherzero orchestrate project-health-check

# Or run individual scripts
aitherzero 0407 -All          # Syntax
aitherzero 0404               # Code quality
aitherzero 0420 -Path ./domains  # Component quality
aitherzero 0402               # Unit tests
aitherzero 0403               # Integration tests
```

## GitHub Actions Workflows Mapped

| Workflow | Local Equivalent | Scripts Used |
|----------|------------------|--------------|
| ⚡ quick-health-check.yml | Syntax Validation | 0407 |
| ✅ pr-validation.yml | Code Quality | 0407, 0402 |
| 🎯 quality-validation.yml | Component Quality | 0420 |
| 🧪 parallel-testing.yml | Unit & Integration Tests | 0402, 0403, 0404, 0407 |
| 📊 publish-test-reports.yml | Project Report | 0402, 0404, 0420, 0510 |

## Validation Stages

### Stage 1: Syntax Validation ✓ Required
- **Script**: 0407_Validate-Syntax.ps1
- **Purpose**: Validates PowerShell syntax for all .ps1, .psm1, .psd1 files
- **Duration**: ~2 seconds
- **Pass Criteria**: Zero syntax errors

### Stage 2: Code Quality Analysis ✓ Required
- **Script**: 0404_Run-PSScriptAnalyzer.ps1
- **Purpose**: Runs PSScriptAnalyzer linting rules
- **Duration**: ~60-90 seconds
- **Pass Criteria**: No critical errors (warnings acceptable)

### Stage 3: Component Quality ○ Optional
- **Script**: 0420_Validate-ComponentQuality.ps1
- **Purpose**: Validates error handling, logging, tests, UI integration
- **Duration**: ~2-5 minutes
- **Pass Criteria**: Component health checks pass

### Stage 4: Unit Tests ✓ Required
- **Script**: 0402_Run-UnitTests.ps1
- **Purpose**: Runs all Pester unit tests
- **Duration**: ~45-60 seconds
- **Pass Criteria**: All tests pass (known failures documented)

### Stage 5: Integration Tests ○ Optional
- **Script**: 0403_Run-IntegrationTests.ps1
- **Purpose**: Runs integration test suites
- **Duration**: ~2-3 minutes
- **Pass Criteria**: Integration tests pass

### Stage 6: Configuration Validation ✓ Required
- **Script**: 0413_Validate-ConfigManifest.ps1
- **Purpose**: Validates config.psd1 structure and integrity
- **Duration**: ~5 seconds
- **Pass Criteria**: Config manifest is valid

### Stage 7: Test Coverage ○ Optional
- **Script**: 0426_Validate-TestScriptSync.ps1
- **Purpose**: Ensures all automation scripts have tests
- **Duration**: ~10 seconds
- **Pass Criteria**: Test-script synchronization validated

### Stage 8: Project Report ○ Optional
- **Script**: 0510_Generate-ProjectReport.ps1
- **Purpose**: Generates comprehensive project health report
- **Duration**: ~30 seconds
- **Pass Criteria**: Report generated successfully

## Best Practices

### Before Committing Changes

```powershell
# Quick validation (< 2 minutes)
./library/automation-scripts/0407_Validate-Syntax.ps1 -All
./library/automation-scripts/0404_Run-PSScriptAnalyzer.ps1

# If you modified tests or core functionality
./library/automation-scripts/0402_Run-UnitTests.ps1
```

### Before Creating a PR

```powershell
# Full validation (15-30 minutes)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook project-health-check

# Or use fast PR validation
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook pr-validation-fast
```

### After Fixing Issues

```powershell
# Re-run specific checks
./library/automation-scripts/0407_Validate-Syntax.ps1 -All

# Or re-run full health check
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook project-health-check
```

## Interpreting Results

### Success Indicators
- ✓ All required stages pass
- ○ Optional stages provide additional insights
- Zero syntax errors
- PSScriptAnalyzer warnings < 100
- All unit tests pass

### Common Issues

**Syntax Errors**
```
Solution: Fix PowerShell syntax errors in reported files
Tool: Use VS Code with PowerShell extension for immediate feedback
```

**PSScriptAnalyzer Warnings**
```
Solution: Address high-priority issues (errors and warnings)
Info: Informational issues can be addressed over time
```

**Test Failures**
```
Solution: Fix failing tests or update tests if behavior changed intentionally
Known: Some tests may have documented expected failures
```

**Component Quality Issues**
```
Solution: Add error handling, logging, or tests as indicated
Note: These are recommendations for improvement
```

## Continuous Integration

The project-health-check playbook matches the validation performed by GitHub Actions:

- **On PR**: quick-health-check.yml, pr-validation.yml
- **On Merge**: quality-validation.yml, parallel-testing.yml
- **Scheduled**: Full test suite with reports

Running the playbook locally ensures your changes will pass CI/CD validation.

## Troubleshooting

### Module Loading Issues
```powershell
# Clean and re-bootstrap
./bootstrap.ps1 -Mode Clean
./bootstrap.ps1 -Mode New -InstallProfile Minimal
```

### Playbook Not Found
```powershell
# Verify playbook exists
ls ./domains/orchestration/playbooks/project-health-check.psd1

# Load module first
Import-Module ./AitherZero.psd1 -Force
```

### Script Execution Errors
```powershell
# Check if script exists
ls ./library/automation-scripts/0407_Validate-Syntax.ps1

# Run with verbose output
./library/automation-scripts/0407_Validate-Syntax.ps1 -All -Verbose
```

## See Also

- [Orchestration Playbooks](../domains/orchestration/playbooks/README.md)
- [Testing Guide](./TESTING-README.md)
- [CI/CD Workflows](../.github/workflows/README.md)
- [Quality Validation](../library/automation-scripts/0420_Validate-ComponentQuality.ps1)
