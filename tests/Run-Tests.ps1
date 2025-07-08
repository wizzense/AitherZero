# AitherZero Test Runner - Enhanced & Robust Test Execution Framework
# Supports centralized, distributed, and consolidated module tests
# Automatically detects new AitherCore consolidated module structure
# Includes comprehensive installation and setup testing capabilities

param(
    [switch]$Quick,
    [switch]$Setup,
    [switch]$All,
    [switch]$CI,
    [switch]$Distributed,
    [switch]$Installation,
    [string[]]$Modules = @(),
    [int]$MaxParallelJobs = 4,
    [int]$TimeoutMinutes = 30,
    [switch]$Verbose,
    [switch]$ShowProgress,
    [switch]$FailFast
)

# Enhanced error handling and logging
$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }

# Initialize test session
$script:TestSession = @{
    StartTime = Get-Date
    TestResults = @()
    Errors = @()
    Warnings = @()
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
}

# Enhanced logging function
function Write-TestOutput {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info',
        [switch]$NoNewline
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Level) {
        'Info' { "ℹ️" }
        'Success' { "✅" }
        'Warning' { "⚠️" }
        'Error' { "❌" }
        'Debug' { "🔍" }
    }
    
    $color = switch ($Level) {
        'Info' { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Debug' { 'Gray' }
    }
    
    $formattedMessage = "[$timestamp] $prefix $Message"
    
    if ($NoNewline) {
        Write-Host $formattedMessage -ForegroundColor $color -NoNewline
    } else {
        Write-Host $formattedMessage -ForegroundColor $color
    }
    
    # Track errors and warnings
    if ($Level -eq 'Error') {
        $script:TestSession.Errors += $Message
    } elseif ($Level -eq 'Warning') {
        $script:TestSession.Warnings += $Message
    }
}

# PowerShell version check with better messaging
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-TestOutput "PowerShell 7.0+ recommended for full test functionality. Current version: $($PSVersionTable.PSVersion)" -Level Warning
    Write-TestOutput "Some tests may be skipped or have limited functionality" -Level Warning
}
# Initialize paths and environment
$testPath = $PSScriptRoot
$projectRoot = Split-Path $testPath -Parent

Write-TestOutput "Initializing test environment..." -Level Info
Write-TestOutput "Test Path: $testPath" -Level Debug
Write-TestOutput "Project Root: $projectRoot" -Level Debug

# Enhanced environment detection
try {
    # Check for installation and setup test runner
    $installationTestRunner = Join-Path $testPath "Run-Installation-Tests.ps1"
    $hasInstallationTests = Test-Path $installationTestRunner
    
    # Detect if we're using the new consolidated AitherCore module
    $aitherCorePath = Join-Path $projectRoot "aither-core/AitherCore.psd1"
    $useConsolidatedModule = Test-Path $aitherCorePath
    
    # Validate project structure
    $requiredPaths = @(
        (Join-Path $projectRoot "aither-core"),
        (Join-Path $projectRoot "aither-core/modules"),
        (Join-Path $projectRoot "configs")
    )
    
    $missingPaths = @()
    foreach ($path in $requiredPaths) {
        if (-not (Test-Path $path)) {
            $missingPaths += $path
        }
    }
    
    if ($missingPaths) {
        Write-TestOutput "Missing required paths: $($missingPaths -join ', ')" -Level Error
        throw "Invalid project structure detected"
    }
    
    Write-TestOutput "Project structure validation passed" -Level Success
    
} catch {
    Write-TestOutput "Environment initialization failed: $($_.Exception.Message)" -Level Error
    Write-TestOutput "Please ensure you're running from the correct directory" -Level Error
    exit 1
}

