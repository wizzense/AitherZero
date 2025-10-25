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
$remainingArgs = if ($args.Count -gt 1) { $args[1..($args.Count-1)] } else { @() }

# Call the automation script directly as a more robust approach
$automationScriptsPath = Join-Path $PSScriptRoot "automation-scripts"
$scriptPattern = "${scriptNumber}_*.ps1"
$matchingScripts = Get-ChildItem -Path $automationScriptsPath -Filter $scriptPattern -ErrorAction SilentlyContinue

if ($matchingScripts.Count -eq 0) {
    Write-Error "No script found matching pattern: $scriptPattern in $automationScriptsPath"
    exit 1
} elseif ($matchingScripts.Count -gt 1) {
    Write-Host "Multiple scripts found:" -ForegroundColor Yellow
    $matchingScripts | ForEach-Object { Write-Host "  $($_.Name)" }
    Write-Host "Please use a more specific script number." -ForegroundColor Yellow
    exit 1
}

# Execute the script directly with parameters
$scriptPath = $matchingScripts[0].FullName
Write-Host "Executing: $($matchingScripts[0].Name)" -ForegroundColor Cyan

try {
    if ($remainingArgs.Count -gt 0) {
        $exitCode = & $scriptPath @remainingArgs
        $actualExitCode = $LASTEXITCODE
    } else {
        $exitCode = & $scriptPath
        $actualExitCode = $LASTEXITCODE
    }
    
    # Exit with the same code as the script
    exit $actualExitCode
} catch {
    Write-Error "Script execution failed: $_"
    exit 1
}