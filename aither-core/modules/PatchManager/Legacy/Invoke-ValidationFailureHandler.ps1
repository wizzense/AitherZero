#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive validation failure handler with automatic GitHub issue creation

.DESCRIPTION
    This function is triggered when PatchManager validation fails and automatically:
    1. Creates a comprehensive summary issue for all validation failures
    2. Creates individual sub-issues for each specific error
    3. Populates all relevant details including environment info and affected files
    4. Links all issues together for systematic resolution

.PARAMETER ValidationResults
    Hash table containing detailed validation results and failures

.PARAMETER Context
    Context information about the operation that failed validation

.PARAMETER PatchDescription
    Description of the patch that failed validation

.PARAMETER AffectedFiles
    Array of files that were supposed to be affected by the patch

.PARAMETER Force
    Force issue creation even if similar issues exist

.EXAMPLE
    Invoke-ValidationFailureHandler -ValidationResults $validationResults -Context @{Operation="PatchManager"} -PatchDescription "fix: module imports"

.NOTES
    - Automatically creates parent and child issues
    - Links issues with proper references
    - Includes comprehensive environment details
    - Provides actionable resolution steps
#>

function Invoke-ValidationFailureHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ValidationResults,

        [Parameter(Mandatory = $false)]
        [hashtable]$Context = @{},

        [Parameter(Mandatory = $false)]
        [string]$PatchDescription,

        [Parameter(Mandatory = $false)]
        [string[]]$AffectedFiles = @(),

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-CustomLog "Starting comprehensive validation failure tracking..." -Level INFO

        # Import required modules
        try {
            Import-Module "$env:PROJECT_ROOT/core-runner/modules/Logging" -Force -ErrorAction Stop
        } catch {
            Write-Warning "Could not import Logging module: $($_.Exception.Message)"
        }
          $trackingId = "VALIDATION-FAIL-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

        # Analyze validation failures
        $failureAnalysis = Get-ValidationFailureAnalysis -ValidationResults $ValidationResults
    }
      process {
        try {
            # Step 1: Search for existing validation issues to prevent spam
            Write-CustomLog "Checking for existing validation issues to prevent duplicates..." -Level INFO
            $existingIssues = Find-ExistingValidationIssues -FailureAnalysis $failureAnalysis -TrackingId $trackingId

            # Step 2: Determine smart issue strategy
            $issueStrategy = Get-SmartIssueStrategy -ExistingIssues $existingIssues -FailureAnalysis $failureAnalysis -Force:$Force
            Write-CustomLog "Issue strategy: $($issueStrategy.Action) (Reason: $($issueStrategy.ReasonCode))" -Level INFO

            # Step 3: Execute based on strategy
            if ($issueStrategy.SummaryAction -eq "Update" -and $existingIssues.SummaryIssues.Count -gt 0) {
                # Update existing summary issue instead of creating new
                $recentSummary = $existingIssues.SummaryIssues | Sort-Object createdAt -Descending | Select-Object -First 1
                $summaryIssue = Update-ExistingValidationIssue -IssueNumber $recentSummary.number -NewFailureAnalysis $failureAnalysis -TrackingId $trackingId -UpdateType "Summary"

                Write-CustomLog "Updated existing summary issue #$($recentSummary.number): $($recentSummary.url)" -Level SUCCESS
                  } else {
                # Create new comprehensive summary issue with smart counter
                Write-CustomLog "Creating comprehensive validation failure summary issue..." -Level INFO
                $summaryIssue = New-ValidationSummaryIssue -FailureAnalysis $failureAnalysis -Context $Context -PatchDescription $PatchDescription -AffectedFiles $AffectedFiles -TrackingId $trackingId -CounterSuffix $issueStrategy.CounterSuffix

                if ($summaryIssue.Success) {
                    Write-CustomLog "Summary issue created: $($summaryIssue.IssueUrl)" -Level SUCCESS
                    Write-CustomLog "Summary issue number: #$($summaryIssue.IssueNumber)" -Level INFO
                }
            }

            if ($summaryIssue.Success) {
                # Step 4: Create individual sub-issues for each failure category with smart strategy
                $subIssues = @()
                foreach ($failure in $failureAnalysis.CategorizedFailures.GetEnumerator()) {
                    if ($failure.Value.Count -gt 0) {
                        $categoryAction = if ($issueStrategy.CategoryActions.ContainsKey($failure.Key)) {
                            $issueStrategy.CategoryActions[$failure.Key]
                        } else {
                            "Create"
                        }

                        if ($categoryAction -eq "Update" -and $existingIssues.CategoryIssues.ContainsKey($failure.Key)) {
                            # Update existing category issue
                            $existingCategoryIssue = $existingIssues.CategoryIssues[$failure.Key] | Sort-Object createdAt -Descending | Select-Object -First 1
                            $subIssue = Update-ExistingValidationIssue -IssueNumber $existingCategoryIssue.number -NewFailureAnalysis $failureAnalysis -TrackingId $trackingId -UpdateType $failure.Key
                            Write-CustomLog "Updated existing $($failure.Key) issue #$($existingCategoryIssue.number)" -Level SUCCESS
                        } else {
                            # Create new sub-issue
                            Write-CustomLog "Creating sub-issue for $($failure.Key) failures..." -Level INFO
                            $subIssue = New-ValidationSubIssue -FailureCategory $failure.Key -Failures $failure.Value -ParentIssueNumber $summaryIssue.IssueNumber -Context $Context -TrackingId $trackingId

                            if ($subIssue.Success) {
                                Write-CustomLog "Sub-issue created for $($failure.Key): $($subIssue.IssueUrl)" -Level SUCCESS
                                # Link the sub-issue to the parent
                                Add-IssueReference -ParentIssueNumber $summaryIssue.IssueNumber -ChildIssueNumber $subIssue.IssueNumber -Category $failure.Key
                            } else {
                                Write-CustomLog "Failed to create sub-issue for $($failure.Key): $($subIssue.Message)" -Level ERROR
                            }
                        }

                        if ($subIssue.Success) {
                            $subIssues += $subIssue
                        }
                    }
                }

                # Step 5: Update parent issue with sub-issue links
                if ($summaryIssue.IssueNumber) {
                    Update-SummaryIssueWithSubIssues -IssueNumber $summaryIssue.IssueNumber -SubIssues $subIssues -TrackingId $trackingId
                }

                Write-CustomLog "Validation failure tracking completed successfully" -Level SUCCESS
                Write-CustomLog "Summary Issue: $($summaryIssue.IssueUrl)" -Level INFO
                Write-CustomLog "Sub-issues processed: $($subIssues.Count)" -Level INFO

                return @{
                    Success = $true
                    SummaryIssue = $summaryIssue
                    SubIssues = $subIssues
                    TrackingId = $trackingId
                    Strategy = $issueStrategy
                    Message = "Comprehensive validation failure tracking completed with smart duplicate handling"
                }
                  } else {
                Write-CustomLog "Failed to create or update summary issue: $($summaryIssue.Message)" -Level ERROR
                return @{
                    Success = $false
                    Message = "Failed to create validation failure tracking: $($summaryIssue.Message)"
                }
            }
        } catch {
            $errorMessage = "Validation failure handler failed: $($_.Exception.Message)"
            Write-CustomLog $errorMessage -Level ERROR

            return @{
                Success = $false
                Message = $errorMessage
                Error = $_
            }
        }
    }
}

