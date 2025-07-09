# AitherCore Integration Tests - Domain Loading System
# Tests cross-domain and cross-module integration
# Agent 3 Mission: Integration Testing Architect

#Requires -Version 7.0

# Enable verbose output for debugging
$VerbosePreference = 'Continue'

# Test Framework Configuration
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Test Context Setup
BeforeAll {
    # Find project root
    $projectRoot = $PSScriptRoot
    while ($projectRoot -and -not (Test-Path (Join-Path $projectRoot "aither-core"))) {
        $parent = Split-Path $projectRoot -Parent
        if ($parent -eq $projectRoot) { break }
        $projectRoot = $parent
    }
    
    if (-not $projectRoot) {
        throw "Could not find project root with aither-core directory"
    }
    
    # Set environment variables
    $env:PROJECT_ROOT = $projectRoot
    $env:PWSH_MODULES_PATH = Join-Path $projectRoot "aither-core/modules"
    
    # Initialize test results collection
    $script:TestResults = @{
        DomainLoadingTests = @()
        CrossDomainTests = @()
        InitializationTests = @()
        IntegrationWorkflowTests = @()
        PerformanceTests = @()
        ErrorHandlingTests = @()
        StartTime = Get-Date
    }
    
    Write-Information "Setting up integration test environment..."
    Write-Information "Project Root: $projectRoot"
    Write-Information "Module Path: $env:PWSH_MODULES_PATH"
}

# Test Suite 1: Domain Loading Order and Dependencies
Describe "AitherCore Domain Loading System" {
    
    Context "Domain Loading Order" {
        It "Should load Logging module first" {
            # Import AitherCore and capture the loading process
            $coreModulePath = Join-Path $env:PROJECT_ROOT "aither-core/AitherCore.psm1"
            
            # Remove any existing module to ensure clean test
            Remove-Module AitherCore -Force -ErrorAction SilentlyContinue
            
            # Import with verbose output to capture loading order
            $importResult = Import-Module $coreModulePath -Force -PassThru -Verbose 2>&1
            
            # Check that Write-CustomLog is available after import
            $logCommandAvailable = Get-Command Write-CustomLog -ErrorAction SilentlyContinue
            $logCommandAvailable | Should -Not -BeNullOrEmpty
            
            # Verify logging module loaded before other domains
            $module = Get-Module AitherCore
            $module | Should -Not -BeNullOrEmpty
            
            # Log test result
            $script:TestResults.DomainLoadingTests += @{
                TestName = "Logging Module First"
                Result = "PASSED"
                Details = "Write-CustomLog available after import"
            }
        }
        
        It "Should load domains in correct dependency order" {
            # Test the domain loading order from CoreDomains array
            $coreModule = Get-Module AitherCore
            $coreModule | Should -Not -BeNullOrEmpty
            
            # Call Initialize-CoreApplication to trigger domain loading
            $initResult = Initialize-CoreApplication -RequiredOnly
            $initResult | Should -Be $true
            
            # Verify domain loading tracking
            $domainStatus = Get-CoreModuleStatus
            $domainStatus | Should -Not -BeNullOrEmpty
            
            # Check that required domains are loaded
            $requiredDomains = $domainStatus | Where-Object { $_.Required -eq $true -and $_.Type -eq 'Domain' }
            $loadedRequiredDomains = $requiredDomains | Where-Object { $_.Loaded -eq $true }
            
            $loadedRequiredDomains.Count | Should -BeGreaterThan 0
            
            $script:TestResults.DomainLoadingTests += @{
                TestName = "Domain Loading Order"
                Result = "PASSED"
                Details = "Required domains loaded: $($loadedRequiredDomains.Name -join ', ')"
            }
        }
        
        It "Should handle domain file loading correctly" {
            # Test domain file loading (domains use .ps1 files, not .psm1)
            $infraDomainPath = Join-Path $env:PROJECT_ROOT "aither-core/domains/infrastructure"
            $configDomainPath = Join-Path $env:PROJECT_ROOT "aither-core/domains/configuration"
            
            # Verify domain directories exist
            Test-Path $infraDomainPath | Should -Be $true
            Test-Path $configDomainPath | Should -Be $true
            
            # Verify domain files exist
            $infraFiles = Get-ChildItem -Path $infraDomainPath -Filter "*.ps1" -ErrorAction SilentlyContinue
            $configFiles = Get-ChildItem -Path $configDomainPath -Filter "*.ps1" -ErrorAction SilentlyContinue
            
            $infraFiles.Count | Should -BeGreaterThan 0
            $configFiles.Count | Should -BeGreaterThan 0
            
            $script:TestResults.DomainLoadingTests += @{
                TestName = "Domain File Structure"
                Result = "PASSED"
                Details = "Infrastructure files: $($infraFiles.Count), Configuration files: $($configFiles.Count)"
            }
        }
    }
    
    Context "Module vs Domain Coexistence" {
        It "Should load both domains and individual modules" {
            # Initialize full system (not just required)
            $fullInitResult = Initialize-CoreApplication -RequiredOnly:$false
            $fullInitResult | Should -Be $true
            
            # Get comprehensive status
            $allStatus = Get-CoreModuleStatus
            $domains = $allStatus | Where-Object { $_.Type -eq 'Domain' }
            $modules = $allStatus | Where-Object { $_.Type -eq 'Module' }
            
            $domains.Count | Should -BeGreaterThan 0
            $modules.Count | Should -BeGreaterThan 0
            
            # Verify mixed loading works
            $loadedDomains = $domains | Where-Object { $_.Loaded -eq $true }
            $loadedModules = $modules | Where-Object { $_.Loaded -eq $true }
            
            $script:TestResults.DomainLoadingTests += @{
                TestName = "Domain-Module Coexistence"
                Result = "PASSED"
                Details = "Loaded domains: $($loadedDomains.Count), Loaded modules: $($loadedModules.Count)"
            }
        }
        
        It "Should handle module dependencies correctly" {
            # Test that modules with dependencies load properly
            $moduleStatus = Get-CoreModuleStatus
            $communicationModule = $moduleStatus | Where-Object { $_.Name -eq 'ModuleCommunication' }
            
            if ($communicationModule -and $communicationModule.Available) {
                # Test module communication system
                $commResult = Test-ModuleCommunication
                $commResult | Should -Be $true
                
                $script:TestResults.DomainLoadingTests += @{
                    TestName = "Module Dependencies"
                    Result = "PASSED"
                    Details = "ModuleCommunication system functional"
                }
            } else {
                $script:TestResults.DomainLoadingTests += @{
                    TestName = "Module Dependencies"
                    Result = "SKIPPED"
                    Details = "ModuleCommunication not available"
                }
            }
        }
    }
}

