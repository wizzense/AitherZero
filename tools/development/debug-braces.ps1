#!/usr/bin/env pwsh
#Requires -Version 7.0

$content = Get-Content "/workspaces/AitherZero/aither-core/modules/PatchManager/Public/Invoke-ReleaseWorkflow.ps1"
$braceDepth = 0
$inFunction = $false

for ($i = 0; $i -lt $content.Count; $i++) {
    $line = $content[$i]
    
    if ($line -match "^function Invoke-ReleaseWorkflow") {
        $inFunction = $true
        Write-Host "$($i+1): $('  ' * $braceDepth)$line" -ForegroundColor Green
    }
    elseif ($inFunction -and $line -match "^Export-ModuleMember") {
        break
    }
    elseif ($inFunction) {
        # Count braces on this line
        $openCount = ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
        $closeCount = ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
        
        if ($openCount -gt 0 -or $closeCount -gt 0) {
            $color = if ($openCount -eq $closeCount) { 'White' } elseif ($openCount -gt $closeCount) { 'Yellow' } else { 'Cyan' }
            Write-Host "$($i+1): $('  ' * $braceDepth)$line" -ForegroundColor $color
        }
        
        $braceDepth += $openCount - $closeCount
        
        if ($braceDepth -lt 0) {
            Write-Host "❌ NEGATIVE DEPTH at line $($i+1)!" -ForegroundColor Red
            break
        }
    }
}

Write-Host "Final brace depth: $braceDepth" -ForegroundColor $(if ($braceDepth -eq 0) { 'Green' } else { 'Red' })