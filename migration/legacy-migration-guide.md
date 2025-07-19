# Legacy Code Migration Guide

## Overview

This guide documents the removal of legacy code from AitherZero as part of the v1.0.0 consolidation effort. All legacy code has been preserved in the `legacy-archive` branch for historical reference.

**Total Code Reduction**: ~2,100+ lines removed

## Legacy Code Removed

### 1. PatchManager Legacy Directory

**Location**: `aither-core/modules/PatchManager/Legacy/`  
**Size**: 28 files, ~2,000+ lines of code  
**Archive Branch**: `legacy-archive`

#### Files Removed:

- `BranchStrategy.ps1` - Old branching logic (replaced by v3.0 atomic operations)
- `CheckoutAndCommit.ps1` - Deprecated checkout workflow
- `ConvertTo-PipelineSyntax.ps1` - Obsolete pipeline conversion
- `CopilotIntegration.ps1` - Deprecated AI integration
- `ErrorHandling.ps1` - Old error handling (replaced by Invoke-ErrorRecovery)
- `GitOperations.ps1` - Legacy git operations
- `Invoke-AutomatedErrorTracking.ps1` - Replaced by unified error system
- `Invoke-BranchRollback.ps1` - Replaced by Invoke-PatchRollback
- `Invoke-ComprehensiveIssueTracking.ps1` - Replaced by New-PatchIssue
- `Invoke-ComprehensiveValidation.ps1` - Integrated into New-Patch
- `Invoke-CopilotSuggestionHandler.ps1` - Deprecated AI handler
- `Invoke-CrossPlatformFixer.ps1` - Integrated into core
- `Invoke-EnhancedGitOperations.ps1` - Replaced by atomic operations
- `Invoke-EnhancedPatchManager.ps1` - Replaced by v3.0
- `Invoke-ErrorHandler.ps1` - Replaced by Invoke-ErrorRecovery
- `Invoke-GitControlledPatch.ps1` - Replaced by New-Patch
- `Invoke-GitHubIssueIntegration.ps1` - Replaced by New-PatchIssue
- `Invoke-GitHubIssueResolution.ps1` - Integrated into PR workflow
- `Invoke-IntelligentBranchStrategy.ps1` - Replaced by smart mode detection
- `Invoke-MassFileFix.ps1` - Deprecated mass operation
- `Invoke-MonitoredExecution.ps1` - Replaced by Invoke-AtomicOperation
- `Invoke-PatchValidation.ps1` - Integrated into New-Patch
- `Invoke-QuickRollback.ps1` - Replaced by Invoke-PatchRollback
- `Invoke-SimplifiedPatchWorkflow.ps1` - Replaced by New-QuickFix
- `Invoke-UnifiedMaintenance.ps1` - Moved to UnifiedMaintenance module
- `Invoke-ValidationFailureHandler.ps1` - Integrated into error recovery
- `Update-Changelog.ps1` - Deprecated changelog automation
- `Update-ProjectManifest.ps1` - Integrated into release workflow

### 2. TestingFramework Compatibility Functions

**Location**: `aither-core/modules/TestingFramework/TestingFramework.psm1`  
**Functions Removed**: ~100+ lines

- `Write-TestLog` (lines 40-44) - Backward compatibility wrapper
- `Publish-TestEvent` (alias) - Replaced by Submit-TestEvent
- `Subscribe-TestEvent` (alias) - Replaced by Register-TestEventHandler

**Additional Changes**:
- Fixed all Write-TestLog calls to use Write-CustomLog with correct parameter order
- Updated 82+ function calls throughout the module

## Migration Instructions

### For PatchManager Legacy Functions

All legacy functions have modern replacements in PatchManager v3.0:

#### Basic Patch Operations
```powershell
# OLD (Legacy)
Invoke-SimplifiedPatchWorkflow -PatchDescription "Fix" -PatchOperation { }

# NEW (v3.0)
New-QuickFix -Description "Fix" -Changes { }
```

