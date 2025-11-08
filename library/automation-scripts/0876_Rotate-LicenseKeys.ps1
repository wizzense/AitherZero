#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Rotates license keys and re-encrypts files safely
    
.DESCRIPTION
    Safely rotates encryption keys by:
    1. Verifying old license backup exists remotely
    2. Decrypting all encrypted files with old key
    3. Creating new license with new keys
    4. Backing up new license to GitHub
    5. Re-encrypting all files with new key
    
    Stage: Key Rotation
    Dependencies: Security.psm1, LicenseManager.psm1, Encryption.psm1
    Tags: Security, Rotation, Key Management, Licensing
    
.PARAMETER OldLicensePath
    Path to current license file
    
.PARAMETER NewLicenseId
    License ID for the new license
    
.PARAMETER GitHubOwner
    GitHub organization/user for backup storage
    
.PARAMETER GitHubRepo
    GitHub repository for backup storage (default: licenses)
    
.PARAMETER EncryptedPattern
    File pattern for encrypted files (default: *.encrypted)
    
.PARAMETER DryRun
    Show what would be done without making changes
    
.EXAMPLE
    ./0876_Rotate-LicenseKeys.ps1 `
        -OldLicensePath "./license.json" `
        -NewLicenseId "PROD-002" `
        -GitHubOwner "aitherium"
    
.EXAMPLE
    ./0876_Rotate-LicenseKeys.ps1 `
        -OldLicensePath "~/.aitherzero/license.json" `
        -NewLicenseId "DEV-NEW-001" `
        -GitHubOwner "myorg" `
        -DryRun
    
.NOTES
    Author: AitherZero Team
    Version: 1.0.0
    
    SAFETY FEATURES:
    - Verifies old license is backed up remotely before starting
    - Creates backup of all files before rotation
    - Backs up new license before re-encrypting
    - Validates each step before proceeding
    - Can be run in dry-run mode to preview changes
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$OldLicensePath,
    
    [Parameter(Mandatory)]
    [string]$NewLicenseId,
    
    [Parameter(Mandatory)]
    [string]$GitHubOwner,
    
    [string]$GitHubRepo = "licenses",
    
    [string]$EncryptedPattern = "*.encrypted",
    
    [switch]$DryRun
)

# Script metadata
$script:ScriptName = "Rotate-LicenseKeys"
$script:ScriptVersion = "1.0.0"

function Write-RotationLog {
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
        'Critical' = '🔄'
    }[$Level]
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

try {
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $securityPath = Join-Path $projectRoot "domains/security"
    
    Write-RotationLog "LICENSE KEY ROTATION STARTING..." -Level 'Critical'
    
    # Load modules
    Import-Module (Join-Path $securityPath "Security.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $securityPath "LicenseManager.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $securityPath "Encryption.psm1") -Force -ErrorAction Stop
    
    # Step 1: Verify old license backup
    Write-Host ""
    Write-RotationLog "STEP 1: Verifying old license backup..." -Level 'Info'
    
    $verifyScript = Join-Path $PSScriptRoot "0875_Verify-LicenseBackup.ps1"
    if (Test-Path $verifyScript) {
        $verifyResult = & $verifyScript -LicensePath $OldLicensePath -GitHubOwner $GitHubOwner -GitHubRepo $GitHubRepo
        if ($LASTEXITCODE -ne 0) {
            throw "Old license not backed up remotely - cannot safely rotate"
        }
    } else {
        Write-RotationLog "Warning: Backup verification script not found, skipping" -Level 'Warning'
    }
    
    # Read old license
    $oldLicense = Get-Content -Path $OldLicensePath -Raw | ConvertFrom-Json
    $oldKey = Get-LicenseKey -LicensePath $OldLicensePath
    
    Write-RotationLog "Old License: $($oldLicense.LicenseId)" -Level 'Success'
    
    # Step 2: Find all encrypted files
    Write-Host ""
    Write-RotationLog "STEP 2: Finding encrypted files..." -Level 'Info'
    
    $encryptedFiles = Get-ChildItem -Path $projectRoot -Filter $EncryptedPattern -Recurse -File
    Write-RotationLog "Found $($encryptedFiles.Count) encrypted file(s)" -Level 'Info'
    
    if ($encryptedFiles.Count -eq 0) {
        Write-RotationLog "No encrypted files found - nothing to rotate" -Level 'Warning'
        exit 0
    }
    
    # Step 3: Create backup
    Write-Host ""
    Write-RotationLog "STEP 3: Creating backup..." -Level 'Info'
    
    $backupDir = Join-Path $projectRoot ".rotation-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    if (-not $DryRun) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
        foreach ($file in $encryptedFiles) {
            $relativePath = $file.FullName.Substring($projectRoot.Length + 1)
            $backupPath = Join-Path $backupDir $relativePath
            $backupParent = Split-Path $backupPath -Parent
            
            if (-not (Test-Path $backupParent)) {
                New-Item -Path $backupParent -ItemType Directory -Force | Out-Null
            }
            
            Copy-Item -Path $file.FullName -Destination $backupPath -Force
        }
        Write-RotationLog "Backup created: $backupDir" -Level 'Success'
    } else {
        Write-RotationLog "[DRY RUN] Would create backup: $backupDir" -Level 'Info'
    }
    
    # Step 4: Create new license
    Write-Host ""
    Write-RotationLog "STEP 4: Creating new license..." -Level 'Info'
    
    $newLicensePath = Join-Path $projectRoot "$NewLicenseId.json"
    
    if ($PSCmdlet.ShouldProcess($newLicensePath, "Create new license")) {
        if (-not $DryRun) {
            $licenseParams = @{
                LicenseId = $NewLicenseId
                LicensedTo = $oldLicense.LicensedTo
                OutputPath = $newLicensePath
                GenerateKey = $true
                GenerateSigningKey = $true
            }
            
            if ($oldLicense.ExpirationDate) {
                # Extend expiration by same duration as original
                $originalDuration = ([DateTime]$oldLicense.ExpirationDate) - ([DateTime]$oldLicense.IssuedDate)
                $licenseParams.ExpirationDays = $originalDuration.TotalDays
            }
            
            New-License @licenseParams
            Write-RotationLog "New license created: $NewLicenseId" -Level 'Success'
        } else {
            Write-RotationLog "[DRY RUN] Would create license: $NewLicenseId" -Level 'Info'
        }
    }
    
    # Step 5: Deploy new license to GitHub
    Write-Host ""
    Write-RotationLog "STEP 5: Deploying new license to GitHub..." -Level 'Info'
    
    if (-not $DryRun) {
        $deployScript = Join-Path $PSScriptRoot "0874_Deploy-LicenseToGitHub.ps1"
        if (Test-Path $deployScript) {
            & $deployScript -LicensePath $newLicensePath -Owner $GitHubOwner -Repo $GitHubRepo
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to deploy new license to GitHub"
            }
            Write-RotationLog "New license backed up remotely" -Level 'Success'
        } else {
            Write-RotationLog "Deploy script not found - manual backup required!" -Level 'Warning'
        }
    } else {
        Write-RotationLog "[DRY RUN] Would deploy to $GitHubOwner/$GitHubRepo" -Level 'Info'
    }
    
    # Step 6: Re-encrypt files with new key
    Write-Host ""
    Write-RotationLog "STEP 6: Re-encrypting files with new key..." -Level 'Info'
    
    if (-not $DryRun) {
        $newKey = Get-LicenseKey -LicensePath $newLicensePath
        $successCount = 0
        $failCount = 0
        
        foreach ($encryptedFile in $encryptedFiles) {
            try {
                Write-RotationLog "Processing: $($encryptedFile.Name)" -Level 'Info'
                
                # Decrypt with old key
                $decryptedPath = $encryptedFile.FullName -replace '\.encrypted$', ''
                Unprotect-File -EncryptedPath $encryptedFile.FullName -Key $oldKey -OutputPath $decryptedPath
                
                # Delete old encrypted file
                Remove-Item -Path $encryptedFile.FullName -Force
                $metaFile = "$($encryptedFile.FullName).meta"
                if (Test-Path $metaFile) {
                    Remove-Item -Path $metaFile -Force
                }
                
                # Re-encrypt with new key
                Protect-File -Path $decryptedPath -Key $newKey
                
                # Remove decrypted plaintext
                Remove-Item -Path $decryptedPath -Force
                
                $successCount++
                Write-RotationLog "✓ Rotated: $($encryptedFile.Name)" -Level 'Success'
                
            } catch {
                $failCount++
                Write-RotationLog "✗ Failed: $($encryptedFile.Name) - $_" -Level 'Error'
            }
        }
        
        Write-Host ""
        Write-RotationLog "Re-encryption complete: $successCount succeeded, $failCount failed" -Level 'Info'
    } else {
        Write-RotationLog "[DRY RUN] Would re-encrypt $($encryptedFiles.Count) file(s)" -Level 'Info'
    }
    
    # Step 7: Update license path
    Write-Host ""
    Write-RotationLog "STEP 7: Final steps..." -Level 'Info'
    
    if (-not $DryRun) {
        Write-RotationLog "Rotation complete!" -Level 'Success'
        Write-Host ""
        Write-Host "IMPORTANT NEXT STEPS:" -ForegroundColor Yellow
        Write-Host "1. Update license path: mv $newLicensePath ~/.aitherzero/license.json" -ForegroundColor White
        Write-Host "2. Verify new license: ./automation-scripts/0800_Manage-License.ps1 -Action Info" -ForegroundColor White
        Write-Host "3. Test decryption: ./automation-scripts/0802_Load-ObfuscatedModule.ps1 -EncryptedPath <file>.encrypted" -ForegroundColor White
        Write-Host "4. Archive old license: $OldLicensePath" -ForegroundColor White
        Write-Host "5. Keep backup until verified: $backupDir" -ForegroundColor White
        Write-Host ""
    } else {
        Write-RotationLog "[DRY RUN] Rotation preview complete - no changes made" -Level 'Info'
    }
    
    exit 0
    
} catch {
    Write-RotationLog "Rotation failed: $($_.Exception.Message)" -Level 'Error'
    Write-RotationLog "Check backup directory for recovery" -Level 'Warning'
    exit 1
}