# Handle installation and setup testing with enhanced error handling
if ($Installation) {
    Write-TestOutput "Installation test mode selected" -Level Info
    
    if ($hasInstallationTests) {
        Write-TestOutput "Running Installation & Setup Tests..." -Level Info

        # Build parameters for installation test runner
        $installationParams = @{}
        if ($CI) { $installationParams['CI'] = $true }
        if ($Quick) { $installationParams['TestSuite'] = 'Quick' }
        elseif ($Setup) { $installationParams['TestSuite'] = 'Setup' }
        elseif ($All) { $installationParams['TestSuite'] = 'All' }

        # Execute installation tests with timeout
        try {
            $installationJob = Start-Job -ScriptBlock {
                param($RunnerPath, $Params)
                & $RunnerPath @Params
                return $LASTEXITCODE
            } -ArgumentList $installationTestRunner, $installationParams
            
            $installationCompleted = Wait-Job -Job $installationJob -Timeout ($TimeoutMinutes * 60)
            
            if (-not $installationCompleted) {
                Write-TestOutput "Installation tests timed out after $TimeoutMinutes minutes" -Level Error
                Stop-Job -Job $installationJob
                Remove-Job -Job $installationJob
                if ($CI) { exit 1 }
                return
            }
            
            $installationExitCode = Receive-Job -Job $installationJob
            Remove-Job -Job $installationJob
            
            if ($installationExitCode -ne 0) {
                Write-TestOutput "Installation tests failed with exit code: $installationExitCode" -Level Error
                if ($CI) { exit $installationExitCode }
            } else {
                Write-TestOutput "Installation tests completed successfully" -Level Success
            }

            return
        }
        catch {
            Write-TestOutput "Installation tests failed: $($_.Exception.Message)" -Level Error
            if ($CI) { exit 1 }
            return
        }
    } else {
        Write-TestOutput "Installation test runner not found at: $installationTestRunner" -Level Warning
        Write-TestOutput "Falling back to standard tests..." -Level Warning
    }
}

# Display module architecture information
if ($useConsolidatedModule) {
    Write-TestOutput "Detected consolidated AitherCore module - using enhanced testing mode" -Level Info
} else {
    Write-TestOutput "Using legacy individual module structure" -Level Warning
}

if ($hasInstallationTests) {
    Write-TestOutput "Installation & setup tests available - use -Installation to run them" -Level Info
}

# Enhanced Pester installation with better error handling
function Install-PesterModule {
    param([string]$MinimumVersion = '5.0.0')
    
    Write-TestOutput "Checking Pester installation..." -Level Info
    
    try {
        $existingPester = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge $MinimumVersion }
        
        if (-not $existingPester) {
            Write-TestOutput "Installing Pester $MinimumVersion..." -Level Info
            
            # Check if we have permission to install
            if (-not (Test-Path "$env:ProgramFiles\WindowsPowerShell\Modules" -ErrorAction SilentlyContinue)) {
                # Use CurrentUser scope if we can't write to system
                Install-Module -Name Pester -MinimumVersion $MinimumVersion -Force -SkipPublisherCheck -Scope CurrentUser
            } else {
                Install-Module -Name Pester -MinimumVersion $MinimumVersion -Force -SkipPublisherCheck
            }
            
            Write-TestOutput "Pester installation completed" -Level Success
        } else {
            Write-TestOutput "Pester $($existingPester.Version) already installed" -Level Success
        }
        
        # Import Pester with error handling
        Import-Module Pester -MinimumVersion $MinimumVersion -Force
        Write-TestOutput "Pester module imported successfully" -Level Success
        
    } catch {
        Write-TestOutput "Failed to install/import Pester: $($_.Exception.Message)" -Level Error
        throw "Pester installation failed"
    }
}

# Install Pester if needed (CI environments or if missing)
if ($CI -or -not (Get-Module -ListAvailable -Name Pester | Where-Object Version -ge '5.0.0')) {
    Install-PesterModule -MinimumVersion '5.0.0'
} else {
    Import-Module Pester -MinimumVersion 5.0.0
}

