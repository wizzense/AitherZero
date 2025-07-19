#Requires -Version 7.0

<#
.SYNOPSIS
    Enhanced dynamic menu system for AitherZero with multi-input support
.DESCRIPTION
    Provides an interactive menu with multi-column layout and flexible input options
#>

# Source module capabilities if not already loaded
$moduleCapabilitiesPath = Join-Path $PSScriptRoot 'Get-ModuleCapabilities.ps1'
if (Test-Path $moduleCapabilitiesPath) {
    . $moduleCapabilitiesPath
}

function Show-DynamicMenu {
    [CmdletBinding()]
    param(
        [string]$Title = "AitherZero Infrastructure Automation",
        [hashtable]$Config = @{},
        [switch]$FirstRun
    )

    $menuRunning = $true

    while ($menuRunning) {
        Clear-Host

        # Show compact banner
        Write-Host "`n$('═' * 80)" -ForegroundColor Cyan
        Write-Host "    _    _ _   _               _____                 " -ForegroundColor Cyan -NoNewline
        Write-Host "    $Title" -ForegroundColor Yellow
        Write-Host "   / \  (_) |_| |__   ___ _ _|__  /___ _ __ ___     " -ForegroundColor Cyan -NoNewline
        Write-Host "    Version $(Get-Content (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'VERSION') -ErrorAction SilentlyContinue)" -ForegroundColor DarkGray
        Write-Host "  / _ \ | | __| '_ \ / _ \ '__| / // _ \ '__/ _ \    " -ForegroundColor Cyan
        Write-Host " / ___ \| | |_| | | |  __/ |   / /|  __/ | | (_) |   " -ForegroundColor Cyan
        Write-Host "/_/   \_\_|\__|_| |_|\___|_|  /____\___|_|  \___/    " -ForegroundColor Cyan
        Write-Host "$('═' * 80)" -ForegroundColor Cyan

        if ($FirstRun) {
            Write-Host "`n🎉 Welcome to AitherZero!" -ForegroundColor Green
            Write-Host "This appears to be your first run. Let's get you started!" -ForegroundColor Yellow
        }

        # Build menu structure
        $menuStructure = Build-MenuStructure -Config $Config

        # Display menu with multi-column layout
        Display-MenuColumns -MenuStructure $menuStructure

        # Show input options
        Write-Host "`n📝 Input Options:" -ForegroundColor Magenta
        Write-Host "  • Menu number (e.g., 3)" -ForegroundColor Gray
        Write-Host "  • Script prefix (e.g., 0200)" -ForegroundColor Gray
        Write-Host "  • Script name (e.g., Get-SystemInfo)" -ForegroundColor Gray
        Write-Host "  • Multiple items (e.g., 0200,0201,0202 or 3,5,7)" -ForegroundColor Gray
        Write-Host "  • [R] Refresh  [H] Help  [Q] Quit" -ForegroundColor Gray

        # Get user selection
        $selection = Read-Host "`nEnter your selection"

        # Process input
        $result = Process-MenuInput -Selection $selection -MenuStructure $menuStructure -Config $Config

        if ($result.Exit) {
            $menuRunning = $false
            Write-Host "`n👋 Thank you for using AitherZero!" -ForegroundColor Green
        } elseif ($result.Message) {
            Write-Host "`n$($result.Message)" -ForegroundColor $result.Color
            if (-not $result.NoWait) {
                Read-Host "`nPress Enter to continue"
            }
        }
    }
}

