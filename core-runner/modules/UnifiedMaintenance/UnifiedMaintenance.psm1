#Requires -Version 7.0

<#
.SYNOPSIS
    UnifiedMaintenance PowerShell module for OpenTofu Lab Automation project

.DESCRIPTION
    This module consolidates all project maintenance functionality into a single,
    coherent system that integrates with PatchManager for change control and
    includes comprehensive automated testing workflows.

.NOTES
    - Integrates with PatchManager for all changes
    - Includes automated Pester and pytest execution
    - Provides comprehensive health monitoring
    - Supports continuous integration workflows
#>

# Module functions to export
$publicFunctions = @(
    'Invoke-UnifiedMaintenance',
    'Invoke-AutomatedTestWorkflow',
    'Invoke-InfrastructureHealth',
    'Invoke-RecurringIssueTracking',
    'Start-ContinuousMonitoring'
)

function Write-MaintenanceLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR','MAINTENANCE')]
        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'INFO'        { 'Cyan' }
        'SUCCESS'     { 'Green' }
        'WARNING'     { 'Yellow' }
        'ERROR'       { 'Red' }
        'MAINTENANCE' { 'Magenta' }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-ProjectRoot {
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        return "$env:PROJECT_ROOT"
    }
    else {
        return '/workspaces/opentofu-lab-automation'
    }
}

function Test-Prerequisites {
    param([string]$ProjectRoot)    $prerequisites = @{
        'PatchManager Module' = "$ProjectRoot/core-runner/modules/PatchManager/PatchManager.psd1"
        'LabRunner Module'    = "$ProjectRoot/core-runner/modules/LabRunner/LabRunner.psm1"
        'Tests Directory'     = "$ProjectRoot/tests"
        'Python labctl'       = "$ProjectRoot/py/labctl"
    }

    $missing = @()
    foreach ($entry in $prerequisites.GetEnumerator()) {
        if (-not (Test-Path $entry.Value)) {
            $missing += $entry.Key
        }
    }

    if ($missing.Count -gt 0) {
        Write-MaintenanceLog "Missing prerequisites: $($missing -join ', ')" 'ERROR'
        return $false
    }
    return $true
}

function Invoke-MaintenanceStep {
    param(
        [string]    $StepName,
        [scriptblock] $StepAction,
        [bool]      $CriticalStep = $true
    )
    Write-MaintenanceLog "Starting: $StepName" 'MAINTENANCE'
    try {
        $result = & $StepAction
        Write-MaintenanceLog "Completed: $StepName" 'SUCCESS'
        return $result
    }
    catch {
        Write-MaintenanceLog "Failed: $StepName - $($_.Exception.Message)" 'ERROR'
        if ($CriticalStep) { throw }
        return $null
    }
}

