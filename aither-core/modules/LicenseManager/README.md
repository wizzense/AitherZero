# LicenseManager Module

## Test Status
- **Last Run**: 2025-07-08 17:29:43 UTC
- **Status**: ✅ PASSING (10/10 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 10/10 | 0% | 1s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 0.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Module Overview

The LicenseManager module provides tier-based feature access control and license validation for the AitherZero infrastructure automation framework. It implements a flexible licensing system that enables monetization of advanced features while maintaining a robust free tier for basic infrastructure automation needs.

### Core Functionality and Use Cases

- **Tier-Based Licensing**: Support for free, professional, and enterprise licensing tiers
- **Feature Access Control**: Granular control over module and feature availability
- **License Validation**: Cryptographic signature validation and expiry checking
- **Monetization Support**: Enable commercial distribution of advanced features
- **Graceful Degradation**: Seamless fallback to free tier when licenses are invalid or expired
- **Multi-Environment Support**: Support for development, testing, and production licensing

### Integration with Infrastructure Automation

- Integrates with all AitherZero modules for feature access control
- Provides licensing hooks for OpenTofu provider features
- Supports tiered access to advanced automation capabilities
- Enables enterprise features like priority support and advanced monitoring
- Facilitates commercial deployment scenarios

### Key Features and Capabilities

- JSON-based license storage with cryptographic validation
- Feature registry system for defining tier-based access
- Automatic license discovery and validation
- Development-friendly licensing with easy tier switching
- Enterprise-grade security with signature validation
- Cross-platform license file management

## Directory Structure

```
LicenseManager/
├── LicenseManager.psd1               # Module manifest
├── LicenseManager.psm1               # Module script with initialization
├── Public/                           # Exported functions
│   ├── Get-LicenseStatus.ps1         # License status and validation
│   ├── Set-License.ps1               # License installation and management
│   └── Get-AvailableFeatures.ps1     # Feature discovery and access
└── Private/                          # Internal helper functions
    ├── Get-FeatureRegistry.ps1       # Feature registry management
    └── Validate-LicenseSignature.ps1 # License signature validation
```

## Core Functions

### Get-LicenseStatus

Retrieves and validates the current license status, returning tier information and feature access details.

**Parameters:** None

**Returns:** PSCustomObject with license status details

**License Status Object:**
```powershell
@{
    IsValid = $true/$false          # License validity
    Tier = 'free'/'pro'/'enterprise' # License tier
    Features = @()                  # Available features array
    ExpiryDate = [DateTime]         # License expiration (null for free)
    IssuedTo = 'String'            # License holder name
    LicenseId = 'String'           # Unique license identifier
    Message = 'String'             # Status message
}
```

**Usage Example:**
```powershell
# Check current license status
$licenseStatus = Get-LicenseStatus

Write-Host "License Tier: $($licenseStatus.Tier)"
Write-Host "Valid: $($licenseStatus.IsValid)"
Write-Host "Features: $($licenseStatus.Features -join ', ')"

if ($licenseStatus.ExpiryDate) {
    $daysRemaining = ($licenseStatus.ExpiryDate - (Get-Date)).Days
    Write-Host "Days Remaining: $daysRemaining"
}

# Feature-specific check
if ('advanced-deployment' -in $licenseStatus.Features) {
    Write-Host "Advanced deployment features available"
    Enable-AdvancedDeployment
} else {
    Write-Host "Using standard deployment features"
    Enable-StandardDeployment
}
```

### Set-License

Installs or updates a license file with validation and feature activation.

**Parameters:**
- `LicensePath` (Mandatory): Path to the license file to install
- `LicenseString`: License content as a string (alternative to file path)
- `Force`: Overwrite existing license without confirmation
- `Validate`: Perform immediate validation after installation

**Returns:** License installation result object

**Usage Example:**
```powershell
# Install license from file
$installation = Set-License -LicensePath "C:\Licenses\aitherzero-pro.json" -Validate

if ($installation.Success) {
    Write-Host "License installed successfully"
    Write-Host "Tier: $($installation.Tier)"
    Write-Host "Features: $($installation.Features -join ', ')"
} else {
    Write-Warning "License installation failed: $($installation.Error)"
}

# Install license from string (for automation)
$licenseJson = Get-Content ".\license.json" -Raw
Set-License -LicenseString $licenseJson -Force

# Install and activate immediately
Set-License -LicensePath ".\enterprise.json" -Validate -Force
```

### Get-AvailableFeatures

Retrieves a list of all available features organized by tier, showing what features are accessible with different license levels.

**Parameters:**
- `Tier`: Filter features by specific tier (optional)
- `IncludeDescriptions`: Include detailed feature descriptions

**Returns:** Array of feature objects with tier information

**Feature Object Structure:**
```powershell
@{
    Name = 'feature-name'
    Tier = 'free'/'pro'/'enterprise'
    Description = 'Feature description'
    Module = 'ModuleName'
    Available = $true/$false    # Based on current license
    RequiresLicense = $true/$false
}
```

**Usage Example:**
```powershell
# Get all available features
$allFeatures = Get-AvailableFeatures -IncludeDescriptions

# Display by tier
$allFeatures | Group-Object Tier | ForEach-Object {
    Write-Host "`n$($_.Name.ToUpper()) TIER FEATURES:" -ForegroundColor Cyan
    $_.Group | ForEach-Object {
        $status = if ($_.Available) { "✓" } else { "✗" }
        Write-Host "  $status $($_.Name) - $($_.Description)"
    }
}

