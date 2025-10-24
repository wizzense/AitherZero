#Requires -Version 7.0

Describe "0511_Show-ProjectDashboard" {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0511_Show-ProjectDashboard.ps1"
        $script:TempDir = [System.IO.Path]::GetTempPath()
        $script:TestProjectPath = Join-Path $script:TempDir "TestProject"
        
        # Mock external dependencies
        Mock -CommandName Import-Module -MockWith { }
        Mock -CommandName Clear-Host -MockWith { }
        Mock -CommandName Write-Host -MockWith { }
        Mock -CommandName Get-Content -MockWith { 
            if ($Path -like "*ProjectReport*.json") {
                @{ 
                    FileAnalysis = @{ TotalFiles = 100 }
                    Coverage = @{ TotalFiles = 50; FunctionCount = 25; CodeLines = 1000; CommentRatio = 15 }
                    Documentation = @{ HelpCoverage = 75 }
                } | ConvertTo-Json -Depth 5
            } elseif ($Path -like "*Summary*.json") {
                @{ TotalTests = 10; Passed = 8; Failed = 2 } | ConvertTo-Json
            } elseif ($Path -like "*aitherzero.log") {
                @("[INFO] Test log entry", "[ERROR] Test error", "[WARNING] Test warning")
            } else {
                @()
            }
        }
        Mock -CommandName Get-ChildItem -MockWith {
            if ($Filter -like "*ProjectReport*.json") { 
                @(@{ FullName = "ProjectReport.json"; LastWriteTime = (Get-Date) })
            } elseif ($Filter -like "*Summary*.json") {
                @(@{ FullName = "TestSummary.json"; BaseName = "TestSummary-20240101-120000"; LastWriteTime = (Get-Date) })
            } elseif ($Directory -and $_.Name -eq "domains") {
                @(@{ Name = "utilities"; FullName = "utilities" }, @{ Name = "testing"; FullName = "testing" })
            } elseif ($Filter -eq "*.psm1") {
                @(@{ BaseName = "Logging" }, @{ BaseName = "TestFramework" })
            } else {
                @(@{ FullName = "TestFile.ps1"; LastWriteTime = (Get-Date).AddHours(-1) })
            }
        }
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName git -MockWith { @("abc1234 Initial commit", "def5678 Add feature") }
        Mock -CommandName Get-Date -MockWith { [DateTime]::Now }
        Mock -CommandName Initialize-Logging -MockWith { }
        Mock -CommandName Write-CustomLog -MockWith { }
    }

    Context "Parameter Validation" {
        It "Should accept ProjectPath parameter" {
            { & $script:ScriptPath -ProjectPath $script:TestProjectPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept ShowLogs switch" {
            { & $script:ScriptPath -ShowLogs -WhatIf } | Should -Not -Throw
        }

        It "Should accept ShowTests switch" {
            { & $script:ScriptPath -ShowTests -WhatIf } | Should -Not -Throw
        }

        It "Should accept ShowMetrics switch" {
            { & $script:ScriptPath -ShowMetrics -WhatIf } | Should -Not -Throw
        }

        It "Should accept LogTailLines parameter" {
            { & $script:ScriptPath -LogTailLines 25 -WhatIf } | Should -Not -Throw
        }

        It "Should accept Follow switch" {
            { & $script:ScriptPath -Follow -WhatIf } | Should -Not -Throw
        }
    }

    Context "Dashboard Display" {
        It "Should display dashboard successfully" {
            $result = & $script:ScriptPath -ProjectPath $script:TestProjectPath 2>&1
            $LASTEXITCODE | Should -Be 0
            Should -Invoke Clear-Host
        }

        It "Should show project metrics when available" {
            & $script:ScriptPath -ShowMetrics -ProjectPath $script:TestProjectPath 2>&1
            Should -Invoke Get-ChildItem -ParameterFilter { $Filter -like "*ProjectReport*.json" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Total Files:*" }
        }

        It "Should show test results when available" {
            & $script:ScriptPath -ShowTests -ProjectPath $script:TestProjectPath 2>&1
            Should -Invoke Get-ChildItem -ParameterFilter { $Filter -like "*Summary*.json" }
        }

        It "Should show logs when requested" {
            & $script:ScriptPath -ShowLogs -ProjectPath $script:TestProjectPath -LogTailLines 10 2>&1
            Should -Invoke Get-Content -ParameterFilter { $Tail -eq 10 }
        }

        It "Should show all sections by default" {
            & $script:ScriptPath -ProjectPath $script:TestProjectPath 2>&1
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*PROJECT METRICS*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*TEST RESULTS*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*RECENT LOGS*" }
        }
    }

    Context "Data Sources" {
        It "Should handle missing project report gracefully" {
            Mock -CommandName Get-ChildItem -ParameterFilter { $Filter -like "*ProjectReport*.json" } -MockWith { @() }
            
            & $script:ScriptPath -ShowMetrics -ProjectPath $script:TestProjectPath 2>&1
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*No project report found*" }
        }

        It "Should handle missing log file gracefully" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*aitherzero.log" } -MockWith { $false }
            
            & $script:ScriptPath -ShowLogs -ProjectPath $script:TestProjectPath 2>&1
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Log file not found*" }
        }

        It "Should display module status" {
            & $script:ScriptPath -ShowMetrics -ProjectPath $script:TestProjectPath 2>&1
            Should -Invoke Get-ChildItem -ParameterFilter { $Directory -and $Path -like "*domains*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*MODULE STATUS*" }
        }

        It "Should show recent activity" {
            & $script:ScriptPath -ProjectPath $script:TestProjectPath 2>&1
            Should -Invoke git -ParameterFilter { $ArgumentList -contains "--oneline" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*RECENT ACTIVITY*" }
        }
    }

    Context "WhatIf Support" {
        It "Should show dashboard preview with WhatIf" {
            $result = & $script:ScriptPath -WhatIf -ProjectPath $script:TestProjectPath 2>&1
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should not initialize logging with WhatIf" {
            & $script:ScriptPath -WhatIf -ShowLogs 2>&1
            Should -Not -Invoke Initialize-Logging
        }
    }

    Context "Error Handling" {
        It "Should handle git command failures gracefully" {
            Mock -CommandName git -MockWith { throw "Git not available" }
            
            { & $script:ScriptPath -ProjectPath $script:TestProjectPath } | Should -Not -Throw
        }

        It "Should handle module import failures" {
            Mock -CommandName Import-Module -MockWith { throw "Module not found" }
            
            { & $script:ScriptPath -ProjectPath $script:TestProjectPath } | Should -Not -Throw
        }
    }
}
