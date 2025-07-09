#Requires -Version 7.0

<#
.SYNOPSIS
    Examples demonstrating the enhanced TestingFramework capabilities

.DESCRIPTION
    This script provides comprehensive examples of how to use the enhanced TestingFramework
    module including automated test generation, README.md updates, monitoring, and integration testing.

.NOTES
    Run these examples to learn how to leverage the full power of the TestingFramework module
#>

# Import the TestingFramework module
Import-Module "./TestingFramework.psm1" -Force

Write-Host "🧪 TestingFramework v2.1.0 - Enhanced Capabilities Examples" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Example 1: Automated Test Generation
Write-Host "`n📋 Example 1: Automated Test Generation" -ForegroundColor Green
Write-Host "Generating tests for modules that don't have them..." -ForegroundColor Yellow

# Generate tests for a specific module
Write-Host "`n🔧 Generating tests for ProgressTracking module..."
$generationResult = Invoke-AutomatedTestGeneration -ModuleName "ProgressTracking" -UseDistributedTests -IncludeIntegrationTests -DryRun

Write-Host "Generation Result:"
Write-Host "  Total Modules: $($generationResult.Summary.Total)"
Write-Host "  Generated: $($generationResult.Summary.Generated)"
Write-Host "  Skipped: $($generationResult.Summary.Skipped)"
Write-Host "  Errors: $($generationResult.Summary.Errors)"

# Bulk test generation for all modules
Write-Host "`n🏭 Bulk test generation for all modules without tests..."
$bulkResult = Invoke-AutomatedTestGeneration -UseDistributedTests -IncludeIntegrationTests -DryRun

Write-Host "Bulk Generation Result:"
Write-Host "  Total Modules: $($bulkResult.Summary.Total)"
Write-Host "  Generated: $($bulkResult.Summary.Generated)"
Write-Host "  Skipped: $($bulkResult.Summary.Skipped)"
Write-Host "  Errors: $($bulkResult.Summary.Errors)"

# Example 2: README.md Test Status Updates
Write-Host "`n📝 Example 2: README.md Test Status Updates" -ForegroundColor Green
Write-Host "Updating README.md files with test status..." -ForegroundColor Yellow

# First, run some tests to get results
Write-Host "`n🧪 Running quick tests to generate test results..."
$testResults = Invoke-UnifiedTestExecution -TestSuite "Quick" -TestProfile "Development" -GenerateReport

# Update README.md files with test results
Write-Host "`n📄 Updating README.md files with test results..."
Update-ReadmeTestStatus -UpdateAll -TestResults $testResults

# Update specific module README
Write-Host "`n📑 Updating ProgressTracking module README..."
$progressResults = $testResults | Where-Object { $_.Module -eq "ProgressTracking" }
if ($progressResults) {
    Update-ReadmeTestStatus -ModulePath "./ProgressTracking" -TestResults $progressResults
}

# Example 3: Test Execution Monitoring
Write-Host "`n🔍 Example 3: Test Execution Monitoring" -ForegroundColor Green
Write-Host "Starting comprehensive test monitoring..." -ForegroundColor Yellow

# Start monitoring with README updates and report generation
Write-Host "`n📊 Starting monitored test execution..."
$monitoringResult = Start-TestExecutionMonitoring -TestSuite "Unit" -UpdateReadme -GenerateReport -ModuleFilter @("ProgressTracking", "ModuleCommunication")

Write-Host "Monitoring Result:"
Write-Host "  Total Runs: $($monitoringResult.Metrics.TotalRuns)"
Write-Host "  Average Time: $($monitoringResult.Metrics.AverageTime.ToString('0.00'))s"
Write-Host "  Success Rate: $($monitoringResult.Metrics.SuccessRate)%"
Write-Host "  Failure Rate: $($monitoringResult.Metrics.FailureRate)%"

# Example 4: Integration Testing
Write-Host "`n🔗 Example 4: Integration Testing" -ForegroundColor Green
Write-Host "Running integration tests between modules..." -ForegroundColor Yellow

# Run integration tests
Write-Host "`n🔄 Running integration tests..."
$integrationResults = Invoke-UnifiedTestExecution -TestSuite "Integration" -TestProfile "Development" -GenerateReport

Write-Host "Integration Test Results:"
foreach ($result in $integrationResults) {
    $status = if ($result.TestsFailed -eq 0) { "✅ PASS" } else { "❌ FAIL" }
    Write-Host "  $($result.Module) - $($result.Phase): $status ($($result.TestsPassed)/$($result.TestsRun))"
}

