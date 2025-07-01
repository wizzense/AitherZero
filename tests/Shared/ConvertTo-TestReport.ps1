#Requires -Version 7.0
<#
.SYNOPSIS
    Converts Pester test results to multiple report formats
.DESCRIPTION
    Generates comprehensive test reports in JSON, XML, HTML, and other formats
    from Pester test results with enhanced visualization and analytics.
.PARAMETER TestResult
    Pester test result object
.PARAMETER OutputPath
    Base output path for reports
.PARAMETER Format
    Report formats to generate: JSON, HTML, XML, CSV, Markdown
.PARAMETER IncludeCoverage
    Include code coverage information in reports
.PARAMETER Theme
    HTML report theme: Light, Dark, Auto
.EXAMPLE
    ConvertTo-TestReport -TestResult $result -OutputPath "./reports" -Format @('JSON', 'HTML')
#>

function ConvertTo-TestReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$TestResult,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [ValidateSet('JSON', 'HTML', 'XML', 'CSV', 'Markdown', 'All')]
        [string[]]$Format = @('JSON', 'HTML'),
        
        [hashtable]$AdditionalData = @{},
        [switch]$IncludeCoverage,
        [ValidateSet('Light', 'Dark', 'Auto')]
        [string]$Theme = 'Auto',
        [string]$ReportTitle = 'AitherZero Test Report'
    )
    
    # Ensure output directory exists
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $reportFiles = @{}
    
    # Generate base report data
    $reportData = New-BaseReportData -TestResult $TestResult -AdditionalData $AdditionalData -IncludeCoverage:$IncludeCoverage
    
    # Handle 'All' format
    if ($Format -contains 'All') {
        $Format = @('JSON', 'HTML', 'XML', 'CSV', 'Markdown')
    }
    
    foreach ($fmt in $Format) {
        Write-Host "Generating $fmt report..." -ForegroundColor Cyan
        
        switch ($fmt) {
            'JSON' {
                $reportFiles.JSON = New-JsonReport -ReportData $reportData -OutputPath $OutputPath -Timestamp $timestamp
            }
            'HTML' {
                $reportFiles.HTML = New-HtmlReport -ReportData $reportData -OutputPath $OutputPath -Timestamp $timestamp -Theme $Theme -Title $ReportTitle
            }
            'XML' {
                $reportFiles.XML = New-XmlReport -ReportData $reportData -OutputPath $OutputPath -Timestamp $timestamp
            }
            'CSV' {
                $reportFiles.CSV = New-CsvReport -ReportData $reportData -OutputPath $OutputPath -Timestamp $timestamp
            }
            'Markdown' {
                $reportFiles.Markdown = New-MarkdownReport -ReportData $reportData -OutputPath $OutputPath -Timestamp $timestamp
            }
        }
    }
    
    Write-Host "Report generation completed" -ForegroundColor Green
    return $reportFiles
}

