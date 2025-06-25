#!/usr/bin/env pwsh
# Load shared test helpers for environment setup
. (Join-Path $PSScriptRoot 'helpers' 'TestHelpers.ps1')
#Requires -Version 7.0

<#
.SYNOPSIS
Intelligent test discovery and execution for OpenTofu Lab Automation

.DESCRIPTION
This unified test runner automatically discovers and tests all functional modules
and scripts in the project using intelligent analysis and template-based testing.
No need for individual test files - this discovers what actually makes the project work.

.PARAMETER TestType
The type of tests to run: All, Unit, Integration, Smoke, Module, Script

.PARAMETER ModuleName
Test only specific module (optional)

.PARAMETER Severity
Test severity level: Critical, Standard, Comprehensive

.PARAMETER OutputFormat
Output format: Console, JUnit, NUnit, JSON

.EXAMPLE
.\Invoke-IntelligentTests.ps1 -TestType Smoke
Run smoke tests to verify core functionality

.EXAMPLE
.\Invoke-IntelligentTests.ps1 -TestType Module -ModuleName PatchManager
Test only the PatchManager module

.EXAMPLE
.\Invoke-IntelligentTests.ps1 -TestType All -Severity Comprehensive -OutputFormat JUnit
Run all tests with comprehensive coverage and JUnit output
#>

param(
    [ValidateSet('All', 'Unit', 'Integration', 'Smoke', 'Module', 'Script')]
    [string]$TestType,

    [string]$ModuleName,

    [ValidateSet('Critical', 'Standard', 'Comprehensive')]
    [string]$Severity,

    [ValidateSet('Console', 'JUnit', 'NUnit', 'JSON')]
    [string]$OutputFormat
)

# Set default values
if (-not $TestType) { $TestType = 'Smoke' }
if (-not $Severity) { $Severity = 'Standard' }
if (-not $OutputFormat) { $OutputFormat = 'Console' }

# Set up environment
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Environment variables for cross-platform compatibility
$env:PROJECT_ROOT = $ProjectRoot
$env:PWSH_MODULES_PATH = "$ProjectRoot/aither-core/modules"  # Updated for aither-core structure
$env:PYTHON_MODULES_PATH = Join-Path $ProjectRoot "py"

# Import test configuration
$testConfig = @{
    ProjectRoot = $ProjectRoot
    ModulesPath = "$ProjectRoot/aither-core/modules"  # Updated for aither-core structure
    PythonPath = "$ProjectRoot/py"
    OutputPath = Join-Path $PSScriptRoot "results"
    Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
}

# Ensure output directory exists
if (-not (Test-Path $testConfig.OutputPath)) {
    if (-not (Test-Path $testConfig.OutputPath)) { New-Item -Path $testConfig.OutputPath -ItemType Directory -Force | Out-Null }
}

Write-Information " -InformationAction Continue[SYMBOL] OpenTofu Lab Automation - Intelligent Test Runner" -ForegroundColor Cyan
Write-Information " -InformationAction ContinueProject Root: $($testConfig.ProjectRoot)" -ForegroundColor Gray
Write-Information " -InformationAction ContinueTest Type: $TestType | Severity: $Severity | Output: $OutputFormat" -ForegroundColor Gray

# Import Pester with proper version
if (-not (Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version -ge [version]'5.0.0' })) {
    Write-Warning "Pester 5.x is required. Installing..."
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
}
Import-Module Pester -MinimumVersion 5.0.0 -Force

# Discover functional modules
function Get-FunctionalModules {
    [CmdletBinding()]

    $modulesPath = $testConfig.ModulesPath
    if (-not (Test-Path $modulesPath)) {
        Write-Warning "Modules path not found: $modulesPath"
        return @()
    }

    $modules = Get-ChildItem $modulesPath -Directory | ForEach-Object {
        $manifestPath = Join-Path $_.FullName "*.psd1"
        $moduleFilePath = Join-Path $_.FullName "*.psm1"

        if ((Test-Path $manifestPath) -or (Test-Path $moduleFilePath)) {
            [PSCustomObject]@{
                Name = $_.Name
                Path = $_.FullName
                HasManifest = Test-Path $manifestPath
                HasModuleFile = Test-Path $moduleFilePath
                PublicFunctions = @()
                PrivateFunctions = @()
            }
        }
    } | Where-Object { $_ -ne $null }

    # Analyze each module for functions
    foreach ($module in $modules) {
        try {
            Import-Module $module.Path -Force -ErrorAction SilentlyContinue
            $exportedFunctions = Get-Command -Module $module.Name -CommandType Function -ErrorAction SilentlyContinue
            $module.PublicFunctions = $exportedFunctions | ForEach-Object { $_.Name }

            # Look for Public/Private folders
            $publicPath = Join-Path $module.Path "Public"
            $privatePath = Join-Path $module.Path "Private"

            if (Test-Path $publicPath) {
                $publicFiles = Get-ChildItem $publicPath -Filter "*.ps1" | ForEach-Object { $_.BaseName }
                $module.PublicFunctions += $publicFiles
            }

            if (Test-Path $privatePath) {
                $privateFiles = Get-ChildItem $privatePath -Filter "*.ps1" | ForEach-Object { $_.BaseName }
                $module.PrivateFunctions = $privateFiles
            }

            Remove-Module $module.Name -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Verbose "Could not analyze module $($module.Name): $($_.Exception.Message)"
        }
    }

    return $modules
}

