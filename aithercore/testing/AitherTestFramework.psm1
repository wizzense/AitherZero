#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Next-Generation Testing Framework
.DESCRIPTION
    High-performance testing framework designed specifically for AitherZero orchestration.
    Replaces 97 individual test files with organized, cached, parallelized test suites.
.NOTES
    Copyright © 2025 Aitherium Corporation
    Optimized for speed and integration with AitherZero automation platform
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:TestFramework = @{
    Version = '2.0.0'
    StartTime = Get-Date
    TestSuites = @{}
    Results = @{}
    Cache = @{}
    Config = @{}
    ParallelJobs = @{}
}

# Performance tracking
$script:Metrics = @{
    TotalTests = 0
    TestsExecuted = 0
    TestsSkipped = 0
    TestsFromCache = 0
    ExecutionTime = 0
    CacheHitRate = 0
}

# Test categories for optimized execution
$script:TestCategories = @{
    Smoke = @{
        Name = 'Smoke'
        Description = 'Critical functionality verification (< 30 seconds)'
        Timeout = 30
        Parallel = $true
        MaxJobs = 8
    }
    Unit = @{
        Name = 'Unit'
        Description = 'Module and function unit tests (< 2 minutes)'
        Timeout = 120
        Parallel = $true
        MaxJobs = 6
    }
    Integration = @{
        Name = 'Integration'
        Description = 'Cross-module integration tests (< 5 minutes)'
        Timeout = 300
        Parallel = $false
        MaxJobs = 2
    }
    Full = @{
        Name = 'Full'
        Description = 'Comprehensive test suite (complete coverage)'
        Timeout = 1800
        Parallel = $true
        MaxJobs = 4
    }
}

# Logging helper
function Write-TestLog {
    param(
        [string]$Message,
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source 'AitherTestFramework' -Data $Data
    } else {
        $timestamp = Get-Date -Format 'HH:mm:ss.fff'
        $prefix = switch ($Level) {
            'Error' { '❌' }
            'Warning' { '⚠️' }
            'Information' { 'ℹ️' }
            'Debug' { '🔍' }
            default { '•' }
        }
        Write-Host "[$timestamp] $prefix $Message"
    }
}

function Initialize-TestFramework {
    <#
    .SYNOPSIS
        Initialize the AitherZero testing framework
    .DESCRIPTION
        Sets up the testing environment with proper configuration and caching
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Configuration = @{},
        [string]$CachePath = '',
        [switch]$ClearCache
    )

    # Set default cache path if not provided
    if ([string]::IsNullOrEmpty($CachePath)) {
        $tempPath = if ($IsWindows) { $env:TEMP } else { '/tmp' }
        $CachePath = Join-Path $tempPath 'AitherZero-TestCache'
    }

    Write-TestLog "Initializing AitherZero Testing Framework v$($script:TestFramework.Version)"

    # Set up configuration
    $projectRoot = if ($env:AITHERZERO_ROOT) { $env:AITHERZERO_ROOT } else { Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
    $parallelExecution = if ($Configuration.ContainsKey('ParallelExecution')) { $Configuration.ParallelExecution } else { $true }
    $useCache = if ($Configuration.ContainsKey('UseCache')) { $Configuration.UseCache } else { $true }
    $cacheMaxAge = if ($Configuration.ContainsKey('CacheMaxAge')) { $Configuration.CacheMaxAge } else { New-TimeSpan -Hours 1 }
    $testTimeout = if ($Configuration.ContainsKey('TestTimeout')) { $Configuration.TestTimeout } else { 300 }
    $logLevel = if ($Configuration.ContainsKey('LogLevel')) { $Configuration.LogLevel } else { 'Information' }

    $script:TestFramework.Config = @{
        ProjectRoot = $projectRoot
        CachePath = $CachePath
        ParallelExecution = $parallelExecution
        UseCache = $useCache
        CacheMaxAge = $cacheMaxAge
        TestTimeout = $testTimeout
        LogLevel = $logLevel
    }

    # Create cache directory
    if (-not (Test-Path $script:TestFramework.Config.CachePath)) {
        New-Item -Path $script:TestFramework.Config.CachePath -ItemType Directory -Force | Out-Null
    }

    # Clear cache if requested
    if ($ClearCache) {
        Clear-TestCache
    }

    Write-TestLog "Framework initialized" -Data @{
        ProjectRoot = $script:TestFramework.Config.ProjectRoot
        CachePath = $script:TestFramework.Config.CachePath
        ParallelExecution = $script:TestFramework.Config.ParallelExecution
        UseCache = $script:TestFramework.Config.UseCache
    }

    return $script:TestFramework
}

