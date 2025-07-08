function Invoke-DirectoryAnalysis {
    <#
    .SYNOPSIS
        Performs comprehensive PSScriptAnalyzer analysis on a directory

    .DESCRIPTION
        Executes PSScriptAnalyzer on all PowerShell files in a directory,
        processes results, and updates status and bug tracking files

    .PARAMETER Path
        Directory path to analyze

    .PARAMETER ModuleName
        Optional module name for context-specific analysis

    .PARAMETER Configuration
        Custom PSScriptAnalyzer configuration to use

    .PARAMETER UpdateFiles
        Whether to update status and .bugz files (default: true)

    .PARAMETER Recurse
        Whether to analyze subdirectories (default: true)

    .PARAMETER IncludeTests
        Whether to include test files in analysis (default: false)

    .EXAMPLE
        $results = Invoke-DirectoryAnalysis -Path "./aither-core/modules/PatchManager" -ModuleName "PatchManager"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [hashtable]$Configuration,

        [Parameter(Mandatory = $false)]
        [bool]$UpdateFiles = $true,

        [Parameter(Mandatory = $false)]
        [bool]$Recurse = $true,

        [Parameter(Mandatory = $false)]
        [bool]$IncludeTests = $false
    )

    try {
        $resolvedPath = Resolve-Path $Path -ErrorAction Stop

        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'INFO' -Message "Starting PSScriptAnalyzer analysis for: $resolvedPath"
        }

        # Get configuration if not provided
        if (-not $Configuration) {
            $Configuration = Get-AnalysisConfiguration -Path $resolvedPath -ModuleName $ModuleName
        }

        # Find PowerShell files
        $includePatterns = @('*.ps1', '*.psm1', '*.psd1')
        $excludePatterns = @()

        if (-not $IncludeTests) {
            $excludePatterns += @('*.Tests.ps1', '*test*.ps1', '*Tests*.ps1')
        }

        $psFiles = Get-ChildItem -Path $resolvedPath -Include $includePatterns -Recurse:$Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $include = $true
                foreach ($pattern in $excludePatterns) {
                    if ($_.Name -like $pattern) {
                        $include = $false
                        break
                    }
                }

                # Check if file is in excluded paths from configuration
                if ($include -and $Configuration.ContainsKey('ExcludeFilePath')) {
                    $relativePath = $_.FullName -replace [regex]::Escape($resolvedPath.Path), ''
                    foreach ($excludePath in $Configuration.ExcludeFilePath) {
                        if ($relativePath -like $excludePath) {
                            $include = $false
                            break
                        }
                    }
                }

                return $include
            }

        if ($psFiles.Count -eq 0) {
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'WARNING' -Message "No PowerShell files found in $resolvedPath"
            }
            return @{
                Path = $resolvedPath.Path
                FilesAnalyzed = 0
                Results = @()
                Status = 'no-files'
                Configuration = $Configuration
            }
        }

        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'INFO' -Message "Found $($psFiles.Count) PowerShell files to analyze"
        }

        # Prepare PSScriptAnalyzer parameters
        $analyzerParams = @{
            Path = $resolvedPath.Path
            Recurse = $Recurse
        }

        # Add configuration parameters
        if ($Configuration.ContainsKey('IncludeRules') -and $Configuration.IncludeRules.Count -gt 0) {
            $analyzerParams.IncludeRule = $Configuration.IncludeRules
        }

        if ($Configuration.ContainsKey('ExcludeRules') -and $Configuration.ExcludeRules.Count -gt 0) {
            $analyzerParams.ExcludeRule = $Configuration.ExcludeRules
        }

        if ($Configuration.ContainsKey('Severity') -and $Configuration.Severity.Count -gt 0) {
            $analyzerParams.Severity = $Configuration.Severity
        }

        # Use custom settings file if available
        $globalConfigPath = $script:DefaultSettings.GlobalConfigPath
        if (Test-Path $globalConfigPath) {
            $analyzerParams.Settings = $globalConfigPath
        }

        # Run PSScriptAnalyzer
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'INFO' -Message "Running PSScriptAnalyzer with parameters: $($analyzerParams | ConvertTo-Json -Compress)"
        }

        $analysisResults = @()
        $analysisErrors = @()

        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $analysisResults = Invoke-ScriptAnalyzer @analyzerParams -ErrorAction Continue -ErrorVariable analysisErrors
            $stopwatch.Stop()

            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'INFO' -Message "PSScriptAnalyzer completed in $($stopwatch.ElapsedMilliseconds)ms. Found $($analysisResults.Count) findings."
            }
        }
        catch {
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'ERROR' -Message "PSScriptAnalyzer failed: $($_.Exception.Message)"
            }
            throw
        }

        # Process analysis errors
        if ($analysisErrors.Count -gt 0) {
            if ($script:UseCustomLogging) {
                Write-CustomLog -Level 'WARNING' -Message "PSScriptAnalyzer encountered $($analysisErrors.Count) errors during analysis"
            }
            foreach ($error in $analysisErrors) {
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'WARNING' -Message "Analysis error: $($error.Exception.Message)"
                }
            }
        }

        # Categorize results by severity
        $resultsSummary = @{
            Errors = ($analysisResults | Where-Object Severity -eq 'Error').Count
            Warnings = ($analysisResults | Where-Object Severity -eq 'Warning').Count
            Information = ($analysisResults | Where-Object Severity -eq 'Information').Count
            Total = $analysisResults.Count
        }

        # Determine overall status
        $overallStatus = if ($resultsSummary.Errors -gt 0) {
            'critical'
        } elseif ($resultsSummary.Warnings -gt $script:QualityThresholds.WarningThreshold) {
            'needs-attention'
        } elseif ($resultsSummary.Warnings -gt 0) {
            'warnings'
        } elseif ($resultsSummary.Information -gt $script:QualityThresholds.InfoThreshold) {
            'review-recommended'
        } else {
            'good'
        }

        # Update files if requested
        if ($UpdateFiles) {
            try {
                # Update status file
                New-StatusFile -Path $resolvedPath -AnalysisResults $analysisResults -Configuration $Configuration -Force

                # Update .bugz file
                Update-BugzFile -Path $resolvedPath -AnalysisResults $analysisResults -UpdateExisting -AutoResolve

                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'INFO' -Message "Updated status and .bugz files for $resolvedPath"
                }
            }
            catch {
                if ($script:UseCustomLogging) {
                    Write-CustomLog -Level 'WARNING' -Message "Failed to update tracking files: $($_.Exception.Message)"
                }
            }
        }

        # Return analysis results
        return @{
            Path = $resolvedPath.Path
            ModuleName = $ModuleName
            FilesAnalyzed = $psFiles.Count
            Results = $analysisResults
            Summary = $resultsSummary
            Status = $overallStatus
            Configuration = $Configuration
            AnalysisErrors = $analysisErrors
            Duration = if ($stopwatch) { $stopwatch.ElapsedMilliseconds } else { 0 }
            Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
        }
    }
    catch {
        if ($script:UseCustomLogging) {
            Write-CustomLog -Level 'ERROR' -Message "Failed to analyze directory ${Path}: $($_.Exception.Message)"
        }
        throw
    }
}
