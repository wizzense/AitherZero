Import-Module ./aither-core/modules/PatchManager -Force

# Create release for v0.6.15
Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Fix bootstrap PS7 window closing issues - Window no longer closes on error, proper script path detection for iex, -NoExit flag keeps PS7 window open"

Write-Host "Release workflow started!"