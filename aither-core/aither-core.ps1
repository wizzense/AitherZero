#Requires -Version 7.0

<#
.SYNOPSIS
    Core application runner for Aitherium Infrastructure Automation

.DESCRIPTION
    Main runner script that orchestrates infrastructure setup, configuration, and script execution
    for the Aitherium platform.

.PARAMETER Quiet
    Run in quiet mode with minimal output

.PARAMETER Verbosity
    Set verbosity level: silent, normal, detailed

.PARAMETER ConfigFile
    Path to configuration file (defaults to default-config.json)

.PARAMETER Auto
    Run in automatic mode without prompts

.PARAMETER Scripts
    Specific scripts to run

.PARAMETER Force
    Force operations even if validations fail

.PARAMETER NonInteractive
    Run in non-interactive mode, suppress prompts and user input

.EXAMPLE
    .\core-runner.ps1

.EXAMPLE
    .\core-runner.ps1 -ConfigFile "custom-config.json" -Verbosity detailed
#>

[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Default')]
param(
    [Parameter(ParameterSetName = 'Quiet')]
    [switch]$Quiet,

    [Parameter(ParameterSetName = 'Default')]
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',

    [string]$ConfigFile,
    [switch]$Auto,
    [string]$Scripts,
    [switch]$Force,
    [switch]$NonInteractive,
    [switch]$Help,
    
    [Parameter(HelpMessage = 'Run first-time setup wizard')]
    [switch]$Setup,
    
    [Parameter(HelpMessage = 'Installation profile: minimal, developer, full, or interactive')]
    [ValidateSet('minimal', 'developer', 'full', 'interactive')]
    [string]$InstallationProfile = 'interactive',
    
    [Parameter(HelpMessage = 'Force enhanced UI experience with StartupExperience module')]
    [switch]$EnhancedUI,
    
    [Parameter(HelpMessage = 'Force classic menu experience with Show-DynamicMenu')]
    [switch]$ClassicUI,
    
    [Parameter(HelpMessage = 'UI preference mode')]
    [ValidateSet('auto', 'enhanced', 'classic')]
    [string]$UIMode = 'auto'
)

# Set up environment
$ErrorActionPreference = 'Stop'

# Handle UI mode parameter conflicts
if ($EnhancedUI -and $ClassicUI) {
    Write-Error "Cannot specify both -EnhancedUI and -ClassicUI. Please choose one."
    exit 1
}

# Resolve UI mode based on parameters
if ($EnhancedUI) {
    $UIMode = 'enhanced'
} elseif ($ClassicUI) {
    $UIMode = 'classic'
}

# Handle help request
if ($Help) {
    Write-Host "AitherZero Core Application" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  aither-core.ps1 [options]"
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  -Quiet          Run in quiet mode with minimal output"
    Write-Host "  -Verbosity      Set verbosity level: silent, normal, detailed"
    Write-Host "  -ConfigFile     Path to configuration file"
    Write-Host "  -Auto           Run in automatic mode without prompts"
    Write-Host "  -Scripts        Specific scripts to run"
    Write-Host "  -Force          Force operations even if validations fail"
    Write-Host "  -NonInteractive Run in non-interactive mode"
    Write-Host "  -Setup          Run first-time setup wizard"
    Write-Host "  -InstallationProfile Installation profile: minimal, developer, full, interactive"
    Write-Host "  -EnhancedUI     Force enhanced UI experience"
    Write-Host "  -ClassicUI      Force classic menu experience"
    Write-Host "  -UIMode         UI preference: auto, enhanced, classic"
    Write-Host "  -Help           Show this help information"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\aither-core.ps1"
    Write-Host "  .\aither-core.ps1 -Verbosity detailed -Auto"
    Write-Host "  .\aither-core.ps1 -ConfigFile custom.json -Scripts LabRunner"
    Write-Host "  .\aither-core.ps1 -Setup -InstallationProfile developer"
    Write-Host "  .\aither-core.ps1 -Setup  # Interactive profile selection"
    Write-Host ""
    return
}

function Invoke-ScriptWithOutputHandling {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ScriptName,

        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [Parameter(Mandatory)]
        [hashtable]$Config,

        [switch]$Force,

        [ValidateSet('silent', 'normal', 'detailed')]
        [string]$Verbosity = 'normal'
    )

    # Script execution with output handling and user-focused display
    # In normal mode, logging is minimal (WARN/ERROR only) to keep output clean
    # Scripts should use Write-Host for user-facing output and Write-CustomLog for internal logging
    Write-CustomLog "Starting script execution: $ScriptName" -Level DEBUG

    try {
        $scriptOutput = & $ScriptPath -Config $Config *>&1
        $visibleOutputCount = 0
        $hasUserVisibleOutput = $false

        if ($scriptOutput) {
            $scriptOutput | ForEach-Object {
                if ($_ -is [System.Management.Automation.ErrorRecord]) {
                    Write-CustomLog "Script error: $($_.Exception.Message)" -Level ERROR
                    $visibleOutputCount++
                    $hasUserVisibleOutput = $true
                } elseif ($_ -is [System.Management.Automation.WarningRecord]) {
                    Write-CustomLog "Script warning: $($_.Message)" -Level WARN
                    $visibleOutputCount++
                    $hasUserVisibleOutput = $true
                } elseif ($_ -is [System.Management.Automation.VerboseRecord]) {
                    Write-CustomLog "Script verbose: $($_.Message)" -Level DEBUG
                    # Verbose output doesn't count as "user visible" in normal mode
                } else {
                    # In silent mode, suppress all Write-Host output including user-facing information
                    if ($Verbosity -ne 'silent') {
                        Write-Host $_.ToString()
                        $visibleOutputCount++
                        $hasUserVisibleOutput = $true
                    } else {
                        # Still count the output for tracking, but don't display it
                        $visibleOutputCount++
                        $hasUserVisibleOutput = $true
                    }
                }
            }
        }

        # Detect and warn about scripts with no visible output
        if (-not $hasUserVisibleOutput -and $Verbosity -in @('normal', 'silent')) {
            $warningMessage = "⚠️  Script '$ScriptName' completed successfully but produced no visible output in '$Verbosity' mode."
            $suggestionMessage = "💡 Consider running with '-Verbosity detailed' to see more information, or the script may need output improvements."

            Write-Host ""
            Write-Host $warningMessage -ForegroundColor Yellow
            Write-Host $suggestionMessage -ForegroundColor Cyan
            Write-Host ""

            Write-CustomLog "No visible output detected for script: $ScriptName in verbosity mode: $Verbosity" -Level WARN

            # Track this for potential automation/reporting
            $script:NoOutputScripts = $script:NoOutputScripts ?? @()
            $script:NoOutputScripts += [PSCustomObject]@{
                ScriptName = $ScriptName
                ScriptPath = $ScriptPath
                Verbosity = $Verbosity
                Timestamp = Get-Date
            }
        }

        Write-CustomLog "Script completed: $ScriptName (Visible outputs: $visibleOutputCount)" -Level DEBUG
    } catch {
        Write-CustomLog "Script failed: $ScriptName - $($_.Exception.Message)" -Level ERROR
        if (-not $Force) {
            throw
        }
    }
}

