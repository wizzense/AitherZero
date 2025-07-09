# Simple CI/CD Pipeline Trigger

Write-Host "Triggering CI/CD Pipeline..." -ForegroundColor Green

# Read current version
$currentVersion = Get-Content "./VERSION" -Raw -ErrorAction SilentlyContinue
if (-not $currentVersion) {
    $currentVersion = "0.10.2"
}

# Increment version
$versionParts = $currentVersion.Trim() -split '\.'
$patchNumber = [int]$versionParts[2] + 1
$newVersion = "$($versionParts[0]).$($versionParts[1]).$patchNumber"

Write-Host "Updating version from $($currentVersion.Trim()) to $newVersion"

# Update version file
Set-Content "./VERSION" -Value $newVersion

# Create marker
$marker = "# CI/CD Pipeline Validation Trigger - $(Get-Date)"
Set-Content "./PIPELINE-TRIGGER.md" -Value $marker

Write-Host "Version updated to: $newVersion"
Write-Host "Pipeline trigger files created."