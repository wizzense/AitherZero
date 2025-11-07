#Requires -Version 7.0

<#
.SYNOPSIS
    License Manager Module for AitherZero Platform
    
.DESCRIPTION
    Manages software licensing, license validation, and key retrieval for
    the source code obfuscation system. Supports local and remote license
    storage with GitHub integration for private license repositories.
    
.NOTES
    License features:
    - License file validation with expiration dates
    - Key retrieval from local or remote sources
    - GitHub integration for private license repositories
    - License caching for offline operation
    - Audit logging for license operations
#>

# Logging helper for LicenseManager module
function Write-LicenseLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "LicenseManager" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow' 
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$($Level.ToUpper().PadRight(11))] [LicenseManager] $Message" -ForegroundColor $color
    }
}

# Initialize module
if (-not (Get-Variable -Name "AitherZeroLicenseManagerInitialized" -Scope Global -ErrorAction SilentlyContinue)) {
    Write-LicenseLog -Message "License Manager module initialized"
    $global:AitherZeroLicenseManagerInitialized = $true
}

<#
.SYNOPSIS
    Creates a new license file
    
.DESCRIPTION
    Generates a license file with specified parameters including expiration date,
    licensed user, and encryption key.
    
.PARAMETER LicenseId
    Unique identifier for the license
    
.PARAMETER LicensedTo
    Name or organization the license is issued to
    
.PARAMETER ExpirationDate
    License expiration date
    
.PARAMETER EncryptionKey
    Encryption key for source code obfuscation
    
.PARAMETER OutputPath
    Path to save the license file
    
.PARAMETER Features
    Array of licensed features
    
.EXAMPLE
    New-License -LicenseId "ABC123" -LicensedTo "Acme Corp" -ExpirationDate (Get-Date).AddYears(1) -EncryptionKey $key -OutputPath "./license.json"
#>
function New-License {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LicenseId,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LicensedTo,
        
        [Parameter(Mandatory)]
        [datetime]$ExpirationDate,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EncryptionKey,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [string[]]$Features = @("SourceCodeObfuscation")
    )
    
    try {
        # Create license object
        $license = @{
            LicenseId = $LicenseId
            LicensedTo = $LicensedTo
            IssuedDate = (Get-Date).ToString("o")
            ExpirationDate = $ExpirationDate.ToString("o")
            Features = $Features
            Version = "1.0"
            EncryptionKey = $EncryptionKey
            Type = "AitherZero-SourceProtection"
        }
        
        # Add signature (HMAC of license data)
        $licenseJson = $license | ConvertTo-Json -Depth 10
        
        # Import Encryption module for hash function
        $encryptionModule = Join-Path $PSScriptRoot "Encryption.psm1"
        if (Test-Path $encryptionModule) {
            Import-Module $encryptionModule -Force -ErrorAction SilentlyContinue
        }
        
        if (Get-Command Get-DataHash -ErrorAction SilentlyContinue) {
            $signature = Get-DataHash -Data $licenseJson -Key $EncryptionKey
            $license.Signature = $signature
        }
        
        # Save license file
        $license | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Force
        
        Write-LicenseLog -Message "License created successfully" -Data @{
            LicenseId = $LicenseId
            LicensedTo = $LicensedTo
            ExpirationDate = $ExpirationDate
            OutputPath = $OutputPath
        }
        
        return $license
    }
    catch {
        Write-LicenseLog -Level Error -Message "License creation failed" -Data @{
            Error = $_.Exception.Message
        }
        throw
    }
}

<#
.SYNOPSIS
    Validates a license file
    
.DESCRIPTION
    Checks if a license file is valid, not expired, and has correct signature.
    
.PARAMETER LicensePath
    Path to the license file
    
.PARAMETER VerifySignature
    Whether to verify the license signature (default: $true)
    
.EXAMPLE
    $isValid = Test-License -LicensePath "./license.json"
    
.EXAMPLE
    Test-License -LicensePath $licensePath -VerifySignature $true
    
.OUTPUTS
    Hashtable with validation results