# Get only enterprise features
$enterpriseFeatures = Get-AvailableFeatures -Tier 'enterprise'

# Check specific feature availability
$features = Get-AvailableFeatures
$advancedMonitoring = $features | Where-Object Name -eq 'advanced-monitoring'

if ($advancedMonitoring.Available) {
    Enable-AdvancedMonitoring
}
```

### Test-FeatureAccess

Tests whether a specific feature is available under the current license.

**Parameters:**
- `FeatureName` (Mandatory): Name of the feature to test
- `ModuleName`: Module containing the feature (optional)
- `ThrowOnDenied`: Throw an exception if access is denied

**Returns:** Boolean indicating feature availability

**Usage Example:**
```powershell
# Basic feature check
if (Test-FeatureAccess -FeatureName 'parallel-deployment') {
    Start-ParallelDeployment
} else {
    Start-SequentialDeployment
}

# Module-specific feature check
$hasAdvancedISO = Test-FeatureAccess -FeatureName 'advanced-customization' `
                                    -ModuleName 'ISOCustomizer'

# Strict checking with exception
try {
    Test-FeatureAccess -FeatureName 'enterprise-support' -ThrowOnDenied
    Enable-EnterpriseSupport
} catch {
    Write-Warning "Enterprise support not available: $($_.Exception.Message)"
}
```

### Clear-License

Removes the current license and reverts to free tier.

**Parameters:**
- `Confirm`: Prompt for confirmation before clearing
- `Force`: Clear without confirmation

**Returns:** License clearing result

**Usage Example:**
```powershell
# Clear license with confirmation
Clear-License

# Force clear for automation
Clear-License -Force

# Clear and verify
Clear-License -Force
$status = Get-LicenseStatus
Write-Host "Reverted to tier: $($status.Tier)"
```

### Get-FeatureTier

Gets the required tier for a specific feature.

**Parameters:**
- `FeatureName` (Mandatory): Name of the feature

**Returns:** Required tier string

**Usage Example:**
```powershell
$requiredTier = Get-FeatureTier -FeatureName 'advanced-monitoring'
Write-Host "Advanced monitoring requires: $requiredTier tier"

# Check if current license meets requirement
$currentLicense = Get-LicenseStatus
$hasAccess = Get-TierLevel($currentLicense.Tier) -ge Get-TierLevel($requiredTier)
```

## Workflows

### License Installation and Validation Workflow

