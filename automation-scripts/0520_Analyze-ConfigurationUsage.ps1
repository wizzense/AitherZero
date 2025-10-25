#Requires -Version 7.0
<#
.SYNOPSIS
    Analyzes configuration usage across the codebase
.DESCRIPTION
    Scans all PowerShell files to determine which configuration settings are actually used,
    helping identify unused or partially implemented configuration options
#>

# Script metadata
# Stage: Reporting
# Dependencies: 0400
# Description: Configuration usage analysis for tech debt reporting
# Tags: reporting, tech-debt, configuration, analysis

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = "./config.psd1",
    [string]$OutputPath = "./reports/tech-debt/analysis",
    [switch]$UseCache,
    [switch]$Detailed = $false,
    [string[]]$ExcludePaths = @('tests', 'legacy-to-migrate', 'examples', 'reports')
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

function Analyze-ConfigurationUsage {
    Write-AnalysisLog "Starting configuration usage analysis..." -Component "ConfigUsage"

    # Check cache
    if ($UseCache) {
        $cacheKey = "config-usage-$(Get-FileHash -Path $ConfigPath)"
        $cachedResults = Get-CachedResults -CacheKey $cacheKey

        if ($cachedResults) {
            Write-AnalysisLog "Using cached results" -Component "ConfigUsage" -Level Success
            return $cachedResults
        }
    }

    # Load configuration
    $configFullPath = Join-Path $script:ProjectRoot $ConfigPath
    if (-not (Test-Path $configFullPath)) {
        Write-AnalysisLog "Configuration file not found: $ConfigPath" -Component "ConfigUsage" -Level Error
        return @{ Error = "config.psd1 not found"; Path = $configFullPath }
    }

    $config = Import-PowerShellDataFile $configFullPath

    # Initialize results
    $usage = @{
        TotalSettings = 0
        UsedSettings = 0
        UnusedSettings = @()
        PartiallyImplemented = @()
        BySection = @{}
        ScanStartTime = $script:StartTime
        ConfigPath = $ConfigPath
    }

    # Get files to analyze
    $files = Get-FilesToAnalyze -Path $script:ProjectRoot -Exclude $ExcludePaths
    Write-AnalysisLog "Analyzing $($files.Count) files for configuration usage" -Component "ConfigUsage"

    # Analyze each configuration section
    foreach ($section in $config.PSObject.Properties) {
        $sectionName = $section.Name
        $sectionUsage = @{
            Total = 0
            Used = 0
            Unused = @()
            Usage = @{}
        }

        # Analyze each setting in the section
        foreach ($setting in $section.Value.PSObject.Properties) {
            $settingPath = "$sectionName.$($setting.Name)"
            $usage.TotalSettings++
            $sectionUsage.Total++

            # Search patterns for this setting
            $searchPatterns = @(
                [regex]::Escape("config.$settingPath")
                [regex]::Escape("Configuration['$sectionName']['$($setting.Name)']")
                [regex]::Escape("Configuration.$settingPath")
                [regex]::Escape("config['$sectionName']['$($setting.Name)']")
                [regex]::Escape("`$config.$settingPath")
                [regex]::Escape("`$$sectionName.$($setting.Name)")
            )

            $found = $false
            $locations = @()

            # Search in parallel with limited concurrency for better performance
            $maxConcurrency = 8
            $batchSize = [Math]::Ceiling($files.Count / $maxConcurrency)
            $searchJobs = @()

            for ($i = 0; $i -lt $files.Count; $i += $batchSize) {
                $batch = $files[$i..([Math]::Min($i + $batchSize - 1, $files.Count - 1))]
                $searchJobs += Start-ThreadJob -ScriptBlock {
                    param($FileBatch, $Patterns)
                    $foundMatches = @()

                    foreach ($file in $FileBatch) {
                        try {
                            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                            if ($content) {
                                foreach ($pattern in $Patterns) {
                                    if ($content -match $pattern) {
                                        $foundMatches += $file.FullName
                                        break
                                    }
                                }
                            }
                        }
                        catch {
                            # Skip files that can't be read
                            Write-Debug "Skipping file $($file.FullName): $_"
                        }
                    }

                    return $foundMatches
                } -ArgumentList $batch, $searchPatterns
            }

            # Wait for all search jobs with timeout
            $searchResults = @()
            foreach ($job in $searchJobs) {
                try {
                    $result = Wait-Job $job -Timeout 30 | Receive-Job
                    $searchResults += $result
                }
                catch {
                    Write-AnalysisLog "Job timeout or error: $_" -Component "ConfigUsage" -Level Warning
                }
                finally {
                    Remove-Job $job -Force -ErrorAction SilentlyContinue
                }
            }

            $locations = $searchResults | Where-Object { $_ } | ForEach-Object { $_.Replace($script:ProjectRoot, '.') }

            if ($locations.Count -gt 0) {
                $found = $true
                $usage.UsedSettings++
                $sectionUsage.Used++
                $sectionUsage.Usage[$setting.Name] = @{
                    Used = $true
                    Locations = $locations
                    Count = $locations.Count
                }
            } else {
                $usage.UnusedSettings += $settingPath
                $sectionUsage.Unused += $setting.Name
                $sectionUsage.Usage[$setting.Name] = @{
                    Used = $false
                    Locations = @()
                    Count = 0
                }
            }

            if ($Detailed) {
                Write-AnalysisLog "  $settingPath`: $(if ($found) { "Used in $($locations.Count) files" } else { "Not used" })" -Component "ConfigUsage"
            }
        }

        $sectionUsage.UsagePercentage = if ($sectionUsage.Total -gt 0) {
            [Math]::Round(($sectionUsage.Used / $sectionUsage.Total) * 100, 2)
        } else { 0 }

        $usage.BySection[$sectionName] = $sectionUsage
    }

    # Calculate overall usage
    $usage.UsagePercentage = if ($usage.TotalSettings -gt 0) {
        [Math]::Round(($usage.UsedSettings / $usage.TotalSettings) * 100, 2)
    } else { 0 }

    $usage.ScanEndTime = Get-Date
    $usage.Duration = $usage.ScanEndTime - $usage.ScanStartTime

    # Cache results if enabled
    if ($UseCache -and -not $usage.Error) {
        if ($PSCmdlet.ShouldProcess("Analysis cache", "Save configuration usage analysis results")) {
            Set-CachedResults -CacheKey $cacheKey -Results $usage -DependentFiles @($configFullPath)
        }
    }

    return $usage
}

