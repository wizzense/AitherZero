#Requires -Version 7.0

# TestCacheManager.psm1
# Intelligent test result caching system to prevent redundant test executions

$script:CachePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) '.cache/test-results'
$script:CacheIndexFile = Join-Path $script:CachePath 'cache-index.json'
$script:MaxCacheAge = [TimeSpan]::FromHours(24)
$script:FileHashCache = @{}

# Ensure cache directory exists
if (-not (Test-Path $script:CachePath)) {
    New-Item -Path $script:CachePath -ItemType Directory -Force | Out-Null
}

function Get-FileHashSignature {
    <#
    .SYNOPSIS
    Calculate hash signature for a file or directory
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (Test-Path $Path -PathType Container) {
        # For directories, combine hashes of all relevant files
        $files = Get-ChildItem -Path $Path -Recurse -File -Include "*.ps1", "*.psm1", "*.psd1" |
                 Where-Object { $_.FullName -notmatch 'test-results|\.cache|logs' }
        
        $combinedHash = ""
        foreach ($file in $files | Sort-Object FullName) {
            if (-not $script:FileHashCache.ContainsKey($file.FullName)) {
                $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
                $script:FileHashCache[$file.FullName] = @{
                    Hash = $hash
                    LastWrite = $file.LastWriteTimeUtc
                }
            } elseif ($script:FileHashCache[$file.FullName].LastWrite -ne $file.LastWriteTimeUtc) {
                # File changed, recalculate
                $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
                $script:FileHashCache[$file.FullName] = @{
                    Hash = $hash
                    LastWrite = $file.LastWriteTimeUtc
                }
            }
            $combinedHash += $script:FileHashCache[$file.FullName].Hash
        }
        
        if ($combinedHash) {
            return (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($combinedHash))) -Algorithm SHA256).Hash
        }
    } elseif (Test-Path $Path -PathType Leaf) {
        return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
    }
    
    return $null
}

function Get-TestCacheKey {
    <#
    .SYNOPSIS
    Generate cache key for test execution
    #>
    param(
        [string]$TestPath,
        [string]$TestType = 'Unit',
        [hashtable]$Parameters = @{}
    )
    
    $keyComponents = @(
        $TestType
        $TestPath
        ($Parameters.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ';'
    )
    
    $keyString = $keyComponents -join '|'
    return (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($keyString))) -Algorithm SHA256).Hash.Substring(0, 16)
}

function Get-CachedTestResult {
    <#
    .SYNOPSIS
    Retrieve cached test results if valid
    
    .DESCRIPTION
    Returns cached test results if:
    - Cache entry exists
    - Source files haven't changed
    - Cache isn't expired
    #>
    param(
        [Parameter(Mandatory)]
        [string]$CacheKey,
        [string]$SourcePath
    )
    
    # Load cache index
    $cacheIndex = if (Test-Path $script:CacheIndexFile) {
        Get-Content $script:CacheIndexFile -Raw | ConvertFrom-Json -AsHashtable
    } else {
        @{}
    }
    
    if (-not $cacheIndex.ContainsKey($CacheKey)) {
        Write-Verbose "No cache entry found for key: $CacheKey"
        return $null
    }
    
    $cacheEntry = $cacheIndex[$CacheKey]
    
    # Check age
    $cacheTime = [DateTime]::Parse($cacheEntry.Timestamp)
    if ((Get-Date) - $cacheTime -gt $script:MaxCacheAge) {
        Write-Verbose "Cache entry expired for key: $CacheKey"
        return $null
    }
    
    # Check source hash if provided
    if ($SourcePath) {
        $currentHash = Get-FileHashSignature -Path $SourcePath
        if ($currentHash -ne $cacheEntry.SourceHash) {
            Write-Verbose "Source files changed, cache invalidated for key: $CacheKey"
            return $null
        }
    }
    
    # Load and return cached result
    $resultFile = Join-Path $script:CachePath "$CacheKey.json"
    if (Test-Path $resultFile) {
        $result = Get-Content $resultFile -Raw | ConvertFrom-Json
        Write-Verbose "Returning cached test result for key: $CacheKey"
        return $result
    }
    
    return $null
}