# Example 5: Performance Testing
Write-Host "`n⚡ Example 5: Performance Testing" -ForegroundColor Green
Write-Host "Running performance tests on critical modules..." -ForegroundColor Yellow

# Run performance tests
Write-Host "`n🏃‍♂️ Running performance tests..."
$performanceResults = Invoke-UnifiedTestExecution -TestSuite "Performance" -TestProfile "Development" -GenerateReport

Write-Host "Performance Test Results:"
foreach ($result in $performanceResults) {
    $avgTime = if ($result.TestsRun -gt 0) { ($result.Duration / $result.TestsRun).ToString('0.00') } else { "N/A" }
    Write-Host "  $($result.Module): $avgTime seconds average per test"
}

# Example 6: Custom Test Configuration
Write-Host "`n⚙️ Example 6: Custom Test Configuration" -ForegroundColor Green
Write-Host "Using custom test configurations..." -ForegroundColor Yellow

# Get test configuration for different profiles
Write-Host "`n📋 Development Profile Configuration:"
$devConfig = Get-TestConfiguration -Profile "Development"
Write-Host "  Verbosity: $($devConfig.Verbosity)"
Write-Host "  Timeout: $($devConfig.TimeoutMinutes) minutes"
Write-Host "  Parallel Jobs: $($devConfig.ParallelJobs)"
Write-Host "  Coverage Enabled: $($devConfig.EnableCoverage)"

Write-Host "`n📋 CI Profile Configuration:"
$ciConfig = Get-TestConfiguration -Profile "CI"
Write-Host "  Verbosity: $($ciConfig.Verbosity)"
Write-Host "  Timeout: $($ciConfig.TimeoutMinutes) minutes"
Write-Host "  Retry Count: $($ciConfig.RetryCount)"
Write-Host "  Coverage Threshold: $($ciConfig.CoverageThreshold)%"

# Example 7: Module Discovery and Analysis
Write-Host "`n🔍 Example 7: Module Discovery and Analysis" -ForegroundColor Green
Write-Host "Discovering and analyzing modules..." -ForegroundColor Yellow

# Discover modules
Write-Host "`n🔎 Discovering modules..."
$discoveredModules = Get-DiscoveredModules -IncludeDistributedTests -IncludeCentralizedTests

Write-Host "Module Discovery Results:"
Write-Host "  Total Modules: $($discoveredModules.Count)"

$testStrategies = $discoveredModules | Group-Object -Property { $_.TestDiscovery.TestStrategy }
foreach ($strategy in $testStrategies) {
    Write-Host "  $($strategy.Name): $($strategy.Count) modules"
}

# Analyze a specific module
Write-Host "`n🔬 Analyzing ProgressTracking module..."
$progressTrackingPath = "./ProgressTracking"
if (Test-Path $progressTrackingPath) {
    $moduleAnalysis = Get-ModuleAnalysis -ModulePath $progressTrackingPath -ModuleName "ProgressTracking"
    Write-Host "Module Analysis Results:"
    Write-Host "  Module Type: $($moduleAnalysis.ModuleType)"
    Write-Host "  Exported Functions: $($moduleAnalysis.ExportedFunctions.Count)"
    Write-Host "  Has Manifest: $($moduleAnalysis.HasManifest)"
    Write-Host "  Has Private/Public: $($moduleAnalysis.HasPrivatePublic)"
    Write-Host "  Description: $($moduleAnalysis.Description)"
}

# Example 8: Event System
Write-Host "`n📡 Example 8: Event System Usage" -ForegroundColor Green
Write-Host "Demonstrating event system..." -ForegroundColor Yellow

# Register event handler
Write-Host "`n📬 Registering event handler..."
Register-TestEventHandler -EventType "TestCompleted" -Handler {
    param($EventData)
    Write-Host "  📨 Event received: Test completed for module $($EventData.ModuleName)" -ForegroundColor Magenta
}

# Submit test event
Write-Host "`n📤 Submitting test event..."
Submit-TestEvent -EventType "TestCompleted" -Data @{
    ModuleName = "ExampleModule"
    TestsRun = 10
    TestsPassed = 8
    TestsFailed = 2
    Duration = 5.5
}

# Get event history
Write-Host "`n📜 Getting event history..."
$events = Get-TestEvents -EventType "TestCompleted"
Write-Host "Event History: $($events.Count) events found"

# Example 9: Test Providers
Write-Host "`n🔌 Example 9: Test Providers" -ForegroundColor Green
Write-Host "Working with test providers..." -ForegroundColor Yellow