function Get-ValidationFailureAnalysis {
    [CmdletBinding()]
    param([hashtable]$ValidationResults)

    $analysis = @{
        TotalFailures = 0
        CategorizedFailures = @{
            ModuleImport = @()
            SyntaxError = @()
            CommandMissing = @()
            FileSystemError = @()
            GitConflict = @()
            ConfigurationError = @()
            RuntimeError = @()
            Other = @()
        }
        CriticalCount = 0
        WarningCount = 0
        Recommendations = @()
    }

    # Analyze each validation result
    foreach ($result in $ValidationResults.GetEnumerator()) {
        $key = $result.Key
        $value = $result.Value

        if ($value -eq $false -or ($value -is [array] -and $value.Count -gt 0)) {
            $analysis.TotalFailures++

            # Categorize the failure
            $category = Get-FailureCategory -Key $key -Value $value
            $analysis.CategorizedFailures[$category] += @{
                Key = $key
                Value = $value
                Details = Get-FailureDetails -Key $key -Value $value
                Severity = Get-FailureSeverity -Key $key -Value $value
            }

            # Count by severity
            $severity = Get-FailureSeverity -Key $key -Value $value
            if ($severity -eq "Critical") {
                $analysis.CriticalCount++
            } else {
                $analysis.WarningCount++
            }
        }
    }

    # Generate recommendations
    $analysis.Recommendations = Get-ValidationRecommendations -Analysis $analysis

    return $analysis
}

function Get-FailureCategory {
    [CmdletBinding()]
    param([string]$Key, $Value)

    switch -Regex ($Key) {
        "Module|Import" { return "ModuleImport" }
        "Syntax|Parse" { return "SyntaxError" }
        "Command|Missing|NotFound" { return "CommandMissing" }
        "File|Path|Directory" { return "FileSystemError" }
        "Git|Conflict|Merge" { return "GitConflict" }
        "Config|Setting" { return "ConfigurationError" }
        "Runtime|Execution" { return "RuntimeError" }
        default { return "Other" }
    }
}

function Get-FailureDetails {
    [CmdletBinding()]
    param([string]$Key, $Value)

    if ($Value -is [array]) {
        return "Issues found: $($Value -join ', ')"
    } elseif ($Value -is [string]) {
        return $Value
    } else {
        return "Validation failed for: $Key"
    }
}

