#Requires -Version 7.0

<#
.SYNOPSIS
    Unified test runner for AitherZero Installation & Setup testing

.DESCRIPTION
    Comprehensive test runner for all installation and setup related tests:
    - Installation profile testing (minimal, developer, full)
    - PowerShell version compatibility testing
    - Cross-platform bootstrap validation
    - Setup wizard integration testing
    - Entry point validation
    - Developer setup script testing

.PARAMETER TestSuite
    Test suite to run: All, Installation, Setup, Platform, Performance, Quick

.PARAMETER Profile
    Installation profile to test: minimal, developer, full, all

.PARAMETER Platform
    Platform-specific tests: Windows, Linux, macOS, Current, All

.PARAMETER CI
    Run in CI mode (minimal output, strict validation)

.PARAMETER WhatIf
    Show what tests would be run without executing them

.PARAMETER Parallel
    Run tests in parallel where possible (default: true)

.PARAMETER OutputFormat
    Output format: Detailed, Minimal, JSON, XML

.PARAMETER ReportPath
    Path to save test reports

.PARAMETER Tags
    Specific tags to include in test run

.PARAMETER ExcludeTags
    Specific tags to exclude from test run

.EXAMPLE
    ./tests/Run-Installation-Tests.ps1
    # Run all installation & setup tests

.EXAMPLE
    ./tests/Run-Installation-Tests.ps1 -TestSuite Installation -Profile developer
    # Run installation tests for developer profile

.EXAMPLE
    ./tests/Run-Installation-Tests.ps1 -TestSuite Platform -Platform Current
    # Run platform-specific tests for current platform

.EXAMPLE
    ./tests/Run-Installation-Tests.ps1 -CI
    # Run in CI mode with minimal output

.NOTES
    This is the primary test runner for installation and setup validation
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Test suite to run")]
    [ValidateSet('All', 'Installation', 'Setup', 'Platform', 'Performance', 'Quick')]
    [string]$TestSuite = 'All',
    
    [Parameter(HelpMessage = "Installation profile to test")]
    [ValidateSet('minimal', 'developer', 'full', 'all')]
    [string]$Profile = 'all',
    
    [Parameter(HelpMessage = "Platform-specific tests")]
    [ValidateSet('Windows', 'Linux', 'macOS', 'Current', 'All')]
    [string]$Platform = 'Current',
    
    [Parameter(HelpMessage = "Run in CI mode")]
    [switch]$CI,
    
    [Parameter(HelpMessage = "Show what would be run")]
    [switch]$WhatIf,
    
    [Parameter(HelpMessage = "Run tests in parallel")]
    [switch]$Parallel = $true,
    
    [Parameter(HelpMessage = "Output format")]
    [ValidateSet('Detailed', 'Minimal', 'JSON', 'XML')]
    [string]$OutputFormat = 'Detailed',
    
    [Parameter(HelpMessage = "Path to save test reports")]
    [string]$ReportPath,
    
    [Parameter(HelpMessage = "Tags to include")]
    [string[]]$Tags = @(),
    
    [Parameter(HelpMessage = "Tags to exclude")]
    [string[]]$ExcludeTags = @()
)

# Script configuration
$ErrorActionPreference = 'Stop'
$script:StartTime = Get-Date
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:TestResults = @()

# Test configuration
$script:TestConfig = @{
    TestFiles = @(
        @{
            Name = 'Setup-Installation.Tests.ps1'
            Path = Join-Path $PSScriptRoot 'Setup-Installation.Tests.ps1'
            Category = 'Installation'
            Tags = @('Setup', 'Installation', 'Profiles', 'Critical')
            Description = 'Installation profile and setup testing'
            EstimatedDuration = 45
        },
        @{
            Name = 'PowerShell-Version.Tests.ps1'
            Path = Join-Path $PSScriptRoot 'PowerShell-Version.Tests.ps1'
            Category = 'Platform'
            Tags = @('Version', 'Compatibility', 'Critical')
            Description = 'PowerShell version compatibility testing'
            EstimatedDuration = 30
        },
        @{
            Name = 'CrossPlatform-Bootstrap.Tests.ps1'
            Path = Join-Path $PSScriptRoot 'CrossPlatform-Bootstrap.Tests.ps1'
            Category = 'Platform'
            Tags = @('CrossPlatform', 'Bootstrap', 'Critical')
            Description = 'Cross-platform bootstrap validation'
            EstimatedDuration = 60
        },
        @{
            Name = 'SetupWizard-Integration.Tests.ps1'
            Path = Join-Path $PSScriptRoot 'SetupWizard-Integration.Tests.ps1'
            Category = 'Setup'
            Tags = @('SetupWizard', 'Integration', 'Profiles')
            Description = 'Setup wizard integration testing'
            EstimatedDuration = 90
        },
        @{
            Name = 'EntryPoint-Validation.Tests.ps1'
            Path = Join-Path $PSScriptRoot 'EntryPoint-Validation.Tests.ps1'
            Category = 'Installation'
            Tags = @('EntryPoint', 'Validation', 'Critical')
            Description = 'Entry point script validation'
            EstimatedDuration = 30
        }
    )
    ReportFormats = @{
        'Detailed' = 'Detailed'
        'Minimal' = 'Minimal'  
        'JSON' = 'JUnitXml'
        'XML' = 'JUnitXml'
    }
    TimeoutMinutes = 15
}

