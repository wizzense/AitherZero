#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero - Infrastructure Automation Platform Entry Point

.DESCRIPTION
    Main entry point for the AitherZero automation platform.
    
    This script provides backward compatibility and convenience wrappers
    for the new AitherZero CLI cmdlets.
    
    For full functionality, use the cmdlets directly:
    - Invoke-AitherScript, Get-AitherScript
    - Invoke-AitherPlaybook, Get-AitherPlaybook  
    - Get-AitherConfig, Show-AitherDashboard
    
.PARAMETER ScriptNumber
    Execute a specific automation script by number (0000-9999)

.PARAMETER Playbook
    Execute a predefined playbook sequence

.PARAMETER Profile
    Playbook profile to use (quick, full, ci)

.PARAMETER ConfigPath
    Path to configuration file (default: ./config.psd1)

.PARAMETER List
    List available scripts or playbooks

.PARAMETER Dashboard
    Show system dashboard

.PARAMETER Help
    Show detailed help and usage examples

.EXAMPLE
    ./Start-AitherZero.ps1 0402
    
    Run unit tests (script 0402)
    
.EXAMPLE
    ./Start-AitherZero.ps1 -Playbook test-quick
    
    Execute quick test playbook
    
.EXAMPLE
    ./Start-AitherZero.ps1 -List scripts
    
    List all available scripts
    
.EXAMPLE
    ./Start-AitherZero.ps1 -Dashboard
    
    Show system dashboard

.NOTES
    AitherZero v2.0 - Unified CLI Architecture
    PowerShell 7.0+ required
    
    Tip: Use cmdlets directly for full control:
    Get-Command -Module AitherZero | Where-Object Name -like '*-Aither*'
#>

[CmdletBinding(DefaultParameterSetName='Script')]
param(
    [Parameter(Position=0, ParameterSetName='Script')]
    [ValidatePattern('^\d{4}$')]
    [string]$ScriptNumber,
    
    [Parameter(ParameterSetName='Playbook', Mandatory=$true)]
    [string]$Playbook,
    
    [Parameter(ParameterSetName='Playbook')]
    [string]$Profile,
    
    [Parameter()]
    [string]$ConfigPath = './config.psd1',
    
    [Parameter(ParameterSetName='List')]
    [ValidateSet('scripts', 'playbooks', 'all')]
    [string]$List = 'all',
    
    [Parameter(ParameterSetName='Dashboard')]
    [switch]$Dashboard,
    
    [Parameter()]
    [switch]$Help
)

#region Initialization

# Set strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Set environment variables
$env:AITHERZERO_ROOT = $PSScriptRoot
$env:AITHERZERO_INITIALIZED = "1"

#endregion

#region Load Module

try {
    Import-Module (Join-Path $PSScriptRoot 'AitherZero.psd1') -Force -ErrorAction Stop
    Write-Verbose "Module loaded successfully"
}
catch {
    Write-Warning "Failed to load AitherZero module: $_"
    Write-Host "Run bootstrap.ps1 first to set up the environment" -ForegroundColor Yellow
    exit 1
}

#endregion

#region Main Execution

# Show banner
if (-not $env:CI -and -not $env:AITHERZERO_SUPPRESS_BANNER) {
    Write-Host ""
    Write-Host "  █████╗ ██╗████████╗██╗  ██╗███████╗██████╗ ███████╗███████╗██████╗  ██████╗ " -ForegroundColor Cyan
    Write-Host " ██╔══██╗██║╚══██╔══╝██║  ██║██╔════╝██╔══██╗╚══███╔╝██╔════╝██╔══██╗██╔═══██╗" -ForegroundColor Cyan
    Write-Host " ███████║██║   ██║   ███████║█████╗  ██████╔╝  ███╔╝ █████╗  ██████╔╝██║   ██║" -ForegroundColor Blue
    Write-Host " ██╔══██║██║   ██║   ██╔══██║██╔══╝  ██╔══██╗ ███╔╝  ██╔══╝  ██╔══██╗██║   ██║" -ForegroundColor Blue
    Write-Host " ██║  ██║██║   ██║   ██║  ██║███████╗██║  ██║███████╗███████╗██║  ██║╚██████╔╝" -ForegroundColor DarkBlue
    Write-Host " ╚═╝  ╚═╝╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ " -ForegroundColor DarkBlue
    Write-Host ""
    Write-Host "  Infrastructure Automation Platform v2.0" -ForegroundColor DarkCyan
    Write-Host "  PowerShell 7+ | CI/CD | DevOps | Systems Engineering" -ForegroundColor DarkGray
    Write-Host ""
}

