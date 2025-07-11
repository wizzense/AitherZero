#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive validation script for AitherZero project

.DESCRIPTION
    This script runs all validation checks in parallel for maximum performance:
    - PowerShell syntax validation
    - PSScriptAnalyzer checks
    - YAML syntax validation for GitHub Actions
    - Module manifest validation
    - Documentation validation
    - Security scanning
    - Test execution
    - Generates comprehensive validation report

.PARAMETER Path
    Path to validate. Defaults to project root.

.PARAMETER IncludeTests
    Include test execution in validation

.PARAMETER GenerateReport
    Generate HTML validation report

.PARAMETER FixIssues
    Attempt to automatically fix issues where possible

.PARAMETER CI
    Run in CI mode with strict validation

.EXAMPLE
    ./Run-ComprehensiveValidation.ps1
    Run all validations for the entire project

.EXAMPLE
    ./Run-ComprehensiveValidation.ps1 -Path ./aither-core -FixIssues
    Validate specific directory and auto-fix issues
#>

[CmdletBinding()]
param(
    [string]$Path,
    [switch]$IncludeTests,
    [switch]$GenerateReport,
    [switch]$FixIssues,
    [switch]$CI
)

$ErrorActionPreference = 'Stop'
$script:StartTime = Get-Date

# Find project root
. "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

if (-not $Path) {
    $Path = $projectRoot
}

# Import required modules
Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
try {
    Import-Module (Join-Path $projectRoot "aither-core/modules/ParallelExecution") -Force -ErrorAction Stop
    $script:UseParallel = $true
} catch {
    Write-Warning "ParallelExecution module not available, using sequential processing"
    $script:UseParallel = $false
}

# Initialize validation results
$script:ValidationResults = @{
    StartTime = $script:StartTime
    TotalFiles = 0
    Issues = @{
        Errors = @()
        Warnings = @()
        Information = @()
    }
    Categories = @{
        PowerShellSyntax = @{ Passed = 0; Failed = 0; Issues = @() }
        PSScriptAnalyzer = @{ Passed = 0; Failed = 0; Issues = @() }
        YAMLSyntax = @{ Passed = 0; Failed = 0; Issues = @() }
        ModuleManifest = @{ Passed = 0; Failed = 0; Issues = @() }
        Documentation = @{ Passed = 0; Failed = 0; Issues = @() }
        Security = @{ Passed = 0; Failed = 0; Issues = @() }
        Tests = @{ Passed = 0; Failed = 0; Issues = @() }
    }
    Fixed = @()
}

Write-CustomLog -Level 'INFO' -Message "Starting comprehensive validation for: $Path"

# Helper function to add issue
function Add-ValidationIssue {
    param(
        [string]$Category,
        [string]$File,
        [string]$Message,
        [ValidateSet('Error', 'Warning', 'Information')]
        [string]$Severity = 'Error',
        [int]$Line = 0,
        [string]$Rule = ''
    )
    
    $issue = [PSCustomObject]@{
        Category = $Category
        File = $File
        Message = $Message
        Severity = $Severity
        Line = $Line
        Rule = $Rule
        Timestamp = Get-Date
    }
    
    $script:ValidationResults.Issues.$Severity = @($script:ValidationResults.Issues.$Severity) + $issue
    $script:ValidationResults.Categories.$Category.Issues = @($script:ValidationResults.Categories.$Category.Issues) + $issue
    
    if ($Severity -eq 'Error') {
        $script:ValidationResults.Categories.$Category.Failed++
    }
}