function Build-MenuStructure {
    param([hashtable]$Config)

    $structure = @{
        Items = @()
        ByIndex = @{}
        ByPrefix = @{}
        ByName = @{}
        NextIndex = 1
    }

    # Add quick actions
    $quickActions = @(
        @{ Type = 'QuickStart'; Name = '🚀 Quick Start Wizard'; Description = 'First-time setup' }
        @{ Type = 'EditConfig'; Name = '⚙️  Edit Configuration'; Description = 'Modify settings' }
        @{ Type = 'SwitchConfig'; Name = '🔄 Switch Profile'; Description = 'Change configuration' }
    )

    foreach ($action in $quickActions) {
        $item = @{
            Index = $structure.NextIndex
            Type = $action.Type
            Name = $action.Name
            Description = $action.Description
            Category = '📋 Quick Actions'
            DisplayName = $action.Name
        }
        $structure.Items += $item
        $structure.ByIndex[$structure.NextIndex] = $item
        $structure.NextIndex++
    }

    # Get modules
    $modules = Get-ModuleCapabilities

    foreach ($module in $modules) {
        $item = @{
            Index = $structure.NextIndex
            Type = 'Module'
            Module = $module
            Name = $module.Name
            DisplayName = $module.DisplayName
            Description = $module.Description
            Category = "📁 $($module.Category)"
        }
        $structure.Items += $item
        $structure.ByIndex[$structure.NextIndex] = $item
        $structure.ByName[$module.Name.ToLower()] = $item
        $structure.NextIndex++
    }

    # Get legacy scripts
    $scriptsPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts'
    if (Test-Path $scriptsPath) {
        $scripts = Get-ChildItem -Path $scriptsPath -Filter '*.ps1' | Sort-Object Name
        foreach ($script in $scripts) {
            # Extract prefix if present (e.g., "0200_Get-SystemInfo.ps1")
            $prefix = $null
            if ($script.BaseName -match '^(\d{4})_(.+)$') {
                $prefix = $matches[1]
                $scriptName = $matches[2]
            } else {
                $scriptName = $script.BaseName
            }

            $item = @{
                Index = $structure.NextIndex
                Type = 'Script'
                Script = $script
                Name = $scriptName
                DisplayName = $script.BaseName
                Description = "Legacy script"
                Category = '📜 Legacy Scripts'
                Prefix = $prefix
            }

            $structure.Items += $item
            $structure.ByIndex[$structure.NextIndex] = $item
            $structure.ByName[$scriptName.ToLower()] = $item
            $structure.ByName[$script.BaseName.ToLower()] = $item

            if ($prefix) {
                $structure.ByPrefix[$prefix] = $item
            }

            $structure.NextIndex++
        }
    }

    return $structure
}

function Display-MenuColumns {
    param($MenuStructure)

    # Get terminal width
    $terminalWidth = $Host.UI.RawUI.WindowSize.Width
    if ($terminalWidth -lt 80) { $terminalWidth = 80 }

    # Calculate column layout
    $columnWidth = 38  # Width for each menu item column
    $columnCount = [Math]::Floor(($terminalWidth - 4) / $columnWidth)
    if ($columnCount -lt 1) { $columnCount = 1 }
    if ($columnCount -gt 3) { $columnCount = 3 }  # Max 3 columns for readability

    # Group items by category
    $categories = $MenuStructure.Items | Group-Object Category | Sort-Object Name

    foreach ($category in $categories) {
        Write-Host "`n$($category.Name):" -ForegroundColor Yellow

        # Process items in columns
        $items = $category.Group
        $itemsPerColumn = [Math]::Ceiling($items.Count / $columnCount)

        for ($row = 0; $row -lt $itemsPerColumn; $row++) {
            $line = ""
            for ($col = 0; $col -lt $columnCount; $col++) {
                $itemIndex = $row + ($col * $itemsPerColumn)
                if ($itemIndex -lt $items.Count) {
                    $item = $items[$itemIndex]

                    # Format item display
                    $indexStr = "[$($item.Index)]"
                    $nameStr = $item.DisplayName

                    # Add prefix if available
                    if ($item.Prefix) {
                        $indexStr = "[$($item.Index)/$($item.Prefix)]"
                    }

                    # Truncate name if too long
                    $maxNameLength = $columnWidth - $indexStr.Length - 3
                    if ($nameStr.Length -gt $maxNameLength) {
                        $nameStr = $nameStr.Substring(0, $maxNameLength - 3) + "..."
                    }

                    # Build column entry
                    $entry = "$indexStr $nameStr"
                    $line += $entry.PadRight($columnWidth)
                }
            }
            Write-Host "  $line" -ForegroundColor White
        }
    }
}

