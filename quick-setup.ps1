#!/usr/bin/env pwsh
<#
.SYNOPSIS
    AitherZero Quick Setup - Streamlined first-time experience

.DESCRIPTION
    This script provides a fast, reliable setup experience for new AitherZero users.
    It detects the environment, validates prerequisites, and gets users up and running quickly.

.PARAMETER Profile
    Installation profile to use (minimal, standard, developer, full)

.PARAMETER Auto
    Run in automated mode with minimal user interaction

.PARAMETER SkipValidation
    Skip environment validation (use with caution)

.EXAMPLE
    ./quick-setup.ps1
    Interactive setup with standard profile

.EXAMPLE
    ./quick-setup.ps1 -Profile developer -Auto
    Automated setup with developer profile

.NOTES
    AitherZero Quick Setup v1.0
    This replaces the complex multi-file startup process with a single, reliable script.
#>

[CmdletBinding()]
param(
    [ValidateSet('minimal', 'standard', 'developer', 'full')]
    [string]$Profile = 'standard',
    
    [switch]$Auto,
    
    [switch]$SkipValidation
)

# Set strict mode and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Colors for consistent output
$Colors = @{
    Primary = 'Cyan'
    Success = 'Green'
    Warning = 'Yellow'
    Error = 'Red'
    Info = 'Blue'
    Muted = 'DarkGray'
}

function Write-SetupMessage {
    param(
        [string]$Message,
        [ValidateSet('Primary', 'Success', 'Warning', 'Error', 'Info', 'Muted')]
        [string]$Type = 'Info',
        [switch]$NoNewline
    )
    
    $color = $Colors[$Type]
    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $color
    }
}

function Write-SetupHeader {
    param([string]$Title)
    
    Write-Host ""
    # Use ASCII-compatible characters for PowerShell 5.1 compatibility
    $rocket = if ($PSVersionTable.PSVersion.Major -ge 6) { "🚀" } else { "[SETUP]" }
    Write-SetupMessage "$rocket AitherZero Quick Setup - $Title" -Type Primary
    Write-SetupMessage ("=" * 60) -Type Muted
    Write-Host ""
}

function Test-Prerequisites {
    $checkIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "🔍" } else { "[CHECK]" }
    Write-SetupMessage "$checkIcon Checking prerequisites..." -Type Info
    
    $issues = @()
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        $issues += "PowerShell 5.0+ required (current: $psVersion)"
    } elseif ($psVersion.Major -eq 5) {
        $warnIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "⚠️" } else { "[WARN]" }
        Write-SetupMessage "  $warnIcon  PowerShell 5.1 detected - some features may be limited" -Type Warning
        Write-SetupMessage "     Consider upgrading to PowerShell 7+ for best experience" -Type Muted
    } else {
        $okIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "✅" } else { "[OK]" }
        Write-SetupMessage "  $okIcon PowerShell $psVersion" -Type Success
    }
    
    # Check execution policy
    $executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($executionPolicy -eq 'Restricted') {
        $warnIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "⚠️" } else { "[WARN]" }
        Write-SetupMessage "  $warnIcon  Execution policy is Restricted" -Type Warning
        Write-SetupMessage "     This may prevent script execution" -Type Muted
    } else {
        $okIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "✅" } else { "[OK]" }
        Write-SetupMessage "  $okIcon Execution policy: $executionPolicy" -Type Success
    }
    
    # Check if we're in the right directory
    $currentDir = $PWD.Path
    $scriptDir = $PSScriptRoot
    if ($currentDir -ne $scriptDir) {
        $infoIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "ℹ️" } else { "[INFO]" }
        Write-SetupMessage "  $infoIcon  Working directory: $currentDir" -Type Info
        Write-SetupMessage "     Script directory: $scriptDir" -Type Muted
    }
    
    # Check for required directories
    $requiredDirs = @(
        'aither-core',
        'aither-core/modules',
        'aither-core/shared'
    )
    
    foreach ($dir in $requiredDirs) {
        $fullPath = Join-Path $PSScriptRoot $dir
        if (Test-Path $fullPath) {
            $okIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "✅" } else { "[OK]" }
            Write-SetupMessage "  $okIcon Directory: $dir" -Type Success
        } else {
            $issues += "Missing required directory: $dir"
        }
    }
    
    if ($issues.Count -gt 0) {
        $errorIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "❌" } else { "[ERROR]" }
        Write-SetupMessage "$errorIcon Prerequisites check failed:" -Type Error
        foreach ($issue in $issues) {
            $bullet = if ($PSVersionTable.PSVersion.Major -ge 6) { "•" } else { "-" }
            Write-SetupMessage "   $bullet $issue" -Type Error
        }
        return $false
    }
    
    $successIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "✅" } else { "[OK]" }
    Write-SetupMessage "$successIcon All prerequisites satisfied!" -Type Success
    return $true
}

