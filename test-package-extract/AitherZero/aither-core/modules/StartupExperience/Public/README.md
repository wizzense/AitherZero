# StartupExperience Public Functions

This directory contains the public (exported) functions for the StartupExperience module.

## Function Overview

### Core Functions

- **Start-InteractiveMode.ps1** - Main interactive startup interface
- **Show-ConfigurationManager.ps1** - Configuration management UI
- **Get-ModuleDiscovery.ps1** - Module discovery and loading
- **New-ConfigurationProfile.ps1** - Profile creation and management

### Profile Management

- **Get-ConfigurationProfile.ps1** - Retrieve configuration profiles
- **Set-ConfigurationProfile.ps1** - Update profile settings
- **Remove-ConfigurationProfile.ps1** - Delete profiles
- **Export-ConfigurationProfile.ps1** - Export profiles for backup
- **Import-ConfigurationProfile.ps1** - Import profiles from backup

### UI and Display

- **Show-ModuleExplorer.ps1** - Interactive module browser
- **Show-UIDebugInfo.ps1** - UI diagnostics and troubleshooting
- **Get-UIStatus.ps1** - Current UI status information

### GitHub Integration

- **Sync-ConfigurationToGitHub.ps1** - Synchronize configurations with GitHub

### Utility Functions

- **Get-StartupMode.ps1** - Determine appropriate startup mode
- **Clear-ModuleDiscoveryCache.ps1** - Cache management
- **Test-StartupPerformance.ps1** - Performance testing and optimization

## Usage Patterns

### Basic Startup
```powershell
# Start interactive mode
Start-InteractiveMode

# Start with specific profile
Start-InteractiveMode -Profile "development"
```

### Profile Management
```powershell
# Create new profile
$profile = New-ConfigurationProfile -Name "my-env"

# Export for backup
Export-ConfigurationProfile -Profile "my-env" -Path "./backup.json"
```

### Module Discovery
```powershell
# Discover available modules
$modules = Get-ModuleDiscovery

# Clear cache after updates
Clear-ModuleDiscoveryCache
```

## Integration Notes

- All functions integrate with the LicenseManager for feature access control
- Functions use Write-CustomLog for consistent logging
- UI functions automatically detect terminal capabilities
- Profile functions support GitHub synchronization