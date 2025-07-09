function Get-AnalysisStatus {
    <#
    .SYNOPSIS
        Gets PSScriptAnalyzer analysis status for directories or modules

    .DESCRIPTION
        Retrieves and displays PSScriptAnalyzer analysis status from .pssa-status files,
        with options for rollup reporting and filtering by status or quality thresholds.

    .PARAMETER Path
        Directory path to get status for. Defaults to current directory.

    .PARAMETER Rollup
        Whether to provide rollup summary across multiple directories (default: false)

    .PARAMETER Recurse
        Whether to recursively search subdirectories for status files (default: true)

    .PARAMETER StatusFilter
        Filter by status: 'good', 'warnings', 'needs-attention', 'critical' (optional)

    .PARAMETER MinQualityScore
        Minimum quality score threshold for filtering results (0-100)

    .PARAMETER ShowDetails
        Whether to show detailed findings breakdown (default: false)

    .PARAMETER Format
        Output format: 'Table', 'JSON', 'Summary' (default: 'Table')

    .PARAMETER ExportPath
        Path to export results (optional)

    .EXAMPLE
        Get-AnalysisStatus -Path "./aither-core/modules" -Rollup

        Gets rollup status for all modules

    .EXAMPLE
        Get-AnalysisStatus -Path "." -StatusFilter "critical" -ShowDetails

        Shows detailed status for directories with critical findings

    .EXAMPLE
        Get-AnalysisStatus -Path "./aither-core" -MinQualityScore 80 -Format JSON -ExportPath "./quality-report.json"

        Gets status for directories with quality score >= 80 and exports as JSON
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = ".",

        [Parameter(Mandatory = $false)]
        [switch]$Rollup,

        [Parameter(Mandatory = $false)]
        [bool]$Recurse = $true,

        [Parameter(Mandatory = $false)]
        [ValidateSet('good', 'warnings', 'needs-attention', 'critical')]
        [string]$StatusFilter,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 100)]
        [int]$MinQualityScore,

        [Parameter(Mandatory = $false)]
        [switch]$ShowDetails,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Table', 'JSON', 'Summary')]
        [string]$Format = 'Table',

        [Parameter(Mandatory = $false)]
        [string]$ExportPath
    )

    try {
        $resolvedPath = Resolve-Path $Path -ErrorAction Stop

        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'INFO' -Message "Getting analysis status for: $resolvedPath"
        }

        # Find all .pssa-status files
        $statusFiles = Get-ChildItem -Path $resolvedPath -Name $script:DefaultSettings.StatusFileName -Recurse:$Recurse -ErrorAction SilentlyContinue

        if ($statusFiles.Count -eq 0) {
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'WARNING' -Message "No .pssa-status files found in $resolvedPath"
            } else {
                Write-Warning "No .pssa-status files found. Run Start-DirectoryAudit first to generate status files."
            }
            return $null
        }

        # Load status data
        $statusData = @()
        foreach ($statusFile in $statusFiles) {
            $statusFilePath = Join-Path $resolvedPath $statusFile.FullName
            try {
                $content = Get-Content $statusFilePath | ConvertFrom-Json

                # Add computed properties
                $content | Add-Member -NotePropertyName 'StatusFile' -NotePropertyValue $statusFilePath
                $content | Add-Member -NotePropertyName 'DirectoryName' -NotePropertyValue (Split-Path $content.directory -Leaf)
                $content | Add-Member -NotePropertyName 'RelativePath' -NotePropertyValue ($content.directory -replace [regex]::Escape($resolvedPath.Path), '' -replace '^[\\\/]', '')

                # Calculate age
                if ($content.lastAnalysis) {
                    $lastAnalysis = [DateTime]::Parse($content.lastAnalysis)
                    $age = (Get-Date) - $lastAnalysis
                    $content | Add-Member -NotePropertyName 'AnalysisAge' -NotePropertyValue $age
                    $content | Add-Member -NotePropertyName 'AnalysisAgeDisplay' -NotePropertyValue (
                        if ($age.TotalDays -gt 1) {
                            "$([math]::Round($age.TotalDays, 1)) days"
                        } elseif ($age.TotalHours -gt 1) {
                            "$([math]::Round($age.TotalHours, 1)) hours"
                        } else {
                            "$([math]::Round($age.TotalMinutes, 1)) minutes"
                        }
                    )
                } else {
                    $content | Add-Member -NotePropertyName 'AnalysisAge' -NotePropertyValue $null
                    $content | Add-Member -NotePropertyName 'AnalysisAgeDisplay' -NotePropertyValue 'Unknown'
                }

                $statusData += $content
            }
            catch {
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'WARNING' -Message "Failed to load status file ${statusFilePath}: $($_.Exception.Message)"
                }
            }
        }

        # Apply filters
        if ($StatusFilter) {
            $statusData = $statusData | Where-Object { $_.status -eq $StatusFilter }
        }

        if ($PSBoundParameters.ContainsKey('MinQualityScore')) {
            $statusData = $statusData | Where-Object { $_.qualityScore -ge $MinQualityScore }
        }

        if ($statusData.Count -eq 0) {
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'INFO' -Message "No status data matches the specified filters"
            } else {
                Write-Host "No status data matches the specified filters." -ForegroundColor Yellow
            }
            return $null
        }

        # Sort by quality score (lowest first to highlight issues)
        $statusData = $statusData | Sort-Object qualityScore, @{Expression={$_.findings.errors}; Descending=$true}

        # Prepare output based on format
        if ($Rollup) {
            # Calculate rollup statistics
            $rollupData = @{
                TotalDirectories = $statusData.Count
                TotalFiles = ($statusData | Measure-Object -Property totalFiles -Sum).Sum
                TotalAnalyzedFiles = ($statusData | Measure-Object -Property analyzedFiles -Sum).Sum
                TotalFindings = ($statusData | ForEach-Object { $_.findings.errors + $_.findings.warnings + $_.findings.information } | Measure-Object -Sum).Sum
                TotalErrors = ($statusData | ForEach-Object { $_.findings.errors } | Measure-Object -Sum).Sum
                TotalWarnings = ($statusData | ForEach-Object { $_.findings.warnings } | Measure-Object -Sum).Sum
                TotalInformation = ($statusData | ForEach-Object { $_.findings.information } | Measure-Object -Sum).Sum
                AverageQualityScore = if ($statusData.Count -gt 0) { ($statusData | Measure-Object -Property qualityScore -Average).Average } else { 0 }
                StatusBreakdown = @{
                    Good = ($statusData | Where-Object { $_.status -eq 'good' }).Count
                    Warnings = ($statusData | Where-Object { $_.status -eq 'warnings' }).Count
                    NeedsAttention = ($statusData | Where-Object { $_.status -eq 'needs-attention' }).Count
                    Critical = ($statusData | Where-Object { $_.status -eq 'critical' }).Count
                }
                OldestAnalysis = if ($statusData.AnalysisAge) { ($statusData | Sort-Object AnalysisAge -Descending | Select-Object -First 1).AnalysisAgeDisplay } else { 'Unknown' }
                NewestAnalysis = if ($statusData.AnalysisAge) { ($statusData | Sort-Object AnalysisAge | Select-Object -First 1).AnalysisAgeDisplay } else { 'Unknown' }
            }

            $rollupData.OverallStatus = if ($rollupData.TotalErrors -gt 0) {
                'critical'
            } elseif ($rollupData.StatusBreakdown.Critical -gt 0) {
                'critical'
            } elseif ($rollupData.StatusBreakdown.NeedsAttention -gt 0) {
                'needs-attention'
            } elseif ($rollupData.StatusBreakdown.Warnings -gt 0) {
                'warnings'
            } else {
                'good'
            }

            switch ($Format) {
                'JSON' {
                    $output = $rollupData | ConvertTo-Json -Depth 5
                }
                'Summary' {
                    $output = @"
📊 PSScriptAnalyzer Status Rollup
=====================================
📁 Directories: $($rollupData.TotalDirectories)
📄 Files: $($rollupData.TotalAnalyzedFiles)/$($rollupData.TotalFiles)
🔍 Total Findings: $($rollupData.TotalFindings)
❌ Errors: $($rollupData.TotalErrors)
⚠️  Warnings: $($rollupData.TotalWarnings)
ℹ️  Information: $($rollupData.TotalInformation)
⭐ Average Score: $([math]::Round($rollupData.AverageQualityScore, 1))%
🎯 Overall Status: $($rollupData.OverallStatus.ToUpper())

Status Breakdown:
✅ Good: $($rollupData.StatusBreakdown.Good)
⚠️  Warnings: $($rollupData.StatusBreakdown.Warnings)
🔶 Needs Attention: $($rollupData.StatusBreakdown.NeedsAttention)
🔴 Critical: $($rollupData.StatusBreakdown.Critical)

Analysis Age:
🕐 Oldest: $($rollupData.OldestAnalysis) ago
🕐 Newest: $($rollupData.NewestAnalysis) ago
"@
                }
                default {
                    # Table format for rollup
                    $tableData = [PSCustomObject]@{
                        'Total Directories' = $rollupData.TotalDirectories
                        'Files Analyzed' = "$($rollupData.TotalAnalyzedFiles)/$($rollupData.TotalFiles)"
                        'Total Findings' = $rollupData.TotalFindings
                        'Errors' = $rollupData.TotalErrors
                        'Warnings' = $rollupData.TotalWarnings
                        'Information' = $rollupData.TotalInformation
                        'Avg Quality Score' = "$([math]::Round($rollupData.AverageQualityScore, 1))%"
                        'Overall Status' = $rollupData.OverallStatus
                    }
                    $output = $tableData
                }
            }
        } else {
            # Detailed directory listing
            switch ($Format) {
                'JSON' {
                    $output = if ($ShowDetails) {
                        $statusData | ConvertTo-Json -Depth 10
                    } else {
                        $statusData | Select-Object DirectoryName, status, qualityScore, findings, AnalysisAgeDisplay | ConvertTo-Json -Depth 5
                    }
                }
                'Summary' {
                    $output = $statusData | ForEach-Object {
                        $emoji = switch ($_.status) {
                            'good' { '✅' }
                            'warnings' { '⚠️' }
                            'needs-attention' { '🔶' }
                            'critical' { '🔴' }
                            default { '❓' }
                        }

                        $details = if ($ShowDetails -and $_.ruleBreakdown -and $_.ruleBreakdown.Count -gt 0) {
                            "`n    Top Issues: " + (($_.ruleBreakdown.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 3 | ForEach-Object { "$($_.Key)($($_.Value))" }) -join ', ')
                        } else {
                            ""
                        }

                        "$emoji $($_.DirectoryName) - Score: $($_.qualityScore)% | E:$($_.findings.errors) W:$($_.findings.warnings) I:$($_.findings.information) | Age: $($_.AnalysisAgeDisplay)$details"
                    }
                    $output = $output -join "`n"
                }
                default {
                    # Table format
                    if ($ShowDetails) {
                        $output = $statusData | Select-Object DirectoryName, status, qualityScore,
                            @{Name='Errors'; Expression={$_.findings.errors}},
                            @{Name='Warnings'; Expression={$_.findings.warnings}},
                            @{Name='Information'; Expression={$_.findings.information}},
                            @{Name='Files'; Expression={"$($_.analyzedFiles)/$($_.totalFiles)"}},
                            AnalysisAgeDisplay,
                            @{Name='TopRule'; Expression={
                                if ($_.ruleBreakdown -and $_.ruleBreakdown.Count -gt 0) {
                                    ($_.ruleBreakdown.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
                                } else {
                                    'None'
                                }
                            }}
                    } else {
                        $output = $statusData | Select-Object DirectoryName, status,
                            @{Name='Score'; Expression={"$($_.qualityScore)%"}},
                            @{Name='E'; Expression={$_.findings.errors}},
                            @{Name='W'; Expression={$_.findings.warnings}},
                            @{Name='I'; Expression={$_.findings.information}},
                            @{Name='Files'; Expression={"$($_.analyzedFiles)/$($_.totalFiles)"}},
                            @{Name='Age'; Expression={$_.AnalysisAgeDisplay}}
                    }
                }
            }
        }

        # Export if requested
        if ($ExportPath) {
            try {
                if ($Format -eq 'JSON') {
                    $output | Set-Content -Path $ExportPath -Encoding UTF8
                } else {
                    $output | Out-String | Set-Content -Path $ExportPath -Encoding UTF8
                }

                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'INFO' -Message "Exported analysis status to: $ExportPath"
                } else {
                    Write-Host "📄 Exported analysis status to: $ExportPath" -ForegroundColor Green
                }
            }
            catch {
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'ERROR' -Message "Failed to export status: $($_.Exception.Message)"
                } else {
                    Write-Error "Failed to export status: $($_.Exception.Message)"
                }
            }
        }

        return $output
    }
    catch {
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get analysis status: $($_.Exception.Message)"
        } else {
            Write-Error "Failed to get analysis status: $($_.Exception.Message)"
        }
        throw
    }
}
