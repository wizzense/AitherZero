#Requires -Version 7.0
# Stage: Validation
# Dependencies: PSScriptAnalyzer, Pester
# Description: Generate test coverage reports and baseline tests

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [hashtable]$Configuration
)

# Initialize logging
$script:LoggingAvailable = $false
try {
    $loggingPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/core/Logging.psm1"
    if (Test-Path $loggingPath) {
        Import-Module $loggingPath -Force -Global
        $script:LoggingAvailable = $true
    }
} catch {
    # Fallback to basic output
}

function Write-ScriptLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $prefix = switch ($Level) {
            'Error' { 'ERROR' }
            'Warning' { 'WARN' }
            'Debug' { 'DEBUG' }
            default { 'INFO' }
        }
        Write-Host "[$timestamp] [$prefix] $Message"
    }
}

Write-ScriptLog "Starting test coverage generation"

try {
    # Get configuration
    $config = if ($Configuration) { $Configuration } else { @{} }

    # Check if test generation is enabled
    $shouldGenerate = $false
    $testConfig = @{
        TargetCoverage = 80
        OutputPath = Join-Path (Split-Path $PSScriptRoot -Parent) "tests/generated"
        IncludeModules = @()
        ExcludeModules = @()
        GenerateBaseline = $true
        RunCoverageAnalysis = $true
    }

    if ($config.Testing -and $config.Testing.CoverageGeneration) {
        $coverageConfig = $config.Testing.CoverageGeneration
        $shouldGenerate = $coverageConfig.Enable -eq $true

        # Override defaults with config
        if ($coverageConfig.TargetCoverage) { $testConfig.TargetCoverage = $coverageConfig.TargetCoverage }
        if ($coverageConfig.OutputPath) { $testConfig.OutputPath = [System.Environment]::ExpandEnvironmentVariables($coverageConfig.OutputPath) }
        if ($coverageConfig.IncludeModules) { $testConfig.IncludeModules = $coverageConfig.IncludeModules }
        if ($coverageConfig.ExcludeModules) { $testConfig.ExcludeModules = $coverageConfig.ExcludeModules }
        if ($null -ne $coverageConfig.GenerateBaseline) { $testConfig.GenerateBaseline = $coverageConfig.GenerateBaseline }
        if ($null -ne $coverageConfig.RunCoverageAnalysis) { $testConfig.RunCoverageAnalysis = $coverageConfig.RunCoverageAnalysis }
    }

    if (-not $shouldGenerate) {
        Write-ScriptLog "Test coverage generation is not enabled in configuration"
        exit 0
    }

    # Check prerequisites
    Write-ScriptLog "Checking prerequisites..."

    # Check Pester
    $pesterModule = Get-Module -ListAvailable -Name Pester -ErrorAction SilentlyContinue
    if (-not $pesterModule) {
        Write-ScriptLog "Pester is required but not found. Please run 0006_Install-ValidationTools.ps1 first" -Level 'Error'
        exit 1
    }

    # Import Pester
    Import-Module Pester -Force -MinimumVersion 5.0
    Write-ScriptLog "Pester loaded: v$((Get-Module Pester).Version)"

    # Create output directory
    if (-not (Test-Path $testConfig.OutputPath)) {
        if ($PSCmdlet.ShouldProcess($testConfig.OutputPath, 'Create directory')) {
            New-Item -ItemType Directory -Path $testConfig.OutputPath -Force | Out-Null
            Write-ScriptLog "Created output directory: $($testConfig.OutputPath)"
        }
    }

    # Discover modules
    $modulesPath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains"
    Write-ScriptLog "Discovering modules in: $modulesPath"

    $allModules = Get-ChildItem -Path $modulesPath -Directory -Recurse -Depth 2 |
        Where-Object {
            Test-Path (Join-Path $_.FullName "*.psm1") -or
            Test-Path (Join-Path $_.FullName "*.psd1")
        }

    # Apply include/exclude filters
    $modulesToTest = $allModules

    if ($testConfig.IncludeModules.Count -gt 0) {
        $modulesToTest = $modulesToTest | Where-Object { $_.Name -in $testConfig.IncludeModules }
    }

    if ($testConfig.ExcludeModules.Count -gt 0) {
        $modulesToTest = $modulesToTest | Where-Object { $_.Name -notin $testConfig.ExcludeModules }
    }

    Write-ScriptLog "Found $($modulesToTest.Count) modules to process"

    # Generate baseline tests if enabled
    if ($testConfig.GenerateBaseline) {
        Write-ScriptLog "Generating baseline tests..."

        $generatedCount = 0
        $skippedCount = 0

        foreach ($module in $modulesToTest) {
            $moduleName = $module.Name
            $testFileName = "$moduleName.Generated.Tests.ps1"
            $testFilePath = Join-Path $testConfig.OutputPath $testFileName

            # Skip if already exists
            if (Test-Path $testFilePath) {
                $skippedCount++
                Write-ScriptLog "Test already exists for $moduleName (use -Force to overwrite)" -Level 'Debug'
                continue
            }

            if ($PSCmdlet.ShouldProcess($moduleName, 'Generate baseline tests')) {
                try {
                    # Generate test content
                    $testContent = New-BaselineTestContent -ModulePath $module.FullName -ModuleName $moduleName

                    # Write test file
                    Set-Content -Path $testFilePath -Value $testContent -Encoding UTF8
                    $generatedCount++
                    Write-ScriptLog "Generated baseline tests for $moduleName"
                } catch {
                    Write-ScriptLog "Failed to generate tests for $moduleName : $_" -Level 'Error'
                }
            }
        }

        Write-ScriptLog "Baseline generation complete: $generatedCount generated, $skippedCount skipped"
    }

    # Run coverage analysis if enabled
    if ($testConfig.RunCoverageAnalysis) {
        Write-ScriptLog "Running test coverage analysis..."

        # Configure Pester for coverage
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = Join-Path (Split-Path $PSScriptRoot -Parent) "tests"
        $pesterConfig.Run.PassThru = $true
        $pesterConfig.Output.Verbosity = 'Minimal'

        # Enable code coverage
        $pesterConfig.CodeCoverage.Enabled = $true
        $pesterConfig.CodeCoverage.Path = $modulesToTest.FullName
        $pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
        $pesterConfig.CodeCoverage.OutputPath = Join-Path $testConfig.OutputPath "coverage.xml"

        # Run tests with coverage
        if ($PSCmdlet.ShouldProcess('Pester tests', 'Run with coverage analysis')) {
            $testResults = Invoke-Pester -Configuration $pesterConfig

            # Report results
            Write-ScriptLog ""
            Write-ScriptLog "Test Results:"
            Write-ScriptLog "  Total Tests: $($testResults.TotalCount)"
            Write-ScriptLog "  Passed: $($testResults.PassedCount)"
            Write-ScriptLog "  Failed: $($testResults.FailedCount)"
            Write-ScriptLog "  Skipped: $($testResults.SkippedCount)"

            if ($testResults.CodeCoverage) {
                $coverage = [math]::Round(($testResults.CodeCoverage.CoveragePercent), 2)
                Write-ScriptLog ""
                Write-ScriptLog "Code Coverage: $coverage%"

                if ($coverage -ge $testConfig.TargetCoverage) {
                    Write-ScriptLog "✅ Target coverage of $($testConfig.TargetCoverage)% achieved!" -Level 'Information'
                } else {
                    Write-ScriptLog "⚠️  Below target coverage of $($testConfig.TargetCoverage)%" -Level 'Warning'
                }
            }

            # Generate HTML report if configured
            if ($config.Testing.CoverageGeneration.GenerateHtmlReport -eq $true) {
                $htmlPath = Join-Path $testConfig.OutputPath "coverage-report.html"
                Write-ScriptLog "Generating HTML coverage report: $htmlPath"
                # HTML generation would be implemented here
            }
        }
    }

    Write-ScriptLog "Test coverage generation completed successfully"
    exit 0

} catch {
    Write-ScriptLog "Critical error during test coverage generation: $_" -Level 'Error'
    Write-ScriptLog $_.ScriptStackTrace -Level 'Error'
    exit 1
}

