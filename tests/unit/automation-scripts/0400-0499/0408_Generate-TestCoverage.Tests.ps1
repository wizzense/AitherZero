#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for 0408_Generate-TestCoverage.ps1
.DESCRIPTION
    Tests the test coverage generation and baseline test creation script.
#>

BeforeAll {
    # Get script path
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0408_Generate-TestCoverage.ps1"

    # Mock functions
    Mock Import-Module {}
    Mock Get-Module {
        return @([PSCustomObject]@{
            Name = 'Pester'
            Version = [Version]'5.3.0'
        })
    }
    Mock Get-ChildItem {
        return @(
            [PSCustomObject]@{
                Name = 'TestModule1'
                FullName = '/path/to/TestModule1'
            }
            [PSCustomObject]@{
                Name = 'TestModule2'
                FullName = '/path/to/TestModule2'
            }
        )
    }
    Mock Test-Path { return $true }
    Mock New-Item {}
    Mock Set-Content {}
    Mock Invoke-Pester {
        return [PSCustomObject]@{
            TotalCount = 15
            PassedCount = 13
            FailedCount = 2
            SkippedCount = 0
            CodeCoverage = [PSCustomObject]@{
                CoveragePercent = 78.5
            }
        }
    }
    Mock New-PesterConfiguration {
        return [PSCustomObject]@{
            Run = [PSCustomObject]@{ Path = '' }
            CodeCoverage = [PSCustomObject]@{
                Enabled = $false
                Path = @()
                OutputFormat = ''
                OutputPath = ''
            }
        }
    }
    Mock Write-Host {}
    Mock New-BaselineTestContent {
        return "# Generated test content for module"
    }
}

