<#
.SYNOPSIS
    AitherZero Platform Launcher with Orchestration Engine
.DESCRIPTION
    Main entry point for the AitherZero automation platform.
    Provides interactive menu and number-based orchestration capabilities.
    
    Note: This script requires PowerShell 7.0 or higher. If running from PowerShell 5.1,
    the script will automatically attempt to relaunch itself using pwsh.
.PARAMETER Mode
    Startup mode: Interactive (default), Orchestrate, Validate
.PARAMETER Sequence
    Number sequence for orchestration mode
.PARAMETER ConfigPath
    Path to configuration file
.PARAMETER NonInteractive
    Run without user prompts (automatically detected in CI environments)
.PARAMETER Profile
    Execution profile to use
.PARAMETER Playbook
    Name of the playbook to execute
.PARAMETER PlaybookProfile
    Profile to use within the playbook (e.g., quick, full, ci)
.PARAMETER IsRelaunch
    Internal parameter to prevent infinite relaunch loops
.EXAMPLE
    # Interactive mode
    .\Start-AitherZero.ps1

.EXAMPLE
    # Run specific sequence
    .\Start-AitherZero.ps1 -Mode Orchestrate -Sequence "0000-0099"

.EXAMPLE
    # Modern CLI - List all scripts
    .\Start-AitherZero.ps1 -Mode List -Target scripts

.EXAMPLE
    # Modern CLI - Run a specific script
    .\Start-AitherZero.ps1 -Mode Run -Target script -ScriptNumber 0402

.EXAMPLE
    # Modern CLI - Search for security tools
    .\Start-AitherZero.ps1 -Mode Search -Query security

.EXAMPLE
    # Run playbook with specific profile
    .\Start-AitherZero.ps1 -Mode Orchestrate -Playbook tech-debt-analysis -PlaybookProfile quick
#>
[CmdletBinding()]
param(
    [ValidateSet('Interactive', 'Orchestrate', 'Validate', 'Deploy', 'Test', 'List', 'Search', 'Run')]
    [string]$Mode = 'Interactive',

    [string[]]$Sequence,

    [string]$ConfigPath,

    [switch]$NonInteractive,

    [ValidateSet('Minimal', 'Standard', 'Developer', 'Full')]
    [string]$ProfileName,

    [string]$Playbook,

    [string]$PlaybookProfile,

    [switch]$DryRun,

    [switch]$Version,

    [switch]$Help,

    # Modern CLI parameters
    [string]$Target,
    [string]$Query,
    [string]$ScriptNumber,

    [switch]$CI,

    [hashtable]$Variables,

    [switch]$Sequential,

    [switch]$Parallel,

    # Internal parameter to prevent relaunch loops
    [switch]$IsRelaunch,

    # Catch any extra arguments that might come from shell redirection
    [Parameter(ValueFromRemainingArguments)]
    [object[]]$RemainingArguments
)

#region PowerShell Version Check and Auto-Relaunch
# Check if we're running PowerShell 7+ - required for AitherZero
if ($PSVersionTable.PSVersion.Major -lt 7 -and -not $IsRelaunch) {
    Write-Host ""
    Write-Host "PowerShell Version Check" -ForegroundColor Yellow
    Write-Host "========================" -ForegroundColor Yellow
    Write-Host "Current version: PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "Required version: PowerShell 7.0 or higher" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "AitherZero requires PowerShell 7+ for cross-platform compatibility and modern features." -ForegroundColor Cyan
    Write-Host ""

    # Try to find and launch pwsh
    $pwshCommand = $null
    
    # Check if pwsh is in PATH
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        $pwshCommand = "pwsh"
    }
    # On Windows, check common installation paths
    # Note: In PS 5.1, $IsWindows doesn't exist, so we check PSVersion and Platform
    elseif ($PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows) {
        $pwshPaths = @(
            "$env:ProgramFiles\PowerShell\7\pwsh.exe",
            "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
            "$env:ProgramFiles\PowerShell\pwsh.exe"
        )
        foreach ($path in $pwshPaths) {
            if (Test-Path $path) {
                $pwshCommand = $path
                break
            }
        }
    }

    if ($pwshCommand) {
        Write-Host "Found PowerShell 7+ at: $pwshCommand" -ForegroundColor Green
        Write-Host "Relaunching script with PowerShell 7..." -ForegroundColor Green
        Write-Host ""

        # Build argument list to preserve all parameters
        $argumentList = @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', $PSCommandPath
        )

        # Preserve all bound parameters
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            if ($param.Value -is [switch]) {
                if ($param.Value) {
                    $argumentList += "-$($param.Key)"
                }
            }
            elseif ($param.Value -is [array]) {
                $argumentList += "-$($param.Key)"
                $argumentList += ($param.Value -join ',')
            }
            elseif ($param.Value -is [hashtable]) {
                # Hashtables require special handling - use JSON for safe serialization
                $argumentList += "-$($param.Key)"
                # Serialize to JSON, escape it properly for command line
                $jsonString = ($param.Value | ConvertTo-Json -Compress) -replace '"', '\"'
                $argumentList += $jsonString
            }
            else {
                $argumentList += "-$($param.Key)", $param.Value
            }
        }

        # Add IsRelaunch flag to prevent infinite loops
        $argumentList += '-IsRelaunch'

        # Add any remaining arguments
        if ($RemainingArguments) {
            $argumentList += $RemainingArguments
        }

        try {
            # Use Start-Process to ensure proper console attachment
            & $pwshCommand @argumentList
            exit $LASTEXITCODE
        }
        catch {
            Write-Host "Failed to launch PowerShell 7: $_" -ForegroundColor Red
            Write-Host ""
            Write-Host "Please run this script directly with PowerShell 7:" -ForegroundColor Yellow
            Write-Host "  pwsh $PSCommandPath" -ForegroundColor Cyan
            exit 1
        }
    }
    else {
        Write-Host "PowerShell 7+ is not installed or not found in the expected locations." -ForegroundColor Red
        Write-Host ""
        Write-Host "Please install PowerShell 7+ from:" -ForegroundColor Yellow
        Write-Host "  https://github.com/PowerShell/PowerShell#get-powershell" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Or run the AitherZero bootstrap script which will install it for you:" -ForegroundColor Yellow
        Write-Host "  .\bootstrap.ps1 -AutoInstallDeps" -ForegroundColor Cyan
        Write-Host ""
        exit 1
    }
}
#endregion

# Set up environment
$script:ProjectRoot = $PSScriptRoot
$env:AITHERZERO_ROOT = $script:ProjectRoot

# Import Configuration module early to use Get-ConfiguredValue
$configModulePath = Join-Path $script:ProjectRoot 'domains/configuration/Configuration.psm1'
if (Test-Path $configModulePath) {
    Import-Module $configModulePath -Force -ErrorAction SilentlyContinue
}

# Apply configuration defaults if not provided
if ([string]::IsNullOrEmpty($ProfileName)) {
    if (Get-Command Get-ConfiguredValue -ErrorAction SilentlyContinue) {
        $ProfileName = Get-ConfiguredValue -Name 'Profile' -Section 'Core' -Default 'Standard'
    } else {
        $ProfileName = 'Standard'
    }
}

# Smart execution mode detection
function Get-SmartExecutionMode {
    param($CurrentMode, $CI, $NonInteractive)
    
    # If mode is explicitly set, respect it
    if ($CurrentMode -ne 'Interactive') {
        return $CurrentMode
    }
    
    # Detect CI environments
    $isCI = $env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true' -or $env:TF_BUILD -eq 'true'
    $isHeadless = $env:SSH_TTY -or $env:SSH_CLIENT -or (-not [Environment]::UserInteractive)
    
    # Check for automation indicators
    $isAutomated = $NonInteractive -or $CI -or $isCI -or $isHeadless
    
    # Check for specific scenarios
    if ($isCI) {
        # CI environment - likely running tests or deployment
        if ($env:GITHUB_ACTION_PATH -or $env:GITHUB_WORKFLOW) {
            return 'Validate'  # GitHub Actions typically validate
        }
        return 'Test'  # Default CI mode
    }
    
    if ($isHeadless -or $NonInteractive) {
        # Headless environment - likely server deployment
        return 'Deploy'
    }
    
    # Check if this looks like a testing session
    if ($PSCommandPath -match 'test' -or $MyInvocation.InvocationName -match 'test') {
        return 'Test'
    }
    
    # Default to interactive for user sessions
    return 'Interactive'
}