function New-BaseReportData {
    param(
        [object]$TestResult,
        [hashtable]$AdditionalData,
        [switch]$IncludeCoverage
    )
    
    $executionTime = Get-Date
    $duration = $TestResult.Duration.TotalSeconds
    $passRate = if ($TestResult.TotalCount -gt 0) { 
        [math]::Round(($TestResult.PassedCount / $TestResult.TotalCount) * 100, 2) 
    } else { 0 }
    
    $reportData = @{
        Metadata = @{
            GeneratedAt = $executionTime.ToString('yyyy-MM-dd HH:mm:ss UTC')
            GeneratedBy = 'AitherZero Test Suite'
            Version = '2.0'
            Platform = @{
                OS = $PSVersionTable.Platform ?? $PSVersionTable.OS
                PowerShell = $PSVersionTable.PSVersion.ToString()
                Architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
                MachineName = $env:COMPUTERNAME ?? $env:HOSTNAME
                User = $env:USERNAME ?? $env:USER
            }
        }
        Summary = @{
            TotalTests = $TestResult.TotalCount
            PassedTests = $TestResult.PassedCount
            FailedTests = $TestResult.FailedCount
            SkippedTests = $TestResult.SkippedCount
            NotRunTests = $TestResult.NotRunCount
            PassRate = $passRate
            Duration = @{
                TotalSeconds = $duration
                Formatted = Format-Duration -Seconds $duration
            }
            Result = if ($TestResult.FailedCount -eq 0) { 'Success' } else { 'Failed' }
        }
        Configuration = @{
            PesterVersion = (Get-Module Pester).Version.ToString()
            TestResultFormat = $TestResult.GetType().Name
        }
        Containers = @()
        Tests = @()
        Failures = @()
        Tags = @{}
        Performance = @{
            FastestTest = $null
            SlowestTest = $null
            AverageDuration = 0
            TestsByDuration = @()
        }
    }
    
    # Add additional data
    foreach ($key in $AdditionalData.Keys) {
        $reportData[$key] = $AdditionalData[$key]
    }
    
    # Process containers
    foreach ($container in $TestResult.Containers) {
        if ($container.Type -eq 'File') {
            $containerData = @{
                Name = Split-Path $container.Name -Leaf
                FullPath = $container.Name
                Type = $container.Type
                TotalTests = $container.TotalCount
                PassedTests = $container.PassedCount
                FailedTests = $container.FailedCount
                SkippedTests = $container.SkippedCount
                NotRunTests = $container.NotRunCount
                Duration = $container.Duration.TotalSeconds
                Result = $container.Result
                PassRate = if ($container.TotalCount -gt 0) { 
                    [math]::Round(($container.PassedCount / $container.TotalCount) * 100, 2) 
                } else { 0 }
            }
            $reportData.Containers += $containerData
        }
    }
    
    # Process individual tests
    $testDurations = @()
    foreach ($test in $TestResult.Tests) {
        $testData = @{
            Name = $test.Name
            Result = $test.Result
            Duration = $test.Duration.TotalMilliseconds
            File = $test.ScriptBlock.File
            Line = $test.ScriptBlock.StartPosition.StartLine
            Tags = @($test.Tag)
        }
        
        if ($test.Result -eq 'Failed') {
            $testData.Error = @{
                Message = $test.ErrorRecord.Exception.Message
                StackTrace = $test.ErrorRecord.ScriptStackTrace
                FullException = $test.ErrorRecord.ToString()
                Category = $test.ErrorRecord.CategoryInfo.Category.ToString()
            }
            
            $reportData.Failures += $testData
        }
        
        $reportData.Tests += $testData
        $testDurations += $test.Duration.TotalMilliseconds
        
        # Collect tags
        foreach ($tag in $test.Tag) {
            if ($reportData.Tags.ContainsKey($tag)) {
                $reportData.Tags[$tag]++
            } else {
                $reportData.Tags[$tag] = 1
            }
        }
    }
    
    # Calculate performance metrics
    if ($testDurations.Count -gt 0) {
        $sortedTests = $reportData.Tests | Sort-Object Duration
        $reportData.Performance.FastestTest = $sortedTests[0]
        $reportData.Performance.SlowestTest = $sortedTests[-1]
        $reportData.Performance.AverageDuration = [math]::Round(($testDurations | Measure-Object -Average).Average, 2)
        
        # Group tests by duration ranges
        $durationRanges = @{
            'Fast (< 100ms)' = ($reportData.Tests | Where-Object { $_.Duration -lt 100 }).Count
            'Medium (100ms - 1s)' = ($reportData.Tests | Where-Object { $_.Duration -ge 100 -and $_.Duration -lt 1000 }).Count
            'Slow (1s - 5s)' = ($reportData.Tests | Where-Object { $_.Duration -ge 1000 -and $_.Duration -lt 5000 }).Count
            'Very Slow (> 5s)' = ($reportData.Tests | Where-Object { $_.Duration -ge 5000 }).Count
        }
        $reportData.Performance.TestsByDuration = $durationRanges
    }
    
    # Add code coverage if available
    if ($IncludeCoverage -and $TestResult.CodeCoverage) {
        $reportData.CodeCoverage = @{
            CoveragePercent = [math]::Round(($TestResult.CodeCoverage.CoveragePercent ?? 0), 2)
            AnalyzedFiles = @()
            MissedCommands = @()
            HitCommands = @()
        }
        
        if ($TestResult.CodeCoverage.AnalyzedFiles) {
            foreach ($file in $TestResult.CodeCoverage.AnalyzedFiles) {
                $reportData.CodeCoverage.AnalyzedFiles += @{
                    Path = $file.Path
                    CoveragePercent = [math]::Round(($file.CoveragePercent ?? 0), 2)
                    TotalLines = $file.AnalyzedCommands.Count
                    CoveredLines = $file.HitCommands.Count
                    MissedLines = $file.MissedCommands.Count
                }
            }
        }
    }
    
    return $reportData
}

