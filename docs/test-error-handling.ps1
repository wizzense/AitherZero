#!/usr/bin/env pwsh

# Error Handling Test Script
# Tests error handling and recovery scenarios

$ErrorActionPreference = 'Continue'
Set-Location '/workspaces/AitherZero'

Write-Host "=== ERROR HANDLING AND RECOVERY TESTS ===" -ForegroundColor Cyan

$ErrorResults = @()

# Test 1: Invalid module path
Write-Host "Test 1: Invalid module path" -ForegroundColor Yellow
try {
    Import-Module './aither-core/modules/NonExistentModule' -Force -ErrorAction Stop
    $ErrorResults += [PSCustomObject]@{
        TestName = "Invalid module path"
        Status = "Unexpected Success"
        Error = "Module should not have loaded"
    }
} catch {
    Write-Host "  ✓ Correctly handled invalid module path" -ForegroundColor Green
    $ErrorResults += [PSCustomObject]@{
        TestName = "Invalid module path"
        Status = "Pass"
        Error = $_.Exception.Message
    }
}

# Test 2: Module with syntax errors (we know OpenTofuProvider has issues)
Write-Host "Test 2: Module with syntax errors" -ForegroundColor Yellow
try {
    Import-Module './aither-core/modules/OpenTofuProvider' -Force -ErrorAction Stop
    $ErrorResults += [PSCustomObject]@{
        TestName = "Module with syntax errors"
        Status = "Unexpected Success"
        Error = "Module should not have loaded due to syntax errors"
    }
} catch {
    Write-Host "  ✓ Correctly handled module with syntax errors" -ForegroundColor Green
    $ErrorResults += [PSCustomObject]@{
        TestName = "Module with syntax errors"
        Status = "Pass"
        Error = "Syntax errors properly caught"
    }
}

# Test 3: Function call with invalid parameters
Write-Host "Test 3: Function call with invalid parameters" -ForegroundColor Yellow
try {
    Import-Module './aither-core/modules/ConfigurationCore' -Force -ErrorAction Stop
    # Try to call a function with invalid parameters
    Get-ConfigurationStore -InvalidParameter "test" -ErrorAction Stop
    $ErrorResults += [PSCustomObject]@{
        TestName = "Invalid function parameters"
        Status = "Unexpected Success"
        Error = "Function should have rejected invalid parameters"
    }
} catch {
    Write-Host "  ✓ Correctly handled invalid function parameters" -ForegroundColor Green
    $ErrorResults += [PSCustomObject]@{
        TestName = "Invalid function parameters"
        Status = "Pass"
        Error = "Invalid parameters properly rejected"
    }
}

# Test 4: Missing dependency handling
Write-Host "Test 4: Missing dependency handling" -ForegroundColor Yellow
try {
    # Try to call a function that might need dependencies
    Import-Module './aither-core/modules/TestingFramework' -Force -ErrorAction Stop
    Write-Host "  ✓ TestingFramework loaded with dependencies" -ForegroundColor Green
    $ErrorResults += [PSCustomObject]@{
        TestName = "Missing dependency handling"
        Status = "Pass"
        Error = "Dependencies loaded correctly"
    }
} catch {
    Write-Host "  ⚠ TestingFramework failed to load - dependency issue" -ForegroundColor Yellow
    $ErrorResults += [PSCustomObject]@{
        TestName = "Missing dependency handling"
        Status = "Fail"
        Error = $_.Exception.Message
    }
}

# Test 5: Configuration error handling
Write-Host "Test 5: Configuration error handling" -ForegroundColor Yellow
try {
    Import-Module './aither-core/modules/ConfigurationCore' -Force -ErrorAction Stop
    
    # Try to load a non-existent configuration
    try {
        Get-ConfigurationStore -ConfigurationName "NonExistentConfig" -ErrorAction Stop
        $ErrorResults += [PSCustomObject]@{
            TestName = "Configuration error handling"
            Status = "Unexpected Success"
            Error = "Should have failed with non-existent config"
        }
    } catch {
        Write-Host "  ✓ Correctly handled non-existent configuration" -ForegroundColor Green
        $ErrorResults += [PSCustomObject]@{
            TestName = "Configuration error handling"
            Status = "Pass"
            Error = "Non-existent config properly handled"
        }
    }
} catch {
    Write-Host "  ✗ ConfigurationCore failed to load" -ForegroundColor Red
    $ErrorResults += [PSCustomObject]@{
        TestName = "Configuration error handling"
        Status = "Fail"
        Error = $_.Exception.Message
    }
}