```powershell
# Complete license installation workflow
function Install-AitherZeroLicense {
    param(
        [string]$LicensePath,
        [switch]$Backup = $true
    )
    
    try {
        # 1. Backup existing license if requested
        if ($Backup) {
            $currentStatus = Get-LicenseStatus
            if ($currentStatus.IsValid) {
                $backupPath = "$env:USERPROFILE\.aitherzero\license-backup-$(Get-Date -Format 'yyyyMMddHHmmss').json"
                Copy-Item $script:LicensePath $backupPath -ErrorAction SilentlyContinue
                Write-Host "Existing license backed up to: $backupPath"
            }
        }
        
        # 2. Install new license
        Write-Host "Installing license from: $LicensePath"
        $installation = Set-License -LicensePath $LicensePath -Validate
        
        if (-not $installation.Success) {
            throw "License installation failed: $($installation.Error)"
        }
        
        # 3. Verify installation
        $newStatus = Get-LicenseStatus
        Write-Host "License installed successfully!" -ForegroundColor Green
        Write-Host "  Tier: $($newStatus.Tier)" -ForegroundColor Cyan
        Write-Host "  Issued To: $($newStatus.IssuedTo)" -ForegroundColor Cyan
        Write-Host "  Valid Until: $($newStatus.ExpiryDate)" -ForegroundColor Cyan
        
        # 4. Display available features
        Write-Host "`nAvailable Features:" -ForegroundColor Yellow
        $features = Get-AvailableFeatures | Where-Object Available -eq $true
        $features | ForEach-Object {
            Write-Host "  ✓ $($_.Name) ($($_.Module))" -ForegroundColor Green
        }
        
        # 5. Test key features
        $keyFeatures = @('advanced-deployment', 'enterprise-support', 'priority-updates')
        Write-Host "`nFeature Access Test:" -ForegroundColor Yellow
        foreach ($feature in $keyFeatures) {
            $hasAccess = Test-FeatureAccess -FeatureName $feature
            $status = if ($hasAccess) { "✓" } else { "✗" }
            $color = if ($hasAccess) { "Green" } else { "Red" }
            Write-Host "  $status $feature" -ForegroundColor $color
        }
        
        return $installation
        
    } catch {
        Write-Error "License installation failed: $($_.Exception.Message)"
        throw
    }
}

# Usage
Install-AitherZeroLicense -LicensePath "C:\Downloads\aitherzero-enterprise.json"
```

### Feature-Gated Deployment Workflow

```powershell
# Deployment with license-based feature selection
function Start-TieredDeployment {
    param(
        [string]$LabName,
        [hashtable]$BaseConfig
    )
    
    # Check license status
    $license = Get-LicenseStatus
    Write-Host "Deploying with $($license.Tier) tier features"
    
    # Base deployment configuration
    $deploymentConfig = $BaseConfig.Clone()
    
    # Add tier-specific features
    switch ($license.Tier) {
        'enterprise' {
            Write-Host "Enabling enterprise features..." -ForegroundColor Green
            
            # Advanced monitoring
            if (Test-FeatureAccess -FeatureName 'advanced-monitoring') {
                $deploymentConfig.Monitoring = @{
                    Enabled = $true
                    Type = 'Enterprise'
                    AlertingEnabled = $true
                    CustomDashboards = $true
                }
            }
            
            # High availability
            if (Test-FeatureAccess -FeatureName 'high-availability') {
                $deploymentConfig.HighAvailability = @{
                    Enabled = $true
                    LoadBalancing = $true
                    Clustering = $true
                    AutoFailover = $true
                }
            }
            
            # Priority support features
            if (Test-FeatureAccess -FeatureName 'priority-support') {
                $deploymentConfig.Support = @{
                    Level = 'Enterprise'
                    ContactMethod = 'Direct'
                    SLA = '1-hour-response'
                }
            }
        }
        
        'pro' {
            Write-Host "Enabling professional features..." -ForegroundColor Cyan
            
            # Advanced deployment
            if (Test-FeatureAccess -FeatureName 'advanced-deployment') {
                $deploymentConfig.Deployment = @{
                    ParallelExecution = $true
                    RollbackSupport = $true
                    BlueGreenDeployment = $true
                }
            }
            
            # Enhanced monitoring
            if (Test-FeatureAccess -FeatureName 'enhanced-monitoring') {
                $deploymentConfig.Monitoring = @{
                    Enabled = $true
                    Type = 'Professional'
                    BasicAlerting = $true
                }
            }
        }
        
        'free' {
            Write-Host "Using free tier features..." -ForegroundColor Yellow
            
            # Basic features only
            $deploymentConfig.Deployment = @{
                ParallelExecution = $false
                BasicValidation = $true
            }
            
            $deploymentConfig.Monitoring = @{
                Enabled = $true
                Type = 'Basic'
                LoggingOnly = $true
            }
        }
    }
    
    # Execute deployment with tier-appropriate features
    try {
        Write-Host "Starting deployment with configuration:"
        $deploymentConfig | ConvertTo-Json -Depth 3 | Write-Host
        
        $result = Start-LabDeployment -Name $LabName -Config $deploymentConfig
        
        Write-Host "Deployment completed successfully!" -ForegroundColor Green
        return $result
        
    } catch {
        Write-Error "Deployment failed: $($_.Exception.Message)"
        
        # Enterprise tier gets enhanced error reporting
        if ($license.Tier -eq 'enterprise') {
            Send-EnterpriseErrorReport -Error $_ -LabName $LabName
        }
        
        throw
    }
}
```

### License Monitoring and Renewal Workflow

```powershell
# Automated license monitoring
function Start-LicenseMonitoring {
    param(
        [int]$CheckIntervalHours = 24,
        [int]$ExpiryWarningDays = 30
    )
    
    Write-Host "Starting license monitoring (checking every $CheckIntervalHours hours)"
    
    while ($true) {
        try {
            $license = Get-LicenseStatus
            
            # Check license validity
            if (-not $license.IsValid) {
                Write-Warning "License is invalid: $($license.Message)"
                Send-LicenseAlert -Type 'Invalid' -License $license
            }
            
            # Check expiry warning
            if ($license.ExpiryDate) {
                $daysUntilExpiry = ($license.ExpiryDate - (Get-Date)).Days
                
                if ($daysUntilExpiry -le $ExpiryWarningDays -and $daysUntilExpiry -gt 0) {
                    Write-Warning "License expires in $daysUntilExpiry days"
                    Send-LicenseAlert -Type 'ExpiryWarning' -DaysRemaining $daysUntilExpiry
                } elseif ($daysUntilExpiry -le 0) {
                    Write-Error "License has expired!"
                    Send-LicenseAlert -Type 'Expired' -License $license
                }
            }
            
            # Log status
            Write-Host "License check: $($license.Tier) tier, valid until $($license.ExpiryDate)"
            
        } catch {
            Write-Warning "License monitoring error: $($_.Exception.Message)"
        }
        
        # Wait for next check
        Start-Sleep -Seconds ($CheckIntervalHours * 3600)
    }
}

