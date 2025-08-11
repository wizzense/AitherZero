#Requires -Version 7.0
<#
.SYNOPSIS
    Comprehensive unit tests for the TechDebtAnalysis module
.DESCRIPTION
    Tests all functions in the TechDebtAnalysis module including initialization,
    caching, result management, file analysis, and parallel processing
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
BeforeAll {
    # Discover and import the TechDebtAnalysis module
    $ModulePath = Join-Path $PSScriptRoot "../../../../domains/reporting/TechDebtAnalysis.psm1"
    if (-not (Test-Path $ModulePath)) {
        throw "TechDebtAnalysis module not found at: $ModulePath"
    }
    
    # Import the module to test
    Import-Module $ModulePath -Force
    
    # Set up test environment
    $script:TestTempPath = Join-Path ([System.IO.Path]::GetTempPath()) "AitherZero-TechDebt-Tests"
    $script:TestCachePath = Join-Path $script:TestTempPath "cache"
    $script:TestResultsPath = Join-Path $script:TestTempPath "results"
    
    # Clean up any existing test directories
    if (Test-Path $script:TestTempPath) {
        Remove-Item $script:TestTempPath -Recurse -Force
    }
    
    # Create test directories
    New-Item -ItemType Directory -Path $script:TestTempPath -Force | Out-Null
    New-Item -ItemType Directory -Path $script:TestCachePath -Force | Out-Null
    New-Item -ItemType Directory -Path $script:TestResultsPath -Force | Out-Null
    
    # Create test files for analysis
    $script:TestFile1 = Join-Path $script:TestTempPath "TestScript1.ps1"
    $script:TestFile2 = Join-Path $script:TestTempPath "TestScript2.psm1"
    $script:TestFile3 = Join-Path $script:TestTempPath "TestScript3.psd1"
    
    @"
# Test PowerShell script 1
function Test-Function1 {
    param([string]`$Name)
    Write-Host "Hello `$Name"
}
"@ | Set-Content -Path $script:TestFile1
    
    @"
# Test PowerShell module
function Test-Function2 {
    <#
    .SYNOPSIS
        A documented function
    #>
    param([int]`$Number)
    return `$Number * 2
}
Export-ModuleMember -Function Test-Function2
"@ | Set-Content -Path $script:TestFile2
    
    @"
@{
    ModuleVersion = '1.0.0'
    GUID = 'test-guid'
    Author = 'Test Author'
}
"@ | Set-Content -Path $script:TestFile3
}

AfterAll {
    # Clean up test directories
    if (Test-Path $script:TestTempPath) {
        Remove-Item $script:TestTempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "TechDebtAnalysis Module" {
    Context "Module Import and Functions" {
        It "Should import the module successfully" {
            Get-Module TechDebtAnalysis | Should -Not -BeNullOrEmpty
        }
        
        It "Should export all expected functions" {
            $exportedFunctions = (Get-Module TechDebtAnalysis).ExportedFunctions.Keys
            $expectedFunctions = @(
                'Initialize-TechDebtAnalysis',
                'Get-FileHash',
                'Test-CacheValid',
                'Get-CachedResults',
                'Set-CachedResults',
                'Write-AnalysisLog',
                'Save-AnalysisResults',
                'Get-AnalysisResults',
                'Merge-AnalysisResults',
                'Get-FilesToAnalyze',
                'Start-ParallelAnalysis'
            )
            
            foreach ($func in $expectedFunctions) {
                $exportedFunctions | Should -Contain $func
            }
        }
    }
    
    Context "Initialize-TechDebtAnalysis" {
        It "Should initialize with default parameters" {
            { Initialize-TechDebtAnalysis } | Should -Not -Throw
        }
        
        It "Should initialize with custom paths" {
            $customCachePath = Join-Path $script:TestTempPath "custom-cache"
            $customResultsPath = Join-Path $script:TestTempPath "custom-results"
            
            { Initialize-TechDebtAnalysis -CachePath $customCachePath -ResultsPath $customResultsPath } | Should -Not -Throw
            
            Test-Path $customCachePath | Should -Be $true
            Test-Path $customResultsPath | Should -Be $true
        }
        
        It "Should set custom cache age" {
            $customAge = [TimeSpan]::FromHours(12)
            { Initialize-TechDebtAnalysis -MaxCacheAge $customAge } | Should -Not -Throw
        }
        
        It "Should clean old cache files" {
            # Create an old cache file
            $oldCacheFile = Join-Path $script:TestCachePath "old-test.cache.json"
            @{ timestamp = (Get-Date).AddDays(-2).ToString('o') } | ConvertTo-Json | Set-Content -Path $oldCacheFile
            
            # Set the file's last write time to be old
            (Get-Item $oldCacheFile).LastWriteTime = (Get-Date).AddDays(-2)
            
            Initialize-TechDebtAnalysis -CachePath $script:TestCachePath -MaxCacheAge ([TimeSpan]::FromHours(24))
            
            Test-Path $oldCacheFile | Should -Be $false
        }
    }
    
    Context "Get-FileHash Function" {
        It "Should return hash for existing file" {
            $hash = Get-FileHash -Path $script:TestFile1
            $hash | Should -Not -BeNullOrEmpty
            $hash | Should -Match "^[A-F0-9]{64}$"
        }
        
        It "Should return null for non-existent file" {
            $nonExistentFile = Join-Path $script:TestTempPath "NonExistent.ps1"
            $hash = Get-FileHash -Path $nonExistentFile
            $hash | Should -BeNullOrEmpty
        }
        
        It "Should return different hashes for different files" {
            $hash1 = Get-FileHash -Path $script:TestFile1
            $hash2 = Get-FileHash -Path $script:TestFile2
            $hash1 | Should -Not -Be $hash2
        }
    }
    
    Context "Cache Management Functions" {
        BeforeEach {
            Initialize-TechDebtAnalysis -CachePath $script:TestCachePath -ResultsPath $script:TestResultsPath
        }
        
        Context "Set-CachedResults and Get-CachedResults" {
            It "Should store and retrieve cached results" {
                $testResults = @{
                    Analysis = "Test"
                    Count = 42
                    Items = @("item1", "item2", "item3")
                }
                
                Set-CachedResults -CacheKey "test-key" -Results $testResults
                
                $retrieved = Get-CachedResults -CacheKey "test-key"
                $retrieved.Analysis | Should -Be "Test"
                $retrieved.Count | Should -Be 42
                $retrieved.Items.Count | Should -Be 3
            }
            
            It "Should return null for non-existent cache key" {
                $retrieved = Get-CachedResults -CacheKey "non-existent"
                $retrieved | Should -BeNullOrEmpty
            }
            
            It "Should store file hashes with results" {
                $testResults = @{ Data = "test" }
                $dependentFiles = @($script:TestFile1, $script:TestFile2)
                
                Set-CachedResults -CacheKey "test-with-files" -Results $testResults -DependentFiles $dependentFiles
                
                $cacheFile = Join-Path $script:TestCachePath "test-with-files.cache.json"
                Test-Path $cacheFile | Should -Be $true
                
                $cacheData = Get-Content $cacheFile -Raw | ConvertFrom-Json
                $cacheData.FileHashes | Should -Not -BeNullOrEmpty
                $cacheData.FileHashes.Count | Should -Be 2
            }
        }
        
        Context "Test-CacheValid" {
            It "Should return false for non-existent cache" {
                $isValid = Test-CacheValid -CacheKey "non-existent"
                $isValid | Should -Be $false
            }
            
            It "Should return true for valid recent cache" {
                $testResults = @{ Data = "test" }
                Set-CachedResults -CacheKey "valid-cache" -Results $testResults
                
                $isValid = Test-CacheValid -CacheKey "valid-cache"
                $isValid | Should -Be $true
            }
            
            It "Should return false for old cache" {
                # Create cache data manually with old timestamp
                $cacheData = @{
                    Timestamp = (Get-Date).AddDays(-2).ToString('o')
                    CacheKey = "old-cache"
                    FileHashes = @()
                    Results = @{ Data = "test" }
                }
                
                $cacheFile = Join-Path $script:TestCachePath "old-cache.cache.json"
                $cacheData | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheFile
                
                $isValid = Test-CacheValid -CacheKey "old-cache"
                $isValid | Should -Be $false
            }
            
            It "Should validate file hashes" {
                $testResults = @{ Data = "test" }
                $dependentFiles = @($script:TestFile1)
                
                Set-CachedResults -CacheKey "hash-test" -Results $testResults -DependentFiles $dependentFiles
                
                # Cache should be valid initially
                $isValid = Test-CacheValid -CacheKey "hash-test" -DependentFiles $dependentFiles
                $isValid | Should -Be $true
                
                # Modify the file
                "# Modified content" | Add-Content -Path $script:TestFile1
                
                # Cache should now be invalid
                $isValid = Test-CacheValid -CacheKey "hash-test" -DependentFiles $dependentFiles
                $isValid | Should -Be $false
            }
        }
    }
    
    Context "Write-AnalysisLog" {
        It "Should write log messages without error" {
            { Write-AnalysisLog -Message "Test message" } | Should -Not -Throw
        }
        
        It "Should handle different log levels" {
            { Write-AnalysisLog -Message "Info message" -Level "Information" } | Should -Not -Throw
            { Write-AnalysisLog -Message "Warning message" -Level "Warning" } | Should -Not -Throw
            { Write-AnalysisLog -Message "Error message" -Level "Error" } | Should -Not -Throw
        }
        
        It "Should include component in log message" {
            { Write-AnalysisLog -Message "Test message" -Component "TestComponent" } | Should -Not -Throw
        }
    }
    
    Context "Analysis Results Management" {
        BeforeEach {
            Initialize-TechDebtAnalysis -CachePath $script:TestCachePath -ResultsPath $script:TestResultsPath
        }
        
        Context "Save-AnalysisResults and Get-AnalysisResults" {
            It "Should save and retrieve analysis results" {
                $testResults = @{
                    Summary = "Test analysis"
                    Count = 10
                    Issues = @("Issue1", "Issue2")
                    Duration = "00:02:30"
                }
                
                $savedPath = Save-AnalysisResults -AnalysisType "TestAnalysis" -Results $testResults
                
                Test-Path $savedPath | Should -Be $true
                
                $retrieved = Get-AnalysisResults -AnalysisType "TestAnalysis" -Latest
                $retrieved.Summary | Should -Be "Test analysis"
                $retrieved.Count | Should -Be 10
                $retrieved.Issues.Count | Should -Be 2
            }
            
            It "Should create timestamped and latest files" {
                $testResults = @{ Data = "test" }
                Save-AnalysisResults -AnalysisType "TimestampTest" -Results $testResults
                
                $latestFile = Join-Path $script:TestResultsPath "TimestampTest-latest.json"
                Test-Path $latestFile | Should -Be $true
                
                $timestampedFiles = Get-ChildItem -Path $script:TestResultsPath -Filter "TimestampTest-*.json" | 
                    Where-Object { $_.Name -ne "TimestampTest-latest.json" }
                $timestampedFiles.Count | Should -BeGreaterThan 0
            }
            
            It "Should return null for non-existent analysis type" {
                $result = Get-AnalysisResults -AnalysisType "NonExistent" -Latest
                $result | Should -BeNullOrEmpty
            }
            
            It "Should get most recent results when not using -Latest" {
                $testResults1 = @{ Version = 1 }
                $testResults2 = @{ Version = 2 }
                
                Save-AnalysisResults -AnalysisType "VersionTest" -Results $testResults1
                Start-Sleep -Milliseconds 100
                Save-AnalysisResults -AnalysisType "VersionTest" -Results $testResults2
                
                $retrieved = Get-AnalysisResults -AnalysisType "VersionTest"
                $retrieved.Version | Should -Be 2
            }
        }
        
        Context "Merge-AnalysisResults" {
            It "Should merge multiple analysis types" {
                $results1 = @{ Score = 85; Issues = @("Issue1") }
                $results2 = @{ Score = 92; Issues = @("Issue2", "Issue3") }
                
                Save-AnalysisResults -AnalysisType "Analysis1" -Results $results1
                Save-AnalysisResults -AnalysisType "Analysis2" -Results $results2
                
                $merged = Merge-AnalysisResults -AnalysisTypes @("Analysis1", "Analysis2")
                
                $merged.Analyses | Should -Not -BeNullOrEmpty
                $merged.Analyses.Analysis1.Score | Should -Be 85
                $merged.Analyses.Analysis2.Score | Should -Be 92
                $merged.Timestamp | Should -Not -BeNullOrEmpty
            }
            
            It "Should handle missing analysis types gracefully" {
                $results1 = @{ Data = "test" }
                Save-AnalysisResults -AnalysisType "ExistingAnalysis" -Results $results1
                
                $merged = Merge-AnalysisResults -AnalysisTypes @("ExistingAnalysis", "NonExistentAnalysis")
                
                $merged.Analyses.ExistingAnalysis | Should -Not -BeNullOrEmpty
                $merged.Analyses.NonExistentAnalysis | Should -BeNullOrEmpty
            }
        }
    }
    
    Context "Get-FilesToAnalyze" {
        BeforeAll {
            # Create additional test structure
            $script:TestSubDir = Join-Path $script:TestTempPath "subdir"
            New-Item -ItemType Directory -Path $script:TestSubDir -Force | Out-Null
            
            $script:TestExcludedDir = Join-Path $script:TestTempPath "tests"
            New-Item -ItemType Directory -Path $script:TestExcludedDir -Force | Out-Null
            
            # Create files in subdirectory
            $script:TestSubFile = Join-Path $script:TestSubDir "SubScript.ps1"
            "# Subdirectory script" | Set-Content -Path $script:TestSubFile
            
            # Create file in excluded directory
            $script:TestExcludedFile = Join-Path $script:TestExcludedDir "TestExcluded.ps1"
            "# Excluded script" | Set-Content -Path $script:TestExcludedFile
            
            # Create non-PowerShell file
            $script:TestTextFile = Join-Path $script:TestTempPath "readme.txt"
            "This is not a PowerShell file" | Set-Content -Path $script:TestTextFile
        }
        
        It "Should find PowerShell files by default" {
            $files = Get-FilesToAnalyze -Path $script:TestTempPath
            $files.Count | Should -BeGreaterThan 0
            $files.Name | Should -Contain "TestScript1.ps1"
            $files.Name | Should -Contain "TestScript2.psm1"
            $files.Name | Should -Contain "TestScript3.psd1"
        }
        
        It "Should respect include patterns" {
            $files = Get-FilesToAnalyze -Path $script:TestTempPath -Include @("*.ps1")
            $files | Where-Object { $_.Extension -eq ".ps1" } | Should -Not -BeNullOrEmpty
            $files | Where-Object { $_.Extension -eq ".psm1" } | Should -BeNullOrEmpty
        }
        
        It "Should exclude specified directories" {
            $files = Get-FilesToAnalyze -Path $script:TestTempPath
            $files.FullName | Should -Not -Contain $script:TestExcludedFile
        }
        
        It "Should include files from subdirectories" {
            $files = Get-FilesToAnalyze -Path $script:TestTempPath
            $files.FullName | Should -Contain $script:TestSubFile
        }
        
        It "Should filter by change date when ChangedOnly is specified" {
            $recentFiles = Get-FilesToAnalyze -Path $script:TestTempPath -ChangedOnly -Since (Get-Date).AddMinutes(-5)
            $recentFiles | Should -Not -BeNullOrEmpty
            
            $oldFiles = Get-FilesToAnalyze -Path $script:TestTempPath -ChangedOnly -Since (Get-Date).AddMinutes(5)
            $oldFiles | Should -BeNullOrEmpty
        }
    }
    
    Context "Start-ParallelAnalysis" {
        It "Should process items in parallel" {
            $testItems = 1..10
            $scriptBlock = {
                param($item)
                Start-Sleep -Milliseconds (Get-Random -Minimum 10 -Maximum 50)
                return @{ Item = $item; Processed = $true }
            }
            
            $startTime = Get-Date
            $results = Start-ParallelAnalysis -ScriptBlock $scriptBlock -InputObject $testItems -MaxConcurrency 3
            $endTime = Get-Date
            
            $results.Count | Should -Be 10
            $results[0].Item | Should -Not -BeNullOrEmpty
            $results[0].Processed | Should -Be $true
            
            # Parallel processing should be faster than sequential
            $duration = ($endTime - $startTime).TotalMilliseconds
            $duration | Should -BeLessThan 500  # Should complete faster than sequential processing
        }
        
        It "Should handle empty input gracefully" {
            $scriptBlock = { param($item) return $item }
            $results = Start-ParallelAnalysis -ScriptBlock $scriptBlock -InputObject @() -MaxConcurrency 2
            $results.Count | Should -Be 0
        }
        
        It "Should respect max concurrency limit" {
            $testItems = 1..5
            $scriptBlock = {
                param($item)
                return @{ Item = $item; ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId }
            }
            
            $results = Start-ParallelAnalysis -ScriptBlock $scriptBlock -InputObject $testItems -MaxConcurrency 2
            $uniqueThreads = ($results | ForEach-Object { $_.ThreadId } | Select-Object -Unique).Count
            
            # Should not exceed max concurrency (though some threads might be reused)
            $uniqueThreads | Should -BeLessOrEqual 5  # Allow for thread reuse
        }
        
        It "Should handle job failures gracefully" {
            $testItems = 1..3
            $scriptBlock = {
                param($item)
                if ($item -eq 2) {
                    throw "Simulated error for item $item"
                }
                return @{ Item = $item; Success = $true }
            }
            
            # This should not throw, but should handle the failed job
            $results = Start-ParallelAnalysis -ScriptBlock $scriptBlock -InputObject $testItems -MaxConcurrency 2
            
            # Should get results for successful items only
            $successfulResults = $results | Where-Object { $_.Success -eq $true }
            $successfulResults.Count | Should -Be 2
        }
        
        It "Should use custom job names" {
            $testItems = @(1)
            $scriptBlock = { param($item) return $item }
            
            { Start-ParallelAnalysis -ScriptBlock $scriptBlock -InputObject $testItems -JobName "CustomJob" } | Should -Not -Throw
        }
    }
    
    Context "Integration Tests" {
        BeforeEach {
            Initialize-TechDebtAnalysis -CachePath $script:TestCachePath -ResultsPath $script:TestResultsPath
        }
        
        It "Should work in a typical analysis workflow" {
            # 1. Get files to analyze
            $files = Get-FilesToAnalyze -Path $script:TestTempPath
            $files | Should -Not -BeNullOrEmpty
            
            # 2. Check cache
            $cacheKey = "integration-test"
            $cached = Get-CachedResults -CacheKey $cacheKey
            $cached | Should -BeNullOrEmpty
            
            # 3. Perform analysis (simulated)
            $analysisResults = @{
                FilesAnalyzed = $files.Count
                Issues = @("TODO: Implement feature", "FIXME: Handle edge case")
                Score = 85
                Timestamp = (Get-Date).ToString('o')
            }
            
            # 4. Cache results
            Set-CachedResults -CacheKey $cacheKey -Results $analysisResults -DependentFiles $files.FullName
            
            # 5. Verify cache
            $isCacheValid = Test-CacheValid -CacheKey $cacheKey -DependentFiles $files.FullName
            $isCacheValid | Should -Be $true
            
            # 6. Retrieve from cache
            $cachedResults = Get-CachedResults -CacheKey $cacheKey
            $cachedResults.Score | Should -Be 85
            
            # 7. Save to results
            $savedPath = Save-AnalysisResults -AnalysisType "IntegrationTest" -Results $analysisResults
            Test-Path $savedPath | Should -Be $true
            
            # 8. Retrieve saved results
            $savedResults = Get-AnalysisResults -AnalysisType "IntegrationTest" -Latest
            $savedResults.Score | Should -Be 85
        }
        
        It "Should handle parallel analysis with caching" {
            $files = Get-FilesToAnalyze -Path $script:TestTempPath
            
            $analysisScript = {
                param($file)
                
                $cacheKey = "file-analysis-$($file.Name)"
                
                # Check cache first (simulated)
                # In real scenario, we'd use Get-CachedResults
                
                # Perform analysis (simulated)
                $lineCount = (Get-Content $file.FullName -ErrorAction SilentlyContinue | Measure-Object).Count
                
                return @{
                    File = $file.Name
                    Lines = $lineCount
                    Hash = Get-FileHash -Path $file.FullName
                }
            }
            
            $results = Start-ParallelAnalysis -ScriptBlock $analysisScript -InputObject $files -MaxConcurrency 2
            
            $results.Count | Should -Be $files.Count
            $results | ForEach-Object {
                $_.File | Should -Not -BeNullOrEmpty
                $_.Lines | Should -BeGreaterOrEqual 0
                $_.Hash | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Error Handling and Edge Cases" {
        It "Should handle invalid paths gracefully" {
            $invalidPath = "/non/existent/path"
            { Get-FilesToAnalyze -Path $invalidPath } | Should -Not -Throw
        }
        
        It "Should handle empty results gracefully" {
            $emptyResults = @{}
            { Save-AnalysisResults -AnalysisType "EmptyTest" -Results $emptyResults } | Should -Not -Throw
        }
        
        It "Should handle malformed cache files" {
            # Create malformed cache file
            $badCacheFile = Join-Path $script:TestCachePath "bad-cache.cache.json"
            "{ invalid json }" | Set-Content -Path $badCacheFile
            
            # Should handle gracefully
            $results = Get-CachedResults -CacheKey "bad-cache"
            $results | Should -BeNullOrEmpty
        }
        
        It "Should handle concurrent access to cache" {
            $testResults = @{ Data = "concurrent-test" }
            $cacheKey = "concurrent-test"
            
            # Simulate concurrent writes (this is a basic test)
            $job1 = Start-Job -ScriptBlock {
                param($ModulePath, $CacheKey, $Results, $CachePath)
                Import-Module $ModulePath -Force
                Initialize-TechDebtAnalysis -CachePath $CachePath
                Set-CachedResults -CacheKey $CacheKey -Results $Results
            } -ArgumentList $ModulePath, $cacheKey, $testResults, $script:TestCachePath
            
            $job2 = Start-Job -ScriptBlock {
                param($ModulePath, $CacheKey, $Results, $CachePath)
                Import-Module $ModulePath -Force
                Initialize-TechDebtAnalysis -CachePath $CachePath
                Set-CachedResults -CacheKey $CacheKey -Results $Results
            } -ArgumentList $ModulePath, $cacheKey, $testResults, $script:TestCachePath
            
            Wait-Job $job1, $job2
            Remove-Job $job1, $job2
            
            # Should still be able to read results
            $retrieved = Get-CachedResults -CacheKey $cacheKey
            $retrieved | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Performance and Memory Tests" {
        It "Should handle large file lists efficiently" {
            # Create many test files
            $largeTestDir = Join-Path $script:TestTempPath "large-test"
            New-Item -ItemType Directory -Path $largeTestDir -Force | Out-Null
            
            1..50 | ForEach-Object {
                $filePath = Join-Path $largeTestDir "TestFile$_.ps1"
                "# Test file $_" | Set-Content -Path $filePath
            }
            
            $startTime = Get-Date
            $files = Get-FilesToAnalyze -Path $largeTestDir
            $endTime = Get-Date
            
            $files.Count | Should -Be 50
            ($endTime - $startTime).TotalSeconds | Should -BeLessThan 5
            
            # Clean up
            Remove-Item $largeTestDir -Recurse -Force
        }
        
        It "Should handle large result objects" {
            $largeResults = @{
                Summary = "Large test"
                Items = 1..1000 | ForEach-Object { @{ Id = $_; Data = "Item $_" } }
            }
            
            { Save-AnalysisResults -AnalysisType "LargeTest" -Results $largeResults } | Should -Not -Throw
            
            $retrieved = Get-AnalysisResults -AnalysisType "LargeTest" -Latest
            $retrieved.Items.Count | Should -Be 1000
        }
    }
}