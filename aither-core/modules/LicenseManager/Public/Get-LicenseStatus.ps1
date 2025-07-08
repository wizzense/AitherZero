function Get-LicenseStatus {
    <#
    .SYNOPSIS
        Gets the current license status with performance caching
    .DESCRIPTION
        Retrieves and validates the current license, returning tier and feature access.
        Uses intelligent caching to improve performance for repeated calls.
    .PARAMETER BypassCache
        Skip cache and force fresh license validation
    .PARAMETER RefreshCache
        Refresh the cache after getting current status
    .EXAMPLE
        Get-LicenseStatus
    .EXAMPLE
        Get-LicenseStatus -BypassCache
    .OUTPUTS
        PSCustomObject with license details
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$BypassCache,

        [Parameter()]
        [switch]$RefreshCache
    )

    try {
        # Check cache first (unless bypassed)
        if (-not $BypassCache) {
            $cachedStatus = Get-CachedLicenseStatus
            if ($cachedStatus) {
                return $cachedStatus
            }
        }

        # Check if license file exists
        if (-not (Test-Path $script:LicensePath)) {
            $status = [PSCustomObject]@{
                IsValid = $false
                Tier = 'free'
                Features = @('core', 'development')
                ExpiryDate = $null
                IssuedTo = 'Unlicensed'
                LicenseId = $null
                Message = 'No license found - using free tier'
                CacheSource = 'Fresh'
            }

            # Cache the result
            Set-CachedLicenseStatus -Status $status
            return $status
        }

        # Load and validate license
        try {
            $license = Get-Content $script:LicensePath -Raw | ConvertFrom-Json

            # Validate license structure
            $requiredProperties = @('licenseId', 'tier', 'features', 'issuedTo', 'expiryDate', 'signature')
            foreach ($prop in $requiredProperties) {
                if (-not $license.PSObject.Properties.Name -contains $prop) {
                    throw "Invalid license format - missing $prop"
                }
            }

            # Check expiry
            $expiryDate = [DateTime]::Parse($license.expiryDate)
            $isExpired = $expiryDate -lt (Get-Date)

            # Validate signature with enhanced security
            $isValidSignature = Validate-LicenseSignature -License $license

            if ($isExpired) {
                $status = [PSCustomObject]@{
                    IsValid = $false
                    Tier = 'free'
                    Features = @('core', 'development')
                    ExpiryDate = $expiryDate
                    IssuedTo = $license.issuedTo
                    LicenseId = $license.licenseId
                    Message = 'License expired'
                    CacheSource = 'Fresh'
                }

                # Cache expired license status
                Set-CachedLicenseStatus -Status $status
                return $status
            }

            if (-not $isValidSignature) {
                $status = [PSCustomObject]@{
                    IsValid = $false
                    Tier = 'free'
                    Features = @('core', 'development')
                    ExpiryDate = $expiryDate
                    IssuedTo = $license.issuedTo
                    LicenseId = $license.licenseId
                    Message = 'Invalid license signature'
                    CacheSource = 'Fresh'
                }

                # Cache invalid signature status
                Set-CachedLicenseStatus -Status $status
                return $status
            }

            # Valid license
            $status = [PSCustomObject]@{
                IsValid = $true
                Tier = $license.tier
                Features = $license.features
                ExpiryDate = $expiryDate
                IssuedTo = $license.issuedTo
                LicenseId = $license.licenseId
                Message = 'License valid'
                CacheSource = 'Fresh'
            }

            # Cache valid license status
            Set-CachedLicenseStatus -Status $status

            # Log license validation
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message "License status validated" -Level DEBUG -Context @{
                    LicenseId = $license.licenseId
                    Tier = $license.tier
                    Valid = $true
                    ExpiryDate = $expiryDate
                    DaysUntilExpiry = ($expiryDate - (Get-Date)).Days
                    BypassCache = $BypassCache.IsPresent
                }
            }

            return $status

        } catch {
            Write-Warning "Error reading license: $_"
            $status = [PSCustomObject]@{
                IsValid = $false
                Tier = 'free'
                Features = @('core', 'development')
                ExpiryDate = $null
                IssuedTo = 'Unlicensed'
                LicenseId = $null
                Message = "License error: $_"
                CacheSource = 'Fresh'
            }

            # Cache error status
            Set-CachedLicenseStatus -Status $status

            # Log license error
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message "License validation error" -Level ERROR -Exception $_.Exception -Context @{
                    LicensePath = $script:LicensePath
                    BypassCache = $BypassCache.IsPresent
                }
            }

            return $status
        }

    } catch {
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Critical error in license status check" -Level ERROR -Exception $_.Exception
        }
        Write-Error "Error checking license status: $_"
        throw
    }
}
