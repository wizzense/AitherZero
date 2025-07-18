#!/usr/bin/env pwsh
#Requires -Version 7.0

# AitherZero Enhanced Bootstrap Script
# Compatible with PowerShell 5.1+ with comprehensive reliability improvements
# This script MUST run on any PowerShell version - NO #Requires statement

<#
.SYNOPSIS
    Enhanced bootstrap script for AitherZero with reliability improvements and retry mechanisms

.DESCRIPTION
    This script provides a robust bootstrap experience with:
    - Enhanced PowerShell 7 detection with comprehensive path searching
    - Network connectivity testing with offline fallback
    - Automated installation with multiple methods and retry logic
    - Comprehensive error handling with specific recovery guidance
    - Bootstrap validation system with health checks
    - Offline installation support for air-gapped environments

.PARAMETER Auto
    Run in automatic mode without user interaction

.PARAMETER Scripts
    Comma-separated list of scripts to run

.PARAMETER Setup
    Run first-time setup wizard

.PARAMETER InstallationProfile
    Installation profile: minimal, developer, full, or interactive

.PARAMETER WhatIf
    Preview mode - show what would be done without making changes

.PARAMETER Help
    Show help information

.PARAMETER NonInteractive
    Run in non-interactive mode (no prompts)

.PARAMETER Quiet
    Run in quiet mode with minimal output

.PARAMETER Verbosity
    Set verbosity level: silent, normal, detailed

.PARAMETER ConfigFile
    Path to configuration file

.PARAMETER Force
    Force operations even if validations fail

.PARAMETER EnhancedUI
    Force enhanced UI experience

.PARAMETER ClassicUI
    Force classic menu experience

.PARAMETER UIMode
    UI preference mode: auto, enhanced, classic

.PARAMETER SkipNetworkTest
    Skip network connectivity testing

.PARAMETER OfflineMode
    Run in offline mode (no network operations)

.PARAMETER MaxRetries
    Maximum retry attempts for failed operations (default: 3)

.EXAMPLE
    ./Start-AitherZero.ps1
    # Run in interactive mode with automatic PowerShell 7 installation if needed

.EXAMPLE
    ./Start-AitherZero.ps1 -Setup -InstallationProfile developer
    # Run setup wizard with developer profile

.EXAMPLE
    ./Start-AitherZero.ps1 -OfflineMode
    # Run in offline mode without network operations

.EXAMPLE
    ./Start-AitherZero.ps1 -MaxRetries 5
    # Run with increased retry attempts for operations
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Run in automatic mode without user interaction")]
    [switch]$Auto,

    [Parameter(HelpMessage = "Scripts to run (comma-separated)")]
    [string]$Scripts,

    [Parameter(HelpMessage = "Run first-time setup wizard")]
    [switch]$Setup,

    [Parameter(HelpMessage = "Installation profile: minimal, developer, full, or interactive")]
    [ValidateSet("minimal", "developer", "full", "interactive")]
    [string]$InstallationProfile = "interactive",

    [Parameter(HelpMessage = "Preview mode - show what would be done")]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Show help information")]
    [switch]$Help,

    [Parameter(HelpMessage = "Run in non-interactive mode (no prompts)")]
    [switch]$NonInteractive,

    [Parameter(HelpMessage = "Run in quiet mode with minimal output")]
    [switch]$Quiet,

    [Parameter(HelpMessage = "Set verbosity level: silent, normal, detailed")]
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',

    [Parameter(HelpMessage = "Path to configuration file")]
    [string]$ConfigFile,

    [Parameter(HelpMessage = "Force operations even if validations fail")]
    [switch]$Force,

    [Parameter(HelpMessage = "Force enhanced UI experience")]
    [switch]$EnhancedUI,

    [Parameter(HelpMessage = "Force classic menu experience")]
    [switch]$ClassicUI,

    [Parameter(HelpMessage = "UI preference mode: auto, enhanced, classic")]
    [ValidateSet('auto', 'enhanced', 'classic')]
    [string]$UIMode = 'auto',

    [Parameter(HelpMessage = "Skip network connectivity testing")]
    [switch]$SkipNetworkTest,

    [Parameter(HelpMessage = "Run in offline mode (no network operations)")]
    [switch]$OfflineMode,

    [Parameter(HelpMessage = "Maximum retry attempts for failed operations")]
    [int]$MaxRetries = 3
)

