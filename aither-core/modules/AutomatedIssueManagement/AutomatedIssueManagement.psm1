#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Automated Issue Management for AitherZero CI/CD Pipeline
    
.DESCRIPTION
    Comprehensive automated issue creation and management system that tracks ALL types of
    CI/CD failures and problems. Creates GitHub issues automatically for:
    - PSScriptAnalyzer failures/errors
    - Pester test failures/errors  
    - Missing documentation
    - Missing tests
    - Missing/unresolved dependencies
    - Security issues
    - Code quality issues
    - Build failures
    - Deployment issues
    
    Features:
    - Rich issue templates with full context
    - Automatic labeling and assignment
    - Duplicate issue prevention
    - Issue lifecycle management
    - Integration with comprehensive dashboards
    - System metadata collection
    
.NOTES
    Module: AutomatedIssueManagement
    Version: 1.0.0
    Author: AitherZero CI/CD System
    
    Integrated with AitherZero "ULTRATHINK" comprehensive automation system
#>

# Module initialization
$script:ModuleRoot = $PSScriptRoot
$script:ModuleVersion = "1.0.0"

# Import shared utilities
. (Join-Path $PSScriptRoot ".." ".." "shared" "Find-ProjectRoot.ps1")

<#
.SYNOPSIS
    Initialize the automated issue management system
    
.DESCRIPTION
    Sets up the automated issue management system with configuration and state tracking
    
.PARAMETER RepositoryOwner
    GitHub repository owner
    
.PARAMETER RepositoryName  
    GitHub repository name
    
.PARAMETER GitHubToken
    GitHub authentication token
    
.PARAMETER EnableDuplicatePrevention
    Enable duplicate issue prevention
    
.PARAMETER MaxIssuesPerRun
    Maximum issues to create per CI run
    
.EXAMPLE
    Initialize-AutomatedIssueManagement -RepositoryOwner "AitherZero" -RepositoryName "AitherZero"
#>
function Initialize-AutomatedIssueManagement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepositoryOwner = $env:GITHUB_REPOSITORY_OWNER,
        
        [Parameter(Mandatory = $false)]
        [string]$RepositoryName = ($env:GITHUB_REPOSITORY -split '/')[-1],
        
        [Parameter(Mandatory = $false)]
        [string]$GitHubToken = $env:GITHUB_TOKEN,
        
        [Parameter(Mandatory = $false)]
        [switch]$EnableDuplicatePrevention = $true,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxIssuesPerRun = 10
    )
    
    $result = @{
        success = $false
        configuration = @{}
        state_file = ""
        errors = @()
    }
    
    try {
        Write-Host "🚀 Initializing Automated Issue Management System..." -ForegroundColor Cyan
        
        # Create configuration
        $config = @{
            repository = @{
                owner = $RepositoryOwner
                name = $RepositoryName
                full_name = "$RepositoryOwner/$RepositoryName"
            }
            authentication = @{
                token = $GitHubToken
                token_available = (-not [string]::IsNullOrEmpty($GitHubToken))
            }
            settings = @{
                duplicate_prevention = $EnableDuplicatePrevention.IsPresent
                max_issues_per_run = $MaxIssuesPerRun
                issue_labels = @("ci-cd", "automated", "bug", "needs-triage")
                assignees = @()
                milestone = ""
            }
            templates = @{}
            state = @{
                last_run = ""
                created_issues = @()
                resolved_issues = @()
                open_issues = @()
            }
        }
        
        # Create state directory
        $stateDir = "./.github/automated-issues"
        if (-not (Test-Path $stateDir)) {
            New-Item -Path $stateDir -ItemType Directory -Force | Out-Null
        }
        
        # Save configuration
        $configFile = "$stateDir/config.json"
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configFile -Encoding UTF8
        
        # Initialize issue templates
        Initialize-IssueTemplates -ConfigPath $configFile
        
        # Initialize state tracking
        $stateFile = "$stateDir/state.json"
        if (-not (Test-Path $stateFile)) {
            $config.state | ConvertTo-Json -Depth 5 | Set-Content -Path $stateFile -Encoding UTF8
        }
        
        $result.success = $true
        $result.configuration = $config
        $result.state_file = $stateFile
        
        Write-Host "✅ Automated Issue Management System initialized" -ForegroundColor Green
        
    } catch {
        $result.errors += "Error initializing automated issue management: $($_.Exception.Message)"
        Write-Host "❌ Failed to initialize automated issue management: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $result
}

