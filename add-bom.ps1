#!/usr/bin/env pwsh
# Add BOM to UTF-8 files that need it

$filesToFix = @(
    '/workspaces/AitherZero/aither-core/aither-core.ps1',
    '/workspaces/AitherZero/aither-core/AitherCore.psm1',
    '/workspaces/AitherZero/aither-core/domains/experience/Experience.ps1'
)

foreach ($file in $filesToFix) {
    if (Test-Path $file) {
        Write-Host "Adding BOM to: $file"
        
        # Read the file content
        $content = Get-Content -Path $file -Raw
        
        # Write with UTF-8 BOM
        $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($file, $content, $utf8WithBom)
        
        Write-Host "  ✓ BOM added successfully"
    } else {
        Write-Host "  ✗ File not found: $file"
    }
}

Write-Host "BOM addition completed"