# ════════════════════════════════════════════════════════════════════════════════
#                            BOOTSTRAP INITIALIZATION
# ════════════════════════════════════════════════════════════════════════════════

# Global error handling
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Bootstrap state tracking
$script:BootstrapState = @{
    StartTime = Get-Date
    Attempts = 0
    MaxRetries = $MaxRetries
    Errors = @()
    Warnings = @()
    NetworkConnectivity = $null
    PowerShell7Path = $null
    OfflineMode = $OfflineMode.IsPresent
    ValidationResults = @{}
}

# ════════════════════════════════════════════════════════════════════════════════
#                            ENHANCED LOGGING SYSTEM
# ════════════════════════════════════════════════════════════════════════════════

function Write-BootstrapLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',
        
        [switch]$NoNewline
    )
    
    if ($Quiet -and $Level -ne 'ERROR') {
        return
    }
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $colors = @{
        'INFO'    = 'Cyan'
        'SUCCESS' = 'Green'
        'WARNING' = 'Yellow'
        'ERROR'   = 'Red'
        'DEBUG'   = 'Gray'
    }
    
    $symbols = @{
        'INFO'    = '🔵'
        'SUCCESS' = '✅'
        'WARNING' = '⚠️'
        'ERROR'   = '❌'
        'DEBUG'   = '🔍'
    }
    
    $prefix = "$($symbols[$Level]) [$timestamp]"
    $color = $colors[$Level]
    
    if ($NoNewline) {
        Write-Host "$prefix $Message" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$prefix $Message" -ForegroundColor $color
    }
    
    # Track errors and warnings in bootstrap state
    if ($Level -eq 'ERROR') {
        $script:BootstrapState.Errors += $Message
    } elseif ($Level -eq 'WARNING') {
        $script:BootstrapState.Warnings += $Message
    }
}

function Show-BootstrapBanner {
    if (-not $Quiet) {
        Write-Host @"
════════════════════════════════════════════════════════════════════════════════
                      🚀 AitherZero Enhanced Bootstrap v2.0 🚀
════════════════════════════════════════════════════════════════════════════════

    Enhanced reliability features:
    ✅ Comprehensive PowerShell 7 detection
    ✅ Network failure handling with offline fallback
    ✅ Retry mechanisms with exponential backoff
    ✅ Bootstrap validation system
    ✅ Specific error recovery guidance
    ✅ Air-gapped environment support

════════════════════════════════════════════════════════════════════════════════
"@ -ForegroundColor Cyan
    }
}

# ════════════════════════════════════════════════════════════════════════════════
#                        BOOTSTRAP VALIDATION SYSTEM
# ════════════════════════════════════════════════════════════════════════════════

