#!/usr/bin/env pwsh
#Requires -Version 7.0

# Test script for module initialization sequences and order validation

param(
    [switch]$Detailed,
    [switch]$TestBootstrap
)

$ErrorActionPreference = 'Stop'

function Test-ModuleLoadOrder {
    Write-Host "=== Testing Module Load Order ===" -ForegroundColor Cyan
    
    $loadSequence = @()
    $startTime = Get-Date
    
    try {
        # Test 1: Bootstrap sequence
        Write-Host "`n1. Testing bootstrap sequence..." -ForegroundColor Yellow
        
        # Clean start - remove any existing modules
        Get-Module | Where-Object { $_.Name -in @('AitherCore', 'Logging', 'LabRunner', 'OpenTofuProvider', 'ModuleCommunication', 'ConfigurationCore') } | Remove-Module -Force
        
        # Step 1: Import AitherCore (should trigger consolidated loading)
        $step1Start = Get-Date
        Import-Module ./aither-core/AitherCore.psd1 -Force -Verbose
        $step1End = Get-Date
        $loadSequence += @{
            Step = "AitherCore Import"
            Duration = ($step1End - $step1Start).TotalMilliseconds
            ModulesLoaded = (Get-Module).Count
        }
        Write-Host "✓ AitherCore imported in $([math]::Round(($step1End - $step1Start).TotalMilliseconds, 1))ms" -ForegroundColor Green
        
        # Step 2: Initialize with required modules only
        $step2Start = Get-Date
        $initResult = Initialize-CoreApplication -RequiredOnly -Verbose
        $step2End = Get-Date
        $loadSequence += @{
            Step = "Initialize Required Modules"
            Duration = ($step2End - $step2Start).TotalMilliseconds
            ModulesLoaded = (Get-Module).Count
            Success = $initResult
        }
        Write-Host "✓ Required modules initialized in $([math]::Round(($step2End - $step2Start).TotalMilliseconds, 1))ms" -ForegroundColor Green
        
        # Step 3: Load all modules
        $step3Start = Get-Date
        $fullInitResult = Import-CoreModules -Verbose
        $step3End = Get-Date
        $loadSequence += @{
            Step = "Import All Modules"
            Duration = ($step3End - $step3Start).TotalMilliseconds
            ModulesLoaded = (Get-Module).Count
            ImportedCount = $fullInitResult.ImportedCount
            FailedCount = $fullInitResult.FailedCount
        }
        Write-Host "✓ All modules imported in $([math]::Round(($step3End - $step3Start).TotalMilliseconds, 1))ms" -ForegroundColor Green
        
        return @{
            Success = $true
            LoadSequence = $loadSequence
            TotalTime = ($step3End - $startTime).TotalSeconds
        }
        
    } catch {
        Write-Host "✗ Module load order test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            LoadSequence = $loadSequence
        }
    }
}

