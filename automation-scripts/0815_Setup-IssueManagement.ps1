#Requires -Version 7.0

<#
.SYNOPSIS
    Setup comprehensive issue management and change control
.DESCRIPTION
    Configures automated issue creation from test failures, change impact analysis,
    automated PR descriptions, and release note generation for comprehensive
    change management and auditing.

    Exit Codes:
    0   - Issue management configured successfully
    1   - Configuration failed
    2   - Setup error

.NOTES
    Stage: Issue Management
    Order: 0815
    Dependencies: 0800, 0700
    Tags: issues, change-management, automation, github
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$EnableAutoIssues,
    [switch]$EnableChangeTracking,
    [switch]$EnableReleaseNotes,
    [switch]$TestMode,
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Issue Management'
    Order = 0815
    Dependencies = @('0800', '0700')
    Tags = @('issues', 'change-management', 'automation')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

# Import modules
$projectRoot = Split-Path $PSScriptRoot -Parent
$loggingModule = Join-Path $projectRoot "domains/core/Logging.psm1"
$configModule = Join-Path $projectRoot "domains/configuration/Configuration.psm1"

if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
}

if (Test-Path $configModule) {
    Import-Module $configModule -Force
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0815_Setup-IssueManagement" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] $Message"
    }
}

function New-IssueTemplate {
    param(
        [string]$Type,
        [string]$OutputPath
    )

    $templates = @{
        'bug' = @"
---
name: Bug Report
about: Create a report to help us improve
title: '[BUG] '
labels: 'bug'
assignees: ''
---

## Bug Description
A clear and concise description of what the bug is.

## To Reproduce
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

## Expected Behavior
A clear and concise description of what you expected to happen.

## Screenshots
If applicable, add screenshots to help explain your problem.

## Environment Information
- OS: [e.g. Windows 10, Ubuntu 20.04]
- PowerShell Version: [e.g. 7.3.0]
- AitherZero Version: [e.g. 1.0.0]

## Additional Context
Add any other context about the problem here.

## Automated Information
<!-- This section is filled by automation -->
- Test Suite: {{ TEST_SUITE }}
- Test File: {{ TEST_FILE }}
- Error Message: {{ ERROR_MESSAGE }}
- Stack Trace: {{ STACK_TRACE }}
- CI Run: {{ CI_RUN_URL }}
"@

        'feature' = @"
---
name: Feature Request
about: Suggest an idea for this project
title: '[FEATURE] '
labels: 'enhancement'
assignees: ''
---

## Is your feature request related to a problem?
A clear and concise description of what the problem is. Ex. I'm always frustrated when [...]

## Describe the solution you'd like
A clear and concise description of what you want to happen.

## Describe alternatives you've considered
A clear and concise description of any alternative solutions or features you've considered.

## Additional context
Add any other context or screenshots about the feature request here.

## Implementation Notes
- [ ] Requires new automation scripts
- [ ] Requires configuration changes
- [ ] Requires documentation updates
- [ ] Requires tests
"@

        'task' = @"
---
name: Task
about: Track work items and improvements
title: '[TASK] '
labels: 'task'
assignees: ''
---

## Task Description
Clear description of what needs to be done.

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Technical Requirements
- [ ] Code changes required
- [ ] Tests need to be added/updated
- [ ] Documentation needs update
- [ ] Configuration changes needed

## Priority
- [ ] High
- [ ] Medium
- [ ] Low

## Estimated Effort
- [ ] Small (< 2 hours)
- [ ] Medium (2-8 hours)
- [ ] Large (> 8 hours)
"@
    }

    $template = $templates[$Type]
    if ($template) {
        $templatePath = Join-Path $OutputPath "$Type.md"
        if ($PSCmdlet.ShouldProcess($templatePath, "Create issue template")) {
            $template | Set-Content -Path $templatePath
            Write-ScriptLog -Message "Created issue template: $templatePath"
        }
    }
}