function Send-LicenseAlert {
    param(
        [string]$Type,
        [object]$License = $null,
        [int]$DaysRemaining = 0
    )
    
    $alertData = @{
        Timestamp = Get-Date
        Type = $Type
        MachineName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        License = $License
        DaysRemaining = $DaysRemaining
    }
    
    # Send to monitoring system (implementation specific)
    Write-Host "License alert sent: $Type" -ForegroundColor Red
    $alertData | ConvertTo-Json | Write-Verbose
}
```

## Configuration

### Feature Registry

The feature registry defines available features and their tier requirements:

```json
{
  "version": "1.0",
  "features": {
    "core": {
      "tier": "free",
      "description": "Basic infrastructure automation",
      "modules": ["LabRunner", "Logging", "ConfigurationCore"]
    },
    "development": {
      "tier": "free",
      "description": "Development and testing tools",
      "modules": ["SetupWizard", "DevEnvironment"]
    },
    "advanced-deployment": {
      "tier": "pro",
      "description": "Parallel execution and advanced orchestration",
      "modules": ["LabRunner", "ParallelExecution"]
    },
    "enhanced-monitoring": {
      "tier": "pro",
      "description": "Enhanced monitoring and alerting",
      "modules": ["SystemMonitoring", "ProgressTracking"]
    },
    "advanced-customization": {
      "tier": "pro",
      "description": "Advanced ISO customization features",
      "modules": ["ISOCustomizer"]
    },
    "advanced-monitoring": {
      "tier": "enterprise",
      "description": "Enterprise-grade monitoring with custom dashboards",
      "modules": ["SystemMonitoring"]
    },
    "high-availability": {
      "tier": "enterprise",
      "description": "High availability and clustering features",
      "modules": ["OpenTofuProvider", "LabRunner"]
    },
    "priority-support": {
      "tier": "enterprise",
      "description": "Priority technical support and SLA",
      "modules": ["*"]
    },
    "enterprise-security": {
      "tier": "enterprise",
      "description": "Advanced security and compliance features",
      "modules": ["SecurityAutomation", "SecureCredentials"]
    }
  },
  "tiers": {
    "free": {
      "description": "Open source features for basic automation",
      "price": 0,
      "support": "community"
    },
    "pro": {
      "description": "Professional features for advanced automation",
      "price": 99,
      "support": "standard"
    },
    "enterprise": {
      "description": "Enterprise features with premium support",
      "price": 499,
      "support": "priority"
    }
  }
}
```

### License File Format

```json
{
  "licenseId": "lic_1234567890abcdef",
  "tier": "enterprise",
  "features": [
    "core",
    "development", 
    "advanced-deployment",
    "enhanced-monitoring",
    "advanced-customization",
    "advanced-monitoring",
    "high-availability",
    "priority-support",
    "enterprise-security"
  ],
  "issuedTo": "Contoso Corporation",
  "issuedDate": "2025-01-01T00:00:00Z",
  "expiryDate": "2026-01-01T00:00:00Z",
  "metadata": {
    "customerNumber": "CUST-12345",
    "purchaseOrder": "PO-67890",
    "seats": 50,
    "environment": "production"
  },
  "signature": "SHA256:ABCD1234...signature_hash",
  "version": "1.0"
}
```

### Module Integration

Modules can integrate with the license manager:

```powershell
# In module initialization
function Initialize-ModuleWithLicensing {
    param([string]$ModuleName)
    
    # Check if LicenseManager is available
    if (Get-Module -Name 'LicenseManager' -ListAvailable) {
        try {
            Import-Module LicenseManager -ErrorAction Stop
            
            # Check module access
            $hasAccess = Test-ModuleAccess -ModuleName $ModuleName
            
            if (-not $hasAccess) {
                Write-Warning "$ModuleName: Limited functionality - upgrade license for full features"
                $script:LimitedMode = $true
            } else {
                Write-Verbose "$ModuleName: Full functionality available"
                $script:LimitedMode = $false
            }
            
        } catch {
            Write-Verbose "LicenseManager not available - using free tier"
            $script:LimitedMode = $true
        }
    } else {
        $script:LimitedMode = $true
    }
}

