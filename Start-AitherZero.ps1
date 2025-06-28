#!/usr/bin/env pwsh
# AitherZero Cross-Platform Application Launcher v1.1.0+
# Compatible with PowerShell 5.1+ and 7.x
# Automatic PowerShell version detection and parameter mapping

[CmdletBinding()]
param(
    [Parameter(HelpMessage = 'First-time setup and environment validation')]
    [switch]$Setup,

    [Parameter(HelpMessage = 'Show detailed usage information')]
    [switch]$Help,

    [Parameter(HelpMessage = 'Enable interactive mode (default)')]
    [switch]$Interactive,

    [Parameter(HelpMessage = 'Run in automated mode without prompts')]
    [switch]$Auto,

    [Parameter(HelpMessage = 'Specify which scripts/modules to run')]
    [string[]]$Scripts,

    [Parameter(HelpMessage = 'Logging verbosity level')]
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',

    [Parameter(HelpMessage = 'Custom configuration file path')]
    [string]$ConfigFile,

    [Parameter(HelpMessage = 'Show what would be done without executing')]
    [switch]$WhatIf,

    [Parameter(HelpMessage = 'Force operations even if validations fail')]
    [switch]$Force,

    [Parameter(HelpMessage = 'Run in non-interactive mode, suppress prompts')]
    [switch]$NonInteractive,

    [Parameter(HelpMessage = 'Run in quiet mode with minimal output')]
    [switch]$Quiet
)

# Detect PowerShell version for compatibility messaging
$psVersion = $PSVersionTable.PSVersion.Major

# Show banner
Write-Host 'AitherZero Infrastructure Automation Framework v1.1.0+' -ForegroundColor Green
Write-Host ''
Write-Host '   Cross-Platform Infrastructure Automation with OpenTofu/Terraform' -ForegroundColor Cyan
Write-Host ''

# Handle help request
if ($Help) {
    Write-Host 'AitherZero Usage:' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Modes:' -ForegroundColor Cyan
    Write-Host '  -Setup         First-time setup and environment validation'
    Write-Host '  -Interactive   Interactive mode with menu system (default)'
    Write-Host '  -Auto          Automated execution without prompts'
    Write-Host ''
    Write-Host 'Options:' -ForegroundColor Cyan
    Write-Host "  -Scripts       Specify modules to run (e.g., 'LabRunner,BackupManager')"
    Write-Host '  -Verbosity     Logging level: silent, normal, detailed'
    Write-Host '  -ConfigFile    Custom configuration file path'
    Write-Host '  -WhatIf        Preview mode - show what would be done'
    Write-Host '  -Help          This help information'
    Write-Host ''
    Write-Host 'Examples:' -ForegroundColor Cyan
    Write-Host '  .\Start-AitherZero.ps1 -Setup'
    Write-Host '  .\Start-AitherZero.ps1 -Interactive'
    Write-Host '  .\Start-AitherZero.ps1 -Auto -Verbosity detailed'
    Write-Host "  .\Start-AitherZero.ps1 -Scripts 'LabRunner' -WhatIf"
    Write-Host ''
    Write-Host 'Direct Core Access:' -ForegroundColor Cyan
    Write-Host "  pwsh -ExecutionPolicy Bypass -File 'aither-core.ps1' -Help"
    Write-Host ''
    return
}