function Test-BootstrapHealth {
    [CmdletBinding()]
    param()
    
    Write-BootstrapLog "Running bootstrap health checks..." -Level 'INFO'
    
    $healthChecks = @{
        'PowerShellVersion' = $PSVersionTable.PSVersion.Major -ge 5
        'ExecutionPolicy' = $true  # Will be tested below
        'FileSystem' = Test-Path $scriptRoot
        'Permissions' = $true  # Will be tested below
        'NetworkAccess' = $true  # Will be tested if not offline
    }
    
    # Test execution policy
    try {
        $policy = Get-ExecutionPolicy -Scope CurrentUser
        $healthChecks['ExecutionPolicy'] = $policy -ne 'Restricted'
        if (-not $healthChecks['ExecutionPolicy']) {
            Write-BootstrapLog "Execution policy is Restricted. Some operations may fail." -Level 'WARNING'
        }
    } catch {
        Write-BootstrapLog "Could not check execution policy: $_" -Level 'WARNING'
    }
    
    # Test file system permissions
    try {
        $testFile = Join-Path $scriptRoot "bootstrap_test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
        "test" | Out-File -FilePath $testFile -Force
        Remove-Item $testFile -Force
        $healthChecks['Permissions'] = $true
    } catch {
        $healthChecks['Permissions'] = $false
        Write-BootstrapLog "File system permissions test failed: $_" -Level 'WARNING'
    }
    
    # Test network access (if not offline)
    if (-not $script:BootstrapState.OfflineMode -and -not $SkipNetworkTest) {
        try {
            $networkTest = Test-NetworkConnectivity -Timeout 5
            $healthChecks['NetworkAccess'] = $networkTest.HasConnectivity
            $script:BootstrapState.NetworkConnectivity = $networkTest
            
            if ($networkTest.HasConnectivity) {
                Write-BootstrapLog "Network connectivity confirmed (${networkTest.FastestResponse}ms)" -Level 'SUCCESS'
            } else {
                Write-BootstrapLog "Network connectivity issues detected" -Level 'WARNING'
            }
        } catch {
            $healthChecks['NetworkAccess'] = $false
            Write-BootstrapLog "Network connectivity test failed: $_" -Level 'WARNING'
        }
    }
    
    $script:BootstrapState.ValidationResults = $healthChecks
    
    $failedChecks = $healthChecks.GetEnumerator() | Where-Object { -not $_.Value }
    if ($failedChecks) {
        Write-BootstrapLog "Health check failures detected:" -Level 'WARNING'
        foreach ($check in $failedChecks) {
            Write-BootstrapLog "  - $($check.Key): Failed" -Level 'WARNING'
        }
    } else {
        Write-BootstrapLog "All health checks passed" -Level 'SUCCESS'
    }
    
    return $healthChecks
}

# ════════════════════════════════════════════════════════════════════════════════
#                         RETRY MECHANISM WITH BACKOFF
# ════════════════════════════════════════════════════════════════════════════════

function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $true)]
        [string]$OperationName,
        
        [int]$MaxRetries = $script:BootstrapState.MaxRetries,
        
        [int]$BaseDelaySeconds = 2,
        
        [switch]$ExponentialBackoff
    )
    
    $attempt = 0
    $success = $false
    $lastError = $null
    
    while (-not $success -and $attempt -lt $MaxRetries) {
        $attempt++
        
        try {
            Write-BootstrapLog "Attempting $OperationName (attempt $attempt/$MaxRetries)" -Level 'INFO'
            
            $result = & $ScriptBlock
            $success = $true
            
            Write-BootstrapLog "$OperationName completed successfully" -Level 'SUCCESS'
            return $result
            
        } catch {
            $lastError = $_
            Write-BootstrapLog "$OperationName failed on attempt $attempt`: $($_.Exception.Message)" -Level 'WARNING'
            
            if ($attempt -lt $MaxRetries) {
                $delay = if ($ExponentialBackoff) {
                    $BaseDelaySeconds * [Math]::Pow(2, $attempt - 1)
                } else {
                    $BaseDelaySeconds
                }
                
                Write-BootstrapLog "Retrying in $delay seconds..." -Level 'INFO'
                Start-Sleep -Seconds $delay
            }
        }
    }
    
    if (-not $success) {
        Write-BootstrapLog "$OperationName failed after $MaxRetries attempts" -Level 'ERROR'
        throw $lastError
    }
}

# ════════════════════════════════════════════════════════════════════════════════
#                      ENHANCED POWERSHELL 7 BOOTSTRAP
# ════════════════════════════════════════════════════════════════════════════════

