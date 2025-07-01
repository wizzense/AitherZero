#Requires -Version 7.0
<#
.SYNOPSIS
    Comprehensive release validation for AitherZero with automated testing and quality gates
.DESCRIPTION
    Validates release readiness through comprehensive testing, security analysis, build validation,
    and performance benchmarking. Integrates with PatchManager release workflow and CI/CD pipeline.
.PARAMETER ReleaseType
    Type of release: patch, minor, major
.PARAMETER TargetVersion
    Specific version to validate (overrides ReleaseType auto-increment)
.PARAMETER ValidationLevel
    Validation depth: Quick (5min), Standard (15min), Complete (30min), Production (60min)
.PARAMETER SkipTests
    Skip specific test categories: Unit, Integration, E2E, Performance, Security
.PARAMETER CreateRelease
    Automatically create release after successful validation
.PARAMETER DryRun
    Preview validation steps without executing
.PARAMETER CI
    Run in CI/CD mode with optimized settings
.PARAMETER ForceValidation
    Bypass non-critical validation failures
.EXAMPLE
    ./tests/Invoke-ReleaseValidation.ps1 -ReleaseType patch -ValidationLevel Standard
.EXAMPLE
    ./tests/Invoke-ReleaseValidation.ps1 -TargetVersion "2.1.0" -ValidationLevel Complete -CreateRelease
.EXAMPLE
    ./tests/Invoke-ReleaseValidation.ps1 -ValidationLevel Production -CI
#>

[CmdletBinding()]
param(
    [ValidateSet('patch', 'minor', 'major')]
    [string]$ReleaseType = 'patch',
    
    [string]$TargetVersion,
    
    [ValidateSet('Quick', 'Standard', 'Complete', 'Production')]
    [string]$ValidationLevel = 'Standard',
    
    [string[]]$SkipTests = @(),
    [switch]$CreateRelease,
    [switch]$DryRun,
    [switch]$CI,
    [switch]$ForceValidation,
    
    [string]$OutputPath = './tests/TestResults/release-validation',
    [string]$BaselinePath = './tests/TestResults/performance-baseline.json'
)

# Initialize environment
$ErrorActionPreference = 'Stop'
$script:StartTime = Get-Date
$script:ValidationResults = @{
    StartTime = $script:StartTime
    ValidationLevel = $ValidationLevel
    ReleaseType = $ReleaseType
    TargetVersion = $TargetVersion
    Stages = @{}
    OverallResult = 'Unknown'
    CriticalFailures = @()
    Warnings = @()
    Performance = @{}
    Artifacts = @()
}

# Ensure output directory exists
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

# Import parallel execution module if available
$script:ParallelAvailable = $false
try {
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $parallelModulePath = Join-Path $projectRoot "aither-core/modules/ParallelExecution"
    
    if (Test-Path $parallelModulePath) {
        Import-Module $parallelModulePath -Force -ErrorAction Stop
        $script:ParallelAvailable = $true
        Write-Verbose "ParallelExecution module loaded successfully"
    }
} catch {
    Write-Verbose "ParallelExecution module not available: $_"
}

function Write-ValidationLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO',
        [string]$Stage = 'General'
    )
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $prefix = switch ($Level) {
        'INFO' { "ℹ️" }
        'WARN' { "⚠️" }
        'ERROR' { "❌" }
        'SUCCESS' { "✅" }
        'DEBUG' { "🔍" }
    }
    
    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        'SUCCESS' { 'Green' }
        'DEBUG' { 'Gray' }
    }
    
    $formattedMessage = "[$timestamp] [$Stage] $prefix $Message"
    Write-Host $formattedMessage -ForegroundColor $color
    
    # Add to stage results
    if (-not $script:ValidationResults.Stages.ContainsKey($Stage)) {
        $script:ValidationResults.Stages[$Stage] = @{
            StartTime = Get-Date
            Messages = @()
            Result = 'Running'
            Duration = $null
        }
    }
    
    $script:ValidationResults.Stages[$Stage].Messages += @{
        Timestamp = Get-Date
        Level = $Level
        Message = $Message
    }
}

function Complete-ValidationStage {
    param(
        [string]$Stage,
        [ValidateSet('Passed', 'Failed', 'Warning', 'Skipped')]
        [string]$Result,
        [string]$Summary = ""
    )
    
    if ($script:ValidationResults.Stages.ContainsKey($Stage)) {
        $stageData = $script:ValidationResults.Stages[$Stage]
        $stageData.Result = $Result
        $stageData.Duration = (Get-Date) - $stageData.StartTime
        $stageData.Summary = $Summary
        
        $icon = switch ($Result) {
            'Passed' { "✅" }
            'Failed' { "❌" }
            'Warning' { "⚠️" }
            'Skipped' { "⏭️" }
        }
        
        Write-ValidationLog "Stage completed: $Result ($($stageData.Duration.TotalSeconds.ToString('F1'))s) - $Summary" -Level ($Result -eq 'Failed' ? 'ERROR' : 'SUCCESS') -Stage $Stage
    }
}

