#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero root module that loads all nested modules
.DESCRIPTION
    Aitherium™ Enterprise Infrastructure Automation Platform
    AitherZero - Imports all modules and re-exports their functions

.NOTES
    Copyright © 2025 Aitherium Corporation
    Version: 1.0.0
#>

# Set environment variables
$env:AITHERZERO_ROOT = $PSScriptRoot
$env:AITHERZERO_INITIALIZED = "1"

# Performance optimization: Skip transcript in test mode or when disabled
# Transcripts add I/O overhead (~50-100ms per operation) and are not needed for:
# - Automated testing (test output is already captured by test frameworks)
# - CI/CD environments (logs are captured by the CI system)
# - When explicitly disabled by the user
$isTestOrCIMode = ($env:AITHERZERO_DISABLE_TRANSCRIPT -eq '1') -or 
                   ($env:AITHERZERO_TEST_MODE) -or 
                   ($env:CI)
$script:TranscriptEnabled = -not $isTestOrCIMode

# Start PowerShell transcription for complete activity logging (if enabled)
if ($script:TranscriptEnabled) {
    $transcriptPath = Join-Path $PSScriptRoot "logs/transcript-$(Get-Date -Format 'yyyy-MM-dd').log"
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

# Add automation scripts to PATH
$automationPath = Join-Path $PSScriptRoot "automation-scripts"
$pathSeparator = [IO.Path]::PathSeparator
if ($env:PATH -notlike "*$automationPath*") {
    $env:PATH = "$automationPath$pathSeparator$env:PATH"
}

# Import all nested modules and re-export their functions
$modulesToLoad = @(
    # Core utilities first
    './aithercore/utilities/Logging.psm1',

    # Configuration (both old and new for backward compatibility)
    './aithercore/configuration/Configuration.psm1',
    './aithercore/configuration/ConfigManager.psm1',

    # CLI Module (NEW - loads after configuration)
    './aithercore/cli/AitherZeroCLI.psm1',

    # Development tools
    './aithercore/development/GitAutomation.psm1',
    './aithercore/development/IssueTracker.psm1',
    './aithercore/development/PullRequestManager.psm1',

    # Testing (Legacy and New)
    './aithercore/testing/TestingFramework.psm1',
    './aithercore/testing/AitherTestFramework.psm1',
    './aithercore/testing/CoreTestSuites.psm1',

    # Reporting
    './aithercore/reporting/ReportingEngine.psm1',
    './aithercore/reporting/TechDebtAnalysis.psm1',

    # Automation (exports Invoke-OrchestrationSequence)
    './aithercore/automation/OrchestrationEngine.psm1',
    './aithercore/automation/GitHubWorkflowParser.psm1',
    './aithercore/automation/DeploymentAutomation.psm1',
    './aithercore/automation/ScriptUtilities.psm1',

    # Infrastructure
    './aithercore/infrastructure/Infrastructure.psm1',
    
    # Security
    './aithercore/security/Security.psm1',
    
    # Documentation
    './aithercore/documentation/DocumentationEngine.psm1',
    './aithercore/documentation/ProjectIndexer.psm1'
)

# Parallel module loading for better performance
$jobs = @()
$loadedModules = [System.Collections.Concurrent.ConcurrentBag[string]]::new()

# Performance tracking (only in debug mode)
$script:ModuleLoadTiming = @{}
$script:LoadStartTime = Get-Date

# Load critical modules first (synchronously)
$criticalModules = @(
    './aithercore/utilities/Logging.psm1',
    './aithercore/configuration/Configuration.psm1',
    './aithercore/configuration/ConfigManager.psm1'
)

foreach ($modulePath in $criticalModules) {
    $fullPath = Join-Path $PSScriptRoot $modulePath
    if (Test-Path $fullPath) {
        try {
            $moduleLoadStart = Get-Date
            # Import without -Global to keep functions in this module's scope
            Import-Module $fullPath -Force -ErrorAction Stop
            
            # Track timing in debug mode
            if ($env:AITHERZERO_DEBUG) {
                $script:ModuleLoadTiming[$modulePath] = ((Get-Date) - $moduleLoadStart).TotalMilliseconds
            }
        } catch {
            Write-Error "Failed to load critical module: $modulePath - $_"
        }
    }
}

# Load remaining modules sequentially (parallel loading doesn't work well with module scope)
$parallelModules = $modulesToLoad | Where-Object { $_ -notin $criticalModules }

foreach ($modulePath in $parallelModules) {
    $fullPath = Join-Path $PSScriptRoot $modulePath
    if (Test-Path $fullPath) {
        try {
            $moduleLoadStart = Get-Date
            # Import without -Global to keep functions in this module's scope
            Import-Module $fullPath -Force -ErrorAction Stop
            
            # Track timing in debug mode
            if ($env:AITHERZERO_DEBUG) {
                $script:ModuleLoadTiming[$modulePath] = ((Get-Date) - $moduleLoadStart).TotalMilliseconds
            }
        } catch {
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level 'Warning' -Message "Failed to load module: $modulePath" -Source "ModuleLoader" -Data @{ Error = $_.ToString() }
            } else {
                Write-Warning "Failed to load module: $modulePath - $_"
            }
        }
    }
}

# Report module loading performance in debug mode
if ($env:AITHERZERO_DEBUG) {
    $totalLoadTime = ((Get-Date) - $script:LoadStartTime).TotalMilliseconds
    Write-Host "Module loading completed in $([Math]::Round($totalLoadTime, 2))ms" -ForegroundColor Cyan
    
    # Show top 5 slowest modules
    $slowest = $script:ModuleLoadTiming.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
    if ($slowest) {
        Write-Host "Slowest modules:" -ForegroundColor Yellow
        foreach ($module in $slowest) {
            Write-Host "  $($module.Key): $([Math]::Round($module.Value, 2))ms" -ForegroundColor Gray
        }
    }
}

# Note: Invoke-AitherScript is now provided by AitherZeroCLI module
# The CLI module provides a comprehensive implementation with proper help,
# pipeline support, and all QOL features. No duplicate definition needed here.

# Set up aliases (CLI module exports the function)
Set-Alias -Name 'az' -Value 'Invoke-AitherScript' -Force

# Initialize config manager if available
if (Get-Command Initialize-ConfigManager -ErrorAction SilentlyContinue) {
    try {
        Initialize-ConfigManager
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Config manager initialized" -Level 'Information' -Source "AitherZero"
        }
    } catch {
        if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Failed to initialize config manager: $_" -Level 'Warning' -Source "AitherZero"
        }
    }
}

# Note: We do NOT use Export-ModuleMember here. When omitted, PowerShell automatically
# exports all functions and aliases defined in the module. The nested modules are imported
# into this module's scope (not global), so their functions become part of this module.
# The .psd1 manifest's FunctionsToExport list controls what is ultimately exported.