function Set-CachedTestResult {
    <#
    .SYNOPSIS
    Cache test execution results
    #>
    param(
        [Parameter(Mandatory)]
        [string]$CacheKey,
        [Parameter(Mandatory)]
        [PSCustomObject]$Result,
        [string]$SourcePath
    )
    
    # Ensure cache directory exists
    if (-not (Test-Path $script:CachePath)) {
        New-Item -Path $script:CachePath -ItemType Directory -Force | Out-Null
    }
    
    # Save result file
    $resultFile = Join-Path $script:CachePath "$CacheKey.json"
    $Result | ConvertTo-Json -Depth 10 | Set-Content -Path $resultFile
    
    # Update cache index
    $cacheIndex = if (Test-Path $script:CacheIndexFile) {
        Get-Content $script:CacheIndexFile -Raw | ConvertFrom-Json -AsHashtable
    } else {
        @{}
    }
    
    $cacheEntry = @{
        Timestamp = (Get-Date).ToString('o')
        SourceHash = if ($SourcePath) { Get-FileHashSignature -Path $SourcePath } else { $null }
        ResultFile = $resultFile
        Summary = @{
            TotalTests = $Result.TotalTests
            Passed = $Result.Passed
            Failed = $Result.Failed
            Duration = $Result.Duration
        }
    }
    
    $cacheIndex[$CacheKey] = $cacheEntry
    $cacheIndex | ConvertTo-Json -Depth 10 | Set-Content -Path $script:CacheIndexFile
    
    Write-Verbose "Cached test result with key: $CacheKey"
}

function Clear-TestCache {
    <#
    .SYNOPSIS
    Clear test cache entries
    #>
    param(
        [string]$Pattern,
        [switch]$All,
        [switch]$Expired
    )
    
    if ($All) {
        Remove-Item -Path "$script:CachePath/*" -Force -ErrorAction SilentlyContinue
        Write-Verbose "Cleared all test cache entries"
        return
    }
    
    $cacheIndex = if (Test-Path $script:CacheIndexFile) {
        Get-Content $script:CacheIndexFile -Raw | ConvertFrom-Json -AsHashtable
    } else {
        @{}
    }
    
    $keysToRemove = @()
    
    foreach ($key in $cacheIndex.Keys) {
        $remove = $false
        
        if ($Expired) {
            $cacheTime = [DateTime]::Parse($cacheIndex[$key].Timestamp)
            if ((Get-Date) - $cacheTime -gt $script:MaxCacheAge) {
                $remove = $true
            }
        }
        
        if ($Pattern -and $key -like $Pattern) {
            $remove = $true
        }
        
        if ($remove) {
            $keysToRemove += $key
            $resultFile = Join-Path $script:CachePath "$key.json"
            Remove-Item -Path $resultFile -Force -ErrorAction SilentlyContinue
        }
    }
    
    foreach ($key in $keysToRemove) {
        $cacheIndex.Remove($key)
    }
    
    if ($keysToRemove.Count -gt 0) {
        $cacheIndex | ConvertTo-Json -Depth 10 | Set-Content -Path $script:CacheIndexFile
        Write-Verbose "Removed $($keysToRemove.Count) cache entries"
    }
}

