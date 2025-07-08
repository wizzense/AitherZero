#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive integration test for PatchManager v3.0

.DESCRIPTION
    Tests the complete PatchManager workflow including:
    - Module loading and function availability
    - Atomic operations and smart mode detection
    - Git workflow automation
    - Error handling and recovery
    - CI/CD integration compatibility

.PARAMETER TestMode
    Test mode: Quick, Standard, or Complete

.EXAMPLE
    ./test-patchmanager-integration.ps1 -TestMode Quick
#>

param(
    [ValidateSet('Quick', 'Standard', 'Complete')]
    [string]$TestMode = 'Standard'
)

$ErrorActionPreference = 'Stop'

# Test configuration
$TestConfig = @{
    TestRepo = Join-Path $PSScriptRoot "test-integration-repo"
    ModulePath = "./aither-core/modules/PatchManager"
    Results = @{
        Passed = 0
        Failed = 0
        Skipped = 0
        Tests = @()
    }
}

function Write-TestResult {
    param($TestName, $Result, $Details = "", $Duration = $null)

    $status = if ($Result) { "✅ PASS" } else { "❌ FAIL" }
    $durationText = if ($Duration) { " ($($Duration.TotalMilliseconds)ms)" } else { "" }

    Write-Host "$status $TestName$durationText" -ForegroundColor $(if ($Result) { 'Green' } else { 'Red' })

    if ($Details -and -not $Result) {
        Write-Host "  Details: $Details" -ForegroundColor Yellow
    }

    $TestConfig.Results.Tests += @{
        Name = $TestName
        Result = $Result
        Details = $Details
        Duration = $Duration
    }

    if ($Result) {
        $TestConfig.Results.Passed++
    } else {
        $TestConfig.Results.Failed++
    }
}

function Test-ModuleLoading {
    Write-Host "`n🔧 Testing Module Loading..." -ForegroundColor Cyan

    try {
        $startTime = Get-Date
        Import-Module $TestConfig.ModulePath -Force -ErrorAction Stop
        $duration = (Get-Date) - $startTime

        Write-TestResult "Module Import" $true "" $duration

        # Test core v3.0 functions
        $CoreFunctions = @('New-Patch', 'New-QuickFix', 'New-Feature', 'New-Hotfix', 'Get-SmartOperationMode', 'Invoke-AtomicOperation')

        foreach ($func in $CoreFunctions) {
            $exists = Get-Command $func -Module PatchManager -ErrorAction SilentlyContinue
            Write-TestResult "Function: $func" ($null -ne $exists)
        }

        # Test legacy compatibility
        $LegacyFunctions = @('Invoke-PatchWorkflow', 'Sync-GitBranch', 'New-PatchPR')

        foreach ($func in $LegacyFunctions) {
            $exists = Get-Command $func -Module PatchManager -ErrorAction SilentlyContinue
            Write-TestResult "Legacy Function: $func" ($null -ne $exists)
        }

    } catch {
        Write-TestResult "Module Import" $false $_.Exception.Message
    }
}

function Test-SmartModeDetection {
    Write-Host "`n🧠 Testing Smart Mode Detection..." -ForegroundColor Cyan

    try {
        # Test low-risk detection
        $startTime = Get-Date
        $analysis = Get-SmartOperationMode -PatchDescription "Fix typo in documentation"
        $duration = (Get-Date) - $startTime

        Write-TestResult "Smart Analysis Execution" $true "" $duration
        Write-TestResult "Low-risk Detection" ($analysis.RecommendedMode -eq "Simple")
        Write-TestResult "Risk Level Assessment" ($analysis.RiskLevel -in @("Low", "Medium"))
        Write-TestResult "Confidence Score" ($analysis.Confidence -gt 0.5)

        # Test high-risk detection
        $securityAnalysis = Get-SmartOperationMode -PatchDescription "Critical security fix for authentication bypass"
        Write-TestResult "High-risk Detection" ($securityAnalysis.RiskLevel -eq "High")
        Write-TestResult "PR Recommendation" ($securityAnalysis.ShouldCreatePR -eq $true)

        # Test feature detection
        $featureAnalysis = Get-SmartOperationMode -PatchDescription "Add new user dashboard feature"
        Write-TestResult "Feature Detection" ($featureAnalysis.ShouldCreatePR -eq $true)

    } catch {
        Write-TestResult "Smart Mode Detection" $false $_.Exception.Message
    }
}