# Logging function
function Write-TestLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',
        [switch]$NoTimestamp
    )
    
    $colors = @{
        'INFO'    = 'White'
        'SUCCESS' = 'Green'
        'WARNING' = 'Yellow'
        'ERROR'   = 'Red'
        'DEBUG'   = 'Gray'
    }
    
    $prefix = if (-not $NoTimestamp) {
        $timestamp = Get-Date -Format 'HH:mm:ss.fff'
        "[$timestamp] [$Level] "
    } else {
        "[$Level] "
    }
    
    Write-Host "$prefix$Message" -ForegroundColor $colors[$Level]
}

# Function to show test runner banner
function Show-TestRunnerBanner {
    if (-not $CI) {
        Clear-Host
        Write-Host ""
        Write-Host "    ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "    ║         AitherZero Installation & Setup Testing         ║" -ForegroundColor Cyan
        Write-Host "    ║                    Comprehensive Test Suite             ║" -ForegroundColor Cyan
        Write-Host "    ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
    }
    
    Write-TestLog "Starting AitherZero Installation & Setup Tests" -Level 'INFO'
    Write-TestLog "Project Root: $script:ProjectRoot" -Level 'INFO'
    Write-TestLog "Test Suite: $TestSuite" -Level 'INFO'
    Write-TestLog "Profile: $Profile" -Level 'INFO'
    Write-TestLog "Platform: $Platform" -Level 'INFO'
    Write-TestLog "Output Format: $OutputFormat" -Level 'INFO'
    
    if ($WhatIf) {
        Write-TestLog "Running in WhatIf mode - tests will not be executed" -Level 'WARNING'
    }
    
    if ($CI) {
        Write-TestLog "Running in CI mode - minimal output" -Level 'INFO'
    }
    
    Write-Host ""
}

# Function to validate prerequisites
function Test-TestPrerequisites {
    Write-TestLog "Validating test prerequisites..." -Level 'INFO'
    
    $prerequisites = @{
        PowerShell = $PSVersionTable.PSVersion.Major -ge 7
        Pester = $null -ne (Get-Module -ListAvailable -Name Pester | Where-Object Version -ge '5.0.0')
        ProjectStructure = Test-Path (Join-Path $script:ProjectRoot "Start-AitherZero.ps1")
    }
    
    $failed = @()
    foreach ($prereq in $prerequisites.GetEnumerator()) {
        if (-not $prereq.Value) {
            $failed += $prereq.Key
            Write-TestLog "Prerequisite failed: $($prereq.Key)" -Level 'ERROR'
        } else {
            Write-TestLog "Prerequisite passed: $($prereq.Key)" -Level 'SUCCESS'
        }
    }
    
    if ($failed.Count -gt 0) {
        Write-TestLog "Prerequisites validation failed for: $($failed -join ', ')" -Level 'ERROR'
        return $false
    }
    
    # Install Pester if needed and in CI mode
    if ($CI -and -not $prerequisites.Pester) {
        Write-TestLog "Installing Pester for CI environment..." -Level 'INFO'
        try {
            Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck -Scope CurrentUser
            Import-Module Pester -Force
            Write-TestLog "Pester installed successfully" -Level 'SUCCESS'
        }
        catch {
            Write-TestLog "Failed to install Pester: $($_.Exception.Message)" -Level 'ERROR'
            return $false
        }
    }
    
    Write-TestLog "All prerequisites validated successfully" -Level 'SUCCESS'
    return $true
}

