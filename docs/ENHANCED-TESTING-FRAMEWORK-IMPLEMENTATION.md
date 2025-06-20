# Enhanced TestingFramework Implementation Plan

## 🎯 **Immediate Implementation: Enhanced TestingFramework Module**

This is the concrete implementation plan for transforming the TestingFramework module into the central orchestrator for all testing activities.

### **New Enhanced TestingFramework.psm1 Structure**

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    Integrated Testing Framework for OpenTofu Lab Automation

.DESCRIPTION
    Central orchestrator that leverages all project modules to provide:
    - Unified test discovery and execution
    - Intelligent parallelization
    - Environment setup and teardown
    - Comprehensive reporting
    - CI/CD integration
#>

# Import dependencies
$script:ModulePath = "$env:PWSH_MODULES_PATH"
$script:ProjectRoot = $env:PROJECT_ROOT

# Core Integration Functions
function Invoke-IntegratedTesting {
    [CmdletBinding()]
    param(
        [ValidateSet('Discovery', 'Unit', 'Integration', 'Performance', 'Smoke', 'All')]
        [string]$TestSuite = 'Unit',

        [ValidateSet('Sequential', 'Parallel', 'Intelligent')]
        [string]$ExecutionMode = 'Intelligent',

        [ValidateSet('Process', 'Container', 'None')]
        [string]$IsolationLevel = 'Process',

        [string]$OutputPath = './tests/results',
        [switch]$SetupEnvironment,
        [switch]$GenerateReport,
        [switch]$CreatePatchIfFailures,
        [switch]$VSCodeIntegration,
        [switch]$CleanupAfter
    )

    Write-CustomLog "Starting integrated testing: Suite=$TestSuite, Mode=$ExecutionMode" -Level INFO

    try {
        # Phase 1: Environment Setup
        $environment = $null
        if ($SetupEnvironment -or $IsolationLevel -ne 'None') {
            $environment = Initialize-TestEnvironment -IsolationLevel $IsolationLevel -TestSuite $TestSuite
        }

        # Phase 2: Test Discovery
        $testTargets = Get-TestableTargets -TestSuite $TestSuite
        Write-CustomLog "Discovered $($testTargets.Count) test targets" -Level INFO

        # Phase 3: Execution Strategy
        $executionPlan = New-TestExecutionPlan -Targets $testTargets -Mode $ExecutionMode
        $results = Invoke-TestExecution -ExecutionPlan $executionPlan -Environment $environment

        # Phase 4: Reporting
        if ($GenerateReport) {
            Export-IntegratedTestReport -Results $results -OutputPath $OutputPath -VSCode:$VSCodeIntegration
        }

        # Phase 5: CI/CD Integration
        if ($CreatePatchIfFailures -and $results.FailureCount -gt 0) {
            New-TestFailurePatch -Results $results
        }

        # Phase 6: Cleanup
        if ($CleanupAfter -and $environment) {
            Remove-TestEnvironment -Environment $environment
        }

        return $results

    } catch {
        Write-CustomLog "Integrated testing failed: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

# Environment Management (DevEnvironment Integration)
function Initialize-TestEnvironment {
    [CmdletBinding()]
    param(
        [ValidateSet('Process', 'Container', 'None')]
        [string]$IsolationLevel = 'Process',
        [string]$TestSuite
    )

    Import-Module "$script:ModulePath/DevEnvironment" -Force
    Import-Module "$script:ModulePath/Logging" -Force

    switch ($IsolationLevel) {
        'Process' {
            $environment = @{
                Type = 'Process'
                TempPath = New-TemporaryDirectory
                ModulePath = $env:PWSH_MODULES_PATH
                OriginalLocation = Get-Location
            }
        }
        'Container' {
            # Future: Container-based isolation
            $environment = New-ContainerizedTestEnvironment -TestSuite $TestSuite
        }
        'None' {
            $environment = @{ Type = 'None' }
        }
    }

    Write-CustomLog "Test environment initialized: $($environment.Type)" -Level INFO
    return $environment
}

# Test Discovery (ScriptManager + LabRunner Integration)
function Get-TestableTargets {
    [CmdletBinding()]
    param([string]$TestSuite)

    Import-Module "$script:ModulePath/ScriptManager" -Force
    Import-Module "$script:ModulePath/LabRunner" -Force

    $targets = @()

    switch ($TestSuite) {
        'Discovery' {
            # Test script discovery and template generation
            $targets += Get-ScriptDiscoveryTests
        }
        'Unit' {
            # Individual module and script tests
            $targets += Get-UnitTestTargets
        }
        'Integration' {
            # Cross-module integration tests
            $targets += Get-IntegrationTestTargets
        }
        'Performance' {
            # Performance and load tests
            $targets += Get-PerformanceTestTargets
        }
        'Smoke' {
            # Quick validation tests
            $targets += Get-SmokeTestTargets
        }
        'All' {
            $targets += Get-TestableTargets -TestSuite 'Unit'
            $targets += Get-TestableTargets -TestSuite 'Integration'
            $targets += Get-TestableTargets -TestSuite 'Smoke'
        }
    }

    return $targets
}

# Execution Planning (ParallelExecution Integration)
function New-TestExecutionPlan {
    [CmdletBinding()]
    param(
        [array]$Targets,
        [string]$Mode
    )

    Import-Module "$script:ModulePath/ParallelExecution" -Force

    $plan = @{
        Mode = $Mode
        Targets = $Targets
        MaxConcurrency = 4
        Dependencies = @{}
        EstimatedDuration = 0
    }

    switch ($Mode) {
        'Sequential' {
            $plan.MaxConcurrency = 1
            $plan.ExecutionOrder = $Targets
        }
        'Parallel' {
            # Simple parallel execution
            $plan.ExecutionOrder = $Targets
        }
        'Intelligent' {
            # Analyze dependencies and optimize
            $plan = Optimize-TestExecutionPlan -Plan $plan
        }
    }

    return $plan
}

# Test Execution Core
function Invoke-TestExecution {
    [CmdletBinding()]
    param(
        [hashtable]$ExecutionPlan,
        [hashtable]$Environment
    )

    $results = @{
        TotalTests = $ExecutionPlan.Targets.Count
        PassedCount = 0
        FailedCount = 0
        SkippedCount = 0
        Duration = 0
        StartTime = Get-Date
        TestResults = @()
        FailedTests = @()
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        if ($ExecutionPlan.MaxConcurrency -eq 1) {
            # Sequential execution
            foreach ($target in $ExecutionPlan.ExecutionOrder) {
                $testResult = Invoke-SingleTest -Target $target -Environment $Environment
                $results.TestResults += $testResult
                Update-TestResults -Results $results -TestResult $testResult
            }
        } else {
            # Parallel execution
            Import-Module "$script:ModulePath/ParallelExecution" -Force
            $parallelResults = Invoke-ParallelTestExecution -Targets $ExecutionPlan.ExecutionOrder -MaxConcurrency $ExecutionPlan.MaxConcurrency -Environment $Environment

            foreach ($testResult in $parallelResults) {
                $results.TestResults += $testResult
                Update-TestResults -Results $results -TestResult $testResult
            }
        }

    } finally {
        $stopwatch.Stop()
        $results.Duration = $stopwatch.Elapsed.TotalSeconds
        $results.EndTime = Get-Date
    }

    Write-CustomLog "Test execution completed: Passed=$($results.PassedCount), Failed=$($results.FailedCount), Duration=$($results.Duration)s" -Level INFO
    return $results
}

# Individual Test Execution
function Invoke-SingleTest {
    [CmdletBinding()]
    param(
        [hashtable]$Target,
        [hashtable]$Environment
    )

    $testResult = @{
        Name = $Target.Name
        Type = $Target.Type
        Path = $Target.Path
        Status = 'Running'
        StartTime = Get-Date
        Duration = 0
        Output = @()
        Errors = @()
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        switch ($Target.Type) {
            'Pester' {
                $testResult = Invoke-PesterTestTarget -Target $Target -Environment $Environment
            }
            'Script' {
                $testResult = Invoke-ScriptTestTarget -Target $Target -Environment $Environment
            }
            'Module' {
                $testResult = Invoke-ModuleTestTarget -Target $Target -Environment $Environment
            }
            'Syntax' {
                $testResult = Invoke-SyntaxTestTarget -Target $Target
            }
        }

        $testResult.Status = if ($testResult.Errors.Count -eq 0) { 'Passed' } else { 'Failed' }

    } catch {
        $testResult.Status = 'Failed'
        $testResult.Errors += $_.Exception.Message
    } finally {
        $stopwatch.Stop()
        $testResult.Duration = $stopwatch.Elapsed.TotalSeconds
        $testResult.EndTime = Get-Date
    }

    return $testResult
}

# Reporting Integration
function Export-IntegratedTestReport {
    [CmdletBinding()]
    param(
        [hashtable]$Results,
        [string]$OutputPath,
        [switch]$VSCode
    )

    Import-Module "$script:ModulePath/Logging" -Force

    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    # Generate multiple report formats
    $reportData = @{
        Summary = @{
            TotalTests = $Results.TotalTests
            PassedCount = $Results.PassedCount
            FailedCount = $Results.FailedCount
            SkippedCount = $Results.SkippedCount
            Duration = $Results.Duration
            StartTime = $Results.StartTime
            EndTime = $Results.EndTime
            SuccessRate = if ($Results.TotalTests -gt 0) { ($Results.PassedCount / $Results.TotalTests) * 100 } else { 0 }
        }
        TestResults = $Results.TestResults
        FailedTests = $Results.FailedTests
        Environment = @{
            PowerShellVersion = $PSVersionTable.PSVersion
            Platform = $PSVersionTable.Platform
            OS = $PSVersionTable.OS
        }
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }

    # JSON Report (for tools)
    $reportData | ConvertTo-Json -Depth 10 | Out-File "$OutputPath/integrated-test-report.json" -Encoding UTF8

    # XML Report (for CI/CD)
    Export-JUnitXmlReport -Results $Results -OutputPath "$OutputPath/junit-report.xml"

    # HTML Report (for humans)
    Export-HtmlTestReport -Results $Results -OutputPath "$OutputPath/test-report.html"

    # VS Code Integration
    if ($VSCode) {
        Export-VSCodeTestReport -Results $Results -OutputPath "$OutputPath/vscode-test-results.json"
    }

    Write-CustomLog "Test reports generated in: $OutputPath" -Level SUCCESS
}

# CI/CD Integration (PatchManager)
function New-TestFailurePatch {
    [CmdletBinding()]
    param([hashtable]$Results)

    Import-Module "$script:ModulePath/PatchManager" -Force

    $failureCount = $Results.FailedTests.Count
    $affectedFiles = $Results.FailedTests | ForEach-Object { $_.Path } | Sort-Object -Unique

    $description = "Automated test failure detection: $failureCount test(s) failed"
    $labels = @("test-failure", "automated", "needs-review")

    if ($failureCount -gt 10) {
        $labels += "critical"
        $priority = "Critical"
    } elseif ($failureCount -gt 5) {
        $priority = "High"
    } else {
        $priority = "Medium"
    }

    New-PatchIssue -Description $description -Priority $priority -AffectedFiles $affectedFiles -Labels $labels

    Write-CustomLog "Created patch issue for test failures" -Level WARN
}

# Helper Functions
function Update-TestResults {
    param([hashtable]$Results, [hashtable]$TestResult)

    switch ($TestResult.Status) {
        'Passed' { $Results.PassedCount++ }
        'Failed' {
            $Results.FailedCount++
            $Results.FailedTests += $TestResult
        }
        'Skipped' { $Results.SkippedCount++ }
    }
}

function Get-UnitTestTargets {
    # Discover all unit tests
    $unitTests = @()

    # Module tests
    $moduleTests = Get-ChildItem "$script:ProjectRoot/tests/unit/modules" -Filter "*.Tests.ps1" -Recurse
    foreach ($test in $moduleTests) {
        $unitTests += @{
            Name = $test.BaseName
            Type = 'Pester'
            Path = $test.FullName
            Category = 'Module'
        }
    }

    # Script tests
    $scriptTests = Get-ChildItem "$script:ProjectRoot/tests/unit/scripts" -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue
    foreach ($test in $scriptTests) {
        $unitTests += @{
            Name = $test.BaseName
            Type = 'Pester'
            Path = $test.FullName
            Category = 'Script'
        }
    }

    return $unitTests
}

function Get-IntegrationTestTargets {
    # Discover integration tests
    $integrationTests = @()

    $tests = Get-ChildItem "$script:ProjectRoot/tests/integration" -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue
    foreach ($test in $tests) {
        $integrationTests += @{
            Name = $test.BaseName
            Type = 'Pester'
            Path = $test.FullName
            Category = 'Integration'
        }
    }

    return $integrationTests
}

function Get-SmokeTestTargets {
    # Quick validation tests
    return @(
        @{
            Name = 'Module-Load-Test'
            Type = 'Script'
            Path = 'Quick module loading validation'
            Category = 'Smoke'
        },
        @{
            Name = 'Syntax-Validation'
            Type = 'Syntax'
            Path = 'All PowerShell files'
            Category = 'Smoke'
        }
    )
}

# Export functions
Export-ModuleMember -Function @(
    'Invoke-IntegratedTesting',
    'Initialize-TestEnvironment',
    'Get-TestableTargets',
    'New-TestExecutionPlan',
    'Invoke-TestExecution',
    'Export-IntegratedTestReport',
    'New-TestFailurePatch'
)
```

## 🔧 **VS Code Tasks Integration**

### **New .vscode/tasks.json entries**

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "🧪 Integrated Testing - Quick Unit Tests",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Import-Module './aither-core/modules/TestingFramework' -Force; Invoke-IntegratedTesting -TestSuite Unit -ExecutionMode Parallel -VSCodeIntegration"
            ],
            "group": {
                "kind": "test",
                "isDefault": true
            },
            "presentation": {
                "reveal": "always",
                "panel": "new",
                "clear": true
            },
            "problemMatcher": [
                "$pester"
            ]
        },
        {
            "label": "🔬 Integrated Testing - Full Suite",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Import-Module './aither-core/modules/TestingFramework' -Force; Invoke-IntegratedTesting -TestSuite All -ExecutionMode Intelligent -SetupEnvironment -GenerateReport -VSCodeIntegration -CleanupAfter"
            ],
            "group": "test",
            "presentation": {
                "reveal": "always",
                "panel": "new",
                "clear": true
            }
        },
        {
            "label": "⚡ Integrated Testing - Smoke Tests",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Import-Module './aither-core/modules/TestingFramework' -Force; Invoke-IntegratedTesting -TestSuite Smoke -ExecutionMode Sequential -VSCodeIntegration"
            ],
            "group": "test",
            "presentation": {
                "reveal": "silent",
                "panel": "shared"
            }
        },
        {
            "label": "🚀 Development Workflow - Test & Patch",
            "type": "shell",
            "command": "pwsh",
            "args": [
                "-Command",
                "Import-Module './aither-core/modules/TestingFramework' -Force; $results = Invoke-IntegratedTesting -TestSuite Unit -ExecutionMode Parallel -VSCodeIntegration; if ($results.FailedCount -eq 0) { Write-Host '✅ All tests passed - ready for patch creation' -ForegroundColor Green } else { Write-Host '❌ Tests failed - review issues before patching' -ForegroundColor Red }"
            ],
            "group": "build",
            "dependsOrder": "sequence",
            "dependsOn": ["🛠️ Setup Development Environment"]
        }
    ],
    "inputs": [
        {
            "id": "testSuite",
            "description": "Select test suite to run",
            "type": "pickString",
            "options": [
                "Unit",
                "Integration",
                "Performance",
                "Smoke",
                "All"
            ],
            "default": "Unit"
        },
        {
            "id": "executionMode",
            "description": "Select execution mode",
            "type": "pickString",
            "options": [
                "Sequential",
                "Parallel",
                "Intelligent"
            ],
            "default": "Intelligent"
        }
    ]
}
```

## 📋 **Implementation Steps**

### **Step 1: Backup Current Implementation**
```powershell
# Create backup of current TestingFramework
Copy-Item "./aither-core/modules/TestingFramework" "./aither-core/modules/TestingFramework.backup" -Recurse
```

### **Step 2: Implement Enhanced TestingFramework**
- Replace current TestingFramework.psm1 with enhanced version
- Add new integration functions
- Update module manifest

### **Step 3: Update VS Code Tasks**
- Replace current testing tasks with integrated versions
- Add new development workflow tasks
- Test task execution

### **Step 4: Create Migration Scripts**
- Script to update existing tests to new framework
- Validation script to ensure backward compatibility
- Documentation update scripts

### **Step 5: Testing & Validation**
- Run comprehensive tests with new framework
- Validate all module integrations work correctly
- Performance testing of parallel execution

This implementation provides a concrete foundation for the integrated testing architecture while maintaining backward compatibility and providing immediate improvements in testing workflow.