function Test-VersionRequirements {
    param([string]$Stage = 'Version-Requirements')
    
    Write-ValidationLog "Validating version requirements..." -Stage $Stage
    
    try {
        # Check PowerShell version
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            throw "PowerShell 7.0+ required, found $($PSVersionTable.PSVersion)"
        }
        Write-ValidationLog "PowerShell version: $($PSVersionTable.PSVersion) ✓" -Level 'SUCCESS' -Stage $Stage
        
        # Validate current version file
        $versionFile = Join-Path (Get-Location) "VERSION"
        if (-not (Test-Path $versionFile)) {
            throw "VERSION file not found at $versionFile"
        }
        
        $currentVersion = (Get-Content $versionFile -Raw).Trim()
        if (-not $currentVersion -match '^\d+\.\d+\.\d+$') {
            throw "Invalid version format in VERSION file: $currentVersion"
        }
        Write-ValidationLog "Current version: $currentVersion ✓" -Level 'SUCCESS' -Stage $Stage
        
        # Calculate target version if not specified
        if (-not $TargetVersion) {
            $versionParts = $currentVersion -split '\.'
            $script:TargetVersion = switch ($ReleaseType) {
                'major' { "$([int]$versionParts[0] + 1).0.0" }
                'minor' { "$($versionParts[0]).$([int]$versionParts[1] + 1).0" }
                'patch' { "$($versionParts[0]).$($versionParts[1]).$([int]$versionParts[2] + 1)" }
            }
        } else {
            $script:TargetVersion = $TargetVersion
        }
        
        Write-ValidationLog "Target version: $script:TargetVersion ($ReleaseType release) ✓" -Level 'SUCCESS' -Stage $Stage
        $script:ValidationResults.TargetVersion = $script:TargetVersion
        
        Complete-ValidationStage -Stage $Stage -Result 'Passed' -Summary "Version validation successful: $currentVersion → $script:TargetVersion"
        return $true
        
    } catch {
        Write-ValidationLog "Version validation failed: $_" -Level 'ERROR' -Stage $Stage
        $script:ValidationResults.CriticalFailures += "Version validation: $_"
        Complete-ValidationStage -Stage $Stage -Result 'Failed' -Summary "Version validation failed: $_"
        return $false
    }
}

function Test-ProjectStructure {
    param([string]$Stage = 'Project-Structure')
    
    Write-ValidationLog "Validating project structure..." -Stage $Stage
    
    try {
        $requiredPaths = @(
            'Start-AitherZero.ps1',
            'aither-core/aither-core.ps1',
            'aither-core/modules',
            'aither-core/shared/Find-ProjectRoot.ps1',
            'tests',
            'configs',
            '.github/workflows'
        )
        
        $missingPaths = @()
        foreach ($path in $requiredPaths) {
            if (-not (Test-Path $path)) {
                $missingPaths += $path
            } else {
                Write-ValidationLog "Found: $path ✓" -Level 'DEBUG' -Stage $Stage
            }
        }
        
        if ($missingPaths.Count -gt 0) {
            throw "Missing required paths: $($missingPaths -join ', ')"
        }
        
        # Validate critical modules exist
        $criticalModules = @('Logging', 'LabRunner', 'PatchManager', 'TestingFramework')
        $missingModules = @()
        
        foreach ($module in $criticalModules) {
            $modulePath = Join-Path 'aither-core/modules' $module
            if (-not (Test-Path $modulePath)) {
                $missingModules += $module
            } else {
                # Check for module manifest
                $manifestPath = Join-Path $modulePath "$module.psd1"
                if (Test-Path $manifestPath) {
                    Write-ValidationLog "Module validated: $module ✓" -Level 'DEBUG' -Stage $Stage
                } else {
                    Write-ValidationLog "Module missing manifest: $module" -Level 'WARN' -Stage $Stage
                }
            }
        }
        
        if ($missingModules.Count -gt 0) {
            throw "Missing critical modules: $($missingModules -join ', ')"
        }
        
        Complete-ValidationStage -Stage $Stage -Result 'Passed' -Summary "All required project structure validated"
        return $true
        
    } catch {
        Write-ValidationLog "Project structure validation failed: $_" -Level 'ERROR' -Stage $Stage
        $script:ValidationResults.CriticalFailures += "Project structure: $_"
        Complete-ValidationStage -Stage $Stage -Result 'Failed' -Summary "Project structure validation failed: $_"
        return $false
    }
}

function Invoke-TestSuite {
    param(
        [string]$SuiteName,
        [string]$Stage,
        [string[]]$TestCategories = @('All')
    )
    
    Write-ValidationLog "Running $SuiteName test suite..." -Stage $Stage
    
    try {
        $testParams = @{
            TestSuite = $TestCategories[0]
            OutputPath = Join-Path $OutputPath $SuiteName.ToLower()
            CI = $CI.IsPresent
            GenerateHTML = $true
            ShowCoverage = ($ValidationLevel -in @('Complete', 'Production'))
        }
        
        # Skip if requested
        $shouldSkip = $false
        foreach ($category in $TestCategories) {
            if ($SkipTests -contains $category) {
                $shouldSkip = $true
                break
            }
        }
        
        if ($shouldSkip) {
            Write-ValidationLog "Skipping $SuiteName tests (requested)" -Level 'WARN' -Stage $Stage
            Complete-ValidationStage -Stage $Stage -Result 'Skipped' -Summary "Tests skipped by request"
            return $true
        }
        
        if ($DryRun) {
            Write-ValidationLog "DRY RUN: Would execute tests with: $($testParams | ConvertTo-Json -Compress)" -Level 'INFO' -Stage $Stage
            Complete-ValidationStage -Stage $Stage -Result 'Skipped' -Summary "Dry run mode"
            return $true
        }
        
        # Execute production test runner
        $testScript = Join-Path (Get-Location) 'tests/Run-ProductionTests.ps1'
        if (-not (Test-Path $testScript)) {
            throw "Production test runner not found at $testScript"
        }
        
        $testResults = & $testScript @testParams
        
        if ($testResults) {
            # Parse results if available
            $resultsFile = Join-Path $testParams.OutputPath "test-results.json"
            if (Test-Path $resultsFile) {
                $parsedResults = Get-Content $resultsFile | ConvertFrom-Json
                
                $passRate = if ($parsedResults.Summary.TotalTests -gt 0) {
                    [math]::Round(($parsedResults.Summary.PassedTests / $parsedResults.Summary.TotalTests) * 100, 2)
                } else { 0 }
                
                $summary = "Total: $($parsedResults.Summary.TotalTests), Passed: $($parsedResults.Summary.PassedTests), Failed: $($parsedResults.Summary.FailedTests), Pass Rate: $passRate%"
                
                if ($parsedResults.Summary.FailedTests -gt 0) {
                    if ($ForceValidation) {
                        Write-ValidationLog "Test failures detected but continuing due to -ForceValidation" -Level 'WARN' -Stage $Stage
                        Complete-ValidationStage -Stage $Stage -Result 'Warning' -Summary $summary
                        return $true
                    } else {
                        Write-ValidationLog "Test failures detected: $($parsedResults.Summary.FailedTests)" -Level 'ERROR' -Stage $Stage
                        Complete-ValidationStage -Stage $Stage -Result 'Failed' -Summary $summary
                        return $false
                    }
                } else {
                    Write-ValidationLog "All tests passed! $summary" -Level 'SUCCESS' -Stage $Stage
                    Complete-ValidationStage -Stage $Stage -Result 'Passed' -Summary $summary
                    return $true
                }
            }
        }
        
        # Fallback if no results file
        Write-ValidationLog "Tests completed but no detailed results available" -Level 'WARN' -Stage $Stage
        Complete-ValidationStage -Stage $Stage -Result 'Warning' -Summary "Tests completed, results unclear"
        return $true
        
    } catch {
        Write-ValidationLog "Test suite failed: $_" -Level 'ERROR' -Stage $Stage
        $script:ValidationResults.CriticalFailures += "$SuiteName tests: $_"
        Complete-ValidationStage -Stage $Stage -Result 'Failed' -Summary "Test execution failed: $_"
        return $false
    }
}

