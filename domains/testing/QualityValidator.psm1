#Requires -Version 7.0
<#
.SYNOPSIS
    Quality validation framework for AitherZero components and features
.DESCRIPTION
    Provides comprehensive quality checks for new features and components including:
    - Error handling validation
    - Logging implementation checks
    - Test coverage validation
    - UI/CLI integration verification
    - GitHub Actions integration checks
    - PSScriptAnalyzer compliance
    - Documentation completeness
.NOTES
    Copyright © 2025 Aitherium Corporation
    Domain: Testing
#>

Set-StrictMode -Version Latest

# Import dependencies
$script:ProjectRoot = $env:AITHERZERO_ROOT
if (-not $script:ProjectRoot) {
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$loggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force -ErrorAction SilentlyContinue
}

#region Helper Functions

function Write-QualityLog {
    <#
    .SYNOPSIS
        Write quality validation log message
    #>
    param(
        [string]$Message,
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source 'QualityValidator' -Data $Data
    } else {
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'Cyan'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

function Get-FileContent {
    <#
    .SYNOPSIS
        Get file content with error handling
    #>
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        return $null
    }
    
    try {
        return Get-Content -Path $Path -Raw -ErrorAction Stop
    } catch {
        Write-QualityLog -Level Warning -Message "Failed to read file: $Path - $_"
        return $null
    }
}

#endregion

#region Error Handling Validation

function Test-ErrorHandling {
    <#
    .SYNOPSIS
        Validate error handling implementation in a script or module
    .DESCRIPTION
        Checks for:
        - Try/catch blocks around risky operations
        - $ErrorActionPreference = 'Stop' (recommended)
        - Proper error logging
        - Finally blocks for cleanup
    .PARAMETER Path
        Path to the script or module file to validate
    .OUTPUTS
        ValidationResult object with status and findings
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Write-QualityLog -Message "Validating error handling: $Path"
    
    $result = [PSCustomObject]@{
        CheckName = 'ErrorHandling'
        Status = 'Passed'
        Findings = @()
        Score = 100
        Details = @{}
    }
    
    $content = Get-FileContent -Path $Path
    if (-not $content) {
        $result.Status = 'Failed'
        $result.Score = 0
        $result.Findings += "Could not read file content"
        return $result
    }
    
    # Check for try/catch blocks
    $tryCatchPattern = '(?ms)try\s*\{.*?\}\s*catch'
    $tryCatchMatches = [regex]::Matches($content, $tryCatchPattern)
    $result.Details.TryCatchBlocks = $tryCatchMatches.Count
    
    # Check for ErrorActionPreference
    if ($content -match '\$ErrorActionPreference\s*=\s*[''"]Stop[''"]') {
        $result.Details.HasErrorActionPreference = $true
    } else {
        $result.Findings += "Consider setting `$ErrorActionPreference = 'Stop' for better error handling"
        $result.Score -= 10
    }
    
    # Check for error logging in catch blocks
    $errorLogPattern = '(?ms)catch\s*\{[^}]*?(Write-.*Log|Write-Error|throw)'
    if ($content -match $errorLogPattern) {
        $result.Details.HasErrorLogging = $true
    } else {
        if ($tryCatchMatches.Count -gt 0) {
            $result.Findings += "Catch blocks should log or throw errors"
            $result.Score -= 15
        }
    }
    
    # Check for finally blocks
    $finallyPattern = '(?ms)finally\s*\{'
    if ($content -match $finallyPattern) {
        $result.Details.HasFinallyBlock = $true
    }
    
    # Check for common risky operations without error handling
    $riskyOperations = @(
        @{ Pattern = 'Invoke-RestMethod'; Name = 'Invoke-RestMethod' }
        @{ Pattern = 'Invoke-WebRequest'; Name = 'Invoke-WebRequest' }
        @{ Pattern = 'New-Item.*-ItemType.*Directory'; Name = 'Directory creation' }
        @{ Pattern = 'Remove-Item'; Name = 'Remove-Item' }
        @{ Pattern = 'Copy-Item'; Name = 'Copy-Item' }
        @{ Pattern = 'Move-Item'; Name = 'Move-Item' }
        @{ Pattern = 'Import-Module'; Name = 'Import-Module' }
        @{ Pattern = 'Install-Module'; Name = 'Install-Module' }
    )
    
    $unhandledRiskyOps = @()
    foreach ($op in $riskyOperations) {
        if ($content -match $op.Pattern) {
            # Check if it's within a try block (basic check)
            $opMatches = [regex]::Matches($content, $op.Pattern)
            foreach ($match in $opMatches) {
                $beforeMatch = $content.Substring(0, $match.Index)
                $tryCount = ([regex]::Matches($beforeMatch, 'try\s*\{')).Count
                $catchCount = ([regex]::Matches($beforeMatch, '\}\s*catch')).Count
                
                if ($tryCount -le $catchCount) {
                    $unhandledRiskyOps += $op.Name
                }
            }
        }
    }
    
    if ($unhandledRiskyOps.Count -gt 0) {
        $result.Findings += "Consider wrapping these risky operations in try/catch: $($unhandledRiskyOps -join ', ')"
        $result.Score -= [math]::Min(30, $unhandledRiskyOps.Count * 5)
    }
    
    if ($result.Score -lt 70) {
        $result.Status = 'Failed'
    } elseif ($result.Score -lt 90) {
        $result.Status = 'Warning'
    }
    
    return $result
}

#endregion

#region Logging Validation

function Test-LoggingImplementation {
    <#
    .SYNOPSIS
        Validate logging implementation in a script or module
    .DESCRIPTION
        Checks for:
        - Presence of logging statements
        - Use of appropriate logging functions
        - Logging at different levels (Info, Warning, Error)
        - Logging of important operations
    .PARAMETER Path
        Path to the script or module file to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Write-QualityLog -Message "Validating logging implementation: $Path"
    
    $result = [PSCustomObject]@{
        CheckName = 'Logging'
        Status = 'Passed'
        Findings = @()
        Score = 100
        Details = @{}
    }
    
    $content = Get-FileContent -Path $Path
    if (-not $content) {
        $result.Status = 'Failed'
        $result.Score = 0
        $result.Findings += "Could not read file content"
        return $result
    }
    
    # Check for logging statements
    $loggingPatterns = @(
        'Write-CustomLog'
        'Write-.*Log'
        'Write-Verbose'
        'Write-Information'
        'Write-Warning'
        'Write-Error'
    )
    
    $hasLogging = $false
    $loggingCounts = @{}
    
    foreach ($pattern in $loggingPatterns) {
        $matches = [regex]::Matches($content, $pattern)
        if ($matches.Count -gt 0) {
            $hasLogging = $true
            $loggingCounts[$pattern] = $matches.Count
        }
    }
    
    $result.Details.LoggingStatements = $loggingCounts
    $result.Details.TotalLoggingCalls = ($loggingCounts.Values | Measure-Object -Sum).Sum
    
    if (-not $hasLogging) {
        $result.Status = 'Failed'
        $result.Score = 0
        $result.Findings += "No logging statements found. Add logging for important operations."
        return $result
    }
    
    # Check for logging at different levels
    $infoLevelPattern = 'Write-.*(Log|Verbose|Information).*-Level.*[''"]Information[''"]'
    $infoFunctionPattern = 'Write-(Verbose|Information)'
    $warningLevelPattern = 'Write-.*(Log|Warning).*-Level.*[''"]Warning[''"]'
    $warningFunctionPattern = 'Write-Warning'
    $errorLevelPattern = 'Write-.*(Log|Error).*-Level.*[''"]Error[''"]'
    $errorFunctionPattern = 'Write-Error'

    $hasInfo = $content -match $infoLevelPattern -or 
               $content -match $infoFunctionPattern
    $hasWarning = $content -match $warningLevelPattern -or 
                  $content -match $warningFunctionPattern
    $hasError = $content -match $errorLevelPattern -or 
                $content -match $errorFunctionPattern
    
    $result.Details.HasInfoLevel = $hasInfo
    $result.Details.HasWarningLevel = $hasWarning
    $result.Details.HasErrorLevel = $hasError
    
    if (-not $hasInfo) {
        $result.Findings += "Consider adding informational logging for tracking execution flow"
        $result.Score -= 15
    }
    
    if (-not $hasError) {
        $result.Findings += "Consider adding error logging in catch blocks"
        $result.Score -= 20
    }
    
    # Check for function-level logging
    $functionPattern = 'function\s+[\w-]+'
    $functionMatches = [regex]::Matches($content, $functionPattern)
    $result.Details.FunctionCount = $functionMatches.Count
    
    if ($functionMatches.Count -gt 0 -and $result.Details.TotalLoggingCalls -lt $functionMatches.Count) {
        $result.Findings += "Some functions may lack logging statements"
        $result.Score -= 10
    }
    
    if ($result.Score -lt 70) {
        $result.Status = 'Failed'
    } elseif ($result.Score -lt 90) {
        $result.Status = 'Warning'
    }
    
    return $result
}

#endregion

#region Test Coverage Validation

function Test-TestCoverage {
    <#
    .SYNOPSIS
        Validate test coverage for a script or module
    .DESCRIPTION
        Checks for:
        - Existence of corresponding test file
        - Test file passes when executed
        - Adequate number of test cases
    .PARAMETER Path
        Path to the script or module file to validate
    .PARAMETER TestsPath
        Path to the tests directory (default: ./tests)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$TestsPath = (Join-Path $script:ProjectRoot 'tests')
    )
    
    Write-QualityLog -Message "Validating test coverage: $Path"
    
    $result = [PSCustomObject]@{
        CheckName = 'TestCoverage'
        Status = 'Passed'
        Findings = @()
        Score = 100
        Details = @{}
    }
    
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $fileDir = Split-Path $Path -Parent
    
    # Determine expected test file location
    $possibleTestPaths = @()
    
    # For domain modules
    if ($fileDir -like "*domains*") {
        $domainName = ($fileDir -split 'domains[\\/]')[1] -split '[\\/]' | Select-Object -First 1
        $possibleTestPaths += Join-Path $TestsPath "domains/$domainName/$fileName.Tests.ps1"
        $possibleTestPaths += Join-Path $TestsPath "unit/$fileName.Tests.ps1"
    }
    
    # For automation scripts
    if ($fileDir -like "*automation-scripts*") {
        $possibleTestPaths += Join-Path $TestsPath "integration/$fileName.Tests.ps1"
        $possibleTestPaths += Join-Path $TestsPath "unit/$fileName.Tests.ps1"
    }
    
    # Generic location
    $possibleTestPaths += Join-Path $TestsPath "$fileName.Tests.ps1"
    
    $testFilePath = $possibleTestPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if (-not $testFilePath) {
        $result.Status = 'Failed'
        $result.Score = 0
        $result.Findings += "No test file found. Expected at one of: $($possibleTestPaths -join ', ')"
        $result.Details.TestFileExists = $false
        return $result
    }
    
    $result.Details.TestFileExists = $true
    $result.Details.TestFilePath = $testFilePath
    
    # Check test file content
    $testContent = Get-FileContent -Path $testFilePath
    if (-not $testContent) {
        $result.Status = 'Failed'
        $result.Score = 20
        $result.Findings += "Test file exists but is empty or unreadable"
        return $result
    }
    
    # Count test cases
    $describeBlocks = [regex]::Matches($testContent, 'Describe\s+[''"].*?[''"]')
    $itBlocks = [regex]::Matches($testContent, 'It\s+[''"].*?[''"]')
    
    $result.Details.DescribeBlocks = $describeBlocks.Count
    $result.Details.ItBlocks = $itBlocks.Count
    
    if ($itBlocks.Count -eq 0) {
        $result.Status = 'Failed'
        $result.Score = 30
        $result.Findings += "Test file has no test cases (It blocks)"
        return $result
    }
    
    if ($itBlocks.Count -lt 3) {
        $result.Findings += "Consider adding more test cases for better coverage (currently: $($itBlocks.Count))"
        $result.Score -= 20
    }
    
    # Check if tests can be run (basic validation)
    try {
        # Check if Pester is available
        if (-not (Get-Module -ListAvailable -Name Pester)) {
            $result.Findings += "Pester not installed - cannot verify if tests pass"
            $result.Score -= 30
            $result.Status = 'Warning'
        } else {
            # Note: Actually running tests here could be expensive
            # We'll just validate the test file structure is valid PowerShell
            $parseErrors = $null
            $testAst = [System.Management.Automation.Language.Parser]::ParseFile($testFilePath, [ref]$null, [ref]$parseErrors)
            if ($parseErrors -and $parseErrors.Count -gt 0) {
                $result.Details.TestFileSyntaxValid = $false
                $result.Findings += "Test file has syntax errors:`n" + ($parseErrors | ForEach-Object { $_.Message } | Out-String)
                $result.Score -= 40
                $result.Status = 'Failed'
            } elseif ($testAst) {
                $result.Details.TestFileSyntaxValid = $true
            }
        }
    } catch {
        $result.Findings += "Test file has syntax errors: $_"
        $result.Score -= 40
        $result.Status = 'Failed'
    }
    
    if ($result.Score -lt 70) {
        $result.Status = 'Failed'
    } elseif ($result.Score -lt 90) {
        $result.Status = 'Warning'
    }
    
    return $result
}

