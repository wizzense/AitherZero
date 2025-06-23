#Requires -Version 7.0

<#
.SYNOPSIS
    Enhanced error and test failure handler with automatic GitHub issue creation
    
.DESCRIPTION
    This function automatically detects and handles:
    1. Test failures (Pester, pytest, PSScriptAnalyzer)
    2. Runtime errors and exceptions
    3. Build/deployment failures
    4. Any other errors or warnings
    
    Creates GitHub issues for central tracking and systematic resolution.
    
.PARAMETER ErrorRecord
    The PowerShell error record to process
    
.PARAMETER TestResults
    Test results object from Pester or other test frameworks
    
.PARAMETER ErrorType
    Type of error (TestFailure, RuntimeError, BuildFailure, Warning)
    
.PARAMETER Context
    Additional context information
    
.PARAMETER CreateIssue
    Whether to automatically create a GitHub issue (default: true)
    
.EXAMPLE
    Invoke-ErrorHandler -ErrorRecord $Error[0] -ErrorType "RuntimeError" -Context @{Operation = "Module Import"}
    
.EXAMPLE
    Invoke-ErrorHandler -TestResults $PesterResults -ErrorType "TestFailure"
    
.NOTES
    - Integrates with Invoke-ComprehensiveIssueTracking
    - Provides detailed error analysis and context
    - Creates actionable GitHub issues for systematic resolution
    - Supports all major error types and test frameworks
#>

function Invoke-ErrorHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [Parameter(Mandatory = $false)]
        [object]$TestResults,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("TestFailure", "RuntimeError", "BuildFailure", "Warning", "ImportError", "SyntaxError")]
        [string]$ErrorType,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Context = @{},
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateIssue = $true,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Critical", "High", "Medium", "Low")]
        [string]$Priority = "Medium"
    )
    
    begin {
        Write-CustomLog "Processing error/failure: $ErrorType" -Level INFO
        
        # Import comprehensive issue tracking if available
        try {
            $projectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else { "c:\Users\alexa\OneDrive\Documents\0. wizzense\opentofu-lab-automation" }
            Import-Module "$projectRoot\pwsh\modules\PatchManager\Public\Invoke-ComprehensiveIssueTracking.ps1" -Force -ErrorAction SilentlyContinue
        } catch {
            Write-CustomLog "Could not import comprehensive issue tracking: $($_.Exception.Message)" -Level WARN
        }
    }
    
    process {
        # Analyze the error/failure and extract detailed information
        $analysisResult = Analyze-ErrorDetails -ErrorRecord $ErrorRecord -TestResults $TestResults -ErrorType $ErrorType -Context $Context
        
        # Log the error details locally
        Write-CustomLog "=== ERROR/FAILURE DETECTED ===" -Level ERROR
        Write-CustomLog "Type: $ErrorType" -Level ERROR
        Write-CustomLog "Summary: $($analysisResult.Summary)" -Level ERROR
        if ($analysisResult.Details) {
            Write-CustomLog "Details: $($analysisResult.Details)" -Level ERROR
        }
        
        # Create GitHub issue for tracking if enabled
        if ($CreateIssue) {
            try {
                Write-CustomLog "Creating GitHub issue for error tracking..." -Level INFO
                
                $operation = switch ($ErrorType) {
                    "TestFailure" { "TestFailure" }
                    "RuntimeError" { "RuntimeFailure" }
                    "BuildFailure" { "Error" }
                    "Warning" { "Warning" }
                    "ImportError" { "Error" }
                    "SyntaxError" { "Error" }
                    default { "Error" }
                }
                
                $issueResult = Invoke-ComprehensiveIssueTracking -Operation $operation -Title $analysisResult.IssueTitle -Description $analysisResult.IssueDescription -ErrorDetails $analysisResult.ErrorDetails -AffectedFiles $analysisResult.AffectedFiles -Priority $Priority
                
                if ($issueResult.Success) {
                    Write-CustomLog "Error tracking issue created: $($issueResult.IssueUrl)" -Level SUCCESS
                    Write-CustomLog "Issue #$($issueResult.IssueNumber) will track resolution of this $ErrorType" -Level INFO
                    
                    return @{
                        Success = $true
                        ErrorProcessed = $true
                        IssueCreated = $true
                        IssueUrl = $issueResult.IssueUrl
                        IssueNumber = $issueResult.IssueNumber
                        Summary = $analysisResult.Summary
                        Recommendation = $analysisResult.Recommendation
                    }
                } else {
                    Write-CustomLog "Failed to create error tracking issue: $($issueResult.Message)" -Level WARN
                    
                    return @{
                        Success = $true
                        ErrorProcessed = $true
                        IssueCreated = $false
                        IssueCreationError = $issueResult.Message
                        Summary = $analysisResult.Summary
                        Recommendation = $analysisResult.Recommendation
                    }
                }
            } catch {
                Write-CustomLog "Exception while creating error tracking issue: $($_.Exception.Message)" -Level ERROR
                
                return @{
                    Success = $true
                    ErrorProcessed = $true
                    IssueCreated = $false
                    IssueCreationError = $_.Exception.Message
                    Summary = $analysisResult.Summary
                    Recommendation = $analysisResult.Recommendation
                }
            }
        } else {
            Write-CustomLog "Issue creation disabled - error logged locally only" -Level INFO
            
            return @{
                Success = $true
                ErrorProcessed = $true
                IssueCreated = $false
                Summary = $analysisResult.Summary
                Recommendation = $analysisResult.Recommendation
            }
        }
    }
}

