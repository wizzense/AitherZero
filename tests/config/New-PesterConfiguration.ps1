# Dynamic Pester Configuration Generator
# Creates Pester configuration with proper cross-platform paths

param(
    [string]$OutputPath,
    [string[]]$TestPaths,
    [string[]]$CoveragePaths,
    [switch]$BulletproofMode
)

# Find project root
. "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Default test paths relative to project root
if (-not $TestPaths) {
    $TestPaths = @(
        Join-Path $projectRoot 'tests' 'unit',
        Join-Path $projectRoot 'tests' 'integration',
        Join-Path $projectRoot 'tests' 'pester',
        Join-Path $projectRoot 'tests' 'unit' 'modules' 'CoreApp' 'NonInteractiveMode.Tests.ps1',
        Join-Path $projectRoot 'tests' 'unit' 'modules' 'CoreApp' 'BulletproofCoreRunner.Tests.ps1'
    )
}

# Default coverage paths relative to project root
if (-not $CoveragePaths) {
    $CoveragePaths = @(
        Join-Path $projectRoot 'aither-core' '*.ps1',
        Join-Path $projectRoot 'aither-core' '*.psm1',
        Join-Path $projectRoot 'aither-core' 'modules' '*' '*.ps1',
        Join-Path $projectRoot 'aither-core' 'modules' '*' '*.psm1',
        Join-Path $projectRoot 'aither-core' 'shared' '*.ps1'
    )
}

# Default output paths
if (-not $OutputPath) {
    $resultsPath = Join-Path $projectRoot 'tests' 'results'
    if (-not (Test-Path $resultsPath)) {
        New-Item -ItemType Directory -Path $resultsPath -Force | Out-Null
    }
    $testResultsPath = Join-Path $resultsPath 'TestResults.xml'
    $coverageResultsPath = Join-Path $resultsPath 'coverage.xml'
} else {
    $testResultsPath = $OutputPath
    $coverageResultsPath = [System.IO.Path]::ChangeExtension($OutputPath, '.coverage.xml')
}

# Create configuration hashtable
$config = @{
    Run = @{
        Path = $TestPaths
        Exit = $false
        PassThru = $true
        Throw = $false
    }

    Filter = @{
        ExcludeTag = @('Slow', 'E2E')
        Tag = @('Unit', 'Integration', 'Bulletproof', 'CoreApp', 'NonInteractive')
    }

    Output = @{
        Verbosity = 'Detailed'
        CIFormat = 'Auto'
        StackTraceVerbosity = 'Full'
    }

    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = $testResultsPath
        TestSuiteName = 'AitherZero Infrastructure Automation - Enhanced'
        OutputEncoding = 'UTF8'
    }

    CodeCoverage = @{
        Enabled = $true
        Path = $CoveragePaths
        ExcludeTests = $true
        RecursePaths = $true
        CoveragePercentTarget = 80
        OutputFormat = 'JaCoCo'
        OutputPath = $coverageResultsPath
        OutputEncoding = 'UTF8'
        UseBreakpoints = $false
        SingleHitBreakpoints = $true
    }

    Should = @{
        ErrorAction = 'Stop'
    }

    Debug = @{
        ShowFullErrors = $true
        WriteDebugMessages = $true
        WriteDebugMessagesFrom = @('Bulletproof', 'CoreApp', 'NonInteractive')
        ReturnRawResultObject = $true
        WriteVSCodeMarker = $true
    }

    Custom = @{
        BulletproofMode = $BulletproofMode.IsPresent
        NonInteractiveValidation = $true
        ExitCodeTesting = $true
        LogFileValidation = $true
        PerformanceBenchmarks = $true
        CoverageThresholds = @{
            Functions = 80
            Lines = 75
            Commands = 70
        }
        AdditionalCoverageFormats = @('CoverageGutters', 'Cobertura')
    }
}

return $config