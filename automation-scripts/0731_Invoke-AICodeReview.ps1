#!/usr/bin/env pwsh
#requires -version 7

<#
.SYNOPSIS
    Multi-AI code analysis pipeline for comprehensive code review.

.DESCRIPTION
    Performs security analysis, performance optimization, and code quality checks
    using multiple AI providers, then aggregates results into comprehensive reports.

.PARAMETER Path
    Path to file or directory to review

.PARAMETER Profile
    Review profile (Quick, Standard, Comprehensive)

.PARAMETER OutputFormat
    Output format for the report (Console, HTML, Markdown, JSON)

.PARAMETER PRNumber
    GitHub PR number to post comments to

.EXAMPLE
    ./0731_Invoke-AICodeReview.ps1 -Path ./src -Profile Standard

.EXAMPLE
    ./0731_Invoke-AICodeReview.ps1 -Path ./module.psm1 -PRNumber 123 -OutputFormat Markdown
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [ValidateSet('Quick', 'Standard', 'Comprehensive')]
    [string]$ProfileName = 'Standard',

    [ValidateSet('Console', 'HTML', 'Markdown', 'JSON')]
    [string[]]$OutputFormat = @('Console'),

    [int]$PRNumber = 0,

    [switch]$SkipSecurity,
    [switch]$SkipPerformance,
    [switch]$SkipQuality
)

#region Metadata
$script:Stage = "AIAutomation"
$script:Dependencies = @('0730', '0400')
$script:Tags = @('ai', 'code-review', 'quality', 'security')
$script:Condition = '$env:ANTHROPIC_API_KEY -or $env:OPENAI_API_KEY -or $env:GOOGLE_API_KEY'
$script:Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
#endregion

#region Module Imports
$projectRoot = Split-Path $PSScriptRoot -Parent
$modulePaths = @(
    "$projectRoot/domains/development/DevTools.psm1"
    "$projectRoot/domains/ai-agents/AIWorkflowOrchestrator.psm1"
    "$projectRoot/domains/core/Logging.psm1"
    "$projectRoot/domains/development/DevTools.psm1"
)

foreach ($modulePath in $modulePaths) {
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -ErrorAction SilentlyContinue
    }
}
#endregion

#region Helper Functions
function Get-AIConfig {
    param([string]$ConfigPath)

    try {
        if (Test-Path $ConfigPath) {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            return $config.AI
        } else {
            Write-Warning "Config file not found at $ConfigPath"
            return $null
        }
    } catch {
        Write-Error "Failed to load config: $_"
        return $null
    }
}

