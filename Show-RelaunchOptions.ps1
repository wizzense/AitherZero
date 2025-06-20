<#
.SYNOPSIS
    Shows all available relaunch options for OpenTofu Lab Automation

.DESCRIPTION
    Displays all the ways you can restart/relaunch the CoreApp environment
    after the initial bootstrap with kicker-git.ps1.

.EXAMPLE
    .\Show-RelaunchOptions.ps1
#>

Write-Host "🔄 OpenTofu Lab Automation - Relaunch Options" -ForegroundColor Cyan
Write-Host ("=" * 55) -ForegroundColor DarkGray
Write-Host ""

Write-Host "📂 Current Directory: $(Get-Location)" -ForegroundColor Green
Write-Host ""

Write-Host "🚀 Available Relaunch Scripts:" -ForegroundColor Yellow

$scripts = @(
    @{Name=".\Relaunch-CoreApp.ps1"; Description="Auto-generated comprehensive relaunch (RECOMMENDED)"; Color="Green"}
    @{Name=".\Start-CoreApp.ps1"; Description="Manual CoreApp initialization"; Color="Cyan"}
    @{Name=".\go.ps1"; Description="Super quick launcher (minimal typing)"; Color="Magenta"}
    @{Name=".\Quick-Setup.ps1"; Description="Development environment setup"; Color="Yellow"}
)

foreach ($script in $scripts) {
    $exists = Test-Path $script.Name
    $status = if ($exists) { "✅" } else { "❌" }
    $availableText = if ($exists) { "Available" } else { "Not Found" }

    Write-Host "  $status " -NoNewline
    Write-Host $script.Name -ForegroundColor $script.Color -NoNewline
    Write-Host " - $($script.Description) " -NoNewline
    Write-Host "($availableText)" -ForegroundColor $(if ($exists) { "Green" } else { "Red" })
}

Write-Host ""
Write-Host "💡 Manual Options:" -ForegroundColor Yellow
Write-Host "  Import-Module './aither-core/CoreApp.psm1' -Force"
Write-Host "  Initialize-CoreApplication"
Write-Host ""

Write-Host "🛠️ If Nothing Works:" -ForegroundColor Red
Write-Host "  .\kicker-git.ps1 -Force    # Re-run bootstrap"
Write-Host ""

Write-Host "🎯 Recommended Quick Start:" -ForegroundColor Green
if (Test-Path ".\Relaunch-CoreApp.ps1") {
    Write-Host "  .\Relaunch-CoreApp.ps1" -ForegroundColor Green
} elseif (Test-Path ".\go.ps1") {
    Write-Host "  .\go.ps1" -ForegroundColor Magenta
} else {
    Write-Host "  .\Start-CoreApp.ps1" -ForegroundColor Cyan
}
