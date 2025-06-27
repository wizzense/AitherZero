<#
.SYNOPSIS
Extensible test runner with automatic discovery and categorization

.DESCRIPTION
This script provides enhanced test execution with:
- Automatic test discovery
- Platform-specific filtering
- Performance monitoring
- Detailed reporting
- Parallel execution support

.EXAMPLE
./Invoke-ExtensibleTests.ps1 -Category "Installer" -Platform "Windows"

.EXAMPLE
./Invoke-ExtensibleTests.ps1 -ScriptPattern "*Install*" -Parallel
#>

param(
    string$Category = @(),
    
    ValidateSet('Windows', 'Linux', 'macOS', 'All')
    string$Platform = 'All',
    
    string$ScriptPattern = '*',
    
    string$TestPattern = '*',
    
    switch$Parallel,
    
    switch$EnableCodeCoverage,
    
    switch$GenerateReport,
    
    string$OutputPath = 'coverage',
    
    int$MaxParallelJobs = 4,
    
    switch$Verbose
)

# Load required modules
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

function Get-TestCategories {
    <#
    .SYNOPSIS
    Discovers and categorizes test files
    #>
    param(string$TestsPath)
    
    $testFiles = Get-ChildItem $TestsPath -Filter "*.Tests.ps1" -Recurse
    $categories = @{}
    
    foreach ($file in $testFiles) {
        $content = Get-Content $file.FullName -Raw
        
        # Determine category based on content analysis
            } elseif ($content -match 'Cross-platformCrossPlatform') {
            $category = 'CrossPlatform'
        }
        
        # Determine platform compatibility
        $platforms = @('Windows', 'Linux', 'macOS')  # Default to all
        
        if ($content -match '-Skip:\$SkipNonWindowsRequiredPlatforms.*Windows') {
            $platforms = @('Windows')
        } elseif ($content -match 'RequiredPlatforms.*Linux') {
            $platforms = @('Linux')
        } elseif ($content -match 'RequiredPlatforms.*macOS') {
            $platforms = @('macOS')
        }
        
        if (-not $categories.ContainsKey($category)) {
            $categories$category = @()
        }
        
        $categories$category += @{
            Path = $file.FullName
            Name = $file.BaseName
            Category = $category
            Platforms = $platforms
            Size = $file.Length
            LastWrite = $file.LastWriteTime
        }
    }
    
    return $categories
}

function Test-PlatformCompatibility {
    param(string$TestPlatforms, string$TargetPlatform)
    
    if ($TargetPlatform -eq 'All') {
        return $true
    }
    
    return $TargetPlatform -in $TestPlatforms
}