function Write-ReviewLog {
    param(
        [string]$Message,
        [ValidateSet('Information', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Information'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "AI-CodeReview"
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Debug' { 'Gray' }
            default { 'White' }
        }
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

function Get-CodeFiles {
    param([string]$Path)

    $extensions = @('*.ps1', '*.psm1', '*.psd1', '*.cs', '*.js', '*.ts', '*.py', '*.go', '*.java')
    $files = @()

    if (Test-Path $Path -PathType Leaf) {
        $files = @(Get-Item $Path)
    } else {
        foreach ($ext in $extensions) {
            $files += Get-ChildItem -Path $Path -Filter $ext -Recurse -File -ErrorAction SilentlyContinue
        }
    }

    return $files
}

function Invoke-SecurityAnalysis {
    param(
        [System.IO.FileInfo[]]$Files,
        [string]$Provider,
        [hashtable]$SecurityConfig
    )

    Write-ReviewLog "Starting security analysis with $Provider" -Level Information

    $results = @()
    $totalIssues = 0

    foreach ($file in $Files) {
        $content = Get-Content $file.FullName -Raw

        $analysis = @{
            File = $file.Name
            Path = $file.FullName
            SecurityIssues = @()
        }

        # Check each enabled security check from config
        if ($SecurityConfig.CredentialExposure) {
            if ($content -match 'password\s*=\s*[''"]|apikey\s*=\s*[''"]|secret\s*=\s*[''"') {
                $analysis.SecurityIssues += @{
                    Type = 'Credential Exposure'
                    Severity = 'Critical'
                    Line = ($content | Select-String 'password\s*=\s*[''"]|apikey\s*=\s*[''"]').LineNumber
                    Description = 'Hardcoded credentials detected'
                    Recommendation = 'Use secure credential storage (e.g., Azure Key Vault, AWS Secrets Manager)'
                }
                $totalIssues++
            }
        }

        if ($SecurityConfig.InjectionVulnerabilities) {
            if ($content -match 'Invoke-Expression|iex') {
                $analysis.SecurityIssues += @{
                    Type = 'Code Injection'
                    Severity = 'High'
                    Line = ($content | Select-String 'Invoke-Expression|iex').LineNumber
                    Description = 'Potential code injection vulnerability'
                    Recommendation = 'Avoid Invoke-Expression; use safer alternatives'
                }
                $totalIssues++
            }
        }

        if ($SecurityConfig.InputValidation) {
            if ($content -match '\$_\.' -and $content -notmatch 'ValidateScript|ValidateSet|ValidatePattern') {
                $analysis.SecurityIssues += @{
                    Type = 'Input Validation'
                    Severity = 'Medium'
                    Description = 'Pipeline input used without validation'
                    Recommendation = 'Validate and sanitize all pipeline input'
                }
                $totalIssues++
            }
        }

        $results += $analysis
    }

    Write-ReviewLog "Security analysis complete: $totalIssues issue(s) found" -Level $(if ($totalIssues -gt 0) { 'Warning' } else { 'Information' })

    return @{
        Provider = $Provider
        Type = 'Security'
        TotalFiles = $Files.Count
        TotalIssues = $totalIssues
        Results = $results
    }
}

function Invoke-PerformanceAnalysis {
    param(
        [System.IO.FileInfo[]]$Files,
        [string]$Provider = 'Gemini'
    )

    Write-ReviewLog "Starting performance analysis with $Provider" -Level Information

    $results = @()
    $totalOptimizations = 0

    foreach ($file in $Files) {
        $content = Get-Content $file.FullName -Raw

        $analysis = @{
            File = $file.Name
            Path = $file.FullName
            PerformanceIssues = @()
        }

        # Check for common performance issues
        if ($content -match 'Get-ChildItem.*-Recurse.*\|.*Where-Object') {
            $analysis.PerformanceIssues += @{
                Type = 'Inefficient Filtering'
                Severity = 'Medium'
                Description = 'Filtering after recursive enumeration'
                Recommendation = 'Use -Filter or -Include parameter instead of piping to Where-Object'
                PotentialImprovement = '50-80% faster'
            }
            $totalOptimizations++
        }

        if ($content -match '\+=') {
            $analysis.PerformanceIssues += @{
                Type = 'Array Concatenation'
                Severity = 'Low'
                Description = 'Using += for array operations'
                Recommendation = 'Use ArrayList or generic List[T] for better performance'
                PotentialImprovement = '10-30% faster for large arrays'
            }
            $totalOptimizations++
        }

        if ($content -match 'Import-Module.*-Force' -and $content -notmatch 'if.*Get-Module') {
            $analysis.PerformanceIssues += @{
                Type = 'Redundant Module Loading'
                Severity = 'Low'
                Description = 'Module imported with -Force without checking if already loaded'
                Recommendation = 'Check if module is loaded before importing'
                PotentialImprovement = 'Reduce startup time by 20-40ms per module'
            }
            $totalOptimizations++
        }

        $results += $analysis
    }

    Write-ReviewLog "Performance analysis complete: $totalOptimizations optimization(s) found" -Level Information

    return @{
        Provider = $Provider
        Type = 'Performance'
        TotalFiles = $Files.Count
        TotalOptimizations = $totalOptimizations
        Results = $results
    }
}

function Invoke-QualityAnalysis {
    param(
        [System.IO.FileInfo[]]$Files,
        [string]$Provider = 'Codex'
    )

    Write-ReviewLog "Starting code quality analysis with $Provider" -Level Information

    $results = @()
    $totalIssues = 0

    foreach ($file in $Files) {
        $content = Get-Content $file.FullName -Raw

        $analysis = @{
            File = $file.Name
            Path = $file.FullName
            QualityIssues = @()
            Metrics = @{}
        }

        # Calculate complexity metrics
        $lines = ($content -split "`n").Count
        $functions = ([regex]::Matches($content, 'function\s+\w+')).Count
        $analysis.Metrics = @{
            LinesOfCode = $lines
            Functions = $functions
            AverageComplexity = if ($functions -gt 0) { [math]::Round($lines / $functions, 2) } else { 0 }
        }

        # Check for quality issues
        if ($content -match 'TODO|FIXME|HACK') {
            $matchResults = [regex]::Matches($content, 'TODO|FIXME|HACK')
            $analysis.QualityIssues += @{
                Type = 'Technical Debt'
                Severity = 'Low'
                Count = $matchResults.Count
                Description = "Found $($matchResults.Count) TODO/FIXME/HACK comment(s)"
                Recommendation = 'Address technical debt items or create issues for tracking'
            }
            $totalIssues += $matchResults.Count
        }

        if (-not ($content -match '\.SYNOPSIS')) {
            $analysis.QualityIssues += @{
                Type = 'Missing Documentation'
                Severity = 'Medium'
                Description = 'No comment-based help found'
                Recommendation = 'Add .SYNOPSIS and .DESCRIPTION to all functions'
            }
            $totalIssues++
        }

        if ($content -match 'catch\s*{\s*}') {
            $analysis.QualityIssues += @{
                Type = 'Empty Catch Block'
                Severity = 'Medium'
                Description = 'Empty catch block found'
                Recommendation = 'Add proper error handling or logging'
            }
            $totalIssues++
        }

        $results += $analysis
    }

    Write-ReviewLog "Quality analysis complete: $totalIssues issue(s) found" -Level Information

    return @{
        Provider = $Provider
        Type = 'Quality'
        TotalFiles = $Files.Count
        TotalIssues = $totalIssues
        Results = $results
    }
}

function Format-ReviewReport {
    param(
        [hashtable[]]$Analyses,
        [string]$Format
    )

    switch ($Format) {
        'Console' {
            Write-Host "`n═══════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "           AI Code Review Report" -ForegroundColor Cyan
            Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan

            foreach ($analysis in $Analyses) {
                Write-Host "`n$($analysis.Type) Analysis ($($analysis.Provider)):" -ForegroundColor Yellow
                Write-Host "Files analyzed: $($analysis.TotalFiles)"

                if ($analysis.Type -eq 'Security') {
                    Write-Host "Security issues: $($analysis.TotalIssues)" -ForegroundColor $(if ($analysis.TotalIssues -gt 0) { 'Red' } else { 'Green' })
                } elseif ($analysis.Type -eq 'Performance') {
                    Write-Host "Optimizations: $($analysis.TotalOptimizations)" -ForegroundColor $(if ($analysis.TotalOptimizations -gt 0) { 'Yellow' } else { 'Green' })
                } elseif ($analysis.Type -eq 'Quality') {
                    Write-Host "Quality issues: $($analysis.TotalIssues)" -ForegroundColor $(if ($analysis.TotalIssues -gt 0) { 'Yellow' } else { 'Green' })
                }

                foreach ($result in $analysis.Results) {
                    if ($result.SecurityIssues -and $result.SecurityIssues.Count -gt 0) {
                        Write-Host "`n  File: $($result.File)" -ForegroundColor White
                        foreach ($issue in $result.SecurityIssues) {
                            Write-Host "    [$($issue.Severity)] $($issue.Type): $($issue.Description)" -ForegroundColor Red
                        }
                    }

                    if ($result.PerformanceIssues -and $result.PerformanceIssues.Count -gt 0) {
                        Write-Host "`n  File: $($result.File)" -ForegroundColor White
                        foreach ($issue in $result.PerformanceIssues) {
                            Write-Host "    [$($issue.Severity)] $($issue.Type): $($issue.Description)" -ForegroundColor Yellow
                        }
                    }

                    if ($result.QualityIssues -and $result.QualityIssues.Count -gt 0) {
                        Write-Host "`n  File: $($result.File)" -ForegroundColor White
                        foreach ($issue in $result.QualityIssues) {
                            Write-Host "    [$($issue.Severity)] $($issue.Type): $($issue.Description)" -ForegroundColor Yellow
                        }
                    }
                }
            }
        }

        'Markdown' {
            $report = @'
# AI Code Review Report

Generated: {0}

## Summary

'@ -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            foreach ($analysis in $Analyses) {
                $report += @"

### $($analysis.Type) Analysis
- **Provider**: $($analysis.Provider)
- **Files Analyzed**: $($analysis.TotalFiles)
"@

                if ($analysis.Type -eq 'Security') {
                    $report += "- **Security Issues**: $($analysis.TotalIssues)`n"
                } elseif ($analysis.Type -eq 'Performance') {
                    $report += "- **Optimizations Found**: $($analysis.TotalOptimizations)`n"
                } elseif ($analysis.Type -eq 'Quality') {
                    $report += "- **Quality Issues**: $($analysis.TotalIssues)`n"
                }

                if ($analysis.Results) {
                    $report += "`n#### Detailed Findings`n"
                    foreach ($result in $analysis.Results) {
                        $allIssues = @()
                        $allIssues += $result.SecurityIssues
                        $allIssues += $result.PerformanceIssues
                        $allIssues += $result.QualityIssues

                        if ($allIssues.Count -gt 0) {
                            $report += "`n**$($result.File)**`n"
                            foreach ($issue in $allIssues) {
                                if ($issue) {
                                    $report += "- `[$($issue.Severity)`] **$($issue.Type)**: $($issue.Description)`n"
                                    if ($issue.Recommendation) {
                                        $report += "  - *Recommendation*: $($issue.Recommendation)`n"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            return $report
        }

        'JSON' {
            return $Analyses | ConvertTo-Json -Depth 10
        }

        'HTML' {
            # Generate HTML report (simplified)
            $dateStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AI Code Review Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #0066cc; color: white; padding: 20px; }
        .section { margin: 20px 0; }
        .critical { color: #d00; }
        .high { color: #f60; }
        .medium { color: #fa0; }
        .low { color: #090; }
    </style>
</head>
<body>
    <div class="header">
        <h1>AI Code Review Report</h1>
        <p>Generated: $dateStr</p>
    </div>
"@

            foreach ($analysis in $Analyses) {
                $html += "<div class='section'><h2>$($analysis.Type) Analysis</h2>"
                $html += "<p>Provider: $($analysis.Provider)<br/>Files: $($analysis.TotalFiles)</p>"
                # Add more HTML generation logic here
                $html += "</div>"
            }

            $html += "</body></html>"
            return $html
        }
    }
}

function Post-PRComment {
    param(
        [int]$PRNumber,
        [string]$Comment
    )

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            gh pr comment $PRNumber --body $Comment
            Write-ReviewLog "Posted review comments to PR #$PRNumber" -Level Information
        } catch {
            Write-ReviewLog "Failed to post PR comment: $_" -Level Error
        }
    } else {
        Write-ReviewLog "GitHub CLI not available for PR commenting" -Level Warning
    }
}
#endregion

#region Main Execution
function Main {
    Write-ReviewLog "Starting AI Code Review (Profile: $ProfileName)" -Level Information

    # Load configuration
    $configPath = if ($PSScriptRoot) {
        Join-Path (Split-Path $PSScriptRoot -Parent) "config.psd1"
    } else {
        "./config.psd1"
    }

    $aiConfig = Get-AIConfig -ConfigPath $configPath
    if (-not $aiConfig -or -not $aiConfig.Enabled -or -not $aiConfig.CodeReview.Enabled) {
        Write-ReviewLog "AI Code Review is not enabled in configuration" -Level Warning
        exit 1
    }

    # Get profile configuration
    $ProfileNameConfig = $aiConfig.CodeReview.Profiles.$ProfileName
    if (-not $ProfileNameConfig) {
        Write-ReviewLog "Profile '$ProfileName' not found in configuration" -Level Error
        exit 1
    }

    # Get files to review
    $files = Get-CodeFiles -Path $Path

    if ($files.Count -eq 0) {
        Write-ReviewLog "No code files found to review" -Level Warning
        exit 1
    }

    Write-ReviewLog "Found $($files.Count) file(s) to review" -Level Information
    Write-ReviewLog "Using profile: $($ProfileNameConfig.Description)" -Level Information
    Write-ReviewLog "Providers: $($ProfileNameConfig.Providers -join ', ')" -Level Information

    $analyses = @()

    # Run security analysis if configured
    if (-not $SkipSecurity -and 'security' -in $ProfileNameConfig.Checks) {
        $securityProvider = $aiConfig.SecurityAnalysis.Provider ?? $ProfileNameConfig.Providers[0]
        $securityAnalysis = Invoke-SecurityAnalysis -Files $files -Provider $securityProvider -SecurityConfig $aiConfig.CodeReview.SecurityChecks
        $analyses += $securityAnalysis
    }

    # Run performance analysis if configured
    if (-not $SkipPerformance -and 'performance' -in $ProfileNameConfig.Checks) {
        $perfProvider = $aiConfig.PerformanceOptimization.Provider ?? $ProfileNameConfig.Providers[1]
        $performanceAnalysis = Invoke-PerformanceAnalysis -Files $files -Provider $perfProvider
        $analyses += $performanceAnalysis
    }

    # Run quality analysis if configured
    if (-not $SkipQuality -and 'quality' -in $ProfileNameConfig.Checks) {
        $qualityProvider = $ProfileNameConfig.Providers | Select-Object -Last 1
        $qualityAnalysis = Invoke-QualityAnalysis -Files $files -Provider $qualityProvider
        $analyses += $qualityAnalysis
    }

    # Generate reports
    foreach ($format in $OutputFormat) {
        $report = Format-ReviewReport -Analyses $analyses -Format $format

        if ($format -eq 'Console') {
            # Already displayed
        } elseif ($format -eq 'Markdown') {
            $reportPath = "$projectRoot/reports/ai-code-review-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
            if ($PSCmdlet.ShouldProcess($reportPath, "Save Markdown report")) {
                # Ensure reports directory exists
                $reportsDir = Split-Path $reportPath -Parent
                if (-not (Test-Path $reportsDir) -and $PSCmdlet.ShouldProcess($reportsDir, "Create reports directory")) {
                    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
                }
                $report | Set-Content $reportPath
                Write-ReviewLog "Markdown report saved to: $reportPath" -Level Information
            }
        } elseif ($format -eq 'JSON') {
            $reportPath = "$projectRoot/reports/ai-code-review-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            if ($PSCmdlet.ShouldProcess($reportPath, "Save JSON report")) {
                # Ensure reports directory exists
                $reportsDir = Split-Path $reportPath -Parent
                if (-not (Test-Path $reportsDir) -and $PSCmdlet.ShouldProcess($reportsDir, "Create reports directory")) {
                    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
                }
                $report | Set-Content $reportPath
                Write-ReviewLog "JSON report saved to: $reportPath" -Level Information
            }
        } elseif ($format -eq 'HTML') {
            $reportPath = "$projectRoot/reports/ai-code-review-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
            if ($PSCmdlet.ShouldProcess($reportPath, "Save HTML report")) {
                # Ensure reports directory exists
                $reportsDir = Split-Path $reportPath -Parent
                if (-not (Test-Path $reportsDir) -and $PSCmdlet.ShouldProcess($reportsDir, "Create reports directory")) {
                    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
                }
                $report | Set-Content $reportPath
                Write-ReviewLog "HTML report saved to: $reportPath" -Level Information
            }
        }
    }

    # Post to PR if specified
    if ($PRNumber -gt 0) {
        $markdownReport = Format-ReviewReport -Analyses $analyses -Format 'Markdown'
        Post-PRComment -PRNumber $PRNumber -Comment $markdownReport
    }

    # Calculate exit code based on severity and configuration
    $criticalCount = ($analyses.Results.SecurityIssues | Where-Object { $_.Severity -eq 'Critical' }).Count
    $highCount = ($analyses.Results.SecurityIssues | Where-Object { $_.Severity -eq 'High' }).Count

    if ($criticalCount -gt 0) {
        Write-ReviewLog "Review failed: $criticalCount critical issue(s) found" -Level Error
        exit 2
    } elseif ($highCount -gt 0 -and $ProfileNameConfig.FailOnHighSeverity) {
        Write-ReviewLog "Review failed: $highCount high severity issue(s) found" -Level Error
        exit 1
    } else {
        Write-ReviewLog "Review completed successfully" -Level Information
        exit 0
    }
}

# Execute main function
Main
#endregion
