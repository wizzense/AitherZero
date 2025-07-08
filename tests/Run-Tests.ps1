# Note: Tests work best with PowerShell 7.0+ but will attempt to run on older versions

param(
    [switch]$Quick,
    [switch]$Setup,
    [switch]$All,
    [switch]$CI,
    [switch]$Distributed,
    [switch]$Installation,
    [string[]]$Modules = @()
)

# Enhanced test runner - supports centralized, distributed, and consolidated module tests
# Automatically detects new AitherCore consolidated module structure
# Includes comprehensive installation and setup testing capabilities

# Warn if not on PS7+
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "Some tests require PowerShell 7.0+. They will be skipped on version $($PSVersionTable.PSVersion)"
}

$ErrorActionPreference = 'Stop'
$testPath = $PSScriptRoot
$projectRoot = Split-Path $testPath -Parent

# Check for installation and setup test runner
$installationTestRunner = Join-Path $testPath "Run-Installation-Tests.ps1"
$hasInstallationTests = Test-Path $installationTestRunner

# Detect if we're using the new consolidated AitherCore module
$aitherCorePath = Join-Path $projectRoot "aither-core/AitherCore.psd1"
$useConsolidatedModule = Test-Path $aitherCorePath

# Handle installation and setup testing
if ($Installation) {
    if ($hasInstallationTests) {
        Write-Host "🔧 Running Installation & Setup Tests..." -ForegroundColor Cyan

        # Build parameters for installation test runner
        $installationParams = @{}
        if ($CI) { $installationParams['CI'] = $true }
        if ($Quick) { $installationParams['TestSuite'] = 'Quick' }
        elseif ($Setup) { $installationParams['TestSuite'] = 'Setup' }
        elseif ($All) { $installationParams['TestSuite'] = 'All' }

        # Execute installation tests
        try {
            & $installationTestRunner @installationParams
            $installationExitCode = $LASTEXITCODE

            if ($CI -and $installationExitCode -ne 0) {
                exit $installationExitCode
            }

            return
        }
        catch {
            Write-Host "❌ Installation tests failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($CI) { exit 1 }
            return
        }
    } else {
        Write-Host "⚠️  Installation test runner not found at: $installationTestRunner" -ForegroundColor Yellow
        Write-Host "   Falling back to standard tests..." -ForegroundColor Yellow
    }
}

if ($useConsolidatedModule) {
    Write-Host "🔄 Detected consolidated AitherCore module - using enhanced testing mode" -ForegroundColor Cyan
} else {
    Write-Host "📦 Using legacy individual module structure" -ForegroundColor Yellow
}

if ($hasInstallationTests) {
    Write-Host "🔧 Installation & setup tests available - use -Installation to run them" -ForegroundColor Green
}

# Install Pester if needed (CI environments)
if ($CI -and -not (Get-Module -ListAvailable -Name Pester | Where-Object Version -ge '5.0.0')) {
    Write-Host "Installing Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
}

# Import Pester
Import-Module Pester -MinimumVersion 5.0.0

