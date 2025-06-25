#!/usr/bin/env pwsh
# AitherZero Application Launcher (Fixed Version)
# Compatible with PowerShell 5.1+ and 7.x

param(
    [string]$Command,
    [switch]$Help,
    [switch]$Setup,
    [switch]$Interactive,
    [string]$ConfigFile,
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',
    [switch]$Auto,
    [string]$Scripts
)

# PowerShell version compatibility check
$psVersion = $PSVersionTable.PSVersion.Major
$isPS7Plus = $psVersion -ge 7

Clear-Host
Write-Host "🚀 AitherZero Infrastructure Automation Framework" -ForegroundColor Cyan
Write-Host "   Cross-Platform Infrastructure Automation with OpenTofu/Terraform" -ForegroundColor Yellow
Write-Host ""

if ($Help) {
    Write-Host "AitherZero Usage:" -ForegroundColor Green
    Write-Host ""
    Write-Host "Quick Start:" -ForegroundColor Cyan
    Write-Host "  ./Start-AitherZero.ps1                    # Interactive menu"
    Write-Host "  ./Start-AitherZero.ps1 -Auto             # Run all automation scripts"
    Write-Host "  ./Start-AitherZero.ps1 -Interactive      # Force interactive mode"
    Write-Host ""
    Write-Host "Advanced Usage:" -ForegroundColor Cyan
    Write-Host "  ./Start-AitherZero.ps1 -Scripts 'LabRunner,BackupManager'"
    Write-Host "  ./Start-AitherZero.ps1 -Verbosity detailed"
    Write-Host "  ./Start-AitherZero.ps1 -ConfigFile 'my-config.json'"
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  ./Start-AitherZero.ps1 -Setup            # First-time setup wizard"
    Write-Host ""
    Write-Host "Available Scripts: LabRunner, BackupManager, DevEnvironment, ScriptManager, UnifiedMaintenance, ParallelExecution"
    Write-Host ""
    return
}

# Set up environment
$env:AITHER_APP_ROOT = $PSScriptRoot
$env:PROJECT_ROOT = $PSScriptRoot

