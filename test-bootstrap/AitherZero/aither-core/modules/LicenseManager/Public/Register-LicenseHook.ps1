function Register-LicenseHook {
    <#
    .SYNOPSIS
        Registers license checking hooks for modules
    .DESCRIPTION
        Provides a standardized way for modules to integrate with license management
    .PARAMETER ModuleName
        Name of the module to register
    .PARAMETER RequiredFeatures
        Array of features required by the module
    .PARAMETER OnLicenseInvalid
        Script block to execute when license is invalid
    .PARAMETER OnFeatureDenied
        Script block to execute when feature access is denied
    .PARAMETER CheckOnLoad
        Whether to check license when module loads
    .EXAMPLE
        Register-LicenseHook -ModuleName "OpenTofuProvider" -RequiredFeatures @("infrastructure") -CheckOnLoad
    .EXAMPLE
        Register-LicenseHook -ModuleName "SecureCredentials" -RequiredFeatures @("security") -OnFeatureDenied { Write-Warning "Enterprise license required" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter()]
        [string[]]$RequiredFeatures = @(),
        
        [Parameter()]
        [scriptblock]$OnLicenseInvalid,
        
        [Parameter()]
        [scriptblock]$OnFeatureDenied,
        
        [Parameter()]
        [switch]$CheckOnLoad,
        
        [Parameter()]
        [hashtable]$ModuleMetadata = @{}
    )
    
    try {
        # Initialize license hooks registry if needed
        if (-not $script:LicenseHooks) {
            $script:LicenseHooks = @{}
        }
        
        # Create hook registration
        $hookInfo = @{
            ModuleName = $ModuleName
            RequiredFeatures = $RequiredFeatures
            OnLicenseInvalid = $OnLicenseInvalid
            OnFeatureDenied = $OnFeatureDenied
            CheckOnLoad = $CheckOnLoad.IsPresent
            ModuleMetadata = $ModuleMetadata
            RegisteredAt = Get-Date
            LastCheck = $null
            LastCheckResult = $null
        }
        
        # Register the hook
        $script:LicenseHooks[$ModuleName] = $hookInfo
        
        # Perform immediate check if requested
        if ($CheckOnLoad) {
            $checkResult = Test-ModuleLicenseHook -ModuleName $ModuleName
            $hookInfo.LastCheck = Get-Date
            $hookInfo.LastCheckResult = $checkResult
        }
        
        # Log registration
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "License hook registered for module" -Level DEBUG -Context @{
                Module = $ModuleName
                RequiredFeatures = $RequiredFeatures -join ", "
                CheckOnLoad = $CheckOnLoad.IsPresent
                ImmediateCheckResult = if ($CheckOnLoad) { $checkResult.HasAccess } else { "Skipped" }
            }
        }
        
        return $hookInfo
        
    } catch {
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Error registering license hook" -Level ERROR -Exception $_.Exception -Context @{
                Module = $ModuleName
            }
        }
        throw
    }
}

function Test-ModuleLicenseHook {
    <#
    .SYNOPSIS
        Tests license requirements for a registered module
    .PARAMETER ModuleName
        Name of the module to test
    .PARAMETER ThrowOnDenied
        Throw exception if access is denied
    .OUTPUTS
        License check result object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter()]
        [switch]$ThrowOnDenied
    )
    
    try {
        if (-not $script:LicenseHooks -or -not $script:LicenseHooks.ContainsKey($ModuleName)) {
            # Module not registered, assume it's free
            return @{
                ModuleName = $ModuleName
                HasAccess = $true
                Message = "Module not registered for license checking"
                RequiredFeatures = @()
                AvailableFeatures = @()
                LicenseStatus = $null
            }
        }
        
        $hook = $script:LicenseHooks[$ModuleName]
        $licenseStatus = Get-LicenseStatus
        
        # Check each required feature
        $deniedFeatures = @()
        $accessGranted = $true
        
        foreach ($feature in $hook.RequiredFeatures) {
            $hasFeature = Test-FeatureAccess -FeatureName $feature
            if (-not $hasFeature) {
                $deniedFeatures += $feature
                $accessGranted = $false
            }
        }
        
        # Create result object
        $result = @{
            ModuleName = $ModuleName
            HasAccess = $accessGranted
            RequiredFeatures = $hook.RequiredFeatures
            DeniedFeatures = $deniedFeatures
            AvailableFeatures = $licenseStatus.Features
            LicenseStatus = $licenseStatus
            Message = if ($accessGranted) { 
                "Access granted" 
            } else { 
                "Access denied - missing features: $($deniedFeatures -join ', ')" 
            }
            CheckedAt = Get-Date
        }
        
        # Update hook with last check result
        $hook.LastCheck = Get-Date
        $hook.LastCheckResult = $result
        
        # Execute appropriate callback
        if (-not $accessGranted) {
            if ($hook.OnFeatureDenied) {
                try {
                    & $hook.OnFeatureDenied $result
                } catch {
                    Write-Warning "Error executing OnFeatureDenied callback for $ModuleName : $($_.Exception.Message)"
                }
            }
            
            if ($ThrowOnDenied) {
                throw "Module '$ModuleName' requires features not available in current license: $($deniedFeatures -join ', ')"
            }
        } elseif (-not $licenseStatus.IsValid) {
            if ($hook.OnLicenseInvalid) {
                try {
                    & $hook.OnLicenseInvalid $result
                } catch {
                    Write-Warning "Error executing OnLicenseInvalid callback for $ModuleName : $($_.Exception.Message)"
                }
            }
        }
        
        # Log check result
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Module license check completed" -Level DEBUG -Context @{
                Module = $ModuleName
                HasAccess = $accessGranted
                RequiredFeatures = $hook.RequiredFeatures -join ", "
                DeniedFeatures = $deniedFeatures -join ", "
                LicenseTier = $licenseStatus.Tier
                LicenseValid = $licenseStatus.IsValid
            }
        }
        
        return $result
        
    } catch {
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Error checking module license hook" -Level ERROR -Exception $_.Exception -Context @{
                Module = $ModuleName
            }
        }
        
        if ($ThrowOnDenied) {
            throw
        }
        
        return @{
            ModuleName = $ModuleName
            HasAccess = $false
            Message = "Error checking license: $($_.Exception.Message)"
            RequiredFeatures = @()
            DeniedFeatures = @()
            AvailableFeatures = @()
            LicenseStatus = $null
            Error = $_.Exception.Message
        }
    }
}

