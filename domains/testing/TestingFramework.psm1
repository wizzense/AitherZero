#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Testing Framework Module (Legacy + Enhanced)
.DESCRIPTION
    Core testing orchestration module that integrates Pester, PSScriptAnalyzer,
    and custom testing capabilities into the AitherZero platform.
    Enhanced to consolidate functionality from automation scripts 0400-0499.
.NOTES
    Copyright © 2025 Aitherium Corporation
    Consolidates: 0400_Install-TestingTools.ps1, 0402_Run-UnitTests.ps1,
                  0403_Run-IntegrationTests.ps1, 0404_Run-PSScriptAnalyzer.ps1,
                  0405_Validate-AST.ps1, 0406_Generate-Coverage.ps1, 0407_Validate-Syntax.ps1,
                  0408_Generate-TestCoverage.ps1, 0409_Run-AllTests.ps1, plus workflow testing
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:TestingState = @{
    CurrentProfile = 'Standard'
    Results = @()
    Coverage = @{}
    AnalysisResults = @()
}

# Import dependencies
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:ConfigPath = Join-Path $script:ProjectRoot 'config.psd1'

# Logging helper for TestingFramework module
function Write-TestingLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    # Respect quiet mode - only show warnings and errors
    if ($env:AITHERZERO_QUIET_MODE -eq 'true' -and $Level -notin @('Warning', 'Error')) {
        return
    }
    
    # Respect log level override
    $logLevels = @{ 'Debug' = 0; 'Information' = 1; 'Warning' = 2; 'Error' = 3 }
    $minLevel = if ($env:AITHERZERO_LOG_LEVEL) { $env:AITHERZERO_LOG_LEVEL } else { 'Information' }
    if ($logLevels[$Level] -lt $logLevels[$minLevel]) {
        return
    }

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "TestingFramework" -Data $Data
    } else {
        # Only output to console if not in quiet mode
        if ($env:AITHERZERO_QUIET_MODE -ne 'true') {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $color = @{
                'Error' = 'Red'
                'Warning' = 'Yellow'
                'Information' = 'White'
                'Debug' = 'Gray'
            }[$Level]
            Write-Host "[$timestamp] [$Level] [TestingFramework] $Message" -ForegroundColor $color
        }
    }
}

# Log module initialization (only once)
if (-not (Get-Variable -Name "AitherZeroTestingInitialized" -Scope Global -ErrorAction SilentlyContinue)) {
    Write-TestingLog -Message "Testing framework module initialized" -Data @{
        ProjectRoot = $script:ProjectRoot
        ConfigPath = $script:ConfigPath
        CurrentProfile = $script:TestingState.CurrentProfile
    }
    $global:AitherZeroTestingInitialized = $true
}

# Load configuration
function Get-TestingConfiguration {
    param(
        [string]$ConfigPath = $script:ConfigPath
    )

    Write-TestingLog -Level Debug -Message "Loading testing configuration" -Data @{
        ConfigPath = $ConfigPath
    }

    # Try to use Configuration module if available
    if (Get-Command Get-Configuration -ErrorAction SilentlyContinue) {
        try {
            Write-TestingLog -Level Debug -Message "Using Configuration module"
            $testingConfig = Get-Configuration -Section 'Testing'
            if ($testingConfig) {
                Write-TestingLog -Message "Testing configuration loaded via Configuration module"
                return $testingConfig
            }
        } catch {
            Write-TestingLog -Level Warning -Message "Failed to load configuration via Configuration module" -Data @{
                Error = $_.Exception.Message
            }
        }
    }

    # Fallback to direct file loading with local override support
    if (Test-Path $ConfigPath) {
        try {
            Write-TestingLog -Level Debug -Message "Loading configuration directly from file"
            $config = Import-PowerShellDataFile $ConfigPath

            # Check for local overrides
            $localConfigPath = $ConfigPath -replace '\.psd1$', '.local.psd1'
            if (Test-Path $localConfigPath) {
                Write-TestingLog -Level Debug -Message "Loading local configuration overrides" -Data @{
                    LocalConfigPath = $localConfigPath
                }
                $localConfig = Import-PowerShellDataFile $localConfigPath
                if ($localConfig.Testing) {
                    # Merge local Testing configuration
                    foreach ($key in $localConfig.Testing.Keys) {
                        $config.Testing.$key = $localConfig.Testing.$key
                    }
                }
            }

            $testingConfig = $config.Testing ?? @{
                Framework = 'Pester'
                MinVersion = '5.0.0'
                Parallel = $true
                MaxConcurrency = 4
            }
            Write-TestingLog -Message "Testing configuration loaded from file" -Data @{
                Framework = $testingConfig.Framework
                MinVersion = $testingConfig.MinVersion
                Parallel = $testingConfig.Parallel
            }
            return $testingConfig
        } catch {
            Write-TestingLog -Level Error -Message "Failed to load testing configuration from file" -Data @{
                ConfigPath = $ConfigPath
                Error = $_.Exception.Message
            }
            throw
        }
    }

    Write-TestingLog -Message "Using default testing configuration (no config file found)"
    return @{}
}

