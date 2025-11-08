#Requires -Version 7.0

<#
.SYNOPSIS
    Initialize Infrastructure Git Submodules

.DESCRIPTION
    Initializes Git submodules for infrastructure repositories based on configuration in config.psd1.
    
    This script is part of the infrastructure submodule system where infrastructure-as-code
    is managed as separate Git repositories that are integrated via Git submodules.
    
    By default, this initializes the Aitherium infrastructure repository which provides
    templates for mass deployments across any environment.

.PARAMETER Force
    Force re-initialization of existing submodules.

.PARAMETER UpdateExisting
    Update existing submodules to latest commits.

.PARAMETER Name
    Initialize only the specified submodule by name.

.PARAMETER WhatIf
    Show what would be done without actually doing it.

.EXAMPLE
    ./library/automation-scripts/0109_Initialize-InfrastructureSubmodules.ps1
    Initializes all enabled infrastructure submodules from configuration.

.EXAMPLE
    ./library/automation-scripts/0109_Initialize-InfrastructureSubmodules.ps1 -UpdateExisting
    Initializes new submodules and updates existing ones.

.EXAMPLE
    ./library/automation-scripts/0109_Initialize-InfrastructureSubmodules.ps1 -Name 'aitherium-infrastructure'
    Initializes only the default Aitherium infrastructure submodule.

.NOTES
    File Name      : 0109_Initialize-InfrastructureSubmodules.ps1
    Prerequisite   : PowerShell 7.0+, Git
    Stage          : Environment
    Dependencies   : Git, Infrastructure module
    Tags           : infrastructure, git, submodules, automation
    Version        : 1.0.0
    Author         : AitherZero Team
    
    Configuration:
    Infrastructure submodules are configured in config.psd1 under Infrastructure.Submodules.
    See infrastructure/SUBMODULES.md for complete documentation.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$UpdateExisting,

    [Parameter()]
    [string]$Name
)

#region Setup and Initialization

# Import ScriptUtilities for common functions
$ProjectRoot = if ($env:AITHERZERO_ROOT) { 
    $env:AITHERZERO_ROOT 
} else { 
    $scriptPath = Split-Path -Parent $PSScriptRoot
    $scriptPath = Split-Path -Parent $scriptPath
    $scriptPath
}

$ScriptUtilPath = Join-Path $ProjectRoot "aithercore/automation/ScriptUtilities.psm1"

if (Test-Path $ScriptUtilPath) {
    Import-Module $ScriptUtilPath -Force -ErrorAction SilentlyContinue
}

# Script metadata
$ScriptName = "Initialize-InfrastructureSubmodules"
$Stage = "Environment"

