#!/usr/bin/env pwsh
<#
.SYNOPSIS
    AitherZero Quick Setup - Simple version compatible with PowerShell 5.1+

.DESCRIPTION
    This script provides a fast, reliable setup experience for new AitherZero users.
    Compatible with both PowerShell 5.1 and 7.x.

.PARAMETER Auto
    Run in automated mode with minimal user interaction

.EXAMPLE
    ./quick-setup-simple.ps1
    ./quick-setup-simple.ps1 -Auto
#>

[CmdletBinding()]
param(
    [switch]$Auto
)

# Set strict mode and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

function Write-Message {
    param(
        [string]$Message,
        [string]$Type = 'Info'
    )
    
    switch ($Type) {
        'Success' { Write-Host $Message -ForegroundColor Green }
        'Warning' { Write-Host $Message -ForegroundColor Yellow }
        'Error' { Write-Host $Message -ForegroundColor Red }
        'Primary' { Write-Host $Message -ForegroundColor Cyan }
        default { Write-Host $Message -ForegroundColor White }
    }
}

function Write-Header {
    param([string]$Title)
    
    Write-Host ""
    Write-Message "AitherZero Quick Setup - $Title" -Type Primary
    Write-Message ("=" * 50) -Type Info
    Write-Host ""
}

function Test-Prerequisites {
    Write-Message "Checking prerequisites..." -Type Info
    
    $issues = @()
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        $issues += "PowerShell 5.0+ required (current: $psVersion)"
    } else {
        Write-Message "  [OK] PowerShell $psVersion" -Type Success
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
            Write-Message "  [OK] Directory: $dir" -Type Success
        } else {
            $issues += "Missing required directory: $dir"
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-Message "Prerequisites check failed:" -Type Error
        foreach ($issue in $issues) {
            Write-Message "   - $issue" -Type Error
        }
        return $false
    }
    
    Write-Message "All prerequisites satisfied!" -Type Success
    return $true
}

function Import-CoreModules {
    Write-Message "Loading core modules..." -Type Info
    
    $modulesPath = Join-Path $PSScriptRoot "aither-core/modules"
    
    if (-not (Test-Path $modulesPath)) {
        Write-Message "Modules directory not found at: $modulesPath" -Type Error
        return $false
    }
    
    # Load critical modules first
    $criticalModules = @('Logging', 'ModuleCommunication', 'ConfigurationCore')
    $loadedCount = 0
    
    foreach ($moduleName in $criticalModules) {
        $modulePath = Join-Path $modulesPath $moduleName
        if (Test-Path $modulePath) {
            try {
                Import-Module $modulePath -Force -ErrorAction Stop
                Write-Message "  [OK] $moduleName" -Type Success
                $loadedCount++
            } catch {
                Write-Message "  [WARN] $moduleName failed to load" -Type Warning
            }
        }
    }
    
    # Try to load other modules
    $otherModules = Get-ChildItem $modulesPath -Directory | Where-Object { $_.Name -notin $criticalModules }
    
    foreach ($module in $otherModules) {
        try {
            Import-Module $module.FullName -Force -ErrorAction Stop
            Write-Message "  [OK] $($module.Name)" -Type Success
            $loadedCount++
        } catch {
            # Silently continue for non-critical modules
        }
    }
    
    $totalModules = (Get-ChildItem $modulesPath -Directory).Count
    Write-Message "Loaded $loadedCount/$totalModules modules" -Type Info
    
    return $loadedCount -gt 0
}

function Initialize-AitherZero {
    Write-Message "Initializing AitherZero..." -Type Info
    
    try {
        # Check if SetupWizard is available
        if (Get-Command Start-IntelligentSetup -ErrorAction SilentlyContinue) {
            if ($Auto) {
                Write-Message "  Running automated setup..." -Type Info
                $result = Start-IntelligentSetup -MinimalSetup -SkipOptional
            } else {
                Write-Message "  Starting interactive setup..." -Type Info
                $result = Start-IntelligentSetup
            }
            
            if ($result) {
                Write-Message "AitherZero initialized successfully!" -Type Success
                return $true
            }
        } else {
            Write-Message "  SetupWizard not available, using basic initialization" -Type Warning
            
            # Basic initialization
            $configDir = Join-Path $env:USERPROFILE ".aither"
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                Write-Message "  Created configuration directory" -Type Success
            }
            
            return $true
        }
    } catch {
        Write-Message "Initialization failed: $($_.Exception.Message)" -Type Error
        return $false
    }
    
    return $false
}

function Show-QuickStart {
    Write-Message "AitherZero is ready to use!" -Type Success
    Write-Host ""
    Write-Message "QUICK START COMMANDS:" -Type Primary
    Write-Host ""
    Write-Host "  .\aither.ps1 help                    # Show all available commands"
    Write-Host "  .\aither.ps1 init                    # Run full interactive setup"
    Write-Host "  .\aither.ps1 dev release patch 'Fix' # Development workflow"
    Write-Host ""
    Write-Message "WINDOWS USERS:" -Type Info
    Write-Host "  aither help                          # Use the batch file"
    Write-Host ""
}

# Main execution
try {
    Write-Header "Getting You Started"
    
    if (-not (Test-Prerequisites)) {
        Write-Message "Setup cannot continue due to missing prerequisites" -Type Error
        exit 1
    }
    
    if (-not (Import-CoreModules)) {
        Write-Message "Module loading had issues, but continuing..." -Type Warning
    }
    
    if (Initialize-AitherZero) {
        Show-QuickStart
    } else {
        Write-Message "Initialization had issues, but basic functionality should work" -Type Warning
        Show-QuickStart
    }
    
} catch {
    Write-Message "Quick setup failed: $($_.Exception.Message)" -Type Error
    exit 1
}

Write-Host ""
Write-Message "Happy automating with AitherZero!" -Type Primary