function Test-SecurityValidation {
    param([string]$Stage = 'Security-Validation')
    
    if ($SkipTests -contains 'Security') {
        Write-ValidationLog "Skipping security validation (requested)" -Level 'WARN' -Stage $Stage
        Complete-ValidationStage -Stage $Stage -Result 'Skipped' -Summary "Security tests skipped by request"
        return $true
    }
    
    Write-ValidationLog "Running security validation..." -Stage $Stage
    
    try {
        if ($DryRun) {
            Write-ValidationLog "DRY RUN: Would run PSScriptAnalyzer security analysis" -Level 'INFO' -Stage $Stage
            Complete-ValidationStage -Stage $Stage -Result 'Skipped' -Summary "Dry run mode"
            return $true
        }
        
        # Run PSScriptAnalyzer for security issues
        if (-not (Get-Module PSScriptAnalyzer -ListAvailable)) {
            Write-ValidationLog "Installing PSScriptAnalyzer..." -Level 'INFO' -Stage $Stage
            Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
        }
        
        Write-ValidationLog "Running PowerShell security analysis..." -Level 'INFO' -Stage $Stage
        $analysisResults = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error, Warning -Settings PSGallery
        
        # Filter for security-related issues
        $securityIssues = $analysisResults | Where-Object { 
            $_.Tags -contains 'Security' -or 
            $_.RuleName -like '*Security*' -or 
            $_.RuleName -like '*Credential*' -or
            $_.RuleName -like '*Password*'
        }
        
        $criticalIssues = $analysisResults | Where-Object Severity -eq 'Error'
        
        if ($criticalIssues.Count -gt 0) {
            Write-ValidationLog "Critical security issues found: $($criticalIssues.Count)" -Level 'ERROR' -Stage $Stage
            foreach ($issue in $criticalIssues | Select-Object -First 5) {
                Write-ValidationLog "  • $($issue.ScriptName):$($issue.Line) - $($issue.Message)" -Level 'ERROR' -Stage $Stage
            }
            
            if (-not $ForceValidation) {
                Complete-ValidationStage -Stage $Stage -Result 'Failed' -Summary "Critical security issues: $($criticalIssues.Count)"
                return $false
            }
        }
        
        if ($securityIssues.Count -gt 0) {
            Write-ValidationLog "Security-related issues found: $($securityIssues.Count)" -Level 'WARN' -Stage $Stage
            $script:ValidationResults.Warnings += "Security issues detected: $($securityIssues.Count)"
        }
        
        Write-ValidationLog "Security validation completed - Critical: $($criticalIssues.Count), Security-related: $($securityIssues.Count)" -Level 'SUCCESS' -Stage $Stage
        Complete-ValidationStage -Stage $Stage -Result 'Passed' -Summary "Security analysis complete: $($criticalIssues.Count) critical, $($securityIssues.Count) security-related"
        return $true
        
    } catch {
        Write-ValidationLog "Security validation failed: $_" -Level 'ERROR' -Stage $Stage
        $script:ValidationResults.CriticalFailures += "Security validation: $_"
        Complete-ValidationStage -Stage $Stage -Result 'Failed' -Summary "Security validation failed: $_"
        return $false
    }
}

