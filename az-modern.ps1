#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Modern CLI - Smooth as Butter Interface
.DESCRIPTION
    A completely redesigned CLI interface for AitherZero that provides:
    - Intuitive command patterns (az <action> <target> --options)
    - Interactive navigation with fuzzy search
    - Full scriptability for CI/CD workflows
    - Consistent UX across all operations
    - Real-time feedback and progress
    - Zero-config setup

.PARAMETER Action
    The action to perform (run, list, show, search, config, menu, help)

.PARAMETER Target
    The target for the action (script, playbook, sequence, etc.)

.PARAMETER Arguments
    Additional arguments for the action

.EXAMPLE
    # Interactive usage
    ./az-modern.ps1
    
.EXAMPLE
    # Run a specific script
    ./az-modern.ps1 run script 0402
    
.EXAMPLE  
    # List all playbooks
    ./az-modern.ps1 list playbooks
    
.EXAMPLE
    # Search for test-related items
    ./az-modern.ps1 search test
    
.EXAMPLE
    # Interactive playbook selection
    ./az-modern.ps1 run playbook
    
.EXAMPLE
    # CI/CD usage
    ./az-modern.ps1 run sequence 0400-0499 --no-interactive
#>

[CmdletBinding()]
param(
    [string]$Action,
    [string]$Target,
    [string[]]$Arguments = @()
)

# Setup
$ErrorActionPreference = 'Stop'
$script:ProjectRoot = $PSScriptRoot

# Ensure AitherZero is loaded
try {
    if (-not $env:AITHERZERO_INITIALIZED) {
        $moduleManifest = Join-Path $script:ProjectRoot "AitherZero.psd1"
        if (Test-Path $moduleManifest) {
            Import-Module $moduleManifest -Force -Global
        }
    }
} catch {
    Write-Warning "Could not load AitherZero module: $_"
}

# Load the modern CLI module
$modernCliPath = Join-Path $script:ProjectRoot "domains/experience/ModernCLI.psm1"
if (-not (Test-Path $modernCliPath)) {
    Write-Error "Modern CLI module not found: $modernCliPath"
    exit 1
}

Import-Module $modernCliPath -Force

# Build arguments array from parameters and remaining args
$allArgs = @()
if ($Action) { $allArgs += $Action }
if ($Target) { $allArgs += $Target }
$allArgs += $Arguments

# If no arguments provided, check if we're in interactive mode
if ($allArgs.Count -eq 0) {
    if ([Environment]::UserInteractive -and (-not $env:CI)) {
        # Show interactive help and prompt for command
        Clear-Host
        
        Write-Host "🚀 " -ForegroundColor Cyan -NoNewline
        Write-Host "AitherZero Modern CLI" -ForegroundColor White
        Write-Host "=" * 50 -ForegroundColor DarkCyan
        Write-Host ""
        
        Write-Host "Quick Start:" -ForegroundColor Yellow
        Write-Host "  az-modern run script 0402       " -ForegroundColor Gray -NoNewline
        Write-Host "# Run unit tests" -ForegroundColor DarkGray
        Write-Host "  az-modern run playbook           " -ForegroundColor Gray -NoNewline  
        Write-Host "# Interactive playbook selection" -ForegroundColor DarkGray
        Write-Host "  az-modern list scripts           " -ForegroundColor Gray -NoNewline
        Write-Host "# List all automation scripts" -ForegroundColor DarkGray
        Write-Host "  az-modern search security        " -ForegroundColor Gray -NoNewline
        Write-Host "# Find security-related items" -ForegroundColor DarkGray
        Write-Host "  az-modern menu                   " -ForegroundColor Gray -NoNewline
        Write-Host "# Legacy menu mode" -ForegroundColor DarkGray
        Write-Host ""
        
        # Interactive command prompt
        while ($true) {
            Write-Host "az-modern> " -ForegroundColor Cyan -NoNewline
            $input = Read-Host
            
            if ([string]::IsNullOrWhiteSpace($input)) {
                continue
            }
            
            if ($input -eq 'exit' -or $input -eq 'quit' -or $input -eq 'q') {
                Write-Host "Goodbye! 👋" -ForegroundColor Green
                break
            }
            
            if ($input -eq 'help' -or $input -eq 'h') {
                Invoke-ModernCLI -Arguments @('help')
                continue
            }
            
            # Parse the input
            $inputArgs = $input -split '\s+' | Where-Object { $_ }
            
            try {
                Invoke-ModernCLI -Arguments $inputArgs
            } catch {
                Write-Host "Error: $_" -ForegroundColor Red
            }
            
            Write-Host ""
        }
    } else {
        # Non-interactive - show help
        Invoke-ModernCLI -Arguments @('help')
    }
} else {
    # Execute the command
    try {
        Invoke-ModernCLI -Arguments $allArgs
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
        exit 1
    }
}