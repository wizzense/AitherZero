#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Sets up license infrastructure including CA integration and key management
    
.DESCRIPTION
    Configures the complete license infrastructure for an AitherZero organization:
    - Integrates with Certificate Authority (if available)
    - Generates signing keys for license tamper protection
    - Configures license storage locations
    - Sets up GitHub credential integration for license distribution
    
    Stage: License Infrastructure
    Dependencies: 0104_Install-CertificateAuthority.ps1, Security.psm1, LicenseManager.psm1, Encryption.psm1
    Tags: Security, Licensing, Infrastructure, CA, PKI
    
.PARAMETER OrganizationName
    Name of the organization (e.g., "aitherium")
    
.PARAMETER LicenseStoragePath
    Local path for license storage (default: ~/.aitherzero/licenses)
    
.PARAMETER GitHubOwner
    GitHub organization/owner for remote license storage
    
.PARAMETER GitHubRepo
    GitHub repository for remote license storage (default: "licenses")
    
.PARAMETER SetupCA
    Whether to set up Certificate Authority integration for signing keys
    
.PARAMETER GenerateMasterKeys
    Generate master signing and encryption keys
    
.EXAMPLE
    ./0803_Setup-LicenseInfrastructure.ps1 -OrganizationName "aitherium" -SetupCA -GenerateMasterKeys
    
.EXAMPLE
    ./0803_Setup-LicenseInfrastructure.ps1 -OrganizationName "myorg" -GitHubOwner "myorg" -GitHubRepo "secure-licenses"
    
.NOTES
    Author: AitherZero Team
    Version: 1.0.0
    
    This script should be run once during initial organization setup.
    Master keys are stored securely using AitherZero's credential management.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OrganizationName,
    
    [string]$LicenseStoragePath = "~/.aitherzero/licenses",
    
    [string]$GitHubOwner,
    
    [string]$GitHubRepo = "licenses",
    
    [switch]$SetupCA,
    
    [switch]$GenerateMasterKeys
)

# Script metadata
$script:ScriptName = "Setup-LicenseInfrastructure"
$script:ScriptVersion = "1.0.0"
$script:StartTime = Get-Date

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
    Write-ScriptOutput "Setting up license infrastructure for: $OrganizationName" -Level 'Info'
    
    # Load required modules
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $securityPath = Join-Path $projectRoot "aithercore/security"
    
    Import-Module (Join-Path $securityPath "Security.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $securityPath "Encryption.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $securityPath "LicenseManager.psm1") -Force -ErrorAction Stop
    
    Write-ScriptOutput "Loaded security modules" -Level 'Success'
    
    # 1. Setup license storage directory
    $licenseDir = [System.IO.Path]::GetFullPath([System.Environment]::ExpandEnvironmentVariables($LicenseStoragePath))
    if (-not (Test-Path $licenseDir)) {
        if ($PSCmdlet.ShouldProcess($licenseDir, "Create license storage directory")) {
            New-Item -Path $licenseDir -ItemType Directory -Force | Out-Null
            Write-ScriptOutput "Created license storage: $licenseDir" -Level 'Success'
        }
    } else {
        Write-ScriptOutput "License storage exists: $licenseDir" -Level 'Info'
    }
    
    # 2. Generate master keys if requested
    if ($GenerateMasterKeys) {
        Write-ScriptOutput "Generating master signing and encryption keys..." -Level 'Info'
        
        if ($PSCmdlet.ShouldProcess("Master Keys", "Generate encryption and signing keys")) {
            # Generate encryption key
            $masterEncryptionKey = & (Get-Module Encryption) { New-EncryptionKey }
            Write-ScriptOutput "Generated master encryption key" -Level 'Success'
            
            # Generate signing key (separate from encryption key for security)
            $masterSigningKey = & (Get-Module Encryption) { New-EncryptionKey }
            Write-ScriptOutput "Generated master signing key" -Level 'Success'
            
            # Store keys securely using AitherZero credential system
            $credNamePrefix = "AitherZero-$OrganizationName"
            
            Set-AitherCredential -Name "$credNamePrefix-MasterEncryptionKey" `
                -Token $masterEncryptionKey `
                -Description "Master encryption key for $OrganizationName licenses"
            
            Set-AitherCredential -Name "$credNamePrefix-MasterSigningKey" `
                -Token $masterSigningKey `
                -Description "Master signing key for $OrganizationName license tamper protection"
            
            Write-ScriptOutput "Master keys stored securely in credential vault" -Level 'Success'
            Write-ScriptOutput "Credential names: $credNamePrefix-MasterEncryptionKey, $credNamePrefix-MasterSigningKey" -Level 'Info'
        }
    }
    
    # 3. Setup CA integration if requested
    if ($SetupCA) {
        Write-ScriptOutput "Setting up Certificate Authority integration..." -Level 'Info'
        
        # Check if CA is installed
        $caScript = Join-Path $PSScriptRoot "0104_Install-CertificateAuthority.ps1"
        if (Test-Path $caScript) {
            $caInstalled = $false
            
            # Check for Windows CA
            if ($IsWindows) {
                $caInstalled = (Get-WindowsFeature -Name ADCS-Cert-Authority -ErrorAction SilentlyContinue)?.Installed
            }
            
            if (-not $caInstalled) {
                Write-ScriptOutput "Certificate Authority not found. Run 0104_Install-CertificateAuthority.ps1 first" -Level 'Warning'
            } else {
                Write-ScriptOutput "Certificate Authority detected - can be used for certificate-based signing" -Level 'Success'
                
                # Store CA configuration
                $caConfig = @{
                    OrganizationName = $OrganizationName
                    CAConfigured = $true
                    ConfiguredDate = (Get-Date).ToString('o')
                }
                
                $caConfigPath = Join-Path $licenseDir "ca-config.json"
                $caConfig | ConvertTo-Json | Out-File -FilePath $caConfigPath -Force
                
                Write-ScriptOutput "CA configuration saved to: $caConfigPath" -Level 'Success'
            }
        } else {
            Write-ScriptOutput "CA setup script not found - skipping CA integration" -Level 'Warning'
        }
    }
    
    # 4. Setup GitHub integration if specified
    if ($GitHubOwner) {
        Write-ScriptOutput "Configuring GitHub integration for license distribution..." -Level 'Info'
        
        if ($PSCmdlet.ShouldProcess("GitHub Integration", "Configure for $GitHubOwner/$GitHubRepo")) {
            # Store GitHub configuration
            $githubConfig = @{
                Owner = $GitHubOwner
                Repo = $GitHubRepo
                OrganizationName = $OrganizationName
                ConfiguredDate = (Get-Date).ToString('o')
            }
            
            $githubConfigPath = Join-Path $licenseDir "github-config.json"
            $githubConfig | ConvertTo-Json | Out-File -FilePath $githubConfigPath -Force
            
            Write-ScriptOutput "GitHub configuration saved: $GitHubOwner/$GitHubRepo" -Level 'Success'
            Write-ScriptOutput "Use 0804_Deploy-LicenseToGitHub.ps1 to upload licenses" -Level 'Info'
            
            # Check if GitHub credentials are configured
            try {
                $gitHubCred = Get-AitherCredentialGitHub -ErrorAction Stop
                Write-ScriptOutput "GitHub credentials configured" -Level 'Success'
            } catch {
                Write-ScriptOutput "GitHub credentials not configured. Run: Set-AitherCredentialGitHub -Token <your-token>" -Level 'Warning'
            }
        }
    }
    
    # 5. Create infrastructure summary
    $summary = @"

