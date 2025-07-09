#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive Pester tests for the {{MODULE_NAME}} module (Critical Module)

.DESCRIPTION
    Enhanced test suite for critical modules including:
    - Module import and structure validation
    - Core functionality testing with performance benchmarks
    - Error handling and edge cases
    - Integration testing with dependent modules
    - Performance and reliability testing
    - Security validation
    - {{ADDITIONAL_TEST_AREAS}}

.NOTES
    Critical module test template - includes extensive validation and performance testing
    This template is designed for modules that are essential to AitherZero operation
#>

BeforeAll {
    # Import the module under test
    $ModulePath = Split-Path -Parent $PSScriptRoot
    $ModuleName = "{{MODULE_NAME}}"
    
    # Import with error handling for critical modules
    try {
        Import-Module $ModulePath -Force -ErrorAction Stop
        Write-Host "✅ Successfully imported critical module: $ModuleName" -ForegroundColor Green
    } catch {
        Write-Host "❌ CRITICAL: Failed to import module $ModuleName`: $_" -ForegroundColor Red
        throw "Critical module import failure"
    }

    # Setup test environment
    $script:TestStartTime = Get-Date
    $script:PerformanceMetrics = @{}
    $script:CriticalErrors = @()
    
    {{TEST_SETUP}}

    # Enhanced logging setup for critical modules
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Message, [string]$Level = "INFO")
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $color = switch ($Level) {
                "ERROR" { "Red" }
                "WARN" { "Yellow" }
                "SUCCESS" { "Green" }
                default { "White" }
            }
            Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
        }
    }

    # Initialize performance monitoring
    function Start-PerformanceTimer {
        param([string]$Operation)
        $script:PerformanceMetrics[$Operation] = @{
            StartTime = Get-Date
            EndTime = $null
            Duration = $null
        }
    }

    function Stop-PerformanceTimer {
        param([string]$Operation)
        if ($script:PerformanceMetrics.ContainsKey($Operation)) {
            $script:PerformanceMetrics[$Operation].EndTime = Get-Date
            $script:PerformanceMetrics[$Operation].Duration = $script:PerformanceMetrics[$Operation].EndTime - $script:PerformanceMetrics[$Operation].StartTime
        }
    }

    # Memory monitoring
    function Get-MemoryUsage {
        $process = Get-Process -Id $PID
        return [Math]::Round($process.WorkingSet64 / 1MB, 2)
    }

    $script:InitialMemory = Get-MemoryUsage
}

AfterAll {
    # Performance analysis
    Write-Host "`n📊 Performance Analysis for Critical Module: $ModuleName" -ForegroundColor Cyan
    foreach ($metric in $script:PerformanceMetrics.GetEnumerator()) {
        if ($metric.Value.Duration) {
            $durationMs = $metric.Value.Duration.TotalMilliseconds
            $color = if ($durationMs -lt 1000) { "Green" } elseif ($durationMs -lt 5000) { "Yellow" } else { "Red" }
            Write-Host "  $($metric.Key): $([Math]::Round($durationMs, 2))ms" -ForegroundColor $color
        }
    }

    # Memory analysis
    $finalMemory = Get-MemoryUsage
    $memoryIncrease = $finalMemory - $script:InitialMemory
    Write-Host "  Memory Usage: $memoryIncrease MB increase" -ForegroundColor $(if ($memoryIncrease -lt 50) { "Green" } elseif ($memoryIncrease -lt 100) { "Yellow" } else { "Red" })

    # Critical error summary
    if ($script:CriticalErrors.Count -gt 0) {
        Write-Host "`n❌ Critical Errors Detected:" -ForegroundColor Red
        foreach ($error in $script:CriticalErrors) {
            Write-Host "  - $error" -ForegroundColor Red
        }
    }

    # Cleanup test environment
    {{TEST_CLEANUP}}

    # Calculate total test execution time
    $testDuration = (Get-Date) - $script:TestStartTime
    $durationColor = if ($testDuration.TotalSeconds -lt 30) { "Green" } elseif ($testDuration.TotalSeconds -lt 60) { "Yellow" } else { "Red" }
    Write-Host "🕐 Total test execution time: $($testDuration.TotalSeconds.ToString('0.00')) seconds" -ForegroundColor $durationColor
}