function Invoke-TestSuite {
    <#
    .SYNOPSIS
        Execute a test suite based on profile or custom configuration
    .PARAMETER Profile
        Test profile to execute (Quick, Standard, Full, CI)
    .PARAMETER Categories
        Specific test categories to run
    .PARAMETER Path
        Path to test files (defaults to ./tests)
    .PARAMETER OutputPath
        Path for test results
    .PARAMETER Configuration
        Override configuration
    .PARAMETER PassThru
        Return test results object
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Quick', 'Standard', 'Full', 'CI')]
        [string]$ProfileName = 'Standard',

        [string[]]$Categories,

        [string]$Path = (Join-Path $script:ProjectRoot 'tests'),

        [string]$OutputPath,

        [hashtable]$Configuration,

        [switch]$PassThru
    )

    Write-TestingLog -Message "Starting test suite execution" -Data @{
        Profile = $ProfileName
        Categories = ($Categories -join ', ')
        Path = $Path
        OutputPath = $OutputPath
        HasCustomConfiguration = ($null -ne $Configuration)
    }

    try {
        $testConfig = Get-TestingConfiguration
        if ($Configuration) {
            Write-TestingLog -Level Debug -Message "Applying custom configuration override"
            $testConfig = $testConfig + $Configuration
        }

        # Get profile settings
        $ProfileNameConfig = if ($testConfig -and $testConfig.ContainsKey('Profiles') -and $testConfig.Profiles -and $testConfig.Profiles.ContainsKey($ProfileName)) {
            $testConfig.Profiles[$ProfileName]
        } else {
            @{
                Categories = @('Unit', 'Integration')
                Timeout = 900
            }
        }

        # Override with explicit categories
        if ($Categories) {
            Write-TestingLog -Level Debug -Message "Overriding profile categories" -Data @{
                OriginalCategories = ($ProfileNameConfig.Categories -join ', ')
                NewCategories = ($Categories -join ', ')
            }
            $ProfileNameConfig.Categories = $Categories
        }

        Write-TestingLog -Message "Test profile configuration loaded" -Data @{
            Profile = $ProfileName
            Categories = ($ProfileNameConfig.Categories -join ', ')
            Timeout = $ProfileNameConfig.Timeout
        }

        Write-Verbose "Executing test profile: $ProfileName"
        Write-Verbose "Categories: $($ProfileNameConfig.Categories -join ', ')"

        # Ensure Pester is available
        Write-TestingLog -Level Debug -Message "Checking Pester availability" -Data @{
            RequiredVersion = $testConfig.MinVersion
        }

        if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge $testConfig.MinVersion })) {
            Write-TestingLog -Level Error -Message "Required Pester version not available" -Data @{
                RequiredVersion = $testConfig.MinVersion
            }
            throw "Pester $($testConfig.MinVersion) or higher is required"
        }

        Write-TestingLog -Message "Pester module available and compatible"

        Import-Module Pester -MinimumVersion $testConfig.MinVersion
        Write-TestingLog -Message "Pester module imported successfully" -Data @{
            Version = (Get-Module Pester).Version.ToString()
        }

        # Build Pester configuration
        Write-TestingLog -Level Debug -Message "Building Pester configuration"
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $Path
        $pesterConfig.Run.PassThru = $true
        $pesterConfig.Run.Exit = $false

        # Filter by categories
        if ($ProfileNameConfig.Categories -and $ProfileNameConfig.Categories[0] -ne '*') {
            Write-TestingLog -Level Debug -Message "Applying test category filters" -Data @{
                Categories = ($ProfileNameConfig.Categories -join ', ')
            }
            $pesterConfig.Filter.Tag = $ProfileNameConfig.Categories
        }

        # Output configuration
        if ($OutputPath) {
            $testResultPath = Join-Path $OutputPath "TestResults-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
            Write-TestingLog -Level Debug -Message "Configuring test result output" -Data @{
                OutputPath = $testResultPath
                Format = 'NUnitXml'
            }
            $pesterConfig.TestResult.Enabled = $true
            $pesterConfig.TestResult.OutputPath = $testResultPath
            $pesterConfig.TestResult.OutputFormat = 'NUnitXml'
        }

        # Code coverage
        if ($testConfig.CodeCoverage.Enabled) {
            $coveragePath = Join-Path ($OutputPath ?? './tests/coverage') "Coverage-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
            Write-TestingLog -Message "Code coverage enabled" -Data @{
                CoveragePath = $coveragePath
                MinimumPercent = $testConfig.CodeCoverage.MinimumPercent
            }
            $pesterConfig.CodeCoverage.Enabled = $true
            $pesterConfig.CodeCoverage.Path = Join-Path $script:ProjectRoot 'domains'
            $pesterConfig.CodeCoverage.OutputPath = $coveragePath
            $pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
        }

        # Execute tests
        Write-TestingLog -Message "Starting Pester test execution" -Data @{
            TestPath = $Path
            Categories = ($ProfileNameConfig.Categories -join ', ')
            CoverageEnabled = $testConfig.CodeCoverage.Enabled
        }
        $result = Invoke-Pester -Configuration $pesterConfig

        # Store results
        $script:TestingState.Results += $result

        # Log test execution results
        Write-TestingLog -Message "Test execution completed" -Data @{
            Profile = $ProfileName
            TotalTests = $result.TotalCount
            PassedTests = $result.PassedCount
            FailedTests = $result.FailedCount
            SkippedTests = $result.SkippedCount
            Duration = $result.Duration
            Success = ($result.FailedCount -eq 0)
        }

        # Check minimum coverage
        if ($testConfig.CodeCoverage.Enabled) {
            $coveragePercent = $result.CodeCoverage.CoveragePercent
            Write-TestingLog -Message "Code coverage analysis completed" -Data @{
                CoveragePercent = $coveragePercent
                MinimumRequired = $testConfig.CodeCoverage.MinimumPercent
                MeetsRequirement = ($coveragePercent -ge $testConfig.CodeCoverage.MinimumPercent)
            }

            if ($coveragePercent -lt $testConfig.CodeCoverage.MinimumPercent) {
                Write-TestingLog -Level Warning -Message "Code coverage below minimum threshold" -Data @{
                    Actual = $coveragePercent
                    Required = $testConfig.CodeCoverage.MinimumPercent
                }
                Write-Warning "Code coverage ($($coveragePercent)%) is below minimum ($($testConfig.CodeCoverage.MinimumPercent)%)"
            }
        }

        # Log failed tests if any
        if ($result.FailedCount -gt 0) {
            Write-TestingLog -Level Warning -Message "Test failures detected" -Data @{
                FailedCount = $result.FailedCount
                FailedTests = ($result.Tests | Where-Object Result -eq 'Failed' | Select-Object -ExpandProperty Name)
            }
        }

        # Display summary
        Write-Host "`nTest Summary:" -ForegroundColor Cyan
        Write-Host "  Total Tests: $($result.TotalCount)"
        Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
        Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Green' })
        Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Yellow

        if ($testConfig.CodeCoverage.Enabled) {
            Write-Host "  Coverage: $($result.CodeCoverage.CoveragePercent)%" -ForegroundColor $(
                if ($result.CodeCoverage.CoveragePercent -ge $testConfig.CodeCoverage.MinimumPercent) { 'Green' } else { 'Yellow' }
            )
    }

        if ($PassThru) {
            return $result
        }

        # Return success/failure
        return $result.FailedCount -eq 0

    } catch {
        Write-TestingLog -Level Error -Message "Test suite execution failed" -Data @{
            Profile = $ProfileName
            Path = $Path
            Error = $_.Exception.Message
            StackTrace = $_.ScriptStackTrace
        }
        throw
    }
}

