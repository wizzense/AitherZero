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

# Backward compatibility and unified initialization functions
function Initialize-BackwardCompatibilityLayer {
    [CmdletBinding()]
    param()

    # Use Write-CustomLog only if available, otherwise use Write-Verbose
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog "Initializing backward compatibility layer..." -Level DEBUG
    } else {
        Write-Verbose "Initializing backward compatibility layer..."
    }

    # Ensure legacy module aliases are available
    $legacyModuleAliases = @{
        'CoreApp' = 'LabRunner'
        'CoreApplication' = 'LabRunner'
        'InfrastructureProvider' = 'OpenTofuProvider'
        'CredentialManager' = 'SecureCredentials'
        'ConnectionManager' = 'RemoteConnection'
        'EnvironmentManager' = 'DevEnvironment'
        'MaintenanceManager' = 'UnifiedMaintenance'
        'ScriptExecutor' = 'ScriptManager'
        'TestRunner' = 'TestingFramework'
    }

    # Create backward compatibility aliases
    foreach ($alias in $legacyModuleAliases.GetEnumerator()) {
        try {
            if (Get-Module -Name $alias.Value -ErrorAction SilentlyContinue) {
                # Create alias for the module
                $script:BackwardCompatibilityAliases = $script:BackwardCompatibilityAliases ?? @{}
                $script:BackwardCompatibilityAliases[$alias.Key] = $alias.Value
                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                    Write-CustomLog "Created backward compatibility alias: $($alias.Key) -> $($alias.Value)" -Level DEBUG
                } else {
                    Write-Verbose "Created backward compatibility alias: $($alias.Key) -> $($alias.Value)"
                }
            }
        } catch {
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog "Warning: Could not create backward compatibility alias $($alias.Key): $_" -Level WARN
            } else {
                Write-Warning "Could not create backward compatibility alias $($alias.Key): $_"
            }
        }
    }

    # Initialize legacy function mappings
    Initialize-LegacyFunctionMappings

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog "Backward compatibility layer initialized successfully" -Level DEBUG
    } else {
        Write-Verbose "Backward compatibility layer initialized successfully"
    }
}

function Initialize-LegacyFunctionMappings {
    [CmdletBinding()]
    param()

    # Map legacy function names to new consolidated functions
    $legacyFunctionMappings = @{
        'Start-CoreApplication' = 'Start-LabRunner'
        'Invoke-CoreApplication' = 'Invoke-LabRunner'
        'Initialize-CoreApplication' = 'Initialize-LabRunner'
        'Get-CoreApplicationStatus' = 'Get-LabRunnerStatus'
        'Test-CoreApplicationHealth' = 'Test-LabRunnerHealth'
        'Start-InfrastructureDeployment' = 'Start-OpenTofuDeployment'
        'Get-InfrastructureStatus' = 'Get-OpenTofuStatus'
        'Start-CredentialManagement' = 'Start-SecureCredentials'
        'Get-CredentialStatus' = 'Get-SecureCredentialStatus'
    }

    foreach ($mapping in $legacyFunctionMappings.GetEnumerator()) {
        try {
            # Check if the new function exists
            if (Get-Command $mapping.Value -ErrorAction SilentlyContinue) {
                # Create a wrapper function for backward compatibility
                $wrapperScript = @"
function $($mapping.Key) {
    [CmdletBinding()]
    param()

    Write-CustomLog "Legacy function $($mapping.Key) called - redirecting to $($mapping.Value)" -Level WARN
    Write-Warning "Function $($mapping.Key) is deprecated. Use $($mapping.Value) instead."

    # Forward all parameters to the new function
    & $($mapping.Value) @PSBoundParameters
}
"@
                Invoke-Expression $wrapperScript
                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                    Write-CustomLog "Created legacy function wrapper: $($mapping.Key) -> $($mapping.Value)" -Level DEBUG
                } else {
                    Write-Verbose "Created legacy function wrapper: $($mapping.Key) -> $($mapping.Value)"
                }
            }
        } catch {
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog "Warning: Could not create legacy function mapping $($mapping.Key): $_" -Level WARN
            } else {
                Write-Warning "Could not create legacy function mapping $($mapping.Key): $_"
            }
        }
    }
}

