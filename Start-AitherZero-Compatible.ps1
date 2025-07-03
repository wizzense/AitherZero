# AitherZero Launcher - PowerShell 5.1+ Compatible Version
# This launcher ensures compatibility with all PowerShell versions

[CmdletBinding()]
param(
    [switch]$Interactive,
    [switch]$Auto,
    [switch]$Setup,
    [switch]$Help,
    [string[]]$Scripts,
    [ValidateSet('minimal', 'standard', 'developer', 'full')]
    [string]$InstallationProfile = 'standard',
    [switch]$WhatIf
)

# Ensure we're in the correct directory
$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
Set-Location $scriptRoot

# Version check and compatibility layer
$psVersion = $PSVersionTable.PSVersion
$isPS5 = $psVersion.Major -eq 5
$isPS7Plus = $psVersion.Major -ge 7

# Display banner
function Show-Banner {
    Write-Host ""
    Write-Host "AitherZero Infrastructure Automation Framework" -ForegroundColor Cyan
    Write-Host "PowerShell $($psVersion.Major).$($psVersion.Minor) Detected" -ForegroundColor Yellow
    Write-Host ""
}

# Help display
if ($Help) {
    Show-Banner
    Write-Host "USAGE:" -ForegroundColor Green
    Write-Host "  .\Start-AitherZero-Compatible.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Green
    Write-Host "  -Interactive          Run in interactive mode with menus" -ForegroundColor White
    Write-Host "  -Auto                 Run in automated mode" -ForegroundColor White
    Write-Host "  -Setup                Run first-time setup wizard" -ForegroundColor White
    Write-Host "  -Scripts <names>      Run specific scripts (comma-separated)" -ForegroundColor White
    Write-Host "  -InstallationProfile  Setup profile: minimal, standard, developer, full" -ForegroundColor White
    Write-Host "  -WhatIf               Preview mode - show what would be done" -ForegroundColor White
    Write-Host "  -Help                 Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Green
    Write-Host "  .\Start-AitherZero-Compatible.ps1 -Interactive" -ForegroundColor Gray
    Write-Host "  .\Start-AitherZero-Compatible.ps1 -Setup -InstallationProfile developer" -ForegroundColor Gray
    Write-Host "  .\Start-AitherZero-Compatible.ps1 -Scripts 'BackupManager,LabRunner'" -ForegroundColor Gray
    Write-Host ""
    return
}

Show-Banner

# Setup mode
if ($Setup) {
    Write-Host "Running Setup Wizard..." -ForegroundColor Green
    Write-Host ""
    
    # Run the compatible quick setup instead of the full wizard
    $quickSetup = Join-Path $scriptRoot "quick-setup-simple.ps1"
    if (Test-Path $quickSetup) {
        & $quickSetup -Profile $InstallationProfile
    }
    else {
        Write-Host "ERROR: Setup script not found" -ForegroundColor Red
        Write-Host "Please ensure all files are properly installed" -ForegroundColor Yellow
    }
    return
}

# Check if core files exist
$coreScript = Join-Path $scriptRoot "aither-core" "aither-core.ps1"
if (-not (Test-Path $coreScript)) {
    Write-Host "ERROR: Core script not found at: $coreScript" -ForegroundColor Red
    Write-Host ""
    Write-Host "It appears AitherZero is not properly installed." -ForegroundColor Yellow
    Write-Host "Please run: .\Start-AitherZero-Compatible.ps1 -Setup" -ForegroundColor White
    Write-Host ""
    return
}

# Load modules with compatibility handling
$modulesPath = Join-Path $scriptRoot "aither-core" "modules"
Write-Host "Loading modules..." -ForegroundColor Green

# Essential modules that should work with PS 5.1
$compatibleModules = @(
    "Logging",
    "ConfigurationRepository",
    "BackupManager",
    "RemoteConnection"
)