function Invoke-TestBatch {
    param(
        object$Tests,
        object$Configuration,
        switch$Parallel
    )
    
                TestResult = @{ 
                Enabled = $Configuration.TestResult.Enabled.Value
                OutputPath = $Configuration.TestResult.OutputPath.Value
            }
        }
        
        if ($Configuration.CodeCoverage.Enabled.Value) {
                            $config = New-PesterConfiguration -Hashtable $ConfigHash
                    $result = Invoke-Pester -Path $TestPath -Configuration $config -PassThru
                    return @{
                        Success = $true
                        Result = $result
                        Path = $TestPath
                    }
                } catch {
                    return @{
                        Success = $false
                        Error = $_.Exception.Message
                        Path = $TestPath
                    }
                }
            
        # Wait for jobs and collect results
        $results = @()
        foreach ($jobInfo in $jobs) {
            $result = Receive-Job -Job $jobInfo.Job -Wait
            Remo        $results = @()
        foreach ($test in $Tests) {
            Write-Host "Running test: $($test.Name)" -ForegroundColor Cyan
            
            try {
                $result = Invoke-Pester -Path $test.Path -Configuration $Configuration -PassThru
                $results += @{
                    Success = $true
                    Result = $result
                    Path = $test.Path
                }
            } catch {
                $results += @{
                    Success = $false
                    Error = $_.Exception.Message
                    Path = $test.Path
                }
                Write-Error "Test failed: $($test.Path) - $_"
            }
        }
        
        return $    $reportData = @{
        Timestamp = Get-Date
        Platform = $script:CurrentPlatform
        TotalTests = $Results.Count
        PassedTests = (Results | Where-Object{ $_.Success -and $_.Result.FailedCount -eq 0 }).Count
        FailedTests = (Results | Where-Object{ -not $_.Success -or $_.Result.FailedCount -gt 0 }).Count
        Categories = @{}
        Details = $Results
    }
    
    # Group by category for summary
    foreach ($result in $Results) {
        $testName = System.IO.Path::GetFileNameWithoutExtension($result.Path)
        $category = 'Unknown'
        
        if ($testName -match 'Install') { $category = 'Installer' }
        elseif ($testName -match 'Enable') { $category = 'Feature' }
        elseif ($testName -match 'Config') { $category = 'Configuration' }
        elseif ($testName -match 'Service') { $category = 'Service' }
        
        if (-not $reportData.Categories.ContainsKey($category)) {
            $reportData.Categories$category = @{
                Total = 0
                Passed = 0
                Failed = 0
            }
        }
        
        $reportData.Categories$category.Total++
        if ($result.Success -and $result.Result.FailedCount -eq 0) {
            $reportData.Categories$category.Passed++
        } else {
            $reportData.Categories$category.Failed++
        }
    }
        <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background: #f0f0f0; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .passed { color: green; font-weight: bold; }
        .failed { color: red; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .category-summary { margin: 10px 0; }
    </style>
</head>
<body>
    <h1>OpenTofu Lab Automation Test Report</h1>
    
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Generated:</strong> $($reportData.Timestamp)</p>
        <p><strong>Platform:</strong> $($reportData.Platform)</p>
        <p><strong>Total Tests:</strong> $($reportData.TotalTests)</p>
        <p><strong>Passed:</strong> <span class="passed">$($reportData.PassedTests)</span></p>
        <p><strong>Failed:</strong> <span class="failed">$($reportData.FailedTests)</span></p>
    </div>
    
    <div class="category-summary">
        <h2>Results by Category</h2>
        <table>
            <tr><th>Category</th><th>Total</th><th>Passed</th><th>Failed</th><th>Success Rate</th></tr>
"@
        $html += @"
        </table>
    </div>
    
    <div class="test-details">
        <h2>Test Details</h2>
        <table>
            <tr><th>Test</th><th>Status</th><th>Duration</th><th>Details</th></tr>
"@
    
    foreach ($result in $Results) {
        $testName = System.IO.Path::GetFileNameWithoutExtension($result.Path)
        $status = if ($result.Success -and $result.Result.FailedCount -eq 0) { 'PASSED'    } else { 'FAILED'    }
        $statusClass = if ($status -eq 'PASSED') { 'passed'    } else { 'failed'    }
        $duration = if ($result.Result) { $result.Result.Duration    } else { 'N/A'    }
        $details = if ($result.Error) { $result.Error    } else { "$($result.Result.PassedCount) passed, $($result.Result.FailedCount) failed"    }
        
        $html += "<tr><td>$testName</td><td class='$statusClass'>$status</td><td>$duration</td><td>$details</td></tr>`n"
    }
    
    $html += @"
        </table>
    </div>
</body>
</html>
"@
    
    $reportPath = Join-Path $OutputPath 'test-report.html'
    Set-Content -Path $reportPath -Value $html -Encoding UTF8
    Write-Host "Test report generated: $reportPath" -ForegroundColor Green
    
    # Also generate JSON for programmatic consumption
    $jsonPath = Join-Path $OutputPath 'test-report.json'
    reportData | ConvertTo-Json-Depth 10  Set-Content -Path $jsonPath -Encoding UTF8
    Write-Host "JSON report generated: $jsonPath" -ForegroundColor Green
}

# Main execution
try {
    $testsPath = Join-Path $PSScriptRoot '..'
    
    Write-Host "Discovering tests..." -ForegroundColor Yellow
    $categories = Get-TestCategories $testsPath
    
    # Filter by category if specified
    $selectedTests = @()
    if ($Category.Count -gt 0) {
        foreach ($cat in $Category) {
            if ($categories.ContainsKey($cat)) {
                $selectedTests += $categories$cat
            }
        }
    } else {
        # Include all categories
        foreach ($cat in $categories.Keys) {
            $selectedTests += $categories$cat
        }
    }
    
    # Filter by platform compatibility
    $selectedTests = selectedTests | Where-Object{ Test-PlatformCompatibility $_.Platforms $Platform }
    
    # Filter by script pattern
    if ($ScriptPattern -ne '*') {
        $selectedTests = selectedTests | Where-Object{ $_.Name -like $ScriptPattern }
    }
    
    Write-Host "Found $($selectedTests.Count) compatible tests for platform: $Platform" -ForegroundColor Green
    
    if ($selectedTests.Count -eq 0) {
        Write-Warning "No tests found matching criteria"
        exit 0
    }
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    
    # Configure Pester
    $pesterConfig = New-PesterConfiguration
    $pesterConfig.Run.PassThru = $true
    $pesterConfig.Output.Verbosity = if ($Verbose) { 'Detailed' } else { 'Normal' }
    
    if ($EnableCodeCoverage) {
    
        $pesterConfig.CodeCoverage.Enabled = $true
        $pesterConfig.CodeCoverage.Path = @('aither-core/scripts', 'aither-core/modules')
        $pesterConfig.CodeCoverage.OutputPath = Join-Path $OutputPath 'coverage.xml'
        
    }
    
    $pesterConfig.TestResult.Enabled = $true
    $pesterConfig.TestResult.OutputPath = Join-Path $OutputPath 'testResults.xml'
    
    # Execute tests
    Write-Host "Executing tests..." -ForegroundColor Yellow
    $results = Invoke-TestBatch -Tests $selectedTests -Configuration $pesterConfig -Parallel:$Parallel
    
    # Generate report if requested
    if ($GenerateReport) {
        Write-Host "Generating test report..." -ForegroundColor Yellow
        New-TestReport -Results $results -OutputPath $OutputPath
    }
    
    # Summary
    $totalTests = $results.Count
    $passedTests = (results | Where-Object{ $_.Success -and $_.Result.FailedCount -eq 0 }).Count
    $failedTests = $totalTests - $passedTests
    
    Write-Host "`nTest Execution Summary:" -ForegroundColor Cyan
    Write-Host "  Total Tests: $totalTests"
    Write-Host "  Passed: $passedTests" -ForegroundColor Green
    Write-Host "  Failed: $failedTests" -ForegroundColor Red
    Write-Host "  Success Rate: $([Math]::Round(($passedTests / $totalTests) * 100, 1))%"
    
    if ($failedTests -gt 0) {
        Write-Host "`nFailed Tests:" -ForegroundColor Red
        $failedResults = results | Where-Object{ -not $_.Success -or $_.Result.FailedCount -gt 0 }
        foreach ($failed in $failedResults) {
            $testName = System.IO.Path::GetFileNameWithoutExtension($failed.Path)
            $error = if ($failed.Error) { $failed.Error    } else { "Test failures: $($failed.Result.FailedCount)"    }
            Write-Host "  - $testName`: $error" -ForegroundColor Red
        }
        exit 1
    }
    
    Write-Host "`nAll tests passed!" -ForegroundColor Green
    
} catch {
    Write-Error "Test execution failed: $_"
    exit 1
}
