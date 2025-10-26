#Requires -Version 7.0
<#
.SYNOPSIS
    Sets up automated issue management based on analysis findings
.DESCRIPTION
    Bridges the gap between analysis results and GitHub issue creation
    Processes security findings, test failures, and code quality issues
.PARAMETER AnalysisPath
    Path to analysis results directory
.PARAMETER CreateIssues
    Actually create GitHub issues (requires gh CLI and authentication)
.PARAMETER DryRun
    Show what issues would be created without actually creating them
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$AnalysisPath = "./reports",

    [switch]$CreateIssues,

    [switch]$DryRun
)

# Script metadata
$scriptInfo = @{
    Stage = 'Analysis'
    Number = '0815'
    Name = 'Setup-IssueManagement'
    Description = 'Creates GitHub issues from analysis findings'
    Dependencies = @('gh', 'git')
    Tags = @('analysis', 'github', 'automation', 'issues')
    RequiresAdmin = $false
}

# Import required modules
$modulePath = Join-Path $PSScriptRoot ".." "Initialize-AitherModules.ps1"
if (Test-Path $modulePath) {
    . $modulePath
}

function Write-Status {
    param([string]$Message, [string]$Level = "Info")
    $color = switch ($Level) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        default { "Cyan" }
    }
    Write-Host "🤖 $Message" -ForegroundColor $color
}

function Get-SecurityFindings {
    param([string]$Path)
    
    $securityFile = Join-Path $Path "tech-debt/analysis/SecurityIssues-latest.json"
    if (-not (Test-Path $securityFile)) {
        Write-Status "No security analysis found at: $securityFile" "Warning"
        return @()
    }

    try {
        $analysis = Get-Content $securityFile | ConvertFrom-Json
        $findings = @()

        # Critical security issues
        if ($analysis.Results.UnsafeCommands.Count -gt 0) {
            $criticalCount = ($analysis.Results.UnsafeCommands | Where-Object { $_.Severity -eq 'Critical' }).Count
            $highCount = ($analysis.Results.UnsafeCommands | Where-Object { $_.Severity -eq 'High' }).Count
            
            if ($criticalCount -gt 0) {
                $findings += @{
                    Title = "🚨 [SECURITY] Critical Security Vulnerabilities Detected ($criticalCount issues)"
                    Priority = "P0-Critical"
                    Type = "security"
                    Count = $criticalCount
                    Details = $analysis.Results.UnsafeCommands | Where-Object { $_.Severity -eq 'Critical' } | Select-Object -First 5
                }
            }
            
            if ($highCount -gt 0) {
                $findings += @{
                    Title = "⚠️ [SECURITY] High-Severity Security Issues ($highCount issues)"
                    Priority = "P1-High"
                    Type = "security"
                    Count = $highCount
                    Details = $analysis.Results.UnsafeCommands | Where-Object { $_.Severity -eq 'High' } | Select-Object -First 5
                }
            }
        }

        # Credential issues
        if ($analysis.Results.PlainTextCredentials.Count -gt 0) {
            $findings += @{
                Title = "🔐 [SECURITY] Exposed Credentials Detected ($($analysis.Results.PlainTextCredentials.Count) instances)"
                Priority = "P0-Critical"
                Type = "credentials"
                Count = $analysis.Results.PlainTextCredentials.Count
                Details = $analysis.Results.PlainTextCredentials | Select-Object -First 5
            }
        }

        # Insecure protocols
        if ($analysis.Results.InsecureProtocols.Count -gt 0) {
            $findings += @{
                Title = "🌐 [SECURITY] Insecure Protocol Usage ($($analysis.Results.InsecureProtocols.Count) instances)"
                Priority = "P1-High"
                Type = "protocols"
                Count = $analysis.Results.InsecureProtocols.Count
                Details = $analysis.Results.InsecureProtocols | Select-Object -First 5
            }
        }

        return $findings
    }
    catch {
        Write-Status "Error parsing security analysis: $_" "Error"
        return @()
    }
}