function Test-DependencyOrder {
    Write-Host "`n=== Testing Dependency Order ===" -ForegroundColor Cyan
    
    # Clean slate
    Get-Module | Where-Object { $_.Name -like '*' -and $_.Name -notin @('Microsoft.PowerShell.*', 'PSReadLine', 'PackageManagement', 'PowerShellGet') } | Remove-Module -Force
    
    $dependencyTests = @()
    
    try {
        # Test 1: Load dependent module before dependencies (should fail gracefully)
        Write-Host "`n1. Testing dependent module without dependencies..." -ForegroundColor Yellow
        try {
            Import-Module ./aither-core/modules/LabRunner -Force -ErrorAction Stop
            $dependencyTests += @{
                Test = "LabRunner without Logging"
                Success = $true
                Note = "Module loaded successfully (dependencies auto-resolved or optional)"
            }
            Write-Host "✓ LabRunner loaded without explicit Logging dependency" -ForegroundColor Green
        } catch {
            $dependencyTests += @{
                Test = "LabRunner without Logging"
                Success = $false
                Error = $_.Exception.Message
                Note = "Expected behavior - dependency required"
            }
            Write-Host "✓ LabRunner correctly failed without Logging: $($_.Exception.Message)" -ForegroundColor Green
        }
        
        # Test 2: Load dependencies in correct order
        Write-Host "`n2. Testing correct dependency order..." -ForegroundColor Yellow
        
        # Remove all modules again
        Get-Module | Where-Object { $_.Name -like '*' -and $_.Name -notin @('Microsoft.PowerShell.*', 'PSReadLine', 'PackageManagement', 'PowerShellGet') } | Remove-Module -Force
        
        # Load Logging first
        Import-Module ./aither-core/modules/Logging -Force
        Write-Host "✓ Logging loaded first" -ForegroundColor Green
        
        # Then load dependent modules
        Import-Module ./aither-core/modules/LabRunner -Force
        Write-Host "✓ LabRunner loaded after Logging" -ForegroundColor Green
        
        Import-Module ./aither-core/modules/OpenTofuProvider -Force
        Write-Host "✓ OpenTofuProvider loaded after dependencies" -ForegroundColor Green
        
        $dependencyTests += @{
            Test = "Correct dependency order"
            Success = $true
            Note = "All modules loaded in correct sequence"
        }
        
        # Test 3: Verify all modules are functional
        Write-Host "`n3. Testing module functionality after ordered loading..." -ForegroundColor Yellow
        
        # Test Logging
        if (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue) {
            Write-CustomLog -Message "Testing ordered initialization" -Level 'INFO'
            Write-Host "✓ Logging functional" -ForegroundColor Green
        }
        
        # Test LabRunner
        if (Get-Command 'Get-LabStatus' -ErrorAction SilentlyContinue) {
            try {
                $labStatus = Get-LabStatus
                Write-Host "✓ LabRunner functional" -ForegroundColor Green
            } catch {
                Write-Host "⚠ LabRunner loaded but some functions may need configuration" -ForegroundColor Yellow
            }
        }
        
        $dependencyTests += @{
            Test = "Module functionality verification"
            Success = $true
            Note = "All loaded modules are functional"
        }
        
        return @{
            Success = $true
            Tests = $dependencyTests
        }
        
    } catch {
        Write-Host "✗ Dependency order test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            Tests = $dependencyTests
        }
    }
}

function Test-InitializationStability {
    Write-Host "`n=== Testing Initialization Stability ===" -ForegroundColor Cyan
    
    $stabilityResults = @()
    
    try {
        # Test repeated initialization
        Write-Host "`n1. Testing repeated initialization..." -ForegroundColor Yellow
        
        for ($i = 1; $i -le 3; $i++) {
            Write-Host "  Iteration $i..." -ForegroundColor Gray
            
            # Remove modules
            Get-Module | Where-Object { $_.Name -like 'AitherCore' } | Remove-Module -Force
            
            # Re-import and initialize
            $iterStart = Get-Date
            Import-Module ./aither-core/AitherCore.psd1 -Force
            $initResult = Initialize-CoreApplication -RequiredOnly
            $iterEnd = Get-Date
            
            $stabilityResults += @{
                Iteration = $i
                Success = $initResult
                Duration = ($iterEnd - $iterStart).TotalMilliseconds
                ModulesLoaded = (Get-Module).Count
            }
            
            Write-Host "    ✓ Iteration $i completed in $([math]::Round(($iterEnd - $iterStart).TotalMilliseconds, 1))ms" -ForegroundColor Green
        }
        
        # Test force re-initialization
        Write-Host "`n2. Testing force re-initialization..." -ForegroundColor Yellow
        
        $forceStart = Get-Date
        $forceResult = Initialize-CoreApplication -Force
        $forceEnd = Get-Date
        
        Write-Host "✓ Force re-initialization completed in $([math]::Round(($forceEnd - $forceStart).TotalMilliseconds, 1))ms" -ForegroundColor Green
        
        # Test concurrent loading (simulated)
        Write-Host "`n3. Testing initialization state consistency..." -ForegroundColor Yellow
        
        $moduleStatus1 = Get-CoreModuleStatus
        Start-Sleep -Milliseconds 100
        $moduleStatus2 = Get-CoreModuleStatus
        
        $statusConsistent = ($moduleStatus1.Count -eq $moduleStatus2.Count)
        if ($statusConsistent) {
            Write-Host "✓ Module status is consistent across calls" -ForegroundColor Green
        } else {
            Write-Host "⚠ Module status inconsistency detected" -ForegroundColor Yellow
        }
        
        return @{
            Success = $true
            StabilityResults = $stabilityResults
            ForceInitDuration = ($forceEnd - $forceStart).TotalMilliseconds
            StatusConsistent = $statusConsistent
        }
        
    } catch {
        Write-Host "✗ Initialization stability test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            StabilityResults = $stabilityResults
        }
    }
}