function Invoke-ScriptAnalysis {
    <#
    .SYNOPSIS
        Run PSScriptAnalyzer on project files
    .PARAMETER Path
        Path to analyze
    .PARAMETER Recurse
        Analyze recursively
    .PARAMETER SettingsPath
        Path to PSScriptAnalyzer settings
    .PARAMETER Fix
        Attempt to fix issues automatically
    .PARAMETER OutputPath
        Path for analysis results
    #>
    [CmdletBinding()]
    param(
        [string]$Path = $script:ProjectRoot,

        [switch]$Recurse,

        [string]$SettingsPath,

        [switch]$Fix,

        [string]$OutputPath
    )

    $testConfig = Get-TestingConfiguration
    $analysisConfig = $testConfig.PSScriptAnalyzer

    if (-not $analysisConfig.Enabled) {
        Write-Warning "PSScriptAnalyzer is disabled in configuration"
        return
    }

    # Ensure PSScriptAnalyzer is available
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        throw "PSScriptAnalyzer module is required"
    }

    Import-Module PSScriptAnalyzer

    # Build parameters
    $analyzerParams = @{
        Path = $Path
        Recurse = $Recurse
        ExcludeRule = $analysisConfig.Rules.ExcludeRules
        Severity = $analysisConfig.Rules.Severity
    }

    if ($SettingsPath -or $analysisConfig.SettingsPath) {
        $settingsFile = $SettingsPath ?? (Join-Path $script:ProjectRoot $analysisConfig.SettingsPath)
        if (Test-Path $settingsFile) {
            $analyzerParams['Settings'] = $settingsFile
        }
    }

    if ($Fix) {
        $analyzerParams['Fix'] = $true
    }

    # Run analysis
    Write-Host "Running PSScriptAnalyzer on: $Path" -ForegroundColor Cyan
    $results = Invoke-ScriptAnalyzer @analyzerParams

    # Store results
    $script:TestingState.AnalysisResults = $results

    # Output results
    if ($OutputPath) {
        $results | Export-Csv -Path (Join-Path $OutputPath "PSScriptAnalyzer-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv") -NoTypeInformation
    }

    # Display summary
    $grouped = $results | Group-Object Severity
    Write-Host "`nAnalysis Summary:" -ForegroundColor Cyan

    foreach ($group in $grouped) {
        $color = switch ($group.Name) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Information' { 'Cyan' }
            default { 'White' }
        }
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor $color
    }

    if ($results.Count -eq 0) {
        Write-Host "  No issues found!" -ForegroundColor Green
    }

    return $results
}