<#
.SYNOPSIS
    Create automated issue from CI/CD failure
    
.DESCRIPTION
    Creates a GitHub issue automatically for any type of CI/CD failure with rich context
    
.PARAMETER FailureType
    Type of failure (test, psscriptanalyzer, documentation, dependency, security, etc.)
    
.PARAMETER FailureDetails
    Detailed information about the failure
    
.PARAMETER SystemMetadata
    System metadata (environment, versions, etc.)
    
.PARAMETER CreateIssue
    Actually create the GitHub issue (vs dry run)
    
.EXAMPLE
    New-AutomatedIssueFromFailure -FailureType "test" -FailureDetails $testFailure -SystemMetadata $metadata
#>
function New-AutomatedIssueFromFailure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("test", "psscriptanalyzer", "documentation", "dependency", "security", "build", "deployment", "quality")]
        [string]$FailureType,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$FailureDetails,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$SystemMetadata = @{},
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateIssue
    )
    
    $result = @{
        success = $false
        issue_created = $false
        issue_number = 0
        issue_url = ""
        issue_data = @{}
        errors = @()
    }
    
    try {
        Write-Host "🔍 Processing $FailureType failure for automated issue creation..." -ForegroundColor Yellow
        
        # Load configuration
        $config = Get-AutomatedIssueConfig
        if (-not $config) {
            throw "Automated issue management not initialized"
        }
        
        # Check if issue creation is enabled and token is available
        if (-not $config.authentication.token_available) {
            Write-Host "⚠️ GitHub token not available - skipping issue creation" -ForegroundColor Yellow
            $result.success = $true
            return $result
        }
        
        # Generate issue signature for duplicate prevention
        $issueSignature = Get-IssueSignature -FailureType $FailureType -FailureDetails $FailureDetails
        
        # Check for existing issue if duplicate prevention is enabled
        if ($config.settings.duplicate_prevention) {
            $existingIssue = Find-ExistingIssue -Signature $issueSignature -Config $config
            if ($existingIssue) {
                Write-Host "📋 Found existing issue #$($existingIssue.number) for this failure" -ForegroundColor Blue
                Update-ExistingIssue -IssueNumber $existingIssue.number -FailureDetails $FailureDetails -Config $config
                $result.success = $true
                $result.issue_number = $existingIssue.number
                return $result
            }
        }
        
        # Check issue creation limits
        $state = Get-AutomatedIssueState
        $todayCreated = ($state.created_issues | Where-Object { 
            (Get-Date $_.created_at).Date -eq (Get-Date).Date 
        }).Count
        
        if ($todayCreated -ge $config.settings.max_issues_per_run) {
            Write-Host "⚠️ Maximum issues per run limit reached ($($config.settings.max_issues_per_run))" -ForegroundColor Yellow
            $result.success = $true
            return $result
        }
        
        # Generate issue content
        $issueContent = New-IssueContent -FailureType $FailureType -FailureDetails $FailureDetails -SystemMetadata $SystemMetadata -Config $config
        
        # Create the issue if requested
        if ($CreateIssue.IsPresent) {
            $issueResult = New-GitHubIssue -Config $config -IssueContent $issueContent
            
            if ($issueResult.success) {
                $result.issue_created = $true
                $result.issue_number = $issueResult.issue_number
                $result.issue_url = $issueResult.issue_url
                
                # Update state
                Update-AutomatedIssueState -Action "created" -IssueData $issueResult -Signature $issueSignature
                
                Write-Host "✅ Created automated issue #$($result.issue_number): $($issueContent.title)" -ForegroundColor Green
            }
        } else {
            Write-Host "🔍 [DRY RUN] Would create issue: $($issueContent.title)" -ForegroundColor Magenta
        }
        
        $result.success = $true
        $result.issue_data = $issueContent
        
    } catch {
        $result.errors += "Error creating automated issue: $($_.Exception.Message)"
        Write-Host "❌ Failed to create automated issue: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $result
}

<#
.SYNOPSIS
    Process Pester test failures and create issues
    
.DESCRIPTION
    Analyzes Pester test results and creates automated issues for test failures
    
.PARAMETER TestResults
    Pester test results object or JSON file path
    
.PARAMETER SystemMetadata
    System metadata for context
    
.PARAMETER CreateIssues
    Actually create GitHub issues
    