function Get-FailureSeverity {
    [CmdletBinding()]
    param([string]$Key, $Value)

    # Critical failures that prevent operation
    $criticalPatterns = @("Syntax", "Parse", "ModuleImport", "Git", "Runtime")

    foreach ($pattern in $criticalPatterns) {
        if ($Key -match $pattern) {
            return "Critical"
        }
    }

    return "Warning"
}

function Get-ValidationRecommendations {
    [CmdletBinding()]
    param([hashtable]$Analysis)

    $recommendations = @()

    if ($Analysis.CategorizedFailures.ModuleImport.Count -gt 0) {
        $recommendations += "Fix module import issues by verifying module paths and dependencies"
    }

    if ($Analysis.CategorizedFailures.SyntaxError.Count -gt 0) {
        $recommendations += "Resolve PowerShell syntax errors before proceeding"
    }

    if ($Analysis.CategorizedFailures.CommandMissing.Count -gt 0) {
        $recommendations += "Install missing commands and tools"
    }

    if ($Analysis.CategorizedFailures.GitConflict.Count -gt 0) {
        $recommendations += "Resolve git conflicts and clean working tree"
    }

    if ($Analysis.CriticalCount -gt 0) {
        $recommendations += "Address all critical issues before attempting patch operations"
    }

    return $recommendations
}

function New-ValidationSummaryIssue {
    [CmdletBinding()]
    param(
        [hashtable]$FailureAnalysis,
        [hashtable]$Context,
        [string]$PatchDescription,
        [string[]]$AffectedFiles,
        [string]$TrackingId,
        [string]$CounterSuffix = ""
    )

    $title = "🚨 Comprehensive Validation Failure Summary - $TrackingId$CounterSuffix"

    $description = @"
# Comprehensive Validation Failure Summary

**Tracking ID**: $TrackingId
**Timestamp**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')
**Operation**: $($Context.Operation)
**Patch Description**: $PatchDescription

## Failure Overview

- **Total Failures**: $($FailureAnalysis.TotalFailures)
- **Critical Issues**: $($FailureAnalysis.CriticalCount)
- **Warnings**: $($FailureAnalysis.WarningCount)

## Failure Categories

$(foreach ($category in $FailureAnalysis.CategorizedFailures.GetEnumerator()) {
    if ($category.Value.Count -gt 0) {
        @"
### $($category.Key) ($($category.Value.Count) issues)
$(foreach ($failure in $category.Value) {
"- **$($failure.Key)**: $($failure.Details) [$($failure.Severity)]"
})

"@
    }
})

## Recommendations

$(foreach ($rec in $FailureAnalysis.Recommendations) {
"- $rec"
})

## Sub-Issues

This is the master tracking issue. Individual sub-issues will be created for each failure category:

<!-- SUB-ISSUES-PLACEHOLDER -->

## Resolution Strategy

1. **Immediate Actions**: Address all critical failures first
2. **Systematic Resolution**: Work through each sub-issue methodically
3. **Validation**: Re-run validation after each fix
4. **Final Verification**: Ensure all issues are resolved before closing

## Environment Context

- **Operation Context**: $($Context | ConvertTo-Json -Depth 2)
- **Affected Files**: $(if ($AffectedFiles.Count -gt 0) { $AffectedFiles -join ', ' } else { 'None specified' })

---

**Auto-generated by**: PatchManager Validation Failure Handler
**Issue Type**: Comprehensive Validation Failure Summary
**Priority**: High (due to validation failures blocking operations)
"@

    try {
        $result = Invoke-ComprehensiveIssueTracking -Operation "Error" -Title $title -Description $description -ErrorDetails @{
            FailureAnalysis = $FailureAnalysis
            Context = $Context
            TrackingId = $TrackingId
        } -AffectedFiles $AffectedFiles -Priority "High"

        return $result
    } catch {
        return @{
            Success = $false
            Message = "Failed to create summary issue: $($_.Exception.Message)"
        }
    }
}