# Register a test provider
Write-Host "`n📝 Registering test provider..."
Register-TestProvider -ModuleName "CustomTestProvider" -TestTypes @("Unit", "Integration") -Handler {
    param($TestType, $ModuleName)
    Write-Host "  🔧 Custom test provider handling $TestType tests for $ModuleName" -ForegroundColor Cyan
}

# Get registered providers
Write-Host "`n📋 Getting registered test providers..."
$providers = Get-RegisteredTestProviders
Write-Host "Registered Providers: $($providers.Count)"

# Example 10: VS Code Integration
Write-Host "`n💻 Example 10: VS Code Integration" -ForegroundColor Green
Write-Host "Generating VS Code compatible test results..." -ForegroundColor Yellow

# Export VS Code test results
Write-Host "`n📊 Exporting VS Code test results..."
Export-VSCodeTestResults -Results $testResults -OutputPath "./tests/results"

# Example 11: Complete Workflow
Write-Host "`n🔄 Example 11: Complete Testing Workflow" -ForegroundColor Green
Write-Host "Demonstrating complete testing workflow..." -ForegroundColor Yellow

Write-Host "`n🎯 Complete Workflow Steps:"
Write-Host "1. Generate missing tests"
Write-Host "2. Run comprehensive tests"
Write-Host "3. Update README.md files"
Write-Host "4. Generate reports"
Write-Host "5. Monitor execution"

# Step 1: Generate missing tests (dry run)
Write-Host "`n📋 Step 1: Generate missing tests..."
$generationResult = Invoke-AutomatedTestGeneration -UseDistributedTests -IncludeIntegrationTests -DryRun

# Step 2: Run comprehensive tests
Write-Host "`n🧪 Step 2: Run comprehensive tests..."
$comprehensiveResults = Invoke-UnifiedTestExecution -TestSuite "All" -TestProfile "Development" -GenerateReport -Parallel

# Step 3: Update README.md files
Write-Host "`n📝 Step 3: Update README.md files..."
Update-ReadmeTestStatus -UpdateAll -TestResults $comprehensiveResults

# Step 4: Generate reports
Write-Host "`n📊 Step 4: Generate reports..."
$reportPath = New-TestReport -Results $comprehensiveResults -OutputPath "./tests/results" -TestSuite "All"

# Step 5: Monitor execution (summary)
Write-Host "`n🔍 Step 5: Monitoring summary..."
$totalTests = ($comprehensiveResults | Measure-Object -Property TestsRun -Sum).Sum
$passedTests = ($comprehensiveResults | Measure-Object -Property TestsPassed -Sum).Sum
$failedTests = ($comprehensiveResults | Measure-Object -Property TestsFailed -Sum).Sum
$successRate = if ($totalTests -gt 0) { [Math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }

Write-Host "Final Results:"
Write-Host "  Total Tests: $totalTests"
Write-Host "  Passed: $passedTests ✅"
Write-Host "  Failed: $failedTests ❌"
Write-Host "  Success Rate: $successRate%"
Write-Host "  Report: $reportPath"

Write-Host "`n🎉 TestingFramework Examples Complete!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

# Summary of key capabilities
Write-Host "`n📋 Key TestingFramework v2.1.0 Capabilities:" -ForegroundColor Cyan
Write-Host "✅ Automated test generation for modules without tests"
Write-Host "✅ Automatic README.md status updates with test results"
Write-Host "✅ Real-time test execution monitoring"
Write-Host "✅ Integration testing between modules"
Write-Host "✅ Performance testing for critical modules"
Write-Host "✅ Comprehensive reporting and analytics"
Write-Host "✅ Event-driven architecture"
Write-Host "✅ VS Code integration"
Write-Host "✅ Parallel test execution"
Write-Host "✅ Cross-platform compatibility"
Write-Host "✅ Module discovery and analysis"
Write-Host "✅ Custom test providers"
Write-Host "✅ Complete workflow automation"

Write-Host "`n📚 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Run: ./tests/Run-Tests.ps1 -All to execute all tests"
Write-Host "2. Use: Update-ReadmeTestStatus -UpdateAll to update all README files"
Write-Host "3. Try: Start-TestExecutionMonitoring -TestSuite All -UpdateReadme -GenerateReport"
Write-Host "4. Generate: Invoke-AutomatedTestGeneration -UseDistributedTests -IncludeIntegrationTests"

Write-Host "`n🚀 The TestingFramework is now ready for enterprise-grade testing!" -ForegroundColor Green