function New-JsonReport {
    param(
        [hashtable]$ReportData,
        [string]$OutputPath,
        [string]$Timestamp
    )
    
    $jsonPath = Join-Path $OutputPath "test-report-$Timestamp.json"
    $ReportData | ConvertTo-Json -Depth 10 | Out-File $jsonPath -Encoding UTF8
    
    Write-Host "  JSON report: $jsonPath" -ForegroundColor Green
    return $jsonPath
}

function New-XmlReport {
    param(
        [hashtable]$ReportData,
        [string]$OutputPath,
        [string]$Timestamp
    )
    
    $xmlPath = Join-Path $OutputPath "test-report-$Timestamp.xml"
    
    # Create XML document
    $xml = New-Object System.Xml.XmlDocument
    $declaration = $xml.CreateXmlDeclaration('1.0', 'UTF-8', $null)
    $xml.AppendChild($declaration) | Out-Null
    
    # Root element
    $root = $xml.CreateElement('TestReport')
    $xml.AppendChild($root) | Out-Null
    
    # Metadata
    $metadataElement = $xml.CreateElement('Metadata')
    $root.AppendChild($metadataElement) | Out-Null
    
    foreach ($key in $ReportData.Metadata.Keys) {
        $element = $xml.CreateElement($key)
        $element.InnerText = $ReportData.Metadata[$key]
        $metadataElement.AppendChild($element) | Out-Null
    }
    
    # Summary
    $summaryElement = $xml.CreateElement('Summary')
    $root.AppendChild($summaryElement) | Out-Null
    
    foreach ($key in $ReportData.Summary.Keys) {
        $element = $xml.CreateElement($key)
        if ($ReportData.Summary[$key] -is [hashtable]) {
            foreach ($subKey in $ReportData.Summary[$key].Keys) {
                $subElement = $xml.CreateElement($subKey)
                $subElement.InnerText = $ReportData.Summary[$key][$subKey]
                $element.AppendChild($subElement) | Out-Null
            }
        } else {
            $element.InnerText = $ReportData.Summary[$key]
        }
        $summaryElement.AppendChild($element) | Out-Null
    }
    
    # Test containers
    $containersElement = $xml.CreateElement('Containers')
    $root.AppendChild($containersElement) | Out-Null
    
    foreach ($container in $ReportData.Containers) {
        $containerElement = $xml.CreateElement('Container')
        foreach ($key in $container.Keys) {
            $element = $xml.CreateElement($key)
            $element.InnerText = $container[$key]
            $containerElement.AppendChild($element) | Out-Null
        }
        $containersElement.AppendChild($containerElement) | Out-Null
    }
    
    # Failed tests
    if ($ReportData.Failures.Count -gt 0) {
        $failuresElement = $xml.CreateElement('Failures')
        $root.AppendChild($failuresElement) | Out-Null
        
        foreach ($failure in $ReportData.Failures) {
            $failureElement = $xml.CreateElement('Failure')
            
            $nameElement = $xml.CreateElement('Name')
            $nameElement.InnerText = $failure.Name
            $failureElement.AppendChild($nameElement) | Out-Null
            
            $errorElement = $xml.CreateElement('Error')
            $messageElement = $xml.CreateElement('Message')
            $messageElement.InnerText = $failure.Error.Message
            $errorElement.AppendChild($messageElement) | Out-Null
            
            $stackElement = $xml.CreateElement('StackTrace')
            $stackElement.InnerText = $failure.Error.StackTrace
            $errorElement.AppendChild($stackElement) | Out-Null
            
            $failureElement.AppendChild($errorElement) | Out-Null
            $failuresElement.AppendChild($failureElement) | Out-Null
        }
    }
    
    $xml.Save($xmlPath)
    Write-Host "  XML report: $xmlPath" -ForegroundColor Green
    return $xmlPath
}

