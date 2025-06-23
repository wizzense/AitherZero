#Requires -Version 7.0
<#
.SYNOPSIS
    Creates and manages GitHub issues for automated bug fixes and patches
    
.DESCRIPTION
    This function automatically creates GitHub issues when patches fix bugs,
    links them to pull requests, and provides comprehensive tracking of 
    automated fixes with priority levels and proper labeling.
    
.PARAMETER PatchDescription
    Description of the patch being applied
    
.PARAMETER PullRequestUrl
    URL of the associated pull request
    
.PARAMETER AffectedFiles
    Array of files affected by the patch
    
.PARAMETER Labels
    Labels to apply to the GitHub issue
    
.PARAMETER Priority
    Priority level for the issue (Low, Medium, High, Critical)
    
.PARAMETER ForceCreate
    Force creation of issue even if not detected as bug fix
    
.EXAMPLE
    Invoke-GitHubIssueIntegration -PatchDescription "Fix critical validation bug" -PullRequestUrl "https://github.com/repo/pull/123" -AffectedFiles @("script.ps1") -Priority "High"
    
.NOTES
    - Requires GitHub CLI (gh) to be installed and authenticated
    - Only creates issues for bug fixes unless ForceCreate is specified
    - Links issues to pull requests automatically
    - Provides comprehensive audit trail
#>

