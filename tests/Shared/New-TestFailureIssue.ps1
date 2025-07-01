#Requires -Version 7.0
<#
.SYNOPSIS
    Creates GitHub issues specifically for test failures with intelligent analysis
.DESCRIPTION
    Wrapper function around PatchManager's New-PatchIssue that provides enhanced
    test failure analysis and formatting for automated issue creation.
.PARAMETER TestFailures
    Array of test failure objects from Pester
.PARAMETER TestSuite
    Name of the test suite that was executed
.PARAMETER TestRunContext
    Additional context about the test run
.PARAMETER GroupByFile
    Group multiple failures from the same file into a single issue
.PARAMETER DryRun
    Preview issue creation without actually creating them
.EXAMPLE
    New-TestFailureIssue -TestFailures $failures -TestSuite "Critical" -TestRunContext $context
#>

function New-TestFailureIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$TestFailures,
        
        [Parameter(Mandatory)]
        [string]$TestSuite,
        
        [hashtable]$TestRunContext = @{},
        
        [switch]$GroupByFile,
        [switch]$DryRun,
        [string]$TargetRepository
    )
    
    if ($TestFailures.Count -eq 0) {
        Write-Host "No test failures to process" -ForegroundColor Green
        return @()
    }
    
    Write-Host "Processing $($TestFailures.Count) test failures for issue creation..." -ForegroundColor Yellow
    
    # Import PatchManager if available
    try {
        $patchManagerPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'aither-core/modules/PatchManager'
        if (Test-Path $patchManagerPath) {
            Import-Module $patchManagerPath -Force
            $patchManagerAvailable = $true
        } else {
            throw "PatchManager not found"
        }
    } catch {
        Write-Warning "PatchManager not available - using fallback issue creation"
        $patchManagerAvailable = $false
    }
    
    $createdIssues = @()
    
    if ($GroupByFile) {
        # Group failures by test file
        $groupedFailures = $TestFailures | Group-Object { Split-Path $_.ScriptBlock.File -Leaf }
        
        foreach ($group in $groupedFailures) {
            $fileName = $group.Name
            $fileFailures = $group.Group
            
            Write-Host "Creating issue for $($fileFailures.Count) failures in $fileName..." -ForegroundColor Cyan
            
            $issue = New-SingleTestIssue -Failures $fileFailures -TestSuite $TestSuite -TestRunContext $TestRunContext -DryRun:$DryRun -TargetRepository $TargetRepository -PatchManagerAvailable $patchManagerAvailable
            if ($issue) {
                $createdIssues += $issue
            }
        }
    } else {
        # Create individual issues for each failure
        foreach ($failure in $TestFailures) {
            Write-Host "Creating issue for test: $($failure.Name)..." -ForegroundColor Cyan
            
            $issue = New-SingleTestIssue -Failures @($failure) -TestSuite $TestSuite -TestRunContext $TestRunContext -DryRun:$DryRun -TargetRepository $TargetRepository -PatchManagerAvailable $patchManagerAvailable
            if ($issue) {
                $createdIssues += $issue
            }
        }
    }
    
    Write-Host "Created $($createdIssues.Count) GitHub issues" -ForegroundColor Green
    return $createdIssues
}

