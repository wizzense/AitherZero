$env:PROJECT_ROOT = '/workspaces/AitherZero'
$env:PWSH_MODULES_PATH = '/workspaces/AitherZero/aither-core/modules'

Write-Host "Testing environment setup..." -ForegroundColor Cyan
Write-Host "PROJECT_ROOT: $env:PROJECT_ROOT" -ForegroundColor Yellow
Write-Host "PWSH_MODULES_PATH: $env:PWSH_MODULES_PATH" -ForegroundColor Yellow

Write-Host "Testing LabRunner module import..." -ForegroundColor Cyan
try {
    Import-Module (Join-Path $env:PWSH_MODULES_PATH 'LabRunner') -Force
    Write-Host "✅ LabRunner module loaded successfully!" -ForegroundColor Green
    
    $commands = Get-Command -Module LabRunner
    Write-Host "Available commands ($($commands.Count)):" -ForegroundColor Cyan
    $commands | Select-Object -First 5 | ForEach-Object { 
        Write-Host "  - $($_.Name)" -ForegroundColor White 
    }
} catch {
    Write-Host "❌ Failed to load LabRunner: $($_.Exception.Message)" -ForegroundColor Red
}