function Initialize-ModuleStatusTracking {
    [CmdletBinding()]
    param()

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog "Initializing unified module status tracking..." -Level DEBUG
    } else {
        Write-Verbose "Initializing unified module status tracking..."
    }

    # Initialize module status registry
    $script:ModuleStatusRegistry = @{
        CoreModules = @{}
        ConsolidatedModules = @{}
        LoadingStats = $script:ModuleLoadingStats
        LastUpdate = Get-Date
    }

    # Populate core module status
    foreach ($moduleName in $coreModules) {
        $moduleInfo = Get-Module -Name $moduleName -ErrorAction SilentlyContinue
        $script:ModuleStatusRegistry.CoreModules[$moduleName] = @{
            Name = $moduleName
            Loaded = $null -ne $moduleInfo
            Version = if ($moduleInfo) { $moduleInfo.Version.ToString() } else { 'Not Loaded' }
            Path = if ($moduleInfo) { $moduleInfo.Path } else { 'Unknown' }
            Functions = if ($moduleInfo) { $moduleInfo.ExportedFunctions.Keys } else { @() }
            Required = $true
            Category = 'Core'
        }
    }

    # Populate consolidated module status
    foreach ($moduleName in $consolidatedModules) {
        $moduleInfo = Get-Module -Name $moduleName -ErrorAction SilentlyContinue
        $script:ModuleStatusRegistry.ConsolidatedModules[$moduleName] = @{
            Name = $moduleName
            Loaded = $null -ne $moduleInfo
            Version = if ($moduleInfo) { $moduleInfo.Version.ToString() } else { 'Not Loaded' }
            Path = if ($moduleInfo) { $moduleInfo.Path } else { 'Unknown' }
            Functions = if ($moduleInfo) { $moduleInfo.ExportedFunctions.Keys } else { @() }
            Required = $false
            Category = 'Consolidated'
        }
    }

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog "Module status tracking initialized for $($script:ModuleStatusRegistry.CoreModules.Count + $script:ModuleStatusRegistry.ConsolidatedModules.Count) modules" -Level DEBUG
    } else {
        Write-Verbose "Module status tracking initialized for $($script:ModuleStatusRegistry.CoreModules.Count + $script:ModuleStatusRegistry.ConsolidatedModules.Count) modules"
    }
}

function Get-ConsolidatedModuleStatus {
    [CmdletBinding()]
    param(
        [string]$ModuleName,
        [switch]$Detailed
    )

    if (-not $script:ModuleStatusRegistry) {
        Write-Warning "Module status tracking not initialized"
        return
    }

    # Update registry with current state
    $script:ModuleStatusRegistry.LastUpdate = Get-Date

    if ($ModuleName) {
        # Return specific module status
        $moduleStatus = $script:ModuleStatusRegistry.CoreModules[$ModuleName] ??
                       $script:ModuleStatusRegistry.ConsolidatedModules[$ModuleName]

        if ($moduleStatus) {
            if ($Detailed) {
                return $moduleStatus
            } else {
                return [PSCustomObject]@{
                    Name = $moduleStatus.Name
                    Loaded = $moduleStatus.Loaded
                    Version = $moduleStatus.Version
                    Category = $moduleStatus.Category
                    Required = $moduleStatus.Required
                }
            }
        } else {
            Write-Warning "Module '$ModuleName' not found in registry"
            return $null
        }
    } else {
        # Return all module statuses
        $allModules = @()

        foreach ($module in $script:ModuleStatusRegistry.CoreModules.Values) {
            $allModules += if ($Detailed) { $module } else {
                [PSCustomObject]@{
                    Name = $module.Name
                    Loaded = $module.Loaded
                    Version = $module.Version
                    Category = $module.Category
                    Required = $module.Required
                }
            }
        }

        foreach ($module in $script:ModuleStatusRegistry.ConsolidatedModules.Values) {
            $allModules += if ($Detailed) { $module } else {
                [PSCustomObject]@{
                    Name = $module.Name
                    Loaded = $module.Loaded
                    Version = $module.Version
                    Category = $module.Category
                    Required = $module.Required
                }
            }
        }

        return $allModules
    }
}

