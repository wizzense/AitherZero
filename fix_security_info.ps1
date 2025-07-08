$filePath = "/workspaces/AitherZero/aither-core/modules/SecurityAutomation/Public/SystemManagement/Get-SystemSecurityInventory.ps1"
$content = Get-Content $filePath -Raw

# Find the line that assigns SecurityInfo
$lines = $content -split "`n"
$securityInfoLine = $lines | Where-Object {$_ -match '\$SecurityInfo\s*=\s*@\{'}
Write-Host "Found SecurityInfo assignment: $securityInfoLine"

# Check if there's a closing brace for SecurityInfo
$closingBracePattern = '^\s*\}\s*$'
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '\$SecurityInfo\s*=\s*@\{') {
        Write-Host "SecurityInfo starts at line $($i + 1)"
        
        # Find the corresponding closing brace
        $braceCount = 1
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            if ($lines[$j] -match '\{') {
                $braceCount++
            }
            if ($lines[$j] -match '\}') {
                $braceCount--
                if ($braceCount -eq 0) {
                    Write-Host "SecurityInfo ends at line $($j + 1)"
                    break
                }
            }
        }
        break
    }
}