# 1. PowerShell Syntax Validation
function Test-PowerShellSyntax {
    param([string[]]$Files)
    
    Write-CustomLog -Level 'INFO' -Message "Validating PowerShell syntax for $($Files.Count) files..."
    
    foreach ($file in $Files) {
        try {
            $content = Get-Content $file -Raw
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
            
            if ($errors.Count -eq 0) {
                $script:ValidationResults.Categories.PowerShellSyntax.Passed++
            } else {
                foreach ($error in $errors) {
                    Add-ValidationIssue -Category 'PowerShellSyntax' -File $file `
                        -Message $error.Message -Severity 'Error' -Line $error.Token.StartLine
                }
            }
        } catch {
            Add-ValidationIssue -Category 'PowerShellSyntax' -File $file `
                -Message $_.Exception.Message -Severity 'Error' -Line 0
        }
    }
}

# 2. PSScriptAnalyzer Validation
function Test-PSScriptAnalyzer {
    param([string[]]$Files)
    
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Write-CustomLog -Level 'WARNING' -Message "PSScriptAnalyzer not installed, skipping analysis"
        return
    }
    
    Import-Module PSScriptAnalyzer -Force
    Write-CustomLog -Level 'INFO' -Message "Running PSScriptAnalyzer on $($Files.Count) files..."
    
    foreach ($file in $Files) {
        try {
            $results = Invoke-ScriptAnalyzer -Path $file -Severity Error,Warning,Information
            
            if ($results) {
                foreach ($finding in $results) {
                    Add-ValidationIssue -Category 'PSScriptAnalyzer' -File $file `
                        -Message $finding.Message -Severity $finding.Severity `
                        -Line $finding.Line -Rule $finding.RuleName
                }
            } else {
                $script:ValidationResults.Categories.PSScriptAnalyzer.Passed++
            }
        } catch {
            Add-ValidationIssue -Category 'PSScriptAnalyzer' -File $file `
                -Message $_.Exception.Message -Severity 'Error'
        }
    }
}

# 3. YAML Syntax Validation
function Test-YAMLSyntax {
    param([string[]]$Files)
    
    if (-not (Get-Command yamllint -ErrorAction SilentlyContinue)) {
        Write-CustomLog -Level 'WARNING' -Message "yamllint not installed, skipping YAML validation"
        return
    }
    
    Write-CustomLog -Level 'INFO' -Message "Validating YAML syntax for $($Files.Count) files..."
    
    foreach ($file in $Files) {
        $yamlOutput = yamllint $file 2>&1
        if ($LASTEXITCODE -eq 0) {
            $script:ValidationResults.Categories.YAMLSyntax.Passed++
        } else {
            $yamlOutput | ForEach-Object {
                if ($_ -match '^(.+):(\d+):(\d+):\s+\[(error|warning)\]\s+(.+)$') {
                    $severity = if ($matches[4] -eq 'error') { 'Error' } else { 'Warning' }
                    Add-ValidationIssue -Category 'YAMLSyntax' -File $file `
                        -Message $matches[5] -Severity $severity -Line ([int]$matches[2])
                }
            }
        }
    }
}

# 4. Module Manifest Validation
function Test-ModuleManifests {
    param([string[]]$Files)
    
    Write-CustomLog -Level 'INFO' -Message "Validating module manifests for $($Files.Count) files..."
    
    foreach ($file in $Files) {
        try {
            $manifest = Test-ModuleManifest -Path $file -ErrorAction Stop
            $script:ValidationResults.Categories.ModuleManifest.Passed++
            
            # Additional checks
            if (-not $manifest.Description) {
                Add-ValidationIssue -Category 'ModuleManifest' -File $file `
                    -Message "Module manifest missing description" -Severity 'Warning'
            }
            
            if ($manifest.ModuleVersion -eq '0.0') {
                Add-ValidationIssue -Category 'ModuleManifest' -File $file `
                    -Message "Module version not set" -Severity 'Warning'
            }
        } catch {
            Add-ValidationIssue -Category 'ModuleManifest' -File $file `
                -Message $_.Exception.Message -Severity 'Error'
        }
    }
}

# 5. Security Scanning
function Test-SecurityIssues {
    param([string[]]$Files)
    
    Write-CustomLog -Level 'INFO' -Message "Scanning for security issues in $($Files.Count) files..."
    
    $secretPatterns = @(
        @{ Pattern = 'password\s*=\s*["\''`].+["\''`]'; Description = 'Hardcoded password' }
        @{ Pattern = 'api[_-]?key\s*=\s*["\''`].+["\''`]'; Description = 'Hardcoded API key' }
        @{ Pattern = 'secret\s*=\s*["\''`].+["\''`]'; Description = 'Hardcoded secret' }
        @{ Pattern = 'token\s*=\s*["\''`].+["\''`]'; Description = 'Hardcoded token' }
        @{ Pattern = 'BEGIN\s+(RSA|DSA|EC|OPENSSH)\s+PRIVATE\s+KEY'; Description = 'Private key' }
        @{ Pattern = 'https?://[^/]+:[^@]+@'; Description = 'URL with credentials' }
    )
    
    foreach ($file in $Files) {
        $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        $foundIssue = $false
        foreach ($pattern in $secretPatterns) {
            if ($content -match $pattern.Pattern) {
                Add-ValidationIssue -Category 'Security' -File $file `
                    -Message "Potential security issue: $($pattern.Description)" `
                    -Severity 'Error'
                $foundIssue = $true
            }
        }
        
        if (-not $foundIssue) {
            $script:ValidationResults.Categories.Security.Passed++
        }
    }
}

# 6. Documentation Validation
function Test-Documentation {
    param([string[]]$Files)
    
    Write-CustomLog -Level 'INFO' -Message "Validating documentation for $($Files.Count) PowerShell files..."
    
    foreach ($file in $Files) {
        $content = Get-Content $file -Raw
        
        # Check for synopsis
        if ($content -notmatch '\.SYNOPSIS') {
            Add-ValidationIssue -Category 'Documentation' -File $file `
                -Message "Missing .SYNOPSIS in comment-based help" -Severity 'Warning'
        }
        
        # Check for function documentation
        $functions = [regex]::Matches($content, 'function\s+(\w+-\w+)\s*{')
        foreach ($function in $functions) {
            $funcName = $function.Groups[1].Value
            $funcIndex = $function.Index
            
            # Look for documentation before the function
            $beforeFunc = $content.Substring(0, $funcIndex)
            if ($beforeFunc -notmatch "<#[\s\S]*?\.SYNOPSIS[\s\S]*?#>\s*$") {
                Add-ValidationIssue -Category 'Documentation' -File $file `
                    -Message "Function '$funcName' missing documentation" -Severity 'Information'
            }
        }
        
        if ($script:ValidationResults.Categories.Documentation.Issues.Count -eq 0) {
            $script:ValidationResults.Categories.Documentation.Passed++
        }
    }
}