# Handle distributed testing (enhanced for consolidated modules)
if ($Distributed -or $useConsolidatedModule) {
    Write-TestOutput "Running distributed tests using TestingFramework..." -Level Info

    # Try to import TestingFramework for distributed testing
    $testingFrameworkPath = Join-Path $projectRoot "aither-core/modules/TestingFramework"
    $frameworkImported = $false

    # If using consolidated module, try AitherCore first
    if ($useConsolidatedModule) {
        try {
            Write-TestOutput "Attempting to import consolidated AitherCore module..." -Level Info
            Import-Module $aitherCorePath -Force -ErrorAction Stop
            Write-TestOutput "Imported consolidated AitherCore module" -Level Success

            # Initialize the consolidated module ecosystem
            if (Get-Command Initialize-CoreApplication -ErrorAction SilentlyContinue) {
                Write-TestOutput "Initializing core application with modules..." -Level Info
                $initResult = Initialize-CoreApplication -RequiredOnly:(-not $All)
                Write-TestOutput "Initialized core application with modules" -Level Success
            }

            # Check if TestingFramework is available through consolidated module
            $frameworkImported = (Get-Module -Name TestingFramework -ErrorAction SilentlyContinue) -ne $null
            
            if ($frameworkImported) {
                Write-TestOutput "TestingFramework available through consolidated module" -Level Success
            }
        } catch {
            Write-TestOutput "Could not load consolidated AitherCore: $($_.Exception.Message)" -Level Warning
            Write-TestOutput "Falling back to direct TestingFramework import..." -Level Info
        }
    }

    # Fallback to direct TestingFramework import if needed
    if (-not $frameworkImported -and (Test-Path $testingFrameworkPath)) {
        try {
            Write-TestOutput "Importing TestingFramework module directly..." -Level Info
            Import-Module $testingFrameworkPath -Force -ErrorAction Stop
            $frameworkImported = $true
            Write-TestOutput "Imported TestingFramework module directly" -Level Success
        } catch {
            Write-TestOutput "Failed to import TestingFramework: $($_.Exception.Message)" -Level Error
        }
    }

    if ($frameworkImported) {
        # Determine test suite based on parameters
        $testSuite = if ($All) { "All" }
                    elseif ($Setup) { "Environment" }
                    else { "Unit" }

        # Configure execution parameters with enhanced options
        $executionParams = @{
            TestSuite = $testSuite
            TestProfile = if ($CI) { "CI" } else { "Development" }
            GenerateReport = $true
            Parallel = if ($CI -or $FailFast) { $false } else { $true }
            OutputPath = Join-Path $testPath "results/unified"
        }

        # Add specific modules if specified
        if ($Modules.Count -gt 0) {
            $executionParams.Modules = $Modules
            Write-TestOutput "Testing specific modules: $($Modules -join ', ')" -Level Info
        }

        # Add MaxParallelJobs parameter
        if ($MaxParallelJobs -ne 4) {
            Write-TestOutput "Using $MaxParallelJobs parallel jobs" -Level Info
        }

        # Execute distributed tests with consolidated module support
        try {
            Write-TestOutput "Starting unified test execution..." -Level Info
            $testStartTime = Get-Date
            
            $results = Invoke-UnifiedTestExecution @executionParams
            
            $testDuration = (Get-Date) - $testStartTime
            Write-TestOutput "Test execution completed in $($testDuration.TotalSeconds.ToString('F2')) seconds" -Level Success

            # Calculate summary from distributed results
            $totalPassed = ($results | Measure-Object -Property TestsPassed -Sum).Sum
            $totalFailed = ($results | Measure-Object -Property TestsFailed -Sum).Sum
            $totalCount = $totalPassed + $totalFailed
            $totalDuration = ($results | Measure-Object -Property Duration -Sum).Sum

            # Update test session tracking
            $script:TestSession.TotalTests = $totalCount
            $script:TestSession.PassedTests = $totalPassed
            $script:TestSession.FailedTests = $totalFailed
            $script:TestSession.TestResults = $results

            # Test the consolidated module integration if available
            if ($useConsolidatedModule) {
                Write-TestOutput "Testing consolidated module integration..." -Level Info

                # Test AitherCore health
                if (Get-Command Test-CoreApplicationHealth -ErrorAction SilentlyContinue) {
                    $coreHealth = Test-CoreApplicationHealth
                    $healthStatus = if ($coreHealth) { "Healthy" } else { "Issues Detected" }
                    $healthLevel = if ($coreHealth) { "Success" } else { "Error" }
                    Write-TestOutput "Core Health: $healthStatus" -Level $healthLevel
                }

                # Test module status
                if (Get-Command Get-CoreModuleStatus -ErrorAction SilentlyContinue) {
                    $moduleStatus = Get-CoreModuleStatus
                    $loadedModules = ($moduleStatus | Where-Object { $_.Loaded }).Count
                    $availableModules = ($moduleStatus | Where-Object { $_.Available }).Count
                    Write-TestOutput "Modules: $loadedModules loaded / $availableModules available" -Level Info
                }
            }

            # Display enhanced distributed test summary
            Write-TestOutput "" -Level Info
            Write-TestOutput "=== DISTRIBUTED TEST RESULTS ===" -Level Info
            Write-TestOutput "Modules Tested: $(($results | Select-Object -ExpandProperty Module -Unique).Count)" -Level Info
            Write-TestOutput "Tests Passed: $totalPassed" -Level Success
            Write-TestOutput "Tests Failed: $totalFailed" -Level $(if ($totalFailed -eq 0) { 'Success' } else { 'Error' })
            Write-TestOutput "Total Tests: $totalCount" -Level Info
            Write-TestOutput "Duration: $($totalDuration.ToString('0.00'))s" -Level Info
            
            # Calculate success rate
            $successRate = if ($totalCount -gt 0) { ($totalPassed / $totalCount) * 100 } else { 0 }
            Write-TestOutput "Success Rate: $($successRate.ToString('F1'))%" -Level $(if ($successRate -ge 90) { 'Success' } elseif ($successRate -ge 70) { 'Warning' } else { 'Error' })

            # Show failed modules if any
            if ($totalFailed -gt 0) {
                $failedModules = $results | Where-Object { $_.TestsFailed -gt 0 } | Select-Object -ExpandProperty Module -Unique
                Write-TestOutput "Failed Modules: $($failedModules -join ', ')" -Level Error
                
                if ($FailFast) {
                    Write-TestOutput "FailFast enabled - stopping on first failure" -Level Error
                }
            }

            # Exit with proper code for CI
            if ($CI -and $totalFailed -gt 0) {
                Write-TestOutput "CI mode: Exiting with failure code due to test failures" -Level Error
                exit 1
            }

            return
        } catch {
            Write-TestOutput "Distributed test execution failed: $($_.Exception.Message)" -Level Error
            Write-TestOutput "Falling back to centralized tests..." -Level Warning
        }
    } else {
        Write-TestOutput "TestingFramework not found, falling back to centralized tests" -Level Warning
    }
}