# Auto-detect non-interactive mode if not explicitly set
if (-not $NonInteractive) {
    $hostCheck = ($Host.Name -eq 'Default Host')
    $userInteractiveCheck = ([Environment]::UserInteractive -eq $false)
    $pesterCheck = ($env:PESTER_RUN -eq 'true')
    $whatIfCheck = ($PSCmdlet.WhatIf)
    $autoCheck = ($Auto.IsPresent)

    Write-Verbose "NonInteractive checks: Host=$hostCheck, UserInteractive=$userInteractiveCheck, Pester=$pesterCheck, WhatIf=$whatIfCheck, Auto=$autoCheck"

    $NonInteractive = $hostCheck -or $userInteractiveCheck -or $pesterCheck -or $whatIfCheck -or $autoCheck
}

Write-Verbose "Final NonInteractive value: $NonInteractive"

# Use robust project root detection from shared utility
# Try multiple locations for the shared utility based on structure
$findProjectRootPaths = @(
    (Join-Path $PSScriptRoot "shared" "Find-ProjectRoot.ps1"),           # Release structure: same level as script
    (Join-Path $PSScriptRoot ".." "shared" "Find-ProjectRoot.ps1"),      # Dev structure: up one level
    (Join-Path $PSScriptRoot ".." "aither-core" "shared" "Find-ProjectRoot.ps1")  # Alternative dev structure
)

