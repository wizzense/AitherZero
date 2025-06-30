# Phase 3: Licensing and Feature Control Requirements

## Licensing System Overview

### Core Concepts
1. **Feature Flags**: Control which modules/functions are available
2. **License Tiers**: Free, Pro, Enterprise (or custom tiers)
3. **Build-Time Control**: Features can be excluded during package creation
4. **Runtime Validation**: License checks for premium features
5. **Easy Management**: Simple configuration to enable/disable features

## Implementation Approach

### 1. Feature Registry
```json
{
  "features": {
    "core": {
      "tier": "free",
      "modules": [
        "Logging",
        "TestingFramework",
        "ProgressTracking"
      ]
    },
    "infrastructure": {
      "tier": "pro",
      "modules": [
        "OpenTofuProvider",
        "CloudProviderIntegration",
        "OrchestrationEngine"
      ]
    },
    "enterprise": {
      "tier": "enterprise",
      "modules": [
        "SecureCredentials",
        "RemoteConnection",
        "SystemMonitoring"
      ]
    },
    "ai": {
      "tier": "pro",
      "modules": [
        "AIToolsIntegration",
        "ConfigurationCarousel"
      ]
    }
  }
}
```

### 2. License File Structure
```json
{
  "licenseId": "XXXX-XXXX-XXXX-XXXX",
  "tier": "pro",
  "features": ["infrastructure", "ai"],
  "issuedTo": "user@example.com",
  "issuedDate": "2025-01-29",
  "expiryDate": "2026-01-29",
  "signature": "base64-signature"
}
```

### 3. Build-Time Feature Control
```powershell
# Build script parameters
./build/Build-Package.ps1 -Platform "windows" -Version "1.0.0" -FeatureTier "free"
./build/Build-Package.ps1 -Platform "windows" -Version "1.0.0" -FeatureTier "pro" -IncludeFeatures @("infrastructure", "ai")
```

### 4. Module Structure Updates
```powershell
# In each module manifest (.psd1)
@{
    # ... existing properties
    PrivateData = @{
        PSData = @{
            # ... existing data
            Licensing = @{
                Tier = 'pro'  # free, pro, enterprise
                Feature = 'infrastructure'
                RequiresLicense = $true
            }
        }
    }
}
```

### 5. License Validation Module
```
aither-core/
├── modules/
│   └── LicenseManager/
│       ├── LicenseManager.psd1
│       ├── LicenseManager.psm1
│       ├── Public/
│       │   ├── Get-LicenseStatus.ps1
│       │   ├── Set-License.ps1
│       │   ├── Test-FeatureAccess.ps1
│       │   └── Get-AvailableFeatures.ps1
│       └── Private/
│           ├── Validate-LicenseSignature.ps1
│           ├── Get-FeatureRegistry.ps1
│           └── Test-LicenseExpiry.ps1
```

### 6. Integration Points

#### Startup Integration
```powershell
# In Start-AitherZero.ps1
$licenseStatus = Get-LicenseStatus
if ($licenseStatus.IsValid) {
    $availableModules = Get-AvailableModules -Tier $licenseStatus.Tier
} else {
    $availableModules = Get-AvailableModules -Tier 'free'
}
```

#### Module Loading
```powershell
# In module import logic
function Import-LicensedModule {
    param($ModuleName)
    
    if (Test-FeatureAccess -Module $ModuleName) {
        Import-Module $ModuleName
    } else {
        Write-Warning "Module '$ModuleName' requires a license. Using limited functionality."
        # Load stub module with limited features
    }
}
```

#### Interactive Menu Integration
```
┌─ Module Explorer ───────────────────────────┐
│ Search: [____________________] 🔍           │
│                                             │
│ ▼ Infrastructure (5 modules)                │
│   ├─ OpenTofuProvider [PRO]                │
│   ├─ CloudProviderIntegration [PRO]        │
│   └─ RemoteConnection [ENTERPRISE]         │
│                                             │
│ ▼ Development (4 modules)                   │
│   ├─ DevEnvironment [FREE]                 │
│   ├─ PatchManager [FREE]                   │
│   └─ AIToolsIntegration [PRO] 🔒           │
│                                             │
│ License: Free Tier (Upgrade)                │
└─────────────────────────────────────────────┘
```

### 7. Simple License Application
```powershell
# Apply license
./Start-AitherZero.ps1 -ApplyLicense "license-key-here"

# Or interactively
./Start-AitherZero.ps1 -Interactive
# Navigate to Settings → License Management → Apply License
```

### 8. Build Configuration
```json
// build-config.json
{
  "editions": {
    "free": {
      "includeModules": [
        "Logging",
        "TestingFramework",
        "ProgressTracking",
        "DevEnvironment",
        "PatchManager"
      ],
      "excludeModules": [
        "OpenTofuProvider",
        "CloudProviderIntegration",
        "SecureCredentials"
      ]
    },
    "pro": {
      "includeAllModules": true,
      "excludeModules": [
        "SecureCredentials",
        "SystemMonitoring"
      ]
    },
    "enterprise": {
      "includeAllModules": true
    }
  }
}
```

## Implementation Strategy

### Phase 1: Basic Feature Flags
1. Add `RequiresLicense` property to module manifests
2. Create simple feature registry JSON
3. Implement basic Test-FeatureAccess function
4. Update module loading to check feature access

### Phase 2: License Management
1. Create LicenseManager module
2. Implement license file validation
3. Add license application functionality
4. Create license status display

### Phase 3: Build Integration
1. Update Build-Package.ps1 to support feature tiers
2. Create module filtering during build
3. Generate edition-specific packages
4. Add build-time feature stripping

### Phase 4: UI Integration
1. Add license status to startup UI
2. Show locked features with upgrade prompts
3. Add license management to settings
4. Implement graceful degradation

## Benefits
- **Flexible Monetization**: Easy to create different product tiers
- **Simple Management**: JSON-based configuration
- **Build-Time Optimization**: Smaller packages for free tier
- **Graceful Degradation**: Features fail gracefully without license
- **Easy Testing**: Simple flags to test different tiers

## Example Usage

### For AitherZero (Free/Open Source)
```powershell
# Default build excludes premium features
./build/Build-Package.ps1 -FeatureTier "free"
```

### For AitherLabs (Pro)
```powershell
# Include pro features
./build/Build-Package.ps1 -FeatureTier "pro" -SignPackage
```

### For Aitherium (Enterprise)
```powershell
# Include all features
./build/Build-Package.ps1 -FeatureTier "enterprise" -SignPackage -CertPath "cert.pfx"
```