function Analyze-ErrorDetails {
    [CmdletBinding()]
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [object]$TestResults,
        [string]$ErrorType,
        [hashtable]$Context
    )
    
    $analysis = @{
        Summary = ""
        Details = ""
        IssueTitle = ""
        IssueDescription = ""
        ErrorDetails = @{}
        AffectedFiles = @()
        Recommendation = ""
    }
    
    switch ($ErrorType) {
        "TestFailure" {
            if ($TestResults) {
                # Handle Pester test results
                if ($TestResults.PSObject.Properties.Name -contains "FailedTests") {
                    $failedCount = $TestResults.FailedTests.Count
                    $totalCount = $TestResults.TotalTests
                    
                    $analysis.Summary = "Pester test failures: $failedCount out of $totalCount tests failed"
                    $analysis.IssueTitle = "Test Failures: $failedCount Pester tests failing"
                    
                    $failureDetails = $TestResults.FailedTests | ForEach-Object {
                        "- **$($_.Name)**: $($_.FailureMessage)"
                    } | Out-String
                    
                    $analysis.Details = $failureDetails
                    $analysis.IssueDescription = @"
Multiple Pester tests are failing and require investigation and fixes.

## Failed Tests Summary
$failedCount out of $totalCount tests failed.

## Failed Test Details
$failureDetails

## Impact
Test failures indicate potential regressions or issues that need to be addressed to maintain code quality and prevent deployment issues.

## Next Steps
1. Investigate each failing test individually
2. Determine if tests need updates or if code needs fixes
3. Fix underlying issues or update test expectations
4. Validate all tests pass after fixes
"@
                    
                    $analysis.ErrorDetails = @{
                        FailedTestCount = $failedCount
                        TotalTestCount = $totalCount
                        TestFramework = "Pester"
                        FailedTests = $TestResults.FailedTests
                        TestOutput = $TestResults.Output
                    }
                    
                    $analysis.AffectedFiles = $TestResults.FailedTests | ForEach-Object { $_.Source } | Where-Object { $_ } | Sort-Object -Unique
                    $analysis.Recommendation = "Review and fix failing tests to restore test suite integrity"
                    
                } elseif ($TestResults.PSObject.Properties.Name -contains "Failed") {
                    # Handle simple test result format
                    $analysis.Summary = "Test failure detected"
                    $analysis.IssueTitle = "Test Failure: Investigation Required"
                    $analysis.IssueDescription = "Test failure detected requiring investigation and resolution."
                    $analysis.ErrorDetails = @{
                        TestResults = $TestResults
                        TestFramework = "Unknown"
                    }
                    $analysis.Recommendation = "Investigate test failure and implement appropriate fix"
                }
            } else {
                $analysis.Summary = "Test failure reported without detailed results"
                $analysis.IssueTitle = "Test Failure: Details Unknown"
                $analysis.IssueDescription = "Test failure was reported but detailed results are not available."
                $analysis.Recommendation = "Gather more details about the test failure and rerun analysis"
            }
        }
        
        "RuntimeError" {
            if ($ErrorRecord) {
                $analysis.Summary = "Runtime error: $($ErrorRecord.Exception.Message)"
                $analysis.IssueTitle = "Runtime Error: $($ErrorRecord.Exception.GetType().Name)"
                $analysis.Details = $ErrorRecord.Exception.Message
                
                $analysis.IssueDescription = @"
A runtime error occurred during script execution that requires investigation and resolution.

## Error Details
**Exception Type**: $($ErrorRecord.Exception.GetType().FullName)
**Error Message**: $($ErrorRecord.Exception.Message)
**Script**: $($ErrorRecord.InvocationInfo.ScriptName)
**Line Number**: $($ErrorRecord.InvocationInfo.ScriptLineNumber)
**Line**: $($ErrorRecord.InvocationInfo.Line.Trim())

## Stack Trace
```
$($ErrorRecord.ScriptStackTrace)
```

## Impact
Runtime errors can cause script failures, data corruption, or unexpected behavior that affects system reliability.

## Next Steps
1. Analyze the error context and root cause
2. Implement appropriate error handling or fix
3. Test the fix thoroughly
4. Consider adding prevention measures
"@
                
                $analysis.ErrorDetails = @{
                    Exception = $ErrorRecord.Exception
                    ErrorMessage = $ErrorRecord.Exception.Message
                    ScriptName = $ErrorRecord.InvocationInfo.ScriptName
                    LineNumber = $ErrorRecord.InvocationInfo.ScriptLineNumber
                    ScriptStackTrace = $ErrorRecord.ScriptStackTrace
                    CommandName = $ErrorRecord.InvocationInfo.InvocationName
                }
                
                if ($ErrorRecord.InvocationInfo.ScriptName) {
                    $analysis.AffectedFiles = @($ErrorRecord.InvocationInfo.ScriptName)
                }
                
                $analysis.Recommendation = "Investigate error context and implement appropriate fix with error handling"
            }
        }
        
        "BuildFailure" {
            $analysis.Summary = "Build or deployment failure occurred"
            $analysis.IssueTitle = "Build Failure: Deployment Process Error"
            $analysis.IssueDescription = @"
A build or deployment failure occurred that prevents successful completion of the process.

## Context
$(if ($Context.Operation) { "**Operation**: $($Context.Operation)" })
$(if ($Context.Stage) { "**Build Stage**: $($Context.Stage)" })
$(if ($Context.ErrorMessage) { "**Error**: $($Context.ErrorMessage)" })

## Impact
Build failures prevent successful deployment and can block development workflows.

## Next Steps
1. Review build logs and error details
2. Identify the root cause of the failure
3. Fix the underlying issue
4. Validate the build process works correctly
"@
            
            $analysis.ErrorDetails = $Context
            $analysis.Recommendation = "Review build process and fix identified issues"
        }
        
        "Warning" {
            $warningMessage = if ($Context.WarningMessage) { $Context.WarningMessage } else { "Warning condition detected" }
            $analysis.Summary = "Warning: $warningMessage"
            $analysis.IssueTitle = "Warning Condition: Monitoring Required"
            $analysis.IssueDescription = @"
A warning condition has been detected that should be monitored and potentially addressed.

## Warning Details
$warningMessage

$(if ($Context.Source) { "**Source**: $($Context.Source)" })
$(if ($Context.Frequency) { "**Frequency**: $($Context.Frequency)" })

## Impact
Warnings may indicate potential issues that could become problems if left unaddressed.

## Next Steps
1. Monitor the frequency and pattern of this warning
2. Assess potential impact if condition worsens
3. Determine if preventive action is needed
"@
            
            $analysis.ErrorDetails = $Context
            $analysis.Recommendation = "Monitor warning condition and assess if action is required"
        }
        
        "ImportError" {
            $analysis.Summary = "Module or script import failure"
            $analysis.IssueTitle = "Import Error: Module Loading Failed"
            $analysis.IssueDescription = @"
A module or script import failed, which can cause functionality issues and script failures.

## Import Details
$(if ($Context.ModuleName) { "**Module**: $($Context.ModuleName)" })
$(if ($Context.Path) { "**Path**: $($Context.Path)" })
$(if ($ErrorRecord) { "**Error**: $($ErrorRecord.Exception.Message)" })

## Impact
Import failures can cause missing functionality and script execution errors.

## Next Steps
1. Verify module/script exists at expected location
2. Check file permissions and accessibility
3. Validate module/script syntax and dependencies
4. Fix path or module issues
"@
            
            $analysis.ErrorDetails = $Context
            if ($Context.Path) {
                $analysis.AffectedFiles = @($Context.Path)
            }
            $analysis.Recommendation = "Verify and fix module/script import paths and dependencies"
        }
        
        "SyntaxError" {
            $analysis.Summary = "PowerShell syntax error detected"
            $analysis.IssueTitle = "Syntax Error: PowerShell Parsing Failed"
            $analysis.IssueDescription = @"
PowerShell syntax errors were detected that prevent script execution.

## Syntax Error Details
$(if ($Context.FileName) { "**File**: $($Context.FileName)" })
$(if ($Context.LineNumber) { "**Line**: $($Context.LineNumber)" })
$(if ($Context.ErrorMessage) { "**Error**: $($Context.ErrorMessage)" })

## Impact
Syntax errors prevent script execution and can cause build failures.

## Next Steps
1. Review and fix syntax errors in identified files
2. Use PowerShell ISE or VS Code for syntax validation
3. Test script execution after fixes
4. Consider adding syntax validation to CI/CD pipeline
"@
            
            $analysis.ErrorDetails = $Context
            if ($Context.FileName) {
                $analysis.AffectedFiles = @($Context.FileName)
            }
            $analysis.Recommendation = "Fix PowerShell syntax errors and validate script execution"
        }
    }
    
    # Add context information if provided
    if ($Context.Count -gt 0) {
        $analysis.ErrorDetails += $Context
    }
    
    return $analysis
}


