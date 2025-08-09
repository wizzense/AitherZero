#Requires -Version 7.0
<#
.SYNOPSIS
    Shared module for tech debt analysis functionality
.DESCRIPTION
    Provides common functions and utilities for analyzing technical debt,
    including result caching, file change detection, and report formatting
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:AnalysisState = @{
    CachePath = Join-Path ([System.IO.Path]::GetTempPath()) 'aitherzero-techdebt-cache'
    ResultsPath = './reports/tech-debt/analysis'
    MaxCacheAge = [TimeSpan]::FromHours(24)
}

# Initialize cache directory
if (-not (Test-Path $script:AnalysisState.CachePath)) {
    New-Item -ItemType Directory -Path $script:AnalysisState.CachePath -Force | Out-Null
}

function Initialize-TechDebtAnalysis {
    <#
    .SYNOPSIS
        Initialize tech debt analysis environment
    .DESCRIPTION
        Sets up cache directories and loads configuration
    #>
    [CmdletBinding()]
    param(
        [string]$CachePath = $script:AnalysisState.CachePath,
        [string]$ResultsPath = $script:AnalysisState.ResultsPath,
        [TimeSpan]$MaxCacheAge = $script:AnalysisState.MaxCacheAge
    )

    $script:AnalysisState.CachePath = $CachePath
    $script:AnalysisState.ResultsPath = $ResultsPath
    $script:AnalysisState.MaxCacheAge = $MaxCacheAge

    # Ensure directories exist
    @($CachePath, $ResultsPath) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }

    # Clean old cache files
    Get-ChildItem -Path $CachePath -Filter "*.cache.json" | 
        Where-Object { $_.LastWriteTime -lt (Get-Date).Subtract($MaxCacheAge) } |
        Remove-Item -Force
}

function Get-FileHash {
    <#
    .SYNOPSIS
        Get hash of file content for change detection
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }
    
    $hash = Get-FileHash -Path $Path
    return $hash.Hash
}

function Test-CacheValid {
    <#
    .SYNOPSIS
        Check if cached analysis results are still valid
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CacheKey,
        [string[]]$DependentFiles = @()
    )

    $cachePath = Join-Path $script:AnalysisState.CachePath "$CacheKey.cache.json"

    if (-not (Test-Path $cachePath)) {
        return $false
    }
    
    $cacheData = Get-Content $cachePath -Raw | ConvertFrom-Json

    # Check age
    $cacheAge = [DateTime]::Parse($cacheData.Timestamp)
    if ($cacheAge -lt (Get-Date).Subtract($script:AnalysisState.MaxCacheAge)) {
        return $false
    }

    # Check file hashes
    foreach ($file in $DependentFiles) {
        $currentHash = Get-FileHash -Path $file
        $cachedHash = $cacheData.FileHashes | Where-Object { $_.Path -eq $file } | Select-Object -ExpandProperty Hash
        
        if ($currentHash -ne $cachedHash) {
            return $false
        }
    }
    
    return $true
}

function Get-CachedResults {
    <#
    .SYNOPSIS
        Retrieve cached analysis results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CacheKey
    )

    $cachePath = Join-Path $script:AnalysisState.CachePath "$CacheKey.cache.json"

    if (Test-Path $cachePath) {
        $cacheData = Get-Content $cachePath -Raw | ConvertFrom-Json
        return $cacheData.Results
    }
    
    return $null
}

function Set-CachedResults {
    <#
    .SYNOPSIS
        Store analysis results in cache
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CacheKey,
        [Parameter(Mandatory)]
        $Results,
        [string[]]$DependentFiles = @()
    )

    $fileHashes = @()
    foreach ($file in $DependentFiles) {
        if (Test-Path $file) {
            $fileHashes += @{
                Path = $file
                Hash = Get-FileHash -Path $file
            }
        }
    }
    
    $cacheData = @{
        Timestamp = (Get-Date).ToString('o')
        CacheKey = $CacheKey
        FileHashes = $fileHashes
        Results = $Results
    }
    
    $cachePath = Join-Path $script:AnalysisState.CachePath "$CacheKey.cache.json"
    $cacheData | ConvertTo-Json -Depth 10 | Set-Content -Path $cachePath -Force
}

