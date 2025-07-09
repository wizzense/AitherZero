function Get-AvailableFeatures {
    <#
    .SYNOPSIS
        Gets list of features available with current license
    .DESCRIPTION
        Returns detailed information about available and locked features
    .PARAMETER IncludeLocked
        Include locked features in the output
    .EXAMPLE
        Get-AvailableFeatures
    .EXAMPLE
        Get-AvailableFeatures -IncludeLocked | Format-Table
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludeLocked
    )

    try {
        # Get current license status
        $licenseStatus = Get-LicenseStatus
        $currentTier = $licenseStatus.Tier

        # Get feature registry
        $registry = Get-FeatureRegistry

        $features = @()

        # Process each feature
        foreach ($feature in $registry.features.PSObject.Properties) {
            $featureName = $feature.Name
            $featureData = $feature.Value

            $isAvailable = Test-TierAccess -RequiredTier $featureData.tier -CurrentTier $currentTier

            if ($isAvailable -or $IncludeLocked) {
                $featureInfo = [PSCustomObject]@{
                    Name = $featureName
                    DisplayName = $featureData.name ?? $featureName
                    RequiredTier = $featureData.tier
                    IsAvailable = $isAvailable
                    Status = if ($isAvailable) { "✓ Available" } else { "🔒 Locked" }
                    Modules = $featureData.modules
                    ModuleCount = $featureData.modules.Count
                }

                $features += $featureInfo
            }
        }

        # Add tier information
        if ($features.Count -gt 0) {
            Write-Host "`nCurrent License Tier: " -NoNewline
            switch ($currentTier) {
                'enterprise' { Write-Host "ENTERPRISE" -ForegroundColor Green }
                'pro' { Write-Host "PROFESSIONAL" -ForegroundColor Cyan }
                default { Write-Host "FREE" -ForegroundColor Yellow }
            }
            Write-Host "Licensed to: $($licenseStatus.IssuedTo)" -ForegroundColor DarkGray
            if ($licenseStatus.ExpiryDate) {
                $daysLeft = ($licenseStatus.ExpiryDate - (Get-Date)).Days
                $expiryColor = if ($daysLeft -lt 30) { 'Red' } elseif ($daysLeft -lt 90) { 'Yellow' } else { 'Green' }
                Write-Host "Expires: $($licenseStatus.ExpiryDate.ToString('yyyy-MM-dd')) ($daysLeft days)" -ForegroundColor $expiryColor
            }
            Write-Host ""
        }

        return $features | Sort-Object RequiredTier, Name

    } catch {
        Write-Error "Failed to get available features: $_"
        throw
    }
}

function Get-LicenseInfo {
    <#
    .SYNOPSIS
        Gets detailed license information
    .DESCRIPTION
        Returns comprehensive information about the current license
    .PARAMETER ShowModules
        Include detailed module access information
    .EXAMPLE
        Get-LicenseInfo
    .EXAMPLE
        Get-LicenseInfo -ShowModules
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ShowModules
    )

    try {
        $status = Get-LicenseStatus
        $registry = Get-FeatureRegistry

        # Basic license info
        $info = [PSCustomObject]@{
            Status = if ($status.IsValid) { "Valid" } else { "Invalid/Expired" }
            Tier = $status.Tier
            TierName = $registry.tiers.$($status.Tier).name ?? $status.Tier
            IssuedTo = $status.IssuedTo
            Features = $status.Features
            ExpiryDate = $status.ExpiryDate
            DaysRemaining = if ($status.ExpiryDate) { ($status.ExpiryDate - (Get-Date)).Days } else { $null }
            Message = $status.Message
        }

        # Display formatted output
        Write-Host "`n╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║           License Information                 ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan

        Write-Host "`nStatus: " -NoNewline
        if ($status.IsValid) {
            Write-Host "✓ Valid" -ForegroundColor Green
        } else {
            Write-Host "✗ $($status.Message)" -ForegroundColor Red
        }

        Write-Host "Tier: " -NoNewline
        switch ($status.Tier) {
            'enterprise' { Write-Host "$($info.TierName) 👑" -ForegroundColor Green }
            'pro' { Write-Host "$($info.TierName) ⭐" -ForegroundColor Cyan }
            default { Write-Host "$($info.TierName)" -ForegroundColor Yellow }
        }

        Write-Host "Licensed to: $($info.IssuedTo)" -ForegroundColor White

        if ($info.ExpiryDate) {
            Write-Host "Expires: " -NoNewline
            $color = if ($info.DaysRemaining -lt 30) { 'Red' } elseif ($info.DaysRemaining -lt 90) { 'Yellow' } else { 'Green' }
            Write-Host "$($info.ExpiryDate.ToString('yyyy-MM-dd')) ($($info.DaysRemaining) days)" -ForegroundColor $color
        }

        Write-Host "`nFeatures:" -ForegroundColor Yellow
        foreach ($feature in $info.Features) {
            $featureData = $registry.features.$feature
            if ($featureData) {
                Write-Host "  • $($featureData.name ?? $feature)" -ForegroundColor White
            } else {
                Write-Host "  • $feature" -ForegroundColor White
            }
        }

        if ($ShowModules) {
            Write-Host "`nAccessible Modules:" -ForegroundColor Yellow

            $allModules = @()
            foreach ($feature in $info.Features) {
                if ($registry.features.$feature.modules) {
                    $allModules += $registry.features.$feature.modules
                }
            }

            $allModules | Select-Object -Unique | Sort-Object | ForEach-Object {
                Write-Host "  • $_" -ForegroundColor DarkGray
            }
        }

        return $info

    } catch {
        Write-Error "Failed to get license info: $_"
        throw
    }
}

