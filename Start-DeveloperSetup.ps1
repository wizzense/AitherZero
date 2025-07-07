#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Quick launcher for AitherZero developer setup
    
.DESCRIPTION
    Convenient wrapper to run the unified developer setup command.
    This script imports the necessary modules and launches Start-DeveloperSetup.
    
.PARAMETER Profile
    Development profile to install (Quick, Standard, Full, Custom)
    
.PARAMETER SkipPrerequisites
    Skip prerequisite checks
    
.PARAMETER SkipAITools
    Skip AI development tools installation
    
.PARAMETER SkipVSCode
    Skip VS Code configuration
    
.PARAMETER SkipGitHooks
    Skip Git hooks installation
    
.PARAMETER Force
    Force reinstallation of existing components
    
.EXAMPLE
    ./Start-DeveloperSetup.ps1
    # Standard developer setup
    
.EXAMPLE
    ./Start-DeveloperSetup.ps1 -Profile Full
    # Full developer setup with all tools
    
.EXAMPLE
    ./Start-DeveloperSetup.ps1 -Profile Quick -SkipAITools
    # Quick setup without AI tools
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Quick', 'Standard', 'Full', 'Custom')]
    [string]$Profile = 'Standard',
    
    [Parameter()]
    [switch]$SkipPrerequisites,
    
    [Parameter()]
    [switch]$SkipAITools,
    
    [Parameter()]
    [switch]$SkipVSCode,
    
    [Parameter()]
    [switch]$SkipGitHooks,
    
    [Parameter()]
    [switch]$Force
)

# Set error handling
$ErrorActionPreference = 'Stop'

try {
    # Find project root
    $scriptRoot = $PSScriptRoot
    if (-not $scriptRoot) { $scriptRoot = Get-Location }
    
    # Import required modules
    Write-Host "Loading AitherZero modules..." -ForegroundColor Cyan
    
    $devEnvPath = Join-Path $scriptRoot "aither-core/modules/DevEnvironment"
    $aiToolsPath = Join-Path $scriptRoot "aither-core/modules/AIToolsIntegration"
    
    if (Test-Path $devEnvPath) {
        Import-Module $devEnvPath -Force
    } else {
        throw "DevEnvironment module not found at: $devEnvPath"
    }
    
    if (Test-Path $aiToolsPath) {
        Import-Module $aiToolsPath -Force
    }
    
    # Check if the function exists
    if (-not (Get-Command Start-DeveloperSetup -ErrorAction SilentlyContinue)) {
        throw "Start-DeveloperSetup function not found. Please ensure DevEnvironment module is properly installed."
    }
    
    # Run the developer setup
    $setupParams = @{
        Profile = $Profile
        SkipPrerequisites = $SkipPrerequisites
        SkipAITools = $SkipAITools
        SkipVSCode = $SkipVSCode
        SkipGitHooks = $SkipGitHooks
        Force = $Force
    }
    
    Start-DeveloperSetup @setupParams
    
} catch {
    Write-Error "Developer setup failed: $_"
    exit 1
}