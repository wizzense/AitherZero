#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Pre-commit hook for source code obfuscation
    
.DESCRIPTION
    Automatically encrypts specified source files before commit when a valid
    license is present. Files matching patterns in .obfuscate-patterns are
    encrypted using the license key.
    
    Stage: Pre-Commit
    Dependencies: Encryption.psm1, LicenseManager.psm1
    Tags: Security, Obfuscation, Git
    
.PARAMETER DryRun
    Show what would be encrypted without actually encrypting
    
.PARAMETER Force
    Force encryption even if files already encrypted
    
.EXAMPLE
    ./0801_Obfuscate-PreCommit.ps1
    
.EXAMPLE
    ./0801_Obfuscate-PreCommit.ps1 -DryRun
    
.NOTES
    This script is designed to be called by the Git pre-commit hook.
    Configure patterns in .obfuscate-patterns file (one pattern per line).
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force
)

# Script metadata
$script:ScriptName = "Obfuscate-PreCommit"
$script:ScriptVersion = "1.0.0"

# Import required modules
$projectRoot = if ($env:AITHERZERO_ROOT) { 
    $env:AITHERZERO_ROOT 
} else { 
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent 
}

$securityPath = Join-Path $projectRoot "domains/security"

try {
    Import-Module (Join-Path $securityPath "Encryption.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $securityPath "LicenseManager.psm1") -Force -ErrorAction Stop
} catch {
    Write-Error "Failed to load required modules: $_"
    exit 1
}

# Helper function for output
function Write-ObfuscateLog {
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

try {
    Write-ObfuscateLog "Pre-commit source code obfuscation check..." -Level 'Info'
    
    # Check if obfuscation is enabled
    $patternsFile = Join-Path $projectRoot ".obfuscate-patterns"
    if (-not (Test-Path $patternsFile)) {
        Write-ObfuscateLog "Obfuscation not configured (.obfuscate-patterns not found)" -Level 'Info'
        Write-ObfuscateLog "To enable obfuscation, create .obfuscate-patterns with file patterns" -Level 'Info'
        exit 0
    }
    
    # Find license
    Write-ObfuscateLog "Searching for valid license..." -Level 'Info'
    $licensePath = Find-License
    
    if (-not $licensePath) {
        Write-ObfuscateLog "No valid license found - obfuscation skipped" -Level 'Warning'
        Write-ObfuscateLog "Run: ./automation-scripts/0800_Manage-License.ps1 -Action Info" -Level 'Info'
        exit 0
    }
    
    # Validate license
    $validation = Test-License -LicensePath $licensePath
    if (-not $validation.IsValid) {
        Write-ObfuscateLog "License invalid: $($validation.Reason)" -Level 'Error'
        exit 1
    }
    
    Write-ObfuscateLog "Valid license found: $($validation.License.LicenseId)" -Level 'Success'
    
    # Get encryption key from license
    $key = Get-LicenseKey -LicensePath $licensePath
    
    # Read patterns
    $patterns = Get-Content $patternsFile | Where-Object { $_ -and $_ -notmatch '^\s*#' }
    if ($patterns.Count -eq 0) {
        Write-ObfuscateLog "No obfuscation patterns configured" -Level 'Info'
        exit 0
    }
    
    Write-ObfuscateLog "Loaded $($patterns.Count) obfuscation pattern(s)" -Level 'Info'
    
    # Get staged files
    $stagedFiles = git diff --cached --name-only --diff-filter=ACM 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $stagedFiles) {
        Write-ObfuscateLog "No files staged for commit" -Level 'Info'
        exit 0
    }
    
    # Filter files matching patterns
    $filesToObfuscate = @()
    foreach ($file in $stagedFiles) {
        $fullPath = Join-Path $projectRoot $file
        if (-not (Test-Path $fullPath -PathType Leaf)) {
            continue
        }
        
        foreach ($pattern in $patterns) {
            if ($file -like $pattern) {
                # Check if already encrypted
                $encryptedPath = "$fullPath.encrypted"
                if ((Test-Path $encryptedPath) -and -not $Force) {
                    Write-ObfuscateLog "Already encrypted: $file" -Level 'Info'
                    continue
                }
                
                $filesToObfuscate += $file
                break
            }
        }
    }
    
    if ($filesToObfuscate.Count -eq 0) {
        Write-ObfuscateLog "No files to obfuscate" -Level 'Info'
        exit 0
    }
    
    Write-ObfuscateLog "Found $($filesToObfuscate.Count) file(s) to obfuscate" -Level 'Info'
    
    # Encrypt files
    $encryptedCount = 0
    foreach ($file in $filesToObfuscate) {
        $fullPath = Join-Path $projectRoot $file
        
        if ($DryRun) {
            Write-ObfuscateLog "[DRY RUN] Would encrypt: $file" -Level 'Info'
        } else {
            try {
                Write-ObfuscateLog "Encrypting: $file" -Level 'Info'
                
                $result = Protect-File -Path $fullPath -Key $key
                
                # Stage encrypted files
                git add -f $result.EncryptedFile 2>&1 | Out-Null
                git add -f $result.MetadataFile 2>&1 | Out-Null
                
                # Unstage and remove original plaintext from the commit
                git reset HEAD $file 2>&1 | Out-Null
                
                # Remove original from working directory (after backup warning)
                # Uncomment to auto-remove plaintext after encryption:
                # Remove-Item -Path $fullPath -Force
                
                $encryptedCount++
                Write-ObfuscateLog "Encrypted: $file → $($result.EncryptedFile)" -Level 'Success'
            } catch {
                Write-ObfuscateLog "Failed to encrypt $file : $_" -Level 'Error'
                exit 1
            }
        }
    }
    
    if ($DryRun) {
        Write-ObfuscateLog "Dry run complete - no files were encrypted" -Level 'Info'
    } else {
        Write-ObfuscateLog "Obfuscation complete - encrypted $encryptedCount file(s)" -Level 'Success'
    }
    
    exit 0
} catch {
    Write-ObfuscateLog "Error: $($_.Exception.Message)" -Level 'Error'
    if ($env:AITHERZERO_DEBUG) {
        Write-Host ""
        Write-Host "Stack trace:"
        Write-Host $_.ScriptStackTrace
    }
    exit 1
}
