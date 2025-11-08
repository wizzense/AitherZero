#Requires -Version 7.0

<#
.SYNOPSIS
    Validate component quality for new features and components
.DESCRIPTION
    Comprehensive quality validation tool that checks:
    - Error handling implementation
    - Logging implementation
    - Test coverage
    - UI/CLI integration
    - GitHub Actions integration
    - PSScriptAnalyzer compliance
    - Documentation completeness

    This script is part of the AitherZero quality assurance framework and should
    be run on all new features and components before merging.
    
    Note: PowerShell data files (.psd1) are automatically detected and only
    validated for syntax (PSScriptAnalyzer). They do not require error handling,
    logging, or test coverage as they are pure data files.

    Exit Codes:
    0   - All quality checks passed
    1   - Quality checks failed
    2   - Execution error

.PARAMETER Path
    Path to the script or module file to validate. Can be a file or directory.
    If directory, validates all PowerShell files within it.
.PARAMETER Recursive
    When Path is a directory, recursively validate all PowerShell files
.PARAMETER SkipChecks
    Array of check names to skip: ErrorHandling, Logging, TestCoverage,
    UIIntegration, GitHubActions, PSScriptAnalyzer
.PARAMETER ExcludeDataFiles
    Exclude PowerShell data files (.psd1) from validation entirely
.PARAMETER OutputPath
    Path to save the quality report (default: ./reports/quality)
.PARAMETER Format
    Output format: Text, HTML, JSON (default: Text)
.PARAMETER FailOnWarnings
    Fail the validation if warnings are found (not just failures)
.PARAMETER MinimumScore
    Minimum overall score required to pass (0-100, default: 70)
.PARAMETER DryRun
    Show what would be validated without running checks
.PARAMETER CreateIssues
    Force creation of GitHub issues for failed validations (requires gh CLI)
.PARAMETER NoIssueCreation
    Disable automatic issue creation even if configured in config.psd1
.EXAMPLE
    ./0420_Validate-ComponentQuality.ps1 -Path ./aithercore/testing/NewModule.psm1
    Validate a single module file
.EXAMPLE
    ./0420_Validate-ComponentQuality.ps1 -Path ./domains/testing -Recursive
    Validate all PowerShell files in the testing domain
.EXAMPLE
    ./0420_Validate-ComponentQuality.ps1 -Path ./automation-scripts/0500_NewScript.ps1 -Format HTML
    Validate a script and generate HTML report
.EXAMPLE
    ./0420_Validate-ComponentQuality.ps1 -Path ./config -Recursive -ExcludeDataFiles
    Validate all scripts in config directory, but skip .psd1 data files
.EXAMPLE
    ./0420_Validate-ComponentQuality.ps1 -Path ./domains/testing -Recursive -CreateIssues
    Validate all files in testing domain and create GitHub issues for failures
.NOTES
    Stage: Testing
    Order: 0420
    Dependencies: 0400 (Testing tools installation), gh CLI (optional, for issue creation)
    Tags: testing, quality, validation, standards, automation
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Path,
    
    [switch]$Recursive,
    
    [string[]]$SkipChecks = @(),
    
    [switch]$ExcludeDataFiles,
    
    [string]$OutputPath,
    
    [ValidateSet('Text', 'HTML', 'JSON')]
    [string]$Format = 'Text',
    
    [switch]$FailOnWarnings,
    
    [int]$MinimumScore = 70,
    
    [switch]$DryRun,
    
    [switch]$CreateIssues,
    
    [switch]$NoIssueCreation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$script:ScriptName = '0420_Validate-ComponentQuality'
$script:StartTime = Get-Date

# Get project root
$projectRoot = Split-Path $PSScriptRoot -Parent
$env:AITHERZERO_ROOT = $projectRoot

# Import modules
$loggingModule = Join-Path $projectRoot "aithercore/utilities/Logging.psm1"
$qualityModule = Join-Path $projectRoot "aithercore/testing/QualityValidator.psm1"

if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $qualityModule)) {
    Write-Error "Quality validation module not found at: $qualityModule"
    exit 2
}

Import-Module $qualityModule -Force

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source $script:ScriptName -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