function Invoke-AutomatedTestWorkflow {
    <#
    .SYNOPSIS
        Runs Pester, pytest, integration and performance tests, then generates a report
    .PARAMETER TestCategory
        One of Unit, Integration, Performance, All
    .PARAMETER GenerateCoverage
        Switch to enable coverage collection
    .PARAMETER Parallel
        (Reserved) switch for parallel execution
    .PARAMETER OutputPath
        Directory to write test results and report
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Unit','Integration','Performance','All')]
        [string]$TestCategory = 'All',

        [switch]$GenerateCoverage,
        [switch]$Parallel,
        [string]$OutputPath = 'TestResults'
    )

    $ProjectRoot = Get-ProjectRoot

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $testResults = @{
        Timestamp   = Get-Date
        TotalTests  = 0
        TotalPassed = 0
        TotalFailed = 0
        Categories  = @{}
    }

    Write-MaintenanceLog "Starting Automated Test Workflow - Category: $TestCategory" 'MAINTENANCE'

    # 1. PowerShell Pester Tests
    if ($TestCategory -in @('Unit','All')) {        Invoke-MaintenanceStep 'PowerShell Pester Tests' {
            Write-MaintenanceLog 'Running Pester tests...' 'INFO'
            $config = New-PesterConfiguration
            $config.Run.Path              = "$ProjectRoot/tests"
            $config.Output.Verbosity      = 'Detailed'
            $config.TestResult.Enabled    = $true
            $config.TestResult.OutputPath = "$OutputPath/PesterResults.xml"
            $config.TestResult.OutputFormat = 'NUnitXml'
            if ($GenerateCoverage) {
                $config.CodeCoverage.Enabled    = $true
                $config.CodeCoverage.Path       = @("$ProjectRoot/core-runner/modules","$ProjectRoot/core-runner/core_app")
                $config.CodeCoverage.OutputPath = "$OutputPath/PesterCoverage.xml"
            }
            $pesterResults = Invoke-Pester -Configuration $config

            $testResults.Categories.Pester = @{
                Total   = $pesterResults.TotalCount
                Passed  = $pesterResults.PassedCount
                Failed  = $pesterResults.FailedCount
                Skipped = $pesterResults.SkippedCount
            }

            Write-MaintenanceLog "Pester: $($pesterResults.PassedCount)/$($pesterResults.TotalCount) passed" 'INFO'
            return $pesterResults
        } -CriticalStep:$false
    }

    # 2. Python pytest Tests
    if ($TestCategory -in @('Unit','Integration','All')) {        Invoke-MaintenanceStep 'Python pytest Tests' {
            Write-MaintenanceLog 'Running pytest tests...' 'INFO'
            $pyPath = "$ProjectRoot/py/tests"
            if (Test-Path $pyPath) {
                $pytestArgs = @($pyPath,'-v','--tb=short',"--junit-xml=$OutputPath/pytestResults.xml")
                if ($GenerateCoverage) {
                    $pytestArgs += @(
                        '--cov=py.labctl',
                        "--cov-report=xml:$OutputPath/pytestCoverage.xml",
                        "--cov-report=html:$OutputPath/htmlcov"
                    )
                }
                $output = python -m pytest @pytestArgs
                $exit   = $LASTEXITCODE

                $testResults.Categories.Pytest = @{
                    ExitCode = $exit
                    Success  = ($exit -eq 0)
                }

                Write-MaintenanceLog "pytest exit code: $exit" 'INFO'
                return @{ ExitCode = $exit; Output = $output }
            }
            else {
                Write-MaintenanceLog "Python tests directory not found: $pyPath" 'WARNING'
                return $null
            }
        }
    }

    # 3. Integration Tests
    if ($TestCategory -in @('Integration','All')) {        Invoke-MaintenanceStep 'Integration Tests' {
            Write-MaintenanceLog 'Running integration tests...' 'INFO'
            $script = "$ProjectRoot/tests/Integration/Test-CoreAppIntegration.ps1"
            if (Test-Path $script) {
                $res = & $script -OutputPath $OutputPath
                $testResults.Categories.Integration = @{
                    Success = $res.Success
                    Details = $res.Details
                }
                return $res
            }
            else {
                Write-MaintenanceLog 'Integration script not found' 'WARNING'
                return $null
            }
        }
    }

    # 4. Performance Tests
    if ($TestCategory -in @('Performance','All')) {
        Invoke-MaintenanceStep 'Performance Tests' {            Write-MaintenanceLog 'Running performance benchmarks...' 'INFO'
            $perf = @{}

            $imp = Measure-Command {
                Import-Module "$ProjectRoot/core-runner/modules/LabRunner" -Force
                Import-Module "$ProjectRoot/core-runner/modules/PatchManager" -Force
            }
            $perf.ModuleImportTime = $imp.TotalSeconds

            $run = Measure-Command {
                & "$ProjectRoot/core-runner/core_app/core-runner.ps1" -Scripts 'help' -ErrorAction SilentlyContinue
            }
            $perf.RunnerPerformanceTime = $run.TotalSeconds

            $testResults.Categories.Performance = $perf
            Write-MaintenanceLog "Module import: $($imp.TotalSeconds.ToString('F2'))s" 'INFO'
            Write-MaintenanceLog "Runner performance: $($run.TotalSeconds.ToString('F2'))s" 'INFO'
            return $perf
        }
    }

    # 5. Generate comprehensive report
    Invoke-MaintenanceStep 'Generate Test Report' {
        $report = @"
# Automated Test Workflow Report
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Test Category: $TestCategory
Coverage Enabled: $($GenerateCoverage.IsPresent)
Parallel Execution: $($Parallel.IsPresent)

## Summary

"@

        if ($testResults.Categories.Pester) {
            $report += @"
### PowerShell Pester Tests
- Total:   $($testResults.Categories.Pester.Total)
- Passed:  $($testResults.Categories.Pester.Passed)
- Failed:  $($testResults.Categories.Pester.Failed)
- Skipped: $($testResults.Categories.Pester.Skipped)

"@
        }
        if ($testResults.Categories.Pytest) {
            $report += @"
### Python pytest Tests
- Exit Code: $($testResults.Categories.Pytest.ExitCode)
- Success:   $($testResults.Categories.Pytest.Success)

"@
        }
        if ($testResults.Categories.Performance) {
            $report += @"
### Performance Benchmarks
- Module Import Time:    $($testResults.Categories.Performance.ModuleImportTime.ToString('F2'))s
- Runner Performance:    $($testResults.Categories.Performance.RunnerPerformanceTime.ToString('F2'))s

"@
        }

        $out = Join-Path $OutputPath 'TestWorkflowReport.md'
        Set-Content -Path $out -Value $report
        Write-MaintenanceLog "Test report generated: $out" 'SUCCESS'
        return $out
    }

    Write-MaintenanceLog 'Automated Test Workflow completed' 'SUCCESS'
    return $testResults
}

