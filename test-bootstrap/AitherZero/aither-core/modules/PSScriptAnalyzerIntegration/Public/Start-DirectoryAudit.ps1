function Start-DirectoryAudit {
    <#
    .SYNOPSIS
        Starts a comprehensive PSScriptAnalyzer audit of a directory or module
    
    .DESCRIPTION
        Performs automated PSScriptAnalyzer analysis on PowerShell files within a directory,
        creates or updates status tracking files, and generates bug tracking files.
        Supports recursive analysis and parallel processing for large codebases.
    
    .PARAMETER Path
        Directory path to audit. Defaults to current directory.
    
    .PARAMETER ModuleName
        Optional module name for context-specific analysis rules
    
    .PARAMETER Recurse
        Whether to recursively analyze subdirectories (default: true)
    
    .PARAMETER IncludeTests
        Whether to include test files in analysis (default: false)
    
    .PARAMETER UpdateDocumentation
        Whether to generate missing README.md files (default: false)
    
    .PARAMETER Parallel
        Whether to use parallel processing for multiple directories (default: true)
    
    .PARAMETER ReportFormat
        Output report format: JSON, HTML, XML (default: JSON)
    
    .PARAMETER ExportPath
        Path to export consolidated report (optional)
    
    .PARAMETER Force
        Force overwrite of existing status files
    
    .EXAMPLE
        Start-DirectoryAudit -Path "./aither-core/modules" -Recurse -UpdateDocumentation
        
        Audits all modules in the aither-core/modules directory recursively and generates missing documentation
    
    .EXAMPLE
        Start-DirectoryAudit -Path "./aither-core/modules/PatchManager" -ModuleName "PatchManager" -IncludeTests
        
        Audits the PatchManager module including test files
    
    .EXAMPLE
        Start-DirectoryAudit -Path "." -ReportFormat HTML -ExportPath "./audit-report.html"
        
        Audits current directory and exports HTML report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path = ".",
        
        [Parameter(Mandatory = $false)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $false)]
        [bool]$Recurse = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludeTests = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$UpdateDocumentation = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$Parallel = $true,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('JSON', 'HTML', 'XML')]
        [string]$ReportFormat = 'JSON',
        
        [Parameter(Mandatory = $false)]
        [string]$ExportPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    try {
        $resolvedPath = Resolve-Path $Path -ErrorAction Stop
        
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'INFO' -Message "Starting comprehensive directory audit for: $resolvedPath"
        } else {
            Write-Host "🔍 Starting PSScriptAnalyzer audit for: $resolvedPath" -ForegroundColor Cyan
        }
        
        # Initialize audit results
        $auditResults = @{
            StartTime = Get-Date
            Path = $resolvedPath.Path
            Configuration = @{
                Recurse = $Recurse
                IncludeTests = $IncludeTests
                UpdateDocumentation = $UpdateDocumentation
                Parallel = $Parallel
                ReportFormat = $ReportFormat
            }
            DirectoryResults = @()
            Summary = @{
                DirectoriesAnalyzed = 0
                FilesAnalyzed = 0
                TotalFindings = 0
                ErrorCount = 0
                WarningCount = 0
                InformationCount = 0
                OverallStatus = 'unknown'
                QualityScore = 0
            }
            Errors = @()
        }
        
        # Discover directories to analyze
        $directoriesToAnalyze = @()
        
        if ($Recurse) {
            # Find all directories containing PowerShell files
            $psFiles = Get-ChildItem -Path $resolvedPath -Include *.ps1,*.psm1,*.psd1 -Recurse -File -ErrorAction SilentlyContinue
            $uniqueDirectories = $psFiles | ForEach-Object { $_.Directory.FullName } | Select-Object -Unique | Sort-Object
            
            foreach ($dir in $uniqueDirectories) {
                $directoriesToAnalyze += @{
                    Path = $dir
                    ModuleName = if ($dir -like "*modules*") {
                        Split-Path $dir -Leaf
                    } else {
                        $null
                    }
                }
            }
        } else {
            # Analyze only the specified directory
            $directoriesToAnalyze += @{
                Path = $resolvedPath.Path
                ModuleName = $ModuleName
            }
        }
        
        if ($directoriesToAnalyze.Count -eq 0) {
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'WARNING' -Message "No directories with PowerShell files found"
            } else {
                Write-Warning "No directories with PowerShell files found"
            }
            return $auditResults
        }
        
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'INFO' -Message "Found $($directoriesToAnalyze.Count) directories to analyze"
        } else {
            Write-Host "📁 Found $($directoriesToAnalyze.Count) directories to analyze" -ForegroundColor Green
        }
        
        # Process directories
        if ($Parallel -and $directoriesToAnalyze.Count -gt 1) {
            # Parallel processing
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'INFO' -Message "Using parallel processing for directory analysis"
            } else {
                Write-Host "⚡ Using parallel processing..." -ForegroundColor Yellow
            }
            
            $jobs = @()
            foreach ($directory in $directoriesToAnalyze) {
                $job = Start-Job -ScriptBlock {
                    param($DirPath, $ModName, $IncTests, $ScriptRoot)
                    
                    # Import module in job context
                    Import-Module "$ScriptRoot/PSScriptAnalyzerIntegration.psd1" -Force
                    
                    return Invoke-DirectoryAnalysis -Path $DirPath -ModuleName $ModName -IncludeTests $IncTests
                } -ArgumentList $directory.Path, $directory.ModuleName, $IncludeTests, $PSScriptRoot
                
                $jobs += $job
            }
            
            # Wait for jobs and collect results
            $completed = 0
            while ($jobs | Where-Object { $_.State -eq 'Running' }) {
                $finishedJobs = $jobs | Where-Object { $_.State -eq 'Completed' }
                if ($finishedJobs.Count -gt $completed) {
                    $completed = $finishedJobs.Count
                    if (-not $script:UseCustomLogging) {
                        Write-Host "✅ Completed: $completed/$($jobs.Count)" -ForegroundColor Green
                    }
                }
                Start-Sleep -Milliseconds 500
            }
            
            # Collect all results
            foreach ($job in $jobs) {
                try {
                    $result = Receive-Job -Job $job -ErrorAction Stop
                    $auditResults.DirectoryResults += $result
                }
                catch {
                    $auditResults.Errors += "Job failed: $($_.Exception.Message)"
                    if ($script:UseCustomLogging) {
                        Write-CustomLog -Level 'ERROR' -Message "Parallel job failed: $($_.Exception.Message)"
                    }
                }
                finally {
                    Remove-Job -Job $job -Force
                }
            }
        } else {
            # Sequential processing
            $completed = 0
            foreach ($directory in $directoriesToAnalyze) {
                try {
                    if (-not $script:UseCustomLogging) {
                        $completed++
                        Write-Host "📊 Analyzing [$completed/$($directoriesToAnalyze.Count)]: $($directory.Path)" -ForegroundColor Cyan
                    }
                    
                    $result = Invoke-DirectoryAnalysis -Path $directory.Path -ModuleName $directory.ModuleName -IncludeTests $IncludeTests
                    $auditResults.DirectoryResults += $result
                }
                catch {
                    $auditResults.Errors += "Analysis failed for $($directory.Path): $($_.Exception.Message)"
                    if ($script:UseCustomLogging) {
                        Write-CustomLog -Level 'ERROR' -Message "Analysis failed for $($directory.Path): $($_.Exception.Message)"
                    }
                }
            }
        }
        
        # Calculate summary statistics
        foreach ($result in $auditResults.DirectoryResults) {
            $auditResults.Summary.DirectoriesAnalyzed++
            $auditResults.Summary.FilesAnalyzed += $result.FilesAnalyzed
            $auditResults.Summary.TotalFindings += $result.Summary.Total
            $auditResults.Summary.ErrorCount += $result.Summary.Errors
            $auditResults.Summary.WarningCount += $result.Summary.Warnings
            $auditResults.Summary.InformationCount += $result.Summary.Information
        }
        
        # Calculate overall status and quality score
        $auditResults.Summary.OverallStatus = if ($auditResults.Summary.ErrorCount -gt 0) {
            'critical'
        } elseif ($auditResults.Summary.WarningCount -gt ($script:QualityThresholds.WarningThreshold * $auditResults.Summary.DirectoriesAnalyzed)) {
            'needs-attention'
        } elseif ($auditResults.Summary.WarningCount -gt 0) {
            'warnings'
        } elseif ($auditResults.Summary.InformationCount -gt ($script:QualityThresholds.InfoThreshold * $auditResults.Summary.DirectoriesAnalyzed)) {
            'review-recommended'
        } else {
            'good'
        }
        
        $auditResults.Summary.QualityScore = [math]::Max(0, 100 - 
            ($auditResults.Summary.ErrorCount * 10) - 
            ($auditResults.Summary.WarningCount * 2) - 
            ($auditResults.Summary.InformationCount * 0.5))
        
        $auditResults.EndTime = Get-Date
        $auditResults.Duration = ($auditResults.EndTime - $auditResults.StartTime).TotalMilliseconds
        
        # Update documentation if requested
        if ($UpdateDocumentation) {
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'INFO' -Message "Updating documentation for analyzed directories"
            } else {
                Write-Host "📝 Updating documentation..." -ForegroundColor Yellow
            }
            
            foreach ($result in $auditResults.DirectoryResults) {
                $readmePath = Join-Path $result.Path "README.md"
                if (-not (Test-Path $readmePath)) {
                    try {
                        $readmeContent = @"
# $($result.ModuleName -or (Split-Path $result.Path -Leaf))

## Overview
This directory contains PowerShell code that has been analyzed by PSScriptAnalyzer.

## Code Quality Status
- **Quality Score**: $([math]::Round((100 - ($result.Summary.Errors * 10) - ($result.Summary.Warnings * 2) - ($result.Summary.Information * 0.5)), 1))%
- **Status**: $($result.Status)
- **Files Analyzed**: $($result.FilesAnalyzed)
- **Findings**: $($result.Summary.Total) ($($result.Summary.Errors) errors, $($result.Summary.Warnings) warnings, $($result.Summary.Information) info)

## Files
- `.pssa-status` - PSScriptAnalyzer analysis status
- `.bugz` - Bug tracking for code quality findings

*This README was auto-generated by PSScriptAnalyzerIntegration on $(Get-Date -Format 'yyyy-MM-dd')*
"@
                        Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
                        if ($script:UseCustomLogging) {
                            Write-CustomLog -Level 'INFO' -Message "Generated README.md for $($result.Path)"
                        }
                    }
                    catch {
                        if ($script:UseCustomLogging) {
                            Write-CustomLog -Level 'WARNING' -Message "Failed to generate README.md for $($result.Path): $($_.Exception.Message)"
                        }
                    }
                }
            }
        }
        
        # Export report if requested
        if ($ExportPath) {
            try {
                switch ($ReportFormat) {
                    'JSON' {
                        $auditResults | ConvertTo-Json -Depth 10 | Set-Content -Path $ExportPath -Encoding UTF8
                    }
                    'HTML' {
                        $htmlReport = New-QualityReport -AuditResults $auditResults -Format HTML
                        Set-Content -Path $ExportPath -Value $htmlReport -Encoding UTF8
                    }
                    'XML' {
                        $auditResults | ConvertTo-Xml -Depth 10 -NoTypeInformation | Set-Content -Path $ExportPath -Encoding UTF8
                    }
                }
                
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'INFO' -Message "Exported $ReportFormat report to: $ExportPath"
                } else {
                    Write-Host "📄 Exported $ReportFormat report to: $ExportPath" -ForegroundColor Green
                }
            }
            catch {
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'ERROR' -Message "Failed to export report: $($_.Exception.Message)"
                } else {
                    Write-Error "Failed to export report: $($_.Exception.Message)"
                }
            }
        }
        
        # Display summary
        if (-not $script:UseCustomLogging) {
            Write-Host "`n📊 Audit Summary:" -ForegroundColor Cyan
            Write-Host "  Directories Analyzed: $($auditResults.Summary.DirectoriesAnalyzed)" -ForegroundColor White
            Write-Host "  Files Analyzed: $($auditResults.Summary.FilesAnalyzed)" -ForegroundColor White
            Write-Host "  Total Findings: $($auditResults.Summary.TotalFindings)" -ForegroundColor White
            Write-Host "  Errors: $($auditResults.Summary.ErrorCount)" -ForegroundColor Red
            Write-Host "  Warnings: $($auditResults.Summary.WarningCount)" -ForegroundColor Yellow
            Write-Host "  Information: $($auditResults.Summary.InformationCount)" -ForegroundColor Blue
            Write-Host "  Overall Status: $($auditResults.Summary.OverallStatus)" -ForegroundColor $(
                switch ($auditResults.Summary.OverallStatus) {
                    'good' { 'Green' }
                    'warnings' { 'Yellow' }
                    'needs-attention' { 'Yellow' }
                    'critical' { 'Red' }
                    default { 'White' }
                }
            )
            Write-Host "  Quality Score: $([math]::Round($auditResults.Summary.QualityScore, 1))%" -ForegroundColor Magenta
            Write-Host "  Duration: $([math]::Round($auditResults.Duration / 1000, 2)) seconds" -ForegroundColor Gray
        }
        
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'SUCCESS' -Message "Directory audit completed successfully. Status: $($auditResults.Summary.OverallStatus), Score: $([math]::Round($auditResults.Summary.QualityScore, 1))%"
        }
        
        return $auditResults
    }
    catch {
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'ERROR' -Message "Directory audit failed: $($_.Exception.Message)"
        } else {
            Write-Error "Directory audit failed: $($_.Exception.Message)"
        }
        throw
    }
}