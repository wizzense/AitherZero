#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Core application runner for AitherZero Infrastructure Automation - Domain Architecture Version

.DESCRIPTION
    Main runner script that orchestrates infrastructure setup, configuration, and script execution
    using the new domain-based architecture.

.PARAMETER Auto
    Run in automatic mode without prompts

.PARAMETER Scripts
    Specific scripts to run

.PARAMETER Setup
    Run first-time setup wizard

.PARAMETER InstallationProfile
    Installation profile: minimal, developer, full, or interactive

.PARAMETER WhatIf
    Preview mode - show what would be done

.PARAMETER Help
    Show help information

.PARAMETER NonInteractive
    Run in non-interactive mode, suppress prompts and user input

.PARAMETER Quiet
    Run in quiet mode with minimal output

.PARAMETER Verbosity
    Set verbosity level: silent, normal, detailed

.PARAMETER ConfigFile
    Path to configuration file

.PARAMETER Force
    Force operations even if validations fail

.EXAMPLE
    ./aither-core-domain-fixed.ps1

.EXAMPLE
    ./aither-core-domain-fixed.ps1 -Setup -InstallationProfile developer
#>

[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
    [switch]$Auto,
    [string]$Scripts,
    [switch]$Setup,
    [ValidateSet("minimal", "developer", "full", "interactive")]
    [string]$InstallationProfile = "interactive",
    [switch]$PreviewMode,
    [switch]$Help,
    [switch]$NonInteractive,
    [switch]$Quiet,
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',
    [string]$ConfigFile,
    [switch]$Force
)

# Global error handling
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

