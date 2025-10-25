#Requires -Version 7.0
<#
.SYNOPSIS
    Analyzes documentation coverage across the codebase
.DESCRIPTION
    Scans PowerShell files to check for comment-based help, README files,
    and identifies missing or outdated documentation
#>

# Script metadata
# Stage: Reporting
# Dependencies: 0400
# Description: Documentation coverage analysis for tech debt reporting
# Tags: reporting, tech-debt, documentation, analysis

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = ".",
    [string]$OutputPath = "./reports/tech-debt/analysis",
    [switch]$UseCache = $true,
    [switch]$Detailed = $false,
    [switch]$CheckOutdated = $true,
    [string[]]$ExcludePaths = @('tests', 'legacy-to-migrate', 'examples', 'reports', '.git')
)

# Initialize
$ErrorActionPreference = 'Stop'
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:StartTime = Get-Date

# Import modules
Import-Module (Join-Path $script:ProjectRoot 'domains/infrastructure/Infrastructure.psm1') -Force
Import-Module (Join-Path $script:ProjectRoot 'domains/core/Logging.psm1') -Force -ErrorAction SilentlyContinue

# Initialize analysis
if ($PSCmdlet.ShouldProcess($OutputPath, "Initialize tech debt analysis results directory")) {
    Initialize-SecurityConfiguration -ResultsPath $OutputPath
}

