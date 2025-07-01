#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Invoke-SyntaxValidation'
}

Describe 'TestingFramework.Invoke-SyntaxValidation' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
        Mock Import-Module { } -ModuleName $script:ModuleName
        Mock Join-Path { 'C:\project\core-runner' } -ModuleName $script:ModuleName -ParameterFilter {
            $ChildPath -eq 'core-runner'
        }
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'PSScriptAnalyzer Available' {
        BeforeEach {
            Mock Invoke-ScriptAnalyzer {
                @(
                    [PSCustomObject]@{
                        Severity = 'Error'
                        RuleName = 'PSUseApprovedVerbs'
                        Message = 'Use approved verb'
                        ScriptName = 'BadScript.ps1'
                    },
                    [PSCustomObject]@{
                        Severity = 'Warning'
                        RuleName = 'PSAvoidUsingCmdletAliases'
                        Message = 'Avoid aliases'
                        ScriptName = 'Script.ps1'
                    },
                    [PSCustomObject]@{
                        Severity = 'Information'
                        RuleName = 'PSUseDeclaredVarsMoreThanAssignments'
                        Message = 'Variable assigned but not used'
                        ScriptName = 'Script.ps1'
                    }
                )
            } -ModuleName $script:ModuleName
        }
        
        It 'Should log syntax validation start' {
            Invoke-SyntaxValidation
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Syntax validation' -and
                $Message -match 'PowerShell script analysis' -and
                $Level -eq 'INFO'
            }
        }
        
        It 'Should import PSScriptAnalyzer module' {
            Invoke-SyntaxValidation
            
            Should -Invoke Import-Module -ModuleName $script:ModuleName -ParameterFilter {
                $Name -eq 'PSScriptAnalyzer' -and
                $ErrorAction -eq 'Stop'
            }
        }
        
        It 'Should analyze scripts in core-runner directory' {
            Invoke-SyntaxValidation
            
            Should -Invoke Invoke-ScriptAnalyzer -ModuleName $script:ModuleName -ParameterFilter {
                $Path -eq 'C:\project\core-runner' -and
                $Recurse -eq $true
            }
        }
        
        It 'Should count errors and warnings correctly' {
            $result = Invoke-SyntaxValidation
            
            $result.TestsRun | Should -Be 3
            $result.TestsPassed | Should -Be 2  # Total - Errors
            $result.TestsFailed | Should -Be 1  # Errors only
            $result.Warnings | Should -Be 1
            $result.Details | Should -Match '1 errors, 1 warnings'
        }
        
        It 'Should handle no issues found' {
            Mock Invoke-ScriptAnalyzer { @() } -ModuleName $script:ModuleName
            
            $result = Invoke-SyntaxValidation
            
            $result.TestsRun | Should -Be 0
            $result.TestsPassed | Should -Be 0
            $result.TestsFailed | Should -Be 0
            $result.Warnings | Should -Be 0
            $result.Details | Should -Match '0 errors, 0 warnings'
        }
        
        It 'Should pass OutputPath parameter (even if not used)' {
            $result = Invoke-SyntaxValidation -OutputPath 'C:\output'
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It 'Should pass VSCodeIntegration parameter (even if not used)' {
            $result = Invoke-SyntaxValidation -VSCodeIntegration
            
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'PSScriptAnalyzer Not Available' {
        BeforeEach {
            Mock Import-Module { throw "Module not found" } -ModuleName $script:ModuleName -ParameterFilter {
                $Name -eq 'PSScriptAnalyzer'
            }
        }
        
        It 'Should handle missing PSScriptAnalyzer gracefully' {
            { Invoke-SyntaxValidation } | Should -Not -Throw
        }
        
        It 'Should log warning about missing analyzer' {
            Invoke-SyntaxValidation
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'PSScriptAnalyzer not available' -and
                $Level -eq 'WARN'
            }
        }
        
        It 'Should return empty results when analyzer missing' {
            $result = Invoke-SyntaxValidation
            
            $result.TestsRun | Should -Be 0
            $result.TestsPassed | Should -Be 0
            $result.TestsFailed | Should -Be 0
            $result.Message | Should -Be 'PSScriptAnalyzer not available'
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle Invoke-ScriptAnalyzer errors' {
            Mock Import-Module { } -ModuleName $script:ModuleName
            Mock Invoke-ScriptAnalyzer { throw "Analysis failed" } -ModuleName $script:ModuleName
            
            { Invoke-SyntaxValidation } | Should -Not -Throw
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Analysis failed' -and
                $Level -eq 'WARN'
            }
        }
        
        It 'Should continue gracefully with ErrorAction SilentlyContinue' {
            Mock Invoke-ScriptAnalyzer { 
                Write-Error "Some error"
                @()
            } -ModuleName $script:ModuleName
            
            { Invoke-SyntaxValidation } | Should -Not -Throw
        }
    }
    
    Context 'Result Filtering' {
        It 'Should filter only Error severity for failures' {
            Mock Invoke-ScriptAnalyzer {
                @(
                    [PSCustomObject]@{ Severity = 'Error' },
                    [PSCustomObject]@{ Severity = 'Error' },
                    [PSCustomObject]@{ Severity = 'Warning' },
                    [PSCustomObject]@{ Severity = 'Information' }
                )
            } -ModuleName $script:ModuleName
            
            $result = Invoke-SyntaxValidation
            
            $result.TestsFailed | Should -Be 2
        }
        
        It 'Should filter only Warning severity for warnings' {
            Mock Invoke-ScriptAnalyzer {
                @(
                    [PSCustomObject]@{ Severity = 'Warning' },
                    [PSCustomObject]@{ Severity = 'Warning' },
                    [PSCustomObject]@{ Severity = 'Warning' },
                    [PSCustomObject]@{ Severity = 'Information' }
                )
            } -ModuleName $script:ModuleName
            
            $result = Invoke-SyntaxValidation
            
            $result.Warnings | Should -Be 3
        }
    }
}