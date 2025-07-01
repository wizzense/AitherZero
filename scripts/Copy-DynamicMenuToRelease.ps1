#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    Copy dynamic menu files to existing AitherZero installation
#>

param(
    [string]$TargetPath = "C:\Users\alexa\AitherZero"
)

Write-Host "`n🚀 Updating AitherZero Installation with Dynamic Menu" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Cyan

$sourceRoot = Split-Path $PSScriptRoot -Parent

# Files to copy
$filesToCopy = @(
    @{
        Source = "aither-core/aither-core.ps1"
        Dest = "aither-core.ps1"
        Description = "Patched core script with dynamic menu"
    },
    @{
        Source = "aither-core/shared/Show-DynamicMenu.ps1"
        Dest = "shared/Show-DynamicMenu.ps1"
        Description = "Dynamic menu system"
    },
    @{
        Source = "aither-core/shared/Get-ModuleCapabilities.ps1"
        Dest = "shared/Get-ModuleCapabilities.ps1"
        Description = "Module discovery system"
    },
    @{
        Source = "aither-core/modules/SetupWizard/Public/Edit-Configuration.ps1"
        Dest = "modules/SetupWizard/Public/Edit-Configuration.ps1"
        Description = "Configuration editor"
    },
    @{
        Source = "aither-core/modules/SetupWizard/Public/Review-Configuration.ps1"
        Dest = "modules/SetupWizard/Public/Review-Configuration.ps1"
        Description = "Configuration review for setup"
    },
    @{
        Source = "aither-core/modules/SetupWizard/SetupWizard.psm1"
        Dest = "modules/SetupWizard/SetupWizard.psm1"
        Description = "Updated SetupWizard module"
    },
    @{
        Source = "Start-AitherZero.ps1"
        Dest = "Start-AitherZero.ps1"
        Description = "Fixed launcher with modules path"
    }
)

$successCount = 0

foreach ($file in $filesToCopy) {
    $sourcePath = Join-Path $sourceRoot $file.Source
    $destPath = Join-Path $TargetPath $file.Dest
    
    Write-Host "`n📄 $($file.Description)" -ForegroundColor Yellow
    Write-Host "   From: $sourcePath" -ForegroundColor Gray
    Write-Host "   To:   $destPath" -ForegroundColor Gray
    
    if (Test-Path $sourcePath) {
        try {
            # Create directory if needed
            $destDir = Split-Path $destPath -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            # Backup existing file
            if (Test-Path $destPath) {
                $backupPath = "$destPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item -Path $destPath -Destination $backupPath -Force
                Write-Host "   ✓ Backed up existing file" -ForegroundColor Green
            }
            
            # Copy new file
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            Write-Host "   ✓ Copied successfully" -ForegroundColor Green
            $successCount++
        } catch {
            Write-Host "   ✗ Failed: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "   ✗ Source file not found!" -ForegroundColor Red
    }
}

Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "✅ Update Complete: $successCount/$($filesToCopy.Count) files updated" -ForegroundColor Green
Write-Host "`n🎯 Now you can run:" -ForegroundColor Yellow
Write-Host "   cd $TargetPath" -ForegroundColor White
Write-Host "   .\Start-AitherZero.ps1" -ForegroundColor White
Write-Host "`nThe dynamic menu will now appear!" -ForegroundColor Green