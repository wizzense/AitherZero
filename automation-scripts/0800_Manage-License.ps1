#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Manages AitherZero licenses for source code protection
    
.DESCRIPTION
    Creates, validates, and retrieves licenses for the AitherZero source code
    obfuscation and licensing system. Supports local license generation and
    remote license retrieval from private GitHub repositories.
    
    Stage: License Management
    Dependencies: Security.psm1, Encryption.psm1, LicenseManager.psm1
    Tags: Security, Licensing, Obfuscation
    
.PARAMETER Action
    Action to perform: Create, Validate, Retrieve, or Info
    
.PARAMETER LicenseId
    Unique identifier for the license
    
.PARAMETER LicensedTo
    Name or organization the license is issued to
    
.PARAMETER ExpirationDays
    Number of days until license expires (default: 365)
    
.PARAMETER OutputPath
    Path to save the license file
    
.PARAMETER LicensePath
    Path to an existing license file (for Validate action)
    
.PARAMETER GitHubOwner
    GitHub organization/owner for remote license retrieval
    
.PARAMETER GitHubRepo
    GitHub repository name for remote license retrieval
    
.PARAMETER GenerateKey
    Generate a new encryption key instead of using an existing one
    
.EXAMPLE
    ./0800_Manage-License.ps1 -Action Create -LicenseId "DEMO-001" -LicensedTo "Acme Corp"
    
.EXAMPLE
    ./0800_Manage-License.ps1 -Action Validate -LicensePath "./license.json"
    
.EXAMPLE
    ./0800_Manage-License.ps1 -Action Retrieve -LicenseId "PROD-123" -GitHubOwner "aitherium" -GitHubRepo "licenses"
    
.EXAMPLE
    ./0800_Manage-License.ps1 -Action Info
    
.NOTES
    Author: AitherZero Team
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Create', 'Validate', 'Retrieve', 'Info')]
    [string]$Action,
    
    [string]$LicenseId,
    
    [string]$LicensedTo,
    
    [int]$ExpirationDays = 365,
    
    [string]$OutputPath,
    
    [string]$LicensePath,
    
    [string]$GitHubOwner,
    
    [string]$GitHubRepo,
    
    [switch]$GenerateKey
)

# Script metadata
$script:ScriptName = "Manage-License"
$script:ScriptVersion = "1.0.0"

# Import required modules
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$securityPath = Join-Path $projectRoot "domains/security"