if ($Setup) {
    Write-Host "🔧 AitherZero First-Time Setup" -ForegroundColor Green
    Write-Host ""
    Write-Host "This will guide you through setting up AitherZero for your environment."
    Write-Host ""
    
    # Check PowerShell version with improved messaging
    if ($psVersion -lt 7) {
        Write-Host "⚠️  PowerShell $($PSVersionTable.PSVersion) detected" -ForegroundColor Yellow
        Write-Host "   AitherZero works best with PowerShell 7.0+" -ForegroundColor Yellow
        Write-Host "   Download: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   ✅ You can continue with your current version!" -ForegroundColor Green
        Write-Host "   Some advanced features may be limited, but core functionality works." -ForegroundColor White
    } else {
        Write-Host "✅ PowerShell $($PSVersionTable.PSVersion) detected - Full compatibility!" -ForegroundColor Green
    }
    
    # Check Git
    $gitVersion = try { git --version 2>$null } catch { $null }
    if ($gitVersion) {
        Write-Host "✅ Git detected: $gitVersion" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Git not found - required for PatchManager and repository operations" -ForegroundColor Yellow
        Write-Host "Install Git: https://git-scm.com/downloads" -ForegroundColor Yellow
    }
    
    # Check OpenTofu/Terraform
    $tofuVersion = try { tofu version 2>$null } catch { $null }
    $terraformVersion = try { terraform version 2>$null } catch { $null }
    if ($tofuVersion) {
        Write-Host "✅ OpenTofu detected: $($tofuVersion.Split([System.Environment]::NewLine)[0])" -ForegroundColor Green
    } elseif ($terraformVersion) {
        Write-Host "✅ Terraform detected: $($terraformVersion.Split([System.Environment]::NewLine)[0])" -ForegroundColor Green
    } else {
        Write-Host "⚠️  OpenTofu/Terraform not found - required for infrastructure automation" -ForegroundColor Yellow
        Write-Host "Install OpenTofu: https://opentofu.org/docs/intro/install/" -ForegroundColor Yellow
        Write-Host "Or Terraform: https://developer.hashicorp.com/terraform/downloads" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "🎯 Setup Complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Run: ./Start-AitherZero.ps1 -Interactive  # For guided experience"
    Write-Host "  2. Run: ./Start-AitherZero.ps1 -Auto         # For automated execution"
    Write-Host "  3. Run: ./Start-AitherZero.ps1 -Help         # For more options"
    Write-Host ""
    return
}

# Import essential modules with error handling (if available)
Write-Host "Loading AitherZero modules..." -ForegroundColor Cyan
if (Test-Path "$PSScriptRoot/modules") {
    $loadedModules = 0
    $totalModules = (Get-ChildItem "$PSScriptRoot/modules" -Directory).Count
    Get-ChildItem "$PSScriptRoot/modules" -Directory | ForEach-Object {
        try {
            Import-Module $_.FullName -Force -ErrorAction Stop
            $loadedModules++
            Write-Host "  ✅ $($_.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠️  $($_.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    Write-Host "Loaded $loadedModules/$totalModules modules successfully" -ForegroundColor Cyan
} else {
    Write-Host "⚠️  Modules directory not found at $PSScriptRoot/modules" -ForegroundColor Yellow
    Write-Host "   Some advanced features may not be available." -ForegroundColor White
}

# Build arguments for core script with proper parameter mapping
$coreArgs = @()

# FIXED: Proper parameter mapping to match aither-core.ps1 expectations
if ($ConfigFile) { 
    $coreArgs += '-ConfigFile', $ConfigFile 
}

# FIXED: Map Verbosity parameter correctly
if ($Verbosity -and $Verbosity -ne 'normal') { 
    $coreArgs += '-Verbosity', $Verbosity 
}

if ($Auto) { 
    $coreArgs += '-Auto' 
}

if ($Scripts) { 
    $coreArgs += '-Scripts', $Scripts 
}

# Add NonInteractive flag if not in interactive mode
if (-not $Interactive -and ($Auto -or $Scripts)) {
    $coreArgs += '-NonInteractive'
}

if (-not $Interactive -and -not $Auto -and -not $Scripts) {
    # Default to interactive mode if no specific mode is chosen
    Write-Host ""
    Write-Host "💡 Starting in interactive mode. Use -Auto for automated execution or -Help for more options." -ForegroundColor Cyan
    Write-Host ""
}

# Start the core application with enhanced error handling
Write-Host "Starting AitherZero core application..." -ForegroundColor Green
Write-Host ""

# FIXED: Enhanced PowerShell version handling
$coreScriptPath = "$PSScriptRoot/aither-core.ps1"

if (-not (Test-Path $coreScriptPath)) {
    Write-Host "❌ Core application file not found: aither-core.ps1" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Ensure all files were extracted properly" -ForegroundColor White
    Write-Host "  2. Check if this is the correct AitherZero directory" -ForegroundColor White
    Write-Host "  3. Re-download the AitherZero package if files are missing" -ForegroundColor White
    exit 1
}

try {
    # FIXED: Handle PowerShell version compatibility
    if ($psVersion -lt 7) {
        # Running on PowerShell 5.1 - check if PowerShell 7 is available
        $pwsh7Available = Get-Command pwsh -ErrorAction SilentlyContinue
        
        if ($pwsh7Available) {
            Write-Host "🔄 Switching to PowerShell 7 for optimal compatibility..." -ForegroundColor Yellow
            
            # Build the command line for PowerShell 7
            $pwshArgs = @('-ExecutionPolicy', 'Bypass', '-File', $coreScriptPath) + $coreArgs
            
            # Execute in PowerShell 7
            & pwsh @pwshArgs
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -ne 0) {
                throw "Core application exited with code: $exitCode"
            }
        } else {
            Write-Host "⚠️  PowerShell 7 not available, attempting to run with PowerShell $psVersion..." -ForegroundColor Yellow
            Write-Host "   Some features may be limited." -ForegroundColor White
            Write-Host ""
            
            # Try to run with current PowerShell version
            & $coreScriptPath @coreArgs
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -ne 0) {
                throw "Core application exited with code: $exitCode"
            }
        }
    } else {
        # Running on PowerShell 7+ - execute normally
        & $coreScriptPath @coreArgs
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -ne 0) {
            throw "Core application exited with code: $exitCode"
        }
    }
    
    Write-Host ""
    Write-Host "✅ AitherZero completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "❌ Error running AitherZero: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Troubleshooting Steps:" -ForegroundColor Yellow
    Write-Host "  1. Try setup mode: ./Start-AitherZero.ps1 -Setup" -ForegroundColor White
    Write-Host "  2. Get help: ./Start-AitherZero.ps1 -Help" -ForegroundColor White
    Write-Host "  3. Check PowerShell version: `$PSVersionTable.PSVersion" -ForegroundColor White
    Write-Host "  4. Ensure all files extracted properly" -ForegroundColor White
    Write-Host ""
    
    if ($psVersion -lt 7) {
        Write-Host "💡 Consider upgrading to PowerShell 7+ for full compatibility:" -ForegroundColor Cyan
        Write-Host "   https://aka.ms/powershell-release-windows" -ForegroundColor White
        Write-Host ""
        Write-Host "   Or use these alternative launch methods:" -ForegroundColor Cyan
        Write-Host "   - Windows: Use AitherZero.bat launcher" -ForegroundColor White
        Write-Host "   - PowerShell: pwsh -ExecutionPolicy Bypass -File aither-core.ps1 -Help" -ForegroundColor White
    }
    
    Write-Host ""
    exit 1
}
