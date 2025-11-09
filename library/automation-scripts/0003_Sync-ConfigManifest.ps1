#Requires -Version 7.0
<#
.SYNOPSIS
    Comprehensive synchronization of config.psd1 with repository state
.DESCRIPTION
    Automatically discovers and synchronizes all inventory in config.psd1:
    - Automation scripts in library/automation-scripts
    - Test files (unit and integration tests)
    - Playbooks in library/playbooks
    - GitHub Actions workflows in .github/workflows
    
    Reports missing items and optionally updates config.psd1 with discovered inventory.
    Ensures config.psd1 remains the single source of truth for the repository.
    
    Exit Codes:
    0 - All inventory synchronized or updated successfully
    1 - Missing items found (when not in Fix mode)
    2 - Execution error

.PARAMETER Fix
    Automatically update config.psd1 with discovered inventory
.PARAMETER DryRun
    Show what would be changed without making changes
.PARAMETER Verbose
    Show detailed information about the sync process
.EXAMPLE
    ./automation-scripts/0003_Sync-ConfigManifest.ps1
    Check for missing items in config.psd1
.EXAMPLE
    ./automation-scripts/0003_Sync-ConfigManifest.ps1 -Fix
    Automatically update config.psd1 with discovered inventory
.EXAMPLE
    ./automation-scripts/0003_Sync-ConfigManifest.ps1 -DryRun
    Preview what would be changed
.NOTES
    Stage: Environment Setup
    Order: 0003
    Dependencies: None
    Tags: configuration, maintenance, automation, inventory, comprehensive
    
    This is the ONLY config sync script - no separate "comprehensive" version needed.
    All inventory tracking is handled here.
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
    Description = 'Comprehensive synchronization of config.psd1 with repository state (scripts, tests, playbooks, workflows)'
    Tags = @('configuration', 'maintenance', 'automation', 'inventory', 'comprehensive')
}

# Paths
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$configPath = Join-Path $projectRoot "config.psd1"
$scriptsPath = Join-Path $projectRoot "library/automation-scripts"
$testsPath = Join-Path $projectRoot "tests"
$playbooksPath = Join-Path $projectRoot "library/playbooks"
$workflowsPath = Join-Path $projectRoot ".github/workflows"

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

# Check for duplicate script numbers (CRITICAL)
Write-SyncLog "Checking for duplicate script numbers..." -Level Info
$duplicateNumbers = $discoveredScripts | 
    Group-Object Number | 
    Where-Object { $_.Count -gt 1 }