function Get-CodeQualityFindings {
    param([string]$Path)
    
    $findings = @()
    
    # Look for existing PSScriptAnalyzer results first
    $analyzerResultsFile = Join-Path $Path "psscriptanalyzer-results.json"
    
    if (Test-Path $analyzerResultsFile) {
        try {
            Write-Status "Loading existing PSScriptAnalyzer results..."
            $results = Get-Content $analyzerResultsFile | ConvertFrom-Json
            
            $errorCount = ($results | Where-Object { $_.Severity -eq 'Error' }).Count
            $warningCount = ($results | Where-Object { $_.Severity -eq 'Warning' }).Count
            
            if ($errorCount -gt 0) {
                $findings += @{
                    Title = "❌ [CODE-QUALITY] PSScriptAnalyzer Errors ($errorCount violations)"
                    Priority = "P1-High"
                    Type = "code-quality"
                    Count = $errorCount
                    Details = $results | Where-Object { $_.Severity -eq 'Error' } | Select-Object -First 5
                }
            }
            
            if ($warningCount -gt 50) {
                $findings += @{
                    Title = "⚠️ [CODE-QUALITY] High Warning Count ($warningCount violations)"
                    Priority = "P2-Medium"
                    Type = "code-quality"
                    Count = $warningCount
                    Details = $results | Where-Object { $_.Severity -eq 'Warning' } | Group-Object RuleName | Sort-Object Count -Descending | Select-Object -First 5
                }
            }
            
            return $findings
        }
        catch {
            Write-Status "Error parsing existing PSScriptAnalyzer results: $_" "Warning"
        }
    }
    
    # If no results file exists, create a finding to run analysis
    Write-Status "No existing PSScriptAnalyzer results found, creating reminder issue..."
    
    $findings += @{
        Title = "📊 [CODE-QUALITY] PSScriptAnalyzer Analysis Required"
        Priority = "P2-Medium"
        Type = "code-quality"
        Count = 1
        Details = @(@{
            RuleName = "AnalysisRequired"
            Message = "PSScriptAnalyzer needs to be run to identify code quality issues"
            ScriptName = "N/A"
            Line = "N/A"
        })
    }
    
    return $findings
}

function Get-TestFindings {
    param([string]$Path)
    
    $findings = @()
    
    # Look for test report files
    $testFiles = Get-ChildItem -Path $Path -Filter "TestReport-*.json" -ErrorAction SilentlyContinue | Sort-Object CreationTime -Descending | Select-Object -First 1
    
    foreach ($testFile in $testFiles) {
        try {
            $testReport = Get-Content $testFile.FullName | ConvertFrom-Json
            
            # Check if there are test failures
            if ($testReport.TestResults -and $testReport.TestResults.Details) {
                $failedTests = $testReport.TestResults.Details | Where-Object { $_.Result -eq 'Failed' }
                
                if ($failedTests.Count -gt 0) {
                    $findings += @{
                        Title = "🧪 [TESTS] Test Failures Detected ($($failedTests.Count) failures)"
                        Priority = "P1-High"
                        Type = "test-failure"
                        Count = $failedTests.Count
                        Details = $failedTests | Select-Object -First 3
                        ReportFile = $testFile.Name
                    }
                }
            }
        }
        catch {
            Write-Status "Error parsing test report $($testFile.Name): $_" "Warning"
        }
    }
    
    return $findings
}

