#Requires -Version 7.0

<#
.SYNOPSIS
    Automated error and failure detection and tracking system for PatchManager
    
.DESCRIPTION
    This function provides comprehensive automatic error detection and issue creation for:
    1. PowerShell runtime errors and exceptions
    2. Test failures (Pester, pytest, any test framework)
    3. Build and deployment failures
    4. Module import errors
    5. Syntax errors and validation failures
    6. Performance issues and warnings
    
    Automatically creates detailed GitHub issues with full context for systematic resolution.
    
.PARAMETER SourceFunction
    The function or script that triggered the error
    
.PARAMETER ErrorRecord
    PowerShell error record (auto-detected from $Error if not provided)
    
.PARAMETER TestResults
    Test results from any testing framework
    
.PARAMETER Context
    Additional context information about the operation
    
.PARAMETER Priority
    Priority level for the issue (auto-determined if not specified)
    
.PARAMETER AffectedFiles
    Files affected by the error/failure
    
.PARAMETER AlwaysCreateIssue
    Always create an issue regardless of error severity
    
.EXAMPLE
    Invoke-AutomatedErrorTracking -SourceFunction "Invoke-GitControlledPatch" -Context @{Operation = "Branch Creation"}
    
.EXAMPLE
    Invoke-AutomatedErrorTracking -TestResults $PesterResults -SourceFunction "Test Suite"
    
.NOTES
    - Automatically detects error types and severity
    - Creates rich issue content with full diagnostic information
    - Integrates seamlessly with PatchManager workflow
    - Ensures no errors are lost or untracked
#>

function Invoke-AutomatedErrorTracking {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFunction,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [Parameter(Mandatory = $false)]
        [object]$TestResults,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Context = @{},
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Critical", "High", "Medium", "Low")]
        [string]$Priority,
        
        [Parameter(Mandatory = $false)]
        [string[]]$AffectedFiles = @(),
        
        [Parameter(Mandatory = $false)]
        [switch]$AlwaysCreateIssue
    )
    
    begin {
        Write-CustomLog "Starting automated error tracking for: $SourceFunction" -Level INFO
        
        # Auto-detect error if not provided
        if (-not $ErrorRecord -and $Error.Count -gt 0) {
            $ErrorRecord = $Error[0]
            Write-CustomLog "Auto-detected most recent error for analysis" -Level INFO
        }
    }
    
    process {
        try {
            # Comprehensive error analysis
            $errorAnalysis = Get-ComprehensiveErrorAnalysis -ErrorRecord $ErrorRecord -TestResults $TestResults -Context $Context -SourceFunction $SourceFunction
            
            # Determine if issue creation is warranted
            $shouldCreateIssue = $AlwaysCreateIssue -or $errorAnalysis.ShouldCreateIssue
            
            # Auto-determine priority if not specified
            if (-not $Priority) {
                $Priority = $errorAnalysis.RecommendedPriority
            }
            
            Write-CustomLog "Error Analysis Complete:" -Level INFO
            Write-CustomLog "  Type: $($errorAnalysis.ErrorType)" -Level INFO
            Write-CustomLog "  Severity: $($errorAnalysis.Severity)" -Level INFO
            Write-CustomLog "  Priority: $Priority" -Level INFO
            Write-CustomLog "  Should Create Issue: $shouldCreateIssue" -Level INFO
            
            if ($shouldCreateIssue) {
                # Create comprehensive issue
                $issueResult = Invoke-ComprehensiveIssueTracking -Operation $errorAnalysis.IssueOperation -Title $errorAnalysis.IssueTitle -Description $errorAnalysis.IssueDescription -ErrorDetails $errorAnalysis.ErrorDetails -AffectedFiles ($AffectedFiles + $errorAnalysis.DetectedFiles) -Priority $Priority
                
                if ($issueResult.Success) {
                    Write-CustomLog "Automated error tracking issue created: $($issueResult.IssueUrl)" -Level SUCCESS
                    Write-CustomLog "Issue #$($issueResult.IssueNumber) will track resolution" -Level INFO
                    
                    # Log to central error tracking log
                    Add-ErrorTrackingEntry -ErrorAnalysis $errorAnalysis -IssueResult $issueResult -Priority $Priority
                    
                    return @{
                        Success = $true
                        IssueCreated = $true
                        IssueUrl = $issueResult.IssueUrl
                        IssueNumber = $issueResult.IssueNumber
                        ErrorType = $errorAnalysis.ErrorType
                        Severity = $errorAnalysis.Severity
                        Priority = $Priority
                        Summary = $errorAnalysis.Summary
                        Recommendation = $errorAnalysis.Recommendation
                    }
                } else {
                    Write-CustomLog "Failed to create automated tracking issue: $($issueResult.Message)" -Level ERROR
                    
                    return @{
                        Success = $false
                        IssueCreated = $false
                        Error = $issueResult.Message
                        ErrorType = $errorAnalysis.ErrorType
                        Severity = $errorAnalysis.Severity
                        Summary = $errorAnalysis.Summary
                    }
                }
            } else {
                Write-CustomLog "Error severity below threshold - no issue created" -Level INFO
                Write-CustomLog "Summary: $($errorAnalysis.Summary)" -Level INFO
                
                return @{
                    Success = $true
                    IssueCreated = $false
                    Reason = "Below issue creation threshold"
                    ErrorType = $errorAnalysis.ErrorType
                    Severity = $errorAnalysis.Severity
                    Summary = $errorAnalysis.Summary
                }
            }
            
        } catch {
            Write-CustomLog "Failed to process automated error tracking: $($_.Exception.Message)" -Level ERROR
            
            return @{
                Success = $false
                IssueCreated = $false
                Error = $_.Exception.Message
                Summary = "Error tracking system failure"
            }
        }
    }
}

