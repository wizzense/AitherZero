#Requires -Version 7.0

<#
.SYNOPSIS
    Run PSScriptAnalyzer on AitherZero codebase
.DESCRIPTION
    Performs static code analysis to identify potential issues and ensure code quality
    
    Exit Codes:
    0   - No issues found
    1   - Issues found
    2   - Analysis error
    
.NOTES
    Stage: Testing
    Order: 0404
    Dependencies: 0400
    Tags: testing, code-quality, psscriptanalyzer, static-analysis
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = (Split-Path $PSScriptRoot -Parent),
    [string]$OutputPath,
    [switch]$DryRun,
    [switch]$Fix,
    [switch]$IncludeSuppressed,
    [string[]]$ExcludePaths = @('tests', 'legacy-to-migrate')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata (kept as comment for documentation)
# Stage: Testing
# Order: 0404
# Dependencies: 0400
# Tags: testing, code-quality, psscriptanalyzer, static-analysis
# RequiresAdmin: No
# SupportsWhatIf: Yes

# Import modules
$projectRoot = Split-Path $PSScriptRoot -Parent
$loggingModule = Join-Path $projectRoot "domains/utilities/Logging.psm1"

if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
    $script:LoggingAvailable = $true
} else {
    $script:LoggingAvailable = $false
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0404_Run-PSScriptAnalyzer" -Data $Data
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
    Write-ScriptLog -Message "Starting PSScriptAnalyzer analysis"

    # Check if running in DryRun mode
    if ($DryRun) {
        Write-ScriptLog -Message "DRY RUN: Would run PSScriptAnalyzer"
        Write-ScriptLog -Message "Analysis path: $Path"
        Write-ScriptLog -Message "Fix mode: $Fix"
        Write-ScriptLog -Message "Excluded paths: $($ExcludePaths -join ', ')"
        
        # List PowerShell files that would be analyzed
        $psFiles = Get-ChildItem -Path $Path -Include "*.ps1", "*.psm1", "*.psd1" -Recurse | 
            Where-Object { 
                $file = $_
                -not ($ExcludePaths | Where-Object { $file.FullName -like "*\$_\*" })
            }
        Write-ScriptLog -Message "Would analyze $($psFiles.Count) PowerShell files"
        exit 0
    }

    # Ensure PSScriptAnalyzer is available
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Write-ScriptLog -Level Error -Message "PSScriptAnalyzer is required. Run 0400_Install-TestingTools.ps1 first."
        exit 2
    }
    
    Import-Module PSScriptAnalyzer

    # Load configuration
    $configPath = Join-Path $projectRoot "config.json"
    $analysisConfig = if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $config.Testing.PSScriptAnalyzer
    } else {
        @{
            Enabled = $true
            Rules = @{
                Severity = @('Error', 'Warning')
                ExcludeRules = @('PSAvoidUsingWriteHost', 'PSUseShouldProcessForStateChangingFunctions')
            }
        }
    }

    # Build PSScriptAnalyzer parameters
    $analyzerParams = @{
        Path = $Path
        Recurse = $true
        Severity = $analysisConfig.Rules.Severity
        ExcludeRule = $analysisConfig.Rules.ExcludeRules
    }

    # Add exclude paths using file filtering instead
    $filesToAnalyze = $null
    if ($ExcludePaths) {
        Write-ScriptLog -Message "Filtering files to exclude paths: $($ExcludePaths -join ', ')"
        # Get all PS1 files and filter out excluded paths
        $allFiles = Get-ChildItem -Path $Path -Recurse -Filter "*.ps1" | Where-Object {
            $file = $_.FullName
            $exclude = $false
            foreach ($excludePath in $ExcludePaths) {
                if ($file -like "*$excludePath*") {
                    $exclude = $true
                    break
                }
            }
            -not $exclude
        }
        $analyzerParams.Remove('Path')
        $analyzerParams.Remove('Recurse')
        if ($allFiles) {
            $filesToAnalyze = $allFiles | ForEach-Object { $_.FullName }
            $analyzerParams['Path'] = $filesToAnalyze
        } else {
            Write-ScriptLog -Message "No files found after applying exclusions"
            return @{
                Success = $true
                Results = @()
                Summary = @{
                    TotalIssues = 0
                    FilesAnalyzed = 0
                    Message = "No files found to analyze after exclusions"
                }
            }
        }
    }

    # Check for settings file
    $settingsPath = Join-Path $projectRoot "PSScriptAnalyzerSettings.psd1"
    if (Test-Path $settingsPath) {
        Write-ScriptLog -Message "Using PSScriptAnalyzer settings from: $settingsPath"
        $analyzerParams['Settings'] = $settingsPath
    }

    # Add fix parameter if requested
    if ($Fix) {
        $analyzerParams['Fix'] = $true
        Write-ScriptLog -Level Warning -Message "Running in FIX mode - files will be modified!"
    }

    # Include suppressed if requested
    if ($IncludeSuppressed) {
        $analyzerParams['IncludeSuppressed'] = $true
    }

    # Performance tracking
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Start-PerformanceTrace -Name "PSScriptAnalyzer" -Description "Static code analysis"
    }
    
    Write-ScriptLog -Message "Analyzing PowerShell files..."
    Write-Host "`nRunning PSScriptAnalyzer. This may take a few minutes..." -ForegroundColor Yellow

    # Run analysis
    if ($PSCmdlet.ShouldProcess("PowerShell files", "Run PSScriptAnalyzer analysis")) {
        if ($analyzerParams.Path -is [array] -and $analyzerParams.Path.Count -gt 1) {
            # Handle multiple files by analyzing each one and combining results
            $allResults = @()
            foreach ($file in $analyzerParams.Path) {
                $singleFileParams = $analyzerParams.Clone()
                $singleFileParams['Path'] = $file
                $fileResults = Invoke-ScriptAnalyzer @singleFileParams
                if ($fileResults) {
                    $allResults += $fileResults
                }
            }
            $results = $allResults
        } else {
            $results = Invoke-ScriptAnalyzer @analyzerParams
        }
    } else {
        Write-ScriptLog -Message "WhatIf: Would run PSScriptAnalyzer analysis"
        return @{
            Success = $true
            Results = @()
            Summary = @{
                TotalIssues = 0
                FilesAnalyzed = 0
                Message = "WhatIf mode - analysis skipped"
            }
        }
    }

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        $duration = Stop-PerformanceTrace -Name "PSScriptAnalyzer"
    }

    # Process results
    $resultSummary = @{
        TotalIssues = $results.Count
        ByScript = @{}
        BySeverity = @{}
        ByRule = @{}
    }

    # Group results
    if ($results) {
        $severityGroups = $results | Group-Object Severity
        $resultSummary.BySeverity = @{}
        foreach ($group in $severityGroups) {
            $resultSummary.BySeverity[$group.Name] = $group.Count
        }
        
        $ruleGroups = $results | Group-Object RuleName | Sort-Object Count -Descending | Select-Object -First 10
        $resultSummary.ByRule = @{}
        foreach ($group in $ruleGroups) {
            $resultSummary.ByRule[$group.Name] = $group.Count
        }
        
        $scriptGroups = $results | Group-Object ScriptName | Sort-Object Count -Descending | Select-Object -First 10
        $resultSummary.ByScript = @{}
        foreach ($group in $scriptGroups) {
            $resultSummary.ByScript[$group.Name] = $group.Count
        }
    }
    
    Write-ScriptLog -Message "PSScriptAnalyzer analysis completed" -Data $resultSummary

    # Display summary
    Write-Host "`nPSScriptAnalyzer Summary:" -ForegroundColor Cyan
    Write-Host "  Total Issues: $($results.Count)"

    if ($results.Count -gt 0) {
        # By severity
        Write-Host "`n  By Severity:" -ForegroundColor Yellow
        foreach ($severity in @('Error', 'Warning', 'Information')) {
            $severityResults = @($results | Where-Object { $_.Severity -eq $severity })
            $count = $severityResults.Count
            if ($count -gt 0) {
                $color = @{ 'Error' = 'Red'; 'Warning' = 'Yellow'; 'Information' = 'Cyan' }[$severity]
                Write-Host "    $severity : $count" -ForegroundColor $color
            }
        }
        
        # Top rules
        Write-Host "`n  Top Rules Violated:" -ForegroundColor Yellow
        $results | Group-Object RuleName | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
            Write-Host "    $($_.Name): $($_.Count)"
        }
        
        # Top files
        Write-Host "`n  Files with Most Issues:" -ForegroundColor Yellow
        $results | Group-Object ScriptName | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
            $fileName = Split-Path $_.Name -Leaf
            Write-Host "    $fileName : $($_.Count)"
        }
        
        # Show errors if any
        $errors = $results | Where-Object { $_.Severity -eq 'Error' }
        if ($errors) {
            Write-Host "`nErrors Found:" -ForegroundColor Red
            $errors | Select-Object -First 10 | ForEach-Object {
                Write-Host "  File: $(Split-Path $_.ScriptName -Leaf):$($_.Line)" -ForegroundColor Red
                Write-Host "  Rule: $($_.RuleName)" -ForegroundColor DarkRed
                Write-Host "  Message: $($_.Message)" -ForegroundColor DarkRed
                Write-Host ""
            }

            if ($errors.Count -gt 10) {
                Write-Host "  ... and $($errors.Count - 10) more errors" -ForegroundColor DarkRed
            }
        }
    } else {
        Write-Host "  No issues found! Code meets all PSScriptAnalyzer rules." -ForegroundColor Green
    }

    # Save results
    if ($results.Count -gt 0) {
        if (-not $OutputPath) {
            $OutputPath = Join-Path $projectRoot "tests/analysis"
        }
        
        if (-not (Test-Path $OutputPath)) {
            if ($PSCmdlet.ShouldProcess($OutputPath, "Create analysis output directory")) {
                New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
            }
        }
        
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        
        # Save as CSV for easy analysis
        $csvPath = Join-Path $OutputPath "PSScriptAnalyzer-$timestamp.csv"
        if ($PSCmdlet.ShouldProcess($csvPath, "Export analysis results to CSV")) {
            $results | Export-Csv -Path $csvPath -NoTypeInformation
            Write-ScriptLog -Message "Analysis results saved to: $csvPath"
        }
        
        # Save as JSON with summary
        $jsonPath = Join-Path $OutputPath "PSScriptAnalyzer-Summary-$timestamp.json"
        if ($PSCmdlet.ShouldProcess($jsonPath, "Save analysis summary as JSON")) {
            @{
                Timestamp = Get-Date
                Summary = $resultSummary
                Details = $results | Select-Object RuleName, Severity, ScriptName, Line, Column, Message
            } | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath
            Write-ScriptLog -Message "Analysis summary saved to: $jsonPath"
        }
        
        # Generate SARIF format for integration with other tools
        if (Get-Command -Name ConvertTo-SarifReport -ErrorAction SilentlyContinue) {
            $sarifPath = Join-Path $OutputPath "PSScriptAnalyzer-$timestamp.sarif"
            if ($PSCmdlet.ShouldProcess($sarifPath, "Generate SARIF report")) {
                $results | ConvertTo-SarifReport | Set-Content -Path $sarifPath
                Write-ScriptLog -Message "SARIF report saved to: $sarifPath"
            }
        }
    }

    # Exit based on results
    if ($results.Count -eq 0) {
        Write-ScriptLog -Message "PSScriptAnalyzer found no issues!"
        exit 0
    } else {
        $errorResults = @($results | Where-Object { $_.Severity -eq 'Error' })
        $errorCount = $errorResults.Count
        if ($errorCount -gt 0) {
            Write-ScriptLog -Level Error -Message "PSScriptAnalyzer found $errorCount errors"
        } else {
            Write-ScriptLog -Level Warning -Message "PSScriptAnalyzer found $($results.Count) warnings"
        }
        exit 1
    }
}
catch {
    Write-ScriptLog -Level Error -Message "PSScriptAnalyzer analysis failed: $_" -Data @{ 
        Exception = $_.Exception.Message 
        ScriptStackTrace = $_.ScriptStackTrace
    }
    exit 2
}

# Helper function to merge hashtables - removed as unused
# If needed in future, use: $merged = @{}; $hashtables | ForEach-Object { $merged += $_ }