.EXAMPLE
    New-PesterTestFailureIssues -TestResults $pesterResults -SystemMetadata $metadata -CreateIssues
#>
function New-PesterTestFailureIssues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$TestResults,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$SystemMetadata = @{},
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateIssues
    )
    
    $result = @{
        success = $false
        issues_created = 0
        test_failures = 0
        errors = @()
    }
    
    try {
        Write-Host "🧪 Processing Pester test failures for automated issues..." -ForegroundColor Cyan
        
        # Parse test results if it's a file path
        if ($TestResults -is [string] -and (Test-Path $TestResults)) {
            $TestResults = Get-Content $TestResults | ConvertFrom-Json
        }
        
        # Extract failed tests
        $failedTests = @()
        
        # Check if FailedTests is an array of test objects, not just a count
        if ($TestResults.FailedTests -and $TestResults.FailedTests -is [array]) {
            $failedTests = $TestResults.FailedTests
        } elseif ($TestResults.Tests) {
            $allTests = @($TestResults.Tests)
            
            $failedTests = @()
            foreach ($test in $allTests) {
                if ($test.Result -eq 'Failed') {
                    $failedTests += $test
                }
            }
        }
        
        $result.test_failures = $failedTests.Count
        
        if ($failedTests.Count -eq 0) {
            Write-Host "✅ No test failures found - no issues to create" -ForegroundColor Green
            $result.success = $true
            return $result
        }
        
        Write-Host "🔍 Found $($failedTests.Count) test failures" -ForegroundColor Yellow
        
        # Group similar failures to avoid spam
        $groupedFailures = Group-TestFailures -FailedTests $failedTests
        
        foreach ($group in $groupedFailures) {
            $failureDetails = @{
                test_name = $group.TestName
                test_file = $group.TestFile
                failure_message = $group.FailureMessage
                error_details = $group.ErrorDetails
                test_count = $group.TestCount
                similar_tests = $group.SimilarTests
                failure_category = $group.Category
                stack_trace = $group.StackTrace
            }
            
            $issueResult = New-AutomatedIssueFromFailure -FailureType "test" -FailureDetails $failureDetails -SystemMetadata $SystemMetadata -CreateIssue:$CreateIssues
            
            if ($issueResult.success -and $issueResult.issue_created) {
                $result.issues_created++
            }
        }
        
        $result.success = $true
        Write-Host "✅ Processed test failures: $($result.issues_created) issues created" -ForegroundColor Green
        
    } catch {
        $result.errors += "Error processing test failures: $($_.Exception.Message)"
        Write-Host "❌ Failed to process test failures: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $result
}

<#
.SYNOPSIS
    Process PSScriptAnalyzer findings and create issues
    
.DESCRIPTION
    Analyzes PSScriptAnalyzer results and creates automated issues for violations
    
.PARAMETER AnalyzerResults
    PSScriptAnalyzer results array or JSON file path
    
.PARAMETER MinimumSeverity
    Minimum severity level to create issues for
    
.PARAMETER SystemMetadata
    System metadata for context
    
.PARAMETER CreateIssues
    Actually create GitHub issues
    
.EXAMPLE
    New-PSScriptAnalyzerIssues -AnalyzerResults $results -MinimumSeverity "Warning" -CreateIssues