# Auto-detect CI if not explicitly set
if (-not $CI -and -not $NonInteractive) {
    if (Get-Command Get-ConfiguredValue -ErrorAction SilentlyContinue) {
        # Let Configuration module detect CI
        $nonInteractiveValue = Get-ConfiguredValue -Name 'NonInteractive' -Section 'Automation' -Default $false
        if ($nonInteractiveValue -eq $true -or $nonInteractiveValue -eq '1' -or $nonInteractiveValue -eq 'true') {
            $NonInteractive = $true
        }
    }
}

# Apply smart mode detection
$originalMode = $Mode
$Mode = Get-SmartExecutionMode -CurrentMode $Mode -CI $CI -NonInteractive $NonInteractive

if ($Mode -ne $originalMode) {
    Write-Verbose "Smart execution mode detection: $originalMode -> $Mode"
}

# CRITICAL: Block any conflicting systems
if ($env:DISABLE_COREAPP -ne "1") {
    # Force clean environment if not already done
    @('CoreApp', 'AitherRun', 'StartupExperience', 'ConfigurationCore', 'ConfigurationCarousel') | ForEach-Object {
        Remove-Module $_ -Force -ErrorAction SilentlyContinue 2>$null
    }
    $env:DISABLE_COREAPP = "1"
    $env:SKIP_AUTO_MODULES = "1"
}

# ASCII Art Banner with Gradient Colors
function Show-Banner {
    # Split banner into lines for gradient coloring
    $bannerLines = @(
        "    _    _ _   _               ______               ",
        "   / \  (_) |_| |__   ___ _ __|__  /___ _ __ ___   ",
        "  / _ \ | | __| '_ \ / _ \ '__| / // _ \ '__/ _ \  ",
        " / ___ \| | |_| | | |  __/ |   / /|  __/ | | (_) | ",
        "/_/   \_\_|\__|_| |_|\___|_|  /____\___|_|  \___/  ",
        "                                                    ",
        "        Aitherium™ Automation Platform v1.0",
        "        PowerShell 7 | Cross-Platform | Orchestrated"
    )

    # Define gradient colors from light blue to light pink
    $gradientColors = @(
        "`e[38;2;173;216;230m",  # Light Blue
        "`e[38;2;185;209;234m",  # Blue-Cyan transition
        "`e[38;2;197;202;238m",  # Cyan-Lavender transition
        "`e[38;2;209;195;242m",  # Lavender
        "`e[38;2;221;188;246m",  # Lavender-Pink transition
        "`e[38;2;233;181;250m",  # Light Purple-Pink
        "`e[38;2;245;174;254m",  # Pink-Purple
        "`e[38;2;255;182;193m"   # Light Pink
    )

    # Display each line with gradient color
    for ($i = 0; $i -lt $bannerLines.Count; $i++) {
        Write-Host "$($gradientColors[$i])$($bannerLines[$i])`e[0m"
    }
    Write-Host ""
}

# Show help information
function Show-Help {
    if (-not $env:CI -and -not $env:GITHUB_ACTIONS) {
        try { Clear-Host } catch { Write-Verbose "Unable to clear host in this context" }
    }
    Show-UIBorder -Title "AitherZero Help" -Style 'Double'

    Write-UIText "Quick Commands:" -Color 'Primary'
    Write-UIText "  seq 0000-0099        # Run scripts 0000 through 0099" -Color 'Info'
    Write-UIText "  seq 02*              # Run all 0200-0299 scripts" -Color 'Info'
    Write-UIText "  seq stage:Core       # Run all Core stage scripts" -Color 'Info'
    Write-UIText "  seq 0001,0207,0210   # Run specific scripts" -Color 'Info'
    Write-UIText "" -Color 'Info'

    Write-UIText "Profiles:" -Color 'Primary'
    Write-UIText "  Minimal    - Core infrastructure only" -Color 'Info'
    Write-UIText "  Standard   - Production-ready setup" -Color 'Info'
    Write-UIText "  Developer  - Full development environment" -Color 'Info'
    Write-UIText "  Full       - Everything including optional components" -Color 'Info'
    Write-UIText "" -Color 'Info'

    Write-UIText "Command Line Usage:" -Color 'Primary'
    Write-UIText "  -Mode Orchestrate -Sequence '0000-0099'" -Color 'Info'
    Write-UIText "  -Mode Orchestrate -Playbook 'infrastructure-lab'" -Color 'Info'
    Write-UIText "  -Mode Orchestrate -Playbook 'tech-debt-analysis' -PlaybookProfile 'quick'" -Color 'Info'
    Write-UIText "  -NonInteractive -Profile Developer" -Color 'Info'
    Write-UIText "  -DryRun    # Preview without executing" -Color 'Info'
}

# Version
if ($Version) {
    Write-Host "AitherZero v1.0" -ForegroundColor Cyan
    exit 0
}

# Help
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}

# Initialize core modules efficiently
function Initialize-CoreModules {
    # Direct import without background jobs to avoid double initialization
    try {
        # Check if already loaded and avoid repeated imports in CI
        $moduleLoaded = Get-Module -Name "AitherZero"
        $shouldReload = -not $moduleLoaded -or (-not $env:AITHERZERO_CI -and -not $global:AitherZeroModuleLoaded)

        if ($shouldReload) {
            Import-Module (Join-Path $script:ProjectRoot "AitherZero.psd1") -Force -Global
            $global:AitherZeroModuleLoaded = $true
        }

        # Initialize UI if available (without re-loading config)
        if (Get-Command Initialize-AitherUI -ErrorAction SilentlyContinue) {
            # Only initialize if not already done
            if (-not $global:AitherUIInitialized) {
                Initialize-AitherUI
                $global:AitherUIInitialized = $true
            }
        }

        return @{
            Logging = (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) -ne $null
            Configuration = (Get-Command Get-Configuration -ErrorAction SilentlyContinue) -ne $null
            UI = (Get-Command Show-UIMenu -ErrorAction SilentlyContinue) -ne $null
            Orchestration = (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue) -ne $null
        }
    } catch {
        Write-Error "Failed to import AitherZero module: $($_.Exception.Message)"
        return @{
            Logging = $false
            Configuration = $false
            UI = $false
            Orchestration = $false
        }
    }
}

# Load configuration
# Helper function to convert PSObject to Hashtable
function Convert-PSObjectToHashtable {
    param($InputObject)
    
    if ($InputObject -is [hashtable]) {
        return $InputObject
    }
    
    $hashtable = @{}
    if ($InputObject) {
        foreach ($property in $InputObject.PSObject.Properties) {
            if ($property.Value -is [PSCustomObject]) {
                $hashtable[$property.Name] = Convert-PSObjectToHashtable $property.Value
            } elseif ($property.Value -is [array]) {
                $hashtable[$property.Name] = $property.Value | ForEach-Object {
                    if ($_ -is [PSCustomObject]) {
                        Convert-PSObjectToHashtable $_
                    } else {
                        $_
                    }
                }
            } else {
                $hashtable[$property.Name] = $property.Value
            }
        }
    }
    return $hashtable
}

function Get-AitherConfiguration {
    param([string]$Path)

    if ($Path -and (Test-Path $Path)) {
        return Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
    }

    # Try both PSD1 and JSON formats
    $psd1Path = Join-Path $script:ProjectRoot 'config.psd1'
    if (Test-Path $psd1Path) {
        try {
            $configData = Import-PowerShellDataFile $psd1Path
            # Convert to hashtable for compatibility
            return Convert-PSObjectToHashtable $configData
        } catch {
            Write-Warning "Failed to load PSD1 config: $($_.Exception.Message)"
        }
    }

    $defaultPath = Join-Path $script:ProjectRoot 'config.json'
    if (Test-Path $defaultPath) {
        return Get-Content $defaultPath -Raw | ConvertFrom-Json -AsHashtable
    }

    Write-Warning "No configuration file found, using defaults"
    return @{
        Core = @{
            Name = "AitherZero"
            Version = "1.0.0"
            Profile = $ProfileName
        }
}
}