function New-SingleTestIssue {
    param(
        [array]$Failures,
        [string]$TestSuite,
        [hashtable]$TestRunContext,
        [switch]$DryRun,
        [string]$TargetRepository,
        [bool]$PatchManagerAvailable
    )
    
    $firstFailure = $Failures[0]
    $fileName = Split-Path $firstFailure.ScriptBlock.File -Leaf
    
    # Analyze failure patterns
    $failureAnalysis = Get-TestFailureAnalysis -Failures $Failures
    
    # Create issue title
    if ($Failures.Count -eq 1) {
        $issueTitle = "Test Failure: $($firstFailure.Name)"
    } else {
        $issueTitle = "Multiple Test Failures in $fileName ($($Failures.Count) tests)"
    }
    
    # Determine priority based on failure characteristics
    $priority = Get-TestFailurePriority -Failures $Failures -Analysis $failureAnalysis
    
    # Generate detailed error information
    $errorDetails = @()
    $affectedFiles = @()
    
    foreach ($failure in $Failures) {
        $affectedFiles += $failure.ScriptBlock.File
        
        $errorDetail = @"
## Test: $($failure.Name)

**Location**: $($failure.ScriptBlock.File):$($failure.ScriptBlock.StartPosition.StartLine)
**Duration**: $($failure.Duration.TotalMilliseconds)ms
**Result**: $($failure.Result)

### Error Message
```
$($failure.ErrorRecord.Exception.Message)
```

### Stack Trace
```
$($failure.ErrorRecord.ScriptStackTrace)
```

### Full Exception
```
$($failure.ErrorRecord.ToString())
```

---
"@
        $errorDetails += $errorDetail
    }
    
    # Generate comprehensive test output
    $testOutput = @(
        "Test Suite: $TestSuite",
        "Total Failures: $($Failures.Count)",
        "Test File: $fileName",
        "Analysis Results: $($failureAnalysis | ConvertTo-Json -Depth 3)"
    )
    
    # Add test run context
    if ($TestRunContext.Count -gt 0) {
        $testOutput += "Test Run Context: $($TestRunContext | ConvertTo-Json -Depth 3)"
    }
    
    # Determine appropriate labels
    $labels = @('test-failure', 'automated', $TestSuite.ToLower())
    
    # Add labels based on failure analysis
    if ($failureAnalysis.Categories.Contains('timeout')) {
        $labels += 'timeout'
    }
    if ($failureAnalysis.Categories.Contains('permission')) {
        $labels += 'permissions'
    }
    if ($failureAnalysis.Categories.Contains('network')) {
        $labels += 'network'
    }
    if ($failureAnalysis.Categories.Contains('file-system')) {
        $labels += 'filesystem'
    }
    if ($failureAnalysis.IsInfrastructureRelated) {
        $labels += 'infrastructure'
    }
    
    # Create enhanced test context
    $enhancedTestContext = @{
        TestSuite = $TestSuite
        TestFile = $fileName
        FailureCount = $Failures.Count
        Platform = $PSVersionTable.Platform
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Analysis = $failureAnalysis
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
    }
    
    # Merge with provided test run context
    foreach ($key in $TestRunContext.Keys) {
        $enhancedTestContext[$key] = $TestRunContext[$key]
    }
    
    if ($PatchManagerAvailable) {
        # Use PatchManager's enhanced issue creation
        $issueParams = @{
            Description = $issueTitle
            Priority = $priority
            AffectedFiles = $affectedFiles | Sort-Object -Unique
            Labels = $labels
            TestOutput = $testOutput
            ErrorDetails = $errorDetails
            TestType = "Production Test - $TestSuite"
            TestContext = $enhancedTestContext
            DryRun = $DryRun
        }
        
        if ($TargetRepository) {
            $issueParams.TargetRepository = $TargetRepository
        }
        
        try {
            $result = New-PatchIssue @issueParams
            
            if ($result.Success) {
                Write-Host "  ✅ Created issue: $($result.IssueUrl)" -ForegroundColor Green
                return $result
            } else {
                Write-Host "  ❌ Failed to create issue: $($result.Message)" -ForegroundColor Red
                return $null
            }
        } catch {
            Write-Host "  ❌ Error creating issue: $_" -ForegroundColor Red
            return $null
        }
    } else {
        # Fallback issue creation using GitHub CLI directly
        return New-FallbackTestIssue -Title $issueTitle -Failures $Failures -TestContext $enhancedTestContext -DryRun:$DryRun -TargetRepository $TargetRepository
    }
}

function Get-TestFailureAnalysis {
    param([array]$Failures)
    
    $analysis = @{
        Categories = @()
        Patterns = @()
        IsInfrastructureRelated = $false
        Confidence = 'Medium'
        CommonCauses = @()
        Recommendations = @()
    }
    
    $allErrors = $Failures | ForEach-Object { $_.ErrorRecord.Exception.Message }
    $combinedErrors = $allErrors -join " "
    
    # Analyze error patterns
    $patterns = @{
        'timeout' = @('timeout', 'timed out', 'operation timeout', 'connection timeout')
        'permission' = @('access denied', 'permission denied', 'unauthorized', 'forbidden')
        'network' = @('network', 'connection', 'unreachable', 'host not found', 'dns')
        'file-system' = @('file not found', 'path not found', 'directory not found', 'cannot find')
        'module' = @('module not found', 'import-module', 'cannot import', 'module load')
        'configuration' = @('configuration', 'config', 'settings', 'invalid parameter')
        'infrastructure' = @('opentofu', 'terraform', 'deployment', 'infrastructure', 'provider')
    }
    
    foreach ($category in $patterns.Keys) {
        $categoryPatterns = $patterns[$category]
        $matches = $categoryPatterns | Where-Object { $combinedErrors -match $_ }
        
        if ($matches.Count -gt 0) {
            $analysis.Categories += $category
            $analysis.Patterns += $matches
            
            if ($category -eq 'infrastructure') {
                $analysis.IsInfrastructureRelated = $true
            }
        }
    }
    
    # Generate recommendations based on analysis
    foreach ($category in $analysis.Categories) {
        switch ($category) {
            'timeout' {
                $analysis.Recommendations += "Review test timeout settings and system performance"
                $analysis.CommonCauses += "Slow system response or network latency"
            }
            'permission' {
                $analysis.Recommendations += "Check file/directory permissions and execution policy"
                $analysis.CommonCauses += "Insufficient permissions or security restrictions"
            }
            'network' {
                $analysis.Recommendations += "Verify network connectivity and firewall settings"
                $analysis.CommonCauses += "Network connectivity issues or DNS resolution"
            }
            'file-system' {
                $analysis.Recommendations += "Ensure all required files and paths exist"
                $analysis.CommonCauses += "Missing files or incorrect path references"
            }
            'module' {
                $analysis.Recommendations += "Check PowerShell module availability and import paths"
                $analysis.CommonCauses += "Missing modules or module import failures"
            }
            'configuration' {
                $analysis.Recommendations += "Review configuration files and parameter values"
                $analysis.CommonCauses += "Invalid configuration or missing settings"
            }
            'infrastructure' {
                $analysis.Recommendations += "Check infrastructure provider setup and credentials"
                $analysis.CommonCauses += "Infrastructure provider issues or credential problems"
            }
        }
    }
    
    # Adjust confidence based on pattern matches
    if ($analysis.Categories.Count -eq 0) {
        $analysis.Confidence = 'Low'
    } elseif ($analysis.Categories.Count -ge 3) {
        $analysis.Confidence = 'High'
    }
    
    return $analysis
}