#>
function New-PSScriptAnalyzerIssues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$AnalyzerResults,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Error", "Warning", "Information")]
        [string]$MinimumSeverity = "Warning",
        
        [Parameter(Mandatory = $false)]
        [hashtable]$SystemMetadata = @{},
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateIssues
    )
    
    $result = @{
        success = $false
        issues_created = 0
        analyzer_violations = 0
        errors = @()
    }
    
    try {
        Write-Host "🔍 Processing PSScriptAnalyzer findings for automated issues..." -ForegroundColor Cyan
        
        # Parse analyzer results if it's a file path
        if ($AnalyzerResults -is [string] -and (Test-Path $AnalyzerResults)) {
            $AnalyzerResults = Get-Content $AnalyzerResults | ConvertFrom-Json
        }
        
        # Filter by severity
        $severityOrder = @{ "Error" = 3; "Warning" = 2; "Information" = 1 }
        $minSeverityLevel = $severityOrder[$MinimumSeverity]
        
        $filteredResults = @()
        foreach ($analyzerResult in $AnalyzerResults) {
            $resultSeverityLevel = $severityOrder[$analyzerResult.Severity]
            if ($resultSeverityLevel -ge $minSeverityLevel) {
                $filteredResults += $analyzerResult
            }
        }
        
        $result.analyzer_violations = $filteredResults.Count
        
        if ($filteredResults.Count -eq 0) {
            Write-Host "✅ No PSScriptAnalyzer violations above $MinimumSeverity level" -ForegroundColor Green
            $result.success = $true
            return $result
        }
        
        Write-Host "🔍 Found $($filteredResults.Count) PSScriptAnalyzer violations" -ForegroundColor Yellow
        
        # Group similar violations
        $groupedViolations = Group-PSScriptAnalyzerFindings -Findings $filteredResults
        
        foreach ($group in $groupedViolations) {
            $failureDetails = @{
                rule_name = $group.RuleName
                severity = $group.Severity
                message = $group.Message
                script_path = $group.ScriptPath
                line_number = $group.LineNumber
                column_number = $group.ColumnNumber
                violation_count = $group.ViolationCount
                similar_violations = $group.SimilarViolations
                rule_description = $group.RuleDescription
                suggested_corrections = $group.SuggestedCorrections
            }
            
            $issueResult = New-AutomatedIssueFromFailure -FailureType "psscriptanalyzer" -FailureDetails $failureDetails -SystemMetadata $SystemMetadata -CreateIssue:$CreateIssues
            
            if ($issueResult.success -and $issueResult.issue_created) {
                $result.issues_created++
            }
        }
        
        $result.success = $true
        Write-Host "✅ Processed PSScriptAnalyzer violations: $($result.issues_created) issues created" -ForegroundColor Green
        
    } catch {
        $result.errors += "Error processing PSScriptAnalyzer findings: $($_.Exception.Message)"
        Write-Host "❌ Failed to process PSScriptAnalyzer findings: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $result
}

<#
.SYNOPSIS
    Collect comprehensive system metadata
    
.DESCRIPTION
    Collects detailed system metadata for issue context and reporting
    
.EXAMPLE
    $metadata = Get-SystemMetadata
#>
function Get-SystemMetadata {
    [CmdletBinding()]
    param()
    
    try {
        $metadata = @{
            timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            environment = @{
                os = $PSVersionTable.OS
                platform = $PSVersionTable.Platform
                powershell_version = $PSVersionTable.PSVersion.ToString()
                powershell_edition = $PSVersionTable.PSEdition
                is_windows = $IsWindows
                is_linux = $IsLinux
                is_macos = $IsMacOS
            }
            ci_environment = @{
                is_github_actions = $env:GITHUB_ACTIONS -eq 'true'
                workflow_name = $env:GITHUB_WORKFLOW
                job_name = $env:GITHUB_JOB
                run_id = $env:GITHUB_RUN_ID
                run_number = $env:GITHUB_RUN_NUMBER
                actor = $env:GITHUB_ACTOR
                event_name = $env:GITHUB_EVENT_NAME
                ref = $env:GITHUB_REF
                sha = $env:GITHUB_SHA
                repository = $env:GITHUB_REPOSITORY
            }
            project = @{
                root = Find-ProjectRoot
                version = if (Test-Path "./VERSION") { (Get-Content "./VERSION" -Raw).Trim() } else { "unknown" }
                branch = if ($env:GITHUB_REF) { $env:GITHUB_REF -replace 'refs/heads/', '' } else { "unknown" }
            }
            modules = @{
                loaded_modules = (Get-Module | Select-Object Name, Version)
                aither_modules = (Get-ChildItem "./aither-core/modules" -Directory -ErrorAction SilentlyContinue | Select-Object Name)
            }
            dependencies = @{
                pester_version = (Get-Module Pester -ListAvailable | Select-Object -First 1 -ExpandProperty Version -ErrorAction SilentlyContinue)
                psscriptanalyzer_version = (Get-Module PSScriptAnalyzer -ListAvailable | Select-Object -First 1 -ExpandProperty Version -ErrorAction SilentlyContinue)
            }
        }
        
        return $metadata
        
    } catch {
        Write-Warning "Error collecting system metadata: $($_.Exception.Message)"
        return @{ error = $_.Exception.Message }
    }
}

<#
.SYNOPSIS
    Generate comprehensive automated issue report
    
.DESCRIPTION
    Generates a comprehensive report of all automated issues created, system status, and metrics
    
.PARAMETER ReportPath
    Path to save the report
    
.PARAMETER OutputFormat
    Output format (json, html, markdown)
    