function Write-AnalysisLog {
    <#
    .SYNOPSIS
        Write log message for analysis operations
    #>
    param(
        [string]$Message,
        [string]$Level = 'Information',
        [string]$Component = 'TechDebt'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "[$Component] $Message" -Level $Level
    } else {
        $color = switch ($Level) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Information' { 'Green' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

function Save-AnalysisResults {
    <#
    .SYNOPSIS
        Save analysis results to file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AnalysisType,
        [Parameter(Mandatory)]
        $Results,
        [string]$OutputPath = $script:AnalysisState.ResultsPath
    )

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $filename = "$AnalysisType-$timestamp.json"
    $filepath = Join-Path $OutputPath $filename

    # Also save a "latest" version
    $latestPath = Join-Path $OutputPath "$AnalysisType-latest.json"
    
    $resultData = @{
        AnalysisType = $AnalysisType
        Timestamp = (Get-Date).ToString('o')
        Duration = if ($Results.Duration) { $Results.Duration } else { $null }
        Results = $Results
    }
    
    $resultData | ConvertTo-Json -Depth 10 | Set-Content -Path $filepath -Force
    $resultData | ConvertTo-Json -Depth 10 | Set-Content -Path $latestPath -Force
    
    Write-AnalysisLog "Saved $AnalysisType results to $filename" -Level Information
    
    return $filepath
}

function Get-AnalysisResults {
    <#
    .SYNOPSIS
        Load analysis results from file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AnalysisType,
        [string]$ResultsPath = $script:AnalysisState.ResultsPath,
        [switch]$Latest
    )

    if ($Latest) {
        $filepath = Join-Path $ResultsPath "$AnalysisType-latest.json"
    } else {
        # Get most recent file
        $pattern = "$AnalysisType-*.json"
        $files = Get-ChildItem -Path $ResultsPath -Filter $pattern | 
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
            
        if (-not $files) {
            Write-AnalysisLog "No results found for $AnalysisType" -Level Warning
            return $null
        }
        
        $filepath = $files.FullName
    }

    if (-not (Test-Path $filepath)) {
        Write-AnalysisLog "Results file not found: $filepath" -Level Warning
        return $null
    }
    
    $data = Get-Content $filepath -Raw | ConvertFrom-Json
    return $data.Results
}

function Merge-AnalysisResults {
    <#
    .SYNOPSIS
        Merge results from multiple analysis types
    #>
    [CmdletBinding()]
    param(
        [string[]]$AnalysisTypes = @('ConfigurationUsage', 'DocumentationCoverage', 'CodeQuality', 'SecurityIssues'),
        [string]$ResultsPath = $script:AnalysisState.ResultsPath
    )

    $mergedResults = @{
        Timestamp = (Get-Date).ToString('o')
        Analyses = @{}
    }
    
    foreach ($type in $AnalysisTypes) {
        $results = Get-AnalysisResults -AnalysisType $type -ResultsPath $ResultsPath -Latest
        if ($results) {
            $mergedResults.Analyses[$type] = $results
        } else {
            Write-AnalysisLog "No results found for $type" -Level Warning
        }
    }
    
    return $mergedResults
}

function Get-FilesToAnalyze {
    <#
    .SYNOPSIS
        Get list of files to analyze with optional filtering
    #>
    [CmdletBinding()]
    param(
        [string]$Path = (Get-Location).Path,
        [string[]]$Include = @('*.ps1', '*.psm1', '*.psd1'),
        [string[]]$Exclude = @('tests', 'legacy-to-migrate', 'examples', 'reports', '.git', 'node_modules'),
        [switch]$ChangedOnly,
        [DateTime]$Since = (Get-Date).AddDays(-7)
    )

    $excludePattern = $Exclude | ForEach-Object { "*\$_\*" }
    
    $files = Get-ChildItem -Path $Path -Recurse -Include $Include -File |
        Where-Object { 
            $fullName = $_.FullName
            -not ($excludePattern | Where-Object { $fullName -like $_ })
        }

    if ($ChangedOnly) {
        $files = $files | Where-Object { $_.LastWriteTime -gt $Since }
    }
    
    return $files
}

function Start-ParallelAnalysis {
    <#
    .SYNOPSIS
        Run analysis in parallel using ThreadJob
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        [Parameter(Mandatory)]
        [object[]]$InputObject,
        [int]$MaxConcurrency = 4,
        [string]$JobName = 'TechDebtAnalysis'
    )

    $jobs = @()
    $results = @()
    $completed = 0
    $total = $InputObject.Count
    
    Write-AnalysisLog "Starting parallel analysis of $total items with max concurrency $MaxConcurrency"

    # Start jobs in batches
    for ($i = 0; $i -lt $total; $i += $MaxConcurrency) {
        $batch = $InputObject[$i..[Math]::Min($i + $MaxConcurrency - 1, $total - 1)]
        
        foreach ($item in $batch) {
            $jobs += Start-ThreadJob -ScriptBlock $ScriptBlock -ArgumentList $item -Name "$JobName-$i"
        }
        
        # Wait for batch to complete
        $jobs | Wait-Job | Out-Null
        
        # Collect results
        foreach ($job in $jobs) {
            if ($job.State -eq 'Completed') {
                $results += Receive-Job -Job $job
                $completed++
            } else {
                Write-AnalysisLog "Job failed: $($job.Name)" -Level Warning
            }
            Remove-Job -Job $job
        }
        
        # Progress update
        Write-Progress -Activity "Parallel Analysis" -Status "$completed of $total completed" -PercentComplete (($completed / $total) * 100)
        $jobs = @()
    }
    
    Write-Progress -Activity "Parallel Analysis" -Completed
    Write-AnalysisLog "Parallel analysis completed: $completed of $total items processed" -Level Information
    
    return $results
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-TechDebtAnalysis'
    'Get-FileHash'
    'Test-CacheValid'
    'Get-CachedResults'
    'Set-CachedResults'
    'Write-AnalysisLog'
    'Save-AnalysisResults'
    'Get-AnalysisResults'
    'Merge-AnalysisResults'
    'Get-FilesToAnalyze'
    'Start-ParallelAnalysis'
)