function Test-ASTValidation {
    <#
    .SYNOPSIS
        Validate PowerShell Abstract Syntax Tree
    .PARAMETER Path
        Path to validate
    .PARAMETER CheckSyntax
        Check for syntax errors
    .PARAMETER CheckParameters
        Validate parameter usage
    .PARAMETER CheckCommands
        Verify command existence
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$CheckSyntax,

        [switch]$CheckParameters,

        [switch]$CheckCommands
    )

    $issues = @()

    # Get all PowerShell files
    $files = if (Test-Path $Path -PathType Container) {
        Get-ChildItem -Path $Path -Filter "*.ps*1" -Recurse
    } else {
        Get-Item $Path
    }

    foreach ($file in $files) {
        Write-Verbose "Validating: $($file.FullName)"

        try {
            # Parse the file
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName,
                [ref]$tokens,
                [ref]$errors
            )

            # Check syntax errors
            if ($CheckSyntax -and $errors.Count -gt 0) {
                foreach ($errorMsg in $errors) {
                    $issues += [PSCustomObject]@{
                        File = $file.FullName
                        Line = $errorMsg.Extent.StartLineNumber
                        Column = $error.Extent.StartColumnNumber
                        Type = 'SyntaxError'
                        Message = $errorMsg.Message
                    }
                }
            }

            # Check parameters
            if ($CheckParameters) {
                $paramAsts = $ast.FindAll({
                    $arguments[0] -is [System.Management.Automation.Language.ParameterAst]
                }, $true)

                foreach ($param in $paramAsts) {
                    # Check for missing parameter types
                    if (-not $param.StaticType -and -not $param.Attributes) {
                        $issues += [PSCustomObject]@{
                            File = $file.FullName
                            Line = $param.Extent.StartLineNumber
                            Column = $param.Extent.StartColumnNumber
                            Type = 'MissingParameterType'
                            Message = "Parameter '$($param.Name)' has no type declaration"
                        }
                    }
                }
            }

            # Check commands
            if ($CheckCommands) {
                $commandAsts = $ast.FindAll({
                    $arguments[0] -is [System.Management.Automation.Language.CommandAst]
                }, $true)

                foreach ($cmd in $commandAsts) {
                    $cmdName = $cmd.GetCommandName()
                    if ($cmdName -and -not (Get-Command $cmdName -ErrorAction SilentlyContinue)) {
                        # Check if it's a dynamic command or alias
                        if ($cmdName -notmatch '^\$' -and $cmdName -notmatch '^&') {
                            $issues += [PSCustomObject]@{
                                File = $file.FullName
                                Line = $cmd.Extent.StartLineNumber
                                Column = $cmd.Extent.StartColumnNumber
                                Type = 'UnknownCommand'
                                Message = "Command '$cmdName' not found"
                            }
                        }
                    }
                }
            }
        }
        catch {
            $issues += [PSCustomObject]@{
                File = $file.FullName
                Line = 0
                Column = 0
                Type = 'ParseError'
                Message = $_.Exception.Message
            }
        }
    }

    # Display results
    if ($issues.Count -eq 0) {
        Write-Host "AST validation passed!" -ForegroundColor Green
    } else {
        Write-Host "AST validation found $($issues.Count) issues:" -ForegroundColor Yellow
        $issues | Group-Object Type | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor Yellow
        }
    }

    return $issues
}

