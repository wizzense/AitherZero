Import-Module ./aither-core/modules/PatchManager -Force

Invoke-PatchWorkflow -PatchDescription "Release v1.2.0 with enhanced setup wizard and AI tools integration" -PatchOperation {
    # Update VERSION file
    $versionContent = Get-Content "VERSION" -Raw
    $newContent = $versionContent -replace '1\.0\.0', '1.2.0'
    Set-Content "VERSION" -Value $newContent -NoNewline
} -CreatePR -Priority "Critical"