function New-ValidationSubIssue {
    [CmdletBinding()]
    param(
        [string]$FailureCategory,
        [array]$Failures,
        [int]$ParentIssueNumber,
        [hashtable]$Context,
        [string]$TrackingId
    )

    $title = "VALIDATION FAILURES - $FailureCategory - $TrackingId"

    $description = @"
# $FailureCategory Validation Failures

**Parent Issue**: #$ParentIssueNumber
**Tracking ID**: $TrackingId
**Category**: $FailureCategory
**Failure Count**: $($Failures.Count)

## Specific Failures

$(foreach ($failure in $Failures) {
@"
### $($failure.Key)
- **Details**: $($failure.Details)
- **Severity**: $($failure.Severity)
$(if ($failure.Value -is [array] -and $failure.Value.Count -gt 0) {
"- **Specific Issues**:
$(foreach ($item in $failure.Value) { "  - $item" })"
})

"@
})

## Resolution Steps

$(Get-CategorySpecificResolutionSteps -Category $FailureCategory)

## Validation Commands

To verify resolution of these issues:

``````powershell
# Re-run validation for this category (simplified validation)
# Test-PatchingRequirements -Category $FailureCategory  # Disabled for now

# Specific validation commands
$(Get-CategoryValidationCommands -Category $FailureCategory)
``````

## Success Criteria

- [ ] All $FailureCategory issues resolved
- [ ] Validation passes for this category
- [ ] No regression in other categories
- [ ] Parent issue updated with resolution status

---

**Part of**: #$ParentIssueNumber (Comprehensive Validation Failure Summary)
**Auto-generated by**: PatchManager Validation Failure Handler
**Category**: $FailureCategory Validation Failure
"@

    try {
        $result = Invoke-ComprehensiveIssueTracking -Operation "Error" -Title $title -Description $description -ErrorDetails @{
            Category = $FailureCategory
            Failures = $Failures
            ParentIssue = $ParentIssueNumber
            TrackingId = $TrackingId
        } -Priority "Medium"

        return $result
    } catch {
        return @{
            Success = $false
            Message = "Failed to create sub-issue for $FailureCategory : $($_.Exception.Message)"
        }
    }
}

function Get-CategorySpecificResolutionSteps {
    [CmdletBinding()]
    param([string]$Category)

    switch ($Category) {
        "ModuleImport" {
            return @"
1. **Verify Module Paths**: Check that module directories exist and are accessible
2. **Check Dependencies**: Ensure all required modules are installed
3. **Import Test**: Manually test module imports in clean PowerShell session
4. **Path Resolution**: Verify environment variables and path references
5. **Permissions**: Check file system permissions on module directories
"@
        }
        "SyntaxError" {
            return @"
1. **Syntax Check**: Use PSScriptAnalyzer to identify specific syntax issues
2. **File Encoding**: Verify files are saved with correct encoding (UTF-8)
3. **Line Endings**: Check for proper line ending consistency
4. **Bracket Matching**: Verify all brackets, braces, and parentheses are properly closed
5. **Variable Declaration**: Ensure all variables are properly declared and typed
"@
        }
        "CommandMissing" {
            return @"
1. **Install Tools**: Install missing commands and applications
2. **PATH Update**: Add tool locations to system PATH
3. **Version Check**: Verify correct versions are installed
4. **Alias Setup**: Configure any required command aliases
5. **Test Access**: Verify commands are accessible from PowerShell
"@
        }
        "GitConflict" {
            return @"
1. **Status Check**: Run 'git status' to identify conflicts
2. **Conflict Resolution**: Manually resolve merge conflicts
3. **Clean Working Tree**: Ensure working directory is clean
4. **Branch State**: Verify correct branch and commit state
5. **Remote Sync**: Ensure local and remote repositories are synchronized
"@
        }
        "FileSystemError" {
            return @"
1. **Path Verification**: Check that all file and directory paths exist
2. **Permissions**: Verify read/write permissions on affected files
3. **Disk Space**: Ensure sufficient disk space available
4. **File Locks**: Check for locked files or processes
5. **Cross-Platform**: Verify path compatibility across platforms
"@
        }
        default {
            return @"
1. **Issue Analysis**: Analyze the specific error details
2. **Environment Check**: Verify system configuration
3. **Dependencies**: Check all required dependencies
4. **Manual Test**: Attempt manual reproduction of the issue
5. **Documentation**: Consult relevant documentation for guidance
"@
        }
    }
}

function Get-CategoryValidationCommands {
    [CmdletBinding()]
    param([string]$Category)

    switch ($Category) {
        "ModuleImport" {
            return @"
# Test module imports
Get-Module -ListAvailable | Where-Object Name -in @('LabRunner', 'PatchManager', 'DevEnvironment')
Import-Module "$env:PROJECT_ROOT/core-runner/modules/PatchManager" -Force -Verbose
"@
        }
        "SyntaxError" {
            return @"
# Syntax validation
Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSGallery
Get-ChildItem -Filter "*.ps1" -Recurse | ForEach-Object {
    try { [System.Management.Automation.PSParser]::Tokenize((Get-Content $_.FullName -Raw), [ref]$null) }
    catch { Write-Warning "Syntax error in $($_.Name): $_" }
}
"@
        }
        "CommandMissing" {
            return @"
# Check required commands
@('git', 'gh', 'pwsh') | ForEach-Object { Get-Command $_ -ErrorAction SilentlyContinue }
"@
        }
        default {
            return "# Run category-specific validation commands as needed"
        }
    }
}

