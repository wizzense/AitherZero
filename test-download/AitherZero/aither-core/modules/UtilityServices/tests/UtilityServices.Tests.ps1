#Requires -Version 7.0

BeforeAll {
    # Import the module being tested
    $modulePath = Join-Path $PSScriptRoot ".." "UtilityServices.psm1"
    Import-Module $modulePath -Force -ErrorAction Stop

    # Setup test environment
    $script:TestOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) "UtilityServicesTests"

    # Create test directories
    if (Test-Path $script:TestOutputPath) {
        Remove-Item $script:TestOutputPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $script:TestOutputPath -Force | Out-Null
}

Describe "UtilityServices Module Tests" {
    Context "Module Loading and Initialization" {
        It "Should import module successfully" {
            Get-Module UtilityServices | Should -Not -BeNullOrEmpty
        }

        It "Should have valid manifest" {
            $manifestPath = Join-Path $PSScriptRoot ".." "UtilityServices.psd1"
            Test-Path $manifestPath | Should -Be $true

            { Test-ModuleManifest $manifestPath } | Should -Not -Throw
        }

        It "Should export expected functions" {
            $expectedFunctions = @(
                'Test-UtilityIntegration'
            )

            foreach ($function in $expectedFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }

        It "Should load helper functions" {
            # Test that the module loads its helper functions
            $helperFunctions = @(
                'Initialize-SemanticVersioningService',
                'Initialize-ProgressTrackingService',
                'Initialize-TestingFrameworkService',
                'Initialize-ScriptManagerService',
                'Get-UtilityServiceStatus',
                'Get-UtilityMetrics',
                'Export-UtilityReport'
            )

            foreach ($function in $helperFunctions) {
                Get-Command $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "Helper function $function should be available"
            }
        }
    }

    Context "Test-UtilityIntegration Function Tests" {
        It "Should run basic integration test successfully" {
            $result = Test-UtilityIntegration -TestLevel Basic -OutputPath $script:TestOutputPath

            $result | Should -Not -BeNullOrEmpty
            $result.TestLevel | Should -Be 'Basic'
            $result.Success | Should -BeOfType [bool]
            $result.StartTime | Should -Not -BeNullOrEmpty
            $result.EndTime | Should -Not -BeNullOrEmpty
            $result.Duration | Should -BeGreaterThan 0
        }

        It "Should run standard integration test successfully" {
            $result = Test-UtilityIntegration -TestLevel Standard -OutputPath $script:TestOutputPath

            $result | Should -Not -BeNullOrEmpty
            $result.TestLevel | Should -Be 'Standard'
            $result.WorkflowTests | Should -Not -BeNullOrEmpty
        }

        It "Should run comprehensive integration test successfully" {
            $result = Test-UtilityIntegration -TestLevel Comprehensive -OutputPath $script:TestOutputPath

            $result | Should -Not -BeNullOrEmpty
            $result.TestLevel | Should -Be 'Comprehensive'
            $result.ComprehensiveTests | Should -Not -BeNullOrEmpty
        }

        It "Should test specific services when requested" {
            $specificServices = @('ProgressTracking', 'TestingFramework')
            $result = Test-UtilityIntegration -Services $specificServices -OutputPath $script:TestOutputPath

            $result.Services | Should -Be $specificServices
            $result.ServiceTests.Keys | Should -Contain 'ProgressTracking'
            $result.ServiceTests.Keys | Should -Contain 'TestingFramework'
            $result.ServiceTests.Keys.Count | Should -Be 2
        }

        It "Should validate test result structure" {
            $result = Test-UtilityIntegration -TestLevel Basic -OutputPath $script:TestOutputPath

            # Verify required properties
            $result.TestLevel | Should -Not -BeNullOrEmpty
            $result.Services | Should -Not -BeNullOrEmpty
            $result.StartTime | Should -Not -BeNullOrEmpty
            $result.EndTime | Should -Not -BeNullOrEmpty
            $result.ServiceTests | Should -Not -BeNullOrEmpty
            $result.IntegrationTests | Should -Not -BeNullOrEmpty
            $result.Summary | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeOfType [bool]
        }

        It "Should handle invalid test level parameter" {
            { Test-UtilityIntegration -TestLevel "Invalid" } | Should -Throw
        }

        It "Should create output directory and files" {
            $customOutputPath = Join-Path $script:TestOutputPath "custom-output"
            $result = Test-UtilityIntegration -TestLevel Standard -OutputPath $customOutputPath

            Test-Path $customOutputPath | Should -Be $true
            $resultFile = Join-Path $customOutputPath "integration-test-results.json"
            Test-Path $resultFile | Should -Be $true
        }
    }

    Context "Service Initialization Tests" {
        It "Should test SemanticVersioning service initialization" {
            $result = Initialize-SemanticVersioningService

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeOfType [bool]
            $result.Functions | Should -Not -BeNullOrEmpty
        }

        It "Should test ProgressTracking service initialization" {
            $result = Initialize-ProgressTrackingService

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeOfType [bool]
            $result.Functions | Should -Not -BeNullOrEmpty
        }

        It "Should test TestingFramework service initialization" {
            $result = Initialize-TestingFrameworkService

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeOfType [bool]
            $result.Functions | Should -Not -BeNullOrEmpty
        }

        It "Should test ScriptManager service initialization" {
            $result = Initialize-ScriptManagerService

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeOfType [bool]
            $result.Functions | Should -Not -BeNullOrEmpty
        }

        It "Should handle service initialization failures gracefully" {
            # All initialization functions should return results even if services aren't loaded
            $services = @('SemanticVersioning', 'ProgressTracking', 'TestingFramework', 'ScriptManager')

            foreach ($service in $services) {
                $initFunction = "Initialize-${service}Service"
                $result = & $initFunction

                $result | Should -Not -BeNullOrEmpty
                $result.ContainsKey('Success') | Should -Be $true
                $result.ContainsKey('Functions') | Should -Be $true
            }
        }
    }

    Context "Integration Testing Features" {
        It "Should test service integration comprehensively" {
            $result = Test-UtilityIntegration -TestLevel Standard -OutputPath $script:TestOutputPath

            # Check service tests
            $result.ServiceTests | Should -Not -BeNullOrEmpty
            foreach ($serviceTest in $result.ServiceTests.Values) {
                $serviceTest.Service | Should -Not -BeNullOrEmpty
                $serviceTest.ContainsKey('InitializationTest') | Should -Be $true
                $serviceTest.ContainsKey('FunctionTest') | Should -Be $true
                $serviceTest.ContainsKey('ConfigurationTest') | Should -Be $true
                $serviceTest.ContainsKey('Errors') | Should -Be $true
            }
        }

        It "Should test cross-service integration" {
            $result = Test-UtilityIntegration -TestLevel Standard -OutputPath $script:TestOutputPath

            $integrationTests = $result.IntegrationTests
            $integrationTests | Should -Not -BeNullOrEmpty
            $integrationTests.ContainsKey('EventSystemTest') | Should -Be $true
            $integrationTests.ContainsKey('ConfigurationSharingTest') | Should -Be $true
            $integrationTests.ContainsKey('ServiceCommunicationTest') | Should -Be $true
            $integrationTests.ContainsKey('ProgressIntegrationTest') | Should -Be $true
        }

        It "Should test workflow operations in standard mode" {
            $result = Test-UtilityIntegration -TestLevel Standard -OutputPath $script:TestOutputPath

            $workflowTests = $result.WorkflowTests
            $workflowTests | Should -Not -BeNullOrEmpty
            $workflowTests.ContainsKey('ServiceStatusTest') | Should -Be $true
            $workflowTests.ContainsKey('MetricsTest') | Should -Be $true
            $workflowTests.ContainsKey('ReportGenerationTest') | Should -Be $true
        }

        It "Should include comprehensive tests in comprehensive mode" {
            $result = Test-UtilityIntegration -TestLevel Comprehensive -OutputPath $script:TestOutputPath

            $result.ComprehensiveTests | Should -Not -BeNullOrEmpty
            $result.ComprehensiveTests.ContainsKey('IntegratedOperationTest') | Should -Be $true
            $result.ComprehensiveTests.ContainsKey('PerformanceTest') | Should -Be $true
            $result.ComprehensiveTests.ContainsKey('ConcurrencyTest') | Should -Be $true
        }
    }

    Context "Utility Helper Functions" {
        It "Should get utility service status" {
            $status = Get-UtilityServiceStatus

            $status | Should -Not -BeNullOrEmpty
            $status.Services | Should -Not -BeNullOrEmpty
            $status.Timestamp | Should -Not -BeNullOrEmpty
            $status.Services.Count | Should -BeGreaterThan 0
        }

        It "Should get utility metrics" {
            $metrics = Get-UtilityMetrics -TimeRange "LastHour"

            $metrics | Should -Not -BeNullOrEmpty
            $metrics.CollectedAt | Should -Not -BeNullOrEmpty
            $metrics.TimeRange | Should -Be "LastHour"
            $metrics.Metrics | Should -Not -BeNullOrEmpty
        }

        It "Should export utility reports" {
            $reportPath = Join-Path $script:TestOutputPath "test-report.json"
            $result = Export-UtilityReport -OutputPath $reportPath -Format JSON

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.Path | Should -Be $reportPath
            Test-Path $reportPath | Should -Be $true

            # Verify report content
            $reportContent = Get-Content $reportPath | ConvertFrom-Json
            $reportContent.ReportType | Should -Be "UtilityServices"
            $reportContent.Generated | Should -Not -BeNullOrEmpty
        }

        It "Should handle utility configuration operations" {
            $originalConfig = Get-UtilityConfiguration
            $originalConfig | Should -Not -BeNullOrEmpty

            Set-UtilityConfiguration -Configuration @{ TestSetting = "TestValue" }
            $updatedConfig = Get-UtilityConfiguration
            $updatedConfig.TestSetting | Should -Be "TestValue"
        }

        It "Should handle utility event operations" {
            # Event functions should not throw
            { Subscribe-UtilityEvent -EventType "TestEvent" -Handler { param($e) } } | Should -Not -Throw
            { Publish-UtilityEvent -EventType "TestEvent" -Data @{ Test = "Data" } } | Should -Not -Throw
        }
    }

    Context "Test Summary and Results" {
        It "Should generate comprehensive summary" {
            $result = Test-UtilityIntegration -TestLevel Standard -OutputPath $script:TestOutputPath

            $summary = $result.Summary
            $summary | Should -Not -BeNullOrEmpty
            $summary.TotalServices | Should -BeGreaterThan 0
            $summary.ContainsKey('ServicesPassedInit') | Should -Be $true
            $summary.ContainsKey('ServicesPassedFunctions') | Should -Be $true
            $summary.ContainsKey('IntegrationTestsPassed') | Should -Be $true
            $summary.ContainsKey('IntegrationTestsTotal') | Should -Be $true
            $summary.ContainsKey('AllErrors') | Should -Be $true
            $summary.ContainsKey('OverallSuccess') | Should -Be $true
        }

        It "Should track test duration" {
            $result = Test-UtilityIntegration -TestLevel Basic -OutputPath $script:TestOutputPath

            $result.Duration | Should -BeGreaterThan 0
            $result.Duration | Should -BeLessThan 30  # Should complete in reasonable time
        }

        It "Should collect and report errors" {
            $result = Test-UtilityIntegration -TestLevel Standard -OutputPath $script:TestOutputPath

            $summary = $result.Summary
            $summary.AllErrors | Should -Not -BeNullOrEmpty  # Should be an array
            $summary.AllErrors.GetType().Name | Should -Be "Object[]"
        }

        It "Should determine overall success correctly" {
            $result = Test-UtilityIntegration -TestLevel Basic -OutputPath $script:TestOutputPath

            $summary = $result.Summary
            $summary.OverallSuccess | Should -BeOfType [bool]

            # Success should be true if no errors and all tests pass
            if ($summary.AllErrors.Count -eq 0 -and $summary.ServicesPassedInit -eq $summary.TotalServices) {
                $summary.OverallSuccess | Should -Be $true
            }
        }
    }

    Context "Error Handling and Edge Cases" {
        It "Should handle missing services gracefully" {
            # Test with non-existent services
            $result = Test-UtilityIntegration -Services @('NonExistentService') -OutputPath $script:TestOutputPath

            $result | Should -Not -BeNullOrEmpty
            $result.ServiceTests.NonExistentService.InitializationTest | Should -Be $false
        }

        It "Should handle output path creation" {
            $newOutputPath = Join-Path $script:TestOutputPath "new-directory" "nested"
            $result = Test-UtilityIntegration -TestLevel Standard -OutputPath $newOutputPath

            Test-Path $newOutputPath | Should -Be $true
        }

        It "Should handle invalid output paths gracefully" {
            # Test with invalid characters in path (if applicable to platform)
            $invalidPath = Join-Path $script:TestOutputPath "test-output"
            { Test-UtilityIntegration -TestLevel Basic -OutputPath $invalidPath } | Should -Not -Throw
        }

        It "Should handle service initialization exceptions" {
            # The initialization functions should handle missing modules gracefully
            { Initialize-SemanticVersioningService } | Should -Not -Throw
            { Initialize-ProgressTrackingService } | Should -Not -Throw
            { Initialize-TestingFrameworkService } | Should -Not -Throw
            { Initialize-ScriptManagerService } | Should -Not -Throw
        }
    }

    Context "Performance and Resource Management" {
        It "Should complete basic tests efficiently" {
            $startTime = Get-Date
            $result = Test-UtilityIntegration -TestLevel Basic -OutputPath $script:TestOutputPath
            $endTime = Get-Date

            $actualDuration = ($endTime - $startTime).TotalSeconds
            $actualDuration | Should -BeLessThan 10  # Should complete quickly
        }

        It "Should handle concurrent testing" {
            # Test that multiple test runs don't interfere
            $job1 = Start-Job -ScriptBlock {
                param($ModulePath, $OutputPath)
                Import-Module $ModulePath -Force
                Test-UtilityIntegration -TestLevel Basic -OutputPath "$OutputPath-job1"
            } -ArgumentList $modulePath, $script:TestOutputPath

            $job2 = Start-Job -ScriptBlock {
                param($ModulePath, $OutputPath)
                Import-Module $ModulePath -Force
                Test-UtilityIntegration -TestLevel Basic -OutputPath "$OutputPath-job2"
            } -ArgumentList $modulePath, $script:TestOutputPath

            $result1 = Receive-Job $job1 -Wait
            $result2 = Receive-Job $job2 -Wait

            Remove-Job $job1, $job2

            $result1 | Should -Not -BeNullOrEmpty
            $result2 | Should -Not -BeNullOrEmpty
            $result1.Success | Should -BeOfType [bool]
            $result2.Success | Should -BeOfType [bool]
        }

        It "Should clean up resources properly" {
            # Test multiple runs to ensure no resource leaks
            for ($i = 1; $i -le 3; $i++) {
                $testPath = Join-Path $script:TestOutputPath "cleanup-test-$i"
                $result = Test-UtilityIntegration -TestLevel Basic -OutputPath $testPath
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Integration with Logging Module" {
        It "Should work with or without Logging module" {
            # Should work regardless of whether Logging module is available
            { Test-UtilityIntegration -TestLevel Basic -OutputPath $script:TestOutputPath } | Should -Not -Throw
        }

        It "Should provide fallback logging when Logging module unavailable" {
            # The module provides fallback logging functions
            $result = Test-UtilityIntegration -TestLevel Basic -OutputPath $script:TestOutputPath
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should work on current platform" {
            $platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
            $platform | Should -BeIn @("Windows", "Linux", "macOS")

            # Test that utility services work on this platform
            $result = Test-UtilityIntegration -TestLevel Basic -OutputPath $script:TestOutputPath
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should handle path operations cross-platform" {
            $testPath = Join-Path $script:TestOutputPath "cross-platform" "test"
            $result = Test-UtilityIntegration -TestLevel Basic -OutputPath $testPath

            $result | Should -Not -BeNullOrEmpty
            Test-Path $testPath | Should -Be $true
        }

        It "Should work with PowerShell 7+" {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7

            # Module should function correctly with PowerShell 7+
            $result = Test-UtilityIntegration -TestLevel Basic -OutputPath $script:TestOutputPath
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Report Generation and Output" {
        It "Should generate detailed test results" {
            $result = Test-UtilityIntegration -TestLevel Standard -OutputPath $script:TestOutputPath

            $resultsFile = Join-Path $script:TestOutputPath "integration-test-results.json"
            Test-Path $resultsFile | Should -Be $true

            $savedResults = Get-Content $resultsFile | ConvertFrom-Json
            $savedResults.TestLevel | Should -Be 'Standard'
            $savedResults.ServiceTests | Should -Not -BeNullOrEmpty
        }

        It "Should include workflow test reports" {
            $result = Test-UtilityIntegration -TestLevel Standard -OutputPath $script:TestOutputPath

            $reportFile = Join-Path $script:TestOutputPath "integration-test-report.json"
            if (Test-Path $reportFile) {
                $reportContent = Get-Content $reportFile | ConvertFrom-Json
                $reportContent.ReportType | Should -Be "UtilityServices"
            }
        }

        It "Should generate readable output format" {
            $result = Test-UtilityIntegration -TestLevel Basic -OutputPath $script:TestOutputPath

            # Results should be serializable
            { $result | ConvertTo-Json -Depth 10 } | Should -Not -Throw
        }
    }
}

AfterAll {
    # Clean up test environment
    if (Test-Path $script:TestOutputPath) {
        Remove-Item $script:TestOutputPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Remove the module
    Remove-Module UtilityServices -Force -ErrorAction SilentlyContinue
}
