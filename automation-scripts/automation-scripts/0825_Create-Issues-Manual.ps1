#Requires -Version 7.0
<#
.SYNOPSIS
    Manually create GitHub issues from analysis findings
.DESCRIPTION
    Simple script to immediately create GitHub issues without workflows
    This is the fallback method when workflows aren't triggering properly
.PARAMETER Force
    Force creation even if GitHub CLI isn't authenticated
.PARAMETER ShowPreview
    Show what issues would be created without creating them
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$ShowPreview
)

# Script metadata
$scriptInfo = @{
    Stage = 'Manual'
    Number = '0825'
    Name = 'Create-Issues-Manual'
    Description = 'Manually create GitHub issues from findings'
    Dependencies = @('0815', 'gh')
    Tags = @('manual', 'github', 'issues')
}

function Write-ManualStatus {
    param([string]$Message, [string]$Level = "Info")
    $color = switch ($Level) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        "Critical" { "Magenta" }
        default { "Cyan" }
    }
    Write-Host "🔧 $Message" -ForegroundColor $color
}

try {
    Write-ManualStatus "Manual GitHub Issue Creation Tool" "Critical"
    Write-Host "====================================" -ForegroundColor White
    Write-Host ""
    
    # Check prerequisites
    Write-ManualStatus "Checking prerequisites..." "Info"
    
    # Check if issue management script exists
    $issueScript = "./automation-scripts/0815_Setup-IssueManagement.ps1"
    if (-not (Test-Path $issueScript)) {
        Write-ManualStatus "❌ Issue management script not found at: $issueScript" "Error"
        exit 1
    }
    Write-ManualStatus "✅ Issue management script found" "Success"
    
    # Check GitHub CLI
    $ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghAvailable) {
        Write-ManualStatus "❌ GitHub CLI (gh) not available" "Error"
        Write-ManualStatus "Install with: npm install -g @github/cli" "Info"
        if (-not $Force) { exit 1 }
    } else {
        Write-ManualStatus "✅ GitHub CLI available" "Success"
        
        # Check authentication
        try {
            $authStatus = & gh auth status 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ManualStatus "✅ GitHub CLI authenticated" "Success"
            } else {
                Write-ManualStatus "❌ GitHub CLI not authenticated" "Error"
                Write-ManualStatus "Run: gh auth login" "Info"
                if (-not $Force) { exit 1 }
            }
        } catch {
            Write-ManualStatus "⚠️ Cannot check GitHub CLI auth status" "Warning"
            if (-not $Force) { exit 1 }
        }
    }
    
    Write-Host ""
    
    if ($ShowPreview) {
        Write-ManualStatus "🔍 PREVIEW MODE - Showing what issues would be created..." "Warning"
        Write-Host ""
        
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $issueScript -DryRun
        
        Write-Host ""
        Write-ManualStatus "Preview completed. Run without -ShowPreview to create actual issues." "Info"
        exit 0
    }
    
    # Confirm action
    Write-ManualStatus "⚠️ This will create REAL GitHub issues in the repository!" "Warning"
    Write-Host ""
    Write-Host "The following types of issues will be created:" -ForegroundColor Yellow
    Write-Host "• 🚨 Critical Security Vulnerabilities" -ForegroundColor Red
    Write-Host "• 🔐 Exposed Credentials" -ForegroundColor Red  
    Write-Host "• 🌐 Insecure Protocol Usage" -ForegroundColor Yellow
    Write-Host "• 📊 Code Quality Issues" -ForegroundColor Gray
    Write-Host ""
    
    if (-not $Force) {
        $confirmation = Read-Host "Are you sure you want to proceed? Type 'YES' to continue"
        if ($confirmation -ne 'YES') {
            Write-ManualStatus "Operation cancelled by user." "Info"
            exit 0
        }
    }
    
    Write-Host ""
    Write-ManualStatus "🚀 Creating GitHub issues..." "Critical"
    Write-Host ""
    
    # Run the issue creation
    $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $issueScript -CreateIssues
    $exitCode = $LASTEXITCODE
    
    Write-Host ""
    
    if ($exitCode -eq 0) {
        Write-ManualStatus "✅ Issues created successfully!" "Success"
        Write-Host ""
        Write-ManualStatus "🔗 View created issues:" "Info"
        Write-Host "https://github.com/wizzense/AitherZero/issues?q=is:issue+is:open+label:automated-issue" -ForegroundColor Cyan
        Write-Host ""
        Write-ManualStatus "📋 Next steps:" "Info"
        Write-Host "1. Review the created issues" -ForegroundColor White
        Write-Host "2. Prioritize critical security issues first" -ForegroundColor White
        Write-Host "3. Assign team members or let AI agents handle them" -ForegroundColor White
        Write-Host ""
    } else {
        Write-ManualStatus "❌ Issue creation failed with exit code: $exitCode" "Error"
        Write-ManualStatus "Check the output above for details" "Info"
        exit $exitCode
    }
    
    exit 0
}
catch {
    Write-ManualStatus "❌ Script failed with error: $_" "Error"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}