#>
function Test-License {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$LicensePath,
        
        [bool]$VerifySignature = $true
    )
    
    try {
        # Read license file
        $license = Get-Content -Path $LicensePath -Raw | ConvertFrom-Json
        
        $validationResults = @{
            IsValid = $true
            Reason = ""
            License = $license
            Warnings = @()
        }
        
        # Check required fields
        $requiredFields = @('LicenseId', 'LicensedTo', 'ExpirationDate', 'EncryptionKey', 'Type')
        foreach ($field in $requiredFields) {
            if (-not $license.$field) {
                $validationResults.IsValid = $false
                $validationResults.Reason = "Missing required field: $field"
                Write-LicenseLog -Level Error -Message "License validation failed: Missing field" -Data @{ Field = $field }
                return $validationResults
            }
        }
        
        # Check license type
        if ($license.Type -ne "AitherZero-SourceProtection") {
            $validationResults.IsValid = $false
            $validationResults.Reason = "Invalid license type: $($license.Type)"
            Write-LicenseLog -Level Error -Message "Invalid license type" -Data @{ Type = $license.Type }
            return $validationResults
        }
        
        # Check expiration
        $expirationDate = [datetime]::Parse($license.ExpirationDate)
        if ($expirationDate -lt (Get-Date)) {
            $validationResults.IsValid = $false
            $validationResults.Reason = "License expired on $($expirationDate.ToString('yyyy-MM-dd'))"
            Write-LicenseLog -Level Warning -Message "License expired" -Data @{ 
                ExpirationDate = $expirationDate
                LicenseId = $license.LicenseId
            }
            return $validationResults
        }
        
        # Warn if expiring soon (within 30 days)
        if ($expirationDate -lt (Get-Date).AddDays(30)) {
            $daysRemaining = ($expirationDate - (Get-Date)).Days
            $validationResults.Warnings += "License expires in $daysRemaining days"
            Write-LicenseLog -Level Warning -Message "License expiring soon" -Data @{
                DaysRemaining = $daysRemaining
                ExpirationDate = $expirationDate
            }
        }
        
        # Verify signature if requested
        if ($VerifySignature -and $license.Signature) {
            # Import Encryption module for hash function
            $encryptionModule = Join-Path $PSScriptRoot "Encryption.psm1"
            if (Test-Path $encryptionModule) {
                Import-Module $encryptionModule -Force -ErrorAction SilentlyContinue
            }
            
            if (Get-Command Get-DataHash -ErrorAction SilentlyContinue) {
                # Recreate license object without signature
                $licenseForVerification = @{
                    LicenseId = $license.LicenseId
                    LicensedTo = $license.LicensedTo
                    IssuedDate = $license.IssuedDate
                    ExpirationDate = $license.ExpirationDate
                    Features = $license.Features
                    Version = $license.Version
                    EncryptionKey = $license.EncryptionKey
                    Type = $license.Type
                }
                $licenseJson = $licenseForVerification | ConvertTo-Json -Depth 10
                
                $expectedSignature = Get-DataHash -Data $licenseJson -Key $license.EncryptionKey
                
                if ($expectedSignature -ne $license.Signature) {
                    $validationResults.IsValid = $false
                    $validationResults.Reason = "Invalid license signature"
                    Write-LicenseLog -Level Error -Message "License signature verification failed"
                    return $validationResults
                }
            }
        }
        
        Write-LicenseLog -Message "License validated successfully" -Data @{
            LicenseId = $license.LicenseId
            LicensedTo = $license.LicensedTo
            ExpirationDate = $expirationDate
        }
        
        return $validationResults
    }
    catch {
        Write-LicenseLog -Level Error -Message "License validation failed" -Data @{
            LicensePath = $LicensePath
            Error = $_.Exception.Message
        }
        
        return @{
            IsValid = $false
            Reason = "Error reading or parsing license: $($_.Exception.Message)"
            License = $null
            Warnings = @()
        }
    }
}

<#
.SYNOPSIS
    Retrieves a license from a GitHub repository
    
.DESCRIPTION
    Fetches a license file from a private GitHub repository using GitHub CLI (gh).
    Requires gh CLI to be authenticated.
    
.PARAMETER Owner
    Repository owner/organization
    
.PARAMETER Repo
    Repository name
    
.PARAMETER LicenseId
    License ID to retrieve
    
.PARAMETER OutputPath
    Local path to save the license
    
.PARAMETER Branch
    Branch to retrieve from (default: main)
    
.EXAMPLE
    Get-LicenseFromGitHub -Owner "aitherium" -Repo "licenses" -LicenseId "ABC123" -OutputPath "./license.json"