function Clear-License {
    <#
    .SYNOPSIS
        Removes the current license
    .DESCRIPTION
        Clears the current license and reverts to free tier
    .PARAMETER Force
        Skip confirmation prompt
    .EXAMPLE
        Clear-License -Force
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force
    )

    try {
        if (-not $Force) {
            if (-not (Confirm-Action "Remove current license and revert to free tier?")) {
                Write-Host "License removal cancelled" -ForegroundColor Yellow
                return
            }
        }

        if (Test-Path $script:LicensePath) {
            Remove-Item -Path $script:LicensePath -Force
            $script:CurrentLicense = $null

            # Clear all caches when license is removed
            Clear-LicenseCache -Type All

            Write-Host "✅ License removed. Reverted to free tier." -ForegroundColor Green

            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level 'INFO' -Message "License cleared - reverted to free tier"
            }

            return $true
        } else {
            Write-Host "No license found to remove" -ForegroundColor Yellow
            return $false
        }

    } catch {
        Write-Error "Failed to clear license: $_"
        throw
    }
}

function Get-FeatureTier {
    <#
    .SYNOPSIS
        Gets the required tier for a feature
    .DESCRIPTION
        Returns the minimum tier required to access a feature
    .PARAMETER Feature
        Feature name to check
    .PARAMETER Module
        Module name to check
    .EXAMPLE
        Get-FeatureTier -Feature "infrastructure"
    .EXAMPLE
        Get-FeatureTier -Module "OpenTofuProvider"
    #>
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'Feature')]
        [string]$Feature,

        [Parameter(ParameterSetName = 'Module')]
        [string]$Module
    )

    try {
        $registry = Get-FeatureRegistry

        if ($Feature) {
            if ($registry.features.$Feature) {
                return $registry.features.$Feature.tier
            }
            return 'free'
        }

        if ($Module) {
            # Check overrides first
            if ($registry.moduleOverrides.$Module) {
                return $registry.moduleOverrides.$Module.tier
            }

            # Find in features
            foreach ($feat in $registry.features.PSObject.Properties) {
                if ($feat.Value.modules -contains $Module) {
                    return $feat.Value.tier
                }
            }
        }

        return 'free'

    } catch {
        Write-Warning "Error getting feature tier: $_"
        return 'free'
    }
}

function Test-ModuleAccess {
    <#
    .SYNOPSIS
        Tests if a module is accessible with current license
    .DESCRIPTION
        Quick check for module accessibility
    .PARAMETER ModuleName
        Name of the module to check
    .EXAMPLE
        Test-ModuleAccess -ModuleName "OpenTofuProvider"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    return Test-FeatureAccess -Module $ModuleName
}