try {
    # Handle help request
    if ($Help) {
        Write-Host @"
AitherZero Infrastructure Automation - Domain Architecture

This script uses the new domain-based architecture with 6 consolidated domains:
• Infrastructure: Lab automation, OpenTofu deployment, ISO management, monitoring
• Security: Credential management, security automation
• Configuration: Environment switching, configuration repositories
• Utilities: AI tools, version management, maintenance
• Experience: Setup wizards, progress tracking
• Automation: Script management, workflow orchestration

Usage:
  ./aither-core-domain-fixed.ps1                    # Interactive mode
  ./aither-core-domain-fixed.ps1 -Setup             # First-time setup
  ./aither-core-domain-fixed.ps1 -Auto              # Automatic mode
  ./aither-core-domain-fixed.ps1 -Scripts "config"  # Specific functionality

Available Functions: 196+ functions across 6 domains
See FUNCTION-INDEX.md for complete catalog.
"@
        exit 0
    }

    # Initialize environment
    . "$PSScriptRoot/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    $env:PROJECT_ROOT = $projectRoot

    Write-Host "🚀 AitherZero - Domain Architecture" -ForegroundColor Cyan
    Write-Host "   Loading 6 domains with 196+ functions..." -ForegroundColor Gray

    # Load AitherCore orchestration system
    try {
        Import-Module "$PSScriptRoot/AitherCore.psm1" -Force
        Write-Host "   ✅ Domain orchestration loaded" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️  Orchestration warning: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   Attempting direct domain loading..." -ForegroundColor Gray
        
        # Fallback: Load domains directly
        $domains = @('configuration', 'experience', 'utilities', 'infrastructure', 'security', 'automation')
        $loadedDomains = 0
        
        foreach ($domain in $domains) {
            try {
                . "$PSScriptRoot/domains/$domain/$($domain.Substring(0,1).ToUpper() + $domain.Substring(1)).ps1"
                $loadedDomains++
                Write-Host "   ✅ $domain domain loaded" -ForegroundColor Green
            } catch {
                Write-Host "   ⚠️  $domain domain: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        Write-Host "   📊 Loaded $loadedDomains/$($domains.Count) domains" -ForegroundColor Cyan
    }

    # Create fallback logging if needed
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function global:Write-CustomLog {
            param([string]$Message, [string]$Level = 'INFO', [string]$Component = 'AitherCore')
            $color = switch ($Level) {
                'ERROR' { 'Red' }; 'WARN' { 'Yellow' }; 'INFO' { 'Cyan' }; 'SUCCESS' { 'Green' }
                'DEBUG' { 'Gray' }; default { 'White' }
            }
            Write-Host "[$Level] $Message" -ForegroundColor $color
        }
    }

    Write-CustomLog "AitherZero domain architecture initialized" -Level 'SUCCESS'

    # Handle different modes
    if ($Setup) {
        Write-CustomLog "Starting setup wizard..." -Level 'INFO'
        if (Get-Command Start-IntelligentSetup -ErrorAction SilentlyContinue) {
            $setupParams = @{}
            if ($InstallationProfile -ne 'interactive') {
                $setupParams['InstallationProfile'] = $InstallationProfile
            }
            if ($NonInteractive) { $setupParams['NonInteractive'] = $true }
            Start-IntelligentSetup @setupParams
        } else {
            Write-CustomLog "Setup wizard not available. Load Experience domain first." -Level 'WARNING'
            Write-Host "   Manual setup: Import-Module ./aither-core/AitherCore.psm1 -Force" -ForegroundColor Cyan
        }
    } elseif ($Scripts) {
        Write-CustomLog "Running specific functionality: $Scripts" -Level 'INFO'
        
        # Route to appropriate domain based on script request
        switch -Regex ($Scripts) {
            'config|configuration' {
                Write-CustomLog "Loading configuration management..." -Level 'INFO'
                if (Get-Command Get-ConfigurationStore -ErrorAction SilentlyContinue) {
                    Get-AvailableConfigurations
                } else {
                    Write-CustomLog "Configuration functions not available" -Level 'WARNING'
                }
            }
            'lab|infrastructure' {
                Write-CustomLog "Loading infrastructure management..." -Level 'INFO'
                if (Get-Command Start-LabAutomation -ErrorAction SilentlyContinue) {
                    Write-Host "Infrastructure functions available. Use Start-LabAutomation to begin." -ForegroundColor Green
                } else {
                    Write-CustomLog "Infrastructure functions not available" -Level 'WARNING'
                }
            }
            'ai|tools' {
                Write-CustomLog "Loading AI tools integration..." -Level 'INFO'
                if (Get-Command Get-AIToolsStatus -ErrorAction SilentlyContinue) {
                    Get-AIToolsStatus
                } else {
                    Write-CustomLog "AI tools functions not available" -Level 'WARNING'
                }
            }
            default {
                Write-CustomLog "Available domains: infrastructure, security, configuration, utilities, experience, automation" -Level 'INFO'
                Write-CustomLog "Use Get-CoreModuleStatus to see all available functions" -Level 'INFO'
            }
        }
    } elseif ($Auto) {
        Write-CustomLog "Running in automatic mode..." -Level 'INFO'
        
        # Auto mode: show status and available functions
        if (Get-Command Get-CoreModuleStatus -ErrorAction SilentlyContinue) {
            Get-CoreModuleStatus
        } else {
            Write-CustomLog "Domain status not available. Using manual approach." -Level 'WARNING'
        }
        
        Write-Host ""
        Write-Host "🎯 Available Functionality:" -ForegroundColor Cyan
        Write-Host "   • Configuration: Switch-ConfigurationSet, Get-AvailableConfigurations"
        Write-Host "   • Infrastructure: Start-LabAutomation, Start-InfrastructureDeployment"
        Write-Host "   • AI Tools: Install-ClaudeCode, Get-AIToolsStatus"
        Write-Host "   • Setup: Start-IntelligentSetup -InstallationProfile developer"
        Write-Host ""
        Write-Host "📚 Documentation: See FUNCTION-INDEX.md for all 196+ functions"
        
    } else {
        # Interactive mode
        Write-Host ""
        Write-Host "🎛️  AitherZero Interactive Mode" -ForegroundColor Green
        Write-Host ""
        
        if (Get-Command Get-CoreModuleStatus -ErrorAction SilentlyContinue) {
            Write-Host "📊 Domain Status:" -ForegroundColor Cyan
            Get-CoreModuleStatus
        }
        
        Write-Host ""
        Write-Host "🚀 Quick Start Options:" -ForegroundColor Yellow
        Write-Host "   1. Configuration Management: Switch-ConfigurationSet"
        Write-Host "   2. Setup Wizard: Start-IntelligentSetup"
        Write-Host "   3. Infrastructure: Start-LabAutomation"
        Write-Host "   4. AI Tools: Install-ClaudeCode"
        Write-Host ""
        Write-Host "💡 Pro Tip: See FUNCTION-INDEX.md for all 196+ available functions"
        Write-Host ""
        
        # Simple interactive menu
        if (-not $NonInteractive) {
            Write-Host "Press any key to see available domains, or Ctrl+C to exit..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            Write-Host ""
            Write-Host "📋 Available Domains:" -ForegroundColor Cyan
            $domains = @(
                "Configuration - Environment switching, repositories, backup/restore",
                "Experience - Setup wizards, progress tracking, user interface", 
                "Utilities - AI tools, version management, maintenance",
                "Infrastructure - Lab automation, OpenTofu, ISO management, monitoring",
                "Security - Credential management, security automation",
                "Automation - Script management, workflow orchestration"
            )
            
            for ($i = 0; $i -lt $domains.Count; $i++) {
                Write-Host "   $($i + 1). $($domains[$i])" -ForegroundColor White
            }
            
            Write-Host ""
            Write-Host "For detailed function list: Get-Content ./FUNCTION-INDEX.md" -ForegroundColor Cyan
        }
    }

    Write-CustomLog "AitherZero session complete" -Level 'SUCCESS'

} catch {
    Write-Host ""
    Write-Host "❌ AitherZero Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Ensure you're in the AitherZero directory"
    Write-Host "   2. Load domains manually: Import-Module ./aither-core/AitherCore.psm1 -Force"
    Write-Host "   3. Use direct domain loading: . './aither-core/domains/configuration/Configuration.ps1'"
    Write-Host "   4. See RESTORE-PATCHMANAGER.ps1 for PatchManager functions"
    Write-Host ""
    exit 1
}