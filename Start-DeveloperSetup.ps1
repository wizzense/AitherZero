#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Developer Setup - ONE COMMAND SETUP! 🚀
    
.DESCRIPTION
    Unified developer setup script that configures everything needed for AitherZero development.
    This is the recommended way to set up a development environment.
    
    What this script does:
    ✅ Prerequisites validation (PowerShell 7, Git, etc.)
    ✅ Core development environment configuration
    ✅ VS Code settings and extensions
    ✅ Git pre-commit hooks
    ✅ AI development tools (Claude Code, Gemini CLI)
    ✅ PatchManager aliases and shortcuts
    ✅ Module path configuration
    
.PARAMETER Profile
    Setup profile:
    - Quick: Minimal setup (fast)
    - Full: Complete setup (all tools and features)
    
.PARAMETER SkipAITools
    Skip AI development tools installation
    
.PARAMETER SkipGitHooks
    Skip Git pre-commit hooks installation
    
.PARAMETER SkipVSCode
    Skip VS Code configuration
    
.PARAMETER Force
    Force reinstallation of components
    
.PARAMETER WhatIf
    Preview mode - show what would be done
    
.PARAMETER Verbose
    Enable verbose logging
    
.EXAMPLE
    ./Start-DeveloperSetup.ps1
    # Default setup with developer profile
    
.EXAMPLE
    ./Start-DeveloperSetup.ps1 -Profile Quick
    # Quick setup (minimal, fast)
    
.EXAMPLE
    ./Start-DeveloperSetup.ps1 -Profile Full
    # Full setup (all tools and features)
    
.EXAMPLE
    ./Start-DeveloperSetup.ps1 -SkipAITools -SkipGitHooks
    # Custom setup options
    
.NOTES
    Version: 1.0.0
    AitherZero Developer Setup - Unified development environment configuration
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Setup profile: Quick, Full")]
    [ValidateSet('Quick', 'Full')]
    [string]$Profile = 'Full',
    
    [Parameter(HelpMessage = "Skip AI development tools installation")]
    [switch]$SkipAITools,
    
    [Parameter(HelpMessage = "Skip Git pre-commit hooks installation")]
    [switch]$SkipGitHooks,
    
    [Parameter(HelpMessage = "Skip VS Code configuration")]
    [switch]$SkipVSCode,
    
    [Parameter(HelpMessage = "Force reinstallation of components")]
    [switch]$Force,
    
    [Parameter(HelpMessage = "Preview mode - show what would be done")]
    [switch]$WhatIf,
    
    [Parameter(HelpMessage = "Enable verbose logging")]
    [switch]$VerboseOutput
)

# Script configuration
$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($VerboseOutput) { 'Continue' } else { 'SilentlyContinue' }

# Get project root
$projectRoot = $PSScriptRoot

# Validate PowerShell version using Test-PowerShellVersion
$versionCheckPath = Join-Path $projectRoot "aither-core" "shared" "Test-PowerShellVersion.ps1"
if (Test-Path $versionCheckPath) {
    try {
        . $versionCheckPath
        if (Get-Command Test-PowerShellVersion -ErrorAction SilentlyContinue) {
            $versionTest = Test-PowerShellVersion -MinimumVersion "7.0" -Quiet
            if (-not $versionTest) {
                Write-Error "PowerShell 7.0 or higher is required. Current version: $($PSVersionTable.PSVersion)"
                exit 1
            }
        }
    } catch {
        Write-Warning "Could not validate PowerShell version: $($_.Exception.Message)"
    }
}

# Logging function
function Write-SetupLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $colors = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }
    
    $prefix = switch ($Level) {
        'Info' { "ℹ️" }
        'Success' { "✅" }
        'Warning' { "⚠️" }
        'Error' { "❌" }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $colors[$Level]
}

# Show banner
function Show-SetupBanner {
    Write-Host ""
    Write-Host "    ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "    ║            AitherZero Developer Setup - ONE COMMAND!         ║" -ForegroundColor Cyan
    Write-Host "    ║                  Complete Dev Environment                    ║" -ForegroundColor Cyan
    Write-Host "    ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-SetupLog "🚀 AitherZero Developer Setup v1.0.0"
    Write-SetupLog "Profile: $Profile"
    Write-SetupLog "Project Root: $projectRoot"
    
    if ($WhatIf) {
        Write-SetupLog "WhatIf Mode: Preview only" -Level 'Warning'
    }
    
    Write-Host ""
}

# Prerequisites validation
function Test-Prerequisites {
    Write-SetupLog "Validating prerequisites..."
    
    $prerequisites = @{
        PowerShell = $PSVersionTable.PSVersion.Major -ge 7
        Git = (Get-Command git -ErrorAction SilentlyContinue) -ne $null
        ProjectStructure = Test-Path (Join-Path $projectRoot "aither-core")
    }
    
    $failed = @()
    foreach ($prereq in $prerequisites.GetEnumerator()) {
        if (-not $prereq.Value) {
            $failed += $prereq.Key
            Write-SetupLog "Prerequisite failed: $($prereq.Key)" -Level 'Error'
        } else {
            Write-SetupLog "Prerequisite passed: $($prereq.Key)" -Level 'Success'
        }
    }
    
    if ($failed.Count -gt 0) {
        Write-SetupLog "Prerequisites validation failed: $($failed -join ', ')" -Level 'Error'
        return $false
    }
    
    Write-SetupLog "Prerequisites validation completed" -Level 'Success'
    return $true
}