function Get-RegisteredLicenseHooks {
    <#
    .SYNOPSIS
        Gets all registered license hooks
    .PARAMETER ModuleName
        Filter by specific module name
    .OUTPUTS
        Array of registered license hooks
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ModuleName
    )
    
    if (-not $script:LicenseHooks) {
        return @()
    }
    
    $hooks = if ($ModuleName) {
        if ($script:LicenseHooks.ContainsKey($ModuleName)) {
            @($script:LicenseHooks[$ModuleName])
        } else {
            @()
        }
    } else {
        $script:LicenseHooks.Values
    }
    
    # Convert to output objects
    return $hooks | ForEach-Object {
        [PSCustomObject]@{
            ModuleName = $_.ModuleName
            RequiredFeatures = $_.RequiredFeatures
            CheckOnLoad = $_.CheckOnLoad
            RegisteredAt = $_.RegisteredAt
            LastCheck = $_.LastCheck
            LastCheckResult = if ($_.LastCheckResult) { 
                [PSCustomObject]$_.LastCheckResult 
            } else { 
                $null 
            }
            HasCallbacks = ($null -ne $_.OnLicenseInvalid -or $null -ne $_.OnFeatureDenied)
        }
    }
}

function Unregister-LicenseHook {
    <#
    .SYNOPSIS
        Removes a license hook registration
    .PARAMETER ModuleName
        Name of the module to unregister
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )
    
    if ($script:LicenseHooks -and $script:LicenseHooks.ContainsKey($ModuleName)) {
        $script:LicenseHooks.Remove($ModuleName)
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "License hook unregistered" -Level DEBUG -Context @{
                Module = $ModuleName
            }
        }
        
        return $true
    }
    
    return $false
}

function Test-AllRegisteredModules {
    <#
    .SYNOPSIS
        Tests license compliance for all registered modules
    .PARAMETER ShowCompliant
        Include compliant modules in output
    .OUTPUTS
        Array of license check results
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ShowCompliant
    )
    
    if (-not $script:LicenseHooks) {
        return @()
    }
    
    $results = @()
    
    foreach ($moduleName in $script:LicenseHooks.Keys) {
        $result = Test-ModuleLicenseHook -ModuleName $moduleName
        
        if ($ShowCompliant -or -not $result.HasAccess) {
            $results += [PSCustomObject]$result
        }
    }
    
    # Display summary
    $totalModules = $script:LicenseHooks.Count
    $compliantModules = ($results | Where-Object HasAccess).Count
    $nonCompliantModules = $totalModules - $compliantModules
    
    Write-Host "`nLicense Compliance Summary:" -ForegroundColor Yellow
    Write-Host "  Total registered modules: $totalModules" -ForegroundColor White
    Write-Host "  Compliant modules: $compliantModules" -ForegroundColor Green
    Write-Host "  Non-compliant modules: $nonCompliantModules" -ForegroundColor $(if ($nonCompliantModules -gt 0) { 'Red' } else { 'Green' })
    
    return $results
}