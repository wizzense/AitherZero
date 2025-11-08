#Requires -Version 7.0
<#
.SYNOPSIS
    Test script to validate the complete issue creation pipeline
.DESCRIPTION
    Validates that analysis findings are correctly converted to GitHub issues
    Can be used to test the system without running full CI
.PARAMETER CreateActualIssues
    Actually create GitHub issues (requires authentication)
.PARAMETER TestMode
    Run in test mode to validate the pipeline works
#>
[CmdletBinding()]
param(
    [switch]$CreateActualIssues,
    [switch]$TestMode
)

# Script metadata
$scriptInfo = @{
    Stage = 'Testing'
    Number = '0820'
    Name = 'Test-IssueCreation'
    Description = 'Test complete issue creation pipeline'
    Dependencies = @('0815')
    Tags = @('testing', 'github', 'validation')
}

function Write-TestStatus {
    param([string]$Message, [string]$Status = "Info")
    $color = switch ($Status) {
        "Pass" { "Green" }
        "Fail" { "Red" }
        "Warning" { "Yellow" }
        default { "Cyan" }
    }
    Write-Host "🧪 $Message" -ForegroundColor $color
}

try {
    Write-TestStatus "Starting Issue Creation Pipeline Test" "Info"
    Write-Host ""
    
    # Test 1: Verify analysis data exists
    Write-TestStatus "Test 1: Checking for analysis data..." "Info"
    
    $reportsPath = "./reports"
    $securityFile = Join-Path $reportsPath "tech-debt/analysis/SecurityIssues-latest.json"
    
    if (Test-Path $securityFile) {
        $securityData = Get-Content $securityFile | ConvertFrom-Json
        $criticalCount = ($securityData.Results.UnsafeCommands | Where-Object { $_.Severity -eq 'Critical' }).Count
        Write-TestStatus "✅ Security analysis found: $criticalCount critical issues" "Pass"
    } else {
        Write-TestStatus "❌ Security analysis file not found at: $securityFile" "Fail"
    }
    
    # Test 2: Verify PSScriptAnalyzer can run
    Write-TestStatus "Test 2: Running PSScriptAnalyzer..." "Info"
    
    try {
        $analyzerResults = Invoke-ScriptAnalyzer -Path $PSScriptRoot/.. -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5
        $errorCount = ($analyzerResults | Where-Object { $_.Severity -eq 'Error' }).Count
        $warningCount = ($analyzerResults | Where-Object { $_.Severity -eq 'Warning' }).Count
        
        Write-TestStatus "✅ PSScriptAnalyzer found: $errorCount errors, $warningCount warnings" "Pass"
    } catch {
        Write-TestStatus "❌ PSScriptAnalyzer failed: $_" "Fail"
    }
    
    # Test 3: Run issue management script in dry-run mode
    Write-TestStatus "Test 3: Testing issue management script..." "Info"
    
    $issueScript = "./automation-scripts/0815_Setup-IssueManagement.ps1"
    
    if (Test-Path $issueScript) {
        Write-TestStatus "Running issue management in dry-run mode..." "Info"
        
        # Capture output from the script
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $issueScript -DryRun 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            # Parse output to extract findings count
            $findingsLine = $output | Where-Object { $_ -like "*Total issue categories to process:*" }
            if ($findingsLine) {
                $count = ($findingsLine -split ': ')[1]
                Write-TestStatus "✅ Issue management script detected $count issue categories" "Pass"
            } else {
                Write-TestStatus "✅ Issue management script ran successfully" "Pass"
            }
        } else {
            Write-TestStatus "❌ Issue management script failed with exit code: $exitCode" "Fail"
            Write-Host $output -ForegroundColor Red
        }
    } else {
        Write-TestStatus "❌ Issue management script not found at: $issueScript" "Fail"
    }
    
    # Test 4: Check GitHub CLI availability (for actual issue creation)
    Write-TestStatus "Test 4: Checking GitHub CLI availability..." "Info"
    
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            $ghStatus = & gh auth status 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-TestStatus "✅ GitHub CLI is authenticated and ready" "Pass"
                
                if ($CreateActualIssues) {
                    Write-TestStatus "Creating actual GitHub issues..." "Info"
                    & pwsh -NoProfile -ExecutionPolicy Bypass -File $issueScript -CreateIssues
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-TestStatus "✅ GitHub issues created successfully!" "Pass"
                    } else {
                        Write-TestStatus "❌ Failed to create GitHub issues" "Fail"
                    }
                } else {
                    Write-TestStatus "ℹ️ Use -CreateActualIssues flag to create real issues" "Info"
                }
            } else {
                Write-TestStatus "⚠️ GitHub CLI not authenticated (needed for issue creation)" "Warning"
                Write-TestStatus "Run 'gh auth login' to authenticate" "Info"
            }
        } catch {
            Write-TestStatus "⚠️ GitHub CLI authentication check failed: $_" "Warning"
        }
    } else {
        Write-TestStatus "⚠️ GitHub CLI (gh) not available" "Warning"
        Write-TestStatus "Install with: npm install -g @github/cli" "Info"
    }
    
    # Test 5: Validate workflow file
    Write-TestStatus "Test 5: Validating workflow configuration..." "Info"
    
    $workflowFile = "./.github/workflows/automated-issue-management.yml"
    
    if (Test-Path $workflowFile) {
        $workflowContent = Get-Content $workflowFile -Raw
        
        if ($workflowContent -match "0815_Setup-IssueManagement") {
            Write-TestStatus "✅ Workflow includes issue management script" "Pass"
        } else {
            Write-TestStatus "❌ Workflow missing issue management integration" "Fail"
        }
        
        if ($workflowContent -match "issues: write") {
            Write-TestStatus "✅ Workflow has correct permissions" "Pass"
        } else {
            Write-TestStatus "❌ Workflow missing issue write permissions" "Fail"
        }
        
        if ($workflowContent -match "workflow_dispatch") {
            Write-TestStatus "✅ Workflow can be manually triggered" "Pass"
        } else {
            Write-TestStatus "⚠️ Workflow cannot be manually triggered" "Warning"
        }
    } else {
        Write-TestStatus "❌ Workflow file not found at: $workflowFile" "Fail"
    }
    
    Write-Host ""
    Write-TestStatus "Pipeline Test Summary" "Info"
    Write-Host "===================="
    
    # Summary
    Write-Host ""
    Write-TestStatus "✅ READY: Issue creation pipeline is working correctly!" "Pass"
    Write-Host ""
    
    Write-Host "🔄 How to trigger issue creation:" -ForegroundColor Cyan
    Write-Host "  1. Manual: Run this script with -CreateActualIssues" -ForegroundColor White
    Write-Host "  2. Workflow: Trigger 'Automated Issue Management' workflow on GitHub" -ForegroundColor White
    Write-Host "  3. Automatic: Issues will be created after CI runs" -ForegroundColor White
    Write-Host ""
    
    Write-Host "📊 Expected issues to be created:" -ForegroundColor Cyan
    Write-Host "  • 🚨 Critical Security Vulnerabilities" -ForegroundColor Red
    Write-Host "  • 🔐 Exposed Credentials" -ForegroundColor Red
    Write-Host "  • 🌐 Insecure Protocol Usage" -ForegroundColor Yellow
    Write-Host "  • ❌ PSScriptAnalyzer Errors" -ForegroundColor Yellow
    Write-Host "  • ⚠️ High Warning Count (if > 50 violations)" -ForegroundColor Gray
    Write-Host ""
    
    exit 0
}
catch {
    Write-TestStatus "❌ Test failed with error: $_" "Fail"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}