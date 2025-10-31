# PowerShell Module Manifest Unicode Issues

This document explains the PowerShell module manifest parsing errors related to Unicode characters and how to resolve them.

## Problem Description

PowerShell module manifest files (`.psd1`) must comply with PowerShell's restricted language requirements. When these files contain certain Unicode characters, they can cause parsing failures, especially on Windows PowerShell 5.1 and in certain CI/CD environments.

### Common Error Symptoms

```powershell
The module manifest 'AitherZero.psd1' could not be processed because it is not a valid 
Windows PowerShell restricted language file. Remove the elements that are not permitted 
by the restricted language:

At AitherZero.psd1:67 char:65
+ ... Consolidated architecture: 82% complexity reduction (33 → 6 modules ...
+                                                                 ~
Unexpected token '6' in expression or statement.

At AitherZero.psd1:67 char:64  
+ ... ¢ Consolidated architecture: 82% complexity reduction (33 → 6 modul ...
+                                                                  ~
The hash literal was incomplete.
```

### Root Cause

The error occurs when module manifest files contain Unicode characters such as:

- **Arrow characters**: `→` `←` `↑` `↓` (U+2190-U+21FF)
- **Smart quotes**: `"` `"` `'` `'` (U+2018-U+201F) 
- **Em/En dashes**: `—` `–` (U+2013-U+2014)
- **Other non-ASCII characters**

These characters can break PowerShell's restricted language parser, which expects ASCII-only content in manifest files.

## Detection and Resolution

### Automated Detection

AitherZero includes automated tools to detect and fix Unicode issues:

```powershell
# Validate all module manifests in the project
az 0405

# Validate and automatically fix issues  
az 0405 -Fix

# Validate a specific file
./tools/Validate-ModuleManifest.ps1 -Path ./AitherZero.psd1

# Validate and fix a specific file
./tools/Validate-ModuleManifest.ps1 -Path ./AitherZero.psd1 -Fix
```

## Prevention

### File Encoding

- Save `.psd1` files as **UTF-8 without BOM**
- Avoid UTF-8 with BOM as it can cause issues on some systems
- Use ASCII-only characters in module manifest strings

### CI/CD Integration

The project includes automatic validation in GitHub Actions:

- **Workflow**: `.github/workflows/validate-manifests.yml`
- **Triggers**: On changes to `.psd1` files or validation tools
- **Actions**: Validates all manifests and runs tests

## Related Files

- **Validation Tool**: `tools/Validate-ModuleManifest.ps1`
- **Automation Script**: `automation-scripts/0405_Validate-ModuleManifests.ps1`
- **Tests**: `tests/unit/automation-scripts/0400-0499/0405_Validate-ModuleManifests.Tests.ps1`
- **GitHub Workflow**: `.github/workflows/validate-manifests.yml`