#>
function Get-LicenseFromGitHub {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Owner,
        
        [Parameter(Mandatory)]
        [string]$Repo,
        
        [Parameter(Mandatory)]
        [string]$LicenseId,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [string]$Branch = "main"
    )
    
    try {
        # Check if gh CLI is available
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            throw "GitHub CLI (gh) is not installed or not in PATH"
        }
        
        # Check if authenticated
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
        }
        
        # Construct file path in repo
        $filePath = "licenses/$LicenseId.json"
        
        Write-LicenseLog -Message "Retrieving license from GitHub" -Data @{
            Owner = $Owner
            Repo = $Repo
            LicenseId = $LicenseId
            Branch = $Branch
        }
        
        # Fetch file content using gh api
        $apiUrl = "/repos/$Owner/$Repo/contents/$filePath`?ref=$Branch"
        $response = gh api $apiUrl --jq '.content' 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to retrieve license from GitHub: $response"
        }
        
        # Decode Base64 content
        $content = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($response))
        
        # Save to output path
        $content | Out-File -FilePath $OutputPath -Force
        
        Write-LicenseLog -Message "License retrieved successfully from GitHub" -Data @{
            OutputPath = $OutputPath
            LicenseId = $LicenseId
        }
        
        return $OutputPath
    }
    catch {
        Write-LicenseLog -Level Error -Message "Failed to retrieve license from GitHub" -Data @{
            Owner = $Owner
            Repo = $Repo
            LicenseId = $LicenseId
            Error = $_.Exception.Message
        }
        throw
    }
}

<#
.SYNOPSIS
    Gets the encryption key from a valid license
    
.DESCRIPTION
    Extracts the encryption key from a validated license file.
    
.PARAMETER LicensePath
    Path to the license file
    
.EXAMPLE
    $key = Get-LicenseKey -LicensePath "./license.json"
    
.OUTPUTS
    Encryption key string
#>
function Get-LicenseKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$LicensePath,
        
        [bool]$VerifySignature = $false
    )
    
    try {
        # Validate license first
        $validation = Test-License -LicensePath $LicensePath -VerifySignature $VerifySignature
        
        if (-not $validation.IsValid) {
            throw "License is invalid: $($validation.Reason)"
        }
        
        Write-LicenseLog -Message "Retrieved encryption key from license" -Data @{
            LicenseId = $validation.License.LicenseId
        }
        
        return $validation.License.EncryptionKey
    }
    catch {
        Write-LicenseLog -Level Error -Message "Failed to retrieve license key" -Data @{
            LicensePath = $LicensePath
            Error = $_.Exception.Message
        }
        throw
    }
}

<#
.SYNOPSIS
    Finds a valid license in standard locations
    
.DESCRIPTION
    Searches for a valid license file in common locations:
    - Current directory (./.license.json)
    - User home directory (~/.aitherzero/license.json)
    - Environment variable (AITHERZERO_LICENSE_PATH)
    
.EXAMPLE
    $licensePath = Find-License
    
.OUTPUTS
    Path to valid license file or $null if not found
#>
function Find-License {
    [CmdletBinding()]
    param()
    
    try {
        $searchPaths = @()
        
        # Environment variable
        if ($env:AITHERZERO_LICENSE_PATH) {
            $searchPaths += $env:AITHERZERO_LICENSE_PATH
        }
        
        # Current directory
        $searchPaths += "./.license.json"
        
        # User home directory
        $homeDir = if ($IsWindows) { $env:USERPROFILE } else { $env:HOME }
        $searchPaths += "$homeDir/.aitherzero/license.json"
        
        # Repository root (if in AitherZero repo)
        if ($env:AITHERZERO_ROOT) {
            $searchPaths += "$env:AITHERZERO_ROOT/.license.json"
        }
        
        Write-LicenseLog -Message "Searching for license file" -Data @{
            SearchPaths = $searchPaths -join ", "
        }
        
        foreach ($path in $searchPaths) {
            if (Test-Path $path -PathType Leaf) {
                # Test if license is valid
                $validation = Test-License -LicensePath $path
                if ($validation.IsValid) {
                    Write-LicenseLog -Message "Found valid license" -Data @{
                        Path = $path
                        LicenseId = $validation.License.LicenseId
                    }
                    return (Resolve-Path $path).Path
                } else {
                    Write-LicenseLog -Level Warning -Message "Found license but validation failed" -Data @{
                        Path = $path
                        Reason = $validation.Reason
                    }
                }
            }
        }
        
        Write-LicenseLog -Level Warning -Message "No valid license found in standard locations"
        return $null
    }
    catch {
        Write-LicenseLog -Level Error -Message "Error searching for license" -Data @{
            Error = $_.Exception.Message
        }
        return $null
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'New-License',
    'Test-License',
    'Get-LicenseFromGitHub',
    'Get-LicenseKey',
    'Find-License'
)