# Load enhanced PowerShell version utilities
$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) {
    # Fallback path resolution using Split-Path and MyInvocation
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$versionCheckPath = Join-Path $scriptRoot "aither-core/shared/Test-PowerShellVersion.ps1"
if (Test-Path $versionCheckPath) {
    . $versionCheckPath
} else {
    Write-BootstrapLog "PowerShell version utilities not found at: $versionCheckPath" -Level 'WARNING'
    Write-BootstrapLog "Using fallback PowerShell detection methods" -Level 'INFO'
    Write-BootstrapLog "Please ensure AitherZero is properly installed" -Level 'WARNING'
    
    # Fallback function if shared utilities not available
    function Find-PowerShell7 {
        $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwshCmd) {
            return $pwshCmd.Source
        }
        return $null
    }
}

function Initialize-PowerShell7Bootstrap {
    [CmdletBinding()]
    param()
    
    # Check current PowerShell version
    $currentVersion = $PSVersionTable.PSVersion
    Write-BootstrapLog "Current PowerShell version: $currentVersion" -Level 'INFO'
    
    if ($currentVersion.Major -ge 7) {
        Write-BootstrapLog "PowerShell 7+ detected. Bootstrap complete!" -Level 'SUCCESS'
        return $true
    }
    
    Write-BootstrapLog "PowerShell 7 required. Current version: $currentVersion" -Level 'WARNING'
    
    # Enhanced PowerShell 7 detection
    $pwsh7Path = Find-PowerShell7 -IncludePreview
    
    if ($pwsh7Path) {
        Write-BootstrapLog "PowerShell 7 found at: $pwsh7Path" -Level 'SUCCESS'
        $script:BootstrapState.PowerShell7Path = $pwsh7Path
        
        # Attempt to restart with PowerShell 7
        return Start-WithPowerShell7Enhanced
    }
    
    # PowerShell 7 not found - attempt installation
    if (-not $script:BootstrapState.OfflineMode) {
        return Install-PowerShell7Enhanced
    } else {
        Write-BootstrapLog "PowerShell 7 not found and offline mode enabled" -Level 'ERROR'
        Show-OfflineInstallationGuidance
        return $false
    }
}

function Start-WithPowerShell7Enhanced {
    [CmdletBinding()]
    param()
    
    if (-not $script:BootstrapState.PowerShell7Path) {
        Write-BootstrapLog "PowerShell 7 path not available" -Level 'ERROR'
        return $false
    }
    
    $restartOperation = {
        # Build argument list preserving all parameters
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $MyInvocation.MyCommand.Path)
        
        # Add all bound parameters
        foreach ($key in $PSBoundParameters.Keys) {
            $value = $PSBoundParameters[$key]
            if ($value -is [switch]) {
                if ($value.IsPresent) { $argList += "-$key" }
            } elseif ($null -ne $value) {
                $argList += "-$key", $value
            }
        }
        
        Write-BootstrapLog "Restarting with PowerShell 7: $($script:BootstrapState.PowerShell7Path)" -Level 'INFO'
        & $script:BootstrapState.PowerShell7Path @argList
        
        if ($LASTEXITCODE -ne 0) {
            throw "PowerShell 7 restart failed with exit code: $LASTEXITCODE"
        }
        
        return $true
    }
    
    try {
        $result = Invoke-WithRetry -ScriptBlock $restartOperation -OperationName "PowerShell 7 Restart" -MaxRetries 2
        exit $LASTEXITCODE
    } catch {
        Write-BootstrapLog "Failed to restart with PowerShell 7: $_" -Level 'ERROR'
        Show-PowerShellRestartGuidance
        return $false
    }
}

