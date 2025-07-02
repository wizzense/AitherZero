#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Invoke-SequentialTestExecution'
}

Describe 'TestingFramework.Invoke-SequentialTestExecution' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
        Mock Invoke-ModuleTestPhase {
            @{
                ModuleName = $ModuleName
                Phase = $Phase
                TestsRun = 10
                TestsPassed = 9
                TestsFailed = 1
                Duration = 5
                Details = @("Test completed")
            }
        } -ModuleName $script:ModuleName
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require TestPlan parameter' {
            { Invoke-SequentialTestExecution -OutputPath './output' } | Should -Throw
        }
        
        It 'Should require OutputPath parameter' {
            $testPlan = @{ TestPhases = @('Unit'); Modules = @() }
            { Invoke-SequentialTestExecution -TestPlan $testPlan } | Should -Throw
        }
        
        It 'Should accept valid parameters' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @()
                Configuration = @{}
            }
            
            { Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output' } | Should -Not -Throw
        }
    }
    
    Context 'Sequential Execution' {
        It 'Should execute all phases in order' {
            $testPlan = @{
                TestPhases = @('Environment', 'Unit', 'Integration')
                Modules = @(
                    @{ Name = 'Module1'; TestPath = 'C:\Tests\Module1' }
                )
                Configuration = @{}
            }
            
            $callOrder = @()
            Mock Invoke-ModuleTestPhase {
                $callOrder += "$ModuleName-$Phase"
                @{ Success = $true; Module = $ModuleName; Phase = $Phase }
            } -ModuleName $script:ModuleName
            
            Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Invoke-ModuleTestPhase -ModuleName $script:ModuleName -Times 3
        }
        
        It 'Should execute all modules for each phase' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(
                    @{ Name = 'Module1'; TestPath = 'C:\Tests\Module1' },
                    @{ Name = 'Module2'; TestPath = 'C:\Tests\Module2' },
                    @{ Name = 'Module3'; TestPath = 'C:\Tests\Module3' }
                )
                Configuration = @{}
            }
            
            Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Invoke-ModuleTestPhase -ModuleName $script:ModuleName -Times 3
        }
        
        It 'Should pass correct parameters to Invoke-ModuleTestPhase' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(
                    @{ Name = 'TestModule'; TestPath = 'C:\Tests\TestModule' }
                )
                Configuration = @{ Verbosity = 'Detailed' }
            }
            
            Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Invoke-ModuleTestPhase -ModuleName $script:ModuleName -ParameterFilter {
                $ModuleName -eq 'TestModule' -and
                $Phase -eq 'Unit' -and
                $TestPath -eq 'C:\Tests\TestModule' -and
                $Configuration.Verbosity -eq 'Detailed'
            }
        }
    }
    
    Context 'Result Collection' {
        It 'Should collect results from all executions' {
            $testPlan = @{
                TestPhases = @('Unit', 'Integration')
                Modules = @(
                    @{ Name = 'Module1'; TestPath = 'C:\Tests\Module1' },
                    @{ Name = 'Module2'; TestPath = 'C:\Tests\Module2' }
                )
                Configuration = @{}
            }
            
            $results = Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output'
            
            $results | Should -HaveCount 4  # 2 modules × 2 phases
            $results | ForEach-Object { $_.Success | Should -Be $true }
        }
        
        It 'Should include success status in results' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(@{ Name = 'Module1'; TestPath = 'C:\Tests' })
                Configuration = @{}
            }
            
            Mock Invoke-ModuleTestPhase {
                @{ TestsPassed = 10; TestsFailed = 0 }
            } -ModuleName $script:ModuleName
            
            $results = Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output'
            
            $results[0].Success | Should -Be $true
            $results[0].Module | Should -Be 'Module1'
            $results[0].Phase | Should -Be 'Unit'
        }
        
        It 'Should calculate duration for each test' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(@{ Name = 'Module1'; TestPath = 'C:\Tests' })
                Configuration = @{}
            }
            
            Mock Start-Sleep { } -ModuleName $script:ModuleName
            
            $results = Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output'
            
            $results[0].Duration | Should -BeOfType [double]
            $results[0].Duration | Should -BeGreaterThan 0
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle test phase failures' {
            $testPlan = @{
                TestPhases = @('Unit', 'Integration')
                Modules = @(@{ Name = 'FailModule'; TestPath = 'C:\Tests' })
                Configuration = @{}
            }
            
            Mock Invoke-ModuleTestPhase {
                if ($Phase -eq 'Unit') {
                    throw "Test failed"
                }
                @{ TestsPassed = 5; TestsFailed = 0 }
            } -ModuleName $script:ModuleName
            
            $results = Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output'
            
            # Should have results for both phases
            $results | Should -HaveCount 2
            
            # First should be failure
            $results[0].Success | Should -Be $false
            $results[0].Error | Should -Match "Test failed"
            
            # Second should succeed (continue after failure)
            $results[1].Success | Should -Be $true
        }
        
        It 'Should stop execution on critical Environment phase failure' {
            $testPlan = @{
                TestPhases = @('Environment', 'Unit')
                Modules = @(@{ Name = 'Module1'; TestPath = 'C:\Tests' })
                Configuration = @{}
            }
            
            Mock Invoke-ModuleTestPhase {
                if ($Phase -eq 'Environment') {
                    throw "Environment setup failed"
                }
                @{ TestsPassed = 5; TestsFailed = 0 }
            } -ModuleName $script:ModuleName
            
            { Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output' } | Should -Throw "Critical environment phase failed"
        }
        
        It 'Should continue with next module after non-critical failure' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(
                    @{ Name = 'FailModule'; TestPath = 'C:\Tests\Fail' },
                    @{ Name = 'PassModule'; TestPath = 'C:\Tests\Pass' }
                )
                Configuration = @{}
            }
            
            Mock Invoke-ModuleTestPhase {
                if ($ModuleName -eq 'FailModule') {
                    throw "Module failed"
                }
                @{ TestsPassed = 5; TestsFailed = 0 }
            } -ModuleName $script:ModuleName
            
            $results = Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output'
            
            $results | Should -HaveCount 2
            $results[0].Success | Should -Be $false
            $results[1].Success | Should -Be $true
        }
    }
    
    Context 'Logging' {
        It 'Should log start of sequential execution' {
            $testPlan = @{
                TestPhases = @()
                Modules = @()
                Configuration = @{}
            }
            
            Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Starting sequential test execution' -and
                $Level -eq 'INFO'
            }
        }
        
        It 'Should log each phase execution' {
            $testPlan = @{
                TestPhases = @('Unit', 'Integration')
                Modules = @(@{ Name = 'Module1'; TestPath = 'C:\Tests' })
                Configuration = @{}
            }
            
            Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Executing test phase: Unit'
            }
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Executing test phase: Integration'
            }
        }
        
        It 'Should log module test execution' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(@{ Name = 'TestModule'; TestPath = 'C:\Tests' })
                Configuration = @{}
            }
            
            Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Testing TestModule - Unit'
            }
        }
        
        It 'Should log successful completion' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(@{ Name = 'Module1'; TestPath = 'C:\Tests' })
                Configuration = @{}
            }
            
            Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Module1 - Unit completed' -and
                $Level -eq 'SUCCESS'
            }
        }
        
        It 'Should log failures' {
            $testPlan = @{
                TestPhases = @('Unit')
                Modules = @(@{ Name = 'FailModule'; TestPath = 'C:\Tests' })
                Configuration = @{}
            }
            
            Mock Invoke-ModuleTestPhase { throw "Test error" } -ModuleName $script:ModuleName
            
            Invoke-SequentialTestExecution -TestPlan $testPlan -OutputPath './output'
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'FailModule - Unit failed: Test error' -and
                $Level -eq 'ERROR'
            }
        }
    }
}