function Add-IssueReference {
    [CmdletBinding()]
    param(
        [int]$ParentIssueNumber,
        [int]$ChildIssueNumber,
        [string]$Category
    )

    try {
        $comment = "**Sub-Issue Created**: #$ChildIssueNumber for $Category validation failures. This issue will track resolution of $Category-specific problems."

        gh issue comment $ParentIssueNumber --body $comment | Out-Null
        Write-CustomLog "Added reference to child issue #$ChildIssueNumber in parent issue #$ParentIssueNumber" -Level INFO

    } catch {
        Write-CustomLog "Failed to add issue reference: $($_.Exception.Message)" -Level WARN
    }
}

function Update-SummaryIssueWithSubIssues {
    [CmdletBinding()]
    param(
        [int]$IssueNumber,
        [array]$SubIssues,
        [string]$TrackingId
    )

    try {
        if ($SubIssues.Count -gt 0) {
            $subIssuesList = foreach ($subIssue in $SubIssues) {
                "- #$($subIssue.IssueNumber) - $($subIssue.Category) failures"
            }

            $updateComment = @"
## Sub-Issues Created

The following sub-issues have been created for systematic resolution:

$($subIssuesList -join "`n")

## Resolution Progress

Track progress by monitoring the completion of each sub-issue. This parent issue will be closed when all sub-issues are resolved.

**Next Steps**:
1. Address each sub-issue individually
2. Update sub-issues with resolution status
3. Re-run validation after each fix
4. Close this issue when all validations pass
"@

            gh issue comment $IssueNumber --body $updateComment | Out-Null
            Write-CustomLog "Updated summary issue #$IssueNumber with sub-issue links" -Level SUCCESS
        }

    } catch {
        Write-CustomLog "Failed to update summary issue: $($_.Exception.Message)" -Level WARN
    }
}

function Find-ExistingValidationIssues {
    [CmdletBinding()]
    param(
        [hashtable]$FailureAnalysis,
        [string]$TrackingId
    )

    Write-CustomLog "Searching for existing validation issues..." -Level INFO

    $existingIssues = @{
        SummaryIssues = @()
        CategoryIssues = @{
        }
        DuplicateCount = 0
    }

    try {
        # Search for existing validation failure issues
        $searchResults = gh issue list --label "validation-failure" --label "automated" --state "open" --json "number,title,labels,createdAt,url" | ConvertFrom-Json

        foreach ($issue in $searchResults) {
            $issueAge = (Get-Date) - [datetime]$issue.createdAt

            # Only consider issues from last 7 days to avoid spam
            if ($issueAge.TotalDays -le 7) {
                if ($issue.title -match "Comprehensive Validation Failure Summary") {
                    $existingIssues.SummaryIssues += $issue
                    $existingIssues.DuplicateCount++
                } else {
                    # Check for category-specific issues
                    foreach ($category in $FailureAnalysis.CategorizedFailures.Keys) {
                        if ($issue.title -match $category) {
                            if (-not $existingIssues.CategoryIssues.ContainsKey($category)) {
                                $existingIssues.CategoryIssues[$category] = @()
                            }
                            $existingIssues.CategoryIssues[$category] += $issue
                        }
                    }
                }
            }
        }

        Write-CustomLog "Found $($existingIssues.DuplicateCount) recent validation summary issues" -Level INFO
        Write-CustomLog "Found category issues: $($existingIssues.CategoryIssues.Keys -join ', ')" -Level INFO

        return $existingIssues

    } catch {
        Write-CustomLog "Error searching for existing issues: $($_.Exception.Message)" -Level WARN
        return $existingIssues
    }
}