function New-TestReport {
    <#
    .SYNOPSIS
        Generate comprehensive test report
    .PARAMETER IncludeTests
        Include test results
    .PARAMETER IncludeAnalysis
        Include PSScriptAnalyzer results
    .PARAMETER IncludeCoverage
        Include code coverage
    .PARAMETER OutputPath
        Report output path
    .PARAMETER Format
        Report format (HTML, Markdown, JSON)
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeTests,

        [switch]$IncludeAnalysis,

        [switch]$IncludeCoverage,

        [string]$OutputPath = './tests/reports',

        [ValidateSet('HTML', 'Markdown', 'JSON')]
        [string]$Format = 'HTML'
    )

    $report = [PSCustomObject]@{
        Generated = Get-Date
        Project = 'AitherZero'
        Platform = $PSVersionTable.Platform
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    }

    # Add test results
    if ($IncludeTests -and $script:TestingState.Results) {
        $testSummary = $script:TestingState.Results | ForEach-Object {
            [PSCustomObject]@{
                Timestamp = $_.ExecutedAt
                TotalTests = $_.TotalCount
                Passed = $_.PassedCount
                Failed = $_.FailedCount
                Skipped = $_.SkippedCount
                Duration = $_.Duration
            }
        }
        $report | Add-Member -MemberType NoteProperty -Name TestResults -Value $testSummary
    }

    # Add analysis results
    if ($IncludeAnalysis -and $script:TestingState.AnalysisResults) {
        $analysisSummary = $script:TestingState.AnalysisResults | Group-Object Severity | ForEach-Object {
            [PSCustomObject]@{
                Severity = $_.Name
                Count = $_.Count
                Rules = $_.Group | Group-Object RuleName | ForEach-Object {
                    [PSCustomObject]@{
                        Rule = $_.Name
                        Count = $_.Count
                    }
                }
            }
        }
        $report | Add-Member -MemberType NoteProperty -Name AnalysisResults -Value $analysisSummary
    }

    # Add coverage results
    if ($IncludeCoverage -and $script:TestingState.Results[0].CodeCoverage) {
        $coverageSummary = [PSCustomObject]@{
            CoveragePercent = $script:TestingState.Results[0].CodeCoverage.CoveragePercent
            CoveredCommands = $script:TestingState.Results[0].CodeCoverage.NumberOfCommandsAnalyzed
            MissedCommands = $script:TestingState.Results[0].CodeCoverage.NumberOfCommandsMissed
        }
        $report | Add-Member -MemberType NoteProperty -Name CodeCoverage -Value $coverageSummary
    }

    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $filename = "TestReport-$timestamp"

    switch ($Format) {
        'JSON' {
            $outputFile = Join-Path $OutputPath "$filename.json"
            $report | ConvertTo-Json -Depth 10 | Set-Content $outputFile
        }

        'Markdown' {
            $outputFile = Join-Path $OutputPath "$filename.md"
            $markdown = @"
# AitherZero Test Report

Generated: $($report.Generated)

## Environment
- Platform: $($report.Platform)
- PowerShell: $($report.PowerShellVersion)

"@

            if ($report.TestResults) {
                $markdown += @"
## Test Results

| Timestamp | Total | Passed | Failed | Skipped | Duration |
|-----------|-------|--------|--------|---------|----------|
"@
                foreach ($result in $report.TestResults) {
                    $markdown += "| $($result.Timestamp) | $($result.TotalTests) | $($result.Passed) | $($result.Failed) | $($result.Skipped) | $($result.Duration) |`n"
                }
            }

            $markdown | Set-Content $outputFile
        }

        'HTML' {
            $outputFile = Join-Path $OutputPath "$filename.html"
            # Generate HTML report (simplified version)
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .passed { color: green; }
        .failed { color: red; }
        .skipped { color: orange; }
    </style>
</head>
<body>
    <h1>AitherZero Test Report</h1>
    <p>Generated: $($report.Generated)</p>
    <h2>Environment</h2>
    <ul>
        <li>Platform: $($report.Platform)</li>
        <li>PowerShell: $($report.PowerShellVersion)</li>
    </ul>
"@

            if ($report.TestResults) {
                $html += "<h2>Test Results</h2><table><tr><th>Timestamp</th><th>Total</th><th>Passed</th><th>Failed</th><th>Skipped</th><th>Duration</th></tr>"
                foreach ($result in $report.TestResults) {
                    $html += "<tr><td>$($result.Timestamp)</td><td>$($result.TotalTests)</td><td class='passed'>$($result.Passed)</td><td class='failed'>$($result.Failed)</td><td class='skipped'>$($result.Skipped)</td><td>$($result.Duration)</td></tr>"
                }
                $html += "</table>"
            }

            $html += "</body></html>"
            $html | Set-Content $outputFile
        }
    }

    Write-Host "Report generated: $outputFile" -ForegroundColor Green
    return $outputFile
}

