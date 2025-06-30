function Get-LicenseStatus {
    <#
    .SYNOPSIS
        Gets the current license status
    .DESCRIPTION
        Retrieves and validates the current license, returning tier and feature access
    .EXAMPLE
        Get-LicenseStatus
    .OUTPUTS
        PSCustomObject with license details
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Check if license file exists
        if (-not (Test-Path $script:LicensePath)) {
            return [PSCustomObject]@{
                IsValid = $false
                Tier = 'free'
                Features = @('core', 'development')
                ExpiryDate = $null
                IssuedTo = 'Unlicensed'
                Message = 'No license found - using free tier'
            }
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
            
            # Validate signature (simplified for now)
            $isValidSignature = Validate-LicenseSignature -License $license
            
            if ($isExpired) {
                return [PSCustomObject]@{
                    IsValid = $false
                    Tier = 'free'
                    Features = @('core', 'development')
                    ExpiryDate = $expiryDate
                    IssuedTo = $license.issuedTo
                    Message = 'License expired'
                }
            }
            
            if (-not $isValidSignature) {
                return [PSCustomObject]@{
                    IsValid = $false
                    Tier = 'free'
                    Features = @('core', 'development')
                    ExpiryDate = $expiryDate
                    IssuedTo = $license.issuedTo
                    Message = 'Invalid license signature'
                }
            }
            
            # Valid license
            return [PSCustomObject]@{
                IsValid = $true
                Tier = $license.tier
                Features = $license.features
                ExpiryDate = $expiryDate
                IssuedTo = $license.issuedTo
                LicenseId = $license.licenseId
                Message = 'License valid'
            }
            
        } catch {
            Write-Warning "Error reading license: $_"
            return [PSCustomObject]@{
                IsValid = $false
                Tier = 'free'
                Features = @('core', 'development')
                ExpiryDate = $null
                IssuedTo = 'Unlicensed'
                Message = "License error: $_"
            }
        }
        
    } catch {
        Write-Error "Error checking license status: $_"
        throw
    }
}