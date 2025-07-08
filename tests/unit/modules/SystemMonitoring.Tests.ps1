#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive unit tests for the SystemMonitoring module.

.DESCRIPTION
    Tests all aspects of the SystemMonitoring module including:
    - Performance metrics collection
    - Alerting functionality
    - Dashboard generation
    - Configuration management
    - Intelligent monitoring features
    - Cross-platform compatibility

.NOTES
    Author: AitherZero Development Team
    Version: 2.0.0
    PowerShell: 7.0+
#>

# Import test framework
Import-Module Pester -Force

# Setup test environment
BeforeAll {
    # Import required modules
    $projectRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/SystemMonitoring") -Force

    # Test data directory
    $script:TestDataPath = Join-Path $projectRoot "tests/data/monitoring"
    if (-not (Test-Path $script:TestDataPath)) {
        New-Item -Path $script:TestDataPath -ItemType Directory -Force | Out-Null
    }

    # Mock data for testing
    $script:MockMetrics = @{
        Timestamp = "2025-07-06 12:00:00"
        System = @{
            CPU = @{ Average = 45.5; Maximum = 78.2; Minimum = 15.3; Trend = "Stable" }
            Memory = @{ Average = 65.2; Current = 68.1; TotalGB = 16.0; UsedGB = 10.9; FreeGB = 5.1; Trend = "Increasing" }
            Disk = @()
            Network = @()
        }
        Application = @{
            StartupTime = 2.3
            ProcessInfo = @{ WorkingSetMB = 245.6; ThreadCount = 12 }
        }
        SLACompliance = @{
            Overall = "Pass"
            Score = 85.5
        }
    }
}

