function New-GitHubIssueFromFinding {
    <#
    .SYNOPSIS
        Creates GitHub Issues from PSScriptAnalyzer findings with automated assignment and labeling
    
    .DESCRIPTION
        This function automates the creation of GitHub Issues for PSScriptAnalyzer findings,
        including appropriate templates, labels, assignments, and metadata for tracking.
    
    .PARAMETER Finding
        PSScriptAnalyzer finding object to create an issue for
    
    .PARAMETER RepositoryOwner
        GitHub repository owner (defaults to current repository)
    
    .PARAMETER RepositoryName
        GitHub repository name (defaults to current repository)
    
    .PARAMETER DryRun
        If specified, shows what issues would be created without actually creating them
    
    .PARAMETER ForceCreate
        Force creation even if similar issue already exists
    
    .PARAMETER GitHubToken
        GitHub personal access token (uses GITHUB_TOKEN environment variable if not specified)
    
    .EXAMPLE
        $findings = Invoke-ScriptAnalyzer -Path . -Recurse
        $findings | Where-Object Severity -eq 'Error' | New-GitHubIssueFromFinding
        
        Creates GitHub Issues for all Error-level findings
    
    .EXAMPLE
        New-GitHubIssueFromFinding -Finding $finding -DryRun
        
        Shows what issue would be created without actually creating it
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Finding,
        
        [Parameter(Mandatory = $false)]
        [string]$RepositoryOwner,
        
        [Parameter(Mandatory = $false)]
        [string]$RepositoryName,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun,
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceCreate,
        
        [Parameter(Mandatory = $false)]
        [string]$GitHubToken
    )
    
    begin {
        # Initialize GitHub CLI availability check
        $ghAvailable = $false
        try {
            $null = Get-Command 'gh' -ErrorAction Stop
            $ghAvailable = $true
        }
        catch {
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'ERROR' -Message "GitHub CLI (gh) not available. Cannot create issues."
            } else {
                Write-Error "GitHub CLI (gh) not available. Please install GitHub CLI to create issues."
            }
            return
        }
        
        # Get repository information
        if (-not $RepositoryOwner -or -not $RepositoryName) {
            try {
                $repoInfo = & gh repo view --json owner,name | ConvertFrom-Json
                if (-not $RepositoryOwner) { $RepositoryOwner = $repoInfo.owner.login }
                if (-not $RepositoryName) { $RepositoryName = $repoInfo.name }
            }
            catch {
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'ERROR' -Message "Failed to determine repository information: $($_.Exception.Message)"
                } else {
                    Write-Error "Failed to determine repository information: $($_.Exception.Message)"
                }
                return
            }
        }
        
        # Set up GitHub token if provided
        if ($GitHubToken) {
            $env:GITHUB_TOKEN = $GitHubToken
        }
        
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'INFO' -Message "Initializing GitHub Issues creation for repository: $RepositoryOwner/$RepositoryName"
        }
        
        $createdIssues = @()
        $skippedIssues = @()
        $errors = @()
    }
    
    process {
        try {
            # Validate finding object
            if (-not $Finding -or -not $Finding.RuleName -or -not $Finding.Severity) {
                Write-Warning "Invalid finding object provided - missing required properties"
                return
            }
            
            # Determine if this finding should become an issue
            $shouldCreateIssue = $false
            $issuePriority = 'low'
            
            switch ($Finding.Severity) {
                'Error' {
                    $shouldCreateIssue = $true
                    $issuePriority = 'critical'
                }
                'Warning' {
                    # Only create issues for certain warning types or if they accumulate
                    $criticalWarningRules = @(
                        'PSAvoidUsingPlainTextForPassword',
                        'PSAvoidUsingUsernameAndPasswordParams',
                        'PSAvoidUsingConvertToSecureStringWithPlainText',
                        'PSUsePSCredentialType',
                        'PSAvoidHardcodedCredentials',
                        'PSAvoidUsingInvokeExpression',
                        'PSUseCompatibleCmdlets',
                        'PSUseCompatibleSyntax'
                    )
                    
                    if ($Finding.RuleName -in $criticalWarningRules) {
                        $shouldCreateIssue = $true
                        $issuePriority = 'high'
                    } else {
                        $issuePriority = 'medium'
                        # Check if we should create issue based on accumulation or configuration
                        $shouldCreateIssue = $true  # For now, create issues for all warnings
                    }
                }
                'Information' {
                    # Generally don't create issues for informational findings
                    # unless they are in critical areas or accumulate significantly
                    $shouldCreateIssue = $false
                    $issuePriority = 'low'
                    
                    # Exception: Create issues for documentation-related findings in critical modules
                    if ($Finding.RuleName -eq 'PSProvideCommentHelp' -and 
                        $Finding.ScriptPath -match 'SecureCredentials|SecurityAutomation|LicenseManager') {
                        $shouldCreateIssue = $true
                    }
                }
            }
            
            if (-not $shouldCreateIssue) {
                $skippedIssues += @{
                    Finding = $Finding
                    Reason = "Severity $($Finding.Severity) with rule $($Finding.RuleName) does not meet issue creation criteria"
                }
                return
            }
            
            # Check for existing similar issues (unless ForceCreate is specified)
            if (-not $ForceCreate) {
                $searchQuery = "repo:$RepositoryOwner/$RepositoryName is:issue is:open label:psscriptanalyzer $($Finding.RuleName)"
                try {
                    $existingIssues = & gh issue list --search $searchQuery --json number,title,labels --limit 10 | ConvertFrom-Json
                    
                    # Check if we already have an issue for this specific finding
                    $duplicateIssue = $existingIssues | Where-Object { 
                        $_.title -match [regex]::Escape($Finding.RuleName) -and
                        $_.title -match [regex]::Escape((Split-Path $Finding.ScriptPath -Leaf))
                    }
                    
                    if ($duplicateIssue) {
                        $skippedIssues += @{
                            Finding = $Finding
                            Reason = "Similar issue already exists: #$($duplicateIssue.number)"
                            ExistingIssue = $duplicateIssue
                        }
                        return
                    }
                }
                catch {
                    if ($script:UseCustomLogging) {
                        Write-CustomLog -Level 'WARNING' -Message "Failed to check for existing issues: $($_.Exception.Message)"
                    }
                }
            }
            
            # Prepare issue data
            $fileName = Split-Path $Finding.ScriptPath -Leaf
            $relativePath = $Finding.ScriptPath -replace [regex]::Escape($script:ProjectRoot), '' -replace '^[\\\/]', ''
            
            # Determine assignees based on CODEOWNERS
            $assignees = @()
            try {
                $codeownersPath = Join-Path $script:ProjectRoot ".github/CODEOWNERS"
                if (Test-Path $codeownersPath) {
                    $codeowners = Get-Content $codeownersPath
                    $matchingRule = $codeowners | Where-Object { 
                        $_ -notmatch '^#' -and $_ -match '\S' -and 
                        ($relativePath -like ($_ -split '\s+')[0])
                    } | Select-Object -First 1
                    
                    if ($matchingRule) {
                        $owners = ($matchingRule -split '\s+')[1..100] | Where-Object { $_ -match '^@' }
                        $assignees = $owners -replace '^@', ''
                    }
                }
            }
            catch {
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'WARNING' -Message "Failed to determine assignees from CODEOWNERS: $($_.Exception.Message)"
                }
            }
            
            # Generate issue title
            $issueTitle = "[$($Finding.Severity.ToUpper())] $($Finding.RuleName) in $fileName"
            
            # Generate issue body based on severity
            $issueBody = Get-IssueBodyForFinding -Finding $Finding -Priority $issuePriority
            
            # Determine structured labels
            $labels = @(
                'code-quality',
                'psscriptanalyzer',
                $Finding.Severity.ToLower(),
                "priority:$(if ($issuePriority -eq 'critical') { 'critical' } elseif ($issuePriority -eq 'high') { 'high' } elseif ($issuePriority -eq 'medium') { 'medium' } else { 'low' })"
            )
            
            # Add category-based labels
            $categoryLabels = Get-CategoryLabelsForRule -RuleName $Finding.RuleName
            $labels += $categoryLabels
            
            # Add security label for security-related rules
            $securityRules = @(
                'PSAvoidUsingPlainTextForPassword',
                'PSAvoidUsingUsernameAndPasswordParams',
                'PSAvoidUsingConvertToSecureStringWithPlainText',
                'PSUsePSCredentialType',
                'PSAvoidHardcodedCredentials',
                'PSAvoidUsingInvokeExpression'
            )
            
            if ($Finding.RuleName -in $securityRules) {
                $labels += 'security'
            }
            
            # Add module-specific label
            if ($relativePath -match 'aither-core[/\\]modules[/\\]([^/\\]+)') {
                $labels += "module:$($matches[1].ToLower())"
            }
            
            # Add automation capability label
            $autoFixableRules = @(
                'PSAvoidUsingCmdletAliases',
                'PSUseConsistentWhitespace',
                'PSUseConsistentIndentation',
                'PSAvoidTrailingWhitespace',
                'PSAvoidSemicolonsAsLineTerminators',
                'PSUseCorrectCasing',
                'PSAlignAssignmentStatement'
            )
            
            if ($Finding.RuleName -in $autoFixableRules) {
                $labels += 'auto-fixable'
            } else {
                $labels += 'manual-review'
            }
            
            # Determine milestone based on priority and module
            $milestone = Get-MilestoneForIssue -Priority $issuePriority -ModulePath $relativePath -Severity $Finding.Severity
            
            if ($DryRun) {
                $issuePreview = @{
                    Title = $issueTitle
                    Body = $issueBody
                    Labels = $labels
                    Assignees = $assignees
                    Milestone = $milestone
                    Finding = $Finding
                    Priority = $issuePriority
                }
                
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'INFO' -Message "DRY RUN: Would create issue '$issueTitle' with labels: $($labels -join ', '), milestone: $milestone"
                } else {
                    Write-Host "DRY RUN: Would create issue '$issueTitle'" -ForegroundColor Yellow
                    Write-Host "  Labels: $($labels -join ', ')" -ForegroundColor Gray
                    Write-Host "  Assignees: $($assignees -join ', ')" -ForegroundColor Gray
                    Write-Host "  Milestone: $milestone" -ForegroundColor Gray
                }
                
                $createdIssues += $issuePreview
            } else {
                # Create the actual GitHub issue
                $createArgs = @(
                    'issue', 'create',
                    '--title', $issueTitle,
                    '--body', $issueBody,
                    '--label', ($labels -join ',')
                )
                
                if ($assignees.Count -gt 0) {
                    $createArgs += '--assignee'
                    $createArgs += ($assignees -join ',')
                }
                
                if ($milestone) {
                    $createArgs += '--milestone'
                    $createArgs += $milestone
                }
                
                try {
                    $issueResult = & gh @createArgs
                    $issueNumber = if ($issueResult -match '#(\d+)') { $matches[1] } else { 'unknown' }
                    
                    $createdIssue = @{
                        Number = $issueNumber
                        Title = $issueTitle
                        Labels = $labels
                        Assignees = $assignees
                        Milestone = $milestone
                        Finding = $Finding
                        Priority = $issuePriority
                        URL = "https://github.com/$RepositoryOwner/$RepositoryName/issues/$issueNumber"
                    }
                    
                    $createdIssues += $createdIssue
                    
                    if ($script:UseCustomLogging) {
                        Write-CustomLog -Level 'SUCCESS' -Message "Created GitHub issue #$issueNumber for $($Finding.RuleName) in $fileName"
                    } else {
                        Write-Host "✅ Created issue #$issueNumber: $issueTitle" -ForegroundColor Green
                    }
                }
                catch {
                    $error = "Failed to create GitHub issue for $($Finding.RuleName) in $fileName: $($_.Exception.Message)"
                    $errors += $error
                    
                    if ($script:UseCustomLogging) {
                        Write-CustomLog -Level 'ERROR' -Message $error
                    } else {
                        Write-Error $error
                    }
                }
            }
        }
        catch {
            $error = "Error processing finding $($Finding.RuleName): $($_.Exception.Message)"
            $errors += $error
            
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'ERROR' -Message $error
            } else {
                Write-Error $error
            }
        }
    }
    
    end {
        # Return summary
        $summary = @{
            CreatedIssues = $createdIssues
            SkippedIssues = $skippedIssues
            Errors = $errors
            TotalProcessed = $createdIssues.Count + $skippedIssues.Count + $errors.Count
            Repository = "$RepositoryOwner/$RepositoryName"
            DryRun = $DryRun.IsPresent
        }
        
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'INFO' -Message "GitHub Issues creation completed: $($createdIssues.Count) created, $($skippedIssues.Count) skipped, $($errors.Count) errors"
        } else {
            Write-Host "`n📊 GitHub Issues Summary:" -ForegroundColor Cyan
            Write-Host "  Created: $($createdIssues.Count)" -ForegroundColor Green
            Write-Host "  Skipped: $($skippedIssues.Count)" -ForegroundColor Yellow
            Write-Host "  Errors: $($errors.Count)" -ForegroundColor Red
            Write-Host "  Total Processed: $($summary.TotalProcessed)" -ForegroundColor White
        }
        
        return $summary
    }
}