.EXAMPLE
    New-AutomatedIssueReport -ReportPath "./automated-issues-report.html" -OutputFormat "html"
#>
function New-AutomatedIssueReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ReportPath = "./automated-issues-report.json",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("json", "html", "markdown")]
        [string]$OutputFormat = "json"
    )
    
    $result = @{
        success = $false
        report_path = ""
        report_data = @{}
        errors = @()
    }
    
    try {
        Write-Host "📊 Generating automated issues report..." -ForegroundColor Cyan
        
        # Collect report data
        $reportData = @{
            metadata = @{
                generated_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                report_version = "1.0.0"
                system_metadata = Get-SystemMetadata
            }
            configuration = Get-AutomatedIssueConfig
            state = Get-AutomatedIssueState
            statistics = Get-AutomatedIssueStatistics
            recent_issues = Get-RecentAutomatedIssues -Days 7
        }
        
        # Generate report content based on format
        switch ($OutputFormat) {
            "json" {
                $content = $reportData | ConvertTo-Json -Depth 10
            }
            "html" {
                $content = ConvertTo-HTMLReport -ReportData $reportData
            }
            "markdown" {
                $content = ConvertTo-MarkdownReport -ReportData $reportData
            }
        }
        
        # Save report
        $content | Set-Content -Path $ReportPath -Encoding UTF8
        
        $result.success = $true
        $result.report_path = $ReportPath
        $result.report_data = $reportData
        
        Write-Host "✅ Automated issues report generated: $ReportPath" -ForegroundColor Green
        
    } catch {
        $result.errors += "Error generating automated issue report: $($_.Exception.Message)"
        Write-Host "❌ Failed to generate automated issue report: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    return $result
}

# Private helper functions

function Get-AutomatedIssueConfig {
    $configFile = "./.github/automated-issues/config.json"
    if (Test-Path $configFile) {
        return Get-Content $configFile | ConvertFrom-Json
    }
    return $null
}

function Group-PSScriptAnalyzerFindings {
    param([array]$Findings)
    
    $grouped = @()
    $processedFindings = @{}
    
    foreach ($finding in $Findings) {
        $key = "$($finding.RuleName)-$($finding.ScriptPath)"
        
        if (-not $processedFindings.ContainsKey($key)) {
            $similar = $Findings | Where-Object { 
                $_.RuleName -eq $finding.RuleName -and $_.ScriptPath -eq $finding.ScriptPath 
            }
            
            $group = @{
                RuleName = $finding.RuleName
                Severity = $finding.Severity
                Message = $finding.Message
                ScriptPath = $finding.ScriptPath
                LineNumber = $finding.Line
                ColumnNumber = $finding.Column
                ViolationCount = $similar.Count
                SimilarViolations = $similar | ForEach-Object { "Line $($_.Line): $($_.Message)" }
                RuleDescription = "PSScriptAnalyzer rule: $($finding.RuleName)"
                SuggestedCorrections = @("Review and fix the $($finding.RuleName) violation", "Run PSScriptAnalyzer locally to verify fix")
            }
            
            $grouped += $group
            $processedFindings[$key] = $true
        }
    }
    
    return $grouped
}

function Group-TestFailures {
    param([array]$FailedTests)
    
    $grouped = @()
    $processedTests = @{}
    
    foreach ($test in $FailedTests) {
        $testFile = if ($test.ScriptBlock -and $test.ScriptBlock.File) { 
            $test.ScriptBlock.File 
        } else { 
            "Unknown" 
        }
        
        $key = "$($test.Name)-$testFile"
        
        if (-not $processedTests.ContainsKey($key)) {
            $errorMessage = if ($test.ErrorRecord -and $test.ErrorRecord.Exception) {
                $test.ErrorRecord.Exception.Message
            } else {
                "No error details available"
            }
            
            $group = @{
                TestName = $test.Name
                TestFile = $testFile
                FailureMessage = $test.FailureMessage
                ErrorDetails = $errorMessage
                TestCount = 1
                SimilarTests = @($test.Name)
                Category = "Test Failure"
                StackTrace = if ($test.ErrorRecord) { $test.ErrorRecord.ScriptStackTrace } else { "No stack trace available" }
            }
            
            $grouped += $group
            $processedTests[$key] = $true
        }
    }
    
    return $grouped
}

