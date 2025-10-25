#Requires -Version 7.0

Describe "0521_Analyze-DocumentationCoverage" {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0521_Analyze-DocumentationCoverage.ps1"
        $script:TempOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) "analysis"

        # Mock external dependencies
        Mock -CommandName Import-Module -MockWith { }
        Mock -CommandName Write-AnalysisLog -MockWith { param($Message, $Component, $Level) Write-Host "[$Level] $Message" }
        Mock -CommandName Initialize-TechDebtAnalysis -MockWith { }
        Mock -CommandName Get-FilesToAnalyze -MockWith {
            @(
                @{ FullName = "TestScript1.ps1"; BaseName = "TestScript1" }
                @{ FullName = "TestScript2.psm1"; BaseName = "TestScript2" }
            )
        }
        Mock -CommandName Get-CachedResults -MockWith { $null }
        Mock -CommandName Set-CachedResults -MockWith { }
        Mock -CommandName Save-AnalysisResults -MockWith { "documentation-analysis.json" }
        Mock -CommandName Get-Content -MockWith {
            @(
                "function Test-Function {",
                "<#",
                ".SYNOPSIS",
                "Test function with documentation",
                "#>",
                "    # Function body",
                "}",
                "function Test-UndocumentedFunction {",
                "    # No documentation",
                "}"
            )
        }
        Mock -CommandName Write-Host -MockWith { }
        Mock -CommandName Test-Path -MockWith { $true }
    }

    Context "Parameter Validation" {
        It "Should accept OutputPath parameter" {
            { & $script:ScriptPath -OutputPath $script:TempOutputPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept UseCache switch" {
            { & $script:ScriptPath -UseCache -WhatIf } | Should -Not -Throw
        }

        It "Should accept Detailed switch" {
            { & $script:ScriptPath -Detailed -WhatIf } | Should -Not -Throw
        }

        It "Should accept ExcludePaths parameter" {
            { & $script:ScriptPath -ExcludePaths @("tests", "legacy") -WhatIf } | Should -Not -Throw
        }
    }

    Context "Documentation Analysis" {
        It "Should analyze documentation coverage successfully" {
            $result = & $script:ScriptPath -OutputPath $script:TempOutputPath 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It "Should analyze PowerShell files for documentation" {
            & $script:ScriptPath -OutputPath $script:TempOutputPath 2>&1
            Should -Invoke Get-FilesToAnalyze -Times 1
            Should -Invoke Get-Content -AtLeast 1
        }

        It "Should identify documented functions" {
            & $script:ScriptPath -OutputPath $script:TempOutputPath 2>&1
            Should -Invoke Get-Content -ParameterFilter { $Raw -eq $true }
        }

        It "Should calculate coverage percentages" {
            & $script:ScriptPath -OutputPath $script:TempOutputPath 2>&1
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Coverage:*" }
        }
    }

    Context "Cache Functionality" {
        It "Should use cache when UseCache is specified" {
            Mock -CommandName Get-CachedResults -MockWith {
                @{
                    TotalFunctions = 10
                    DocumentedFunctions = 7
                    FunctionCoveragePercentage = 70
                    OverallCoveragePercentage = 75
                }
            }

            & $script:ScriptPath -OutputPath $script:TempOutputPath -UseCache 2>&1
            Should -Invoke Get-CachedResults -Times 1
        }

        It "Should save cache when analysis completes" {
            & $script:ScriptPath -OutputPath $script:TempOutputPath -UseCache 2>&1
            Should -Invoke Set-CachedResults -Times 1
        }
    }

    Context "Output and Reporting" {
        It "Should save analysis results" {
            & $script:ScriptPath -OutputPath $script:TempOutputPath 2>&1
            Should -Invoke Save-AnalysisResults -ParameterFilter { $AnalysisType -eq "DocumentationCoverage" }
        }

        It "Should display summary information" {
            & $script:ScriptPath -OutputPath $script:TempOutputPath 2>&1
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Documentation Coverage Summary:*" }
        }

        It "Should show detailed output when requested" {
            & $script:ScriptPath -OutputPath $script:TempOutputPath -Detailed 2>&1
            Should -Invoke Write-AnalysisLog -AtLeast 5
        }
    }

    Context "WhatIf Support" {
        It "Should show analysis preview with WhatIf" {
            $result = & $script:ScriptPath -WhatIf -OutputPath $script:TempOutputPath 2>&1
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should not save results with WhatIf" {
            & $script:ScriptPath -WhatIf -OutputPath $script:TempOutputPath 2>&1
            Should -Not -Invoke Save-AnalysisResults
        }

        It "Should not initialize analysis with WhatIf" {
            & $script:ScriptPath -WhatIf -OutputPath $script:TempOutputPath 2>&1
            Should -Not -Invoke Initialize-TechDebtAnalysis
        }
    }

    Context "Error Handling" {
        It "Should handle file access errors gracefully" {
            Mock -CommandName Get-Content -MockWith { throw "Access denied" }

            { & $script:ScriptPath -OutputPath $script:TempOutputPath } | Should -Not -Throw
        }

        It "Should handle module import failures" {
            Mock -CommandName Import-Module -MockWith { throw "Module not found" }

            $result = & $script:ScriptPath -OutputPath $script:TempOutputPath 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }
}