function Show-ModuleLoadingSummary {
    [CmdletBinding()]
    param()

    if (-not $script:ModuleLoadingStats) {
        Write-Warning "Module loading statistics not available"
        return
    }

    $stats = $script:ModuleLoadingStats
    $totalModules = $stats.CoreModules.Total + $stats.ConsolidatedModules.Total
    $totalLoaded = $stats.CoreModules.Loaded + $stats.ConsolidatedModules.Loaded
    $totalFailed = $stats.CoreModules.Failed + $stats.ConsolidatedModules.Failed

    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host " AitherZero Module Loading Summary" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host ""

    Write-Host "📊 Overall Statistics:" -ForegroundColor Yellow
    Write-Host "   Total Modules: $totalModules" -ForegroundColor White
    Write-Host "   Successfully Loaded: $totalLoaded" -ForegroundColor Green
    Write-Host "   Failed to Load: $totalFailed" -ForegroundColor Red
    Write-Host "   Success Rate: $([math]::Round(($totalLoaded / $totalModules) * 100, 1))%" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "🔧 Core Infrastructure Modules:" -ForegroundColor Yellow
    Write-Host "   Loaded: $($stats.CoreModules.Loaded)/$($stats.CoreModules.Total)" -ForegroundColor White
    Write-Host "   Status: $(if ($stats.CoreModules.Failed -eq 0) { 'All Critical Modules Loaded' } else { 'Some Core Modules Failed' })" -ForegroundColor $(if ($stats.CoreModules.Failed -eq 0) { 'Green' } else { 'Red' })
    Write-Host ""

    Write-Host "🚀 Consolidated Feature Modules:" -ForegroundColor Yellow
    Write-Host "   Loaded: $($stats.ConsolidatedModules.Loaded)/$($stats.ConsolidatedModules.Total)" -ForegroundColor White
    Write-Host "   Status: $(if ($stats.ConsolidatedModules.Loaded -gt 0) { 'Feature Modules Available' } else { 'No Feature Modules Loaded' })" -ForegroundColor $(if ($stats.ConsolidatedModules.Loaded -gt 0) { 'Green' } else { 'Yellow' })
    Write-Host ""

    if ($stats.CoreModules.Failed -gt 0 -or $stats.ConsolidatedModules.Failed -gt 0) {
        Write-Host "⚠️  Module Loading Issues:" -ForegroundColor Red
        Write-Host "   Some modules failed to load. Run with -Verbosity detailed for more information." -ForegroundColor Yellow
        Write-Host "   Use Get-ConsolidatedModuleStatus -Detailed to see specific module details." -ForegroundColor Yellow
        Write-Host ""
    }

    Write-Host "=" * 70 -ForegroundColor Cyan
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

# Import PowerShell version checking utility
$versionCheckPath = Join-Path (Split-Path $PSScriptRoot -Parent) "aither-core/shared/Test-PowerShellVersion.ps1"
if (Test-Path $versionCheckPath) {
    . $versionCheckPath
} else {
    # Fallback if utility not found
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Host 'AitherZero requires PowerShell 7.0 or later.' -ForegroundColor Yellow
        Write-Host "Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
        exit 1
    }
}

# Check PowerShell version
if (-not (Test-PowerShellVersion -MinimumVersion "7.0" -Quiet)) {
    Write-Host 'AitherZero Core requires PowerShell 7.0 or later.' -ForegroundColor Yellow
    # Note: Start-AitherZero.ps1 handles the relaunch, so we just exit here
    exit 1
}

# Import progress indicator utilities
$progressPath = Join-Path $PSScriptRoot "shared/Show-Progress.ps1"
if (Test-Path $progressPath) {
    . $progressPath
}

