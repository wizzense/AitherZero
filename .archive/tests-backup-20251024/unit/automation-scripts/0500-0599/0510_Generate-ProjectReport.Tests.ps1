#Requires -Version 7.0

Describe "0510_Generate-ProjectReport" {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0510_Generate-ProjectReport.ps1"
        $script:TempDir = [System.IO.Path]::GetTempPath()
        $script:TestProjectPath = Join-Path $script:TempDir "TestProject"
        $script:TestOutputPath = Join-Path $script:TestProjectPath "tests/reports"
        
        # Create test directory structure
        New-Item -ItemType Directory -Path $script:TestProjectPath -Force | Out-Null
        New-Item -ItemType Directory -Path $script:TestOutputPath -Force | Out-Null
        
        # Mock external dependencies
        Mock -CommandName Import-Module -MockWith { }
        Mock -CommandName Write-CustomLog -MockWith { param($Message, $Level, $Source) Write-Host "[$Level] $Message" }
        Mock -CommandName Get-Content -MockWith {
            if ($Path -like "*VERSION*") { "1.0.0" }
            elseif ($Path -like "*.psd1") { @{} }
            elseif ($Path -like "*.json") { "{}" | ConvertFrom-Json }
            elseif ($Path -like "*.ps1" -or $Path -like "*.psm1") { @("# Sample PowerShell code", "function Test-Function { }", "# TODO: Add feature") }
            else { @() }
        }
        Mock -CommandName Import-PowerShellDataFile -MockWith { @{ ModuleVersion = "1.0.0"; RequiredModules = @() } }
        Mock -CommandName Get-ChildItem -MockWith {
            if ($Filter -eq "*.psd1") { @(@{ BaseName = "TestModule"; FullName = "TestModule.psd1" }) }
            elseif ($Filter -eq "*.ps1" -or $Filter -eq "*.psm1") { @(@{ FullName = "TestScript.ps1" }) }
            elseif ($Filter -eq "*.Tests.ps1") { @(@{ FullName = "TestScript.Tests.ps1" }) }
            elseif ($Filter -eq "*.md") { @(@{ FullName = "README.md" }) }
            elseif ($Directory) { @(@{ Name = "TestDomain"; FullName = "TestDomain" }) }
            else { @(@{ Name = "TestFile.txt"; Length = 1024 }) }
        }
        Mock -CommandName Test-Path -MockWith { $true }
        Mock -CommandName Set-Content -MockWith { }
        Mock -CommandName ConvertTo-Json -MockWith { "mocked json" }
        Mock -CommandName Write-Host -MockWith { }
    }

    AfterAll {
        # Clean up test directory
        if (Test-Path $script:TestProjectPath) {
            Remove-Item -Path $script:TestProjectPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Parameter Validation" {
        It "Should accept ProjectPath parameter" {
            { & $script:ScriptPath -ProjectPath $script:TestProjectPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept OutputPath parameter" {
            { & $script:ScriptPath -OutputPath $script:TestOutputPath -WhatIf } | Should -Not -Throw
        }

        It "Should accept Format parameter" {
            { & $script:ScriptPath -Format "JSON" -WhatIf } | Should -Not -Throw
            { & $script:ScriptPath -Format "HTML" -WhatIf } | Should -Not -Throw
            { & $script:ScriptPath -Format "Markdown" -WhatIf } | Should -Not -Throw
            { & $script:ScriptPath -Format "All" -WhatIf } | Should -Not -Throw
        }

        It "Should validate Format parameter values" {
            { & $script:ScriptPath -Format "Invalid" -WhatIf } | Should -Throw
        }
    }

    Context "Report Generation" {
        It "Should generate project report successfully" {
            $result = & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It "Should analyze dependencies" {
            & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath 2>&1
            Should -Invoke Get-ChildItem -ParameterFilter { $Filter -eq "*.psd1" }
        }

        It "Should collect test results" {
            & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath 2>&1
            Should -Invoke Get-ChildItem -ParameterFilter { $Filter -eq "*.Tests.ps1" }
        }

        It "Should calculate code coverage metrics" {
            & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath 2>&1
            Should -Invoke Get-ChildItem -ParameterFilter { $Filter -eq "*.ps1" -or $Filter -eq "*.psm1" }
        }

        It "Should analyze documentation" {
            & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath 2>&1
            Should -Invoke Get-ChildItem -ParameterFilter { $Filter -eq "*.md" }
        }
    }

    Context "Output Formats" {
        It "Should generate JSON report" {
            & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "JSON" 2>&1
            Should -Invoke Set-Content -ParameterFilter { $Path -like "*ProjectReport*.json" }
        }

        It "Should generate HTML report" {
            & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "HTML" 2>&1
            Should -Invoke Set-Content -ParameterFilter { $Path -like "*ProjectReport*.html" }
        }

        It "Should generate Markdown report" {
            & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "Markdown" 2>&1
            Should -Invoke Set-Content -ParameterFilter { $Path -like "*ProjectReport*.md" }
        }

        It "Should generate all formats when Format is All" {
            & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "All" 2>&1
            Should -Invoke Set-Content -ParameterFilter { $Path -like "*ProjectReport*.json" }
            Should -Invoke Set-Content -ParameterFilter { $Path -like "*ProjectReport*.html" }
            Should -Invoke Set-Content -ParameterFilter { $Path -like "*ProjectReport*.md" }
        }
    }

    Context "WhatIf Support" {
        It "Should show report generation preview with WhatIf" {
            $result = & $script:ScriptPath -WhatIf -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath 2>&1
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should not create files with WhatIf" {
            & $script:ScriptPath -WhatIf -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "All" 2>&1
            Should -Not -Invoke Set-Content
        }
    }

    Context "Error Handling" {
        It "Should handle missing project path gracefully" {
            Mock -CommandName Test-Path -ParameterFilter { $Path -like "*nonexistent*" } -MockWith { $false }
            Mock -CommandName Get-ChildItem -MockWith { @() }
            
            $result = & $script:ScriptPath -ProjectPath "nonexistent" -OutputPath $script:TestOutputPath 2>&1
            $LASTEXITCODE | Should -Be 0  # Should complete even with missing files
        }

        It "Should handle module import failures" {
            Mock -CommandName Import-Module -MockWith { throw "Module not found" }
            
            { & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath } | Should -Not -Throw
        }
    }
}