# Modern CLI Functions
function Write-ModernCLI {
    param(
        [string]$Message,
        [string]$Type = 'Info',
        [string]$Icon = '',
        [switch]$NoNewline
    )
    
    # Color mapping
    $colors = if ($env:CI -eq 'true') {
        @{ Info='White'; Success='White'; Warning='White'; Error='White'; Accent='White'; Muted='White' }
    } else {
        @{ Info='White'; Success='Green'; Warning='Yellow'; Error='Red'; Accent='Cyan'; Muted='DarkGray' }
    }
    
    $color = $colors[$Type]
    
    if ($Icon) {
        $prefix = "$Icon "
    } else {
        $prefix = switch ($Type) {
            'Success' { '✓ ' }
            'Warning' { '⚠ ' }
            'Error' { '✗ ' }
            'Accent' { '➤ ' }
            default { '' }
        }
    }
    
    Write-Host "$prefix$Message" -ForegroundColor $color -NoNewline:$NoNewline
}

function Show-ModernHelp {
    param([string]$ActionHelp)
    
    if ($ActionHelp) {
        switch ($ActionHelp) {
            'run' {
                Write-ModernCLI "Start-AitherZero.ps1 -Mode Run - Execute scripts, playbooks, or sequences" -Type 'Accent'
                Write-Host ""
                Write-ModernCLI "Examples:" -Type 'Info'
                Write-ModernCLI "  .\Start-AitherZero.ps1 -Mode Run -Target script -ScriptNumber 0402" -Type 'Muted'
                Write-ModernCLI "  .\Start-AitherZero.ps1 -Mode Run -Target playbook -Playbook tech-debt-analysis" -Type 'Muted'
                Write-ModernCLI "  .\Start-AitherZero.ps1 -Mode Run -Target sequence -Sequence 0400-0499" -Type 'Muted'
            }
            default {
                Write-ModernCLI "Unknown action: $ActionHelp" -Type 'Error'
            }
        }
        return
    }
    
    Write-ModernCLI "AitherZero Modern CLI" -Type 'Accent'
    Write-ModernCLI "Usage: .\Start-AitherZero.ps1 -Mode <action> [options]" -Type 'Info'
    Write-Host ""
    
    Write-ModernCLI "Available Modes:" -Type 'Info'
    Write-ModernCLI "  List" -Type 'Accent' -NoNewline
    Write-ModernCLI " - List available resources (scripts, playbooks)" -Type 'Muted'
    Write-ModernCLI "  Run" -Type 'Accent' -NoNewline  
    Write-ModernCLI " - Execute scripts, playbooks, or sequences" -Type 'Muted'
    Write-ModernCLI "  Search" -Type 'Accent' -NoNewline
    Write-ModernCLI " - Find resources by name or description" -Type 'Muted'
    Write-ModernCLI "  Interactive" -Type 'Accent' -NoNewline
    Write-ModernCLI " - Traditional menu interface" -Type 'Muted'
    
    Write-Host ""
    Write-ModernCLI "Examples:" -Type 'Info'
    Write-ModernCLI "  .\Start-AitherZero.ps1 -Mode List -Target scripts" -Type 'Muted'
    Write-ModernCLI "  .\Start-AitherZero.ps1 -Mode Run -Target script -ScriptNumber 0402" -Type 'Muted'
    Write-ModernCLI "  .\Start-AitherZero.ps1 -Mode Search -Query security" -Type 'Muted'
    Write-ModernCLI "  .\Start-AitherZero.ps1 -Mode Interactive" -Type 'Muted'
}

function Invoke-ModernListAction {
    param([string]$ListTarget)
    
    switch ($ListTarget) {
        'scripts' {
            if (Test-Path "automation-scripts") {
                $scripts = Get-ChildItem "automation-scripts" -Filter "*.ps1" | Sort-Object Name
                Write-ModernCLI "Available Scripts ($($scripts.Count)):" -Type 'Accent'
                Write-Host ""
                
                foreach ($script in $scripts) {
                    if ($script.Name -match '^(\d{4})_(.+)\.ps1$') {
                        $number = $matches[1]
                        $name = $matches[2].Replace('_', ' ').Replace('-', ' ')
                        Write-ModernCLI "  $number" -Type 'Accent' -NoNewline
                        Write-ModernCLI " - $name" -Type 'Info'
                    }
                }
            } else {
                Write-ModernCLI "Scripts directory not found" -Type 'Warning'
            }
        }
        'playbooks' {
            if (Test-Path "orchestration/playbooks") {
                $playbooks = Get-ChildItem "orchestration/playbooks" -Filter "*.json" -Recurse | Sort-Object Directory,Name
                Write-ModernCLI "Available Playbooks ($($playbooks.Count)):" -Type 'Accent'
                Write-Host ""
                
                $currentCategory = ""
                foreach ($playbook in $playbooks) {
                    try {
                        $pb = Get-Content $playbook.FullName | ConvertFrom-Json
                        $name = if ($pb.Name) { $pb.Name } else { $pb.name }
                        $desc = if ($pb.Description) { $pb.Description } else { $pb.description }
                        $category = $playbook.Directory.Name
                        
                        if ($category -ne $currentCategory -and $category -ne 'playbooks') {
                            if ($currentCategory) { Write-Host "" }
                            Write-ModernCLI "[$($category.ToUpper())]" -Type 'Accent'
                            $currentCategory = $category
                        }
                        
                        Write-ModernCLI "  $name" -Type 'Info' -NoNewline
                        if ($desc) {
                            Write-ModernCLI " - $desc" -Type 'Muted'
                        } else {
                            Write-Host ""
                        }
                    } catch {
                        Write-ModernCLI "  [Error reading: $($playbook.Name)]" -Type 'Warning'
                    }
                }
            } else {
                Write-ModernCLI "Playbooks directory not found" -Type 'Warning'
            }
        }
        'all' {
            Invoke-ModernListAction -ListTarget 'scripts'
            Write-Host ""
            Invoke-ModernListAction -ListTarget 'playbooks'
        }
        default {
            Write-ModernCLI "Unknown target: $ListTarget" -Type 'Error'
            Write-ModernCLI "Valid targets: scripts, playbooks, all" -Type 'Info'
        }
    }
}

function Invoke-ModernSearchAction {
    param([string]$Query)
    
    if (-not $Query) {
        Write-ModernCLI "Search query required: -Query <term>" -Type 'Error'
        return
    }
    
    Write-ModernCLI "Searching for: $Query" -Type 'Info'
    Write-Host ""
    
    # Search scripts
    if (Test-Path "automation-scripts") {
        $matchingScripts = Get-ChildItem "automation-scripts" -Filter "*.ps1" | Where-Object {
            $_.Name -like "*$Query*"
        } | Sort-Object Name
        
        if ($matchingScripts) {
            Write-ModernCLI "Scripts:" -Type 'Accent'
            foreach ($script in $matchingScripts) {
                if ($script.Name -match '^(\d{4})_(.+)\.ps1$') {
                    $number = $matches[1]
                    $name = $matches[2].Replace('_', ' ').Replace('-', ' ')
                    Write-ModernCLI "  $number - $name" -Type 'Info'
                }
            }
            Write-Host ""
        }
    }
    
    # Search playbooks
    if (Test-Path "orchestration/playbooks") {
        $matchingPlaybooks = Get-ChildItem "orchestration/playbooks" -Filter "*.json" -Recurse | ForEach-Object {
            try {
                $pb = Get-Content $_.FullName | ConvertFrom-Json
                $name = if ($pb.Name) { $pb.Name } else { $pb.name }
                $desc = if ($pb.Description) { $pb.Description } else { $pb.description }
                
                if ($name -like "*$Query*" -or ($desc -and $desc -like "*$Query*")) {
                    [PSCustomObject]@{
                        Name = $name
                        Description = $desc
                        Category = $_.Directory.Name
                    }
                }
            } catch {
                $null
            }
        } | Where-Object { $_ }
        
        if ($matchingPlaybooks) {
            Write-ModernCLI "Playbooks:" -Type 'Accent'
            foreach ($playbook in $matchingPlaybooks) {
                Write-ModernCLI "  [$($playbook.Category)] $($playbook.Name)" -Type 'Info'
                if ($playbook.Description) {
                    Write-ModernCLI "    $($playbook.Description)" -Type 'Muted'
                }
            }
        }
    }
    
    if (-not $matchingScripts -and -not $matchingPlaybooks) {
        Write-ModernCLI "No results found for: $Query" -Type 'Warning'
    }
}

