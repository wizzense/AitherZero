#!/usr/bin/env pwsh
#Requires -Version 7.0

# Extract just the function structure to debug braces
$content = Get-Content "/workspaces/AitherZero/aither-core/modules/PatchManager/Public/Invoke-ReleaseWorkflow.ps1" -Raw

# Find function boundaries
$lines = $content -split "`n"
$functionStart = -1
$functionEnd = -1

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^function Invoke-ReleaseWorkflow") {
        $functionStart = $i
    }
    if ($functionStart -ge 0 -and $lines[$i] -match "^Export-ModuleMember") {
        $functionEnd = $i - 1
        break
    }
}

Write-Host "Function starts at line: $($functionStart + 1)"
Write-Host "Function ends at line: $($functionEnd + 1)"

# Count braces just within the function
$functionContent = $lines[$functionStart..$functionEnd] -join "`n"
$openBraces = ($functionContent.ToCharArray() | Where-Object { $_ -eq '{' }).Count
$closeBraces = ($functionContent.ToCharArray() | Where-Object { $_ -eq '}' }).Count

Write-Host "Function braces: $openBraces opening, $closeBraces closing"

if ($openBraces -ne $closeBraces) {
    Write-Host "❌ Function has brace mismatch!" -ForegroundColor Red
    
    # Find the mismatched area
    $braceCount = 0
    $lineNum = $functionStart
    
    foreach ($line in $lines[$functionStart..$functionEnd]) {
        $lineNum++
        $lineBraces = ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count - ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
        $braceCount += $lineBraces
        
        if ($braceCount -lt 0) {
            Write-Host "❌ Line $lineNum has too many closing braces: $line" -ForegroundColor Red
            break
        }
    }
    
    if ($braceCount -gt 0) {
        Write-Host "❌ Function is missing $braceCount closing braces" -ForegroundColor Red
    }
} else {
    Write-Host "✅ Function braces are balanced" -ForegroundColor Green
}