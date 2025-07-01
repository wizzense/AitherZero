#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'New-TestReport'
}

Describe 'TestingFramework.New-TestReport' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
        Mock Out-File { } -ModuleName $script:ModuleName
        Mock ConvertTo-Json { '{"test": "data"}' } -ModuleName $script:ModuleName
        Mock New-HTMLTestReport { '<html>Test Report</html>' } -ModuleName $script:ModuleName
        Mock New-LogTestReport { 'Test Summary Log' } -ModuleName $script:ModuleName
        
        # Create test output directory
        $script:TestOutputPath = Join-Path $TestDrive 'test-output'
        New-Item -Path $script:TestOutputPath -ItemType Directory -Force | Out-Null
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require Results parameter' {
            { New-TestReport -OutputPath $script:TestOutputPath -TestSuite 'All' } | Should -Throw
        }
        
        It 'Should require OutputPath parameter' {
            { New-TestReport -Results @() -TestSuite 'All' } | Should -Throw
        }
        
        It 'Should require TestSuite parameter' {
            { New-TestReport -Results @() -OutputPath $script:TestOutputPath } | Should -Throw
        }
        
        It 'Should accept empty Results array' {
            { New-TestReport -Results @() -OutputPath $script:TestOutputPath -TestSuite 'All' } | Should -Not -Throw
        }
    }
    
    Context 'Summary Generation' {
        It 'Should generate correct summary statistics' {
            $testResults = @(
                @{
                    Success = $true
                    Module = 'Module1'
                    Phase = 'Unit'
                    TestsRun = 10
                    TestsPassed = 9
                    TestsFailed = 1
                    Duration = 5.5
                },
                @{
                    Success = $false
                    Module = 'Module2'
                    Phase = 'Unit'
                    TestsRun = 5
                    TestsPassed = 2
                    TestsFailed = 3
                    Duration = 3.2
                }
            )
            
            $capturedSummary = $null
            Mock New-HTMLTestReport {
                $capturedSummary = $Summary
                '<html></html>'
            } -ModuleName $script:ModuleName
            
            New-TestReport -Results $testResults -OutputPath $script:TestOutputPath -TestSuite 'Unit'
            
            $capturedSummary | Should -Not -BeNullOrEmpty
            $capturedSummary.TestSuite | Should -Be 'Unit'
            $capturedSummary.TotalModules | Should -Be 2
            $capturedSummary.TotalTests | Should -Be 15
            $capturedSummary.TotalPassed | Should -Be 11
            $capturedSummary.TotalFailed | Should -Be 4
            $capturedSummary.SuccessfulModules | Should -Be 1
            $capturedSummary.FailedModules | Should -Be 1
            $capturedSummary.TotalDuration | Should -Be 8.7
        }
        
        It 'Should calculate success rate correctly' {
            $testResults = @(
                @{
                    Success = $true
                    Module = 'Module1'
                    TestsRun = 10
                    TestsPassed = 8
                    TestsFailed = 2
                    Duration = 1
                }
            )
            
            $capturedSummary = $null
            Mock New-HTMLTestReport {
                $capturedSummary = $Summary
                '<html></html>'
            } -ModuleName $script:ModuleName
            
            New-TestReport -Results $testResults -OutputPath $script:TestOutputPath -TestSuite 'All'
            
            $capturedSummary.SuccessRate | Should -Be 80
        }
        
        It 'Should handle zero tests gracefully' {
            $testResults = @(
                @{
                    Success = $true
                    Module = 'Module1'
                    TestsRun = 0
                    TestsPassed = 0
                    TestsFailed = 0
                    Duration = 0
                }
            )
            
            $capturedSummary = $null
            Mock New-HTMLTestReport {
                $capturedSummary = $Summary
                '<html></html>'
            } -ModuleName $script:ModuleName
            
            New-TestReport -Results $testResults -OutputPath $script:TestOutputPath -TestSuite 'All'
            
            $capturedSummary.SuccessRate | Should -Be 0
        }
    }
    
    Context 'Report Generation' {
        BeforeEach {
            $script:TestResults = @(
                @{
                    Success = $true
                    Module = 'TestModule'
                    Phase = 'Unit'
                    TestsRun = 5
                    TestsPassed = 5
                    TestsFailed = 0
                    Duration = 2.5
                }
            )
        }
        
        It 'Should create reports directory' {
            $reportDir = Join-Path $script:TestOutputPath 'reports'
            
            New-TestReport -Results $script:TestResults -OutputPath $script:TestOutputPath -TestSuite 'All'
            
            # Check that Out-File was called with a path in the reports directory
            Should -Invoke Out-File -ModuleName $script:ModuleName -ParameterFilter {
                $FilePath -like "*reports*"
            }
        }
        
        It 'Should generate JSON report' {
            Mock Get-Date { [DateTime]::new(2025, 1, 15, 10, 30, 0) } -ModuleName $script:ModuleName
            
            New-TestReport -Results $script:TestResults -OutputPath $script:TestOutputPath -TestSuite 'All'
            
            Should -Invoke ConvertTo-Json -ModuleName $script:ModuleName -ParameterFilter {
                $InputObject.Summary -ne $null -and
                $InputObject.Results -ne $null -and
                $Depth -eq 10
            }
            
            Should -Invoke Out-File -ModuleName $script:ModuleName -ParameterFilter {
                $FilePath -match 'test-report-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.json$' -and
                $Encoding -eq 'UTF8'
            }
        }
        
        It 'Should generate HTML report' {
            New-TestReport -Results $script:TestResults -OutputPath $script:TestOutputPath -TestSuite 'All'
            
            Should -Invoke New-HTMLTestReport -ModuleName $script:ModuleName -ParameterFilter {
                $Summary -ne $null -and
                $Results -ne $null
            }
            
            Should -Invoke Out-File -ModuleName $script:ModuleName -ParameterFilter {
                $FilePath -match 'test-report-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.html$'
            }
        }
        
        It 'Should generate log report' {
            New-TestReport -Results $script:TestResults -OutputPath $script:TestOutputPath -TestSuite 'All'
            
            Should -Invoke New-LogTestReport -ModuleName $script:ModuleName -ParameterFilter {
                $Summary -ne $null -and
                $Results -ne $null
            }
            
            Should -Invoke Out-File -ModuleName $script:ModuleName -ParameterFilter {
                $FilePath -match 'test-summary-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.log$'
            }
        }
    }
    
    Context 'Return Value' {
        It 'Should return HTML report path' {
            Mock Get-Date { [DateTime]::new(2025, 1, 15, 10, 30, 0) } -ModuleName $script:ModuleName
            
            $result = New-TestReport -Results @() -OutputPath $script:TestOutputPath -TestSuite 'All'
            
            $result | Should -Match 'test-report-2025-01-15_10-30-00\.html$'
        }
    }
    
    Context 'Logging' {
        It 'Should log report generation' {
            New-TestReport -Results @() -OutputPath $script:TestOutputPath -TestSuite 'All'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Reports generated:' -and
                $Level -eq 'SUCCESS'
            }
        }
        
        It 'Should log each report type' {
            New-TestReport -Results @() -OutputPath $script:TestOutputPath -TestSuite 'All'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'JSON:' -and $Level -eq 'INFO'
            }
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'HTML:' -and $Level -eq 'INFO'
            }
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Log:' -and $Level -eq 'INFO'
            }
        }
    }
    
    Context 'Timestamp Handling' {
        It 'Should use consistent timestamp for all reports' {
            $capturedPaths = @()
            Mock Out-File {
                $capturedPaths += $FilePath
            } -ModuleName $script:ModuleName
            
            New-TestReport -Results @() -OutputPath $script:TestOutputPath -TestSuite 'All'
            
            # Extract timestamps from paths
            $timestamps = $capturedPaths | ForEach-Object {
                if ($_ -match '\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}') {
                    $matches[0]
                }
            }
            
            # All timestamps should be the same
            $timestamps | Select-Object -Unique | Should -HaveCount 1
        }
    }
}