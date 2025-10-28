# Quality Validation Quick Reference

Quick reference guide for AitherZero quality validation system.

## 🚀 Quick Start

### Validate a File
```powershell
./automation-scripts/0420_Validate-ComponentQuality.ps1 -Path ./MyModule.psm1
```

### Validate Directory
```powershell
./automation-scripts/0420_Validate-ComponentQuality.ps1 -Path ./domains/testing -Recursive
```

## ✅ Quality Checklist

Before submitting a PR, ensure your code meets these requirements:

### Error Handling
- [ ] Set `$ErrorActionPreference = 'Stop'`
- [ ] Wrap risky operations in try/catch
- [ ] Log errors in catch blocks
- [ ] Use finally for cleanup

### Logging
- [ ] Add logging at key points
- [ ] Use different log levels (Info, Warning, Error)
- [ ] Log function entry/exit for complex functions
- [ ] Include relevant context in log messages

### Testing
- [ ] Create `.Tests.ps1` file
- [ ] Add at least 3 test cases
- [ ] Test success and failure scenarios
- [ ] Ensure tests pass locally

### Documentation
- [ ] Add `.SYNOPSIS`
- [ ] Add `.DESCRIPTION`
- [ ] Document all parameters
- [ ] Include usage examples
- [ ] Use `[CmdletBinding()]`

### Code Quality
- [ ] Run PSScriptAnalyzer
- [ ] Fix all errors
- [ ] Address warnings
- [ ] Use approved verbs

## 📊 Scoring

| Score | Status | Action |
|-------|--------|--------|
| 90-100 | ✅ Passed | Good to merge |
| 70-89 | ⚠️ Warning | Review findings |
| 0-69 | ❌ Failed | Must fix |

**Minimum Required Score**: 70%

## 🛠️ Common Fixes

### "No error handling"
```powershell
$ErrorActionPreference = 'Stop'
try {
    # Your code
} catch {
    Write-CustomLog -Level Error -Message "Failed: $_"
    throw
}
```

### "No logging"
```powershell
Write-CustomLog -Level Information -Message "Starting operation"
# Your code
Write-CustomLog -Level Information -Message "Operation completed"
```

### "No test file"
```powershell
# Create tests/domains/{domain}/MyModule.Tests.ps1
Describe "MyModule" {
    It "Should work" {
        $result = Invoke-MyFunction
        $result | Should -Not -BeNullOrEmpty
    }
}
```

### "Missing help"
```powershell
<#
.SYNOPSIS
    Brief description
.DESCRIPTION
    Detailed description
.PARAMETER Name
    Description
.EXAMPLE
    ./MyScript.ps1 -Name "test"
#>
```

## 🔧 Parameters

### Basic Validation
```powershell
-Path <string>           # File or directory to validate
-Recursive               # Validate subdirectories
-Format <Text|HTML|JSON> # Report format
```

### Advanced Options
```powershell
-SkipChecks <string[]>   # Skip specific checks
-FailOnWarnings          # Treat warnings as failures
-MinimumScore <int>      # Custom minimum score (default: 70)
-OutputPath <string>     # Custom report location
```

## 📂 Report Locations

- **Local**: `./reports/quality/`
- **CI/CD**: Workflow artifacts
- **PR**: Inline comments

## 🔍 CI/CD Integration

Quality validation runs automatically on:
- Pull requests (modified PowerShell files)
- Manual workflow dispatch

View results in:
- PR comments
- GitHub Actions workflow logs
- Downloadable artifacts

## 🆘 Need Help?

- Full documentation: `docs/QUALITY-STANDARDS.md`
- Open an issue for bugs
- Use discussions for questions

---

**Quick Links**:
- [Full Documentation](./QUALITY-STANDARDS.md)
- [Contributing Guide](../CONTRIBUTING.md)
- [Module Reference](../domains/testing/QualityValidator.psm1)