function Invoke-ModernRunAction {
    param([string]$RunTarget, [string]$ScriptNum, [string]$PlaybookName, [string[]]$SequenceRange)
    
    switch ($RunTarget) {
        'script' {
            if (-not $ScriptNum) {
                Write-ModernCLI "Script number required: -ScriptNumber <number>" -Type 'Error'
                return
            }
            
            Write-ModernCLI "Running script $ScriptNum..." -Type 'Info'
            
            # Execute automation script directly
            $scriptPath = "./automation-scripts/$($ScriptNum.ToString().PadLeft(4, '0'))_*.ps1"
            $matchingScript = Get-ChildItem -Path $scriptPath -ErrorAction SilentlyContinue | Select-Object -First 1
            
            if ($matchingScript) {
                Write-ModernCLI "Executing: $($matchingScript.Name)" -Type 'Success'
                & $matchingScript.FullName
            } else {
                Write-ModernCLI "Script not found: $scriptPath" -Type 'Error'
            }
        }
        'playbook' {
            if (-not $PlaybookName) {
                Write-ModernCLI "Playbook name required: -Playbook <name>" -Type 'Error'
                return
            }
            
            Write-ModernCLI "Running playbook: $PlaybookName" -Type 'Info'
            if (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue) {
                Invoke-OrchestrationSequence -LoadPlaybook $PlaybookName
            } else {
                Write-ModernCLI "Orchestration engine not available" -Type 'Error'
            }
        }
        'sequence' {
            if (-not $SequenceRange) {
                Write-ModernCLI "Sequence required: -Sequence <range>" -Type 'Error'
                return
            }
            
            Write-ModernCLI "Running sequence: $($SequenceRange -join ',')" -Type 'Info'
            if (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue) {
                Invoke-OrchestrationSequence -Sequence $SequenceRange
            } else {
                Write-ModernCLI "Orchestration engine not available" -Type 'Error'
            }
        }
        default {
            Write-ModernCLI "Unknown target: $RunTarget" -Type 'Error'
            Write-ModernCLI "Valid targets: script, playbook, sequence" -Type 'Info'
        }
    }
}

# Main Interactive Menu using Core UI
function Show-InteractiveMenu {
    param($Config)

    # Interactive menus are now always enabled unless in non-interactive mode

    # Show banner only once at the start
    if (-not $env:CI -and -not $env:GITHUB_ACTIONS) {
        try { Clear-Host } catch { Write-Verbose "Unable to clear host in this context" }
    }
    Show-Banner

    while ($true) {
        # Build menu items
        $menuItems = @(
            [PSCustomObject]@{
                Name = "Quick Setup"
                Description = "Run profile-based setup (Current: $($Config.Core.Profile))"
            },
            [PSCustomObject]@{
                Name = "Orchestration"
                Description = "Run custom automation sequences"
            },
            [PSCustomObject]@{
                Name = "Playbooks"
                Description = "Execute pre-defined playbooks"
            },
            [PSCustomObject]@{
                Name = "Testing"
                Description = "Run tests and validation"
            },
            [PSCustomObject]@{
                Name = "Infrastructure"
                Description = "Deploy and manage infrastructure"
            },
            [PSCustomObject]@{
                Name = "Development"
                Description = "Git automation and AI coding tools"
            },
            [PSCustomObject]@{
                Name = "Health Dashboard"
                Description = "View system health, errors, and test results"
            },
            [PSCustomObject]@{
                Name = "Reports & Logs"
                Description = "View logs, generate reports, and analyze metrics"
            },
            [PSCustomObject]@{
                Name = "Advanced"
                Description = "Configuration and system management"
            }
    )

        # Show menu using UI module
        try {
            $menuParams = @{
                Title = "AitherZero Main Menu"
                Items = $menuItems
                ShowNumbers = $true
                CustomActions = @{
                    'Q' = 'Quit'
                    'H' = 'Help'
                }
            }

            $selection = Show-UIMenu @menuParams
        }
        catch {
            Write-Error "Menu error: $_"
            Show-UIPrompt -Message "Press Enter to continue or Ctrl+C to exit" | Out-Null
            # Don't clear screen, just continue to menu
            continue
        }

        # Handle null selection
        if (-not $selection) {
            continue
        }

        # Handle selection
        if ($selection.Action -eq 'Q') {
            Show-UINotification -Message "Thank you for using AitherZero!" -Type 'Success'
            return
        }
    elseif ($selection.Action -eq 'H') {
            Show-Help
            Show-UIPrompt -Message "Press Enter to continue" | Out-Null
        }
    elseif ($selection.Name) {
            switch ($selection.Name) {
                'Quick Setup' { Invoke-QuickSetup -Config $Config }
                'Orchestration' { Invoke-OrchestrationMenu -Config $Config }
                'Playbooks' { Invoke-PlaybookMenu -Config $Config }
                'Testing' { Invoke-TestingMenu -Config $Config }
                'Infrastructure' { Invoke-InfrastructureMenu -Config $Config }
                'Development' { Invoke-DevelopmentMenu -Config $Config }
                'Health Dashboard' {
                    # Show the consolidated health dashboard
                    $healthScript = Join-Path $script:ProjectRoot "automation-scripts/0550_Health-Dashboard.ps1"
                    if (Test-Path $healthScript) {
                        & $healthScript -Configuration $Config -ShowAll
                    } else {
                        Show-UINotification -Message "Health Dashboard script not found" -Type 'Warning'
                    }
                    Show-UIPrompt -Message "Press Enter to continue" | Out-Null
                }
                'Reports & Logs' { Invoke-ReportsAndLogsMenu -Config $Config }
                'Advanced' { Show-AdvancedMenu -Config $Config }
            }
    }
}
}

# Quick Setup
function Invoke-QuickSetup {
    param($Config)

    # Display what Quick Setup will do
    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    Quick Setup                            ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Current Profile: " -NoNewline -ForegroundColor White
    Write-Host "$($Config.Core.Profile)" -ForegroundColor Green
    Write-Host ""

    # Determine what will be installed
    $ProfileNameSequence = switch ($Config.Core.Profile) {
        'Minimal' { 
            Write-Host "Minimal Profile includes:" -ForegroundColor Yellow
            Write-Host "  • Basic environment setup (0000-0099)" -ForegroundColor Gray
            Write-Host "  • Git installation (0207)" -ForegroundColor Gray
            "0000-0099,0207"
        }
        'Standard' { 
            Write-Host "Standard Profile includes:" -ForegroundColor Yellow
            Write-Host "  • Environment setup (0000-0199)" -ForegroundColor Gray
            Write-Host "  • Git (0207) and Node.js Core (0201)" -ForegroundColor Gray
            "0000-0199,0207,0201"
        }
        'Developer' { 
            Write-Host "Developer Profile includes:" -ForegroundColor Yellow
            Write-Host "  • Full development environment (0000-0299)" -ForegroundColor Gray
            Write-Host "  • Excluding Docker Desktop (0208)" -ForegroundColor Gray
            "0000-0299,!0208"
        }
        'Full' { 
            Write-Host "Full Profile includes:" -ForegroundColor Yellow
            Write-Host "  • Complete infrastructure setup (0000-0499)" -ForegroundColor Gray
            "0000-0499"
        }
    }

    Write-Host ""
    Write-Host "⚠️  This will execute multiple automation scripts." -ForegroundColor Yellow
    Write-Host ""

    # Confirm before proceeding
    $confirm = Show-UIPrompt -Message "Do you want to proceed with Quick Setup?" -ValidateSet @('Yes', 'No', 'Dry-Run') -DefaultValue 'No'

    if ($confirm -eq 'No') {
        Show-UINotification -Message "Quick Setup cancelled" -Type 'Info'
        Show-UIPrompt -Message "Press Enter to continue" | Out-Null
        return
    }

    if ($confirm -eq 'Dry-Run') {
        Show-UINotification -Message "Running dry run for $($Config.Core.Profile) profile..." -Type 'Info'
        Write-Host ""
        $result = Invoke-OrchestrationSequence -Sequence $ProfileNameSequence -Configuration $Config -DryRun
        Write-Host ""
        $proceed = Show-UIPrompt -Message "Dry run complete. Execute for real?" -ValidateSet @('Yes', 'No') -DefaultValue 'No'
        if ($proceed -eq 'No') {
            Show-UINotification -Message "Quick Setup cancelled after dry run" -Type 'Info'
            Show-UIPrompt -Message "Press Enter to continue" | Out-Null
            return
        }
    }

    # Execute the setup
    Show-UINotification -Message "Starting $($Config.Core.Profile) profile setup..." -Type 'Info' -Title "Quick Setup"
    Write-Host ""
    
    $result = Invoke-OrchestrationSequence -Sequence $ProfileNameSequence -Configuration $Config

    Write-Host ""
    if ($result.Failed -eq 0) {
        Show-UINotification -Message "✅ Profile setup completed successfully!" -Type 'Success'
    } else {
        Show-UINotification -Message "⚠️  Profile setup completed with $($result.Failed) errors" -Type 'Warning'
    }
    
    Show-UIPrompt -Message "Press Enter to continue" | Out-Null
}

