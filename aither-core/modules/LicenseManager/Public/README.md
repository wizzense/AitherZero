# LicenseManager Public Functions

This directory contains the public (exported) functions for the LicenseManager module.

## Core License Management

### Get-LicenseStatus.ps1
Retrieves and validates the current license status
- Returns license tier, validity, features, and expiration
- Performs signature validation
- Caches results for performance
- Handles graceful degradation to free tier

### Set-License.ps1  
Installs or updates license files
- Validates license format and signature
- Installs license to user profile
- Provides installation feedback
- Supports force installation

### New-License.ps1
Creates new license files (for license generation)
- Generates properly formatted license files
- Includes signature generation
- Supports all license tiers
- Validates license data structure

## Feature Access Control

### Test-FeatureAccess.ps1
Tests whether specific features are available
- Module-aware feature checking
- Tier-based access control
- Caching for performance
- Integration with license hooks

### Get-AvailableFeatures.ps1
Retrieves list of available features by tier
- Returns feature registry information
- Filters by current license
- Includes feature descriptions
- Supports tier filtering

## License Hook System

### Register-LicenseHook.ps1
Registers modules for license checking
- Module registration system
- Feature requirement specification
- Callback system for access denied scenarios
- Automatic license checking on module load

## Cache Management

### Get-LicenseCacheStatistics.ps1
Returns cache performance metrics
- Cache hit ratios
- Cache age information
- Performance statistics
- Cache health monitoring

## Usage Examples

### Basic License Operations
```powershell
# Check current license
$status = Get-LicenseStatus

# Install new license
Set-License -LicensePath "./enterprise.json" -Validate

# Check feature access
if (Test-FeatureAccess -FeatureName "advanced-deployment") {
    # Use advanced features
}
```

### Module Integration
```powershell
# Register module for license checking
Register-LicenseHook -ModuleName "MyModule" -RequiredFeatures @("pro-feature") -CheckOnLoad

# Test module access
$result = Test-ModuleLicenseHook -ModuleName "MyModule"
```

### Feature Discovery
```powershell
# Get all available features
$features = Get-AvailableFeatures -IncludeDescriptions

# Get enterprise features only
$enterpriseFeatures = Get-AvailableFeatures -Tier "enterprise"
```

## Integration Notes

- All functions integrate with Write-CustomLog for logging
- Cache system improves performance for repeated calls
- Graceful degradation ensures functionality without valid licenses
- Hook system enables seamless module integration