function Process-MenuInput {
    param(
        [string]$Selection,
        $MenuStructure,
        [hashtable]$Config
    )

    switch ($Selection.ToUpper()) {
        'Q' {
            return @{ Exit = $true }
        }
        'R' {
            return @{ Message = "🔄 Refreshing menu..."; Color = 'Yellow'; NoWait = $true }
        }
        'H' {
            Show-Help
            return @{ Message = ""; NoWait = $false }
        }
        default {
            # Parse comma-separated inputs
            $inputs = $Selection -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

            if ($inputs.Count -eq 0) {
                return @{ Message = "❌ No valid input provided"; Color = 'Red'; NoWait = $true }
            }

            $executedItems = @()

            foreach ($input in $inputs) {
                $item = Find-MenuItem -Input $input -MenuStructure $MenuStructure

                if ($item) {
                    $executedItems += $item
                    Execute-MenuItem -Item $item -Config $Config
                } else {
                    Write-Host "❌ Invalid selection: $input" -ForegroundColor Red
                }
            }

            if ($executedItems.Count -gt 0) {
                $names = $executedItems | ForEach-Object { $_.DisplayName }
                return @{
                    Message = "✅ Executed: $($names -join ', ')"
                    Color = 'Green'
                    NoWait = $false
                }
            } else {
                return @{ Message = "❌ No valid items found"; Color = 'Red'; NoWait = $true }
            }
        }
    }
}

function Find-MenuItem {
    param(
        [string]$Input,
        $MenuStructure
    )

    # Try as menu index
    if ($Input -match '^\d+$') {
        $index = [int]$Input
        if ($MenuStructure.ByIndex.ContainsKey($index)) {
            return $MenuStructure.ByIndex[$index]
        }
    }

    # Try as 4-digit prefix
    if ($Input -match '^\d{4}$') {
        if ($MenuStructure.ByPrefix.ContainsKey($Input)) {
            return $MenuStructure.ByPrefix[$Input]
        }
    }

    # Try as name (case-insensitive)
    $lowerInput = $Input.ToLower()
    if ($MenuStructure.ByName.ContainsKey($lowerInput)) {
        return $MenuStructure.ByName[$lowerInput]
    }

    # Try partial name match
    $matches = $MenuStructure.ByName.Keys | Where-Object { $_ -like "*$lowerInput*" }
    if ($matches.Count -eq 1) {
        return $MenuStructure.ByName[$matches[0]]
    }

    return $null
}

function Execute-MenuItem {
    param(
        $Item,
        [hashtable]$Config
    )

    Write-Host "`n🚀 Executing: $($Item.DisplayName)" -ForegroundColor Green

    switch ($Item.Type) {
        'QuickStart' {
            Invoke-QuickStart -Config $Config
        }
        'EditConfig' {
            Edit-Configuration -Config $Config
        }
        'SwitchConfig' {
            Switch-ConfigurationProfile -Config $Config
        }
        'Module' {
            Show-ModuleMenu -Module $Item.Module -Config $Config
        }
        'Script' {
            Invoke-LegacyScript -Script $Item.Script -Config $Config
        }
    }
}

function Show-ModuleMenu {
    [CmdletBinding()]
    param(
        [PSCustomObject]$Module,
        [hashtable]$Config
    )

    Write-Host "`n🔧 Module: $($Module.DisplayName)" -ForegroundColor Green
    Write-Host "Description: $($Module.Description)" -ForegroundColor Gray
    Write-Host ""

    # Get quick actions for this module
    $quickActions = Get-ModuleQuickActions -ModuleName $Module.Name

    if ($quickActions) {
        Write-Host "Quick Actions:" -ForegroundColor Yellow
        $actionIndex = 1
        $actionMap = @{}

        foreach ($action in $quickActions) {
            Write-Host "  [$actionIndex] $($action.Name) - $($action.Description)" -ForegroundColor Cyan
            $actionMap[$actionIndex] = $action
            $actionIndex++
        }

        Write-Host ""
        Write-Host "  [L] List all functions" -ForegroundColor Gray
        Write-Host "  [B] Back to main menu" -ForegroundColor Gray
        Write-Host ""

        $actionSelection = Read-Host "Select action (1-$($actionIndex-1), L, B)"

        switch ($actionSelection.ToUpper()) {
            'B' { return }
            'L' {
                Write-Host "`nAll Functions in $($Module.Name):" -ForegroundColor Yellow
                foreach ($func in $Module.Functions) {
                    Write-Host "  • $func" -ForegroundColor White
                }
            }
            default {
                if ($actionSelection -match '^\d+$') {
                    $selectedAction = $actionMap[[int]$actionSelection]
                    if ($selectedAction) {
                        try {
                            Write-Host "`nExecuting: $($selectedAction.Function)..." -ForegroundColor Green

                            # Import module if needed
                            if (-not (Get-Module $Module.Name)) {
                                Import-Module $Module.Path -Force
                            }

                            # Execute the function
                            & $selectedAction.Function

                        } catch {
                            Write-Host "❌ Error executing action: $_" -ForegroundColor Red
                        }
                    }
                }
            }
        }
    } else {
        # Show all functions if no quick actions defined
        Write-Host "Available Functions:" -ForegroundColor Yellow
        foreach ($func in $Module.Functions) {
            Write-Host "  • $func" -ForegroundColor White
        }

        Write-Host "`nTo use these functions, import the module:" -ForegroundColor Gray
        Write-Host "  Import-Module $($Module.Name)" -ForegroundColor White
    }
}

