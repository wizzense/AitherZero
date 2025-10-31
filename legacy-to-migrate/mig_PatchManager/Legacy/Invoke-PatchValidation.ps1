function Invoke-PatchValidation {
    param(
        [string[]]$ChangedFiles
    )

    Write-Host "Running patch validation..." -ForegroundColor Blue
    $issues = @()

    try {
        foreach ($file in $ChangedFiles) {
            if (-not (Test-PowerShellSyntax -Path $file)) {
                $issues += $file
            }
        }

        if ($issues.Count -gt 0) {
            Write-Warning "Validation failed for the following files: $($issues -join ', ')"
            throw "Patch validation failed."
        } else {
            Write-Host "All files passed validation." -ForegroundColor Green
        }
    } catch {
        Write-Error "An error occurred during patch validation: $($_.Exception.Message)"
        throw
    }
}
