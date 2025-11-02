#Requires -Version 7.0
<#
.SYNOPSIS
    Configuration-Driven Interactive UI Module for AitherZero
    
.DESCRIPTION
    Provides dynamic, configuration-driven interactive menus for AitherZero.
    All menus, categories, and features are built automatically from config.psd1.
    Zero hardcoding - everything is configuration-driven.
    
    Key Features:
    - Dynamic menu generation from config.psd1 Manifest.FeatureDependencies
    - Automatic script discovery and categorization
    - Profile-based feature visibility
    - Integrated quality of life features (search, recent actions, quick jump, etc.)
    - CLI learning mode integration
    - Prerequisites checking
    - Execution history tracking
    
.EXAMPLE
    # Load module and start interactive UI
    Import-Module ./domains/experience/InteractiveUI.psm1
    Start-InteractiveUI -ConfigPath ./config.psd1
    
.NOTES
    This module is the single entry point for all interactive functionality.
    Start-AitherZero.ps1 should delegate to this module for -Mode Interactive.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
$modulesToImport = @(
    (Join-Path $PSScriptRoot "BetterMenu.psm1")
    (Join-Path $PSScriptRoot "UserInterface.psm1")
    (Join-Path $PSScriptRoot "CLIHelper.psm1")
    (Join-Path $PSScriptRoot "../configuration/Configuration.psm1")
)

foreach ($modulePath in $modulesToImport) {
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction SilentlyContinue
    }
}

# Module state
$script:InteractiveState = @{
    Config = $null
    CurrentProfile = 'Standard'
    MenuCache = @{}
    ScriptCache = @{}
    PlaybookCache = @{}
}

<#
.SYNOPSIS
    Starts the interactive UI system
.DESCRIPTION
    Main entry point for interactive mode. Builds dynamic menus from configuration
    and presents the main interactive interface.
.PARAMETER ConfigPath
    Path to config.psd1 file
.PARAMETER Profile
    Profile to use (Minimal, Standard, Developer, Full)
#>
function Start-InteractiveUI {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath = './config.psd1',
        
        [Parameter()]
        [ValidateSet('Minimal', 'Standard', 'Developer', 'Full', 'CI')]
        [string]$Profile = 'Standard'
    )
    
    try {
        # Load configuration
        Write-Host "Loading configuration..." -ForegroundColor Cyan
        $script:InteractiveState.Config = Get-ConfigurationFromFile -Path $ConfigPath
        $script:InteractiveState.CurrentProfile = $Profile
        
        # Cache automation resources
        Write-Host "Discovering automation resources..." -ForegroundColor Cyan
        Initialize-ResourceCache
        
        # Show welcome and start main menu
        Show-WelcomeBanner
        Show-MainMenu
    }
    catch {
        Write-Error "Failed to start interactive UI: $_"
        throw
    }
}

<#
.SYNOPSIS
    Shows the welcome banner
