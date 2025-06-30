Import-Module ./aither-core/modules/PatchManager -Force

Invoke-PatchWorkflow -PatchDescription "Release v1.2.1 hotfix - Fix merge conflicts and syntax errors" -PatchOperation {
    # Update VERSION file
    $versionContent = Get-Content "VERSION" -Raw
    $newContent = $versionContent -replace '1\.2\.0', '1.2.1'
    Set-Content "VERSION" -Value $newContent -NoNewline
    
    # Update version in Start-AitherZero.ps1
    $startContent = Get-Content "Start-AitherZero.ps1" -Raw
    $startContent = $startContent -replace 'v1\.1\.0\+', 'v1.2.1'
    Set-Content "Start-AitherZero.ps1" -Value $startContent -NoNewline
} -CreatePR -Priority "High"