# Handle distributed testing (enhanced for consolidated modules)
if ($Distributed -or $useConsolidatedModule) {
    Write-Host "Running distributed tests using TestingFramework..." -ForegroundColor Cyan

    # Try to import TestingFramework for distributed testing
    $testingFrameworkPath = Join-Path $projectRoot "aither-core/modules/TestingFramework"
    $frameworkImported = $false

    # If using consolidated module, try AitherCore first
    if ($useConsolidatedModule) {
        try {
            Import-Module $aitherCorePath -Force -ErrorAction Stop
            Write-Host "✅ Imported consolidated AitherCore module" -ForegroundColor Green

            # Initialize the consolidated module ecosystem
            if (Get-Command Initialize-CoreApplication -ErrorAction SilentlyContinue) {
                $initResult = Initialize-CoreApplication -RequiredOnly:(-not $All)
                Write-Host "📡 Initialized core application with modules" -ForegroundColor Cyan
            }

            # Check if TestingFramework is available through consolidated module
            $frameworkImported = (Get-Module -Name TestingFramework -ErrorAction SilentlyContinue) -ne $null
        } catch {
            Write-Host "⚠️  Could not load consolidated AitherCore: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # Fallback to direct TestingFramework import if needed
    if (-not $frameworkImported -and (Test-Path $testingFrameworkPath)) {
        try {
            Import-Module $testingFrameworkPath -Force -ErrorAction Stop
            $frameworkImported = $true
            Write-Host "📦 Imported TestingFramework module directly" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to import TestingFramework: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if ($frameworkImported) {
        # Determine test suite based on parameters
        $testSuite = if ($All) { "All" }
                    elseif ($Setup) { "Environment" }
                    else { "Unit" }

        # Configure execution parameters
        $executionParams = @{
            TestSuite = $testSuite
            TestProfile = if ($CI) { "CI" } else { "Development" }
            GenerateReport = $true
            Parallel = -not $CI  # Use parallel for non-CI runs
        }

        # Add specific modules if specified
        if ($Modules.Count -gt 0) {
            $executionParams.Modules = $Modules
            Write-Host "Testing specific modules: $($Modules -join ', ')" -ForegroundColor Yellow
        }

        # Execute distributed tests with consolidated module support
        try {
            $results = Invoke-UnifiedTestExecution @executionParams

            # Calculate summary from distributed results
            $totalPassed = ($results | Measure-Object -Property TestsPassed -Sum).Sum
            $totalFailed = ($results | Measure-Object -Property TestsFailed -Sum).Sum
            $totalCount = $totalPassed + $totalFailed
            $totalDuration = ($results | Measure-Object -Property Duration -Sum).Sum

            # Test the consolidated module integration if available
            if ($useConsolidatedModule) {
                Write-Host "🔧 Testing consolidated module integration..." -ForegroundColor Cyan

                # Test AitherCore health
                if (Get-Command Test-CoreApplicationHealth -ErrorAction SilentlyContinue) {
                    $coreHealth = Test-CoreApplicationHealth
                    Write-Host "  Core Health: $(if ($coreHealth) { '✅ Healthy' } else { '❌ Issues' })" -ForegroundColor $(if ($coreHealth) { 'Green' } else { 'Red' })
                }

                # Test module status
                if (Get-Command Get-CoreModuleStatus -ErrorAction SilentlyContinue) {
                    $moduleStatus = Get-CoreModuleStatus
                    $loadedModules = ($moduleStatus | Where-Object { $_.Loaded }).Count
                    $availableModules = ($moduleStatus | Where-Object { $_.Available }).Count
                    Write-Host "  Modules: $loadedModules loaded / $availableModules available" -ForegroundColor Cyan
                }
            }

        # Display distributed test summary
        Write-Host "`nDistributed Test Results:" -ForegroundColor White
        Write-Host "  Modules Tested: $(($results | Select-Object -ExpandProperty Module -Unique).Count)" -ForegroundColor Cyan
        Write-Host "  Passed: $totalPassed " -ForegroundColor Green
        Write-Host "  Failed: $totalFailed " -ForegroundColor $(if ($totalFailed -eq 0) { 'Green' } else { 'Red' })
        Write-Host "  Total:  $totalCount" -ForegroundColor White
        Write-Host "  Time:   $($totalDuration.ToString('0.00'))s" -ForegroundColor Cyan

        # Exit with proper code for CI
        if ($CI -and $totalFailed -gt 0) {
            exit 1
        }

            return
        } catch {
            Write-Host "❌ Distributed test execution failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Falling back to centralized tests..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️  TestingFramework not found, falling back to centralized tests" -ForegroundColor Yellow
    }
}

# Standard centralized testing (enhanced for consolidated modules)
$testsToRun = @()

if ($All) {
    Write-Host "Running ALL centralized tests..." -ForegroundColor Cyan
    $testsToRun = @(
        Join-Path $testPath "Core.Tests.ps1"
        Join-Path $testPath "Setup.Tests.ps1"
    )

    # Add consolidated module tests if available
    if ($useConsolidatedModule) {
        $consolidatedTestPath = Join-Path $testPath "AitherCore.Tests.ps1"
        if (Test-Path $consolidatedTestPath) {
            $testsToRun += $consolidatedTestPath
            Write-Host "  📦 Including AitherCore consolidated module tests" -ForegroundColor Green
        }
    }

} elseif ($Setup) {
    Write-Host "Running Setup tests..." -ForegroundColor Cyan
    $testsToRun = @(Join-Path $testPath "Setup.Tests.ps1")

    # Include installation tests if available and Setup flag is used
    if ($hasInstallationTests) {
        Write-Host "  🔧 Including installation & setup validation tests" -ForegroundColor Green
        $installationTests = @(
            Join-Path $testPath "Setup-Installation.Tests.ps1",
            Join-Path $testPath "PowerShell-Version.Tests.ps1"
        ) | Where-Object { Test-Path $_ }
        $testsToRun += $installationTests
    }

} else {
    # Default to Quick (Core tests only)
    Write-Host "Running Core tests..." -ForegroundColor Cyan
    $testsToRun = @(Join-Path $testPath "Core.Tests.ps1")

    # Include basic consolidated module test for quick mode if available
    if ($useConsolidatedModule) {
        $quickConsolidatedTest = Join-Path $testPath "AitherCore.Quick.Tests.ps1"
        if (Test-Path $quickConsolidatedTest) {
            $testsToRun += $quickConsolidatedTest
            Write-Host "  ⚡ Including quick AitherCore tests" -ForegroundColor Green
        }
    }
}

# Run centralized tests
$config = @{
    Path = $testsToRun
    Output = 'Detailed'
    PassThru = $true
}

if ($CI) {
    $config.Output = 'Minimal'
}

$results = Invoke-Pester @config

# Enhanced result summary with consolidated module information
Write-Host "`nCentralized Test Results:" -ForegroundColor White
Write-Host "  Passed: $($results.Passed) " -ForegroundColor Green
Write-Host "  Failed: $($results.Failed) " -ForegroundColor $(if ($results.Failed -eq 0) { 'Green' } else { 'Red' })
Write-Host "  Total:  $($results.TotalCount)" -ForegroundColor White
Write-Host "  Time:   $($results.Duration.TotalSeconds.ToString('0.00'))s" -ForegroundColor Cyan

# Show available test categories
Write-Host "`n📋 Available Test Categories:" -ForegroundColor White
Write-Host "  • Core Tests: ./tests/Run-Tests.ps1 (default)" -ForegroundColor Gray
Write-Host "  • Setup Tests: ./tests/Run-Tests.ps1 -Setup" -ForegroundColor Gray
Write-Host "  • All Tests: ./tests/Run-Tests.ps1 -All" -ForegroundColor Gray
if ($hasInstallationTests) {
    Write-Host "  • Installation & Setup: ./tests/Run-Tests.ps1 -Installation" -ForegroundColor Green
    Write-Host "  • Comprehensive Installation: ./tests/Run-Installation-Tests.ps1" -ForegroundColor Green
}

# Display module architecture information
if ($useConsolidatedModule) {
    Write-Host "`n📦 Module Architecture:" -ForegroundColor White
    Write-Host "  Using: Consolidated AitherCore module" -ForegroundColor Green

    # Show loaded modules if function is available
    if (Get-Command Get-CoreModuleStatus -ErrorAction SilentlyContinue) {
        $moduleStatus = Get-CoreModuleStatus
        $loadedCount = ($moduleStatus | Where-Object { $_.Loaded }).Count
        $totalCount = $moduleStatus.Count
        Write-Host "  Modules: $loadedCount/$totalCount loaded" -ForegroundColor Cyan
    }
} else {
    Write-Host "`n📦 Module Architecture:" -ForegroundColor White
    Write-Host "  Using: Legacy individual modules" -ForegroundColor Yellow
}

# Exit with proper code for CI
if ($CI) {
    # Ensure we have valid results object
    if ($null -eq $results) {
        Write-Error "Test execution failed - no results returned"
        exit 1
    }

    # Check for failures
    $failureCount = if ($null -ne $results.Failed) { $results.Failed } else { 0 }
    if ($failureCount -gt 0) {
        exit 1
    }
}
