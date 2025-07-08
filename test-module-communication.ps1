#!/usr/bin/env pwsh
#Requires -Version 7.0

# Test script for module communication and integration validation

param(
    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'

function Test-InterModuleCommunication {
    Write-Host "=== Testing Inter-Module Communication ===" -ForegroundColor Cyan
    
    $communicationTests = @()
    
    try {
        # Initialize AitherCore
        Import-Module ./aither-core/AitherCore.psd1 -Force
        $initResult = Initialize-CoreApplication -RequiredOnly
        
        # Test 1: Logging integration across modules
        Write-Host "`n1. Testing logging integration across modules..." -ForegroundColor Yellow
        
        try {
            # Test if logging is available globally
            Write-CustomLog -Message "Testing inter-module logging" -Level 'INFO'
            
            # Test if other modules can use logging
            if (Get-Command 'Get-LabStatus' -ErrorAction SilentlyContinue) {
                $labStatus = Get-LabStatus
                $communicationTests += @{
                    Test = "Logging integration across modules"
                    Success = $true
                    Details = "Logging available to all modules"
                }
                Write-Host "✓ Logging integration working across modules" -ForegroundColor Green
            } else {
                $communicationTests += @{
                    Test = "Logging integration across modules"
                    Success = $true
                    Details = "Logging available, some module functions not loaded"
                }
                Write-Host "✓ Logging integration working" -ForegroundColor Green
            }
            
        } catch {
            $communicationTests += @{
                Test = "Logging integration across modules"
                Success = $false
                Error = $_.Exception.Message
            }
            Write-Host "✗ Logging integration failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Test 2: Configuration system integration
        Write-Host "`n2. Testing configuration system integration..." -ForegroundColor Yellow
        
        try {
            # Test configuration retrieval
            $config = Get-CoreConfiguration
            if ($config) {
                $communicationTests += @{
                    Test = "Configuration system integration"
                    Success = $true
                    Details = "Configuration accessible across modules"
                }
                Write-Host "✓ Configuration system integration working" -ForegroundColor Green
            } else {
                $communicationTests += @{
                    Test = "Configuration system integration"
                    Success = $false
                    Details = "Configuration returned null"
                }
                Write-Host "✗ Configuration system returned null" -ForegroundColor Red
            }
            
        } catch {
            $communicationTests += @{
                Test = "Configuration system integration"
                Success = $false
                Error = $_.Exception.Message
            }
            Write-Host "✗ Configuration system integration failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Test 3: Module status communication
        Write-Host "`n3. Testing module status communication..." -ForegroundColor Yellow
        
        try {
            $moduleStatus = Get-CoreModuleStatus
            if ($moduleStatus -and $moduleStatus.Count -gt 0) {
                $loadedModules = ($moduleStatus | Where-Object { $_.Loaded }).Count
                $communicationTests += @{
                    Test = "Module status communication"
                    Success = $true
                    Details = "Status available for $($moduleStatus.Count) modules, $loadedModules loaded"
                }
                Write-Host "✓ Module status communication working ($loadedModules loaded modules)" -ForegroundColor Green
            } else {
                $communicationTests += @{
                    Test = "Module status communication"
                    Success = $false
                    Details = "Module status returned empty or null"
                }
                Write-Host "✗ Module status communication failed" -ForegroundColor Red
            }
            
        } catch {
            $communicationTests += @{
                Test = "Module status communication"
                Success = $false
                Error = $_.Exception.Message
            }
            Write-Host "✗ Module status communication failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        return @{
            Success = $true
            CommunicationTests = $communicationTests
        }
        
    } catch {
        Write-Host "✗ Inter-module communication test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            CommunicationTests = $communicationTests
        }
    }
}

function Test-ModuleCommunicationSystem {
    Write-Host "`n=== Testing ModuleCommunication System ===" -ForegroundColor Cyan
    
    $mcTests = @()
    
    try {
        # Load ModuleCommunication if available
        if (Test-Path "./aither-core/modules/ModuleCommunication") {
            Import-Module ./aither-core/modules/ModuleCommunication -Force
            
            # Test 1: Module communication status
            Write-Host "`n1. Testing ModuleCommunication system status..." -ForegroundColor Yellow
            
            try {
                if (Get-Command 'Get-CommunicationStatus' -ErrorAction SilentlyContinue) {
                    $commStatus = Get-CommunicationStatus
                    $mcTests += @{
                        Test = "ModuleCommunication system status"
                        Success = $true
                        Details = "Communication system accessible"
                    }
                    Write-Host "✓ ModuleCommunication system status available" -ForegroundColor Green
                } else {
                    $mcTests += @{
                        Test = "ModuleCommunication system status"
                        Success = $false
                        Details = "Get-CommunicationStatus not available"
                    }
                    Write-Host "✗ ModuleCommunication status function not available" -ForegroundColor Red
                }
                
            } catch {
                $mcTests += @{
                    Test = "ModuleCommunication system status"
                    Success = $false
                    Error = $_.Exception.Message
                }
                Write-Host "✗ ModuleCommunication status test failed: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            # Test 2: Message channels
            Write-Host "`n2. Testing message channels..." -ForegroundColor Yellow
            
            try {
                if (Get-Command 'Get-MessageChannels' -ErrorAction SilentlyContinue) {
                    $channels = Get-MessageChannels
                    $mcTests += @{
                        Test = "Message channels functionality"
                        Success = $true
                        Details = "Message channels accessible"
                    }
                    Write-Host "✓ Message channels functionality available" -ForegroundColor Green
                } else {
                    $mcTests += @{
                        Test = "Message channels functionality"
                        Success = $false
                        Details = "Get-MessageChannels not available"
                    }
                    Write-Host "✗ Message channels function not available" -ForegroundColor Red
                }
                
            } catch {
                $mcTests += @{
                    Test = "Message channels functionality"
                    Success = $false
                    Error = $_.Exception.Message
                }
                Write-Host "✗ Message channels test failed: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            # Test 3: API registration
            Write-Host "`n3. Testing API registration..." -ForegroundColor Yellow
            
            try {
                if (Get-Command 'Get-ModuleAPIs' -ErrorAction SilentlyContinue) {
                    $apis = Get-ModuleAPIs
                    $mcTests += @{
                        Test = "API registration system"
                        Success = $true
                        Details = "API registration system accessible"
                    }
                    Write-Host "✓ API registration system available" -ForegroundColor Green
                } else {
                    $mcTests += @{
                        Test = "API registration system"
                        Success = $false
                        Details = "Get-ModuleAPIs not available"
                    }
                    Write-Host "✗ API registration function not available" -ForegroundColor Red
                }
                
            } catch {
                $mcTests += @{
                    Test = "API registration system"
                    Success = $false
                    Error = $_.Exception.Message
                }
                Write-Host "✗ API registration test failed: $($_.Exception.Message)" -ForegroundColor Red
            }
            
        } else {
            $mcTests += @{
                Test = "ModuleCommunication availability"
                Success = $false
                Details = "ModuleCommunication module not found"
            }
            Write-Host "⚠ ModuleCommunication module not available for testing" -ForegroundColor Yellow
        }
        
        return @{
            Success = $true
            MCTests = $mcTests
        }
        
    } catch {
        Write-Host "✗ ModuleCommunication system test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            MCTests = $mcTests
        }
    }
}

function Test-PlatformIntegration {
    Write-Host "`n=== Testing Platform Integration ===" -ForegroundColor Cyan
    
    $platformTests = @()
    
    try {
        # Ensure AitherCore is loaded
        if (-not (Get-Module -Name 'AitherCore')) {
            Import-Module ./aither-core/AitherCore.psd1 -Force
        }
        
        # Test 1: Platform information
        Write-Host "`n1. Testing platform information..." -ForegroundColor Yellow
        
        try {
            if (Get-Command 'Get-PlatformInfo' -ErrorAction SilentlyContinue) {
                $platformInfo = Get-PlatformInfo
                if ($platformInfo) {
                    $platformTests += @{
                        Test = "Platform information"
                        Success = $true
                        Details = "Platform: $platformInfo"
                    }
                    Write-Host "✓ Platform information available: $platformInfo" -ForegroundColor Green
                } else {
                    $platformTests += @{
                        Test = "Platform information"
                        Success = $false
                        Details = "Get-PlatformInfo returned null"
                    }
                    Write-Host "✗ Platform information returned null" -ForegroundColor Red
                }
            } else {
                $platformTests += @{
                    Test = "Platform information"
                    Success = $false
                    Details = "Get-PlatformInfo not available"
                }
                Write-Host "✗ Get-PlatformInfo function not available" -ForegroundColor Red
            }
            
        } catch {
            $platformTests += @{
                Test = "Platform information"
                Success = $false
                Error = $_.Exception.Message
            }
            Write-Host "✗ Platform information test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Test 2: Integrated toolset
        Write-Host "`n2. Testing integrated toolset..." -ForegroundColor Yellow
        
        try {
            if (Get-Command 'Get-IntegratedToolset' -ErrorAction SilentlyContinue) {
                $toolset = Get-IntegratedToolset
                if ($toolset) {
                    $moduleCount = $toolset.CoreModules.Count
                    $capabilityCount = $toolset.Capabilities.Count
                    $platformTests += @{
                        Test = "Integrated toolset"
                        Success = $true
                        Details = "$moduleCount modules, $capabilityCount capabilities"
                    }
                    Write-Host "✓ Integrated toolset available: $moduleCount modules, $capabilityCount capabilities" -ForegroundColor Green
                } else {
                    $platformTests += @{
                        Test = "Integrated toolset"
                        Success = $false
                        Details = "Get-IntegratedToolset returned null"
                    }
                    Write-Host "✗ Integrated toolset returned null" -ForegroundColor Red
                }
            } else {
                $platformTests += @{
                    Test = "Integrated toolset"
                    Success = $false
                    Details = "Get-IntegratedToolset not available"
                }
                Write-Host "✗ Get-IntegratedToolset function not available" -ForegroundColor Red
            }
            
        } catch {
            $platformTests += @{
                Test = "Integrated toolset"
                Success = $false
                Error = $_.Exception.Message
            }
            Write-Host "✗ Integrated toolset test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Test 3: Platform health check
        Write-Host "`n3. Testing platform health check..." -ForegroundColor Yellow
        
        try {
            if (Get-Command 'Get-PlatformHealth' -ErrorAction SilentlyContinue) {
                $platformHealth = Get-PlatformHealth
                $platformTests += @{
                    Test = "Platform health check"
                    Success = $true
                    Details = "Platform health check available"
                }
                Write-Host "✓ Platform health check available" -ForegroundColor Green
            } else {
                $platformTests += @{
                    Test = "Platform health check"
                    Success = $false
                    Details = "Get-PlatformHealth not available"
                }
                Write-Host "✗ Get-PlatformHealth function not available" -ForegroundColor Red
            }
            
        } catch {
            $platformTests += @{
                Test = "Platform health check"
                Success = $false
                Error = $_.Exception.Message
            }
            Write-Host "✗ Platform health check test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        return @{
            Success = $true
            PlatformTests = $platformTests
        }
        
    } catch {
        Write-Host "✗ Platform integration test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            PlatformTests = $platformTests
        }
    }
}

function Test-ModuleIntegrationScenarios {
    Write-Host "`n=== Testing Module Integration Scenarios ===" -ForegroundColor Cyan
    
    $scenarioTests = @()
    
    try {
        # Ensure we have a clean environment
        Import-Module ./aither-core/AitherCore.psd1 -Force
        Initialize-CoreApplication -RequiredOnly
        
        # Scenario 1: Configuration + Logging integration
        Write-Host "`n1. Testing Configuration + Logging integration..." -ForegroundColor Yellow
        
        try {
            # Get configuration and log it
            $config = Get-CoreConfiguration
            if ($config) {
                Write-CustomLog -Message "Configuration loaded successfully" -Level 'INFO'
                $scenarioTests += @{
                    Scenario = "Configuration + Logging"
                    Success = $true
                    Details = "Configuration loaded and logged successfully"
                }
                Write-Host "✓ Configuration + Logging integration working" -ForegroundColor Green
            } else {
                $scenarioTests += @{
                    Scenario = "Configuration + Logging"
                    Success = $false
                    Details = "Configuration not available"
                }
                Write-Host "✗ Configuration not available for logging test" -ForegroundColor Red
            }
            
        } catch {
            $scenarioTests += @{
                Scenario = "Configuration + Logging"
                Success = $false
                Error = $_.Exception.Message
            }
            Write-Host "✗ Configuration + Logging integration failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Scenario 2: LabRunner + Logging integration
        Write-Host "`n2. Testing LabRunner + Logging integration..." -ForegroundColor Yellow
        
        try {
            # Test if LabRunner functions are available and can log
            if (Get-Command 'Get-LabStatus' -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message "Testing LabRunner integration" -Level 'INFO'
                $labStatus = Get-LabStatus
                $scenarioTests += @{
                    Scenario = "LabRunner + Logging"
                    Success = $true
                    Details = "LabRunner functions available with logging"
                }
                Write-Host "✓ LabRunner + Logging integration working" -ForegroundColor Green
            } else {
                $scenarioTests += @{
                    Scenario = "LabRunner + Logging"
                    Success = $false
                    Details = "LabRunner functions not available"
                }
                Write-Host "⚠ LabRunner functions not loaded for integration test" -ForegroundColor Yellow
            }
            
        } catch {
            $scenarioTests += @{
                Scenario = "LabRunner + Logging"
                Success = $false
                Error = $_.Exception.Message
            }
            Write-Host "✗ LabRunner + Logging integration failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Scenario 3: Complete ecosystem health
        Write-Host "`n3. Testing complete ecosystem health..." -ForegroundColor Yellow
        
        try {
            # Test comprehensive health check
            $coreHealth = Test-CoreApplicationHealth
            $moduleStatus = Get-CoreModuleStatus
            
            if ($coreHealth -and $moduleStatus) {
                $loadedCount = ($moduleStatus | Where-Object { $_.Loaded }).Count
                $availableCount = ($moduleStatus | Where-Object { $_.Available }).Count
                
                $scenarioTests += @{
                    Scenario = "Complete ecosystem health"
                    Success = $true
                    Details = "Core healthy: $coreHealth, Modules: $loadedCount/$availableCount loaded"
                }
                Write-Host "✓ Complete ecosystem health check passed" -ForegroundColor Green
                Write-Host "  - Core health: $coreHealth" -ForegroundColor White
                Write-Host "  - Modules loaded: $loadedCount/$availableCount" -ForegroundColor White
            } else {
                $scenarioTests += @{
                    Scenario = "Complete ecosystem health"
                    Success = $false
                    Details = "Health check failed or status unavailable"
                }
                Write-Host "✗ Complete ecosystem health check failed" -ForegroundColor Red
            }
            
        } catch {
            $scenarioTests += @{
                Scenario = "Complete ecosystem health"
                Success = $false
                Error = $_.Exception.Message
            }
            Write-Host "✗ Complete ecosystem health test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        return @{
            Success = $true
            ScenarioTests = $scenarioTests
        }
        
    } catch {
        Write-Host "✗ Module integration scenarios test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            ScenarioTests = $scenarioTests
        }
    }
}

try {
    Write-Host "=== Module Communication and Integration Testing ===" -ForegroundColor Cyan
    
    $testResults = @{}
    
    # Test 1: Inter-Module Communication
    $testResults.InterModuleCommunication = Test-InterModuleCommunication
    
    # Test 2: ModuleCommunication System
    $testResults.ModuleCommunicationSystem = Test-ModuleCommunicationSystem
    
    # Test 3: Platform Integration
    $testResults.PlatformIntegration = Test-PlatformIntegration
    
    # Test 4: Module Integration Scenarios
    $testResults.IntegrationScenarios = Test-ModuleIntegrationScenarios
    
    # Final Assessment
    Write-Host "`n=== Final Assessment ===" -ForegroundColor Cyan
    
    $failedTests = $testResults.Values | Where-Object { -not $_.Success }
    $allTestsPassed = ($failedTests.Count -eq 0)
    
    if ($allTestsPassed) {
        Write-Host "🎉 All module communication and integration tests PASSED" -ForegroundColor Green
    } else {
        Write-Host "❌ Some communication and integration tests had issues:" -ForegroundColor Red
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
            
            if ($categoryResult.CommunicationTests) {
                $categoryResult.CommunicationTests | Format-Table Test, Success, Details -AutoSize
            }
            if ($categoryResult.MCTests) {
                $categoryResult.MCTests | Format-Table Test, Success, Details -AutoSize
            }
            if ($categoryResult.PlatformTests) {
                $categoryResult.PlatformTests | Format-Table Test, Success, Details -AutoSize
            }
            if ($categoryResult.ScenarioTests) {
                $categoryResult.ScenarioTests | Format-Table Scenario, Success, Details -AutoSize
            }
        }
    }
    
    # Summary statistics
    $totalTests = 0
    $passedTests = 0
    
    foreach ($result in $testResults.Values) {
        if ($result.CommunicationTests) { 
            $totalTests += $result.CommunicationTests.Count
            $passedTests += ($result.CommunicationTests | Where-Object { $_.Success }).Count
        }
        if ($result.MCTests) { 
            $totalTests += $result.MCTests.Count
            $passedTests += ($result.MCTests | Where-Object { $_.Success }).Count
        }
        if ($result.PlatformTests) { 
            $totalTests += $result.PlatformTests.Count
            $passedTests += ($result.PlatformTests | Where-Object { $_.Success }).Count
        }
        if ($result.ScenarioTests) { 
            $totalTests += $result.ScenarioTests.Count
            $passedTests += ($result.ScenarioTests | Where-Object { $_.Success }).Count
        }
    }
    
    Write-Host "`n📊 Communication & Integration Test Summary:" -ForegroundColor Cyan
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
    Write-Host "`n=== Module Communication and Integration Testing FAILED ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    
    return @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }
}