function Invoke-QuickStart {
    [CmdletBinding()]
    param(
        [hashtable]$Config
    )

    Write-Host "`n🚀 AitherZero Quick Start Wizard" -ForegroundColor Green
    Write-Host "$('=' * 50)" -ForegroundColor Cyan

    # Try to use SetupWizard module
    try {
        if (Get-Module SetupWizard -ListAvailable) {
            Import-Module SetupWizard -Force
            Start-IntelligentSetup -Interactive
        } else {
            Write-Host "SetupWizard module not available. Running basic setup..." -ForegroundColor Yellow

            # Basic setup steps
            Write-Host "`nChecking environment..." -ForegroundColor Yellow
            Write-Host "✓ PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Green

            # Prompt for configuration
            $editConfig = Read-Host "`nWould you like to edit the configuration? (Y/N)"
            if ($editConfig -eq 'Y') {
                Edit-Configuration -Config $Config
            }
        }
    } catch {
        Write-Host "Error during setup: $_" -ForegroundColor Red
    }
}

function Edit-Configuration {
    [CmdletBinding()]
    param(
        [hashtable]$Config
    )

    Write-Host "`n⚙️  Configuration Editor" -ForegroundColor Green
    Write-Host "$('=' * 50)" -ForegroundColor Cyan

    # Try to find config file
    $configFile = $null
    $possiblePaths = @(
        (Join-Path $env:PROJECT_ROOT "configs/default-config.json"),
        (Join-Path $PSScriptRoot "../../configs/default-config.json"),
        "./configs/default-config.json"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $configFile = $path
            break
        }
    }

    if ($configFile) {
        Write-Host "Current configuration file: $configFile" -ForegroundColor Yellow
        Write-Host ""

        # Show current config
        try {
            $currentConfig = Get-Content $configFile -Raw | ConvertFrom-Json
            Write-Host "Current Settings:" -ForegroundColor Cyan
            $currentConfig | ConvertTo-Json -Depth 3 | Write-Host
        } catch {
            Write-Host "Error reading configuration: $_" -ForegroundColor Red
        }

        Write-Host ""
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host "  [1] Open in default editor" -ForegroundColor White
        Write-Host "  [2] Edit key-value pairs interactively" -ForegroundColor White
        Write-Host "  [3] Reset to defaults" -ForegroundColor White
        Write-Host "  [B] Back" -ForegroundColor Gray

        $choice = Read-Host "Select option"

        switch ($choice) {
            '1' {
                # Open in default editor
                if ($IsWindows) {
                    Start-Process notepad.exe -ArgumentList $configFile -Wait
                } else {
                    $editor = $env:EDITOR ?? 'nano'
                    & $editor $configFile
                }
            }
            '2' {
                Edit-ConfigurationInteractive -ConfigFile $configFile
            }
            '3' {
                Write-Host "`nConfig reset functionality pending implementation" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "❌ Configuration file not found!" -ForegroundColor Red
        Write-Host "Checked paths:" -ForegroundColor Yellow
        foreach ($path in $possiblePaths) {
            Write-Host "  • $path" -ForegroundColor Gray
        }
    }
}

function Switch-ConfigurationProfile {
    [CmdletBinding()]
    param(
        [hashtable]$Config
    )

    Write-Host "`n🔄 Configuration Profile Switcher" -ForegroundColor Green
    Write-Host "$('=' * 50)" -ForegroundColor Cyan

    # Try to use ConfigurationCarousel module
    try {
        if (Get-Module ConfigurationCarousel -ListAvailable) {
            Import-Module ConfigurationCarousel -Force

            $configs = Get-AvailableConfigurations
            if ($configs) {
                Write-Host "Available Configurations:" -ForegroundColor Yellow
                $index = 1
                foreach ($cfg in $configs) {
                    Write-Host "  [$index] $($cfg.Name) - $($cfg.Description)" -ForegroundColor White
                    $index++
                }

                $selection = Read-Host "`nSelect configuration (1-$($configs.Count))"
                if ($selection -match '^\d+$') {
                    $selected = $configs[[int]$selection - 1]
                    if ($selected) {
                        Switch-ConfigurationSet -ConfigurationName $selected.Name
                        Write-Host "✓ Switched to configuration: $($selected.Name)" -ForegroundColor Green
                    }
                }
            } else {
                Write-Host "No alternative configurations found" -ForegroundColor Yellow
            }
        } else {
            Write-Host "ConfigurationCarousel module not available" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error switching configuration: $_" -ForegroundColor Red
    }
}

function Show-Help {
    Write-Host "`n📚 AitherZero Help" -ForegroundColor Green
    Write-Host "$('=' * 50)" -ForegroundColor Cyan

    Write-Host "`nAitherZero is a comprehensive infrastructure automation framework." -ForegroundColor White
    Write-Host ""

    Write-Host "Input Methods:" -ForegroundColor Yellow
    Write-Host "  • Menu Number: Type the number shown in brackets (e.g., 3)" -ForegroundColor White
    Write-Host "  • Script Prefix: Type the 4-digit prefix (e.g., 0200)" -ForegroundColor White
    Write-Host "  • Script Name: Type the script or module name (e.g., Get-SystemInfo)" -ForegroundColor White
    Write-Host "  • Multiple: Comma-separated list (e.g., 0200,0201,0202)" -ForegroundColor White
    Write-Host ""

    Write-Host "Key Features:" -ForegroundColor Yellow
    Write-Host "  • Infrastructure as Code with OpenTofu/Terraform" -ForegroundColor White
    Write-Host "  • Multi-environment configuration management" -ForegroundColor White
    Write-Host "  • Git workflow automation" -ForegroundColor White
    Write-Host "  • Automated backup and recovery" -ForegroundColor White
    Write-Host "  • AI tools integration" -ForegroundColor White
    Write-Host "  • Advanced orchestration engine" -ForegroundColor White
    Write-Host ""

    Write-Host "Getting Started:" -ForegroundColor Yellow
    Write-Host "  1. Run Quick Start Wizard for initial setup" -ForegroundColor White
    Write-Host "  2. Edit configuration to match your environment" -ForegroundColor White
    Write-Host "  3. Explore modules based on your needs" -ForegroundColor White
    Write-Host ""

    Write-Host "For more information:" -ForegroundColor Yellow
    Write-Host "  • Documentation: https://github.com/wizzense/AitherZero" -ForegroundColor White
    Write-Host "  • Issues: https://github.com/wizzense/AitherZero/issues" -ForegroundColor White
}

function Invoke-LegacyScript {
    [CmdletBinding()]
    param(
        [System.IO.FileInfo]$Script,
        [hashtable]$Config
    )

    Write-Host "`nExecuting legacy script: $($Script.BaseName)" -ForegroundColor Yellow

    try {
        & $Script.FullName -Config $Config
    } catch {
        Write-Host "Error executing script: $_" -ForegroundColor Red
    }
}

function Edit-ConfigurationInteractive {
    [CmdletBinding()]
    param(
        [string]$ConfigFile
    )

    Write-Host "`n📝 Interactive Configuration Editor" -ForegroundColor Green
    Write-Host "$('=' * 50)" -ForegroundColor Cyan

    try {
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json

        # Show UI preferences
        Write-Host "`nUI Preferences:" -ForegroundColor Yellow
        Write-Host "  [1] UI Mode: $($config.UIPreferences.Mode ?? 'auto')" -ForegroundColor White
        Write-Host "  [2] Default UI: $($config.UIPreferences.DefaultUI ?? 'enhanced')" -ForegroundColor White
        Write-Host "  [3] Show UI Selector: $($config.UIPreferences.ShowUISelector ?? $true)" -ForegroundColor White

        # Show common settings
        Write-Host "`nCommon Settings:" -ForegroundColor Yellow
        Write-Host "  [4] Computer Name: $($config.ComputerName)" -ForegroundColor White
        Write-Host "  [5] DNS Servers: $($config.DNSServers)" -ForegroundColor White
        Write-Host "  [6] Install Git: $($config.InstallGit)" -ForegroundColor White
        Write-Host "  [7] Install OpenTofu: $($config.InstallOpenTofu)" -ForegroundColor White

        Write-Host "`n  [S] Save changes" -ForegroundColor Green
        Write-Host "  [B] Back without saving" -ForegroundColor Gray
        Write-Host ""

        $editing = $true
        $modified = $false

        while ($editing) {
            $choice = Read-Host "Select option to edit (1-7, S, B)"

            switch ($choice.ToUpper()) {
                '1' {
                    $newValue = Read-Host "Enter UI Mode (auto/enhanced/classic) [current: $($config.UIPreferences.Mode)]"
                    if ($newValue -and $newValue -in @('auto', 'enhanced', 'classic')) {
                        if (-not $config.UIPreferences) { $config | Add-Member -NotePropertyName UIPreferences -NotePropertyValue @{} }
                        $config.UIPreferences.Mode = $newValue
                        $modified = $true
                        Write-Host "✓ UI Mode set to: $newValue" -ForegroundColor Green
                    }
                }
                '2' {
                    $newValue = Read-Host "Enter Default UI (enhanced/classic) [current: $($config.UIPreferences.DefaultUI)]"
                    if ($newValue -and $newValue -in @('enhanced', 'classic')) {
                        if (-not $config.UIPreferences) { $config | Add-Member -NotePropertyName UIPreferences -NotePropertyValue @{} }
                        $config.UIPreferences.DefaultUI = $newValue
                        $modified = $true
                        Write-Host "✓ Default UI set to: $newValue" -ForegroundColor Green
                    }
                }
                '3' {
                    $newValue = Read-Host "Show UI Selector (true/false) [current: $($config.UIPreferences.ShowUISelector)]"
                    if ($newValue -in @('true', 'false')) {
                        if (-not $config.UIPreferences) { $config | Add-Member -NotePropertyName UIPreferences -NotePropertyValue @{} }
                        $config.UIPreferences.ShowUISelector = ($newValue -eq 'true')
                        $modified = $true
                        Write-Host "✓ Show UI Selector set to: $newValue" -ForegroundColor Green
                    }
                }
                '4' {
                    $newValue = Read-Host "Enter Computer Name [current: $($config.ComputerName)]"
                    if ($newValue) {
                        $config.ComputerName = $newValue
                        $modified = $true
                        Write-Host "✓ Computer Name set to: $newValue" -ForegroundColor Green
                    }
                }
                '5' {
                    $newValue = Read-Host "Enter DNS Servers (comma-separated) [current: $($config.DNSServers)]"
                    if ($newValue) {
                        $config.DNSServers = $newValue
                        $modified = $true
                        Write-Host "✓ DNS Servers set to: $newValue" -ForegroundColor Green
                    }
                }
                '6' {
                    $newValue = Read-Host "Install Git (true/false) [current: $($config.InstallGit)]"
                    if ($newValue -in @('true', 'false')) {
                        $config.InstallGit = ($newValue -eq 'true')
                        $modified = $true
                        Write-Host "✓ Install Git set to: $newValue" -ForegroundColor Green
                    }
                }
                '7' {
                    $newValue = Read-Host "Install OpenTofu (true/false) [current: $($config.InstallOpenTofu)]"
                    if ($newValue -in @('true', 'false')) {
                        $config.InstallOpenTofu = ($newValue -eq 'true')
                        $modified = $true
                        Write-Host "✓ Install OpenTofu set to: $newValue" -ForegroundColor Green
                    }
                }
                'S' {
                    if ($modified) {
                        $config | ConvertTo-Json -Depth 10 | Out-File $ConfigFile -Encoding UTF8
                        Write-Host "`n✅ Configuration saved successfully!" -ForegroundColor Green
                    } else {
                        Write-Host "`nNo changes to save." -ForegroundColor Yellow
                    }
                    $editing = $false
                }
                'B' {
                    if ($modified) {
                        $confirm = Read-Host "You have unsaved changes. Discard them? (Y/N)"
                        if ($confirm -eq 'Y') {
                            $editing = $false
                        }
                    } else {
                        $editing = $false
                    }
                }
                default {
                    Write-Host "Invalid option: $choice" -ForegroundColor Red
                }
            }
        }
    } catch {
        Write-Host "Error editing configuration: $_" -ForegroundColor Red
    }
}

# Function is automatically available when dot-sourced
# Export-ModuleMember is only valid in .psm1 modules, not dot-sourced .ps1 files
