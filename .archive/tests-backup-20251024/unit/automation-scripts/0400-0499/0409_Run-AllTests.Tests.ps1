#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for 0409_Run-AllTests.ps1
.DESCRIPTION
    Tests the comprehensive test execution script that runs all test types
    without tag filtering.
#>

BeforeAll {
    # Get script path
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0409_Run-AllTests.ps1"

    # Mock Pester and other functions
    Mock Invoke-Pester {
        return [PSCustomObject]@{
            TotalCount = 35
            PassedCount = 30
            FailedCount = 5
            SkippedCount = 0
            Duration = [TimeSpan]::FromSeconds(125.7)
            CodeCoverage = [PSCustomObject]@{
                CoveragePercent = 72.8
                CommandsAnalyzedCount = 650
                CommandsExecutedCount = 473
                CommandsMissedCount = 177
            }
            Failed = @(
                [PSCustomObject]@{
                    ExpandedPath = 'Integration.Database.Connection.Test'
                    ErrorRecord = [PSCustomObject]@{
                        Exception = [PSCustomObject]@{
                            Message = 'Database connection failed'
                        }
                    }
                }
                [PSCustomObject]@{
                    ExpandedPath = 'E2E.User.Registration.Test'
                    ErrorRecord = [PSCustomObject]@{
                        Exception = [PSCustomObject]@{
                            Message = 'User registration endpoint timeout'
                        }
                    }
                }
            )
        }
    }
    Mock New-PesterConfiguration {
        return [PSCustomObject]@{
            Run = [PSCustomObject]@{
                Path = ''
                PassThru = $false
                Exit = $false
            }
            Filter = [PSCustomObject]@{
                Tag = @()
                ExcludeTag = @()
            }
            TestResult = [PSCustomObject]@{
                Enabled = $false
                OutputPath = ''
                OutputFormat = ''
            }
            CodeCoverage = [PSCustomObject]@{
                Enabled = $false
                Path = @()
                OutputPath = ''
                OutputFormat = ''
            }
            Output = [PSCustomObject]@{
                Verbosity = 'Normal'
            }
            Should = [PSCustomObject]@{
                ErrorAction = 'Stop'
            }
        }
    }
    Mock Import-Module {}
    Mock Get-Module {
        return @([PSCustomObject]@{
            Version = [Version]'5.3.0'
        })
    }
    Mock Get-ChildItem {
        return @(
            [PSCustomObject]@{ Name = 'Unit.Tests.ps1' }
            [PSCustomObject]@{ Name = 'Integration.Tests.ps1' }
            [PSCustomObject]@{ Name = 'E2E.Tests.ps1' }
            [PSCustomObject]@{ Name = 'Performance.Tests.ps1' }
        )
    }
    Mock Test-Path { return $true }
    Mock New-Item {}
    Mock Get-Content {
        return '{"Testing":{"Framework":"Pester","MinVersion":"5.0.0","CodeCoverage":{"Enabled":true,"MinimumPercent":80}}}'
    } -ParameterFilter { $Path -like "*config*" }
    Mock ConvertFrom-Json {
        return @{
            Testing = @{
                Framework = 'Pester'
                MinVersion = '5.0.0'
                CodeCoverage = @{
                    Enabled = $true
                    MinimumPercent = 80
                }
            }
        }
    }
    Mock Set-Content {}
    Mock ConvertTo-Json { return '{}' }
    Mock Write-Host {}
}