######################################################################################
# CONSOLIDATED TESTING FUNCTIONS (from automation scripts 0400-0499)
######################################################################################

function Install-TestingTools {
    <#
    .SYNOPSIS
        Install complete testing toolchain
    .DESCRIPTION
        Installs Pester, PSScriptAnalyzer, and other testing tools
        Consolidates 0400_Install-TestingTools.ps1
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Force,
        [string[]]$AdditionalTools = @()
    )

    Write-TestingLog "Installing testing tools"

    $tools = @(
        @{ Name = 'Pester'; MinVersion = '5.0.0'; Repository = 'PSGallery' },
        @{ Name = 'PSScriptAnalyzer'; MinVersion = '1.20.0'; Repository = 'PSGallery' },
        @{ Name = 'PSCodeCovIo'; MinVersion = '1.0.0'; Repository = 'PSGallery' },
        @{ Name = 'PowerShellYaml'; MinVersion = '0.4.0'; Repository = 'PSGallery' }
    ) + $AdditionalTools

    foreach ($tool in $tools) {
        try {
            $installed = Get-Module -Name $tool.Name -ListAvailable |
                Where-Object { $_.Version -ge [Version]$tool.MinVersion } |
                Sort-Object Version -Descending |
                Select-Object -First 1

            if (-not $installed -or $Force) {
                Write-TestingLog "Installing $($tool.Name)"
                if ($PSCmdlet.ShouldProcess($tool.Name, "Install module")) {
                    Install-Module -Name $tool.Name -Repository $tool.Repository -MinimumVersion $tool.MinVersion -Force -Scope CurrentUser
                }
            } else {
                Write-TestingLog "$($tool.Name) v$($installed.Version) is already installed"
            }
        } catch {
            Write-TestingLog "Failed to install $($tool.Name): $($_.Exception.Message)" -Level Warning
        }
    }

    Write-TestingLog "Testing tools installation completed"
}

function Invoke-UnitTestSuite {
    <#
    .SYNOPSIS
        Execute unit tests with enhanced capabilities
    .DESCRIPTION
        Runs unit tests using Pester with advanced configuration
        Consolidates and enhances 0402_Run-UnitTests.ps1
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path = (Join-Path $script:ProjectRoot "tests/unit"),
        [string]$OutputPath = (Join-Path $script:ProjectRoot "test-results"),
        [switch]$NoCoverage,
        [switch]$CI,
        [switch]$UseCache,
        [int]$CoverageThreshold = 80,
        [string[]]$Tags = @(),
        [string[]]$ExcludeTags = @()
    )

    Write-TestingLog "Executing unit test suite"

    # Use new AitherTestFramework if available
    if (Get-Command Invoke-TestCategory -ErrorAction SilentlyContinue) {
        Write-TestingLog "Using AitherTestFramework for unit tests"

        $params = @{ Category = 'Unit' }
        if ($Tags.Count -gt 0) { $params['IncludeTags'] = $Tags }
        if ($ExcludeTags.Count -gt 0) { $params['ExcludeTags'] = $ExcludeTags }
        if ($CI) { $params['Force'] = $true }

        return Invoke-TestCategory @params
    }

    # Fallback to legacy Pester execution
    return Invoke-LegacyPesterTests -Path $Path -OutputPath $OutputPath -NoCoverage:$NoCoverage -CI:$CI
}