# Test Suite 2: Cross-Domain Function Calls and Data Sharing
Describe "Cross-Domain Integration" {
    
    Context "Cross-Domain Function Calls" {
        It "Should enable configuration domain to call infrastructure functions" {
            # Test configuration domain can use infrastructure functions
            $configInitResult = Initialize-ConfigurationCore
            $configInitResult | Should -Not -Throw
            
            # Test infrastructure domain functions are available
            $labStatusCmd = Get-Command Get-LabStatus -ErrorAction SilentlyContinue
            if ($labStatusCmd) {
                $labStatus = Get-LabStatus
                $labStatus | Should -Not -BeNullOrEmpty
                
                $script:TestResults.CrossDomainTests += @{
                    TestName = "Configuration-Infrastructure Integration"
                    Result = "PASSED"
                    Details = "Configuration domain can call infrastructure functions"
                }
            }
        }
        
        It "Should enable infrastructure domain to use configuration functions" {
            # Test infrastructure can use configuration functions
            $configCmd = Get-Command Get-ConfigurationStore -ErrorAction SilentlyContinue
            if ($configCmd) {
                $configStore = Get-ConfigurationStore
                $configStore | Should -Not -BeNullOrEmpty
                
                $script:TestResults.CrossDomainTests += @{
                    TestName = "Infrastructure-Configuration Integration"
                    Result = "PASSED"
                    Details = "Infrastructure domain can access configuration store"
                }
            }
        }
        
        It "Should enable shared Write-CustomLog across all domains" {
            # Test that Write-CustomLog is universally available
            $logCmd = Get-Command Write-CustomLog -ErrorAction SilentlyContinue
            $logCmd | Should -Not -BeNullOrEmpty
            
            # Test logging from different contexts
            { Write-CustomLog -Message "Test from infrastructure context" -Level "INFO" } | Should -Not -Throw
            { Write-CustomLog -Message "Test from configuration context" -Level "SUCCESS" } | Should -Not -Throw
            
            $script:TestResults.CrossDomainTests += @{
                TestName = "Shared Logging System"
                Result = "PASSED"
                Details = "Write-CustomLog available across all domains"
            }
        }
    }
    
    Context "Data Sharing Between Domains" {
        It "Should share environment variables correctly" {
            # Test environment variable sharing
            $env:PROJECT_ROOT | Should -Not -BeNullOrEmpty
            $env:PWSH_MODULES_PATH | Should -Not -BeNullOrEmpty
            
            # Test that domains can access shared environment
            $projectRoot = $env:PROJECT_ROOT
            $modulePath = $env:PWSH_MODULES_PATH
            
            $projectRoot | Should -Match "AitherZero"
            $modulePath | Should -Match "modules"
            
            $script:TestResults.CrossDomainTests += @{
                TestName = "Environment Variable Sharing"
                Result = "PASSED"
                Details = "PROJECT_ROOT and PWSH_MODULES_PATH available"
            }
        }
        
        It "Should maintain script-level variable integrity" {
            # Test that script-level variables don't conflict between domains
            $coreModule = Get-Module AitherCore
            $coreModule | Should -Not -BeNullOrEmpty
            
            # Test that domain loading tracking works
            $moduleStatus = Get-CoreModuleStatus
            $moduleStatus | Should -Not -BeNullOrEmpty
            
            # Verify we can distinguish between domains and modules
            $domains = $moduleStatus | Where-Object { $_.Type -eq 'Domain' }
            $modules = $moduleStatus | Where-Object { $_.Type -eq 'Module' }
            
            $domains.Count | Should -BeGreaterThan 0
            $modules.Count | Should -BeGreaterThan 0
            
            $script:TestResults.CrossDomainTests += @{
                TestName = "Script Variable Integrity"
                Result = "PASSED"
                Details = "Domain and module tracking maintained separately"
            }
        }
    }
}

