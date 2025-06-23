#Requires -Version 7.0

<#
.SYNOPSIS
    Automatic error monitoring and GitHub issue creation wrapper
    
.DESCRIPTION
    This function wraps script execution with comprehensive error monitoring and automatic
    GitHub issue creation for any errors, test failures, or runtime failures that occur.
    
    Provides central error tracking and systematic resolution through GitHub issues.
    
.PARAMETER ScriptBlock
    The script block to execute with error monitoring
    
.PARAMETER ErrorHandling
    Level of error handling (Comprehensive, BasicOnly, Silent)
    
.PARAMETER CreateIssues
    Whether to automatically create GitHub issues for errors (default: true)
    
.PARAMETER Context
    Additional context information for error tracking
    
.EXAMPLE
    Invoke-MonitoredExecution -ScriptBlock { Import-Module "NonExistentModule" } -Context @{Operation = "Module Import Test"}
    
.EXAMPLE
    Invoke-MonitoredExecution -ScriptBlock { Invoke-Pester "tests/" } -ErrorHandling "Comprehensive"
    
.NOTES
    - Automatically detects and categorizes different types of errors
    - Creates GitHub issues for systematic tracking and resolution
    - Integrates with PatchManager error handling workflow
    - Supports all common error types and test frameworks
#>

function Invoke-MonitoredExecution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [string]$OperationName = "Unknown Operation",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Comprehensive", "BasicOnly", "Silent")]
        [string]$ErrorHandling = "Comprehensive",
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateIssues = $true,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Context = @{}
    )
    
    begin {
        Write-CustomLog "Starting monitored execution with $ErrorHandling error handling" -Level INFO
        
        # Import error handler
        try {
            $projectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else { "c:\Users\alexa\OneDrive\Documents\0. wizzense\opentofu-lab-automation" }
            Import-Module "$projectRoot\pwsh\modules\PatchManager\Public\Invoke-ErrorHandler.ps1" -Force -ErrorAction SilentlyContinue
        } catch {
            Write-CustomLog "Could not import error handler: $($_.Exception.Message)" -Level WARN
        }
        
        # Set up error tracking
        $originalErrorActionPreference = $ErrorActionPreference
        if ($ErrorHandling -eq "Comprehensive") {
            $ErrorActionPreference = "Continue"  # Capture all errors but continue execution
        }
        
        $executionResult = @{
            Success = $false
            Output = $null
            Errors = @()
            Warnings = @()
            IssuesCreated = @()
            ExecutionTime = $null
        }
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }
    
    process {
        try {
            Write-CustomLog "Executing monitored script block..." -Level INFO
            
            # Execute the script block with comprehensive error monitoring
            $executionResult.Output = & $ScriptBlock
            
            # Check for any errors that occurred during execution
            if ($Error.Count -gt 0) {
                $newErrors = $Error | Select-Object -First ($Error.Count - ($executionResult.Errors.Count))
                $executionResult.Errors += $newErrors
                
                if ($ErrorHandling -eq "Comprehensive" -and $CreateIssues) {
                    foreach ($errorRecord in $newErrors) {
                        Write-CustomLog "Processing error for issue creation: $($errorRecord.Exception.Message)" -Level WARN
                        
                        try {
                            # Determine error type
                            $errorType = Classify-ErrorType -ErrorRecord $errorRecord
                            
                            # Create error tracking issue
                            $errorContext = $Context.Clone()
                            $errorContext.Add("AutoDetected", $true)
                            $errorContext.Add("ExecutionTime", $stopwatch.Elapsed.ToString())
                            
                            $errorResult = Invoke-ErrorHandler -ErrorRecord $errorRecord -ErrorType $errorType -Context $errorContext -CreateIssue:$CreateIssues
                            
                            if ($errorResult.IssueCreated) {
                                $executionResult.IssuesCreated += @{
                                    ErrorType = $errorType
                                    IssueUrl = $errorResult.IssueUrl
                                    IssueNumber = $errorResult.IssueNumber
                                    Summary = $errorResult.Summary
                                }
                                
                                Write-CustomLog "Error tracked in issue #$($errorResult.IssueNumber): $($errorResult.Summary)" -Level INFO
                            }
                        } catch {
                            Write-CustomLog "Failed to process error for issue creation: $($_.Exception.Message)" -Level WARN
                        }
                    }
                }
            }
            
            # Check for test failures if output appears to be test results
            if ($executionResult.Output -and $CreateIssues -and $ErrorHandling -eq "Comprehensive") {
                $testFailures = Detect-TestFailures -Output $executionResult.Output
                
                if ($testFailures.HasFailures) {
                    Write-CustomLog "Test failures detected - creating tracking issue..." -Level WARN
                    
                    try {
                        $testContext = $Context.Clone()
                        $testContext.Add("AutoDetected", $true)
                        $testContext.Add("TestFramework", $testFailures.Framework)
                        
                        $testResult = Invoke-ErrorHandler -TestResults $testFailures.Results -ErrorType "TestFailure" -Context $testContext -CreateIssue:$CreateIssues
                        
                        if ($testResult.IssueCreated) {
                            $executionResult.IssuesCreated += @{
                                ErrorType = "TestFailure"
                                IssueUrl = $testResult.IssueUrl
                                IssueNumber = $testResult.IssueNumber
                                Summary = $testResult.Summary
                            }
                            
                            Write-CustomLog "Test failures tracked in issue #$($testResult.IssueNumber)" -Level INFO
                        }
                    } catch {
                        Write-CustomLog "Failed to create test failure tracking issue: $($_.Exception.Message)" -Level WARN
                    }
                }
            }
            
            $executionResult.Success = $true
            Write-CustomLog "Monitored execution completed successfully" -Level SUCCESS
            
        } catch {
            Write-CustomLog "Critical error during monitored execution: $($_.Exception.Message)" -Level ERROR
            $executionResult.Errors += $_
            
            # Create critical error tracking issue
            if ($CreateIssues -and $ErrorHandling -ne "Silent") {
                try {
                    $criticalContext = $Context.Clone()
                    $criticalContext.Add("CriticalError", $true)
                    $criticalContext.Add("ExecutionTime", $stopwatch.Elapsed.ToString())
                    
                    $criticalResult = Invoke-ErrorHandler -ErrorRecord $_ -ErrorType "RuntimeError" -Context $criticalContext -Priority "Critical" -CreateIssue:$CreateIssues
                    
                    if ($criticalResult.IssueCreated) {
                        $executionResult.IssuesCreated += @{
                            ErrorType = "CriticalError"
                            IssueUrl = $criticalResult.IssueUrl
                            IssueNumber = $criticalResult.IssueNumber
                            Summary = $criticalResult.Summary
                        }
                        
                        Write-CustomLog "Critical error tracked in issue #$($criticalResult.IssueNumber)" -Level ERROR
                    }
                } catch {
                    Write-CustomLog "Failed to create critical error tracking issue: $($_.Exception.Message)" -Level ERROR
                }
            }
            
            $executionResult.Success = $false
        } finally {
            $stopwatch.Stop()
            $executionResult.ExecutionTime = $stopwatch.Elapsed
            
            # Restore original error action preference
            $ErrorActionPreference = $originalErrorActionPreference
        }
    }
    
    end {
        # Summary reporting
        Write-CustomLog "=== MONITORED EXECUTION SUMMARY ===" -Level INFO
        Write-CustomLog "Success: $($executionResult.Success)" -Level INFO
        Write-CustomLog "Execution Time: $($executionResult.ExecutionTime)" -Level INFO
        Write-CustomLog "Errors Detected: $($executionResult.Errors.Count)" -Level INFO
        Write-CustomLog "Issues Created: $($executionResult.IssuesCreated.Count)" -Level INFO
        
        if ($executionResult.IssuesCreated.Count -gt 0) {
            Write-CustomLog "GitHub Issues Created for Tracking:" -Level INFO
            foreach ($issue in $executionResult.IssuesCreated) {
                Write-CustomLog "  - #$($issue.IssueNumber) [$($issue.ErrorType)]: $($issue.Summary)" -Level INFO
                Write-CustomLog "    URL: $($issue.IssueUrl)" -Level INFO
            }
        }
        
        return $executionResult
    }
}