function Register-TestSuite {
    <#
    .SYNOPSIS
        Register a test suite with the framework
    .DESCRIPTION
        Defines a test suite that can be executed as part of different test categories
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$TestScript,

        [string[]]$Categories = @('Unit'),
        [string[]]$Tags = @(),
        [string[]]$Dependencies = @(),
        [int]$Priority = 100,
        [string]$Description = '',
        [hashtable]$Configuration = @{}
    )

    $testSuite = @{
        Name = $Name
        TestScript = $TestScript
        Categories = $Categories
        Tags = $Tags
        Dependencies = $Dependencies
        Priority = $Priority
        Description = $Description
        Configuration = $Configuration
        RegisteredAt = Get-Date
        LastRun = $null
        LastResult = $null
        CacheKey = (Get-StringHash "$Name-$($TestScript.ToString())")
    }

    $script:TestFramework.TestSuites[$Name] = $testSuite
    Write-TestLog "Registered test suite: $Name" -Data @{ Categories = $Categories; Tags = $Tags }

    return $testSuite
}

function Invoke-TestCategory {
    <#
    .SYNOPSIS
        Execute all test suites in a specific category
    .DESCRIPTION
        Runs tests optimized for the specified category with appropriate parallelization
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Smoke', 'Unit', 'Integration', 'Full')]
        [string]$Category,

        [string[]]$IncludeTags = @(),
        [string[]]$ExcludeTags = @(),
        [switch]$Force,
        [switch]$NoCache
    )

    $categoryConfig = $script:TestCategories[$Category]
    Write-TestLog "Starting $Category tests" -Data $categoryConfig

    # Get applicable test suites
    $testSuites = $script:TestFramework.TestSuites.Values | Where-Object {
        $suite = $_

        # Category filter
        $categoryMatch = $suite.Categories -contains $Category

        # Tag filters
        $tagMatch = $true
        if ($IncludeTags.Count -gt 0) {
            $tagMatch = $tagMatch -and ($suite.Tags | Where-Object { $_ -in $IncludeTags }).Count -gt 0
        }
        if ($ExcludeTags.Count -gt 0) {
            $tagMatch = $tagMatch -and ($suite.Tags | Where-Object { $_ -in $ExcludeTags }).Count -eq 0
        }

        return $categoryMatch -and $tagMatch
    } | Sort-Object Priority

    if ($testSuites.Count -eq 0) {
        Write-TestLog "No test suites found for category: $Category" -Level Warning
        return @{ Success = $true; Results = @(); Message = "No tests to run" }
    }

    Write-TestLog "Found $($testSuites.Count) test suites for $Category tests"

    # Execute tests
    $startTime = Get-Date
    $results = @()

    if ($categoryConfig.Parallel -and $script:TestFramework.Config.ParallelExecution) {
        Write-TestLog "Running tests in parallel (max $($categoryConfig.MaxJobs) jobs)"
        $results = Invoke-TestsParallel -TestSuites $testSuites -MaxJobs $categoryConfig.MaxJobs -Timeout $categoryConfig.Timeout -Force:$Force -NoCache:$NoCache
    } else {
        Write-TestLog "Running tests sequentially"
        $results = Invoke-TestsSequential -TestSuites $testSuites -Timeout $categoryConfig.Timeout -Force:$Force -NoCache:$NoCache
    }

    $endTime = Get-Date
    $duration = $endTime - $startTime

    # Compile results
    $summary = @{
        Category = $Category
        TotalSuites = $testSuites.Count
        Passed = ($results | Where-Object { $_.Result -eq 'Passed' }).Count
        Failed = ($results | Where-Object { $_.Result -eq 'Failed' }).Count
        Skipped = ($results | Where-Object { $_.Result -eq 'Skipped' }).Count
        FromCache = ($results | Where-Object { $_.FromCache -eq $true }).Count
        Duration = $duration
        Success = ($results | Where-Object { $_.Result -eq 'Failed' }).Count -eq 0
    }

    Write-TestLog "$Category tests completed" -Data $summary

    return @{
        Success = $summary.Success
        Results = $results
        Summary = $summary
        Category = $Category
        Duration = $duration
    }
}