function New-CsvReport {
    param(
        [hashtable]$ReportData,
        [string]$OutputPath,
        [string]$Timestamp
    )
    
    # Generate test results CSV
    $csvPath = Join-Path $OutputPath "test-results-$Timestamp.csv"
    
    $csvData = @()
    foreach ($test in $ReportData.Tests) {
        $csvData += [PSCustomObject]@{
            Name = $test.Name
            Result = $test.Result
            Duration = $test.Duration
            File = Split-Path $test.File -Leaf
            Line = $test.Line
            Tags = ($test.Tags -join ';')
            Error = if ($test.Error) { $test.Error.Message } else { '' }
        }
    }
    
    $csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    
    # Generate summary CSV
    $summaryPath = Join-Path $OutputPath "test-summary-$Timestamp.csv"
    $summaryData = @()
    
    foreach ($container in $ReportData.Containers) {
        $summaryData += [PSCustomObject]@{
            TestFile = $container.Name
            TotalTests = $container.TotalTests
            PassedTests = $container.PassedTests
            FailedTests = $container.FailedTests
            SkippedTests = $container.SkippedTests
            PassRate = "$($container.PassRate)%"
            Duration = $container.Duration
            Result = $container.Result
        }
    }
    
    $summaryData | Export-Csv -Path $summaryPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "  CSV reports: $csvPath, $summaryPath" -ForegroundColor Green
    return @($csvPath, $summaryPath)
}

function New-MarkdownReport {
    param(
        [hashtable]$ReportData,
        [string]$OutputPath,
        [string]$Timestamp
    )
    
    $mdPath = Join-Path $OutputPath "test-report-$Timestamp.md"
    
    $markdown = @"
# Test Report

**Generated**: $($ReportData.Metadata.GeneratedAt)  
**Platform**: $($ReportData.Metadata.Platform.OS) | PowerShell $($ReportData.Metadata.Platform.PowerShell)  
**Duration**: $($ReportData.Summary.Duration.Formatted)

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | $($ReportData.Summary.TotalTests) |
| Passed | $($ReportData.Summary.PassedTests) ✅ |
| Failed | $($ReportData.Summary.FailedTests) ❌ |
| Skipped | $($ReportData.Summary.SkippedTests) ⏭️ |
| Pass Rate | $($ReportData.Summary.PassRate)% |
| Result | $($ReportData.Summary.Result) |

## Test Files

| File | Total | Passed | Failed | Pass Rate | Duration |
|------|-------|--------|--------|-----------|----------|
"@
    
    foreach ($container in $ReportData.Containers) {
        $markdown += "`n| $($container.Name) | $($container.TotalTests) | $($container.PassedTests) | $($container.FailedTests) | $($container.PassRate)% | $($container.Duration)s |"
    }
    
    if ($ReportData.Failures.Count -gt 0) {
        $markdown += @"

## Failed Tests

"@
        foreach ($failure in $ReportData.Failures) {
            $markdown += @"

### $($failure.Name)

**File**: $($failure.File):$($failure.Line)  
**Duration**: $($failure.Duration)ms

**Error**:
``````
$($failure.Error.Message)
``````

"@
        }
    }
    
    if ($ReportData.Tags.Count -gt 0) {
        $markdown += @"

## Tags

| Tag | Count |
|-----|-------|
"@
        foreach ($tag in ($ReportData.Tags.GetEnumerator() | Sort-Object Value -Descending)) {
            $markdown += "`n| $($tag.Key) | $($tag.Value) |"
        }
    }
    
    $markdown += @"

## Performance

- **Fastest Test**: $($ReportData.Performance.FastestTest.Name) ($($ReportData.Performance.FastestTest.Duration)ms)
- **Slowest Test**: $($ReportData.Performance.SlowestTest.Name) ($($ReportData.Performance.SlowestTest.Duration)ms)
- **Average Duration**: $($ReportData.Performance.AverageDuration)ms

### Duration Distribution

"@
    
    foreach ($range in $ReportData.Performance.TestsByDuration.GetEnumerator()) {
        $markdown += "- **$($range.Key)**: $($range.Value) tests`n"
    }
    
    if ($ReportData.CodeCoverage) {
        $markdown += @"

## Code Coverage

**Overall Coverage**: $($ReportData.CodeCoverage.CoveragePercent)%

### File Coverage

| File | Coverage | Lines | Covered | Missed |
|------|----------|-------|---------|--------|
"@
        foreach ($file in $ReportData.CodeCoverage.AnalyzedFiles) {
            $fileName = Split-Path $file.Path -Leaf
            $markdown += "`n| $fileName | $($file.CoveragePercent)% | $($file.TotalLines) | $($file.CoveredLines) | $($file.MissedLines) |"
        }
    }
    
    $markdown += @"

---
*Generated by AitherZero Test Suite v$($ReportData.Metadata.Version)*
"@
    
    $markdown | Out-File $mdPath -Encoding UTF8
    Write-Host "  Markdown report: $mdPath" -ForegroundColor Green
    return $mdPath
}