function Get-ComprehensiveErrorAnalysis {
    [CmdletBinding()]
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [object]$TestResults,
        [hashtable]$Context,
        [string]$SourceFunction
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
    
    # Initialize analysis result
    $analysis = @{
        ErrorType = "Unknown"
        Severity = "Medium"
        RecommendedPriority = "Medium"
        ShouldCreateIssue = $false
        Summary = "Error detected in $SourceFunction"
        Recommendation = "Investigate and resolve"
        IssueOperation = "Error"
        IssueTitle = "Automated Error Detection: $SourceFunction"
        IssueDescription = ""
        ErrorDetails = @{}
        DetectedFiles = @()
    }
    
    # Analyze PowerShell error record
    if ($ErrorRecord) {
        $analysis.ErrorType = Get-ErrorType -ErrorRecord $ErrorRecord
        $analysis.Severity = Get-ErrorSeverity -ErrorRecord $ErrorRecord
        $analysis.ShouldCreateIssue = $true
        
        $analysis.ErrorDetails = @{
            ErrorMessage = $ErrorRecord.Exception.Message
            ErrorCategory = $ErrorRecord.CategoryInfo.Category.ToString()
            Exception = $ErrorRecord.Exception.GetType().FullName
            ScriptStackTrace = $ErrorRecord.ScriptStackTrace
            InvocationInfo = $ErrorRecord.InvocationInfo.PositionMessage
            FullyQualifiedErrorId = $ErrorRecord.FullyQualifiedErrorId
            TargetObject = if ($ErrorRecord.TargetObject) { $ErrorRecord.TargetObject.ToString() } else { "N/A" }
        }
        
        # Extract affected files from stack trace
        if ($ErrorRecord.ScriptStackTrace) {
            $analysis.DetectedFiles = Extract-FilesFromStackTrace -StackTrace $ErrorRecord.ScriptStackTrace
        }
        
        $analysis.Summary = "PowerShell $($analysis.ErrorType): $($ErrorRecord.Exception.Message)"
        $analysis.IssueTitle = "Automated Error: $($analysis.ErrorType) in $SourceFunction"
    }
    
    # Analyze test results
    if ($TestResults) {
        $testAnalysis = Analyze-TestResults -TestResults $TestResults
        
        if ($testAnalysis.HasFailures) {
            $analysis.ErrorType = "TestFailure"
            $analysis.Severity = $testAnalysis.Severity
            $analysis.ShouldCreateIssue = $true
            $analysis.IssueOperation = "TestFailure"
            
            $analysis.ErrorDetails.TestName = $testAnalysis.FailedTestName
            $analysis.ErrorDetails.TestFile = $testAnalysis.TestFile
            $analysis.ErrorDetails.FailureMessage = $testAnalysis.FailureMessage
            $analysis.ErrorDetails.TestOutput = $testAnalysis.TestOutput
            $analysis.ErrorDetails.TestType = $testAnalysis.TestType
            $analysis.ErrorDetails.AffectedFeature = $testAnalysis.AffectedFeature
            
            $analysis.DetectedFiles += $testAnalysis.DetectedFiles
            $analysis.Summary = "Test Failure: $($testAnalysis.FailedTestName) - $($testAnalysis.FailureMessage)"
            $analysis.IssueTitle = "Automated Test Failure: $($testAnalysis.FailedTestName)"
        }
    }
    
    # Analyze context for additional clues
    if ($Context.Count -gt 0) {
        foreach ($key in $Context.Keys) {
            $analysis.ErrorDetails[$key] = $Context[$key]
        }
        
        # Determine error type from context
        if ($Context.Operation -like "*Test*") {
            $analysis.ErrorType = "TestFailure"
            $analysis.IssueOperation = "TestFailure"
        } elseif ($Context.Operation -like "*Import*") {
            $analysis.ErrorType = "ImportError"
        } elseif ($Context.Operation -like "*Syntax*") {
            $analysis.ErrorType = "SyntaxError"
        } elseif ($Context.Operation -like "*Build*" -or $Context.Operation -like "*Deploy*") {
            $analysis.ErrorType = "BuildFailure"
        }
    }
    
    # Set priority based on error type and severity
    $analysis.RecommendedPriority = Get-RecommendedPriority -ErrorType $analysis.ErrorType -Severity $analysis.Severity
    
    # Build comprehensive issue description
    $analysis.IssueDescription = Build-AutomatedIssueDescription -Analysis $analysis -SourceFunction $SourceFunction -Timestamp $timestamp
    
    return $analysis
}