function Invoke-TestsParallel {
    <#
    .SYNOPSIS
        Execute test suites in parallel
    #>
    [CmdletBinding()]
    param(
        [array]$TestSuites,
        [int]$MaxJobs = 4,
        [int]$Timeout = 300,
        [switch]$Force,
        [switch]$NoCache
    )

    $results = $TestSuites | ForEach-Object -ThrottleLimit $MaxJobs -Parallel {
        $suite = $_
        $Force = $using:Force
        $NoCache = $using:NoCache
        $framework = $using:script:TestFramework

        # Import required modules in parallel runspace
        if ($env:AITHERZERO_ROOT) {
            Import-Module (Join-Path $env:AITHERZERO_ROOT "domains/testing/AitherTestFramework.psm1") -Force
        }

        try {
            $result = Invoke-SingleTestSuite -TestSuite $suite -Timeout $using:Timeout -Force:$Force -NoCache:$NoCache
            return $result
        } catch {
            return @{
                SuiteName = $suite.Name
                Result = 'Failed'
                Error = $_.Exception.Message
                Duration = [TimeSpan]::Zero
                FromCache = $false
            }
        }
    }

    return $results
}

function Invoke-TestsSequential {
    <#
    .SYNOPSIS
        Execute test suites sequentially
    #>
    [CmdletBinding()]
    param(
        [array]$TestSuites,
        [int]$Timeout = 300,
        [switch]$Force,
        [switch]$NoCache
    )

    $results = @()
    foreach ($suite in $TestSuites) {
        try {
            $result = Invoke-SingleTestSuite -TestSuite $suite -Timeout $Timeout -Force:$Force -NoCache:$NoCache
            $results += $result
        } catch {
            $results += @{
                SuiteName = $suite.Name
                Result = 'Failed'
                Error = $_.Exception.Message
                Duration = [TimeSpan]::Zero
                FromCache = $false
            }
        }
    }

    return $results
}