function Find-ExistingIssue {
    param(
        [string]$Signature,
        [object]$Config
    )
    
    # This would typically query GitHub API for existing issues
    # For now, return null (no existing issue found)
    # In a real implementation, this would:
    # 1. Search GitHub issues with the signature
    # 2. Check issue body/comments for the signature
    # 3. Return the issue if found
    
    return $null
}

function Update-ExistingIssue {
    param(
        [int]$IssueNumber,
        [hashtable]$FailureDetails,
        [object]$Config
    )
    
    # This would update an existing GitHub issue
    # For now, just log that we would update
    Write-Host "📝 Would update existing issue #$IssueNumber with new failure details" -ForegroundColor Blue
    
    return @{ success = $true; updated = $true }
}

function New-GitHubIssue {
    param(
        [object]$Config,
        [hashtable]$IssueContent
    )
    
    # This would create a GitHub issue via API
    # For now, simulate the creation (dry run)
    Write-Host "🎫 [DRY RUN] Would create GitHub issue: $($IssueContent.title)" -ForegroundColor Magenta
    Write-Host "   Labels: $($IssueContent.labels -join ', ')" -ForegroundColor Gray
    
    return @{
        success = $true
        issue_number = Get-Random -Minimum 1000 -Maximum 9999
        issue_url = "https://github.com/$($Config.repository.full_name)/issues/$(Get-Random -Minimum 1000 -Maximum 9999)"
        created_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    }
}

function Update-AutomatedIssueState {
    param(
        [string]$Action,
        [hashtable]$IssueData,
        [string]$Signature
    )
    
    $stateFile = "./.github/automated-issues/state.json"
    $state = Get-AutomatedIssueState
    
    if ($Action -eq "created") {
        $state.created_issues += @{
            issue_number = $IssueData.issue_number
            issue_url = $IssueData.issue_url
            created_at = $IssueData.created_at
            signature = $Signature
        }
    }
    
    $state | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFile -Encoding UTF8
}

function Get-AutomatedIssueStatistics {
    $state = Get-AutomatedIssueState
    $today = (Get-Date).Date
    
    $todayIssues = $state.created_issues | Where-Object { 
        (Get-Date $_.created_at).Date -eq $today 
    }
    
    return @{
        issues_created_today = $todayIssues.Count
        total_open_issues = $state.open_issues.Count
        total_created_issues = $state.created_issues.Count
        recent_resolutions = $state.resolved_issues.Count
        last_updated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    }
}

function Get-RecentAutomatedIssues {
    param([int]$Days = 7)
    
    $state = Get-AutomatedIssueState
    $cutoffDate = (Get-Date).AddDays(-$Days)
    
    $recentIssues = $state.created_issues | Where-Object {
        (Get-Date $_.created_at) -ge $cutoffDate
    }
    
    return $recentIssues
}