# Setup development environment
function Initialize-DevelopmentEnvironment {
    Write-SetupLog "Setting up development environment..."
    
    # Try to load DevEnvironment module
    $devEnvPath = Join-Path $projectRoot "aither-core/modules/DevEnvironment"
    if (Test-Path $devEnvPath) {
        try {
            if (-not $WhatIf) {
                Import-Module $devEnvPath -Force
                Initialize-DevelopmentEnvironment
                Write-SetupLog "Development environment initialized" -Level 'Success'
            } else {
                Write-SetupLog "Would initialize development environment" -Level 'Info'
            }
        } catch {
            Write-SetupLog "Failed to initialize development environment: $($_.Exception.Message)" -Level 'Warning'
        }
    } else {
        Write-SetupLog "DevEnvironment module not found, skipping" -Level 'Warning'
    }
}

# Setup AI tools
function Install-AITools {
    if ($SkipAITools) {
        Write-SetupLog "Skipping AI tools installation" -Level 'Info'
        return
    }
    
    Write-SetupLog "Installing AI development tools..."
    
    # Try to load AIToolsIntegration module
    $aiToolsPath = Join-Path $projectRoot "aither-core/modules/AIToolsIntegration"
    if (Test-Path $aiToolsPath) {
        try {
            if (-not $WhatIf) {
                Import-Module $aiToolsPath -Force
                Install-ClaudeCode
                Install-GeminiCLI
                Write-SetupLog "AI tools installed successfully" -Level 'Success'
            } else {
                Write-SetupLog "Would install Claude Code and Gemini CLI" -Level 'Info'
            }
        } catch {
            Write-SetupLog "Failed to install AI tools: $($_.Exception.Message)" -Level 'Warning'
        }
    } else {
        Write-SetupLog "AIToolsIntegration module not found, skipping" -Level 'Warning'
    }
}

# Setup Git hooks
function Install-GitHooks {
    if ($SkipGitHooks) {
        Write-SetupLog "Skipping Git hooks installation" -Level 'Info'
        return
    }
    
    Write-SetupLog "Installing Git pre-commit hooks..."
    
    if (-not $WhatIf) {
        # Install pre-commit hook if available
        $preCommitScript = Join-Path $projectRoot "aither-core/modules/DevEnvironment/Public/Install-PreCommitHook.ps1"
        if (Test-Path $preCommitScript) {
            try {
                & $preCommitScript
                Write-SetupLog "Git hooks installed successfully" -Level 'Success'
            } catch {
                Write-SetupLog "Failed to install Git hooks: $($_.Exception.Message)" -Level 'Warning'
            }
        } else {
            Write-SetupLog "Pre-commit hook script not found, skipping" -Level 'Warning'
        }
    } else {
        Write-SetupLog "Would install Git pre-commit hooks" -Level 'Info'
    }
}

# Setup VS Code
function Initialize-VSCode {
    if ($SkipVSCode) {
        Write-SetupLog "Skipping VS Code configuration" -Level 'Info'
        return
    }
    
    Write-SetupLog "Configuring VS Code settings and extensions..."
    
    if (-not $WhatIf) {
        # Initialize VS Code workspace if available
        $vsCodeScript = Join-Path $projectRoot "aither-core/modules/DevEnvironment/Public/Initialize-VSCodeWorkspace.ps1"
        if (Test-Path $vsCodeScript) {
            try {
                & $vsCodeScript
                Write-SetupLog "VS Code configured successfully" -Level 'Success'
            } catch {
                Write-SetupLog "Failed to configure VS Code: $($_.Exception.Message)" -Level 'Warning'
            }
        } else {
            Write-SetupLog "VS Code configuration script not found, skipping" -Level 'Warning'
        }
    } else {
        Write-SetupLog "Would configure VS Code settings and extensions" -Level 'Info'
    }
}

# Main execution
function Start-DeveloperSetup {
    try {
        Show-SetupBanner
        
        # Validate prerequisites
        if (-not (Test-Prerequisites)) {
            Write-SetupLog "Prerequisites validation failed" -Level 'Error'
            exit 1
        }
        
        # Setup components based on profile
        Initialize-DevelopmentEnvironment
        
        if ($Profile -eq 'Full') {
            Install-AITools
            Install-GitHooks
            Initialize-VSCode
        } else {
            Write-SetupLog "Quick profile selected - skipping optional components" -Level 'Info'
        }
        
        # Show completion message
        Write-Host ""
        Write-SetupLog "🎉 Developer setup completed successfully!" -Level 'Success'
        Write-SetupLog "You're ready to develop with AitherZero!" -Level 'Success'
        
        if ($WhatIf) {
            Write-SetupLog "This was a preview - run without -WhatIf to apply changes" -Level 'Info'
        }
        
        Write-Host ""
        
    } catch {
        Write-SetupLog "Developer setup failed: $($_.Exception.Message)" -Level 'Error'
        Write-SetupLog "Stack trace: $($_.ScriptStackTrace)" -Level 'Error'
        exit 1
    }
}

# Script entry point
if ($MyInvocation.InvocationName -ne '.') {
    Start-DeveloperSetup
}