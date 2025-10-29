#Requires -Version 7.0
<#
.SYNOPSIS
    AitherCore - Essential modules for basic releases
.DESCRIPTION
    Consolidated core modules providing minimal foundation functionality:
    - Logging (centralized logging system)
    - Configuration (configuration management)
    - TextUtilities (text formatting)
    - BetterMenu (interactive menus)
    - UserInterface (unified UI system)
    - Infrastructure (infrastructure essentials)
    - Security (security and credentials)
    - OrchestrationEngine (script orchestration)

.NOTES
    Copyright © 2025 Aitherium Corporation
    Version: 1.0.0
#>

# Set environment variables
$env:AITHERCORE_ROOT = $PSScriptRoot
$env:AITHERCORE_INITIALIZED = "1"

# Set project root if not already set
if (-not $env:AITHERZERO_ROOT) {
    $env:AITHERZERO_ROOT = Split-Path $PSScriptRoot -Parent
}

# Transcript logging configuration (can be disabled via environment variable)
$script:TranscriptEnabled = if ($env:AITHERCORE_DISABLE_TRANSCRIPT -eq '1') { $false } else { $true }

# Start PowerShell transcription for complete activity logging (if enabled)
if ($script:TranscriptEnabled) {
    $transcriptPath = Join-Path $env:AITHERZERO_ROOT "logs/transcript-aithercore-$(Get-Date -Format 'yyyy-MM-dd').log"
    $logsDir = Split-Path $transcriptPath -Parent
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    try {
        # Try to start transcript, stop any existing one first
        try { Stop-Transcript -ErrorAction Stop | Out-Null } catch { }
        Start-Transcript -Path $transcriptPath -Append -IncludeInvocationHeader | Out-Null
    } catch {
        # Transcript functionality not available or failed
    }
}

# Load modules in dependency order
$modulesToLoad = @(
    # Core utilities (no dependencies)
    'TextUtilities.psm1',
    'Logging.psm1',
    
    # Configuration (optional Logging dependency)
    'Configuration.psm1',
    
    # User interface (depends on TextUtilities, Configuration)
    'BetterMenu.psm1',
    'UserInterface.psm1',
    
    # Infrastructure and Security (depend on Logging)
    'Infrastructure.psm1',
    'Security.psm1',
    
    # Orchestration (depends on Logging, Configuration)
    'OrchestrationEngine.psm1'
)

# Load all modules sequentially
foreach ($moduleName in $modulesToLoad) {
    $modulePath = Join-Path $PSScriptRoot $moduleName
    if (Test-Path $modulePath) {
        try {
            Import-Module $modulePath -Force -ErrorAction Stop
        } catch {
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level 'Warning' -Message "Failed to load aithercore module: $moduleName" -Source "AitherCore" -Data @{ Error = $_.ToString() }
            } else {
                Write-Warning "Failed to load aithercore module: $moduleName - $_"
            }
        }
    } else {
        Write-Warning "AitherCore module not found: $modulePath"
    }
}

# Note: We do NOT use Export-ModuleMember here. When omitted, PowerShell automatically
# exports all functions and aliases defined in the module. The nested modules are imported
# into this module's scope, so their functions become part of this module.
# The .psd1 manifest's FunctionsToExport list controls what is ultimately exported.