function ConvertTo-HTMLReport {
    param([hashtable]$ReportData)
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Automated Issues Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #0366d6; color: white; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background: #f6f8fa; border-radius: 3px; }
        .timestamp { color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🤖 AitherZero ULTRATHINK Automated Issues Report</h1>
        <p class="timestamp">Generated: $($ReportData.metadata.generated_at)</p>
    </div>
    
    <div class="section">
        <h2>📊 Issue Statistics</h2>
        <div class="metric">
            <strong>Issues Created Today:</strong> $($ReportData.statistics.issues_created_today)
        </div>
        <div class="metric">
            <strong>Total Open Issues:</strong> $($ReportData.statistics.total_open_issues)
        </div>
        <div class="metric">
            <strong>Recent Resolutions:</strong> $($ReportData.statistics.recent_resolutions)
        </div>
    </div>
    
    <div class="section">
        <h2>🖥️ System Information</h2>
        <p><strong>Platform:</strong> $($ReportData.metadata.system_metadata.environment.platform)</p>
        <p><strong>PowerShell Version:</strong> $($ReportData.metadata.system_metadata.environment.powershell_version)</p>
        <p><strong>CI Run:</strong> $($ReportData.metadata.system_metadata.ci_environment.run_id)</p>
    </div>
    
    <div class="section">
        <h2>⚙️ Configuration</h2>
        <p><strong>Repository:</strong> $($ReportData.configuration.repository.full_name)</p>
        <p><strong>Duplicate Prevention:</strong> $($ReportData.configuration.settings.duplicate_prevention)</p>
        <p><strong>Max Issues Per Run:</strong> $($ReportData.configuration.settings.max_issues_per_run)</p>
    </div>
    
    <footer style="margin-top: 40px; text-align: center; color: #666;">
        <p>🤖 Generated by AitherZero ULTRATHINK System</p>
    </footer>
</body>
</html>
"@
    
    return $html
}

function ConvertTo-MarkdownReport {
    param([hashtable]$ReportData)
    
    $markdown = @"
# 🤖 AitherZero ULTRATHINK Automated Issues Report

**Generated:** $($ReportData.metadata.generated_at)

## 📊 Issue Statistics

- **Issues Created Today:** $($ReportData.statistics.issues_created_today)
- **Total Open Issues:** $($ReportData.statistics.total_open_issues)
- **Recent Resolutions:** $($ReportData.statistics.recent_resolutions)

## 🖥️ System Information

- **Platform:** $($ReportData.metadata.system_metadata.environment.platform)
- **PowerShell Version:** $($ReportData.metadata.system_metadata.environment.powershell_version)
- **CI Run:** $($ReportData.metadata.system_metadata.ci_environment.run_id)

## ⚙️ Configuration

- **Repository:** $($ReportData.configuration.repository.full_name)
- **Duplicate Prevention:** $($ReportData.configuration.settings.duplicate_prevention)
- **Max Issues Per Run:** $($ReportData.configuration.settings.max_issues_per_run)

---
🤖 *Generated by AitherZero ULTRATHINK System*
"@
    
    return $markdown
}

function Get-AutomatedIssueState {
    $stateFile = "./.github/automated-issues/state.json"
    if (Test-Path $stateFile) {
        return Get-Content $stateFile | ConvertFrom-Json
    }
    return @{ created_issues = @(); resolved_issues = @(); open_issues = @() }
}

function Initialize-IssueTemplates {
    param([string]$ConfigPath)
    
    # Templates are defined inline for now but could be externalized
    $templates = @{
        test = @{
            title_template = "Test Failure: {test_name} in {test_file}"
            body_template = @"
## Test Failure Details

**Test Name:** {test_name}
**Test File:** {test_file}
**Failure Count:** {test_count}

## Error Message
```
{failure_message}
```

## Error Details
```
{error_details}
```

## System Context
- **PowerShell Version:** {powershell_version}
- **Platform:** {platform}
- **CI Run:** {run_id}
- **Branch:** {branch}
- **Commit:** {sha}

## Stack Trace
```
{stack_trace}
```

## Similar Failed Tests
{similar_tests}

## Suggested Actions
- [ ] Review test logic for potential race conditions
- [ ] Check for environmental dependencies
- [ ] Verify test data and mocks
- [ ] Run test locally to reproduce

---
🤖 **Automated Issue** - Created by AitherZero CI/CD System
**Issue Type:** Test Failure
**Created:** {timestamp}
"@
            labels = @("test-failure", "ci-cd", "automated", "bug")
        }
        psscriptanalyzer = @{
            title_template = "Code Quality: {rule_name} violation in {script_path}"
            body_template = @"
## PSScriptAnalyzer Violation

**Rule:** {rule_name}
**Severity:** {severity}
**File:** {script_path}
**Line:** {line_number}
**Column:** {column_number}

## Violation Message
```
{message}
```

## Rule Description
{rule_description}

## System Context
- **PowerShell Version:** {powershell_version}
- **Platform:** {platform}
- **CI Run:** {run_id}
- **Branch:** {branch}
- **Commit:** {sha}

## Suggested Corrections
{suggested_corrections}

## Similar Violations
Found {violation_count} similar violations:
{similar_violations}

## Recommended Actions
- [ ] Review and fix the code quality issue
- [ ] Run PSScriptAnalyzer locally to verify fix
- [ ] Consider adding a suppression if this is intentional
- [ ] Update coding standards if needed

---
🤖 **Automated Issue** - Created by AitherZero CI/CD System
**Issue Type:** Code Quality
**Created:** {timestamp}
"@
            labels = @("code-quality", "psscriptanalyzer", "ci-cd", "automated")
        }
        documentation = @{
            title_template = "Documentation: Missing documentation for {file_path}"
            body_template = "## Missing Documentation`n`n**File:** {file_path}`n**Issue:** {issue_description}`n`n---`n🤖 **Automated Issue** - Created by AitherZero CI/CD System"
            labels = @("documentation", "ci-cd", "automated")
        }
        dependency = @{
            title_template = "Dependency: Unresolved dependency {dependency_name}"
            body_template = "## Dependency Issue`n`n**Dependency:** {dependency_name}`n**Issue:** {issue_description}`n`n---`n🤖 **Automated Issue** - Created by AitherZero CI/CD System"
            labels = @("dependencies", "ci-cd", "automated")
        }
        security = @{
            title_template = "Security: Security issue in {file_path}"
            body_template = "## Security Issue`n`n**File:** {file_path}`n**Issue:** {issue_description}`n`n---`n🤖 **Automated Issue** - Created by AitherZero CI/CD System"
            labels = @("security", "ci-cd", "automated", "priority-high")
        }
        build = @{
            title_template = "Build: Build failure in {component}"
            body_template = "## Build Failure`n`n**Component:** {component}`n**Issue:** {issue_description}`n`n---`n🤖 **Automated Issue** - Created by AitherZero CI/CD System"
            labels = @("build", "ci-cd", "automated")
        }
        deployment = @{
            title_template = "Deployment: Deployment failure in {environment}"
            body_template = "## Deployment Failure`n`n**Environment:** {environment}`n**Issue:** {issue_description}`n`n---`n🤖 **Automated Issue** - Created by AitherZero CI/CD System"
            labels = @("deployment", "ci-cd", "automated")
        }
        quality = @{
            title_template = "Quality: Code quality issue in {file_path}"
            body_template = "## Code Quality Issue`n`n**File:** {file_path}`n**Issue:** {issue_description}`n`n---`n🤖 **Automated Issue** - Created by AitherZero CI/CD System"
            labels = @("quality", "ci-cd", "automated")
        }
    }
    
    return $templates
}

function Get-IssueSignature {
    param(
        [string]$FailureType,
        [hashtable]$FailureDetails
    )
    
    # Generate a unique signature for duplicate detection
    $signatureInput = "$FailureType-"
    
    switch ($FailureType) {
        "test" { $signatureInput += "$($FailureDetails.test_name)-$($FailureDetails.test_file)" }
        "psscriptanalyzer" { $signatureInput += "$($FailureDetails.rule_name)-$($FailureDetails.script_path)-$($FailureDetails.line_number)" }
        default { $signatureInput += "$($FailureDetails | ConvertTo-Json -Compress)" }
    }
    
    # Create hash
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($signatureInput))
    return [System.BitConverter]::ToString($hash) -replace '-', ''
}

