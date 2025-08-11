#!/usr/bin/env pwsh
# AitherZero Script Runner - ensures environment is loaded

# Load environment if not already loaded
if (-not $env:AITHERZERO_INITIALIZED) {
    $moduleManifest = Join-Path $PSScriptRoot "AitherZero.psd1"
    if (Test-Path $moduleManifest) {
        Import-Module $moduleManifest -Force -Global
    }
}

# Ensure transcript logging is active for automation scripts
$transcriptPath = Join-Path $PSScriptRoot "logs/transcript-$(Get-Date -Format 'yyyy-MM-dd').log"
try {
    # Try to get current transcript status
    $transcriptActive = $false
    try {
        $null = Stop-Transcript -ErrorAction Stop
        $transcriptActive = $true
        Start-Transcript -Path $transcriptPath -Append -IncludeInvocationHeader | Out-Null
    } catch [System.InvalidOperationException] {
        # No transcript was running, start one
        Start-Transcript -Path $transcriptPath -Append -IncludeInvocationHeader | Out-Null
    }
} catch {
    # Transcript functionality not available or failed
}

# Now run the requested script
if ($args.Count -eq 0) {
    Write-Host "Usage: az <script-number> [arguments]" -ForegroundColor Yellow
    Write-Host "Examples:" -ForegroundColor Gray
    Write-Host "  az 0402              # Run unit tests" -ForegroundColor White
    Write-Host "  az 0510              # Generate project report" -ForegroundColor White
    Write-Host "  az 0511 -ShowAll     # Show project dashboard" -ForegroundColor White
    exit 1
}

# Pass the first argument as ScriptNumber and rest as additional parameters
$scriptNumber = [string]$args[0]
$additionalArgs = if ($args.Count -gt 1) { $args[1..($args.Count-1)] } else { @() }

Invoke-AitherScript -ScriptNumber $scriptNumber @additionalArgs