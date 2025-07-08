#!/usr/bin/env pwsh
# Quick formatting fix script for v0.8.0 release

Write-Host "🔧 Fixing PowerShell formatting issues..." -ForegroundColor Cyan

$files = Get-ChildItem -Path . -Include '*.ps1','*.psm1','*.psd1' -Recurse |
         Where-Object { $_.FullName -notmatch '\\\.git\\|/\.git/|node_modules|artifacts|reports' }

$totalFiles = $files.Count
$currentFile = 0

foreach ($file in $files) {
    $currentFile++
    Write-Progress -Activity "Formatting PowerShell files" -Status "$currentFile of $totalFiles" -PercentComplete (($currentFile / $totalFiles) * 100)

    try {
        $content = Get-Content $file.FullName -Raw
        if ($content) {
            # Remove trailing whitespace
            $content = $content -replace '[ \t]+(\r?\n)', '$1'
            $content = $content -replace '[ \t]+$', ''

            # Normalize line endings
            $content = $content -replace '\r\n', "`n"
            $content = $content -replace '\r', "`n"
            $content = $content -replace '\n', "`r`n"

            # Remove multiple blank lines
            $content = $content -replace '(\r?\n){3,}', "`r`n`r`n"

            # Ensure file ends with single newline
            $content = $content.TrimEnd() + "`r`n"

            Set-Content -Path $file.FullName -Value $content -NoNewline
        }
    } catch {
        Write-Warning "Failed to format $($file.Name): $_"
    }
}

Write-Host "✅ Formatted $totalFiles PowerShell files" -ForegroundColor Green