# Orchestration Menu
function Invoke-OrchestrationMenu {
    param($Config)

    $sequence = Show-UIPrompt -Message "Enter orchestration sequence (e.g., 0001-0099,0201,stage:Core)"

    if ($sequence) {
        $dryRun = Show-UIPrompt -Message "Perform dry run first?" -ValidateSet @('Yes', 'No') -DefaultValue 'Yes'

        $variables = @{}
        if ($CI) { $variables['CI'] = $true }

        if ($dryRun -eq 'Yes') {
            Show-UINotification -Message "Running dry run..." -Type 'Info'
            $result = Invoke-OrchestrationSequence -Sequence $sequence -Configuration $Config -Variables $variables -DryRun

            $proceed = Show-UIPrompt -Message "Dry run complete. Proceed with execution?" -ValidateSet @('Yes', 'No') -DefaultValue 'No'
            if ($proceed -eq 'Yes') {
                $result = Invoke-OrchestrationSequence -Sequence $sequence -Configuration $Config -Variables $variables
            }
    } else {
            $result = Invoke-OrchestrationSequence -Sequence $sequence -Configuration $Config -Variables $variables
        }
}

    Show-UIPrompt -Message "Press Enter to continue" | Out-Null
}

# Playbook Menu
function Invoke-PlaybookMenu {
    param($Config)

    $playbookDir = Join-Path $script:ProjectRoot "orchestration/playbooks"
    if (-not (Test-Path $playbookDir)) {
        Show-UINotification -Message "No playbooks directory found" -Type 'Error'
        Show-UIPrompt -Message "Press Enter to continue" | Out-Null
        return
    }

    # Load playbooks (including from subdirectories)
    $playbooks = Get-ChildItem $playbookDir -Filter "*.json" -Recurse | ForEach-Object {
        $pb = Get-Content $_.FullName | ConvertFrom-Json
        # Get category from parent directory if in a subdirectory
        $category = if ($_.Directory.Name -ne 'playbooks') {
            $_.Directory.Name
        } else {
            'general'
        }
        # Handle case-sensitive property names in JSON
        $name = if ($pb.Name) { $pb.Name } else { $pb.name }
        $description = if ($pb.Description) { $pb.Description } else { $pb.description }
        
        [PSCustomObject]@{
            Name = if ($category -ne 'general' -and $category -ne 'archive') { "[$category] $name" } else { $name }
            Description = $description
            Path = $_.FullName
            Category = $category
            OriginalName = $name
        }
    } | Sort-Object Category, Name

    if ($playbooks.Count -eq 0) {
        Show-UINotification -Message "No playbooks found" -Type 'Warning'
        Show-UIPrompt -Message "Press Enter to continue" | Out-Null
        return
    }

    $selection = Show-UIMenu -Title "Select Playbook" -Items $playbooks -ShowNumbers

    if ($selection) {
        Show-UINotification -Message "Executing playbook: $($selection.Name)" -Type 'Info'
        $variables = @{}
        if ($CI) { $variables['CI'] = $true }
        # Use OriginalName to avoid category prefix issues like "[analysis] name"
        $playbookName = if ($selection.OriginalName) { $selection.OriginalName } else { $selection.Name }
        
        try {
            Write-Host "DEBUG: Attempting to load playbook '$playbookName' (Display: '$($selection.Name)')" -ForegroundColor Yellow
            $result = Invoke-OrchestrationSequence -LoadPlaybook $playbookName -Configuration $Config -Variables $variables

            if ($result.Failed -eq 0) {
                Show-UINotification -Message "Playbook completed successfully!" -Type 'Success'
            } else {
                Show-UINotification -Message "Playbook completed with errors" -Type 'Error'
            }
        } catch {
            Show-UINotification -Message "Failed to execute playbook '$playbookName': $($_.Exception.Message)" -Type 'Error'
            Write-Host "ERROR: $($_.Exception)" -ForegroundColor Red
        }
    } else {
        Show-UINotification -Message "No playbook selected" -Type 'Warning'
    }

    Show-UIPrompt -Message "Press Enter to continue" | Out-Null
}

# Testing Menu
function Invoke-TestingMenu {
    param($Config)

    $testItems = @(
        [PSCustomObject]@{
            Name = "Run Unit Tests"
            Description = "Execute unit test suite"
            Sequence = "0402"
        },
        [PSCustomObject]@{
            Name = "Run Integration Tests"
            Description = "Execute integration test suite"
            Sequence = "0403"
        },
        [PSCustomObject]@{
            Name = "Run PSScriptAnalyzer"
            Description = "Analyze code quality"
            Sequence = "0404"
        },
        [PSCustomObject]@{
            Name = "Validate Environment"
            Description = "Check system requirements"
            Sequence = "0500"
        },
        [PSCustomObject]@{
            Name = "Generate Coverage Report"
            Description = "Create code coverage report"
            Sequence = "0406"
        },
        [PSCustomObject]@{
            Name = "Full Test Suite"
            Description = "Run all tests with reporting"
            Playbook = "test-full"
        }
)

    $selection = Show-UIMenu -Title "Testing & Validation" -Items $testItems -ShowNumbers

    if ($selection) {
        Show-UINotification -Message "Starting: $($selection.Name)" -Type 'Info'

        if ($selection.Sequence) {
            $result = Invoke-OrchestrationSequence -Sequence $selection.Sequence -Configuration $Config
        } elseif ($selection.Playbook) {
            $result = Invoke-OrchestrationSequence -LoadPlaybook $selection.Playbook -Configuration $Config
        }

        # Only prompt if successful (errors already prompt)
        if (-not $result -or $result.Failed -eq 0) {
            Show-UIPrompt -Message "Press Enter to continue" | Out-Null
        }
    }
}

# Infrastructure Menu
function Invoke-InfrastructureMenu {
    param($Config)

    $infraItems = @(
        [PSCustomObject]@{
            Name = "Install Hyper-V"
            Description = "Setup virtualization platform"
            Sequence = "0105"
        },
        [PSCustomObject]@{
            Name = "Install OpenTofu"
            Description = "Setup infrastructure as code"
            Sequence = "0007-0009"
        },
        [PSCustomObject]@{
            Name = "Deploy Infrastructure"
            Description = "Deploy configured infrastructure"
            Sequence = "0300"
        },
        [PSCustomObject]@{
            Name = "Full Infrastructure Setup"
            Description = "Complete infrastructure deployment"
            Playbook = "infrastructure-lab"
        }
)

    $selection = Show-UIMenu -Title "Infrastructure Management" -Items $infraItems -ShowNumbers

    if ($selection) {
        $confirm = Show-UIPrompt -Message "This may modify your system. Continue?" -ValidateSet @('Yes', 'No') -DefaultValue 'No'

        if ($confirm -eq 'Yes') {
            Show-UINotification -Message "Starting: $($selection.Name)" -Type 'Info'

            if ($selection.Sequence) {
                $result = Invoke-OrchestrationSequence -Sequence $selection.Sequence -Configuration $Config
            } elseif ($selection.Playbook) {
                $result = Invoke-OrchestrationSequence -LoadPlaybook $selection.Playbook -Configuration $Config
            }
    }
}

    Show-UIPrompt -Message "Press Enter to continue" | Out-Null
}

