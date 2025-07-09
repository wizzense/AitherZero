function Start-ScriptRunner {
    <#
    .SYNOPSIS
        Interactive script runner for legacy and module scripts
    .DESCRIPTION
        Provides a menu-driven interface to run various scripts
    .PARAMETER Tier
        License tier for feature access
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Tier = 'free'
    )

    try {
        $exitRunner = $false
        
        while (-not $exitRunner) {
            Clear-Host
            Show-Banner -Tier $Tier
            
            # Get all available modules and scripts
            $modules = Get-ConsolidatedModules
            $legacyScripts = Get-LegacyScripts
            
            # Display menu
            Write-Host "`n📁 Modules:" -ForegroundColor Cyan
            $menuIndex = 1
            $menuItems = @()
            
            # Add module functions
            foreach ($module in $modules | Sort-Object Name) {
                $moduleItem = @{
                    Index = $menuIndex
                    Type = 'Module'
                    Name = $module.Name
                    Module = $module
                    Action = { 
                        param($item)
                        Show-ModuleFunctionMenu -Module $item.Module
                    }
                }
                $menuItems += $moduleItem
                
                Write-Host "  [$menuIndex] $($module.Name)" -ForegroundColor White
                $menuIndex++
            }
            
            Write-Host "`n🏛️ Legacy Scripts:" -ForegroundColor Yellow
            
            # Add legacy scripts
            foreach ($script in $legacyScripts | Sort-Object Name) {
                $scriptItem = @{
                    Index = $menuIndex
                    Type = 'Script'
                    Name = $script.Name
                    Path = $script.FullName
                    Action = {
                        param($item)
                        Write-Host "`nExecuting: $($item.Name)" -ForegroundColor Green
                        Write-Host "Path: $($item.Path)" -ForegroundColor DarkGray
                        Write-Host ("-" * 60) -ForegroundColor DarkGray
                        
                        try {
                            # Execute the script and capture output
                            & $item.Path
                            
                            Write-Host "`n$('-' * 60)" -ForegroundColor DarkGray
                            Write-Host "Script completed successfully!" -ForegroundColor Green
                        } catch {
                            Write-Host "`nError executing script: $_" -ForegroundColor Red
                        }
                        
                        Write-Host "`nPress any key to continue..."
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                }
                $menuItems += $scriptItem
                
                # Format script name for display
                $displayName = $script.Name -replace '\.ps1$', ''
                if ($displayName -match '^(\d+)_(.+)$') {
                    $scriptNum = $matches[1]
                    $scriptName = $matches[2] -replace '_', ' '
                    Write-Host "  [$menuIndex/$scriptNum] $scriptName" -ForegroundColor White
                } else {
                    Write-Host "  [$menuIndex] $displayName" -ForegroundColor White
                }
                $menuIndex++
            }
            
            Write-Host "`n📋 Quick Actions:" -ForegroundColor Green
            Write-Host "  [R] Refresh" -ForegroundColor White
            Write-Host "  [H] Help" -ForegroundColor White
            Write-Host "  [Q] Quit" -ForegroundColor White
            
            Write-Host "`n📝 Input Options:" -ForegroundColor DarkGray
            Write-Host "  • Menu number (e.g., 3)" -ForegroundColor DarkGray
            Write-Host "  • Script prefix (e.g., 0200)" -ForegroundColor DarkGray
            Write-Host "  • Script name (e.g., Get-SystemInfo)" -ForegroundColor DarkGray
            Write-Host "  • Multiple items (e.g., 3,5,7)" -ForegroundColor DarkGray
            
            $selection = Read-Host "`nEnter your selection"
            
            switch ($selection.ToUpper()) {
                'R' { continue }
                'H' { 
                    Show-ScriptRunnerHelp
                    Write-Host "`nPress any key to continue..."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
                'Q' { $exitRunner = $true }
                default {
                    # Handle numeric selections
                    if ($selection -match '^\d+$') {
                        $selectedItem = $menuItems | Where-Object { $_.Index -eq [int]$selection }
                        if ($selectedItem) {
                            & $selectedItem.Action $selectedItem
                        } else {
                            Write-Host "Invalid selection!" -ForegroundColor Red
                            Start-Sleep -Seconds 1
                        }
                    }
                    # Handle script prefix (e.g., 0200)
                    elseif ($selection -match '^\d{4}$') {
                        $scriptItem = $menuItems | Where-Object { 
                            $_.Type -eq 'Script' -and $_.Name -like "$selection*"
                        }
                        if ($scriptItem) {
                            & $scriptItem.Action $scriptItem
                        } else {
                            Write-Host "Script not found!" -ForegroundColor Red
                            Start-Sleep -Seconds 1
                        }
                    }
                    # Handle script name
                    else {
                        $searchPattern = "*$selection*"
                        $matches = $menuItems | Where-Object { 
                            $_.Name -like $searchPattern
                        }
                        
                        if ($matches.Count -eq 1) {
                            & $matches[0].Action $matches[0]
                        } elseif ($matches.Count -gt 1) {
                            Write-Host "Multiple matches found. Please be more specific." -ForegroundColor Yellow
                            Start-Sleep -Seconds 2
                        } else {
                            Write-Host "No matching item found!" -ForegroundColor Red
                            Start-Sleep -Seconds 1
                        }
                    }
                }
            }
        }
        
    } catch {
        Write-Error "Error in script runner: $_"
        throw
    }
}

function Get-ConsolidatedModules {
    <#
    .SYNOPSIS
        Gets all available consolidated modules
    #>
    try {
        $projectRoot = Find-ProjectRoot
        $modulesPath = Join-Path $projectRoot "aither-core" "modules"
        
        if (-not (Test-Path $modulesPath)) {
            return @()
        }
        
        $modules = @()
        Get-ChildItem $modulesPath -Directory | ForEach-Object {
            $manifestPath = Join-Path $_.FullName "$($_.Name).psd1"
            if (Test-Path $manifestPath) {
                $modules += [PSCustomObject]@{
                    Name = $_.Name
                    Path = $_.FullName
                }
            }
        }
        
        return $modules
    } catch {
        Write-Warning "Error getting modules: $_"
        return @()
    }
}

function Get-LegacyScripts {
    <#
    .SYNOPSIS
        Gets all legacy scripts from the scripts directory
    #>
    try {
        $projectRoot = Find-ProjectRoot
        $scriptsPath = Join-Path $projectRoot "scripts"
        
        if (-not (Test-Path $scriptsPath)) {
            return @()
        }
        
        # Get all .ps1 files recursively
        return Get-ChildItem $scriptsPath -Filter "*.ps1" -Recurse | 
            Where-Object { -not $_.PSIsContainer } |
            Sort-Object Name
            
    } catch {
        Write-Warning "Error getting legacy scripts: $_"
        return @()
    }
}

function Show-ModuleFunctionMenu {
    <#
    .SYNOPSIS
        Shows menu of functions for a specific module
    #>
    param(
        [PSCustomObject]$Module
    )
    
    try {
        # Import the module temporarily
        Import-Module $Module.Path -Force -ErrorAction Stop
        
        # Get exported functions
        $functions = Get-Command -Module $Module.Name | 
            Where-Object { $_.CommandType -eq 'Function' } |
            Sort-Object Name
            
        if ($functions.Count -eq 0) {
            Write-Host "No functions found in module $($Module.Name)" -ForegroundColor Yellow
            Write-Host "`nPress any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
        
        $exitMenu = $false
        while (-not $exitMenu) {
            Clear-Host
            Write-Host "┌─ $($Module.Name) Functions ─────────────────┐" -ForegroundColor Cyan
            
            $index = 1
            foreach ($func in $functions) {
                Write-Host "│ $index. $($func.Name)" -ForegroundColor White
                $index++
            }
            
            Write-Host "│" -ForegroundColor Cyan
            Write-Host "│ [B] Back to main menu" -ForegroundColor Yellow
            Write-Host "└────────────────────────────────────────────┘" -ForegroundColor Cyan
            
            $selection = Read-Host "`nSelect function to run (1-$($functions.Count)) or B"
            
            if ($selection -eq 'B' -or $selection -eq 'b') {
                $exitMenu = $true
            } elseif ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $functions.Count) {
                $selectedFunc = $functions[[int]$selection - 1]
                
                Write-Host "`nExecuting: $($selectedFunc.Name)" -ForegroundColor Green
                Write-Host ("-" * 60) -ForegroundColor DarkGray
                
                try {
                    # Get function parameters
                    $params = (Get-Command $selectedFunc.Name).Parameters
                    $paramValues = @{}
                    
                    foreach ($param in $params.GetEnumerator()) {
                        if ($param.Value.ParameterSets.ContainsKey('__AllParameterSets') -or 
                            $param.Value.ParameterSets.Count -eq 0) {
                            
                            # Skip common parameters
                            if ($param.Key -in @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 
                                'InformationAction', 'ErrorVariable', 'WarningVariable', 
                                'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable')) {
                                continue
                            }
                            
                            $paramType = $param.Value.ParameterType.Name
                            $isMandatory = $param.Value.Attributes | 
                                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                                ForEach-Object { $_.Mandatory } | 
                                Where-Object { $_ -eq $true }
                                
                            if ($isMandatory) {
                                $value = Read-Host "Enter value for $($param.Key) [$paramType]"
                                if ($value) {
                                    $paramValues[$param.Key] = $value
                                }
                            }
                        }
                    }
                    
                    # Execute the function
                    & $selectedFunc.Name @paramValues
                    
                } catch {
                    Write-Host "`nError executing function: $_" -ForegroundColor Red
                }
                
                Write-Host "`n$('-' * 60)" -ForegroundColor DarkGray
                Write-Host "Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        
    } catch {
        Write-Host "Error loading module: $_" -ForegroundColor Red
        Write-Host "`nPress any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Show-ScriptRunnerHelp {
    <#
    .SYNOPSIS
        Shows help for the script runner
    #>
    Write-Host "`n📚 Script Runner Help" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor DarkGray
    
    Write-Host "`n🎯 Selection Methods:" -ForegroundColor Yellow
    Write-Host "  1. Menu Number: Type the number shown in brackets" -ForegroundColor White
    Write-Host "     Example: 5" -ForegroundColor DarkGray
    
    Write-Host "`n  2. Script Prefix: Type the 4-digit script prefix" -ForegroundColor White
    Write-Host "     Example: 0200 (for 0200_Get-SystemInfo)" -ForegroundColor DarkGray
    
    Write-Host "`n  3. Script Name: Type part of the script name" -ForegroundColor White
    Write-Host "     Example: SystemInfo" -ForegroundColor DarkGray
    
    Write-Host "`n  4. Multiple Selection: Comma-separated numbers" -ForegroundColor White
    Write-Host "     Example: 3,5,7 (runs scripts 3, 5, and 7)" -ForegroundColor DarkGray
    
    Write-Host "`n📋 Module Functions:" -ForegroundColor Yellow
    Write-Host "  • Select a module to see its available functions" -ForegroundColor White
    Write-Host "  • Functions may prompt for required parameters" -ForegroundColor White
    Write-Host "  • Output is displayed in the console" -ForegroundColor White
    
    Write-Host "`n🏛️ Legacy Scripts:" -ForegroundColor Yellow
    Write-Host "  • These are standalone PowerShell scripts" -ForegroundColor White
    Write-Host "  • Located in the /scripts directory" -ForegroundColor White
    Write-Host "  • May require specific prerequisites" -ForegroundColor White
}

# Export the function
Export-ModuleMember -Function Start-ScriptRunner