function Install-PowerShell7Enhanced {
    [CmdletBinding()]
    param()
    
    if ($script:BootstrapState.OfflineMode) {
        Write-BootstrapLog "Cannot install PowerShell 7 in offline mode" -Level 'ERROR'
        return $false
    }
    
    Write-BootstrapLog "Attempting to install PowerShell 7..." -Level 'INFO'
    
    # Check if we should attempt automatic installation
    if ($NonInteractive -or $Auto) {
        $attemptInstall = $true
    } else {
        $attemptInstall = Confirm-AutoInstallation
    }
    
    if (-not $attemptInstall) {
        Show-ManualInstallationGuidance
        return $false
    }
    
    $installOperation = {
        return Install-PowerShell7 -Method auto
    }
    
    try {
        $installResult = Invoke-WithRetry -ScriptBlock $installOperation -OperationName "PowerShell 7 Installation" -MaxRetries 2 -ExponentialBackoff
        
        if ($installResult) {
            Write-BootstrapLog "PowerShell 7 installation completed successfully" -Level 'SUCCESS'
            
            # Try to find PowerShell 7 again
            Start-Sleep -Seconds 3  # Give installation time to complete
            $pwsh7Path = Find-PowerShell7
            
            if ($pwsh7Path) {
                $script:BootstrapState.PowerShell7Path = $pwsh7Path
                return Start-WithPowerShell7Enhanced
            } else {
                Write-BootstrapLog "PowerShell 7 installation succeeded but executable not found" -Level 'ERROR'
                Show-PostInstallationGuidance
                return $false
            }
        } else {
            Write-BootstrapLog "PowerShell 7 installation failed" -Level 'ERROR'
            Show-InstallationFailureGuidance
            return $false
        }
    } catch {
        Write-BootstrapLog "PowerShell 7 installation failed: $_" -Level 'ERROR'
        Show-InstallationFailureGuidance
        return $false
    }
}

function Confirm-AutoInstallation {
    if (-not $Host.UI.RawUI) {
        return $false
    }
    
    Write-Host ""
    Write-Host "🤖 AUTOMATIC POWERSHELL 7 INSTALLATION" -ForegroundColor Green
    Write-Host "Would you like to install PowerShell 7 automatically? (y/n): " -ForegroundColor Cyan -NoNewline
    
    try {
        $response = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Write-Host $response.Character
        return $response.Character -eq 'y' -or $response.Character -eq 'Y'
    } catch {
        Write-BootstrapLog "Unable to read user input" -Level 'WARNING'
        return $false
    }
}

# ════════════════════════════════════════════════════════════════════════════════
#                        ENHANCED GUIDANCE SYSTEM
# ════════════════════════════════════════════════════════════════════════════════

function Show-OfflineInstallationGuidance {
    Write-Host @"

┌─────────────────────────────────────────────────────────────────────────────────┐
│                           📡 OFFLINE MODE GUIDANCE                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  PowerShell 7 is required but not found, and offline mode is enabled.          │
│                                                                                 │
│  OFFLINE INSTALLATION OPTIONS:                                                 │
│                                                                                 │
│  1. Download PowerShell 7 installer on a connected machine:                    │
│     https://github.com/PowerShell/PowerShell/releases/latest                   │
│                                                                                 │
│  2. Transfer the installer to this machine and run it manually                 │
│                                                                                 │
│  3. Or install using your organization's package management system             │
│                                                                                 │
│  AFTER INSTALLATION:                                                           │
│  - Restart your terminal                                                       │
│  - Run this script again                                                       │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

"@ -ForegroundColor Yellow
}