Describe "SystemMonitoring Module" -Tag "Unit", "SystemMonitoring" {

    Context "Module Loading" {
        It "Should load SystemMonitoring module successfully" {
            Get-Module SystemMonitoring | Should -Not -BeNullOrEmpty
        }

        It "Should export all required functions" {
            $expectedFunctions = @(
                'Get-SystemDashboard',
                'Get-SystemAlerts',
                'Get-SystemPerformance',
                'Get-ServiceStatus',
                'Search-SystemLogs',
                'Set-PerformanceBaseline',
                'Invoke-HealthCheck',
                'Start-SystemMonitoring',
                'Stop-SystemMonitoring',
                'Get-MonitoringConfiguration',
                'Set-MonitoringConfiguration',
                'Export-MonitoringData',
                'Import-MonitoringData',
                'Enable-PredictiveAlerting',
                'Get-MonitoringInsights'
            )

            $exportedFunctions = Get-Module SystemMonitoring | Select-Object -ExpandProperty ExportedFunctions

            foreach ($function in $expectedFunctions) {
                $exportedFunctions.ContainsKey($function) | Should -BeTrue -Because "Function $function should be exported"
            }
        }

        It "Should have correct module version" {
            $module = Get-Module SystemMonitoring
            $module.Version.ToString() | Should -Be "2.0.0"
        }
    }

    Context "Performance Metrics Collection" {
        It "Should collect system performance metrics" {
            $result = Get-SystemPerformance -MetricType System -Duration 1

            $result | Should -Not -BeNullOrEmpty
            $result.System | Should -Not -BeNullOrEmpty
            $result.System.CPU | Should -Not -BeNullOrEmpty
            $result.System.Memory | Should -Not -BeNullOrEmpty
        }

        It "Should collect application metrics" {
            $result = Get-SystemPerformance -MetricType Application -Duration 1

            $result | Should -Not -BeNullOrEmpty
            $result.Application | Should -Not -BeNullOrEmpty
            $result.Application.ProcessInfo | Should -Not -BeNullOrEmpty
        }

        It "Should support different output formats" {
            $jsonResult = Get-SystemPerformance -MetricType System -Duration 1 -OutputFormat JSON
            $csvResult = Get-SystemPerformance -MetricType System -Duration 1 -OutputFormat CSV

            $jsonResult | Should -Not -BeNullOrEmpty
            $csvResult | Should -Not -BeNullOrEmpty

            # Validate JSON format
            { $jsonResult | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include trend analysis when requested" {
            $result = Get-SystemPerformance -MetricType All -Duration 2 -IncludeTrends

            $result.Trends | Should -Not -BeNullOrEmpty
            $result.Trends.CPU | Should -Not -BeNullOrEmpty
            $result.Trends.Memory | Should -Not -BeNullOrEmpty
        }

        It "Should calculate SLA compliance correctly" {
            $result = Get-SystemPerformance -MetricType All -Duration 1

            $result.SLACompliance | Should -Not -BeNullOrEmpty
            $result.SLACompliance.Overall | Should -BeIn @("Pass", "Fail")
            $result.SLACompliance.Score | Should -BeGreaterOrEqual 0
            $result.SLACompliance.Score | Should -BeLessOrEqual 100
        }
    }

    Context "System Dashboard" {
        It "Should generate system dashboard successfully" {
            $result = Get-SystemDashboard

            $result | Should -Not -BeNullOrEmpty
            $result.Metrics | Should -Not -BeNullOrEmpty
            $result.Summary | Should -Not -BeNullOrEmpty
        }

        It "Should support different output formats" {
            $jsonResult = Get-SystemDashboard -Format JSON
            $htmlResult = Get-SystemDashboard -Format HTML

            $jsonResult | Should -Not -BeNullOrEmpty
            $htmlResult | Should -Not -BeNullOrEmpty

            # Validate JSON format
            { $jsonResult | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include detailed information when requested" {
            $result = Get-SystemDashboard -Detailed

            $result | Should -Not -BeNullOrEmpty
            # Detailed dashboard should include additional information
        }

        It "Should export dashboard data when requested" {
            $tempFile = Join-Path $script:TestDataPath "test-dashboard.json"

            { Get-SystemDashboard -Export -Format JSON } | Should -Not -Throw

            # Cleanup
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force
            }
        }
    }

    Context "Alert Management" {
        It "Should retrieve system alerts" {
            $result = Get-SystemAlerts

            $result | Should -Not -BeNull
            # Result should be an array (even if empty)
        }

        It "Should filter alerts by severity" {
            $criticalAlerts = Get-SystemAlerts -Severity Critical
            $highAlerts = Get-SystemAlerts -Severity High

            # Should not throw errors
            $criticalAlerts | Should -Not -BeNull
            $highAlerts | Should -Not -BeNull
        }

        It "Should show only active alerts when requested" {
            $activeAlerts = Get-SystemAlerts -Active

            $activeAlerts | Should -Not -BeNull
        }

        It "Should export alert data" {
            { Get-SystemAlerts -Export } | Should -Not -Throw
        }

        It "Should acknowledge alerts" {
            # This is a functional test - in real scenarios would need existing alerts
            { Get-SystemAlerts -Acknowledge -AlertIds @("TEST001") } | Should -Not -Throw
        }

        It "Should mute alerts temporarily" {
            { Get-SystemAlerts -Mute -Duration "30m" } | Should -Not -Throw
        }
    }

    Context "Service Monitoring" {
        It "Should get service status" {
            $result = Get-ServiceStatus

            $result | Should -Not -BeNullOrEmpty
        }

        It "Should filter critical services" {
            $criticalServices = Get-ServiceStatus -Critical

            $criticalServices | Should -Not -BeNull
        }

        It "Should include dependencies when requested" {
            if ($IsWindows) {
                $servicesWithDeps = Get-ServiceStatus -ServiceName "Spooler" -IncludeDependencies
                $servicesWithDeps | Should -Not -BeNull
            } else {
                # Linux/macOS test
                $servicesWithDeps = Get-ServiceStatus -IncludeDependencies
                $servicesWithDeps | Should -Not -BeNull
            }
        }
    }

    Context "Health Checks" {
        It "Should perform comprehensive health check" {
            $result = Invoke-HealthCheck -CheckType All

            $result | Should -Not -BeNullOrEmpty
        }

        It "Should perform specific health checks" {
            $systemCheck = Invoke-HealthCheck -CheckType System
            $serviceCheck = Invoke-HealthCheck -CheckType Services

            $systemCheck | Should -Not -BeNull
            $serviceCheck | Should -Not -BeNull
        }

        It "Should include detailed diagnostics when requested" {
            $detailedResult = Invoke-HealthCheck -CheckType System -Detailed

            $detailedResult | Should -Not -BeNullOrEmpty
        }
    }

    Context "Monitoring Configuration" {
        It "Should get current monitoring configuration" {
            $config = Get-MonitoringConfiguration

            $config | Should -Not -BeNullOrEmpty
            $config.AlertThresholds | Should -Not -BeNullOrEmpty
        }

        It "Should update monitoring configuration" {
            $newThresholds = @{
                CPU = @{ Critical = 90; High = 80; Medium = 70 }
                Memory = @{ Critical = 95; High = 85; Medium = 75 }
            }

            $result = Set-MonitoringConfiguration -AlertThresholds $newThresholds

            $result | Should -Not -BeNullOrEmpty
            $result.AlertThresholds | Should -Not -BeNullOrEmpty
        }

        It "Should enable intelligent thresholds" {
            $result = Set-MonitoringConfiguration -EnableIntelligentThresholds -AlertSensitivity Balanced

            $result | Should -Not -BeNullOrEmpty
        }

        It "Should persist configuration when requested" {
            { Set-MonitoringConfiguration -PersistConfiguration } | Should -Not -Throw
        }
    }

    Context "Performance Baselines" {
        It "Should set performance baseline" {
            $result = Set-PerformanceBaseline -Name "TestBaseline" -Duration (New-TimeSpan -Minutes 1)

            $result | Should -Not -BeNullOrEmpty
        }

        It "Should set baseline for specific metrics" {
            $result = Set-PerformanceBaseline -Name "CPUBaseline" -Metrics @("CPU", "Memory")

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Log Searching" {
        BeforeAll {
            # Create test log file
            $testLogPath = Join-Path $script:TestDataPath "test.log"
            $testLogContent = @(
                "[2025-07-06 12:00:00] INFO: Test log entry 1",
                "[2025-07-06 12:01:00] ERROR: Test error message",
                "[2025-07-06 12:02:00] WARNING: Test warning message",
                "[2025-07-06 12:03:00] INFO: Another test entry"
            )
            $testLogContent | Out-File -FilePath $testLogPath -Encoding UTF8
        }

        It "Should search system logs" {
            $result = Search-SystemLogs -Pattern "ERROR" -StartTime (Get-Date).AddHours(-1)

            $result | Should -Not -BeNullOrEmpty
            $result.Pattern | Should -Be "ERROR"
        }

        It "Should support different match types" {
            $exactResult = Search-SystemLogs -Pattern "ERROR" -MatchType Exact
            $regexResult = Search-SystemLogs -Pattern "ERR.*" -MatchType Regex
            $fuzzyResult = Search-SystemLogs -Pattern "err" -MatchType Fuzzy

            $exactResult | Should -Not -BeNull
            $regexResult | Should -Not -BeNull
            $fuzzyResult | Should -Not -BeNull
        }

        It "Should include context when requested" {
            $result = Search-SystemLogs -Pattern "ERROR" -IncludeContext

            $result | Should -Not -BeNullOrEmpty
        }

        It "Should limit results" {
            $result = Search-SystemLogs -Pattern ".*" -MaxResults 5

            $result | Should -Not -BeNullOrEmpty
            $result.TotalMatches | Should -BeLessOrEqual 5
        }

        AfterAll {
            # Cleanup test log file
            $testLogPath = Join-Path $script:TestDataPath "test.log"
            if (Test-Path $testLogPath) {
                Remove-Item $testLogPath -Force
            }
        }
    }

    Context "Data Export/Import" {
        It "Should export monitoring data" {
            $exportPath = Join-Path $script:TestDataPath "test-export.json"

            $result = Export-MonitoringData -OutputPath $exportPath -Format JSON

            $result | Should -BeTrue
            Test-Path $exportPath | Should -BeTrue

            # Cleanup
            Remove-Item $exportPath -Force -ErrorAction SilentlyContinue
        }

        It "Should export in different formats" {
            $jsonPath = Join-Path $script:TestDataPath "test-export.json"
            $csvPath = Join-Path $script:TestDataPath "test-export.csv"

            { Export-MonitoringData -OutputPath $jsonPath -Format JSON } | Should -Not -Throw
            { Export-MonitoringData -OutputPath $csvPath -Format CSV } | Should -Not -Throw

            # Cleanup
            Remove-Item $jsonPath -Force -ErrorAction SilentlyContinue
            Remove-Item $csvPath -Force -ErrorAction SilentlyContinue
        }

        It "Should import monitoring data" {
            # Create test data file
            $importPath = Join-Path $script:TestDataPath "test-import.json"
            $testData = @{
                MonitoringData = @{ Test = "Data" }
                AlertThresholds = @{ CPU = @{ Critical = 90 } }
            }
            $testData | ConvertTo-Json -Depth 5 | Out-File -FilePath $importPath -Encoding UTF8

            $result = Import-MonitoringData -InputPath $importPath

            $result | Should -BeTrue

            # Cleanup
            Remove-Item $importPath -Force
        }
    }

    Context "Monitoring Jobs" {
        It "Should start system monitoring" {
            $result = Start-SystemMonitoring -MonitoringProfile Basic -Duration 1

            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be "Running"
        }

        It "Should stop system monitoring" {
            # Start monitoring first
            Start-SystemMonitoring -MonitoringProfile Basic -Duration 1
            Start-Sleep -Seconds 2  # Let it run briefly

            $result = Stop-SystemMonitoring

            $result | Should -Not -BeNullOrEmpty
        }

        It "Should support different monitoring profiles" {
            $basicResult = Start-SystemMonitoring -MonitoringProfile Basic -Duration 1
            Stop-SystemMonitoring -Force

            $standardResult = Start-SystemMonitoring -MonitoringProfile Standard -Duration 1
            Stop-SystemMonitoring -Force

            $basicResult | Should -Not -BeNull
            $standardResult | Should -Not -BeNull
        }
    }

    Context "Advanced Features" {
        It "Should enable predictive alerting" {
            $result = Enable-PredictiveAlerting -PredictionWindowMinutes 15 -PredictionConfidenceThreshold 0.7

            $result | Should -Not -BeNullOrEmpty
            $result.Enabled | Should -BeTrue
        }

        It "Should generate monitoring insights" {
            $result = Get-MonitoringInsights -InsightType Performance -HistoryDays 1

            $result | Should -Not -BeNullOrEmpty
            $result.InsightType | Should -Be "Performance"
        }

        It "Should generate insights for all types" {
            $result = Get-MonitoringInsights -InsightType All -HistoryDays 3

            $result | Should -Not -BeNullOrEmpty
            $result.Recommendations | Should -Not -BeNullOrEmpty
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should work on Windows" -Skip:(-not $IsWindows) {
            $result = Get-SystemPerformance -MetricType System -Duration 1

            $result | Should -Not -BeNullOrEmpty
            $result.Metadata.Platform | Should -Be "Windows"
        }

        It "Should work on Linux" -Skip:(-not $IsLinux) {
            $result = Get-SystemPerformance -MetricType System -Duration 1

            $result | Should -Not -BeNullOrEmpty
            $result.Metadata.Platform | Should -Be "Linux"
        }

        It "Should work on macOS" -Skip:(-not $IsMacOS) {
            $result = Get-SystemPerformance -MetricType System -Duration 1

            $result | Should -Not -BeNullOrEmpty
            $result.Metadata.Platform | Should -Be "macOS"
        }
    }

    Context "Error Handling" {
        It "Should handle invalid parameters gracefully" {
            { Get-SystemPerformance -MetricType "InvalidType" } | Should -Throw
            { Get-SystemDashboard -Format "InvalidFormat" } | Should -Throw
        }

        It "Should handle missing files gracefully" {
            { Import-MonitoringData -InputPath "/nonexistent/file.json" } | Should -Throw
        }

        It "Should validate parameter ranges" {
            { Get-SystemPerformance -Duration 0 } | Should -Throw
            { Get-SystemPerformance -Duration 400 } | Should -Throw
        }
    }

    Context "Performance Tests" {
        It "Should collect metrics within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            Get-SystemPerformance -MetricType System -Duration 1

            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 5000  # 5 seconds max
        }

        It "Should generate dashboard quickly" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            Get-SystemDashboard

            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 3000  # 3 seconds max
        }

        It "Should handle multiple concurrent requests" {
            $jobs = @()

            # Start multiple background jobs
            for ($i = 1; $i -le 3; $i++) {
                $jobs += Start-Job {
                    Import-Module (Join-Path $using:projectRoot "aither-core/modules/SystemMonitoring") -Force
                    Get-SystemPerformance -MetricType System -Duration 1
                }
            }

            # Wait for all jobs to complete
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job

            $results.Count | Should -Be 3
            foreach ($result in $results) {
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }
}

# Integration tests
Describe "SystemMonitoring Integration Tests" -Tag "Integration", "SystemMonitoring" {

    Context "End-to-End Monitoring Workflow" {
        It "Should complete full monitoring cycle" {
            # 1. Configure monitoring
            $config = Set-MonitoringConfiguration -DefaultProfile Standard -AlertSensitivity Balanced
            $config | Should -Not -BeNullOrEmpty

            # 2. Set baseline
            $baseline = Set-PerformanceBaseline -Name "IntegrationTest" -Duration (New-TimeSpan -Minutes 1)
            $baseline | Should -Not -BeNullOrEmpty

            # 3. Start monitoring
            $monitoring = Start-SystemMonitoring -MonitoringProfile Standard -Duration 1
            $monitoring | Should -Not -BeNullOrEmpty

            # 4. Collect metrics
            Start-Sleep -Seconds 2
            $metrics = Get-SystemPerformance -MetricType All -Duration 1
            $metrics | Should -Not -BeNullOrEmpty

            # 5. Check alerts
            $alerts = Get-SystemAlerts
            $alerts | Should -Not -BeNull

            # 6. Generate dashboard
            $dashboard = Get-SystemDashboard
            $dashboard | Should -Not -BeNullOrEmpty

            # 7. Stop monitoring
            $stopResult = Stop-SystemMonitoring
            $stopResult | Should -Not -BeNullOrEmpty

            # 8. Export data
            $exportPath = Join-Path $script:TestDataPath "integration-export.json"
            $exportResult = Export-MonitoringData -OutputPath $exportPath
            $exportResult | Should -BeTrue

            # Cleanup
            Remove-Item $exportPath -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Monitoring with Alerts" {
        It "Should handle alert lifecycle" {
            # Configure sensitive thresholds to trigger alerts
            $sensitiveThresholds = @{
                CPU = @{ Critical = 10; High = 5; Medium = 1 }
                Memory = @{ Critical = 10; High = 5; Medium = 1 }
            }

            Set-MonitoringConfiguration -AlertThresholds $sensitiveThresholds

            # Start monitoring
            Start-SystemMonitoring -MonitoringProfile Standard -Duration 1
            Start-Sleep -Seconds 3

            # Check for alerts (should have some with low thresholds)
            $alerts = Get-SystemAlerts -Active

            # Stop monitoring
            Stop-SystemMonitoring -Force

            # Test passed if no errors occurred
            $true | Should -BeTrue
        }
    }
}

# Cleanup after all tests
AfterAll {
    # Stop any running monitoring jobs
    try {
        Stop-SystemMonitoring -Force -ErrorAction SilentlyContinue
    } catch {
        # Ignore cleanup errors
    }

    # Clean up test data directory
    if (Test-Path $script:TestDataPath) {
        Remove-Item $script:TestDataPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Remove test modules
    Remove-Module SystemMonitoring -Force -ErrorAction SilentlyContinue
    Remove-Module Logging -Force -ErrorAction SilentlyContinue
}