function New-AutoIssueScript {
    Write-ScriptLog -Message "Creating automated issue creation script"

    $autoIssueScript = @'
#!/usr/bin/env pwsh
# Automated issue creation from test failures

param(
    [string]$TestResultsPath,
    [string]$Repository,
    [switch]$DryRun
)

function New-IssueFromTestFailure {
    param(
        [string]$TestName,
        [string]$ErrorMessage,
        [string]$TestFile,
        [string]$StackTrace = "",
        [string]$CIRunUrl = ""
    )

    $issueTitle = "[AUTO] Test Failure: $TestName"
    $issueBody = @"
## Automated Issue from Test Failure

**Test Name:** $TestName
**Test File:** $TestFile
**Status:** Failed
**Created:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')

### Error Message
```
$ErrorMessage
```

### Stack Trace
```
$StackTrace
```

### CI Information
- **Run URL:** $CIRunUrl
- **Repository:** $Repository
- **Branch:** $env:GITHUB_REF_NAME
- **Commit:** $env:GITHUB_SHA

### Next Steps
- [ ] Investigate root cause
- [ ] Fix the failing test
- [ ] Verify fix with test run
- [ ] Close this issue

**Note:** This issue was created automatically from CI/CD pipeline.
"@

    if ($DryRun) {
        Write-Host "Would create issue:"
        Write-Host "Title: $issueTitle"
        Write-Host "Body: $issueBody"
    } else {
        # Create issue using GitHub CLI
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            $tempFile = New-TemporaryFile
            $issueBody | Set-Content $tempFile.FullName

            gh issue create --title $issueTitle --body-file $tempFile.FullName --label "bug,automated,test-failure"

            Remove-Item $tempFile.FullName -Force
            Write-Host "Created issue: $issueTitle"
        } else {
            Write-Warning "GitHub CLI not available - cannot create issue"
        }
    }
}

# Parse test results and create issues
if (Test-Path $TestResultsPath) {
    Write-Host "Processing test results from: $TestResultsPath"

    # Look for JUnit XML or other test result formats
    $testFiles = Get-ChildItem -Path $TestResultsPath -Filter "*.xml" -Recurse

    foreach ($testFile in $testFiles) {
        try {
            [xml]$testXml = Get-Content $testFile.FullName

            # Process failed tests (JUnit format)
            $failedTests = $testXml.SelectNodes("//testcase[failure or error]")

            foreach ($test in $failedTests) {
                $testName = $test.name
                $className = $test.classname
                $failure = $test.failure
                $error = $test.error

                $errorMessage = if ($failure) { $failure.message } elseif ($error) { $error.message } else { "Unknown error" }
                $stackTrace = if ($failure) { $failure.InnerText } elseif ($error) { $error.InnerText } else { "" }

                New-IssueFromTestFailure -TestName "$className.$testName" -ErrorMessage $errorMessage -TestFile $testFile.Name -StackTrace $stackTrace -CIRunUrl $env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID
            }
        } catch {
            Write-Warning "Failed to process test file $($testFile.Name): $_"
        }
    }
} else {
    Write-Warning "Test results path not found: $TestResultsPath"
}
'@

    $scriptPath = Join-Path $projectRoot "tools/create-issues-from-tests.ps1"

    if ($PSCmdlet.ShouldProcess($scriptPath, "Create auto-issue script")) {
        $autoIssueScript | Set-Content -Path $scriptPath
        Write-ScriptLog -Message "Auto-issue script created: $scriptPath"
    }
}

