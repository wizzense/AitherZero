#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive bulletproof test suite for all CoreApp modules and components

.DESCRIPTION
    This master test suite validates:
    - All module functionality and integration
    - Error handling and resilience
    - Performance benchmarks
    - Cross-platform compatibility
    - Non-interactive automation
    - Exit code consistency
    - Logging standards
    - Configuration handling

.NOTES
    This is the primary bulletproof validation suite for the entire CoreApp ecosystem
#>

BeforeAll {
    # Set up comprehensive test environment
    $script:ProjectRoot = $env:PROJECT_ROOT
    if (-not $script:ProjectRoot) {
        $script:ProjectRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
    }

    # Test infrastructure paths
    $script:CoreAppPath = Join-Path $script:ProjectRoot "aither-core"
    $script:ModulesPath = Join-Path $script:ProjectRoot "core-runner/modules"
    $script:TestLogDir = Join-Path $script:ProjectRoot "logs/bulletproof-master"
    $script:ConfigFile = Join-Path $script:CoreAppPath "default-config.json"

    # Ensure test log directory exists
    if (-not (Test-Path $script:TestLogDir)) {
        New-Item -ItemType Directory -Path $script:TestLogDir -Force | Out-Null
    }

    # Track test results globally
    $script:TestResults = @{
        Modules = @{}
        Performance = @{}
        Integration = @{}
        ErrorHandling = @{}
        Summary = @{
            StartTime = Get-Date
            TotalTests = 0
            PassedTests = 0
            FailedTests = 0
            SkippedTests = 0
        }
    }

    # Enhanced test execution function
    function Invoke-MasterTest {
        param(
            [string]$Category,
            [string]$TestName,
            [scriptblock]$TestScript,
            [hashtable]$ExpectedResults = @{},
            [int]$TimeoutSeconds = 120
        )

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
        $logFile = Join-Path $script:TestLogDir "master-$Category-$TestName-$timestamp.log"

        $testResult = @{
            Category = $Category
            TestName = $TestName
            StartTime = Get-Date
            LogFile = $logFile
            Success = $false
            Duration = 0
            Output = ""
            Error = ""
            Details = @{}
        }

        try {
            $startTime = Get-Date

            # Execute test with timeout
            $job = Start-Job -ScriptBlock $TestScript
            $completed = Wait-Job $job -Timeout $TimeoutSeconds

            if ($completed) {
                $output = Receive-Job $job
                $testResult.Output = $output | Out-String
                $testResult.Success = $true
            } else {
                Remove-Job $job -Force
                throw "Test timed out after $TimeoutSeconds seconds"
            }

            $testResult.EndTime = Get-Date
            $testResult.Duration = ($testResult.EndTime - $testResult.StartTime).TotalMilliseconds

            # Validate expected results
            foreach ($key in $ExpectedResults.Keys) {
                $expected = $ExpectedResults[$key]
                $actual = $testResult.Output

                switch ($key) {
                    'Contains' {
                        if ($actual -notmatch $expected) {
                            throw "Expected output to contain: $expected"
                        }
                    }
                    'NotContains' {
                        if ($actual -match $expected) {
                            throw "Expected output to NOT contain: $expected"
                        }
                    }
                    'MaxDuration' {
                        if ($testResult.Duration -gt $expected) {
                            throw "Test exceeded maximum duration: $($testResult.Duration)ms > ${expected}ms"
                        }
                    }
                }
            }

        } catch {
            $testResult.Success = $false
            $testResult.Error = $_.Exception.Message
            $testResult.EndTime = Get-Date
            $testResult.Duration = ($testResult.EndTime - $testResult.StartTime).TotalMilliseconds
        } finally {
            Remove-Job $job -Force -ErrorAction SilentlyContinue
        }

        # Log detailed results
        $logContent = @"
=== Master Bulletproof Test Results ===
Category: $($testResult.Category)
Test Name: $($testResult.TestName)
Start Time: $($testResult.StartTime)
End Time: $($testResult.EndTime)
Duration: $($testResult.Duration)ms
Success: $($testResult.Success)

=== Test Output ===
$($testResult.Output)

=== Error Information ===
$($testResult.Error)

=== Expected Results Validation ===
$($ExpectedResults | ConvertTo-Json -Depth 2)

=== End of Master Test Log ===
"@
        $logContent | Out-File -FilePath $logFile -Encoding UTF8

        # Update global results
        $script:TestResults.Summary.TotalTests++
        if ($testResult.Success) {
            $script:TestResults.Summary.PassedTests++
        } else {
            $script:TestResults.Summary.FailedTests++
        }

        if (-not $script:TestResults[$testResult.Category]) {
            $script:TestResults[$testResult.Category] = @{}
        }
        $script:TestResults[$testResult.Category][$testResult.TestName] = $testResult

        return $testResult
    }
}

