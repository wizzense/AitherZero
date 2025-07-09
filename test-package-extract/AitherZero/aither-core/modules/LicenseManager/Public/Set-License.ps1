function Set-License {
    <#
    .SYNOPSIS
        Installs or updates a license with validation and feature activation
    .DESCRIPTION
        Validates and applies a license from key, file, or string with comprehensive security checks
    .PARAMETER LicenseKey
        The license key to apply (base64 encoded)
    .PARAMETER LicensePath
        Path to a license file to import
    .PARAMETER LicenseString
        License content as a JSON string
    .PARAMETER Force
        Overwrite existing license without confirmation
    .PARAMETER Validate
        Perform immediate validation after installation
    .PARAMETER StrictValidation
        Enable strict validation mode with enhanced security checks
    .EXAMPLE
        Set-License -LicenseKey "XXXX-XXXX-XXXX-XXXX"
    .EXAMPLE
        Set-License -LicensePath "C:\path\to\license.json" -Validate
    .EXAMPLE
        Set-License -LicenseString $jsonContent -Force
    .OUTPUTS
        License installation result object
    #>
    [CmdletBinding(DefaultParameterSetName = 'Key')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Key')]
        [string]$LicenseKey,

        [Parameter(Mandatory, ParameterSetName = 'File')]
        [string]$LicensePath,

        [Parameter(Mandatory, ParameterSetName = 'String')]
        [string]$LicenseString,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Validate,

        [Parameter()]
        [switch]$StrictValidation
    )

    try {
        # Log license installation attempt
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Starting license installation" -Level INFO -Context @{
                ParameterSet = $PSCmdlet.ParameterSetName
                Force = $Force.IsPresent
                Validate = $Validate.IsPresent
                StrictValidation = $StrictValidation.IsPresent
            }
        }

        # Check for existing license
        if ((Test-Path $script:LicensePath) -and -not $Force) {
            $existingLicense = Get-LicenseStatus
            if ($existingLicense.IsValid) {
                $message = "A valid license already exists (Tier: $($existingLicense.Tier), Issued to: $($existingLicense.IssuedTo)). Use -Force to replace it."
                if (-not (Confirm-Action -Message $message -Title "Replace Existing License?")) {
                    return @{
                        Success = $false
                        Error = "License installation cancelled by user"
                        ExistingLicense = $existingLicense
                    }
                }
            }
        }

        Write-Host "Installing license..." -ForegroundColor Yellow

        # Parse license from different sources
        $license = $null
        $sourceInfo = ""

        switch ($PSCmdlet.ParameterSetName) {
            'Key' {
                try {
                    $sourceInfo = "license key"
                    $decodedBytes = [System.Convert]::FromBase64String($LicenseKey)
                    $decodedText = [System.Text.Encoding]::UTF8.GetString($decodedBytes)
                    $license = $decodedText | ConvertFrom-Json
                } catch {
                    throw "Invalid license key format: $($_.Exception.Message)"
                }
            }
            'File' {
                if (-not (Test-Path $LicensePath)) {
                    throw "License file not found: $LicensePath"
                }
                try {
                    $sourceInfo = "file: $LicensePath"
                    $license = Get-Content $LicensePath -Raw | ConvertFrom-Json
                } catch {
                    throw "Invalid license file format: $($_.Exception.Message)"
                }
            }
            'String' {
                try {
                    $sourceInfo = "license string"
                    $license = $LicenseString | ConvertFrom-Json
                } catch {
                    throw "Invalid license string format: $($_.Exception.Message)"
                }
            }
        }

        # Validate license structure
        $requiredProperties = @('licenseId', 'tier', 'features', 'issuedTo', 'expiryDate', 'signature')
        foreach ($prop in $requiredProperties) {
            if (-not $license.PSObject.Properties.Name -contains $prop) {
                throw "Invalid license format - missing required property: $prop"
            }
        }

        # Validate expiry date
        try {
            $expiryDate = [DateTime]::Parse($license.expiryDate)
            if ($expiryDate -lt (Get-Date)) {
                throw "License has expired on $($expiryDate.ToString('yyyy-MM-dd'))"
            }
        } catch [System.FormatException] {
            throw "Invalid expiry date format in license"
        }

        # Validate signature with appropriate mode
        $signatureValid = if ($StrictValidation) {
            Validate-LicenseSignature -License $license -StrictMode
        } else {
            Validate-LicenseSignature -License $license
        }

        if (-not $signatureValid) {
            throw "License signature validation failed"
        }

        # Create backup of existing license if it exists
        if ((Test-Path $script:LicensePath) -and $Force) {
            $backupPath = "$($script:LicensePath).backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
            try {
                Copy-Item -Path $script:LicensePath -Destination $backupPath -ErrorAction SilentlyContinue
                Write-Host "Existing license backed up to: $backupPath" -ForegroundColor DarkGray
            } catch {
                Write-Warning "Could not create license backup: $($_.Exception.Message)"
            }
        }

        # Ensure license directory exists
        $licenseDir = Split-Path -Parent $script:LicensePath
        if (-not (Test-Path $licenseDir)) {
            New-Item -Path $licenseDir -ItemType Directory -Force | Out-Null
        }

        # Save license with proper formatting
        try {
            $license | ConvertTo-Json -Depth 10 | Set-Content -Path $script:LicensePath -Encoding UTF8
        } catch {
            throw "Failed to save license file: $($_.Exception.Message)"
        }

        # Update current license cache and clear caches
        $script:CurrentLicense = $license
        Clear-LicenseCache -Type All

        # Perform additional validation if requested
        if ($Validate) {
            $validationResult = Get-LicenseStatus
            if (-not $validationResult.IsValid) {
                throw "License validation failed after installation: $($validationResult.Message)"
            }
        }

        # Display success information
        Write-Host "License installed successfully!" -ForegroundColor Green
        Write-Host "  Source: $sourceInfo" -ForegroundColor DarkGray
        Write-Host "  License ID: $($license.licenseId)" -ForegroundColor Cyan
        Write-Host "  Tier: $($license.tier)" -ForegroundColor Cyan
        Write-Host "  Features: $($license.features -join ', ')" -ForegroundColor Cyan
        Write-Host "  Expires: $($expiryDate.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
        Write-Host "  Issued to: $($license.issuedTo)" -ForegroundColor Cyan

        # Calculate days until expiry
        $daysUntilExpiry = ($expiryDate - (Get-Date)).Days
        if ($daysUntilExpiry -le 30) {
            $color = if ($daysUntilExpiry -le 7) { "Red" } else { "Yellow" }
            Write-Host "  Warning: License expires in $daysUntilExpiry days" -ForegroundColor $color
        }

        # Log successful installation
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Level 'SUCCESS' -Message "License installed successfully" -Context @{
                LicenseId = $license.licenseId
                Tier = $license.tier
                IssuedTo = $license.issuedTo
                ExpiryDate = $expiryDate
                Source = $sourceInfo
                ValidationMode = if ($StrictValidation) { "Strict" } else { "Standard" }
            }
        }

        # Return detailed result
        return @{
            Success = $true
            LicenseId = $license.licenseId
            Tier = $license.tier
            Features = $license.features
            IssuedTo = $license.issuedTo
            ExpiryDate = $expiryDate
            DaysUntilExpiry = $daysUntilExpiry
            Source = $sourceInfo
            ValidationMode = if ($StrictValidation) { "Strict" } else { "Standard" }
        }

    } catch {
        $errorMsg = "Failed to install license: $($_.Exception.Message)"
        Write-Error $errorMsg

        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Level 'ERROR' -Message $errorMsg -Exception $_.Exception -Context @{
                ParameterSet = $PSCmdlet.ParameterSetName
                Force = $Force.IsPresent
                StrictValidation = $StrictValidation.IsPresent
            }
        }

        return @{
            Success = $false
            Error = $_.Exception.Message
            ParameterSet = $PSCmdlet.ParameterSetName
        }
    }
}