# Handle setup mode with comprehensive environment checking
if ($Setup) {
    Write-Host '🔧 AitherZero First-Time Setup' -ForegroundColor Green
    Write-Host ''
    Write-Host 'This will guide you through setting up AitherZero for your environment.'
    Write-Host ''

    # Check PowerShell version with improved messaging
    if ($psVersion -lt 7) {
        Write-Host "⚠️  PowerShell $($PSVersionTable.PSVersion) detected" -ForegroundColor Yellow
        Write-Host '   AitherZero works best with PowerShell 7.0+' -ForegroundColor Yellow
        Write-Host '   Download: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '   ✅ You can continue with your current version!' -ForegroundColor Green
        Write-Host '   Some advanced features may be limited, but core functionality works.' -ForegroundColor White
    } else {
        Write-Host "✅ PowerShell $($PSVersionTable.PSVersion) detected - Full compatibility!" -ForegroundColor Green
    }

    # Check Git
    $gitVersion = try { git --version 2>$null } catch { $null }
    if ($gitVersion) {
        Write-Host "✅ Git detected: $gitVersion" -ForegroundColor Green
    } else {
        Write-Host '⚠️  Git not found - required for PatchManager and repository operations' -ForegroundColor Yellow
        Write-Host 'Install Git: https://git-scm.com/downloads' -ForegroundColor Yellow
    }

    # Check OpenTofu/Terraform
    $tofuVersion = try { tofu version 2>$null } catch { $null }
    $terraformVersion = try { terraform version 2>$null } catch { $null }
    if ($tofuVersion) {
        Write-Host "✅ OpenTofu detected: $($tofuVersion.Split([System.Environment]::NewLine)[0])" -ForegroundColor Green
    } elseif ($terraformVersion) {
        Write-Host "✅ Terraform detected: $($terraformVersion.Split([System.Environment]::NewLine)[0])" -ForegroundColor Green
    } else {
        Write-Host '⚠️  OpenTofu/Terraform not found - required for infrastructure automation' -ForegroundColor Yellow
        Write-Host 'Install OpenTofu: https://opentofu.org/docs/intro/install/' -ForegroundColor Yellow
        Write-Host 'Or Terraform: https://developer.hashicorp.com/terraform/downloads' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host '🎯 Setup Complete!' -ForegroundColor Green
    Write-Host ''
    Write-Host 'Next Steps:' -ForegroundColor Cyan
    Write-Host '  1. Run: ./Start-AitherZero.ps1 -Interactive  # For guided experience'
    Write-Host '  2. Run: ./Start-AitherZero.ps1 -Auto         # For automated execution'
    Write-Host '  3. Run: ./Start-AitherZero.ps1 -Help         # For more options'
    Write-Host ''
    return
}

# Import essential modules with error handling (if available)
Write-Host 'Loading AitherZero modules...' -ForegroundColor Cyan

# Determine modules directory based on launcher location
$modulesPath = Join-Path $PSScriptRoot 'modules'
if (-not (Test-Path $modulesPath)) {
    $modulesPath = Join-Path $PSScriptRoot 'aither-core/modules'
}
if (-not (Test-Path $modulesPath)) {
    $modulesPath = Join-Path $PSScriptRoot '../../aither-core/modules'
}

if (Test-Path $modulesPath) {
    $loadedModules = 0
    $totalModules = (Get-ChildItem $modulesPath -Directory).Count
    Get-ChildItem $modulesPath -Directory | ForEach-Object {
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
    Write-Host '⚠️  Modules directory not found at expected locations' -ForegroundColor Yellow
    $path1 = Join-Path $PSScriptRoot 'modules'
    $path2 = Join-Path $PSScriptRoot (Join-Path 'aither-core' 'modules')
    $path3 = Join-Path $PSScriptRoot (Join-Path '..' (Join-Path '..' (Join-Path 'aither-core' 'modules')))
    Write-Host "   Checked: $path1, $path2, $path3" -ForegroundColor Yellow
    Write-Host '   Some advanced features may not be available.' -ForegroundColor White
}

# Set up core script arguments with proper parameter mapping
$coreArgs = @{}

# String parameters (pass with value)
if ($PSBoundParameters.ContainsKey('Verbosity')) { $coreArgs['Verbosity'] = $Verbosity }
if ($PSBoundParameters.ContainsKey('ConfigFile')) { $coreArgs['ConfigFile'] = $ConfigFile }
if ($PSBoundParameters.ContainsKey('Scripts')) { $coreArgs['Scripts'] = ($Scripts -join ',') }

# Switch parameters (pass only the switch when present)
if ($PSBoundParameters.ContainsKey('Auto')) { $coreArgs['Auto'] = $true }
if ($PSBoundParameters.ContainsKey('Force')) { $coreArgs['Force'] = $true }
if ($PSBoundParameters.ContainsKey('NonInteractive')) { $coreArgs['NonInteractive'] = $true }
if ($PSBoundParameters.ContainsKey('Quiet')) { $coreArgs['Quiet'] = $true }
if ($PSBoundParameters.ContainsKey('WhatIf')) { $coreArgs['WhatIf'] = $true }

# Note: Setup, Help, Interactive are launcher-specific and not passed to core script

# Handle default mode selection
if (-not $Interactive -and -not $Auto -and -not $Scripts) {
    # Default to interactive mode if no specific mode is chosen
    Write-Host ''
    Write-Host '💡 Starting in interactive mode. Use -Auto for automated execution or -Help for more options.' -ForegroundColor Cyan
    Write-Host ''
}

# Start the core application with enhanced error handling and PowerShell version awareness
Write-Host 'Starting AitherZero core application...' -ForegroundColor Green
Write-Host ''

try {
    # Resolve path to core application script with robust detection
    # This launcher supports multiple deployment scenarios

    $possiblePaths = @(
        # Scenario 1: Launcher in root of application package
        (Join-Path $PSScriptRoot 'aither-core.ps1'),
        # Scenario 2: Launcher in root, core in aither-core directory
        (Join-Path $PSScriptRoot (Join-Path 'aither-core' 'aither-core.ps1')),
        # Scenario 3: Launcher in templates/launchers (development)
        (Join-Path $PSScriptRoot (Join-Path '..' (Join-Path '..' (Join-Path 'aither-core' 'aither-core.ps1')))),
        # Scenario 4: Try to find using shared utility (if available)
        $null  # Placeholder for Find-ProjectRoot result
    )

    # Try Find-ProjectRoot utility if available
    $findProjectRootPath = Join-Path $PSScriptRoot (Join-Path '..' (Join-Path '..' (Join-Path 'aither-core' (Join-Path 'shared' 'Find-ProjectRoot.ps1'))))
    if (Test-Path $findProjectRootPath) {
        try {
            . $findProjectRootPath
            $projectRoot = Find-ProjectRoot -StartPath $PSScriptRoot
            if ($projectRoot) {
                $possiblePaths[3] = Join-Path $projectRoot (Join-Path 'aither-core' 'aither-core.ps1')
            }
        } catch {
            Write-Verbose "Find-ProjectRoot utility failed: $($_.Exception.Message)"
        }
    }

    # Try each path until we find the core script
    $coreScriptPath = $null
    foreach ($path in $possiblePaths) {
        if ($path -and (Test-Path $path)) {
            $coreScriptPath = $path
            Write-Verbose "Found core script at: $coreScriptPath"
            break
        }
    }

    if (-not $coreScriptPath) {
        Write-Host "❌ Core application file not found." -ForegroundColor Red
        Write-Host ""
        Write-Host "Tried the following paths:" -ForegroundColor Yellow
        foreach ($path in $possiblePaths) {
            if ($path) {
                $exists = if (Test-Path $path) { "✓" } else { "✗" }
                Write-Host "  $exists $path" -ForegroundColor $(if (Test-Path $path) { 'Green' } else { 'Red' })
            }
        }
        Write-Host ""
        Write-Host "💡 Troubleshooting:" -ForegroundColor Cyan
        Write-Host "  1. Ensure all files were extracted properly" -ForegroundColor White
        Write-Host "  2. Run from the project root directory" -ForegroundColor White
        Write-Host "  3. Check that $(Join-Path 'aither-core' 'aither-core.ps1') exists" -ForegroundColor White
        Write-Host "  4. Current launcher location: $PSScriptRoot" -ForegroundColor White
        throw "Core application file not found in any expected location"
    }

    # Enhanced execution for PowerShell version compatibility
    if ($psVersion -lt 7) {
        # Check if PowerShell 7 is available for optimal execution
        $pwsh7Available = try { Get-Command pwsh -ErrorAction Stop; $true } catch { $false }

        if ($pwsh7Available) {
            Write-Host "⚠️  PowerShell $psVersion detected, but PowerShell 7 is available" -ForegroundColor Yellow
            Write-Host '   Attempting to use PowerShell 7 for optimal compatibility...' -ForegroundColor White
            Write-Host ''

            # Build the command line for PowerShell 7
            $pwshArgs = @('-ExecutionPolicy', 'Bypass', '-File', $coreScriptPath)

            # Add core arguments to pwsh command
            foreach ($key in $coreArgs.Keys) {
                if ($coreArgs[$key] -eq $true) {
                    # Switch parameter
                    $pwshArgs += "-$key"
                } else {
                    # Value parameter
                    $pwshArgs += "-$key"
                    $pwshArgs += $coreArgs[$key]
                }
            }

            # Execute in PowerShell 7
            & pwsh $pwshArgs
            $exitCode = $LASTEXITCODE

            if ($exitCode -ne 0) {
                throw "Core application exited with code: $exitCode"
            }
        } else {
            Write-Host "⚠️  PowerShell 7 not available, attempting to run with PowerShell $psVersion..." -ForegroundColor Yellow
            Write-Host '   Some features may be limited.' -ForegroundColor White
            Write-Host ''

            # Try to run with current PowerShell version using hashtable splatting
            & $coreScriptPath @coreArgs
            $exitCode = $LASTEXITCODE

            if ($exitCode -ne 0) {
                throw "Core application exited with code: $exitCode"
            }
        }
    } else {
        # Running on PowerShell 7+ - execute normally with proper argument handling
        & $coreScriptPath @coreArgs
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            throw "Core application exited with code: $exitCode"
        }
    }

    Write-Host ''
    Write-Host '✅ AitherZero completed successfully!' -ForegroundColor Green

} catch {
    Write-Host ''
    Write-Host "❌ Error running AitherZero: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ''
    Write-Host '💡 Troubleshooting Steps:' -ForegroundColor Yellow
    Write-Host '  1. Try setup mode: ./Start-AitherZero.ps1 -Setup' -ForegroundColor White
    Write-Host '  2. Get help: ./Start-AitherZero.ps1 -Help' -ForegroundColor White
    Write-Host "  3. Check PowerShell version: `$PSVersionTable.PSVersion" -ForegroundColor White
    Write-Host '  4. Ensure all files extracted properly' -ForegroundColor White
    Write-Host ''

    if ($psVersion -lt 7) {
        Write-Host '💡 Consider upgrading to PowerShell 7+ for full compatibility:' -ForegroundColor Cyan
        Write-Host '   https://aka.ms/powershell-release-windows' -ForegroundColor White
        Write-Host ''
        Write-Host '   Or use these alternative launch methods:' -ForegroundColor Cyan
        Write-Host '   - Windows: Use AitherZero.bat launcher' -ForegroundColor White
        Write-Host '   - PowerShell: pwsh -ExecutionPolicy Bypass -File aither-core.ps1 -Help' -ForegroundColor White
    }

    Write-Host ''
    exit 1
}
