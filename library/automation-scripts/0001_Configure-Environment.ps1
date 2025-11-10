#Requires -Version 7.0

<#
.SYNOPSIS
    Configure system environment based on AitherZero configuration files
.DESCRIPTION
    Applies environment configuration settings from config files including:
    - Windows long path support, developer mode, registry settings
    - Linux kernel parameters, packages, firewall, SSH config
    - macOS system preferences, Homebrew packages
    - Environment variables (system, user, process)
    - PATH configuration
    - Shell integration
    
    This script reads from the OS-specific config files (config.windows.psd1,
    config.linux.psd1, config.macos.psd1) and applies the configured settings.
    
.PARAMETER Category
    Specific category to configure: All, Windows, Unix, EnvironmentVariables, Path
.PARAMETER DryRun
    Preview changes without applying them
.PARAMETER Force
    Skip confirmation prompts
.PARAMETER GenerateArtifacts
    Generate deployment artifacts (Unattend.xml, cloud-init, Brewfile, etc.)
.PARAMETER ArtifactsPath
    Output path for generated artifacts (default: ./artifacts)
.EXAMPLE
    ./0001_Configure-Environment.ps1
    
    Apply all environment configuration with prompts
.EXAMPLE
    ./0001_Configure-Environment.ps1 -DryRun
    
    Preview all configuration changes without applying
.EXAMPLE
    ./0001_Configure-Environment.ps1 -Category Windows -Force
    
    Apply Windows-specific configuration without prompts
.EXAMPLE
    ./0001_Configure-Environment.ps1 -GenerateArtifacts
    
    Configure environment and generate deployment artifacts
.NOTES
    Stage: Environment Setup
    Dependencies: None
    Tags: environment, configuration, setup, system
    
    This script is idempotent - safe to run multiple times.
    
    Configuration hierarchy:
    1. config.psd1 (base)
    2. config.{os}.psd1 (OS-specific, auto-detected)
    3. config.local.psd1 (local overrides)
    
    Windows: Requires Administrator for system-level changes
    Linux: Requires root for system-level changes
    macOS: May require sudo for some operations
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('All', 'Windows', 'Unix', 'EnvironmentVariables', 'Path')]
    [string]$Category = 'All',
    
    [switch]$DryRun,
    
    [switch]$Force,
    
    [switch]$GenerateArtifacts,
    
    [string]$ArtifactsPath = './artifacts'
)

#region Setup

$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($PSBoundParameters.ContainsKey('Verbose')) { 'Continue' } else { 'SilentlyContinue' }

# Get script location
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Get project root (two levels up from automation-scripts)
$ProjectRoot = Split-Path (Split-Path $ScriptRoot -Parent) -Parent

# Import ScriptUtilities for centralized logging
$scriptUtilsPath = Join-Path $ProjectRoot "aithercore/automation/ScriptUtilities.psm1"
if (Test-Path $scriptUtilsPath) {
    Import-Module $scriptUtilsPath -Force -ErrorAction SilentlyContinue
}

# Import required modules
$modulePaths = @(
    (Join-Path $ProjectRoot 'domains/utilities/EnvironmentConfig.psm1')
    (Join-Path $ProjectRoot 'domains/infrastructure/DeploymentArtifacts.psm1')
    (Join-Path $ProjectRoot 'domains/configuration/Configuration.psm1')
)

foreach ($modulePath in $modulePaths) {
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction SilentlyContinue
    }
}

#endregion

#region Helper Functions

$prefix = switch ($Level) {
        'Information' { '[i]' }
        'Warning' { '[!]' }
        'Error' { '[x]' }
        'Success' { '[✓]' }
    }
    
    Write-Host "$timestamp $prefix $Message" -ForegroundColor $colors[$Level]
}

function Test-AdminPrivileges {
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    else {
        return (id -u) -eq 0
    }
}

#endregion

#region Main Script