function Get-IssueBodyForFinding {
    <#
    .SYNOPSIS
        Generates appropriate issue body content for a PSScriptAnalyzer finding
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Finding,
        
        [Parameter(Mandatory = $false)]
        [string]$Priority = 'medium'
    )
    
    $relativePath = $Finding.ScriptPath -replace [regex]::Escape($script:ProjectRoot), '' -replace '^[\\\/]', ''
    $fileName = Split-Path $Finding.ScriptPath -Leaf
    $moduleContext = if ($relativePath -match 'aither-core[/\\]modules[/\\]([^/\\]+)') { $matches[1] } else { 'Unknown' }
    
    # Read code snippet around the finding
    $codeSnippet = ""
    try {
        if (Test-Path $Finding.ScriptPath) {
            $lines = Get-Content $Finding.ScriptPath
            $startLine = [math]::Max(1, $Finding.Line - 3)
            $endLine = [math]::Min($lines.Count, $Finding.Line + 3)
            $snippetLines = $lines[($startLine-1)..($endLine-1)]
            $codeSnippet = $snippetLines -join "`n"
        }
    }
    catch {
        $codeSnippet = "Unable to read code snippet"
    }
    
    # Generate context information
    $analysisContext = @{
        analysisDate = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
        moduleContext = $moduleContext
        fileName = $fileName
        ruleName = $Finding.RuleName
        severity = $Finding.Severity
        line = $Finding.Line
        column = $Finding.Column
        priority = $Priority
    } | ConvertTo-Json -Compress
    
    # Generate issue body
    $body = @"
