function Validate-LicenseSignature {
    <#
    .SYNOPSIS
        Validates a license signature using enhanced security
    .DESCRIPTION
        Checks if the license signature is valid using multiple validation methods
    .PARAMETER License
        License object to validate
    .PARAMETER StrictMode
        Enable strict validation mode with enhanced security checks
    .OUTPUTS
        Boolean indicating signature validity
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$License,
        
        [Parameter()]
        [switch]$StrictMode
    )
    
    try {
        # Log validation attempt
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Starting license signature validation" -Level DEBUG -Context @{
                LicenseId = $License.licenseId
                Tier = $License.tier
                StrictMode = $StrictMode.IsPresent
            }
        }
        
        # Basic validation
        if (-not $License.signature -or [string]::IsNullOrWhiteSpace($License.signature)) {
            Write-Warning "License signature is missing or empty"
            return $false
        }
        
        # Validate signature format
        if (-not (Test-SignatureFormat -Signature $License.signature)) {
            Write-Warning "License signature format is invalid"
            return $false
        }
        
        # Create canonical data to sign (ordered consistently)
        $canonicalData = Get-CanonicalLicenseData -License $License
        
        # Perform signature validation
        $isValid = $false
        
        try {
            if ($StrictMode) {
                $isValid = Test-StrictSignature -License $License -CanonicalData $canonicalData
            } else {
                $isValid = Test-BasicSignature -License $License -CanonicalData $canonicalData
            }
        } catch {
            Write-Warning "Error during signature validation: $($_.Exception.Message)"
            return $false
        }
        
        # Additional security checks
        if ($isValid -and $StrictMode) {
            $isValid = Test-LicenseIntegrity -License $License
        }
        
        # Log validation result
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "License signature validation completed" -Level DEBUG -Context @{
                LicenseId = $License.licenseId
                Valid = $isValid
                ValidationMethod = if ($StrictMode) { "Strict" } else { "Basic" }
            }
        }
        
        return $isValid
        
    } catch {
        Write-Warning "Error validating license signature: $($_.Exception.Message)"
        return $false
    }
}

function Test-SignatureFormat {
    <#
    .SYNOPSIS
        Tests if signature has valid format
    .PARAMETER Signature
        The signature string to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Signature
    )
    
    try {
        # Check if it's valid base64
        $null = [System.Convert]::FromBase64String($Signature)
        
        # Check minimum length (signatures should be reasonably long)
        if ($Signature.Length -lt 16) {
            return $false
        }
        
        # Check for suspicious patterns
        if ($Signature -match '^[0]+$' -or $Signature -match '^[A-Z]+$') {
            return $false
        }
        
        return $true
    } catch {
        return $false
    }
}

function Get-CanonicalLicenseData {
    <#
    .SYNOPSIS
        Creates canonical data representation for signing
    .PARAMETER License
        License object to create canonical data for
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$License
    )
    
    # Create ordered, canonical representation
    $canonicalData = @(
        "licenseId:$($License.licenseId)"
        "tier:$($License.tier)"
        "issuedTo:$($License.issuedTo)"
        "expiryDate:$($License.expiryDate)"
        "features:$($License.features -join ',')"
    ) -join "|"
    
    return $canonicalData
}

function Test-BasicSignature {
    <#
    .SYNOPSIS
        Performs basic signature validation
    .PARAMETER License
        License object
    .PARAMETER CanonicalData
        Canonical data string
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$License,
        
        [Parameter(Mandatory)]
        [string]$CanonicalData
    )
    
    try {
        # Decode signature
        $decodedSignature = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($License.signature))
        
        # For basic validation, use simple comparison
        # This is a simplified approach - in production you'd use proper cryptographic verification
        return $decodedSignature -eq $CanonicalData
        
    } catch {
        return $false
    }
}

function Test-StrictSignature {
    <#
    .SYNOPSIS
        Performs strict signature validation with enhanced security
    .PARAMETER License
        License object
    .PARAMETER CanonicalData
        Canonical data string
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$License,
        
        [Parameter(Mandatory)]
        [string]$CanonicalData
    )
    
    try {
        # In strict mode, we would use proper cryptographic verification
        # For this implementation, we'll add additional checks
        
        # Basic signature check
        $basicValid = Test-BasicSignature -License $License -CanonicalData $CanonicalData
        if (-not $basicValid) {
            return $false
        }
        
        # Additional entropy check - signature should have reasonable entropy
        $signature = $License.signature
        $uniqueChars = ($signature.ToCharArray() | Sort-Object -Unique).Count
        if ($uniqueChars -lt 8) {
            Write-Warning "License signature has insufficient entropy"
            return $false
        }
        
        # Check for timestamp proximity (signatures should be reasonably recent for new licenses)
        if ($License.PSObject.Properties.Name -contains 'issuedDate') {
            $issuedDate = [DateTime]::Parse($License.issuedDate)
            $maxAge = (Get-Date).AddYears(-10)  # Licenses shouldn't be older than 10 years
            if ($issuedDate -lt $maxAge) {
                Write-Warning "License issue date is suspiciously old"
                return $false
            }
        }
        
        return $true
        
    } catch {
        Write-Warning "Error in strict signature validation: $($_.Exception.Message)"
        return $false
    }
}

function Test-LicenseIntegrity {
    <#
    .SYNOPSIS
        Tests overall license integrity
    .PARAMETER License
        License object to test
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$License
    )
    
    try {
        # Check required properties exist
        $requiredProps = @('licenseId', 'tier', 'features', 'issuedTo', 'expiryDate', 'signature')
        foreach ($prop in $requiredProps) {
            if (-not $License.PSObject.Properties.Name -contains $prop) {
                Write-Warning "License missing required property: $prop"
                return $false
            }
        }
        
        # Validate tier is known
        $validTiers = @('free', 'pro', 'professional', 'enterprise')
        if ($License.tier -notin $validTiers) {
            Write-Warning "License contains invalid tier: $($License.tier)"
            return $false
        }
        
        # Validate features array
        if (-not $License.features -or $License.features.Count -eq 0) {
            Write-Warning "License contains no features"
            return $false
        }
        
        # Validate license ID format (should be GUID-like)
        if (-not [System.Guid]::TryParse($License.licenseId, [ref][System.Guid]::Empty)) {
            # Allow non-GUID formats but they should be reasonable length
            if ($License.licenseId.Length -lt 8) {
                Write-Warning "License ID format appears invalid"
                return $false
            }
        }
        
        # Validate expiry date is parseable and reasonable
        try {
            $expiryDate = [DateTime]::Parse($License.expiryDate)
            $minExpiry = (Get-Date).AddYears(-20)  # Shouldn't expire before 20 years ago
            $maxExpiry = (Get-Date).AddYears(20)   # Shouldn't expire more than 20 years from now
            
            if ($expiryDate -lt $minExpiry -or $expiryDate -gt $maxExpiry) {
                Write-Warning "License expiry date is outside reasonable range"
                return $false
            }
        } catch {
            Write-Warning "License expiry date cannot be parsed"
            return $false
        }
        
        return $true
        
    } catch {
        Write-Warning "Error checking license integrity: $($_.Exception.Message)"
        return $false
    }
}