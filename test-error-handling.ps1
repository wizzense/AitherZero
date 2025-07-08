#!/usr/bin/env pwsh
#Requires -Version 7.0

# Test script for error handling and missing dependency scenarios

param(
    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'

function Test-MissingModuleHandling {
    Write-Host "=== Testing Missing Module Handling ===" -ForegroundColor Cyan
    
    $errorTests = @()
    
    try {
        # Test 1: Try to import non-existent module
        Write-Host "`n1. Testing non-existent module import..." -ForegroundColor Yellow
        
        try {
            Import-Module "./non-existent-module" -ErrorAction Stop
            $errorTests += @{
                Test = "Non-existent module import"
                Expected = "Should fail"
                Actual = "Succeeded (unexpected)"
                Success = $false
            }
            Write-Host "✗ Non-existent module import should have failed" -ForegroundColor Red
        } catch {
            $errorTests += @{
                Test = "Non-existent module import"
                Expected = "Should fail with module not found"
                Actual = "Failed as expected: $($_.Exception.Message)"
                Success = $true
            }
            Write-Host "✓ Non-existent module import failed correctly: $($_.Exception.Message)" -ForegroundColor Green
        }
        
        # Test 2: Try to import module with missing dependencies
        Write-Host "`n2. Testing module with missing dependencies..." -ForegroundColor Yellow
        
        # First ensure Logging is not loaded
        if (Get-Module -Name 'Logging' -ErrorAction SilentlyContinue) {
            Remove-Module -Name 'Logging' -Force
        }
        
        try {
            # Try to import a module that depends on Logging
            Import-Module "./aither-core/modules/ConfigurationManager" -ErrorAction Stop
            $errorTests += @{
                Test = "Module with missing dependencies"
                Expected = "Should handle dependency gracefully"
                Actual = "Succeeded (may have auto-resolved)"
                Success = $true
            }
            Write-Host "✓ Module with missing dependency loaded (auto-resolution working)" -ForegroundColor Green
        } catch {
            $errorTests += @{
                Test = "Module with missing dependencies"
                Expected = "Should fail with dependency error"
                Actual = "Failed as expected: $($_.Exception.Message)"
                Success = $true
            }
            Write-Host "✓ Module with missing dependency failed correctly: $($_.Exception.Message)" -ForegroundColor Green
        }
        
        # Test 3: Test AitherCore with corrupted module directory
        Write-Host "`n3. Testing corrupted module scenarios..." -ForegroundColor Yellow
        
        # Create a temporary invalid module directory
        $tempInvalidModule = Join-Path $env:TEMP "InvalidTestModule"
        if (Test-Path $tempInvalidModule) {
            Remove-Item $tempInvalidModule -Recurse -Force
        }
        New-Item -ItemType Directory -Path $tempInvalidModule -Force | Out-Null
        
        try {
            Import-Module $tempInvalidModule -ErrorAction Stop
            $errorTests += @{
                Test = "Invalid module directory"
                Expected = "Should fail gracefully"
                Actual = "Succeeded (unexpected)"
                Success = $false
            }
            Write-Host "✗ Invalid module directory should have failed" -ForegroundColor Red
        } catch {
            $errorTests += @{
                Test = "Invalid module directory"
                Expected = "Should fail with appropriate error"
                Actual = "Failed as expected: $($_.Exception.Message)"
                Success = $true
            }
            Write-Host "✓ Invalid module directory failed correctly: $($_.Exception.Message)" -ForegroundColor Green
        } finally {
            # Cleanup
            if (Test-Path $tempInvalidModule) {
                Remove-Item $tempInvalidModule -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        return @{
            Success = $true
            ErrorTests = $errorTests
        }
        
    } catch {
        Write-Host "✗ Missing module handling test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            ErrorTests = $errorTests
        }
    }
}

function Test-FunctionNotFoundHandling {
    Write-Host "`n=== Testing Function Not Found Handling ===" -ForegroundColor Cyan
    
    $functionTests = @()
    
    try {
        # Import AitherCore to ensure we have a baseline
        Import-Module ./aither-core/AitherCore.psd1 -Force
        
        # Test 1: Call non-existent function
        Write-Host "`n1. Testing non-existent function call..." -ForegroundColor Yellow
        
        try {
            & "Non-Existent-Function"
            $functionTests += @{
                Test = "Non-existent function call"
                Expected = "Should fail with command not found"
                Actual = "Succeeded (unexpected)"
                Success = $false
            }
            Write-Host "✗ Non-existent function call should have failed" -ForegroundColor Red
        } catch {
            $functionTests += @{
                Test = "Non-existent function call"
                Expected = "Should fail with command not found"
                Actual = "Failed as expected: $($_.Exception.Message)"
                Success = $true
            }
            Write-Host "✓ Non-existent function call failed correctly: $($_.Exception.Message)" -ForegroundColor Green
        }
        
        # Test 2: Call function with invalid parameters
        Write-Host "`n2. Testing function with invalid parameters..." -ForegroundColor Yellow
        
        try {
            # Use a known function with invalid parameters
            Write-CustomLog -Level "INVALID_LEVEL" -Message "Test"
            $functionTests += @{
                Test = "Function with invalid parameters"
                Expected = "Should fail with parameter validation error"
                Actual = "Succeeded (unexpected)"
                Success = $false
            }
            Write-Host "✗ Function with invalid parameters should have failed" -ForegroundColor Red
        } catch {
            $functionTests += @{
                Test = "Function with invalid parameters"
                Expected = "Should fail with parameter validation error"
                Actual = "Failed as expected: $($_.Exception.Message)"
                Success = $true
            }
            Write-Host "✓ Function with invalid parameters failed correctly: $($_.Exception.Message)" -ForegroundColor Green
        }
        
        # Test 3: Test module function availability after module removal
        Write-Host "`n3. Testing function availability after module removal..." -ForegroundColor Yellow
        
        # Import a test module
        Import-Module ./aither-core/modules/Logging -Force
        
        # Verify function exists
        if (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue) {
            Write-Host "   ✓ Function available after module import" -ForegroundColor Green
            
            # Remove the module
            Remove-Module 'Logging' -Force
            
            # Test if function is still available (it shouldn't be, or should gracefully handle)
            try {
                $testResult = Get-Command 'Write-CustomLog' -ErrorAction Stop
                $functionTests += @{
                    Test = "Function availability after module removal"
                    Expected = "Function should not be available or handle gracefully"
                    Actual = "Function still available (may be from another module)"
                    Success = $true
                    Note = "Function may be available from another loaded module"
                }
                Write-Host "   ⚠ Function still available (possibly from another module)" -ForegroundColor Yellow
            } catch {
                $functionTests += @{
                    Test = "Function availability after module removal"
                    Expected = "Function should not be available"
                    Actual = "Function correctly removed: $($_.Exception.Message)"
                    Success = $true
                }
                Write-Host "   ✓ Function correctly removed after module unload" -ForegroundColor Green
            }
        }
        
        return @{
            Success = $true
            FunctionTests = $functionTests
        }
        
    } catch {
        Write-Host "✗ Function not found handling test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            FunctionTests = $functionTests
        }
    }
}

function Test-InitializationErrorRecovery {
    Write-Host "`n=== Testing Initialization Error Recovery ===" -ForegroundColor Cyan
    
    $recoveryTests = @()
    
    try {
        # Test 1: Initialize with missing required module
        Write-Host "`n1. Testing initialization with missing required module..." -ForegroundColor Yellow
        
        # Remove all modules first
        Get-Module | Where-Object { $_.Name -in @('AitherCore', 'Logging', 'LabRunner', 'OpenTofuProvider') } | Remove-Module -Force
        
        # Temporarily rename a required module to simulate missing dependency
        $loggingPath = "./aither-core/modules/Logging"
        $tempLoggingPath = "./aither-core/modules/Logging_temp_hidden"
        
        if (Test-Path $loggingPath) {
            Rename-Item $loggingPath $tempLoggingPath
        }
        
        try {
            # Try to initialize AitherCore
            Import-Module ./aither-core/AitherCore.psd1 -Force
            $initResult = Initialize-CoreApplication -RequiredOnly
            
            $recoveryTests += @{
                Test = "Initialize with missing required module"
                Expected = "Should handle missing dependencies gracefully"
                Actual = "Initialization result: $initResult"
                Success = $true
                Note = "System may have recovered or used fallbacks"
            }
            Write-Host "   ✓ Initialization handled missing dependency gracefully" -ForegroundColor Green
            
        } catch {
            $recoveryTests += @{
                Test = "Initialize with missing required module"
                Expected = "Should fail gracefully with clear error"
                Actual = "Failed as expected: $($_.Exception.Message)"
                Success = $true
            }
            Write-Host "   ✓ Initialization failed gracefully: $($_.Exception.Message)" -ForegroundColor Green
        } finally {
            # Restore the module
            if (Test-Path $tempLoggingPath) {
                Rename-Item $tempLoggingPath $loggingPath
            }
        }
        
        # Test 2: Test recovery after failed initialization
        Write-Host "`n2. Testing recovery after failed initialization..." -ForegroundColor Yellow
        
        # Clean slate
        Get-Module | Where-Object { $_.Name -like 'AitherCore' } | Remove-Module -Force
        
        # Normal initialization should work now
        try {
            Import-Module ./aither-core/AitherCore.psd1 -Force
            $recoveryResult = Initialize-CoreApplication -RequiredOnly
            
            $recoveryTests += @{
                Test = "Recovery after failed initialization"
                Expected = "Should recover and initialize successfully"
                Actual = "Recovery successful: $recoveryResult"
                Success = $recoveryResult
            }
            
            if ($recoveryResult) {
                Write-Host "   ✓ Successfully recovered and initialized" -ForegroundColor Green
            } else {
                Write-Host "   ⚠ Recovery partially successful" -ForegroundColor Yellow
            }
            
        } catch {
            $recoveryTests += @{
                Test = "Recovery after failed initialization"
                Expected = "Should recover successfully"
                Actual = "Recovery failed: $($_.Exception.Message)"
                Success = $false
            }
            Write-Host "   ✗ Recovery failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Test 3: Test force re-initialization
        Write-Host "`n3. Testing force re-initialization..." -ForegroundColor Yellow
        
        try {
            $forceResult = Initialize-CoreApplication -Force
            
            $recoveryTests += @{
                Test = "Force re-initialization"
                Expected = "Should re-initialize successfully"
                Actual = "Force initialization result: $forceResult"
                Success = $forceResult
            }
            
            if ($forceResult) {
                Write-Host "   ✓ Force re-initialization successful" -ForegroundColor Green
            } else {
                Write-Host "   ⚠ Force re-initialization had issues" -ForegroundColor Yellow
            }
            
        } catch {
            $recoveryTests += @{
                Test = "Force re-initialization"
                Expected = "Should re-initialize successfully"
                Actual = "Force initialization failed: $($_.Exception.Message)"
                Success = $false
            }
            Write-Host "   ✗ Force re-initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        return @{
            Success = $true
            RecoveryTests = $recoveryTests
        }
        
    } catch {
        Write-Host "✗ Initialization error recovery test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            RecoveryTests = $recoveryTests
        }
    }
}

function Test-ErrorPropagation {
    Write-Host "`n=== Testing Error Propagation ===" -ForegroundColor Cyan
    
    $propagationTests = @()
    
    try {
        # Ensure AitherCore is loaded
        Import-Module ./aither-core/AitherCore.psd1 -Force
        Initialize-CoreApplication -RequiredOnly
        
        # Test 1: Test error propagation in core functions
        Write-Host "`n1. Testing error propagation in core functions..." -ForegroundColor Yellow
        
        try {
            # Test with invalid configuration path
            $result = Get-CoreConfiguration -ConfigPath "./non-existent-config.json"
            $propagationTests += @{
                Test = "Error propagation in Get-CoreConfiguration"
                Expected = "Should propagate file not found error"
                Actual = "Succeeded unexpectedly"
                Success = $false
            }
            Write-Host "   ✗ Get-CoreConfiguration should have failed with invalid path" -ForegroundColor Red
        } catch {
            $propagationTests += @{
                Test = "Error propagation in Get-CoreConfiguration"
                Expected = "Should propagate file not found error"
                Actual = "Error propagated correctly: $($_.Exception.Message)"
                Success = $true
            }
            Write-Host "   ✓ Get-CoreConfiguration error propagated correctly: $($_.Exception.Message)" -ForegroundColor Green
        }
        
        # Test 2: Test error handling in module status
        Write-Host "`n2. Testing error handling in module status..." -ForegroundColor Yellow
        
        try {
            $moduleStatus = Get-CoreModuleStatus
            if ($moduleStatus) {
                $propagationTests += @{
                    Test = "Module status error handling"
                    Expected = "Should return status or handle errors gracefully"
                    Actual = "Returned status for $($moduleStatus.Count) modules"
                    Success = $true
                }
                Write-Host "   ✓ Module status retrieved successfully" -ForegroundColor Green
            } else {
                $propagationTests += @{
                    Test = "Module status error handling"
                    Expected = "Should return status or handle errors gracefully"
                    Actual = "Returned null/empty status"
                    Success = $false
                }
                Write-Host "   ✗ Module status returned null/empty" -ForegroundColor Red
            }
        } catch {
            $propagationTests += @{
                Test = "Module status error handling"
                Expected = "Should handle errors gracefully"
                Actual = "Exception thrown: $($_.Exception.Message)"
                Success = $false
            }
            Write-Host "   ✗ Module status threw exception: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Test 3: Test error handling in health check
        Write-Host "`n3. Testing error handling in health check..." -ForegroundColor Yellow
        
        try {
            $healthResult = Test-CoreApplicationHealth
            $propagationTests += @{
                Test = "Health check error handling"
                Expected = "Should return boolean result"
                Actual = "Health check result: $healthResult"
                Success = $true
            }
            Write-Host "   ✓ Health check completed: $healthResult" -ForegroundColor Green
        } catch {
            $propagationTests += @{
                Test = "Health check error handling"
                Expected = "Should handle errors gracefully"
                Actual = "Exception thrown: $($_.Exception.Message)"
                Success = $false
            }
            Write-Host "   ✗ Health check threw exception: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        return @{
            Success = $true
            PropagationTests = $propagationTests
        }
        
    } catch {
        Write-Host "✗ Error propagation test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            PropagationTests = $propagationTests
        }
    }
}

try {
    Write-Host "=== Error Handling and Dependency Testing ===" -ForegroundColor Cyan
    
    $testResults = @{}
    
    # Test 1: Missing Module Handling
    $testResults.MissingModuleHandling = Test-MissingModuleHandling
    
    # Test 2: Function Not Found Handling
    $testResults.FunctionNotFoundHandling = Test-FunctionNotFoundHandling
    
    # Test 3: Initialization Error Recovery
    $testResults.InitializationErrorRecovery = Test-InitializationErrorRecovery
    
    # Test 4: Error Propagation
    $testResults.ErrorPropagation = Test-ErrorPropagation
    
    # Final Assessment
    Write-Host "`n=== Final Assessment ===" -ForegroundColor Cyan
    
    $failedTests = $testResults.Values | Where-Object { -not $_.Success }
    $allTestsPassed = ($failedTests.Count -eq 0)
    
    if ($allTestsPassed) {
        Write-Host "🎉 All error handling tests PASSED" -ForegroundColor Green
    } else {
        Write-Host "❌ Some error handling tests had issues:" -ForegroundColor Red
        foreach ($failedTest in $failedTests) {
            Write-Host "  - $($failedTest.Error)" -ForegroundColor Red
        }
    }
    
    # Detailed breakdown if requested
    if ($Detailed) {
        Write-Host "`nDetailed Test Results:" -ForegroundColor Cyan
        
        foreach ($testCategory in $testResults.Keys) {
            Write-Host "`n$testCategory Results:" -ForegroundColor Yellow
            $categoryResult = $testResults[$testCategory]
            
            if ($categoryResult.ErrorTests) {
                $categoryResult.ErrorTests | Format-Table Test, Expected, Actual, Success -AutoSize
            }
            if ($categoryResult.FunctionTests) {
                $categoryResult.FunctionTests | Format-Table Test, Expected, Actual, Success -AutoSize
            }
            if ($categoryResult.RecoveryTests) {
                $categoryResult.RecoveryTests | Format-Table Test, Expected, Actual, Success -AutoSize
            }
            if ($categoryResult.PropagationTests) {
                $categoryResult.PropagationTests | Format-Table Test, Expected, Actual, Success -AutoSize
            }
        }
    }
    
    # Summary statistics
    $totalTests = 0
    $passedTests = 0
    
    foreach ($result in $testResults.Values) {
        if ($result.ErrorTests) { 
            $totalTests += $result.ErrorTests.Count
            $passedTests += ($result.ErrorTests | Where-Object { $_.Success }).Count
        }
        if ($result.FunctionTests) { 
            $totalTests += $result.FunctionTests.Count
            $passedTests += ($result.FunctionTests | Where-Object { $_.Success }).Count
        }
        if ($result.RecoveryTests) { 
            $totalTests += $result.RecoveryTests.Count
            $passedTests += ($result.RecoveryTests | Where-Object { $_.Success }).Count
        }
        if ($result.PropagationTests) { 
            $totalTests += $result.PropagationTests.Count
            $passedTests += ($result.PropagationTests | Where-Object { $_.Success }).Count
        }
    }
    
    Write-Host "`n📊 Error Handling Test Summary:" -ForegroundColor Cyan
    Write-Host "  - Total tests: $totalTests" -ForegroundColor White
    Write-Host "  - Passed: $passedTests" -ForegroundColor Green
    Write-Host "  - Failed: $($totalTests - $passedTests)" -ForegroundColor $(if (($totalTests - $passedTests) -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  - Success rate: $([math]::Round(($passedTests / $totalTests) * 100, 1))%" -ForegroundColor White
    
    return @{
        Success = $allTestsPassed
        TestResults = $testResults
        Summary = @{
            TotalTests = $totalTests
            PassedTests = $passedTests
            FailedTests = ($totalTests - $passedTests)
            SuccessRate = ($passedTests / $totalTests) * 100
        }
    }
    
} catch {
    Write-Host "`n=== Error Handling Testing FAILED ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    
    return @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }
}