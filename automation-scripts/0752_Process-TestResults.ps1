#Requires -Version 7.0

<#
.SYNOPSIS
    Process test results and update tracker with failures
.DESCRIPTION
    Parses NUnit XML test results and adds failing tests to the tracker file.
    Only adds new failures that aren't already being tracked.
    
    Exit Codes:
    0   - Results processed successfully
    1   - Error processing results
    
.NOTES
    Stage: Testing
    Order: 0752
    Dependencies: 0751, 0402
    Tags: testing, tracking, automation, xml
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TrackerPath = './test-fix-tracker.json',
    [string]$TestResultsPath = './tests/reports',  # Changed to reports directory
    [string]$ResultsFile,  # Specific file to process
    [int]$MaxAgeHours = 24,  # Maximum age of test results in hours
    [switch]$RunTestsFirst,
    [switch]$ForceRunTests,  # Force running tests even if recent results exist
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0752
    Dependencies = @('0751', '0402')
    Tags = @('testing', 'tracking', 'automation', 'xml')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = @{
        'Error' = 'Red'
        'Warning' = 'Yellow'
        'Information' = 'White'
        'Debug' = 'Gray'
    }[$Level]
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

try {
    # Load tracker
    if (-not (Test-Path $TrackerPath)) {
        Write-ScriptLog -Level Error -Message "Tracker file not found. Run 0751_Load-TestTracker.ps1 first."
        exit 1
    }
    
    $tracker = Get-Content $TrackerPath -Raw | ConvertFrom-Json -AsHashtable
    Write-ScriptLog -Message "Loaded tracker with $($tracker.issues.Count) existing issues"
    
    # Check for recent test results first
    $needNewTests = $false
    
    if (-not $ResultsFile) {
        # Look for JSON reports first, then XML
        $jsonResults = Get-ChildItem "$TestResultsPath/TestReport-*.json" -ErrorAction SilentlyContinue | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1
        
        if ($jsonResults) {
            $resultAge = (Get-Date) - $jsonResults.LastWriteTime
            if ($resultAge.TotalHours -gt $MaxAgeHours) {
                Write-ScriptLog -Level Warning -Message "Test results are $([int]$resultAge.TotalHours) hours old (max: $MaxAgeHours)"
                $needNewTests = $true
            } else {
                Write-ScriptLog -Message "Found recent JSON test results: $($jsonResults.Name) (age: $([int]$resultAge.TotalHours) hours)"
            }
        } else {
            Write-ScriptLog -Level Warning -Message "No JSON test results found in $TestResultsPath"
            $needNewTests = $true
        }
    }
    
    # Run tests if needed or requested
    if ($RunTestsFirst -or $ForceRunTests -or $needNewTests) {
        Write-ScriptLog -Message "Running unit tests..."
        $testScript = Join-Path (Split-Path $PSScriptRoot -Parent) "automation-scripts/0402_Run-UnitTests.ps1"
        
        if ($PSCmdlet.ShouldProcess($testScript, "Run unit tests")) {
            & $testScript
            
            # Wait for results to be generated
            Start-Sleep -Seconds 2
        }
    }
    
    # Find test results - prefer JSON over XML
    $latestResults = if ($ResultsFile) {
        if (Test-Path $ResultsFile) {
            Get-Item $ResultsFile
        } else {
            Write-ScriptLog -Level Error -Message "Specified results file not found: $ResultsFile"
            exit 1
        }
    } else {
        # First try JSON reports
        $jsonResults = Get-ChildItem "$TestResultsPath/TestReport-*.json" -ErrorAction SilentlyContinue | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1
        
        if ($jsonResults) {
            $jsonResults
        } else {
            # Fall back to XML if no JSON found
            Write-ScriptLog -Message "No JSON results found, looking for XML..."
            Get-ChildItem "$TestResultsPath/UnitTests-*.xml" -ErrorAction SilentlyContinue | 
                Sort-Object LastWriteTime -Descending | 
                Select-Object -First 1
        }
    }
    
    if (-not $latestResults) {
        Write-ScriptLog -Level Warning -Message "No test results found in: $TestResultsPath"
        Write-ScriptLog -Message "Run tests with: ./automation-scripts/0402_Run-UnitTests.ps1"
        exit 0
    }
    
    Write-ScriptLog -Message "Processing results file: $($latestResults.Name)"
    
    # Check if we've already processed this file
    if ($tracker.lastProcessedResults -eq $latestResults.Name) {
        Write-ScriptLog -Message "Results already processed. No new failures to add."
        
        # Show current status
        $open = @($tracker.issues | Where-Object { $_.status -eq 'open' }).Count
        $resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' }).Count
        $failed = @($tracker.issues | Where-Object { $_.status -eq 'failed' }).Count
        
        Write-Host "`n📊 Current Status:" -ForegroundColor Cyan
        Write-Host "  Open: $open" -ForegroundColor Yellow
        Write-Host "  Resolved: $resolved" -ForegroundColor Green
        Write-Host "  Failed: $failed" -ForegroundColor Red
        
        if ($PassThru) {
            return $tracker
        }
        exit 0
    }
    
    # Parse results based on format
    $failures = @()
    
    if ($latestResults.Extension -eq '.json') {
        Write-ScriptLog -Message "Parsing JSON test results"
        $testJson = Get-Content $latestResults.FullName -Raw | ConvertFrom-Json
        
        # Extract failures from Pester JSON format
        if ($testJson.Failed -gt 0 -and $testJson.Tests) {
            $failures = @($testJson.Tests | Where-Object { $_.Result -eq 'Failed' })
        }
    } elseif ($latestResults.Extension -eq '.xml') {
        Write-ScriptLog -Message "Parsing XML test results"
        [xml]$testXml = Get-Content $latestResults.FullName
        $xmlFailures = $testXml.SelectNodes("//test-case[@result='Failure']")
        
        # Convert XML failures to consistent format
        $failures = @($xmlFailures | ForEach-Object {
            [PSCustomObject]@{
                ExpandedPath = $_.GetAttribute('name')
                ErrorRecord = @{
                    Exception = @{
                        Message = $_.SelectSingleNode('failure/message').InnerText
                    }
                    ScriptStackTrace = $_.SelectSingleNode('failure/stack-trace').InnerText
                }
            }
        })
    } else {
        Write-ScriptLog -Level Error -Message "Unsupported results format: $($latestResults.Extension)"
        exit 1
    }
    
    Write-ScriptLog -Message "Found $($failures.Count) failing tests in results"
    
    if ($failures.Count -eq 0) {
        Write-ScriptLog -Message "No failures found - all tests passing!"
        $tracker.lastProcessedResults = $latestResults.Name
        
        if ($PSCmdlet.ShouldProcess($TrackerPath, "Update tracker with no failures")) {
            $tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerPath
        }
        
        if ($PassThru) {
            return $tracker
        }
        exit 0
    }
    
    # Process failures
    $issueId = if ($tracker.issues.Count -gt 0) {
        [int]($tracker.issues | ForEach-Object { [int]$_.id } | Sort-Object -Descending | Select-Object -First 1) + 1
    } else {
        1
    }
    
    $newIssues = 0
    $skippedIssues = 0
    
    foreach ($failure in $failures) {
        # Handle both JSON and XML formats
        $testName = if ($failure.ExpandedPath) { 
            $failure.ExpandedPath 
        } else { 
            $failure.GetAttribute('name') 
        }
        
        # Check if already tracked (not resolved)
        $existing = $tracker.issues | Where-Object { 
            $_.testName -eq $testName -and $_.status -ne 'resolved' 
        }
        
        if ($existing) {
            $skippedIssues++
            Write-ScriptLog -Level Debug -Message "Skipping already tracked: $testName"
            continue
        }
        
        # Extract failure details (handle both formats)
        if ($failure.ErrorRecord) {
            # JSON format
            $errorMsg = $failure.ErrorRecord.Exception.Message
            $stackTrace = $failure.ErrorRecord.ScriptStackTrace
        } else {
            # XML format
            $errorMsg = $failure.SelectSingleNode('failure/message').InnerText
            $stackTrace = $failure.SelectSingleNode('failure/stack-trace').InnerText
        }
        
        # Try to extract file and line from stack trace
        $file = ''
        $line = 0
        if ($stackTrace -match 'at .+, (.+\.ps1):(\d+)') {
            $file = $Matches[1]
            $line = [int]$Matches[2]
        } elseif ($stackTrace -match 'at .+, (.+\.Tests\.ps1):(\d+)') {
            $file = $Matches[1]
            $line = [int]$Matches[2]
        }
        
        # Create issue entry
        $issue = @{
            id = "{0:D3}" -f $issueId++
            testName = $testName
            file = $file
            line = $line
            error = ($errorMsg -split "`n")[0]  # First line only
            fullError = $errorMsg
            stackTrace = $stackTrace
            status = 'open'
            githubIssue = $null
            attempts = 0
            lastAttempt = $null
            fixCommit = $null
            createdAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
        
        $tracker.issues += $issue
        $newIssues++
        
        Write-ScriptLog -Message "Added issue $($issue.id): $testName"
    }
    
    # Update tracker
    $tracker.lastProcessedResults = $latestResults.Name
    $tracker.updatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    if ($PSCmdlet.ShouldProcess($TrackerPath, "Save updated tracker")) {
        $tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerPath
        Write-ScriptLog -Message "Tracker updated with $newIssues new issues"
    }
    
    # Summary
    Write-Host "`n📊 Processing Summary:" -ForegroundColor Cyan
    Write-Host "  Results File: $($latestResults.Name)" -ForegroundColor Gray
    Write-Host "  Total Failures: $($failures.Count)" -ForegroundColor Gray
    Write-Host "  New Issues: $newIssues" -ForegroundColor Green
    Write-Host "  Already Tracked: $skippedIssues" -ForegroundColor Yellow
    
    $open = @($tracker.issues | Where-Object { $_.status -eq 'open' }).Count
    $resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' }).Count
    $failed = @($tracker.issues | Where-Object { $_.status -eq 'failed' }).Count
    
    Write-Host "`n  Total Issues:" -ForegroundColor Cyan
    Write-Host "    Open: $open" -ForegroundColor Yellow
    Write-Host "    Resolved: $resolved" -ForegroundColor Green
    Write-Host "    Failed: $failed" -ForegroundColor Red
    
    if ($PassThru) {
        return $tracker
    }
    
    exit 0
}
catch {
    Write-ScriptLog -Level Error -Message "Failed to process test results: $_"
    exit 1
}