# Development Menu
function Invoke-DevelopmentMenu {
    param($Config)

    $devItems = @(
        [PSCustomObject]@{
            Name = "Git Status"
            Description = "Show current repository status"
            Command = { git status }
        },
        [PSCustomObject]@{
            Name = "Create Feature Branch"
            Description = "Create a new feature branch"
            Command = {
                $name = Show-UIPrompt -Message "Feature name"
                if ($name) { git checkout -b "feature/$name" }
            }
    },
        [PSCustomObject]@{
            Name = "Run Pre-commit Checks"
            Description = "Validate code before commit"
            Sequence = "0404,0402"
        },
        [PSCustomObject]@{
            Name = "Generate Tests"
            Description = "Auto-generate test cases"
            Sequence = "0407"
        }
)

    $selection = Show-UIMenu -Title "Development Tools" -Items $devItems -ShowNumbers

    if ($selection) {
        if ($selection.Command) {
            & $selection.Command
        } elseif ($selection.Sequence) {
            $result = Invoke-OrchestrationSequence -Sequence $selection.Sequence -Configuration $Config
        }
}

    Show-UIPrompt -Message "Press Enter to continue" | Out-Null
}

# Reports & Logs Menu
function Invoke-ReportsAndLogsMenu {
    param($Config)

    # Import LogViewer module if not already loaded
    $logViewerPath = Join-Path $script:ProjectRoot "domains/utilities/LogViewer.psm1"
    if (Test-Path $logViewerPath) {
        Import-Module $logViewerPath -Force -ErrorAction SilentlyContinue
    }

    $reportItems = @(
        [PSCustomObject]@{
            Name = "Health Dashboard"
            Description = "Consolidated system health and status"
            Action = 'HealthDashboard'
        },
        [PSCustomObject]@{
            Name = "View Latest Logs"
            Description = "Show recent log entries"
            Action = 'ViewLogs'
            Mode = 'Latest'
        },
        [PSCustomObject]@{
            Name = "Log Dashboard"
            Description = "Interactive log viewer with statistics"
            Action = 'ViewLogs'
            Mode = 'Dashboard'
        },
        [PSCustomObject]@{
            Name = "View Errors & Warnings"
            Description = "Show only error and warning messages"
            Action = 'ViewLogs'
            Mode = 'Errors'
        },
        [PSCustomObject]@{
            Name = "Search Logs"
            Description = "Search for specific patterns in logs"
            Action = 'ViewLogs'
            Mode = 'Search'
        },
        [PSCustomObject]@{
            Name = "View PowerShell Transcript"
            Description = "Show PowerShell session transcript"
            Action = 'ViewLogs'
            Mode = 'Transcript'
        },
        [PSCustomObject]@{
            Name = "Generate Project Report"
            Description = "Create comprehensive project analysis"
            Sequence = "0510"
        },
        [PSCustomObject]@{
            Name = "Tech Debt Analysis"
            Description = "Analyze and report technical debt"
            Sequence = "0524"
        },
        [PSCustomObject]@{
            Name = "Code Quality Report"
            Description = "Analyze code quality metrics"
            Sequence = "0522"
        },
        [PSCustomObject]@{
            Name = "Documentation Coverage"
            Description = "Check documentation completeness"
            Sequence = "0521"
        },
        [PSCustomObject]@{
            Name = "Logging Status"
            Description = "Check logging system configuration"
            Action = 'ViewLogs'
            Mode = 'Status'
        }
    )

    $selection = Show-UIMenu -Title "Reports & Logs" -Items $reportItems -ShowNumbers

    if ($selection) {
        Show-UINotification -Message "Starting: $($selection.Name)" -Type 'Info'

        if ($selection.Action -eq 'HealthDashboard') {
            # Call health dashboard script
            $healthScript = Join-Path $script:ProjectRoot "automation-scripts/0550_Health-Dashboard.ps1"
            if (Test-Path $healthScript) {
                & $healthScript -Configuration $Config -ShowAll
            } else {
                Show-UINotification -Message "Health Dashboard script not found at: $healthScript" -Type 'Warning'
            }
        }
        elseif ($selection.Action -eq 'ViewLogs') {
            # Call log viewer script directly with proper parameters
            $logScript = Join-Path $script:ProjectRoot "automation-scripts/0530_View-Logs.ps1"
            if (Test-Path $logScript) {
                & $logScript -Mode $selection.Mode -Configuration $Config
            } else {
                Show-UINotification -Message "Log viewer script not found at: $logScript" -Type 'Warning'
            }
        }
        elseif ($selection.Sequence) {
            # Use orchestration for report generation
            $result = Invoke-OrchestrationSequence -Sequence $selection.Sequence -Configuration $Config
        }
    }

    Show-UIPrompt -Message "Press Enter to continue" | Out-Null
}