Describe "CoreApp Master Bulletproof Tests" -Tag @('Master', 'Bulletproof', 'Comprehensive') {

    Context "Module Loading and Initialization" {

        It "Should import CoreApp module successfully" {
            $result = Invoke-MasterTest -Category "Modules" -TestName "CoreApp-Import" -TestScript {
                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force
                Get-Module CoreApp | Should -Not -BeNullOrEmpty
                return "CoreApp module imported successfully"
            } -ExpectedResults @{
                Contains = "imported successfully"
                MaxDuration = 15000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ CoreApp import test: $($result.LogFile)" -ForegroundColor Green
        }

        It "Should initialize CoreApp ecosystem" {
            $result = Invoke-MasterTest -Category "Modules" -TestName "CoreApp-Initialize" -TestScript {
                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force
                $initResult = Initialize-CoreApplication -RequiredOnly
                $initResult | Should -Be $true
                return "CoreApp ecosystem initialized: $initResult"
            } -ExpectedResults @{
                Contains = "initialized"
                MaxDuration = 30000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ CoreApp initialization test: $($result.LogFile)" -ForegroundColor Green
        }

        It "Should load required modules successfully" {
            $result = Invoke-MasterTest -Category "Modules" -TestName "Required-Modules" -TestScript {
                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force
                $moduleResult = Import-CoreModules -RequiredOnly
                $moduleResult.ImportedCount | Should -BeGreaterThan 0
                return "Required modules loaded: $($moduleResult.ImportedCount)"
            } -ExpectedResults @{
                Contains = "modules loaded"
                MaxDuration = 45000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Required modules test: $($result.LogFile)" -ForegroundColor Green
        }

        It "Should validate module status and health" {
            $result = Invoke-MasterTest -Category "Modules" -TestName "Module-Status" -TestScript {
                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force
                Initialize-CoreApplication -RequiredOnly
                $status = Get-CoreModuleStatus
                $status | Should -Not -BeNullOrEmpty
                $loadedModules = $status | Where-Object { $_.Loaded }
                $loadedModules.Count | Should -BeGreaterThan 0
                return "Module status checked: $($loadedModules.Count) modules loaded"
            } -ExpectedResults @{
                Contains = "modules loaded"
                MaxDuration = 20000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Module status test: $($result.LogFile)" -ForegroundColor Green
        }
    }

    Context "Core Functionality Testing" {

        It "Should execute core-runner in non-interactive mode" {
            $result = Invoke-MasterTest -Category "Core" -TestName "NonInteractive-Execution" -TestScript {
                $coreRunnerScript = Join-Path $using:CoreAppPath "core-runner.ps1"
                $process = Start-Process -FilePath "pwsh" -ArgumentList @("-File", $coreRunnerScript, "-NonInteractive", "-Verbosity", "detailed", "-WhatIf") -NoNewWindow -Wait -PassThru
                $process.ExitCode | Should -Be 0
                return "Core-runner executed with exit code: $($process.ExitCode)"
            } -ExpectedResults @{
                Contains = "exit code: 0"
                MaxDuration = 60000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Non-interactive execution test: $($result.LogFile)" -ForegroundColor Green
        }

        It "Should handle auto mode execution" {
            $result = Invoke-MasterTest -Category "Core" -TestName "Auto-Mode" -TestScript {
                $coreRunnerScript = Join-Path $using:CoreAppPath "core-runner.ps1"
                $process = Start-Process -FilePath "pwsh" -ArgumentList @("-File", $coreRunnerScript, "-NonInteractive", "-Auto", "-WhatIf", "-Verbosity", "silent") -NoNewWindow -Wait -PassThru
                $process.ExitCode | Should -Be 0
                return "Auto mode executed with exit code: $($process.ExitCode)"
            } -ExpectedResults @{
                Contains = "exit code: 0"
                MaxDuration = 90000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Auto mode test: $($result.LogFile)" -ForegroundColor Green
        }

        It "Should validate configuration handling" {
            $result = Invoke-MasterTest -Category "Core" -TestName "Configuration" -TestScript {
                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force
                $config = Get-CoreConfiguration -ConfigPath $using:ConfigFile
                $config | Should -Not -BeNullOrEmpty
                $config.PSObject.Properties.Count | Should -BeGreaterThan 0
                return "Configuration loaded with $($config.PSObject.Properties.Count) properties"
            } -ExpectedResults @{
                Contains = "properties"
                MaxDuration = 10000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Configuration test: $($result.LogFile)" -ForegroundColor Green
        }

        It "Should perform health checks successfully" {
            $result = Invoke-MasterTest -Category "Core" -TestName "Health-Check" -TestScript {
                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force
                $health = Test-CoreApplicationHealth
                $health | Should -Be $true
                return "Health check result: $health"
            } -ExpectedResults @{
                Contains = "True"
                MaxDuration = 15000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Health check test: $($result.LogFile)" -ForegroundColor Green
        }
    }

    Context "Error Handling and Resilience" {

        It "Should handle missing configuration files gracefully" {
            $result = Invoke-MasterTest -Category "ErrorHandling" -TestName "Missing-Config" -TestScript {
                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force
                $fakeConfigPath = Join-Path $using:TestLogDir "nonexistent-config.json"
                try {
                    Get-CoreConfiguration -ConfigPath $fakeConfigPath
                    return "Should have thrown error for missing config"
                } catch {
                    return "Correctly handled missing config: $($_.Exception.Message)"
                }
            } -ExpectedResults @{
                Contains = "Correctly handled"
                MaxDuration = 5000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Missing config test: $($result.LogFile)" -ForegroundColor Green
        }

        It "Should handle module import failures gracefully" {
            $result = Invoke-MasterTest -Category "ErrorHandling" -TestName "Module-Import-Failure" -TestScript {
                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force
                # Try to import a non-existent module path
                $moduleResult = Import-CoreModules -Force
                # Should still work even if some modules fail
                $moduleResult | Should -Not -BeNullOrEmpty
                return "Module import handled failures: Failed=$($moduleResult.FailedCount), Imported=$($moduleResult.ImportedCount)"
            } -ExpectedResults @{
                Contains = "Module import handled"
                MaxDuration = 60000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Module import failure test: $($result.LogFile)" -ForegroundColor Green
        }

        It "Should handle concurrent access safely" {
            $result = Invoke-MasterTest -Category "ErrorHandling" -TestName "Concurrent-Access" -TestScript {
                $jobs = 1..3 | ForEach-Object {
                    Start-Job -ScriptBlock {
                        Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force
                        $health = Test-CoreApplicationHealth
                        return $health
                    }
                }
                $results = $jobs | Wait-Job | Receive-Job
                $jobs | Remove-Job

                $results | Should -HaveCount 3
                $results | Should -Not -Contain $false
                return "Concurrent access test: $($results.Count) jobs completed successfully"
            } -ExpectedResults @{
                Contains = "jobs completed successfully"
                MaxDuration = 30000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Concurrent access test: $($result.LogFile)" -ForegroundColor Green
        }
    }

    Context "Performance and Scalability" {

        It "Should meet performance benchmarks for module loading" {
            $result = Invoke-MasterTest -Category "Performance" -TestName "Module-Loading-Speed" -TestScript {
                $startTime = Get-Date
                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force
                Initialize-CoreApplication -RequiredOnly
                $endTime = Get-Date
                $duration = ($endTime - $startTime).TotalMilliseconds

                $duration | Should -BeLessThan 30000
                return "Module loading completed in ${duration}ms"
            } -ExpectedResults @{
                Contains = "completed in"
                MaxDuration = 35000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Module loading speed test: $($result.LogFile)" -ForegroundColor Green
        }

        It "Should handle memory usage efficiently" {
            $result = Invoke-MasterTest -Category "Performance" -TestName "Memory-Usage" -TestScript {
                $beforeMemory = [System.GC]::GetTotalMemory($false)

                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force
                Initialize-CoreApplication -RequiredOnly
                $moduleStatus = Get-CoreModuleStatus

                $afterMemory = [System.GC]::GetTotalMemory($true)
                $memoryIncrease = $afterMemory - $beforeMemory

                $memoryIncrease | Should -BeLessThan 100MB
                return "Memory increase: $('{0:N0}' -f $memoryIncrease) bytes"
            } -ExpectedResults @{
                Contains = "Memory increase"
                MaxDuration = 45000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Memory usage test: $($result.LogFile)" -ForegroundColor Green
        }

        It "Should scale with multiple operations" {
            $result = Invoke-MasterTest -Category "Performance" -TestName "Scalability" -TestScript {
                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force
                Initialize-CoreApplication -RequiredOnly

                $operations = 1..10 | ForEach-Object {
                    $startTime = Get-Date
                    $health = Test-CoreApplicationHealth
                    $status = Get-CoreModuleStatus
                    $endTime = Get-Date
                    ($endTime - $startTime).TotalMilliseconds
                }

                $avgTime = ($operations | Measure-Object -Average).Average
                $avgTime | Should -BeLessThan 1000
                return "Average operation time: ${avgTime}ms over $($operations.Count) operations"
            } -ExpectedResults @{
                Contains = "Average operation time"
                MaxDuration = 60000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Scalability test: $($result.LogFile)" -ForegroundColor Green
        }
    }

    Context "Cross-Platform Compatibility" {

        It "Should detect platform correctly" {
            $result = Invoke-MasterTest -Category "Platform" -TestName "Platform-Detection" -TestScript {
                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force
                $platform = Get-PlatformInfo
                $platform | Should -BeIn @('Windows', 'Linux', 'macOS')
                return "Platform detected: $platform"
            } -ExpectedResults @{
                Contains = "Platform detected"
                MaxDuration = 5000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Platform detection test: $($result.LogFile)" -ForegroundColor Green
        }

        It "Should handle paths correctly on current platform" {
            $result = Invoke-MasterTest -Category "Platform" -TestName "Path-Handling" -TestScript {
                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force

                # Test various path operations
                $testPath = Join-Path $using:ProjectRoot "test"
                $testPath | Should -Not -BeNullOrEmpty

                $configPath = Join-Path $using:CoreAppPath "default-config.json"
                Test-Path $configPath | Should -Be $true

                return "Path handling validated for current platform"
            } -ExpectedResults @{
                Contains = "validated"
                MaxDuration = 10000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Path handling test: $($result.LogFile)" -ForegroundColor Green
        }
    }

    Context "Integration and End-to-End Testing" {

        It "Should complete full workflow successfully" {
            $result = Invoke-MasterTest -Category "Integration" -TestName "Full-Workflow" -TestScript {
                # Complete end-to-end workflow
                Import-Module "$using:CoreAppPath/CoreApp.psm1" -Force

                # Initialize
                $initResult = Initialize-CoreApplication -RequiredOnly
                $initResult | Should -Be $true

                # Check status
                $status = Get-CoreModuleStatus
                $status | Should -Not -BeNullOrEmpty

                # Health check
                $health = Test-CoreApplicationHealth
                $health | Should -Be $true

                # Configuration
                $config = Get-CoreConfiguration
                $config | Should -Not -BeNullOrEmpty

                return "Full workflow completed successfully"
            } -ExpectedResults @{
                Contains = "completed successfully"
                MaxDuration = 60000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ Full workflow test: $($result.LogFile)" -ForegroundColor Green
        }

        It "Should integrate with external tools" {
            $result = Invoke-MasterTest -Category "Integration" -TestName "External-Tools" -TestScript {
                # Test integration with git, PowerShell modules, etc.
                $gitAvailable = (Get-Command git -ErrorAction SilentlyContinue) -ne $null
                $pesterAvailable = (Get-Module Pester -ListAvailable) -ne $null

                $integrations = @()
                if ($gitAvailable) { $integrations += "Git" }
                if ($pesterAvailable) { $integrations += "Pester" }

                $integrations.Count | Should -BeGreaterThan 0
                return "External tool integration: $($integrations -join ', ')"
            } -ExpectedResults @{
                Contains = "integration"
                MaxDuration = 15000
            }

            $result.Success | Should -Be $true
            Write-Host "✅ External tools test: $($result.LogFile)" -ForegroundColor Green
        }
    }
}

AfterAll {
    # Generate comprehensive master test report
    $script:TestResults.Summary.EndTime = Get-Date
    $script:TestResults.Summary.TotalDuration = ($script:TestResults.Summary.EndTime - $script:TestResults.Summary.StartTime).TotalMinutes

    Write-Host "`n🎯 Master Bulletproof Test Suite Summary:" -ForegroundColor Cyan
    Write-Host "⏱️  Total Duration: $($script:TestResults.Summary.TotalDuration.ToString('F2')) minutes" -ForegroundColor Yellow
    Write-Host "📊 Total Tests: $($script:TestResults.Summary.TotalTests)" -ForegroundColor Yellow
    Write-Host "✅ Passed: $($script:TestResults.Summary.PassedTests)" -ForegroundColor Green
    Write-Host " FAILFailed: $($script:TestResults.Summary.FailedTests)" -ForegroundColor Red
    Write-Host "⏭️  Skipped: $($script:TestResults.Summary.SkippedTests)" -ForegroundColor Yellow

    # Calculate success rate
    $successRate = if ($script:TestResults.Summary.TotalTests -gt 0) {
        ($script:TestResults.Summary.PassedTests / $script:TestResults.Summary.TotalTests) * 100
    } else { 0 }

    Write-Host "🎯 Success Rate: $($successRate.ToString('F1'))%" -ForegroundColor $(if ($successRate -ge 95) { 'Green' } elseif ($successRate -ge 80) { 'Yellow' } else { 'Red' })

    # Category breakdown
    Write-Host "`n📋 Test Categories:" -ForegroundColor Cyan
    foreach ($category in $script:TestResults.Keys) {
        if ($category -ne 'Summary') {
            $categoryTests = $script:TestResults[$category]
            $categoryCount = $categoryTests.Count
            $categoryPassed = ($categoryTests.Values | Where-Object { $_.Success }).Count
            Write-Host "  • $category`: $categoryPassed/$categoryCount tests passed" -ForegroundColor Gray
        }
    }

    # Performance metrics
    if ($script:TestResults.Performance.Count -gt 0) {
        Write-Host "`n⚡ Performance Metrics:" -ForegroundColor Cyan
        foreach ($perfTest in $script:TestResults.Performance.Values) {
            Write-Host "  • $($perfTest.TestName): $($perfTest.Duration.ToString('F0'))ms" -ForegroundColor Gray
        }
    }

    # Log files summary
    if (Test-Path $script:TestLogDir) {
        $logFiles = Get-ChildItem -Path $script:TestLogDir -Filter "master-*.log" | Sort-Object LastWriteTime
        if ($logFiles) {
            Write-Host "`n📂 Test Log Files ($($logFiles.Count) files):" -ForegroundColor Yellow
            $totalLogSize = ($logFiles | Measure-Object -Property Length -Sum).Sum
            Write-Host "  📂 Location: $script:TestLogDir" -ForegroundColor Gray
            Write-Host "  📊 Total Size: $([math]::Round($totalLogSize / 1KB, 2))KB" -ForegroundColor Gray

            # Show recent logs
            $recentLogs = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 5
            Write-Host "  📄 Recent Logs:" -ForegroundColor Gray
            $recentLogs | ForEach-Object {
                $size = [math]::Round($_.Length / 1KB, 2)
                Write-Host "    • $($_.Name) (${size}KB)" -ForegroundColor DarkGray
            }
        }
    }

    # Final status
    Write-Host "`n🚀 Bulletproof Validation Status:" -ForegroundColor Cyan
    if ($successRate -ge 95) {
        Write-Host "✅ BULLETPROOF - All systems validated and ready for production" -ForegroundColor Green
    } elseif ($successRate -ge 80) {
        Write-Host "⚠️  MOSTLY BULLETPROOF - Minor issues detected, review recommended" -ForegroundColor Yellow
    } else {
        Write-Host " FAILNOT BULLETPROOF - Critical issues detected, remediation required" -ForegroundColor Red
    }

    # Export detailed results
    $reportPath = Join-Path $script:TestLogDir "master-bulletproof-report.json"
    $script:TestResults | ConvertTo-Json -Depth 5 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "`n📄 Detailed report saved to: $reportPath" -ForegroundColor Cyan
}