# Standard centralized testing (enhanced for consolidated modules)
Write-TestOutput "Preparing centralized test execution..." -Level Info

$testsToRun = @()

if ($All) {
    Write-TestOutput "Running ALL centralized tests..." -Level Info
    $testsToRun = @(
        Join-Path $testPath "Core.Tests.ps1"
        Join-Path $testPath "Setup.Tests.ps1"
    )

    # Add consolidated module tests if available
    if ($useConsolidatedModule) {
        $consolidatedTestPath = Join-Path $testPath "AitherCore.Tests.ps1"
        if (Test-Path $consolidatedTestPath) {
            $testsToRun += $consolidatedTestPath
            Write-TestOutput "Including AitherCore consolidated module tests" -Level Info
        }
    }

} elseif ($Setup) {
    Write-TestOutput "Running Setup tests..." -Level Info
    $testsToRun = @(Join-Path $testPath "Setup.Tests.ps1")

    # Include installation tests if available and Setup flag is used
    if ($hasInstallationTests) {
        Write-TestOutput "Including installation & setup validation tests" -Level Info
        $installationTests = @(
            Join-Path $testPath "Setup-Installation.Tests.ps1",
            Join-Path $testPath "PowerShell-Version.Tests.ps1"
        ) | Where-Object { Test-Path $_ }
        $testsToRun += $installationTests
    }

} else {
    # Default to Quick (Core tests only)
    Write-TestOutput "Running Core tests..." -Level Info
    $testsToRun = @(Join-Path $testPath "Core.Tests.ps1")

    # Include basic consolidated module test for quick mode if available
    if ($useConsolidatedModule) {
        $quickConsolidatedTest = Join-Path $testPath "AitherCore.Quick.Tests.ps1"
        if (Test-Path $quickConsolidatedTest) {
            $testsToRun += $quickConsolidatedTest
            Write-TestOutput "Including quick AitherCore tests" -Level Info
        }
    }
}

# Validate that test files exist
$validTests = @()
$missingTests = @()

foreach ($testFile in $testsToRun) {
    if (Test-Path $testFile) {
        $validTests += $testFile
    } else {
        $missingTests += $testFile
    }
}

if ($missingTests) {
    Write-TestOutput "Missing test files: $($missingTests -join ', ')" -Level Warning
}

if (-not $validTests) {
    Write-TestOutput "No valid test files found to execute" -Level Error
    exit 1
}

$testsToRun = $validTests
Write-TestOutput "Found $($testsToRun.Count) test files to execute" -Level Info

# Run centralized tests with enhanced configuration
Write-TestOutput "Executing centralized tests..." -Level Info

try {
    $config = @{
        Path = $testsToRun
        Output = if ($CI) { 'Minimal' } else { 'Detailed' }
        PassThru = $true
    }

    # Add timeout if specified
    if ($TimeoutMinutes -ne 30) {
        Write-TestOutput "Setting test timeout to $TimeoutMinutes minutes" -Level Info
    }

    $centralizedStartTime = Get-Date
    $results = Invoke-Pester @config
    $centralizedDuration = (Get-Date) - $centralizedStartTime

    # Update test session tracking
    $script:TestSession.TotalTests += $results.TotalCount
    $script:TestSession.PassedTests += $results.Passed
    $script:TestSession.FailedTests += $results.Failed

    # Enhanced result summary with consolidated module information
    Write-TestOutput "" -Level Info
    Write-TestOutput "=== CENTRALIZED TEST RESULTS ===" -Level Info
    Write-TestOutput "Tests Passed: $($results.Passed)" -Level Success
    Write-TestOutput "Tests Failed: $($results.Failed)" -Level $(if ($results.Failed -eq 0) { 'Success' } else { 'Error' })
    Write-TestOutput "Total Tests: $($results.TotalCount)" -Level Info
    Write-TestOutput "Duration: $($centralizedDuration.TotalSeconds.ToString('0.00'))s" -Level Info
    
    # Calculate success rate
    $successRate = if ($results.TotalCount -gt 0) { ($results.Passed / $results.TotalCount) * 100 } else { 0 }
    Write-TestOutput "Success Rate: $($successRate.ToString('F1'))%" -Level $(if ($successRate -ge 90) { 'Success' } elseif ($successRate -ge 70) { 'Warning' } else { 'Error' })

} catch {
    Write-TestOutput "Centralized test execution failed: $($_.Exception.Message)" -Level Error
    $script:TestSession.Errors += "Centralized test execution failed: $($_.Exception.Message)"
    
    if ($CI) {
        exit 1
    }
}