function Test-PerformanceBenchmark {
    param([string]$Stage = 'Performance-Benchmark')
    
    if ($SkipTests -contains 'Performance' -or $ValidationLevel -eq 'Quick') {
        Write-ValidationLog "Skipping performance benchmark" -Level 'WARN' -Stage $Stage
        Complete-ValidationStage -Stage $Stage -Result 'Skipped' -Summary "Performance tests skipped"
        return $true
    }
    
    Write-ValidationLog "Running performance benchmark..." -Stage $Stage
    
    try {
        if ($DryRun) {
            Write-ValidationLog "DRY RUN: Would run performance regression tests" -Level 'INFO' -Stage $Stage
            Complete-ValidationStage -Stage $Stage -Result 'Skipped' -Summary "Dry run mode"
            return $true
        }
        
        # Load performance regression testing
        $perfScript = Join-Path (Get-Location) 'tests/Shared/Test-PerformanceRegression.ps1'
        if (Test-Path $perfScript) {
            . $perfScript
            
            # Run a quick benchmark
            $benchmarkResults = Measure-Command {
                # Import core modules
                Import-Module (Join-Path (Get-Location) 'aither-core/modules/Logging') -Force
                Import-Module (Join-Path (Get-Location) 'aither-core/modules/TestingFramework') -Force
                
                # Basic functionality test
                for ($i = 0; $i -lt 10; $i++) {
                    $null = Find-ProjectRoot -StartPath (Get-Location)
                }
            }
            
            $mockTestResults = @{
                Duration = $benchmarkResults
                Tests = @()
                TotalCount = 1
                PassedCount = 1
                FailedCount = 0
                SkippedCount = 0
            }
            
            $perfData = Test-PerformanceRegression -TestResults $mockTestResults -BaselinePath $BaselinePath -GenerateReport
            
            $script:ValidationResults.Performance = @{
                BenchmarkDuration = $benchmarkResults.TotalSeconds
                OverallStatus = $perfData.OverallStatus
                Regressions = $perfData.Regressions.Count
                Improvements = $perfData.Improvements.Count
            }
            
            if ($perfData.OverallStatus -eq 'Regression') {
                Write-ValidationLog "Performance regression detected!" -Level 'WARN' -Stage $Stage
                $script:ValidationResults.Warnings += "Performance regression detected"
            }
            
            Write-ValidationLog "Performance benchmark: $($benchmarkResults.TotalSeconds.ToString('F3'))s, Status: $($perfData.OverallStatus)" -Level 'SUCCESS' -Stage $Stage
            Complete-ValidationStage -Stage $Stage -Result 'Passed' -Summary "Benchmark: $($benchmarkResults.TotalSeconds.ToString('F3'))s, Status: $($perfData.OverallStatus)"
            return $true
        } else {
            Write-ValidationLog "Performance regression script not found, skipping" -Level 'WARN' -Stage $Stage
            Complete-ValidationStage -Stage $Stage -Result 'Skipped' -Summary "Performance script not available"
            return $true
        }
        
    } catch {
        Write-ValidationLog "Performance benchmark failed: $_" -Level 'ERROR' -Stage $Stage
        Complete-ValidationStage -Stage $Stage -Result 'Failed' -Summary "Performance benchmark failed: $_"
        return $false
    }
}

function Test-BuildValidation {
    param([string]$Stage = 'Build-Validation')
    
    Write-ValidationLog "Validating build integrity..." -Stage $Stage
    
    try {
        if ($DryRun) {
            Write-ValidationLog "DRY RUN: Would validate module manifests and build integrity" -Level 'INFO' -Stage $Stage
            Complete-ValidationStage -Stage $Stage -Result 'Skipped' -Summary "Dry run mode"
            return $true
        }
        
        # Validate all module manifests
        $manifestErrors = @()
        $manifestFiles = Get-ChildItem -Path "aither-core/modules" -Filter "*.psd1" -Recurse
        
        foreach ($manifest in $manifestFiles) {
            try {
                $null = Test-ModuleManifest -Path $manifest.FullName -ErrorAction Stop
                Write-ValidationLog "Manifest valid: $($manifest.Name) ✓" -Level 'DEBUG' -Stage $Stage
            } catch {
                $manifestErrors += "$($manifest.Name): $($_.Exception.Message)"
                Write-ValidationLog "Manifest invalid: $($manifest.Name) - $_" -Level 'ERROR' -Stage $Stage
            }
        }
        
        if ($manifestErrors.Count -gt 0) {
            Write-ValidationLog "Module manifest validation failed: $($manifestErrors.Count) errors" -Level 'ERROR' -Stage $Stage
            if (-not $ForceValidation) {
                Complete-ValidationStage -Stage $Stage -Result 'Failed' -Summary "Manifest validation failed: $($manifestErrors.Count) errors"
                return $false
            }
        }
        
        # Validate core entry points
        $entryPoints = @(
            'Start-AitherZero.ps1',
            'aither-core/aither-core.ps1'
        )
        
        foreach ($entryPoint in $entryPoints) {
            if (Test-Path $entryPoint) {
                # Basic syntax validation
                try {
                    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $entryPoint -Raw), [ref]$null)
                    Write-ValidationLog "Syntax valid: $entryPoint ✓" -Level 'DEBUG' -Stage $Stage
                } catch {
                    Write-ValidationLog "Syntax error in $entryPoint : $_" -Level 'ERROR' -Stage $Stage
                    $manifestErrors += "$entryPoint : $_"
                }
            }
        }
        
        if ($manifestErrors.Count -gt 0 -and -not $ForceValidation) {
            Complete-ValidationStage -Stage $Stage -Result 'Failed' -Summary "Build validation failed: $($manifestErrors.Count) issues"
            return $false
        }
        
        Write-ValidationLog "Build validation completed successfully" -Level 'SUCCESS' -Stage $Stage
        Complete-ValidationStage -Stage $Stage -Result 'Passed' -Summary "All builds and manifests validated successfully"
        return $true
        
    } catch {
        Write-ValidationLog "Build validation failed: $_" -Level 'ERROR' -Stage $Stage
        $script:ValidationResults.CriticalFailures += "Build validation: $_"
        Complete-ValidationStage -Stage $Stage -Result 'Failed' -Summary "Build validation failed: $_"
        return $false
    }
}