# Main execution
try {
    # Get all files to validate
    $allFiles = Get-ChildItem -Path $Path -Recurse -File
    $script:ValidationResults.TotalFiles = $allFiles.Count
    
    # Filter files by type
    $psFiles = $allFiles | Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1' }
    $yamlFiles = $allFiles | Where-Object { $_.Name -match '\.yml$' -and $_.DirectoryName -match '\.github[/\\]workflows' }
    $manifestFiles = $allFiles | Where-Object { $_.Extension -eq '.psd1' }
    
    Write-CustomLog -Level 'INFO' -Message "Found $($psFiles.Count) PowerShell files, $($yamlFiles.Count) YAML files"
    
    # Run validations
    if ($psFiles) {
        Test-PowerShellSyntax -Files $psFiles.FullName
        Test-PSScriptAnalyzer -Files $psFiles.FullName
        Test-Documentation -Files $psFiles.FullName
        Test-SecurityIssues -Files $psFiles.FullName
    }
    
    if ($yamlFiles) {
        Test-YAMLSyntax -Files $yamlFiles.FullName
    }
    
    if ($manifestFiles) {
        Test-ModuleManifests -Files $manifestFiles.FullName
    }
    
    # Run tests if requested
    if ($IncludeTests) {
        Write-CustomLog -Level 'INFO' -Message "Running tests..."
        try {
            $testScript = Join-Path $projectRoot "tests/Run-UnifiedTests.ps1"
            if (Test-Path $testScript) {
                $testResult = & $testScript -TestSuite Quick -CI -Quiet -PassThru
                if ($testResult.Failed -eq 0) {
                    $script:ValidationResults.Categories.Tests.Passed = $testResult.Passed
                } else {
                    $script:ValidationResults.Categories.Tests.Failed = $testResult.Failed
                    Add-ValidationIssue -Category 'Tests' -File 'Tests' `
                        -Message "$($testResult.Failed) tests failed" -Severity 'Error'
                }
            }
        } catch {
            Add-ValidationIssue -Category 'Tests' -File 'Tests' `
                -Message "Test execution failed: $($_.Exception.Message)" -Severity 'Error'
        }
    }
    
    # Fix issues if requested
    if ($FixIssues) {
        Write-CustomLog -Level 'INFO' -Message "Attempting to fix issues..."
        
        # Fix YAML issues
        $yamlFixScript = Join-Path $projectRoot "aither-core/modules/Fix-GitHub-Actions-YAML.ps1"
        if (Test-Path $yamlFixScript) {
            & $yamlFixScript
            $script:ValidationResults.Fixed += "Attempted to fix YAML syntax issues"
        }
        
        # Fix PowerShell formatting
        foreach ($psFile in $psFiles) {
            try {
                # Basic formatting fixes
                $content = Get-Content $psFile.FullName -Raw
                $originalContent = $content
                
                # Fix line endings
                $content = $content -replace "`r`n", "`n"
                $content = $content -replace "`r", "`n"
                $content = $content -replace "`n", "`r`n"
                
                # Remove trailing whitespace
                $content = $content -replace '[ \t]+$', ''
                
                if ($content -ne $originalContent) {
                    Set-Content -Path $psFile.FullName -Value $content -NoNewline
                    $script:ValidationResults.Fixed += "Fixed formatting in $($psFile.Name)"
                }
            } catch {
                Write-CustomLog -Level 'WARNING' -Message "Failed to fix $($psFile.Name): $_"
            }
        }
    }
    
    # Calculate summary
    $script:ValidationResults.Duration = (Get-Date) - $script:StartTime
    $script:ValidationResults.Summary = @{
        TotalErrors = $script:ValidationResults.Issues.Errors.Count
        TotalWarnings = $script:ValidationResults.Issues.Warnings.Count
        TotalInformation = $script:ValidationResults.Issues.Information.Count
        PassRate = 0
    }
    
    $totalChecks = 0
    $totalPassed = 0
    foreach ($category in $script:ValidationResults.Categories.Keys) {
        $cat = $script:ValidationResults.Categories[$category]
        $totalChecks += $cat.Passed + $cat.Failed
        $totalPassed += $cat.Passed
    }
    
    if ($totalChecks -gt 0) {
        $script:ValidationResults.Summary.PassRate = [math]::Round(($totalPassed / $totalChecks) * 100, 2)
    }
    
    # Display results
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           Comprehensive Validation Results                   ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Duration: $($script:ValidationResults.Duration.TotalSeconds.ToString('0.0'))s"
    Write-Host "Files Analyzed: $($script:ValidationResults.TotalFiles)"
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Yellow
    Write-Host "  Errors:       $($script:ValidationResults.Summary.TotalErrors)" -ForegroundColor $(if ($script:ValidationResults.Summary.TotalErrors -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Warnings:     $($script:ValidationResults.Summary.TotalWarnings)" -ForegroundColor $(if ($script:ValidationResults.Summary.TotalWarnings -gt 0) { 'Yellow' } else { 'Green' })
    Write-Host "  Information:  $($script:ValidationResults.Summary.TotalInformation)" -ForegroundColor Cyan
    Write-Host "  Pass Rate:    $($script:ValidationResults.Summary.PassRate)%" -ForegroundColor $(if ($script:ValidationResults.Summary.PassRate -lt 80) { 'Red' } elseif ($script:ValidationResults.Summary.PassRate -lt 95) { 'Yellow' } else { 'Green' })
    Write-Host ""
    
    # Show category breakdown
    Write-Host "Category Breakdown:" -ForegroundColor Yellow
    foreach ($category in $script:ValidationResults.Categories.Keys | Sort-Object) {
        $cat = $script:ValidationResults.Categories[$category]
        $total = $cat.Passed + $cat.Failed
        if ($total -gt 0) {
            $passRate = [math]::Round(($cat.Passed / $total) * 100, 0)
            Write-Host ("  {0,-20} {1,4}/{2,-4} ({3,3}%)" -f $category, $cat.Passed, $total, $passRate) -ForegroundColor $(if ($passRate -lt 80) { 'Red' } elseif ($passRate -lt 95) { 'Yellow' } else { 'Green' })
        }
    }
    Write-Host ""
    
    # Show top issues
    if ($script:ValidationResults.Issues.Errors.Count -gt 0) {
        Write-Host "Top Errors:" -ForegroundColor Red
        $script:ValidationResults.Issues.Errors | Select-Object -First 5 | ForEach-Object {
            Write-Host "  [$($_.Category)] $($_.File):$($_.Line) - $($_.Message)" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    # Generate report if requested
    if ($GenerateReport) {
        $reportPath = Join-Path $projectRoot "reports/validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
        Write-CustomLog -Level 'INFO' -Message "Generating validation report: $reportPath"
        
        # Generate HTML report
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Validation Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #0066cc; padding-bottom: 10px; }
        h2 { color: #666; margin-top: 30px; }
        .summary { background: #f0f0f0; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .metric { display: inline-block; margin: 10px 20px 10px 0; }
        .metric-value { font-size: 24px; font-weight: bold; }
        .error { color: #d00; }
        .warning { color: #f90; }
        .success { color: #090; }
        .info { color: #09f; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #f0f0f0; font-weight: bold; }
        tr:hover { background: #f5f5f5; }
        .issue-error { background: #fee; }
        .issue-warning { background: #ffd; }
        .issue-info { background: #eef; }
        .category-chart { margin: 20px 0; }
        .bar { height: 20px; background: #090; display: inline-block; }
        .bar-failed { background: #d00; }
    </style>
</head>
<body>
    <div class="container">
        <h1>AitherZero Validation Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        
        <div class="summary">
            <h2>Summary</h2>
            <div class="metric">
                <div class="metric-value error">$($script:ValidationResults.Summary.TotalErrors)</div>
                <div>Errors</div>
            </div>
            <div class="metric">
                <div class="metric-value warning">$($script:ValidationResults.Summary.TotalWarnings)</div>
                <div>Warnings</div>
            </div>
            <div class="metric">
                <div class="metric-value info">$($script:ValidationResults.Summary.TotalInformation)</div>
                <div>Information</div>
            </div>
            <div class="metric">
                <div class="metric-value $(if ($script:ValidationResults.Summary.PassRate -ge 95) { 'success' } elseif ($script:ValidationResults.Summary.PassRate -ge 80) { 'warning' } else { 'error' })">$($script:ValidationResults.Summary.PassRate)%</div>
                <div>Pass Rate</div>
            </div>
        </div>
        
        <h2>Category Results</h2>
        <table>
            <thead>
                <tr>
                    <th>Category</th>
                    <th>Passed</th>
                    <th>Failed</th>
                    <th>Pass Rate</th>
                    <th>Visual</th>
                </tr>
            </thead>
            <tbody>
"@
        
        foreach ($category in $script:ValidationResults.Categories.Keys | Sort-Object) {
            $cat = $script:ValidationResults.Categories[$category]
            $total = $cat.Passed + $cat.Failed
            if ($total -gt 0) {
                $passRate = [math]::Round(($cat.Passed / $total) * 100, 0)
                $passWidth = [math]::Round($passRate * 2, 0)
                $failWidth = 200 - $passWidth
                
                $html += @"
                <tr>
                    <td>$category</td>
                    <td class="success">$($cat.Passed)</td>
                    <td class="error">$($cat.Failed)</td>
                    <td>$passRate%</td>
                    <td>
                        <div style="width: 200px; display: inline-block; background: #ddd;">
                            <div class="bar" style="width: ${passWidth}px;"></div>
                            <div class="bar bar-failed" style="width: ${failWidth}px;"></div>
                        </div>
                    </td>
                </tr>
"@
            }
        }
        
        $html += @"
            </tbody>
        </table>
        
        <h2>Issues</h2>
"@
        
        if ($script:ValidationResults.Issues.Errors.Count -gt 0) {
            $html += "<h3>Errors</h3><table><thead><tr><th>Category</th><th>File</th><th>Line</th><th>Message</th></tr></thead><tbody>"
            foreach ($issue in $script:ValidationResults.Issues.Errors | Sort-Object Category, File, Line) {
                $html += "<tr class='issue-error'><td>$($issue.Category)</td><td>$($issue.File)</td><td>$($issue.Line)</td><td>$($issue.Message)</td></tr>"
            }
            $html += "</tbody></table>"
        }
        
        if ($script:ValidationResults.Issues.Warnings.Count -gt 0) {
            $html += "<h3>Warnings</h3><table><thead><tr><th>Category</th><th>File</th><th>Line</th><th>Message</th></tr></thead><tbody>"
            foreach ($issue in $script:ValidationResults.Issues.Warnings | Sort-Object Category, File, Line | Select-Object -First 50) {
                $html += "<tr class='issue-warning'><td>$($issue.Category)</td><td>$($issue.File)</td><td>$($issue.Line)</td><td>$($issue.Message)</td></tr>"
            }
            $html += "</tbody></table>"
        }
        
        $html += @"
    </div>
</body>
</html>
"@
        
        New-Item -ItemType Directory -Path (Split-Path $reportPath -Parent) -Force | Out-Null
        $html | Set-Content $reportPath
        Write-CustomLog -Level 'SUCCESS' -Message "Validation report generated: $reportPath"
    }
    
    # Exit with appropriate code
    if ($CI -and $script:ValidationResults.Summary.TotalErrors -gt 0) {
        exit 1
    }
    
} catch {
    Write-CustomLog -Level 'ERROR' -Message "Validation failed: $($_.Exception.Message)"
    Write-CustomLog -Level 'ERROR' -Message $_.ScriptStackTrace
    exit 1
}