function New-IssueBody {
    param(
        [hashtable]$Finding,
        [string]$Context = "Automated Analysis"
    )
    
    $body = @()
    $body += "## 🤖 Automated Issue - $($Finding.Type.ToUpper()) Analysis"
    $body += ""
    $body += "**Generated by:** AitherZero Issue Management System"
    $body += "**Analysis Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $body += "**Priority:** $($Finding.Priority)"
    $body += "**Issue Count:** $($Finding.Count)"
    $body += ""
    
    switch ($Finding.Type) {
        'security' {
            $body += "## 🔒 Security Analysis Summary"
            $body += ""
            $body += "Automated security analysis has identified critical security vulnerabilities that require immediate attention."
            $body += ""
            $body += "### 📊 Finding Details"
            foreach ($detail in $Finding.Details) {
                $body += "- **$($detail.Severity)**: Line $($detail.Line) in ``$($detail.File)``"
                $body += "  - **Issue**: $($detail.Description)"
                $body += "  - **Context**: ``$($detail.Context)``"
                $body += ""
            }
            
            $body += "### 🛠️ Recommended Actions"
            $body += ""
            $body += "@copilot Please address these security vulnerabilities:"
            $body += ""
            $body += "1. **Review each identified location** for security implications"
            $body += "2. **Replace unsafe patterns** with secure alternatives:"
            $body += "   - Replace `Invoke-Expression` with direct command execution"
            $body += "   - Use `SecureString` for credential handling"
            $body += "   - Implement proper input validation"
            $body += "3. **Test security fixes** to ensure functionality is maintained"
            $body += "4. **Run security analysis** again to verify resolution"
            $body += ""
            $body += "### 🎯 Security Best Practices"
            $body += "- Avoid dynamic code execution (`Invoke-Expression`)"
            $body += "- Use secure credential storage mechanisms"
            $body += "- Implement input validation and sanitization"
            $body += "- Follow principle of least privilege"
        }
        
        'credentials' {
            $body += "## 🔐 Credential Security Issue"
            $body += ""
            $body += "**CRITICAL**: Exposed credentials detected in source code."
            $body += ""
            $body += "### 📍 Locations Found"
            foreach ($detail in $Finding.Details) {
                $body += "- ``$($detail.File):$($detail.Line)`` - $($detail.Description)"
            }
            $body += ""
            $body += "### ⚡ Immediate Actions Required"
            $body += ""
            $body += "@copilot **URGENT**: Please address exposed credentials immediately:"
            $body += ""
            $body += "1. **Remove hardcoded credentials** from source code"
            $body += "2. **Use environment variables** or secure credential stores"
            $body += "3. **Rotate any exposed credentials** if they're real"
            $body += "4. **Implement `SecureString` patterns** for PowerShell"
            $body += "5. **Add `.gitignore` entries** for credential files"
        }
        
        'code-quality' {
            $body += "## 📊 Code Quality Analysis"
            $body += ""
            $body += "PSScriptAnalyzer has identified code quality issues that should be addressed."
            $body += ""
            $body += "### 🔍 Top Issues"
            if ($Finding.Details[0].RuleName) {
                # Grouped format
                foreach ($group in $Finding.Details) {
                    $body += "- **$($group.Name)**: $($group.Count) violations"
                }
            } else {
                # Individual format
                foreach ($detail in $Finding.Details) {
                    $body += "- **$($detail.RuleName)**: $($detail.Message)"
                    $body += "  - File: ``$($detail.ScriptName):$($detail.Line)``"
                }
            }
            $body += ""
            $body += "### 🛠️ Resolution Steps"
            $body += ""
            $body += "@copilot Please address these code quality issues:"
            $body += ""
            $body += "1. **Run PSScriptAnalyzer** locally: ``./automation-scripts/0404_Run-PSScriptAnalyzer.ps1``"
            $body += "2. **Fix high-priority violations** first (Errors, then Warnings)"
            $body += "3. **Follow PowerShell best practices** for consistent code style"
            $body += "4. **Test changes** to ensure no functional regression"
            $body += "5. **Re-run analysis** to verify fixes"
        }
        
        'test-failure' {
            $body += "## 🧪 Test Failure Analysis"
            $body += ""
            $body += "Automated testing has detected failures that require attention."
            $body += ""
            if ($Finding.ReportFile) {
                $body += "**Report File:** ``$($Finding.ReportFile)``"
                $body += ""
            }
            
            $body += "### 📋 Failed Tests"
            foreach ($test in $Finding.Details) {
                $body += "- **$($test.Name)**: $($test.Result)"
            }
            $body += ""
            $body += "### 🔧 Fix Instructions"
            $body += ""
            $body += "@copilot Please investigate and fix these test failures:"
            $body += ""
            $body += "1. **Run tests locally**: ``./automation-scripts/0402_Run-UnitTests.ps1``"
            $body += "2. **Analyze failure patterns** and root causes"
            $body += "3. **Fix underlying issues** in code or tests"
            $body += "4. **Verify fixes** with full test suite"
            $body += "5. **Update tests** if requirements have changed"
        }
    }
    
    $body += ""
    $body += "---"
    $body += "### 📈 Impact & Priority"
    
    switch ($Finding.Priority) {
        'P0-Critical' { 
            $body += "**🚨 CRITICAL**: Requires immediate attention - security risk or blocking issue"
            $body += "**Expected Resolution Time**: < 4 hours"
        }
        'P1-High' { 
            $body += "**⚡ HIGH**: Should be resolved within 1-2 days"
            $body += "**Expected Resolution Time**: 1-2 days"
        }
        'P2-Medium' { 
            $body += "**🔧 MEDIUM**: Should be addressed in current sprint"
            $body += "**Expected Resolution Time**: 1 week"
        }
    }
    
    $body += ""
    $body += "**Automation**: This issue was automatically created by AitherZero analysis system"
    $body += "**Next Analysis**: Will run again after changes are made"
    
    return $body -join "`n"
}