# Import required modules
try {
    Write-Verbose 'Importing core modules...'

    # Show startup progress if not in quiet mode
    if (-not $Quiet -and $Verbosity -ne 'silent') {
        Show-SimpleProgress -Message "Starting AitherZero Infrastructure Automation" -Type Start
    }

    # Standardized Module Loading Architecture
    # Uses AitherCore.psm1 orchestration approach for consistency and reliability

    Write-Verbose "Initializing standardized module loading architecture..."

    # Import AitherCore orchestration module
    $aitherCorePath = Join-Path $PSScriptRoot "AitherCore.psm1"
    if (Test-Path $aitherCorePath) {
        try {
            Write-Verbose "Loading AitherCore orchestration module..."
            Import-Module $aitherCorePath -Force -Global -ErrorAction Stop

            # Verify Write-CustomLog is available after AitherCore import
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message "AitherCore module loaded successfully - Write-CustomLog available" -Level SUCCESS
            } else {
                Write-Warning "Write-CustomLog not available after AitherCore import"
            }

            # Initialize the complete CoreApp ecosystem with parallel loading
            Write-Verbose "Initializing CoreApp ecosystem with parallel module loading..."
            $initResult = Initialize-CoreApplication -RequiredOnly:$false

            if ($initResult) {
                Write-Verbose "AitherCore ecosystem initialized successfully"
                $moduleLoadingSuccess = $true
            } else {
                Write-Warning "AitherCore initialization completed with issues"
                $moduleLoadingSuccess = $false
            }
        } catch {
            Write-Error "Failed to load AitherCore orchestration module: $_"
            $moduleLoadingSuccess = $false
        }
    } else {
        Write-Error "AitherCore.psm1 not found at: $aitherCorePath"
        $moduleLoadingSuccess = $false
    }

    # Report module loading results
    if ($moduleLoadingSuccess) {
        # Get module status from AitherCore orchestration
        if (Get-Command Get-CoreModuleStatus -ErrorAction SilentlyContinue) {
            $moduleStatus = Get-CoreModuleStatus
            $loadedCount = ($moduleStatus | Where-Object { $_.Loaded }).Count
            $availableCount = ($moduleStatus | Where-Object { $_.Available }).Count

            Write-Verbose "Standardized module loading completed successfully"
            Write-Verbose "Modules loaded: $loadedCount/$availableCount available"

            # Store module loading statistics for later use (compatible format)
            $script:ModuleLoadingStats = @{
                CoreModules = @{
                    Total = ($moduleStatus | Where-Object { $_.Required }).Count
                    Loaded = ($moduleStatus | Where-Object { $_.Required -and $_.Loaded }).Count
                    Failed = ($moduleStatus | Where-Object { $_.Required -and (-not $_.Loaded) }).Count
                }
                ConsolidatedModules = @{
                    Total = ($moduleStatus | Where-Object { -not $_.Required }).Count
                    Loaded = ($moduleStatus | Where-Object { -not $_.Required -and $_.Loaded }).Count
                    Failed = ($moduleStatus | Where-Object { -not $_.Required -and (-not $_.Loaded) }).Count
                }
                StartTime = Get-Date
            }
        } else {
            Write-Warning "Get-CoreModuleStatus function not available. Module status reporting limited."
            $script:ModuleLoadingStats = @{
                CoreModules = @{ Total = 0; Loaded = 0; Failed = 0 }
                ConsolidatedModules = @{ Total = 0; Loaded = 0; Failed = 0 }
                StartTime = Get-Date
            }
        }
    } else {
        Write-Warning "Module loading failed or completed with issues"
        $script:ModuleLoadingStats = @{
            CoreModules = @{ Total = 0; Loaded = 0; Failed = 1 }
            ConsolidatedModules = @{ Total = 0; Loaded = 0; Failed = 0 }
            StartTime = Get-Date
        }
    }

    # Initialize logging system with proper verbosity mapping (Force required to override auto-init)
    if (Get-Command Initialize-LoggingSystem -ErrorAction SilentlyContinue) {
        if ($Verbosity -eq 'silent') {
            Initialize-LoggingSystem -ConsoleLevel $script:LogLevel -LogLevel 'DEBUG' -Force *>$null
        } else {
            Initialize-LoggingSystem -ConsoleLevel $script:LogLevel -LogLevel 'DEBUG' -Force
        }
    } else {
        Write-Warning "Initialize-LoggingSystem function not available. Logging module may not have loaded properly."
    }

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog 'Core runner started with consolidated module architecture' -Level INFO
    } else {
        Write-Host "✓ Core runner started with consolidated module architecture" -ForegroundColor Green
    }

    # Initialize backward compatibility layer
    Initialize-BackwardCompatibilityLayer

    # Initialize unified module status tracking
    Initialize-ModuleStatusTracking

    # Show module loading summary if verbosity allows
    if ($Verbosity -in @('normal', 'detailed') -and -not $NonInteractive) {
        Show-ModuleLoadingSummary
    }
} catch {
    Write-Host "❌ Error initializing consolidated module architecture: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "" -ForegroundColor White
    Write-Host "💡 Troubleshooting Steps for Consolidated Modules:" -ForegroundColor Yellow
    Write-Host "  1. Verify project structure is complete" -ForegroundColor White
    Write-Host "  2. Check that modules exist at: $env:PWSH_MODULES_PATH" -ForegroundColor White
    Write-Host "  3. Ensure all consolidated modules are properly structured" -ForegroundColor White
    Write-Host "  4. Try running from the project root directory" -ForegroundColor White
    Write-Host "  5. Check PowerShell version: `$PSVersionTable.PSVersion" -ForegroundColor White
    Write-Host "  6. Run Get-ConsolidatedModuleStatus for detailed module information" -ForegroundColor White
    Write-Host "" -ForegroundColor White
    Write-Host "🔍 Current paths:" -ForegroundColor Cyan
    Write-Host "  Project Root: $env:PROJECT_ROOT" -ForegroundColor White
    Write-Host "  Modules Path: $env:PWSH_MODULES_PATH" -ForegroundColor White
    Write-Host "  Script Location: $PSScriptRoot" -ForegroundColor White
    Write-Host "" -ForegroundColor White
    Write-Host "🔧 Recovery Options:" -ForegroundColor Yellow
    Write-Host "  • Run with -Verbosity detailed for more information" -ForegroundColor White
    Write-Host "  • Use individual module imports as fallback" -ForegroundColor White
    Write-Host "  • Check logs for specific module loading failures" -ForegroundColor White
    Write-Host "" -ForegroundColor White

    # Try to show partial module loading statistics if available
    if ($script:ModuleLoadingStats) {
        Write-Host "📊 Partial Loading Statistics:" -ForegroundColor Cyan
        Write-Host "  Core Modules Loaded: $($script:ModuleLoadingStats.CoreModules.Loaded)" -ForegroundColor White
        Write-Host "  Consolidated Modules Loaded: $($script:ModuleLoadingStats.ConsolidatedModules.Loaded)" -ForegroundColor White
    }

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

                # Build setup parameters
                $setupParams = @{}
                if ($InstallationProfile -ne 'interactive') {
                    $setupParams['InstallationProfile'] = $InstallationProfile
                }
                if ($NonInteractive) {
                    $setupParams['SkipOptional'] = $true
                    # Set environment variable for child processes
                    $env:NO_PROMPT = 'true'
                }

                $result = Start-IntelligentSetup @setupParams
                Write-Host "✓ Setup completed successfully" -ForegroundColor Green

                # Show clear next steps
                Write-Host ""
                Write-Host "🚀 SETUP COMPLETE! HERE'S HOW TO USE AITHERZERO:" -ForegroundColor Green
                Write-Host "=" * 60 -ForegroundColor Green
                Write-Host ""
                Write-Host "OPTION 1 - Interactive Mode (Recommended):" -ForegroundColor Cyan
                Write-Host "  ./Start-AitherZero.ps1" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "OPTION 2 - Run Specific Modules:" -ForegroundColor Cyan
                Write-Host "  ./Start-AitherZero.ps1 -Scripts 'LabRunner'" -ForegroundColor Yellow
                Write-Host "  ./Start-AitherZero.ps1 -Scripts 'BackupManager,OpenTofuProvider'" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "OPTION 3 - Automated Mode:" -ForegroundColor Cyan
                Write-Host "  ./Start-AitherZero.ps1 -Auto" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "=" * 60 -ForegroundColor Green

                # After setup, if non-interactive, launch into auto mode
                if ($NonInteractive) {
                    Write-CustomLog "Non-interactive setup complete, launching application in auto mode" -Level INFO
                    $Auto = $true
                } else {
                    # Ask if user wants to launch now
                    Write-Host ""
                    $launch = Read-Host "Would you like to launch AitherZero now? [Y/n]"
                    if ([string]::IsNullOrWhiteSpace($launch) -or $launch -match '^[Yy]') {
                        Write-Host ""
                        Write-Host "Launching AitherZero..." -ForegroundColor Cyan
                        Write-Host ""
                        # Don't return - continue to interactive mode
                    } else {
                        Write-Host ""
                        Write-Host "To launch AitherZero later, run: ./Start-AitherZero.ps1" -ForegroundColor Yellow
                        return
                    }
                }
            } catch {
                Write-CustomLog "Error running setup wizard: $_" -Level ERROR
                throw
            }
        } else {
            Write-Error "SetupWizard module not found at: $setupWizardPath"
            exit 1
        }

        # If we didn't return above, continue to launch the app
        if (-not $Auto -and -not $Scripts -and -not $NonInteractive) {
            # Fall through to interactive mode
        } else {
            return
        }
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
                    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
                    if ($_.Exception.InnerException) {
                        Write-Host "Inner error: $($_.Exception.InnerException.Message)" -ForegroundColor Red
                    }
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
