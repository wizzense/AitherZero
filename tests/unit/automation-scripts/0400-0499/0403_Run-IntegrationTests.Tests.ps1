#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for 0403_Run-IntegrationTests.ps1
.DESCRIPTION
    Tests the integration test execution script functionality including E2E tests,
    environment setup, and module loading.
#>

BeforeAll {
    # Get script path
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0403_Run-IntegrationTests.ps1"
    
    # Mock Pester and other functions
    Mock Invoke-Pester {
        return [PSCustomObject]@{
            TotalCount = 8
            PassedCount = 6
            FailedCount = 2
            SkippedCount = 0
            Duration = [TimeSpan]::FromSeconds(45.2)
            Tests = @(
                [PSCustomObject]@{
                    Tags = @('Critical')
                    Result = 'Failed'
                    Name = 'Critical Integration Test'
                }
            )
            Failed = @(
                [PSCustomObject]@{
                    ExpandedPath = 'Integration.Test.Should.Work'
                    ErrorRecord = [PSCustomObject]@{
                        Exception = [PSCustomObject]@{
                            Message = 'Integration test failure'
                        }
                        TargetObject = 'TestModule'
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
                Parallel = $false
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
        }
    }
    Mock Import-Module {}
    Mock Get-Module { 
        return @([PSCustomObject]@{
            Version = [Version]'5.3.0'
        }) 
    }
    Mock Get-ChildItem { 
        param($Path, $Filter, $Recurse)
        if ($Filter -eq '*.Tests.ps1') {
            return @()
        }
        if ($Filter -eq '*.psm1') {
            return @(
                [PSCustomObject]@{ FullName = '/path/to/module1.psm1'; Name = 'Module1.psm1' }
                [PSCustomObject]@{ FullName = '/path/to/module2.psm1'; Name = 'Module2.psm1' }
            )
        }
        return @()
    }
    Mock Test-Path { return $true }
    Mock New-Item {}
    Mock Remove-Item {}
    Mock Get-Content { return '{"Testing":{"Framework":"Pester","MinVersion":"5.0.0","Parallel":false}}' }
    Mock ConvertFrom-Json { 
        return @{
            Testing = @{
                Framework = 'Pester'
                MinVersion = '5.0.0'
                Parallel = $false
            }
        }
    }
    Mock Set-Content {}
    Mock ConvertTo-Json { return '{}' }
    Mock Write-Host {}
    Mock Join-Path { 
        param($Path, $ChildPath)
        return "$Path/$ChildPath"
    }
}

Describe "0403_Run-IntegrationTests" -Tag @('Unit', 'Testing', 'Integration') {
    
    Context "Script Metadata" {
        It "Should have correct metadata structure" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '#Requires -Version 7.0'
            $scriptContent | Should -Match 'Stage.*Testing'
            $scriptContent | Should -Match 'Order.*0403'
        }
    }

    Context "DryRun Mode" {
        It "Should preview test execution without running tests when DryRun is specified" {
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{ Name = 'Integration1.Tests.ps1' }
                    [PSCustomObject]@{ Name = 'Integration2.Tests.ps1' }
                )
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            $result = & $scriptPath -DryRun -Path "/integration/tests"
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled Invoke-Pester -Times 0
        }
        
        It "Should display E2E inclusion status in DryRun mode" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'E2E.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -DryRun -Path "/integration/tests" -IncludeE2E
            
            # Should check for test files
            Assert-MockCalled Get-ChildItem -ParameterFilter { $Filter -eq '*.Tests.ps1' }
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter without executing tests" {
            { & $scriptPath -WhatIf -Path "/integration/tests" } | Should -Not -Throw
            
            Assert-MockCalled Invoke-Pester -Times 0
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

    Context "Module Loading for Integration Tests" {
        It "Should load all domain modules for integration testing" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Integration.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/integration/tests"
            
            # Should load domain modules
            Assert-MockCalled Get-ChildItem -ParameterFilter { $Filter -eq '*.psm1' }
            Assert-MockCalled Import-Module -Times 2  # For the 2 mocked modules
        }
    }

    Context "Pester Configuration" {
        It "Should configure Pester for integration tests with proper tags" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Integration.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/integration/tests"
            
            Assert-MockCalled New-PesterConfiguration
            Assert-MockCalled Invoke-Pester
        }

        It "Should disable parallel execution for integration tests" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Integration.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/integration/tests"
            
            Assert-MockCalled Invoke-Pester
        }

        It "Should include E2E tests when IncludeE2E is specified" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'E2E.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/integration/tests" -IncludeE2E
            
            Assert-MockCalled Invoke-Pester
        }
    }

    Context "Test Environment Setup" {
        It "Should create test environment directory" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Integration.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/integration/tests"
            
            Assert-MockCalled New-Item -ParameterFilter { 
                $ItemType -eq 'Directory' -and $Path -like "*AitherZero-IntegrationTest-*"
            }
        }

        It "Should set test environment variables" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Integration.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/integration/tests"
            
            # Environment setup happens, but we can't easily test env vars in mocks
            Assert-MockCalled Invoke-Pester
        }

        It "Should cleanup test environment after execution" {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Integration.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/integration/tests"
            
            Assert-MockCalled Remove-Item -ParameterFilter { 
                $Path -like "*AitherZero-IntegrationTest-*" -and $Recurse -eq $true
            }
        }
    }

    Context "Configuration Loading" {
        It "Should load configuration from config.psd1 if available" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*config.psd1" }
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Integration.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/integration/tests"
            
            Assert-MockCalled Get-Content -ParameterFilter { $Path -like "*config.psd1" }
        }

        It "Should use default configuration if config.psd1 not found" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*config.psd1" }
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Integration.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/integration/tests"
            
            # Should still run with defaults
            Assert-MockCalled Invoke-Pester
        }
    }

    Context "Module Dependencies" {
        It "Should check for Pester availability" {
            Mock Get-Module { return $null } -ParameterFilter { 
                $ListAvailable -and $Name -eq 'Pester' 
            }
            
            $result = & $scriptPath -Path "/integration/tests" 2>$null
            $LASTEXITCODE | Should -Be 2
        }

        It "Should require minimum Pester version" {
            Mock Get-Module { 
                return @([PSCustomObject]@{
                    Version = [Version]'4.10.1'
                }) 
            } -ParameterFilter { $ListAvailable -and $Name -eq 'Pester' }
            
            $result = & $scriptPath -Path "/integration/tests" 2>$null
            $LASTEXITCODE | Should -Be 2
        }
    }

    Context "Results Processing" {
        BeforeEach {
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Integration.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
        }

        It "Should save test summary as JSON with extended information" {
            & $scriptPath -Path "/integration/tests"
            
            Assert-MockCalled Set-Content -ParameterFilter { 
                $Path -like "*IntegrationTests-Summary-*.json" 
            }
        }

        It "Should return Pester result when PassThru is specified" {
            $result = & $scriptPath -Path "/integration/tests" -PassThru
            
            $result | Should -Not -BeNullOrEmpty
            $result.TotalCount | Should -Be 8
            $result.PassedCount | Should -Be 6
            $result.FailedCount | Should -Be 2
        }

        It "Should exit with code 0 when all tests pass" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    TotalCount = 5
                    PassedCount = 5
                    FailedCount = 0
                    SkippedCount = 0
                    Duration = [TimeSpan]::FromSeconds(30)
                    Tests = @()
                }
            }
            
            $result = & $scriptPath -Path "/integration/tests"
            $LASTEXITCODE | Should -Be 0
        }

        It "Should exit with code 1 when tests fail" {
            $result = & $scriptPath -Path "/integration/tests"
            $LASTEXITCODE | Should -Be 1
        }

        It "Should detect and report critical test failures" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    TotalCount = 3
                    PassedCount = 2
                    FailedCount = 1
                    SkippedCount = 0
                    Duration = [TimeSpan]::FromSeconds(20)
                    Tests = @(
                        [PSCustomObject]@{
                            Tags = @('Critical')
                            Result = 'Failed'
                            Name = 'Critical Database Connection Test'
                        }
                    )
                }
            }
            
            $result = & $scriptPath -Path "/integration/tests"
            
            # Should detect critical failure
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Error Handling" {
        It "Should handle Pester execution errors gracefully" {
            Mock Invoke-Pester { throw "Integration test execution failed" }
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Integration.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            $result = & $scriptPath -Path "/integration/tests" 2>$null
            $LASTEXITCODE | Should -Be 2
        }

        It "Should cleanup environment even on failure" {
            Mock Invoke-Pester { throw "Test execution failed" }
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Integration.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            $result = & $scriptPath -Path "/integration/tests" 2>$null
            
            # Should still cleanup
            Assert-MockCalled Remove-Item -ParameterFilter { 
                $Path -like "*AitherZero-IntegrationTest-*"
            }
        }
    }

    Context "Test Categorization" {
        It "Should group test results by categories in summary" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    TotalCount = 6
                    PassedCount = 4
                    FailedCount = 2
                    SkippedCount = 0
                    Duration = [TimeSpan]::FromSeconds(40)
                    Tests = @(
                        [PSCustomObject]@{ Tags = @('Integration', 'Database'); Result = 'Passed' }
                        [PSCustomObject]@{ Tags = @('Integration', 'API'); Result = 'Failed' }
                        [PSCustomObject]@{ Tags = @('E2E'); Result = 'Passed' }
                    )
                }
            }
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ Name = 'Integration.Tests.ps1' })
            } -ParameterFilter { $Filter -eq '*.Tests.ps1' }
            
            & $scriptPath -Path "/integration/tests" -IncludeE2E
            
            Assert-MockCalled Set-Content -ParameterFilter { 
                $Path -like "*IntegrationTests-Summary-*.json" 
            }
        }
    }
}
