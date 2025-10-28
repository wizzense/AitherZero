#Requires -Version 7.0
<#
.SYNOPSIS
    Synchronize config.psd1 with actual automation scripts
.DESCRIPTION
    Automatically discovers automation scripts in the automation-scripts directory
    and compares them with the scripts listed in config.psd1 manifest.
    
    Reports missing scripts and optionally updates config.psd1 with discovered scripts.
    Helps keep configuration in sync when new automation scripts are added.
    
    Exit Codes:
    0 - All scripts are registered or updated successfully
    1 - Missing scripts found (when not in Fix mode)
    2 - Execution error

.PARAMETER Fix
    Automatically add missing scripts to config.psd1
.PARAMETER DryRun
    Show what would be changed without making changes
.PARAMETER Verbose
    Show detailed information about the sync process
.EXAMPLE
    ./automation-scripts/0003_Sync-ConfigManifest.ps1
    Check for missing scripts in config.psd1
.EXAMPLE
    ./automation-scripts/0003_Sync-ConfigManifest.ps1 -Fix
    Automatically add missing scripts to config.psd1
.EXAMPLE
    ./automation-scripts/0003_Sync-ConfigManifest.ps1 -DryRun
    Preview what would be changed
.NOTES
    Stage: Environment Setup
    Order: 0003
    Dependencies: None
    Tags: configuration, maintenance, automation
#>

[CmdletBinding()]
param(
    [switch]$Fix,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Environment'
    Order = '0003'
    Name = 'Sync-ConfigManifest'
    Description = 'Synchronize config.psd1 with automation scripts'
    Tags = @('configuration', 'maintenance', 'automation')
}

# Paths
$projectRoot = Split-Path $PSScriptRoot -Parent
$configPath = Join-Path $projectRoot "config.psd1"
$scriptsPath = Join-Path $projectRoot "automation-scripts"

function Write-SyncLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $color = switch ($Level) {
        'Error' { 'Red' }
        'Warning' { 'Yellow' }
        'Success' { 'Green' }
        default { 'Cyan' }
    }
    
    $icon = switch ($Level) {
        'Error' { '❌' }
        'Warning' { '⚠️' }
        'Success' { '✅' }
        default { 'ℹ️' }
    }
    
    Write-Host "$icon $Message" -ForegroundColor $color
}

# Discover all automation scripts
Write-SyncLog "Discovering automation scripts..." -Level Info

$discoveredScripts = Get-ChildItem -Path $scriptsPath -Filter "*.ps1" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^\d{4}_' } |
    ForEach-Object {
        $number = $_.Name.Substring(0, 4)
        @{
            Number = $number
            Name = $_.Name
            Path = $_.FullName
        }
    } |
    Sort-Object { [int]$_.Number }

Write-SyncLog "Found $($discoveredScripts.Count) automation scripts" -Level Success

# Load config.psd1
Write-SyncLog "Loading config.psd1..." -Level Info

if (-not (Test-Path $configPath)) {
    Write-SyncLog "config.psd1 not found at: $configPath" -Level Error
    exit 2
}

try {
    $config = Import-PowerShellDataFile -Path $configPath
} catch {
    Write-SyncLog "Failed to load config.psd1: $($_.Exception.Message)" -Level Error
    exit 2
}

# Extract all script numbers from config
$registeredScripts = @{}
$config.Manifest.FeatureDependencies.GetEnumerator() | ForEach-Object {
    $category = $_.Key
    $_.Value.GetEnumerator() | ForEach-Object {
        $feature = $_.Key
        $featureData = $_.Value
        if ($featureData -is [hashtable] -and $featureData.ContainsKey('Scripts')) {
            $featureData.Scripts | ForEach-Object {
                $scriptNum = $_
                if (-not $registeredScripts.ContainsKey($scriptNum)) {
                    $registeredScripts[$scriptNum] = @()
                }
                $registeredScripts[$scriptNum] += "$category.$feature"
            }
        }
    }
}

Write-SyncLog "Found $($registeredScripts.Count) scripts registered in config.psd1" -Level Success

# Compare discovered vs registered
$missingScripts = @()
foreach ($script in $discoveredScripts) {
    if (-not $registeredScripts.ContainsKey($script.Number)) {
        $missingScripts += $script
    }
}

# Report results
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                  Config Sync Results                         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Discovered Scripts: $($discoveredScripts.Count)" -ForegroundColor White
Write-Host "Registered Scripts: $($registeredScripts.Count)" -ForegroundColor White
Write-Host "Missing Scripts: $($missingScripts.Count)" -ForegroundColor $(if ($missingScripts.Count -gt 0) { 'Yellow' } else { 'Green' })
Write-Host ""

if ($missingScripts.Count -gt 0) {
    Write-SyncLog "Missing scripts found:" -Level Warning
    Write-Host ""
    
    # Group by range
    $grouped = $missingScripts | Group-Object { 
        $num = [int]$_.Number
        switch ($num) {
            { $_ -lt 100 } { '0000-0099' }
            { $_ -lt 200 } { '0100-0199' }
            { $_ -lt 300 } { '0200-0299' }
            { $_ -lt 400 } { '0300-0399' }
            { $_ -lt 500 } { '0400-0499' }
            { $_ -lt 600 } { '0500-0599' }
            { $_ -lt 700 } { '0600-0699' }
            { $_ -lt 800 } { '0700-0799' }
            { $_ -lt 900 } { '0800-0899' }
            { $_ -lt 1000 } { '0900-0999' }
            default { '9000-9999' }
        }
    }
    
    foreach ($group in $grouped) {
        Write-Host "  $($group.Name):" -ForegroundColor Cyan
        foreach ($script in $group.Group) {
            Write-Host "    • $($script.Number) - $($script.Name)" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    Write-Host "💡 Suggested Actions:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Review each missing script and determine the appropriate category" -ForegroundColor White
    Write-Host "2. Add script numbers to config.psd1 under Manifest.FeatureDependencies" -ForegroundColor White
    Write-Host "3. Update descriptions to reflect new scripts" -ForegroundColor White
    Write-Host ""
    Write-Host "Example sections to update:" -ForegroundColor Cyan
    Write-Host "  - Maintenance.Environment (0000-0099)" -ForegroundColor Gray
    Write-Host "  - Infrastructure (0100-0199)" -ForegroundColor Gray
    Write-Host "  - Development (0200-0299)" -ForegroundColor Gray
    Write-Host "  - Testing (0400-0499)" -ForegroundColor Gray
    Write-Host "  - Reporting (0500-0599)" -ForegroundColor Gray
    Write-Host "  - Git / AIAgents (0700-0799)" -ForegroundColor Gray
    Write-Host "  - IssueManagement (0800-0899)" -ForegroundColor Gray
    Write-Host ""
    
    if ($Fix) {
        Write-SyncLog "Fix mode not yet implemented - manual updates required" -Level Warning
        Write-Host "Manual editing of config.psd1 is recommended to ensure proper categorization" -ForegroundColor Yellow
    } elseif ($DryRun) {
        Write-SyncLog "Dry run complete - no changes made" -Level Info
    }
    
    exit 1
} else {
    Write-SyncLog "All automation scripts are registered in config.psd1!" -Level Success
    Write-Host ""
    Write-Host "✅ Configuration is in sync" -ForegroundColor Green
    exit 0
}