function New-ChangeImpactAnalysis {
    Write-ScriptLog -Message "Creating change impact analysis script"

    $analysisScript = @'
#!/usr/bin/env pwsh
# Change impact analysis for pull requests

param(
    [string]$BaseBranch = "main",
    [string]$HeadBranch = "HEAD",
    [switch]$OutputJson
)

function Get-ChangedFiles {
    param($Base, $Head)

    $changedFiles = @(git diff --name-only $Base...$Head)

    $analysis = @{
        TotalFiles = $changedFiles.Count
        FileTypes = @{}
        ImpactAreas = @()
        RiskLevel = "Low"
    }

    foreach ($file in $changedFiles) {
        $extension = [System.IO.Path]::GetExtension($file)
        if ($analysis.FileTypes.ContainsKey($extension)) {
            $analysis.FileTypes[$extension]++
        } else {
            $analysis.FileTypes[$extension] = 1
        }

        # Analyze impact areas
        switch -Regex ($file) {
            '^domains/configuration' { $analysis.ImpactAreas += "Configuration" }
            '^domains/infrastructure' { $analysis.ImpactAreas += "Infrastructure" }
            '^domains/infrastructure/Infrastructure.psm1' { $analysis.ImpactAreas += "Security" }
            '^automation-scripts' { $analysis.ImpactAreas += "Automation" }
            '^\.github/workflows' { $analysis.ImpactAreas += "CI/CD" }
            '\.Tests\.ps1$' { $analysis.ImpactAreas += "Testing" }
            'config\.psd1$' { $analysis.ImpactAreas += "Configuration"; $analysis.RiskLevel = "Medium" }
            'bootstrap\.(ps1|sh)$' { $analysis.RiskLevel = "High" }
        }
    }

    # Remove duplicates and assess overall risk
    $analysis.ImpactAreas = @($analysis.ImpactAreas | Sort-Object -Unique)

    if ($analysis.ImpactAreas -contains "Security" -or $analysis.ImpactAreas -contains "Infrastructure") {
        $analysis.RiskLevel = "High"
    } elseif ($analysis.ImpactAreas.Count -gt 3) {
        $analysis.RiskLevel = "Medium"
    }

    return $analysis
}

function New-PRDescription {
    param($Analysis)

    $description = @"
## Change Impact Analysis

### Files Changed
- **Total Files:** $($Analysis.TotalFiles)
- **Risk Level:** $($Analysis.RiskLevel)

### Impact Areas
$($Analysis.ImpactAreas | ForEach-Object { "- $_" } | Join-String -Separator "`n")

### File Types
$($Analysis.FileTypes.Keys | ForEach-Object { "- $_`: $($Analysis.FileTypes[$_])" } | Join-String -Separator "`n")

### Review Checklist
- [ ] Code follows project standards
- [ ] Tests are included for new functionality
- [ ] Documentation is updated
- [ ] Security implications reviewed
- [ ] Breaking changes documented
- [ ] CI/CD pipeline passes

### Testing Strategy
Based on the impact areas, the following tests should be prioritized:
$($Analysis.ImpactAreas | ForEach-Object {
    switch ($_) {
        "Configuration" { "- [ ] Configuration loading and validation tests" }
        "Infrastructure" { "- [ ] Infrastructure deployment tests" }
        "Security" { "- [ ] Security and permissions tests" }
        "Automation" { "- [ ] Automation script execution tests" }
        "CI/CD" { "- [ ] Pipeline and workflow tests" }
        "Testing" { "- [ ] Test framework and coverage validation" }
    }
} | Join-String -Separator "`n")

*This analysis was generated automatically based on changed files.*
"@

    return $description
}

# Perform analysis
$analysis = Get-ChangedFiles -Base $BaseBranch -Head $HeadBranch

if ($OutputJson) {
    $analysis | ConvertTo-Json -Depth 10
} else {
    $description = New-PRDescription -Analysis $analysis
    Write-Host $description
}
'@

    $scriptPath = Join-Path $projectRoot "tools/analyze-change-impact.ps1"

    if ($PSCmdlet.ShouldProcess($scriptPath, "Create change impact analysis script")) {
        $analysisScript | Set-Content -Path $scriptPath
        Write-ScriptLog -Message "Change impact analysis script created: $scriptPath"
    }
}

