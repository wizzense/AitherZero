#Requires -Version 7.0

<#
.SYNOPSIS
    The ONLY way to create GitHub issues for patch tracking.

.DESCRIPTION
    Creates clean, professional GitHub issues for patch tracking.
    No emoji/Unicode output - follows project standards.

.PARAMETER Description
    Description of the patch/issue

.PARAMETER Priority
    Priority level (Low, Medium, High, Critical)

.PARAMETER AffectedFiles
    Files affected by the patch

.PARAMETER Labels
    Additional labels to apply

.PARAMETER DryRun
    Preview what would be created without actually creating

.EXAMPLE
    New-PatchIssue -Description "Fix module loading bug" -Priority "High"

.EXAMPLE
    New-PatchIssue -Description "Update config files" -AffectedFiles @("config.json", "settings.ps1") -DryRun

.NOTES
    This function replaces:
    - Invoke-ComprehensiveIssueTracking
    - Invoke-GitHubIssueIntegration
    - New-SimpleIssueForPatch
    - And all other issue creation functions
#>

function New-PatchIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Low', 'Medium', 'High', 'Critical')]
        [string]$Priority = 'Medium',

        [Parameter(Mandatory = $false)]
        [string[]]$AffectedFiles = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$Labels = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$TestOutput = @(),

        [Parameter(Mandatory = $false)]
        [string[]]$ErrorDetails = @(),

        [Parameter(Mandatory = $false)]
        [string]$TestType = 'Unknown',

        [Parameter(Mandatory = $false)]
        [hashtable]$TestContext = @{},

        [Parameter(Mandatory = $false)]
        [string]$TargetRepository,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    begin {
        # Import the test analysis function
        $analysisPath = Join-Path $PSScriptRoot '../Private/Get-TestAnalysisContext.ps1'
        if (Test-Path $analysisPath) {
            . $analysisPath
        }

        function Write-IssueLog {
            param($Message, $Level = 'INFO')
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message $Message -Level $Level
            } else {
                Write-Host "[$Level] $Message"
            }
        }

        Write-IssueLog "Creating enhanced GitHub issue for: $Description" -Level 'INFO'
    }

    process {
        try {
            # Calculate steps for progress if called from parent operation
            $hasProgressContext = $false
            $parentProgressId = $null
            
            # Check if we're being called within a larger operation that has progress
            if (Get-Variable -Name 'progressId' -Scope 1 -ErrorAction SilentlyContinue) {
                $parentProgressId = (Get-Variable -Name 'progressId' -Scope 1).Value
                $hasProgressContext = $true
            }
            
            # Check GitHub CLI availability
            if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
                throw 'GitHub CLI (gh) not found. Please install and authenticate with GitHub CLI.'
            }            # Get repository information (use TargetRepository if specified)
            try {
                if ($TargetRepository) {
                    # Use specified target repository
                    Write-IssueLog "Using specified target repository: $TargetRepository" -Level "INFO"
                    $repoInfo = @{
                        GitHubRepo = $TargetRepository
                        FullName = $TargetRepository
                        Type = "Specified"
                    }
                } else {
                    # Auto-detect current repository
                    $repoInfo = Get-GitRepositoryInfo
                    Write-IssueLog "Detected repository: $($repoInfo.FullName) ($($repoInfo.Type))" -Level "INFO"
                }
            } catch {
                throw "Failed to get repository information: $($_.Exception.Message)"
            }

            # Perform intelligent test analysis if test data is provided
            $analysisResult = $null
            if ($TestOutput.Count -gt 0 -or $ErrorDetails.Count -gt 0) {
                Write-IssueLog 'Performing intelligent test analysis...' -Level 'INFO'
                
                # Update parent progress if in context
                if ($hasProgressContext -and $parentProgressId -and (Get-Command Write-PatchProgressLog -ErrorAction SilentlyContinue)) {
                    Write-PatchProgressLog -Message 'Analyzing test results for issue creation' -Level 'Info'
                }

                $analysisParams = @{
                    TestOutput        = $TestOutput
                    ErrorDetails      = $ErrorDetails
                    TestType          = $TestType
                    AdditionalContext = $TestContext
                }

                if (Get-Command Get-TestAnalysisContext -ErrorAction SilentlyContinue) {
                    $analysisResult = Get-TestAnalysisContext @analysisParams

                    # Merge analysis results with manually specified files
                    if ($analysisResult.AffectedFiles.Count -gt 0) {
                        $AffectedFiles = ($AffectedFiles + $analysisResult.AffectedFiles) | Sort-Object -Unique
                    }

                    Write-IssueLog "Analysis complete. Confidence: $($analysisResult.Confidence), Found $($analysisResult.AffectedFiles.Count) files, $($analysisResult.AffectedModules.Count) modules" -Level 'INFO'
                } else {
                    Write-IssueLog 'Test analysis function not available, using manual file list' -Level 'WARN'
                }
            }

            # Create issue title and body
            $issueTitle = "Patch: $Description"
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'            # Gather comprehensive system information
            $systemInfo = @{
                Platform          = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
                OSVersion         = if ($IsWindows) { [System.Environment]::OSVersion.Version.ToString() } else { 'N/A' }
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                GitBranch         = (git rev-parse --abbrev-ref HEAD 2>$null) -replace "`n", ''
                GitCommit         = (git rev-parse --short HEAD 2>$null) -replace "`n", ''
                GitRemote         = (git config --get remote.origin.url 2>$null) -replace "`n", ''
                WorkingDirectory  = Get-Location
                ProjectRoot       = $env:PROJECT_ROOT
                User              = $env:USERNAME
                Computer          = $env:COMPUTERNAME
                ProcessId         = $PID
                TimeZone          = [System.TimeZoneInfo]::Local.DisplayName
                Timestamp         = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
            }

            $issueBody = @"
## Patch Tracking Issue

**Description**: $Description
**Priority**: $Priority
**Created**: $timestamp

### Files Affected
$(if ($AffectedFiles.Count -gt 0) {
    "**Detected Files** ($($AffectedFiles.Count) total):`n" + (($AffectedFiles | ForEach-Object { "- ``$_``" }) -join "`n")
} else {
    "**Detection Status**: No specific files identified`n`n**Methods Attempted**: Stack trace analysis, error context parsing, intelligent pattern matching`n**Possible Reasons**: Global system error, configuration issue, or runtime failure not tied to specific files`n**Investigation**: Manual review of error details and logs may be required`n**Context**: Review the error description and system logs for additional clues`n**Note**: Some errors affect the entire system or environment rather than specific files."
})

$(if ($analysisResult) { @"

### Intelligent Analysis Results
**Analysis Confidence**: $($analysisResult.Confidence)
**Analysis Timestamp**: $($analysisResult.AnalysisTimestamp)

#### Affected Modules ($($analysisResult.AffectedModules.Count) detected)
$(if ($analysisResult.AffectedModules.Count -gt 0) {
    ($analysisResult.AffectedModules | ForEach-Object { "- ``$_``" }) -join "`n"
} else {
    '*No modules specifically identified*'
})

#### Affected Capabilities ($($analysisResult.AffectedCapabilities.Count) detected)
$(if ($analysisResult.AffectedCapabilities.Count -gt 0) {
    ($analysisResult.AffectedCapabilities | ForEach-Object { "- $_" }) -join "`n"
} else {
    '*No specific capabilities identified*'
})

#### Error Categories ($($analysisResult.ErrorCategories.Count) detected)
$(if ($analysisResult.ErrorCategories.Count -gt 0) {
    ($analysisResult.ErrorCategories | ForEach-Object { "- $_" }) -join "`n"
} else {
    '*No error categories identified*'
})

#### Failure Analysis
$(if ($analysisResult.FailureReasons.Count -gt 0) {
    "**Root Causes**:`n" + (($analysisResult.FailureReasons | ForEach-Object { "- $_" }) -join "`n")
} else {
    '*No specific failure reasons identified*'
})

#### Automated Recommendations
$(if ($analysisResult.Recommendations.Count -gt 0) {
    ($analysisResult.Recommendations | ForEach-Object { "- $_" }) -join "`n"
} else {
    '*No specific recommendations available*'
})

#### Technical Details
- **Test Type**: $($analysisResult.TechnicalDetails.TestType)
- **Output Lines Analyzed**: $($analysisResult.TechnicalDetails.TotalOutputLines)
- **Error Lines Analyzed**: $($analysisResult.TechnicalDetails.TotalErrorLines)
- **Working Directory**: $($analysisResult.TechnicalDetails.WorkingDirectory)
$(if ($analysisResult.TechnicalDetails.RawErrorSample) {
    "- **Error Sample**: ``$($analysisResult.TechnicalDetails.RawErrorSample)``"
})

"@ } else { '' })

### Review Checklist
- [ ] Code review completed
- [ ] All tests passing
- [ ] Documentation updated (if applicable)
- [ ] Security review completed (if applicable)
- [ ] Performance impact assessed
- [ ] Cross-platform compatibility verified
- [ ] PatchManager workflow followed correctly

### Merge Requirements
- [ ] All required approvals received
- [ ] All CI/CD checks passing
- [ ] No merge conflicts
- [ ] Branch is up to date with target branch

### Expected Actions
1. Review associated pull request when created
2. Validate changes in clean environment
3. Approve and merge if all checks pass
4. This issue will auto-close when PR is merged

### System Information

#### Environment Details
- **Platform**: $($systemInfo.Platform)
- **OS Version**: $($systemInfo.OSVersion)
- **PowerShell Version**: $($systemInfo.PowerShellVersion)
- **Git Branch**: $($systemInfo.GitBranch)
- **Git Commit**: $($systemInfo.GitCommit)
- **Git Remote**: $($systemInfo.GitRemote)
- **Working Directory**: $($systemInfo.WorkingDirectory)
- **Project Root**: $($systemInfo.ProjectRoot)
- **User**: $($systemInfo.User)
- **Computer**: $($systemInfo.Computer)
- **Process ID**: $($systemInfo.ProcessId)
- **Time Zone**: $($systemInfo.TimeZone)
- **Timestamp**: $($systemInfo.Timestamp)

### Automation Details
- **Created by**: PatchManager v2.1 (Enhanced with Intelligent Analysis)
- **Operation Type**: Issue Creation
- **Priority Level**: $Priority
- **Auto-generated**: Yes
- **Analysis Engine**: $(if ($analysisResult) { "Enabled (Confidence: $($analysisResult.Confidence))" } else { 'Disabled' })
- **Tracking ID**: PATCH-$(Get-Date -Format 'yyyyMMdd-HHmmss')
- **Last Updated**: $timestamp

---
*Created by PatchManager Enhanced v2.1 with Intelligent Test Analysis*
"@

            if ($DryRun) {
                Write-IssueLog "DRY RUN: Would create issue with title: $issueTitle" -Level 'INFO'
                return @{
                    Success = $true
                    DryRun  = $true
                    Title   = $issueTitle
                    Body    = $issueBody
                }
            }

            # Prepare labels and ensure they exist
            $allLabels = @('patch') + $Labels
            if ($Priority -eq 'High' -or $Priority -eq 'Critical') {
                $allLabels += 'priority'
            }

            # Ensure required labels exist, create them if needed
            foreach ($label in $allLabels) {
                $labelCheck = gh label list --repo $repoInfo.GitHubRepo --search $label 2>&1 | Out-String
                if (-not $labelCheck.Contains($label)) {
                    Write-IssueLog "Creating missing label: $label" -Level 'INFO'
                    
                    # Update parent progress if in context
                    if ($hasProgressContext -and $parentProgressId -and (Get-Command Write-PatchProgressLog -ErrorAction SilentlyContinue)) {
                        Write-PatchProgressLog -Message "Creating GitHub label: $label" -Level 'Info'
                    }
                    
                    $labelColor = switch ($label) {
                        'patch' { '0366d6' }
                        'priority' { 'd93f0b' }
                        default { '7057ff' }
                    }
                    gh label create $label --repo $repoInfo.GitHubRepo --color $labelColor --description 'Auto-created by PatchManager' 2>&1 | Out-Null
                }
            }            # Create the issue with robust error handling
            Write-IssueLog "Creating GitHub issue: $issueTitle" -Level 'INFO'
            
            # Update parent progress if in context
            if ($hasProgressContext -and $parentProgressId -and (Get-Command Write-PatchProgressLog -ErrorAction SilentlyContinue)) {
                Write-PatchProgressLog -Message "Submitting issue to GitHub" -Level 'Info'
            }
            
            $result = gh issue create --repo $repoInfo.GitHubRepo --title $issueTitle --body $issueBody --label ($allLabels -join ',') 2>&1

            # Handle any remaining label errors gracefully
            if ($LASTEXITCODE -ne 0 -and $result -match 'not found') {
                Write-IssueLog 'Label issue detected, creating without labels' -Level 'WARN'
                $result = gh issue create --repo $repoInfo.GitHubRepo --title $issueTitle --body $issueBody 2>&1
            }

            if ($LASTEXITCODE -eq 0) {
                # Extract issue number from URL
                $issueNumber = $null
                if ($result -match '/issues/(\d+)') {
                    $issueNumber = $Matches[1]
                }

                Write-IssueLog "Issue created successfully: $result" -Level 'SUCCESS'
                if ($issueNumber) {
                    Write-IssueLog "Issue number: #$issueNumber" -Level 'INFO'
                }

                return @{
                    Success     = $true
                    IssueUrl    = $result.ToString().Trim()
                    IssueNumber = $issueNumber
                    Title       = $issueTitle
                }
            } else {
                throw "GitHub CLI failed: $($result -join ' ')"
            }

        } catch {
            $errorMessage = "Failed to create issue: $($_.Exception.Message)"
            Write-IssueLog $errorMessage -Level 'ERROR'

            return @{
                Success = $false
                Message = $errorMessage
            }
        }
    }
}

Export-ModuleMember -Function New-PatchIssue
