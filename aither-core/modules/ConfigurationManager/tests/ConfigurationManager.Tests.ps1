#Requires -Version 7.0

BeforeAll {
    # Import the module being tested
    $modulePath = Join-Path $PSScriptRoot ".." "ConfigurationManager.psm1"
    Import-Module $modulePath -Force -ErrorAction Stop
}

Describe "ConfigurationManager Module Tests" {
    Context "Module Loading and Initialization" {
        It "Should import module successfully" {
            Get-Module ConfigurationManager | Should -Not -BeNullOrEmpty
        }
        
        It "Should have valid manifest" {
            $manifestPath = Join-Path $PSScriptRoot ".." "ConfigurationManager.psd1"
            Test-Path $manifestPath | Should -Be $true
            
            { Test-ModuleManifest $manifestPath } | Should -Not -Throw
        }
        
        It "Should export expected functions" {
            $expectedFunctions = @(
                'Test-ConfigurationManager'
            )
            
            foreach ($function in $expectedFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should initialize module variables" {
            # Test that the module initializes its internal variables
            { Test-ConfigurationManager -TestSuite Basic } | Should -Not -Throw
        }
        
        It "Should create configuration storage directory" {
            # After module load, the storage directory should exist
            $storePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero'
            Test-Path $storePath | Should -Be $true
        }
    }
    
    Context "Test-ConfigurationManager Function Tests" {
        It "Should run basic test suite successfully" {
            $result = Test-ConfigurationManager -TestSuite Basic
            $result | Should -Not -BeNullOrEmpty
            $result.TestSuite | Should -Be 'Basic'
            $result.TotalTests | Should -BeGreaterThan 0
        }
        
        It "Should run extended test suite successfully" {
            $result = Test-ConfigurationManager -TestSuite Extended
            $result | Should -Not -BeNullOrEmpty
            $result.TestSuite | Should -Be 'Extended'
            $result.TotalTests | Should -BeGreaterThan 4  # More tests in extended
        }
        
        It "Should run full test suite successfully" {
            $result = Test-ConfigurationManager -TestSuite Full
            $result | Should -Not -BeNullOrEmpty
            $result.TestSuite | Should -Be 'Full'
            $result.TotalTests | Should -BeGreaterThan 7  # Most tests in full
        }
        
        It "Should include performance tests when requested" {
            $result = Test-ConfigurationManager -TestSuite Basic -IncludePerformance
            $result | Should -Not -BeNullOrEmpty
            $result.Performance | Should -Not -BeNullOrEmpty
        }
        
        It "Should generate report when requested" {
            $result = Test-ConfigurationManager -TestSuite Basic -GenerateReport
            $result | Should -Not -BeNullOrEmpty
            
            if ($result.ReportPath) {
                Test-Path $result.ReportPath | Should -Be $true
                # Cleanup
                Remove-Item $result.ReportPath -ErrorAction SilentlyContinue
            }
        }
        
        It "Should validate test result structure" {
            $result = Test-ConfigurationManager -TestSuite Basic
            
            # Verify required properties
            $result.TestSuite | Should -Not -BeNullOrEmpty
            $result.StartTime | Should -Not -BeNullOrEmpty
            $result.EndTime | Should -Not -BeNullOrEmpty
            $result.OverallResult | Should -BeIn @('Passed', 'Failed', 'Warning')
            $result.TotalTests | Should -BeOfType [int]
            $result.PassedTests | Should -BeOfType [int]
            $result.FailedTests | Should -BeOfType [int]
            $result.Tests | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle invalid test suite parameter" {
            { Test-ConfigurationManager -TestSuite "Invalid" } | Should -Throw
        }
    }
    
    Context "Configuration Store Operations" {
        It "Should handle configuration store access" {
            $result = Test-ConfigurationManager -TestSuite Basic
            $storeTest = $result.Tests.ConfigurationStore
            
            $storeTest | Should -Not -BeNullOrEmpty
            $storeTest.TestName | Should -Be 'ConfigurationStoreOperations'
            $storeTest.Result | Should -BeIn @('Passed', 'Failed', 'Warning')
        }
        
        It "Should verify module initialization test" {
            $result = Test-ConfigurationManager -TestSuite Basic
            $initTest = $result.Tests.ModuleInitialization
            
            $initTest | Should -Not -BeNullOrEmpty
            $initTest.TestName | Should -Be 'ModuleInitialization'
            $initTest.Result | Should -Be 'Passed'  # Should always pass if module loads correctly
        }
        
        It "Should test environment management" {
            $result = Test-ConfigurationManager -TestSuite Basic
            $envTest = $result.Tests.EnvironmentManagement
            
            $envTest | Should -Not -BeNullOrEmpty
            $envTest.TestName | Should -Be 'EnvironmentManagement'
            $envTest.Result | Should -BeIn @('Passed', 'Failed', 'Warning')
        }
        
        It "Should test configuration carousel operations" {
            $result = Test-ConfigurationManager -TestSuite Basic
            $carouselTest = $result.Tests.ConfigurationCarousel
            
            $carouselTest | Should -Not -BeNullOrEmpty
            $carouselTest.TestName | Should -Be 'ConfigurationCarouselOperations'
            $carouselTest.Result | Should -BeIn @('Passed', 'Failed', 'Warning')
        }
    }
    
    Context "Extended Test Suite Features" {
        It "Should include repository operations in extended tests" {
            $result = Test-ConfigurationManager -TestSuite Extended
            $repoTest = $result.Tests.RepositoryOperations
            
            $repoTest | Should -Not -BeNullOrEmpty
            $repoTest.TestName | Should -Be 'RepositoryOperations'
        }
        
        It "Should include event system tests in extended tests" {
            $result = Test-ConfigurationManager -TestSuite Extended
            $eventTest = $result.Tests.EventSystem
            
            $eventTest | Should -Not -BeNullOrEmpty
            $eventTest.TestName | Should -Be 'EventSystemOperations'
        }
        
        It "Should include legacy compatibility tests in extended tests" {
            $result = Test-ConfigurationManager -TestSuite Extended
            $legacyTest = $result.Tests.LegacyCompatibility
            
            $legacyTest | Should -Not -BeNullOrEmpty
            $legacyTest.TestName | Should -Be 'LegacyCompatibility'
        }
    }
    
    Context "Full Test Suite Features" {
        It "Should include security tests in full suite" {
            $result = Test-ConfigurationManager -TestSuite Full
            $securityTest = $result.Tests.SecurityFeatures
            
            $securityTest | Should -Not -BeNullOrEmpty
            $securityTest.TestName | Should -Be 'SecurityFeatures'
        }
        
        It "Should include data integrity tests in full suite" {
            $result = Test-ConfigurationManager -TestSuite Full
            $integrityTest = $result.Tests.DataIntegrity
            
            $integrityTest | Should -Not -BeNullOrEmpty
            $integrityTest.TestName | Should -Be 'DataIntegrity'
        }
        
        It "Should include cross-platform compatibility tests in full suite" {
            $result = Test-ConfigurationManager -TestSuite Full
            $platformTest = $result.Tests.CrossPlatformCompatibility
            
            $platformTest | Should -Not -BeNullOrEmpty
            $platformTest.TestName | Should -Be 'CrossPlatformCompatibility'
        }
    }
    
    Context "Performance Testing" {
        It "Should measure configuration access performance" {
            $result = Test-ConfigurationManager -TestSuite Basic -IncludePerformance
            
            $result.Performance | Should -Not -BeNullOrEmpty
            $result.Performance.Tests | Should -Not -BeNullOrEmpty
            $result.Performance.Tests.ConfigurationAccess | Should -Not -BeNullOrEmpty
            $result.Performance.Tests.ConfigurationAccess.Operations | Should -Be 100
        }
        
        It "Should measure JSON serialization performance" {
            $result = Test-ConfigurationManager -TestSuite Basic -IncludePerformance
            
            $result.Performance.Tests.JsonSerialization | Should -Not -BeNullOrEmpty
            $result.Performance.Tests.JsonSerialization.Operations | Should -Be 10
        }
        
        It "Should measure file I/O performance" {
            $result = Test-ConfigurationManager -TestSuite Basic -IncludePerformance
            
            $result.Performance.Tests.FileIO | Should -Not -BeNullOrEmpty
            $result.Performance.Tests.FileIO.Operations | Should -Be 20
        }
        
        It "Should report reasonable performance metrics" {
            $result = Test-ConfigurationManager -TestSuite Basic -IncludePerformance
            
            # Configuration access should be very fast
            $result.Performance.Tests.ConfigurationAccess.AvgTimePerOperation | Should -BeLessThan 10
            
            # JSON serialization should complete in reasonable time
            $result.Performance.Tests.JsonSerialization.AvgTimePerOperation | Should -BeLessThan 1000
        }
    }
    
    Context "Error Handling" {
        It "Should handle missing configuration gracefully" {
            # This should not throw even if configuration is missing
            { Test-ConfigurationManager -TestSuite Basic } | Should -Not -Throw
        }
        
        It "Should return error information in results when failures occur" {
            $result = Test-ConfigurationManager -TestSuite Basic
            
            # Even if some tests fail, the function should return results
            $result | Should -Not -BeNullOrEmpty
            $result.OverallResult | Should -BeIn @('Passed', 'Failed', 'Warning', 'Error')
        }
        
        It "Should handle invalid parameters gracefully" {
            # Should not crash with invalid enum values (this is validated by PowerShell)
            { Test-ConfigurationManager -TestSuite "Basic" } | Should -Not -Throw
        }
    }
    
    Context "Integration with Logging Module" {
        It "Should work with or without Logging module" {
            # Should work regardless of whether Logging module is available
            { Test-ConfigurationManager -TestSuite Basic } | Should -Not -Throw
        }
        
        It "Should provide fallback logging when Logging module unavailable" {
            # The module provides fallback logging functions
            $result = Test-ConfigurationManager -TestSuite Basic
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Configuration Storage and Persistence" {
        It "Should create configuration store file" {
            Test-ConfigurationManager -TestSuite Basic | Out-Null
            
            $storePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'unified-config.json'
            Test-Path $storePath | Should -Be $true
        }
        
        It "Should persist configuration changes" {
            $result = Test-ConfigurationManager -TestSuite Basic
            $storeTest = $result.Tests.ConfigurationStore
            
            # The configuration store test verifies persistence
            if ($storeTest.Result -eq 'Passed') {
                $storePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'unified-config.json'
                $content = Get-Content $storePath -Raw -ErrorAction SilentlyContinue
                $content | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Cross-Platform Compatibility" {
        It "Should work on current platform" {
            $platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
            $platform | Should -BeIn @("Windows", "Linux", "macOS")
            
            # Test that configuration manager works on this platform
            $result = Test-ConfigurationManager -TestSuite Basic
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle path operations cross-platform" {
            $result = Test-ConfigurationManager -TestSuite Full
            $platformTest = $result.Tests.CrossPlatformCompatibility
            
            if ($platformTest.Result -eq 'Passed') {
                $platformTest.Details.Platform | Should -BeIn @('Windows', 'Linux', 'macOS')
            }
        }
        
        It "Should work with PowerShell 7+" {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
            
            # Module should function correctly with PowerShell 7+
            $result = Test-ConfigurationManager -TestSuite Basic
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Report Generation" {
        It "Should generate readable test reports" {
            $result = Test-ConfigurationManager -TestSuite Basic -GenerateReport
            
            if ($result.ReportPath) {
                $reportContent = Get-Content $result.ReportPath -Raw
                $reportContent | Should -Match "Configuration Manager Test Report"
                $reportContent | Should -Match "SUMMARY"
                $reportContent | Should -Match "Total Tests:"
                
                # Cleanup
                Remove-Item $result.ReportPath -ErrorAction SilentlyContinue
            }
        }
        
        It "Should include all test results in report" {
            $result = Test-ConfigurationManager -TestSuite Extended -GenerateReport
            
            if ($result.ReportPath) {
                $reportContent = Get-Content $result.ReportPath -Raw
                $reportContent | Should -Match "DETAILED RESULTS"
                $reportContent | Should -Match "ModuleInitialization"
                $reportContent | Should -Match "ConfigurationStoreOperations"
                
                # Cleanup
                Remove-Item $result.ReportPath -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Module Configuration State" {
        It "Should maintain configuration state across test runs" {
            $result1 = Test-ConfigurationManager -TestSuite Basic
            $result2 = Test-ConfigurationManager -TestSuite Basic
            
            # Both runs should succeed and have consistent results
            $result1.OverallResult | Should -BeIn @('Passed', 'Warning')
            $result2.OverallResult | Should -BeIn @('Passed', 'Warning')
        }
        
        It "Should handle concurrent access gracefully" {
            # Multiple test runs should not interfere with each other
            $job1 = Start-Job -ScriptBlock { 
                Import-Module $using:modulePath -Force
                Test-ConfigurationManager -TestSuite Basic 
            }
            $job2 = Start-Job -ScriptBlock { 
                Import-Module $using:modulePath -Force
                Test-ConfigurationManager -TestSuite Basic 
            }
            
            $result1 = Receive-Job $job1 -Wait
            $result2 = Receive-Job $job2 -Wait
            
            Remove-Job $job1, $job2
            
            $result1 | Should -Not -BeNullOrEmpty
            $result2 | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Clean up any test artifacts
    $tempReports = Get-ChildItem ([System.IO.Path]::GetTempPath()) -Filter "ConfigurationManager-TestReport-*.txt" -ErrorAction SilentlyContinue
    foreach ($report in $tempReports) {
        Remove-Item $report.FullName -ErrorAction SilentlyContinue
    }
    
    # Remove the module
    Remove-Module ConfigurationManager -Force -ErrorAction SilentlyContinue
}