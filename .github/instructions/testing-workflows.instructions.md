---
applyTo: "**/*.Tests.ps1"
description: "Testing workflows and bulletproof testing patterns"
---

# Testing Workflows & Bulletproof Testing Instructions

This file provides comprehensive guidance for running tests and ensuring bulletproof operation without manual testing.

## Core Testing Commands

### Bulletproof Test Suite
Use `Run-BulletproofTests.ps1` for comprehensive validation:

```powershell
# Run all bulletproof tests with detailed reporting
pwsh -File "./tests/Run-BulletproofTests.ps1" -TestSuite "All" -LogLevel "Detailed" -GenerateReport

# CI/CD friendly execution
pwsh -File "./tests/Run-BulletproofTests.ps1" -TestSuite "Unit" -CI -GenerateReport

# Focus on specific components
pwsh -File "./tests/Run-BulletproofTests.ps1" -TestSuite "Integration" -LogLevel "Verbose"
```

### Module-Specific Testing
Use `Run-AllModuleTests.ps1` for comprehensive module validation:

```powershell
# Test all modules in parallel
pwsh -File "./tests/Run-AllModuleTests.ps1" -Parallel -OutputFormat "NUnitXml"

# Test specific module
pwsh -File "./tests/Run-AllModuleTests.ps1" -ModuleName "LabRunner" -TestType "Unit"

# Generate coverage reports
pwsh -File "./tests/Run-AllModuleTests.ps1" -TestType "All" -OutputFile "./tests/results/coverage-report.xml"
```

### Non-Interactive Testing
Use specialized scripts for non-interactive validation:

```powershell
# Test core-runner non-interactive modes
pwsh -File "./test-noninteractive-fix.ps1" -TestMode "All"

# Test specific scenarios
pwsh -File "./test-noninteractive-fix.ps1" -TestMode "Auto"
pwsh -File "./test-noninteractive-fix.ps1" -TestMode "Scripts"
```

## VS Code Tasks for Testing

Use these VS Code tasks for common testing workflows:

### Quick Testing Tasks
- **Ctrl+Shift+P → Tasks: Run Task → "Run All Pester Tests"**
- **Ctrl+Shift+P → Tasks: Run Task → "Run Bulletproof Tests"**
- **Ctrl+Shift+P → Tasks: Run Task → "Test Non-Interactive Mode"**

### Module Testing Tasks
- **Ctrl+Shift+P → Tasks: Run Task → "Test Current Module"**
- **Ctrl+Shift+P → Tasks: Run Task → "Validate All Modules"**
- **Ctrl+Shift+P → Tasks: Run Task → "Generate Test Coverage"**

### CI/CD Testing Tasks
- **Ctrl+Shift+P → Tasks: Run Task → "CI: Full Test Suite"**
- **Ctrl+Shift+P → Tasks: Run Task → "CI: Quick Validation"**

## Bulletproof Testing Patterns

### 1. Core-Runner Validation
Always test core-runner in all modes:

```powershell
# Test basic non-interactive mode
$result = & "./aither-core/aither-core.ps1" -NonInteractive -Verbosity silent
if ($LASTEXITCODE -ne 0) { throw "Core-runner failed in non-interactive mode" }

# Test auto mode with WhatIf
$result = & "./aither-core/aither-core.ps1" -NonInteractive -Auto -WhatIf -Verbosity detailed
if ($LASTEXITCODE -ne 0) { throw "Core-runner failed in auto mode" }

# Test specific scripts
$result = & "./aither-core/aither-core.ps1" -NonInteractive -Scripts "0200_Get-SystemInfo" -WhatIf
if ($LASTEXITCODE -ne 0) { throw "Core-runner failed with specific scripts" }
```

### 2. Module Import Validation
Test module imports comprehensively:

```powershell
# Test all modules can be imported
Get-ChildItem "aither-core/modules" -Directory | ForEach-Object {
    try {
        Import-Module $_.FullName -Force -ErrorAction Stop
        Write-Host "✓ Successfully imported: $($_.Name)" -ForegroundColor Green
    } catch {
        throw "Failed to import module: $($_.Name) - $($_.Exception.Message)"
    }
}
```

### 3. Configuration Validation
Test all configuration files:

```powershell
# Validate JSON configurations
Get-ChildItem "configs" -Filter "*.json" | ForEach-Object {
    try {
        $config = Get-Content $_.FullName -Raw | ConvertFrom-Json
        Write-Host "✓ Valid JSON: $($_.Name)" -ForegroundColor Green
    } catch {
        throw "Invalid JSON in: $($_.Name) - $($_.Exception.Message)"
    }
}
```

