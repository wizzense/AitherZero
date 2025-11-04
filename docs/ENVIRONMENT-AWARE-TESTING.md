# Environment-Aware Testing in AitherZero

This guide explains how to use AitherZero's environment-aware testing features to create tests that adapt automatically to CI vs local execution environments.

## Overview

Environment-aware testing allows your tests to:
- Detect if they're running in CI (GitHub Actions, GitLab CI, etc.) or locally
- Adjust timeouts based on environment (CI gets 2x timeout)
- Skip tests conditionally based on environment
- Use appropriate resource paths for temp files, caching, and logs
- Configure test behavior automatically based on environment

## Quick Start

### 1. Import Test Helpers

```powershell
BeforeAll {
    # Import test helpers
    $testHelpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "TestHelpers.psm1"
    Import-Module $testHelpersPath -Force
    
    # Get environment context
    $script:TestEnv = Get-TestEnvironment
}
```

### 2. Use Environment Detection

```powershell
It 'Should behave differently in CI' {
    if ($script:TestEnv.IsCI) {
        # CI-specific assertions
        Write-Host "Running in CI: $($script:TestEnv.CIProvider)"
    } else {
        # Local-specific assertions
        Write-Host "Running locally"
    }
}
```

## Available Functions

### Core Detection Functions

#### `Test-IsCI`
Returns `$true` if running in a CI/CD environment.

Detects:
- GitHub Actions
- GitLab CI
- Azure Pipelines
- Jenkins
- Travis CI
- AppVeyor
- CircleCI
- TeamCity
- AitherZero CI (custom flag)

```powershell
if (Test-IsCI) {
    # CI-specific logic
}
```

#### `Get-TestEnvironment`
Returns comprehensive environment information.

```powershell
$env = Get-TestEnvironment

# Available properties:
$env.IsCI                      # Boolean: True in CI
$env.IsLocal                   # Boolean: True when not in CI
$env.CIProvider                # String: Name of CI provider or 'Local'
$env.Platform                  # String: 'Windows', 'Linux', or 'macOS'
$env.PowerShellVersion         # Version: PowerShell version object
$env.IsTestMode                # Boolean: True if AITHERZERO_TEST_MODE is set
$env.HasInteractiveConsole     # Boolean: True if interactive console available
$env.ParallelizationSupported  # Boolean: True if parallelization is supported
$env.ProjectRoot               # String: Path to project root
```

#### `Get-CIProvider`
Returns the name of the CI provider or 'Local'.

```powershell
$provider = Get-CIProvider
# Returns: 'GitHubActions', 'GitLabCI', 'AzurePipelines', 'Jenkins', 'TravisCI', 
#          'AppVeyor', 'CircleCI', 'TeamCity', 'AitherZeroCI', or 'Local'
```

### Timeout Functions

#### `Get-TestTimeout`
Returns environment-appropriate timeout values (2x in CI).

```powershell
$timeout = Get-TestTimeout -Operation 'Medium'
# Returns: 120 seconds locally, 240 seconds in CI

# Available operations:
# - 'Short': 30s local, 60s CI
# - 'Medium': 120s local, 240s CI
# - 'Long': 300s local, 600s CI
# - 'VeryLong': 600s local, 1200s CI
```

### Conditional Execution

#### Runtime Skip Pattern
Use `Set-ItResult -Skipped` for runtime conditional execution:

```powershell
It 'Should only run in CI' {
    if (-not $script:TestEnv.IsCI) {
        Set-ItResult -Skipped -Because "CI-only validation"
        return
    }
    
    # Test logic that only runs in CI
}

It 'Should only run locally' {
    if ($script:TestEnv.IsCI) {
        Set-ItResult -Skipped -Because "Requires interactive console"
        return
    }
    
    # Test logic that only runs locally
}
```

### Resource Path Functions

#### `Get-TestResourcePath`
Returns environment-appropriate paths for test resources.

```powershell
# Temp directory (cross-platform)
$tempPath = Get-TestResourcePath -ResourceType 'TempDir'
# CI: $env:RUNNER_TEMP or /tmp
# Local: $env:TEMP or /tmp

# Test data directory
$dataPath = Get-TestResourcePath -ResourceType 'TestData'
# Returns: {ProjectRoot}/tests/data

# Output directory (segregated by environment)
$outputPath = Get-TestResourcePath -ResourceType 'Output'
# CI: {ProjectRoot}/tests/results/ci
# Local: {ProjectRoot}/tests/results/local

# Cache directory
$cachePath = Get-TestResourcePath -ResourceType 'Cache'
# CI: {RunnerTemp}/test-cache
# Local: {ProjectRoot}/.cache/tests

# Log directory (segregated by environment)
$logPath = Get-TestResourcePath -ResourceType 'Logs'
# CI: {ProjectRoot}/logs/ci-tests
# Local: {ProjectRoot}/logs/local-tests
```

### Configuration Functions

#### `New-TestConfiguration`
Creates environment-adaptive test configuration.

