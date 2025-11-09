#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Verifies license is safely backed up before allowing encryption
    
.DESCRIPTION
    SAFETY MECHANISM: Prevents source code encryption unless the license/key
    is verifiably backed up in a remote GitHub repository. This prevents
    permanent data loss from local-only keys.
    
    Stage: Pre-Flight Safety
    Dependencies: Security.psm1, LicenseManager.psm1
    Tags: Security, Safety, Backup, Licensing
    
.PARAMETER LicensePath
    Path to license file to verify
    
.PARAMETER GitHubOwner
    GitHub organization/user that should have the backup
    
.PARAMETER GitHubRepo
    GitHub repository that should have the backup (default: licenses)
    
.PARAMETER Force
    Skip remote verification (DANGEROUS - not recommended)
    
.EXAMPLE
    ./0875_Verify-LicenseBackup.ps1 -LicensePath "./license.json" -GitHubOwner "aitherium"
    
.EXAMPLE
    ./0875_Verify-LicenseBackup.ps1 -LicensePath "~/.aitherzero/license.json" -GitHubOwner "myorg" -GitHubRepo "secrets"
    
.NOTES
    Author: AitherZero Team
    Version: 1.0.0
    
    CRITICAL SAFETY SCRIPT: Prevents permanent data loss by ensuring
    license keys are backed up remotely before encryption.
    
    Returns exit code 0 if safe to encrypt, 1 if not safe.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$LicensePath,
    
    [Parameter(Mandatory)]
    [string]$GitHubOwner,
    
    [string]$GitHubRepo = "licenses",
    
    [switch]$Force
)

# Script metadata
$script:ScriptName = "Verify-LicenseBackup"
$script:ScriptVersion = "1.0.0"

function Write-SafetyLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Critical')]
        [string]$Level = 'Info'
    )
    
    $color = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
        'Critical' = 'Magenta'
    }[$Level]
    
    $prefix = @{
        'Info' = 'ℹ'
        'Success' = '✓'
        'Warning' = '⚠'
        'Error' = '✗'
        'Critical' = '🛑'
    }[$Level]
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

try {
    Write-SafetyLog "SAFETY CHECK: Verifying license backup..." -Level 'Info'
    
    # Load modules
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $securityPath = Join-Path $projectRoot "domains/security"
    
    Import-Module (Join-Path $securityPath "Security.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $securityPath "LicenseManager.psm1") -Force -ErrorAction Stop
    
    # Read license
    $license = Get-Content -Path $LicensePath -Raw | ConvertFrom-Json
    $licenseId = $license.LicenseId
    
    Write-SafetyLog "License ID: $licenseId" -Level 'Info'
    
    if ($Force) {
        Write-SafetyLog "FORCE MODE: Skipping remote verification (DANGEROUS!)" -Level 'Critical'
        Write-SafetyLog "You are responsible for backing up this license manually!" -Level 'Warning'
        exit 0
    }
    
    # Check GitHub credentials
    try {
        $githubCred = Get-AitherCredentialGitHub -ErrorAction Stop
        Write-SafetyLog "GitHub credentials configured" -Level 'Success'
    } catch {
        Write-SafetyLog "GitHub credentials not configured" -Level 'Error'
        Write-SafetyLog "Run: Set-AitherCredentialGitHub -Token 'ghp_...'" -Level 'Info'
        Write-SafetyLog "SAFETY BLOCK: Cannot verify remote backup" -Level 'Critical'
        exit 1
    }
    
    # Try to retrieve license from GitHub to verify it exists
    Write-SafetyLog "Checking remote backup at $GitHubOwner/$GitHubRepo..." -Level 'Info'
    
    try {
        $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "license-verify-$licenseId.json"
        
        # Try to get the license from GitHub using the credential system
        $retrieved = $null
        try {
            $retrieved = Get-AitherSecretGitHub -Owner $GitHubOwner -Repo $GitHubRepo `
                -Path "licenses/$licenseId.json" -ErrorAction Stop
        } catch {
            # Fallback to gh CLI if credential system fails
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                $ghResult = gh api "/repos/$GitHubOwner/$GitHubRepo/contents/licenses/$licenseId.json" --jq '.content' 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $retrieved = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ghResult))
                }
            }
        }
        
        if ($retrieved) {
            Write-SafetyLog "Remote backup verified!" -Level 'Success'
            
            # Compare keys to ensure they match
            $remoteLicense = $retrieved | ConvertFrom-Json
            if ($remoteLicense.EncryptionKey -eq $license.EncryptionKey) {
                Write-SafetyLog "Encryption keys match - SAFE TO ENCRYPT" -Level 'Success'
                exit 0
            } else {
                Write-SafetyLog "Encryption keys DO NOT MATCH!" -Level 'Critical'
                Write-SafetyLog "Remote backup has different key - risk of data loss" -Level 'Error'
                exit 1
            }
        } else {
            throw "License not found in remote repository"
        }
        
    } catch {
        Write-SafetyLog "Remote backup verification FAILED" -Level 'Critical'
        Write-SafetyLog "Error: $($_.Exception.Message)" -Level 'Error'
        Write-Host ""
        Write-SafetyLog "🛑 SAFETY BLOCK ACTIVATED 🛑" -Level 'Critical'
        Write-Host ""
        Write-SafetyLog "Cannot proceed with encryption - license not backed up remotely!" -Level 'Critical'
        Write-SafetyLog "This prevents permanent data loss if local key is lost." -Level 'Warning'
        Write-Host ""
        Write-SafetyLog "To fix:" -Level 'Info'
        Write-SafetyLog "1. Deploy license to GitHub first:" -Level 'Info'
        Write-SafetyLog "   ./automation-scripts/0874_Deploy-LicenseToGitHub.ps1 -LicensePath '$LicensePath'" -Level 'Info'
        Write-SafetyLog "2. Then retry encryption" -Level 'Info'
        Write-Host ""
        Write-SafetyLog "To bypass (NOT RECOMMENDED):" -Level 'Info'
        Write-SafetyLog "   Use -Force flag (you are responsible for backup)" -Level 'Info'
        
        exit 1
    }
    
} catch {
    Write-SafetyLog "Safety check failed: $($_.Exception.Message)" -Level 'Error'
    exit 1
}