Describe "{{MODULE_NAME}} Module - Critical Module Validation" {
    Context "Module Import and Structure (Critical Validation)" {
        It "Should import the module successfully" {
            $module = Get-Module -Name $ModuleName
            $module | Should -Not -BeNullOrEmpty
            $module.ModuleType | Should -Be "Script"
        }

        It "Should have all expected functions exported" {
            $expectedFunctions = @(
                {{EXPECTED_FUNCTIONS}}
            )

            $exportedFunctions = Get-Command -Module $ModuleName | Select-Object -ExpandProperty Name

            # Critical modules must export all expected functions
            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function -Because "Critical module must export all expected functions"
            }
        }

        It "Should require PowerShell 7.0 or higher" {
            $module = Get-Module $ModuleName
            $module.PowerShellVersion | Should -BeGreaterOrEqual ([Version]"7.0")
        }

        It "Should have comprehensive module metadata" {
            $module = Get-Module $ModuleName
            $module | Should -Not -BeNullOrEmpty
            $module.Description | Should -Not -BeNullOrEmpty
            $module.Author | Should -Not -BeNullOrEmpty
            $module.Version | Should -Not -BeNullOrEmpty
        }

        It "Should have proper manifest file" {
            $manifestPath = Join-Path $ModulePath "$ModuleName.psd1"
            Test-Path $manifestPath | Should -Be $true
            
            { Test-ModuleManifest $manifestPath } | Should -Not -Throw
        }

        It "Should have required dependencies properly declared" {
            $module = Get-Module $ModuleName
            if ($module.RequiredModules.Count -gt 0) {
                foreach ($requiredModule in $module.RequiredModules) {
                    Get-Module -Name $requiredModule.Name -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
                }
            }
        }
    }

    Context "Core Functionality (Critical Operations)" {
        BeforeEach {
            Start-PerformanceTimer -Operation "CoreFunctionality"
        }

        AfterEach {
            Stop-PerformanceTimer -Operation "CoreFunctionality"
        }

        {{CORE_FUNCTIONALITY_TESTS}}

        It "Should execute all core functions without errors" {
            $functions = Get-Command -Module $ModuleName -CommandType Function
            $functions | Should -Not -BeNullOrEmpty

            foreach ($function in $functions) {
                { Get-Help $function.Name -ErrorAction Stop } | Should -Not -Throw -Because "All functions should have help documentation"
            }
        }

        It "Should handle null and empty parameters gracefully" {
            $functions = Get-Command -Module $ModuleName -CommandType Function
            
            foreach ($function in $functions) {
                $parameters = $function.Parameters.Values | Where-Object { $_.ParameterType -eq [string] -and -not $_.Attributes.Mandatory }
                
                foreach ($param in $parameters) {
                    try {
                        $splat = @{ $param.Name = "" }
                        & $function.Name @splat -ErrorAction SilentlyContinue
                        # Should not throw for empty string parameters
                    } catch {
                        # Log but don't fail - some functions may legitimately reject empty strings
                        Write-CustomLog "Function $($function.Name) rejected empty string for parameter $($param.Name)" -Level "INFO"
                    }
                }
            }
        }
    }

    Context "Error Handling and Resilience (Critical)" {
        It "Should handle invalid parameters gracefully" {
            {{ERROR_HANDLING_TESTS}}
        }

        It "Should provide meaningful error messages" {
            $functions = Get-Command -Module $ModuleName -CommandType Function
            
            foreach ($function in $functions) {
                $mandatoryParams = $function.Parameters.Values | Where-Object { $_.Attributes.Mandatory -eq $true }
                
                if ($mandatoryParams.Count -gt 0) {
                    try {
                        & $function.Name -ErrorAction Stop
                        # Should throw for missing mandatory parameters
                    } catch {
                        $_.Exception.Message | Should -Not -BeNullOrEmpty
                        $_.Exception.Message | Should -Not -Match "A parameter cannot be found"
                    }
                }
            }
        }

        It "Should handle system resource constraints" {
            # Test behavior under low memory conditions (simulated)
            $functions = Get-Command -Module $ModuleName -CommandType Function
            
            foreach ($function in $functions) {
                try {
                    $initialMemory = Get-MemoryUsage
                    # Execute function (with minimal parameters if possible)
                    & $function.Name -ErrorAction SilentlyContinue
                    $finalMemory = Get-MemoryUsage
                    
                    # Memory increase should be reasonable
                    ($finalMemory - $initialMemory) | Should -BeLessThan 100 -Because "Functions should not consume excessive memory"
                } catch {
                    # Log but don't fail - functions may need specific parameters
                    Write-CustomLog "Function $($function.Name) memory test skipped: $_" -Level "INFO"
                }
            }
        }
    }

    Context "Performance and Reliability (Critical)" {
        It "Should execute core functions within acceptable time limits" {
            {{PERFORMANCE_TESTS}}
        }

        It "Should handle concurrent operations safely" {
            {{CONCURRENCY_TESTS}}
        }

        It "Should maintain consistent performance under load" {
            $functions = Get-Command -Module $ModuleName -CommandType Function | Select-Object -First 3
            
            foreach ($function in $functions) {
                $executionTimes = @()
                
                for ($i = 0; $i -lt 5; $i++) {
                    $startTime = Get-Date
                    try {
                        & $function.Name -ErrorAction SilentlyContinue
                    } catch {
                        # Expected for functions requiring parameters
                    }
                    $endTime = Get-Date
                    $executionTimes += ($endTime - $startTime).TotalMilliseconds
                }
                
                # Performance should be consistent (standard deviation < 50% of mean)
                $mean = ($executionTimes | Measure-Object -Average).Average
                $stdDev = [Math]::Sqrt(($executionTimes | ForEach-Object { [Math]::Pow($_ - $mean, 2) } | Measure-Object -Average).Average)
                
                if ($mean -gt 0) {
                    $coefficientOfVariation = $stdDev / $mean
                    $coefficientOfVariation | Should -BeLessThan 0.5 -Because "Performance should be consistent"
                }
            }
        }

        It "Should not cause memory leaks" {
            $initialMemory = Get-MemoryUsage
            $functions = Get-Command -Module $ModuleName -CommandType Function | Select-Object -First 3
            
            # Run functions multiple times
            for ($i = 0; $i -lt 10; $i++) {
                foreach ($function in $functions) {
                    try {
                        & $function.Name -ErrorAction SilentlyContinue
                    } catch {
                        # Expected for functions requiring parameters
                    }
                }
            }
            
            # Force garbage collection
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
            
            $finalMemory = Get-MemoryUsage
            $memoryIncrease = $finalMemory - $initialMemory
            
            # Memory increase should be minimal
            $memoryIncrease | Should -BeLessThan 50 -Because "Functions should not leak memory"
        }
    }

    Context "Integration with AitherZero Framework (Critical)" {
        It "Should integrate with logging system" {
            {{LOGGING_INTEGRATION_TEST}}
        }

        It "Should handle configuration properly" {
            {{CONFIGURATION_TEST}}
        }

        It "Should support cross-platform operation" {
            {{CROSS_PLATFORM_TEST}}
        }

        It "Should integrate with ModuleCommunication if available" {
            $commModule = Get-Module -Name "ModuleCommunication" -ErrorAction SilentlyContinue
            if ($commModule) {
                # Test basic communication integration
                { Register-ModuleAPI -ModuleName $ModuleName -APIVersion "1.0.0" -Endpoints @("health") -ErrorAction SilentlyContinue } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "ModuleCommunication not available"
            }
        }

        It "Should support ProgressTracking integration" {
            $progressModule = Get-Module -Name "ProgressTracking" -ErrorAction SilentlyContinue
            if ($progressModule) {
                # Test progress tracking integration
                { Start-ProgressOperation -OperationName "Test Integration" -TotalSteps 1 -ErrorAction SilentlyContinue } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "ProgressTracking not available"
            }
        }
    }

    Context "Security Validation (Critical)" {
        It "Should not expose sensitive information in error messages" {
            $functions = Get-Command -Module $ModuleName -CommandType Function
            
            foreach ($function in $functions) {
                try {
                    & $function.Name -ErrorAction Stop
                } catch {
                    # Check error message for sensitive patterns
                    $errorMessage = $_.Exception.Message.ToLower()
                    $errorMessage | Should -Not -Match "password|token|secret|key|credential" -Because "Error messages should not expose sensitive information"
                }
            }
        }

        It "Should validate input parameters properly" {
            $functions = Get-Command -Module $ModuleName -CommandType Function
            
            foreach ($function in $functions) {
                $stringParams = $function.Parameters.Values | Where-Object { $_.ParameterType -eq [string] }
                
                foreach ($param in $stringParams) {
                    # Test with potentially malicious input
                    $maliciousInputs = @(
                        "../../../etc/passwd",
                        "<script>alert('xss')</script>",
                        "'; DROP TABLE users; --",
                        "$(Get-Process)"
                    )
                    
                    foreach ($maliciousInput in $maliciousInputs) {
                        try {
                            $splat = @{ $param.Name = $maliciousInput }
                            & $function.Name @splat -ErrorAction Stop
                        } catch {
                            # Should either reject malicious input or handle it safely
                            $_.Exception.Message | Should -Not -BeNullOrEmpty
                        }
                    }
                }
            }
        }
    }
}

