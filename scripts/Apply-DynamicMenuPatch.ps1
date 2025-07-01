#!/usr/bin/env pwsh
# Compatible with PowerShell 5.1+

<#
.SYNOPSIS
    Apply dynamic menu patch to aither-core.ps1
.DESCRIPTION
    Updates aither-core.ps1 to use dynamic module discovery instead of static script menu
#>

param(
    [switch]$DryRun
)

try {
    # Find project root
    . "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Find aither-core.ps1
    $coreScript = Join-Path $projectRoot "aither-core/aither-core.ps1"
    if (-not (Test-Path $coreScript)) {
        # Try alternate location
        $coreScript = Join-Path $projectRoot "aither-core.ps1"
    }
    
    if (-not (Test-Path $coreScript)) {
        throw "Could not find aither-core.ps1"
    }
    
    Write-Host "Found aither-core.ps1 at: $coreScript" -ForegroundColor Green
    
    # Read current content
    $content = Get-Content $coreScript -Raw
    
    # Check if already patched
    if ($content -match "Show-DynamicMenu") {
        Write-Host "File already contains dynamic menu system!" -ForegroundColor Yellow
        return
    }
    
    # Find the section to replace
    $startPattern = '    # Get available scripts - try multiple locations'
    $endPattern = '        Write-CustomLog ''No scripts to execute'' -Level INFO\r?\n    }'
    
    if ($content -match "(?s)($startPattern.*?$endPattern)") {
        $oldSection = $matches[1]
        
        # New dynamic menu code
        $newSection = @'
    # Load dynamic menu system
    $dynamicMenuPath = Join-Path $PSScriptRoot 'shared' 'Show-DynamicMenu.ps1'
    if (-not (Test-Path $dynamicMenuPath)) {
        $dynamicMenuPath = Join-Path $repoRoot 'aither-core' 'shared' 'Show-DynamicMenu.ps1'
    }
    
    if (Test-Path $dynamicMenuPath) {
        Write-CustomLog "Loading dynamic menu system from: $dynamicMenuPath" -Level DEBUG
        . $dynamicMenuPath
    }

    # Handle different execution modes
    if ($Scripts) {
        # Run specific modules/scripts
        Write-CustomLog "Running specific components: $Scripts" -Level INFO
        
        $componentList = $Scripts -split ','
        foreach ($componentName in $componentList) {
            $componentName = $componentName.Trim()
            
            # Try to find and run as module first
            $modulePath = Join-Path $env:PWSH_MODULES_PATH $componentName
            if (Test-Path $modulePath) {
                Write-CustomLog "Loading module: $componentName" -Level INFO
                try {
                    Import-Module $modulePath -Force
                    Write-Host "✓ Module loaded: $componentName" -ForegroundColor Green
                    
                    # Try to run default function if exists
                    $defaultFunction = "Start-$componentName"
                    if (Get-Command $defaultFunction -ErrorAction SilentlyContinue) {
                        Write-Host "Executing: $defaultFunction" -ForegroundColor Cyan
                        & $defaultFunction
                    } else {
                        Write-Host "Module loaded. Use Get-Command -Module $componentName to see available functions." -ForegroundColor Yellow
                    }
                } catch {
                    Write-CustomLog "Error loading module $componentName : $_" -Level ERROR
                }
            } else {
                # Fallback to legacy script execution
                $scriptsPaths = @(
                    (Join-Path $PSScriptRoot 'scripts'),
                    (Join-Path $repoRoot "aither-core" "scripts"),
                    (Join-Path $repoRoot "scripts")
                )
                
                $scriptFound = $false
                foreach ($scriptsPath in $scriptsPaths) {
                    $scriptPath = Join-Path $scriptsPath "$componentName.ps1"
                    if (Test-Path $scriptPath) {
                        Write-CustomLog "Executing script: $componentName" -Level INFO
                        if ($PSCmdlet.ShouldProcess($componentName, 'Execute script')) {
                            Invoke-ScriptWithOutputHandling -ScriptName $componentName -ScriptPath $scriptPath -Config $config -Force:$Force -Verbosity $Verbosity
                        }
                        $scriptFound = $true
                        break
                    }
                }
                
                if (-not $scriptFound) {
                    Write-CustomLog "Component not found: $componentName" -Level WARN
                }
            }
        }
    } elseif ($Auto) {
        # Auto mode - run all default operations
        Write-CustomLog 'Running in automatic mode' -Level INFO
        
        # Define default auto-mode modules
        $autoModules = @('SetupWizard', 'SystemMonitoring', 'BackupManager')
        
        foreach ($moduleName in $autoModules) {
            $modulePath = Join-Path $env:PWSH_MODULES_PATH $moduleName
            if (Test-Path $modulePath) {
                try {
                    Import-Module $modulePath -Force
                    $defaultFunction = "Start-$moduleName"
                    if (Get-Command $defaultFunction -ErrorAction SilentlyContinue) {
                        Write-Host "Auto-executing: $defaultFunction" -ForegroundColor Cyan
                        & $defaultFunction -Auto
                    }
                } catch {
                    Write-CustomLog "Error in auto mode for $moduleName : $_" -Level WARN
                }
            }
        }
    } else {
        # Check if running in non-interactive mode
        if ($NonInteractive -or $PSCmdlet.WhatIf) {
            Write-CustomLog 'Non-interactive mode: use -Scripts parameter to specify components, or -Auto for automatic mode' -Level INFO
            Write-CustomLog 'Available options:' -Level INFO
            Write-CustomLog '  -Scripts "LabRunner,BackupManager" : Run specific modules' -Level INFO
            Write-CustomLog '  -Auto : Run default automated tasks' -Level INFO
        } else {
            # Interactive mode - show dynamic menu
            Write-CustomLog 'Starting interactive mode with dynamic menu' -Level INFO
            
            # Check if this is first run
            $firstRunFile = Join-Path $env:APPDATA 'AitherZero' '.firstrun'
            $isFirstRun = -not (Test-Path $firstRunFile)
            
            if ($isFirstRun) {
                # Create first run marker
                $firstRunDir = Split-Path $firstRunFile -Parent
                if (-not (Test-Path $firstRunDir)) {
                    New-Item -ItemType Directory -Path $firstRunDir -Force | Out-Null
                }
                New-Item -ItemType File -Path $firstRunFile -Force | Out-Null
            }
            
            # Show dynamic menu
            if (Get-Command Show-DynamicMenu -ErrorAction SilentlyContinue) {
                Show-DynamicMenu -Title "Infrastructure Automation Platform" -Config $config -FirstRun:$isFirstRun
            } else {
                Write-CustomLog 'Dynamic menu system not available, falling back to basic menu' -Level WARN
                
                # Fallback basic menu
                Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
                Write-Host " AitherZero - Infrastructure Automation" -ForegroundColor Cyan
                Write-Host "=" * 60 -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Dynamic menu system not loaded." -ForegroundColor Yellow
                Write-Host "Try running with -Scripts or -Auto parameter." -ForegroundColor Yellow
                Write-Host ""
            }
        }
    }
'@
        
        if ($DryRun) {
            Write-Host "`nDry run - would replace:" -ForegroundColor Yellow
            Write-Host "OLD SECTION (first 200 chars):" -ForegroundColor Red
            Write-Host $oldSection.Substring(0, [Math]::Min(200, $oldSection.Length))
            Write-Host "`nNEW SECTION (first 200 chars):" -ForegroundColor Green
            Write-Host $newSection.Substring(0, [Math]::Min(200, $newSection.Length))
        } else {
            # Create backup
            $backupPath = "$coreScript.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $coreScript $backupPath
            Write-Host "Created backup: $backupPath" -ForegroundColor Yellow
            
            # Replace content
            $newContent = $content.Replace($oldSection, $newSection)
            
            # Write updated content
            Set-Content -Path $coreScript -Value $newContent -NoNewline
            
            Write-Host "`n✅ Successfully patched aither-core.ps1 with dynamic menu system!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Changes made:" -ForegroundColor Cyan
            Write-Host "  • Replaced static script menu with dynamic module discovery" -ForegroundColor White
            Write-Host "  • Added support for running modules directly" -ForegroundColor White
            Write-Host "  • Enhanced -Scripts parameter to work with modules" -ForegroundColor White
            Write-Host "  • Added first-run detection" -ForegroundColor White
            Write-Host "  • Integrated Show-DynamicMenu system" -ForegroundColor White
        }
    } else {
        Write-Host "Could not find the expected script menu section in aither-core.ps1" -ForegroundColor Red
        Write-Host "The file may have already been modified or has a different structure." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Error applying patch: $_" -ForegroundColor Red
    exit 1
}