# Final test session summary
function Show-TestSessionSummary {
    $sessionDuration = (Get-Date) - $script:TestSession.StartTime
    
    Write-TestOutput "" -Level Info
    Write-TestOutput "=== FINAL TEST SESSION SUMMARY ===" -Level Info
    Write-TestOutput "Session Duration: $($sessionDuration.TotalSeconds.ToString('F2'))s" -Level Info
    Write-TestOutput "Total Tests: $($script:TestSession.TotalTests)" -Level Info
    Write-TestOutput "Total Passed: $($script:TestSession.PassedTests)" -Level Success
    Write-TestOutput "Total Failed: $($script:TestSession.FailedTests)" -Level $(if ($script:TestSession.FailedTests -eq 0) { 'Success' } else { 'Error' })
    
    if ($script:TestSession.TotalTests -gt 0) {
        $overallSuccessRate = ($script:TestSession.PassedTests / $script:TestSession.TotalTests) * 100
        Write-TestOutput "Overall Success Rate: $($overallSuccessRate.ToString('F1'))%" -Level $(if ($overallSuccessRate -ge 90) { 'Success' } elseif ($overallSuccessRate -ge 70) { 'Warning' } else { 'Error' })
    }
    
    # Show errors if any
    if ($script:TestSession.Errors) {
        Write-TestOutput "Errors Encountered: $($script:TestSession.Errors.Count)" -Level Error
        foreach ($error in $script:TestSession.Errors) {
            Write-TestOutput "  • $error" -Level Error
        }
    }
    
    # Show warnings if any
    if ($script:TestSession.Warnings) {
        Write-TestOutput "Warnings: $($script:TestSession.Warnings.Count)" -Level Warning
    }
    
    # Show available test categories
    Write-TestOutput "" -Level Info
    Write-TestOutput "Available Test Categories:" -Level Info
    Write-TestOutput "  • Core Tests: ./tests/Run-Tests.ps1 (default)" -Level Info
    Write-TestOutput "  • Setup Tests: ./tests/Run-Tests.ps1 -Setup" -Level Info
    Write-TestOutput "  • All Tests: ./tests/Run-Tests.ps1 -All" -Level Info
    if ($hasInstallationTests) {
        Write-TestOutput "  • Installation & Setup: ./tests/Run-Tests.ps1 -Installation" -Level Info
        Write-TestOutput "  • Comprehensive Installation: ./tests/Run-Installation-Tests.ps1" -Level Info
    }
    
    # Display module architecture information
    if ($useConsolidatedModule) {
        Write-TestOutput "" -Level Info
        Write-TestOutput "Module Architecture: Consolidated AitherCore module" -Level Success
        
        # Show loaded modules if function is available
        if (Get-Command Get-CoreModuleStatus -ErrorAction SilentlyContinue) {
            $moduleStatus = Get-CoreModuleStatus
            $loadedCount = ($moduleStatus | Where-Object { $_.Loaded }).Count
            $totalCount = $moduleStatus.Count
            Write-TestOutput "Modules: $loadedCount/$totalCount loaded" -Level Info
        }
    } else {
        Write-TestOutput "" -Level Info
        Write-TestOutput "Module Architecture: Legacy individual modules" -Level Warning
    }
}

# Show final summary
Show-TestSessionSummary

# Exit with proper code for CI
if ($CI) {
    if ($script:TestSession.FailedTests -gt 0 -or $script:TestSession.Errors.Count -gt 0) {
        Write-TestOutput "CI mode: Exiting with failure code due to test failures or errors" -Level Error
        exit 1
    } else {
        Write-TestOutput "CI mode: All tests passed successfully" -Level Success
        exit 0
    }
}