function Get-ErrorType {
    [CmdletBinding()]
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)
    
    $exceptionType = $ErrorRecord.Exception.GetType().Name
    $errorMessage = $ErrorRecord.Exception.Message.ToLower()
    
    if ($exceptionType -like "*Parse*" -or $errorMessage -like "*syntax*") {
        return "SyntaxError"
    } elseif ($exceptionType -like "*Import*" -or $errorMessage -like "*module*" -or $errorMessage -like "*import*") {
        return "ImportError"
    } elseif ($exceptionType -like "*IO*" -or $exceptionType -like "*File*") {
        return "FileSystemError"
    } elseif ($exceptionType -like "*Network*" -or $exceptionType -like "*Web*") {
        return "NetworkError"
    } elseif ($exceptionType -like "*Security*" -or $exceptionType -like "*Unauthorized*") {
        return "SecurityError"
    } else {
        return "RuntimeError"
    }
}

function Get-ErrorSeverity {
    [CmdletBinding()]
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)
    
    $category = $ErrorRecord.CategoryInfo.Category
    $exceptionType = $ErrorRecord.Exception.GetType().Name
    
    if ($category -eq "SecurityError" -or $exceptionType -like "*Security*") {
        return "Critical"
    } elseif ($category -eq "InvalidOperation" -or $category -eq "InvalidArgument") {
        return "High"
    } elseif ($category -eq "ResourceUnavailable" -or $category -eq "ConnectionError") {
        return "Medium"
    } else {
        return "Medium"
    }
}

function Get-RecommendedPriority {
    [CmdletBinding()]
    param([string]$ErrorType, [string]$Severity)
    
    if ($Severity -eq "Critical" -or $ErrorType -eq "SecurityError") {
        return "Critical"
    } elseif ($Severity -eq "High" -or $ErrorType -eq "SyntaxError" -or $ErrorType -eq "TestFailure") {
        return "High"
    } elseif ($ErrorType -eq "ImportError" -or $ErrorType -eq "BuildFailure") {
        return "Medium"
    } else {
        return "Low"
    }
}