function Test-AtomicOperations {
    Write-Host "`n⚛️  Testing Atomic Operations..." -ForegroundColor Cyan

    try {
        # Test successful atomic operation
        $startTime = Get-Date
        $testOp = {
            "Test atomic content" | Out-File -FilePath "atomic-test.txt"
            return "Success"
        }

        $result = Invoke-AtomicOperation -Operation $testOp -OperationName "Test Atomic"
        $duration = (Get-Date) - $startTime

        Write-TestResult "Atomic Operation Success" ($result.Success -eq $true) "" $duration
        Write-TestResult "Operation Result" ($result.Result -eq "Success")
        Write-TestResult "Context Capture" ($null -ne $result.Context.StartTime)

        # Test atomic operation with pre-conditions
        $preCondition = { $true }
        $result2 = Invoke-AtomicOperation -Operation $testOp -OperationName "Test With PreCondition" -PreConditions $preCondition
        Write-TestResult "Pre-condition Validation" ($result2.Success -eq $true)

        # Test failed pre-condition
        $failPreCondition = { $false }
        $result3 = Invoke-AtomicOperation -Operation $testOp -OperationName "Test Failed PreCondition" -PreConditions $failPreCondition
        Write-TestResult "Failed Pre-condition Handling" ($result3.Success -eq $false)

        # Clean up
        Remove-Item "atomic-test.txt" -Force -ErrorAction SilentlyContinue

    } catch {
        Write-TestResult "Atomic Operations" $false $_.Exception.Message
    }
}

function Test-PatchWorkflows {
    Write-Host "`n🔄 Testing Patch Workflows..." -ForegroundColor Cyan

    try {
        # Test dry-run patch
        $startTime = Get-Date
        $patchResult = New-Patch -Description "Test integration patch" -DryRun
        $duration = (Get-Date) - $startTime

        Write-TestResult "Dry-run Patch Creation" ($patchResult.Success -eq $true) "" $duration
        Write-TestResult "Dry-run Mode Detection" ($patchResult.DryRun -eq $true)
        Write-TestResult "Mode Assignment" ($null -ne $patchResult.Mode)

        # Test QuickFix
        $quickFixResult = New-QuickFix -Description "Test quick fix" -DryRun
        Write-TestResult "QuickFix Workflow" ($quickFixResult.Success -eq $true)

        # Test Feature workflow
        $featureResult = New-Feature -Description "Test feature implementation" -Changes { "Feature code" } -DryRun
        Write-TestResult "Feature Workflow" ($featureResult.Success -eq $true)

        # Test Hotfix workflow
        $hotfixResult = New-Hotfix -Description "Test critical hotfix" -Changes { "Hotfix code" } -DryRun
        Write-TestResult "Hotfix Workflow" ($hotfixResult.Success -eq $true)

        # Test legacy compatibility
        $legacyResult = Invoke-PatchWorkflow -PatchDescription "Legacy test" -DryRun
        Write-TestResult "Legacy Compatibility" ($legacyResult.Success -eq $true)

    } catch {
        Write-TestResult "Patch Workflows" $false $_.Exception.Message
    }
}