╔════════════════════════════════════════════════════════════════╗
║         License Infrastructure Setup Complete                   ║
╚════════════════════════════════════════════════════════════════╝

Organization:     $OrganizationName
Storage Path:     $licenseDir
Master Keys:      $(if ($GenerateMasterKeys) { 'Generated' } else { 'Not Generated' })
CA Integration:   $(if ($SetupCA) { 'Configured' } else { 'Not Configured' })
GitHub Repo:      $(if ($GitHubOwner) { "$GitHubOwner/$GitHubRepo" } else { 'Not Configured' })

Next Steps:
1. Generate licenses:
   ./0800_Manage-License.ps1 -Action Create -LicenseId "PROD-001" ``
       -LicensedTo "Customer Name" -GenerateSigningKey

2. Deploy to GitHub (if configured):
   ./0804_Deploy-LicenseToGitHub.ps1 -LicensePath "./PROD-001.json"

3. Distribute to clients via secure channels

For help: ./0800_Manage-License.ps1 -Action Info

"@
    
    Write-Host $summary -ForegroundColor Cyan
    
    # Save setup record
    $setupRecord = @{
        OrganizationName = $OrganizationName
        SetupDate = (Get-Date).ToString('o')
        LicenseStoragePath = $licenseDir
        MasterKeysGenerated = $GenerateMasterKeys.IsPresent
        CAConfigured = $SetupCA.IsPresent
        GitHubOwner = $GitHubOwner
        GitHubRepo = $GitHubRepo
        ScriptVersion = $script:ScriptVersion
    }
    
    $setupRecordPath = Join-Path $licenseDir "setup-record.json"
    $setupRecord | ConvertTo-Json -Depth 5 | Out-File -FilePath $setupRecordPath -Force
    
    Write-ScriptOutput "Setup complete! Duration: $((Get-Date) - $script:StartTime)" -Level 'Success'
    exit 0
    
} catch {
    Write-ScriptOutput "Setup failed: $($_.Exception.Message)" -Level 'Error'
    Write-ScriptOutput "At: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -Level 'Error'
    exit 1
}