function Get-TestFailurePriority {
    param(
        [array]$Failures,
        [hashtable]$Analysis
    )
    
    # Determine priority based on various factors
    if ($Failures.Count -gt 10) {
        return 'Critical'
    }
    
    if ($Analysis.IsInfrastructureRelated) {
        return 'High'
    }
    
    if ($Analysis.Categories.Contains('timeout') -or $Analysis.Categories.Contains('network')) {
        return 'High'
    }
    
    if ($Failures.Count -gt 5) {
        return 'High'
    }
    
    if ($Failures.Count -gt 2) {
        return 'Medium'
    }
    
    return 'Low'
}

function New-FallbackTestIssue {
    param(
        [string]$Title,
        [array]$Failures,
        [hashtable]$TestContext,
        [switch]$DryRun,
        [string]$TargetRepository
    )
    
    Write-Host "  Using fallback issue creation (GitHub CLI)..." -ForegroundColor Yellow
    
    # Check for GitHub CLI
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host "  ❌ GitHub CLI not available - cannot create issue" -ForegroundColor Red
        return $null
    }
    
    # Generate issue body
    $issueBody = @"
## Test Failure Report

**Test Suite**: $($TestContext.TestSuite)
**File**: $($TestContext.TestFile)
**Failure Count**: $($TestContext.FailureCount)
**Platform**: $($TestContext.Platform)
**PowerShell**: $($TestContext.PowerShellVersion)
**Timestamp**: $($TestContext.Timestamp)

### Failed Tests

"@
    
    foreach ($failure in $Failures) {
        $issueBody += @"

#### $($failure.Name)
- **Location**: $($failure.ScriptBlock.File):$($failure.ScriptBlock.StartPosition.StartLine)
- **Duration**: $($failure.Duration.TotalMilliseconds)ms
- **Error**: $($failure.ErrorRecord.Exception.Message)

```
$($failure.ErrorRecord.ScriptStackTrace)
```

"@
    }
    
    $issueBody += @"

### Analysis
$($TestContext.Analysis | ConvertTo-Json -Depth 3)

---
*This issue was automatically created by the AitherZero test suite*
"@
    
    if ($DryRun) {
        Write-Host "  [DRY RUN] Would create issue: $Title" -ForegroundColor Cyan
        return @{
            Success = $true
            DryRun = $true
            Title = $Title
            Body = $issueBody
        }
    }
    
    try {
        # Try to get repository info
        $repoOwner = if ($TargetRepository) { 
            $TargetRepository.Split('/')[0] 
        } else { 
            (gh repo view --json owner --jq '.owner.login' 2>$null) 
        }
        $repoName = if ($TargetRepository) { 
            $TargetRepository.Split('/')[1] 
        } else { 
            (gh repo view --json name --jq '.name' 2>$null) 
        }
        
        if (-not $repoOwner -or -not $repoName) {
            throw "Could not determine repository information"
        }
        
        $repoSpec = "$repoOwner/$repoName"
        
        # Create the issue
        $result = gh issue create --repo $repoSpec --title $Title --body $issueBody --label "test-failure,automated" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            # Extract issue number from URL
            $issueNumber = $null
            if ($result -match '/issues/(\d+)') {
                $issueNumber = $matches[1]
            }
            
            Write-Host "  ✅ Created issue: $result" -ForegroundColor Green
            return @{
                Success = $true
                IssueUrl = $result.ToString().Trim()
                IssueNumber = $issueNumber
                Title = $Title
            }
        } else {
            throw "GitHub CLI failed: $result"
        }
    } catch {
        Write-Host "  ❌ Fallback issue creation failed: $_" -ForegroundColor Red
        return $null
    }
}

Export-ModuleMember -Function New-TestFailureIssue