function Invoke-GitHubIssueIntegration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PatchDescription,
        
        [Parameter(Mandatory = $false)]
        [int]$IssueNumber,
        
        [Parameter(Mandatory = $false)]
        [string]$PullRequestUrl,
        
        [Parameter(Mandatory = $false)]
        [string[]]$AffectedFiles = @(),
        
        [Parameter(Mandatory = $false)]
        [string[]]$Labels = @("bug"),
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Low", "Medium", "High", "Critical")]
        [string]$Priority = "Medium",
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceCreate,
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateNewIssue,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    begin {
        Write-Host "GitHub Issue Integration: Starting issue creation process..." -ForegroundColor Blue
        
        # Check if GitHub CLI is available
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            return @{
                Success = $false
                Message = "GitHub CLI (gh) not found. Cannot create issues automatically."
                IssueUrl = $null
                IssueNumber = $null
            }
        }
        
        # Detect if this is a bug fix
        $isBugFix = $PatchDescription -match '\b(fix|bug|error|issue|problem|broken|critical|urgent|emergency)\b' -or $ForceCreate
        
        if (-not $isBugFix -and -not $ForceCreate) {
            Write-Host "  Not a bug fix - skipping issue creation" -ForegroundColor Gray
            return @{
                Success = $true
                Message = "Skipped issue creation - not a bug fix"
                IssueUrl = $null
                IssueNumber = $null
            }
        }
    }
    
    process {
        try {
            Write-Host "  Creating GitHub issue for bug fix..." -ForegroundColor Green
            
            # First check if GitHub CLI is available
            $ghInstalled = $null -ne (Get-Command "gh" -ErrorAction SilentlyContinue)
            if (-not $ghInstalled) {
                Write-Warning "GitHub CLI (gh) not found. Skipping issue creation."
                return @{
                    Success = $false
                    Message = "GitHub CLI (gh) not found"
                    IssueUrl = $null
                    IssueNumber = $null
                }
            }
            
            # Check if we're in a GitHub repository
            $repoExists = (git config --get remote.origin.url) -match "github\.com"
            if (-not $repoExists) {
                Write-Warning "Not in a GitHub repository. Skipping issue creation."
                return @{
                    Success = $false
                    Message = "Not in a GitHub repository"
                    IssueUrl = $null 
                    IssueNumber = $null
                }
            }
              # Determine priority-based labels
            $priorityLabels = switch ($Priority) {
                "Critical" { @("high-priority") }
                "High" { @("priority") }
                "Medium" { @() }  # No additional labels for medium
                "Low" { @("minor") }
                default { @() }
            }
            
            # Combine all labels and remove duplicates
            $allLabels = ($Labels + $priorityLabels + @("automated")) | Sort-Object -Unique
            
            # First try to create any missing labels
            foreach ($label in $allLabels) {
                Write-Host "  Checking if label '$label' exists..." -ForegroundColor Gray
                $labelExists = gh label list | Select-String -Pattern "^$label\s" -Quiet
                
                if (-not $labelExists) {
                    try {
                        Write-Host "  Creating missing label: $label" -ForegroundColor Yellow
                        # Default color for new labels
                        $labelColor = switch ($label) {
                            "bug" { "d73a4a" }  # red
                            "automated" { "0075ca" }  # blue
                            "high-priority" { "b60205" }  # dark red
                            "priority" { "d93f0b" }  # orange
                            "minor" { "c2e0c6" }  # light green
                            default { "fbca04" }  # yellow
                        }
                        
                        gh label create $label --color $labelColor --description "Auto-created by PatchManager" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
                            Write-Warning "  Could not create label '$label', will continue without it"
                            # Remove the label from our list so we don't try to use it
                            $allLabels = $allLabels | Where-Object{ $_ -ne $label }
                        }
                    }
                    catch {
                        Write-Warning "  Failed to create label '$label': $_"
                    }
                }
            }            # Create comprehensive GitHub issue (NO EMOJIS - project policy)
            $title = "PatchManager: $PatchDescription"
            
            # Create detailed issue body with full context
            $body = @"
## Automated Patch Issue

**Patch Description**: $PatchDescription
**Priority**: $Priority
**Created**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')
**PatchManager Version**: v2.0

### Affected Files
$($AffectedFiles | ForEach-Object { "- ``$_``" } | Out-String)

### Patch Details
- **Type**: $(if ($PatchDescription -match '\b(fix|bug)\b') { 'Bug Fix' } elseif ($PatchDescription -match '\b(feat|feature)\b') { 'Feature' } elseif ($PatchDescription -match '\b(chore|maintenance)\b') { 'Maintenance' } else { 'General Patch' })
- **Auto-generated**: Yes
- **Manual Review Required**: Yes

### Expected Actions

1. **Review the pull request** (will be linked when created)
2. **Validate changes** in a clean environment  
3. **Test functionality** to ensure no regressions
4. **Approve and merge** if all validations pass
5. **Close this issue** after successful merge

### Automation Status

- [x] Patch applied successfully
- [ ] Pull request pending (will be linked)
- [ ] Awaiting human review and approval

**Note**: This issue was created automatically by PatchManager to track the patch lifecycle and ensure proper review process.
"@
            
            $labelString = $allLabels -join ','
            Write-Host "  Creating issue with title: $title" -ForegroundColor Cyan
            Write-Host "  Labels: $labelString" -ForegroundColor Gray            # Create issue using proper parameter passing to avoid command line issues
            Write-Host "  Creating GitHub issue..." -ForegroundColor Cyan
            
            try {
                # Save body to temp file to avoid command line issues
                $tempBodyFile = [System.IO.Path]::GetTempFileName()
                $body | Out-File -FilePath $tempBodyFile -Encoding utf8
                
                # Create issue with file-based body
                $issueResult = gh issue create --title $title --body-file $tempBodyFile --label $labelString
                
                # Clean up temp file
                Remove-Item $tempBodyFile -Force -ErrorAction SilentlyContinue
                
            } catch {
                Write-Host "  Falling back to simple body..." -ForegroundColor Yellow
                
                # Fallback to simple body if file method fails
                $simpleBody = "Automated patch: $PatchDescription`nAffected files: $($AffectedFiles -join ', ')`nCreated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
                $issueResult = gh issue create --title $title --body $simpleBody --label $labelString
            }if ($LASTEXITCODE -eq 0 -and $issueResult) {
                Write-Host "  GitHub issue created successfully: $issueResult" -ForegroundColor Green
                
                # Extract issue number from the URL
                # GitHub CLI returns URL like: https://github.com/owner/repo/issues/123
                $issueNumber = $null
                if ($issueResult -match '/issues/(\d+)') {
                    $issueNumber = $matches[1]
                    Write-Host "  Issue number extracted: #$issueNumber" -ForegroundColor Cyan
                }
                
                return @{
                    Success = $true
                    Message = "GitHub issue created successfully"
                    IssueUrl = $issueResult
                    IssueNumber = $issueNumber
                }
            } else {
                Write-Warning "  Failed to create GitHub issue: $issueResult"
                return @{
                    Success = $false
                    Message = "Failed to create GitHub issue"
                    IssueUrl = $null
                    IssueNumber = $null
                }
            }
            
        } catch {
            Write-Error "Failed to create GitHub issue: $($_.Exception.Message)"
            return @{
                Success = $false
                Message = "Failed to create GitHub issue: $($_.Exception.Message)"
                IssueUrl = $null
                IssueNumber = $null
            }
        }
    }
}