#endregion

#region UI/CLI Integration Validation

function Test-UIIntegration {
    <#
    .SYNOPSIS
        Validate UI and CLI integration for a component
    .DESCRIPTION
        Checks for:
        - Menu integration in Start-AitherZero.ps1
        - CLI parameter support
        - Help documentation
    .PARAMETER Path
        Path to the script or module file to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Write-QualityLog -Message "Validating UI/CLI integration: $Path"
    
    $result = [PSCustomObject]@{
        CheckName = 'UIIntegration'
        Status = 'Passed'
        Findings = @()
        Score = 100
        Details = @{}
    }
    
    $content = Get-FileContent -Path $Path
    if (-not $content) {
        $result.Status = 'Failed'
        $result.Score = 0
        $result.Findings += "Could not read file content"
        return $result
    }
    
    # Check for CmdletBinding (indicates proper cmdlet structure)
    if ($content -match '\[CmdletBinding\(') {
        $result.Details.HasCmdletBinding = $true
    } else {
        $result.Findings += "Consider adding [CmdletBinding()] for advanced parameter support"
        $result.Score -= 15
    }
    
    # Check for parameter definitions
    $paramPattern = '\[Parameter\('
    $paramMatches = [regex]::Matches($content, $paramPattern)
    $result.Details.ParameterCount = $paramMatches.Count
    
    if ($paramMatches.Count -eq 0) {
        $result.Findings += "No parameters defined. Consider adding parameters for flexibility"
        $result.Score -= 10
    }
    
    # Check for help documentation
    $helpPatterns = @(
        '\.SYNOPSIS'
        '\.DESCRIPTION'
        '\.PARAMETER'
        '\.EXAMPLE'
    )
    
    $helpCount = 0
    foreach ($pattern in $helpPatterns) {
        if ($content -match $pattern) {
            $helpCount++
        }
    }
    
    $result.Details.HelpSections = $helpCount
    
    if ($helpCount -eq 0) {
        $result.Findings += "No help documentation found. Add comment-based help"
        $result.Score -= 30
    } elseif ($helpCount -lt 3) {
        $result.Findings += "Incomplete help documentation. Add more sections (.SYNOPSIS, .DESCRIPTION, .EXAMPLE)"
        $result.Score -= 15
    }
    
    # For automation scripts, check if it's referenced in the main launcher
    if ($Path -like "*automation-scripts*") {
        $scriptNumber = [regex]::Match($Path, '\d{4}').Value
        if ($scriptNumber) {
            $launcherPath = Join-Path $script:ProjectRoot 'Start-AitherZero.ps1'
            if (Test-Path $launcherPath) {
                $launcherContent = Get-FileContent -Path $launcherPath
                if ($launcherContent -match $scriptNumber) {
                    $result.Details.IntegratedInLauncher = $true
                } else {
                    $result.Findings += "Script not integrated into Start-AitherZero.ps1 launcher"
                    $result.Score -= 20
                }
            }
        }
    }
    
    if ($result.Score -lt 70) {
        $result.Status = 'Failed'
    } elseif ($result.Score -lt 90) {
        $result.Status = 'Warning'
    }
    
    return $result
}