# Advanced menu using UI module
function Show-AdvancedMenu {
    param($Config)

    while ($true) {
        $advancedItems = @(
            [PSCustomObject]@{
                Name = "Change Profile"
                Description = "Switch execution profile"
            },
            [PSCustomObject]@{
                Name = "Edit Configuration"
                Description = "Open config.json in editor"
            },
            [PSCustomObject]@{
                Name = "Create Playbook"
                Description = "Create new orchestration playbook"
            },
            [PSCustomObject]@{
                Name = "System Information"
                Description = "Show system and dependency info"
            },
            [PSCustomObject]@{
                Name = "Run Single Script"
                Description = "Execute specific automation script"
            },
            [PSCustomObject]@{
                Name = "Module Manager"
                Description = "Import/reload modules"
            }
    )

        $selection = Show-UIMenu -Title "Advanced Options" -Items $advancedItems -ShowNumbers -CustomActions @{ 'B' = 'Back to Main Menu' }

        if ($selection.Action -eq 'B') {
            return
        }

        switch ($selection.Name) {
            'Change Profile' {
                $ProfileNames = @(
                    [PSCustomObject]@{ Name = 'Minimal'; Description = 'Core infrastructure only' },
                    [PSCustomObject]@{ Name = 'Standard'; Description = 'Production-ready setup' },
                    [PSCustomObject]@{ Name = 'Developer'; Description = 'Full development environment' },
                    [PSCustomObject]@{ Name = 'Full'; Description = 'Everything including optional components' }
                )

                $newProfile = Show-UIMenu -Title "Select Profile" -Items $ProfileNames -ShowNumbers
                if ($newProfile) {
                    $Config.Core.Profile = $newProfile.Name
                    Show-UINotification -Message "Profile changed to: $($newProfile.Name)" -Type 'Success'
                }
        }

            'Edit Configuration' {
                $configPath = Join-Path $script:ProjectRoot 'config.psd1'
                if ($IsWindows) {
                    Start-Process notepad.exe -ArgumentList $configPath -Wait
                } else {
                    $editor = $env:EDITOR ?? 'nano'
                    Start-Process -FilePath $editor -ArgumentList $configPath -Wait
                }

                # Reload configuration after editing
                Show-UINotification -Message "Reloading configuration..." -Type 'Info'
                try {
                    # Clear the cached configuration in the Configuration module if available
                    # This ensures Get-Configuration calls will also see the updated values
                    # Note: This is optional and safe - if the module structure changes, it will just skip this step
                    if (Get-Command Get-Configuration -ErrorAction SilentlyContinue) {
                        # Force reload by accessing the module's script scope
                        $configModule = Get-Module -Name 'Configuration' -ErrorAction SilentlyContinue
                        if ($configModule) {
                            & $configModule { $script:Config = $null }
                        }
                    }

                    # Reload configuration using the same method as initial load
                    $newConfig = Get-AitherConfiguration -Path $ConfigPath
                    
                    # Update the existing hashtable in-place to preserve references
                    # This ensures the changes are visible to all callers
                    $Config.Clear()
                    foreach ($key in $newConfig.Keys) {
                        $Config[$key] = $newConfig[$key]
                    }
                    
                    Show-UINotification -Message "Configuration reloaded successfully!" -Type 'Success'
                } catch {
                    Show-UINotification -Message "Failed to reload configuration: $($_.Exception.Message)" -Type 'Error'
                    Write-ConfigLog -Level Warning -Message "Configuration reload failed, changes will apply on restart" -Data @{
                        Error = $_.Exception.Message
                    }
                }
            }

            'Create Playbook' {
                # Use wizard for playbook creation
                $wizardSteps = @(
                    @{
                        Name = "Basic Information"
                        Script = {
                            $name = Show-UIPrompt -Message "Playbook name" -Required
                            $desc = Show-UIPrompt -Message "Description" -Required
                            @{ Name = $name; Description = $desc }
                        }
                },
                    @{
                        Name = "Sequence Definition"
                        Script = {
                            Write-UIText "Enter sequence (e.g., 0001-0099,0201,stage:Core)" -Color 'Info'
                            $seq = Show-UIPrompt -Message "Sequence" -Required
                            @{ Sequence = ($seq -split ',') }
                        }
                },
                    @{
                        Name = "Variables"
                        Script = {
                            $addVars = Show-UIPrompt -Message "Add variables?" -ValidateSet @('Yes', 'No') -DefaultValue 'No'
                            $vars = @{}
                            if ($addVars -eq 'Yes') {
                                while ($true) {
                                    $key = Show-UIPrompt -Message "Variable name (blank to finish)"
                                    if (-not $key) { break }
                                    $value = Show-UIPrompt -Message "Value for $key"
                                    $vars[$key] = $value
                                }
                        }
                        @{ Variables = $vars }
                        }
                }
            )

                $result = Show-UIWizard -Steps $wizardSteps -Title "Create Playbook"

                if ($result) {
                    Save-OrchestrationPlaybook -Name $result.Name -Sequence $result.Sequence -Variables ($result.Variables + @{Description = $result.Description})
                    Show-UINotification -Message "Playbook '$($result.Name)' created successfully!" -Type 'Success'
                }
        }

            'System Information' {
                if (-not $env:CI -and -not $env:GITHUB_ACTIONS) {
                    try { Clear-Host } catch { Write-Verbose "Unable to clear host in this context" }
                }
                Show-UIBorder -Title "System Information" -Style 'Double'

                $sysInfo = @(
                    [PSCustomObject]@{ Property = "PowerShell"; Value = $PSVersionTable.PSVersion },
                    [PSCustomObject]@{ Property = "OS"; Value = $PSVersionTable.OS },
                    [PSCustomObject]@{ Property = "Platform"; Value = $PSVersionTable.Platform },
                    [PSCustomObject]@{ Property = "Project Root"; Value = $script:ProjectRoot },
                    [PSCustomObject]@{ Property = "Current Profile"; Value = $Config.Core.Profile }
                )

                Show-UITable -Data $sysInfo -Title "System Details"

                Write-UIText "`nChecking Dependencies..." -Color 'Info'
                $deps = @('git', 'node', 'tofu', 'docker', 'pwsh')
                $depStatus = @()

                foreach ($dep in $deps) {
                    try {
                        $version = & $dep --version 2>&1 | Select-Object -First 1
                        $depStatus += [PSCustomObject]@{
                            Tool = $dep
                            Status = "✓ Found"
                            Version = $version
                        }
                } catch {
                        $depStatus += [PSCustomObject]@{
                            Tool = $dep
                            Status = "✗ Not Found"
                            Version = "N/A"
                        }
                }
            }

                Show-UITable -Data $depStatus -Title "Dependencies"
                Show-UIPrompt -Message "Press Enter to continue" | Out-Null
            }

            'Run Single Script' {
                # Allow direct 4-digit script number input or category selection
                Write-UIText "Script Execution Options:" -Color 'Cyan'
                Write-UIText "1. Enter a 4-digit script number directly (e.g., 0402)" -Color 'Info'
                Write-UIText "2. Browse by category" -Color 'Info'
                Write-UIText "3. Search by keyword" -Color 'Info'
                Write-UIText ""

                $scriptInput = Show-UIPrompt -Message "Enter script number, keyword, or press Enter for categories"

                $scriptsPath = Join-Path $script:ProjectRoot "automation-scripts"
                $selected = $null

                if ($scriptInput -match '^\d{4}$') {
                    # Direct script number entered
                    $scriptFile = Get-ChildItem $scriptsPath -Filter "${scriptInput}_*.ps1" | Select-Object -First 1
                    if ($scriptFile) {
                        $selected = [PSCustomObject]@{
                            Name = $scriptFile.Name
                            Description = $scriptFile.Name -replace '^\d{4}_' -replace '\.ps1$' -replace '-', ' '
                        }
                    } else {
                        Show-UINotification -Message "Script $scriptInput not found" -Type 'Warning'
                    }
                } elseif ($scriptInput -and $scriptInput -notmatch '^\d{4}$') {
                    # Search by keyword
                    $scripts = Get-ChildItem $scriptsPath -Filter "*.ps1" |
                        Where-Object { $_.Name -match '^\d{4}_' -and $_.Name -like "*$scriptInput*" } |
                        ForEach-Object {
                            [PSCustomObject]@{
                                Name = $_.Name
                                Description = $_.Name -replace '^\d{4}_' -replace '\.ps1$' -replace '-', ' '
                            }
                        }

                    if ($scripts.Count -eq 0) {
                        Show-UINotification -Message "No scripts found matching '$scriptInput'" -Type 'Warning'
                    } elseif ($scripts.Count -eq 1) {
                        $selected = $scripts[0]
                    } else {
                        $selected = Show-UIMenu -Title "Scripts matching '$scriptInput'" -Items $scripts -ShowNumbers
                    }
                } else {
                    # Browse by category
                    $categories = @(
                        [PSCustomObject]@{ Name = "0000-0099 - Environment & Cleanup"; Range = "00" }
                        [PSCustomObject]@{ Name = "0100-0199 - Infrastructure"; Range = "01" }
                        [PSCustomObject]@{ Name = "0200-0299 - Development Tools"; Range = "02" }
                        [PSCustomObject]@{ Name = "0300-0399 - Deployment"; Range = "03" }
                        [PSCustomObject]@{ Name = "0400-0499 - Testing & Validation"; Range = "04" }
                        [PSCustomObject]@{ Name = "0500-0599 - Reporting & Metrics"; Range = "05" }
                        [PSCustomObject]@{ Name = "0600-0699 - Monitoring"; Range = "06" }
                        [PSCustomObject]@{ Name = "0700-0799 - Git & Development"; Range = "07" }
                        [PSCustomObject]@{ Name = "0800-0899 - Session & Issues"; Range = "08" }
                        [PSCustomObject]@{ Name = "9000-9999 - Maintenance"; Range = "9" }
                        [PSCustomObject]@{ Name = "Show All Scripts"; Range = "all" }
                    )

                    $categorySelection = Show-UIMenu -Title "Select Category" -Items $categories -ShowNumbers

                    if ($categorySelection) {
                        $scripts = if ($categorySelection.Range -eq "all") {
                            Get-ChildItem $scriptsPath -Filter "*.ps1" |
                                Where-Object { $_.Name -match '^\d{4}_' }
                        } else {
                            Get-ChildItem $scriptsPath -Filter "*.ps1" |
                                Where-Object { $_.Name -match "^$($categorySelection.Range)\d{2}_" }
                        }

                        $scripts = $scripts | ForEach-Object {
                            [PSCustomObject]@{
                                Name = $_.Name
                                Description = $_.Name -replace '^\d{4}_' -replace '\.ps1$' -replace '-', ' '
                            }
                        }

                        if ($scripts.Count -eq 0) {
                            Show-UINotification -Message "No scripts found in this category" -Type 'Warning'
                        } else {
                            $selected = Show-UIMenu -Title "Select Script from $($categorySelection.Name)" -Items $scripts -ShowNumbers
                        }
                    }
                }

                if ($selected) {
                    $confirm = Show-UIPrompt -Message "Execute $($selected.Name)?" -ValidateSet @('Yes', 'No') -DefaultValue 'No'
                    if ($confirm -eq 'Yes') {
                        $scriptPath = Join-Path $scriptsPath $selected.Name
                        # Execute directly without Show-UISpinner to avoid variable scope issues
                        Write-UIText "Executing $($selected.Name)..." -Color 'Info'
                        & $scriptPath -Configuration $Config
                        Write-UIText "Execution completed" -Color 'Success'
                }
            }
        }

            'Module Manager' {
                Show-UINotification -Message "Scanning for modules..." -Type 'Info'

                $modules = Get-ChildItem (Join-Path $script:ProjectRoot "domains") -Recurse -Filter "*.psm1" |
                    ForEach-Object {
                        $loaded = Get-Module -Name $_.BaseName -ErrorAction SilentlyContinue
                        [PSCustomObject]@{
                            Name = $_.BaseName
                            Path = $_.FullName.Replace($script:ProjectRoot, '.')
                            Status = if ($loaded) { "Loaded" } else { "Not Loaded" }
                        }
                }

                Show-UITable -Data $modules -Title "Domain Modules"

                $action = Show-UIPrompt -Message "Action" -ValidateSet @('Import All', 'Reload All', 'Cancel') -DefaultValue 'Cancel'

                if ($action -ne 'Cancel') {
                    $modules | ForEach-Object {
                        try {
                            Import-Module $_.Path.Replace('.', $script:ProjectRoot) -Force -Global
                            Write-UIText "  ✓ $($_.Name)" -Color 'Success'
                        } catch {
                            Write-UIText "  ✗ $($_.Name): $_" -Color 'Error'
                        }
                }
            }
        }
    }

        Show-UIPrompt -Message "Press Enter to continue" | Out-Null
    }
}