# Feature-gated function example
function Start-AdvancedDeployment {
    [CmdletBinding()]
    param([hashtable]$Config)
    
    if ($script:LimitedMode) {
        Write-Warning "Advanced deployment requires pro or enterprise license"
        Start-BasicDeployment -Config $Config
        return
    }
    
    # Advanced deployment logic
    Write-Host "Starting advanced deployment with parallel execution"
    # ... implementation
}
```

## Templates and Resources

### License Installation Script Template

```powershell
# Install-License.ps1 - Template for license installation
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LicenseFile,
    
    [switch]$Validate,
    [switch]$Force
)

try {
    # Import LicenseManager
    Import-Module (Join-Path $PSScriptRoot 'aither-core\modules\LicenseManager') -Force
    
    # Install license
    Write-Host "Installing AitherZero license from: $LicenseFile"
    $result = Set-License -LicensePath $LicenseFile -Validate:$Validate -Force:$Force
    
    if ($result.Success) {
        Write-Host "License installed successfully!" -ForegroundColor Green
        
        # Show status
        $status = Get-LicenseStatus
        Write-Host "Tier: $($status.Tier)" -ForegroundColor Cyan
        Write-Host "Valid until: $($status.ExpiryDate)" -ForegroundColor Cyan
        
        # Show features
        $features = Get-AvailableFeatures | Where-Object Available
        Write-Host "Available features: $($features.Count)" -ForegroundColor Cyan
        
    } else {
        Write-Error "License installation failed: $($result.Error)"
        exit 1
    }
    
} catch {
    Write-Error "Error installing license: $($_.Exception.Message)"
    exit 1
}
```

### Feature Testing Template

```powershell
# Test-LicenseFeatures.ps1 - Template for testing feature access
Import-Module LicenseManager -Force

$testFeatures = @(
    'core',
    'development',
    'advanced-deployment',
    'enhanced-monitoring',
    'advanced-customization',
    'advanced-monitoring',
    'high-availability',
    'priority-support',
    'enterprise-security'
)

Write-Host "AitherZero License Feature Test" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Yellow

$license = Get-LicenseStatus
Write-Host "Current License: $($license.Tier) tier" -ForegroundColor Cyan
Write-Host "Valid: $($license.IsValid)" -ForegroundColor Cyan
Write-Host ""

