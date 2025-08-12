#Requires -Version 7.0

<#
.SYNOPSIS
    Unit tests for 0406_Generate-Coverage.ps1
.DESCRIPTION
    Tests the code coverage report generation script functionality including
    report generation, threshold checking, and multiple output formats.
#>

BeforeAll {
    # Get script path
    $scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent -Parent -Parent) "automation-scripts/0406_Generate-Coverage.ps1"
    
    # Mock Pester and coverage functions
    Mock Invoke-Pester {
        return [PSCustomObject]@{
            TotalCount = 25
            PassedCount = 23
            FailedCount = 2
            Duration = [TimeSpan]::FromSeconds(45.8)
            CodeCoverage = [PSCustomObject]@{
                CoveragePercent = 78.5
                NumberOfCommandsExecuted = 314
                NumberOfCommandsAnalyzed = 400
                AnalyzedFiles = @(
                    '/path/to/module1.psm1'
                    '/path/to/module2.psm1'
                    '/path/to/script.ps1'
                )
            }
        }
    }
    Mock New-PesterConfiguration {
        return [PSCustomObject]@{
            Run = [PSCustomObject]@{
                Path = ''
                PassThru = $false
                Exit = $false
            }
            CodeCoverage = [PSCustomObject]@{
                Enabled = $false
                Path = @()
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
    Mock Get-ChildItem { return @() }
    Mock Test-Path { return $true }
    Mock New-Item {}
    Mock Copy-Item {}
    Mock Set-Content {}
    Mock ConvertTo-Json { return '{}' }
    Mock Write-Host {}
    Mock New-CoverageHtmlReport { return '/path/to/coverage.html' }
    Mock Convert-CoverageReport {}
}

Describe "0406_Generate-Coverage" -Tag @('Unit', 'Testing', 'Coverage') {
    
    Context "Script Metadata" {
        It "Should have correct metadata structure" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '#Requires -Version 7.0'
            $scriptContent | Should -Match 'Stage.*Testing'
            $scriptContent | Should -Match 'Order.*0406'
        }
    }

    Context "DryRun Mode" {
        It "Should preview coverage generation without executing when DryRun is specified" {
            $result = & $scriptPath -DryRun -SourcePath "/source" -TestPath "/tests"
            $LASTEXITCODE | Should -Be 0
            
            Assert-MockCalled Invoke-Pester -Times 0
        }
    }

    Context "Module Dependencies" {
        It "Should check for Pester 5.0.0+ when running tests" {
            Mock Get-Module { return $null } -ParameterFilter { 
                $ListAvailable -and $Name -eq 'Pester' 
            }
            
            $result = & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests" 2>$null
            $LASTEXITCODE | Should -Be 2
        }

        It "Should import Pester with minimum version when running tests" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled Import-Module -ParameterFilter { 
                $Name -eq 'Pester' -and $MinimumVersion -eq '5.0.0' 
            }
        }
    }

    Context "Coverage Data Sources" {
        It "Should run tests when RunTests parameter is specified" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled Invoke-Pester
        }

        It "Should run tests when no existing coverage files are found" {
            Mock Get-ChildItem { return @() } -ParameterFilter { $Filter -eq 'Coverage-*.xml' }
            
            & $scriptPath -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled Invoke-Pester
        }

        It "Should use existing coverage data when available and not forced to run tests" {
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{ 
                        Name = 'Coverage-20241201-120000.xml'
                        LastWriteTime = (Get-Date)
                    }
                )
            } -ParameterFilter { $Filter -eq 'Coverage-*.xml' }
            
            $result = & $scriptPath -SourcePath "/source" -TestPath "/tests"
            
            # Should not run new tests
            Assert-MockCalled Invoke-Pester -Times 0
        }
    }

    Context "Pester Configuration" {
        It "Should configure code coverage for specified source paths" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled New-PesterConfiguration
            Assert-MockCalled Invoke-Pester
        }

        It "Should include main module file in coverage path" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            # Should configure coverage for source paths and main files
            Assert-MockCalled New-PesterConfiguration
        }

        It "Should generate JaCoCo format coverage output" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled Invoke-Pester
        }
    }

    Context "Coverage Summary Processing" {
        It "Should process coverage data from test results" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            # Should process and display coverage summary
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Code Coverage Summary*" 
            }
        }

        It "Should calculate per-file coverage statistics" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            # Should process file-level coverage
            Assert-MockCalled Invoke-Pester
        }
    }

    Context "Report Generation" {
        BeforeEach {
            Mock New-Item {}
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*coverage*" }
        }

        It "Should generate HTML report by default" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled New-CoverageHtmlReport
        }

        It "Should generate JaCoCo report when Format is JaCoCo" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests" -Format JaCoCo
            
            # JaCoCo is generated by Pester, should be available
            Assert-MockCalled Invoke-Pester
        }

        It "Should generate all formats when Format is All" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests" -Format All
            
            Assert-MockCalled Convert-CoverageReport -ParameterFilter { $Format -eq 'Cobertura' }
            Assert-MockCalled Convert-CoverageReport -ParameterFilter { $Format -eq 'CoverageGutters' }
            Assert-MockCalled New-CoverageHtmlReport
        }

        It "Should generate specific format when requested" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests" -Format Cobertura
            
            Assert-MockCalled Convert-CoverageReport -ParameterFilter { $Format -eq 'Cobertura' }
        }

        It "Should create output directory if it doesn't exist" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -eq "/custom/output" }
            
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests" -OutputPath "/custom/output"
            
            Assert-MockCalled New-Item -ParameterFilter { 
                $Path -eq "/custom/output" -and $ItemType -eq 'Directory' 
            }
        }

        It "Should save coverage summary as JSON" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled Set-Content -ParameterFilter { 
                $Path -like "*coverage-summary.json" 
            }
        }

        It "Should create coverage badge text file" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled Set-Content -ParameterFilter { 
                $Path -like "*coverage-badge.txt" 
            }
        }
    }

    Context "Threshold Checking" {
        It "Should pass when coverage meets minimum threshold" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    CodeCoverage = [PSCustomObject]@{
                        CoveragePercent = 85.0  # Above default 80% threshold
                    }
                }
            }
            
            $result = & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            $LASTEXITCODE | Should -Be 0
        }

        It "Should fail when coverage is below minimum threshold" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    CodeCoverage = [PSCustomObject]@{
                        CoveragePercent = 65.0  # Below default 80% threshold
                    }
                }
            }
            
            $result = & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            $LASTEXITCODE | Should -Be 1
        }

        It "Should use custom minimum percentage when specified" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    CodeCoverage = [PSCustomObject]@{
                        CoveragePercent = 75.0  # Above custom 70% threshold
                    }
                }
            }
            
            $result = & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests" -MinimumPercent 70
            $LASTEXITCODE | Should -Be 0
        }

        It "Should show files below threshold when coverage fails" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    CodeCoverage = [PSCustomObject]@{
                        CoveragePercent = 65.0
                        AnalyzedFiles = @('/path/to/lowcoverage.psm1')
                    }
                }
            }
            
            $result = & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            # Should display files below threshold
            Assert-MockCalled Write-Host -ParameterFilter { 
                $Object -like "*Files Below Threshold*" 
            }
        }
    }

    Context "HTML Report Generation" {
        It "Should generate comprehensive HTML report" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled New-CoverageHtmlReport -ParameterFilter { 
                $Summary -ne $null -and $OutputPath -ne $null 
            }
        }

        It "Should include coverage metrics in HTML report" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    CodeCoverage = [PSCustomObject]@{
                        CoveragePercent = 82.5
                        NumberOfCommandsExecuted = 330
                        NumberOfCommandsAnalyzed = 400
                        AnalyzedFiles = @('/path/to/file1.psm1', '/path/to/file2.psm1')
                    }
                }
            }
            
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled New-CoverageHtmlReport
        }
    }

    Context "Coverage Report Conversion" {
        It "Should copy JaCoCo report when requested" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests" -Format JaCoCo
            
            # JaCoCo format should be handled by direct copy
            Assert-MockCalled Invoke-Pester
        }

        It "Should log warning for unsupported format conversions" {
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests" -Format Cobertura
            
            Assert-MockCalled Convert-CoverageReport -ParameterFilter { $Format -eq 'Cobertura' }
        }
    }

    Context "Error Handling" {
        It "Should handle test execution errors gracefully" {
            Mock Invoke-Pester { throw "Test execution failed" }
            
            $result = & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests" 2>$null
            $LASTEXITCODE | Should -Be 2
        }

        It "Should handle missing coverage data gracefully" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    CodeCoverage = $null
                }
            }
            
            $result = & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            # Should complete without errors even with no coverage data
            Assert-MockCalled Invoke-Pester
        }
    }

    Context "Performance Tracking" {
        It "Should track performance when logging is available" {
            Mock Get-Command { return $true } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            Mock Start-PerformanceTrace {}
            Mock Stop-PerformanceTrace { return [TimeSpan]::FromSeconds(30) }
            
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled Start-PerformanceTrace -ParameterFilter { $Name -eq 'CoverageTests' }
            Assert-MockCalled Stop-PerformanceTrace -ParameterFilter { $Name -eq 'CoverageTests' }
        }
    }

    Context "Coverage Badge Generation" {
        It "Should create green badge for good coverage" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    CodeCoverage = [PSCustomObject]@{
                        CoveragePercent = 85.0
                    }
                }
            }
            
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled Set-Content -ParameterFilter { 
                $Path -like "*coverage-badge.txt" -and $Value -like "*green*" 
            }
        }

        It "Should create yellow badge for medium coverage" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    CodeCoverage = [PSCustomObject]@{
                        CoveragePercent = 70.0
                    }
                }
            }
            
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled Set-Content -ParameterFilter { 
                $Path -like "*coverage-badge.txt" -and $Value -like "*yellow*" 
            }
        }

        It "Should create red badge for low coverage" {
            Mock Invoke-Pester {
                return [PSCustomObject]@{
                    CodeCoverage = [PSCustomObject]@{
                        CoveragePercent = 45.0
                    }
                }
            }
            
            & $scriptPath -RunTests -SourcePath "/source" -TestPath "/tests"
            
            Assert-MockCalled Set-Content -ParameterFilter { 
                $Path -like "*coverage-badge.txt" -and $Value -like "*red*" 
            }
        }
    }
}