# Function to filter test files based on parameters
function Get-FilteredTestFiles {
    $filteredTests = $script:TestConfig.TestFiles
    
    # Filter by test suite
    switch ($TestSuite) {
        'Installation' {
            $filteredTests = $filteredTests | Where-Object { $_.Category -eq 'Installation' }
        }
        'Setup' {
            $filteredTests = $filteredTests | Where-Object { $_.Category -eq 'Setup' }
        }
        'Platform' {
            $filteredTests = $filteredTests | Where-Object { $_.Category -eq 'Platform' }
        }
        'Performance' {
            $filteredTests = $filteredTests | Where-Object { $_.Tags -contains 'Performance' }
        }
        'Quick' {
            $filteredTests = $filteredTests | Where-Object { $_.EstimatedDuration -le 45 }
        }
        'All' {
            # No filtering - include all tests
        }
    }
    
    # Filter by tags
    if ($Tags.Count -gt 0) {
        $filteredTests = $filteredTests | Where-Object { 
            $testTags = $_.Tags
            $matchingTags = $Tags | Where-Object { $_ -in $testTags }
            $matchingTags.Count -gt 0
        }
    }
    
    # Exclude tags
    if ($ExcludeTags.Count -gt 0) {
        $filteredTests = $filteredTests | Where-Object {
            $testTags = $_.Tags
            $excludedTags = $ExcludeTags | Where-Object { $_ -in $testTags }
            $excludedTags.Count -eq 0
        }
    }
    
    # Validate test files exist
    $existingTests = $filteredTests | Where-Object { Test-Path $_.Path }
    $missingTests = $filteredTests | Where-Object { -not (Test-Path $_.Path) }
    
    if ($missingTests.Count -gt 0) {
        Write-TestLog "Missing test files:" -Level 'WARNING'
        foreach ($missing in $missingTests) {
            Write-TestLog "  - $($missing.Name)" -Level 'WARNING'
        }
    }
    
    return $existingTests
}

# Function to create test configuration
function New-TestConfiguration {
    param([object[]]$TestFiles)
    
    $config = @{
        Path = $TestFiles.Path
        PassThru = $true
        Output = if ($CI) { 'Minimal' } else { $script:TestConfig.ReportFormats[$OutputFormat] }
    }
    
    # Add tags if specified
    if ($Tags.Count -gt 0) {
        $config.Tag = $Tags
    }
    
    if ($ExcludeTags.Count -gt 0) {
        $config.ExcludeTag = $ExcludeTags
    }
    
    # Add report path if specified
    if ($ReportPath) {
        $reportDir = Split-Path $ReportPath -Parent
        if (-not (Test-Path $reportDir)) {
            New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
        }
        
        switch ($OutputFormat) {
            'JSON' {
                $config.Output = 'JUnitXml'
                $config.OutputPath = $ReportPath -replace '\.json$', '.xml'
            }
            'XML' {
                $config.Output = 'JUnitXml'
                $config.OutputPath = $ReportPath
            }
        }
    }
    
    return $config
}

