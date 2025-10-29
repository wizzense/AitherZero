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
.EXAMPLE
    ./0420_Validate-ComponentQuality.ps1 -Path ./domains/testing/NewModule.psm1
    Validate a single module file
.EXAMPLE
    ./0420_Validate-ComponentQuality.ps1 -Path ./domains/testing -Recursive
    Validate all PowerShell files in the testing domain
.EXAMPLE
    ./0420_Validate-ComponentQuality.ps1 -Path ./automation-scripts/0500_NewScript.ps1 -Format HTML
    Validate a script and generate HTML report
.NOTES
    Stage: Testing
    Order: 0420
    Dependencies: 0400 (Testing tools installation)
    Tags: testing, quality, validation, standards
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Path,
    
    [switch]$Recursive,
    
    [string[]]$SkipChecks = @(),
    
    [string]$OutputPath,
    
    [ValidateSet('Text', 'HTML', 'JSON')]
    [string]$Format = 'Text',
    
    [switch]$FailOnWarnings,
    
    [int]$MinimumScore = 70,
    
    [switch]$DryRun
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
$loggingModule = Join-Path $projectRoot "domains/utilities/Logging.psm1"
$qualityModule = Join-Path $projectRoot "domains/testing/QualityValidator.psm1"

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
            Include = '*.ps1', '*.psm1', '*.psd1'
            File = $true
        }
        
        if ($Recursive) {
            $scanParams.Recurse = $true
        }
        
        $filesToValidate = Get-ChildItem @scanParams | Select-Object -ExpandProperty FullName
        
        # Ensure it's an array
        $filesToValidate = @($filesToValidate)
        
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
    
    # Display file-by-file breakdown
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
            
            Write-Host "$statusIcon $fileName" -ForegroundColor $statusColor -NoNewline
            Write-Host " - Score: $score%" -ForegroundColor White
            
            # Show top issues for failed/warning files
            if ($status -in @('Failed', 'Warning')) {
                $issues = $report.Checks | Where-Object { $_.Status -in @('Failed', 'Warning') } | Select-Object -First 2
                foreach ($issue in $issues) {
                    $issueIcon = if ($issue.Status -eq 'Failed') { '  ❌' } else { '  ⚠️ ' }
                    if ($issue.Findings) {
                        $findingsArray = @($issue.Findings)
                        if ($findingsArray.Count -gt 0) {
                            $finding = $findingsArray[0]
                            # Truncate long findings
                            if ($finding.Length -gt 70) {
                                $finding = $finding.Substring(0, 67) + "..."
                            }
                            Write-Host "$issueIcon $($issue.CheckName): $finding" -ForegroundColor Gray
                        }
                    }
                }
            }
        }
        Write-Host ""
    }
    
    # Save reports
    if (-not $OutputPath) {
        $OutputPath = Join-Path $projectRoot "reports/quality"
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
