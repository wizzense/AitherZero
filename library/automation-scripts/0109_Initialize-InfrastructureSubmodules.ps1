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
else { $Level }
    
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
    Write-ScriptLog -Message "==================================================="
    Write-ScriptLog -Message "Initialize Infrastructure Git Submodules"
    Write-ScriptLog -Message "==================================================="

    # Check prerequisites
    Write-ScriptLog -Message "Checking prerequisites..."
    
    # Check for Git
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-ScriptLog -Message "Git is not installed or not in PATH" -Level 'Error'
        Write-ScriptLog -Message "Please install Git: https://git-scm.com/downloads" -Level 'Error'
        exit 1
    }
    Write-ScriptLog -Message "✓ Git found: $(git --version)" -Level Information

    # Check if we're in a Git repository
    try {
        $gitRoot = git rev-parse --show-toplevel 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Not in a git repository"
        }
        Write-ScriptLog -Message "✓ Git repository: $gitRoot" -Level Information
    }
    catch {
        Write-ScriptLog -Message "Not in a Git repository" -Level 'Error'
        Write-ScriptLog -Message "This script must be run from within the AitherZero Git repository" -Level 'Error'
        exit 1
    }

    # Check if Infrastructure module is available
    if (-not (Get-Command Initialize-InfrastructureSubmodule -ErrorAction SilentlyContinue)) {
        Write-ScriptLog -Message "Infrastructure module not loaded, attempting to load..." -Level 'Warning'
        
        try {
            Import-Module (Join-Path $ProjectRoot "AitherZero.psd1") -Force -ErrorAction Stop
            Write-ScriptLog -Message "✓ Infrastructure module loaded" -Level Information
        }
        catch {
            Write-ScriptLog -Message "Failed to load Infrastructure module: $($_.Exception.Message)" -Level 'Error'
            Write-ScriptLog -Message "Please run bootstrap.ps1 first" -Level 'Error'
            exit 1
        }
    }

    # Load configuration
    Write-Host ""
    Write-ScriptLog -Message "Loading configuration..."
    
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
            Write-ScriptLog -Message "Infrastructure submodules are disabled in configuration" -Level 'Warning'
            Write-ScriptLog -Message "Set Infrastructure.Submodules.Enabled = `$true in config.psd1 to enable" -Level 'Warning'
            exit 0
        }
        
        Write-ScriptLog -Message "✓ Configuration loaded" -Level Information
        Write-ScriptLog -Message "  - Auto-initialize: $($submoduleConfig.AutoInit)" -Level 'Information'
        Write-ScriptLog -Message "  - Auto-update: $($submoduleConfig.AutoUpdate)" -Level 'Information'
        Write-ScriptLog -Message "  - Recursive init: $($submoduleConfig.Behavior.RecursiveInit)" -Level 'Information'
    }
    catch {
        Write-ScriptLog -Message "Failed to load configuration: $($_.Exception.Message)" -Level 'Error'
        exit 1
    }

    # Display configured submodules
    Write-Host ""
    Write-ScriptLog -Message "Configured submodules:"
    
    $submoduleCount = 0
    
    if ($submoduleConfig.Default.Enabled) {
        $submoduleCount++
        Write-ScriptLog -Message "  [$submoduleCount] Default: $($submoduleConfig.Default.Name)" -Level 'Information'
        Write-ScriptLog -Message "      URL: $($submoduleConfig.Default.Url)" -Level 'Information'
        Write-ScriptLog -Message "      Path: $($submoduleConfig.Default.Path)" -Level 'Information'
        Write-ScriptLog -Message "      Branch: $($submoduleConfig.Default.Branch)" -Level 'Information'
    }
    
    foreach ($key in $submoduleConfig.Repositories.Keys) {
        $repo = $submoduleConfig.Repositories[$key]
        if ($repo.Enabled) {
            $submoduleCount++
            Write-ScriptLog -Message "  [$submoduleCount] $key" -Level 'Information'
            Write-ScriptLog -Message "      URL: $($repo.Url)" -Level 'Information'
            Write-ScriptLog -Message "      Path: $($repo.Path)" -Level 'Information'
            Write-ScriptLog -Message "      Branch: $($repo.Branch)" -Level 'Information'
        }
    }
    
    if ($submoduleCount -eq 0) {
        Write-ScriptLog -Message "No enabled submodules found in configuration" -Level 'Warning'
        exit 0
    }

    # Initialize submodules
    Write-Host ""
    Write-ScriptLog -Message "Initializing infrastructure submodules..."
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
        Write-ScriptLog -Message "✓ Submodule initialization complete" -Level Information
    }
    catch {
        Write-ScriptLog -Message "Failed to initialize submodules: $($_.Exception.Message)" -Level 'Error'
        exit 1
    }

    # Update existing submodules if requested
    if ($UpdateExisting) {
        Write-Host ""
        Write-ScriptLog -Message "Updating existing submodules..."
        
        try {
            $updateParams = @{}
            
            if ($WhatIfPreference) {
                $updateParams['WhatIf'] = $true
            }
            
            if ($Name) {
                $updateParams['Name'] = $Name
            }
            
            Update-InfrastructureSubmodule @updateParams
            
            Write-ScriptLog -Message "✓ Submodule update complete" -Level Information
        }
        catch {
            Write-ScriptLog -Message "Failed to update submodules: $($_.Exception.Message)" -Level 'Error'
            exit 1
        }
    }

    # Display final status
    Write-Host ""
    Write-ScriptLog -Message "Getting submodule status..."
    Write-Host ""
    
    try {
        Get-InfrastructureSubmodule -Detailed
    }
    catch {
        Write-ScriptLog -Message "Failed to get submodule status: $($_.Exception.Message)" -Level 'Warning'
    }

    # Summary
    Write-Host ""
    Write-ScriptLog -Message "==================================================="
    Write-ScriptLog -Message "Infrastructure Submodule Initialization Summary"
    Write-ScriptLog -Message "==================================================="
    Write-ScriptLog -Message "✓ Initialized $submoduleCount submodule(s)" -Level Information
    Write-Host ""
    Write-ScriptLog -Message "Next steps:" -Level 'Information'
    Write-ScriptLog -Message "  1. Review submodule documentation: ./infrastructure/SUBMODULES.md" -Level 'Information'
    Write-ScriptLog -Message "  2. Explore infrastructure templates in: ./infrastructure/aitherium/" -Level 'Information'
    Write-ScriptLog -Message "  3. Use Invoke-InfrastructurePlan to plan deployments" -Level 'Information'
    Write-ScriptLog -Message "  4. Use Invoke-InfrastructureApply to deploy infrastructure" -Level 'Information'
    Write-Host ""
    Write-ScriptLog -Message "For more information, see:" -Level 'Information'
    Write-ScriptLog -Message "  - ./infrastructure/SUBMODULES.md" -Level 'Information'
    Write-ScriptLog -Message "  - ./aithercore/infrastructure/README.md" -Level 'Information'
    Write-Host ""

    exit 0
}
catch {
    Write-ScriptLog -Message "Unexpected error: $($_.Exception.Message)" -Level 'Error'
    Write-ScriptLog -Message "Stack trace: $($_.ScriptStackTrace)" -Level 'Error'
    exit 1
}

#endregion Main Script