## $($Finding.Severity) Level PSScriptAnalyzer Finding

**Rule:** $($Finding.RuleName)
**File:** $relativePath
**Location:** Line $($Finding.Line), Column $($Finding.Column)
**Module:** $moduleContext
**Priority:** $Priority

### Message
$($Finding.Message)

### Code Context
```powershell
$codeSnippet
```

### Analysis Details
- **Severity:** $($Finding.Severity)
- **Rule Category:** $(if ($Finding.RuleName -match '^PSAvoid') { 'Avoidance' } elseif ($Finding.RuleName -match '^PSUse') { 'Usage' } else { 'General' })
- **Auto-fixable:** $(if ($Finding.RuleName -in @('PSAvoidUsingCmdletAliases', 'PSUseConsistentWhitespace', 'PSAvoidTrailingWhitespace')) { 'Yes' } else { 'Manual review required' })

### Suggested Actions
$(switch ($Finding.Severity) {
    'Error' { "🔴 **CRITICAL**: This error must be resolved before merging. Error-level findings can break functionality or introduce security vulnerabilities." }
    'Warning' { "⚠️ **IMPORTANT**: This warning should be addressed. It may indicate a best practice violation or potential issue." }
    'Information' { "ℹ️ **IMPROVEMENT**: This suggestion can improve code quality when time permits." }
})

