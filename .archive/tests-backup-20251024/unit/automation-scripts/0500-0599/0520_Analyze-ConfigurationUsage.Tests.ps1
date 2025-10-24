#Requires -Version 7.0

Describe "0520_Analyze-ConfigurationUsage" {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0520_Analyze-ConfigurationUsage.ps1"
        $script:TempDir = [System.IO.Path]::GetTempPath()
        $script:TestConfigPath = Join-Path $script:TempDir "config.psd1"
        $script:TestOutputPath = Join-Path $script:TempDir "analysis"
        
        # Create test config file
        @{
            Core = @{
                Profile = "Standard"
                LogLevel = "Information"
            }
            Automation = @{
                MaxConcurrency = 4
                ValidateBeforeRun = $true
            }
        } | ConvertTo-Json -Depth 3 | Set-Content -Path $script:TestConfigPath
        
        # Mock external dependencies
        Mock -CommandName Import-Module -MockWith { }
        Mock -CommandName Write-AnalysisLog -MockWith { param($Message, $Component, $Level) Write-Host "[$Level] $Message" }
        Mock -CommandName Initialize-TechDebtAnalysis -MockWith { }
        Mock -CommandName Get-FilesToAnalyze -MockWith { 
            @(
                @{ FullName = "TestScript1.ps1" }
                @{ FullName = "TestScript2.ps1" }
            )
        }
        Mock -CommandName Get-CachedResults -MockWith { $null }
        Mock -CommandName Set-CachedResults -MockWith { }
        Mock -CommandName Save-AnalysisResults -MockWith { "analysis-results.json" }
        Mock -CommandName Start-ThreadJob -MockWith { 
            @{ Id = 1 }
        }
        Mock -CommandName Wait-Job -MockWith { 
            @{ State = "Completed" }
        }
        Mock -CommandName Receive-Job -MockWith { 
            @("TestScript1.ps1") 
        }
        Mock -CommandName Remove-Job -MockWith { }
        Mock -CommandName Get-Content -MockWith {
            if ($Path -like "*config.psd1") {
                Get-Content $script:TestConfigPath
            } else {
                "# Sample script with config.Core.Profile usage"
            }
        }
        Mock -CommandName Write-Host -MockWith { }
    }

    AfterAll {
        if (Test-Path $script:TestConfigPath) {
            Remove-Item $script:TestConfigPath -Force
        }
    }

    Context "Parameter Validation" {
        It "Should accept ConfigPath parameter" {
            { & $script:ScriptPath -ConfigPath $script:TestConfigPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept OutputPath parameter" {
            { & $script:ScriptPath -OutputPath $script:TestOutputPath -WhatIf } | Should -Not -Throw
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

    Context "Configuration Analysis" {
        It "Should analyze configuration usage successfully" {
            $result = & $script:ScriptPath -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It "Should load configuration file" {
            & $script:ScriptPath -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath 2>&1
            Should -Invoke Get-Content -ParameterFilter { $Path -like "*config.psd1" }
        }

        It "Should analyze files for configuration usage" {
            & $script:ScriptPath -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath 2>&1
            Should -Invoke Get-FilesToAnalyze -Times 1
        }

        It "Should handle missing configuration file" {
            $result = & $script:ScriptPath -ConfigPath "nonexistent.json" -OutputPath $script:TestOutputPath 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Cache Functionality" {
        It "Should use cache when UseCache is specified" {
            Mock -CommandName Get-CachedResults -MockWith { 
                @{
                    TotalSettings = 4
                    UsedSettings = 2
                    UnusedSettings = @("Core.UnusedSetting", "Automation.UnusedSetting")
                    UsagePercentage = 50
                }
            }
            
            & $script:ScriptPath -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath -UseCache 2>&1
            Should -Invoke Get-CachedResults -Times 1
        }

        It "Should save cache when analysis completes" {
            & $script:ScriptPath -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath -UseCache 2>&1
            Should -Invoke Set-CachedResults -Times 1
        }
    }

    Context "Parallel Processing" {
        It "Should use parallel processing for file analysis" {
            & $script:ScriptPath -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath 2>&1
            Should -Invoke Start-ThreadJob -AtLeast 1
            Should -Invoke Wait-Job -AtLeast 1
            Should -Invoke Receive-Job -AtLeast 1
        }

        It "Should handle job timeouts gracefully" {
            Mock -CommandName Wait-Job -MockWith { throw "Timeout" }
            
            { & $script:ScriptPath -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath } | Should -Not -Throw
        }
    }

    Context "Output and Reporting" {
        It "Should save analysis results" {
            & $script:ScriptPath -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath 2>&1
            Should -Invoke Save-AnalysisResults -ParameterFilter { $AnalysisType -eq "ConfigurationUsage" }
        }

        It "Should display summary information" {
            & $script:ScriptPath -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath 2>&1
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Configuration Usage Summary:*" }
        }

        It "Should show detailed output when requested" {
            & $script:ScriptPath -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath -Detailed 2>&1
            Should -Invoke Write-AnalysisLog -ParameterFilter { $Message -like "*Used in*" -or $Message -like "*Not used*" }
        }
    }

    Context "WhatIf Support" {
        It "Should show analysis preview with WhatIf" {
            $result = & $script:ScriptPath -WhatIf -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath 2>&1
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should not save results with WhatIf" {
            & $script:ScriptPath -WhatIf -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath 2>&1
            Should -Not -Invoke Save-AnalysisResults
        }

        It "Should not initialize analysis with WhatIf" {
            & $script:ScriptPath -WhatIf -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath 2>&1
            Should -Not -Invoke Initialize-TechDebtAnalysis
        }
    }

    Context "Error Handling" {
        It "Should handle analysis failures gracefully" {
            Mock -CommandName Get-FilesToAnalyze -MockWith { throw "File access error" }
            
            $result = & $script:ScriptPath -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath 2>&1
            $LASTEXITCODE | Should -Be 1
        }

        It "Should handle module import failures" {
            Mock -CommandName Import-Module -MockWith { throw "Module not found" }
            
            $result = & $script:ScriptPath -ConfigPath $script:TestConfigPath -OutputPath $script:TestOutputPath 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }
}