$repoRoot = $null
foreach ($path in $findProjectRootPaths) {
    if (Test-Path $path) {
        try {
            . $path
            $repoRoot = Find-ProjectRoot -StartPath $PSScriptRoot
            Write-Verbose "Used shared utility to find project root: $repoRoot (from $path)"
            break
        } catch {
            Write-Verbose "Failed to use shared utility at $path : $($_.Exception.Message)"
        }
    }
}

# If shared utility detection failed, use structure-based detection
if (-not $repoRoot) {
    # Check if we're in a release package structure (modules directly in same directory as script)
    $releaseModulesPath = Join-Path $PSScriptRoot "modules"
    if (Test-Path $releaseModulesPath) {
        # Release package structure: script and modules are in the same directory
        $repoRoot = $PSScriptRoot
        Write-Verbose "Detected release package structure, using script directory as root: $repoRoot"
    } else {
        # Fallback: assume aither-core is at project root level (development structure)
        $repoRoot = Split-Path $PSScriptRoot -Parent
        Write-Verbose "Using development structure fallback detection: $repoRoot"
    }
}

# Ensure we have a valid project root
if (-not $repoRoot -or -not (Test-Path $repoRoot)) {
    Write-Error "Could not determine valid project root. Please run from the project directory or set PROJECT_ROOT environment variable."
    exit 1
}

# Set environment variables with proper cross-platform paths
$env:PROJECT_ROOT = $repoRoot

# Determine modules path based on structure
# In release packages, aither-core.ps1 is at the root alongside modules/
# In development, aither-core.ps1 is in aither-core/ subdirectory
$scriptInRoot = (Split-Path $PSScriptRoot -Leaf) -eq (Split-Path $repoRoot -Leaf)
$releaseModulesPath = Join-Path $PSScriptRoot "modules"
$devModulesPath = Join-Path $repoRoot (Join-Path "aither-core" "modules")

Write-Verbose "Script location: $PSScriptRoot"
Write-Verbose "Repo root: $repoRoot"
Write-Verbose "Script in root: $scriptInRoot"
Write-Verbose "Checking release modules at: $releaseModulesPath"
Write-Verbose "Checking dev modules at: $devModulesPath"

if (Test-Path $releaseModulesPath) {
    # Release package structure: modules are in same directory as script
    $env:PWSH_MODULES_PATH = $releaseModulesPath
    Write-Verbose "Using release package modules path: $env:PWSH_MODULES_PATH"
} elseif (Test-Path $devModulesPath) {
    # Development structure: modules are in aither-core/modules
    $env:PWSH_MODULES_PATH = $devModulesPath  
    Write-Verbose "Using development modules path: $env:PWSH_MODULES_PATH"
} else {
    # Neither found - this is an error
    Write-Error "Could not locate modules directory. Checked:"
    Write-Error "  Release structure: $releaseModulesPath"
    Write-Error "  Development structure: $devModulesPath"
    exit 1
}

Write-Verbose "Repository root: $repoRoot"
Write-Verbose "Modules path: $env:PWSH_MODULES_PATH"