function Get-SmartIssueStrategy {
    [CmdletBinding()]
    param(
        [hashtable]$ExistingIssues,
        [hashtable]$FailureAnalysis,
        [switch]$Force
    )

    $strategy = @{
        Action = "Create"  # Create, Update, Skip
        SummaryAction = "Create"
        CategoryActions = @{
        }
        CounterSuffix = ""
        ReasonCode = "NoExisting"
    }

    # If Force is specified, always create new
    if ($Force) {
        $strategy.ReasonCode = "ForceCreate"
        $strategy.CounterSuffix = " (Forced #$(Get-Date -Format 'HHmmss'))"
        return $strategy
    }

    # Check for recent duplicate summary issues
    if ($ExistingIssues.SummaryIssues.Count -gt 0) {
        $recentSummary = $ExistingIssues.SummaryIssues | Sort-Object createdAt -Descending | Select-Object -First 1
        $issueAge = (Get-Date) - [datetime]$recentSummary.createdAt

        if ($issueAge.TotalHours -lt 2) {
            # Very recent issue - update instead of creating new
            $strategy.SummaryAction = "Update"
            $strategy.ReasonCode = "RecentDuplicate"
            Write-CustomLog "Recent validation summary found (age: $([math]::Round($issueAge.TotalMinutes, 1)) minutes), will update instead" -Level INFO
        } elseif ($ExistingIssues.DuplicateCount -ge 3) {
            # Too many recent issues - add counter
            $strategy.CounterSuffix = " (#$($ExistingIssues.DuplicateCount + 1))"
            $strategy.ReasonCode = "MultipleRecent"
            Write-CustomLog "Multiple recent validation issues found, adding counter suffix" -Level INFO
        }
    }

    # Determine category-specific actions
    foreach ($category in $FailureAnalysis.CategorizedFailures.Keys) {
        if ($FailureAnalysis.CategorizedFailures[$category].Count -gt 0) {
            if ($ExistingIssues.CategoryIssues.ContainsKey($category) -and $ExistingIssues.CategoryIssues[$category].Count -gt 0) {
                $recentCategoryIssue = $ExistingIssues.CategoryIssues[$category] | Sort-Object createdAt -Descending | Select-Object -First 1
                $categoryAge = (Get-Date) - [datetime]$recentCategoryIssue.createdAt

                if ($categoryAge.TotalHours -lt 6) {
                    $strategy.CategoryActions[$category] = "Update"
                    Write-CustomLog "Recent $category issue found, will update instead of creating new" -Level INFO
                } else {
                    $strategy.CategoryActions[$category] = "Create"
                }
            } else {
                $strategy.CategoryActions[$category] = "Create"
            }
        }
    }

    return $strategy
}

function Update-ExistingValidationIssue {
    [CmdletBinding()]
    param(
        [int]$IssueNumber,
        [hashtable]$NewFailureAnalysis,
        [string]$TrackingId,
        [string]$UpdateType = "Summary"  # Summary or Category
    )

    Write-CustomLog "Updating existing issue #$IssueNumber with new validation data..." -Level INFO

    try {
        # Build category details string
        $categoryDetails = ""
        foreach ($category in $NewFailureAnalysis.CategorizedFailures.GetEnumerator()) {
            if ($category.Value.Count -gt 0) {
                $categoryDetails += "**$($category.Key)**: $($category.Value.Count) issues`n"
                foreach ($failure in $category.Value) {
                    $categoryDetails += "  - $($failure.Key): $($failure.Details)`n"
                }
                $categoryDetails += "`n"
            }
        }

        $updateComment = @"
## 🔄 Validation Failure Update - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')

**New Tracking ID**: $TrackingId
**Update Type**: $UpdateType

### Latest Failure Analysis
- **Total Failures**: $($NewFailureAnalysis.TotalFailures)
- **Critical Issues**: $($NewFailureAnalysis.CriticalCount)
- **Warnings**: $($NewFailureAnalysis.WarningCount)

### New Issues Detected
$categoryDetails

### Recommendations
$(($NewFailureAnalysis.Recommendations | ForEach-Object { "- $_" }) -join "`n")

---
*This issue was automatically updated to prevent duplicate issue spam. Original issue remains open for tracking.*
"@

        # Add comment to existing issue
        $commentResult = gh issue comment $IssueNumber --body $updateComment 2>&1
          if ($LASTEXITCODE -eq 0) {
            Write-CustomLog "Successfully updated issue #$IssueNumber" -Level SUCCESS

            # Get repository info for URL construction
            $repoInfo = gh repo view --json owner,name | ConvertFrom-Json
            $repoUrl = "https://github.com/$($repoInfo.owner.login)/$($repoInfo.name)"

            return @{
                Success = $true
                IssueNumber = $IssueNumber
                IssueUrl = "$repoUrl/issues/$IssueNumber"
                Message = "Existing issue updated with new validation failure data"
                UpdateType = $UpdateType
            }
        } else {
            throw "GitHub CLI error: $commentResult"
        }

    } catch {
        Write-CustomLog "Failed to update existing issue #${IssueNumber}: $($_.Exception.Message)" -Level ERROR

        return @{
            Success = $false
            Message = "Failed to update existing issue: $($_.Exception.Message)"
            IssueNumber = $IssueNumber
        }
    }
}