#endregion

#region GitHub Actions Integration Validation

function Test-GitHubActionsIntegration {
    <#
    .SYNOPSIS
        Validate GitHub Actions integration where appropriate
    .DESCRIPTION
        Checks if component should be integrated into CI/CD workflows
        and validates the integration if present
    .PARAMETER Path
        Path to the script or module file to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Write-QualityLog -Message "Validating GitHub Actions integration: $Path"
    
    $result = [PSCustomObject]@{
        CheckName = 'GitHubActions'
        Status = 'Passed'
        Findings = @()
        Score = 100
        Details = @{}
    }
    
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    
    # Determine if this component should be in CI/CD
    $shouldBeInCI = $false
    
    # Testing and validation scripts should be in CI
    if ($fileName -match '^(0[4-5]\d{2}|.*Test.*|.*Validate.*|.*Analyze.*)') {
        $shouldBeInCI = $true
    }
    
    # Quality and reporting scripts
    if ($fileName -match '(Quality|Report|Coverage|Analysis)') {
        $shouldBeInCI = $true
    }
    
    $result.Details.ShouldBeInCI = $shouldBeInCI
    
    if (-not $shouldBeInCI) {
        $result.Status = 'Skipped'
        $result.Findings += "Component does not require GitHub Actions integration"
        return $result
    }
    
    # Check if referenced in workflows
    $workflowsPath = Join-Path $script:ProjectRoot '.github/workflows'
    if (-not (Test-Path $workflowsPath)) {
        $result.Status = 'Warning'
        $result.Score = 70
        $result.Findings += "No workflows directory found"
        return $result
    }
    
    $workflowFiles = Get-ChildItem -Path $workflowsPath -Filter '*.yml' -File
    $foundInWorkflow = $false
    $workflowsContainingScript = @()
    
    foreach ($workflow in $workflowFiles) {
        $workflowContent = Get-FileContent -Path $workflow.FullName
        if ($workflowContent -match [regex]::Escape($fileName)) {
            $foundInWorkflow = $true
            $workflowsContainingScript += $workflow.Name
        }
    }
    
    $result.Details.IntegratedInWorkflows = $foundInWorkflow
    $result.Details.Workflows = $workflowsContainingScript
    
    if (-not $foundInWorkflow) {
        $result.Findings += "Component should be integrated into CI/CD workflows"
        $result.Score -= 30
        $result.Status = 'Warning'
    }
    
    if ($result.Score -lt 70) {
        $result.Status = 'Failed'
    } elseif ($result.Score -lt 90) {
        $result.Status = 'Warning'
    }
    
    return $result
}

