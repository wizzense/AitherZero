#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for 0402_Run-UnitTests.ps1
.DESCRIPTION
    Tests the unit test execution script functionality including Pester configuration,
    coverage analysis, caching, and WhatIf mode.
#>

BeforeAll {
    # Get script path
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0402_Run-UnitTests.ps1"
    
    # Mock Pester and other functions
    Mock Invoke-Pester {
        return [PSCustomObject]@{
            TotalCount = 10
            PassedCount = 8
            FailedCount = 2
            SkippedCount = 0
            Duration = [TimeSpan]::FromSeconds(15.5)
            CodeCoverage = [PSCustomObject]@{
                CoveragePercent = 85.5
                NumberOfCommandsExecuted = 342
                NumberOfCommandsAnalyzed = 400
            }
            Failed = @(
                [PSCustomObject]@{
                    ExpandedPath = 'Test.Should.Fail'
                    ErrorRecord = [PSCustomObject]@{
                        Exception = [PSCustomObject]@{
                            Message = 'Test failure message'
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
    Mock Get-ChildItem { return @() }
    Mock Test-Path { return $true }
    Mock New-Item {}
    Mock Get-Content { return '{"Testing":{"Framework":"Pester","MinVersion":"5.0.0","CodeCoverage":{"Enabled":true,"MinimumPercent":80}}}' }
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

Describe "0402_Run-UnitTests" -Tag @('Unit', 'Testing', 'Pester') {
    
    Context "Script Metadata" {
        It "Should have correct metadata structure" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '#Requires -Version 7.0'
            $scriptContent | Should -Match 'Stage.*Testing'
            $scriptContent | Should -Match 'Order.*0402'
        }
    }

    Context "DryRun Mode" {
        It "Should preview test execution without running tests when DryRun is specified" {
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{ Name = 'Test1.Tests.ps1' }
                    [PSCustomObject]@{ Name = 'Test2.Tests.ps1' }
                )
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            $result = & $scriptPath -DryRun -Path "/test/path"
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled Invoke-Pester -Times 0
        }
        
        It "Should list test files in DryRun mode" {
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{ Name = 'Configuration.Tests.ps1' }
                    [PSCustomObject]@{ Name = 'Logging.Tests.ps1' }
                )
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -DryRun -Path "/test/path"
            
            # Should have checked for test files
            Assert-MockCalled Get-ChildItem -ParameterFilter { $Filter -eq '*.Tests.ps1' }
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter without executing tests" {
            { & $scriptPath -WhatIf -Path "/test/path" } | Should -Not -Throw
            
            Assert-MockCalled Invoke-Pester -Times 0
        }
    }

    Context "Test Path Handling" {
        It "Should create test directory if it doesn't exist" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -eq "/nonexistent/path" }
            
            & $scriptPath -Path "/nonexistent/path"
            
            Assert-MockCalled New-Item -ParameterFilter { 
                $Path -eq "/nonexistent/path" -and $ItemType -eq 'Directory' 
            }
        }

        It "Should exit gracefully if no test files found" {
            Mock Get-ChildItem { return @() } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            $result = & $scriptPath -Path "/empty/path"
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Pester Configuration" {
        It "Should configure Pester for unit tests with proper tags" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Test.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled New-PesterConfiguration
            Assert-MockCalled Invoke-Pester
        }

        It "Should enable code coverage by default" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Test.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Invoke-Pester
        }

        It "Should disable code coverage when NoCoverage is specified" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Test.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/test/path" -NoCoverage
            
            Assert-MockCalled Invoke-Pester
        }

        It "Should configure CI mode when CI switch is used" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Test.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/test/path" -CI
            
            Assert-MockCalled Invoke-Pester
        }
    }

    Context "Configuration Loading" {
        It "Should load configuration from config.psd1 if available" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*config.psd1" }
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Test.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Get-Content -ParameterFilter { $Path -like "*config.psd1" }
        }

        It "Should use default configuration if config.psd1 not found" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*config.psd1" }
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Test.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
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
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Test.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Import-Module -ParameterFilter { 
                $Name -eq 'Pester' -and $MinimumVersion -eq '5.0.0' 
            }
        }
    }

    Context "Results Processing" {
        BeforeEach {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Test.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
        }

        It "Should save test summary as JSON" {
            & $scriptPath -Path "/test/path"
            
            Assert-MockCalled Set-Content -ParameterFilter { 
                $Path -like "*UnitTests-Summary-*.json" 
            }
        }

        It "Should return Pester result when PassThru is specified" {
            $result = & $scriptPath -Path "/test/path" -PassThru
            
            $result | Should -Not -BeNullOrEmpty
            $result.TotalCount | Should -Be 10
            $result.PassedCount | Should -Be 8
            $result.FailedCount | Should -Be 2
        }

        It "Should exit with code 0 when all tests pass" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    TotalCount = 5
                    PassedCount = 5
                    FailedCount = 0
                    SkippedCount = 0
                    Duration = [TimeSpan]::FromSeconds(10)
                }
            }
            
            $result = & $scriptPath -Path "/test/path"
            $LASTEXITCODE | Should -Be 0
        }

        It "Should exit with code 1 when tests fail" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    TotalCount = 5
                    PassedCount = 3
                    FailedCount = 2
                    SkippedCount = 0
                    Duration = [TimeSpan]::FromSeconds(10)
                }
            }
            
            $result = & $scriptPath -Path "/test/path"
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Cache Support" {
        It "Should use cached results when UseCache is enabled and results are fresh" {
            Mock Test-ShouldRunTests {
                return @{
                    ShouldRun = $false
                    Reason = 'Cached results are fresh'
                    LastRun = @{
                        Summary = @{
                            TotalTests = 15
                            Passed = 13
                            Failed = 2
                            Duration = 25.5
                        }
                        Timestamp = (Get-Date).ToString()
                    }
                }
            }
            
            $result = & $scriptPath -Path "/test/path" -UseCache
            $LASTEXITCODE | Should -Be 1  # Based on 2 failed tests
            
            Assert-MockCalled Invoke-Pester -Times 0
        }

        It "Should run tests when ForceRun is specified even with cache enabled" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Test.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/test/path" -UseCache -ForceRun
            
            Assert-MockCalled Invoke-Pester -Times 1
        }
    }

    Context "Error Handling" {
        It "Should handle Pester execution errors gracefully" {
            Mock Invoke-Pester { throw "Pester execution failed" }
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Test.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            $result = & $scriptPath -Path "/test/path" 2>$null
            $LASTEXITCODE | Should -Be 2
        }
    }

    Context "Coverage Reporting" {
        It "Should display coverage summary when coverage is enabled" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Test.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/test/path"
            
            # Should display coverage results
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Code Coverage*" 
            } -Times 1
        }

        It "Should warn when coverage is below threshold" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    TotalCount = 10
                    PassedCount = 10
                    FailedCount = 0
                    SkippedCount = 0
                    Duration = [TimeSpan]::FromSeconds(15.5)
                    CodeCoverage = [PSCustomObject]@{
                        CoveragePercent = 65.0  # Below 80% threshold
                    }
                }
            }
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Test.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/test/path"
            
            # Should log warning about low coverage
            Assert-MockCalled Write-Host -Times 1
        }
    }
}