function New-GitHubIssue {
    param(
        [hashtable]$Finding,
        [switch]$DryRun
    )
    
    $title = $Finding.Title
    $body = New-IssueBody -Finding $Finding
    
    $labels = @('automated-issue', $Finding.Type)
    
    # Add priority label
    $labels += $Finding.Priority.ToLower()
    
    # Add specific labels based on type
    switch ($Finding.Type) {
        'security' { $labels += @('security', 'vulnerability') }
        'credentials' { $labels += @('security', 'credentials', 'urgent') }
        'code-quality' { $labels += @('code-quality', 'psscriptanalyzer') }
        'test-failure' { $labels += @('tests', 'ci-failure') }
    }
    
    if ($DryRun) {
        Write-Status "DRY RUN: Would create issue..." "Info"
        Write-Host "Title: $title" -ForegroundColor Yellow
        Write-Host "Labels: $($labels -join ', ')" -ForegroundColor Gray
        Write-Host "Priority: $($Finding.Priority)" -ForegroundColor Magenta
        Write-Host "Body Preview:" -ForegroundColor Gray
        $bodyLines = $body -split "`n" | Select-Object -First 10
        Write-Host ($bodyLines -join "`n") -ForegroundColor DarkGray
        Write-Host "..." -ForegroundColor DarkGray
        Write-Host ""
        return $true
    }
    
    # Check if gh CLI is available
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Status "GitHub CLI (gh) not available. Cannot create issues." "Error"
        return $false
    }
    
    try {
        # Check if similar issue already exists
        $existingIssues = & gh issue list --state open --label "automated-issue" --json title,number 2>$null | ConvertFrom-Json
        
        $similarIssue = $existingIssues | Where-Object { 
            $_.title -like "*$($Finding.Type.ToUpper())*" -and 
            $_.title -like "*$($Finding.Count)*" 
        }
        
        if ($similarIssue) {
            Write-Status "Similar issue already exists: #$($similarIssue.number) - $($similarIssue.title)" "Warning"
            
            # Add a comment instead of creating new issue
            $updateComment = "## 🔄 Analysis Update - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`nThis issue is still present with $($Finding.Count) occurrences. Please prioritize resolution."
            
            & gh issue comment $similarIssue.number --body $updateComment
            Write-Status "Added update comment to existing issue #$($similarIssue.number)" "Success"
            return $true
        }
        
        # Create the issue
        $labelString = $labels -join ','
        $result = & gh issue create --title $title --body $body --label $labelString --assignee '@me' 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Created issue: $result" "Success"
            return $true
        } else {
            Write-Status "Failed to create issue: $result" "Error"
            return $false
        }
    }
    catch {
        Write-Status "Error creating GitHub issue: $_" "Error"
        return $false
    }
}

# Main execution
try {
    Write-Status "🔍 Starting Issue Management Analysis..." "Info"
    Write-Status "Analysis Path: $AnalysisPath" "Info"
    
    if ($DryRun) {
        Write-Status "DRY RUN MODE - No issues will be created" "Warning"
    }
    
    $allFindings = @()
    
    # Gather security findings
    Write-Status "Analyzing security findings..." "Info"
    $securityFindings = Get-SecurityFindings -Path $AnalysisPath
    $allFindings += $securityFindings
    Write-Status "Found $($securityFindings.Count) security issue categories" "Info"
    
    # Gather code quality findings
    Write-Status "Analyzing code quality..." "Info"
    $qualityFindings = Get-CodeQualityFindings -Path $AnalysisPath
    $allFindings += $qualityFindings
    Write-Status "Found $($qualityFindings.Count) code quality issue categories" "Info"
    
    # Gather test findings
    Write-Status "Analyzing test results..." "Info"
    $testFindings = Get-TestFindings -Path $AnalysisPath
    $allFindings += $testFindings
    Write-Status "Found $($testFindings.Count) test failure categories" "Info"
    
    # Summary
    Write-Status "Total issue categories to process: $($allFindings.Count)" "Info"
    
    if ($allFindings.Count -eq 0) {
        Write-Status "✅ No issues found - system is healthy!" "Success"
        exit 0
    }
    
    # Process findings
    $created = 0
    $skipped = 0
    
    foreach ($finding in $allFindings) {
        Write-Status "Processing: $($finding.Title)" "Info"
        
        if ($CreateIssues -or $DryRun) {
            $result = New-GitHubIssue -Finding $finding -DryRun:$DryRun
            if ($result) { $created++ } else { $skipped++ }
        } else {
            Write-Host "  - $($finding.Title) [$($finding.Priority)]" -ForegroundColor Yellow
            Write-Host "    Count: $($finding.Count) issues" -ForegroundColor Gray
        }
    }
    
    # Final summary
    Write-Host ""
    Write-Status "📋 Issue Management Summary:" "Success"
    Write-Host "  Total Findings: $($allFindings.Count)" -ForegroundColor Cyan
    Write-Host "  Issues Created: $created" -ForegroundColor Green
    Write-Host "  Issues Skipped: $skipped" -ForegroundColor Yellow
    
    if (-not $CreateIssues -and -not $DryRun) {
        Write-Host ""
        Write-Status "To create GitHub issues, run with -CreateIssues flag" "Info"
        Write-Status "To preview issues, run with -DryRun flag" "Info"
    }
    
    exit 0
}
catch {
    Write-Status "Error in issue management: $_" "Error"
    Write-Status $_.ScriptStackTrace "Error"
    exit 1
}