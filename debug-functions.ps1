Import-Module './aither-core/AitherCore' -Force
Import-CoreModules -Force | Out-Null

Write-Host "=== Direct Function Test ==="
Write-Host "Testing if functions exist in current session:"

$functions = @(
    "New-SecureCredential",
    "Get-SecureCredential",
    "Test-SecureCredential",
    "New-RemoteConnection",
    "Get-RemoteConnection"
)

foreach ($func in $functions) {
    try {
        $command = Get-Command $func -ErrorAction Stop
        Write-Host "✅ $func - Available (Module: $($command.ModuleName))"
    } catch {
        Write-Host "❌ $func - Not found"

        # Try alternative approach
        try {
            if (Test-Path "function:\$func") {
                Write-Host "   → Found as function: $func"
            }
        } catch {
            Write-Host "   → Not found as function either"
        }
    }
}

Write-Host "`n=== All Available Functions ==="
Get-Command | Where-Object { $_.Name -match "(Secure|Remote)" -and $_.ModuleName -match "(SecureCredentials|RemoteConnection)" } | Select-Object Name, ModuleName
