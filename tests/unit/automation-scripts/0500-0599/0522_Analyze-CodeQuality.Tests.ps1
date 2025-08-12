#Requires -Version 7.0

Describe "0522_Analyze-CodeQuality" {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0522_Analyze-CodeQuality.ps1"
        $script:TempOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) "analysis"
        
        # Mock external dependencies
        Mock -CommandName Import-Module -MockWith { }
        Mock -CommandName Write-AnalysisLog -MockWith { param($Message, $Component, $Level) Write-Host "[$Level] $Message" }
        Mock -CommandName Initialize-TechDebtAnalysis -MockWith { }
        Mock -CommandName Save-AnalysisResults -MockWith { "analysis-results.json" }
        Mock -CommandName Write-Host -MockWith { }
        
        # Script-specific mocks
        if ("0522_Analyze-CodeQuality" -eq "0522_Analyze-CodeQuality") {
            Mock -CommandName Get-FilesToAnalyze -MockWith { 
                @(@{ FullName = "TestScript.ps1" })
            }
            Mock -CommandName Get-Content -MockWith {
                @("# TODO: Implement feature", "# FIXME: Bug fix needed", "function Test-Function { }")
            }
        } elseif ("0522_Analyze-CodeQuality" -eq "0523_Analyze-SecurityIssues") {
            Mock -CommandName Get-FilesToAnalyze -MockWith { 
                @(@{ FullName = "TestScript.ps1" })
            }
            Mock -CommandName Get-Content -MockWith {
                @("param([string]$Password)", "Invoke-Expression $userInput", "$cred = 'admin:password123'")
            }
        } elseif ("0522_Analyze-CodeQuality" -eq "0524_Generate-TechDebtReport") {
            Mock -CommandName Invoke-AnalysisIfNeeded -MockWith { }
            Mock -CommandName Merge-AnalysisResults -MockWith {
                @{
                    Analyses = @{
                        ConfigurationUsage = @{ UsagePercentage = 75; UnusedSettings = @("test.setting") }
                        DocumentationCoverage = @{ OverallCoveragePercentage = 80 }
                        CodeQuality = @{ Summary = @{ QualityScore = 70 }; TODOs = @(); FIXMEs = @(); HACKs = @() }
                        SecurityIssues = @{ SecurityScore = 90; Summary = @{ Critical = 0; High = 1 } }
                    }
                }
            }
            Mock -CommandName Export-HTMLReport -MockWith { }
            Mock -CommandName Export-MarkdownReport -MockWith { }
            Mock -CommandName Set-Content -MockWith { }
            Mock -CommandName ConvertTo-Json -MockWith { "mocked json" }
        }
    }

    Context "Parameter Validation" {
        It "Should accept basic parameters" {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
        
        if ("0522_Analyze-CodeQuality" -eq "0524_Generate-TechDebtReport") {
            It "Should accept Format parameter" {
                { & $script:ScriptPath -Format @("HTML", "JSON") -WhatIf } | Should -Not -Throw
            }
            
            It "Should accept RunAnalysis switch" {
                { & $script:ScriptPath -RunAnalysis -WhatIf } | Should -Not -Throw
            }
        } else {
            It "Should accept OutputPath parameter" {
                { & $script:ScriptPath -OutputPath $script:TempOutputPath -WhatIf } | Should -Not -Throw
            }
            
            It "Should accept UseCache switch" {
                { & $script:ScriptPath -UseCache -WhatIf } | Should -Not -Throw
            }
        }
    }

    Context "Analysis Execution" {
        It "Should execute analysis successfully" {
            $result = & $script:ScriptPath -WhatIf 2>&1
            $result | Should -Not -BeNullOrEmpty
        }
        
        if ("0522_Analyze-CodeQuality" -ne "0524_Generate-TechDebtReport") {
            It "Should initialize tech debt analysis" {
                & $script:ScriptPath -OutputPath $script:TempOutputPath -WhatIf 2>&1
                Should -Not -Invoke Initialize-TechDebtAnalysis # WhatIf should not invoke
            }
        }
    }

    Context "WhatIf Support" {
        It "Should show preview with WhatIf" {
            $result = & $script:ScriptPath -WhatIf 2>&1
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should not save results with WhatIf" {
            & $script:ScriptPath -WhatIf 2>&1
            Should -Not -Invoke Save-AnalysisResults
        }
    }

    Context "Error Handling" {
        It "Should handle module import failures" {
            Mock -CommandName Import-Module -MockWith { throw "Module not found" }
            
            $result = & $script:ScriptPath -WhatIf 2>&1
            # Should complete even with import failures in WhatIf mode
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