Describe "0408_Generate-TestCoverage" -Tag @('Unit', 'Testing', 'Coverage', 'Generation') {

    Context "Script Metadata" {
        It "Should have correct metadata structure" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '#Requires -Version 7.0'
            $scriptContent | Should -Match 'Stage.*Validation'
            $scriptContent | Should -Match 'Description.*Generate test coverage'
        }
    }

    Context "Configuration Loading" {
        It "Should work without configuration parameter" {
            { & $scriptPath } | Should -Not -Throw
        }

        It "Should accept configuration parameter" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        TargetCoverage = 90
                    }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Not -Throw
        }

        It "Should exit early when coverage generation is not enabled" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $false
                    }
                }
            }

            $result = & $scriptPath -Configuration $config
            $LASTEXITCODE | Should -Be 0
        }

        It "Should use default configuration when none provided" {
            $result = & $scriptPath -Configuration @{}
            $LASTEXITCODE | Should -Be 0

            # Should exit early due to no enable flag
            Assert-MockCalled Write-Host -Times 1
        }
    }

    Context "Prerequisites Checking" {
        It "Should check for Pester availability" {
            Mock Get-Module { return $null } -ParameterFilter {
                $ListAvailable -and $Name -eq 'Pester'
            }

            $config = @{
                Testing = @{
                    CoverageGeneration = @{ Enable = $true }
                }
            }

            $result = & $scriptPath -Configuration $config 2>$null
            $LASTEXITCODE | Should -Be 1
        }

        It "Should import Pester with minimum version" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{ Enable = $true }
                }
            }

            & $scriptPath -Configuration $config

            Assert-MockCalled Import-Module -ParameterFilter {
                $Name -eq 'Pester' -and $MinimumVersion -eq '5.0'
            }
        }

        It "Should create output directory if it doesn't exist" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*tests/generated*" }

            $config = @{
                Testing = @{
                    CoverageGeneration = @{ Enable = $true }
                }
            }

            & $scriptPath -Configuration $config

            Assert-MockCalled New-Item -ParameterFilter {
                $ItemType -eq 'Directory'
            }
        }
    }

    Context "Module Discovery" {
        It "Should discover modules in domains directory" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{ Enable = $true }
                }
            }

            & $scriptPath -Configuration $config

            Assert-MockCalled Get-ChildItem -ParameterFilter {
                $Directory -eq $true -and $Recurse -eq $true
            }
        }

        It "Should filter modules by include list when provided" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        IncludeModules = @('TestModule1')
                    }
                }
            }

            & $scriptPath -Configuration $config

            # Should process modules but filter them
            Assert-MockCalled Get-ChildItem
        }

        It "Should exclude modules from exclude list when provided" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        ExcludeModules = @('TestModule2')
                    }
                }
            }

            & $scriptPath -Configuration $config

            # Should process modules but exclude specified ones
            Assert-MockCalled Get-ChildItem
        }
    }

    Context "Baseline Test Generation" {
        BeforeEach {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*Generated.Tests.ps1" }
        }

        It "Should generate baseline tests when enabled" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        GenerateBaseline = $true
                    }
                }
            }

            & $scriptPath -Configuration $config

            Assert-MockCalled Set-Content -ParameterFilter {
                $Path -like "*Generated.Tests.ps1"
            }
        }

        It "Should skip baseline generation when disabled" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        GenerateBaseline = $false
                    }
                }
            }

            & $scriptPath -Configuration $config

            Assert-MockCalled Set-Content -Times 0 -ParameterFilter {
                $Path -like "*Generated.Tests.ps1"
            }
        }

        It "Should skip existing test files" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*Generated.Tests.ps1" }

            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        GenerateBaseline = $true
                    }
                }
            }

            & $scriptPath -Configuration $config

            # Should skip generating files that already exist
            Assert-MockCalled Set-Content -Times 0 -ParameterFilter {
                $Path -like "*Generated.Tests.ps1"
            }
        }

        It "Should generate test content using helper function" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        GenerateBaseline = $true
                    }
                }
            }

            & $scriptPath -Configuration $config

            Assert-MockCalled New-BaselineTestContent -Times 2  # For 2 mocked modules
        }

        It "Should handle test generation errors gracefully" {
            Mock New-BaselineTestContent { throw "Test generation failed" }

            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        GenerateBaseline = $true
                    }
                }
            }

            { & $scriptPath -Configuration $config } | Should -Not -Throw

            # Should continue despite errors
            Assert-MockCalled Write-Host -Times 1
        }
    }

    Context "Coverage Analysis" {
        It "Should run coverage analysis when enabled" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        RunCoverageAnalysis = $true
                    }
                }
            }

            & $scriptPath -Configuration $config

            Assert-MockCalled Invoke-Pester
        }

        It "Should skip coverage analysis when disabled" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        RunCoverageAnalysis = $false
                    }
                }
            }

            & $scriptPath -Configuration $config

            Assert-MockCalled Invoke-Pester -Times 0
        }

        It "Should configure Pester for coverage analysis" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        RunCoverageAnalysis = $true
                    }
                }
            }

            & $scriptPath -Configuration $config

            Assert-MockCalled New-PesterConfiguration
        }

        It "Should report test results" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        RunCoverageAnalysis = $true
                        TargetCoverage = 80
                    }
                }
            }

            & $scriptPath -Configuration $config

            # Should display test results
            Assert-MockCalled Write-Host -ParameterFilter {
                $Object -like "*Test Results*"
            }
        }

        It "Should report coverage results" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        RunCoverageAnalysis = $true
                        TargetCoverage = 80
                    }
                }
            }

            & $scriptPath -Configuration $config

            # Should display coverage results
            Assert-MockCalled Write-Host -ParameterFilter {
                $Object -like "*Code Coverage*"
            }
        }

        It "Should indicate when target coverage is achieved" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    TotalCount = 10
                    PassedCount = 10
                    FailedCount = 0
                    SkippedCount = 0
                    CodeCoverage = [PSCustomObject]@{
                        CoveragePercent = 85.0  # Above 80% target
                    }
                }
            }

            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        RunCoverageAnalysis = $true
                        TargetCoverage = 80
                    }
                }
            }

            & $scriptPath -Configuration $config

            Assert-MockCalled Write-Host -ParameterFilter {
                $Object -like "*Target coverage*achieved*"
            }
        }

        It "Should warn when below target coverage" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    TotalCount = 10
                    PassedCount = 8
                    FailedCount = 2
                    SkippedCount = 0
                    CodeCoverage = [PSCustomObject]@{
                        CoveragePercent = 65.0  # Below 80% target
                    }
                }
            }

            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        RunCoverageAnalysis = $true
                        TargetCoverage = 80
                    }
                }
            }

            & $scriptPath -Configuration $config

            Assert-MockCalled Write-Host -ParameterFilter {
                $Object -like "*Below target coverage*"
            }
        }
    }

    Context "HTML Report Generation" {
        It "Should generate HTML report when configured" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        RunCoverageAnalysis = $true
                        GenerateHtmlReport = $true
                    }
                }
            }

            & $scriptPath -Configuration $config

            Assert-MockCalled Write-Host -ParameterFilter {
                $Object -like "*Generating HTML coverage report*"
            }
        }

        It "Should skip HTML report when not configured" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        RunCoverageAnalysis = $true
                        GenerateHtmlReport = $false
                    }
                }
            }

            & $scriptPath -Configuration $config

            Assert-MockCalled Write-Host -Times 0 -ParameterFilter {
                $Object -like "*Generating HTML coverage report*"
            }
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter" {
            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        GenerateBaseline = $true
                    }
                }
            }

            { & $scriptPath -Configuration $config -WhatIf } | Should -Not -Throw

            # Should not actually create files in WhatIf mode
            Assert-MockCalled Set-Content -Times 0
        }
    }

    Context "Error Handling" {
        It "Should handle critical errors gracefully" {
            Mock Import-Module { throw "Module import failed" }

            $config = @{
                Testing = @{
                    CoverageGeneration = @{ Enable = $true }
                }
            }

            $result = & $scriptPath -Configuration $config 2>$null
            $LASTEXITCODE | Should -Be 1
        }

        It "Should provide error details on failure" {
            Mock Invoke-Pester { throw "Pester execution failed" }

            $config = @{
                Testing = @{
                    CoverageGeneration = @{
                        Enable = $true
                        RunCoverageAnalysis = $true
                    }
                }
            }

            $result = & $scriptPath -Configuration $config 2>$null
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Baseline Test Content Generation" {
        It "Should generate proper test structure" {
            $testContent = New-BaselineTestContent -ModulePath "/path/to/module" -ModuleName "TestModule"

            $testContent | Should -Match "BeforeAll"
            $testContent | Should -Match "Describe 'TestModule Module Tests'"
            $testContent | Should -Match "Context 'Module Loading'"
            $testContent | Should -Match "Context 'Function Tests'"
            $testContent | Should -Match "AfterAll"
        }

        It "Should include module import in test content" {
            $testContent = New-BaselineTestContent -ModulePath "/path/to/module" -ModuleName "TestModule"

            $testContent | Should -Match "Import-Module.*Force"
        }

        It "Should test exported functions" {
            $testContent = New-BaselineTestContent -ModulePath "/path/to/module" -ModuleName "TestModule"

            $testContent | Should -Match "exportedFunctions"
            $testContent | Should -Match "Get-Help"
        }
    }
}