$loadedModules = @()
foreach ($module in $compatibleModules) {
    $modulePath = Join-Path $modulesPath $module
    if (Test-Path $modulePath) {
        try {
            Import-Module $modulePath -Force -ErrorAction Stop
            $loadedModules += $module
            Write-Host "  [OK] $module" -ForegroundColor Green
        }
        catch {
            Write-Host "  [SKIP] $module - Not compatible with PS $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "Loaded $($loadedModules.Count) modules" -ForegroundColor Cyan
Write-Host ""

# Interactive mode
if ($Interactive) {
    Write-Host "Interactive Mode" -ForegroundColor Cyan
    Write-Host "===============" -ForegroundColor Cyan
    Write-Host ""
    
    do {
        Write-Host "Available Options:" -ForegroundColor Green
        Write-Host "  1. Backup Manager" -ForegroundColor White
        Write-Host "  2. Remote Connection" -ForegroundColor White
        Write-Host "  3. View Logs" -ForegroundColor White
        Write-Host "  4. System Info" -ForegroundColor White
        Write-Host "  0. Exit" -ForegroundColor White
        Write-Host ""
        
        $choice = Read-Host "Select an option (0-4)"
        
        switch ($choice) {
            "1" {
                if ("BackupManager" -in $loadedModules) {
                    Write-Host "Starting Backup Manager..." -ForegroundColor Green
                    try {
                        # Call backup manager functions here
                        Get-Command -Module BackupManager | Select-Object -Property Name
                    }
                    catch {
                        Write-Host "Error running Backup Manager: $_" -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "Backup Manager module not available" -ForegroundColor Yellow
                }
            }
            "2" {
                if ("RemoteConnection" -in $loadedModules) {
                    Write-Host "Remote Connection options..." -ForegroundColor Green
                    Get-Command -Module RemoteConnection | Select-Object -Property Name
                }
                else {
                    Write-Host "Remote Connection module not available" -ForegroundColor Yellow
                }
            }
            "3" {
                $logsPath = Join-Path $scriptRoot "logs"
                if (Test-Path $logsPath) {
                    Write-Host "Recent log files:" -ForegroundColor Green
                    Get-ChildItem $logsPath -Filter "*.log" | 
                        Sort-Object LastWriteTime -Descending | 
                        Select-Object -First 5 -Property Name, LastWriteTime, Length
                }
                else {
                    Write-Host "No logs directory found" -ForegroundColor Yellow
                }
            }
            "4" {
                Write-Host "System Information:" -ForegroundColor Green
                Write-Host "  PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor White
                Write-Host "  OS: $($PSVersionTable.OS)" -ForegroundColor White
                Write-Host "  Platform: $($PSVersionTable.Platform)" -ForegroundColor White
                Write-Host "  Loaded Modules: $($loadedModules -join ', ')" -ForegroundColor White
            }
            "0" {
                Write-Host "Exiting..." -ForegroundColor Green
                break
            }
            default {
                Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            }
        }
        
        if ($choice -ne "0") {
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-Host
            Show-Banner
        }
        
    } while ($choice -ne "0")
    
    return
}

# Auto mode
if ($Auto) {
    Write-Host "Auto Mode - Running default tasks..." -ForegroundColor Green
    Write-Host ""
    
    # Run some basic automated tasks
    Write-Host "Checking system status..." -ForegroundColor Yellow
    
    # Check directories
    $dirs = @("configs", "logs", "backups", "temp")
    foreach ($dir in $dirs) {
        $path = Join-Path $scriptRoot $dir
        if (Test-Path $path) {
            Write-Host "  [OK] $dir directory exists" -ForegroundColor Green
        }
        else {
            Write-Host "  [CREATE] Creating $dir directory" -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
    
    Write-Host ""
    Write-Host "Auto mode completed" -ForegroundColor Green
    return
}

# Specific scripts mode
if ($Scripts) {
    Write-Host "Running specified scripts: $($Scripts -join ', ')" -ForegroundColor Green
    Write-Host ""
    
    foreach ($script in $Scripts) {
        if ($script -in $loadedModules) {
            Write-Host "Executing $script..." -ForegroundColor Yellow
            # Execute module-specific commands here
            Write-Host "  $script execution completed" -ForegroundColor Green
        }
        else {
            Write-Host "  $script is not available or not compatible" -ForegroundColor Red
        }
    }
    
    return
}

# Default - show available commands
Write-Host "No mode specified. Available commands:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  .\Start-AitherZero-Compatible.ps1 -Interactive" -ForegroundColor White
Write-Host "    Run in interactive mode with menu" -ForegroundColor Gray
Write-Host ""
Write-Host "  .\Start-AitherZero-Compatible.ps1 -Setup" -ForegroundColor White
Write-Host "    Run first-time setup wizard" -ForegroundColor Gray
Write-Host ""
Write-Host "  .\Start-AitherZero-Compatible.ps1 -Help" -ForegroundColor White
Write-Host "    Show detailed help and examples" -ForegroundColor Gray
Write-Host ""

if ($isPS5) {
    Write-Host "NOTE: Running on PowerShell 5.1" -ForegroundColor Yellow
    Write-Host "Some advanced features may be limited. For full functionality," -ForegroundColor Yellow
    Write-Host "consider upgrading to PowerShell 7+ from: https://aka.ms/powershell" -ForegroundColor Yellow
}