### 4. Script Syntax Validation
Validate all PowerShell scripts:

```powershell
# Check script syntax
Get-ChildItem -Recurse -Filter "*.ps1" | ForEach-Object {
    $errors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)

    if ($errors.Count -gt 0) {
        throw "Syntax errors in: $($_.FullName) - $($errors -join '; ')"
    }
}
```

## Test Result Analysis

### Log File Locations
Tests generate logs in these locations:

- **Pester Results**: `tests/results/TestResults.xml`
- **Coverage Reports**: `tests/results/coverage.xml`
- **Bulletproof Test Logs**: `tests/results/bulletproof-{date}.log`
- **Module Test Results**: `tests/results/module-tests-{date}.xml`
- **Non-Interactive Test Logs**: `logs/non-interactive-tests-{date}.log`

### Result Validation Patterns

```powershell
# Check test results programmatically
$testResults = Import-Clixml "tests/results/TestResults.xml"
if ($testResults.Failed.Count -gt 0) {
    Write-Error "Tests failed: $($testResults.Failed.Count) failures"
    $testResults.Failed | ForEach-Object { Write-Error $_.Exception.Message }
    exit 1
}

# Validate coverage thresholds
$coverage = [xml](Get-Content "tests/results/coverage.xml")
$coveragePercent = [double]$coverage.coverage.'line-rate' * 100
if ($coveragePercent -lt 80) {
    Write-Warning "Coverage below threshold: $coveragePercent%"
}
```

## Continuous Integration Patterns

### Pre-Commit Testing
Run these before any commit:

```powershell
# Quick validation suite
pwsh -File "./tests/Run-BulletproofTests.ps1" -TestSuite "Unit" -CI
pwsh -File "./test-noninteractive-fix.ps1" -TestMode "Basic"

# Syntax validation
pwsh -Command "Invoke-ScriptAnalyzer -Path . -Recurse -Settings './core-runner/PSScriptAnalyzerSettings.psd1'"
```

### Pre-Push Testing
Run these before pushing changes:

```powershell
# Full test suite
pwsh -File "./tests/Run-BulletproofTests.ps1" -TestSuite "All" -GenerateReport
pwsh -File "./tests/Run-AllModuleTests.ps1" -Parallel
pwsh -File "./test-noninteractive-fix.ps1" -TestMode "All"
```

### Deployment Validation
Run these before any deployment:

```powershell
# Complete validation
pwsh -File "./tests/Run-BulletproofTests.ps1" -TestSuite "All" -CI -GenerateReport
pwsh -File "./tests/Run-AllModuleTests.ps1" -TestType "All" -Parallel

# Core functionality validation
& "./aither-core/aither-core.ps1" -NonInteractive -Auto -WhatIf -Verbosity detailed
if ($LASTEXITCODE -ne 0) { throw "Core-runner validation failed" }
```

## Error Handling in Tests

### Robust Error Capture
Always capture comprehensive error information:

```powershell
try {
    # Test operation
    $result = Invoke-SomeOperation
} catch {
    $errorInfo = @{
        Exception = $_.Exception.Message
        ScriptStackTrace = $_.ScriptStackTrace
        CategoryInfo = $_.CategoryInfo.ToString()
        FullyQualifiedErrorId = $_.FullyQualifiedErrorId
        Timestamp = Get-Date
    }

    # Log error details
    $errorInfo | ConvertTo-Json | Add-Content "logs/test-errors.json"
    throw "Test failed: $($_.Exception.Message)"
}
```

### Test Environment Cleanup
Always clean up test environments:

```powershell
try {
    # Run tests
} finally {
    # Cleanup
    Remove-Item "temp-test-*" -Force -Recurse -ErrorAction SilentlyContinue
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue

    # Reset modules
    Get-Module | Where-Object { $_.Name -like "*Test*" } | Remove-Module -Force
}
```

## Performance Testing

### Execution Time Monitoring
Track test execution times:

```powershell
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    # Run tests
    pwsh -File "./tests/Run-BulletproofTests.ps1" -TestSuite "All"
} finally {
    $stopwatch.Stop()
    Write-Host "Test execution time: $($stopwatch.Elapsed)" -ForegroundColor Cyan

    # Log performance data
    @{
        TestSuite = "Bulletproof"
        Duration = $stopwatch.Elapsed.ToString()
        Timestamp = Get-Date
    } | ConvertTo-Json | Add-Content "logs/test-performance.json"
}
```