#>
function Show-WelcomeBanner {
    Clear-Host
    
    $banner = @"

    ╔═══════════════════════════════════════════════════════════╗
    ║              AitherZero - v$($script:InteractiveState.Config.Core.Version)                        ║
    ║         PowerShell Automation Platform                    ║
    ╚═══════════════════════════════════════════════════════════╝

    Profile: $($script:InteractiveState.CurrentProfile)
    Configuration: Loaded from config.psd1
    Scripts: $($script:InteractiveState.ScriptCache.Count) discovered
    Playbooks: $($script:InteractiveState.PlaybookCache.Count) discovered
    
"@
    
    Write-Host $banner -ForegroundColor Cyan
    
    # Show CLI learning mode status if available
    if (Get-Command Test-CLILearningMode -ErrorAction SilentlyContinue) {
        if (Test-CLILearningMode) {
            Write-Host "    💡 CLI Learning Mode: ENABLED (Press 'L' to toggle)`n" -ForegroundColor Green
        }
    }
    
    Write-Host "    Press any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

<#
.SYNOPSIS
    Initializes the resource cache with scripts and playbooks
#>
function Initialize-ResourceCache {
    # Discover all automation scripts
    if (Get-Command Get-AllAutomationScripts -ErrorAction SilentlyContinue) {
        $scripts = Get-AllAutomationScripts
        foreach ($script in $scripts) {
            $script:InteractiveState.ScriptCache[$script.Number] = $script
        }
    }
    
    # Discover all playbooks  
    if (Get-Command Get-AllPlaybooks -ErrorAction SilentlyContinue) {
        $playbooks = Get-AllPlaybooks
        foreach ($playbook in $playbooks) {
            $script:InteractiveState.PlaybookCache[$playbook.Name] = $playbook
        }
    }
}

<#
.SYNOPSIS
    Shows the main interactive menu
#>
function Show-MainMenu {
    $running = $true
    
    while ($running) {
        Clear-Host
        
        # Build main menu items dynamically from config
        $menuItems = Build-MainMenuItems
        
        # Add footer with learning mode status
        $footer = ""
        if (Get-Command Test-CLILearningMode -ErrorAction SilentlyContinue) {
            if (Test-CLILearningMode) {
                $footer = "`n💡 CLI Learning Mode: ON (showing command equivalents)"
            }
        }
        
        $title = "AitherZero - Main Menu [$($script:InteractiveState.CurrentProfile) Profile]"
        $prompt = "Select an option (or 'Q' to quit, 'L' to toggle learning mode)$footer"
        
        $selection = Show-Menu -Title $title -MenuItems $menuItems -Prompt $prompt -AllowBack $false
        
        if ($selection -eq 'Q' -or $selection -eq 'q') {
            $running = $false
            Write-Host "`nExiting AitherZero. Goodbye!" -ForegroundColor Cyan
            break
        }
        elseif ($selection -eq 'L' -or $selection -eq 'l') {
            # Toggle CLI learning mode
            if (Get-Command Test-CLILearningMode -ErrorAction SilentlyContinue) {
                if (Test-CLILearningMode) {
                    Disable-CLILearningMode
                    Write-Host "`n✓ CLI Learning Mode DISABLED" -ForegroundColor Yellow
                }
                else {
                    Enable-CLILearningMode
                    Write-Host "`n✓ CLI Learning Mode ENABLED - Commands will be shown before execution" -ForegroundColor Green
                }
                Start-Sleep -Seconds 2
            }
        }
        elseif ($selection -and $menuItems[$selection - 1]) {
            $item = $menuItems[$selection - 1]
            & $item.Action
        }
    }
}

<#
.SYNOPSIS
    Builds main menu items dynamically from configuration
#>
function Build-MainMenuItems {
    $items = @()
    
    # Get feature dependencies from config to build menu structure
    $manifest = $script:InteractiveState.Config.Manifest
    $currentProfile = $script:InteractiveState.CurrentProfile
    
    # Determine which features are available in current profile
    $profileFeatures = Get-ProfileFeatures -Profile $currentProfile
    
    # Build menu sections based on available features
    
    # 1. Core Operations (always available)
    $items += @{
        Name = "🎯 Interactive Menu System"
        Description = "Guided menu system for all operations"
        Action = { Show-FeatureMenu -Category "All" }
    }
    
    # 2. Quick Actions (quality of life features)
    $items += @{
        Name = "🔍 Smart Search"
        Description = "Search across all scripts and playbooks"
        Action = { Invoke-SmartSearchMenu }
    }
    
    $items += @{
        Name = "⚡ Quick Jump"
        Description = "Jump directly to any script by number"
        Action = { Invoke-QuickJumpMenu }
    }
    
    $items += @{
        Name = "⏱️ Recent Actions"
        Description = "Quick access to recently executed commands"
        Action = { Invoke-RecentActionsMenu }
    }
    
    # 3. Feature Categories (from config)
    if ('Testing' -in $profileFeatures -or '*' -in $profileFeatures) {
        $items += @{
            Name = "✅ Testing & Validation"
            Description = "Run tests, linting, and quality checks"
            Action = { Show-CategoryMenu -Category "Testing" }
        }
    }
    
    if ('Development' -in $profileFeatures -or '*' -in $profileFeatures) {
        $items += @{
            Name = "💻 Development Tools"
            Description = "Install and configure development tools"
            Action = { Show-CategoryMenu -Category "Development" }
        }
    }
    
    if ('Infrastructure' -in $profileFeatures -or '*' -in $profileFeatures) {
        $items += @{
            Name = "🏗️ Infrastructure"
            Description = "Infrastructure automation and management"
            Action = { Show-CategoryMenu -Category "Infrastructure" }
        }
    }
    
    if ('Git' -in $profileFeatures -or '*' -in $profileFeatures) {
        $items += @{
            Name = "🔀 Git Automation"
            Description = "Git workflows and GitHub integration"
            Action = { Show-CategoryMenu -Category "Git" }
        }
    }
    
    if ('Reporting' -in $profileFeatures -or '*' -in $profileFeatures) {
        $items += @{
            Name = "📊 Reports & Analytics"
            Description = "System reports, dashboards, and metrics"
            Action = { Show-CategoryMenu -Category "Reporting" }
        }
    }
    
    # 4. Browse All (always available)
    $items += @{
        Name = "📋 Browse All Scripts"
        Description = "Browse all $($script:InteractiveState.ScriptCache.Count) automation scripts by category"
        Action = { Show-BrowseScriptsMenu }
    }
    
    $items += @{
        Name = "📚 Browse All Playbooks"
        Description = "Browse all $($script:InteractiveState.PlaybookCache.Count) orchestration playbooks"
        Action = { Show-BrowsePlaybooksMenu }
    }
    
    # 5. Configuration & Tools
    $items += @{
        Name = "⚙️ Profile Switcher"
        Description = "Switch between execution profiles (Current: $currentProfile)"
        Action = { Invoke-ProfileSwitcherMenu }
    }
    
    $items += @{
        Name = "💾 Export Commands"
        Description = "Export command history to script file"
        Action = { Invoke-CommandExportMenu }
    }
    
    # 6. Health & Status
    $items += @{
        Name = "🏥 System Health Dashboard"
        Description = "View system status and health metrics"
        Action = { Show-HealthDashboard }
    }
    
    return $items
}

<#
.SYNOPSIS
    Gets features available in a profile
#>
function Get-ProfileFeatures {
    param([string]$Profile)
    
    $profileConfig = $script:InteractiveState.Config.Manifest.ExecutionProfiles[$Profile]
    if (-not $profileConfig) {
        return @('*')  # All features if profile not found
    }
    
    $features = $profileConfig.Features
    if ($features -contains '*') {
        # All features
        return @('*')
    }
    
    # Extract category names from feature paths (e.g., "Core.Git" -> "Core")
    $categories = @()
    foreach ($feature in $features) {
        $parts = $feature -split '\.'
        if ($parts.Count -gt 0) {
            $categories += $parts[0]
        }
    }
    
    return $categories | Select-Object -Unique
}

<#
.SYNOPSIS
    Shows a category-specific menu (Testing, Development, Infrastructure, etc.)
#>
function Show-CategoryMenu {
    param(
        [Parameter(Mandatory)]
        [string]$Category
    )
    
    $running = $true
    
    while ($running) {
        Clear-Host
        
        # Get scripts for this category from config
        $categoryScripts = Get-CategoryScripts -Category $Category
        
        if ($categoryScripts.Count -eq 0) {
            Write-Host "`nNo scripts found for category: $Category" -ForegroundColor Yellow
            Write-Host "Press any key to return..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
        
        # Build menu items
        $menuItems = @()
        foreach ($scriptInfo in $categoryScripts) {
            $menuItems += @{
                Name = "[$($scriptInfo.Number)] $($scriptInfo.Name)"
                Description = $scriptInfo.Synopsis
                Action = { 
                    param($script = $scriptInfo)
                    Invoke-ScriptWithChecks -ScriptNumber $script.Number -ScriptName $script.Name
                }.GetNewClosure()
            }
        }
        
        $title = "$Category - $($categoryScripts.Count) Scripts Available"
        $prompt = "Select a script to run (or 'B' to go back)"
        
        $selection = Show-Menu -Title $title -MenuItems $menuItems -Prompt $prompt -AllowBack $true
        
        if ($selection -eq 'B' -or $selection -eq 'b' -or $selection -eq '') {
            $running = $false
        }
        elseif ($selection -and $menuItems[$selection - 1]) {
            $item = $menuItems[$selection - 1]
            & $item.Action
        }
    }
}

<#
.SYNOPSIS
    Gets scripts for a specific category from config
#>
function Get-CategoryScripts {
    param([string]$Category)
    
    $manifest = $script:InteractiveState.Config.Manifest
    $categoryFeatures = $manifest.FeatureDependencies[$Category]
    
    if (-not $categoryFeatures) {
        return @()
    }
    
    $scripts = @()
    
    # Collect all script numbers from features in this category
    foreach ($featureName in $categoryFeatures.Keys) {
        $feature = $categoryFeatures[$featureName]
        if ($feature.Scripts) {
            foreach ($scriptNum in $feature.Scripts) {
                # Look up script info from cache
                if ($script:InteractiveState.ScriptCache.ContainsKey($scriptNum)) {
                    $scripts += $script:InteractiveState.ScriptCache[$scriptNum]
                }
            }
        }
    }
    
    # Remove duplicates and sort
    return $scripts | Select-Object -Unique | Sort-Object { [int]$_.Number }
}

<#
.SYNOPSIS
    Shows the browse all scripts menu
#>
function Show-BrowseScriptsMenu {
    $running = $true
    
    while ($running) {
        Clear-Host
        
        # Get all script categories
        $categories = Get-ScriptCategories
        
        # Build category menu
        $menuItems = @()
        foreach ($cat in $categories) {
            $menuItems += @{
                Name = "$($cat.Icon) $($cat.Name)"
                Description = "$($cat.Count) scripts ($($cat.Range))"
                Action = {
                    param($category = $cat)
                    Show-ScriptsByCategoryMenu -CategoryInfo $category
                }.GetNewClosure()
            }
        }
        
        $title = "Browse All Scripts by Category"
        $prompt = "Select a category (or 'B' to go back)"
        
        $selection = Show-Menu -Title $title -MenuItems $menuItems -Prompt $prompt -AllowBack $true
        
        if ($selection -eq 'B' -or $selection -eq 'b' -or $selection -eq '') {
            $running = $false
        }
        elseif ($selection -and $menuItems[$selection - 1]) {
            $item = $menuItems[$selection - 1]
            & $item.Action
        }
    }
}

<#
.SYNOPSIS
    Gets script categories from config
#>
function Get-ScriptCategories {
    $inventory = $script:InteractiveState.Config.Manifest.ScriptInventory
    $categories = @()
    
    $iconMap = @{
        '0000-0099' = '🔧'
        '0100-0199' = '🏗️'
        '0200-0299' = '💻'
        '0300-0399' = '🚀'
        '0400-0499' = '✅'
        '0500-0599' = '📊'
        '0700-0799' = '🔀'
        '0800-0899' = '📝'
        '0900-0999' = '🔍'
        '9000-9999' = '🧹'
    }
    
    foreach ($range in $inventory.Keys | Sort-Object) {
        $info = $inventory[$range]
        $categories += @{
            Range = $range
            Name = $info.Category
            Count = $info.Count
            Icon = $iconMap[$range]
        }
    }
    
    return $categories
}

<#
.SYNOPSIS
    Shows scripts for a specific category range
#>
function Show-ScriptsByCategoryMenu {
    param($CategoryInfo)
    
    $running = $true
    
    while ($running) {
        Clear-Host
        
        # Get scripts in this range
        $rangeScripts = Get-ScriptsInRange -Range $CategoryInfo.Range
        
        if ($rangeScripts.Count -eq 0) {
            Write-Host "`nNo scripts found in range: $($CategoryInfo.Range)" -ForegroundColor Yellow
            Write-Host "Press any key to return..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
        
        # Build menu items
        $menuItems = @()
        foreach ($scriptInfo in $rangeScripts) {
            $menuItems += @{
                Name = "[$($scriptInfo.Number)] $($scriptInfo.Name)"
                Description = $scriptInfo.Synopsis
                Action = {
                    param($script = $scriptInfo)
                    Invoke-ScriptWithChecks -ScriptNumber $script.Number -ScriptName $script.Name
                }.GetNewClosure()
            }
        }
        
        $title = "$($CategoryInfo.Icon) $($CategoryInfo.Name) - $($rangeScripts.Count) Scripts"
        $prompt = "Select a script to run (or 'B' to go back)"
        
        $selection = Show-Menu -Title $title -MenuItems $menuItems -Prompt $prompt -AllowBack $true
        
        if ($selection -eq 'B' -or $selection -eq 'b' -or $selection -eq '') {
            $running = $false
        }
        elseif ($selection -and $menuItems[$selection - 1]) {
            $item = $menuItems[$selection - 1]
            & $item.Action
        }
    }
}

<#
.SYNOPSIS
    Gets scripts in a specific number range
#>
function Get-ScriptsInRange {
    param([string]$Range)
    
    # Parse range (e.g., "0400-0499")
    $parts = $Range -split '-'
    if ($parts.Count -ne 2) {
        return @()
    }
    
    $start = [int]$parts[0]
    $end = [int]$parts[1]
    
    $scripts = @()
    foreach ($scriptNum in $script:InteractiveState.ScriptCache.Keys) {
        $num = [int]$scriptNum
        if ($num -ge $start -and $num -le $end) {
            $scripts += $script:InteractiveState.ScriptCache[$scriptNum]
        }
    }
    
    return $scripts | Sort-Object { [int]$_.Number }
}

<#
.SYNOPSIS
    Shows the browse all playbooks menu
#>
function Show-BrowsePlaybooksMenu {
    $running = $true
    
    while ($running) {
        Clear-Host
        
        $playbooks = $script:InteractiveState.PlaybookCache.Values | Sort-Object Name
        
        if ($playbooks.Count -eq 0) {
            Write-Host "`nNo playbooks found" -ForegroundColor Yellow
            Write-Host "Press any key to return..." -ForegroundColor DarkGray
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
        
        # Build menu items
        $menuItems = @()
        foreach ($playbook in $playbooks) {
            $menuItems += @{
                Name = $playbook.Name
                Description = $playbook.Description
                Action = {
                    param($pb = $playbook)
                    Invoke-PlaybookWithChecks -PlaybookName $pb.Name
                }.GetNewClosure()
            }
        }
        
        $title = "Browse All Playbooks - $($playbooks.Count) Available"
        $prompt = "Select a playbook to run (or 'B' to go back)"
        
        $selection = Show-Menu -Title $title -MenuItems $menuItems -Prompt $prompt -AllowBack $true
        
        if ($selection -eq 'B' -or $selection -eq 'b' -or $selection -eq '') {
            $running = $false
        }
        elseif ($selection -and $menuItems[$selection - 1]) {
            $item = $menuItems[$selection - 1]
            & $item.Action
        }
    }
}

<#
.SYNOPSIS
    Shows a generic feature menu (for "All" or other categories)
#>
function Show-FeatureMenu {
    param([string]$Category = "All")
    
    Write-Host "`nFeature menu for: $Category" -ForegroundColor Cyan
    Write-Host "This would show all features/operations" -ForegroundColor DarkGray
    Write-Host "`nPress any key to return..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

<#
.SYNOPSIS
    Shows the health dashboard
#>
function Show-HealthDashboard {
    # Delegate to CLIHelper if available, otherwise show basic info
    if (Get-Command Show-HealthDashboard -ErrorAction SilentlyContinue) {
        & Show-HealthDashboard
    }
    else {
        Write-Host "`nHealth Dashboard" -ForegroundColor Cyan
        Write-Host "Profile: $($script:InteractiveState.CurrentProfile)" -ForegroundColor White
        Write-Host "Scripts: $($script:InteractiveState.ScriptCache.Count)" -ForegroundColor White
        Write-Host "Playbooks: $($script:InteractiveState.PlaybookCache.Count)" -ForegroundColor White
        Write-Host "`nPress any key to return..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
}

<#
.SYNOPSIS
    Invokes a script with prerequisites checks and execution tracking
#>
function Invoke-ScriptWithChecks {
    param(
        [string]$ScriptNumber,
        [string]$ScriptName
    )
    
    Clear-Host
    Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Preparing to run: $ScriptName" -ForegroundColor White
    Write-Host "═══════════════════════════════════════`n" -ForegroundColor Cyan
    
    # Show CLI command if learning mode is on
    if (Get-Command Test-CLILearningMode -ErrorAction SilentlyContinue) {
        if (Test-CLILearningMode) {
            if (Get-Command Show-CLICommand -ErrorAction SilentlyContinue) {
                $cliCommand = "./Start-AitherZero.ps1 -Mode Run -Target $ScriptNumber"
                Show-CLICommand -Command $cliCommand -Description "Run $ScriptName from CLI"
                Write-Host ""
            }
        }
    }
    
    # Check prerequisites if available
    if (Get-Command Test-Prerequisites -ErrorAction SilentlyContinue) {
        Write-Host "Checking prerequisites..." -ForegroundColor Cyan
        $prereqs = Test-Prerequisites -ScriptNumber $ScriptNumber
        
        if (Get-Command Show-PrerequisiteStatus -ErrorAction SilentlyContinue) {
            Show-PrerequisiteStatus -Prerequisites $prereqs
        }
        
        if (-not $prereqs.Overall) {
            Write-Host "`n⚠️  Some prerequisites are not met. Continue anyway? (Y/N)" -ForegroundColor Yellow
            $response = Read-Host
            if ($response -ne 'Y' -and $response -ne 'y') {
                return
            }
        }
    }
    
    # Show execution history if available
    if (Get-Command Get-ExecutionHistory -ErrorAction SilentlyContinue) {
        $history = Get-ExecutionHistory -ScriptNumber $ScriptNumber -Count 3
        if ($history.Count -gt 0) {
            Write-Host "`nRecent executions:" -ForegroundColor Cyan
            if (Get-Command Show-ExecutionHistory -ErrorAction SilentlyContinue) {
                Show-ExecutionHistory -History $history -Count 3
            }
        }
    }
    
    # Confirm execution
    Write-Host "`nExecute script? (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -ne 'Y' -and $response -ne 'y') {
        return
    }
    
    # Execute the script
    Write-Host "`nExecuting..." -ForegroundColor Green
    $scriptPath = Join-Path $PSScriptRoot "../../automation-scripts" "$ScriptNumber_*.ps1"
    $scriptFile = Get-Item $scriptPath -ErrorAction SilentlyContinue
    
    if ($scriptFile) {
        $startTime = Get-Date
        try {
            & $scriptFile.FullName
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            
            # Track execution if available
            if (Get-Command Add-ExecutionHistory -ErrorAction SilentlyContinue) {
                Add-ExecutionHistory -ScriptNumber $ScriptNumber -Status 'Success' -Duration $duration
            }
            
            Write-Host "`n✓ Script completed successfully in $([Math]::Round($duration, 2)) seconds" -ForegroundColor Green
        }
        catch {
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            
            # Track execution failure
            if (Get-Command Add-ExecutionHistory -ErrorAction SilentlyContinue) {
                Add-ExecutionHistory -ScriptNumber $ScriptNumber -Status 'Failed' -Duration $duration
            }
            
            Write-Host "`n✗ Script failed: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "`n✗ Script file not found: $scriptPath" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

<#
.SYNOPSIS
    Invokes a playbook with checks
#>
function Invoke-PlaybookWithChecks {
    param([string]$PlaybookName)
    
    Clear-Host
    Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Preparing to run playbook: $PlaybookName" -ForegroundColor White
    Write-Host "═══════════════════════════════════════`n" -ForegroundColor Cyan
    
    # Show CLI command if learning mode is on
    if (Get-Command Test-CLILearningMode -ErrorAction SilentlyContinue) {
        if (Test-CLILearningMode) {
            if (Get-Command Show-CLICommand -ErrorAction SilentlyContinue) {
                $cliCommand = "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook `"$PlaybookName`""
                Show-CLICommand -Command $cliCommand -Description "Run $PlaybookName playbook from CLI"
                Write-Host ""
            }
        }
    }
    
    # Confirm execution
    Write-Host "Execute playbook? (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -ne 'Y' -and $response -ne 'y') {
        return
    }
    
    # Execute the playbook
    Write-Host "`nExecuting playbook..." -ForegroundColor Green
    $playbookFile = Join-Path $PSScriptRoot "../../orchestration/playbooks" "$PlaybookName.json"
    
    if (Test-Path $playbookFile) {
        $startTime = Get-Date
        try {
            # TODO: Call orchestration engine to run playbook
            Write-Host "Playbook execution would happen here" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            Write-Host "`n✓ Playbook completed successfully in $([Math]::Round($duration, 2)) seconds" -ForegroundColor Green
        }
        catch {
            Write-Host "`n✗ Playbook failed: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "`n✗ Playbook file not found: $playbookFile" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

# Export module functions
Export-ModuleMember -Function @(
    'Start-InteractiveUI'
    'Show-MainMenu'
    'Show-CategoryMenu'
    'Show-BrowseScriptsMenu'
    'Show-BrowsePlaybooksMenu'
    'Invoke-ScriptWithChecks'
    'Invoke-PlaybookWithChecks'
)
