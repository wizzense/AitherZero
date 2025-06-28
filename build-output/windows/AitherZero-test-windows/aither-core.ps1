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
    [switch]$Help
)

# Set up environment
$ErrorActionPreference = 'Stop'

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
    Write-Host "  -Help           Show this help information"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\aither-core.ps1"
    Write-Host "  .\aither-core.ps1 -Verbosity detailed -Auto"
    Write-Host "  .\aither-core.ps1 -ConfigFile custom.json -Scripts LabRunner"
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
        $Config,

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
$releaseModulesPath = Join-Path $repoRoot "modules"
$devModulesPath = Join-Path $repoRoot (Join-Path "aither-core" "modules")

if (Test-Path $releaseModulesPath) {
    # Release package structure: modules are directly in the root
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
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
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

    # Get available scripts - try multiple locations
    $scriptsPaths = @(
        (Join-Path $PSScriptRoot 'scripts'),                    # Release: same as script
        (Join-Path $repoRoot "aither-core" "scripts"),         # Dev: aither-core/scripts
        (Join-Path $repoRoot "scripts")                        # Alternative: root/scripts
    )
    
    $scriptsPath = $null
    $availableScripts = @()
    
    foreach ($path in $scriptsPaths) {
        if (Test-Path $path) {
            $scriptsPath = $path
            $availableScripts = Get-ChildItem -Path $scriptsPath -Filter '*.ps1' | Sort-Object Name
            Write-CustomLog "Found $($availableScripts.Count) scripts in: $scriptsPath" -Level DEBUG
            break
        }
    }
    
    if ($scriptsPath -and $availableScripts.Count -gt 0) {

        if ($Scripts) {
            # Run specific scripts
            $scriptList = $Scripts -split ','
            foreach ($scriptName in $scriptList) {
                $scriptPath = Join-Path $scriptsPath "$scriptName.ps1"
                if (Test-Path $scriptPath) {
                    Write-CustomLog "Executing script: $scriptName" -Level DEBUG
                    if ($PSCmdlet.ShouldProcess($scriptName, 'Execute script')) {
                        Invoke-ScriptWithOutputHandling -ScriptName $scriptName -ScriptPath $scriptPath -Config $config -Force:$Force -Verbosity $Verbosity
                    }
                } else {
                    Write-CustomLog "Script not found: $scriptName" -Level WARN
                }
            }
        } elseif ($Auto) {
            # Run all scripts in auto mode
            Write-CustomLog 'Running all scripts in automatic mode' -Level INFO
            foreach ($script in $availableScripts) {
                Write-CustomLog "Executing script: $($script.BaseName)" -Level INFO
                if ($PSCmdlet.ShouldProcess($script.BaseName, 'Execute script')) {
                    Invoke-ScriptWithOutputHandling -ScriptName $script.BaseName -ScriptPath $script.FullName -Config $config -Force:$Force -Verbosity $Verbosity
                }
            }
        } else {
            # Check if running in non-interactive mode without specific scripts
            if ($NonInteractive -or $PSCmdlet.WhatIf) {
                Write-CustomLog 'Non-interactive mode: use -Scripts parameter to specify which scripts to run, or -Auto for all scripts' -Level INFO

                # In non-interactive mode, if no scripts specified but Auto is enabled, run all scripts
                if ($Auto) {
                    Write-CustomLog 'Non-interactive auto mode: Running all scripts automatically' -Level INFO
                    foreach ($script in $availableScripts) {
                        Write-CustomLog "Executing script: $($script.BaseName)" -Level INFO
                        if ($PSCmdlet.ShouldProcess($script.BaseName, 'Execute script')) {
                            Invoke-ScriptWithOutputHandling -ScriptName $script.BaseName -ScriptPath $script.FullName -Config $config -Force:$Force -Verbosity $Verbosity
                        }
                    }                } else {
                    Write-CustomLog 'No scripts specified for non-interactive execution' -Level WARN
                    Write-CustomLog 'Consider using -Auto to run all scripts, or -Scripts to specify particular scripts' -Level INFO
                }
                # Don't use return here - let the script complete naturally to reach success logging
            } else {
                # Interactive mode - show menu in a loop
                do {
                    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
                    Write-Host "     _    _ _   _               _                 " -ForegroundColor Cyan
                    Write-Host "    / \  (_) |_| |__   ___ _ __(_)_   _ _ __ ___  " -ForegroundColor Cyan
                    Write-Host "   / _ \ | | __| '_ \ / _ \ '__| | | | | '_ \` _ \ " -ForegroundColor Cyan
                    Write-Host "  / ___ \| | |_| | | |  __/ |  | | |_| | | | | | |" -ForegroundColor Cyan
                    Write-Host " /_/   \_\_|\__|_| |_|\___|_|  |_|\__,_|_| |_| |_|" -ForegroundColor Cyan
                    Write-Host "                                                   " -ForegroundColor Cyan
                    Write-Host " Infrastructure Automation That Transcends Boundaries" -ForegroundColor Cyan
                    Write-Host "=" * 60 -ForegroundColor Cyan
                    Write-Host "`nAvailable Scripts:" -ForegroundColor Cyan
                    for ($i = 0; $i -lt $availableScripts.Count; $i++) {
                        $script = $availableScripts[$i]
                        Write-Host "  $($i + 1). $($script.BaseName)" -ForegroundColor Gray
                    }

                    Write-Host "`nOptions:" -ForegroundColor Yellow
                    Write-Host "  • Enter script numbers (comma-separated)" -ForegroundColor Gray
                    Write-Host "  • Type 'all' to run all scripts" -ForegroundColor Gray
                    Write-Host "  • Type 'exit' or 'quit' to quit" -ForegroundColor Gray
                    Write-Host ""

                    $selection = Read-Host 'Selection'

                    if ($selection -eq 'exit' -or $selection -eq 'quit' -or $selection -eq '') {
                        Write-CustomLog 'Exiting at user request' -Level INFO
                        break
                    } elseif ($selection -eq 'all') {
                        foreach ($script in $availableScripts) {
                            Write-CustomLog "Executing script: $($script.BaseName)" -Level INFO
                            Invoke-ScriptWithOutputHandling -ScriptName $script.BaseName -ScriptPath $script.FullName -Config $config -Force:$Force
                        }
                        Write-Host "`nPress any key to return to menu..." -ForegroundColor Yellow
                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                    } else {
                        $selectedItems = $selection -split ',' | ForEach-Object { $_.Trim() }
                        foreach ($item in $selectedItems) {
                            $script = $null
                            # Check if input is a menu number (1-2 digits, within menu range)
                            if ($item -match '^\d{1,2}$' -and [int]$item -le $availableScripts.Count -and [int]$item -gt 0) {
                                $script = $availableScripts[[int]$item - 1]
                            }
                            # Check if input is a 4-digit script name (like 0002, 0006)
                            elseif ($item -match '^\d{4}$') {
                                $script = $availableScripts | Where-Object { $_.BaseName -like "*$item*" } | Select-Object -First 1
                            }
                            # Fallback to name-based matching
                            else {
                                $script = $availableScripts | Where-Object { $_.BaseName -eq $item -or $_.BaseName -like "$item*" } | Select-Object -First 1
                            }

                            if ($script) {
                                Write-CustomLog "Executing script: $($script.BaseName)" -Level INFO
                                Invoke-ScriptWithOutputHandling -ScriptName $script.BaseName -ScriptPath $script.FullName -Config $config -Force:$Force -Verbosity $Verbosity
                            } else {
                                Write-CustomLog "Invalid selection: $item" -Level WARN
                            }
                        }
                        Write-Host "`nPress any key to return to menu..." -ForegroundColor Yellow
                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                    }
                } while ($true)
            }
        }
    } else {
        Write-CustomLog "Scripts directory not found: $scriptsPath" -Level WARN
        Write-CustomLog 'No scripts to execute' -Level INFO
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
