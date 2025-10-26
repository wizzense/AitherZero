#!/usr/bin/env pwsh

# Simple test of modern CLI concept
Write-Host "🚀 AitherZero Modern CLI Test" -ForegroundColor Green
Write-Host "Usage: az <action> <target>" -ForegroundColor White
Write-Host ""

$action = $args[0]
$target = $args[1]

switch ($action) {
    'list' {
        if ($target -eq 'scripts') {
            Write-Host "Available Scripts:" -ForegroundColor Cyan
            Get-ChildItem automation-scripts -Filter "*.ps1" | ForEach-Object {
                if ($_.Name -match '^(\d{4})_(.+)\.ps1$') {
                    Write-Host "  $($matches[1]) - $($matches[2].Replace('_', ' '))" -ForegroundColor White
                }
            }
        }
        elseif ($target -eq 'playbooks') {
            Write-Host "Available Playbooks:" -ForegroundColor Cyan  
            Get-ChildItem orchestration/playbooks -Filter "*.json" -Recurse | ForEach-Object {
                $pb = Get-Content $_.FullName | ConvertFrom-Json
                $name = if ($pb.Name) { $pb.Name } else { $pb.name }
                Write-Host "  [$($_.Directory.Name)] $name" -ForegroundColor White
            }
        }
    }
    'help' {
        Write-Host "Available Actions:" -ForegroundColor Cyan
        Write-Host "  list scripts   - List automation scripts" -ForegroundColor White
        Write-Host "  list playbooks - List orchestration playbooks" -ForegroundColor White
        Write-Host "  help          - Show this help" -ForegroundColor White
    }
    default {
        Write-Host "Unknown action: $action" -ForegroundColor Red
        Write-Host "Use 'help' for available actions" -ForegroundColor Yellow
    }
}