# Helper function to generate baseline test content
function New-BaselineTestContent {
    param(
        [string]$ModulePath,
        [string]$ModuleName
    )

    $testContent = @"
# Generated baseline tests for $ModuleName
# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

BeforeAll {
    # Get the module path
    `$modulePath = '$ModulePath'

    # Import the module
    Import-Module `$modulePath -Force -ErrorAction Stop
}

Describe '$ModuleName Module Tests' {

    Context 'Module Loading' {
        It 'Should import without errors' {
            { Import-Module `$modulePath -Force } | Should -Not -Throw
        }

        It 'Should be loaded' {
            Get-Module $ModuleName | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Module Structure' {
        It 'Should have a module file' {
            `$moduleFile = Get-ChildItem -Path `$modulePath -Filter '*.psm1' -File
            `$moduleFile | Should -Not -BeNullOrEmpty
        }

        It 'Should export functions' {
            `$module = Get-Module $ModuleName
            `$module.ExportedFunctions.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Function Tests' {
        `$exportedFunctions = (Get-Module $ModuleName).ExportedFunctions.Keys

        foreach (`$functionName in `$exportedFunctions) {
            It "Should have help for `$functionName" {
                `$help = Get-Help `$functionName
                `$help | Should -Not -BeNullOrEmpty
            }

            It "`$functionName should have a synopsis" {
                `$help = Get-Help `$functionName
                `$help.Synopsis | Should -Not -BeNullOrEmpty
            }
        }
    }
}

AfterAll {
    Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue
}
"@

    return $testContent
}