function Classify-ErrorType {
    [CmdletBinding()]
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)
    
    $exceptionType = $ErrorRecord.Exception.GetType().Name
    $errorMessage = $ErrorRecord.Exception.Message.ToLower()
    
    # Classify based on exception type and message content
    if ($exceptionType -eq "ParseException" -or $errorMessage -contains "syntax error") {
        return "SyntaxError"
    } elseif ($exceptionType -eq "CommandNotFoundException" -or $errorMessage -contains "not recognized") {
        return "ImportError"
    } elseif ($errorMessage -contains "test" -and ($errorMessage -contains "fail" -or $errorMessage -contains "error")) {
        return "TestFailure"
    } elseif ($exceptionType -eq "FileNotFoundException" -or $exceptionType -eq "DirectoryNotFoundException") {
        return "ImportError"
    } elseif ($errorMessage -contains "build" -or $errorMessage -contains "deploy") {
        return "BuildFailure"
    } else {
        return "RuntimeError"
    }
}

function Detect-TestFailures {
    [CmdletBinding()]
    param([object]$Output)
    
    $result = @{
        HasFailures = $false
        Framework = "Unknown"
        Results = $null
    }
    
    if (-not $Output) {
        return $result
    }
    
    # Check for Pester test results
    if ($Output.PSObject.Properties.Name -contains "FailedCount" -or $Output.PSObject.Properties.Name -contains "Failed") {
        $result.Framework = "Pester"
        
        if ($Output.FailedCount -gt 0 -or $Output.Failed -gt 0) {
            $result.HasFailures = $true
            $result.Results = $Output
        }
    }
    # Check for pytest results (if output is string)
    elseif ($Output -is [string] -and $Output -match "FAILED|ERROR.*test") {
        $result.Framework = "pytest"
        $result.HasFailures = $true
        $result.Results = @{ TestOutput = $Output }
    }
    # Check for PSScriptAnalyzer results
    elseif ($Output -is [array] -and $Output.Count -gt 0 -and $Output[0].PSObject.Properties.Name -contains "Severity") {
        $errors = $Output | Where-Object { $_.Severity -eq "Error" }
        if ($errors.Count -gt 0) {
            $result.Framework = "PSScriptAnalyzer"
            $result.HasFailures = $true
            $result.Results = @{ AnalysisErrors = $errors }
        }
    }
    
    return $result
}