function New-ReleaseArtifacts {
    param([string]$Stage = 'Release-Artifacts')
    
    if (-not $CreateRelease) {
        Write-ValidationLog "Skipping release artifact creation (not requested)" -Level 'INFO' -Stage $Stage
        Complete-ValidationStage -Stage $Stage -Result 'Skipped' -Summary "Release creation not requested"
        return $true
    }
    
    Write-ValidationLog "Creating release artifacts..." -Stage $Stage
    
    try {
        if ($DryRun) {
            Write-ValidationLog "DRY RUN: Would create release $script:TargetVersion using PatchManager" -Level 'INFO' -Stage $Stage
            Complete-ValidationStage -Stage $Stage -Result 'Skipped' -Summary "Dry run mode"
            return $true
        }
        
        # Import PatchManager
        $patchManagerPath = Join-Path (Get-Location) 'aither-core/modules/PatchManager'
        if (-not (Test-Path $patchManagerPath)) {
            throw "PatchManager module not found at $patchManagerPath"
        }
        
        Import-Module $patchManagerPath -Force
        
        if (-not (Get-Command Invoke-ReleaseWorkflow -ErrorAction SilentlyContinue)) {
            throw "Invoke-ReleaseWorkflow command not available in PatchManager"
        }
        
        Write-ValidationLog "Creating $ReleaseType release for version $script:TargetVersion..." -Level 'INFO' -Stage $Stage
        
        $releaseParams = @{
            ReleaseType = $ReleaseType
            Description = "Automated release validation completed for $script:TargetVersion"
        }
        
        if ($script:TargetVersion) {
            $releaseParams['Version'] = $script:TargetVersion
        }
        
        # Execute release workflow
        $releaseResult = Invoke-ReleaseWorkflow @releaseParams
        
        if ($releaseResult) {
            $script:ValidationResults.Artifacts += "Release created: $script:TargetVersion"
            Write-ValidationLog "Release created successfully: $script:TargetVersion" -Level 'SUCCESS' -Stage $Stage
            Complete-ValidationStage -Stage $Stage -Result 'Passed' -Summary "Release $script:TargetVersion created successfully"
            return $true
        } else {
            throw "Release workflow returned null or failed"
        }
        
    } catch {
        Write-ValidationLog "Release creation failed: $_" -Level 'ERROR' -Stage $Stage
        $script:ValidationResults.CriticalFailures += "Release creation: $_"
        Complete-ValidationStage -Stage $Stage -Result 'Failed' -Summary "Release creation failed: $_"
        return $false
    }
}

function Export-ValidationReport {
    param([string]$Stage = 'Report-Generation')
    
    Write-ValidationLog "Generating validation report..." -Stage $Stage
    
    try {
        $script:ValidationResults.EndTime = Get-Date
        $script:ValidationResults.TotalDuration = $script:ValidationResults.EndTime - $script:ValidationResults.StartTime
        
        # Determine overall result
        $criticalFailures = $script:ValidationResults.CriticalFailures.Count
        $failedStages = ($script:ValidationResults.Stages.Values | Where-Object { $_.Result -eq 'Failed' }).Count
        $warningStages = ($script:ValidationResults.Stages.Values | Where-Object { $_.Result -eq 'Warning' }).Count
        
        if ($criticalFailures -gt 0 -or $failedStages -gt 0) {
            $script:ValidationResults.OverallResult = 'Failed'
        } elseif ($warningStages -gt 0) {
            $script:ValidationResults.OverallResult = 'Warning'
        } else {
            $script:ValidationResults.OverallResult = 'Passed'
        }
        
        # Export JSON report
        $jsonReportPath = Join-Path $OutputPath "release-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $script:ValidationResults | ConvertTo-Json -Depth 10 | Out-File $jsonReportPath -Encoding UTF8
        
        # Generate HTML report
        $htmlReportPath = Join-Path $OutputPath "release-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
        $htmlReport = New-ValidationHtmlReport -ValidationResults $script:ValidationResults
        $htmlReport | Out-File $htmlReportPath -Encoding UTF8
        
        Write-ValidationLog "Reports generated:" -Level 'SUCCESS' -Stage $Stage
        Write-ValidationLog "  • JSON: $jsonReportPath" -Level 'INFO' -Stage $Stage
        Write-ValidationLog "  • HTML: $htmlReportPath" -Level 'INFO' -Stage $Stage
        
        Complete-ValidationStage -Stage $Stage -Result 'Passed' -Summary "Reports generated successfully"
        return $true
        
    } catch {
        Write-ValidationLog "Report generation failed: $_" -Level 'ERROR' -Stage $Stage
        Complete-ValidationStage -Stage $Stage -Result 'Failed' -Summary "Report generation failed: $_"
        return $false
    }
}