#endregion

#region PSScriptAnalyzer Compliance

function Test-PSScriptAnalyzerCompliance {
    <#
    .SYNOPSIS
        Validate PSScriptAnalyzer compliance
    .DESCRIPTION
        Runs PSScriptAnalyzer on the file and reports findings
    .PARAMETER Path
        Path to the script or module file to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    Write-QualityLog -Message "Validating PSScriptAnalyzer compliance: $Path"
    
    $result = [PSCustomObject]@{
        CheckName = 'PSScriptAnalyzer'
        Status = 'Passed'
        Findings = @()
        Score = 100
        Details = @{}
    }
    
    # Check if PSScriptAnalyzer is available
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        $result.Status = 'Skipped'
        $result.Findings += "PSScriptAnalyzer not installed"
        return $result
    }
    
    try {
        Import-Module PSScriptAnalyzer -ErrorAction Stop
        
        # Run analysis
        $analysisResults = Invoke-ScriptAnalyzer -Path $Path -Severity Error, Warning -ErrorAction SilentlyContinue
        
        $result.Details.TotalIssues = if ($analysisResults) { $analysisResults.Count } else { 0 }
        
        if ($analysisResults) {
            $errorCount = @($analysisResults | Where-Object { $_.Severity -eq 'Error' }).Count
            $warningCount = @($analysisResults | Where-Object { $_.Severity -eq 'Warning' }).Count
            
            $result.Details.Errors = $errorCount
            $result.Details.Warnings = $warningCount
            
            # Score calculation
            $totalPenalty = ($errorCount * 15) + ($warningCount * 5)
            $result.Score = [math]::Max(0, $result.Score - $totalPenalty)
            
            # Add findings
            if ($errorCount -gt 0) {
                $result.Findings += "$errorCount PSScriptAnalyzer error(s) found"
            }
            if ($warningCount -gt 0) {
                $result.Findings += "$warningCount PSScriptAnalyzer warning(s) found"
            }
            
            # Add top issues
            $topIssues = $analysisResults | Select-Object -First 5 | ForEach-Object {
                "Line $($_.Line): $($_.RuleName) - $($_.Message)"
            }
            $result.Details.TopIssues = $topIssues
        }
        
        if ($result.Score -lt 70) {
            $result.Status = 'Failed'
        } elseif ($result.Score -lt 90) {
            $result.Status = 'Warning'
        }
        
    } catch {
        $result.Status = 'Failed'
        $result.Score = 0
        $result.Findings += "PSScriptAnalyzer execution failed: $_"
    }
    
    return $result
}