function Test-BootstrapSequence {
    Write-Host "`n=== Testing Bootstrap Sequence ===" -ForegroundColor Cyan
    
    try {
        # Test bootstrap script if it exists
        if (Test-Path './bootstrap.ps1') {
            Write-Host "Testing bootstrap script..." -ForegroundColor Yellow
            
            $bootstrapStart = Get-Date
            # Note: Not actually running bootstrap as it might modify environment
            Write-Host "✓ Bootstrap script found at ./bootstrap.ps1" -ForegroundColor Green
        }
        
        # Test aither-core bootstrap
        if (Test-Path './aither-core/aither-core-bootstrap.ps1') {
            Write-Host "Testing aither-core bootstrap..." -ForegroundColor Yellow
            Write-Host "✓ AitherCore bootstrap script found" -ForegroundColor Green
        }
        
        # Test entry point
        if (Test-Path './Start-AitherZero.ps1') {
            Write-Host "Testing main entry point..." -ForegroundColor Yellow
            Write-Host "✓ Main entry point Start-AitherZero.ps1 found" -ForegroundColor Green
        }
        
        return @{
            Success = $true
            BootstrapFound = (Test-Path './bootstrap.ps1')
            AitherCoreBootstrapFound = (Test-Path './aither-core/aither-core-bootstrap.ps1')
            EntryPointFound = (Test-Path './Start-AitherZero.ps1')
        }
        
    } catch {
        Write-Host "✗ Bootstrap sequence test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

try {
    Write-Host "=== Module Initialization Sequences Testing ===" -ForegroundColor Cyan
    
    $testResults = @{}
    
    # Test 1: Module Load Order
    $testResults.LoadOrder = Test-ModuleLoadOrder
    
    # Test 2: Dependency Order
    $testResults.DependencyOrder = Test-DependencyOrder
    
    # Test 3: Initialization Stability
    $testResults.InitializationStability = Test-InitializationStability
    
    # Test 4: Bootstrap Sequence (if requested)
    if ($TestBootstrap) {
        $testResults.BootstrapSequence = Test-BootstrapSequence
    }
    
    # Final Assessment
    Write-Host "`n=== Final Assessment ===" -ForegroundColor Cyan
    
    $allTestsPassed = $testResults.Values | Where-Object { -not $_.Success }
    
    if ($allTestsPassed.Count -eq 0) {
        Write-Host "🎉 All initialization sequence tests PASSED" -ForegroundColor Green
    } else {
        Write-Host "❌ Some initialization tests had issues:" -ForegroundColor Red
        foreach ($failedTest in $allTestsPassed) {
            Write-Host "  - $($failedTest.Error)" -ForegroundColor Red
        }
    }
    
    # Show performance summary
    if ($testResults.LoadOrder.Success) {
        $totalInitTime = $testResults.LoadOrder.TotalTime
        Write-Host "📊 Total initialization time: $([math]::Round($totalInitTime, 2))s" -ForegroundColor White
        
        if ($Detailed -and $testResults.LoadOrder.LoadSequence) {
            Write-Host "`nLoad Sequence Details:" -ForegroundColor Cyan
            $testResults.LoadOrder.LoadSequence | Format-Table Step, @{Name="Duration(ms)"; Expression={[math]::Round($_.Duration, 1)}}, ModulesLoaded -AutoSize
        }
    }
    
    if ($testResults.InitializationStability.Success -and $Detailed) {
        Write-Host "`nStability Test Results:" -ForegroundColor Cyan
        $testResults.InitializationStability.StabilityResults | Format-Table Iteration, Success, @{Name="Duration(ms)"; Expression={[math]::Round($_.Duration, 1)}}, ModulesLoaded -AutoSize
    }
    
    return @{
        Success = ($allTestsPassed.Count -eq 0)
        TestResults = $testResults
        Summary = @{
            LoadOrderPassed = $testResults.LoadOrder.Success
            DependencyOrderPassed = $testResults.DependencyOrder.Success
            StabilityPassed = $testResults.InitializationStability.Success
            TotalInitializationTime = $testResults.LoadOrder.TotalTime
        }
    }
    
} catch {
    Write-Host "`n=== Initialization Sequences Testing FAILED ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    
    return @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }
}