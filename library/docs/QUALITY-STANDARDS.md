# AitherZero Quality Standards

This document defines the quality standards and validation requirements for new features and components in AitherZero.

## Table of Contents

- [Overview](#overview)
- [Quality Validation System](#quality-validation-system)
- [Quality Checks](#quality-checks)
- [Scoring System](#scoring-system)
- [Usage](#usage)
- [CI/CD Integration](#cicd-integration)
- [Best Practices](#best-practices)

## Overview

The AitherZero Quality Validation System ensures that all new features and components meet consistent quality standards before being merged into the codebase. The system performs automated checks on error handling, logging, testing, UI/CLI integration, and code quality.

## Quality Validation System

### Components

1. **QualityValidator.psm1** - Core validation module (`domains/testing/QualityValidator.psm1`)
2. **0420_Validate-ComponentQuality.ps1** - Automation script (`automation-scripts/0420_Validate-ComponentQuality.ps1`)
3. **quality-validation.yml** - GitHub Actions workflow (`.github/workflows/quality-validation.yml`)

### Automated Checks

The system automatically runs on:
- Pull requests that modify PowerShell files
- Manual workflow dispatch
- Local development (via automation script)

## Quality Checks

### 1. Error Handling Validation

**Purpose:** Ensure robust error handling throughout the codebase.

**Checks:**
- ✅ Presence of try/catch blocks around risky operations
- ✅ `$ErrorActionPreference = 'Stop'` is set
- ✅ Proper error logging in catch blocks
- ✅ Finally blocks for cleanup operations
- ✅ Error handling for common risky operations:
  - REST API calls (`Invoke-RestMethod`, `Invoke-WebRequest`)
  - File operations (`New-Item`, `Remove-Item`, `Copy-Item`, `Move-Item`)
  - Module operations (`Import-Module`, `Install-Module`)

**Example - Good:**
```powershell
$ErrorActionPreference = 'Stop'

try {
    Invoke-RestMethod -Uri "https://api.example.com/data"
    New-Item -Path "./output" -ItemType Directory -Force
} catch {
    Write-CustomLog -Level Error -Message "Operation failed: $_"
    throw
} finally {
    # Cleanup
}
```

**Example - Poor:**
```powershell
# No error handling
Invoke-RestMethod -Uri "https://api.example.com/data"
Remove-Item -Path "./temp" -Recurse -Force
```

### 2. Logging Implementation

**Purpose:** Ensure comprehensive logging for debugging and auditing.

**Checks:**
- ✅ Presence of logging statements
- ✅ Use of appropriate logging functions (`Write-CustomLog`, `Write-Verbose`, etc.)
- ✅ Logging at different levels (Information, Warning, Error)
- ✅ Logging of important operations
- ✅ Function-level logging

**Example - Good:**
```powershell
function Process-Data {
    Write-CustomLog -Level Information -Message "Starting data processing"
    
    try {
        Write-CustomLog -Level Information -Message "Fetching data from API"
        $data = Invoke-RestMethod -Uri $apiUrl
        
        Write-CustomLog -Level Information -Message "Processing $($data.Count) records"
        # Process data
        
        Write-CustomLog -Level Information -Message "Data processing completed successfully"
    } catch {
        Write-CustomLog -Level Error -Message "Data processing failed: $_"
        throw
    }
}
```

**Example - Poor:**
```powershell
function Process-Data {
    # No logging
    $data = Invoke-RestMethod -Uri $apiUrl
    return $data
}
```

### 3. Test Coverage

**Purpose:** Ensure all components have adequate test coverage.

**Checks:**
- ✅ Existence of corresponding test file (`.Tests.ps1`)
- ✅ Test file is in appropriate location:
  - Domain modules: `tests/domains/{domain}/*.Tests.ps1`
  - Automation scripts: `tests/integration/*.Tests.ps1`
  - Unit tests: `tests/unit/*.Tests.ps1`
- ✅ Adequate number of test cases (minimum 3 recommended)
- ✅ Valid test file syntax
- ✅ Use of Pester testing framework

**Expected Test Structure:**
```powershell
Describe "MyModule" {
    Context "Function1" {
        It "Should perform basic operation" {
            $result = Invoke-Function1
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle errors gracefully" {
            { Invoke-Function1 -Invalid } | Should -Throw
        }
        
        It "Should return correct type" {
            $result = Invoke-Function1
            $result.GetType().Name | Should -Be 'String'
        }
    }
}
```

### 4. UI/CLI Integration

**Purpose:** Ensure consistent user interface and command-line integration.

**Checks:**
- ✅ Presence of `[CmdletBinding()]` for advanced parameter support
- ✅ Properly defined parameters with `[Parameter()]` attribute
- ✅ Comment-based help documentation:
  - `.SYNOPSIS` - Brief description
  - `.DESCRIPTION` - Detailed description
  - `.PARAMETER` - Parameter descriptions
  - `.EXAMPLE` - Usage examples
- ✅ Integration into launcher (`Start-AitherZero.ps1`) for automation scripts

**Example - Good:**
```powershell
<#
.SYNOPSIS
    Process data from API endpoint
.DESCRIPTION
    This script fetches and processes data from the specified API endpoint.
    It supports authentication and filtering options.
.PARAMETER ApiUrl
    The URL of the API endpoint to fetch data from
.PARAMETER ApiKey
    Optional API key for authentication
.EXAMPLE
    ./Process-ApiData.ps1 -ApiUrl "https://api.example.com/data"
    Process data from the specified API endpoint
.EXAMPLE
    ./Process-ApiData.ps1 -ApiUrl "https://api.example.com/data" -ApiKey "key123"
    Process data with authentication
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ApiUrl,
    
    [Parameter()]
    [string]$ApiKey
)

# Script implementation
```

### 5. GitHub Actions Integration

**Purpose:** Ensure appropriate components are integrated into CI/CD workflows.

**Checks:**
- ✅ Testing and validation scripts (040x, 050x) are referenced in workflows
- ✅ Quality and reporting scripts are integrated appropriately
- ✅ Automation scripts are callable from CI/CD pipeline

**When Required:**
- Testing scripts (0400-0499)
- Validation scripts (0500-0599)
- Quality analysis scripts
- Reporting and metrics scripts

### 6. PSScriptAnalyzer Compliance

**Purpose:** Ensure code meets PowerShell best practices and standards.

**Checks:**
- ✅ No PSScriptAnalyzer errors
- ✅ Minimal PSScriptAnalyzer warnings
- ✅ Compliance with PSScriptAnalyzer rules defined in `PSScriptAnalyzerSettings.psd1`

**Key Rules:**
- Use approved PowerShell verbs (`Get-Verb`)
- Consistent parameter naming
- Proper use of cmdlet binding
- Consistent code formatting
- No deprecated cmdlets

## Scoring System

Each quality check is scored on a scale of 0-100:

- **0-69**: Failed (❌)
- **70-89**: Warning (⚠️)
- **90-100**: Passed (✅)

### Overall Score Calculation

The overall score is the average of all non-skipped checks. A minimum score of **70%** is required to pass.

### Score Penalties

**Error Handling:**
- -10 points: No `$ErrorActionPreference = 'Stop'`
- -15 points: No error logging in catch blocks
- -5 points per unhandled risky operation (max -30)

**Logging:**
- -15 points: Missing informational logging
- -20 points: Missing error logging
- -10 points: Some functions lack logging

**Test Coverage:**
- -100 points: No test file found
- -70 points: Test file empty or unreadable
- -70 points: No test cases
- -20 points: Fewer than 3 test cases

**UI/CLI:**
- -15 points: No `[CmdletBinding()]`
- -10 points: No parameters
- -30 points: No help documentation
- -15 points: Incomplete help (< 3 sections)

**PSScriptAnalyzer:**
- -15 points per error
- -5 points per warning

## Usage

### Local Development

#### Validate a Single File
```powershell
./automation-scripts/0420_Validate-ComponentQuality.ps1 -Path ./domains/testing/MyModule.psm1
```

#### Validate a Directory
```powershell
./automation-scripts/0420_Validate-ComponentQuality.ps1 -Path ./domains/testing -Recursive
```

#### Generate HTML Report
```powershell
./automation-scripts/0420_Validate-ComponentQuality.ps1 `
    -Path ./MyScript.ps1 `
    -Format HTML `
    -OutputPath ./reports
```

#### Skip Specific Checks
```powershell
./automation-scripts/0420_Validate-ComponentQuality.ps1 `
    -Path ./MyModule.psm1 `
    -SkipChecks @('GitHubActions', 'PSScriptAnalyzer')
```

#### Fail on Warnings
```powershell
./automation-scripts/0420_Validate-ComponentQuality.ps1 `
    -Path ./MyScript.ps1 `
    -FailOnWarnings
```

### Via AitherZero Launcher
```powershell
# Using the aitherzero wrapper
aitherzero 0420 -Path ./domains/testing/MyModule.psm1

# Or with Start-AitherZero
./Start-AitherZero.ps1 -Mode Orchestrate -Sequence 0420
```

### Programmatic Usage
```powershell
# Import the module
Import-Module ./domains/testing/QualityValidator.psm1

# Run validation
$report = Invoke-QualityValidation -Path ./MyModule.psm1

# Format and display
$report | Format-QualityReport -Format Text
```

## CI/CD Integration

### Automatic Validation

The quality validation system automatically runs on:

1. **Pull Requests** - When PowerShell files are modified
   - Validates only changed files
   - Posts results as PR comment
   - Blocks merge if validation fails

2. **Manual Trigger** - Via workflow dispatch
   - Allows specifying custom path
   - Supports recursive validation
   - Useful for validating entire domains

### Viewing Results

**In PR Comments:**
- Summary of validation results
- File-by-file breakdown with scores
- Links to detailed artifacts

**In Workflow Artifacts:**
- Detailed text reports
- JSON reports for automation
- HTML reports for viewing

### Workflow Configuration

Located in `.github/workflows/quality-validation.yml`:

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    paths:
      - 'domains/**/*.psm1'
      - 'automation-scripts/*.ps1'
  workflow_dispatch:
    inputs:
      path:
        description: 'Path to validate'
        default: './domains'
```

## Best Practices

### For New Features

1. **Write Tests First**: Create test file before implementation (TDD approach)
2. **Add Logging Early**: Include logging statements from the start
3. **Use Error Handling**: Wrap risky operations in try/catch
4. **Document Thoroughly**: Add comprehensive help documentation
5. **Run Local Validation**: Test locally before pushing

### For Code Reviews

1. **Check Quality Score**: Ensure minimum 70% score
2. **Review Findings**: Address all failed checks
3. **Consider Warnings**: Evaluate and fix warning items
4. **Verify Tests**: Ensure tests pass and provide good coverage
5. **Check Integration**: Verify UI/CLI and workflow integration

### Common Issues and Solutions

#### Issue: "No test file found"
**Solution:** Create a test file in the appropriate location:
```powershell
# For domain module
tests/domains/{domain}/MyModule.Tests.ps1

# For automation script
tests/integration/0XXX_MyScript.Tests.ps1
```

#### Issue: "No logging statements found"
**Solution:** Add logging at key points:
```powershell
Write-CustomLog -Level Information -Message "Operation started"
# ... operation ...
Write-CustomLog -Level Information -Message "Operation completed"
```

#### Issue: "PSScriptAnalyzer warnings"
**Solution:** Run PSScriptAnalyzer and fix issues:
```powershell
Invoke-ScriptAnalyzer -Path ./MyScript.ps1
```

#### Issue: "Missing help documentation"
**Solution:** Add comment-based help at the top of the script:
```powershell
<#
.SYNOPSIS
    Brief description
.DESCRIPTION
    Detailed description
.PARAMETER Name
    Parameter description
.EXAMPLE
    Usage example
#>
```

## Continuous Improvement

The quality standards are living documentation. As the project evolves:

1. **Regular Reviews**: Periodically review and update standards
2. **Community Feedback**: Incorporate suggestions from contributors
3. **Tooling Updates**: Keep validation tools up to date
4. **Best Practices**: Adopt new PowerShell best practices
5. **Metrics Analysis**: Use quality metrics to identify improvement areas

## Questions and Support

- **Issues**: Open a GitHub issue for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Contributing**: See `CONTRIBUTING.md` for contribution guidelines

---

**Last Updated**: October 2025  
**Version**: 1.0.0
