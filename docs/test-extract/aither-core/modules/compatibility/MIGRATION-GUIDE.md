# AitherZero Module Consolidation Migration Guide

## Overview

This guide helps you migrate from the deprecated individual modules to the new consolidated modules in AitherZero. The consolidation improves maintainability, reduces complexity, and provides better integration between related functionality.

## Migration Summary

The following modules have been consolidated and deprecated:

### Configuration Management → ConfigurationManager
- **ConfigurationCore** → ConfigurationManager
- **ConfigurationCarousel** → ConfigurationManager  
- **ConfigurationRepository** → ConfigurationManager

### ISO Management → ISOManagement
- **ISOManager** → ISOManagement
- **ISOCustomizer** → ISOManagement

### Setup & Startup → SetupManager
- **SetupWizard** → SetupManager
- **StartupExperience** → SetupManager

### Utilities → UtilityManager
- **SemanticVersioning** → UtilityManager
- **ProgressTracking** → UtilityManager
- **TestingFramework** → UtilityManager
- **ScriptManager** → UtilityManager

## Backward Compatibility

**100% backward compatibility is maintained** through compatibility shims located in `/aither-core/modules/compatibility/`. These shims:

- ✅ Preserve all existing function signatures
- ✅ Forward calls to the new consolidated modules
- ✅ Show helpful deprecation warnings
- ✅ Provide migration guidance
- ✅ Allow gradual migration at your own pace

## Migration Steps

### 1. Immediate Action Required: None

Your existing scripts will continue to work without any changes. Compatibility shims ensure seamless operation.

### 2. Recommended Migration Process

#### Phase 1: Update Import Statements (Low Risk)
Replace old import statements with new ones:

```powershell
# OLD - These still work but show deprecation warnings
Import-Module ConfigurationCore
Import-Module ConfigurationCarousel
Import-Module ConfigurationRepository

# NEW - Recommended approach
Import-Module ConfigurationManager
```

#### Phase 2: Update Function Calls (Optional)
All functions remain available with the same signatures. No immediate changes needed.

#### Phase 3: Leverage New Features (Optional)
Take advantage of new unified features in consolidated modules.

## Module-Specific Migration Details

### Configuration Modules → ConfigurationManager

#### Before (Old):
```powershell
Import-Module ConfigurationCore
Import-Module ConfigurationCarousel
Import-Module ConfigurationRepository

# Functions work exactly the same
Get-ModuleConfiguration -ModuleName "MyModule"
Switch-ConfigurationSet -ConfigurationName "production"
New-ConfigurationRepository -RepositoryName "custom-config"
```

#### After (Recommended):
```powershell
Import-Module ConfigurationManager

# Same functions, same parameters
Get-ModuleConfiguration -ModuleName "MyModule"
Switch-ConfigurationSet -ConfigurationName "production"
New-ConfigurationRepository -RepositoryName "custom-config"
```

#### Benefits of Migration:
- Single module import instead of three
- Better integration between configuration features
- Enhanced error handling and validation
- Unified logging and monitoring

### ISO Modules → ISOManagement

#### Before (Old):
```powershell
Import-Module ISOManager
Import-Module ISOCustomizer

Get-ISODownload -Url "https://example.com/iso" -Destination "./isos"
New-CustomISO -SourcePath "./source" -OutputPath "./custom.iso"
```

#### After (Recommended):
```powershell
Import-Module ISOManagement

# Same functions, same parameters
Get-ISODownload -Url "https://example.com/iso" -Destination "./isos"
New-CustomISO -SourcePath "./source" -OutputPath "./custom.iso"
```

#### Benefits of Migration:
- Unified ISO management workflow
- Better integration between download and customization
- Enhanced progress tracking
- Improved error handling

### Setup Modules → SetupManager

#### Before (Old):
```powershell
Import-Module SetupWizard
Import-Module StartupExperience

Start-IntelligentSetup -InstallationProfile "developer"
Start-InteractiveMode -ShowWelcome
```

#### After (Recommended):
```powershell
Import-Module SetupManager

# Same functions, same parameters
Start-IntelligentSetup -InstallationProfile "developer"
Start-InteractiveMode -ShowWelcome
```

#### Benefits of Migration:
- Seamless setup-to-startup workflow
- Better user experience integration
- Unified configuration management
- Enhanced onboarding process

### Utility Modules → UtilityManager

#### Before (Old):
```powershell
Import-Module SemanticVersioning
Import-Module ProgressTracking
Import-Module TestingFramework
Import-Module ScriptManager

Get-NextSemanticVersion -CurrentVersion "1.0.0" -BumpType "minor"
Start-ProgressOperation -OperationName "Deploy"
Invoke-TestSuite -TestSuiteName "UnitTests"
Get-ScriptRepository -RepositoryName "automation-scripts"
```

#### After (Recommended):
```powershell
Import-Module UtilityManager

# Same functions, same parameters
Get-NextSemanticVersion -CurrentVersion "1.0.0" -BumpType "minor"
Start-ProgressOperation -OperationName "Deploy"
Invoke-TestSuite -TestSuiteName "UnitTests"
Get-ScriptRepository -RepositoryName "automation-scripts"
```