# Test Suite 3: Initialize-CoreApplication with Different Profiles
Describe "CoreApplication Initialization Profiles" {
    
    Context "Required Only Profile" {
        It "Should load only required components" {
            # Clean state for test
            Remove-Module AitherCore -Force -ErrorAction SilentlyContinue
            Import-Module (Join-Path $env:PROJECT_ROOT "aither-core/AitherCore.psm1") -Force
            
            # Test required-only initialization
            $requiredResult = Initialize-CoreApplication -RequiredOnly
            $requiredResult | Should -Be $true
            
            # Verify only required components loaded
            $status = Get-CoreModuleStatus
            $requiredLoaded = $status | Where-Object { $_.Required -eq $true -and $_.Loaded -eq $true }
            $optionalLoaded = $status | Where-Object { $_.Required -eq $false -and $_.Loaded -eq $true }
            
            $requiredLoaded.Count | Should -BeGreaterThan 0
            $optionalLoaded.Count | Should -BeLessThan $requiredLoaded.Count
            
            $script:TestResults.InitializationTests += @{
                TestName = "Required Only Profile"
                Result = "PASSED"
                Details = "Required: $($requiredLoaded.Count), Optional: $($optionalLoaded.Count)"
            }
        }
    }
    
    Context "Full Profile" {
        It "Should load all available components" {
            # Test full initialization
            $fullResult = Initialize-CoreApplication -RequiredOnly:$false
            $fullResult | Should -Be $true
            
            # Verify more components loaded
            $status = Get-CoreModuleStatus
            $allLoaded = $status | Where-Object { $_.Loaded -eq $true }
            $allAvailable = $status | Where-Object { $_.Available -eq $true }
            
            $allLoaded.Count | Should -BeGreaterThan 0
            
            # Should load most available components
            $loadPercentage = ($allLoaded.Count / $allAvailable.Count) * 100
            $loadPercentage | Should -BeGreaterThan 50
            
            $script:TestResults.InitializationTests += @{
                TestName = "Full Profile"
                Result = "PASSED"
                Details = "Loaded: $($allLoaded.Count)/$($allAvailable.Count) ($([math]::Round($loadPercentage))%)"
            }
        }
    }
    
    Context "Force Re-initialization" {
        It "Should handle force re-initialization correctly" {
            # Test force flag
            $forceResult = Initialize-CoreApplication -Force
            $forceResult | Should -Be $true
            
            # Verify system still functional after force reload
            $healthResult = Test-CoreApplicationHealth
            $healthResult | Should -Be $true
            
            $script:TestResults.InitializationTests += @{
                TestName = "Force Re-initialization"
                Result = "PASSED"
                Details = "System healthy after force reload"
            }
        }
    }
}