try {
    Import-Module (Join-Path $securityPath "Encryption.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $securityPath "LicenseManager.psm1") -Force -ErrorAction Stop
    Write-Host "✓ Loaded security modules" -ForegroundColor Green
} catch {
    Write-Error "Failed to load required modules: $_"
    exit 1
}

# Helper function for consistent output
function Write-ScriptOutput {
    param(
        [string]$Message,
        [string]$Level = 'Info'
    )
    
    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        default { 'White' }
    }
    
    $prefix = switch ($Level) {
        'Success' { '✓' }
        'Warning' { '⚠' }
        'Error' { '✗' }
        default { 'ℹ' }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

# Main script logic
try {
    switch ($Action) {
        'Create' {
            Write-ScriptOutput "Creating new license..." -Level 'Info'
            
            # Validate required parameters
            if (-not $LicenseId) {
                throw "LicenseId is required for Create action"
            }
            if (-not $LicensedTo) {
                throw "LicensedTo is required for Create action"
            }
            
            # Generate or get encryption key
            if ($GenerateKey) {
                Write-ScriptOutput "Generating new encryption key..." -Level 'Info'
                $key = New-EncryptionKey
                Write-ScriptOutput "Encryption key: $key" -Level 'Warning'
                Write-ScriptOutput "SAVE THIS KEY SECURELY - You will need it to decrypt obfuscated code!" -Level 'Warning'
            } else {
                # Prompt for key
                $keyInput = Read-Host -Prompt "Enter encryption key (or press Enter to generate new)"
                if ([string]::IsNullOrWhiteSpace($keyInput)) {
                    $key = New-EncryptionKey
                    Write-ScriptOutput "Generated new key: $key" -Level 'Warning'
                    Write-ScriptOutput "SAVE THIS KEY SECURELY!" -Level 'Warning'
                } else {
                    $key = $keyInput
                }
            }
            
            # Determine output path
            if (-not $OutputPath) {
                $OutputPath = Join-Path (Get-Location) "$LicenseId.json"
            }
            
            # Calculate expiration date
            $expirationDate = (Get-Date).AddDays($ExpirationDays)
            
            # Create license
            $license = New-License `
                -LicenseId $LicenseId `
                -LicensedTo $LicensedTo `
                -ExpirationDate $expirationDate `
                -EncryptionKey $key `
                -OutputPath $OutputPath
            
            Write-ScriptOutput "License created successfully!" -Level 'Success'
            Write-ScriptOutput "License ID: $LicenseId" -Level 'Info'
            Write-ScriptOutput "Licensed To: $LicensedTo" -Level 'Info'
            Write-ScriptOutput "Expires: $($expirationDate.ToString('yyyy-MM-dd'))" -Level 'Info'
            Write-ScriptOutput "Saved to: $OutputPath" -Level 'Info'
            Write-Host ""
            Write-ScriptOutput "Next steps:" -Level 'Info'
            Write-Host "  1. Store the license file securely"
            Write-Host "  2. Save the encryption key in a secure location"
            Write-Host "  3. Configure license path in environment: AITHERZERO_LICENSE_PATH=$OutputPath"
        }
        
        'Validate' {
            Write-ScriptOutput "Validating license..." -Level 'Info'
            
            # Determine license path
            if (-not $LicensePath) {
                $LicensePath = Find-License
                if (-not $LicensePath) {
                    throw "No license file specified and none found in standard locations"
                }
                Write-ScriptOutput "Found license: $LicensePath" -Level 'Info'
            }
            
            # Validate license
            $validation = Test-License -LicensePath $LicensePath
            
            if ($validation.IsValid) {
                Write-ScriptOutput "License is VALID!" -Level 'Success'
                Write-ScriptOutput "License ID: $($validation.License.LicenseId)" -Level 'Info'
                Write-ScriptOutput "Licensed To: $($validation.License.LicensedTo)" -Level 'Info'
                Write-ScriptOutput "Issued: $($validation.License.IssuedDate)" -Level 'Info'
                Write-ScriptOutput "Expires: $($validation.License.ExpirationDate)" -Level 'Info'
                Write-ScriptOutput "Features: $($validation.License.Features -join ', ')" -Level 'Info'
                
                # Show warnings if any
                if ($validation.Warnings.Count -gt 0) {
                    Write-Host ""
                    foreach ($warning in $validation.Warnings) {
                        Write-ScriptOutput $warning -Level 'Warning'
                    }
                }
            } else {
                Write-ScriptOutput "License is INVALID!" -Level 'Error'
                Write-ScriptOutput "Reason: $($validation.Reason)" -Level 'Error'
            }
        }
        
        'Retrieve' {
            Write-ScriptOutput "Retrieving license from GitHub..." -Level 'Info'
            
            # Validate required parameters
            if (-not $LicenseId) {
                throw "LicenseId is required for Retrieve action"
            }
            if (-not $GitHubOwner) {
                throw "GitHubOwner is required for Retrieve action"
            }
            if (-not $GitHubRepo) {
                throw "GitHubRepo is required for Retrieve action"
            }
            
            # Determine output path
            if (-not $OutputPath) {
                $homeDir = if ($IsWindows) { $env:USERPROFILE } else { $env:HOME }
                $licenseDir = Join-Path $homeDir ".aitherzero"
                if (-not (Test-Path $licenseDir)) {
                    New-Item -ItemType Directory -Path $licenseDir -Force | Out-Null
                }
                $OutputPath = Join-Path $licenseDir "license.json"
            }
            
            # Retrieve license
            $retrievedPath = Get-LicenseFromGitHub `
                -Owner $GitHubOwner `
                -Repo $GitHubRepo `
                -LicenseId $LicenseId `
                -OutputPath $OutputPath
            
            Write-ScriptOutput "License retrieved successfully!" -Level 'Success'
            Write-ScriptOutput "Saved to: $retrievedPath" -Level 'Info'
            
            # Validate the retrieved license
            Write-Host ""
            Write-ScriptOutput "Validating retrieved license..." -Level 'Info'
            $validation = Test-License -LicensePath $retrievedPath
            
            if ($validation.IsValid) {
                Write-ScriptOutput "License is valid!" -Level 'Success'
                Write-ScriptOutput "Licensed To: $($validation.License.LicensedTo)" -Level 'Info'
            } else {
                Write-ScriptOutput "Retrieved license is invalid: $($validation.Reason)" -Level 'Error'
            }
        }
        
        'Info' {
            Write-ScriptOutput "License System Information" -Level 'Info'
            Write-Host ""
            
            # Search for licenses
            Write-ScriptOutput "Searching for licenses in standard locations..." -Level 'Info'
            $foundLicense = Find-License
            
            if ($foundLicense) {
                Write-ScriptOutput "Found valid license: $foundLicense" -Level 'Success'
                
                $validation = Test-License -LicensePath $foundLicense
                Write-Host ""
                Write-Host "License Details:"
                Write-Host "  ID: $($validation.License.LicenseId)"
                Write-Host "  Licensed To: $($validation.License.LicensedTo)"
                Write-Host "  Issued: $($validation.License.IssuedDate)"
                Write-Host "  Expires: $($validation.License.ExpirationDate)"
                Write-Host "  Features: $($validation.License.Features -join ', ')"
            } else {
                Write-ScriptOutput "No valid license found" -Level 'Warning'
                Write-Host ""
                Write-Host "Searched locations:"
                Write-Host "  - Current directory: ./.license.json"
                if ($env:AITHERZERO_ROOT) {
                    Write-Host "  - Repository root: $env:AITHERZERO_ROOT/.license.json"
                }
                $homeDir = if ($IsWindows) { $env:USERPROFILE } else { $env:HOME }
                Write-Host "  - User home: $homeDir/.aitherzero/license.json"
                if ($env:AITHERZERO_LICENSE_PATH) {
                    Write-Host "  - Environment: $env:AITHERZERO_LICENSE_PATH"
                }
            }
            
            Write-Host ""
            Write-Host "Environment Variables:"
            Write-Host "  AITHERZERO_LICENSE_PATH: $($env:AITHERZERO_LICENSE_PATH)"
            Write-Host "  AITHERZERO_ROOT: $($env:AITHERZERO_ROOT)"
            
            Write-Host ""
            Write-Host "GitHub CLI Status:"
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                $authStatus = gh auth status 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-ScriptOutput "GitHub CLI is authenticated" -Level 'Success'
                } else {
                    Write-ScriptOutput "GitHub CLI is not authenticated" -Level 'Warning'
                    Write-Host "  Run 'gh auth login' to authenticate"
                }
            } else {
                Write-ScriptOutput "GitHub CLI not installed" -Level 'Warning'
            }
        }
    }
    
    exit 0
} catch {
    Write-ScriptOutput "Error: $($_.Exception.Message)" -Level 'Error'
    if ($env:AITHERZERO_DEBUG) {
        Write-Host ""
        Write-Host "Stack trace:"
        Write-Host $_.ScriptStackTrace
    }
    exit 1
}