# Function to run tests
function Invoke-InstallationTests {
    param([object[]]$TestFiles)
    
    Write-TestLog "Running $($TestFiles.Count) test file(s)..." -Level 'INFO'
    
    if ($WhatIf) {
        Write-TestLog "WhatIf Mode - Tests that would be run:" -Level 'INFO'
        foreach ($test in $TestFiles) {
            Write-TestLog "  ✓ $($test.Name) - $($test.Description)" -Level 'INFO'
            Write-TestLog "    Category: $($test.Category), Duration: ~$($test.EstimatedDuration)s" -Level 'DEBUG'
            Write-TestLog "    Tags: $($test.Tags -join ', ')" -Level 'DEBUG'
        }
        
        $totalDuration = ($TestFiles | Measure-Object -Property EstimatedDuration -Sum).Sum
        Write-TestLog "Total estimated duration: $totalDuration seconds" -Level 'INFO'
        return @{ TotalCount = $TestFiles.Count; Passed = 0; Failed = 0; Skipped = 0; Duration = [TimeSpan]::Zero }
    }
    
    # Import Pester
    try {
        Import-Module Pester -MinimumVersion 5.0.0 -Force
    }
    catch {
        Write-TestLog "Failed to import Pester: $($_.Exception.Message)" -Level 'ERROR'
        throw
    }
    
    # Create test configuration
    $config = New-TestConfiguration -TestFiles $TestFiles
    
    # Set environment variables for test context
    $env:AITHERZERO_TEST_MODE = $true
    $env:AITHERZERO_TEST_PROFILE = $Profile
    $env:AITHERZERO_TEST_PLATFORM = $Platform
    $env:AITHERZERO_TEST_CI = $CI
    
    try {
        # Run tests with timeout
        $testJob = Start-Job -ScriptBlock {
            param($ConfigObject)
            Import-Module Pester -Force
            Invoke-Pester @ConfigObject
        } -ArgumentList $config
        
        $timeoutReached = $false
        $results = $null
        
        try {
            $results = Wait-Job $testJob -Timeout ($script:TestConfig.TimeoutMinutes * 60) | Receive-Job
        }
        catch {
            $timeoutReached = $true
            Write-TestLog "Test execution timed out after $($script:TestConfig.TimeoutMinutes) minutes" -Level 'ERROR'
        }
        finally {
            Remove-Job $testJob -Force -ErrorAction SilentlyContinue
        }
        
        if ($timeoutReached) {
            return @{ 
                TotalCount = $TestFiles.Count
                Passed = 0
                Failed = $TestFiles.Count
                Skipped = 0
                Duration = [TimeSpan]::FromMinutes($script:TestConfig.TimeoutMinutes)
                TimedOut = $true
            }
        }
        
        return $results
    }
    finally {
        # Clean up environment variables
        Remove-Item Env:AITHERZERO_TEST_MODE -ErrorAction SilentlyContinue
        Remove-Item Env:AITHERZERO_TEST_PROFILE -ErrorAction SilentlyContinue
        Remove-Item Env:AITHERZERO_TEST_PLATFORM -ErrorAction SilentlyContinue
        Remove-Item Env:AITHERZERO_TEST_CI -ErrorAction SilentlyContinue
    }
}

