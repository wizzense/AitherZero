---
name: Code Quality Violation
about: Report PSScriptAnalyzer violations or code quality issues
title: '[QUALITY] '
labels: code-quality, psscriptanalyzer
assignees: ''

---

## Violation Summary
<!-- Brief description of the code quality issue -->

## PSScriptAnalyzer Results
```powershell
# Command used
seq 0404  # or Invoke-ScriptAnalyzer command

# Violations found
RuleName                            Severity     ScriptName           Line
--------                            --------     ----------           ----
PSAvoidEmptyCatchBlock              Warning      Module.psm1          45
PSUseDeclaredVarsMoreThanAssignments Warning     Script.ps1           120
```

## Violation Details

### Rule: <!-- PSScriptAnalyzer Rule Name -->
**Severity:** <!-- Error/Warning/Information -->
**File:** <!-- Full path to file -->
**Line:** <!-- Line number -->
**Message:** <!-- Full violation message -->

### Code Context
```powershell
# Line numbers and surrounding code
43: try {
44:     Import-Module $module
45: } catch { }  # <-- Violation here
46: 
```

## Statistics
- **Total Violations:** <!-- Number -->
- **Errors:** <!-- Number -->
- **Warnings:** <!-- Number -->
- **Information:** <!-- Number -->

## Affected Files
<!-- List all files with violations -->
- [ ] `path/to/file1.ps1` (X violations)
- [ ] `path/to/file2.psm1` (Y violations)

## Suggested Fix
```powershell
# Proposed fix for the violation
try {
    Import-Module $module
} catch {
    Write-Warning "Failed to import module: $_"
}
```

## Impact Assessment
- [ ] Blocks deployment
- [ ] Security concern
- [ ] Performance impact
- [ ] Cross-platform compatibility issue
- [ ] Best practice violation only

## Validation
```powershell
# Command to verify fix
Invoke-ScriptAnalyzer -Path "path/to/fixed/file.ps1"
```

## Related Issues
<!-- Link to related code quality issues -->
- #<!-- Issue number -->

## AI Context for Bulk Fixes
**Pattern:** <!-- Common pattern across violations -->
**Files Affected:** <!-- Count of files needing similar fixes -->
**Automation Possible:** <!-- Can this be auto-fixed? -->