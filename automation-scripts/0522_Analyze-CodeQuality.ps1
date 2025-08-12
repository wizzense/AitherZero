#Requires -Version 7.0
<#
.SYNOPSIS
    Analyzes code quality issues across the codebase
.DESCRIPTION
    Scans for TODOs, FIXMEs, deprecated code, complexity issues,
    hardcoded values, and other code quality indicators
#>

# Script metadata
# Stage: Reporting
# Dependencies: 0400
# Description: Code quality analysis for tech debt reporting
# Tags: reporting, tech-debt, code-quality, analysis

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = ".",
    [string]$OutputPath = "./reports/tech-debt/analysis",
    [switch]$UseCache,
    [switch]$Detailed = $false,
    [int]$MaxFunctionLength = 100,
    [int]$MaxComplexity = 10,
    [string[]]$ExcludePaths = @('tests', 'legacy-to-migrate', 'examples', 'reports', '.git')
)

# Initialize
$ErrorActionPreference = 'Stop'
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:StartTime = Get-Date

# Import modules
Import-Module (Join-Path $script:ProjectRoot 'domains/reporting/TechDebtAnalysis.psm1') -Force
Import-Module (Join-Path $script:ProjectRoot 'domains/utilities/Logging.psm1') -Force -ErrorAction SilentlyContinue

# Initialize analysis
if ($PSCmdlet.ShouldProcess($OutputPath, "Initialize tech debt analysis results directory")) {
    Initialize-TechDebtAnalysis -ResultsPath $OutputPath
}

function Get-TodoPatterns {
    return @{
        TODOs = @('TODO:', 'TODO\s*\(', '\[TODO\]', '#\s*TODO')
        FIXMEs = @('FIXME:', 'FIXME\s*\(', '\[FIXME\]', '#\s*FIXME')
        HACKs = @('HACK:', 'HACK\s*\(', '\[HACK\]', '#\s*HACK')
        XXXs = @('XXX:', 'XXX\s*\(', '\[XXX\]')
        Deprecated = @('DEPRECATED:', '@deprecated', '\[DEPRECATED\]', '#\s*DEPRECATED')
        TechDebt = @('TECHDEBT:', 'TECH DEBT:', 'Technical Debt:', '\[TECHDEBT\]')
    }
}