function Extract-FilesFromStackTrace {
    [CmdletBinding()]
    param([string]$StackTrace)
    
    $files = @()
    
    # Extract file paths from PowerShell stack traces
    $fileMatches = [regex]::Matches($StackTrace, '(?:at\s+|in\s+)([^:]+\.(ps1|psm1|psd1))', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    
    foreach ($match in $fileMatches) {
        $filePath = $match.Groups[1].Value.Trim()
        if ($filePath -and $filePath -notlike "*<*" -and $files -notcontains $filePath) {
            $files += $filePath
        }
    }
    
    return $files
}

function Analyze-TestResults {
    [CmdletBinding()]
    param([object]$TestResults)
    
    $analysis = @{
        HasFailures = $false
        Severity = "Low"
        FailedTestName = "Unknown"
        TestFile = "Unknown"
        FailureMessage = "Unknown"
        TestOutput = "N/A"
        TestType = "Unknown"
        AffectedFeature = "Unknown"
        DetectedFiles = @()
    }
    
    # Handle Pester results
    if ($TestResults.PSObject.Properties['FailedCount'] -or $TestResults.PSObject.Properties['Failed']) {
        $failedCount = if ($TestResults.FailedCount) { $TestResults.FailedCount } else { $TestResults.Failed.Count }
        
        if ($failedCount -gt 0) {
            $analysis.HasFailures = $true
            $analysis.TestType = "Pester"
            
            if ($failedCount -gt 10) {
                $analysis.Severity = "Critical"
            } elseif ($failedCount -gt 5) {
                $analysis.Severity = "High"
            } else {
                $analysis.Severity = "Medium"
            }
            
            # Get first failed test details
            $firstFailure = if ($TestResults.Failed) { $TestResults.Failed[0] } else { $null }
            if ($firstFailure) {
                $analysis.FailedTestName = $firstFailure.Name
                $analysis.FailureMessage = $firstFailure.FailureMessage
                $analysis.TestFile = $firstFailure.ScriptPath
                if ($analysis.TestFile) {
                    $analysis.DetectedFiles += $analysis.TestFile
                }
            }
        }
    }
    
    # Handle other test framework results (pytest, etc.)
    if ($TestResults.ToString() -like "*FAILED*" -or $TestResults.ToString() -like "*ERROR*") {
        $analysis.HasFailures = $true
        $analysis.TestType = "Generic"
        $analysis.FailureMessage = "Test failures detected in output"
        $analysis.TestOutput = $TestResults.ToString()
    }
    
    return $analysis
}

function Build-AutomatedIssueDescription {
    [CmdletBinding()]
    param([hashtable]$Analysis, [string]$SourceFunction, [string]$Timestamp)
    
    $description = @"
# Automated Error Detection Report

**Source**: $SourceFunction  
**Detected**: $Timestamp  
**Error Type**: $($Analysis.ErrorType)  
**Severity**: $($Analysis.Severity)  
**Priority**: $($Analysis.RecommendedPriority)

## Error Summary

$($Analysis.Summary)

## Detailed Analysis

**Error Category**: $($Analysis.ErrorType)  
**Severity Level**: $($Analysis.Severity)  
**Detection Method**: Automated Error Tracking System

$(if ($Analysis.ErrorDetails.ErrorMessage) {
@"

### PowerShell Error Details
- **Message**: $($Analysis.ErrorDetails.ErrorMessage)
- **Category**: $($Analysis.ErrorDetails.ErrorCategory)
- **Exception Type**: $($Analysis.ErrorDetails.Exception)
- **Error ID**: $($Analysis.ErrorDetails.FullyQualifiedErrorId)
"@
})

$(if ($Analysis.ErrorDetails.ScriptStackTrace) {
@"

### Stack Trace
```
$($Analysis.ErrorDetails.ScriptStackTrace)
```
"@
})

$(if ($Analysis.ErrorDetails.TestName) {
@"

### Test Failure Details
- **Test Name**: $($Analysis.ErrorDetails.TestName)
- **Test File**: $($Analysis.ErrorDetails.TestFile)
- **Failure Message**: $($Analysis.ErrorDetails.FailureMessage)
- **Test Type**: $($Analysis.ErrorDetails.TestType)
"@
})

$(if ($Analysis.DetectedFiles.Count -gt 0) {
@"

### Affected Files
$(foreach ($file in $Analysis.DetectedFiles) { "- ``$file``" })
"@
})

## Resolution Steps

1. **Immediate Action**: Investigate the root cause using the provided error details
2. **Analysis**: Review the stack trace and affected files for patterns
3. **Fix Strategy**: Implement appropriate fix based on error type and severity
4. **Testing**: Validate fix with comprehensive testing
5. **Prevention**: Update error handling or tests to prevent recurrence

## System Context

- **Source Function**: $SourceFunction
- **Detection Time**: $Timestamp
- **Error Type**: $($Analysis.ErrorType)
- **Recommended Priority**: $($Analysis.RecommendedPriority)

## Automation Notes

This issue was created automatically by the PatchManager Automated Error Tracking system. The system detected this error and created this issue to ensure systematic tracking and resolution.

**Tracking ID**: AUTO-ERROR-$(Get-Date -Format 'yyyyMMdd-HHmmss')
"@

    return $description
}

function Add-ErrorTrackingEntry {
    [CmdletBinding()]
    param([hashtable]$ErrorAnalysis, [hashtable]$IssueResult, [string]$Priority)
    
    try {
        $logEntry = @{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
            ErrorType = $ErrorAnalysis.ErrorType
            Severity = $ErrorAnalysis.Severity
            Priority = $Priority
            IssueNumber = $IssueResult.IssueNumber
            IssueUrl = $IssueResult.IssueUrl
            Summary = $ErrorAnalysis.Summary
        }
        
        $logPath = "logs/automated-error-tracking.json"
        
        # Ensure logs directory exists
        $logDir = Split-Path $logPath -Parent
        if (-not (Test-Path $logDir)) {
            if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        }
        
        # Read existing log or create new array
        $existingLog = if (Test-Path $logPath) {
            Get-Content $logPath -Raw | ConvertFrom-Json
        } else {
            @()
        }
        
        # Add new entry
        $updatedLog = $existingLog + $logEntry
        
        # Write back to file
        $updatedLog | ConvertTo-Json -Depth 10 | Out-File $logPath -Encoding utf8
        
        Write-CustomLog "Error tracking entry added to central log: $logPath" -Level INFO
        
    } catch {
        Write-CustomLog "Failed to add error tracking entry: $($_.Exception.Message)" -Level WARN
    }
}