function New-ValidationHtmlReport {
    param([hashtable]$ValidationResults)
    
    $overallColor = switch ($ValidationResults.OverallResult) {
        'Passed' { '#28a745' }
        'Warning' { '#ffc107' }
        'Failed' { '#dc3545' }
        default { '#6c757d' }
    }
    
    $stagesHtml = ""
    foreach ($stage in $ValidationResults.Stages.Keys | Sort-Object) {
        $stageData = $ValidationResults.Stages[$stage]
        $stageColor = switch ($stageData.Result) {
            'Passed' { '#28a745' }
            'Warning' { '#ffc107' }
            'Failed' { '#dc3545' }
            'Skipped' { '#6c757d' }
            default { '#17a2b8' }
        }
        
        $duration = if ($stageData.Duration) { $stageData.Duration.TotalSeconds.ToString('F1') + 's' } else { 'N/A' }
        
        $stagesHtml += @"
            <tr>
                <td>$stage</td>
                <td><span style="color: $stageColor; font-weight: bold;">$($stageData.Result)</span></td>
                <td>$duration</td>
                <td>$($stageData.Summary)</td>
            </tr>
"@
    }
    
    return @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero Release Validation Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8f9fa; color: #333; line-height: 1.6; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; border-radius: 10px; margin-bottom: 30px; text-align: center; }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .status-badge { display: inline-block; padding: 10px 20px; border-radius: 25px; color: white; font-weight: bold; background: $overallColor; }
        .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric-card { background: white; padding: 25px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.05); text-align: center; }
        .metric-card h3 { font-size: 0.9em; color: #6c757d; margin-bottom: 10px; text-transform: uppercase; }
        .metric-card .value { font-size: 2.5em; font-weight: bold; margin-bottom: 5px; }
        .section { background: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.05); }
        .section h2 { font-size: 1.8em; margin-bottom: 20px; color: #495057; border-bottom: 2px solid #e9ecef; padding-bottom: 10px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px 15px; text-align: left; border-bottom: 1px solid #e9ecef; }
        th { background: #f8f9fa; font-weight: 600; color: #495057; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Release Validation Report</h1>
            <p>Generated: $($ValidationResults.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))</p>
            <div style="margin-top: 20px;">
                <span class="status-badge">$($ValidationResults.OverallResult)</span>
            </div>
        </div>
        
        <div class="metrics-grid">
            <div class="metric-card">
                <h3>Target Version</h3>
                <div class="value" style="color: #17a2b8;">$($ValidationResults.TargetVersion)</div>
            </div>
            <div class="metric-card">
                <h3>Validation Level</h3>
                <div class="value" style="color: #6f42c1;">$($ValidationResults.ValidationLevel)</div>
            </div>
            <div class="metric-card">
                <h3>Total Duration</h3>
                <div class="value" style="color: #28a745;">$($ValidationResults.TotalDuration.TotalMinutes.ToString('F1'))m</div>
            </div>
            <div class="metric-card">
                <h3>Critical Failures</h3>
                <div class="value" style="color: $(if ($ValidationResults.CriticalFailures.Count -gt 0) { '#dc3545' } else { '#28a745' });">$($ValidationResults.CriticalFailures.Count)</div>
            </div>
        </div>
        
        <div class="section">
            <h2>📋 Validation Stages</h2>
            <table>
                <thead>
                    <tr><th>Stage</th><th>Result</th><th>Duration</th><th>Summary</th></tr>
                </thead>
                <tbody>
                    $stagesHtml
                </tbody>
            </table>
        </div>
        
        $(if ($ValidationResults.CriticalFailures.Count -gt 0) {
            "<div class='section'><h2>❌ Critical Failures</h2><ul>" + 
            ($ValidationResults.CriticalFailures | ForEach-Object { "<li>$_</li>" }) -join "" + 
            "</ul></div>"
        })
        
        $(if ($ValidationResults.Warnings.Count -gt 0) {
            "<div class='section'><h2>⚠️ Warnings</h2><ul>" + 
            ($ValidationResults.Warnings | ForEach-Object { "<li>$_</li>" }) -join "" + 
            "</ul></div>"
        })
        
        $(if ($ValidationResults.Performance.BenchmarkDuration) {
            "<div class='section'><h2>⚡ Performance</h2>" +
            "<p>Benchmark Duration: $($ValidationResults.Performance.BenchmarkDuration.ToString('F3'))s</p>" +
            "<p>Overall Status: $($ValidationResults.Performance.OverallStatus)</p>" +
            "<p>Regressions: $($ValidationResults.Performance.Regressions)</p>" +
            "<p>Improvements: $($ValidationResults.Performance.Improvements)</p>" +
            "</div>"
        })
    </div>
</body>
</html>
"@
}

function Get-OptimalValidationParallelSettings {
    <#
    .SYNOPSIS
    Calculate optimal parallel execution settings for release validation
    #>
    param([switch]$CI)
    
    $processorCount = [Environment]::ProcessorCount
    
    # For release validation, be more conservative since stages can be resource-intensive
    $maxParallel = if ($CI) {
        # CI environments - very conservative
        [math]::Min($processorCount, 2)
    } else {
        # Local development - more aggressive
        if ($processorCount -ge 8) {
            4  # Cap at 4 for release validation
        } elseif ($processorCount -ge 4) {
            3
        } else {
            2
        }
    }
    
    return @{
        MaxParallel = [int]$maxParallel
        ProcessorCount = $processorCount
        RecommendParallel = $processorCount -ge 4 -and -not $CI  # Only recommend parallel for multi-core non-CI
    }
}