# Main execution
try {
    # Initialize
    if (-not $NonInteractive) {
        Show-Banner
    }

    $modules = Initialize-CoreModules

    # Check if UI module loaded successfully
    if (-not $modules.UI) {
        $errorMsg = "Failed to load UI module. Cannot continue in interactive mode."

        # Log the error if logging is available
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Level 'Error' -Message $errorMsg -Source "Start-AitherZero" -Data @{
                Mode = $Mode
                ModulesLoaded = $modules
            }
        }

        Write-Error $errorMsg
        if ($Mode -eq 'Interactive') {
            exit 1
        }
    }

    $config = Get-AitherConfiguration -Path $ConfigPath

    # Smart execution mode detection based on environment context
    if (-not $PSBoundParameters.ContainsKey('NonInteractive')) {
        # Detect CI environment using standard CI environment variables
        $isCI = ($env:CI -eq 'true') -or 
                ($env:GITHUB_ACTIONS -eq 'true') -or 
                ($env:TF_BUILD -eq 'true') -or
                ($env:GITLAB_CI -eq 'true') -or
                ($env:JENKINS_URL) -or
                ($env:TRAVIS -eq 'true') -or
                ($env:CIRCLECI -eq 'true')
        
        if ($isCI) {
            # CI environment detected
            if ($PSBoundParameters.ContainsKey('Mode') -and $Mode -eq 'Interactive') {
                # User explicitly requested Interactive mode in CI - allow it for testing
                $NonInteractive = $false
                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                    Write-CustomLog "CI environment detected, but Interactive mode explicitly requested - allowing interactive mode" -Level 'Information'
                }
            } else {
                # Default CI behavior: Non-interactive with validation mode for automated logging
                $NonInteractive = $true
                if ($Mode -eq 'Interactive' -and -not $PSBoundParameters.ContainsKey('Mode')) {
                    $Mode = 'Validate'
                    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                        Write-CustomLog "CI environment detected - running non-interactive validation with logging to files" -Level 'Information'
                    }
                }
            }
        } else {
            # Manual execution: Interactive by default for user experience  
            $NonInteractive = $false
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog "Manual execution detected - starting interactive mode" -Level 'Information'
            }
        }
    }

    # Validate mode compatibility
    if ($NonInteractive -and $Mode -eq 'Interactive') {
        Write-Warning "Interactive mode is not compatible with NonInteractive flag. Use -Mode Validate, Orchestrate, or Test instead."
        exit 1
    }

    # Handle different modes
    switch ($Mode) {
        'Interactive' {
            if ($NonInteractive) {
                Write-Warning "Cannot run interactive mode with -NonInteractive flag"
                exit 1
            }
        Show-InteractiveMenu -Config $config
        }

        'Orchestrate' {
            if (-not $Sequence -and -not $Playbook) {
                Write-Error "Orchestrate mode requires -Sequence or -Playbook parameter"
                exit 1
            }

            # Ensure orchestration module is loaded
            if (-not (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue)) {
                Write-Error "Orchestration module not loaded. Environment initialization may have failed."
                exit 1
            }

            # Use passed Variables parameter or create empty hashtable
            if (-not $Variables) {
                $variables = @{}
            } else {
                $variables = $Variables
            }
            if ($CI) { $variables['CI'] = $true }

            if ($Playbook) {
                $params = @{
                    LoadPlaybook = $Playbook
                    Configuration = $config
                    Variables = $variables
                    DryRun = $DryRun
                }
            if ($PlaybookProfile) {
                    $params['PlaybookProfile'] = $PlaybookProfile
                }
            if ($Sequential) {
                    $params['Parallel'] = $false
                }
            if ($Parallel) {
                    $params['Parallel'] = $true
                }
            $result = Invoke-OrchestrationSequence @params
            } else {
                $result = Invoke-OrchestrationSequence -Sequence $Sequence -Configuration $config -Variables $variables -DryRun:$DryRun
            }

            # Exit with appropriate code
            if ($result.Failed -gt 0) {
                exit 1
            }
    }

        'Validate' {
            & (Join-Path $script:ProjectRoot "automation-scripts/0500_Validate-Environment.ps1") -Configuration $config
        }

        'Deploy' {
            # Ensure orchestration module is loaded
            if (-not (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue)) {
                Write-Error "Orchestration module not loaded. Environment initialization may have failed."
                exit 1
            }

            $result = Invoke-OrchestrationSequence -Sequence "0105,0008,0300" -Configuration $config -DryRun:$DryRun

            if ($result.Failed -gt 0) {
                exit 1
            }
        }

        'Test' {
            # Ensure orchestration module is loaded
            if (-not (Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue)) {
                Write-Error "Orchestration module not loaded. Environment initialization may have failed."
                exit 1
            }

            # Default test sequence - unit tests, PSScriptAnalyzer, and syntax validation
            $testSequence = if ($Sequence) { $Sequence } else { @("0402", "0404", "0407") }

            Write-Host "Running tests with sequence: $($testSequence -join ',')" -ForegroundColor Cyan

            $result = Invoke-OrchestrationSequence -Sequence $testSequence -Configuration $config -DryRun:$DryRun

            if ($result.Failed -gt 0) {
                Write-Host "`nTest run completed with $($result.Failed) failures" -ForegroundColor Red
                exit 1
            } else {
                Write-Host "`nAll tests passed successfully!" -ForegroundColor Green
            }
        }

        'List' {
            if (-not $Target) {
                $Target = 'all'
            }
            Invoke-ModernListAction -ListTarget $Target
        }

        'Search' {
            if (-not $Query) {
                Write-ModernCLI "Search query required. Use -Query <term>" -Type 'Error'
                exit 1
            }
            Invoke-ModernSearchAction -Query $Query
        }

        'Run' {
            if (-not $Target) {
                Write-ModernCLI "Run target required. Use -Target <script|playbook|sequence>" -Type 'Error'
                exit 1
            }
            Invoke-ModernRunAction -RunTarget $Target -ScriptNum $ScriptNumber -PlaybookName $Playbook -SequenceRange $Sequence
        }
    }

} catch {
    $errorMessage = "Fatal error in Start-AitherZero"
    $errorDetails = @{
        Message = $_.Exception.Message
        Type = $_.Exception.GetType().FullName
        StackTrace = $_.ScriptStackTrace
        InvocationInfo = $_.InvocationInfo | ConvertTo-Json -Compress
        TargetObject = $_.TargetObject
    }

    # Try to log if logging is available
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level 'Critical' -Message $errorMessage -Source "Start-AitherZero" -Data $errorDetails
    }

    # Always write to console
    Write-Host "`n[CRITICAL ERROR]" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Location: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Red

    if ($VerbosePreference -eq 'Continue' -or $DebugPreference -eq 'Continue') {
        Write-Host "`nStack Trace:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    }

    exit 1
}