# Validate that the modules directory exists
if (-not (Test-Path $env:PWSH_MODULES_PATH)) {
    Write-Error "Modules directory not found at: $env:PWSH_MODULES_PATH"
    Write-Error "This suggests the project structure is incomplete or the script is not running from the correct location."
    Write-Error "Please ensure all files were extracted properly and run from the project root directory."
    exit 1
}

# Apply default ConfigFile if not provided - try multiple locations
if (-not $PSBoundParameters.ContainsKey('ConfigFile')) {
    # Try multiple configuration file locations based on structure
    $configPaths = @(
        (Join-Path $PSScriptRoot 'default-config.json'),                    # Release: same as script
        (Join-Path $repoRoot "configs" "default-config.json"),             # Standard location
        (Join-Path $PSScriptRoot "configs" "default-config.json"),         # Alternative: relative to script
        (Join-Path $repoRoot "aither-core" "default-config.json")          # Dev fallback
    )
    
    $ConfigFile = $null
    foreach ($configPath in $configPaths) {
        if (Test-Path $configPath) {
            $ConfigFile = $configPath
            Write-Verbose "Found configuration file at: $ConfigFile"
            break
        }
    }
    
    # If no config found, use the standard location (will be created or handled later)
    if (-not $ConfigFile) {
        $ConfigFile = Join-Path $repoRoot "configs" "default-config.json"
        Write-Verbose "No existing config found, will use: $ConfigFile"
    }
}

# Apply quiet flag to verbosity
if ($Quiet) {
    $Verbosity = 'silent'
}

# Map verbosity settings to logging levels
$script:VerbosityToLogLevel = @{
    silent = 'SILENT'   # Suppress all console output in silent mode
    normal = 'WARN'     # Show only WARN and ERROR in normal mode (cleaner user experience)
    detailed = 'DEBUG'  # Show everything including DEBUG in detailed mode
}

$script:VerbosityLevels = @{ silent = 0; normal = 1; detailed = 2 }
$script:ConsoleLevel = $script:VerbosityLevels[$Verbosity]
$script:LogLevel = $script:VerbosityToLogLevel[$Verbosity]

# Determine pwsh executable path for nested script execution
$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) {
    $exeName = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
    $pwshPath = Join-Path $PSHOME $exeName
}

if (-not (Test-Path $pwshPath)) {
    Write-Error 'PowerShell 7 not found. Please install PowerShell 7 or adjust PATH.'
    exit 1
}

# Re-launch under PowerShell 7 if running under Windows PowerShell
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host 'Switching to PowerShell 7...' -ForegroundColor Yellow

    $argList = @()
    foreach ($kvp in $PSBoundParameters.GetEnumerator()) {
        if ($kvp.Value -is [System.Management.Automation.SwitchParameter]) {
            if ($kvp.Value.IsPresent) {
                $argList += "-$($kvp.Key)"
            }
        } else {
            $argList += "-$($kvp.Key)"
            $argList += $kvp.Value
        }
    }

    & $pwshPath -File $PSCommandPath @argList
    exit $LASTEXITCODE
}