function Show-ManualInstallationGuidance {
    $isWindowsOS = $IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSEdition -eq 'Desktop'
    
    Write-Host @"

┌─────────────────────────────────────────────────────────────────────────────────┐
│                        📥 MANUAL INSTALLATION GUIDANCE                         │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  PowerShell 7 installation is required for full AitherZero functionality.      │
│                                                                                 │
"@ -ForegroundColor Yellow
    
    if ($isWindowsOS) {
        Write-Host @"
│  WINDOWS INSTALLATION OPTIONS:                                                 │
│                                                                                 │
│  🎯 RECOMMENDED (choose one):                                                   │
│     • Windows Package Manager: winget install Microsoft.PowerShell            │
│     • Chocolatey: choco install powershell-core                               │
│     • Direct download: https://aka.ms/powershell-release                      │
│                                                                                 │
│  🔧 COMMAND LINE QUICK INSTALL:                                                │
│     • Run as Administrator: winget install Microsoft.PowerShell               │
│                                                                                 │
"@ -ForegroundColor Yellow
    } else {
        Write-Host @"
│  LINUX/MACOS INSTALLATION OPTIONS:                                             │
│                                                                                 │
│  🐧 LINUX:                                                                     │
│     • Ubuntu/Debian: sudo snap install powershell --classic                   │
│     • RHEL/CentOS: sudo yum install powershell                                │
│     • More options: https://aka.ms/powershell-linux                           │
│                                                                                 │
│  🍎 MACOS:                                                                     │
│     • Homebrew: brew install --cask powershell                                │
│     • Direct download: https://aka.ms/powershell-release                      │
│                                                                                 │
"@ -ForegroundColor Yellow
    }
    
    Write-Host @"
│  AFTER INSTALLATION:                                                           │
│  1. Close this terminal window                                                 │
│  2. Open a new terminal (search for 'pwsh' or 'PowerShell 7')                 │
│  3. Navigate to: $PSScriptRoot                                    │
│  4. Run: ./Start-AitherZero.ps1                                                │
│                                                                                 │
│  ✅ VERIFICATION: Run 'pwsh --version' to confirm installation                 │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

"@ -ForegroundColor Yellow
}

function Show-PowerShellRestartGuidance {
    Write-Host @"

┌─────────────────────────────────────────────────────────────────────────────────┐
│                         🔄 RESTART GUIDANCE                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  PowerShell 7 is installed but automatic restart failed.                       │
│                                                                                 │
│  MANUAL RESTART STEPS:                                                         │
│                                                                                 │
│  1. Close this terminal window                                                 │
│  2. Open PowerShell 7 (search for 'pwsh' or 'PowerShell 7')                   │
│  3. Navigate to: $PSScriptRoot                                    │
│  4. Run the same command you used before                                       │
│                                                                                 │
│  ALTERNATIVE: Run directly with PowerShell 7:                                  │
│     pwsh -File "$($MyInvocation.MyCommand.Path)"                              │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

"@ -ForegroundColor Yellow
}

function Show-InstallationFailureGuidance {
    Write-Host @"

┌─────────────────────────────────────────────────────────────────────────────────┐
│                      ⚠️ INSTALLATION FAILURE GUIDANCE                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  Automatic PowerShell 7 installation failed. This can happen due to:          │
│                                                                                 │
│  COMMON CAUSES:                                                                │
│  • Network connectivity issues                                                 │
│  • Insufficient permissions (try running as Administrator)                     │
│  • Corporate firewall or proxy restrictions                                    │
│  • Antivirus software interference                                             │
│                                                                                 │
│  TROUBLESHOOTING STEPS:                                                        │
│                                                                                 │
│  1. Check internet connection                                                  │
│  2. Run terminal as Administrator (Windows) or with sudo (Linux/macOS)        │
│  3. Temporarily disable antivirus (if safe to do so)                          │
│  4. Try manual installation from: https://aka.ms/powershell-release           │
│                                                                                 │
│  ALTERNATIVE INSTALLATION METHODS:                                             │
│  • Direct download from Microsoft                                              │
│  • Use your organization's software center                                     │
│  • Install from Microsoft Store (Windows)                                      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

"@ -ForegroundColor Red
}

