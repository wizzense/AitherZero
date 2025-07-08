#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Enhanced comprehensive unit tests for the SystemMonitoring module with proper mocking.

.DESCRIPTION
    Tests all aspects of the SystemMonitoring module with mocked dependencies including:
    - Performance metrics collection (with mocked system calls)
    - Alerting functionality (with mocked file system)
    - Dashboard generation (with mocked network operations)
    - Configuration management (with mocked registry access)
    - System services monitoring (with mocked service calls)
    - Cross-platform compatibility (with mocked platform detection)

.NOTES
    Author: AitherZero Development Team
    Version: 2.0.0
    Created: 2025-07-08
    PowerShell: 7.0+
#>

# Import test framework and mock helpers
Import-Module Pester -Force

# Import mock helpers
$MockHelpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "shared" "MockHelpers.ps1"
. $MockHelpersPath

# Setup test environment
BeforeAll {
    # Import required modules
    $projectRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/SystemMonitoring") -Force

    # Test data directory (virtual)
    $script:TestDataPath = "/virtual/tests/data/monitoring"
    
    # Mock performance counters and system data
    $script:MockPerformanceCounters = @{
        CPU = @{
            '\Processor(_Total)\% Processor Time' = 45.5
            '\System\Processor Queue Length' = 2
        }
        Memory = @{
            '\Memory\Available MBytes' = 8192
            '\Memory\Committed Bytes' = 8589934592
            '\Memory\Page Faults/sec' = 1000
        }
        Disk = @{
            '\PhysicalDisk(_Total)\% Disk Time' = 25.0
            '\PhysicalDisk(_Total)\Avg. Disk Queue Length' = 0.5
        }
        Network = @{
            '\Network Interface(*)\Bytes Total/sec' = 1048576
            '\Network Interface(*)\Packets/sec' = 1000
        }
    }

    # Mock system services
    $script:MockSystemServices = @{
        'Spooler' = @{
            Name = 'Spooler'
            Status = 'Running'
            StartType = 'Automatic'
        }
        'BITS' = @{
            Name = 'BITS'
            Status = 'Running'
            StartType = 'Automatic'
        }
        'Themes' = @{
            Name = 'Themes'
            Status = 'Stopped'
            StartType = 'Disabled'
        }
    }

    # Mock system processes
    $script:MockSystemProcesses = @{
        'powershell' = @{
            Name = 'powershell'
            Id = 1234
            WorkingSet = 104857600
            CPU = 2.5
        }
        'explorer' = @{
            Name = 'explorer'
            Id = 5678
            WorkingSet = 52428800
            CPU = 1.2
        }
    }

    # Mock metrics data
    $script:MockMetrics = @{
        Timestamp = "2025-07-08 12:00:00"
        System = @{
            CPU = @{ Average = 45.5; Maximum = 78.2; Minimum = 15.3; Trend = "Stable" }
            Memory = @{ Average = 65.2; Current = 68.1; TotalGB = 16.0; UsedGB = 10.9; FreeGB = 5.1; Trend = "Increasing" }
            Disk = @(
                @{ Drive = "C:"; TotalGB = 500; UsedGB = 300; FreeGB = 200; UsedPercent = 60 }
                @{ Drive = "D:"; TotalGB = 1000; UsedGB = 200; FreeGB = 800; UsedPercent = 20 }
            )
            Network = @(
                @{ Interface = "Ethernet"; BytesReceived = 1048576; BytesSent = 524288; PacketsReceived = 1000; PacketsSent = 500 }
            )
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

BeforeEach {
    # Set up comprehensive mocking for each test
    Set-TestMockEnvironment -MockTypes @("FileSystem", "Network", "SystemServices", "ExternalTools")
    
    # Set up virtual file system for monitoring data
    Add-VirtualPath -Path $script:TestDataPath -IsDirectory
    Add-VirtualPath -Path "$($script:TestDataPath)/monitoring-config.json" -Content (@{
        AlertThresholds = @{
            CPU = @{ Critical = 90; High = 80; Medium = 70 }
            Memory = @{ Critical = 95; High = 85; Medium = 75 }
            Disk = @{ Critical = 95; High = 85; Medium = 75 }
        }
        MonitoringProfile = "Standard"
        AlertSensitivity = "Balanced"
    } | ConvertTo-Json -Depth 10)
    
    # Set up mock system services
    foreach ($service in $script:MockSystemServices.GetEnumerator()) {
        Add-MockService -Name $service.Key -Status $service.Value.Status -StartType $service.Value.StartType
    }
    
    # Set up mock processes
    foreach ($process in $script:MockSystemProcesses.GetEnumerator()) {
        Add-MockProcess -Name $process.Key -Id $process.Value.Id -ProcessName $process.Value.Name
    }
    
    # Mock performance counter functions
    Mock -CommandName Get-Counter -MockWith {
        param($Counter)
        
        $mockResults = @()
        foreach ($counterPath in $Counter) {
            $mockValue = switch -Wildcard ($counterPath) {
                '*Processor*' { $script:MockPerformanceCounters.CPU[$counterPath] }
                '*Memory*' { $script:MockPerformanceCounters.Memory[$counterPath] }
                '*Disk*' { $script:MockPerformanceCounters.Disk[$counterPath] }
                '*Network*' { $script:MockPerformanceCounters.Network[$counterPath] }
                default { Get-Random -Minimum 0 -Maximum 100 }
            }
            
            $mockResults += [PSCustomObject]@{
                CounterSamples = @(
                    [PSCustomObject]@{
                        Path = $counterPath
                        CookedValue = $mockValue
                        TimeStamp = Get-Date
                    }
                )
            }
        }
        
        return $mockResults
    }
    
    # Mock Get-CimInstance for system information
    Mock -CommandName Get-CimInstance -MockWith {
        param($ClassName, $ComputerName)
        
        switch ($ClassName) {
            'Win32_OperatingSystem' {
                return [PSCustomObject]@{
                    TotalVisibleMemorySize = 16777216
                    FreePhysicalMemory = 8388608
                    Caption = "Microsoft Windows 10 Pro"
                    Version = "10.0.19045"
                }
            }
            'Win32_Processor' {
                return [PSCustomObject]@{
                    Name = "Intel(R) Core(TM) i7-8700K CPU @ 3.70GHz"
                    NumberOfCores = 6
                    NumberOfLogicalProcessors = 12
                    LoadPercentage = 45
                }
            }
            'Win32_LogicalDisk' {
                return @(
                    [PSCustomObject]@{
                        DeviceID = "C:"
                        Size = 536870912000
                        FreeSpace = 214748364800
                        FileSystem = "NTFS"
                    }
                    [PSCustomObject]@{
                        DeviceID = "D:"
                        Size = 1073741824000
                        FreeSpace = 858993459200
                        FileSystem = "NTFS"
                    }
                )
            }
            'Win32_NetworkAdapter' {
                return [PSCustomObject]@{
                    Name = "Intel(R) Ethernet Connection"
                    NetConnectionStatus = 2
                    Speed = 1000000000
                }
            }
            default {
                return $null
            }
        }
    }
    
    # Mock event log functions
    Mock -CommandName Get-WinEvent -MockWith {
        param($LogName, $MaxEvents)
        
        $events = @()
        for ($i = 1; $i -le ($MaxEvents ?? 10); $i++) {
            $events += [PSCustomObject]@{
                TimeCreated = (Get-Date).AddHours(-$i)
                Id = 1000 + $i
                LevelDisplayName = @('Information', 'Warning', 'Error')[(Get-Random -Maximum 3)]
                Message = "Mock event log entry $i"
                LogName = $LogName
            }
        }
        
        return $events
    }
    
    # Mock network connectivity tests
    Mock -CommandName Test-NetConnection -MockWith {
        param($ComputerName, $Port)
        
        return [PSCustomObject]@{
            ComputerName = $ComputerName
            RemoteAddress = "192.168.1.1"
            RemotePort = $Port
            InterfaceAlias = "Ethernet"
            SourceAddress = "192.168.1.100"
            TcpTestSucceeded = $true
            PingSucceeded = $true
        }
    }
    
    # Mock network responses for monitoring APIs
    Add-MockResponse -Url "https://api.monitoring.local/metrics" -Response $script:MockMetrics
    Add-MockResponse -Url "https://api.monitoring.local/alerts" -Response @{
        alerts = @(
            @{
                id = "alert-001"
                severity = "High"
                message = "CPU usage above 80%"
                timestamp = Get-Date
                acknowledged = $false
            }
        )
    }
}

AfterEach {
    # Clean up mocks after each test
    Clear-TestMockEnvironment
}

Describe "SystemMonitoring Module with Enhanced Mocking" -Tag "Unit", "SystemMonitoring" {

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
    }

    Context "Performance Metrics Collection with Mocked Data" {
        It "Should collect system performance metrics using mocked performance counters" {
            $result = Get-SystemPerformance -MetricType System -Duration 1

            $result | Should -Not -BeNullOrEmpty
            $result.System | Should -Not -BeNullOrEmpty
            $result.System.CPU | Should -Not -BeNullOrEmpty
            $result.System.Memory | Should -Not -BeNullOrEmpty
            
            # Verify mocked data is being used
            $result.System.CPU.Average | Should -Be 45.5
        }

        It "Should collect application metrics using mocked CIM instances" {
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
    }

    Context "System Dashboard with Mocked File System" {
        It "Should generate system dashboard using mocked data" {
            $result = Get-SystemDashboard

            $result | Should -Not -BeNullOrEmpty
            $result.Metrics | Should -Not -BeNullOrEmpty
            $result.Summary | Should -Not -BeNullOrEmpty
        }

        It "Should export dashboard data to virtual file system" {
            $exportPath = "$($script:TestDataPath)/test-dashboard.json"

            { Get-SystemDashboard -Export -Format JSON -ExportPath $exportPath } | Should -Not -Throw

            # Verify file was created in virtual file system
            Test-Path $exportPath | Should -Be $true
        }

        It "Should support different output formats" {
            $jsonResult = Get-SystemDashboard -Format JSON
            $htmlResult = Get-SystemDashboard -Format HTML

            $jsonResult | Should -Not -BeNullOrEmpty
            $htmlResult | Should -Not -BeNullOrEmpty

            # Validate JSON format
            { $jsonResult | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context "Alert Management with Mocked Network Operations" {
        It "Should retrieve system alerts using mocked API responses" {
            $result = Get-SystemAlerts

            $result | Should -Not -BeNull
            # Result should be an array (even if empty)
        }

        It "Should filter alerts by severity using mocked data" {
            $criticalAlerts = Get-SystemAlerts -Severity Critical
            $highAlerts = Get-SystemAlerts -Severity High

            # Should not throw errors
            $criticalAlerts | Should -Not -BeNull
            $highAlerts | Should -Not -BeNull
        }

        It "Should export alert data to virtual file system" {
            $exportPath = "$($script:TestDataPath)/test-alerts.json"
            
            { Get-SystemAlerts -Export -ExportPath $exportPath } | Should -Not -Throw
            
            # Verify file was created in virtual file system
            Test-Path $exportPath | Should -Be $true
        }

        It "Should handle network failures gracefully" {
            # Add failing URL to mock network failures
            Add-FailingUrl -Url "https://api.monitoring.local/alerts"

            # Should handle the failure gracefully
            { Get-SystemAlerts } | Should -Not -Throw
        }
    }

    Context "Service Monitoring with Mocked System Services" {
        It "Should get service status using mocked services" {
            $result = Get-ServiceStatus

            $result | Should -Not -BeNullOrEmpty
            # Should return our mocked services
            $result.Count | Should -Be 3
        }

        It "Should filter critical services" {
            $criticalServices = Get-ServiceStatus -Critical

            $criticalServices | Should -Not -BeNull
        }

        It "Should include dependencies when requested" {
            if ($IsWindows) {
                $servicesWithDeps = Get-ServiceStatus -ServiceName "Spooler" -IncludeDependencies
                $servicesWithDeps | Should -Not -BeNull
                $servicesWithDeps.Name | Should -Be "Spooler"
                $servicesWithDeps.Status | Should -Be "Running"
            } else {
                # Linux/macOS test
                $servicesWithDeps = Get-ServiceStatus -IncludeDependencies
                $servicesWithDeps | Should -Not -BeNull
            }
        }

        It "Should handle service start/stop operations" {
            # Test service start
            Start-Service -Name "Themes"
            $service = Get-Service -Name "Themes"
            $service.Status | Should -Be "Running"

            # Test service stop
            Stop-Service -Name "Themes"
            $service = Get-Service -Name "Themes"
            $service.Status | Should -Be "Stopped"
        }
    }

    Context "Health Checks with Mocked System Data" {
        It "Should perform comprehensive health check using mocked data" {
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

    Context "Monitoring Configuration with Mocked File System" {
        It "Should get current monitoring configuration from virtual file system" {
            $config = Get-MonitoringConfiguration

            $config | Should -Not -BeNullOrEmpty
            $config.AlertThresholds | Should -Not -BeNullOrEmpty
            $config.AlertThresholds.CPU.Critical | Should -Be 90
        }

        It "Should update monitoring configuration in virtual file system" {
            $newThresholds = @{
                CPU = @{ Critical = 95; High = 85; Medium = 75 }
                Memory = @{ Critical = 98; High = 88; Medium = 78 }
            }

            $result = Set-MonitoringConfiguration -AlertThresholds $newThresholds

            $result | Should -Not -BeNullOrEmpty
            $result.AlertThresholds | Should -Not -BeNullOrEmpty
            $result.AlertThresholds.CPU.Critical | Should -Be 95
        }

        It "Should persist configuration to virtual file system" {
            { Set-MonitoringConfiguration -PersistConfiguration } | Should -Not -Throw
            
            # Verify configuration was saved
            Test-Path "$($script:TestDataPath)/monitoring-config.json" | Should -Be $true
        }
    }

    Context "Log Searching with Mocked Event Logs" {
        It "Should search system logs using mocked event log data" {
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

        It "Should limit results appropriately" {
            $result = Search-SystemLogs -Pattern ".*" -MaxResults 5

            $result | Should -Not -BeNullOrEmpty
            $result.TotalMatches | Should -BeLessOrEqual 5
        }
    }

    Context "Data Export/Import with Virtual File System" {
        It "Should export monitoring data to virtual file system" {
            $exportPath = "$($script:TestDataPath)/test-export.json"

            $result = Export-MonitoringData -OutputPath $exportPath -Format JSON

            $result | Should -BeTrue
            Test-Path $exportPath | Should -BeTrue
        }

        It "Should export in different formats" {
            $jsonPath = "$($script:TestDataPath)/test-export.json"
            $csvPath = "$($script:TestDataPath)/test-export.csv"

            { Export-MonitoringData -OutputPath $jsonPath -Format JSON } | Should -Not -Throw
            { Export-MonitoringData -OutputPath $csvPath -Format CSV } | Should -Not -Throw

            Test-Path $jsonPath | Should -Be $true
            Test-Path $csvPath | Should -Be $true
        }

        It "Should import monitoring data from virtual file system" {
            # Create test data file in virtual file system
            $importPath = "$($script:TestDataPath)/test-import.json"
            $testData = @{
                MonitoringData = @{ Test = "Data" }
                AlertThresholds = @{ CPU = @{ Critical = 90 } }
            }
            Add-VirtualPath -Path $importPath -Content ($testData | ConvertTo-Json -Depth 5)

            $result = Import-MonitoringData -InputPath $importPath

            $result | Should -BeTrue
        }
    }

    Context "Cross-Platform Compatibility with Mocked Platform Detection" {
        It "Should work on Windows with mocked platform detection" {
            # Mock platform detection
            Mock -CommandName Get-Variable -MockWith {
                param($Name)
                if ($Name -eq "IsWindows") {
                    return [PSCustomObject]@{ Value = $true }
                }
                return $null
            }

            $result = Get-SystemPerformance -MetricType System -Duration 1

            $result | Should -Not -BeNullOrEmpty
            $result.Metadata.Platform | Should -Be "Windows"
        }

        It "Should work on Linux with mocked platform detection" {
            # Mock platform detection
            Mock -CommandName Get-Variable -MockWith {
                param($Name)
                if ($Name -eq "IsLinux") {
                    return [PSCustomObject]@{ Value = $true }
                }
                return $null
            }

            $result = Get-SystemPerformance -MetricType System -Duration 1

            $result | Should -Not -BeNullOrEmpty
            $result.Metadata.Platform | Should -Be "Linux"
        }
    }

    Context "Network Connectivity with Mocked Network Operations" {
        It "Should test network connectivity using mocked Test-NetConnection" {
            $result = Test-NetConnection -ComputerName "google.com" -Port 80

            $result | Should -Not -BeNullOrEmpty
            $result.TcpTestSucceeded | Should -Be $true
            $result.PingSucceeded | Should -Be $true
        }

        It "Should handle network monitoring API calls" {
            # This would call a mocked monitoring API
            $response = Invoke-RestMethod -Uri "https://api.monitoring.local/metrics"

            $response | Should -Not -BeNullOrEmpty
            $response.System | Should -Not -BeNullOrEmpty
        }
    }

    Context "Performance Tests with Mocked Operations" {
        It "Should collect metrics within reasonable time using mocked data" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            Get-SystemPerformance -MetricType System -Duration 1

            $stopwatch.Stop()
            # Should be very fast with mocked data
            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 1000
        }

        It "Should generate dashboard quickly with mocked data" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            Get-SystemDashboard

            $stopwatch.Stop()
            # Should be very fast with mocked data
            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 1000
        }
    }

    Context "Mock Isolation and Cleanup" {
        It "Should have isolated mocks between tests" {
            # This test verifies that mocks are properly isolated
            Test-MockIsolation | Should -Be $true
        }

        It "Should properly reset file system state between tests" {
            # Add a file
            Add-VirtualPath -Path "$($script:TestDataPath)/temp-file.txt" -Content "Temporary content"
            Test-Path "$($script:TestDataPath)/temp-file.txt" | Should -Be $true
        }

        It "Should have clean file system state after mock reset" {
            # This test should not see the temp file from previous test
            Test-Path "$($script:TestDataPath)/temp-file.txt" | Should -Be $false
        }
    }

    Context "Error Handling with Mocked Failures" {
        It "Should handle invalid parameters gracefully" {
            { Get-SystemPerformance -MetricType "InvalidType" } | Should -Throw
            { Get-SystemDashboard -Format "InvalidFormat" } | Should -Throw
        }

        It "Should handle missing files gracefully with virtual file system" {
            { Import-MonitoringData -InputPath "/nonexistent/file.json" } | Should -Throw
        }

        It "Should handle network failures gracefully" {
            Add-FailingUrl -Url "https://api.monitoring.local/metrics"
            
            # Should handle the failure gracefully
            { Invoke-RestMethod -Uri "https://api.monitoring.local/metrics" } | Should -Throw
        }

        It "Should handle service failures gracefully" {
            # Mock a service that doesn't exist
            { Get-Service -Name "NonExistentService" } | Should -Throw
        }
    }
}

# Integration tests with mocked dependencies
Describe "SystemMonitoring Integration Tests with Mocking" -Tag "Integration", "SystemMonitoring" {

    Context "End-to-End Monitoring Workflow with Mocked Operations" {
        It "Should complete full monitoring cycle with mocked dependencies" {
            # 1. Configure monitoring
            $config = Set-MonitoringConfiguration -DefaultProfile Standard -AlertSensitivity Balanced
            $config | Should -Not -BeNullOrEmpty

            # 2. Set baseline
            $baseline = Set-PerformanceBaseline -Name "IntegrationTest" -Duration (New-TimeSpan -Minutes 1)
            $baseline | Should -Not -BeNullOrEmpty

            # 3. Start monitoring
            $monitoring = Start-SystemMonitoring -MonitoringProfile Standard -Duration 1
            $monitoring | Should -Not -BeNullOrEmpty

            # 4. Collect metrics (using mocked performance counters)
            $metrics = Get-SystemPerformance -MetricType All -Duration 1
            $metrics | Should -Not -BeNullOrEmpty

            # 5. Check alerts (using mocked alert API)
            $alerts = Get-SystemAlerts
            $alerts | Should -Not -BeNull

            # 6. Generate dashboard
            $dashboard = Get-SystemDashboard
            $dashboard | Should -Not -BeNullOrEmpty

            # 7. Stop monitoring
            $stopResult = Stop-SystemMonitoring
            $stopResult | Should -Not -BeNullOrEmpty

            # 8. Export data to virtual file system
            $exportPath = "$($script:TestDataPath)/integration-export.json"
            $exportResult = Export-MonitoringData -OutputPath $exportPath
            $exportResult | Should -BeTrue

            # Verify file was created
            Test-Path $exportPath | Should -Be $true
        }
    }
}

# Cleanup after all tests
AfterAll {
    # Clean up test modules
    Remove-Module SystemMonitoring -Force -ErrorAction SilentlyContinue
    Remove-Module Logging -Force -ErrorAction SilentlyContinue
    
    # Final mock cleanup
    Clear-TestMockEnvironment
}