function Invoke-PSScriptAnalyzerSuite {
    <#
    .SYNOPSIS
        Execute PSScriptAnalyzer static analysis
    .DESCRIPTION
        Runs PSScriptAnalyzer with comprehensive rules
        Consolidates 0404_Run-PSScriptAnalyzer.ps1
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path = $script:ProjectRoot,
        [string]$OutputPath = (Join-Path $script:ProjectRoot "test-results"),
        [string[]]$Severity = @('Error', 'Warning', 'Information'),
        [string[]]$ExcludeRules = @('PSAvoidUsingWriteHost'),
        [switch]$Fix
    )

    Write-TestingLog "Running PSScriptAnalyzer static analysis"

    # Ensure PSScriptAnalyzer is available
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Write-TestingLog "PSScriptAnalyzer not found, installing..."
        Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
    }

    Import-Module PSScriptAnalyzer

    $analyzerParams = @{
        Path = $Path
        Recurse = $true
        Severity = $Severity
        ExcludeRule = $ExcludeRules
    }

    if ($Fix) {
        $analyzerParams['Fix'] = $true
        Write-TestingLog "Running with auto-fix enabled" -Level Warning
    }

    if ($PSCmdlet.ShouldProcess($Path, "Run PSScriptAnalyzer")) {
        $results = Invoke-ScriptAnalyzer @analyzerParams

        # Export results
        if ($results) {
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $csvPath = Join-Path $OutputPath "PSScriptAnalyzer-$timestamp.csv"
            $results | Export-Csv -Path $csvPath -NoTypeInformation
            Write-TestingLog "Analysis results saved to: $csvPath"
        }

        return @{
            Success = $results.Count -eq 0
            Results = $results
            ErrorCount = ($results | Where-Object { $_.Severity -eq 'Error' }).Count
            WarningCount = ($results | Where-Object { $_.Severity -eq 'Warning' }).Count
        }
    }
}

function Test-SyntaxValidation {
    <#
    .SYNOPSIS
        Validate PowerShell syntax across all files
    .DESCRIPTION
        Performs syntax validation using AST parsing
        Consolidates 0405_Validate-AST.ps1 and 0407_Validate-Syntax.ps1
    #>
    [CmdletBinding()]
    param(
        [string]$Path = $script:ProjectRoot,
        [string[]]$Include = @('*.ps1', '*.psm1', '*.psd1'),
        [string[]]$Exclude = @('tests/*', 'legacy-to-migrate/*')
    )

    Write-TestingLog "Validating PowerShell syntax"

    $files = Get-ChildItem -Path $Path -Include $Include -Recurse |
        Where-Object {
            $file = $_
            -not ($Exclude | Where-Object { $file.FullName -like "*$_*" })
        }

    $results = @()
    $errorCount = 0

    foreach ($file in $files) {
        try {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $file.FullName -Raw), [ref]$errors)

            if ($errors.Count -gt 0) {
                $errorCount += $errors.Count
                $results += @{
                    File = $file.FullName
                    Errors = $errors
                    Status = 'Failed'
                }
                Write-TestingLog "Syntax errors in $($file.Name): $($errors.Count)" -Level Error
            } else {
                $results += @{
                    File = $file.FullName
                    Errors = @()
                    Status = 'Passed'
                }
            }
        } catch {
            $errorCount++
            $results += @{
                File = $file.FullName
                Errors = @($_.Exception.Message)
                Status = 'Failed'
            }
            Write-TestingLog "Failed to parse $($file.Name): $($_.Exception.Message)" -Level Error
        }
    }

    Write-TestingLog "Syntax validation completed. Files: $($files.Count), Errors: $errorCount"

    return @{
        Success = $errorCount -eq 0
        TotalFiles = $files.Count
        ErrorCount = $errorCount
        Results = $results
    }
}