function Test-ErrorHandling {
    Write-Host "`n🛡️  Testing Error Handling..." -ForegroundColor Cyan

    try {
        # Test invalid operation
        $startTime = Get-Date
        $failOp = { throw "Simulated failure" }
        $result = Invoke-AtomicOperation -Operation $failOp -OperationName "Failing Test"
        $duration = (Get-Date) - $startTime

        Write-TestResult "Error Handling" ($result.Success -eq $false) "" $duration
        Write-TestResult "Error Message Capture" ($null -ne $result.Error)

        # Test invalid patch description
        try {
            $invalidResult = New-Patch -Description "" -DryRun
            Write-TestResult "Invalid Input Handling" ($invalidResult.Success -eq $false)
        } catch {
            Write-TestResult "Invalid Input Handling" $true  # Exception is expected
        }

        # Test rollback capability
        $rollbackOp = {
            "Temporary file" | Out-File -FilePath "rollback-test.txt"
            throw "Force rollback"
        }

        $rollbackResult = Invoke-AtomicOperation -Operation $rollbackOp -OperationName "Rollback Test"
        Write-TestResult "Rollback Mechanism" ($rollbackResult.Success -eq $false)
        Write-TestResult "State Preservation" (-not (Test-Path "rollback-test.txt"))

    } catch {
        Write-TestResult "Error Handling Test" $false $_.Exception.Message
    }
}

function Test-PerformanceMetrics {
    Write-Host "`n⚡ Testing Performance..." -ForegroundColor Cyan

    try {
        # Measure patch creation performance
        $iterations = if ($TestMode -eq 'Quick') { 3 } elseif ($TestMode -eq 'Standard') { 5 } else { 10 }
        $times = @()

        for ($i = 1; $i -le $iterations; $i++) {
            $startTime = Get-Date
            $result = New-Patch -Description "Performance test $i" -DryRun
            $endTime = Get-Date
            $times += ($endTime - $startTime).TotalMilliseconds
        }

        $avgTime = ($times | Measure-Object -Average).Average
        $maxTime = ($times | Measure-Object -Maximum).Maximum

        Write-TestResult "Average Performance" ($avgTime -lt 2000) "Avg: $([math]::Round($avgTime))ms"
        Write-TestResult "Maximum Performance" ($maxTime -lt 5000) "Max: $([math]::Round($maxTime))ms"

        # Test smart mode detection performance
        $smartStartTime = Get-Date
        $analysis = Get-SmartOperationMode -PatchDescription "Performance test analysis"
        $smartDuration = (Get-Date) - $smartStartTime

        Write-TestResult "Smart Mode Performance" ($smartDuration.TotalMilliseconds -lt 1000) "$([math]::Round($smartDuration.TotalMilliseconds))ms"

    } catch {
        Write-TestResult "Performance Testing" $false $_.Exception.Message
    }
}

function Test-GitIntegration {
    Write-Host "`n🔗 Testing Git Integration..." -ForegroundColor Cyan

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-TestResult "Git Availability" $false "Git not found in PATH"
        return
    }

    try {
        # Test git detection
        $gitCheck = git --version 2>&1
        Write-TestResult "Git Detection" ($LASTEXITCODE -eq 0) $gitCheck

        # Test repository detection (if in a git repo)
        $isRepo = git rev-parse --git-dir 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Repository Detection" $true

            # Test branch detection
            $currentBranch = git branch --show-current 2>$null
            Write-TestResult "Branch Detection" ($null -ne $currentBranch) "Branch: $currentBranch"

            # Test status detection
            $gitStatus = git status --porcelain 2>$null
            $hasChanges = $gitStatus -and ($gitStatus | Where-Object { $_ -match '\S' })
            Write-TestResult "Status Detection" $true "Changes: $(if ($hasChanges) { 'Yes' } else { 'No' })"
        } else {
            Write-TestResult "Repository Detection" $false "Not in a git repository"
        }

    } catch {
        Write-TestResult "Git Integration" $false $_.Exception.Message
    }
}