# Logging helper with fallback
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Map Success to Information for logging functions that don't support it
    $logLevel = if ($Level -eq 'Success') { 'Information' } else { $Level }
    
    $color = @{
        'Error' = 'Red'
        'Warning' = 'Yellow'
        'Information' = 'Green'  # Green for info messages
        'Success' = 'Green'
        'Debug' = 'Gray'
    }[$Level]
    
    if (Get-Command Write-ScriptLog -ErrorAction SilentlyContinue) {
        Write-ScriptLog -Message $Message -Level $logLevel
    }
    elseif (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $logLevel -Source $ScriptName
    }
    else {
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

#endregion Setup and Initialization

#region Main Script

try {
    Write-Log -Message "==================================================="
    Write-Log -Message "Initialize Infrastructure Git Submodules"
    Write-Log -Message "==================================================="

    # Check prerequisites
    Write-Log -Message "Checking prerequisites..."
    
    # Check for Git
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log -Message "Git is not installed or not in PATH" -Level 'Error'
        Write-Log -Message "Please install Git: https://git-scm.com/downloads" -Level 'Error'
        exit 1
    }
    Write-Log -Message "✓ Git found: $(git --version)" -Level 'Success'

    # Check if we're in a Git repository
    try {
        $gitRoot = git rev-parse --show-toplevel 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Not in a git repository"
        }
        Write-Log -Message "✓ Git repository: $gitRoot" -Level 'Success'
    }
    catch {
        Write-Log -Message "Not in a Git repository" -Level 'Error'
        Write-Log -Message "This script must be run from within the AitherZero Git repository" -Level 'Error'
        exit 1
    }

    # Check if Infrastructure module is available
    if (-not (Get-Command Initialize-InfrastructureSubmodule -ErrorAction SilentlyContinue)) {
        Write-Log -Message "Infrastructure module not loaded, attempting to load..." -Level 'Warning'
        
        try {
            Import-Module (Join-Path $ProjectRoot "AitherZero.psd1") -Force -ErrorAction Stop
            Write-Log -Message "✓ Infrastructure module loaded" -Level 'Success'
        }
        catch {
            Write-Log -Message "Failed to load Infrastructure module: $($_.Exception.Message)" -Level 'Error'
            Write-Log -Message "Please run bootstrap.ps1 first" -Level 'Error'
            exit 1
        }
    }

    # Load configuration
    Write-Host ""
    Write-Log -Message "Loading configuration..."
    
    try {
        if (Get-Command Get-Configuration -ErrorAction SilentlyContinue) {
            $config = Get-Configuration
            $submoduleConfig = $config.Infrastructure.Submodules
        }
        else {
            # Fallback to direct loading
            $configPath = Join-Path $ProjectRoot "config.psd1"
            $configContent = Get-Content -Path $configPath -Raw
            $scriptBlock = [scriptblock]::Create($configContent)
            $config = & $scriptBlock
            $submoduleConfig = $config.Infrastructure.Submodules
        }
        
        if (-not $submoduleConfig.Enabled) {
            Write-Log -Message "Infrastructure submodules are disabled in configuration" -Level 'Warning'
            Write-Log -Message "Set Infrastructure.Submodules.Enabled = `$true in config.psd1 to enable" -Level 'Warning'
            exit 0
        }
        
        Write-Log -Message "✓ Configuration loaded" -Level 'Success'
        Write-Log -Message "  - Auto-initialize: $($submoduleConfig.AutoInit)" -Level 'Information'
        Write-Log -Message "  - Auto-update: $($submoduleConfig.AutoUpdate)" -Level 'Information'
        Write-Log -Message "  - Recursive init: $($submoduleConfig.Behavior.RecursiveInit)" -Level 'Information'
    }
    catch {
        Write-Log -Message "Failed to load configuration: $($_.Exception.Message)" -Level 'Error'
        exit 1
    }

    # Display configured submodules
    Write-Host ""
    Write-Log -Message "Configured submodules:"
    
    $submoduleCount = 0
    
    if ($submoduleConfig.Default.Enabled) {
        $submoduleCount++
        Write-Log -Message "  [$submoduleCount] Default: $($submoduleConfig.Default.Name)" -Level 'Information'
        Write-Log -Message "      URL: $($submoduleConfig.Default.Url)" -Level 'Information'
        Write-Log -Message "      Path: $($submoduleConfig.Default.Path)" -Level 'Information'
        Write-Log -Message "      Branch: $($submoduleConfig.Default.Branch)" -Level 'Information'
    }
    
    foreach ($key in $submoduleConfig.Repositories.Keys) {
        $repo = $submoduleConfig.Repositories[$key]
        if ($repo.Enabled) {
            $submoduleCount++
            Write-Log -Message "  [$submoduleCount] $key" -Level 'Information'
            Write-Log -Message "      URL: $($repo.Url)" -Level 'Information'
            Write-Log -Message "      Path: $($repo.Path)" -Level 'Information'
            Write-Log -Message "      Branch: $($repo.Branch)" -Level 'Information'
        }
    }
    
    if ($submoduleCount -eq 0) {
        Write-Log -Message "No enabled submodules found in configuration" -Level 'Warning'
        exit 0
    }

    # Initialize submodules
    Write-Host ""
    Write-Log -Message "Initializing infrastructure submodules..."
    Write-Host ""

    try {
        $initParams = @{}
        
        if ($WhatIfPreference) {
            $initParams['WhatIf'] = $true
        }
        
        if ($Force) {
            $initParams['Force'] = $true
        }
        
        if ($Name) {
            $initParams['Name'] = $Name
        }
        
        Initialize-InfrastructureSubmodule @initParams
        
        Write-Host "" 
        Write-Log -Message "✓ Submodule initialization complete" -Level 'Success'
    }
    catch {
        Write-Log -Message "Failed to initialize submodules: $($_.Exception.Message)" -Level 'Error'
        exit 1
    }

    # Update existing submodules if requested
    if ($UpdateExisting) {
        Write-Host ""
        Write-Log -Message "Updating existing submodules..."
        
        try {
            $updateParams = @{}
            
            if ($WhatIfPreference) {
                $updateParams['WhatIf'] = $true
            }
            
            if ($Name) {
                $updateParams['Name'] = $Name
            }
            
            Update-InfrastructureSubmodules @updateParams
            
            Write-Log -Message "✓ Submodule update complete" -Level 'Success'
        }
        catch {
            Write-Log -Message "Failed to update submodules: $($_.Exception.Message)" -Level 'Error'
            exit 1
        }
    }

    # Display final status
    Write-Host ""
    Write-Log -Message "Getting submodule status..."
    Write-Host ""
    
    try {
        Get-InfrastructureSubmodules -Detailed
    }
    catch {
        Write-Log -Message "Failed to get submodule status: $($_.Exception.Message)" -Level 'Warning'
    }

    # Summary
    Write-Host ""
    Write-Log -Message "==================================================="
    Write-Log -Message "Infrastructure Submodule Initialization Summary"
    Write-Log -Message "==================================================="
    Write-Log -Message "✓ Initialized $submoduleCount submodule(s)" -Level 'Success'
    Write-Host ""
    Write-Log -Message "Next steps:" -Level 'Information'
    Write-Log -Message "  1. Review submodule documentation: ./infrastructure/SUBMODULES.md" -Level 'Information'
    Write-Log -Message "  2. Explore infrastructure templates in: ./infrastructure/aitherium/" -Level 'Information'
    Write-Log -Message "  3. Use Invoke-InfrastructurePlan to plan deployments" -Level 'Information'
    Write-Log -Message "  4. Use Invoke-InfrastructureApply to deploy infrastructure" -Level 'Information'
    Write-Host ""
    Write-Log -Message "For more information, see:" -Level 'Information'
    Write-Log -Message "  - ./infrastructure/SUBMODULES.md" -Level 'Information'
    Write-Log -Message "  - ./aithercore/infrastructure/README.md" -Level 'Information'
    Write-Host ""

    exit 0
}
catch {
    Write-Log -Message "Unexpected error: $($_.Exception.Message)" -Level 'Error'
    Write-Log -Message "Stack trace: $($_.ScriptStackTrace)" -Level 'Error'
    exit 1
}

#endregion Main Script