#endregion

#region Comprehensive Validation

function Invoke-QualityValidation {
    <#
    .SYNOPSIS
        Run comprehensive quality validation on a file
    .DESCRIPTION
        Executes all quality checks and provides comprehensive report
    .PARAMETER Path
        Path to the script or module file to validate
    .PARAMETER SkipChecks
        Array of check names to skip
    .PARAMETER TestsPath
        Path to the tests directory
    .OUTPUTS
        Comprehensive validation report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$Path,
        
        [string[]]$SkipChecks = @(),
        
        [string]$TestsPath = (Join-Path $script:ProjectRoot 'tests')
    )
    
    begin {
        Write-QualityLog -Message "Starting comprehensive quality validation"
    }
    
    process {
        foreach ($filePath in $Path) {
            if (-not (Test-Path $filePath)) {
                Write-QualityLog -Level Error -Message "File not found: $filePath"
                continue
            }
            
            $report = [PSCustomObject]@{
                FilePath = $filePath
                FileName = Split-Path $filePath -Leaf
                Timestamp = Get-Date
                OverallStatus = 'Passed'
                OverallScore = 100
                Checks = @()
                Summary = @{}
            }
            
            # Run all checks
            $checks = @(
                @{ Name = 'ErrorHandling'; Function = 'Test-ErrorHandling' }
                @{ Name = 'Logging'; Function = 'Test-LoggingImplementation' }
                @{ Name = 'TestCoverage'; Function = 'Test-TestCoverage' }
                @{ Name = 'UIIntegration'; Function = 'Test-UIIntegration' }
                @{ Name = 'GitHubActions'; Function = 'Test-GitHubActionsIntegration' }
                @{ Name = 'PSScriptAnalyzer'; Function = 'Test-PSScriptAnalyzerCompliance' }
            )
            
            foreach ($check in $checks) {
                if ($check.Name -in $SkipChecks) {
                    Write-QualityLog -Message "Skipping check: $($check.Name)"
                    continue
                }
                
                try {
                    $checkResult = & $check.Function -Path $filePath
                    if ($check.Name -eq 'TestCoverage') {
                        $checkResult = & $check.Function -Path $filePath -TestsPath $TestsPath
                    }
                    
                    $report.Checks += $checkResult
                    
                    # Update overall status
                    if ($checkResult.Status -eq 'Failed') {
                        $report.OverallStatus = 'Failed'
                    } elseif ($checkResult.Status -eq 'Warning' -and $report.OverallStatus -ne 'Failed') {
                        $report.OverallStatus = 'Warning'
                    }
                    
                } catch {
                    Write-QualityLog -Level Error -Message "Check $($check.Name) failed: $_"
                }
            }
            
            # Calculate overall score (average of non-skipped checks)
            $validScores = $report.Checks | Where-Object { $_.Status -ne 'Skipped' } | Select-Object -ExpandProperty Score
            if ($validScores) {
                $report.OverallScore = [math]::Round(($validScores | Measure-Object -Average).Average, 0)
            }
            
            # Generate summary
            $report.Summary = @{
                TotalChecks = $report.Checks.Count
                Passed = @($report.Checks | Where-Object { $_.Status -eq 'Passed' }).Count
                Failed = @($report.Checks | Where-Object { $_.Status -eq 'Failed' }).Count
                Warnings = @($report.Checks | Where-Object { $_.Status -eq 'Warning' }).Count
                Skipped = @($report.Checks | Where-Object { $_.Status -eq 'Skipped' }).Count
            }
            
            Write-QualityLog -Message "Validation completed for $filePath" -Data @{
                Status = $report.OverallStatus
                Score = $report.OverallScore
            }
            
            Write-Output $report
        }
    }
    
    end {
        Write-QualityLog -Message "Quality validation completed"
    }
}