function Get-TestCacheStatistics {
    <#
    .SYNOPSIS
    Get statistics about test cache usage
    #>
    
    $cacheIndex = if (Test-Path $script:CacheIndexFile) {
        Get-Content $script:CacheIndexFile -Raw | ConvertFrom-Json -AsHashtable
    } else {
        @{}
    }
    
    $stats = @{
        TotalEntries = $cacheIndex.Count
        TotalSize = 0
        OldestEntry = $null
        NewestEntry = $null
        ExpiredEntries = 0
        ValidEntries = 0
    }
    
    if ($cacheIndex.Count -gt 0) {
        $now = Get-Date
        $timestamps = @()
        
        foreach ($entry in $cacheIndex.Values) {
            $timestamp = [DateTime]::Parse($entry.Timestamp)
            $timestamps += $timestamp
            
            if (($now - $timestamp) -gt $script:MaxCacheAge) {
                $stats.ExpiredEntries++
            } else {
                $stats.ValidEntries++
            }
            
            if (Test-Path $entry.ResultFile) {
                $stats.TotalSize += (Get-Item $entry.ResultFile).Length
            }
        }
        
        $stats.OldestEntry = ($timestamps | Sort-Object)[0]
        $stats.NewestEntry = ($timestamps | Sort-Object -Descending)[0]
    }
    
    # Add cache directory size
    if (Test-Path $script:CachePath) {
        $stats.TotalSize = (Get-ChildItem $script:CachePath -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $stats.TotalSizeMB = [Math]::Round($stats.TotalSize / 1MB, 2)
    }
    
    return [PSCustomObject]$stats
}

function Test-ShouldRunTests {
    <#
    .SYNOPSIS
    Determine if tests should be run based on recent changes
    
    .DESCRIPTION
    Analyzes recent file changes and test history to determine if tests need to run
    #>
    param(
        [string]$TestPath,
        [string]$SourcePath,
        [int]$MinutesSinceLastRun = 5
    )
    
    # Check if source files changed
    if ($SourcePath -and (Test-Path $SourcePath)) {
        $recentChanges = Get-ChildItem -Path $SourcePath -Recurse -File -Include "*.ps1", "*.psm1", "*.psd1" |
                        Where-Object { 
                            $_.LastWriteTime -gt (Get-Date).AddMinutes(-$MinutesSinceLastRun) -and
                            $_.FullName -notmatch 'test-results|\.cache|logs'
                        }
        
        if ($recentChanges) {
            return @{
                ShouldRun = $true
                Reason = "Source files changed in the last $MinutesSinceLastRun minutes"
                ChangedFiles = $recentChanges.FullName
            }
        }
    }
    
    # Check last test run time
    $cacheIndex = if (Test-Path $script:CacheIndexFile) {
        Get-Content $script:CacheIndexFile -Raw | ConvertFrom-Json -AsHashtable
    } else {
        @{}
    }
    
    $recentRuns = $cacheIndex.Values | Where-Object {
        [DateTime]::Parse($_.Timestamp) -gt (Get-Date).AddMinutes(-$MinutesSinceLastRun)
    }
    
    if ($recentRuns -and -not $recentRuns.Where({ $_.Summary.Failed -gt 0 })) {
        return @{
            ShouldRun = $false
            Reason = "Tests passed recently (within $MinutesSinceLastRun minutes) with no failures"
            LastRun = ($recentRuns | Sort-Object { [DateTime]::Parse($_.Timestamp) } -Descending)[0]
        }
    }
    
    return @{
        ShouldRun = $true
        Reason = "No recent successful test runs found"
    }
}

function Get-IncrementalTestScope {
    <#
    .SYNOPSIS
    Determine which tests to run based on changed files
    #>
    param(
        [string]$BasePath,
        [string[]]$ChangedFiles
    )
    
    $testScope = @{
        All = $false
        Modules = @()
        Scripts = @()
        TestFiles = @()
    }
    
    foreach ($file in $ChangedFiles) {
        # If core files changed, run all tests
        if ($file -match 'AitherZero\.ps[md]1$' -or $file -match 'Initialize-.*\.ps1$') {
            $testScope.All = $true
            return $testScope
        }
        
        # Map changed files to test scopes
        if ($file -match 'domains[/\\]([^/\\]+)[/\\]') {
            $module = $Matches[1]
            if ($module -notin $testScope.Modules) {
                $testScope.Modules += $module
            }
        }
        
        if ($file -match 'automation-scripts[/\\](\d{4}_.+\.ps1)$') {
            $testScope.Scripts += $Matches[1]
        }
        
        # If test file changed, run it
        if ($file -match '\.Tests\.ps1$') {
            $testScope.TestFiles += $file
        }
    }
    
    return $testScope
}

# Export functions
Export-ModuleMember -Function @(
    'Get-FileHashSignature'
    'Get-TestCacheKey'
    'Get-CachedTestResult'
    'Set-CachedTestResult'
    'Clear-TestCache'
    'Get-TestCacheStatistics'
    'Test-ShouldRunTests'
    'Get-IncrementalTestScope'
)