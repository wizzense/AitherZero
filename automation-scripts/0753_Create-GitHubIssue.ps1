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
    
    # Find issues without GitHub issues or with closed GitHub issues
    $issuesToCreate = @()
    
    foreach ($issue in ($tracker.issues | Where-Object { $_.status -eq 'open' })) {
        $needsIssue = $false
        
        if (-not $issue.ContainsKey('githubIssue') -or -not $issue.githubIssue) {
            # No GitHub issue yet - search for existing ones first
            Write-ScriptLog -Message "Checking for existing GitHub issues for: $($issue.testName)"
            
            # Search for existing issues with this test name
            $searchQuery = "is:issue repo:. ""$($issue.testName)"""
            $existingIssues = gh issue list --search $searchQuery --json number,state,title 2>&1
            
            if ($LASTEXITCODE -eq 0 -and $existingIssues) {
                $existingIssuesObj = $existingIssues | ConvertFrom-Json
                $openIssue = $existingIssuesObj | Where-Object { $_.state -eq 'OPEN' } | Select-Object -First 1
                
                if ($openIssue) {
                    # Found an existing open issue - reuse it
                    Write-ScriptLog -Message "Found existing open issue #$($openIssue.number) - reusing"
                    $issue.githubIssue = [int]$openIssue.number
                    
                    # Save tracker immediately after finding existing issue
                    $tracker.updatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                    $tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerPath
                    
                    # Add a comment that we're reusing this issue
                    gh issue comment $openIssue.number --body @"
🔄 **Reusing existing issue for recurring test failure**

The test is still failing with the same error. Continuing automated fix attempts.

- Test: ``$($issue.testName)``
- Error: ``$($issue.error)``
- Attempt will continue from previous state
"@ 2>&1 | Out-Null
                } else {
                    # No open issues found, but maybe there's a closed one
                    $closedIssue = $existingIssuesObj | Where-Object { $_.state -eq 'CLOSED' } | Select-Object -First 1
                    if ($closedIssue) {
                        Write-ScriptLog -Message "Found closed issue #$($closedIssue.number) - will create new issue"
                    }
                    $needsIssue = $true
                }
            } else {
                # No existing issues found
                $needsIssue = $true
            }
        } else {
            # Has a GitHub issue - check if it's still open
            Write-ScriptLog -Message "Checking status of issue #$($issue.githubIssue)"
            $issueStatus = gh issue view $issue.githubIssue --json state 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $issueState = ($issueStatus | ConvertFrom-Json).state
                if ($issueState -eq 'CLOSED') {
                    Write-ScriptLog -Message "Issue #$($issue.githubIssue) is closed - will create new issue"
                    $needsIssue = $true
                } else {
                    Write-ScriptLog -Message "Issue #$($issue.githubIssue) is still open - no new issue needed"
                }
            } else {
                Write-ScriptLog -Level Warning -Message "Could not check issue status - assuming it needs a new issue"
                $needsIssue = $true
            }
        }
        
        if ($needsIssue) {
            $issuesToCreate += $issue
        }
    }
    
    if ($issuesToCreate.Count -eq 0) {
        Write-ScriptLog -Message "No issues need GitHub issues created"
        
        $withGH = @($tracker.issues | Where-Object { 
            $_.PSObject.Properties.Name -contains 'githubIssue' -and $_.githubIssue 
        }).Count
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
                        # Update the issue with GitHub issue number
                        $issueNumber = [int]$Matches[1]
                        $issue.githubIssue = $issueNumber
                        Write-ScriptLog -Message "Created GitHub issue #$issueNumber"
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
    
    $withGH = @($tracker.issues | Where-Object { 
        $_.PSObject.Properties.Name -contains 'githubIssue' -and $_.githubIssue 
    }).Count
    $withoutGH = @($tracker.issues | Where-Object { 
        -not ($_.PSObject.Properties.Name -contains 'githubIssue') -or -not $_.githubIssue 
    }).Count
    
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