function Invoke-InfrastructureHealth {
    [CmdletBinding()]
    param(
        [switch]$AutoFix,
        [string]$OutputPath = 'HealthReport'
    )

    $ProjectRoot   = Get-ProjectRoot
    $healthResults = @{
        Timestamp     = Get-Date
        OverallHealth = 'Unknown'
        Checks        = @{}
    }

    Write-MaintenanceLog 'Starting Infrastructure Health Check' 'MAINTENANCE'    Invoke-MaintenanceStep 'Module Health Check' {
        $mods = @('LabRunner','PatchManager')
        $mh   = @{}
        foreach ($m in $mods) {
            $path = "$ProjectRoot/core-runner/modules/$m"
            $mh[$m] = @{
                Exists         = Test-Path $path
                LoadsCorrectly = $false
                Functions      = @()
            }
            if ($mh[$m].Exists) {
                try {
                    Import-Module $path -Force
                    $mh[$m].LoadsCorrectly = $true
                    $mh[$m].Functions      = (Get-Command -Module $m).Name
                }
                catch {
                    Write-MaintenanceLog "Module load failed: $m" 'WARNING'
                }
            }
        }
        $healthResults.Checks.Modules = $mh
        return $mh
    } -CriticalStep:$false    Invoke-MaintenanceStep 'Script Syntax Check' {
        $errs  = @()
        $files = Get-ChildItem -Path "$ProjectRoot/core-runner" -Filter '*.ps1' -Recurse
        foreach ($f in $files) {
            try {
                [System.Management.Automation.PSParser]::Tokenize((Get-Content $f.FullName -Raw), [ref]$null)
            }
            catch {
                $errs += @{ File = $f.FullName; Error = $_.Exception.Message }
            }
        }
        $healthResults.Checks.ScriptSyntax = @{
            TotalScripts = $files.Count
            ErrorCount   = $errs.Count
            Errors       = $errs
        }
        Write-MaintenanceLog "Script syntax: $($errs.Count) errors" 'INFO'
        return $errs
    } -CriticalStep:$false    Invoke-MaintenanceStep 'Test Framework Health' {
        $tf = @{
            PesterAvailable = $null -ne (Get-Module -ListAvailable Pester)
            PytestAvailable = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
            TestFilesExist  = Test-Path "$ProjectRoot/tests"
        }
        $healthResults.Checks.TestFramework = $tf
        return $tf
    } -CriticalStep:$false

    $crit = 0
    if (-not $healthResults.Checks.Modules.LabRunner.LoadsCorrectly) { $crit++ }
    if (-not $healthResults.Checks.Modules.PatchManager.LoadsCorrectly) { $crit++ }
    if ($healthResults.Checks.ScriptSyntax.ErrorCount -gt 0)   { $crit++ }

    $healthResults.OverallHealth = if ($crit -eq 0) { 'Good' }
                                  elseif ($crit -le 2) { 'Fair' }
                                  else { 'Poor' }

    Write-MaintenanceLog "Infrastructure Health: $($healthResults.OverallHealth)" 'INFO'    if ($OutputPath) {
        $json = $healthResults | ConvertTo-Json -Depth 10
        $file = "$OutputPath/InfrastructureHealth.json"
        Set-Content -Path $file -Value $json
        Write-MaintenanceLog "Health report saved: $file" 'SUCCESS'
    }

    return $healthResults
}

function Invoke-RecurringIssueTracking {
    [CmdletBinding()]
    param(
        [switch]$IncludePreventionCheck,
        [string]$OutputPath = 'IssueTracking'
    )
    Write-MaintenanceLog 'Starting Recurring Issue Tracking' 'MAINTENANCE'
    return @{
        Timestamp        = Get-Date
        IssuesTracked    = 0
        TopIssues        = @()
        PreventionStatus = 'Good'
    }
}

