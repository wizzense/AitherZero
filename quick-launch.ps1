# AitherZero Quick Launcher
# This is the shortest possible way to get AitherZero running

$url = 'https://raw.githubusercontent.com/wizzense/AitherZero/main/SUPER-SIMPLE-BOOTSTRAP.ps1'
try {
    Write-Host '🚀 Launching AitherZero...' -ForegroundColor Green
    Invoke-Expression (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '🔄 Try the manual method:' -ForegroundColor Yellow
    Write-Host "   iwr $url -o bootstrap.ps1; .\bootstrap.ps1" -ForegroundColor Cyan
}