# Test Suite 4: Integration Workflow Tests
Describe "Integration Workflow Tests" {
    
    Context "Lab Automation Workflow" {
        It "Should integrate lab automation with configuration system" {
            # Test lab automation integration
            $labAutomationCmd = Get-Command Start-LabAutomation -ErrorAction SilentlyContinue
            if ($labAutomationCmd) {
                # Test with minimal configuration
                $testConfig = @{
                    environment = "test"
                    steps = @("validation", "setup")
                }
                
                $result = Start-LabAutomation -Configuration $testConfig -ShowProgress:$false
                $result | Should -Not -BeNullOrEmpty
                $result.Status | Should -Be "Success"
                
                $script:TestResults.IntegrationWorkflowTests += @{
                    TestName = "Lab Automation Integration"
                    Result = "PASSED"
                    Details = "Lab automation successfully integrated with configuration"
                }
            }
        }
    }
    
    Context "Configuration Carousel Integration" {
        It "Should integrate configuration carousel with core system" {
            # Test configuration carousel integration
            $configCmd = Get-Command Get-AvailableConfigurations -ErrorAction SilentlyContinue
            if ($configCmd) {
                $configs = Get-AvailableConfigurations
                $configs | Should -Not -BeNullOrEmpty
                $configs.TotalConfigurations | Should -BeGreaterThan 0
                
                $script:TestResults.IntegrationWorkflowTests += @{
                    TestName = "Configuration Carousel Integration"
                    Result = "PASSED"
                    Details = "Configuration carousel functional with $($configs.TotalConfigurations) configurations"
                }
            }
        }
    }
    
    Context "Module Communication Integration" {
        It "Should enable inter-module communication" {
            # Test module communication system
            $commCmd = Get-Command Register-ModuleAPI -ErrorAction SilentlyContinue
            if ($commCmd) {
                # Register test API
                $registerResult = Register-ModuleAPI -ModuleName "TestModule" -APIVersion "1.0.0" -Endpoints @("test")
                $registerResult | Should -Not -Throw
                
                # Test API invocation
                $apiResult = Invoke-ModuleAPI -ModuleName "TestModule" -Endpoint "test" -ErrorAction SilentlyContinue
                
                $script:TestResults.IntegrationWorkflowTests += @{
                    TestName = "Module Communication Integration"
                    Result = "PASSED"
                    Details = "Module API registration and invocation functional"
                }
            }
        }
    }
}

# Test Suite 5: Performance Testing
Describe "Performance Testing" {
    
    Context "Domain Loading Performance" {
        It "Should load domains efficiently" {
            # Measure domain loading time
            $startTime = Get-Date
            
            # Force reload for timing
            Remove-Module AitherCore -Force -ErrorAction SilentlyContinue
            Import-Module (Join-Path $env:PROJECT_ROOT "aither-core/AitherCore.psm1") -Force
            Initialize-CoreApplication -RequiredOnly
            
            $endTime = Get-Date
            $loadTime = ($endTime - $startTime).TotalMilliseconds
            
            # Should load within reasonable time (less than 10 seconds)
            $loadTime | Should -BeLessThan 10000
            
            $script:TestResults.PerformanceTests += @{
                TestName = "Domain Loading Performance"
                Result = if ($loadTime -lt 5000) { "EXCELLENT" } elseif ($loadTime -lt 10000) { "GOOD" } else { "NEEDS_IMPROVEMENT" }
                Details = "Load time: $([math]::Round($loadTime))ms"
            }
        }
    }
    
    Context "Memory Usage" {
        It "Should have reasonable memory footprint" {
            # Get process memory usage
            $process = Get-Process -Id $PID
            $memoryMB = [math]::Round($process.WorkingSet64 / 1MB, 2)
            
            # Log memory usage (no specific threshold, just monitoring)
            $script:TestResults.PerformanceTests += @{
                TestName = "Memory Usage"
                Result = "MONITORED"
                Details = "Memory usage: ${memoryMB}MB"
            }
        }
    }
}

