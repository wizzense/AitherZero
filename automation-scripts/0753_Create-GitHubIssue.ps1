#Requires -Version 7.0

<#
.SYNOPSIS
    Create GitHub issue for a test failure
.DESCRIPTION
    Creates a GitHub issue for the next untracked test failure in the tracker.
    Updates the tracker with the GitHub issue number.
    
    Exit Codes:
    0   - Issue created successfully or no issues to create
    1   - Error creating issue
    
.NOTES
    Stage: Testing
    Order: 0753
    Dependencies: 0751, 0752, gh CLI
    Tags: testing, github, automation, issues
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TrackerPath = './test-fix-tracker.json',
    [string]$Repository,  # Override repo (default: current repo)
    [string[]]$Labels = @('bug', 'automated', 'test-failure'),
    [string]$Assignee = '@me',
    [switch]$CreateAll,  # Create issues for all open items
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0753
    Dependencies = @('0751', '0752')
    Tags = @('testing', 'github', 'automation', 'issues')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = @{
        'Error' = 'Red'
        'Warning' = 'Yellow'
        'Information' = 'White'
        'Debug' = 'Gray'
    }[$Level]
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

try {
    # Check for gh CLI
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-ScriptLog -Level Error -Message "GitHub CLI (gh) is not installed. Install it first."
        Write-ScriptLog -Message "Visit: https://cli.github.com/"
        exit 1
    }
    
    # Check gh auth status
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ScriptLog -Level Error -Message "GitHub CLI is not authenticated. Run: gh auth login"
        exit 1
    }
    
    # Load tracker
    if (-not (Test-Path $TrackerPath)) {
        Write-ScriptLog -Level Error -Message "Tracker file not found. Run 0751_Load-TestTracker.ps1 first."
        exit 1
    }
    
    $tracker = Get-Content $TrackerPath -Raw | ConvertFrom-Json -AsHashtable
    Write-ScriptLog -Message "Loaded tracker with $($tracker.issues.Count) issues"
    
    # Find issues without GitHub issues
    $issuesToCreate = $tracker.issues | Where-Object { 
        $_.status -eq 'open' -and -not $_.githubIssue 
    }
    
    if ($issuesToCreate.Count -eq 0) {
        Write-ScriptLog -Message "No issues need GitHub issues created"
        
        $withGH = @($tracker.issues | Where-Object { $_.githubIssue }).Count
        Write-Host "`n📊 GitHub Issue Status:" -ForegroundColor Cyan
        Write-Host "  With GitHub Issues: $withGH" -ForegroundColor Green
        Write-Host "  Without GitHub Issues: 0" -ForegroundColor Gray
        
        if ($PassThru) {
            return $tracker
        }
        exit 0
    }
    
    Write-ScriptLog -Message "Found $($issuesToCreate.Count) issues needing GitHub issues"
    
    # Determine how many to create
    $toCreate = if ($CreateAll) {
        $issuesToCreate
    } else {
        $issuesToCreate | Select-Object -First 1
    }
    
    $created = 0
    $failed = 0
    
    foreach ($issue in $toCreate) {
        Write-Host "`n📝 Creating GitHub issue for: $($issue.testName)" -ForegroundColor Cyan
        
        # Truncate long test names for title
        $shortName = if ($issue.testName.Length -gt 60) {
            $issue.testName.Substring(0, 60) + "..."
        } else {
            $issue.testName
        }
        
        $issueTitle = "🔧 Auto-fix: $shortName"
        
        # Build issue body
        $issueBody = @"
## Automated Test Failure

**Test:** ``$($issue.testName)``
**File:** ``$($issue.file):$($issue.line)``
**Tracker ID:** ``$($issue.id)``
**Branch:** ``$($tracker.currentBranch)``

### Error Message
\`\`\`
$($issue.fullError)
\`\`\`

### Stack Trace
\`\`\`
$($issue.stackTrace)
\`\`\`

### Automation Status
- 🤖 Automatically detected by test runner
- 🔄 Being processed by Claude Code automation
- 📝 Issue created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

### Progress Tracking
- [x] Test failure detected
- [x] Issue created
- [ ] Fix attempted
- [ ] Test passing
- [ ] Changes committed
- [ ] PR created

---
*This issue was automatically created by the AitherZero test automation system.*
"@
        
        if ($PSCmdlet.ShouldProcess($issueTitle, "Create GitHub issue")) {
            try {
                # Save body to temp file (gh can have issues with complex strings)
                $bodyFile = [System.IO.Path]::GetTempFileName()
                $issueBody | Out-File $bodyFile -Encoding UTF8
                
                # Build gh command
                $ghArgs = @(
                    'issue', 'create',
                    '--title', $issueTitle,
                    '--body-file', $bodyFile,
                    '--label', ($Labels -join ',')
                )
                
                if ($Assignee) {
                    $ghArgs += '--assignee', $Assignee
                }
                
                if ($Repository) {
                    $ghArgs += '--repo', $Repository
                }
                
                # Create issue
                $result = & gh @ghArgs 2>&1
                
                Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
                
                if ($LASTEXITCODE -eq 0) {
                    # Extract issue number from URL
                    if ($result -match '/issues/(\d+)' -or $result -match '#(\d+)') {
                        $issue.githubIssue = [int]$Matches[1]
                        Write-ScriptLog -Message "Created GitHub issue #$($issue.githubIssue)"
                        Write-Host "  URL: $result" -ForegroundColor Gray
                        $created++
                    } else {
                        Write-ScriptLog -Level Warning -Message "Created issue but couldn't extract number: $result"
                        $created++
                    }
                } else {
                    Write-ScriptLog -Level Error -Message "Failed to create issue: $result"
                    $failed++
                }
            }
            catch {
                Write-ScriptLog -Level Error -Message "Exception creating issue: $_"
                $failed++
            }
        }
        
        # Save tracker after each issue
        $tracker.updatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerPath
    }
    
    # Summary
    Write-Host "`n📊 GitHub Issue Creation Summary:" -ForegroundColor Cyan
    Write-Host "  Created: $created" -ForegroundColor Green
    Write-Host "  Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Gray' })
    
    $withGH = @($tracker.issues | Where-Object { $_.githubIssue }).Count
    $withoutGH = @($tracker.issues | Where-Object { -not $_.githubIssue }).Count
    
    Write-Host "`n  Total Status:" -ForegroundColor Cyan
    Write-Host "    With GitHub Issues: $withGH" -ForegroundColor Green
    Write-Host "    Without GitHub Issues: $withoutGH" -ForegroundColor $(if ($withoutGH -gt 0) { 'Yellow' } else { 'Gray' })
    
    if ($PassThru) {
        return $tracker
    }
    
    exit 0
}
catch {
    Write-ScriptLog -Level Error -Message "Failed to create GitHub issue: $_"
    exit 1
}