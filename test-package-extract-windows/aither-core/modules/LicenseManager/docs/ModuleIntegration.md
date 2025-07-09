# Module Integration Guide for LicenseManager

This guide provides comprehensive instructions for integrating AitherZero modules with the LicenseManager system for secure and efficient license-based feature gating.

## Table of Contents

1. [Quick Start Integration](#quick-start-integration)
2. [Registration-Based Integration](#registration-based-integration)
3. [Manual Integration Patterns](#manual-integration-patterns)
4. [Advanced Integration Techniques](#advanced-integration-techniques)
5. [Best Practices](#best-practices)
6. [Troubleshooting](#troubleshooting)

## Quick Start Integration

### Basic Module Setup

For modules that need license checking, add this to your module initialization:

```powershell
# In your module's .psm1 file
function Initialize-ModuleWithLicensing {
    param([string]$ModuleName)
    
    # Check if LicenseManager is available
    if (Get-Module -Name 'LicenseManager' -ListAvailable) {
        try {
            Import-Module LicenseManager -ErrorAction Stop
            
            # Test if module has license access
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

# Call during module import
Initialize-ModuleWithLicensing -ModuleName "YourModuleName"
```

### Simple Feature Gating

```powershell
function Start-AdvancedFeature {
    [CmdletBinding()]
    param([hashtable]$Config)
    
    # Check for advanced features
    if ($script:LimitedMode -or -not (Test-FeatureAccess -FeatureName "advanced-deployment")) {
        Write-Warning "Advanced deployment requires pro or enterprise license"
        Start-BasicFeature -Config $Config
        return
    }
    
    # Advanced feature logic
    Write-Host "Starting advanced deployment with enhanced features"
    # ... implementation
}
```

## Registration-Based Integration

### Automated License Hook Registration

Use the registration system for comprehensive license management:

```powershell
# Register your module with license requirements
function Initialize-ModuleLicenseHooks {
    param(
        [string]$ModuleName,
        [string[]]$RequiredFeatures,
        [switch]$StrictMode
    )
    
    try {
        # Import LicenseManager if available
        if (-not (Get-Module -Name LicenseManager)) {
            Import-Module LicenseManager -ErrorAction Stop
        }
        
        # Define callbacks for license events
        $onFeatureDenied = {
            param($Result)
            Write-Warning "[$($Result.ModuleName)] Feature access denied - missing: $($Result.DeniedFeatures -join ', ')"
            Write-Host "Current tier: $($Result.LicenseStatus.Tier)" -ForegroundColor Yellow
            Write-Host "Required features: $($Result.RequiredFeatures -join ', ')" -ForegroundColor Yellow
            
            if ($StrictMode) {
                throw "Module '$($Result.ModuleName)' requires higher license tier"
            }
        }
        
        $onLicenseInvalid = {
            param($Result)
            Write-Warning "[$($Result.ModuleName)] License validation failed: $($Result.LicenseStatus.Message)"
            
            if ($StrictMode) {
                throw "Valid license required for module '$($Result.ModuleName)'"
            }
        }
        
        # Register the module
        $hookResult = Register-LicenseHook -ModuleName $ModuleName -RequiredFeatures $RequiredFeatures -OnFeatureDenied $onFeatureDenied -OnLicenseInvalid $onLicenseInvalid -CheckOnLoad
        
        # Store access status in module
        $script:ModuleLicenseAccess = $hookResult.LastCheckResult.HasAccess
        $script:ModuleAccessCheckedAt = Get-Date
        
        Write-Verbose "[$ModuleName] License hook registered successfully"
        return $hookResult
        
    } catch {
        Write-Warning "[$ModuleName] License hook registration failed: $($_.Exception.Message)"
        $script:ModuleLicenseAccess = $false
        return $null
    }
}

# Example usage in module initialization
$RequiredFeatures = @('infrastructure', 'automation')
Initialize-ModuleLicenseHooks -ModuleName "OpenTofuProvider" -RequiredFeatures $RequiredFeatures
```

### Dynamic Feature Checking

```powershell
function Invoke-LicensedOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationName,
        
        [Parameter(Mandatory)]
        [string[]]$RequiredFeatures,
        
        [Parameter(Mandatory)]
        [scriptblock]$Operation,
        
        [Parameter()]
        [scriptblock]$FallbackOperation
    )
    
    try {
        # Test each required feature
        foreach ($feature in $RequiredFeatures) {
            if (-not (Test-FeatureAccess -FeatureName $feature)) {
                $missingFeature = $feature
                break
            }
        }
        
        if ($missingFeature) {
            Write-Warning "Operation '$OperationName' requires feature: $missingFeature"
            
            if ($FallbackOperation) {
                Write-Host "Executing fallback operation..." -ForegroundColor Yellow
                & $FallbackOperation
            } else {
                throw "Feature '$missingFeature' not available in current license"
            }
            return
        }
        
        # Execute the licensed operation
        Write-Verbose "Executing licensed operation: $OperationName"
        & $Operation
        
    } catch {
        Write-Error "Licensed operation failed: $($_.Exception.Message)"
        throw
    }
}

# Example usage
Invoke-LicensedOperation -OperationName "Parallel Deployment" -RequiredFeatures @('automation') -Operation {
    Start-ParallelDeployment @args
} -FallbackOperation {
    Start-SequentialDeployment @args
}
```

## Manual Integration Patterns

### Pattern 1: Simple Feature Check

```powershell
function Enable-AdvancedMonitoring {
    if (-not (Test-FeatureAccess -FeatureName 'monitoring')) {
        Write-Host "Advanced monitoring requires enterprise license" -ForegroundColor Yellow
        return $false
    }
    
    # Enable advanced monitoring
    Write-Host "Enabling advanced monitoring features" -ForegroundColor Green
    return $true
}
```

### Pattern 2: Graceful Degradation

```powershell
function Start-InfrastructureDeployment {
    param(
        [hashtable]$Config,
        [switch]$EnableParallelExecution,
        [switch]$EnableAdvancedMonitoring
    )
    
    # Check license status
    $licenseStatus = Get-LicenseStatus
    
    # Adjust features based on license
    $deploymentConfig = $Config.Clone()
    
    if ($EnableParallelExecution -and (Test-FeatureAccess -FeatureName 'automation')) {
        $deploymentConfig.ParallelExecution = $true
        Write-Host "Parallel execution enabled" -ForegroundColor Green
    } else {
        $deploymentConfig.ParallelExecution = $false
        if ($EnableParallelExecution) {
            Write-Warning "Parallel execution requires automation features (pro+ license)"
        }
    }
    
    if ($EnableAdvancedMonitoring -and (Test-FeatureAccess -FeatureName 'monitoring')) {
        $deploymentConfig.AdvancedMonitoring = $true
        Write-Host "Advanced monitoring enabled" -ForegroundColor Green
    } else {
        $deploymentConfig.AdvancedMonitoring = $false
        if ($EnableAdvancedMonitoring) {
            Write-Warning "Advanced monitoring requires enterprise license"
        }
    }
    
    # Execute deployment with adjusted configuration
    Start-Deployment -Config $deploymentConfig
}
```

### Pattern 3: Tiered Functionality

```powershell
function Get-SecurityConfiguration {
    param([string]$Environment)
    
    $licenseStatus = Get-LicenseStatus
    
    switch ($licenseStatus.Tier) {
        'enterprise' {
            return @{
                EncryptionLevel = "AES256"
                AuditLogging = $true
                ComplianceReporting = $true
                AdvancedFirewall = $true
                ZeroTrustNetworking = $true
            }
        }
        'pro' {
            return @{
                EncryptionLevel = "AES256"
                AuditLogging = $true
                ComplianceReporting = $false
                AdvancedFirewall = $false
                ZeroTrustNetworking = $false
            }
        }
        default {
            return @{
                EncryptionLevel = "AES128"
                AuditLogging = $false
                ComplianceReporting = $false
                AdvancedFirewall = $false
                ZeroTrustNetworking = $false
            }
        }
    }
}
```

## Advanced Integration Techniques

### Caching License Status

```powershell
# Module-level caching for performance
$script:ModuleLicenseCache = @{
    LastCheck = $null
    CacheTimeout = (New-TimeSpan -Minutes 5)
    LicenseStatus = $null
    FeatureAccess = @{}
}

function Get-ModuleLicenseStatus {
    param([switch]$Force)
    
    $now = Get-Date
    
    # Check cache validity
    if (-not $Force -and 
        $script:ModuleLicenseCache.LastCheck -and
        ($now - $script:ModuleLicenseCache.LastCheck) -lt $script:ModuleLicenseCache.CacheTimeout) {
        return $script:ModuleLicenseCache.LicenseStatus
    }
    
    # Refresh cache
    $script:ModuleLicenseCache.LicenseStatus = Get-LicenseStatus
    $script:ModuleLicenseCache.LastCheck = $now
    $script:ModuleLicenseCache.FeatureAccess.Clear()
    
    return $script:ModuleLicenseCache.LicenseStatus
}

function Test-ModuleFeatureAccess {
    param([string]$FeatureName)
    
    # Check feature cache
    if ($script:ModuleLicenseCache.FeatureAccess.ContainsKey($FeatureName)) {
        return $script:ModuleLicenseCache.FeatureAccess[$FeatureName]
    }
    
    # Test and cache result
    $hasAccess = Test-FeatureAccess -FeatureName $FeatureName
    $script:ModuleLicenseCache.FeatureAccess[$FeatureName] = $hasAccess
    
    return $hasAccess
}
```

### License Status Display

```powershell
function Show-ModuleLicenseStatus {
    param([string]$ModuleName)
    
    $licenseStatus = Get-LicenseStatus
    
    Write-Host "`n[$ModuleName] License Status:" -ForegroundColor Cyan
    Write-Host "  Tier: $($licenseStatus.Tier)" -ForegroundColor $(
        switch ($licenseStatus.Tier) {
            'enterprise' { 'Green' }
            'pro' { 'Yellow' }
            default { 'Red' }
        }
    )
    Write-Host "  Valid: $($licenseStatus.IsValid)" -ForegroundColor $(if ($licenseStatus.IsValid) { 'Green' } else { 'Red' })
    
    if ($licenseStatus.ExpiryDate) {
        $daysLeft = ($licenseStatus.ExpiryDate - (Get-Date)).Days
        $color = if ($daysLeft -lt 30) { 'Red' } elseif ($daysLeft -lt 90) { 'Yellow' } else { 'Green' }
        Write-Host "  Expires: $($licenseStatus.ExpiryDate.ToString('yyyy-MM-dd')) ($daysLeft days)" -ForegroundColor $color
    }
    
    # Show available features for this module
    $moduleFeatures = Get-ModuleFeatures -ModuleName $ModuleName
    if ($moduleFeatures) {
        Write-Host "  Available Features:" -ForegroundColor White
        foreach ($feature in $moduleFeatures) {
            $hasAccess = Test-FeatureAccess -FeatureName $feature
            $status = if ($hasAccess) { "✓" } else { "✗" }
            $color = if ($hasAccess) { 'Green' } else { 'Red' }
            Write-Host "    $status $feature" -ForegroundColor $color
        }
    }
}
```

### Configuration-Based Feature Gates

```powershell
function Initialize-FeatureGates {
    param([hashtable]$FeatureConfig)
    
    $licenseStatus = Get-LicenseStatus
    $enabledFeatures = @{}
    
    foreach ($feature in $FeatureConfig.Keys) {
        $config = $FeatureConfig[$feature]
        $requiredTier = $config.RequiredTier
        $requiredFeatures = $config.RequiredFeatures
        
        # Check tier requirement
        $tierAccess = if ($requiredTier) {
            Test-TierAccess -RequiredTier $requiredTier -CurrentTier $licenseStatus.Tier
        } else { $true }
        
        # Check feature requirements
        $featureAccess = if ($requiredFeatures) {
            $requiredFeatures | ForEach-Object { Test-FeatureAccess -FeatureName $_ } | Where-Object { -not $_ } | Measure-Object | Select-Object -ExpandProperty Count
            $featureAccess -eq 0
        } else { $true }
        
        $enabledFeatures[$feature] = $tierAccess -and $featureAccess
        
        if ($enabledFeatures[$feature]) {
            Write-Verbose "Feature enabled: $feature"
        } else {
            Write-Verbose "Feature disabled: $feature (license restriction)"
        }
    }
    
    return $enabledFeatures
}

# Example feature configuration
$FeatureGates = @{
    "ParallelExecution" = @{
        RequiredTier = "pro"
        RequiredFeatures = @("automation")
    }
    "AdvancedMonitoring" = @{
        RequiredTier = "enterprise"
        RequiredFeatures = @("monitoring")
    }
    "CustomReporting" = @{
        RequiredFeatures = @("infrastructure")
    }
}

$EnabledFeatures = Initialize-FeatureGates -FeatureConfig $FeatureGates
```

## Best Practices

### 1. Fail Gracefully

Always provide fallback functionality for unlicensed features:

```powershell
function Deploy-Infrastructure {
    param($Config)
    
    if (Test-FeatureAccess -FeatureName 'automation') {
        Deploy-WithAutomation -Config $Config
    } else {
        Write-Warning "Using manual deployment (automation requires pro license)"
        Deploy-Manually -Config $Config
    }
}
```

### 2. Clear User Communication

Inform users about license limitations:

```powershell
function Show-FeatureUpgradePrompt {
    param([string]$FeatureName, [string]$RequiredTier)
    
    $currentTier = (Get-LicenseStatus).Tier
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║           Feature Upgrade Required           ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Feature: $FeatureName" -ForegroundColor White
    Write-Host "Current Tier: $currentTier" -ForegroundColor Yellow
    Write-Host "Required Tier: $RequiredTier" -ForegroundColor Green
    Write-Host ""
    Write-Host "To access this feature, please upgrade your license." -ForegroundColor White
    Write-Host "Contact support for licensing information." -ForegroundColor Cyan
    Write-Host ""
}
```

### 3. Performance Optimization

Cache license checks for frequently accessed features:

```powershell
function Test-CachedFeatureAccess {
    param([string]$FeatureName)
    
    # Use module-level cache with timeout
    $cacheKey = "feature_$FeatureName"
    $cacheTimeout = 300 # 5 minutes
    
    if ($script:FeatureCache[$cacheKey] -and 
        ((Get-Date) - $script:FeatureCache[$cacheKey].Timestamp).TotalSeconds -lt $cacheTimeout) {
        return $script:FeatureCache[$cacheKey].HasAccess
    }
    
    # Fresh check
    $hasAccess = Test-FeatureAccess -FeatureName $FeatureName
    $script:FeatureCache[$cacheKey] = @{
        HasAccess = $hasAccess
        Timestamp = Get-Date
    }
    
    return $hasAccess
}
```

### 4. Development Mode Support

Provide easy testing capabilities:

```powershell
function Set-DevelopmentMode {
    param([switch]$Enable)
    
    if ($Enable) {
        # Generate a development license
        $devLicense = New-License -Tier 'enterprise' -Email 'dev@localhost' -Days 30
        Set-License -LicenseKey $devLicense -Force
        Write-Host "Development mode enabled (30-day enterprise license)" -ForegroundColor Green
    } else {
        Clear-License -Force
        Write-Host "Development mode disabled" -ForegroundColor Yellow
    }
}
```

## Troubleshooting

### Common Integration Issues

1. **Module Import Order**
   ```powershell
   # Correct: Import LicenseManager first
   Import-Module LicenseManager -ErrorAction SilentlyContinue
   Import-Module YourModule
   
   # Incorrect: May cause dependency issues
   Import-Module YourModule
   Import-Module LicenseManager
   ```

2. **Cache Invalidation**
   ```powershell
   # Clear caches when license changes
   function Update-ModuleLicense {
       Clear-LicenseCache -Type All
       $script:ModuleLicenseCache.LastCheck = $null
       # Re-initialize module features
       Initialize-ModuleLicenseHooks
   }
   ```

3. **Error Handling**
   ```powershell
   function Safe-LicenseCheck {
       param([string]$FeatureName)
       
       try {
           return Test-FeatureAccess -FeatureName $FeatureName
       } catch {
           Write-Warning "License check failed for '$FeatureName': $($_.Exception.Message)"
           return $false # Fail closed
       }
   }
   ```

### Debug Information

```powershell
function Get-ModuleLicenseDebugInfo {
    param([string]$ModuleName)
    
    return @{
        LicenseManagerLoaded = (Get-Module -Name LicenseManager) -ne $null
        LicenseStatus = Get-LicenseStatus
        RegisteredHooks = Get-RegisteredLicenseHooks -ModuleName $ModuleName
        CacheStatistics = Get-LicenseCacheStatistics
        ModuleFeatures = Get-ModuleFeatures -ModuleName $ModuleName
    }
}
```

This integration guide provides comprehensive patterns for implementing license-based feature gating in AitherZero modules. Choose the appropriate pattern based on your module's complexity and requirements.