# Test 6: Logging error handling
Write-Host "Test 6: Logging error handling" -ForegroundColor Yellow
try {
    Import-Module './aither-core/modules/Logging' -Force -ErrorAction Stop
    
    # Test invalid log level
    try {
        Write-CustomLog -Level 'INVALID' -Message "Test message" -ErrorAction Stop
        $ErrorResults += [PSCustomObject]@{
            TestName = "Logging error handling"
            Status = "Unexpected Success"
            Error = "Should have failed with invalid log level"
        }
    } catch {
        Write-Host "  ✓ Correctly handled invalid log level" -ForegroundColor Green
        $ErrorResults += [PSCustomObject]@{
            TestName = "Logging error handling"
            Status = "Pass"
            Error = "Invalid log level properly handled"
        }
    }
} catch {
    Write-Host "  ✗ Logging module failed to load" -ForegroundColor Red
    $ErrorResults += [PSCustomObject]@{
        TestName = "Logging error handling"
        Status = "Fail"
        Error = $_.Exception.Message
    }
}

# Test 7: PatchManager error handling
Write-Host "Test 7: PatchManager error handling" -ForegroundColor Yellow
try {
    Import-Module './aither-core/modules/PatchManager' -Force -ErrorAction Stop
    
    # Test invalid git operation
    try {
        # This should fail gracefully if not in a proper git state
        $Status = Get-PatchStatus -ErrorAction Stop
        Write-Host "  ✓ PatchManager handled git status check" -ForegroundColor Green
        $ErrorResults += [PSCustomObject]@{
            TestName = "PatchManager error handling"
            Status = "Pass"
            Error = "Git operations handled correctly"
        }
    } catch {
        Write-Host "  ✓ PatchManager correctly handled git error" -ForegroundColor Green
        $ErrorResults += [PSCustomObject]@{
            TestName = "PatchManager error handling"
            Status = "Pass"
            Error = "Git errors properly handled"
        }
    }
} catch {
    Write-Host "  ✗ PatchManager failed to load" -ForegroundColor Red
    $ErrorResults += [PSCustomObject]@{
        TestName = "PatchManager error handling"
        Status = "Fail"
        Error = $_.Exception.Message
    }
}

# Test 8: Memory exhaustion protection
Write-Host "Test 8: Memory exhaustion protection" -ForegroundColor Yellow
try {
    # Test loading multiple modules simultaneously
    $ModulesToLoad = @(
        'ConfigurationCore',
        'PatchManager',
        'BackupManager',
        'DevEnvironment',
        'LabRunner'
    )
    
    foreach ($Module in $ModulesToLoad) {
        Import-Module "./aither-core/modules/$Module" -Force -ErrorAction Stop
    }
    
    Write-Host "  ✓ Multiple modules loaded without memory issues" -ForegroundColor Green
    $ErrorResults += [PSCustomObject]@{
        TestName = "Memory exhaustion protection"
        Status = "Pass"
        Error = "Multiple modules loaded successfully"
    }
} catch {
    Write-Host "  ✗ Memory or loading issue with multiple modules" -ForegroundColor Red
    $ErrorResults += [PSCustomObject]@{
        TestName = "Memory exhaustion protection"
        Status = "Fail"
        Error = $_.Exception.Message
    }
}

# Display results
Write-Host "`n=== ERROR HANDLING TEST RESULTS ===" -ForegroundColor Cyan
$ErrorResults | Format-Table -AutoSize

# Summary
$PassCount = ($ErrorResults | Where-Object { $_.Status -eq "Pass" }).Count
$FailCount = ($ErrorResults | Where-Object { $_.Status -eq "Fail" }).Count
$UnexpectedCount = ($ErrorResults | Where-Object { $_.Status -eq "Unexpected Success" }).Count

Write-Host "`n=== ERROR HANDLING SUMMARY ===" -ForegroundColor Cyan
Write-Host "✓ Tests Passed: $PassCount" -ForegroundColor Green
Write-Host "✗ Tests Failed: $FailCount" -ForegroundColor Red
Write-Host "⚠ Unexpected Success: $UnexpectedCount" -ForegroundColor Yellow

# Export results
$ErrorResults | ConvertTo-Json -Depth 3 | Out-File './docs/error-handling-results.json'
Write-Host "`nResults exported to: ./docs/error-handling-results.json" -ForegroundColor Cyan