# Handle parameters
if ($Help) {
    Get-Help $PSCommandPath -Full
    Write-Host ""
    Write-Host "Quick Reference:" -ForegroundColor Cyan
    Write-Host "  Get-AitherScript              List automation scripts" -ForegroundColor Gray
    Write-Host "  Get-AitherPlaybook            List playbooks" -ForegroundColor Gray
    Write-Host "  Invoke-AitherScript 0402      Run a script" -ForegroundColor Gray
    Write-Host "  Invoke-AitherPlaybook test    Run a playbook" -ForegroundColor Gray
    Write-Host "  Show-AitherDashboard          Show dashboard" -ForegroundColor Gray
    Write-Host "  Get-AitherConfig              Get configuration" -ForegroundColor Gray
    Write-Host ""
    Write-Host "For all available cmdlets:" -ForegroundColor Cyan
    Write-Host "  Get-Command -Module AitherZero | Where-Object Name -like '*-Aither*'" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

if ($List) {
    switch ($List) {
        'scripts' {
            Write-Host "Available Scripts:" -ForegroundColor Cyan
            Write-Host ""
            Get-AitherScript | Format-Table Number, Name, Category -AutoSize
        }
        'playbooks' {
            Write-Host "Available Playbooks:" -ForegroundColor Cyan
            Write-Host ""
            Get-AitherPlaybook | Format-Table Name, Description, ScriptCount -AutoSize
        }
        'all' {
            Write-Host "Available Scripts:" -ForegroundColor Cyan
            Write-Host ""
            Get-AitherScript | Format-Table Number, Name, Category -AutoSize
            Write-Host ""
            Write-Host "Available Playbooks:" -ForegroundColor Cyan
            Write-Host ""
            Get-AitherPlaybook | Format-Table Name, Description, ScriptCount -AutoSize
        }
    }
    exit 0
}

if ($Dashboard) {
    Show-AitherDashboard
    exit 0
}

if ($ScriptNumber) {
    $success = Invoke-AitherScript -Number $ScriptNumber -PassThru
    exit ($success.Success ? 0 : 1)
}

if ($Playbook) {
    $params = @{ Name = $Playbook }
    if ($Profile) { $params.Profile = $Profile }
    
    $results = Invoke-AitherPlaybook @params -PassThru
    $failed = ($results | Where-Object { -not $_.Success }).Count
    exit ($failed -eq 0 ? 0 : 1)
}

# No parameters - interactive mode
Write-Host "Welcome to AitherZero Interactive Mode" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

# Show quick stats
$scriptCount = (Get-AitherScript).Count
$playbookCount = (Get-AitherPlaybook).Count
Write-Host "  📋 Scripts: $scriptCount | 📦 Playbooks: $playbookCount | 🖥️  Platform: $(Get-AitherPlatform)" -ForegroundColor DarkGray
Write-Host ""

# Interactive menu
Write-Host "What would you like to do?" -ForegroundColor White
Write-Host ""
Write-Host "  [s] " -ForegroundColor Yellow -NoNewline
Write-Host "List scripts" -ForegroundColor Gray
Write-Host "  [p] " -ForegroundColor Yellow -NoNewline
Write-Host "List playbooks" -ForegroundColor Gray
Write-Host "  [d] " -ForegroundColor Yellow -NoNewline
Write-Host "Show dashboard" -ForegroundColor Gray
Write-Host "  [r] " -ForegroundColor Yellow -NoNewline
Write-Host "Run a script (enter number)" -ForegroundColor Gray
Write-Host "  [e] " -ForegroundColor Yellow -NoNewline
Write-Host "Execute a playbook" -ForegroundColor Gray
Write-Host "  [h] " -ForegroundColor Yellow -NoNewline
Write-Host "Show help" -ForegroundColor Gray
Write-Host "  [q] " -ForegroundColor Yellow -NoNewline
Write-Host "Quit" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Enter choice"

switch ($choice.ToLower()) {
    's' {
        Write-Host ""
        Write-Host "Available Scripts:" -ForegroundColor Cyan
        Write-Host ""
        Get-AitherScript | Format-Table Number, Name, Category -AutoSize
    }
    'p' {
        Write-Host ""
        Write-Host "Available Playbooks:" -ForegroundColor Cyan
        Write-Host ""
        Get-AitherPlaybook | Format-Table Name, Description, ScriptCount -AutoSize
    }
    'd' {
        Write-Host ""
        Show-AitherDashboard
    }
    'r' {
        Write-Host ""
        $scriptNum = Read-Host "Enter script number (0000-9999)"
        if ($scriptNum -match '^\d{4}$') {
            Write-Host ""
            $success = Invoke-AitherScript -Number $scriptNum -PassThru
            exit ($success.Success ? 0 : 1)
        } else {
            Write-Host "Invalid script number. Must be 4 digits (e.g., 0402)" -ForegroundColor Red
            exit 1
        }
    }
    'e' {
        Write-Host ""
        Write-Host "Available playbooks:" -ForegroundColor DarkGray
        Get-AitherPlaybook | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor DarkGray }
        Write-Host ""
        $playbookName = Read-Host "Enter playbook name"
        if ($playbookName) {
            Write-Host ""
            $results = Invoke-AitherPlaybook -Name $playbookName -PassThru
            $failed = ($results | Where-Object { -not $_.Success }).Count
            exit ($failed -eq 0 ? 0 : 1)
        } else {
            Write-Host "No playbook specified" -ForegroundColor Red
            exit 1
        }
    }
    'h' {
        Write-Host ""
        Write-Host "Quick Reference:" -ForegroundColor Cyan
        Write-Host "  Get-AitherScript              List automation scripts" -ForegroundColor Gray
        Write-Host "  Get-AitherPlaybook            List playbooks" -ForegroundColor Gray
        Write-Host "  Invoke-AitherScript 0402      Run a script" -ForegroundColor Gray
        Write-Host "  Invoke-AitherPlaybook test    Run a playbook" -ForegroundColor Gray
        Write-Host "  Show-AitherDashboard          Show dashboard" -ForegroundColor Gray
        Write-Host "  Get-AitherConfig              Get configuration" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Command-line usage:" -ForegroundColor Cyan
        Write-Host "  ./Start-AitherZero.ps1 <number>        Run script by number" -ForegroundColor Gray
        Write-Host "  ./Start-AitherZero.ps1 -Playbook name  Run playbook" -ForegroundColor Gray
        Write-Host "  ./Start-AitherZero.ps1 -List scripts   List scripts" -ForegroundColor Gray
        Write-Host "  ./Start-AitherZero.ps1 -Dashboard      Show dashboard" -ForegroundColor Gray
        Write-Host ""
        Write-Host "For all available cmdlets:" -ForegroundColor Cyan
        Write-Host "  Get-Command -Module AitherZero | Where-Object Name -like '*-Aither*'" -ForegroundColor Gray
    }
    'q' {
        Write-Host ""
        Write-Host "Goodbye! 👋" -ForegroundColor Cyan
        exit 0
    }
    default {
        # Check if it's a script number
        if ($choice -match '^\d{4}$') {
            Write-Host ""
            $success = Invoke-AitherScript -Number $choice -PassThru
            exit ($success.Success ? 0 : 1)
        } else {
            Write-Host ""
            Write-Host "Invalid choice. Use -Help for usage information." -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""
exit 0

#endregion