# Discover Python modules
function Get-PythonModules {
    [CmdletBinding()]

    $pythonPath = $testConfig.PythonPath
    if (-not (Test-Path $pythonPath)) {
        Write-Warning "Python path not found: $pythonPath"
        return @()
    }

    $modules = @()

    # Find labctl package
    $labctlPath = Join-Path $pythonPath "labctl"
    if (Test-Path $labctlPath) {
        $pyFiles = Get-ChildItem $labctlPath -Filter "*.py" | Where-Object { $_.Name -ne "__init__.py" }
        $modules += [PSCustomObject]@{
            Name = "labctl"
            Path = $labctlPath
            Files = $pyFiles | ForEach-Object { $_.BaseName }
            HasCLI = Test-Path (Join-Path $labctlPath "cli.py")
        }
    }

    # Find other Python files
    $otherPyFiles = Get-ChildItem $pythonPath -Filter "*.py" -Recurse | Where-Object {
        $_.FullName -notlike "*\labctl\*" -and $_.Name -ne "__init__.py"
    }

    foreach ($file in $otherPyFiles) {
        $modules += [PSCustomObject]@{
            Name = $file.BaseName
            Path = $file.FullName
            Files = @($file.BaseName)
            HasCLI = $false
        }
    }

    return $modules
}