foreach ($feature in $testFeatures) {
    $hasAccess = Test-FeatureAccess -FeatureName $feature
    $requiredTier = Get-FeatureTier -FeatureName $feature
    $status = if ($hasAccess) { "✓ Available" } else { "✗ Not Available" }
    $color = if ($hasAccess) { "Green" } else { "Red" }
    
    Write-Host "  $feature ($requiredTier tier): $status" -ForegroundColor $color
}
```

## Best Practices

### License Management Guidelines

1. **Development Environment**
   ```powershell
   # Use free tier for development
   Clear-License -Force
   
   # Test with different tiers
   Set-License -LicensePath ".\test-licenses\pro-tier.json"
   # Run tests
   Clear-License -Force
   ```

2. **Production Deployment**
   ```powershell
   # Validate license before deployment
   $license = Get-LicenseStatus
   if (-not $license.IsValid) {
       throw "Valid license required for production deployment"
   }
   
   # Check feature requirements
   $requiredFeatures = @('advanced-deployment', 'enhanced-monitoring')
   foreach ($feature in $requiredFeatures) {
       if (-not (Test-FeatureAccess -FeatureName $feature)) {
           throw "Feature '$feature' not available with current license"
       }
   }
   ```

3. **Graceful Degradation**
   ```powershell
   # Always provide fallback functionality
   function Deploy-WithLicenseCheck {
       if (Test-FeatureAccess -FeatureName 'parallel-deployment') {
           Start-ParallelDeployment @args
       } else {
           Write-Warning "Using sequential deployment (parallel requires pro tier)"
           Start-SequentialDeployment @args
       }
   }
   ```

### Security Considerations

1. **License File Protection**
   - Store license files securely
   - Use appropriate file permissions
   - Consider encryption for sensitive environments
   - Implement access logging

2. **Signature Validation**
   - Always validate license signatures
   - Use secure validation methods
   - Implement revocation checking
   - Monitor for signature tampering

3. **Environment Separation**
   - Use different licenses for dev/test/prod
   - Implement environment-specific validation
   - Monitor license usage across environments

### Performance Considerations

1. **Caching**
   ```powershell
   # Cache license status to avoid repeated validation
   $script:LicenseCache = @{
       Status = $null
       LastCheck = $null
       CacheTimeout = (New-TimeSpan -Minutes 5)
   }
   
   function Get-CachedLicenseStatus {
       $now = Get-Date
       if ($script:LicenseCache.LastCheck -and 
           ($now - $script:LicenseCache.LastCheck) -lt $script:LicenseCache.CacheTimeout) {
           return $script:LicenseCache.Status
       }
       
       $script:LicenseCache.Status = Get-LicenseStatus
       $script:LicenseCache.LastCheck = $now
       return $script:LicenseCache.Status
   }
   ```

2. **Feature Checks**
   - Cache feature availability results
   - Minimize validation overhead
   - Use lazy loading for feature discovery

## Integration Examples

### With Module Loading

```powershell
# Conditional module loading based on license
function Import-LicensedModule {
    param([string]$ModuleName)
    
    $license = Get-LicenseStatus
    $moduleAccess = Test-ModuleAccess -ModuleName $ModuleName
    
    if ($moduleAccess) {
        Import-Module $ModuleName -Force
        Write-Host "Loaded $ModuleName with full features"
    } else {
        Import-Module $ModuleName -Force
        Write-Warning "$ModuleName loaded with limited features (tier: $($license.Tier))"
    }
}
```

### With CI/CD Pipelines

```powershell
# CI/CD license validation
function Test-CILicense {
    param([string]$RequiredTier = 'pro')
    
    $license = Get-LicenseStatus
    
    if ($license.Tier -eq 'free' -and $RequiredTier -ne 'free') {
        Write-Warning "CI/CD pipeline using free tier - some features may be limited"
        return $false
    }
    
    if (-not $license.IsValid) {
        throw "Invalid license detected in CI/CD pipeline"
    }
    
    $tierLevel = Get-TierLevel -Tier $license.Tier
    $requiredLevel = Get-TierLevel -Tier $RequiredTier
    
    if ($tierLevel -lt $requiredLevel) {
        throw "CI/CD pipeline requires $RequiredTier tier (current: $($license.Tier))"
    }
    
    return $true
}
```

### Enterprise Reporting

```powershell
# Generate license usage report
function New-LicenseReport {
    param([string]$OutputPath)
    
    $license = Get-LicenseStatus
    $features = Get-AvailableFeatures -IncludeDescriptions
    
    $report = @{
        Generated = Get-Date
        Environment = $env:COMPUTERNAME
        License = $license
        FeatureUsage = @{}
        Recommendations = @()
    }
    
    # Analyze feature usage
    foreach ($feature in $features) {
        $usage = Get-FeatureUsageStats -FeatureName $feature.Name
        $report.FeatureUsage[$feature.Name] = $usage
        
        # Generate recommendations
        if ($usage.TimesUsed -gt 100 -and -not $feature.Available) {
            $report.Recommendations += "Consider upgrading to $($feature.Tier) tier for $($feature.Name)"
        }
    }
    
    # Export report
    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath
    Write-Host "License report generated: $OutputPath"
}
```

## Troubleshooting

### Common Issues

1. **License File Not Found**
   ```powershell
   # Check license file location
   $licensePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'license.json'
   Write-Host "Expected license path: $licensePath"
   Write-Host "File exists: $(Test-Path $licensePath)"
   ```

2. **Invalid License Format**
   ```powershell
   # Validate license JSON structure
   try {
       $license = Get-Content $licensePath -Raw | ConvertFrom-Json
       $requiredProps = @('licenseId', 'tier', 'features', 'issuedTo', 'expiryDate', 'signature')
       
       foreach ($prop in $requiredProps) {
           if (-not $license.PSObject.Properties.Name -contains $prop) {
               Write-Error "Missing required property: $prop"
           }
       }
   } catch {
       Write-Error "Invalid JSON format: $($_.Exception.Message)"
   }
   ```

3. **Feature Access Issues**
   ```powershell
   # Debug feature access
   $license = Get-LicenseStatus
   $feature = 'advanced-deployment'
   
   Write-Host "License tier: $($license.Tier)"
   Write-Host "License features: $($license.Features -join ', ')"
   Write-Host "Required tier for $feature: $(Get-FeatureTier -FeatureName $feature)"
   Write-Host "Has access: $(Test-FeatureAccess -FeatureName $feature)"
   ```

### Diagnostic Commands

```powershell
# Comprehensive license diagnostics
function Test-LicenseHealth {
    Write-Host "AitherZero License Diagnostics" -ForegroundColor Yellow
    Write-Host "==============================" -ForegroundColor Yellow
    
    # 1. License file check
    $licensePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'license.json'
    Write-Host "License file: $licensePath"
    Write-Host "Exists: $(Test-Path $licensePath)"
    
    # 2. License status
    try {
        $license = Get-LicenseStatus
        Write-Host "Status: $($license.Message)" -ForegroundColor Green
        Write-Host "Tier: $($license.Tier)"
        Write-Host "Valid: $($license.IsValid)"
        Write-Host "Expires: $($license.ExpiryDate)"
        Write-Host "Issued to: $($license.IssuedTo)"
    } catch {
        Write-Host "License error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # 3. Feature registry
    try {
        $features = Get-AvailableFeatures
        Write-Host "Total features: $($features.Count)"
        Write-Host "Available: $(($features | Where-Object Available).Count)"
    } catch {
        Write-Host "Feature registry error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # 4. Module integration
    $modules = Get-Module | Where-Object Name -like '*Aither*'
    Write-Host "AitherZero modules loaded: $($modules.Count)"
    $modules | ForEach-Object { Write-Host "  - $($_.Name)" }
}
```

## Module Dependencies

- **PowerShell 7.0+**: Required for cross-platform support
- **Logging Module**: For license operation logging
- **JSON Processing**: For license file handling
- **Cryptographic Functions**: For license signature validation

## Security Features

- **Cryptographic Signatures**: License integrity validation
- **Expiry Checking**: Time-based license validation
- **Tier Enforcement**: Feature access control
- **Tamper Detection**: License modification detection
- **Secure Storage**: Protected license file storage

## See Also

- [Feature Registry Documentation](../../configs/feature-registry.json)
- [Module Integration Guide](../README.md)
- [Security Best Practices](../../docs/security.md)
- [Licensing FAQ](../../docs/licensing-faq.md)