function Get-QualityRecommendation {
    <#
    .SYNOPSIS
        Get actionable recommendations for quality issues
    #>
    param(
        [string]$CheckName,
        [hashtable]$Details
    )
    
    try {
        switch ($CheckName) {
            'ErrorHandling' {
                if ($Details.ContainsKey('HasErrorActionPreference') -and $Details.HasErrorActionPreference -eq $false) {
                    return "Add at top of file: `$ErrorActionPreference = 'Stop'"
                } elseif ($Details.ContainsKey('TryCatchBlocks') -and $Details.TryCatchBlocks -eq 0) {
                    return "Wrap risky operations in try/catch blocks"
                }
            }
            'Logging' {
                if ($Details.ContainsKey('HasInfoLevel') -and $Details.HasInfoLevel -eq $false) {
                    return "Add Write-CustomLog calls for key operations and milestones"
                }
            }
            'TestCoverage' {
                if ($Details.ContainsKey('TestFileExists') -and $Details.TestFileExists -eq $false) {
                    # Get expected path from finding if available
                    return "Create unit test file for this component"
                }
            }
            'PSScriptAnalyzer' {
                if ($Details.ContainsKey('Errors') -and $Details.Errors -gt 0) {
                    return "Run: ./automation-scripts/0404_Run-PSScriptAnalyzer.ps1 -Path <file>"
                } elseif ($Details.ContainsKey('Warnings') -and $Details.Warnings -gt 0) {
                    return "Review warnings with: Invoke-ScriptAnalyzer -Path <file>"
                }
            }
        }
    } catch {
        # Silently ignore errors in recommendation generation
        Write-Verbose "Error getting recommendation for $CheckName : $_"
    }
    
    return $null
}

function Test-GitHubAuthentication {
    <#
    .SYNOPSIS
        Check if GitHub CLI is installed and authenticated
    .DESCRIPTION
        Validates that gh CLI is available and the user is authenticated.
        Returns $true if ready to create issues, $false otherwise.
        In GitHub Actions, checks for GITHUB_TOKEN or GH_TOKEN environment variables.
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Check if gh CLI is available
        $ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
        if (-not $ghAvailable) {
            Write-ScriptLog -Level Warning -Message "GitHub CLI (gh) is not installed. Install from: https://cli.github.com/"
            return $false
        }
        
        # In GitHub Actions, gh CLI can use GITHUB_TOKEN automatically
        # Check if we're in GitHub Actions with a token
        if ($env:GITHUB_ACTIONS -eq 'true') {
            if ($env:GITHUB_TOKEN -or $env:GH_TOKEN) {
                Write-ScriptLog -Level Debug -Message "GitHub Actions environment detected with token available"
                return $true
            } else {
                Write-ScriptLog -Level Warning -Message "GitHub Actions environment detected but no token available (GITHUB_TOKEN not set)"
                return $false
            }
        }
        
        # For non-GitHub Actions environments, check authentication status
        $authCheck = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ScriptLog -Level Warning -Message "GitHub CLI is not authenticated. Run: gh auth login"
            return $false
        }
        
        Write-ScriptLog -Level Debug -Message "GitHub CLI is authenticated and ready"
        return $true
        
    } catch {
        Write-ScriptLog -Level Warning -Message "Failed to check GitHub authentication: $_"
        return $false
    }
}