# Core testing templates
function Test-ModuleCore {
    param($Module)

    Describe "Module: $($Module.Name)" -Tag @('Unit', 'Module', 'Core') {

        Context "Module Structure" {
            It "should have a valid module structure" {
                Test-Path $Module.Path | Should -Be $true
                ($Module.HasManifest -or $Module.HasModuleFile) | Should -Be $true
            }

            if ($Module.HasManifest) {
                It "should have a valid manifest" {
                    $manifestPath = Get-ChildItem (Join-Path $Module.Path "*.psd1") | Select-Object -First 1
                    { Test-ModuleManifest $manifestPath.FullName -ErrorAction Stop } | Should -Not -Throw
                }
            }
        }

        Context "Module Import" {
            It "should import without errors" {
                { Import-Module $Module.Path -Force -ErrorAction Stop } | Should -Not -Throw
            }

            It "should export functions" {
                Import-Module $Module.Path -Force
                $commands = Get-Command -Module $Module.Name -CommandType Function -ErrorAction SilentlyContinue
                $commands.Count | Should -BeGreaterThan 0
            }
        }

        Context "Function Quality" {
            BeforeAll {
                Import-Module $Module.Path -Force
                $functions = Get-Command -Module $Module.Name -CommandType Function -ErrorAction SilentlyContinue
            }

            foreach ($function in $Module.PublicFunctions) {
                It "function '$function' should have help documentation" {
                    if (Get-Command $function -ErrorAction SilentlyContinue) {
                        $help = Get-Help $function -ErrorAction SilentlyContinue
                        $help.Synopsis | Should -Not -BeNullOrEmpty
                        $help.Synopsis | Should -Not -Be $function  # Not just the function name
                    }
                }

                It "function '$function' should have parameter validation" {
                    if (Get-Command $function -ErrorAction SilentlyContinue) {
                        $cmd = Get-Command $function
                        if ($cmd.Parameters.Count -gt 0) {
                            # Check for some basic parameter attributes
                            $hasValidation = $cmd.Parameters.Values | Where-Object {
                                $_.Attributes | Where-Object {
                                    $_ -is [System.Management.Automation.ParameterAttribute] -or
                                    $_ -is [System.Management.Automation.ValidateSetAttribute] -or
                                    $_ -is [System.Management.Automation.ValidateNotNullOrEmptyAttribute]
                                }
                            }
                            $hasValidation | Should -Not -BeNullOrEmpty
                        }
                    }
                }
            }

            AfterAll {
                Remove-Module $Module.Name -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Test-ModuleIntegration {
    param($Module)

    Describe "Module Integration: $($Module.Name)" -Tag @('Integration', 'Module') {

        Context "Cross-Module Dependencies" {
            BeforeAll {
                # Clean import
                Remove-Module $Module.Name -Force -ErrorAction SilentlyContinue
                Import-Module $Module.Path -Force
            }

            It "should handle missing dependencies gracefully" {
                $commands = Get-Command -Module $Module.Name -ErrorAction SilentlyContinue
                $commands | Should -Not -BeNullOrEmpty
            }

            # Module-specific integration tests
            switch ($Module.Name) {
                'PatchManager' {
                    It "should integrate with Git" {
                        # Test that PatchManager can detect Git repo
                        $isGitRepo = Test-Path (Join-Path $testConfig.ProjectRoot ".git")
                        $isGitRepo | Should -Be $true
                    }
                }

                'LabRunner' {
                    It "should set up environment variables" {
                        $env:PROJECT_ROOT | Should -Not -BeNullOrEmpty
                        $env:PWSH_MODULES_PATH | Should -Not -BeNullOrEmpty
                    }
                }

                'Logging' {
                    It "should provide logging capabilities" {
                        # Test basic logging functionality
                        $logFunctions = Get-Command -Module $Module.Name | Where-Object { $_.Name -like "*Log*" }
                        $logFunctions | Should -Not -BeNullOrEmpty
                    }
                }

                'TestingFramework' {
                    It "should provide testing utilities" {
                        # Test that testing framework has test-related functions
                        $testFunctions = Get-Command -Module $Module.Name | Where-Object { $_.Name -like "*Test*" }
                        $testFunctions | Should -Not -BeNullOrEmpty
                    }
                }
            }

            AfterAll {
                Remove-Module $Module.Name -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Test-PythonModules {
    param($Modules)

    Describe "Python Modules" -Tag @('Unit', 'Python') {

        Context "Python Environment" {
            It "should have Python available" {
                $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
                if (-not $pythonCmd) {
                    $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
                }
                $pythonCmd | Should -Not -BeNullOrEmpty
            }
        }

        foreach ($module in $Modules) {
            Context "Module: $($module.Name)" {
                It "should have valid Python syntax" {
                    foreach ($file in $module.Files) {
                        $filePath = if ($module.Name -eq "labctl") {
                            Join-Path $module.Path "$file.py"
                        } else {
                            $module.Path
                        }

                        if (Test-Path $filePath) {
                            # Basic syntax check using Python
                            $pythonCheck = if (Get-Command python -ErrorAction SilentlyContinue) { "python" } else { "python3" }
                            $result = & $pythonCheck -m py_compile $filePath 2>&1
                            $LASTEXITCODE | Should -Be 0
                        }
                    }
                }

                if ($module.HasCLI) {
                    It "should have CLI entry point" {
                        $cliPath = Join-Path $module.Path "cli.py"
                        Test-Path $cliPath | Should -Be $true
                    }
                }
            }
        }
    }
}

function Test-ProjectSmoke {
    Describe "Project Smoke Tests" -Tag @('Smoke', 'Critical') {

        Context "Project Structure" {
            It "should have required directories" {
                Test-Path (Join-Path $testConfig.ProjectRoot "src") | Should -Be $true
                Test-Path (Join-Path $testConfig.ProjectRoot "src/pwsh") | Should -Be $true
                Test-Path (Join-Path $testConfig.ProjectRoot $env:PWSH_MODULES_PATH) | Should -Be $true
                Test-Path (Join-Path $testConfig.ProjectRoot "tests") | Should -Be $true
            }

            It "should have core files" {
                Test-Path (Join-Path $testConfig.ProjectRoot "README.md") | Should -Be $true
                Test-Path (Join-Path $testConfig.ProjectRoot "LICENSE") | Should -Be $true
                Test-Path (Join-Path $testConfig.ProjectRoot "PROJECT-MANIFEST.json") | Should -Be $true
            }
        }

        Context "Core Modules" {
            $coreModules = @('LabRunner', 'PatchManager', 'Logging')

            foreach ($moduleName in $coreModules) {
                It "should have $moduleName module" {
                    $modulePath = Join-Path $testConfig.ModulesPath $moduleName
                    Test-Path $modulePath | Should -Be $true
                }

                It "$moduleName should be importable" {
                    { Import-Module (Join-Path $testConfig.ModulesPath $moduleName) -Force -ErrorAction Stop } | Should -Not -Throw
                    Remove-Module $moduleName -Force -ErrorAction SilentlyContinue
                }
            }
        }

        Context "Environment Setup" {
            It "should have PROJECT_ROOT set" {
                $env:PROJECT_ROOT | Should -Not -BeNullOrEmpty
                Test-Path $env:PROJECT_ROOT | Should -Be $true
            }

            It "should have PWSH_MODULES_PATH set" {
                $env:PWSH_MODULES_PATH | Should -Not -BeNullOrEmpty
                Test-Path $env:PWSH_MODULES_PATH | Should -Be $true
            }
        }

        Context "Git Repository" {
            It "should be a valid Git repository" {
                Test-Path (Join-Path $testConfig.ProjectRoot ".git") | Should -Be $true
            }

            It "should have remote origin configured" {
                $remotes = git remote 2>&1
                $remotes | Should -Contain "origin"
            }
        }
    }
}

# Main execution logic
Write-Information " -InformationAction Continue`nSEARCHING - Discovering functional modules..." -ForegroundColor Yellow

# Discover modules and components
$modules = Get-FunctionalModules
$pythonModules = Get-PythonModules

if ($ModuleName) {
    $modules = $modules | Where-Object { $_.Name -eq $ModuleName }
    if (-not $modules) {
        Write-Error "Module '$ModuleName' not found"
        exit 1
    }
}

Write-Information " -InformationAction ContinueFound $($modules.Count) PowerShell modules and $($pythonModules.Count) Python modules" -ForegroundColor Gray

# Configure Pester
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Exit = $false
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputPath = Join-Path $testConfig.OutputPath "TestResults_$($testConfig.Timestamp).xml"

switch ($OutputFormat) {
    'JUnit' { $pesterConfig.TestResult.OutputFormat = 'JUnitXml' }
    'NUnit' { $pesterConfig.TestResult.OutputFormat = 'NUnitXml' }
    'JSON' { $pesterConfig.TestResult.OutputFormat = 'Json' }
    default { $pesterConfig.TestResult.OutputFormat = 'NUnitXml' }
}

$pesterConfig.Output.Verbosity = 'Detailed'

# Run tests based on type and severity
$testResults = @()

if ($TestType -in @('All', 'Smoke')) {
    Write-Information " -InformationAction Continue`nEXECUTING - Running Smoke Tests..." -ForegroundColor Yellow
    $smokeResult = Invoke-Pester -Configuration $pesterConfig -Container (New-PesterContainer -ScriptBlock {
        Test-ProjectSmoke
    })
    $testResults += $smokeResult
}

if ($TestType -in @('All', 'Unit', 'Module') -and $modules.Count -gt 0) {
    Write-Information " -InformationAction Continue`nPACKAGE - Running Module Tests..." -ForegroundColor Yellow

    foreach ($module in $modules) {
        Write-Information " -InformationAction Continue  Testing module: $($module.Name)" -ForegroundColor Gray

        $moduleResult = Invoke-Pester -Configuration $pesterConfig -Container (New-PesterContainer -ScriptBlock {
            Test-ModuleCore -Module $using:module
        })
        $testResults += $moduleResult

        if ($Severity -in @('Standard', 'Comprehensive')) {
            $integrationResult = Invoke-Pester -Configuration $pesterConfig -Container (New-PesterContainer -ScriptBlock {
                Test-ModuleIntegration -Module $using:module
            })
            $testResults += $integrationResult
        }
    }
}

if ($TestType -in @('All', 'Unit') -and $pythonModules.Count -gt 0) {
    Write-Information " -InformationAction Continue`nPYTHON - Running Python Tests..." -ForegroundColor Yellow

    $pythonResult = Invoke-Pester -Configuration $pesterConfig -Container (New-PesterContainer -ScriptBlock {
        Test-PythonModules -Modules $using:pythonModules
    })
    $testResults += $pythonResult
}

# Summary
Write-Information " -InformationAction Continue`nANALYSIS - Test Results Summary:" -ForegroundColor Cyan
$totalTests = ($testResults | Measure-Object TotalCount -Sum).Sum
$passedTests = ($testResults | Measure-Object PassedCount -Sum).Sum
$failedTests = ($testResults | Measure-Object FailedCount -Sum).Sum

Write-Information " -InformationAction Continue  Total Tests: $totalTests" -ForegroundColor White
Write-Information " -InformationAction Continue  Passed: $passedTests" -ForegroundColor Green
Write-Information " -InformationAction Continue  Failed: $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { 'Red' } else { 'Green' })

if ($testResults | Where-Object { $_.FailedCount -gt 0 }) {
    Write-Information " -InformationAction Continue`nFAILED - Some tests failed. Check the detailed output above." -ForegroundColor Red
    exit 1
} else {
    Write-Information " -InformationAction Continue`nPASS All tests passed!" -ForegroundColor Green
    exit 0
}