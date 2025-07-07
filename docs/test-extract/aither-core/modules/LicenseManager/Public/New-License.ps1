function New-License {
    <#
    .SYNOPSIS
        Creates a new license (for testing/development)
    .DESCRIPTION
        Generates a new license with specified parameters for testing and development purposes
    .PARAMETER Tier
        License tier (free, pro, enterprise)
    .PARAMETER Email
        Email address for the license
    .PARAMETER Days
        Number of days until expiry
    .PARAMETER IssuedTo
        Name or organization the license is issued to (defaults to Email)
    .EXAMPLE
        New-License -Tier "pro" -Email "user@example.com" -Days 365
    .EXAMPLE
        New-License -Tier "enterprise" -Email "admin@company.com" -IssuedTo "Company Inc" -Days 1095
    .OUTPUTS
        Base64 encoded license key
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('free', 'pro', 'enterprise')]
        [string]$Tier,
        
        [Parameter(Mandatory)]
        [string]$Email,
        
        [Parameter()]
        [int]$Days = 365,
        
        [Parameter()]
        [string]$IssuedTo
    )
    
    try {
        # Use Email as IssuedTo if not specified
        if (-not $IssuedTo) {
            $IssuedTo = $Email
        }
        
        # Get features for tier
        $tierFeatures = switch ($Tier) {
            'enterprise' { 
                @('core', 'development', 'infrastructure', 'ai', 'automation', 'security', 'monitoring', 'enterprise') 
            }
            'pro' { 
                @('core', 'development', 'infrastructure', 'ai', 'automation') 
            }
            default { 
                @('core', 'development') 
            }
        }
        
        # Create license object
        $license = @{
            licenseId = [Guid]::NewGuid().ToString()
            tier = $Tier
            features = $tierFeatures
            issuedTo = $IssuedTo
            issuedDate = (Get-Date).ToString('yyyy-MM-dd')
            expiryDate = (Get-Date).AddDays($Days).ToString('yyyy-MM-dd')
            signature = ""
            metadata = @{
                generator = "AitherZero-LicenseManager"
                version = "1.0"
                createdAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
                email = $Email
            }
        }
        
        # Generate canonical data for signing
        $canonicalData = "licenseId:$($license.licenseId)|tier:$($license.tier)|issuedTo:$($license.issuedTo)|expiryDate:$($license.expiryDate)|features:$($license.features -join ',')"
        
        # Generate signature (simplified - in production use proper cryptographic signing)
        $signature = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($canonicalData))
        $license.signature = $signature
        
        # Convert to base64 license key
        $licenseJson = $license | ConvertTo-Json -Compress -Depth 10
        $licenseKey = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($licenseJson))
        
        # Display license information
        Write-Host "`nGenerated License Key:" -ForegroundColor Green
        Write-Host $licenseKey -ForegroundColor Yellow
        
        Write-Host "`nLicense Details:" -ForegroundColor Cyan
        Write-Host "  License ID: $($license.licenseId)" -ForegroundColor White
        Write-Host "  Tier: $($license.tier)" -ForegroundColor White
        Write-Host "  Issued To: $($license.issuedTo)" -ForegroundColor White
        Write-Host "  Email: $($license.metadata.email)" -ForegroundColor White
        Write-Host "  Issue Date: $($license.issuedDate)" -ForegroundColor White
        Write-Host "  Expiry Date: $($license.expiryDate)" -ForegroundColor White
        Write-Host "  Features: $($license.features -join ', ')" -ForegroundColor White
        Write-Host "  Days Valid: $Days" -ForegroundColor White
        
        # Log license generation
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "License generated for development/testing" -Level INFO -Context @{
                LicenseId = $license.licenseId
                Tier = $license.tier
                IssuedTo = $license.issuedTo
                Email = $Email
                Days = $Days
                Features = $license.features -join ", "
            }
        }
        
        return $licenseKey
        
    } catch {
        Write-Error "Failed to generate license: $($_.Exception.Message)"
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "License generation failed" -Level ERROR -Exception $_.Exception -Context @{
                Tier = $Tier
                Email = $Email
                Days = $Days
            }
        }
        
        throw
    }
}