# Import required modules
try {
    Write-Verbose 'Importing Logging module...'

    # Validate module paths before attempting import
    $loggingModulePath = Join-Path $env:PWSH_MODULES_PATH "Logging"
    $labRunnerModulePath = Join-Path $env:PWSH_MODULES_PATH "LabRunner"

    if (-not (Test-Path $loggingModulePath)) {
        throw "Logging module not found at: $loggingModulePath"
    }
    if (-not (Test-Path $labRunnerModulePath)) {
        throw "LabRunner module not found at: $labRunnerModulePath"
    }

    # In silent mode, suppress all output during module import and initialization
    if ($Verbosity -eq 'silent') {
        Import-Module $loggingModulePath -Force -ErrorAction Stop *>$null
        Import-Module $labRunnerModulePath -Force -ErrorAction Stop *>$null
        # Initialize logging system with proper verbosity mapping (Force required to override auto-init)
        Initialize-LoggingSystem -ConsoleLevel $script:LogLevel -LogLevel 'DEBUG' -Force *>$null
    } else {
        Import-Module $loggingModulePath -Force -ErrorAction Stop
        Write-Verbose 'Importing LabRunner module...'
        Import-Module $labRunnerModulePath -Force -ErrorAction Stop
        # Initialize logging system with proper verbosity mapping (Force required to override auto-init)
        Initialize-LoggingSystem -ConsoleLevel $script:LogLevel -LogLevel 'DEBUG' -Force
    }

    Write-CustomLog 'Core runner started' -Level DEBUG
} catch {
    Write-Host "❌ Error importing required modules: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "" -ForegroundColor White
    Write-Host "💡 Troubleshooting Steps:" -ForegroundColor Yellow
    Write-Host "  1. Verify project structure is complete" -ForegroundColor White
    Write-Host "  2. Check that modules exist at: $env:PWSH_MODULES_PATH" -ForegroundColor White
    Write-Host "  3. Ensure all files were extracted properly" -ForegroundColor White
    Write-Host "  4. Try running from the project root directory" -ForegroundColor White
    Write-Host "  5. Check PowerShell version: `$PSVersionTable.PSVersion" -ForegroundColor White
    Write-Host "" -ForegroundColor White
    Write-Host "🔍 Current paths:" -ForegroundColor Cyan
    Write-Host "  Project Root: $env:PROJECT_ROOT" -ForegroundColor White
    Write-Host "  Modules Path: $env:PWSH_MODULES_PATH" -ForegroundColor White
    Write-Host "  Script Location: $PSScriptRoot" -ForegroundColor White
    Write-Host "" -ForegroundColor White
    exit 1
}

# Set console verbosity level for LabRunner (maintain compatibility)
$env:LAB_CONSOLE_LEVEL = $script:LogLevel

# Load configuration
try {
    if (Test-Path $ConfigFile) {
        Write-CustomLog "Loading configuration from: $ConfigFile" -Level DEBUG
        $configObject = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        
        # Convert PSCustomObject to Hashtable for proper parameter binding
        # This prevents "Cannot convert PSCustomObject to Hashtable" errors
        if ($configObject -is [PSCustomObject]) {
            $config = @{}
            $configObject.PSObject.Properties | ForEach-Object {
                $config[$_.Name] = $_.Value
            }
            Write-CustomLog "Configuration converted from PSCustomObject to Hashtable" -Level DEBUG
        } else {
            $config = $configObject
        }
    } else {
        Write-CustomLog "Configuration file not found: $ConfigFile" -Level WARN
        Write-CustomLog 'Using default configuration' -Level DEBUG
        $config = @{}
    }
} catch {
    Write-CustomLog "Failed to load configuration: $($_.Exception.Message)" -Level ERROR
    exit 1
}