#### Benefits of Migration:
- Unified utility functions
- Better cross-utility integration
- Shared configuration and logging
- Enhanced performance

## Timeline and Support

### Deprecation Schedule

| Phase | Timeline | Status | Action Required |
|-------|----------|--------|-----------------|
| **Phase 1** | Current | ✅ Compatibility shims active | None - everything works |
| **Phase 2** | Next 3 months | ⚠️ Deprecation warnings shown | Plan migration |
| **Phase 3** | 6+ months | 🔄 Gradual removal of old modules | Complete migration |

### Support Policy

- **Compatibility shims**: Supported indefinitely for backward compatibility
- **Deprecation warnings**: Can be suppressed if needed
- **Legacy modules**: Will be preserved in `/legacy/` directory
- **Migration assistance**: Full documentation and examples provided

## Migration Tools and Helpers

### Automated Detection
Check which modules you're using:

```powershell
# Find all PowerShell files importing deprecated modules
Get-ChildItem -Recurse -Filter "*.ps1" | 
    Select-String -Pattern "Import-Module.*(ConfigurationCore|ConfigurationCarousel|ConfigurationRepository|ISOManager|ISOCustomizer|SetupWizard|StartupExperience|SemanticVersioning|ProgressTracking|TestingFramework|ScriptManager)"
```

### Migration Script Template
```powershell
# migration-helper.ps1
# Replace deprecated imports with new ones

$replacements = @{
    'Import-Module ConfigurationCore' = 'Import-Module ConfigurationManager'
    'Import-Module ConfigurationCarousel' = 'Import-Module ConfigurationManager'
    'Import-Module ConfigurationRepository' = 'Import-Module ConfigurationManager'
    'Import-Module ISOManager' = 'Import-Module ISOManagement'
    'Import-Module ISOCustomizer' = 'Import-Module ISOManagement'
    'Import-Module SetupWizard' = 'Import-Module SetupManager'
    'Import-Module StartupExperience' = 'Import-Module SetupManager'
    'Import-Module SemanticVersioning' = 'Import-Module UtilityManager'
    'Import-Module ProgressTracking' = 'Import-Module UtilityManager'
    'Import-Module TestingFramework' = 'Import-Module UtilityManager'
    'Import-Module ScriptManager' = 'Import-Module UtilityManager'
}

# Apply replacements to your scripts
foreach ($file in Get-ChildItem -Recurse -Filter "*.ps1") {
    $content = Get-Content $file.FullName -Raw
    $updated = $content
    
    foreach ($old in $replacements.Keys) {
        $new = $replacements[$old]
        $updated = $updated -replace [regex]::Escape($old), $new
    }
    
    if ($updated -ne $content) {
        Write-Host "Updating: $($file.FullName)"
        Set-Content $file.FullName -Value $updated
    }
}
```

## Troubleshooting

### Common Issues

#### Issue: Deprecation Warnings
**Solution**: Warnings are informational. Your code continues to work. Update imports when convenient.

#### Issue: Module Not Found
**Solution**: Ensure you're using the correct new module name:
- ConfigurationCore → ConfigurationManager
- ISOManager → ISOManagement
- SetupWizard → SetupManager
- etc.

#### Issue: Function Not Available
**Solution**: All functions are preserved. If you encounter issues:
1. Check the function name is correct
2. Verify the new module is installed
3. Try importing the compatibility shim explicitly

#### Issue: Performance Concerns
**Solution**: New consolidated modules are optimized and typically perform better than separate modules.

### Getting Help

- **Documentation**: Each consolidated module has comprehensive documentation
- **Examples**: See `/examples/` directory for migration examples
- **Support**: GitHub issues for migration assistance
- **Community**: AitherZero Discord channel for real-time help

## Benefits of Migration

### Technical Benefits
- **Reduced Memory Usage**: Fewer modules loaded
- **Faster Loading**: Optimized module initialization
- **Better Integration**: Unified functionality across related features
- **Enhanced Logging**: Centralized logging and monitoring
- **Improved Error Handling**: Consistent error management

### Maintenance Benefits
- **Simplified Updates**: Fewer modules to maintain
- **Consistent APIs**: Unified function signatures and patterns
- **Better Testing**: Consolidated test suites
- **Easier Debugging**: Single module to troubleshoot

### User Experience Benefits
- **Cleaner Scripts**: Fewer import statements
- **Better Documentation**: Unified docs per functional area
- **Enhanced Features**: New capabilities from integration
- **Consistent Behavior**: Unified patterns across functions

## Conclusion

The module consolidation provides significant benefits while maintaining 100% backward compatibility. You can:

1. **Continue using existing scripts** without any changes
2. **Migrate gradually** at your own pace
3. **Take advantage of new features** as you update
4. **Get help** throughout the migration process

The compatibility shims ensure a smooth transition, and the new consolidated modules provide better functionality and maintainability.

For questions or assistance, please refer to the individual module documentation or reach out through our support channels.