function Analyze-DocumentationCoverage {
    Write-AnalysisLog "Starting documentation coverage analysis..." -Component "DocCoverage"

    # Initialize results
    $coverage = @{
        Modules = @{}
        Functions = @{}
        Scripts = @{}
        TotalFiles = 0
        DocumentedFiles = 0
        TotalFunctions = 0
        DocumentedFunctions = 0
        MissingDocs = @()
        OutdatedDocs = @()
        READMEStatus = @()
        ScanStartTime = $script:StartTime
    }

    # Get files to analyze
    $files = Get-FilesToAnalyze -Path $script:ProjectRoot -Exclude $ExcludePaths
    Write-AnalysisLog "Analyzing $($files.Count) files for documentation coverage" -Component "DocCoverage"

    # Process files in parallel
    $fileResults = Start-ParallelAnalysis -ScriptBlock {
        param($File)

        $result = @{
            Path = $File.FullName
            HasFileDoc = $false
            Functions = @()
            Errors = @()
        }

        try {
            $content = Get-Content $File.FullName -Raw

            # Check for file-level documentation
            if ($content -match '<#[\s\S]*?\.SYNOPSIS[\s\S]*?#>') {
                $result.HasFileDoc = $true
            }

            # Parse AST
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$parseErrors)

            if ($parseErrors -and $parseErrors.Count -gt 0) {
                $result.Errors += "Parse errors: $($parseErrors.Count)"
                return $result
            }

            # Find functions
            $functions = $ast.FindAll({ $arguments[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

            foreach ($function in $functions) {
                $funcInfo = @{
                    Name = $function.Name
                    HasDoc = $false
                    MissingParams = @()
                    StartLine = $function.Extent.StartLineNumber
                    EndLine = $function.Extent.EndLineNumber
                }

                # Extract function content
                $funcContent = $content.Substring($function.Extent.StartOffset, $function.Extent.EndOffset - $function.Extent.StartOffset)

                # Check for comment-based help
                if ($funcContent -match '<#[\s\S]*?\.SYNOPSIS[\s\S]*?#>' -or $funcContent -match '\.SYNOPSIS') {
                    $funcInfo.HasDoc = $true

                    # Check parameter documentation
                    if ($function.Body -and $function.Body.ParamBlock -and $function.Body.ParamBlock.Parameters) {
                        $params = $function.Body.ParamBlock.Parameters
                        $docParams = [regex]::Matches($funcContent, '\.PARAMETER\s+(\w+)')
                        $docParamNames = $docParams | ForEach-Object { $_.Groups[1].Value }

                        foreach ($param in $params) {
                            $paramName = $param.Name.VariablePath.UserPath
                            if ($docParamNames -notcontains $paramName) {
                                $funcInfo.MissingParams += $paramName
                            }
                        }
                    }
                }

                $result.Functions += $funcInfo
            }
        } catch {
            $result.Errors += "Analysis error: $_"
        }

        return $result
    } -InputObject $files -MaxConcurrency 8 -JobName "DocAnalysis"

    # Process results
    foreach ($fileResult in $fileResults) {
        $coverage.TotalFiles++
        $relativePath = $fileResult.Path.Replace($script:ProjectRoot, '.')

        if ($fileResult.HasFileDoc) {
            $coverage.DocumentedFiles++
        } else {
            $coverage.MissingDocs += @{
                Type = 'File'
                Path = $relativePath
                Issue = 'No file-level documentation'
            }
        }

        foreach ($func in $fileResult.Functions) {
            $coverage.TotalFunctions++

            if ($func.HasDoc) {
                $coverage.DocumentedFunctions++

                if ($func.MissingParams.Count -gt 0) {
                    $coverage.OutdatedDocs += @{
                        Type = 'Function'
                        Name = $func.Name
                        Path = $relativePath
                        Issue = "Missing parameter documentation: $($func.MissingParams -join ', ')"
                        Line = $func.StartLine
                    }
                }
            } else {
                $coverage.MissingDocs += @{
                    Type = 'Function'
                    Name = $func.Name
                    Path = $relativePath
                    Issue = 'No comment-based help'
                    Line = $func.StartLine
                }
            }
        }

        if ($fileResult.Errors.Count -gt 0 -and $Detailed) {
            Write-AnalysisLog "Errors in $relativePath`: $($fileResult.Errors -join '; ')" -Component "DocCoverage" -Level Warning
        }
    }

    # Check for README files in each domain/module directory
    Write-AnalysisLog "Checking for README files..." -Component "DocCoverage"

    $moduleDirectories = @()
    $moduleDirectories += Get-ChildItem -Path (Join-Path $script:ProjectRoot "domains") -Directory -ErrorAction SilentlyContinue
    $moduleDirectories += Get-ChildItem -Path (Join-Path $script:ProjectRoot "modules") -Directory -ErrorAction SilentlyContinue
    $moduleDirectories += Get-ChildItem -Path (Join-Path $script:ProjectRoot "automation-scripts") -Directory -ErrorAction SilentlyContinue

    foreach ($dir in $moduleDirectories) {
        $readmePath = Join-Path $dir.FullName "README.md"
        $relativeDirPath = $dir.FullName.Replace($script:ProjectRoot, '.')

        if (-not (Test-Path $readmePath)) {
            $coverage.MissingDocs += @{
                Type = 'README'
                Path = $relativeDirPath
                Issue = 'Missing README.md'
            }
            $coverage.READMEStatus += @{
                Directory = $relativeDirPath
                HasREADME = $false
                Status = 'Missing'
            }
        } else {
            $readmeInfo = @{
                Directory = $relativeDirPath
                HasREADME = $true
                Status = 'Present'
                LastModified = (Get-Item $readmePath).LastWriteTime
            }

            if ($CheckOutdated) {
                # Check if README is outdated compared to module files
                $moduleFiles = Get-ChildItem $dir.FullName -Filter "*.psm1" -File
                $newerFiles = $moduleFiles | Where-Object { $_.LastWriteTime -gt $readmeInfo.LastModified }

                if ($newerFiles) {
                    $readmeInfo.Status = 'Outdated'
                    $coverage.OutdatedDocs += @{
                        Type = 'README'
                        Path = $readmePath.Replace($script:ProjectRoot, '.')
                        Issue = "Outdated - $($newerFiles.Count) module file(s) modified after README"
                        ModuleDate = ($newerFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
                        ReadmeDate = $readmeInfo.LastModified
                    }
                }
            }

            $coverage.READMEStatus += $readmeInfo
        }
    }

    # Calculate coverage percentages
    $coverage.FileCoveragePercentage = if ($coverage.TotalFiles -gt 0) {
        [Math]::Round(($coverage.DocumentedFiles / $coverage.TotalFiles) * 100, 2)
    } else { 0 }

    $coverage.FunctionCoveragePercentage = if ($coverage.TotalFunctions -gt 0) {
        [Math]::Round(($coverage.DocumentedFunctions / $coverage.TotalFunctions) * 100, 2)
    } else { 0 }

    $coverage.OverallCoveragePercentage = if (($coverage.TotalFiles + $coverage.TotalFunctions) -gt 0) {
        [Math]::Round((($coverage.DocumentedFiles + $coverage.DocumentedFunctions) / ($coverage.TotalFiles + $coverage.TotalFunctions)) * 100, 2)
    } else { 0 }

    $coverage.ScanEndTime = Get-Date
    $coverage.Duration = $coverage.ScanEndTime - $coverage.ScanStartTime

    return $coverage
}

# Main execution
try {
    Write-AnalysisLog "=== Documentation Coverage Analysis ===" -Component "DocCoverage"

    $results = Analyze-DocumentationCoverage

    # Save results
    if ($PSCmdlet.ShouldProcess($OutputPath, "Save documentation coverage analysis results")) {
        $outputFile = Save-AnalysisResults -AnalysisType "DocumentationCoverage" -Results $results -OutputPath $OutputPath
    }

    # Display summary
    Write-Host "`nDocumentation Coverage Summary:" -ForegroundColor Cyan
    Write-Host "  Files: $($results.DocumentedFiles)/$($results.TotalFiles) ($($results.FileCoveragePercentage)%)" -ForegroundColor $(
        if ($results.FileCoveragePercentage -ge 80) { 'Green' }
        elseif ($results.FileCoveragePercentage -ge 60) { 'Yellow' }
        else { 'Red' }
    )
Write-Host "  Functions: $($results.DocumentedFunctions)/$($results.TotalFunctions) ($($results.FunctionCoveragePercentage)%)" -ForegroundColor $(
        if ($results.FunctionCoveragePercentage -ge 80) { 'Green' }
        elseif ($results.FunctionCoveragePercentage -ge 60) { 'Yellow' }
        else { 'Red' }
    )
Write-Host "  Overall Coverage: $($results.OverallCoveragePercentage)%" -ForegroundColor $(
        if ($results.OverallCoveragePercentage -ge 80) { 'Green' }
        elseif ($results.OverallCoveragePercentage -ge 60) { 'Yellow' }
        else { 'Red' }
    )

    Write-Host "`n  Missing Documentation: $($results.MissingDocs.Count) items" -ForegroundColor $(if ($results.MissingDocs.Count -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "  Outdated Documentation: $($results.OutdatedDocs.Count) items" -ForegroundColor $(if ($results.OutdatedDocs.Count -eq 0) { 'Green' } else { 'Yellow' })

    $missingReadmes = $results.READMEStatus | Where-Object { $_.Status -eq 'Missing' }
    Write-Host "  Missing READMEs: $($missingReadmes.Count)" -ForegroundColor $(if ($missingReadmes.Count -eq 0) { 'Green' } else { 'Yellow' })

    Write-Host "  Analysis Duration: $($results.Duration.TotalSeconds.ToString('F2')) seconds"

    if ($Detailed -and $results.MissingDocs.Count -gt 0) {
        Write-Host "`nTop Missing Documentation:" -ForegroundColor Yellow
        $results.MissingDocs | Select-Object -First 10 | ForEach-Object {
            Write-Host "  - $($_.Type): $(if ($_.Name) { $_.Name + ' in ' })$($_.Path)"
        }
    }

    Write-Host "`nDetailed results saved to: $outputFile" -ForegroundColor Green

    exit 0
} catch {
    Write-AnalysisLog "Documentation coverage analysis failed: $_" -Component "DocCoverage" -Level Error
    Write-AnalysisLog "Stack trace: $($_.ScriptStackTrace)" -Component "DocCoverage" -Level Error
    exit 1
}