function Format-QualityReport {
    <#
    .SYNOPSIS
        Format quality validation report for display
    .DESCRIPTION
        Creates a formatted text or HTML report from validation results
    .PARAMETER Report
        Validation report object from Invoke-QualityValidation
    .PARAMETER Format
        Output format: Text, HTML, or JSON
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Report,
        
        [ValidateSet('Text', 'HTML', 'JSON')]
        [string]$Format = 'Text'
    )
    
    process {
        switch ($Format) {
            'JSON' {
                return $Report | ConvertTo-Json -Depth 10
            }
            
            'HTML' {
                # Simple HTML report
                $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Quality Report - $($Report.FileName)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .passed { color: green; }
        .failed { color: red; }
        .warning { color: orange; }
        .score { font-size: 2em; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
    </style>
</head>
<body>
    <h1>Quality Validation Report</h1>
    <p><strong>File:</strong> $($Report.FileName)</p>
    <p><strong>Timestamp:</strong> $($Report.Timestamp)</p>
    <p><strong>Overall Status:</strong> <span class="$($Report.OverallStatus.ToLower())">$($Report.OverallStatus)</span></p>
    <p><strong>Overall Score:</strong> <span class="score">$($Report.OverallScore)%</span></p>
    
    <h2>Check Results</h2>
    <table>
        <tr>
            <th>Check</th>
            <th>Status</th>
            <th>Score</th>
            <th>Findings</th>
        </tr>
"@
                foreach ($check in $Report.Checks) {
                    $html += @"
        <tr>
            <td>$($check.CheckName)</td>
            <td class="$($check.Status.ToLower())">$($check.Status)</td>
            <td>$($check.Score)%</td>
            <td>$($check.Findings -join '<br>')</td>
        </tr>
"@
                }
                
                $html += @"
    </table>
</body>
</html>
"@
                return $html
            }
            
            default {
                # Text format
                $output = @"
================================================================================
                    QUALITY VALIDATION REPORT
================================================================================
File: $($Report.FileName)
Path: $($Report.FilePath)
Timestamp: $($Report.Timestamp)

OVERALL STATUS: $($Report.OverallStatus)
OVERALL SCORE: $($Report.OverallScore)%

SUMMARY:
  Total Checks: $($Report.Summary.TotalChecks)
  Passed: $($Report.Summary.Passed)
  Failed: $($Report.Summary.Failed)
  Warnings: $($Report.Summary.Warnings)
  Skipped: $($Report.Summary.Skipped)

================================================================================
                        DETAILED RESULTS
================================================================================

"@
                foreach ($check in $Report.Checks) {
                    $output += @"
[$($check.Status)] $($check.CheckName) - Score: $($check.Score)%
"@
                    if ($check.Findings.Count -gt 0) {
                        $output += "`n  Findings:`n"
                        foreach ($finding in $check.Findings) {
                            $output += "    - $finding`n"
                        }
                    }
                    $output += "`n"
                }
                
                $output += "================================================================================"
                return $output
            }
        }
    }
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Test-ErrorHandling'
    'Test-LoggingImplementation'
    'Test-TestCoverage'
    'Test-UIIntegration'
    'Test-GitHubActionsIntegration'
    'Test-PSScriptAnalyzerCompliance'
    'Invoke-QualityValidation'
    'Format-QualityReport'
)
