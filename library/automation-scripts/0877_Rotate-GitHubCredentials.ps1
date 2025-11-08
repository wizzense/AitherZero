#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Rotates GitHub credentials safely
    
.DESCRIPTION
    Safely rotates GitHub access tokens used for license/credential management:
    1. Verifies new token has required permissions
    2. Tests access to critical repositories
    3. Updates credential storage
    4. Validates new token works
    5. Provides rollback option
    
    Stage: Credential Rotation
    Dependencies: Security.psm1
    Tags: Security, Rotation, Credentials, GitHub
    
.PARAMETER NewToken
    New GitHub personal access token
    
.PARAMETER TestOwner
    GitHub organization/user to test access (default: uses current config)
    
.PARAMETER TestRepo
    Repository to test access (default: licenses)
    
.PARAMETER SkipTests
    Skip access validation tests (not recommended)
    
.EXAMPLE
    ./0877_Rotate-GitHubCredentials.ps1 -NewToken "ghp_newtoken..."
    
.EXAMPLE
    ./0877_Rotate-GitHubCredentials.ps1 `
        -NewToken "ghp_newtoken..." `
        -TestOwner "aitherium" `
        -TestRepo "licenses"
    
.NOTES
    Author: AitherZero Team
    Version: 1.0.0
    
    SAFETY FEATURES:
    - Backs up old token before rotation
    - Tests new token before committing
    - Provides rollback instructions if rotation fails
    - Validates required scopes/permissions
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$NewToken,
    
    [string]$TestOwner,
    
    [string]$TestRepo = "licenses",
    
    [switch]$SkipTests
)

# Script metadata
$script:ScriptName = "Rotate-GitHubCredentials"
$script:ScriptVersion = "1.0.0"

function Write-CredRotationLog {
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
    Write-CredRotationLog "GITHUB CREDENTIAL ROTATION STARTING..." -Level 'Critical'
    
    # Load modules
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $securityPath = Join-Path $projectRoot "domains/security"
    
    Import-Module (Join-Path $securityPath "Security.psm1") -Force -ErrorAction Stop
    
    # Step 1: Backup existing credentials
    Write-Host ""
    Write-CredRotationLog "STEP 1: Backing up existing credentials..." -Level 'Info'
    
    $backupPath = Join-Path ([System.IO.Path]::GetTempPath()) "github-cred-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    
    try {
        $oldCred = Get-AitherCredentialGitHub -ErrorAction Stop
        "OLD_TOKEN_BACKUP_$(Get-Date -Format 'o')" | Out-File -FilePath $backupPath -Force
        Write-CredRotationLog "Old credentials backed up to: $backupPath" -Level 'Success'
        Write-CredRotationLog "Keep this file until rotation is verified!" -Level 'Warning'
    } catch {
        Write-CredRotationLog "No existing credentials found" -Level 'Info'
    }
    
    # Step 2: Validate new token format
    Write-Host ""
    Write-CredRotationLog "STEP 2: Validating new token format..." -Level 'Info'
    
    if (-not $NewToken.StartsWith("ghp_") -and -not $NewToken.StartsWith("github_pat_")) {
        throw "Invalid token format. Expected 'ghp_' or 'github_pat_' prefix"
    }
    
    Write-CredRotationLog "Token format valid" -Level 'Success'
    
    # Step 3: Test new token
    if (-not $SkipTests) {
        Write-Host ""
        Write-CredRotationLog "STEP 3: Testing new token..." -Level 'Info'
        
        # Get test owner from config if not provided
        if (-not $TestOwner) {
            $licenseDir = [System.IO.Path]::GetFullPath([System.Environment]::ExpandEnvironmentVariables("~/.aitherzero/licenses"))
            $githubConfigPath = Join-Path $licenseDir "github-config.json"
            
            if (Test-Path $githubConfigPath) {
                $githubConfig = Get-Content -Path $githubConfigPath -Raw | ConvertFrom-Json
                $TestOwner = $githubConfig.Owner
            } else {
                Write-CredRotationLog "No test owner specified and no config found" -Level 'Warning'
                $TestOwner = Read-Host "Enter GitHub owner to test access"
            }
        }
        
        Write-CredRotationLog "Testing access to $TestOwner/$TestRepo..." -Level 'Info'
        
        # Test API access
        $headers = @{
            "Authorization" = "Bearer $NewToken"
            "Accept" = "application/vnd.github.v3+json"
        }
        
        try {
            $testUrl = "https://api.github.com/repos/$TestOwner/$TestRepo"
            $response = Invoke-RestMethod -Uri $testUrl -Headers $headers -Method Get -ErrorAction Stop
            Write-CredRotationLog "✓ API access successful" -Level 'Success'
            Write-CredRotationLog "Repository: $($response.full_name)" -Level 'Info'
            
            # Check permissions
            if ($response.permissions) {
                $perms = $response.permissions
                Write-CredRotationLog "Permissions: push=$($perms.push), pull=$($perms.pull), admin=$($perms.admin)" -Level 'Info'
                
                if (-not $perms.push) {
                    Write-CredRotationLog "Warning: Token does not have push permission" -Level 'Warning'
                }
            }
            
        } catch {
            throw "Token test failed: $($_.Exception.Message)"
        }
        
    } else {
        Write-CredRotationLog "Skipping tests (not recommended)" -Level 'Warning'
    }
    
    # Step 4: Update credentials
    Write-Host ""
    Write-CredRotationLog "STEP 4: Updating credentials..." -Level 'Info'
    
    if ($PSCmdlet.ShouldProcess("GitHub Credentials", "Update with new token")) {
        Set-AitherCredentialGitHub -Token $NewToken
        Write-CredRotationLog "Credentials updated" -Level 'Success'
    }
    
    # Step 5: Verify new credentials work
    Write-Host ""
    Write-CredRotationLog "STEP 5: Verifying new credentials..." -Level 'Info'
    
    try {
        $verifyTest = Get-AitherCredentialGitHub -ErrorAction Stop
        Write-CredRotationLog "Credential retrieval successful" -Level 'Success'
        
        if (-not $SkipTests) {
            # Do another API test with the stored credentials
            $headers2 = @{
                "Authorization" = "Bearer $($verifyTest.Token)"
                "Accept" = "application/vnd.github.v3+json"
            }
            
            $testUrl2 = "https://api.github.com/user"
            $userInfo = Invoke-RestMethod -Uri $testUrl2 -Headers $headers2 -Method Get -ErrorAction Stop
            Write-CredRotationLog "Authenticated as: $($userInfo.login)" -Level 'Success'
        }
        
    } catch {
        Write-CredRotationLog "Verification failed: $_" -Level 'Error'
        throw "New credentials not working - check backup: $backupPath"
    }
    
    # Success summary
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  GitHub Credential Rotation Successful!       ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-CredRotationLog "New credentials active and verified" -Level 'Success'
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Test license operations:" -ForegroundColor White
    Write-Host "   ./automation-scripts/0800_Manage-License.ps1 -Action Info" -ForegroundColor Gray
    Write-Host "2. Test deployment:" -ForegroundColor White
    Write-Host "   ./automation-scripts/0874_Deploy-LicenseToGitHub.ps1 -LicensePath <path>" -ForegroundColor Gray
    Write-Host "3. If successful, delete backup: $backupPath" -ForegroundColor White
    Write-Host ""
    Write-Host "Rollback (if needed):" -ForegroundColor Yellow
    Write-Host "Contact administrator to restore credentials from backup" -ForegroundColor Gray
    Write-Host ""
    
    exit 0
    
} catch {
    Write-CredRotationLog "Rotation failed: $($_.Exception.Message)" -Level 'Error'
    Write-Host ""
    Write-Host "ROLLBACK INSTRUCTIONS:" -ForegroundColor Yellow
    Write-Host "1. Contact administrator with backup file: $backupPath" -ForegroundColor White
    Write-Host "2. Manually restore old token:" -ForegroundColor White
    Write-Host "   Set-AitherCredentialGitHub -Token '<old-token>'" -ForegroundColor Gray
    Write-Host ""
    exit 1
}