function Test-CICDCompatibility {
    Write-Host "`n🚀 Testing CI/CD Compatibility..." -ForegroundColor Cyan

    try {
        # Simulate CI environment
        $originalCI = $env:CI
        $env:CI = "true"

        try {
            $ciResult = New-Patch -Description "CI environment test" -DryRun
            Write-TestResult "CI Environment Handling" ($ciResult.Success -eq $true)

            # Test result serialization (important for CI)
            $serialized = $ciResult | ConvertTo-Json -Depth 3
            $deserialized = $serialized | ConvertFrom-Json
            Write-TestResult "Result Serialization" ($null -ne $deserialized.Success)

            # Test exit codes
            $successCode = if ($ciResult.Success) { 0 } else { 1 }
            Write-TestResult "Exit Code Handling" ($successCode -eq 0)

        } finally {
            if ($originalCI) {
                $env:CI = $originalCI
            } else {
                Remove-Item Env:CI -ErrorAction SilentlyContinue
            }
        }

    } catch {
        Write-TestResult "CI/CD Compatibility" $false $_.Exception.Message
    }
}

function Show-TestSummary {
    Write-Host "`n📊 Test Summary" -ForegroundColor Magenta
    Write-Host ("=" * 50) -ForegroundColor Magenta

    $total = $TestConfig.Results.Passed + $TestConfig.Results.Failed + $TestConfig.Results.Skipped
    $passRate = if ($total -gt 0) { [math]::Round(($TestConfig.Results.Passed / $total) * 100, 1) } else { 0 }

    Write-Host "Total Tests: $total" -ForegroundColor White
    Write-Host "Passed: $($TestConfig.Results.Passed)" -ForegroundColor Green
    Write-Host "Failed: $($TestConfig.Results.Failed)" -ForegroundColor Red
    Write-Host "Skipped: $($TestConfig.Results.Skipped)" -ForegroundColor Yellow
    Write-Host "Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 90) { 'Green' } elseif ($passRate -ge 70) { 'Yellow' } else { 'Red' })

    # Show failed tests
    if ($TestConfig.Results.Failed -gt 0) {
        Write-Host "`nFailed Tests:" -ForegroundColor Red
        $TestConfig.Results.Tests | Where-Object { -not $_.Result } | ForEach-Object {
            Write-Host "  ❌ $($_.Name): $($_.Details)" -ForegroundColor Red
        }
    }

    # Show performance metrics
    $durationTests = $TestConfig.Results.Tests | Where-Object { $null -ne $_.Duration }
    if ($durationTests.Count -gt 0) {
        $avgDuration = ($durationTests.Duration | Measure-Object -Property TotalMilliseconds -Average).Average
        Write-Host "`nPerformance:" -ForegroundColor Cyan
        Write-Host "  Average Duration: $([math]::Round($avgDuration))ms" -ForegroundColor White
    }

    # Overall result
    $success = $TestConfig.Results.Failed -eq 0
    Write-Host "`n$(if ($success) { '✅ ALL TESTS PASSED' } else { '❌ SOME TESTS FAILED' })" -ForegroundColor $(if ($success) { 'Green' } else { 'Red' })

    return $success
}

# Main execution
try {
    Write-Host "🧪 PatchManager v3.0 Integration Tests" -ForegroundColor Magenta
    Write-Host "Test Mode: $TestMode" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Gray

    # Run test suites based on mode
    Test-ModuleLoading
    Test-SmartModeDetection
    Test-AtomicOperations
    Test-PatchWorkflows
    Test-ErrorHandling

    if ($TestMode -in @('Standard', 'Complete')) {
        Test-PerformanceMetrics
        Test-GitIntegration
        Test-CICDCompatibility
    }

    if ($TestMode -eq 'Complete') {
        # Additional comprehensive tests would go here
        Write-Host "`n🔍 Complete mode: Additional tests not implemented yet" -ForegroundColor Yellow
    }

    # Show summary and exit with appropriate code
    $success = Show-TestSummary
    exit $(if ($success) { 0 } else { 1 })

} catch {
    Write-Host "`n💥 Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    exit 1
}