```powershell
$config = New-TestConfiguration

# Configuration automatically adapts:
# CI:
#   - Environment: 'CI'
#   - MaxConcurrency: 1 (sequential)
#   - CoverageEnabled: true
#   - Logging.Level: 'Information'
# Local:
#   - Environment: 'Test'
#   - MaxConcurrency: 2 (parallel)
#   - CoverageEnabled: false
#   - Logging.Level: 'Debug'

# Access environment info:
$config.Environment.IsCI        # Boolean
$config.Environment.Platform    # String
$config.Environment.CIProvider  # String
$config.Testing.Timeouts.Short  # Integer (seconds)
```

## Best Practices

### 1. Always Detect Environment First

```powershell
BeforeAll {
    Import-Module $testHelpersPath -Force
    $script:TestEnv = Get-TestEnvironment
}
```

### 2. Use Appropriate Timeouts

```powershell
It 'Should complete within timeout' {
    $timeout = Get-TestTimeout -Operation 'Medium'
    $result = Invoke-SomeOperation -TimeoutSeconds $timeout
    $result | Should -Not -BeNullOrEmpty
}
```

### 3. Segregate Test Artifacts

```powershell
BeforeAll {
    # Use environment-specific output paths
    $script:OutputPath = Get-TestResourcePath -ResourceType 'Output'
    New-Item -Path $script:OutputPath -ItemType Directory -Force | Out-Null
}

It 'Should save results to environment-specific path' {
    $resultFile = Join-Path $script:OutputPath 'test-results.json'
    $data | ConvertTo-Json | Set-Content $resultFile
    Test-Path $resultFile | Should -Be $true
}
```

### 4. Conditional Test Logic

```powershell
It 'Should adapt validation to environment' {
    if ($script:TestEnv.IsCI) {
        # Stricter validation in CI
        $result.ErrorCount | Should -Be 0
    } else {
        # More lenient locally for development
        $result.ErrorCount | Should -BeLessOrEqual 5
    }
}
```

### 5. Use Runtime Skip for Environment-Specific Tests

```powershell
It 'Should test interactive features' {
    # Skip if no interactive console
    if (-not $script:TestEnv.HasInteractiveConsole) {
        Set-ItResult -Skipped -Because "Requires interactive console"
        return
    }
    
    # Test interactive features
}
```

## Auto-Generated Tests

The test generator (`AutoTestGenerator.psm1`) automatically creates environment-aware tests. All tests generated by `0950_Generate-AllTests.ps1` include:

1. TestHelpers import
2. Environment detection in BeforeAll
3. Environment Awareness context with:
   - Environment detection validation
   - CI-specific tests (skipped locally)
   - Local-specific tests (skipped in CI)

### Regenerating Tests

```powershell
# Regenerate a single test with environment awareness
./automation-scripts/0950_Generate-AllTests.ps1 -Mode Quick

# Force regenerate all tests
./automation-scripts/0950_Generate-AllTests.ps1 -Mode Full -Force
```

## Bootstrap Enhancements

The bootstrap script (`bootstrap.ps1`) now includes:

- Automatic CI environment detection
- CI-specific dependency installation logic
- Enhanced logging with environment context
- Better platform and package manager detection
- Optional dependency tracking (Pester, PSScriptAnalyzer)

### CI-Specific Bootstrap Behavior

In CI environments, bootstrap automatically:
- Installs missing dependencies without prompting
- Uses Full profile by default
- Logs detailed environment information
- Provides CI-specific error messages

```powershell
# In CI (automatic)
./bootstrap.ps1 -Mode New

# Force CI behavior locally
$env:CI = 'true'
./bootstrap.ps1 -Mode New
```

## Examples

See `tests/unit/EnvironmentAwareTest.Example.Tests.ps1` for comprehensive examples of all environment-aware testing features.

Run the examples:
```powershell
Invoke-Pester -Path ./tests/unit/EnvironmentAwareTest.Example.Tests.ps1 -Output Detailed
```

## Troubleshooting

### TestHelpers Not Found

If functions aren't available, ensure TestHelpers is imported:

```powershell
BeforeAll {
    $testHelpersPath = Join-Path $PSScriptRoot '..' 'TestHelpers.psm1'
    if (-not (Test-Path $testHelpersPath)) {
        $testHelpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'TestHelpers.psm1'
    }
    Import-Module $testHelpersPath -Force
}
```

### CI Not Detected

Verify environment variables:
```powershell
Write-Host "CI: $env:CI"
Write-Host "GITHUB_ACTIONS: $env:GITHUB_ACTIONS"
Write-Host "TF_BUILD: $env:TF_BUILD"
```

Set manually for testing:
```powershell
$env:CI = 'true'
$env:GITHUB_ACTIONS = 'true'
```

### Timeouts Too Short in CI

Increase timeout multiplier or use longer operation type:
```powershell
$timeout = Get-TestTimeout -Operation 'Long'  # 5 minutes local, 10 minutes CI
```

## Contributing

When adding new tests:
1. Always use environment-aware patterns
2. Import TestHelpers in BeforeAll
3. Use Get-TestEnvironment for context
4. Use appropriate timeouts
5. Segregate test artifacts by environment

## See Also

- `tests/TestHelpers.psm1` - Test helper functions
- `tests/unit/EnvironmentAwareTest.Example.Tests.ps1` - Comprehensive examples
- `domains/testing/AutoTestGenerator.psm1` - Test generation with environment awareness
- `bootstrap.ps1` - Bootstrap with CI detection