function New-HtmlReport {
    param(
        [hashtable]$ReportData,
        [string]$OutputPath,
        [string]$Timestamp,
        [string]$Theme,
        [string]$Title
    )
    
    $htmlPath = Join-Path $OutputPath "test-report-$Timestamp.html"
    
    # Determine theme colors
    $themeColors = if ($Theme -eq 'Dark') {
        @{
            Background = '#1a1a1a'
            CardBackground = '#2d2d2d'
            TextColor = '#ffffff'
            BorderColor = '#404040'
        }
    } else {
        @{
            Background = '#f8f9fa'
            CardBackground = '#ffffff'
            TextColor = '#333333'
            BorderColor = '#e9ecef'
        }
    }
    
    $passRate = $ReportData.Summary.PassRate
    $passRateColor = if ($passRate -ge 95) { '#28a745' } elseif ($passRate -ge 80) { '#ffc107' } else { '#dc3545' }
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$Title</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: $($themeColors.Background);
            color: $($themeColors.TextColor);
            line-height: 1.6;
        }
        .container { max-width: 1400px; margin: 0 auto; padding: 20px; }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white; padding: 40px; border-radius: 15px; margin-bottom: 30px;
            box-shadow: 0 15px 35px rgba(0,0,0,0.1);
        }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .summary-grid {
            display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px; margin-bottom: 30px;
        }
        .card {
            background: $($themeColors.CardBackground); padding: 25px; border-radius: 15px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.08); transition: transform 0.2s;
            border: 1px solid $($themeColors.BorderColor);
        }
        .card:hover { transform: translateY(-5px); }
        .chart-container { position: relative; height: 300px; margin: 20px 0; }
        .pass-rate-circle {
            width: 120px; height: 120px; margin: 0 auto;
            background: conic-gradient($passRateColor 0deg, $passRateColor $($passRate * 3.6)deg, $($themeColors.BorderColor) $($passRate * 3.6)deg);
            border-radius: 50%; position: relative; display: flex; align-items: center; justify-content: center;
        }
        .pass-rate-inner {
            width: 80px; height: 80px; background: $($themeColors.CardBackground);
            border-radius: 50%; display: flex; align-items: center; justify-content: center;
            font-weight: bold; font-size: 1.2em;
        }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid $($themeColors.BorderColor); }
        th { background: $($themeColors.BorderColor); font-weight: 600; }
        .passed { color: #28a745; } .failed { color: #dc3545; } .skipped { color: #ffc107; }
        .failure-details { background: #fff5f5; border-left: 4px solid #dc3545; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .toggle { cursor: pointer; user-select: none; } .collapsible { display: none; }
        .toggle.active + .collapsible { display: block; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>$Title</h1>
            <p>Generated: $($ReportData.Metadata.GeneratedAt) | Platform: $($ReportData.Metadata.Platform.OS) | PowerShell $($ReportData.Metadata.Platform.PowerShell)</p>
        </div>
        
        <div class="summary-grid">
            <div class="card">
                <h3>Pass Rate</h3>
                <div class="pass-rate-circle">
                    <div class="pass-rate-inner">$($passRate)%</div>
                </div>
            </div>
            <div class="card">
                <h3>Total Tests</h3>
                <div style="font-size: 2.5em; font-weight: bold; color: #17a2b8;">$($ReportData.Summary.TotalTests)</div>
            </div>
            <div class="card">
                <h3>Passed</h3>
                <div style="font-size: 2.5em; font-weight: bold;" class="passed">$($ReportData.Summary.PassedTests)</div>
            </div>
            <div class="card">
                <h3>Failed</h3>
                <div style="font-size: 2.5em; font-weight: bold;" class="failed">$($ReportData.Summary.FailedTests)</div>
            </div>
            <div class="card">
                <h3>Duration</h3>
                <div style="font-size: 2.5em; font-weight: bold; color: #6f42c1;">$($ReportData.Summary.Duration.Formatted)</div>
            </div>
        </div>
        
        <div class="card">
            <h2>Test Results by File</h2>
            <table>
                <thead>
                    <tr><th>File</th><th>Total</th><th>Passed</th><th>Failed</th><th>Pass Rate</th><th>Duration</th></tr>
                </thead>
                <tbody>
"@
    
    foreach ($container in $ReportData.Containers) {
        $html += @"
                    <tr>
                        <td>$($container.Name)</td>
                        <td>$($container.TotalTests)</td>
                        <td class="passed">$($container.PassedTests)</td>
                        <td class="failed">$($container.FailedTests)</td>
                        <td>$($container.PassRate)%</td>
                        <td>$([math]::Round($container.Duration, 2))s</td>
                    </tr>
"@
    }
    
    $html += @"
                </tbody>
            </table>
        </div>
        
        <div class="card">
            <h2>Performance Analysis</h2>
            <div class="chart-container">
                <canvas id="durationChart"></canvas>
            </div>
        </div>
"@
    
    if ($ReportData.Failures.Count -gt 0) {
        $html += @"
        <div class="card">
            <h2>Failed Tests ($($ReportData.Failures.Count))</h2>
"@
        
        foreach ($i = 0; $i -lt $ReportData.Failures.Count; $i++) {
            $failure = $ReportData.Failures[$i]
            $html += @"
            <div class="failure-details">
                <h4 class="toggle" onclick="toggleCollapse($i)">$($failure.Name) ▼</h4>
                <div id="collapse$i" class="collapsible">
                    <p><strong>File:</strong> $($failure.File):$($failure.Line)</p>
                    <p><strong>Duration:</strong> $($failure.Duration)ms</p>
                    <p><strong>Error:</strong></p>
                    <pre style="background: #f8f9fa; padding: 10px; border-radius: 5px; overflow-x: auto;">$([System.Web.HttpUtility]::HtmlEncode($failure.Error.Message))</pre>
                </div>
            </div>
"@
        }
        
        $html += @"
        </div>
"@
    }
    
    # Generate chart data
    $durationLabels = @()
    $durationData = @()
    foreach ($range in $ReportData.Performance.TestsByDuration.GetEnumerator()) {
        $durationLabels += "'$($range.Key)'"
        $durationData += $range.Value
    }
    
    $html += @"
    </div>
    
    <script>
        function toggleCollapse(id) {
            const element = document.getElementById('collapse' + id);
            const toggle = element.previousElementSibling;
            if (element.style.display === 'block') {
                element.style.display = 'none';
                toggle.innerHTML = toggle.innerHTML.replace('▲', '▼');
            } else {
                element.style.display = 'block';
                toggle.innerHTML = toggle.innerHTML.replace('▼', '▲');
            }
        }
        
        // Duration chart
        const ctx = document.getElementById('durationChart').getContext('2d');
        new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: [$($durationLabels -join ', ')],
                datasets: [{
                    data: [$($durationData -join ', ')],
                    backgroundColor: ['#28a745', '#17a2b8', '#ffc107', '#dc3545']
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    title: {
                        display: true,
                        text: 'Test Duration Distribution'
                    },
                    legend: {
                        position: 'bottom'
                    }
                }
            }
        });
    </script>
</body>
</html>
"@
    
    $html | Out-File $htmlPath -Encoding UTF8
    Write-Host "  HTML report: $htmlPath" -ForegroundColor Green
    return $htmlPath
}

function Format-Duration {
    param([double]$Seconds)
    
    if ($Seconds -lt 60) {
        return "$([math]::Round($Seconds, 2))s"
    } elseif ($Seconds -lt 3600) {
        $minutes = [math]::Floor($Seconds / 60)
        $remainingSeconds = $Seconds % 60
        return "$($minutes)m $([math]::Round($remainingSeconds, 1))s"
    } else {
        $hours = [math]::Floor($Seconds / 3600)
        $remainingMinutes = [math]::Floor(($Seconds % 3600) / 60)
        $remainingSeconds = $Seconds % 60
        return "$($hours)h $($remainingMinutes)m $([math]::Round($remainingSeconds, 1))s"
    }
}

Export-ModuleMember -Function ConvertTo-TestReport