# Main execution
try {
    Write-AnalysisLog "=== Configuration Usage Analysis ===" -Component "ConfigUsage"

    $results = Analyze-ConfigurationUsage

    # Save results
    if ($PSCmdlet.ShouldProcess($OutputPath, "Save configuration usage analysis results")) {
        $outputFile = Save-AnalysisResults -AnalysisType "ConfigurationUsage" -Results $results -OutputPath $OutputPath
    }

    # Display summary
    if (-not $results.Error) {
        Write-Host "`nConfiguration Usage Summary:" -ForegroundColor Cyan
        Write-Host "  Total Settings: $($results.TotalSettings)"
        Write-Host "  Used Settings: $($results.UsedSettings)" -ForegroundColor Green
        Write-Host "  Unused Settings: $($results.UnusedSettings.Count)" -ForegroundColor $(if ($results.UnusedSettings.Count -gt 0) { 'Yellow' } else { 'Green' })
        Write-Host "  Overall Usage: $($results.UsagePercentage)%" -ForegroundColor $(
            if ($results.UsagePercentage -ge 80) { 'Green' }
            elseif ($results.UsagePercentage -ge 60) { 'Yellow' }
            else { 'Red' }
        )
    Write-Host "  Analysis Duration: $($results.Duration.TotalSeconds.ToString('F2')) seconds"

        if ($results.UnusedSettings.Count -gt 0 -and $Detailed) {
            Write-Host "`nUnused Settings:" -ForegroundColor Yellow
            $results.UnusedSettings | ForEach-Object { Write-Host "  - $_" }
        }

        Write-Host "`nDetailed results saved to: $outputFile" -ForegroundColor Green
    } else {
        Write-Host "Analysis failed: $($results.Error)" -ForegroundColor Red
        exit 1
    }

    exit 0
} catch {
    Write-AnalysisLog "Configuration usage analysis failed: $_" -Component "ConfigUsage" -Level Error
    Write-AnalysisLog "Stack trace: $($_.ScriptStackTrace)" -Component "ConfigUsage" -Level Error
    exit 1
}