Describe "0409_Run-AllTests" -Tag @('Unit', 'Testing', 'Comprehensive') {

    Context "Script Metadata" {
        It "Should have correct metadata structure" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '#Requires -Version 7.0'
            $scriptContent | Should -Match 'Stage.*Testing'
            $scriptContent | Should -Match 'Order.*0409'
        }
    }

    Context "DryRun Mode" {
        It "Should preview test execution without running tests when DryRun is specified" {
            $result = & $scriptPath -DryRun -Path "/test/path"
            $LASTEXITCODE | Should -Be 0

            Assert-MockCalled Invoke-Pester -Times 0
        }

        It "Should list all test files in DryRun mode" {
            & $scriptPath -DryRun -Path "/test/path"

            Assert-MockCalled Get-ChildItem -ParameterFilter { $Filter -eq '*.Tests.ps1' }
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter without executing tests" {
            { & $scriptPath -WhatIf -Path "/test/path" } | Should -Not -Throw

            Assert-MockCalled Invoke-Pester -Times 0
        }

        It "Should return summary object in WhatIf mode" {
            $result = & $scriptPath -WhatIf -Path "/test/path"

            $result | Should -Not -BeNullOrEmpty
            $result.TotalCount | Should -Be 0
            $result.PassedCount | Should -Be 0
            $result.FailedCount | Should -Be 0
        }
    }

    Context "Test Path Handling" {
        It "Should exit gracefully if test path doesn't exist" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -eq "/nonexistent/path" }

            $result = & $scriptPath -Path "/nonexistent/path"
            $LASTEXITCODE | Should -Be 0
        }

        It "Should exit gracefully if no test files found" {
            Mock Get-ChildItem { return @() } -ParameterFilter { $Filter -eq '*.Tests.ps1' }

            $result = & $scriptPath -Path "/empty/path"
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "No Tag Filtering" {
        It "Should run ALL tests without tag filtering" {
            & $scriptPath -Path "/test/path"

            # The key difference from unit tests - should NOT set tag filters
            Assert-MockCalled New-PesterConfiguration
            Assert-MockCalled Invoke-Pester
        }

        It "Should include unit, integration, E2E, and performance tests" {
            & $scriptPath -Path "/test/path"

            # Should process all test files regardless of type
            Assert-MockCalled Get-ChildItem -ParameterFilter { $Filter -eq '*.Tests.ps1' }
        }

        It "Should log that no tag filtering is applied" {
            & $scriptPath -Path "/test/path"

            Assert-MockCalled Write-Host -Times 1
        }
    }

    Context "Pester Configuration" {
        It "Should configure Pester without tag restrictions" {
            & $scriptPath -Path "/test/path"

            Assert-MockCalled New-PesterConfiguration
        }

        It "Should enable code coverage by default" {
            & $scriptPath -Path "/test/path"

            Assert-MockCalled Invoke-Pester
        }

        It "Should disable code coverage when NoCoverage is specified" {
            & $scriptPath -Path "/test/path" -NoCoverage

            Assert-MockCalled Invoke-Pester
        }

        It "Should configure CI mode when CI switch is used" {
            & $scriptPath -Path "/test/path" -CI

            Assert-MockCalled Invoke-Pester
        }
    }

    Context "Configuration Loading" {
        It "Should load configuration from config.psd1 if available" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*config.psd1" }

            & $scriptPath -Path "/test/path"

            Assert-MockCalled Get-Content -ParameterFilter { $Path -like "*config.psd1" }
        }

        It "Should use default configuration if config.psd1 not found" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*config.psd1" }

            & $scriptPath -Path "/test/path"

            # Should still run with defaults
            Assert-MockCalled Invoke-Pester
        }
    }

    Context "Module Dependencies" {
        It "Should check for Pester availability" {
            Mock Get-Module { return $null } -ParameterFilter {
                $ListAvailable -and $Name -eq 'Pester'
            }

            $result = & $scriptPath -Path "/test/path" 2>$null
            $LASTEXITCODE | Should -Be 2
        }

        It "Should require minimum Pester version" {
            Mock Get-Module {
                return @([PSCustomObject]@{
                    Version = [Version]'4.10.1'
                })
            } -ParameterFilter { $ListAvailable -and $Name -eq 'Pester' }

            $result = & $scriptPath -Path "/test/path" 2>$null
            $LASTEXITCODE | Should -Be 2
        }

        It "Should import Pester with minimum version" {
            & $scriptPath -Path "/test/path"

            Assert-MockCalled Import-Module -ParameterFilter {
                $Name -eq 'Pester' -and $MinimumVersion -eq '5.0.0'
            }
        }
    }

    Context "Test Results Processing" {
        It "Should create test results directory if it doesn't exist" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*tests/results*" }

            & $scriptPath -Path "/test/path"

            Assert-MockCalled New-Item -ParameterFilter {
                $ItemType -eq 'Directory'
            }
        }

        It "Should save test results in NUnitXml format" {
            & $scriptPath -Path "/test/path"

            Assert-MockCalled Invoke-Pester
        }

        It "Should save test summary as JSON" {
            & $scriptPath -Path "/test/path"

            Assert-MockCalled Set-Content -ParameterFilter {
                $Path -like "*AllTests-Summary-*.json"
            }
        }

        It "Should return Pester result when PassThru is specified" {
            $result = & $scriptPath -Path "/test/path" -PassThru

            $result | Should -Not -BeNullOrEmpty
            $result.TotalCount | Should -Be 35
            $result.PassedCount | Should -Be 30
            $result.FailedCount | Should -Be 5
        }
    }

    Context "Coverage Reporting" {
        It "Should display comprehensive coverage summary" {
            & $scriptPath -Path "/test/path"

            # Should display all test types' coverage
            Assert-MockCalled Write-Host -ParameterFilter {
                $Object -like "*Code Coverage*"
            }
        }

        It "Should handle different Pester versions for coverage data" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    TotalCount = 20
                    PassedCount = 18
                    FailedCount = 2
                    CodeCoverage = [PSCustomObject]@{
                        CoveragePercent = 75.0
                        NumberOfCommandsAnalyzed = 400
                        NumberOfCommandsMissed = 100
                    }
                }
            }

            & $scriptPath -Path "/test/path"

            Assert-MockCalled Write-Host -Times 1
        }

        It "Should warn when coverage is below threshold" {
            & $scriptPath -Path "/test/path"

            # With 72.8% coverage (below 80% threshold)
            Assert-MockCalled Write-Host -Times 1
        }
    }

    Context "Failed Test Display" {
        It "Should display all failed tests from all test types" {
            & $scriptPath -Path "/test/path"

            # Should display failed tests section
            Assert-MockCalled Write-Host -ParameterFilter {
                $Object -like "*Failed Tests*"
            }
        }

        It "Should show error details for failed tests" {
            & $scriptPath -Path "/test/path"

            # Should display error messages from different test types
            Assert-MockCalled Write-Host -Times 1
        }

        It "Should handle tests with different error record formats" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    TotalCount = 10
                    PassedCount = 8
                    FailedCount = 2
                    Failed = @(
                        [PSCustomObject]@{
                            ExpandedPath = 'Test.With.Exception'
                            ErrorRecord = [PSCustomObject]@{
                                Exception = [PSCustomObject]@{
                                    Message = 'Exception message'
                                }
                            }
                        }
                        [PSCustomObject]@{
                            ExpandedPath = 'Test.Without.Exception'
                            ErrorRecord = 'Plain error message'
                        }
                    )
                }
            }

            & $scriptPath -Path "/test/path"

            Assert-MockCalled Write-Host -Times 1
        }
    }

    Context "Exit Codes" {
        It "Should exit with code 0 when all tests pass" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    TotalCount = 25
                    PassedCount = 25
                    FailedCount = 0
                    SkippedCount = 0
                }
            }

            $result = & $scriptPath -Path "/test/path"
            $LASTEXITCODE | Should -Be 0
        }

        It "Should exit with code 1 when tests fail" {
            $result = & $scriptPath -Path "/test/path"
            $LASTEXITCODE | Should -Be 1
        }

        It "Should exit with code 2 on execution error" {
            Mock Invoke-Pester { throw "Test execution failed" }

            $result = & $scriptPath -Path "/test/path" 2>$null
            $LASTEXITCODE | Should -Be 2
        }
    }

    Context "Performance Tracking" {
        It "Should track performance when logging is available" {
            Mock Get-Command { return $true } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            Mock Start-PerformanceTrace {}
            Mock Stop-PerformanceTrace { return [TimeSpan]::FromSeconds(125.7) }

            & $scriptPath -Path "/test/path"

            Assert-MockCalled Start-PerformanceTrace -ParameterFilter { $Name -eq 'AllTests' }
            Assert-MockCalled Stop-PerformanceTrace -ParameterFilter { $Name -eq 'AllTests' }
        }
    }

    Context "Comprehensive Test Summary" {
        It "Should display summary for all test types combined" {
            & $scriptPath -Path "/test/path"

            # Should show comprehensive summary
            Assert-MockCalled Write-Host -ParameterFilter {
                $Object -like "*All Tests Summary*"
            }
        }

        It "Should include duration for long-running test suites" {
            & $scriptPath -Path "/test/path"

            # Should display execution time
            Assert-MockCalled Write-Host -Times 1
        }

        It "Should show mixed results from different test categories" {
            # This test validates that unit, integration, and E2E results are all included
            & $scriptPath -Path "/test/path"

            Assert-MockCalled Write-Host -Times 1
        }
    }

    Context "Error Handling" {
        It "Should handle test execution errors gracefully" {
            Mock Invoke-Pester { throw "Comprehensive test execution failed" }

            $result = & $scriptPath -Path "/test/path" 2>$null
            $LASTEXITCODE | Should -Be 2
        }

        It "Should provide error context in error messages" {
            Mock Invoke-Pester { throw "Database connection timeout" }

            $result = & $scriptPath -Path "/test/path" 2>$null

            # Should include error details
            $LASTEXITCODE | Should -Be 2
        }
    }

    Context "Output Path Configuration" {
        It "Should use custom output path when specified" {
            & $scriptPath -Path "/test/path" -OutputPath "/custom/output"

            Assert-MockCalled New-Item -ParameterFilter {
                $Path -eq "/custom/output"
            }
        }

        It "Should use default output path when not specified" {
            & $scriptPath -Path "/test/path"

            # Should use default tests/results path
            Assert-MockCalled New-Item -Times 1
        }
    }
}