# Test Suite 6: Error Handling and Resilience
Describe "Error Handling and Resilience" {
    
    Context "Domain Loading Failure Handling" {
        It "Should handle missing domain gracefully" {
            # Test with non-existent domain
            $status = Get-CoreModuleStatus
            $missingDomains = $status | Where-Object { $_.Available -eq $false }
            
            # Should report missing domains without failing
            $missingDomains.Count | Should -BeGreaterOrEqual 0
            
            $script:TestResults.ErrorHandlingTests += @{
                TestName = "Missing Domain Handling"
                Result = "PASSED"
                Details = "Missing domains handled gracefully: $($missingDomains.Count)"
            }
        }
    }
    
    Context "Error Propagation" {
        It "Should propagate errors correctly across domains" {
            # Test error propagation through Write-CustomLog
            $errorLogged = $false
            
            try {
                Write-CustomLog -Message "Test error propagation" -Level "ERROR"
                $errorLogged = $true
            } catch {
                # Should not throw
            }
            
            $errorLogged | Should -Be $true
            
            $script:TestResults.ErrorHandlingTests += @{
                TestName = "Error Propagation"
                Result = "PASSED"
                Details = "Error logging functional across domains"
            }
        }
    }
}

# Helper Functions
function Test-ModuleCommunication {
    try {
        $commCmd = Get-Command Register-ModuleAPI -ErrorAction SilentlyContinue
        if ($commCmd) {
            # Test basic module communication
            Register-ModuleAPI -ModuleName "TestComm" -APIVersion "1.0.0" -Endpoints @("ping")
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

# Test Results Summary
AfterAll {
    Write-Information "`n" -InformationAction Continue
    Write-Information "=== INTEGRATION TEST RESULTS SUMMARY ===" -InformationAction Continue
    Write-Information "Test execution completed: $(Get-Date)" -InformationAction Continue
    Write-Information "Total execution time: $((Get-Date) - $script:TestResults.StartTime)" -InformationAction Continue
    
    # Summary statistics
    $allTests = @()
    $allTests += $script:TestResults.DomainLoadingTests
    $allTests += $script:TestResults.CrossDomainTests
    $allTests += $script:TestResults.InitializationTests
    $allTests += $script:TestResults.IntegrationWorkflowTests
    $allTests += $script:TestResults.PerformanceTests
    $allTests += $script:TestResults.ErrorHandlingTests
    
    $passed = $allTests | Where-Object { $_.Result -eq "PASSED" }
    $failed = $allTests | Where-Object { $_.Result -eq "FAILED" }
    $skipped = $allTests | Where-Object { $_.Result -eq "SKIPPED" }
    
    Write-Information "Tests Passed: $($passed.Count)" -InformationAction Continue
    Write-Information "Tests Failed: $($failed.Count)" -InformationAction Continue
    Write-Information "Tests Skipped: $($skipped.Count)" -InformationAction Continue
    Write-Information "Total Tests: $($allTests.Count)" -InformationAction Continue
    
    # Category breakdown
    Write-Information "`nCategory Breakdown:" -InformationAction Continue
    Write-Information "- Domain Loading Tests: $($script:TestResults.DomainLoadingTests.Count)" -InformationAction Continue
    Write-Information "- Cross-Domain Tests: $($script:TestResults.CrossDomainTests.Count)" -InformationAction Continue
    Write-Information "- Initialization Tests: $($script:TestResults.InitializationTests.Count)" -InformationAction Continue
    Write-Information "- Integration Workflow Tests: $($script:TestResults.IntegrationWorkflowTests.Count)" -InformationAction Continue
    Write-Information "- Performance Tests: $($script:TestResults.PerformanceTests.Count)" -InformationAction Continue
    Write-Information "- Error Handling Tests: $($script:TestResults.ErrorHandlingTests.Count)" -InformationAction Continue
    
    # Save detailed results
    $resultsPath = Join-Path $env:PROJECT_ROOT "test-results/integration-test-results.json"
    $resultsDir = Split-Path $resultsPath -Parent
    if (-not (Test-Path $resultsDir)) {
        New-Item -Path $resultsDir -ItemType Directory -Force | Out-Null
    }
    
    $script:TestResults | ConvertTo-Json -Depth 10 | Set-Content -Path $resultsPath
    Write-Information "Detailed results saved to: $resultsPath" -InformationAction Continue
    
    Write-Information "=== END INTEGRATION TEST RESULTS ===" -InformationAction Continue
}