function Get-HardcodedPatterns {
    return @(
        @{ Pattern = 'https?://localhost'; Type = 'LocalURL' }
        @{ Pattern = 'https?://127\.0\.0\.1'; Type = 'LocalIP' }
        @{ Pattern = 'https?://192\.168\.\d+\.\d+'; Type = 'PrivateIP' }
        @{ Pattern = '[Cc]:\\\\[^"''`\s]+'; Type = 'HardcodedPath' }
        @{ Pattern = '/home/\w+/[^"''`\s]+'; Type = 'HardcodedPath' }
        @{ Pattern = 'password\s*=\s*["\''`][^"\''`]+["\''`]'; Type = 'HardcodedCredential' }
        @{ Pattern = 'apikey\s*=\s*["\''`][^"\''`]+["\''`]'; Type = 'HardcodedCredential' }
        @{ Pattern = 'token\s*=\s*["\''`][^"\''`]+["\''`]'; Type = 'HardcodedCredential' }
        @{ Pattern = 'server\s*=\s*["\''`][^"\''`]+["\''`]'; Type = 'HardcodedServer' }
        @{ Pattern = 'database\s*=\s*["\''`][^"\''`]+["\''`]'; Type = 'HardcodedDatabase' }
        @{ Pattern = 'port\s*=\s*\d{2,5}(?!\d)'; Type = 'HardcodedPort' }
    )
}

function Analyze-FileComplexity {
    param(
        [string]$FilePath,
        [string]$Content,
        $AST
    )

    $complexity = @{
        Functions = @()
        TotalLines = ($Content -split "`n").Count
        CodeLines = 0
        CommentLines = 0
        BlankLines = 0
        MaxNesting = 0
    }

    # Count line types
    $lines = $Content -split "`n"
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '') {
            $complexity.BlankLines++
        } elseif ($trimmed -match '^#' -or $trimmed -match '^<#') {
            $complexity.CommentLines++
        } else {
            $complexity.CodeLines++
        }
    }

    # Analyze functions
    if ($AST) {
        $functions = $AST.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
        
        foreach ($function in $functions) {
            $funcComplexity = @{
                Name = $function.Name
                StartLine = $function.Extent.StartLineNumber
                EndLine = $function.Extent.EndLineNumber
                Lines = $function.Extent.EndLineNumber - $function.Extent.StartLineNumber
                CyclomaticComplexity = 1  # Base complexity
                MaxNesting = 0
                Issues = @()
            }

            # Count control flow statements
            $controlFlow = $function.FindAll({
                $args[0] -is [System.Management.Automation.Language.IfStatementAst] -or
                $args[0] -is [System.Management.Automation.Language.WhileStatementAst] -or
                $args[0] -is [System.Management.Automation.Language.ForStatementAst] -or
                $args[0] -is [System.Management.Automation.Language.ForEachStatementAst] -or
                $args[0] -is [System.Management.Automation.Language.SwitchStatementAst] -or
                $args[0] -is [System.Management.Automation.Language.TryStatementAst]
            }, $true)
            
            $funcComplexity.CyclomaticComplexity += $controlFlow.Count

            # Calculate max nesting
            $nestingLevel = 0
            $maxNesting = 0
            $function.Visit({
                param($ast)
                if ($ast -is [System.Management.Automation.Language.ScriptBlockAst]) {
                    $nestingLevel++
                    if ($nestingLevel -gt $maxNesting) {
                        $maxNesting = $nestingLevel
                    }
                }
                return $true
            }, {
                param($ast)
                if ($ast -is [System.Management.Automation.Language.ScriptBlockAst]) {
                    $nestingLevel--
                }
            })
            
            $funcComplexity.MaxNesting = $maxNesting

            # Check for issues
            if ($funcComplexity.Lines -gt $MaxFunctionLength) {
                $funcComplexity.Issues += "Long function ($($funcComplexity.Lines) lines)"
            }

            if ($funcComplexity.CyclomaticComplexity -gt $MaxComplexity) {
                $funcComplexity.Issues += "High complexity ($($funcComplexity.CyclomaticComplexity))"
            }

            if ($funcComplexity.MaxNesting -gt 4) {
                $funcComplexity.Issues += "Deep nesting (level $($funcComplexity.MaxNesting))"
            }
            
            $complexity.Functions += $funcComplexity
        }
    }
    
    return $complexity
}

function Analyze-CodeQuality {
    Write-AnalysisLog "Starting code quality analysis..." -Component "CodeQuality"

    # Initialize results
    $issues = @{
        TODOs = @()
        FIXMEs = @()
        HACKs = @()
        XXXs = @()
        Deprecated = @()
        TechDebt = @()
        HardcodedValues = @()
        LongFunctions = @()
        ComplexFunctions = @()
        DeeplyNestedCode = @()
        DuplicateCode = @()
        Statistics = @{
            TotalFiles = 0
            TotalLines = 0
            CodeLines = 0
            CommentLines = 0
            BlankLines = 0
        }
        ScanStartTime = $script:StartTime
    }

    # Get files to analyze
    $files = Get-FilesToAnalyze -Path $script:ProjectRoot -Exclude $ExcludePaths
    Write-AnalysisLog "Analyzing $($files.Count) files for code quality issues" -Component "CodeQuality"

    # Get patterns
    $todoPatterns = Get-TodoPatterns
    $hardcodedPatterns = Get-HardcodedPatterns

    # Process files in parallel
    $fileResults = Start-ParallelAnalysis -ScriptBlock {
        param($File)
        
        $result = @{
            Path = $File.FullName
            Issues = @{
                TODOs = @()
                FIXMEs = @()
                HACKs = @()
                XXXs = @()
                Deprecated = @()
                TechDebt = @()
                HardcodedValues = @()
            }
            Complexity = $null
            Errors = @()
        }
        
        try {
            $content = Get-Content $File.FullName -Raw

            # Search for comment-based issues
            $todoPatterns = @{
                TODOs = @('TODO:', 'TODO\s*\(', '\[TODO\]', '#\s*TODO')
                FIXMEs = @('FIXME:', 'FIXME\s*\(', '\[FIXME\]', '#\s*FIXME')
                HACKs = @('HACK:', 'HACK\s*\(', '\[HACK\]', '#\s*HACK')
                XXXs = @('XXX:', 'XXX\s*\(', '\[XXX\]')
                Deprecated = @('DEPRECATED:', '@deprecated', '\[DEPRECATED\]', '#\s*DEPRECATED')
                TechDebt = @('TECHDEBT:', 'TECH DEBT:', 'Technical Debt:', '\[TECHDEBT\]')
            }
            
            foreach ($category in $todoPatterns.GetEnumerator()) {
                foreach ($pattern in $category.Value) {
                    $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    foreach ($match in $matches) {
                        $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                        $line = ($content -split "`n")[$lineNumber - 1].Trim()
                        
                        $result.Issues[$category.Key] += @{
                            Line = $lineNumber
                            Content = $line
                            Pattern = $pattern
                        }
                    }
                }
            }

            # Search for hardcoded values
            $hardcodedPatterns = @(
                @{ Pattern = 'https?://localhost'; Type = 'LocalURL' }
                @{ Pattern = 'https?://127\.0\.0\.1'; Type = 'LocalIP' }
                @{ Pattern = '[Cc]:\\\\[^"''`\s]+'; Type = 'HardcodedPath' }
                @{ Pattern = 'password\s*=\s*["\''`][^"\''`]+["\''`]'; Type = 'HardcodedCredential' }
                @{ Pattern = 'apikey\s*=\s*["\''`][^"\''`]+["\''`]'; Type = 'HardcodedCredential' }
            )
        
            foreach ($patternInfo in $hardcodedPatterns) {
                $matches = [regex]::Matches($content, $patternInfo.Pattern)
                foreach ($match in $matches) {
                    $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                    
                    $result.Issues.HardcodedValues += @{
                        Line = $lineNumber
                        Value = $match.Value
                        Type = $patternInfo.Type
                    }
                }
            }

            # Parse AST for complexity analysis
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$parseErrors)

            if (-not $parseErrors -or $parseErrors.Count -eq 0) {
                # Analyze complexity
                $complexityInfo = @{
                    TotalLines = ($content -split "`n").Count
                    Functions = @()
                }
                
                $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
                
                foreach ($function in $functions) {
                    $funcInfo = @{
                        Name = $function.Name
                        Lines = $function.Extent.EndLineNumber - $function.Extent.StartLineNumber
                        StartLine = $function.Extent.StartLineNumber
                        Complexity = 1
                    }
                    
                    # Count control flow
                    $controlFlow = $function.FindAll({
                        $args[0] -is [System.Management.Automation.Language.IfStatementAst] -or
                        $args[0] -is [System.Management.Automation.Language.WhileStatementAst] -or
                        $args[0] -is [System.Management.Automation.Language.ForStatementAst] -or
                        $args[0] -is [System.Management.Automation.Language.ForEachStatementAst] -or
                        $args[0] -is [System.Management.Automation.Language.SwitchStatementAst]
                    }, $true)
                    
                    $funcInfo.Complexity += $controlFlow.Count
                    $complexityInfo.Functions += $funcInfo
                }
                
                $result.Complexity = $complexityInfo
            }
        } catch {
            $result.Errors += "Analysis error: $_"
        }
        
        return $result
    } -InputObject $files -MaxConcurrency 8 -JobName "CodeQualityAnalysis"

    # Process results
    foreach ($fileResult in $fileResults) {
        $issues.Statistics.TotalFiles++
        $relativePath = $fileResult.Path.Replace($script:ProjectRoot, '.')
        
        # Aggregate issues
        foreach ($category in @('TODOs', 'FIXMEs', 'HACKs', 'XXXs', 'Deprecated', 'TechDebt')) {
            foreach ($issue in $fileResult.Issues[$category]) {
                $issues[$category] += @{
                    File = $relativePath
                    Line = $issue.Line
                    Content = $issue.Content
                }
            }
        }
        
        # Aggregate hardcoded values
        foreach ($hardcoded in $fileResult.Issues.HardcodedValues) {
            $issues.HardcodedValues += @{
                File = $relativePath
                Line = $hardcoded.Line
                Value = $hardcoded.Value
                Type = $hardcoded.Type
            }
        }
        
        # Process complexity
        if ($fileResult.Complexity) {
            $issues.Statistics.TotalLines += $fileResult.Complexity.TotalLines
            
            foreach ($func in $fileResult.Complexity.Functions) {
                if ($func.Lines -gt $MaxFunctionLength) {
                    $issues.LongFunctions += @{
                        Function = $func.Name
                        File = $relativePath
                        Lines = $func.Lines
                        StartLine = $func.StartLine
                    }
                }
                
                if ($func.Complexity -gt $MaxComplexity) {
                    $issues.ComplexFunctions += @{
                        Function = $func.Name
                        File = $relativePath
                        Complexity = $func.Complexity
                        StartLine = $func.StartLine
                    }
                }
            }
        }
        
        if ($fileResult.Errors.Count -gt 0 -and $Detailed) {
            Write-AnalysisLog "Errors in $relativePath`: $($fileResult.Errors -join '; ')" -Component "CodeQuality" -Level Warning
        }
    }

    # Calculate summary statistics
    $issues.Summary = @{
        TotalIssues = $issues.TODOs.Count + $issues.FIXMEs.Count + $issues.HACKs.Count + 
                      $issues.XXXs.Count + $issues.Deprecated.Count + $issues.TechDebt.Count
        CriticalIssues = $issues.FIXMEs.Count + $issues.HACKs.Count + $issues.Deprecated.Count
        HardcodedValues = $issues.HardcodedValues.Count
        QualityScore = 100
    }

    # Calculate quality score (100 = perfect, 0 = worst)
    $deductions = 0
    $deductions += $issues.TODOs.Count * 0.5
    $deductions += $issues.FIXMEs.Count * 2
    $deductions += $issues.HACKs.Count * 3
    $deductions += $issues.Deprecated.Count * 2
    $deductions += $issues.HardcodedValues.Count * 1
    $deductions += $issues.LongFunctions.Count * 2
    $deductions += $issues.ComplexFunctions.Count * 3
    
    $issues.Summary.QualityScore = [Math]::Max(0, 100 - $deductions)
    
    $issues.ScanEndTime = Get-Date
    $issues.Duration = $issues.ScanEndTime - $issues.ScanStartTime
    
    return $issues
}

# Main execution
try {
    Write-AnalysisLog "=== Code Quality Analysis ===" -Component "CodeQuality"
    
    $results = Analyze-CodeQuality

    # Save results
    if ($PSCmdlet.ShouldProcess($OutputPath, "Save code quality analysis results")) {
        $outputFile = Save-AnalysisResults -AnalysisType "CodeQuality" -Results $results -OutputPath $OutputPath
    }

    # Display summary
    Write-Host "`nCode Quality Summary:" -ForegroundColor Cyan
    Write-Host "  Total Files: $($results.Statistics.TotalFiles)"
    Write-Host "  Total Lines: $($results.Statistics.TotalLines)"
    Write-Host "`n  Issues Found:" -ForegroundColor Yellow
    Write-Host "    TODOs: $($results.TODOs.Count)" -ForegroundColor $(if ($results.TODOs.Count -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "    FIXMEs: $($results.FIXMEs.Count)" -ForegroundColor $(if ($results.FIXMEs.Count -eq 0) { 'Green' } else { 'Red' })
    Write-Host "    HACKs: $($results.HACKs.Count)" -ForegroundColor $(if ($results.HACKs.Count -eq 0) { 'Green' } else { 'Red' })
    Write-Host "    Deprecated: $($results.Deprecated.Count)" -ForegroundColor $(if ($results.Deprecated.Count -eq 0) { 'Green' } else { 'Red' })
    Write-Host "    Tech Debt: $($results.TechDebt.Count)" -ForegroundColor $(if ($results.TechDebt.Count -eq 0) { 'Green' } else { 'Yellow' })
    
    Write-Host "`n  Code Complexity:" -ForegroundColor Yellow
    Write-Host "    Long Functions: $($results.LongFunctions.Count)" -ForegroundColor $(if ($results.LongFunctions.Count -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "    Complex Functions: $($results.ComplexFunctions.Count)" -ForegroundColor $(if ($results.ComplexFunctions.Count -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "    Hardcoded Values: $($results.HardcodedValues.Count)" -ForegroundColor $(if ($results.HardcodedValues.Count -eq 0) { 'Green' } else { 'Yellow' })
    
    Write-Host "`n  Quality Score: $($results.Summary.QualityScore)/100" -ForegroundColor $(
        if ($results.Summary.QualityScore -ge 80) { 'Green' }
        elseif ($results.Summary.QualityScore -ge 60) { 'Yellow' }
        else { 'Red' }
    )

    Write-Host "  Analysis Duration: $($results.Duration.TotalSeconds.ToString('F2')) seconds"

    if ($Detailed -and $results.Summary.CriticalIssues -gt 0) {
        Write-Host "`nCritical Issues to Address:" -ForegroundColor Red
        $criticalIssues = @()
        $criticalIssues += $results.FIXMEs | ForEach-Object { "FIXME: $($_.File):$($_.Line) - $($_.Content)" }
        $criticalIssues += $results.HACKs | ForEach-Object { "HACK: $($_.File):$($_.Line) - $($_.Content)" }
        $criticalIssues | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
    }
    
    Write-Host "`nDetailed results saved to: $outputFile" -ForegroundColor Green
    
    exit 0
} catch {
    Write-AnalysisLog "Code quality analysis failed: $_" -Component "CodeQuality" -Level Error
    Write-AnalysisLog "Stack trace: $($_.ScriptStackTrace)" -Component "CodeQuality" -Level Error
    exit 1
}