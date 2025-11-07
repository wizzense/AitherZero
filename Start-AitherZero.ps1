#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero - Infrastructure Automation Platform

.DESCRIPTION
    Clean, powerful CLI for infrastructure automation and DevOps workflows.
    
    Built for systems engineers and power users who demand scriptability,
    extensibility, and control over their automation pipelines.

.PARAMETER ScriptNumber
    Execute a specific automation script by number (0000-9999)
    Example: .\Start-AitherZero.ps1 0402

.PARAMETER Playbook
    Execute a predefined playbook sequence
    Example: .\Start-AitherZero.ps1 -Playbook test-quick

.PARAMETER ConfigPath
    Path to configuration file (default: ./config.psd1)

.PARAMETER Help
    Show detailed help and usage examples

.EXAMPLE
    # Run a specific script
    .\Start-AitherZero.ps1 0402
    
.EXAMPLE
    # Execute a playbook
    .\Start-AitherZero.ps1 -Playbook test-full
    
.EXAMPLE
    # Use custom config
    .\Start-AitherZero.ps1 0500 -ConfigPath ./my-config.psd1

.NOTES
    AitherZero v2.0 - Clean CLI Architecture
    PowerShell 7.0+ required
#>

[CmdletBinding(DefaultParameterSetName='Script')]
param(
    [Parameter(Position=0, ParameterSetName='Script')]
    [ValidatePattern('^\d{4}$')]
    [string]$ScriptNumber,
    
    [Parameter(ParameterSetName='Playbook')]
    [string]$Playbook,
    
    [Parameter()]
    [string]$ConfigPath = './config.psd1',
    
    [Parameter()]
    [switch]$Help
)

#region Initialization

# Set strict mode for better error detection
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Set environment variables
$env:AITHERZERO_ROOT = $PSScriptRoot
$env:AITHERZERO_INITIALIZED = "1"

# Project root
$script:ProjectRoot = $PSScriptRoot

#endregion

#region Helper Functions

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    
    $colors = @{
        Info = 'Cyan'
        Success = 'Green'
        Warning = 'Yellow'
        Error = 'Red'
    }
    
    $prefixes = @{
        Info = '[i]'
        Success = '[✓]'
        Warning = '[!]'
        Error = '[✗]'
    }
    
    Write-Host "$($prefixes[$Type]) " -ForegroundColor $colors[$Type] -NoNewline
    Write-Host $Message
}

function Get-AitherConfig {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Status "Config file not found: $Path" -Type Warning
        return @{}
    }
    
    try {
        $configContent = Get-Content -Path $Path -Raw
        $scriptBlock = [scriptblock]::Create($configContent)
        $config = & $scriptBlock
        
        if ($config -isnot [hashtable]) {
            throw "Config file did not return a valid hashtable"
        }
        
        return $config
    }
    catch {
        Write-Status "Failed to load config: $_" -Type Error
        return @{}
    }
}

function Get-AutomationScripts {
    $scriptsPath = Join-Path $script:ProjectRoot 'automation-scripts'
    
    if (-not (Test-Path $scriptsPath)) {
        return @()
    }
    
    Get-ChildItem -Path $scriptsPath -Filter "*.ps1" | 
        Where-Object { $_.Name -match '^(\d{4})_(.+)\.ps1$' } |
        ForEach-Object {
            [PSCustomObject]@{
                Number = $Matches[1]
                Name = $Matches[2]
                Path = $_.FullName
                File = $_.Name
            }
        } | Sort-Object Number
}

function Get-AvailablePlaybooks {
    $playbooksPath = Join-Path $script:ProjectRoot 'orchestration/playbooks'
    
    if (-not (Test-Path $playbooksPath)) {
        return @()
    }
    
    Get-ChildItem -Path $playbooksPath -Filter "*.psd1" |
        ForEach-Object {
            [PSCustomObject]@{
                Name = $_.BaseName
                Path = $_.FullName
            }
        }
}

function Invoke-AutomationScript {
    param(
        [string]$Number,
        [hashtable]$Config
    )
    
    $scripts = @(Get-AutomationScripts)
    $script = $scripts | Where-Object { $_.Number -eq $Number }
    
    if (-not $script) {
        Write-Status "Script $Number not found" -Type Error
        Write-Host "`nAvailable scripts:" -ForegroundColor Cyan
        $scripts | Select-Object -First 10 | ForEach-Object {
            Write-Host "  $($_.Number) - $($_.Name)"
        }
        if ($scripts.Count -gt 10) {
            Write-Host "`n  ... and $($scripts.Count - 10) more"
        }
        return $false
    }
    
    Write-Status "Executing: $($script.Number) - $($script.Name)" -Type Info
    Write-Host ""
    
    try {
        & $script.Path
        Write-Host ""
        Write-Status "Completed successfully" -Type Success
        return $true
    }
    catch {
        Write-Host ""
        Write-Status "Script failed: $_" -Type Error
        return $false
    }
}