try {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  AitherZero Environment Configuration" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Display current environment
    Write-ScriptLog "Detecting current environment..." -Level Information
    $platform = if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') { 'Windows' }
                elseif ($IsLinux) { 'Linux' }
                elseif ($IsMacOS) { 'macOS' }
                else { 'Unknown' }
    
    Write-ScriptLog "Platform: $platform" -Level Information
    Write-ScriptLog "PowerShell: $($PSVersionTable.PSVersion)" -Level Information
    Write-ScriptLog "Category: $Category" -Level Information
    Write-ScriptLog "Mode: $(if ($DryRun) { 'DRY RUN (preview only)' } else { 'APPLY CHANGES' })" -Level $(if ($DryRun) { 'Warning' } else { 'Information' })
    Write-Host ""
    
    # Check admin privileges
    $isAdmin = Test-AdminPrivileges
    if ($isAdmin) {
        Write-ScriptLog "Running with elevated privileges" -Level Information
    }
    else {
        Write-ScriptLog "Running without elevated privileges (some features may be limited)" -Level Warning
    }
    Write-Host ""
    
    # Get current configuration status
    Write-ScriptLog "Retrieving current environment configuration..." -Level Information
    $currentStatus = Get-EnvironmentConfiguration -Category $Category
    
    if ($currentStatus) {
        Write-ScriptLog "Current environment status retrieved successfully" -Level Information
        
        # Display Windows status
        if ($currentStatus.Status.Windows) {
            Write-Host "  Windows Configuration:" -ForegroundColor Cyan
            Write-Host "    Long Path Support: $(if ($currentStatus.Status.Windows.LongPathSupport.Enabled) { 'Enabled ✓' } else { 'Disabled' })" -ForegroundColor $(if ($currentStatus.Status.Windows.LongPathSupport.Enabled) { 'Green' } else { 'Yellow' })
            Write-Host "    Developer Mode: $(if ($currentStatus.Status.Windows.DeveloperMode.Enabled) { 'Enabled ✓' } else { 'Disabled' })" -ForegroundColor $(if ($currentStatus.Status.Windows.DeveloperMode.Enabled) { 'Green' } else { 'Yellow' })
            Write-Host "    Admin Privileges: $(if ($currentStatus.Status.Windows.IsAdministrator) { 'Yes ✓' } else { 'No' })" -ForegroundColor $(if ($currentStatus.Status.Windows.IsAdministrator) { 'Green' } else { 'Yellow' })
        }
        
        Write-Host ""
    }
    
    # Apply configuration
    Write-ScriptLog "Applying environment configuration..." -Level Information
    Write-Host ""
    
    $params = @{
        Category = $Category
        DryRun = $DryRun
        Force = $Force
    }
    
    $result = Set-EnvironmentConfiguration @params
    
    if ($result -and $result.Success) {
        Write-Host ""
        if ($result.DryRun) {
            Write-ScriptLog "Preview completed - no changes were applied" -Level Warning
            Write-ScriptLog "Run without -DryRun to apply changes" -Level Information
        }
        else {
            Write-ScriptLog "Environment configuration applied successfully" -Level Information
            
            if ($result.AppliedChanges.Count -gt 0) {
                Write-Host "  Applied changes:" -ForegroundColor Green
                foreach ($change in $result.AppliedChanges) {
                    Write-Host "    ✓ $change" -ForegroundColor DarkGreen
                }
            }
            else {
                Write-ScriptLog "No configuration changes were needed" -Level Information
            }
        }
    }
    else {
        Write-ScriptLog "Configuration completed with warnings" -Level Warning
    }
    
    Write-Host ""
    
    # Generate deployment artifacts if requested
    if ($GenerateArtifacts) {
        Write-ScriptLog "Generating deployment artifacts..." -Level Information
        Write-Host ""
        
        try {
            $artifacts = New-DeploymentArtifacts -Platform 'All' -ConfigPath $ProjectRoot -OutputPath $ArtifactsPath
            
            if ($artifacts) {
                $totalArtifacts = ($artifacts.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
                
                if ($totalArtifacts -gt 0) {
                    Write-Host ""
                    Write-ScriptLog "Generated $totalArtifacts deployment artifacts" -Level Information
                    Write-Host ""
                    Write-Host "  Artifact locations:" -ForegroundColor Cyan
                    
                    foreach ($platformKey in $artifacts.Keys) {
                        if ($artifacts[$platformKey].Count -gt 0) {
                            Write-Host "    $platformKey : $($artifacts[$platformKey].Count) file(s)" -ForegroundColor Green
                            foreach ($file in $artifacts[$platformKey]) {
                                $relativePath = $file -replace [regex]::Escape($ProjectRoot), '.'
                                Write-Host "      - $relativePath" -ForegroundColor DarkGray
                            }
                        }
                    }
                }
                else {
                    Write-ScriptLog "No artifacts were generated (check config.*.psd1 settings)" -Level Warning
                }
            }
        }
        catch {
            Write-ScriptLog "Error generating artifacts: $($_.Exception.Message)" -Level Error
        }
        
        Write-Host ""
    }
    
    # Summary
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Configuration Complete" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Tips
    Write-Host "  Next steps:" -ForegroundColor Yellow
    if ($DryRun) {
        Write-Host "    • Review the changes above" -ForegroundColor Gray
        Write-Host "    • Run without -DryRun to apply: ./0001_Configure-Environment.ps1" -ForegroundColor Gray
    }
    else {
        Write-Host "    • Verify configuration: Get-AitherEnvironment" -ForegroundColor Gray
        Write-Host "    • Generate artifacts: ./0001_Configure-Environment.ps1 -GenerateArtifacts" -ForegroundColor Gray
    }
    Write-Host "    • Customize settings in config.local.psd1" -ForegroundColor Gray
    Write-Host "    • View OS-specific config: config.$($platform.ToLower()).psd1" -ForegroundColor Gray
    Write-Host ""
    
    exit 0
}
catch {
    Write-Host ""
    Write-ScriptLog "ERROR: $($_.Exception.Message)" -Level Error
    Write-ScriptLog "Stack trace: $($_.ScriptStackTrace)" -Level Error
    Write-Host ""
    exit 1
}

#endregion
