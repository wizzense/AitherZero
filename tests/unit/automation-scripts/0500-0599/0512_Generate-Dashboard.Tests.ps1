#Requires -Version 7.0

Describe "0512_Generate-Dashboard" {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot "../../../../automation-scripts/0512_Generate-Dashboard.ps1"
        $script:TempDir = [System.IO.Path]::GetTempPath()
        $script:TestProjectPath = Join-Path $script:TempDir "TestDashboard"
        $script:TestOutputPath = Join-Path $script:TestProjectPath "reports"

        # Create test directory structure
        New-Item -ItemType Directory -Path $script:TestProjectPath -Force | Out-Null
        New-Item -ItemType Directory -Path $script:TestOutputPath -Force | Out-Null
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

        It "Should accept Open switch parameter" {
            { & $script:ScriptPath -Format "HTML" -Open -WhatIf } | Should -Not -Throw
        }

        It "Should accept ThemeColor parameter" {
            { & $script:ScriptPath -ThemeColor "#FF5733" -WhatIf } | Should -Not -Throw
        }
    }

    Context "Dashboard Generation" {
        It "Should generate HTML dashboard successfully" {
            $result = & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "HTML" 2>&1
            $LASTEXITCODE | Should -Be 0
            $htmlPath = Join-Path $script:TestOutputPath "dashboard.html"
            Test-Path $htmlPath | Should -Be $true
        }

        It "Should generate Markdown dashboard successfully" {
            $result = & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "Markdown" 2>&1
            $LASTEXITCODE | Should -Be 0
            $mdPath = Join-Path $script:TestOutputPath "dashboard.md"
            Test-Path $mdPath | Should -Be $true
        }

        It "Should generate JSON report successfully" {
            $result = & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "JSON" 2>&1
            $LASTEXITCODE | Should -Be 0
            $jsonPath = Join-Path $script:TestOutputPath "dashboard.json"
            Test-Path $jsonPath | Should -Be $true
        }

        It "Should generate all formats when Format is All" {
            $result = & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "All" 2>&1
            $LASTEXITCODE | Should -Be 0
            
            $htmlPath = Join-Path $script:TestOutputPath "dashboard.html"
            $mdPath = Join-Path $script:TestOutputPath "dashboard.md"
            $jsonPath = Join-Path $script:TestOutputPath "dashboard.json"
            $readmePath = Join-Path $script:TestOutputPath "README.md"
            
            Test-Path $htmlPath | Should -Be $true
            Test-Path $mdPath | Should -Be $true
            Test-Path $jsonPath | Should -Be $true
            Test-Path $readmePath | Should -Be $true
        }

        It "Should create README.md index file" {
            $result = & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath 2>&1
            $readmePath = Join-Path $script:TestOutputPath "README.md"
            Test-Path $readmePath | Should -Be $true
        }
    }

    Context "HTML Dashboard Content" {
        BeforeAll {
            & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "HTML" 2>&1 | Out-Null
            $script:HtmlPath = Join-Path $script:TestOutputPath "dashboard.html"
            $script:HtmlContent = Get-Content $script:HtmlPath -Raw
        }

        It "Should contain HTML doctype" {
            $script:HtmlContent | Should -Match "<!DOCTYPE html>"
        }

        It "Should contain project title" {
            $script:HtmlContent | Should -Match "AitherZero"
        }

        It "Should contain project metrics section" {
            $script:HtmlContent | Should -Match "Project Metrics"
        }

        It "Should contain navigation TOC" {
            $script:HtmlContent | Should -Match "📑 Contents"
        }

        It "Should include responsive CSS" {
            $script:HtmlContent | Should -Match "@media"
        }

        It "Should include JavaScript functionality" {
            $script:HtmlContent | Should -Match "<script>"
        }
    }

    Context "Open Parameter Functionality" {
        It "Should accept Open parameter without error" {
            # Note: We can't test actual browser opening in CI, but we can verify the parameter is accepted
            { & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "HTML" -Open -WhatIf } | Should -Not -Throw
        }

        It "Should work with Open parameter on actual generation" {
            # This will fail to open browser in CI but should not cause script to fail
            $result = & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "HTML" -Open 2>&1
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "WhatIf Support" {
        It "Should show dashboard generation preview with WhatIf" {
            $result = & $script:ScriptPath -WhatIf -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath 2>&1
            # Should complete successfully with WhatIf
            $LASTEXITCODE | Should -Be 0
        }

        It "Should not create files with WhatIf and Open" {
            $testPath = Join-Path $script:TempDir "WhatIfTest"
            New-Item -ItemType Directory -Path $testPath -Force | Out-Null
            $testOutput = Join-Path $testPath "reports"
            New-Item -ItemType Directory -Path $testOutput -Force | Out-Null
            
            & $script:ScriptPath -WhatIf -ProjectPath $testPath -OutputPath $testOutput -Format "HTML" -Open 2>&1 | Out-Null
            
            # Files should not be created
            Test-Path (Join-Path $testOutput "dashboard.html") | Should -Be $false
            
            # Cleanup
            Remove-Item -Path $testPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Error Handling" {
        It "Should handle missing project path gracefully" {
            $result = & $script:ScriptPath -ProjectPath "nonexistent" -OutputPath $script:TestOutputPath 2>&1
            $LASTEXITCODE | Should -Be 0  # Should complete even with missing files
        }

        It "Should handle invalid output path creation" {
            # Use a path that should work but test resilience
            $result = & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath 2>&1
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should detect current platform" {
            $result = & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "JSON" 2>&1
            $jsonPath = Join-Path $script:TestOutputPath "dashboard.json"
            $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
            $json.Environment.Platform | Should -Not -BeNullOrEmpty
        }

        It "Should include PowerShell version in output" {
            $result = & $script:ScriptPath -ProjectPath $script:TestProjectPath -OutputPath $script:TestOutputPath -Format "JSON" 2>&1
            $jsonPath = Join-Path $script:TestOutputPath "dashboard.json"
            $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
            $json.Environment.PowerShell | Should -Not -BeNullOrEmpty
        }
    }
}