# Helper function to search for existing similar issues
function Search-ExistingValidationIssues {
    [CmdletBinding()]
    param(
        [string]$TrackingId,
        [hashtable]$FailureAnalysis
    )

    try {
        Write-CustomLog "Searching for existing validation failure issues..." -Level INFO

        # Search for issues with validation failure tracking patterns
        $searchQueries = @(
            "is:issue is:open label:validation-failure in:title"
            "is:issue is:open 'Comprehensive Validation Failure Summary' in:title"
            "is:issue is:open 'VALIDATION-FAIL-' in:title"
        )

        $existingIssues = @()
        foreach ($query in $searchQueries) {
            try {
                $searchResult = gh issue list --search $query --json number,title,createdAt,labels | ConvertFrom-Json
                if ($searchResult -and $searchResult.Count -gt 0) {
                    $existingIssues += $searchResult
                }
            } catch {
                Write-CustomLog "Search query failed: $query - $($_.Exception.Message)" -Level WARN
            }
        }

        # Remove duplicates and sort by creation date (newest first)
        $uniqueIssues = $existingIssues | Sort-Object number -Unique | Sort-Object createdAt -Descending

        # Analyze for similarity to current failure
        $similarIssues = @()
        foreach ($issue in $uniqueIssues) {
            $similarity = Get-IssueSimilarityScore -Issue $issue -FailureAnalysis $FailureAnalysis
            if ($similarity.Score -gt 0.7) {  # 70% similarity threshold
                $similarIssues += @{
                    Issue = $issue
                    SimilarityScore = $similarity.Score
                    SimilarityReasons = $similarity.Reasons
                }
            }
        }

        Write-CustomLog "Found $($existingIssues.Count) existing validation issues, $($similarIssues.Count) are similar" -Level INFO

        return @{
            Success = $true
            TotalExisting = $existingIssues.Count
            SimilarIssues = $similarIssues
            AllExisting = $uniqueIssues
        }

    } catch {
        Write-CustomLog "Failed to search for existing issues: $($_.Exception.Message)" -Level WARN
        return @{
            Success = $false
            TotalExisting = 0
            SimilarIssues = @()
            AllExisting = @()
        }
    }
}

function Get-IssueSimilarityScore {
    [CmdletBinding()]
    param(
        [object]$Issue,
        [hashtable]$FailureAnalysis
    )

    $score = 0.0
    $reasons = @()

    # Check for similar failure categories
    $titleWords = $Issue.title -split '\s+' | Where-Object { $_.Length -gt 3 }

    foreach ($category in $FailureAnalysis.CategorizedFailures.Keys) {
        if ($FailureAnalysis.CategorizedFailures[$category].Count -gt 0) {
            foreach ($word in $titleWords) {
                if ($word -match $category -or $category -match $word) {
                    $score += 0.3
                    $reasons += "Similar failure category: $category"
                    break
                }
            }
        }
    }

    # Check for validation failure keywords
    $validationKeywords = @("validation", "failure", "comprehensive", "module", "syntax", "import")
    foreach ($keyword in $validationKeywords) {
        if ($Issue.title -match $keyword) {
            $score += 0.1
            $reasons += "Contains validation keyword: $keyword"
        }
    }

    # Check for specific error patterns in title
    if ($Issue.title -match "ModuleImport" -and $FailureAnalysis.CategorizedFailures.ModuleImport.Count -gt 0) {
        $score += 0.4
        $reasons += "Both have ModuleImport failures"
    }

    if ($Issue.title -match "SyntaxError" -and $FailureAnalysis.CategorizedFailures.SyntaxError.Count -gt 0) {
        $score += 0.4
        $reasons += "Both have SyntaxError failures"
    }

    # Check time proximity (higher score for recent issues)
    try {
        $issueAge = [DateTime]::Now - [DateTime]::Parse($Issue.createdAt)
        if ($issueAge.TotalHours -lt 24) {
            $score += 0.2
            $reasons += "Recent issue (within 24 hours)"
        } elseif ($issueAge.TotalDays -lt 7) {
            $score += 0.1
            $reasons += "Recent issue (within 7 days)"
        }
    } catch {
        # Ignore date parsing errors
    }

    return @{
        Score = [Math]::Min($score, 1.0)  # Cap at 1.0
        Reasons = $reasons
    }
}

function Get-NextValidationCounter {
    [CmdletBinding()]
    param(
        [array]$ExistingIssues,
        [string]$BaseTrackingId
    )

    # Extract counter numbers from existing tracking IDs
    $counters = @()
    foreach ($issue in $ExistingIssues) {
        if ($issue.title -match "VALIDATION-FAIL-\d{8}-\d{6}(?:-(\d+))?") {
            if ($matches[1]) {
                $counters += [int]$matches[1]
            } else {
                $counters += 1  # First instance is implicitly counter 1
            }
        }
    }

    if ($counters.Count -eq 0) {
        return 1  # First validation failure issue
    }

    $nextCounter = ($counters | Measure-Object -Maximum).Maximum + 1
    Write-CustomLog "Determined next validation counter: $nextCounter (found $($counters.Count) existing)" -Level INFO

    return $nextCounter
}

