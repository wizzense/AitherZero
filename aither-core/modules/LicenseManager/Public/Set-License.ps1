function Set-License {
    <#
    .SYNOPSIS
        Applies a license key to unlock features
    .DESCRIPTION
        Validates and applies a license key, storing it for future use
    .PARAMETER LicenseKey
        The license key to apply
    .PARAMETER LicenseFile
        Path to a license file to import
    .EXAMPLE
        Set-License -LicenseKey "XXXX-XXXX-XXXX-XXXX"
    .EXAMPLE
        Set-License -LicenseFile "C:\path\to\license.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Key')]
        [string]$LicenseKey,
        
        [Parameter(Mandatory, ParameterSetName = 'File')]
        [string]$LicenseFile
    )
    
    try {
        Write-Host "Applying license..." -ForegroundColor Yellow
        
        # Handle license key
        if ($LicenseKey) {
            # For now, we'll decode a base64 JSON license
            # In production, this would contact a license server
            try {
                # Simple format: base64 encoded JSON
                $decodedBytes = [System.Convert]::FromBase64String($LicenseKey)
                $decodedText = [System.Text.Encoding]::UTF8.GetString($decodedBytes)
                $license = $decodedText | ConvertFrom-Json
            } catch {
                throw "Invalid license key format"
            }
        }
        
        # Handle license file
        if ($LicenseFile) {
            if (-not (Test-Path $LicenseFile)) {
                throw "License file not found: $LicenseFile"
            }
            $license = Get-Content $LicenseFile -Raw | ConvertFrom-Json
        }
        
        # Validate license structure
        $requiredProperties = @('licenseId', 'tier', 'features', 'issuedTo', 'expiryDate', 'signature')
        foreach ($prop in $requiredProperties) {
            if (-not $license.PSObject.Properties.Name -contains $prop) {
                throw "Invalid license format - missing $prop"
            }
        }
        
        # Validate expiry
        $expiryDate = [DateTime]::Parse($license.expiryDate)
        if ($expiryDate -lt (Get-Date)) {
            throw "License has expired"
        }
        
        # Validate signature
        if (-not (Validate-LicenseSignature -License $license)) {
            throw "Invalid license signature"
        }
        
        # Save license
        $licenseDir = Split-Path -Parent $script:LicensePath
        if (-not (Test-Path $licenseDir)) {
            New-Item -Path $licenseDir -ItemType Directory -Force | Out-Null
        }
        
        $license | ConvertTo-Json -Depth 10 | Set-Content -Path $script:LicensePath -Encoding UTF8
        
        # Update current license
        $script:CurrentLicense = $license
        
        Write-Host "License applied successfully!" -ForegroundColor Green
        Write-Host "  Tier: $($license.tier)" -ForegroundColor Cyan
        Write-Host "  Features: $($license.features -join ', ')" -ForegroundColor Cyan
        Write-Host "  Expires: $expiryDate" -ForegroundColor Cyan
        Write-Host "  Issued to: $($license.issuedTo)" -ForegroundColor Cyan
        
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Level 'SUCCESS' -Message "License applied: $($license.tier) tier for $($license.issuedTo)"
        }
        
        return $true
        
    } catch {
        Write-Error "Failed to apply license: $_"
        return $false
    }
}

function New-License {
    <#
    .SYNOPSIS
        Creates a new license (for testing/development)
    .DESCRIPTION
        Generates a new license with specified parameters
    .PARAMETER Tier
        License tier (free, pro, enterprise)
    .PARAMETER Email
        Email address for the license
    .PARAMETER Days
        Number of days until expiry
    .EXAMPLE
        New-License -Tier "pro" -Email "user@example.com" -Days 365
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('free', 'pro', 'enterprise')]
        [string]$Tier,
        
        [Parameter(Mandatory)]
        [string]$Email,
        
        [Parameter()]
        [int]$Days = 365
    )
    
    # Get features for tier
    $tierFeatures = switch ($Tier) {
        'enterprise' { @('core', 'development', 'infrastructure', 'ai', 'automation', 'security', 'monitoring', 'enterprise') }
        'pro' { @('core', 'development', 'infrastructure', 'ai', 'automation') }
        default { @('core', 'development') }
    }
    
    $license = @{
        licenseId = [Guid]::NewGuid().ToString()
        tier = $Tier
        features = $tierFeatures
        issuedTo = $Email
        issuedDate = (Get-Date).ToString('yyyy-MM-dd')
        expiryDate = (Get-Date).AddDays($Days).ToString('yyyy-MM-dd')
        signature = ""
    }
    
    # Generate signature (simplified - in production use proper signing)
    $dataToSign = "$($license.licenseId)|$($license.tier)|$($license.issuedTo)|$($license.expiryDate)"
    $signature = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($dataToSign))
    $license.signature = $signature
    
    # Convert to base64 license key
    $licenseJson = $license | ConvertTo-Json -Compress
    $licenseKey = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($licenseJson))
    
    Write-Host "Generated License:" -ForegroundColor Green
    Write-Host $licenseKey -ForegroundColor Yellow
    Write-Host "`nLicense Details:" -ForegroundColor Cyan
    Write-Host ($license | ConvertTo-Json)
    
    return $licenseKey
}