function Start-ContinuousMonitoring {
    [CmdletBinding()]
    param(
        [int]   $IntervalMinutes = 30,
        [switch]$RunTests,
        [string]$LogPath = 'ContinuousMonitoring.log'
    )
    Write-MaintenanceLog "Starting Continuous Monitoring (Interval: $IntervalMinutes)" 'MAINTENANCE'
    while ($true) {
        try {
            $health = Invoke-InfrastructureHealth -OutputPath 'ContinuousHealth'
            if ($RunTests) {
                $tests = Invoke-AutomatedTestWorkflow -TestCategory 'Unit' -OutputPath 'ContinuousTests'
            }
            $passed = ($tests.Categories.Pester.Passed) -as [int]
            $total  = ($tests.Categories.Pester.Total)  -as [int]
            $status = "Health: $($health.OverallHealth)"
            if ($RunTests) { $status += ", Tests: $passed/$total passed" }
            Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $status"
            Write-MaintenanceLog $status 'INFO'
        }
        catch {
            Write-MaintenanceLog "Monitoring error: $_" 'ERROR'
        }
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    }
}

function Invoke-MaintenanceOperations {
    param(
        [string]$Mode,
        [bool]  $AutoFix,
        [bool]  $UpdateChangelog
    )
    $r = @{}
    switch ($Mode) {
        'Quick'     { $r.Health = Invoke-InfrastructureHealth -AutoFix:$AutoFix }
        'Full'      {
            $r.Health = Invoke-InfrastructureHealth -AutoFix:$AutoFix
            $r.Issues = Invoke-RecurringIssueTracking -IncludePreventionCheck
        }
        'Test'      {
            $r.Health = Invoke-InfrastructureHealth -AutoFix:$AutoFix
            $r.Tests  = Invoke-AutomatedTestWorkflow -TestCategory 'All' -GenerateCoverage
        }
        'TestOnly'  { $r.Tests = Invoke-AutomatedTestWorkflow -TestCategory 'All' -GenerateCoverage }
        'Continuous'{ Start-ContinuousMonitoring -RunTests }
        'Track'     { $r.Issues = Invoke-RecurringIssueTracking -IncludePreventionCheck }
        'Report'    {
            $r.Health = Invoke-InfrastructureHealth
            $r.Issues = Invoke-RecurringIssueTracking
        }
        'All'       {
            $r.Health  = Invoke-InfrastructureHealth -AutoFix:$AutoFix
            $r.Tests   = Invoke-AutomatedTestWorkflow -TestCategory 'All' -GenerateCoverage
            $r.Issues  = Invoke-RecurringIssueTracking -IncludePreventionCheck
        }
    }
    return $r
}

function Invoke-UnifiedMaintenance {
    [CmdletBinding()]
    param(
        [ValidateSet('Quick','Full','Test','TestOnly','Continuous','Track','Report','All')]
        [string]$Mode = 'Quick',
        [switch]$AutoFix,
        [switch]$UpdateChangelog,
        [switch]$UsePatchManager
    )

    $root = Get-ProjectRoot
    Write-MaintenanceLog "Starting Unified Maintenance - Mode: $Mode" 'MAINTENANCE'

    if (-not (Test-Prerequisites -ProjectRoot $root)) {
        throw 'Prerequisites check failed.'
    }

    $results = @{
        Mode           = $Mode
        Timestamp      = Get-Date
        Results        = @{ }
        OverallSuccess = $true
    }

    if ($UsePatchManager -and (Get-Command Invoke-GitControlledPatch -ErrorAction SilentlyContinue)) {
        Write-MaintenanceLog 'Using PatchManager' 'INFO'
        $results.Results = Invoke-GitControlledPatch `
            -PatchDescription "Unified Maintenance: $Mode" `
            -PatchOperation {
                Invoke-MaintenanceOperations -Mode $Mode -AutoFix:$AutoFix -UpdateChangelog:$UpdateChangelog
            } `
            -AutoCommitUncommitted:$AutoFix `
            -TestCommands @("pwsh -NoProfile -Command 'Import-Module $root/core-runner/modules/LabRunner -Force; Write-Host OK'")
    }
    else {
        Write-MaintenanceLog 'Running without PatchManager' 'WARNING'
        $results.Results = Invoke-MaintenanceOperations -Mode $Mode -AutoFix:$AutoFix -UpdateChangelog:$UpdateChangelog
    }

    Write-MaintenanceLog 'Unified Maintenance completed' 'SUCCESS'
    return $results
}

# Export public functions
foreach ($fn in $publicFunctions) {
    Export-ModuleMember -Function $fn
}
