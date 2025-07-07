# AitherZero PowerShell API Consistency Analysis Report

## Executive Summary

This report analyzes the AitherZero codebase for PowerShell API design consistency, focusing on function naming conventions, parameter consistency, and overall API design patterns.

## 1. Non-Approved PowerShell Verbs

The following functions use verbs that are not in the approved PowerShell verb list:

### Functions with Non-Approved Verbs:

| Function | Non-Approved Verb | Recommended Replacement |
|----------|-------------------|------------------------|
| Clone-ConfigurationRepository | Clone | Copy-ConfigurationRepository |
| Configure-AITools | Configure | Set-AIToolsConfiguration |
| Fork-ConfigurationRepository | Fork | Copy-ConfigurationRepository (with -Fork switch) |
| Generate-QuickStartGuide | Generate | New-QuickStartGuide |
| Generate-UsageReport | Generate | New-UsageReport |
| Parse-ConventionalCommits | Parse | ConvertFrom-ConventionalCommits |
| Review-Configuration | Review | Test-Configuration or Get-ConfigurationReview |
| Subscribe-* (6 functions) | Subscribe | Register-*EventHandler |
| Unsubscribe-* (3 functions) | Unsubscribe | Unregister-*EventHandler |
| Validate-* (4 functions) | Validate | Test-* |

### Recommendation:
- Use approved verbs from Get-Verb
- For "Validate", use "Test" (approved diagnostic verb)
- For "Subscribe/Unsubscribe", use "Register/Unregister" (approved lifecycle verbs)
- For "Generate", use "New" (approved common verb)
- For "Configure", use "Set" (approved common verb)

## 2. Inconsistent Naming Patterns

### 2.1 Configuration vs Config
- Some modules use "Configuration" (full): ConfigurationCarousel, ConfigurationCore
- Others use "Config": Get-LabConfig, Get-TaliesinsProviderConfig
- **Recommendation**: Standardize on "Configuration" for consistency

### 2.2 Singular vs Plural Nouns
- Inconsistent usage: Get-AIToolsStatus vs Get-SecureCredential
- Multiple credentials: Get-AllSecureCredentials
- **Recommendation**: Use singular for single items, plural for collections

### 2.3 Info vs Information
- Get-ConfigurationRepositoryInfo
- Show-InformationDialog
- **Recommendation**: Standardize on "Information" (more formal)

## 3. Parameter Naming Inconsistencies

### 3.1 Path Parameters
- **Path**: Used in 14 functions
- **FilePath**: Used in 1 function
- **Recommendation**: Standardize on "Path" for directories, "FilePath" for files

### 3.2 Configuration Parameters
- **Config**: 2 functions
- **Configuration**: 9 functions
- **Settings**: 1 function
- **Recommendation**: Use "Configuration" consistently

### 3.3 Name Parameters
- Generic "Name" vs specific "ModuleName", "RepositoryName"
- **Recommendation**: Use specific names for clarity

## 4. Module-Specific Issues

### 4.1 PatchManager Module
- Mix of v3.0 and legacy functions
- Good use of New-* verbs for main functions
- Legacy functions like "Invoke-PatchWorkflow" should be marked as deprecated

### 4.2 BackupManager Module
- Good verb usage overall
- Consider renaming "Invoke-BackupMaintenance" to "Start-BackupMaintenance"

### 4.3 AIToolsIntegration Module
- "Configure-AITools" should be "Set-AIToolsConfiguration"
- Good consistency with Install-* pattern

### 4.4 ConfigurationCarousel Module
- Good verb usage
- Consider using "ConfigurationSet" consistently instead of mixing with "Configuration"

## 5. Function Prefixing Recommendations

Consider using module prefixes for disambiguation:
- Backup functions: Add "Backup" prefix consistently
- Configuration functions: Group by sub-module (CC-, CR-, CM-)
- Testing functions: Add "Test" prefix or suffix consistently

## 6. Alias Strategy

### Current State:
- Most modules export all aliases (AliasesToExport = '*')
- No documented alias strategy

### Recommendations:
1. Create backward-compatible aliases for renamed functions
2. Document all aliases in module manifests
3. Use consistent alias patterns (e.g., gcfg for Get-Configuration)

## 7. Return Type Consistency

### Issues Found:
- Some Get-* functions might return null vs empty collections
- Status functions return different object types

### Recommendations:
1. Get-* functions should return empty collections, not null
2. Standardize status object properties
3. Document return types in function help

## 8. Recommended Actions

### High Priority:
1. Replace non-approved verbs (19 functions)
2. Standardize Configuration/Config usage
3. Update Subscribe/Unsubscribe to Register/Unregister pattern

### Medium Priority:
1. Standardize parameter names across modules
2. Add function aliases for backward compatibility
3. Update module manifests with specific exports

### Low Priority:
1. Consider module-specific noun prefixes
2. Document naming conventions
3. Create PowerShell format files for custom objects

## 9. Migration Strategy

```powershell
# Example migration approach
# 1. Add aliases in module manifest
AliasesToExport = @(
    'Clone-ConfigurationRepository',  # Alias for Copy-ConfigurationRepository
    'Configure-AITools',              # Alias for Set-AIToolsConfiguration
    'Validate-Configuration'          # Alias for Test-Configuration
)

# 2. Add alias definitions in module
New-Alias -Name 'Clone-ConfigurationRepository' -Value 'Copy-ConfigurationRepository'
New-Alias -Name 'Configure-AITools' -Value 'Set-AIToolsConfiguration'

# 3. Add deprecation warnings
function Clone-ConfigurationRepository {
    Write-Warning "Clone-ConfigurationRepository is deprecated. Use Copy-ConfigurationRepository instead."
    Copy-ConfigurationRepository @PSBoundParameters
}
```

## 10. Benefits of Standardization

1. **Discoverability**: Users can guess function names
2. **IntelliSense**: Better tab completion
3. **Consistency**: Reduced learning curve
4. **Compatibility**: Works better with PowerShell tooling
5. **Professionalism**: Follows PowerShell best practices

## Conclusion

The AitherZero project has good overall structure but would benefit from standardizing on PowerShell naming conventions. The main issues are:
- 19 functions with non-approved verbs
- Inconsistent parameter naming
- Mix of Configuration/Config terminology

Implementing these recommendations will improve the API consistency and user experience.