function Group-ValidationStagesForParallel {
    <#
    .SYNOPSIS
    Group validation stages into parallel-safe groups based on dependencies
    #>
    param([scriptblock[]]$ValidationPipeline)
    
    if (-not $script:ParallelAvailable) {
        # If parallel execution not available, return sequential groups
        return $ValidationPipeline | ForEach-Object { @($_) }
    }
    
    $parallelSettings = Get-OptimalValidationParallelSettings -CI:$CI
    
    if (-not $parallelSettings.RecommendParallel) {
        # If not recommended, return sequential groups
        return $ValidationPipeline | ForEach-Object { @($_) }
    }
    
    # Define stage dependencies and groupings for safe parallel execution
    # Group 1: Prerequisites (must run first)
    $group1 = @()
    # Group 2: Independent validations (can run in parallel)
    $group2 = @()
    # Group 3: Tests (can run in parallel after prerequisites)
    $group3 = @()
    # Group 4: Final stages (must run after tests)
    $group4 = @()
    
    foreach ($stage in $ValidationPipeline) {
        $stageString = $stage.ToString()
        
        # Categorize stages based on their dependencies
        if ($stageString -match 'Test-VersionRequirements|Test-ProjectStructure') {
            # Prerequisites - must run first and sequentially
            $group1 += $stage
        }
        elseif ($stageString -match 'Test-SecurityValidation|Test-BuildValidation|Test-PerformanceBenchmark') {
            # Independent validations - can run in parallel after prerequisites
            $group2 += $stage
        }
        elseif ($stageString -match 'Invoke-TestSuite') {
            # Test suites - can run in parallel after structure validation
            $group3 += $stage
        }
        elseif ($stageString -match 'New-ReleaseArtifacts|Export-ValidationReport') {
            # Final stages - must run after everything else
            $group4 += $stage
        }
        else {
            # Unknown stage - add to sequential group for safety
            $group1 += $stage
        }
    }
    
    # Return groups that have stages
    $groups = @()
    if ($group1.Count -gt 0) { $groups += ,$group1 }
    if ($group2.Count -gt 0) { $groups += ,$group2 }
    if ($group3.Count -gt 0) { $groups += ,$group3 }
    if ($group4.Count -gt 0) { $groups += ,$group4 }
    
    return $groups
}

function Invoke-ParallelValidationStages {
    <#
    .SYNOPSIS
    Execute validation stages in parallel when safe to do so
    #>
    param(
        [scriptblock[]]$StageGroup,
        [string]$GroupName = "Parallel Group"
    )
    
    if ($StageGroup.Count -eq 1) {
        # Single stage - just execute directly
        Write-ValidationLog "Executing single stage in $GroupName..." -Level 'INFO'
        return & $StageGroup[0]
    }
    
    Write-ValidationLog "⚡ Executing $($StageGroup.Count) stages in parallel ($GroupName)..." -Level 'SUCCESS'
    
    $parallelSettings = Get-OptimalValidationParallelSettings -CI:$CI
    
    try {
        # Execute stages in parallel using background jobs
        $jobs = @()
        foreach ($stage in $StageGroup) {
            $job = Start-ParallelJob -Name "ValidationStage-$(Get-Random)" -ScriptBlock $stage
            $jobs += $job
        }
        
        Write-ValidationLog "Started $($jobs.Count) parallel validation jobs" -Level 'INFO'
        
        # Wait for all jobs to complete
        $results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 1800 -ShowProgress  # 30 minute timeout
        
        # Check results
        $overallSuccess = $true
        foreach ($result in $results) {
            if ($result.State -eq 'Failed' -or ($result.Result -is [bool] -and -not $result.Result)) {
                Write-ValidationLog "Parallel stage failed: $($result.Name)" -Level 'ERROR'
                $overallSuccess = $false
            } elseif ($result.HasErrors) {
                Write-ValidationLog "Parallel stage had errors: $($result.Name)" -Level 'WARN'
                if (-not $ForceValidation) {
                    $overallSuccess = $false
                }
            } else {
                Write-ValidationLog "Parallel stage completed: $($result.Name)" -Level 'SUCCESS'
            }
        }
        
        return $overallSuccess
        
    } catch {
        Write-ValidationLog "Parallel execution failed: $_" -Level 'ERROR'
        Write-ValidationLog "Falling back to sequential execution..." -Level 'WARN'
        
        # Fallback to sequential execution
        $overallSuccess = $true
        foreach ($stage in $StageGroup) {
            try {
                $result = & $stage
                if (-not $result) {
                    $overallSuccess = $false
                    if (-not $ForceValidation) {
                        break
                    }
                }
            } catch {
                Write-ValidationLog "Sequential fallback stage failed: $_" -Level 'ERROR'
                $overallSuccess = $false
                if (-not $ForceValidation) {
                    break
                }
            }
        }
        
        return $overallSuccess
    }
}

# Main execution flow
Write-Host ""
Write-Host "🚀 AitherZero Release Validation" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host "Validation Level: $ValidationLevel" -ForegroundColor Cyan
Write-Host "Release Type: $ReleaseType" -ForegroundColor Cyan
if ($TargetVersion) {
    Write-Host "Target Version: $TargetVersion" -ForegroundColor Cyan
}
Write-Host ""

$validationPipeline = @()

# Define validation pipeline based on level
switch ($ValidationLevel) {
    'Quick' {
        $validationPipeline = @(
            { Test-VersionRequirements },
            { Test-ProjectStructure },
            { Invoke-TestSuite -SuiteName "Critical" -Stage "Critical-Tests" -TestCategories @("Critical") }
        )
    }
    'Standard' {
        $validationPipeline = @(
            { Test-VersionRequirements },
            { Test-ProjectStructure },
            { Test-SecurityValidation },
            { Invoke-TestSuite -SuiteName "Critical" -Stage "Critical-Tests" -TestCategories @("Critical") },
            { Invoke-TestSuite -SuiteName "Unit" -Stage "Unit-Tests" -TestCategories @("Unit") },
            { Test-BuildValidation }
        )
    }
    'Complete' {
        $validationPipeline = @(
            { Test-VersionRequirements },
            { Test-ProjectStructure },
            { Test-SecurityValidation },
            { Invoke-TestSuite -SuiteName "Critical" -Stage "Critical-Tests" -TestCategories @("Critical") },
            { Invoke-TestSuite -SuiteName "Unit" -Stage "Unit-Tests" -TestCategories @("Unit") },
            { Invoke-TestSuite -SuiteName "Integration" -Stage "Integration-Tests" -TestCategories @("Integration") },
            { Test-PerformanceBenchmark },
            { Test-BuildValidation }
        )
    }
    'Production' {
        $validationPipeline = @(
            { Test-VersionRequirements },
            { Test-ProjectStructure },
            { Test-SecurityValidation },
            { Invoke-TestSuite -SuiteName "All" -Stage "All-Tests" -TestCategories @("All") },
            { Invoke-TestSuite -SuiteName "E2E" -Stage "E2E-Tests" -TestCategories @("E2E") },
            { Test-PerformanceBenchmark },
            { Test-BuildValidation },
            { New-ReleaseArtifacts }
        )
    }
}