function New-QualityIssue {
    <#
    .SYNOPSIS
        Create a GitHub issue for quality validation failure
    #>
    param(
        [PSCustomObject]$Report,
        [string]$ReportPath
    )
    
    try {
        # Authentication should be checked by caller, but double-check here
        $ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
        if (-not $ghAvailable) {
            Write-ScriptLog -Level Warning -Message "GitHub CLI (gh) not available. Cannot create issues."
            return $null
        }
        
        # Determine priority based on score
        $priorityThresholds = @{
            Critical = 50
            High = 70
        }
        
        $priority = if ($Report.OverallScore -lt $priorityThresholds.Critical) { 'P2' }
                    elseif ($Report.OverallScore -lt $priorityThresholds.High) { 'P3' }
                    else { 'P4' }
        
        # Build issue title
        $issueTitle = "🔍 [Quality] $($Report.FileName) - Score: $($Report.OverallScore)%"
        
        # Build issue body
        $issueBody = @"
## Quality Validation Failure Report

**File**: ``$($Report.FilePath)``
**Overall Score**: $($Report.OverallScore)%
**Status**: $($Report.OverallStatus)
**Validation Date**: $($Report.Timestamp)

### Summary

This file failed quality validation checks. Review the findings below and address the issues.

"@
        
        # Add critical issues
        $criticalIssues = @($Report.Checks | Where-Object { $_.Status -eq 'Failed' })
        if ($criticalIssues.Count -gt 0) {
            $issueBody += "`n### 🔴 Critical Issues`n`n"
            foreach ($issue in $criticalIssues) {
                $issueBody += "#### $($issue.CheckName) (Score: $($issue.Score)%)`n`n"
                if ($issue.Findings) {
                    foreach ($finding in $issue.Findings) {
                        $issueBody += "- $finding`n"
                    }
                }
                
                # Add recommendation
                $recommendation = Get-QualityRecommendation -CheckName $issue.CheckName -Details $issue.Details
                if ($recommendation) {
                    $issueBody += "`n**💡 Recommendation:** $recommendation`n"
                }
                $issueBody += "`n"
            }
        }
        
        # Add warnings
        $warningIssues = @($Report.Checks | Where-Object { $_.Status -eq 'Warning' })
        if ($warningIssues.Count -gt 0) {
            $issueBody += "`n### 🟡 Warnings`n`n"
            foreach ($issue in $warningIssues) {
                $issueBody += "#### $($issue.CheckName) (Score: $($issue.Score)%)`n`n"
                if ($issue.Findings) {
                    foreach ($finding in $issue.Findings) {
                        $issueBody += "- $finding`n"
                    }
                }
                
                # Add recommendation
                $recommendation = Get-QualityRecommendation -CheckName $issue.CheckName -Details $issue.Details
                if ($recommendation) {
                    $issueBody += "`n**💡 Recommendation:** $recommendation`n"
                }
                $issueBody += "`n"
            }
        }
        
        # Add next steps
        $issueBody += @"

### 📋 Next Steps

1. Review the detailed quality report (attached as artifact)
2. Address the issues identified above
3. Run local validation: ``./automation-scripts/0420_Validate-ComponentQuality.ps1 -Path $($Report.FilePath)``
4. Re-run validation after fixes

### 🤖 Automated Processing

@copilot please review this file and address the quality issues identified above following AitherZero quality standards.

---

*This issue was automatically created by the Quality Validation System*
*Report: $ReportPath*
"@
        
        # Create the issue
        $labels = @('quality-validation', 'code-quality', 'copilot-task', $priority)
        
        # Build gh CLI arguments safely
        $ghArgs = @('issue', 'create', '--title', $issueTitle, '--body', $issueBody)
        foreach ($label in $labels) {
            $ghArgs += @('--label', $label)
        }
        
        # Execute gh command and capture output properly
        # gh issue create outputs the URL to the created issue on success
        # Note: Errors will go to stderr; we don't redirect to avoid log corruption
        try {
            $issueUrl = gh @ghArgs
            $exitCode = $LASTEXITCODE
        } catch {
            $exitCode = 1
            $issueUrl = $null
        }
        
        if ($exitCode -eq 0 -and $issueUrl) {
            # Extract issue number from URL (format: https://github.com/owner/repo/issues/123)
            if ($issueUrl -match '/issues/(\d+)') {
                $issueNumber = $Matches[1]
                Write-ScriptLog -Message "Created issue #$issueNumber for $($Report.FileName)" -Data @{
                    IssueNumber = $issueNumber
                    IssueUrl = $issueUrl
                }
                return @{
                    Number = $issueNumber
                    Url = $issueUrl
                    Success = $true
                }
            } else {
                Write-ScriptLog -Level Warning -Message "Issue created but could not parse issue number from: $issueUrl"
                return @{
                    Url = $issueUrl
                    Success = $true
                }
            }
        } else {
            # Log the failure without capturing stderr (which can corrupt logs)
            Write-ScriptLog -Level Warning -Message "GitHub issue creation failed for $($Report.FileName)" -Data @{
                ExitCode = $exitCode
            }
            return $null
        }
        
    } catch {
        Write-ScriptLog -Level Error -Message "Error creating quality issue: $_"
        return $null
    }
}