function Show-PostInstallationGuidance {
    Write-Host @"

┌─────────────────────────────────────────────────────────────────────────────────┐
│                    🔧 POST-INSTALLATION GUIDANCE                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  PowerShell 7 installation completed but the executable was not found.         │
│                                                                                 │
│  POSSIBLE SOLUTIONS:                                                           │
│                                                                                 │
│  1. RESTART YOUR TERMINAL                                                      │
│     • Close this window completely                                             │
│     • Open a new terminal                                                      │
│     • Try running the script again                                             │
│                                                                                 │
│  2. UPDATE YOUR PATH                                                           │
│     • PowerShell 7 may not be in your PATH                                     │
│     • Try: refreshenv (Windows) or source ~/.bashrc (Linux/macOS)             │
│                                                                                 │
│  3. MANUAL VERIFICATION                                                        │
│     • Run: pwsh --version                                                      │
│     • If it works, PowerShell 7 is installed                                  │
│                                                                                 │
│  4. REBOOT YOUR SYSTEM                                                         │
│     • Sometimes a full reboot is needed for PATH updates                       │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

"@ -ForegroundColor Yellow
}

function Show-BootstrapSummary {
    $endTime = Get-Date
    $duration = $endTime - $script:BootstrapState.StartTime
    
    Write-Host @"

┌─────────────────────────────────────────────────────────────────────────────────┐
│                          📊 BOOTSTRAP SUMMARY                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  Duration: $($duration.TotalSeconds.ToString("0.0")) seconds                                                        │
│  Attempts: $($script:BootstrapState.Attempts)                                                                │
│  Errors: $($script:BootstrapState.Errors.Count)                                                                  │
│  Warnings: $($script:BootstrapState.Warnings.Count)                                                                │
│                                                                                 │
"@ -ForegroundColor Cyan
    
    if ($script:BootstrapState.Errors.Count -gt 0) {
        Write-Host "│  ERROR DETAILS:                                                                 │" -ForegroundColor Red
        foreach ($errorItem in $script:BootstrapState.Errors) {
            $truncated = if ($errorItem.Length -gt 73) { $errorItem.Substring(0, 70) + "..." } else { $errorItem }
            Write-Host "│  • $($truncated.PadRight(73))  │" -ForegroundColor Red
        }
    }
    
    if ($script:BootstrapState.Warnings.Count -gt 0) {
        Write-Host "│  WARNING DETAILS:                                                               │" -ForegroundColor Yellow
        foreach ($warning in $script:BootstrapState.Warnings) {
            $truncated = if ($warning.Length -gt 73) { $warning.Substring(0, 70) + "..." } else { $warning }
            Write-Host "│  • $($truncated.PadRight(73))  │" -ForegroundColor Yellow
        }
    }
    
    Write-Host @"
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

"@ -ForegroundColor Cyan
}

# ════════════════════════════════════════════════════════════════════════════════
#                               MAIN EXECUTION
# ════════════════════════════════════════════════════════════════════════════════