function New-ReleaseNotesGenerator {
    Write-ScriptLog -Message "Creating release notes generator"

    $generatorScript = @'
#!/usr/bin/env pwsh
# Automated release notes generation

param(
    [string]$FromTag,
    [string]$ToTag = "HEAD",
    [string]$OutputFormat = "markdown"
)

function Get-CommitsSinceTag {
    param($From, $To)

    $commits = @()
    $gitLog = git log "$From..$To" --pretty=format:"%H|%s|%an|%ad" --date=short

    foreach ($line in $gitLog) {
        $parts = $line -split '\|', 4
        if ($parts.Count -eq 4) {
            $commits += @{
                Hash = $parts[0]
                Subject = $parts[1]
                Author = $parts[2]
                Date = $parts[3]
                Type = Get-CommitType -Subject $parts[1]
            }
        }
    }

    return $commits
}

function Get-CommitType {
    param([string]$Subject)

    switch -Regex ($Subject) {
        '^feat(\(.*\))?:' { return "Features" }
        '^fix(\(.*\))?:' { return "Bug Fixes" }
        '^docs(\(.*\))?:' { return "Documentation" }
        '^style(\(.*\))?:' { return "Style" }
        '^refactor(\(.*\))?:' { return "Refactoring" }
        '^perf(\(.*\))?:' { return "Performance" }
        '^test(\(.*\))?:' { return "Tests" }
        '^chore(\(.*\))?:' { return "Chores" }
        '^ci(\(.*\))?:' { return "CI/CD" }
        '^build(\(.*\))?:' { return "Build" }
        default { return "Other" }
    }
}

function New-MarkdownReleaseNotes {
    param($Commits, $FromTag, $ToTag)

    $groupedCommits = $Commits | Group-Object Type
    $date = Get-Date -Format "yyyy-MM-dd"

    $notes = @"
# Release Notes - $ToTag

**Release Date:** $date
**Previous Version:** $FromTag

"@

    foreach ($group in $groupedCommits) {
        $notes += "`n## $($group.Name)`n`n"
        foreach ($commit in $group.Group) {
            $notes += "- $($commit.Subject) ($(($commit.Hash).Substring(0,7)))`n"
        }
    }

    $notes += @"

## Contributors

$($Commits | Select-Object -ExpandProperty Author -Unique | ForEach-Object { "- $_" } | Join-String -Separator "`n")

## Statistics

- **Total Commits:** $($Commits.Count)
- **Contributors:** $($Commits | Select-Object -ExpandProperty Author -Unique | Measure-Object).Count
- **Files Changed:** $(git diff --name-only $FromTag..$ToTag | Measure-Object).Count

---
*Generated automatically by AitherZero CI/CD Pipeline*
"@

    return $notes
}

# Generate release notes
if (-not $FromTag) {
    # Get the previous tag
    $FromTag = git describe --tags --abbrev=0 HEAD^ 2>$null
    if (-not $FromTag) {
        $FromTag = "HEAD~20"  # Fallback to last 20 commits
    }
}

$commits = Get-CommitsSinceTag -From $FromTag -To $ToTag

switch ($OutputFormat.ToLower()) {
    "json" {
        @{
            FromTag = $FromTag
            ToTag = $ToTag
            Commits = $commits
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        } | ConvertTo-Json -Depth 10
    }
    default {
        New-MarkdownReleaseNotes -Commits $commits -FromTag $FromTag -ToTag $ToTag
    }
}
'@

    $scriptPath = Join-Path $projectRoot "tools/generate-release-notes.ps1"

    if ($PSCmdlet.ShouldProcess($scriptPath, "Create release notes generator")) {
        $generatorScript | Set-Content -Path $scriptPath
        Write-ScriptLog -Message "Release notes generator created: $scriptPath"
    }
}

function New-IssueManagementConfig {
    Write-ScriptLog -Message "Creating issue management configuration"

    $config = @{
        AutoIssueCreation = @{
            Enabled = $EnableAutoIssues
            TestFailureThreshold = 3
            IgnorePatterns = @('*.tmp', 'test-*')
            Labels = @('bug', 'automated', 'test-failure')
            AssignToAuthor = $true
        }
        ChangeTracking = @{
            Enabled = $EnableChangeTracking
            RequireApproval = $true
            HighRiskPaths = @(
                'bootstrap.*',
                'config.psd1',
                'domains/infrastructure/Infrastructure.psm1/*',
                'domains/infrastructure/*'
            )
            ReviewerGroups = @{
                Security = @('security-team')
                Infrastructure = @('infra-team')
                Configuration = @('config-team')
            }
        }
        ReleaseNotes = @{
            Enabled = $EnableReleaseNotes
            AutoGenerate = $true
            IncludeContributors = $true
            IncludeStatistics = $true
            CommitConventions = $true
        }
        Notifications = @{
            Slack = @{
                Enabled = $false
                WebhookUrl = '$env:SLACK_WEBHOOK_URL'
                Channels = @{
                    Issues = '#issues'
                    Releases = '#releases'
                    Changes = '#changes'
                }
            }
            Email = @{
                Enabled = $false
                SmtpServer = 'smtp.company.com'
                Recipients = @('team@company.com')
            }
        }
    }

    $configPath = if ($ConfigPath) { $ConfigPath } else { Join-Path $projectRoot "config/issue-management.json" }

    # Ensure config directory exists
    $configDir = Split-Path $configPath -Parent
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    if ($PSCmdlet.ShouldProcess($configPath, "Create issue management configuration")) {
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
        Write-ScriptLog -Message "Issue management configuration created: $configPath"
    }
}

