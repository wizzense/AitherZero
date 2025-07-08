function Show-ModuleExplorer {
    <#
    .SYNOPSIS
        Shows the interactive module explorer UI
    .DESCRIPTION
        Displays all available modules and their functions with tier-based filtering
    .PARAMETER Tier
        License tier for feature access
    .EXAMPLE
        Show-ModuleExplorer -Tier "pro"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Tier = 'free'
    )

    try {
        $exitExplorer = $false

        while (-not $exitExplorer) {
            # Get all available modules
            $allModules = Get-ModuleDiscovery -Tier $Tier

            Clear-Host
            Write-Host "┌─ Module Explorer ───────────────────────────┐" -ForegroundColor Cyan
            Write-Host "│ Search: " -NoNewline -ForegroundColor Cyan
            $searchTerm = Read-Host
            Write-Host "│" -ForegroundColor Cyan

            # Filter modules if search term provided
            if ($searchTerm) {
                $filteredModules = $allModules | Where-Object {
                    $_.Name -like "*$searchTerm*" -or
                    $_.Category -like "*$searchTerm*" -or
                    $_.Description -like "*$searchTerm*" -or
                    $_.Functions.Name -like "*$searchTerm*"
                }
            } else {
                $filteredModules = $allModules
            }

            # Group by category
            $categories = $filteredModules | Group-Object Category | Sort-Object Name

            $menuItems = @()
            $itemIndex = 1

            foreach ($category in $categories) {
                Write-Host "│ ▼ $($category.Name) ($($category.Count) modules)" -ForegroundColor Green

                foreach ($module in $category.Group | Sort-Object Name) {
                    $lockIcon = if ($module.IsLocked) { " 🔒" } else { "" }
                    $tierBadge = if ($module.RequiredTier -ne 'free') { " [$($module.RequiredTier.ToUpper())]" } else { "" }

                    Write-Host "│   $itemIndex. $($module.Name)$tierBadge$lockIcon" -ForegroundColor White

                    $menuItems += @{
                        Index = $itemIndex
                        Module = $module
                    }
                    $itemIndex++
                }
                Write-Host "│" -ForegroundColor Cyan
            }

            Write-Host "│ [Actions]" -ForegroundColor Yellow
            Write-Host "│   V. View Module Details" -ForegroundColor White
            Write-Host "│   R. Run Module Function" -ForegroundColor White
            Write-Host "│   S. Search Again" -ForegroundColor White
            Write-Host "│   B. Back to Main Menu" -ForegroundColor White
            Write-Host "└─────────────────────────────────────────────┘" -ForegroundColor Cyan

            $selection = Read-Host "`nSelect module (1-$($menuItems.Count)) or action (V/R/S/B)"

            switch ($selection.ToUpper()) {
                'V' {
                    $moduleIndex = Read-Host "Enter module number to view"
                    if ($moduleIndex -match '^\d+$') {
                        $item = $menuItems | Where-Object { $_.Index -eq [int]$moduleIndex }
                        if ($item) {
                            Show-ModuleDetails -Module $item.Module -Tier $Tier
                        }
                    }
                }
                'R' {
                    $moduleIndex = Read-Host "Enter module number to run function from"
                    if ($moduleIndex -match '^\d+$') {
                        $item = $menuItems | Where-Object { $_.Index -eq [int]$moduleIndex }
                        if ($item) {
                            if ($item.Module.IsLocked) {
                                Write-Host "This module requires a $($item.Module.RequiredTier) license!" -ForegroundColor Red
                                Show-UpgradePrompt -RequiredTier $item.Module.RequiredTier
                            } else {
                                Show-ModuleFunctions -Module $item.Module
                            }
                        }
                    }
                }
                'S' {
                    # Loop will continue with new search
                }
                'B' {
                    $exitExplorer = $true
                }
                default {
                    if ($selection -match '^\d+$') {
                        $item = $menuItems | Where-Object { $_.Index -eq [int]$selection }
                        if ($item) {
                            Show-ModuleDetails -Module $item.Module -Tier $Tier
                        }
                    }
                }
            }
        }

    } catch {
        Write-Error "Error in module explorer: $_"
        throw
    }
}

function Show-ModuleDetails {
    param(
        [PSCustomObject]$Module,
        [string]$Tier
    )

    Clear-Host
    Write-Host "┌─ Module Details ────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ Name: $($Module.Name)" -ForegroundColor White
    Write-Host "│ Category: $($Module.Category)" -ForegroundColor White
    Write-Host "│ Required Tier: $($Module.RequiredTier)" -ForegroundColor White
    Write-Host "│ Status: " -NoNewline -ForegroundColor White
    if ($Module.IsLocked) {
        Write-Host "Locked 🔒" -ForegroundColor Red
    } else {
        Write-Host "Available ✓" -ForegroundColor Green
    }
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "│ Description:" -ForegroundColor Yellow
    Write-Host "│ $($Module.Description)" -ForegroundColor White
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "│ Functions ($($Module.Functions.Count)):" -ForegroundColor Yellow

    foreach ($func in $Module.Functions | Sort-Object Name) {
        Write-Host "│   • $($func.Name)" -ForegroundColor White
        if ($func.Description) {
            Write-Host "│     $($func.Description)" -ForegroundColor DarkGray
        }
    }

    Write-Host "└─────────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-ModuleFunctions {
    param(
        [PSCustomObject]$Module
    )

    if ($Module.Functions.Count -eq 0) {
        Write-Host "No public functions found in this module." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }

    $options = $Module.Functions | ForEach-Object {
        @{
            Text = "$($_.Name) - $($_.Description)"
            Action = $_.Name
            Function = $_
        }
    }

    $selected = Show-ContextMenu -Title "Select Function to Run" -Options $options -ReturnAction

    if ($selected) {
        $function = $options | Where-Object { $_.Action -eq $selected } | Select-Object -ExpandProperty Function

        # Prompt for parameters if needed
        if ($function.Parameters.Count -gt 0) {
            Write-Host "`nFunction Parameters:" -ForegroundColor Cyan
            $params = @{}

            foreach ($param in $function.Parameters) {
                Write-Host "$($param.Name) [$($param.Type)]" -NoNewline
                if ($param.Mandatory) {
                    Write-Host " (Required)" -NoNewline -ForegroundColor Yellow
                }
                Write-Host ": " -NoNewline

                $value = Read-Host
                if ($value) {
                    # Convert to appropriate type
                    switch ($param.Type) {
                        'switch' { $params[$param.Name] = [bool]::Parse($value) }
                        'int' { $params[$param.Name] = [int]::Parse($value) }
                        'string[]' { $params[$param.Name] = $value -split ',' }
                        default { $params[$param.Name] = $value }
                    }
                }
            }

            Write-Host "`nExecuting: $($function.Name)" -ForegroundColor Green
            try {
                & $function.Name @params
            } catch {
                Write-Error "Error executing function: $_"
            }
        } else {
            Write-Host "`nExecuting: $($function.Name)" -ForegroundColor Green
            try {
                & $function.Name
            } catch {
                Write-Error "Error executing function: $_"
            }
        }

        Write-Host "`nPress any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