#### Feature Development
```powershell
# OLD (Legacy)
Invoke-EnhancedPatchManager -FeatureName "New feature" -Operations { }

# NEW (v3.0)
New-Feature -Description "New feature" -Changes { }
```

#### Error Handling
```powershell
# OLD (Legacy)
Invoke-ErrorHandler -ErrorInfo $error

# NEW (v3.0)
# Automatic error recovery built into atomic operations
```

#### Validation
```powershell
# OLD (Legacy)
Invoke-PatchValidation -PatchInfo $patch

# NEW (v3.0)
# Validation integrated into New-Patch with -Validate parameter
```

#### Branch Rollback
```powershell
# OLD (Legacy)
Invoke-BranchRollback -BranchName "feature/test"
Invoke-QuickRollback

# NEW (v3.0)
Invoke-PatchRollback -RollbackType "LastCommit"
```

#### GitHub Integration
```powershell
# OLD (Legacy)
Invoke-GitHubIssueIntegration -IssueTitle "Bug" -IssueBody "Description"
Invoke-ComprehensiveIssueTracking

# NEW (v3.0)
New-PatchIssue -Title "Bug" -Body "Description"
```

### For TestingFramework Functions

Replace deprecated aliases and functions with modern equivalents:

```powershell
# OLD
Write-TestLog "Message" -Level "INFO"

# NEW
Write-CustomLog -Level "INFO" -Message "Message"

# OLD
Publish-TestEvent -EventName "test" -Data $data

# NEW
Submit-TestEvent -EventName "test" -Data $data

# OLD
Subscribe-TestEvent -EventName "test" -Handler { }

# NEW
Register-TestEventHandler -EventName "test" -Handler { }
```

## Breaking Changes

### 1. Direct Legacy Function Calls

Any scripts directly calling legacy functions will break. Update to use modern equivalents as shown above.

### 2. Legacy Parameters

Some legacy functions had different parameter names:
- `PatchDescription` → `Description`
- `PatchOperation` → `Changes`
- `FeatureName` → `Description`
- `Operations` → `Changes`

### 3. Return Types

Legacy functions often returned custom objects. Modern functions return standardized result objects with consistent properties:
```powershell
# Modern return object structure
@{
    Success = $true/$false
    Message = "Operation result"
    Details = @()
    Error = $null
}
```

### 4. Event System Changes

The event system has been modernized:
- `Publish-TestEvent` → `Submit-TestEvent`
- `Subscribe-TestEvent` → `Register-TestEventHandler`
- Event data structure is now standardized

## Scripts That May Need Updates

Based on the removed functions, check these areas:
1. CI/CD scripts that may call legacy patch functions
2. Test runners using Write-TestLog
3. Automated maintenance scripts using legacy functions
4. Any custom scripts in the scripts/ directory

## Rollback Instructions

If you need to access legacy code:

1. Check out the legacy archive branch:
   ```bash
   git checkout legacy-archive
   ```

2. Copy needed legacy files to your working branch

3. Adapt the code to work with modern infrastructure

4. Consider why the legacy code is needed - there's likely a modern replacement

## Support

For questions about migrating from legacy functions:
1. Check the PatchManager v3.0 documentation
2. Review examples in the test files
3. Use the `-WhatIf` parameter to preview operations
4. Check the modern function help: `Get-Help New-Patch -Full`

## Timeline

- **January 19, 2025**: Legacy code archived and removed
- **January 31, 2025**: End of transition period for internal scripts
- **February 1, 2025**: Legacy compatibility layer fully removed

## Verification

To verify your scripts work with the new structure:
```powershell
# Test PatchManager functions
New-QuickFix -Description "Test" -WhatIf

# Test event system
Submit-TestEvent -EventName "test" -Data @{test=$true}

# Test logging
Write-CustomLog -Level "INFO" -Message "Test message"
```

## Summary of Benefits

The removal of legacy code provides:
- **Cleaner codebase**: 2,100+ lines removed
- **Better maintainability**: Single implementation for each feature
- **Improved reliability**: Atomic operations prevent partial failures
- **Consistent API**: Standardized parameters and return types
- **Modern patterns**: Event-driven architecture, proper error handling