function New-SmartValidationSummaryIssue {
    [CmdletBinding()]
    param(
        [hashtable]$FailureAnalysis,
        [hashtable]$Context,
        [string]$PatchDescription,
        [string[]]$AffectedFiles,
        [string]$TrackingId,
        [array]$SimilarIssues,
        [int]$Counter
    )

    # Determine title with counter if needed
    $title = if ($Counter -gt 1) {
        "🚨 Comprehensive Validation Failure Summary - $TrackingId-$Counter"
    } else {
        "🚨 Comprehensive Validation Failure Summary - $TrackingId"
    }

    # Build description with duplicate awareness
    $duplicateSection = if ($SimilarIssues.Count -gt 0) {
        $similarIssuesList = $SimilarIssues | ForEach-Object {
            "- #$($_.Issue.number): $($_.Issue.title) (Similarity: $([Math]::Round($_.SimilarityScore * 100, 1))%)"
        }

        @"

## Related Issues

**Similar validation failures found** (this may be a recurring issue):

$($similarIssuesList -join "`n")

### Pattern Analysis
$(if ($Counter -gt 1) {
"⚠️ **This is occurrence #$Counter of similar validation failures**. Consider investigating the root cause to prevent repeated failures."
} else {
"This appears to be a new pattern of validation failures."
})

$(foreach ($similar in $SimilarIssues) {
"**Issue #$($similar.Issue.number) similarity reasons**:
$($similar.SimilarityReasons | ForEach-Object { "- $_" } | Out-String)"
})

"@
    } else {
        @"

## 🆕 New Issue Pattern

This appears to be a new type of validation failure pattern not seen in recent issues.

"@
    }

    $description = @"
# Comprehensive Validation Failure Summary

**Tracking ID**: $TrackingId$(if ($Counter -gt 1) { "-$Counter" })
**Timestamp**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')
**Operation**: $($Context.Operation)
**Patch Description**: $PatchDescription$(if ($Counter -gt 1) { "`n**Occurrence**: #$Counter (repeated validation failure)" })

$duplicateSection

## Failure Overview

- **Total Failures**: $($FailureAnalysis.TotalFailures)
- **Critical Issues**: $($FailureAnalysis.CriticalCount)
- **Warnings**: $($FailureAnalysis.WarningCount)

## Failure Categories

$(foreach ($category in $FailureAnalysis.CategorizedFailures.GetEnumerator()) {
    if ($category.Value.Count -gt 0) {
        @"
### $($category.Key) ($($category.Value.Count) issues)
$(foreach ($failure in $category.Value) {
"- **$($failure.Key)**: $($failure.Details) [$($failure.Severity)]"
})

"@
    }
})

## Recommendations

$(foreach ($rec in $FailureAnalysis.Recommendations) {
"- $rec"
})

$(if ($Counter -gt 1) {
@"

## 🔄 Recurring Issue Analysis

**This is the $Counter$(switch ($Counter) { 2 {"nd"}; 3 {"rd"}; default {"th"} }) occurrence** of a similar validation failure pattern.

### Urgent Actions Required
1. **Root Cause Analysis**: Investigate why similar failures keep occurring
2. **Environmental Review**: Check for systemic issues in the development environment
3. **Process Improvement**: Consider additional validation steps to prevent recurrence
4. **Documentation**: Update troubleshooting guides with patterns observed

"@
})

## Sub-Issues

This is the master tracking issue. Individual sub-issues will be created for each failure category:

<!-- SUB-ISSUES-PLACEHOLDER -->

## Resolution Strategy

1. **Immediate Actions**: Address all critical failures first
2. **Systematic Resolution**: Work through each sub-issue methodically
3. **Validation**: Re-run validation after each fix
4. **Final Verification**: Ensure all issues are resolved before closing$(if ($Counter -gt 1) {
"
5. **Pattern Prevention**: Implement measures to prevent similar future failures"
})

## Environment Context

- **Operation Context**: $($Context | ConvertTo-Json -Depth 2)
- **Affected Files**: $(if ($AffectedFiles.Count -gt 0) { $AffectedFiles -join ', ' } else { 'None specified' })

---

**Auto-generated by**: PatchManager Validation Failure Handler
**Issue Type**: Comprehensive Validation Failure Summary$(if ($Counter -gt 1) { " (Repeat #$Counter)" })
**Priority**: $(if ($Counter -gt 1) { "High (recurring issue)" } else { "High (due to validation failures blocking operations)" })
"@

    try {
        $labels = @("validation-failure", "comprehensive-tracking")
        if ($Counter -gt 1) {
            $labels += "recurring-issue"
            $labels += "pattern-analysis-needed"
        }

        $result = Invoke-ComprehensiveIssueTracking -Operation "Error" -Title $title -Description $description -ErrorDetails @{
            FailureAnalysis = $FailureAnalysis
            Context = $Context
            TrackingId = "$TrackingId$(if ($Counter -gt 1) { "-$Counter" })"
            Counter = $Counter
            SimilarIssues = $SimilarIssues
        } -AffectedFiles $AffectedFiles -Priority $(if ($Counter -gt 1) { "High" } else { "High" }) -Labels $labels

        return $result
    } catch {
        return @{
            Success = $false
            Message = "Failed to create smart summary issue: $($_.Exception.Message)"
        }
    }
}