try {
    Write-ScriptLog -Message "Starting issue management setup"

    # Create .github/ISSUE_TEMPLATE directory
    $templateDir = Join-Path $projectRoot ".github/ISSUE_TEMPLATE"
    if (-not (Test-Path $templateDir)) {
        New-Item -ItemType Directory -Path $templateDir -Force | Out-Null
    }

    # Create issue templates
    New-IssueTemplate -Type "bug" -OutputPath $templateDir
    New-IssueTemplate -Type "feature" -OutputPath $templateDir
    New-IssueTemplate -Type "task" -OutputPath $templateDir

    # Create tools directory
    $toolsDir = Join-Path $projectRoot "tools"
    if (-not (Test-Path $toolsDir)) {
        New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    }

    # Create automation scripts
    New-AutoIssueScript
    New-ChangeImpactAnalysis
    New-ReleaseNotesGenerator

    # Create configuration
    New-IssueManagementConfig

    # Test mode - validate all scripts
    if ($TestMode) {
        Write-Host "`nValidating created scripts..." -ForegroundColor Cyan

        $scripts = @(
            Join-Path $projectRoot "tools/create-issues-from-tests.ps1"
            Join-Path $projectRoot "tools/analyze-change-impact.ps1"
            Join-Path $projectRoot "tools/generate-release-notes.ps1"
        )

        foreach ($script in $scripts) {
            if (Test-Path $script) {
                try {
                    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script -Raw), [ref]$null)
                    Write-Host "✅ $script - Syntax OK" -ForegroundColor Green
                } catch {
                    Write-Host "❌ $script - Syntax Error: $_" -ForegroundColor Red
                }
            }
        }
    }

    # Create GitHub Actions workflow integration
    $workflowIntegration = @'
# Add this to your GitHub Actions workflow for full issue management integration

      - name: Create Issues from Test Failures
        if: failure() && github.event_name == 'push'
        shell: pwsh
        run: |
          ./tools/create-issues-from-tests.ps1 -TestResultsPath ./test-results -Repository ${{ github.repository }}

      - name: Generate Change Impact Analysis
        if: github.event_name == 'pull_request'
        shell: pwsh
        run: |
          $analysis = ./tools/analyze-change-impact.ps1 -OutputJson | ConvertFrom-Json
          echo "CHANGE_IMPACT<<EOF" >> $env:GITHUB_ENV
          ./tools/analyze-change-impact.ps1 >> $env:GITHUB_ENV
          echo "EOF" >> $env:GITHUB_ENV

      - name: Update PR Description
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const body = process.env.CHANGE_IMPACT;
            github.rest.pulls.update({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.issue.number,
              body: body
            });

      - name: Generate Release Notes
        if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/')
        shell: pwsh
        run: |
          $releaseNotes = ./tools/generate-release-notes.ps1
          echo "RELEASE_NOTES<<EOF" >> $env:GITHUB_ENV
          echo $releaseNotes >> $env:GITHUB_ENV
          echo "EOF" >> $env:GITHUB_ENV
'@

    $integrationPath = Join-Path $projectRoot "docs/github-actions-integration.yml"
    if ($PSCmdlet.ShouldProcess($integrationPath, "Create workflow integration guide")) {
        $workflowIntegration | Set-Content -Path $integrationPath
        Write-ScriptLog -Message "Workflow integration guide created: $integrationPath"
    }

    # Summary
    Write-Host "`nIssue Management Setup Complete!" -ForegroundColor Green
    Write-Host "✅ Issue templates created" -ForegroundColor Green
    Write-Host "✅ Automation scripts generated" -ForegroundColor Green
    Write-Host "✅ Configuration files created" -ForegroundColor Green
    Write-Host "✅ GitHub Actions integration provided" -ForegroundColor Green

    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "1. Review and customize issue templates in .github/ISSUE_TEMPLATE/" -ForegroundColor White
    Write-Host "2. Configure settings in config/issue-management.json" -ForegroundColor White
    Write-Host "3. Integrate with GitHub Actions using docs/github-actions-integration.yml" -ForegroundColor White
    Write-Host "4. Test with: ./automation-scripts/0815_Setup-IssueManagement.ps1 -TestMode" -ForegroundColor White

    Write-ScriptLog -Message "Issue management setup completed successfully"
    exit 0

} catch {
    $errorMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    Write-ScriptLog -Level Error -Message "Issue management setup failed: $_" -Data @{ Exception = $errorMsg }
    exit 1
}