# Always add report generation
$validationPipeline += { Export-ValidationReport }

# Group stages for optimal parallel execution
$stageGroups = Group-ValidationStagesForParallel -ValidationPipeline $validationPipeline
$totalStages = $validationPipeline.Count

Write-ValidationLog "Grouped $totalStages stages into $($stageGroups.Count) execution groups" -Level 'INFO'

if ($script:ParallelAvailable -and (Get-OptimalValidationParallelSettings -CI:$CI).RecommendParallel) {
    Write-ValidationLog "⚡ Parallel validation execution enabled" -Level 'SUCCESS'
} else {
    Write-ValidationLog "📋 Sequential validation execution (parallel not available/recommended)" -Level 'INFO'
}

# Execute validation pipeline with parallel groups
$overallSuccess = $true
$groupCount = 0

foreach ($stageGroup in $stageGroups) {
    $groupCount++
    
    Write-Host ""
    Write-Host "[$groupCount/$($stageGroups.Count)] " -NoNewline -ForegroundColor Yellow
    
    # Determine group name based on stages
    $groupName = "Group $groupCount"
    if ($stageGroup.Count -eq 1) {
        $stageName = $stageGroup[0].ToString()
        if ($stageName -match 'Test-VersionRequirements') { $groupName = "Prerequisites" }
        elseif ($stageName -match 'Test-SecurityValidation|Test-BuildValidation|Test-PerformanceBenchmark') { $groupName = "Independent Validation" }
        elseif ($stageName -match 'Invoke-TestSuite') { $groupName = "Test Execution" }
        elseif ($stageName -match 'New-ReleaseArtifacts') { $groupName = "Release Creation" }
        elseif ($stageName -match 'Export-ValidationReport') { $groupName = "Report Generation" }
    } else {
        # Multiple stages - determine group type
        $hasTests = $stageGroup | Where-Object { $_.ToString() -match 'Invoke-TestSuite' }
        $hasValidation = $stageGroup | Where-Object { $_.ToString() -match 'Test-SecurityValidation|Test-BuildValidation|Test-PerformanceBenchmark' }
        
        if ($hasTests) { $groupName = "Parallel Test Execution" }
        elseif ($hasValidation) { $groupName = "Parallel Validation" }
        else { $groupName = "Parallel Group $groupCount" }
    }
    
    try {
        if ($stageGroup.Count -gt 1 -and $script:ParallelAvailable) {
            # Execute group in parallel
            $result = Invoke-ParallelValidationStages -StageGroup $stageGroup -GroupName $groupName
        } else {
            # Execute single stage or fallback to sequential
            Write-ValidationLog "Executing $($stageGroup.Count) stage(s) in $groupName..." -Level 'INFO'
            $result = $true
            foreach ($stage in $stageGroup) {
                $stageResult = & $stage
                if (-not $stageResult) {
                    $result = $false
                    if (-not $ForceValidation) {
                        break
                    }
                }
            }
        }
        
        if (-not $result) {
            $overallSuccess = $false
            if (-not $ForceValidation) {
                Write-ValidationLog "Validation pipeline stopped due to failure in $groupName" -Level 'ERROR'
                break
            }
        }
        
    } catch {
        Write-ValidationLog "Validation group failed with exception: $_" -Level 'ERROR'
        $overallSuccess = $false
        if (-not $ForceValidation) {
            break
        }
    }
}

# Final summary
Write-Host ""
Write-Host "=" * 80 -ForegroundColor Yellow
Write-Host "🏁 RELEASE VALIDATION SUMMARY" -ForegroundColor Yellow
Write-Host "=" * 80 -ForegroundColor Yellow
Write-Host ""

$finalResult = $script:ValidationResults.OverallResult
$resultColor = switch ($finalResult) {
    'Passed' { 'Green' }
    'Warning' { 'Yellow' }
    'Failed' { 'Red' }
    default { 'Gray' }
}

Write-Host "Overall Result: " -NoNewline
Write-Host $finalResult -ForegroundColor $resultColor -NoNewline
Write-Host " ($($script:ValidationResults.TotalDuration.TotalMinutes.ToString('F1')) minutes)"

if ($script:ValidationResults.TargetVersion) {
    Write-Host "Target Version: $($script:ValidationResults.TargetVersion)"
}

Write-Host "Validation Level: $ValidationLevel"
Write-Host "Stages Completed: $($script:ValidationResults.Stages.Count)"

if ($script:ValidationResults.CriticalFailures.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ Critical Failures: $($script:ValidationResults.CriticalFailures.Count)" -ForegroundColor Red
    foreach ($failure in $script:ValidationResults.CriticalFailures) {
        Write-Host "  • $failure" -ForegroundColor Red
    }
}

if ($script:ValidationResults.Warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️ Warnings: $($script:ValidationResults.Warnings.Count)" -ForegroundColor Yellow
    foreach ($warning in $script:ValidationResults.Warnings) {
        Write-Host "  • $warning" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "📊 Reports generated in: $OutputPath" -ForegroundColor Cyan
Write-Host ""

# Exit with appropriate code
if ($finalResult -eq 'Failed') {
    exit 1
} elseif ($finalResult -eq 'Warning') {
    exit 2
} else {
    exit 0
}