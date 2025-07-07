function Start-ScriptRunner {
    <#
    .SYNOPSIS
        Interactive script runner interface
    .DESCRIPTION
        Allows users to browse and execute available scripts with proper navigation back to main menu
    .PARAMETER Tier
        License tier for filtering available scripts
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
            Write-Host "┌─ Script Runner ─────────────────────────────┐" -ForegroundColor Cyan
            Write-Host "│ Available Scripts                           │" -ForegroundColor Yellow
            Write-Host "│                                             │" -ForegroundColor Cyan
            
            # Get available scripts from the scripts directory
            $projectRoot = Find-ProjectRoot
            $scriptsPath = Join-Path $projectRoot "aither-core" "scripts"
            $availableScripts = @()
            
            if (Test-Path $scriptsPath) {
                $scriptFiles = Get-ChildItem $scriptsPath -Filter "*.ps1" -Recurse | Sort-Object Name
                
                $index = 1
                foreach ($script in $scriptFiles) {
                    $relativePath = $script.FullName.Replace($scriptsPath, "").TrimStart('\', '/')
                    Write-Host "│   $index. $relativePath" -ForegroundColor White
                    $availableScripts += @{
                        Index = $index
                        Name = $relativePath
                        Path = $script.FullName
                    }
                    $index++
                }
            }
            
            # Show modules with runnable functions
            Write-Host "│                                             │" -ForegroundColor Cyan
            Write-Host "│ Available Modules                           │" -ForegroundColor Yellow
            
            $modulesPath = Join-Path $projectRoot "aither-core" "modules"
            $availableModules = @()
            
            if (Test-Path $modulesPath) {
                $moduleDirectories = Get-ChildItem $modulesPath -Directory | Sort-Object Name
                
                foreach ($moduleDir in $moduleDirectories) {
                    $moduleName = $moduleDir.Name
                    # Skip certain system modules
                    if ($moduleName -notin @('StartupExperience', 'LicenseManager', 'Logging')) {
                        Write-Host "│   $index. Module: $moduleName" -ForegroundColor Cyan
                        $availableScripts += @{
                            Index = $index
                            Name = "Module: $moduleName"
                            Type = "Module"
                            ModuleName = $moduleName
                        }
                        $index++
                    }
                }
            }
            
            Write-Host "│                                             │" -ForegroundColor Cyan
            Write-Host "│ [Actions]                                   │" -ForegroundColor Yellow
            Write-Host "│   R. Refresh Script List                    │" -ForegroundColor White
            Write-Host "│   B. Back to Main Menu                      │" -ForegroundColor White
            Write-Host "└─────────────────────────────────────────────┘" -ForegroundColor Cyan
            
            if ($availableScripts.Count -eq 0) {
                Write-Host "`nNo scripts found in $scriptsPath" -ForegroundColor Yellow
            }
            
            $selection = Read-Host "`nSelect script (1-$($availableScripts.Count)) or action (R/B)"
            
            switch ($selection.ToUpper()) {
                'R' {
                    # Refresh - loop will continue
                    Write-Host "Refreshing script list..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
                'B' {
                    # Back to main menu
                    $exitRunner = $true
                }
                default {
                    if ($selection -match '^\d+$') {
                        $scriptIndex = [int]$selection
                        $selectedScript = $availableScripts | Where-Object { $_.Index -eq $scriptIndex }
                        
                        if ($selectedScript) {
                            if ($selectedScript.Type -eq "Module") {
                                # Run module function
                                Invoke-ModuleRunner -ModuleName $selectedScript.ModuleName
                            } else {
                                # Run script file
                                Invoke-ScriptFile -ScriptPath $selectedScript.Path -ScriptName $selectedScript.Name
                            }
                        } else {
                            Write-Host "Invalid selection" -ForegroundColor Red
                            Start-Sleep -Seconds 2
                        }
                    } else {
                        Write-Host "Invalid selection. Please enter a number or action letter." -ForegroundColor Red
                        Start-Sleep -Seconds 2
                    }
                }
            }
        }
        
    } catch {
        Write-Error "Error in script runner: $_"
        Write-Host "`nPress any key to return to main menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Invoke-ScriptFile {
    param(
        [string]$ScriptPath,
        [string]$ScriptName
    )
    
    try {
        Clear-Host
        Write-Host "Executing: $ScriptName" -ForegroundColor Green
        Write-Host "Path: $ScriptPath" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Press Ctrl+C to stop execution if needed" -ForegroundColor Yellow
        Write-Host "─" * 60 -ForegroundColor DarkGray
        Write-Host ""
        
        # Execute the script
        & $ScriptPath
        
        Write-Host ""
        Write-Host "─" * 60 -ForegroundColor DarkGray
        Write-Host "Script execution completed." -ForegroundColor Green
        
    } catch {
        Write-Host ""
        Write-Host "─" * 60 -ForegroundColor DarkGray
        Write-Host "Script execution failed: $_" -ForegroundColor Red
    } finally {
        Write-Host "`nPress any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Invoke-ModuleRunner {
    param(
        [string]$ModuleName
    )
    
    try {
        Clear-Host
        Write-Host "Module: $ModuleName" -ForegroundColor Cyan
        Write-Host "═" * 40 -ForegroundColor Cyan
        
        # Try to import the module
        $projectRoot = Find-ProjectRoot
        $modulePath = Join-Path $projectRoot "aither-core" "modules" $ModuleName
        
        if (Test-Path $modulePath) {
            try {
                Import-Module $modulePath -Force
                Write-Host "✅ Module imported successfully" -ForegroundColor Green
                Write-Host ""
                
                # Get exported functions
                $moduleInfo = Get-Module $ModuleName
                if ($moduleInfo -and $moduleInfo.ExportedFunctions.Count -gt 0) {
                    Write-Host "Available functions:" -ForegroundColor Yellow
                    $functionIndex = 1
                    $functions = @()
                    
                    foreach ($function in $moduleInfo.ExportedFunctions.Keys | Sort-Object) {
                        Write-Host "  $functionIndex. $function" -ForegroundColor White
                        $functions += @{
                            Index = $functionIndex
                            Name = $function
                        }
                        $functionIndex++
                    }
                    
                    Write-Host ""
                    $funcSelection = Read-Host "Select function (1-$($functions.Count)) or press Enter to cancel"
                    
                    if ($funcSelection -match '^\d+$') {
                        $selectedFunction = $functions | Where-Object { $_.Index -eq [int]$funcSelection }
                        if ($selectedFunction) {
                            Write-Host ""
                            Write-Host "Executing: $($selectedFunction.Name)" -ForegroundColor Green
                            Write-Host "─" * 40 -ForegroundColor DarkGray
                            
                            try {
                                & $selectedFunction.Name
                                Write-Host "─" * 40 -ForegroundColor DarkGray
                                Write-Host "Function execution completed." -ForegroundColor Green
                            } catch {
                                Write-Host "─" * 40 -ForegroundColor DarkGray
                                Write-Host "Function execution failed: $_" -ForegroundColor Red
                            }
                        }
                    }
                } else {
                    Write-Host "No exported functions found in this module." -ForegroundColor Yellow
                }
                
            } catch {
                Write-Host "❌ Failed to import module: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "❌ Module path not found: $modulePath" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "Error running module: $_" -ForegroundColor Red
    } finally {
        Write-Host "`nPress any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}