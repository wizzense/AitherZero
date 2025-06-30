Import-Module (Join-Path $env:PWSH_MODULES_PATH 'PatchManager') -Force

# Create clean v1.2.1 release
Invoke-PatchWorkflow -PatchDescription "Release v1.2.1 - Clean hotfix release" -PatchOperation {
    # Just update VERSION file - nothing else
    $projectRoot = Find-ProjectRoot
    $versionFilePath = Join-Path $projectRoot 'VERSION'
    $content = Get-Content $versionFilePath -Raw
    $content = $content -replace '1\.2\.0', '1.2.1'
    Set-Content "VERSION" -Value $content -NoNewline
} -CreatePR -Priority "High"