# Function to show test summary
function Show-TestSummary {
    param([object]$Results, [object[]]$TestFiles)
    
    $duration = (Get-Date) - $script:StartTime
    
    Write-Host ""
    if ($CI) {
        Write-Host "Test Summary:" -ForegroundColor White
    } else {
        Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                    Test Summary                          ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
    }
    
    # Overall status
    $overallStatus = if ($Results.Failed -eq 0 -and -not $Results.TimedOut) { 
        '✅ PASSED' 
    } elseif ($Results.TimedOut) {
        '⏰ TIMED OUT'
    } else { 
        '❌ FAILED' 
    }
    
    $statusColor = if ($Results.Failed -eq 0 -and -not $Results.TimedOut) { 'Green' } 
                   elseif ($Results.TimedOut) { 'Yellow' }
                   else { 'Red' }
    
    Write-Host "  Overall Status: $overallStatus" -ForegroundColor $statusColor
    Write-Host "  Test Suite: $TestSuite" -ForegroundColor White
    Write-Host "  Profile: $Profile" -ForegroundColor White
    Write-Host "  Platform: $Platform" -ForegroundColor White
    Write-Host ""
    
    # Test statistics
    Write-Host "  Test Statistics:" -ForegroundColor White
    Write-Host "    Files Executed: $($TestFiles.Count)" -ForegroundColor Cyan
    Write-Host "    Tests Passed: $($Results.Passed)" -ForegroundColor Green
    Write-Host "    Tests Failed: $($Results.Failed)" -ForegroundColor $(if ($Results.Failed -eq 0) { 'Green' } else { 'Red' })
    Write-Host "    Tests Skipped: $($Results.Skipped)" -ForegroundColor Yellow
    Write-Host "    Total Tests: $($Results.TotalCount)" -ForegroundColor White
    Write-Host ""
    
    # Timing information
    $testDuration = if ($Results.Duration) { $Results.Duration } else { [TimeSpan]::Zero }
    Write-Host "  Timing:" -ForegroundColor White
    Write-Host "    Test Execution: $($testDuration.ToString('mm\:ss\.ff'))" -ForegroundColor Cyan
    Write-Host "    Total Duration: $($duration.ToString('mm\:ss\.ff'))" -ForegroundColor Cyan
    Write-Host ""
    
    # Test files executed
    if (-not $CI) {
        Write-Host "  Test Files Executed:" -ForegroundColor White
        foreach ($test in $TestFiles) {
            $icon = "📋"
            Write-Host "    $icon $($test.Name)" -ForegroundColor Gray
            Write-Host "       $($test.Description)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    
    # Platform information
    $currentPlatform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
    Write-Host "  Environment:" -ForegroundColor White
    Write-Host "    Platform: $currentPlatform" -ForegroundColor Cyan
    Write-Host "    PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
    Write-Host "    Architecture: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)" -ForegroundColor Cyan
    
    # Report location
    if ($ReportPath -and (Test-Path $ReportPath)) {
        Write-Host "    Report: $ReportPath" -ForegroundColor Cyan
    }
    
    Write-Host ""
    
    # Recommendations
    if ($Results.Failed -gt 0) {
        Write-Host "  💡 Recommendations:" -ForegroundColor Yellow
        Write-Host "     • Check failed tests for specific issues" -ForegroundColor White
        Write-Host "     • Run with -WhatIf to see test details" -ForegroundColor White
        Write-Host "     • Check prerequisites and dependencies" -ForegroundColor White
        
        if ($TestSuite -eq 'All') {
            Write-Host "     • Try running specific test suites individually" -ForegroundColor White
        }
        
        Write-Host ""
    } elseif ($Results.Failed -eq 0 -and -not $Results.TimedOut) {
        Write-Host "  🎉 All tests passed! Installation & setup validation successful." -ForegroundColor Green
        Write-Host ""
    }
    
    # Next steps
    if ($Results.Failed -eq 0 -and -not $Results.TimedOut) {
        Write-Host "  🚀 Next Steps:" -ForegroundColor Green
        Write-Host "     • Installation and setup are validated" -ForegroundColor White
        Write-Host "     • Run ./Start-AitherZero.ps1 to use the application" -ForegroundColor White
        Write-Host "     • Run ./Start-DeveloperSetup.ps1 for development setup" -ForegroundColor White
        Write-Host ""
    }
}

# Function to handle cleanup
function Invoke-TestCleanup {
    # Clean up any test artifacts
    $testTempDirs = Get-ChildItem $env:TEMP -Directory -Name "*AitherZero*Test*" -ErrorAction SilentlyContinue
    
    foreach ($tempDir in $testTempDirs) {
        $fullPath = Join-Path $env:TEMP $tempDir
        try {
            Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-TestLog "Cleaned up temp directory: $tempDir" -Level 'DEBUG'
        }
        catch {
            Write-TestLog "Failed to clean up temp directory: $tempDir" -Level 'WARNING'
        }
    }
    
    # Force garbage collection
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

# Main execution
function Start-InstallationTestRunner {
    try {
        # Show banner
        Show-TestRunnerBanner
        
        # Validate prerequisites
        if (-not (Test-TestPrerequisites)) {
            Write-TestLog "Prerequisites validation failed. Exiting." -Level 'ERROR'
            exit 1
        }
        
        # Get filtered test files
        $testFiles = Get-FilteredTestFiles
        
        if ($testFiles.Count -eq 0) {
            Write-TestLog "No test files matched the specified criteria" -Level 'WARNING'
            Write-TestLog "TestSuite: $TestSuite, Tags: $($Tags -join ','), ExcludeTags: $($ExcludeTags -join ',')" -Level 'INFO'
            exit 0
        }
        
        Write-TestLog "Found $($testFiles.Count) test file(s) to execute" -Level 'SUCCESS'
        
        # Run tests
        $results = Invoke-InstallationTests -TestFiles $testFiles
        
        # Show summary
        Show-TestSummary -Results $results -TestFiles $testFiles
        
        # Cleanup
        Invoke-TestCleanup
        
        # Exit with appropriate code
        if ($results.Failed -gt 0 -or $results.TimedOut) {
            Write-TestLog "Tests completed with failures" -Level 'ERROR'
            exit 1
        } else {
            Write-TestLog "All tests completed successfully" -Level 'SUCCESS'
            exit 0
        }
        
    }
    catch {
        Write-TestLog "Test runner failed with error: $($_.Exception.Message)" -Level 'ERROR'
        Write-TestLog "Stack trace: $($_.ScriptStackTrace)" -Level 'DEBUG'
        
        # Cleanup on error
        Invoke-TestCleanup
        
        exit 1
    }
}

# Script entry point
if ($MyInvocation.InvocationName -ne '.') {
    # Only run if script is executed directly, not dot-sourced
    Start-InstallationTestRunner
}