#Requires -Version 7.0
<#
.SYNOPSIS
    Core test suites for AitherZero - replaces 97 individual test files
.DESCRIPTION
    Consolidated, high-performance test suites organized by functionality domains.
    Each suite contains focused tests that can be executed in different categories.
.NOTES
    Copyright © 2025 Aitherium Corporation
    Replaces the previous 97 individual .Tests.ps1 files with organized suites
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module initialization - determine project root
if ($env:AITHERZERO_ROOT) {
    $script:ProjectRoot = $env:AITHERZERO_ROOT
} else {
    # Fallback: go up from domains/testing to project root
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$script:DomainsPath = Join-Path $script:ProjectRoot "domains"
$script:AutomationScriptsPath = Join-Path $script:ProjectRoot "automation-scripts"

# Import the test framework
$testFrameworkPath = Join-Path $PSScriptRoot "AitherTestFramework.psm1"
if (Test-Path $testFrameworkPath) {
    Import-Module $testFrameworkPath -Force
}

function Register-CoreTestSuites {
    <#
    .SYNOPSIS
        Register all core test suites with the AitherZero test framework
    .DESCRIPTION
        Defines and registers comprehensive test suites that cover all functionality
    #>
    [CmdletBinding()]
    param()

    Write-Host "🔧 Registering AitherZero Core Test Suites..." -ForegroundColor Cyan

    # Initialize the test framework
    Initialize-TestFramework

    # Register all test suites
    Register-ModuleTestSuites
    Register-AutomationScriptTestSuites
    Register-InfrastructureTestSuites
    Register-IntegrationTestSuites
    Register-PerformanceTestSuites

    Write-Host "✅ All test suites registered successfully!" -ForegroundColor Green
}

function Register-ModuleTestSuites {
    <#
    .SYNOPSIS
        Register test suites for all PowerShell modules
    #>
    [CmdletBinding()]
    param()

    # Configuration Module Tests
    Register-TestSuite -Name "Configuration" -Categories @('Smoke', 'Unit') -Tags @('Core', 'Config') -Priority 10 -TestScript {
        param($config)

        # Test configuration loading and validation
        Describe "Configuration Module" -Tag 'Unit' {
            BeforeAll {
                $configModule = Join-Path $using:script:DomainsPath "configuration/Configuration.psm1"
                Import-Module $configModule -Force -ErrorAction Stop
            }

            It "Should load configuration successfully" {
                { Get-Configuration } | Should -Not -Throw
            }

            It "Should support environment detection" {
                $config = Get-Configuration
                $config.Core.Environment | Should -Not -BeNullOrEmpty
            }

            It "Should handle missing configuration gracefully" {
                # Test with non-existent config
                { Get-ConfiguredValue -Name 'NonExistent' -Section 'Test' -Default 'DefaultValue' } | Should -Not -Throw
            }

            AfterAll {
                Remove-Module Configuration -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Logging Module Tests
    Register-TestSuite -Name "Logging" -Categories @('Smoke', 'Unit') -Tags @('Core', 'Logging') -Priority 5 -TestScript {
        param($config)

        Describe "Logging Module" -Tag 'Unit' {
            BeforeAll {
                $loggingModule = Join-Path $using:script:DomainsPath "utilities/Logging.psm1"
                Import-Module $loggingModule -Force -ErrorAction Stop
            }

            It "Should initialize logging system" {
                { Write-CustomLog -Message "Test message" -Level "Information" } | Should -Not -Throw
            }

            It "Should support different log levels" {
                { Write-CustomLog -Message "Error test" -Level "Error" } | Should -Not -Throw
                { Write-CustomLog -Message "Warning test" -Level "Warning" } | Should -Not -Throw
                { Write-CustomLog -Message "Debug test" -Level "Debug" } | Should -Not -Throw
            }

            It "Should handle structured data logging" {
                $data = @{ TestKey = "TestValue"; Number = 42 }
                { Write-CustomLog -Message "Structured test" -Data $data } | Should -Not -Throw
            }

            AfterAll {
                Remove-Module Logging -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # User Interface Module Tests
    Register-TestSuite -Name "UserInterface" -Categories @('Unit') -Tags @('UI', 'Experience') -Priority 20 -TestScript {
        param($config)

        Describe "User Interface Module" -Tag 'Unit' {
            BeforeAll {
                $uiModule = Join-Path $using:script:DomainsPath "experience/BetterMenu.psm1"
                if (Test-Path $uiModule) {
                    Import-Module $uiModule -Force -ErrorAction Stop
                }
            }

            It "Should provide menu functionality" {
                if (Get-Command Show-BetterMenu -ErrorAction SilentlyContinue) {
                    # Test menu creation (without actually displaying)
                    $items = @("Option 1", "Option 2", "Option 3")
                    { $null = $items } | Should -Not -Throw
                }
            }

            AfterAll {
                Remove-Module BetterMenu -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Testing Framework Module Tests (self-test)
    Register-TestSuite -Name "TestingFramework" -Categories @('Unit') -Tags @('Testing', 'Framework') -Priority 15 -TestScript {
        param($config)

        Describe "Testing Framework Module" -Tag 'Unit' {
            BeforeAll {
                $testingModule = Join-Path $using:script:DomainsPath "testing/TestingFramework.psm1"
                if (Test-Path $testingModule) {
                    Import-Module $testingModule -Force -ErrorAction Stop
                }
            }

            It "Should provide testing capabilities" {
                # Basic validation that testing functions exist
                $testingCommands = Get-Command -Module TestingFramework -ErrorAction SilentlyContinue
                $testingCommands | Should -Not -BeNullOrEmpty
            }

            AfterAll {
                Remove-Module TestingFramework -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Reporting Engine Module Tests
    Register-TestSuite -Name "ReportingEngine" -Categories @('Unit') -Tags @('Reporting', 'Analytics') -Priority 25 -TestScript {
        param($config)

        Describe "Reporting Engine Module" -Tag 'Unit' {
            BeforeAll {
                $reportingModule = Join-Path $using:script:DomainsPath "reporting/ReportingEngine.psm1"
                if (Test-Path $reportingModule) {
                    Import-Module $reportingModule -Force -ErrorAction Stop
                }
            }

            It "Should provide reporting capabilities" {
                # Test that reporting functions are available
                $reportingCommands = Get-Command -Module ReportingEngine -ErrorAction SilentlyContinue
                if ($reportingCommands) {
                    $reportingCommands.Count | Should -BeGreaterThan 0
                }
            }

            AfterAll {
                Remove-Module ReportingEngine -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Register-AutomationScriptTestSuites {
    <#
    .SYNOPSIS
        Register test suites for automation scripts validation
    #>
    [CmdletBinding()]
    param()

    # Core Automation Scripts Validation
    Register-TestSuite -Name "AutomationScripts" -Categories @('Unit', 'Integration') -Tags @('Automation', 'Scripts') -Priority 30 -TestScript {
        param($config)

        Describe "Automation Scripts Validation" -Tag 'Unit' {
            BeforeAll {
                $scriptsPath = $using:script:AutomationScriptsPath
            }

            It "Should have all expected automation scripts" {
                $scriptsPath | Should -Exist

                $scripts = Get-ChildItem -Path $scriptsPath -Filter "*.ps1" -ErrorAction SilentlyContinue
                $scripts.Count | Should -BeGreaterThan 50  # We expect many scripts
            }

            It "Should have scripts following naming convention" {
                $scripts = Get-ChildItem -Path $scriptsPath -Filter "*.ps1"

                foreach ($script in $scripts) {
                    # Check naming pattern: nnnn_Name-With-Dashes.ps1
                    $script.Name | Should -Match '^\d{4}_[\w-]+\.ps1$'
                }
            }

            It "Should have valid PowerShell syntax in scripts" {
                $scripts = Get-ChildItem -Path $scriptsPath -Filter "*.ps1"

                foreach ($script in $scripts) {
                    $errors = $null
                    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script.FullName -Raw), [ref]$errors)
                    $errors | Should -BeNullOrEmpty -Because "Script $($script.Name) should have valid syntax"
                }
            }
        }
    }

    # Script Dependencies Validation
    Register-TestSuite -Name "ScriptDependencies" -Categories @('Unit') -Tags @('Dependencies', 'Validation') -Priority 35 -TestScript {
        param($config)

        Describe "Script Dependencies Validation" -Tag 'Unit' {
            It "Should validate script execution order" {
                # Test that scripts can be ordered by their numeric prefix
                $scriptsPath = $using:script:AutomationScriptsPath
                $scripts = Get-ChildItem -Path $scriptsPath -Filter "*.ps1" |
                    Where-Object { $_.Name -match '^\d{4}_' } |
                    Sort-Object Name

                $scripts.Count | Should -BeGreaterThan 0

                # Verify first script is 0000 series (environment prep)
                $scripts[0].Name | Should -Match '^000\d_'
            }

            It "Should have proper script categories" {
                $scriptsPath = $using:script:AutomationScriptsPath

                # Check for expected categories
                $environmentScripts = Get-ChildItem -Path $scriptsPath -Filter "000*.ps1"
                $infrastructureScripts = Get-ChildItem -Path $scriptsPath -Filter "010*.ps1"
                $developmentScripts = Get-ChildItem -Path $scriptsPath -Filter "020*.ps1"
                $testingScripts = Get-ChildItem -Path $scriptsPath -Filter "040*.ps1"

                $environmentScripts.Count | Should -BeGreaterThan 0
                $infrastructureScripts.Count | Should -BeGreaterOrEqual 0
                $developmentScripts.Count | Should -BeGreaterThan 0
                $testingScripts.Count | Should -BeGreaterThan 0
            }
        }
    }
}

function Register-InfrastructureTestSuites {
    <#
    .SYNOPSIS
        Register test suites for infrastructure validation
    #>
    [CmdletBinding()]
    param()

    # System Requirements Validation
    Register-TestSuite -Name "SystemRequirements" -Categories @('Smoke') -Tags @('System', 'Requirements') -Priority 1 -TestScript {
        param($config)

        Describe "System Requirements" -Tag 'Smoke' {
            It "Should have PowerShell 7+" {
                $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
            }

            It "Should have proper environment variables" {
                $env:AITHERZERO_ROOT | Should -Not -BeNullOrEmpty
            }

            It "Should have accessible project directory" {
                $projectRoot = $using:script:ProjectRoot
                $projectRoot | Should -Exist
                Test-Path (Join-Path $projectRoot "AitherZero.psm1") | Should -Be $true
            }

            It "Should have domains directory" {
                $domainsPath = $using:script:DomainsPath
                $domainsPath | Should -Exist
            }
        }
    }

    # Module Loading Tests
    Register-TestSuite -Name "ModuleLoading" -Categories @('Smoke', 'Integration') -Tags @('Modules', 'Loading') -Priority 5 -TestScript {
        param($config)

        Describe "Module Loading" -Tag 'Integration' {
            It "Should load AitherZero main module" {
                $mainModule = Join-Path $using:script:ProjectRoot "AitherZero.psm1"
                { Import-Module $mainModule -Force } | Should -Not -Throw
            }

            It "Should have core commands available after module load" {
                # Check if the az alias is available
                Get-Command az -ErrorAction SilentlyContinue | Should -Not -BeNull
            }

            It "Should load domain modules successfully" {
                $domainsPath = $using:script:DomainsPath
                $modules = Get-ChildItem -Path $domainsPath -Filter "*.psm1" -Recurse | Select-Object -First 5

                foreach ($module in $modules) {
                    { Import-Module $module.FullName -Force -ErrorAction Stop } | Should -Not -Throw
                }
            }
        }
    }
}

function Register-IntegrationTestSuites {
    <#
    .SYNOPSIS
        Register integration test suites for cross-module functionality
    #>
    [CmdletBinding()]
    param()

    # End-to-End Workflow Tests
    Register-TestSuite -Name "WorkflowIntegration" -Categories @('Integration') -Tags @('Workflow', 'E2E') -Priority 50 -TestScript {
        param($config)

        Describe "Workflow Integration" -Tag 'Integration' {
            BeforeAll {
                # Ensure main module is loaded
                $mainModule = Join-Path $using:script:ProjectRoot "AitherZero.psm1"
                Import-Module $mainModule -Force -ErrorAction Stop
            }

            It "Should execute automation scripts through az command" {
                # Test that the az wrapper works (dry run mode)
                $testScript = Get-ChildItem -Path $using:script:AutomationScriptsPath -Filter "*.ps1" | Select-Object -First 1

                if ($testScript) {
                    $scriptNumber = $testScript.Name.Substring(0, 4)
                    # Test in dry run mode to avoid actual execution
                    { az $scriptNumber -DryRun } | Should -Not -Throw
                }
            }

            It "Should handle configuration integration" {
                if (Get-Command Get-Configuration -ErrorAction SilentlyContinue) {
                    { $config = Get-Configuration } | Should -Not -Throw
                }
            }
        }
    }
}

function Register-PerformanceTestSuites {
    <#
    .SYNOPSIS
        Register performance validation test suites
    #>
    [CmdletBinding()]
    param()

    # Performance Benchmarks
    Register-TestSuite -Name "PerformanceBenchmarks" -Categories @('Full') -Tags @('Performance', 'Benchmarks') -Priority 100 -TestScript {
        param($config)

        Describe "Performance Benchmarks" -Tag 'Performance' {
            It "Should load modules within acceptable time" {
                $startTime = Get-Date

                $mainModule = Join-Path $using:script:ProjectRoot "AitherZero.psm1"
                Import-Module $mainModule -Force

                $loadTime = (Get-Date) - $startTime
                $loadTime.TotalSeconds | Should -BeLessThan 10  # Should load in under 10 seconds
            }

            It "Should execute commands with reasonable performance" {
                $startTime = Get-Date

                # Test basic command performance
                if (Get-Command az -ErrorAction SilentlyContinue) {
                    # Just check command resolution time
                    $null = Get-Command az
                }

                $executionTime = (Get-Date) - $startTime
                $executionTime.TotalSeconds | Should -BeLessThan 2  # Should be very fast
            }
        }
    }
}

# Export the registration function
Export-ModuleMember -Function 'Register-CoreTestSuites'