try {
    # Handle help request immediately
    if ($Help) {
        Show-BootstrapBanner
        Write-Host @"
AitherZero Enhanced Bootstrap Script

This script provides robust PowerShell 7 bootstrap capabilities with:
• Enhanced detection and installation mechanisms
• Network failure handling with offline fallback
• Comprehensive retry logic with exponential backoff
• Bootstrap validation and health checking
• Specific error recovery guidance

All parameters are passed through to the main AitherZero application.

Common Usage:
  ./Start-AitherZero.ps1                    # Interactive mode
  ./Start-AitherZero.ps1 -Setup             # First-time setup
  ./Start-AitherZero.ps1 -OfflineMode       # Offline mode
  ./Start-AitherZero.ps1 -MaxRetries 5      # Increased retry attempts

For full parameter documentation, run the script to bootstrap PowerShell 7,
then use the -Help parameter with the main application.
"@
        exit 0
    }
    
    # Show banner
    Show-BootstrapBanner
    
    # Run bootstrap health checks
    $healthResults = Test-BootstrapHealth
    
    # Initialize PowerShell 7 bootstrap
    $script:BootstrapState.Attempts++
    $bootstrapSuccess = Initialize-PowerShell7Bootstrap
    
    if ($bootstrapSuccess -and $PSVersionTable.PSVersion.Major -ge 7) {
        # If we reach here, we're running on PowerShell 7+
        Write-BootstrapLog "Bootstrap completed successfully. Launching AitherZero..." -Level 'SUCCESS'
        
        # Load and execute the main core script
        $coreScript = Join-Path $PSScriptRoot "aither-core/aither-core.ps1"
        
        if (Test-Path $coreScript) {
            # Build parameter hashtable for delegation
            $coreparams = @{}
            if ($Auto) { $coreparams['Auto'] = $true }
            if ($Scripts) { $coreparams['Scripts'] = $Scripts }
            if ($Setup) { $coreparams['Setup'] = $true }
            if ($InstallationProfile) { $coreparams['InstallationProfile'] = $InstallationProfile }
            if ($WhatIf) { $coreparams['WhatIf'] = $true }
            if ($Help) { $coreparams['Help'] = $true }
            if ($NonInteractive) { $coreparams['NonInteractive'] = $true }
            if ($Quiet) { $coreparams['Quiet'] = $true }
            if ($Verbosity) { $coreparams['Verbosity'] = $Verbosity }
            if ($ConfigFile) { $coreparams['ConfigFile'] = $ConfigFile }
            if ($Force) { $coreparams['Force'] = $true }
            if ($EnhancedUI) { $coreparams['EnhancedUI'] = $true }
            if ($ClassicUI) { $coreparams['ClassicUI'] = $true }
            if ($UIMode) { $coreparams['UIMode'] = $UIMode }
            
            & $coreScript @coreparams
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -ne 0) {
                Write-BootstrapLog "Core application exited with code: $exitCode" -Level 'ERROR'
                exit $exitCode
            }
        } else {
            Write-Error "Core script not found at: $coreScript"
            Write-BootstrapLog "Core script not found at: $coreScript" -Level 'ERROR'
            Write-BootstrapLog "Please ensure AitherZero is properly installed." -Level 'ERROR'
            exit 1
        }
    } else {
        Write-BootstrapLog "Bootstrap failed. Please follow the guidance above." -Level 'ERROR'
        exit 1
    }
    
} catch {
    Write-BootstrapLog "Bootstrap failed with error: $($_.Exception.Message)" -Level 'ERROR'
    
    # Enhanced error handling with specific guidance
    $errorHelperPath = Join-Path $PSScriptRoot "aither-core/shared/Show-UserFriendlyError.ps1"
    if (Test-Path $errorHelperPath) {
        . $errorHelperPath
        Show-UserFriendlyError -ErrorRecord $_ -Context "Bootstrap Process" -Module "Bootstrap"
    } else {
        # Fallback error display
        Write-Host ""
        Write-Host "❌ BOOTSTRAP FAILURE" -ForegroundColor Red
        Write-Host ""
        Write-Host "What happened:" -ForegroundColor Cyan
        Write-Host "  $($_.Exception.Message)" -ForegroundColor White
        Write-Host ""
        Write-Host "Common solutions:" -ForegroundColor Green
        Write-Host "  1. Run as Administrator (Windows) or with sudo (Linux/macOS)" -ForegroundColor Green
        Write-Host "  2. Check internet connection" -ForegroundColor Green
        Write-Host "  3. Try offline mode: ./Start-AitherZero.ps1 -OfflineMode" -ForegroundColor Green
        Write-Host "  4. Install PowerShell 7 manually: https://aka.ms/powershell-release" -ForegroundColor Green
        Write-Host ""
        Write-Host "For more help: https://github.com/wizzense/AitherZero/blob/main/README.md" -ForegroundColor Cyan
        Write-Host ""
    }
    
    exit 1
} finally {
    # Show bootstrap summary
    if (-not $Quiet) {
        Show-BootstrapSummary
    }
}# Test comment