function Import-CoreModules {
    $moduleIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "📦" } else { "[MODULES]" }
    Write-SetupMessage "$moduleIcon Loading core modules..." -Type Info
    
    $modulesPath = Join-Path $PSScriptRoot "aither-core/modules"
    
    if (-not (Test-Path $modulesPath)) {
        throw "Modules directory not found at: $modulesPath"
    }
    
    # Load critical modules in the correct order
    $criticalModules = @('Logging', 'ModuleCommunication', 'ConfigurationCore')
    $loadedCount = 0
    
    foreach ($moduleName in $criticalModules) {
        $modulePath = Join-Path $modulesPath $moduleName
        if (Test-Path $modulePath) {
            try {
                Import-Module $modulePath -Force -ErrorAction Stop
                $okIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "✅" } else { "[OK]" }
                Write-SetupMessage "  $okIcon $moduleName" -Type Success
                $loadedCount++
            } catch {
                Write-SetupMessage "  WARNING $moduleName`: $($_.Exception.Message)" -Type Warning
            }
        } else {
            Write-SetupMessage "  WARNING $moduleName`: Not found" -Type Warning
        }
    }
    
    # Try to load other modules (non-critical)
    $otherModules = Get-ChildItem $modulesPath -Directory | Where-Object { $_.Name -notin $criticalModules }
    
    foreach ($module in $otherModules) {
        try {
            Import-Module $module.FullName -Force -ErrorAction Stop
            $okIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "✅" } else { "[OK]" }
            Write-SetupMessage "  $okIcon $($module.Name)" -Type Success
            $loadedCount++
        } catch {
            Write-SetupMessage "  WARNING $($module.Name)`: Failed to load" -Type Warning
        }
    }
    
    $totalModules = (Get-ChildItem $modulesPath -Directory).Count
    $moduleIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "📦" } else { "[MODULES]" }
    Write-SetupMessage "$moduleIcon Loaded $loadedCount/$totalModules modules" -Type Info
    
    return $loadedCount -gt 0
}

function Initialize-AitherZero {
    param([string]$ProfileName)
    
    $gearIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "⚙️" } else { "[INIT]" }
    Write-SetupMessage "$gearIcon  Initializing AitherZero with '$ProfileName' profile..." -Type Info
    
    try {
        # Check if SetupWizard is available
        if (Get-Command Start-IntelligentSetup -ErrorAction SilentlyContinue) {
            if ($Auto) {
                $robotIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "🤖" } else { "[AUTO]" }
                Write-SetupMessage "  $robotIcon Running automated setup..." -Type Info
                $result = Start-IntelligentSetup -MinimalSetup -SkipOptional
            } else {
                $peopleIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "👥" } else { "[INTERACTIVE]" }
                Write-SetupMessage "  $peopleIcon Starting interactive setup..." -Type Info
                $result = Start-IntelligentSetup
            }
            
            if ($result) {
                $successIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "✅" } else { "[OK]" }
                Write-SetupMessage "$successIcon AitherZero initialized successfully!" -Type Success
                return $true
            }
        } else {
            $warnIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "⚠️" } else { "[WARN]" }
            Write-SetupMessage "  $warnIcon  SetupWizard not available, using basic initialization" -Type Warning
            
            # Basic initialization without SetupWizard
            $configDir = Join-Path $env:USERPROFILE ".aither"
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                $okIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "✅" } else { "[OK]" }
                Write-SetupMessage "  $okIcon Created configuration directory" -Type Success
            }
            
            return $true
        }
    } catch {
        $errorIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "❌" } else { "[ERROR]" }
        Write-SetupMessage "$errorIcon Initialization failed: $($_.Exception.Message)" -Type Error
        return $false
    }
    
    return $false
}

function Show-QuickStart {
    $partyIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "🎉" } else { "[READY]" }
    Write-SetupMessage "$partyIcon AitherZero is ready to use!" -Type Success
    Write-Host ""
    Write-SetupMessage "QUICK START COMMANDS:" -Type Primary
    Write-Host ""
    Write-Host "  ./aither.ps1 help                    # Show all available commands"
    Write-Host "  ./aither.ps1 init                    # Run full interactive setup"
    Write-Host "  ./aither.ps1 deploy create my-lab    # Create your first project"
    Write-Host "  ./aither.ps1 dev release patch 'Fix' # Development workflow"
    Write-Host ""
    Write-SetupMessage "WINDOWS USERS:" -Type Info
    Write-Host "  aither help                          # Use the batch file for easier access"
    Write-Host ""
    Write-SetupMessage "For detailed documentation, visit: https://github.com/wizzense/AitherZero" -Type Muted
}

function Show-TroubleshootingInfo {
    Write-Host ""
    Write-SetupMessage "TROUBLESHOOTING:" -Type Warning
    Write-Host ""
    Write-Host "If you encounter issues:"
    Write-Host "  1. Run: ./Start-AitherZero.ps1 -Setup    # Original setup wizard"
    Write-Host "  2. Run: ./aither.ps1 init                # Modern CLI setup"
    Write-Host "  3. Check: $($PSVersionTable.PSVersion)   # PowerShell version"
    Write-Host "  4. Report issues at: https://github.com/wizzense/AitherZero/issues"
    Write-Host ""
}

# Main execution
try {
    Write-SetupHeader "Getting You Started"
    
    # Skip validation if requested
    if (-not $SkipValidation) {
        if (-not (Test-Prerequisites)) {
            Show-TroubleshootingInfo
            exit 1
        }
    }
    
    # Load modules
    if (-not (Import-CoreModules)) {
        Write-SetupMessage "⚠️  Module loading had issues, but continuing..." -Type Warning
    }
    
    # Initialize AitherZero
    if (Initialize-AitherZero $Profile) {
        Show-QuickStart
    } else {
        Write-SetupMessage "⚠️  Initialization had issues, but basic functionality should work" -Type Warning
        Show-QuickStart
        Show-TroubleshootingInfo
    }
    
} catch {
    $errorIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "❌" } else { "[ERROR]" }
    Write-SetupMessage "$errorIcon Quick setup failed: $($_.Exception.Message)" -Type Error
    Write-SetupMessage "Stack trace: $($_.ScriptStackTrace)" -Type Muted
    Show-TroubleshootingInfo
    exit 1
}

Write-Host ""
$rocketIcon = if ($PSVersionTable.PSVersion.Major -ge 6) { "🚀" } else { ""} 
Write-SetupMessage "Happy automating with AitherZero! $rocketIcon" -Type Primary