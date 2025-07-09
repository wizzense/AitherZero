#!/usr/bin/env pwsh
# Debug Pester isolation

$env:PROJECT_ROOT = "/workspaces/AitherZero"

# Import modules
Import-Module ./aither-core/modules/Logging -Force -Global
Import-Module ./tests/TestIsolation.psm1 -Force

Write-Host "Testing Invoke-PesterWithIsolation:" -ForegroundColor Cyan

$testPath = "/workspaces/AitherZero/aither-core/modules/Logging/tests/Logging.Tests.ps1"
$pesterConfig = @{
    Run = @{
        Path = $testPath
        PassThru = $true
        Exit = $false
    }
    TestResult = @{
        Enabled = $true
        OutputFormat = "NUnitXml"
        OutputPath = "./test-result.xml"
    }
    Output = @{
        Verbosity = "Normal"
    }
}

try {
    Write-Host "`nCalling Invoke-PesterWithIsolation..." -ForegroundColor Yellow
    $result = Invoke-PesterWithIsolation -TestPath $testPath -PesterConfiguration $pesterConfig -IsolateModules -IsolateEnvironment
    
    Write-Host "`nResult type: $($result.GetType().FullName)" -ForegroundColor Green
    Write-Host "Result is null: $($null -eq $result)" -ForegroundColor White
    
    if ($result) {
        Write-Host "`nResult properties:" -ForegroundColor Yellow
        $result | Get-Member -MemberType Property | ForEach-Object {
            $propName = $_.Name
            $propValue = $result.$propName
            Write-Host "  $propName : $propValue" -ForegroundColor White
        }
        
        # Check specific Pester result properties
        Write-Host "`nPester result details:" -ForegroundColor Yellow
        Write-Host "  Tests: $($result.Tests)" -ForegroundColor White
        Write-Host "  TotalCount: $($result.TotalCount)" -ForegroundColor White
        Write-Host "  PassedCount: $($result.PassedCount)" -ForegroundColor White
        Write-Host "  FailedCount: $($result.FailedCount)" -ForegroundColor White
        Write-Host "  Result: $($result.Result)" -ForegroundColor White
    }
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}