function Invoke-SingleTestSuite {
    <#
    .SYNOPSIS
        Execute a single test suite
    #>
    [CmdletBinding()]
    param(
        [hashtable]$TestSuite,
        [int]$Timeout = 300,
        [switch]$Force,
        [switch]$NoCache
    )

    $startTime = Get-Date
    $suiteName = $TestSuite.Name

    Write-TestLog "Executing test suite: $suiteName"

    # Check cache unless forced or cache disabled
    if (-not $Force -and -not $NoCache -and $script:TestFramework.Config.UseCache) {
        $cachedResult = Get-CachedTestResult -CacheKey $TestSuite.CacheKey
        if ($cachedResult) {
            Write-TestLog "Using cached result for: $suiteName"
            return $cachedResult
        }
    }

    try {
        # Execute the test script
        $testJob = Start-Job -ScriptBlock $TestSuite.TestScript -ArgumentList $TestSuite.Configuration

        # Wait with timeout
        $completed = Wait-Job -Job $testJob -Timeout $Timeout

        if ($completed) {
            $jobResult = Receive-Job -Job $testJob -ErrorAction Continue
            $jobError = Receive-Job -Job $testJob -ErrorAction Continue 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }

            $result = @{
                SuiteName = $suiteName
                Result = if ($jobError) { 'Failed' } else { 'Passed' }
                Output = $jobResult
                Error = if ($jobError) { $jobError | Out-String } else { $null }
                Duration = (Get-Date) - $startTime
                FromCache = $false
                TestSuite = $TestSuite.Name
            }
        } else {
            # Timeout
            Stop-Job -Job $testJob
            $result = @{
                SuiteName = $suiteName
                Result = 'Failed'
                Error = "Test suite timed out after $Timeout seconds"
                Duration = (Get-Date) - $startTime
                FromCache = $false
                TestSuite = $TestSuite.Name
            }
        }

        Remove-Job -Job $testJob -Force -ErrorAction SilentlyContinue

        # Cache successful results
        if ($result.Result -eq 'Passed' -and $script:TestFramework.Config.UseCache) {
            Set-CachedTestResult -CacheKey $TestSuite.CacheKey -Result $result
        }

        return $result

    } catch {
        return @{
            SuiteName = $suiteName
            Result = 'Failed'
            Error = $_.Exception.Message
            Duration = (Get-Date) - $startTime
            FromCache = $false
            TestSuite = $TestSuite.Name
        }
    }
}

function Get-CachedTestResult {
    <#
    .SYNOPSIS
        Retrieve cached test result
    #>
    [CmdletBinding()]
    param([string]$CacheKey)

    $cacheFile = Join-Path $script:TestFramework.Config.CachePath "$CacheKey.json"

    if (Test-Path $cacheFile) {
        try {
            $cached = Get-Content $cacheFile -Raw | ConvertFrom-Json
            $cacheAge = (Get-Date) - [DateTime]$cached.Timestamp

            if ($cacheAge -lt $script:TestFramework.Config.CacheMaxAge) {
                $cached.Result.FromCache = $true
                return $cached.Result
            }
        } catch {
            # Invalid cache file, ignore
        }
    }

    return $null
}

function Set-CachedTestResult {
    <#
    .SYNOPSIS
        Cache test result
    #>
    [CmdletBinding()]
    param(
        [string]$CacheKey,
        [hashtable]$Result
    )

    try {
        $cacheData = @{
            Timestamp = Get-Date
            CacheKey = $CacheKey
            Result = $Result
        }

        $cacheFile = Join-Path $script:TestFramework.Config.CachePath "$CacheKey.json"
        $cacheData | ConvertTo-Json -Depth 10 | Set-Content $cacheFile -Encoding UTF8
    } catch {
        # Caching failed, but don't fail the test
        Write-TestLog "Failed to cache result: $($_.Exception.Message)" -Level Warning
    }
}

function Clear-TestCache {
    <#
    .SYNOPSIS
        Clear all cached test results
    #>
    [CmdletBinding()]
    param()

    if (Test-Path $script:TestFramework.Config.CachePath) {
        Get-ChildItem -Path $script:TestFramework.Config.CachePath -Filter "*.json" | Remove-Item -Force
        Write-TestLog "Test cache cleared"
    }
}

function Get-StringHash {
    <#
    .SYNOPSIS
        Generate hash string for caching
    #>
    param([string]$InputString)

    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $hash = $hasher.ComputeHash($bytes)
    return [Convert]::ToBase64String($hash).Substring(0, 16)
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-TestFramework',
    'Register-TestSuite',
    'Invoke-TestCategory',
    'Invoke-TestsParallel',
    'Invoke-TestsSequential',
    'Invoke-SingleTestSuite',
    'Get-CachedTestResult',
    'Set-CachedTestResult',
    'Clear-TestCache',
    'Get-StringHash'
)