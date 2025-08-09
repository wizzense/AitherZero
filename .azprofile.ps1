# AitherZero Project Profile
# This file is automatically sourced when working in the AitherZero project

# Skip if already initialized
if ($env:AITHERZERO_INITIALIZED) {
    return
}

# Initialize AitherZero environment
$initScript = Join-Path $PSScriptRoot "Initialize-AitherEnvironment.ps1"
if (Test-Path $initScript) {
    & $initScript -Force | Out-Null
}

# Project-specific prompt
function prompt {
    $location = Get-Location
    if ($location.Path.StartsWith($env:AITHERZERO_ROOT)) {
        $relativePath = $location.Path.Replace($env:AITHERZERO_ROOT, "~AZ")
        Write-Host "[AitherZero]" -ForegroundColor Cyan -NoNewline
        Write-Host " $relativePath" -NoNewline
    } else {
        Write-Host "$location" -NoNewline
    }
    return "> "
}

# Helpful startup message
Write-Host "`n🚀 AitherZero environment loaded!" -ForegroundColor Green
Write-Host "   Commands: " -NoNewline -ForegroundColor Gray
Write-Host "az <num>" -NoNewline -ForegroundColor Cyan
Write-Host ", " -NoNewline -ForegroundColor Gray
Write-Host "seq <pattern>" -NoNewline -ForegroundColor Cyan
Write-Host ", " -NoNewline -ForegroundColor Gray
Write-Host "./aither" -ForegroundColor Cyan
Write-Host ""