function Invoke-Playbook {
    param(
        [string]$Name,
        [hashtable]$Config
    )
    
    $playbooks = Get-AvailablePlaybooks
    $playbook = $playbooks | Where-Object { $_.Name -eq $Name }
    
    if (-not $playbook) {
        Write-Status "Playbook '$Name' not found" -Type Error
        Write-Host "`nAvailable playbooks:" -ForegroundColor Cyan
        $playbooks | ForEach-Object {
            Write-Host "  - $($_.Name)"
        }
        return $false
    }
    
    Write-Status "Loading playbook: $Name" -Type Info
    
    try {
        # Load playbook definition
        $playbookContent = Get-Content -Path $playbook.Path -Raw
        $playbookBlock = [scriptblock]::Create($playbookContent)
        $playbookData = & $playbookBlock
        
        if (-not $playbookData.Scripts) {
            Write-Status "Playbook has no scripts defined" -Type Error
            return $false
        }
        
        Write-Host "`nExecuting $($playbookData.Scripts.Count) scripts..." -ForegroundColor Cyan
        Write-Host ""
        
        $failed = 0
        foreach ($scriptNum in $playbookData.Scripts) {
            if (-not (Invoke-AutomationScript -Number $scriptNum -Config $Config)) {
                $failed++
            }
            Write-Host ""
        }
        
        if ($failed -eq 0) {
            Write-Status "Playbook completed successfully" -Type Success
            return $true
        }
        else {
            Write-Status "$failed script(s) failed" -Type Error
            return $false
        }
    }
    catch {
        Write-Status "Playbook execution failed: $_" -Type Error
        return $false
    }
}

function Show-HelpText {
    $helpText = @"

AitherZero - Infrastructure Automation Platform
================================================

USAGE:
    .\Start-AitherZero.ps1 <script-number>           Run a specific automation script
    .\Start-AitherZero.ps1 -Playbook <name>          Execute a playbook sequence
    .\Start-AitherZero.ps1 -Help                     Show this help

EXAMPLES:
    # Run unit tests
    .\Start-AitherZero.ps1 0402
    
    # Run PSScriptAnalyzer
    .\Start-AitherZero.ps1 0404
    
    # Execute quick test playbook
    .\Start-AitherZero.ps1 -Playbook test-quick
    
    # Execute full test suite
    .\Start-AitherZero.ps1 -Playbook test-full

AUTOMATION SCRIPTS:
    0000-0099    Environment Setup
    0100-0199    Infrastructure (Hyper-V, Networking, Certificates)
    0200-0299    Development Tools (Git, Docker, VS Code)
    0400-0499    Testing & Validation
    0500-0599    Reporting & Metrics
    0700-0799    Git Automation & AI Tools
    0800-0899    Issue Management
    0900-0999    Validation & Quality
    9000-9999    Maintenance & Cleanup

AVAILABLE SCRIPTS:
"@

    Write-Host $helpText -ForegroundColor Cyan
    
    # Show first 20 scripts
    $scripts = @(Get-AutomationScripts)
    $scripts | Select-Object -First 20 | ForEach-Object {
        Write-Host "    $($_.Number)  $($_.Name)" -ForegroundColor Gray
    }
    
    if ($scripts.Count -gt 20) {
        Write-Host "    ... and $($scripts.Count - 20) more scripts" -ForegroundColor DarkGray
    }
    
    Write-Host "`nAVAILABLE PLAYBOOKS:" -ForegroundColor Cyan
    $playbooks = @(Get-AvailablePlaybooks)
    if ($playbooks.Count -gt 0) {
        $playbooks | ForEach-Object {
            Write-Host "    - $($_.Name)" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "    (No playbooks found)" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "For more information, visit: https://github.com/wizzense/AitherZero" -ForegroundColor DarkGray
    Write-Host ""
}

#endregion

#region Main Execution

# Show banner
Write-Host ""
Write-Host "  █████╗ ██╗████████╗██╗  ██╗███████╗██████╗ ███████╗███████╗██████╗  ██████╗ " -ForegroundColor Cyan
Write-Host " ██╔══██╗██║╚══██╔══╝██║  ██║██╔════╝██╔══██╗╚══███╔╝██╔════╝██╔══██╗██╔═══██╗" -ForegroundColor Cyan
Write-Host " ███████║██║   ██║   ███████║█████╗  ██████╔╝  ███╔╝ █████╗  ██████╔╝██║   ██║" -ForegroundColor Blue
Write-Host " ██╔══██║██║   ██║   ██╔══██║██╔══╝  ██╔══██╗ ███╔╝  ██╔══╝  ██╔══██╗██║   ██║" -ForegroundColor Blue
Write-Host " ██║  ██║██║   ██║   ██║  ██║███████╗██║  ██║███████╗███████╗██║  ██║╚██████╔╝" -ForegroundColor DarkBlue
Write-Host " ╚═╝  ╚═╝╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ " -ForegroundColor DarkBlue
Write-Host ""
Write-Host "  Infrastructure Automation Platform" -ForegroundColor DarkCyan
Write-Host "  PowerShell 7+ | Systems Engineering | DevOps" -ForegroundColor DarkGray
Write-Host ""

# Load module
try {
    Import-Module (Join-Path $script:ProjectRoot 'AitherZero.psd1') -Force -ErrorAction Stop
    Write-Status "Module loaded successfully" -Type Success
}
catch {
    Write-Status "Failed to load AitherZero module: $_" -Type Warning
}

# Load configuration
$config = Get-AitherConfig -Path $ConfigPath

# Handle parameters
if ($Help) {
    Show-HelpText
    exit 0
}

if ($ScriptNumber) {
    $success = Invoke-AutomationScript -Number $ScriptNumber -Config $config
    exit ($success ? 0 : 1)
}

if ($Playbook) {
    $success = Invoke-Playbook -Name $Playbook -Config $config
    exit ($success ? 0 : 1)
}

# No parameters - show help
Show-HelpText
exit 0

#endregion