function Invoke-AllTestSuites {
    <#
    .SYNOPSIS
        Execute all test suites in sequence
    .DESCRIPTION
        Runs unit tests, integration tests, and static analysis
        Consolidates 0409_Run-AllTests.ps1
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$CI,
        [switch]$NoCoverage,
        [string]$OutputPath = (Join-Path $script:ProjectRoot "test-results")
    )

    Write-TestingLog "Executing all test suites"

    # Use new AitherTestFramework if available for comprehensive testing
    if (Get-Command Invoke-TestCategory -ErrorAction SilentlyContinue) {
        Write-TestingLog "Using AitherTestFramework for comprehensive testing"

        # Run Full category tests which includes everything
        $params = @{ Category = 'Full' }
        if ($CI) { $params['Force'] = $true }

        return Invoke-TestCategory @params
    }

    # Fallback to individual legacy test execution
    Write-TestingLog "Using legacy individual test execution"

    $overallResults = @{
        StartTime = Get-Date
        UnitTests = $null
        StaticAnalysis = $null
        SyntaxValidation = $null
        OverallSuccess = $true
    }

    try {
        # Unit tests
        Write-TestingLog "Running unit tests..."
        $overallResults.UnitTests = Invoke-UnitTestSuite -CI:$CI -NoCoverage:$NoCoverage -OutputPath $OutputPath

        # Static analysis
        Write-TestingLog "Running static analysis..."
        $overallResults.StaticAnalysis = Invoke-PSScriptAnalyzerSuite -OutputPath $OutputPath

        # Syntax validation
        Write-TestingLog "Running syntax validation..."
        $overallResults.SyntaxValidation = Test-SyntaxValidation

        # Determine overall success
        $overallResults.OverallSuccess = (
            $overallResults.UnitTests.Success -and
            $overallResults.StaticAnalysis.Success -and
            $overallResults.SyntaxValidation.Success
        )

        $overallResults.EndTime = Get-Date
        $overallResults.Duration = $overallResults.EndTime - $overallResults.StartTime

        Write-TestingLog "All test suites completed. Overall success: $($overallResults.OverallSuccess)"

        return $overallResults

    } catch {
        Write-TestingLog "Test suite execution failed: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Invoke-LegacyPesterTests {
    <#
    .SYNOPSIS
        Legacy Pester test execution for backward compatibility
    #>
    [CmdletBinding()]
    param(
        [string]$Path,
        [string]$OutputPath,
        [switch]$NoCoverage,
        [switch]$CI
    )

    # Ensure Pester is available
    $pesterModule = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pesterModule -or $pesterModule.Version -lt [Version]"5.0.0") {
        throw "Pester 5.0+ is required"
    }

    Import-Module Pester -MinimumVersion 5.0.0 -Force

    # Build Pester configuration
    $pesterConfig = New-PesterConfiguration
    $pesterConfig.Run.Path = $Path
    $pesterConfig.Run.PassThru = $true
    $pesterConfig.Run.Exit = $false

    if ($CI) {
        $pesterConfig.Output.Verbosity = 'Normal'
        $pesterConfig.Should.ErrorAction = 'Continue'
    }

    # Configure test results output
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $pesterConfig.TestResult.Enabled = $true
    $pesterConfig.TestResult.OutputPath = Join-Path $OutputPath "TestResults-$timestamp.xml"
    $pesterConfig.TestResult.OutputFormat = 'NUnitXml'

    # Configure code coverage if not disabled
    if (-not $NoCoverage) {
        $pesterConfig.CodeCoverage.Enabled = $true
        $pesterConfig.CodeCoverage.Path = @(
            Join-Path $script:ProjectRoot 'domains'
            Join-Path $script:ProjectRoot 'AitherZero.psm1'
        )
        $pesterConfig.CodeCoverage.OutputPath = Join-Path $OutputPath "Coverage-$timestamp.xml"
        $pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
    }

    # Execute tests
    $result = Invoke-Pester -Configuration $pesterConfig

    return @{
        Success = $result.FailedCount -eq 0
        TotalCount = $result.TotalCount
        PassedCount = $result.PassedCount
        FailedCount = $result.FailedCount
        Duration = $result.Duration
        Result = $result
    }
}

# Export functions (original + consolidated)
Export-ModuleMember -Function @(
    # Original exports
    'Invoke-TestSuite',
    'Invoke-ScriptAnalysis',
    'Test-ASTValidation',
    'New-TestReport',
    'Get-TestingConfiguration',

    # New consolidated exports (from automation scripts 0400-0499)
    'Install-TestingTools',
    'Invoke-UnitTestSuite',
    'Invoke-PSScriptAnalyzerSuite',
    'Test-SyntaxValidation',
    'Invoke-AllTestSuites'
)