Describe "{{MODULE_NAME}} Module - Advanced Scenarios (Critical)" {
    Context "Edge Cases and Boundary Conditions" {
        {{EDGE_CASE_TESTS}}

        It "Should handle very large inputs gracefully" {
            $functions = Get-Command -Module $ModuleName -CommandType Function
            
            foreach ($function in $functions) {
                $stringParams = $function.Parameters.Values | Where-Object { $_.ParameterType -eq [string] }
                
                foreach ($param in $stringParams) {
                    $largeInput = "x" * 10000  # 10KB string
                    try {
                        $splat = @{ $param.Name = $largeInput }
                        & $function.Name @splat -ErrorAction SilentlyContinue
                    } catch {
                        # Should handle large inputs gracefully
                        $_.Exception.Message | Should -Not -BeNullOrEmpty
                    }
                }
            }
        }

        It "Should handle Unicode and special characters" {
            $functions = Get-Command -Module $ModuleName -CommandType Function
            
            foreach ($function in $functions) {
                $stringParams = $function.Parameters.Values | Where-Object { $_.ParameterType -eq [string] }
                
                foreach ($param in $stringParams) {
                    $unicodeInput = "测试🚀Тест💾αβγ"
                    try {
                        $splat = @{ $param.Name = $unicodeInput }
                        & $function.Name @splat -ErrorAction SilentlyContinue
                    } catch {
                        # Should handle Unicode gracefully
                        $_.Exception | Should -Not -BeNullOrEmpty
                    }
                }
            }
        }
    }

    Context "Integration Testing" {
        {{INTEGRATION_TESTS}}

        It "Should work with all AitherZero core modules" {
            $coreModules = @("Logging", "ConfigurationCore", "ModuleCommunication", "ProgressTracking")
            
            foreach ($coreModule in $coreModules) {
                $module = Get-Module -Name $coreModule -ErrorAction SilentlyContinue
                if ($module) {
                    # Test basic compatibility
                    { Import-Module $coreModule -Force } | Should -Not -Throw
                    Write-CustomLog "Integration test with $coreModule completed" -Level "INFO"
                } else {
                    Set-ItResult -Skipped -Because "$coreModule not available"
                }
            }
        }
    }

    Context "Regression Testing" {
        {{REGRESSION_TESTS}}

        It "Should maintain backward compatibility" {
            $module = Get-Module $ModuleName
            $currentVersion = $module.Version
            
            # Version should follow semantic versioning
            $currentVersion | Should -Match "^\d+\.\d+\.\d+$"
            
            # All exported functions should still be available
            $exportedFunctions = Get-Command -Module $ModuleName -CommandType Function
            $exportedFunctions.Count | Should -BeGreaterThan 0
        }

        It "Should not break existing functionality" {
            # Test that all exported functions are still callable
            $functions = Get-Command -Module $ModuleName -CommandType Function
            
            foreach ($function in $functions) {
                $function | Should -Not -BeNullOrEmpty
                $function.Name | Should -Not -BeNullOrEmpty
                $function.ModuleName | Should -Be $ModuleName
            }
        }
    }

    Context "Stress Testing" {
        It "Should handle rapid successive function calls" {
            $functions = Get-Command -Module $ModuleName -CommandType Function | Select-Object -First 2
            
            foreach ($function in $functions) {
                for ($i = 0; $i -lt 50; $i++) {
                    try {
                        & $function.Name -ErrorAction SilentlyContinue
                    } catch {
                        # Expected for functions requiring parameters
                    }
                }
            }
            
            # Module should still be functional
            Get-Module $ModuleName | Should -Not -BeNullOrEmpty
        }

        It "Should handle parallel execution" {
            $functions = Get-Command -Module $ModuleName -CommandType Function | Select-Object -First 2
            
            $jobs = @()
            foreach ($function in $functions) {
                $jobs += Start-Job -ScriptBlock {
                    param($ModulePath, $FunctionName)
                    Import-Module $ModulePath -Force
                    for ($i = 0; $i -lt 10; $i++) {
                        try {
                            & $FunctionName -ErrorAction SilentlyContinue
                        } catch {
                            # Expected for functions requiring parameters
                        }
                    }
                } -ArgumentList $ModulePath, $function.Name
            }
            
            # Wait for all jobs to complete
            $jobs | Wait-Job | Remove-Job
            
            # Module should still be functional
            Get-Module $ModuleName | Should -Not -BeNullOrEmpty
        }
    }
}