# Main execution logic
try {
    Write-CustomLog 'Starting Aitherium Infrastructure Automation Core Runner' -Level DEBUG
    Write-CustomLog "Repository root: $repoRoot" -Level DEBUG
    Write-CustomLog "Configuration file: $ConfigFile" -Level DEBUG
    Write-CustomLog "Verbosity level: $Verbosity" -Level DEBUG

    # Load dynamic menu system
    $dynamicMenuPath = Join-Path $PSScriptRoot 'shared' 'Show-DynamicMenu.ps1'
    if (-not (Test-Path $dynamicMenuPath)) {
        $dynamicMenuPath = Join-Path $repoRoot 'aither-core' 'shared' 'Show-DynamicMenu.ps1'
    }
    
    if (Test-Path $dynamicMenuPath) {
        Write-CustomLog "Loading dynamic menu system from: $dynamicMenuPath" -Level DEBUG
        . $dynamicMenuPath
    }
    
    # Check for StartupExperience module availability
    $startupExperienceAvailable = $false
    $startupExperiencePath = Join-Path $env:PWSH_MODULES_PATH 'StartupExperience'
    
    if (Test-Path $startupExperiencePath) {
        try {
            Import-Module $startupExperiencePath -Force -ErrorAction Stop
            $startupExperienceAvailable = $true
            Write-CustomLog "StartupExperience module loaded successfully" -Level DEBUG
        } catch {
            Write-CustomLog "Failed to load StartupExperience module: $_" -Level WARN
        }
    }
    
    # Check config for UI preferences if not explicitly set
    if ($UIMode -eq 'auto' -and $config.UIPreferences) {
        $configUIMode = $config.UIPreferences.Mode
        if ($configUIMode -and $configUIMode -ne 'auto') {
            $UIMode = $configUIMode
            Write-CustomLog "Using UI mode from configuration: $UIMode" -Level DEBUG
        }
    }
    
    # Determine which UI to use based on availability and preference
    $useEnhancedUI = $false
    
    if ($UIMode -eq 'enhanced') {
        if ($startupExperienceAvailable) {
            $useEnhancedUI = $true
        } else {
            Write-CustomLog "Enhanced UI requested but StartupExperience module not available. Falling back to classic menu." -Level WARN
            Write-Host "⚠️  Enhanced UI not available. Using classic menu instead." -ForegroundColor Yellow
        }
    } elseif ($UIMode -eq 'classic') {
        # Explicitly requested classic UI
        $useEnhancedUI = $false
    } elseif ($UIMode -eq 'auto') {
        # Auto mode - check config preference
        $defaultUI = if ($config.UIPreferences.DefaultUI) { $config.UIPreferences.DefaultUI } else { 'enhanced' }
        
        # Use enhanced if available and we're in interactive mode
        if ($startupExperienceAvailable -and -not $NonInteractive -and -not $Auto -and -not $Scripts) {
            $useEnhancedUI = ($defaultUI -eq 'enhanced')
            Write-CustomLog "Auto mode: Using $($useEnhancedUI ? 'enhanced' : 'classic') UI based on config preference" -Level DEBUG
        }
    }

    # Handle different execution modes
    if ($Setup) {
        # Run setup wizard
        Write-CustomLog "Running setup wizard with profile: $InstallationProfile" -Level INFO
        
        $setupWizardPath = Join-Path $env:PWSH_MODULES_PATH 'SetupWizard'
        if (Test-Path $setupWizardPath) {
            try {
                Import-Module $setupWizardPath -Force
                if ($InstallationProfile -eq 'interactive') {
                    $result = Start-IntelligentSetup
                } else {
                    $result = Start-IntelligentSetup -InstallationProfile $InstallationProfile
                }
                Write-Host "✓ Setup completed successfully" -ForegroundColor Green
            } catch {
                Write-CustomLog "Error running setup wizard: $_" -Level ERROR
                throw
            }
        } else {
            Write-Error "SetupWizard module not found at: $setupWizardPath"
            exit 1
        }
        return
    } elseif ($Scripts) {
        # Run specific modules/scripts
        Write-CustomLog "Running specific components: $Scripts" -Level INFO
        
        $componentList = $Scripts -split ','
        foreach ($componentName in $componentList) {
            $componentName = $componentName.Trim()
            
            # Try to find and run as module first
            $modulePath = Join-Path $env:PWSH_MODULES_PATH $componentName
            if (Test-Path $modulePath) {
                Write-CustomLog "Loading module: $componentName" -Level INFO
                try {
                    Import-Module $modulePath -Force
                    Write-Host "✓ Module loaded: $componentName" -ForegroundColor Green
                    
                    # Try to run default function if exists
                    $defaultFunction = "Start-$componentName"
                    if (Get-Command $defaultFunction -ErrorAction SilentlyContinue) {
                        Write-Host "Executing: $defaultFunction" -ForegroundColor Cyan
                        & $defaultFunction
                    } else {
                        Write-Host "Module loaded. Use Get-Command -Module $componentName to see available functions." -ForegroundColor Yellow
                    }
                } catch {
                    Write-CustomLog "Error loading module $componentName : $_" -Level ERROR
                }
            } else {
                # Fallback to legacy script execution
                $scriptsPaths = @(
                    (Join-Path $PSScriptRoot 'scripts'),
                    (Join-Path $repoRoot "aither-core" "scripts"),
                    (Join-Path $repoRoot "scripts")
                )
                
                $scriptFound = $false
                foreach ($scriptsPath in $scriptsPaths) {
                    $scriptPath = Join-Path $scriptsPath "$componentName.ps1"
                    if (Test-Path $scriptPath) {
                        Write-CustomLog "Executing script: $componentName" -Level INFO
                        if ($PSCmdlet.ShouldProcess($componentName, 'Execute script')) {
                            Invoke-ScriptWithOutputHandling -ScriptName $componentName -ScriptPath $scriptPath -Config $config -Force:$Force -Verbosity $Verbosity
                        }
                        $scriptFound = $true
                        break
                    }
                }
                
                if (-not $scriptFound) {
                    Write-CustomLog "Component not found: $componentName" -Level WARN
                }
            }
        }
    } elseif ($Auto) {
        # Auto mode - run all default operations
        Write-CustomLog 'Running in automatic mode' -Level INFO
        
        # Define default auto-mode modules
        $autoModules = @('SetupWizard', 'SystemMonitoring', 'BackupManager')
        
        foreach ($moduleName in $autoModules) {
            $modulePath = Join-Path $env:PWSH_MODULES_PATH $moduleName
            if (Test-Path $modulePath) {
                try {
                    Import-Module $modulePath -Force
                    $defaultFunction = "Start-$moduleName"
                    if (Get-Command $defaultFunction -ErrorAction SilentlyContinue) {
                        Write-Host "Auto-executing: $defaultFunction" -ForegroundColor Cyan
                        & $defaultFunction -Auto
                    }
                } catch {
                    Write-CustomLog "Error in auto mode for $moduleName : $_" -Level WARN
                }
            }
        }
    } else {
        # Check if running in non-interactive mode
        if ($NonInteractive -or $PSCmdlet.WhatIf) {
            Write-CustomLog 'Non-interactive mode: use -Scripts parameter to specify components, or -Auto for automatic mode' -Level INFO
            Write-CustomLog 'Available options:' -Level INFO
            Write-CustomLog '  -Scripts "LabRunner,BackupManager" : Run specific modules' -Level INFO
            Write-CustomLog '  -Auto : Run default automated tasks' -Level INFO
        } else {
            # Interactive mode - choose UI based on availability and preference
            if ($useEnhancedUI) {
                Write-CustomLog 'Starting enhanced interactive mode with StartupExperience' -Level INFO
                
                try {
                    # Use enhanced startup experience
                    $startupParams = @{}
                    
                    # Pass configuration if available
                    if ($ConfigFile -and (Test-Path $ConfigFile)) {
                        $profileName = [System.IO.Path]::GetFileNameWithoutExtension($ConfigFile)
                        $startupParams['Profile'] = $profileName
                    }
                    
                    # Start enhanced interactive mode
                    Start-InteractiveMode @startupParams
                    
                } catch {
                    Write-CustomLog "Enhanced UI failed: $_. Falling back to classic menu." -Level WARN
                    Write-Host "⚠️  Enhanced UI encountered an error. Switching to classic menu..." -ForegroundColor Yellow
                    $useEnhancedUI = $false
                }
            }
            
            # If not using enhanced UI or if it failed, use classic menu
            if (-not $useEnhancedUI) {
                Write-CustomLog 'Starting interactive mode with classic dynamic menu' -Level INFO
                
                # Check if this is first run
                $firstRunFile = Join-Path $env:APPDATA 'AitherZero' '.firstrun'
                $isFirstRun = -not (Test-Path $firstRunFile)
                
                if ($isFirstRun) {
                    # Create first run marker
                    $firstRunDir = Split-Path $firstRunFile -Parent
                    if (-not (Test-Path $firstRunDir)) {
                        New-Item -ItemType Directory -Path $firstRunDir -Force | Out-Null
                    }
                    New-Item -ItemType File -Path $firstRunFile -Force | Out-Null
                }
                
                # Show dynamic menu
                if (Get-Command Show-DynamicMenu -ErrorAction SilentlyContinue) {
                    Show-DynamicMenu -Title "Infrastructure Automation Platform" -Config $config -FirstRun:$isFirstRun
                } else {
                    Write-CustomLog 'Dynamic menu system not available, falling back to basic menu' -Level WARN
                    
                    # Fallback basic menu
                    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
                    Write-Host " AitherZero - Infrastructure Automation" -ForegroundColor Cyan
                    Write-Host "=" * 60 -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Dynamic menu system not loaded." -ForegroundColor Yellow
                    Write-Host "Try running with -Scripts or -Auto parameter." -ForegroundColor Yellow
                    Write-Host ""
                }
            }
        }
    }

    # Generate summary of scripts with no output issues
    if ($script:NoOutputScripts -and $script:NoOutputScripts.Count -gt 0) {
        Write-Host ""
        Write-Host "=" * 80 -ForegroundColor Yellow
        Write-Host "📊 NO OUTPUT DETECTION SUMMARY" -ForegroundColor Yellow
        Write-Host "=" * 80 -ForegroundColor Yellow
        Write-Host ""
        Write-Host "The following scripts completed successfully but produced no visible output:" -ForegroundColor Yellow
        Write-Host ""

        foreach ($scriptInfo in $script:NoOutputScripts) {
            Write-Host "• $($scriptInfo.ScriptName) (verbosity: $($scriptInfo.Verbosity))" -ForegroundColor Cyan
        }

        Write-Host ""
        Write-Host "💡 Suggestions:" -ForegroundColor Cyan
        Write-Host "  1. Run with '-Verbosity detailed' to see more information" -ForegroundColor White
        Write-Host "  2. Consider enhancing these scripts to provide user-friendly output" -ForegroundColor White
        Write-Host "  3. Use PatchManager to track and improve script output" -ForegroundColor White
        Write-Host ""
        Write-Host "=" * 80 -ForegroundColor Yellow

        # Save summary to logs for potential automation
        $summaryPath = Join-Path $repoRoot "logs" "no-output-scripts-$(Get-Date -Format 'yyyy-MM-dd-HHmm').json"
        $script:NoOutputScripts | ConvertTo-Json -Depth 3 | Out-File -FilePath $summaryPath -Encoding UTF8
        Write-CustomLog "No-output scripts summary saved to: $summaryPath" -Level INFO

        # Optionally auto-create PatchManager issue for tracking (only in detailed mode to avoid spam)
        if ($Verbosity -eq 'detailed' -and -not $NonInteractive) {
            try {
                Import-Module (Join-Path $repoRoot "aither-core" "modules" "PatchManager") -Force -ErrorAction SilentlyContinue
                if (Get-Command New-PatchIssue -ErrorAction SilentlyContinue) {
                    $issueDescription = "Scripts with no visible output detected: $($script:NoOutputScripts.ScriptName -join ', ')"
                    $affectedFiles = $script:NoOutputScripts.ScriptPath
                    Write-Host "🔧 Creating PatchManager issue to track output improvements..." -ForegroundColor Green
                    New-PatchIssue -Description $issueDescription -Priority "Low" -AffectedFiles $affectedFiles -Labels @("enhancement", "user-experience", "output-improvement")
                }
            } catch {
                Write-CustomLog "Could not create PatchManager issue: $($_.Exception.Message)" -Level WARN
            }
        }
    }

    Write-CustomLog 'Core runner completed successfully' -Level DEBUG
    exit 0  # Explicitly set success exit code

} catch {
    Write-CustomLog "Core runner failed: $($_.Exception.Message)" -Level ERROR
    Write-CustomLog "Stack trace: $($_.ScriptStackTrace)" -Level INFO
    exit 1
}