if ($duplicateNumbers) {
    Write-Host ""
    Write-SyncLog "CRITICAL: Duplicate script numbers detected!" -Level Error
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║            DUPLICATE SCRIPT NUMBERS FOUND                    ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    
    foreach ($dup in $duplicateNumbers) {
        Write-Host "Script Number: $($dup.Name) (found $($dup.Count) times)" -ForegroundColor Red
        foreach ($script in $dup.Group) {
            Write-Host "  • $($script.Name)" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    Write-Host "💥 FAILURE: Duplicate script numbers are not allowed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Each automation script must have a unique number." -ForegroundColor White
    Write-Host "Please rename one of the duplicate scripts to use an available number." -ForegroundColor White
    Write-Host ""
    exit 2
}

Write-SyncLog "No duplicate script numbers found" -Level Success

# Load config.psd1
Write-SyncLog "Loading config.psd1..." -Level Info

if (-not (Test-Path $configPath)) {
    Write-SyncLog "config.psd1 not found at: $configPath" -Level Error
    exit 2
}

try {
    # Use scriptblock evaluation instead of Import-PowerShellDataFile
    # because config.psd1 contains PowerShell expressions ($true/$false) that
    # Import-PowerShellDataFile treats as "dynamic expressions"
    $content = Get-Content -Path $configPath -Raw
    $scriptBlock = [scriptblock]::Create($content)
    $config = & $scriptBlock
    
    if (-not $config -or $config -isnot [hashtable]) {
        throw "Config file did not return a valid hashtable"
    }
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
}

# Check for duplicate script number references in config.psd1
Write-Host ""
Write-SyncLog "Checking config.psd1 for duplicate references..." -Level Info

$configDuplicates = $registeredScripts.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }
if ($configDuplicates) {
    Write-Host ""
    Write-SyncLog "CRITICAL: Duplicate script number references in config.psd1!" -Level Error
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║        DUPLICATE REFERENCES IN CONFIG.PSD1 FOUND            ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    
    foreach ($dup in $configDuplicates) {
        Write-Host "Script Number: $($dup.Key)" -ForegroundColor Red
        foreach ($location in $dup.Value) {
            Write-Host "  • Referenced in: $location" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    Write-Host "💥 FAILURE: Duplicate references will break script execution!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Each script number can only be referenced ONCE in config.psd1." -ForegroundColor White
    Write-Host "Multiple references cause ambiguity and execution failures." -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 Action Required:" -ForegroundColor Red
    Write-Host "  1. Review the duplicate references listed above" -ForegroundColor White
    Write-Host "  2. Determine which feature should own each script" -ForegroundColor White
    Write-Host "  3. Remove duplicate entries from config.psd1" -ForegroundColor White
    Write-Host "  4. Re-run this validation script" -ForegroundColor White
    Write-Host ""
    exit 2
}

# ===================================================================
# COMPREHENSIVE INVENTORY TRACKING
# ===================================================================

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           Comprehensive Inventory Validation                 ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Discover test files
Write-SyncLog "Discovering test files..." -Level Info
$unitTests = @(Get-ChildItem -Path (Join-Path $testsPath "unit") -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue)
$integrationTests = @(Get-ChildItem -Path (Join-Path $testsPath "integration") -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue)
$totalTests = $unitTests.Count + $integrationTests.Count

Write-SyncLog "Found $($unitTests.Count) unit tests, $($integrationTests.Count) integration tests (Total: $totalTests)" -Level Success

# Discover playbooks
Write-SyncLog "Discovering playbooks..." -Level Info
$playbooks = @(Get-ChildItem -Path $playbooksPath -Filter "*.psd1" -ErrorAction SilentlyContinue)
Write-SyncLog "Found $($playbooks.Count) playbooks" -Level Success

# Discover workflows
Write-SyncLog "Discovering workflows..." -Level Info
$workflows = @(Get-ChildItem -Path $workflowsPath -Filter "*.yml" -ErrorAction SilentlyContinue) + 
             @(Get-ChildItem -Path $workflowsPath -Filter "*.yaml" -ErrorAction SilentlyContinue)
Write-SyncLog "Found $($workflows.Count) workflows" -Level Success

# Compare with config.psd1
Write-Host ""
Write-Host "Inventory Validation:" -ForegroundColor Cyan
Write-Host ""

$inventoryMismatches = @()

# Check TestInventory
if ($config.Manifest.TestInventory) {
    $configUnitTests = $config.Manifest.TestInventory.Unit.Count
    $configIntegrationTests = $config.Manifest.TestInventory.Integration.Count
    $configTotalTests = $config.Manifest.TestInventory.Total
    
    if ($configUnitTests -ne $unitTests.Count) {
        $inventoryMismatches += "TestInventory.Unit: Config=$configUnitTests, Actual=$($unitTests.Count)"
    }
    if ($configIntegrationTests -ne $integrationTests.Count) {
        $inventoryMismatches += "TestInventory.Integration: Config=$configIntegrationTests, Actual=$($integrationTests.Count)"
    }
    if ($configTotalTests -ne $totalTests) {
        $inventoryMismatches += "TestInventory.Total: Config=$configTotalTests, Actual=$totalTests"
    }
    
    Write-Host "  Test Inventory:" -ForegroundColor White
    Write-Host "    Unit: $($unitTests.Count)" -ForegroundColor $(if ($configUnitTests -eq $unitTests.Count) { 'Green' } else { 'Yellow' })
    Write-Host "    Integration: $($integrationTests.Count)" -ForegroundColor $(if ($configIntegrationTests -eq $integrationTests.Count) { 'Green' } else { 'Yellow' })
    Write-Host "    Total: $totalTests" -ForegroundColor $(if ($configTotalTests -eq $totalTests) { 'Green' } else { 'Yellow' })
} else {
    $inventoryMismatches += "TestInventory section missing from config.psd1"
    Write-Host "  Test Inventory: NOT CONFIGURED" -ForegroundColor Yellow
}

# Check PlaybookInventory
if ($config.Manifest.PlaybookInventory) {
    $configPlaybooks = $config.Manifest.PlaybookInventory.Count
    if ($configPlaybooks -ne $playbooks.Count) {
        $inventoryMismatches += "PlaybookInventory: Config=$configPlaybooks, Actual=$($playbooks.Count)"
    }
    Write-Host "  Playbook Inventory: $($playbooks.Count)" -ForegroundColor $(if ($configPlaybooks -eq $playbooks.Count) { 'Green' } else { 'Yellow' })
} else {
    $inventoryMismatches += "PlaybookInventory section missing from config.psd1"
    Write-Host "  Playbook Inventory: NOT CONFIGURED" -ForegroundColor Yellow
}

# Check WorkflowInventory
if ($config.Manifest.WorkflowInventory) {
    $configWorkflows = $config.Manifest.WorkflowInventory.Count
    if ($configWorkflows -ne $workflows.Count) {
        $inventoryMismatches += "WorkflowInventory: Config=$configWorkflows, Actual=$($workflows.Count)"
    }
    Write-Host "  Workflow Inventory: $($workflows.Count)" -ForegroundColor $(if ($configWorkflows -eq $workflows.Count) { 'Green' } else { 'Yellow' })
} else {
    $inventoryMismatches += "WorkflowInventory section missing from config.psd1"
    Write-Host "  Workflow Inventory: NOT CONFIGURED" -ForegroundColor Yellow
}

Write-Host ""

if ($inventoryMismatches.Count -gt 0) {
    Write-SyncLog "Inventory mismatches detected:" -Level Warning
    Write-Host ""
    foreach ($mismatch in $inventoryMismatches) {
        Write-Host "  ⚠️  $mismatch" -ForegroundColor Yellow
    }
    Write-Host ""
    
    if ($Fix) {
        Write-SyncLog "Updating config.psd1 inventory sections..." -Level Info
        
        # Update TestInventory
        $configContent = Get-Content -Path $configPath -Raw
        $configContent = $configContent -replace "Unit\s*=\s*@\{\s*Count\s*=\s*\d+", "Unit = @{ Count = $($unitTests.Count)"
        $configContent = $configContent -replace "Integration\s*=\s*@\{\s*Count\s*=\s*\d+", "Integration = @{ Count = $($integrationTests.Count)"
        $configContent = $configContent -replace "TestInventory\s*=\s*@\{[^}]*Total\s*=\s*\d+", {
            $match = $_.Value
            $match -replace "Total\s*=\s*\d+", "Total = $totalTests"
        }
        
        # Update PlaybookInventory
        $configContent = $configContent -replace "PlaybookInventory\s*=\s*@\{\s*Count\s*=\s*\d+", "PlaybookInventory = @{ Count = $($playbooks.Count)"
        
        # Update WorkflowInventory
        $configContent = $configContent -replace "WorkflowInventory\s*=\s*@\{\s*Count\s*=\s*\d+", "WorkflowInventory = @{ Count = $($workflows.Count)"
        
        if (-not $DryRun) {
            Set-Content -Path $configPath -Value $configContent -NoNewline
            Write-SyncLog "Config.psd1 inventory sections updated successfully!" -Level Success
        } else {
            Write-SyncLog "Dry run - no changes made" -Level Info
        }
    } else {
        Write-Host "💡 Run with -Fix to automatically update config.psd1" -ForegroundColor Cyan
    }
} else {
    Write-SyncLog "All inventory counts match config.psd1" -Level Success
}

Write-Host ""
Write-Host "✅ Configuration sync complete" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Scripts: $($discoveredScripts.Count) unique numbers" -ForegroundColor White
Write-Host "  Tests: $totalTests files ($($unitTests.Count) unit + $($integrationTests.Count) integration)" -ForegroundColor White
Write-Host "  Playbooks: $($playbooks.Count) files" -ForegroundColor White
Write-Host "  Workflows: $($workflows.Count) files" -ForegroundColor White
Write-Host ""

exit 0
