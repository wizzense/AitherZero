#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Export-VSCodeTestResults'
}

Describe 'TestingFramework.Export-VSCodeTestResults' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
        Mock ConvertTo-Json { '{"test": "data"}' } -ModuleName $script:ModuleName
        Mock Out-File { } -ModuleName $script:ModuleName
        
        # Create test output directory
        $script:TestOutputPath = Join-Path $TestDrive 'test-output'
        New-Item -Path $script:TestOutputPath -ItemType Directory -Force | Out-Null
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require Results parameter' {
            { Export-VSCodeTestResults -OutputPath $script:TestOutputPath } | Should -Throw
        }
        
        It 'Should require OutputPath parameter' {
            { Export-VSCodeTestResults -Results @() } | Should -Throw
        }
        
        It 'Should accept empty Results array' {
            { Export-VSCodeTestResults -Results @() -OutputPath $script:TestOutputPath } | Should -Not -Throw
        }
    }
    
    Context 'VS Code Format Generation' {
        It 'Should create VS Code compatible output structure' {
            $testResults = @(
                @{
                    Module = 'TestModule1'
                    Phase = 'Unit'
                    Success = $true
                    TestsRun = 10
                    TestsPassed = 9
                    TestsFailed = 1
                    Duration = 5.5
                    Details = @('Test detail 1', 'Test detail 2')
                    Error = $null
                }
            )
            
            $capturedObject = $null
            Mock ConvertTo-Json {
                $capturedObject = $InputObject
                '{"converted": "json"}'
            } -ModuleName $script:ModuleName
            
            Export-VSCodeTestResults -Results $testResults -OutputPath $script:TestOutputPath
            
            $capturedObject | Should -Not -BeNullOrEmpty
            $capturedObject.version | Should -Be '1.0'
            $capturedObject.timestamp | Should -Match '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'
            $capturedObject.results | Should -HaveCount 1
            
            $firstResult = $capturedObject.results[0]
            $firstResult.module | Should -Be 'TestModule1'
            $firstResult.phase | Should -Be 'Unit'
            $firstResult.success | Should -Be $true
            $firstResult.testsRun | Should -Be 10
            $firstResult.testsPassed | Should -Be 9
            $firstResult.testsFailed | Should -Be 1
            $firstResult.duration | Should -Be 5.5
            $firstResult.details | Should -HaveCount 2
            $firstResult.error | Should -Be $null
        }
        
        It 'Should handle multiple results' {
            $testResults = @(
                @{
                    Module = 'Module1'
                    Phase = 'Unit'
                    Success = $true
                    TestsRun = 5
                    TestsPassed = 5
                    TestsFailed = 0
                    Duration = 2.1
                    Details = @()
                    Error = $null
                },
                @{
                    Module = 'Module2'
                    Phase = 'Integration'
                    Success = $false
                    TestsRun = 3
                    TestsPassed = 1
                    TestsFailed = 2
                    Duration = 4.3
                    Details = @('Failed test X')
                    Error = 'Test failure'
                }
            )
            
            $capturedObject = $null
            Mock ConvertTo-Json {
                $capturedObject = $InputObject
                '{"converted": "json"}'
            } -ModuleName $script:ModuleName
            
            Export-VSCodeTestResults -Results $testResults -OutputPath $script:TestOutputPath
            
            $capturedObject.results | Should -HaveCount 2
            $capturedObject.results[1].error | Should -Be 'Test failure'
        }
    }
    
    Context 'File Output' {
        It 'Should write to vscode-test-results.json file' {
            Export-VSCodeTestResults -Results @() -OutputPath $script:TestOutputPath
            
            Should -Invoke Out-File -ModuleName $script:ModuleName -ParameterFilter {
                $FilePath -eq (Join-Path $script:TestOutputPath 'vscode-test-results.json') -and
                $Encoding -eq 'UTF8'
            }
        }
        
        It 'Should convert to JSON with correct depth' {
            Export-VSCodeTestResults -Results @() -OutputPath $script:TestOutputPath
            
            Should -Invoke ConvertTo-Json -ModuleName $script:ModuleName -ParameterFilter {
                $Depth -eq 10
            }
        }
        
        It 'Should create output directory if it does not exist' {
            $nonExistentPath = Join-Path $TestDrive 'non-existent-dir'
            
            # Mock Test-Path to return false
            Mock Test-Path { $false } -ModuleName $script:ModuleName -ParameterFilter {
                $Path -eq $nonExistentPath
            }
            
            # Mock New-Item to track directory creation
            Mock New-Item { } -ModuleName $script:ModuleName
            
            Export-VSCodeTestResults -Results @() -OutputPath $nonExistentPath
            
            Should -Invoke New-Item -ModuleName $script:ModuleName -ParameterFilter {
                $Path -eq $nonExistentPath -and
                $ItemType -eq 'Directory'
            }
        }
    }
    
    Context 'Timestamp Handling' {
        It 'Should use ISO 8601 timestamp format' {
            Mock Get-Date { [DateTime]::new(2025, 1, 15, 10, 30, 45) } -ModuleName $script:ModuleName
            
            $capturedObject = $null
            Mock ConvertTo-Json {
                $capturedObject = $InputObject
                '{"converted": "json"}'
            } -ModuleName $script:ModuleName
            
            Export-VSCodeTestResults -Results @() -OutputPath $script:TestOutputPath
            
            $capturedObject.timestamp | Should -Be '2025-01-15T10:30:45.0000000'
        }
    }
    
    Context 'Logging' {
        It 'Should log VS Code export completion' {
            Export-VSCodeTestResults -Results @() -OutputPath $script:TestOutputPath
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'VS Code test results exported' -and
                $Level -eq 'INFO'
            }
        }
        
        It 'Should include file path in log message' {
            Export-VSCodeTestResults -Results @() -OutputPath $script:TestOutputPath
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'vscode-test-results\.json'
            }
        }
    }
    
    Context 'Edge Cases' {
        It 'Should handle results with null values' {
            $testResults = @(
                @{
                    Module = 'TestModule'
                    Phase = 'Unit'
                    Success = $true
                    TestsRun = 5
                    TestsPassed = 5
                    TestsFailed = 0
                    Duration = 1.0
                    Details = $null
                    Error = $null
                }
            )
            
            { Export-VSCodeTestResults -Results $testResults -OutputPath $script:TestOutputPath } | Should -Not -Throw
        }
        
        It 'Should handle results with empty details array' {
            $testResults = @(
                @{
                    Module = 'TestModule'
                    Phase = 'Unit'
                    Success = $true
                    TestsRun = 5
                    TestsPassed = 5
                    TestsFailed = 0
                    Duration = 1.0
                    Details = @()
                    Error = $null
                }
            )
            
            { Export-VSCodeTestResults -Results $testResults -OutputPath $script:TestOutputPath } | Should -Not -Throw
        }
    }
}