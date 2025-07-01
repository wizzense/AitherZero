#Requires -Version 7.0

<#
.SYNOPSIS
    Dynamic menu system for AitherZero with module discovery
.DESCRIPTION
    Provides an enhanced interactive menu with module capabilities
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
        
        # Show banner
        Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
        Write-Host "     _    _ _   _               _____                 " -ForegroundColor Cyan
        Write-Host "    / \  (_) |_| |__   ___ _ _|__  /___ _ __ ___     " -ForegroundColor Cyan
        Write-Host "   / _ \ | | __| '_ \ / _ \ '__| / // _ \ '__/ _ \    " -ForegroundColor Cyan
        Write-Host "  / ___ \| | |_| | | |  __/ |   / /|  __/ | | (_) |   " -ForegroundColor Cyan
        Write-Host " /_/   \_\_|\__|_| |_|\___|_|  /____\___|_|  \___/    " -ForegroundColor Cyan
        Write-Host "                                                       " -ForegroundColor Cyan
        Write-Host " $Title" -ForegroundColor Yellow
        Write-Host "$('=' * 80)" -ForegroundColor Cyan
        
        # Get module capabilities
        $modules = Get-ModuleCapabilities
        
        if ($FirstRun) {
            Write-Host "`n🎉 Welcome to AitherZero!" -ForegroundColor Green
            Write-Host "This appears to be your first run. Let's get you started!" -ForegroundColor Yellow
            Write-Host ""
        }
        
        # Group modules by category
        $categories = $modules | Group-Object Category | Sort-Object Name
        
        Write-Host "`n🧩 Available Modules:" -ForegroundColor Green
        Write-Host ""
        
        $menuIndex = 1
        $menuMap = @{}
        
        # Special menu items at the top
        Write-Host "📋 Quick Actions:" -ForegroundColor Yellow
        Write-Host "  [$menuIndex] 🚀 Quick Start Wizard" -ForegroundColor Cyan
        $menuMap[$menuIndex] = @{ Type = 'QuickStart' }
        $menuIndex++
        
        Write-Host "  [$menuIndex] ⚙️  Edit Configuration" -ForegroundColor Cyan
        $menuMap[$menuIndex] = @{ Type = 'EditConfig' }
        $menuIndex++
        
        Write-Host "  [$menuIndex] 🔄 Switch Configuration Profile" -ForegroundColor Cyan
        $menuMap[$menuIndex] = @{ Type = 'SwitchConfig' }
        $menuIndex++
        
        Write-Host ""
        
        # Display modules by category
        foreach ($category in $categories) {
            Write-Host "📁 $($category.Name):" -ForegroundColor Yellow
            
            foreach ($module in $category.Group) {
                $displayName = "[$menuIndex] $($module.DisplayName)"
                Write-Host "  $displayName" -ForegroundColor White -NoNewline
                Write-Host " - $($module.Description)" -ForegroundColor Gray
                
                $menuMap[$menuIndex] = @{
                    Type = 'Module'
                    Module = $module
                }
                $menuIndex++
            }
            Write-Host ""
        }
        
        # Legacy scripts support
        $scriptsPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts'
        if (Test-Path $scriptsPath) {
            $scripts = Get-ChildItem -Path $scriptsPath -Filter '*.ps1' | Sort-Object Name
            if ($scripts) {
                Write-Host "📜 Legacy Scripts:" -ForegroundColor Yellow
                foreach ($script in $scripts) {
                    Write-Host "  [$menuIndex] $($script.BaseName)" -ForegroundColor DarkGray
                    $menuMap[$menuIndex] = @{
                        Type = 'Script'
                        Script = $script
                    }
                    $menuIndex++
                }
                Write-Host ""
            }
        }
        
        # Menu options
        Write-Host "🔧 Options:" -ForegroundColor Magenta
        Write-Host "  [R] Refresh menu" -ForegroundColor Gray
        Write-Host "  [H] Help & Documentation" -ForegroundColor Gray
        Write-Host "  [Q] Quit" -ForegroundColor Gray
        Write-Host ""
        
        # Get user selection
        $selection = Read-Host "Select an option (1-$($menuIndex-1), R, H, Q)"
        
        switch ($selection.ToUpper()) {
            'Q' {
                $menuRunning = $false
                Write-Host "`n👋 Thank you for using AitherZero!" -ForegroundColor Green
                return
            }
            'R' {
                Write-Host "`n🔄 Refreshing menu..." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
                continue
            }
            'H' {
                Show-Help
                Read-Host "`nPress Enter to continue"
                continue
            }
            default {
                if ($selection -match '^\d+$') {
                    $selectedIndex = [int]$selection
                    if ($menuMap.ContainsKey($selectedIndex)) {
                        $selectedItem = $menuMap[$selectedIndex]
                        
                        switch ($selectedItem.Type) {
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
                                Show-ModuleMenu -Module $selectedItem.Module -Config $Config
                            }
                            'Script' {
                                Invoke-LegacyScript -Script $selectedItem.Script -Config $Config
                            }
                        }
                        
                        Write-Host "`nPress Enter to return to main menu..."
                        Read-Host
                    } else {
                        Write-Host "`n❌ Invalid selection: $selection" -ForegroundColor Red
                        Start-Sleep -Seconds 2
                    }
                } else {
                    Write-Host "`n❌ Invalid option: $selection" -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
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
                Write-Host "`nInteractive configuration editing not yet implemented" -ForegroundColor Yellow
                # TODO: Implement interactive config editor
            }
            '3' {
                Write-Host "`nReset to defaults not yet implemented" -ForegroundColor Yellow
                # TODO: Implement config reset
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

# Export main function
Export-ModuleMember -Function Show-DynamicMenu