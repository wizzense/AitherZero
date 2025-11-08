#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Deploys licenses to GitHub using AitherZero's secure credential system
    
.DESCRIPTION
    Uploads license files to a private GitHub repository using Set-AitherCredentialGitHub
    for secure storage and distribution. Integrates with the existing credential
    management infrastructure instead of using gh CLI directly.
    
    Stage: License Distribution
    Dependencies: Security.psm1, LicenseManager.psm1
    Tags: Security, Licensing, GitHub, Distribution
    
.PARAMETER LicensePath
    Path to the license file to deploy
    
.PARAMETER Owner
    GitHub organization/owner (uses config from 0803 if not specified)
    
.PARAMETER Repo
    GitHub repository name (uses config from 0803 if not specified)
    
.PARAMETER Branch
    Target branch (default: main)
    
.PARAMETER Path
    Path within repository to store license (default: licenses)
    
.PARAMETER CommitMessage
    Custom commit message (default: auto-generated)
    
.EXAMPLE
    ./0804_Deploy-LicenseToGitHub.ps1 -LicensePath "./PROD-001.json"
    
.EXAMPLE
    ./0804_Deploy-LicenseToGitHub.ps1 -LicensePath "./DEV-123.json" -Owner "aitherium" -Repo "licenses" -Branch "main"
    
.NOTES
    Author: AitherZero Team
    Version: 1.0.0
    
    Requires GitHub token to be configured:
    Set-AitherCredentialGitHub -Token "ghp_..."
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$LicensePath,
    
    [string]$Owner,
    
    [string]$Repo,
    
    [string]$Branch = "main",
    
    [string]$Path = "licenses",
    
    [string]$CommitMessage
)

# Script metadata
$script:ScriptName = "Deploy-LicenseToGitHub"
$script:ScriptVersion = "1.0.0"

function Write-ScriptOutput {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $color = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }[$Level]
    
    $prefix = @{
        'Info' = 'ℹ'
        'Success' = '✓'
        'Warning' = '⚠'
        'Error' = '✗'
    }[$Level]
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

# Main script logic
try {
    Write-ScriptOutput "Deploying license to GitHub..." -Level 'Info'
    
    # Load required modules
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $securityPath = Join-Path $projectRoot "domains/security"
    
    Import-Module (Join-Path $securityPath "Security.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $securityPath "LicenseManager.psm1") -Force -ErrorAction Stop
    
    # Load license file
    $licenseContent = Get-Content -Path $LicensePath -Raw
    $license = $licenseContent | ConvertFrom-Json
    $licenseId = $license.LicenseId
    
    Write-ScriptOutput "Loaded license: $licenseId" -Level 'Success'
    
    # Get GitHub config from setup if not provided
    if (-not $Owner -or -not $Repo) {
        $licenseDir = [System.IO.Path]::GetFullPath([System.Environment]::ExpandEnvironmentVariables("~/.aitherzero/licenses"))
        $githubConfigPath = Join-Path $licenseDir "github-config.json"
        
        if (Test-Path $githubConfigPath) {
            $githubConfig = Get-Content -Path $githubConfigPath -Raw | ConvertFrom-Json
            
            if (-not $Owner) {
                $Owner = $githubConfig.Owner
            }
            if (-not $Repo) {
                $Repo = $githubConfig.Repo
            }
            
            Write-ScriptOutput "Using GitHub config: $Owner/$Repo" -Level 'Info'
        } else {
            if (-not $Owner -or -not $Repo) {
                throw "Owner and Repo must be specified or run 0803_Setup-LicenseInfrastructure.ps1 first"
            }
        }
    }
    
    # Check GitHub credentials
    try {
        $githubCred = Get-AitherCredentialGitHub -ErrorAction Stop
        Write-ScriptOutput "GitHub credentials verified" -Level 'Success'
    } catch {
        throw "GitHub credentials not configured. Run: Set-AitherCredentialGitHub -Token <your-token>"
    }
    
    # Prepare file path in repo
    $fileName = Split-Path $LicensePath -Leaf
    $repoFilePath = "$Path/$fileName"
    
    # Generate commit message if not provided
    if (-not $CommitMessage) {
        $CommitMessage = "Add/Update license: $licenseId"
    }
    
    Write-ScriptOutput "Uploading to $Owner/$Repo at $repoFilePath" -Level 'Info'
    
    if ($PSCmdlet.ShouldProcess("$Owner/$Repo/$repoFilePath", "Upload license file")) {
        # Use Set-AitherCredentialGitHub to store the file
        # Note: This stores as a secret/credential, which is appropriate for sensitive license files
        Set-AitherCredentialGitHub -Owner $Owner -Repo $Repo `
            -Path $repoFilePath -Content $licenseContent `
            -Message $CommitMessage -Branch $Branch
        
        Write-ScriptOutput "License deployed successfully!" -Level 'Success'
        Write-ScriptOutput "Location: https://github.com/$Owner/$Repo/blob/$Branch/$repoFilePath" -Level 'Info'
        
        # Display summary
        $summary = @"

╔════════════════════════════════════════════════════════════════╗
║              License Deployment Summary                         ║
╚════════════════════════════════════════════════════════════════╝

License ID:       $licenseId
Licensed To:      $($license.LicensedTo)
Repository:       $Owner/$Repo
Branch:           $Branch
Path:             $repoFilePath
Commit:           $CommitMessage

Retrieval:
  ./0800_Manage-License.ps1 -Action Retrieve ``
      -LicenseId "$licenseId" ``
      -GitHubOwner "$Owner" ``
      -GitHubRepo "$Repo" ``
      -OutputPath "./license.json"

"@
        
        Write-Host $summary -ForegroundColor Cyan
    }
    
    exit 0
    
} catch {
    Write-ScriptOutput "Deployment failed: $($_.Exception.Message)" -Level 'Error'
    Write-ScriptOutput "At: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -Level 'Error'
    exit 1
}
