#Requires -Version 7.0

<#
.SYNOPSIS
    Manage PSScriptAnalyzer cache for performance optimization
.DESCRIPTION
    Manages the cache used by 0404_Run-PSScriptAnalyzer.ps1 to avoid re-analyzing unchanged files.
    Can display cache stats, clear cache, or prune old entries.
    
.PARAMETER Action
    Action to perform: Info, Clear, Prune
.PARAMETER CacheFile
    Path to cache file (default: reports/.pssa-cache.json)
.PARAMETER DaysOld
    For Prune action: remove entries older than this many days (default: 30)
    
.EXAMPLE
    ./0415_Manage-PSScriptAnalyzerCache.ps1 -Action Info
    
.EXAMPLE
    ./0415_Manage-PSScriptAnalyzerCache.ps1 -Action Prune -DaysOld 7
    
.NOTES
    Stage: Testing
    Order: 0415
    Dependencies: 0404
    Tags: testing, cache, psscriptanalyzer, performance
#>

[CmdletBinding()]
param(
    [ValidateSet('Info', 'Clear', 'Prune')]
    [string]$Action = 'Info',
    
    [string]$CacheFile = "./reports/.pssa-cache.json",
    
    [int]$DaysOld = 30
)

# Determine project root
$projectRoot = if ($env:AITHERZERO_ROOT) {
    $env:AITHERZERO_ROOT
} elseif ($PSScriptRoot) {
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
} else {
    Get-Location
}

# Import ScriptUtilities for centralized logging
$scriptUtilsPath = Join-Path $projectRoot "aithercore/automation/ScriptUtilities.psm1"
if (Test-Path $scriptUtilsPath) {
    Import-Module $scriptUtilsPath -Force -ErrorAction SilentlyContinue
}

try {
    Write-ScriptLog "PSScriptAnalyzer Cache Manager" -Level Information -Source "0415"
    
    if (-not (Test-Path $CacheFile)) {
        Write-ScriptLog "No cache file found at: $CacheFile" -Level Warning
        Write-ScriptLog "Run 0404_Run-PSScriptAnalyzer.ps1 first to create cache"
        exit 0
    }
    
    # Load cache
    $cacheData = Get-Content $CacheFile -Raw | ConvertFrom-Json
    $cache = @{}
    foreach ($prop in $cacheData.PSObject.Properties) {
        $cache[$prop.Name] = $prop.Value
    }
    
    $cacheFile = Get-Item $CacheFile
    
    switch ($Action) {
        'Info' {
            Write-ScriptLog "`nCache Statistics:"
            Write-ScriptLog "  Location: $($cacheFile.FullName)"
            Write-ScriptLog "  Size: $([math]::Round($cacheFile.Length / 1KB, 2)) KB"
            Write-ScriptLog "  Entries: $($cache.Count) files"
            Write-ScriptLog "  Last Modified: $($cacheFile.LastWriteTime)"
            
            # Calculate age distribution
            $now = Get-Date
            $ageGroups = @{
                'Last 24h' = 0
                'Last 7 days' = 0
                'Last 30 days' = 0
                'Older' = 0
            }
            
            foreach ($entry in $cache.Values) {
                if ($entry.LastAnalyzed) {
                    $age = $now - [datetime]$entry.LastAnalyzed
                    if ($age.TotalDays -lt 1) { $ageGroups['Last 24h']++ }
                    elseif ($age.TotalDays -lt 7) { $ageGroups['Last 7 days']++ }
                    elseif ($age.TotalDays -lt 30) { $ageGroups['Last 30 days']++ }
                    else { $ageGroups['Older']++ }
                }
            }
            
            Write-ScriptLog "`nAge Distribution:"
            foreach ($group in $ageGroups.GetEnumerator() | Sort-Object Name) {
                Write-ScriptLog "  $($group.Key): $($group.Value) files"
            }
            
            # Files with issues
            $filesWithIssues = ($cache.Values | Where-Object { $_.Issues -and $_.Issues.Count -gt 0 }).Count
            Write-ScriptLog "`nIssue Statistics:"
            Write-ScriptLog "  Files with issues: $filesWithIssues"
            Write-ScriptLog "  Clean files: $($cache.Count - $filesWithIssues)"
        }
        
        'Clear' {
            Remove-Item $CacheFile -Force
            Write-ScriptLog "Cache cleared" -Level Information
            Write-ScriptLog "Next analysis will rebuild cache from scratch"
        }
        
        'Prune' {
            $cutoffDate = (Get-Date).AddDays(-$DaysOld)
            $pruned = 0
            $kept = @{}
            
            foreach ($entry in $cache.GetEnumerator()) {
                if ($entry.Value.LastAnalyzed) {
                    $analyzed = [datetime]$entry.Value.LastAnalyzed
                    if ($analyzed -gt $cutoffDate) {
                        $kept[$entry.Key] = $entry.Value
                    } else {
                        $pruned++
                    }
                } else {
                    # Keep entries without timestamp (safety)
                    $kept[$entry.Key] = $entry.Value
                }
            }
            
            if ($pruned -gt 0) {
                $kept | ConvertTo-Json -Depth 5 -Compress | Set-Content -Path $CacheFile -Encoding UTF8
                Write-ScriptLog "Pruned $pruned entries older than $DaysOld days" -Level Information
                Write-ScriptLog "Kept $($kept.Count) recent entries"
            } else {
                Write-ScriptLog "No entries older than $DaysOld days found"
            }
        }
    }
    
    exit 0
    
} catch {
    Write-ScriptLog "Cache management failed: $($_.Exception.Message)" -Level Error
    exit 1
}