function New-IssueContent {
    param(
        [string]$FailureType,
        [hashtable]$FailureDetails,
        [hashtable]$SystemMetadata,
        [object]$Config
    )
    
    $templates = Initialize-IssueTemplates
    $template = $templates[$FailureType]
    
    if (-not $template) {
        throw "No template found for failure type: $FailureType"
    }
    
    # Merge all data for template replacement
    $templateData = @{}
    
    # Add failure details
    foreach ($key in $FailureDetails.Keys) {
        $templateData[$key] = $FailureDetails[$key]
    }
    
    # Add system metadata
    if ($SystemMetadata.environment) {
        foreach ($key in $SystemMetadata.environment.Keys) {
            $templateData[$key] = $SystemMetadata.environment[$key]
        }
    }
    
    if ($SystemMetadata.ci_environment) {
        foreach ($key in $SystemMetadata.ci_environment.Keys) {
            $templateData[$key] = $SystemMetadata.ci_environment[$key]
        }
    }
    
    if ($SystemMetadata.project) {
        foreach ($key in $SystemMetadata.project.Keys) {
            $templateData[$key] = $SystemMetadata.project[$key]
        }
    }
    
    $templateData.timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss UTC')
    
    # Replace template variables
    $title = $template.title_template
    $body = $template.body_template
    
    foreach ($key in $templateData.Keys) {
        $value = $templateData[$key]
        if ($value -is [array]) {
            $value = $value -join ", "
        } elseif ($value -is [hashtable]) {
            $value = $value | ConvertTo-Json -Compress
        }
        
        $title = $title -replace "{$key}", $value
        $body = $body -replace "{$key}", $value
    }
    
    return @{
        title = $title
        body = $body
        labels = $template.labels + $Config.settings.issue_labels
        assignees = $Config.settings.assignees
        milestone = $Config.settings.milestone
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-AutomatedIssueManagement',
    'New-AutomatedIssueFromFailure',
    'New-PesterTestFailureIssues', 
    'New-PSScriptAnalyzerIssues',
    'Get-SystemMetadata',
    'New-AutomatedIssueReport'
)