### Context Information
```json
$analysisContext
```

---
*This issue was automatically created by PSScriptAnalyzerIntegration. It will be automatically updated when the finding status changes.*
"@
    
    return $body
}

function Get-CategoryLabelsForRule {
    <#
    .SYNOPSIS
        Determines category-based labels for PSScriptAnalyzer rules
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuleName
    )
    
    $categoryLabels = @()
    
    # Style and formatting rules
    $styleRules = @(
        'PSUseConsistentWhitespace',
        'PSUseConsistentIndentation', 
        'PSAvoidTrailingWhitespace',
        'PSAlignAssignmentStatement',
        'PSAvoidSemicolonsAsLineTerminators',
        'PSUseCorrectCasing',
        'PSAvoidUsingCmdletAliases'
    )
    
    # Best practices rules
    $bestPracticeRules = @(
        'PSProvideCommentHelp',
        'PSAvoidUsingWriteHost',
        'PSAvoidGlobalVars',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSAvoidUsingEmptyCatchBlock',
        'PSUseCmdletCorrectly',
        'PSUseSingularNouns',
        'PSUseApprovedVerbs'
    )
    
    # Security rules
    $securityRules = @(
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingUsernameAndPasswordParams',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSUsePSCredentialType',
        'PSAvoidHardcodedCredentials',
        'PSAvoidUsingInvokeExpression'
    )
    
    # Performance rules
    $performanceRules = @(
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidUsingPositionalParameters',
        'PSReservedCmdletChar',
        'PSReservedParams'
    )
    
    # Compatibility rules
    $compatibilityRules = @(
        'PSUseCompatibleCmdlets',
        'PSUseCompatibleSyntax',
        'PSUseCompatibleCommands'
    )
    
    if ($RuleName -in $styleRules) {
        $categoryLabels += 'style'
    }
    
    if ($RuleName -in $bestPracticeRules) {
        $categoryLabels += 'best-practice'
    }
    
    if ($RuleName -in $securityRules) {
        $categoryLabels += 'security-related'
    }
    
    if ($RuleName -in $performanceRules) {
        $categoryLabels += 'performance'
    }
    
    if ($RuleName -in $compatibilityRules) {
        $categoryLabels += 'compatibility'
    }
    
    # Add rule pattern-based categories
    if ($RuleName -match '^PSAvoid') {
        $categoryLabels += 'avoidance'
    } elseif ($RuleName -match '^PSUse') {
        $categoryLabels += 'usage'
    } elseif ($RuleName -match '^PSProvide') {
        $categoryLabels += 'documentation'
    }
    
    # Ensure we have at least one category
    if ($categoryLabels.Count -eq 0) {
        $categoryLabels += 'general'
    }
    
    return $categoryLabels
}

function Get-MilestoneForIssue {
    <#
    .SYNOPSIS
        Determines appropriate milestone for PSScriptAnalyzer issues
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Priority,
        
        [Parameter(Mandatory = $true)]
        [string]$ModulePath,
        
        [Parameter(Mandatory = $true)]
        [string]$Severity
    )
    
    # Priority-based milestones
    switch ($Priority) {
        'critical' {
            return 'Code Quality - Critical'
        }
        'high' {
            if ($Severity -eq 'Error') {
                return 'Code Quality - Critical'
            } else {
                return 'Code Quality - High Priority'
            }
        }
        'medium' {
            # Check if it's in a core module
            $coreModules = @(
                'ModuleCommunication',
                'TestingFramework', 
                'PatchManager',
                'SecureCredentials',
                'Logging',
                'ParallelExecution'
            )
            
            $isCore = $coreModules | Where-Object { $ModulePath -match $_ }
            
            if ($isCore) {
                return 'Code Quality - High Priority'
            } else {
                return 'Code Quality - Standard'
            }
        }
        'low' {
            return 'Code Quality - Standard'
        }
        default {
            return 'Code Quality - Standard'
        }
    }
}