try {
    Write-ScriptLog -Message "Starting component quality validation"
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          Component Quality Validation System                ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Validate path
    if (-not (Test-Path $Path)) {
        Write-ScriptLog -Level Error -Message "Path not found: $Path"
        exit 2
    }
    
    # Determine files to validate
    $filesToValidate = @()
    
    if ((Get-Item $Path).PSIsContainer) {
        Write-ScriptLog -Message "Scanning directory: $Path"
        
        $scanParams = @{
            Path = $Path
            Filter = '*.ps*'
            File = $true
        }
        
        if ($Recursive) {
            $scanParams.Recurse = $true
        }
        
        $allFiles = Get-ChildItem @scanParams
        
        # Filter to only .ps1, .psm1, .psd1 files (case-insensitive)
        $filesToValidate = @($allFiles | Where-Object { 
            $_.Extension -imatch '\.(ps1|psm1|psd1)$' 
        } | Select-Object -ExpandProperty FullName)
        
        # Filter out .psd1 files if requested
        if ($ExcludeDataFiles) {
            $originalCount = $filesToValidate.Count
            $filesToValidate = @($filesToValidate | Where-Object { 
                [System.IO.Path]::GetExtension($_).ToLower() -ne '.psd1' 
            })
            $excludedCount = $originalCount - $filesToValidate.Count
            if ($excludedCount -gt 0) {
                Write-ScriptLog -Message "Excluded $excludedCount PowerShell data file(s) (.psd1)"
            }
        }
        
        if ($filesToValidate.Count -eq 0) {
            Write-ScriptLog -Level Warning -Message "No PowerShell files found in: $Path"
            exit 0
        }
        
        Write-ScriptLog -Message "Found $($filesToValidate.Count) PowerShell files to validate"
    } else {
        $filesToValidate = @($Path)
    }
    
    if ($DryRun) {
        Write-ScriptLog -Message "DRY RUN: Would validate the following files:"
        foreach ($file in $filesToValidate) {
            Write-Host "  - $file" -ForegroundColor Yellow
        }
        exit 0
    }
    
    # Run validation
    Write-Host "`n🔍 Validating $($filesToValidate.Count) file(s)...`n" -ForegroundColor Cyan
    
    $allReports = @()
    $overallStatus = 'Passed'
    $totalScore = 0
    $fileCount = 0
    
    foreach ($file in $filesToValidate) {
        if (-not $PSCmdlet.ShouldProcess($file, "Validate quality")) {
            continue
        }
        
        Write-Host "Validating: $(Split-Path $file -Leaf)" -ForegroundColor Yellow
        
        try {
            $report = Invoke-QualityValidation -Path $file -SkipChecks $SkipChecks
            $allReports += $report
            $totalScore += $report.OverallScore
            $fileCount++
            
            # Display summary
            $statusColor = @{
                'Passed' = 'Green'
                'Warning' = 'Yellow'
                'Failed' = 'Red'
            }[$report.OverallStatus]
            
            Write-Host "  Status: $($report.OverallStatus) | Score: $($report.OverallScore)%" -ForegroundColor $statusColor
            
            if ($report.OverallStatus -eq 'Failed') {
                $overallStatus = 'Failed'
            } elseif ($report.OverallStatus -eq 'Warning' -and $overallStatus -ne 'Failed') {
                $overallStatus = 'Warning'
            }
            
            # Show critical findings
            $criticalFindings = $report.Checks | Where-Object { $_.Status -eq 'Failed' }
            if ($criticalFindings) {
                foreach ($check in $criticalFindings) {
                    $findingsArray = @($check.Findings)
                    if ($findingsArray.Count -gt 0) {
                        Write-Host "    ❌ $($check.CheckName): $($findingsArray[0])" -ForegroundColor Red
                    }
                }
            }
            
            Write-Host ""
            
        } catch {
            Write-ScriptLog -Level Error -Message "Failed to validate $file : $_"
            $overallStatus = 'Failed'
        }
    }
    
    # Calculate average score
    $averageScore = if ($fileCount -gt 0) { [math]::Round($totalScore / $fileCount, 0) } else { 0 }
    
    # Display overall summary
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                  VALIDATION SUMMARY                          ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "Files Validated: $fileCount" -ForegroundColor White
    Write-Host "Average Score: $averageScore%" -ForegroundColor White
    Write-Host "Overall Status: $overallStatus" -ForegroundColor $(
        @{
            'Passed' = 'Green'
            'Warning' = 'Yellow'
            'Failed' = 'Red'
        }[$overallStatus]
    )
    
    # Count passed/failed/warnings
    $passedCount = @($allReports | Where-Object { $_.OverallStatus -eq 'Passed' }).Count
    $failedCount = @($allReports | Where-Object { $_.OverallStatus -eq 'Failed' }).Count
    $warningCount = @($allReports | Where-Object { $_.OverallStatus -eq 'Warning' }).Count
    
    Write-Host "`n✅ Passed: $passedCount" -ForegroundColor Green
    Write-Host "⚠️  Warnings: $warningCount" -ForegroundColor Yellow
    Write-Host "❌ Failed: $failedCount" -ForegroundColor Red
    
    # Display file-by-file breakdown with detailed findings
    if ($fileCount -gt 0) {
        Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                   FILE BREAKDOWN                             ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
        
        foreach ($report in $allReports) {
            $fileName = $report.FileName
            $status = $report.OverallStatus
            $score = $report.OverallScore
            
            $statusIcon = @{
                'Passed' = '✅'
                'Warning' = '⚠️ '
                'Failed' = '❌'
            }[$status]
            
            $statusColor = @{
                'Passed' = 'Green'
                'Warning' = 'Yellow'
                'Failed' = 'Red'
            }[$status]
            
            $statusBadge = if ($score -ge 90) { "[EXCELLENT]" } 
                          elseif ($score -ge 70) { "[GOOD]" } 
                          elseif ($score -ge 50) { "[NEEDS IMPROVEMENT]" }
                          else { "[NEEDS ATTENTION]" }
            
            Write-Host "$statusIcon $fileName" -ForegroundColor $statusColor -NoNewline
            Write-Host " - Score: $score% $statusBadge" -ForegroundColor White
            Write-Host "   Path: $($report.FilePath)" -ForegroundColor DarkGray
            
            # Show detailed issues for failed/warning files
            if ($status -in @('Failed', 'Warning')) {
                # Group issues by severity
                $criticalIssues = @($report.Checks | Where-Object { $_.Status -eq 'Failed' })
                $warningIssues = @($report.Checks | Where-Object { $_.Status -eq 'Warning' })
                
                if ($criticalIssues.Count -gt 0) {
                    Write-Host "`n   🔴 CRITICAL ISSUES:" -ForegroundColor Red
                    foreach ($issue in $criticalIssues) {
                        Write-Host "   • [$($issue.CheckName)]" -ForegroundColor Red -NoNewline
                        if ($issue.Findings -and $issue.Findings.Count -gt 0) {
                            $findingsArray = @($issue.Findings)
                            foreach ($finding in $findingsArray | Select-Object -First 3) {
                                Write-Host " $finding" -ForegroundColor Gray
                            }
                            
                            # Show recommendations based on check type
                            $recommendation = Get-QualityRecommendation -CheckName $issue.CheckName -Details $issue.Details
                            if ($recommendation) {
                                Write-Host "     → $recommendation" -ForegroundColor Cyan
                            }
                        } else {
                            Write-Host "" -ForegroundColor Gray
                        }
                    }
                }
                
                if ($warningIssues.Count -gt 0) {
                    Write-Host "`n   🟡 WARNINGS:" -ForegroundColor Yellow
                    foreach ($issue in $warningIssues) {
                        Write-Host "   • [$($issue.CheckName)]" -ForegroundColor Yellow -NoNewline
                        if ($issue.Findings -and $issue.Findings.Count -gt 0) {
                            $findingsArray = @($issue.Findings)
                            foreach ($finding in $findingsArray | Select-Object -First 3) {
                                Write-Host " $finding" -ForegroundColor Gray
                            }
                            
                            # Show recommendations
                            $recommendation = Get-QualityRecommendation -CheckName $issue.CheckName -Details $issue.Details
                            if ($recommendation) {
                                Write-Host "     → $recommendation" -ForegroundColor Cyan
                            }
                        } else {
                            Write-Host "" -ForegroundColor Gray
                        }
                    }
                }
                
                # Show PSScriptAnalyzer details if available
                $psaCheck = $report.Checks | Where-Object { $_.CheckName -eq 'PSScriptAnalyzer' -and $_.Status -in @('Failed', 'Warning') }
                if ($psaCheck -and $psaCheck.Details.TopIssues) {
                    Write-Host "`n   🟠 CODE QUALITY (PSScriptAnalyzer):" -ForegroundColor DarkYellow
                    foreach ($topIssue in $psaCheck.Details.TopIssues | Select-Object -First 5) {
                        Write-Host "     → $topIssue" -ForegroundColor Gray
                    }
                    if ($psaCheck.Details.TotalIssues -gt 5) {
                        Write-Host "     ... and $($psaCheck.Details.TotalIssues - 5) more issues" -ForegroundColor DarkGray
                    }
                }
            }
            
            Write-Host ""
        }
    }
    
    # Save reports
    if (-not $OutputPath) {
        $OutputPath = Join-Path $projectRoot "library/reports/quality"
    }
    
    if (-not (Test-Path $OutputPath)) {
        if ($PSCmdlet.ShouldProcess($OutputPath, "Create output directory")) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
    }
    
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $reportName = "quality-report-$timestamp"
    
    # Map format to correct file extension
    switch ($Format.ToUpper()) {
        'TEXT' { $fileExtension = 'txt' }
        'HTML' { $fileExtension = 'html' }
        'JSON' { $fileExtension = 'json' }
        default { $fileExtension = $Format.ToLower() }
    }
    
    foreach ($report in $allReports) {
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($report.FilePath)
        $reportPath = Join-Path $OutputPath "$reportName-$fileName.$fileExtension"
        
        if ($PSCmdlet.ShouldProcess($reportPath, "Save quality report")) {
            $formattedReport = Format-QualityReport -Report $report -Format $Format
            
            if ($Format -eq 'JSON') {
                $formattedReport | Set-Content -Path $reportPath
            } else {
                $formattedReport | Out-File -FilePath $reportPath -Encoding UTF8
            }
            
            Write-ScriptLog -Message "Report saved: $reportPath"
        }
        
        # Always save detailed JSON report for PR comments (in addition to requested format)
        if ($Format -ne 'JSON') {
            $jsonReportPath = Join-Path $OutputPath "$reportName-$fileName.json"
            if ($PSCmdlet.ShouldProcess($jsonReportPath, "Save detailed JSON report")) {
                $jsonReport = Format-QualityReport -Report $report -Format 'JSON'
                $jsonReport | Set-Content -Path $jsonReportPath
                Write-ScriptLog -Message "Detailed JSON report saved: $jsonReportPath"
            }
        }
    }
    
    # Create summary report
    $summaryPath = Join-Path $OutputPath "$reportName-summary.json"
    if ($PSCmdlet.ShouldProcess($summaryPath, "Save summary report")) {
        $summary = @{
            Timestamp = Get-Date
            FilesValidated = $fileCount
            AverageScore = $averageScore
            OverallStatus = $overallStatus
            Passed = $passedCount
            Failed = $failedCount
            Warnings = $warningCount
            Files = $allReports | ForEach-Object {
                @{
                    FilePath = $_.FilePath
                    Status = $_.OverallStatus
                    Score = $_.OverallScore
                }
            }
        } | ConvertTo-Json -Depth 5
        
        $summary | Set-Content -Path $summaryPath
        Write-ScriptLog -Message "Summary saved: $summaryPath"
    }
    
    Write-Host "`n📊 Reports saved to: $OutputPath" -ForegroundColor Cyan
    
    # Create GitHub issues if requested or configured
    $shouldCreateIssues = $false
    
    # Check configuration
    $config = $null
    try {
        $config = Get-Configuration -ErrorAction SilentlyContinue
        if ($config -and $config.ContainsKey('AutomatedIssueManagement')) {
            $autoManagement = $config.AutomatedIssueManagement
            if ($autoManagement -and
                $autoManagement.ContainsKey('AutoCreateIssues') -and 
                $autoManagement.ContainsKey('CreateFromCodeQuality') -and
                $autoManagement.AutoCreateIssues -and 
                $autoManagement.CreateFromCodeQuality) {
                $shouldCreateIssues = $true
                Write-ScriptLog -Message "Automated issue creation enabled by configuration"
            }
        }
    } catch {
        Write-ScriptLog -Level Debug -Message "Could not load configuration: $_"
    }
    
    # Override with explicit parameters
    if ($CreateIssues) {
        $shouldCreateIssues = $true
        Write-ScriptLog -Message "Automated issue creation enabled by parameter"
    }
    if ($NoIssueCreation) {
        $shouldCreateIssues = $false
        Write-ScriptLog -Message "Automated issue creation disabled by parameter"
    }
    
    # Create issues for failed files
    if ($shouldCreateIssues -and ($overallStatus -eq 'Failed' -or $failedCount -gt 0)) {
        # In GitHub Actions/CI, skip issue creation - the workflow handles it
        if ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true') {
            Write-Host "`nℹ️  Issue creation skipped - running in CI environment" -ForegroundColor Cyan
            Write-Host "   GitHub Actions workflow will create issues automatically" -ForegroundColor Gray
            Write-ScriptLog -Message "Skipping issue creation in CI - workflow will handle it"
        } else {
            Write-Host "`n📋 Creating GitHub Issues for Quality Failures..." -ForegroundColor Cyan
            
            # Check GitHub authentication before attempting to create issues
            if (-not (Test-GitHubAuthentication)) {
                Write-Host "  ⚠️  Cannot create issues: GitHub CLI is not authenticated or not installed." -ForegroundColor Yellow
                Write-Host "  💡 To enable issue creation:" -ForegroundColor Cyan
                Write-Host "     1. Install GitHub CLI: https://cli.github.com/" -ForegroundColor Gray
                Write-Host "     2. Authenticate: gh auth login" -ForegroundColor Gray
                Write-ScriptLog -Level Warning -Message "Skipping issue creation - GitHub CLI not authenticated"
            } else {
                $failedReports = $allReports | Where-Object { $_.OverallStatus -eq 'Failed' }
                $issuesCreated = 0
                
                foreach ($failedReport in $failedReports) {
                    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($failedReport.FilePath)
                    $reportPath = Join-Path $OutputPath "$reportName-$fileName.json"
                    
                    Write-Host "  Creating issue for: $($failedReport.FileName)..." -ForegroundColor Yellow
                    
                    $issue = New-QualityIssue -Report $failedReport -ReportPath $reportPath
                    if ($issue) {
                        if ($issue.Number) {
                            Write-Host "  ✅ Created issue #$($issue.Number): $($issue.Url)" -ForegroundColor Green
                        } else {
                            Write-Host "  ✅ Created issue: $($issue.Url)" -ForegroundColor Green
                        }
                        $issuesCreated++
                    } else {
                        Write-Host "  ❌ Failed to create issue for $($failedReport.FileName)" -ForegroundColor Red
                    }
                }
                
                if ($issuesCreated -gt 0) {
                    Write-Host "`n✨ Created $issuesCreated GitHub issue(s) for quality failures" -ForegroundColor Green
                } else {
                    Write-Host "`n⚠️  No issues were created. Check GitHub CLI authentication and permissions." -ForegroundColor Yellow
                }
            }
        }
    }
    
    # Determine exit code
    $duration = (Get-Date) - $script:StartTime
    Write-ScriptLog -Message "Quality validation completed in $($duration.TotalSeconds) seconds" -Data @{
        FilesValidated = $fileCount
        AverageScore = $averageScore
        Status = $overallStatus
    }
    
    if ($overallStatus -eq 'Failed') {
        Write-Host "`n❌ Quality validation FAILED" -ForegroundColor Red
        exit 1
    } elseif ($overallStatus -eq 'Warning' -and $FailOnWarnings) {
        Write-Host "`n⚠️  Quality validation has WARNINGS (treated as failure)" -ForegroundColor Yellow
        exit 1
    } elseif ($averageScore -lt $MinimumScore) {
        Write-Host "`n❌ Average score ($averageScore%) is below minimum threshold ($MinimumScore%)" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "`n✅ Quality validation PASSED" -ForegroundColor Green
        exit 0
    }
    
} catch {
    Write-ScriptLog -Level Error -Message "Quality validation failed: $_" -Data @{
        Exception = $_.Exception.Message
        ScriptStackTrace = $_.ScriptStackTrace
    }
    
    Write-Host "`n❌ Quality validation encountered an error: $_" -ForegroundColor Red
    exit 2
}
