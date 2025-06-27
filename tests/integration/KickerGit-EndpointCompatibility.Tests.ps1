<#
.SYNOPSIS
    Integration tests for kicker-git.ps1 endpoint compatibility

.DESCRIPTION
    Tests the actual kicker-git.ps1 execution scenarios that would be used
    on Windows endpoints with PowerShell 5.1.
#>

Describe "kicker-git.ps1 Integration Tests" {
    BeforeAll {
        $kickerScriptPath = Join-Path $PSScriptRoot "../../kicker-git.ps1"
        $tempTestDir = Join-Path ([System.IO.Path]::GetTempPath()) "kicker-git-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Path $tempTestDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $tempTestDir) {
            Remove-Item $tempTestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "PowerShell 5.1 Endpoint Simulation" {
        It "Should download and parse correctly via Invoke-WebRequest simulation" {
            # Simulate the actual endpoint scenario
            $testScriptPath = Join-Path $tempTestDir "downloaded-kicker-git.ps1"

            # Copy the script (simulating download)
            Copy-Item $kickerScriptPath $testScriptPath

            # Test that it can be parsed
            $errors = $null
            $tokens = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($testScriptPath, [ref]$tokens, [ref]$errors)

            $errors.Count | Should -Be 0 -Because "Downloaded script should parse without errors"
            $ast | Should -Not -BeNullOrEmpty
        }

        It "Should handle parameter parsing correctly" {
            # Test parameter parsing doesn't fail
            $scriptContent = Get-Content $kickerScriptPath -Raw

            # Extract parameter block
            $paramBlockMatch = [regex]::Match($scriptContent, "param\s*\([^\)]*\)", [System.Text.RegularExpressions.RegexOptions]::Singleline)
            $paramBlockMatch.Success | Should -Be $true -Because "Should have a valid parameter block"

            # Test that parameter block is valid PowerShell
            $paramBlock = $paramBlockMatch.Value
            $testScript = "[CmdletBinding()]`n$paramBlock`nWrite-Host `"Test`""

            $errors = $null
            $tokens = $null
            [System.Management.Automation.Language.Parser]::ParseInput($testScript, [ref]$tokens, [ref]$errors) | Out-Null

            $errors.Count | Should -Be 0 -Because "Parameter block should be valid PowerShell syntax"
        }

        It "Should not fail with WhatIf common parameter" {
            # Test that CmdletBinding and SupportsShouldProcess work correctly
            $scriptContent = Get-Content $kickerScriptPath -Raw
            $scriptContent | Should -Match "CmdletBinding\(SupportsShouldProcess\)" -Because "Should support ShouldProcess"
            $scriptContent | Should -Match "\[CmdletBinding\(SupportsShouldProcess\)\]" -Because "Should have proper CmdletBinding syntax"
        }
    }

    Context "Cross-Platform Path Compatibility" {
        It "Should handle Windows paths correctly" {
            # Test Windows-specific path scenarios
            $scriptContent = Get-Content $kickerScriptPath -Raw

            # Should handle C:/ style paths
            $scriptContent | Should -Match "C:/" -Because "Should handle Windows drive paths"

            # Should use platform detection
            $scriptContent | Should -Match "script:PlatformWindows" -Because "Should detect Windows platform"
        }

        It "Should handle temp directory correctly" {
            # Test temp directory resolution
            $scriptContent = Get-Content $kickerScriptPath -Raw
            $scriptContent | Should -Match "Get-PlatformTempPath" -Because "Should use cross-platform temp path function"

            # Check that the function exists
            $funcMatch = [regex]::Match($scriptContent, "function Get-PlatformTempPath", [System.Text.RegularExpressions.RegexOptions]::Multiline)
            $funcMatch.Success | Should -Be $true -Because "Get-PlatformTempPath function should exist"
        }
    }

    Context "Error Handling Validation" {
        It "Should have proper try-catch blocks" {
            $scriptContent = Get-Content $kickerScriptPath -Raw

            # Count try-catch pairs
            $tryCount = ([regex]::Matches($scriptContent, "\btry\s*\{")).Count
            $catchCount = ([regex]::Matches($scriptContent, "\bcatch\s*\{")).Count

            $tryCount | Should -BeGreaterThan 0 -Because "Should have error handling"
            $catchCount | Should -Be $tryCount -Because "Every try should have a corresponding catch"
        }

        It "Should handle PowerShell version detection gracefully" {
            $scriptContent = Get-Content $kickerScriptPath -Raw

            # Should check for PowerShell version
            $scriptContent | Should -Match "PSVersionTable" -Because "Should check PowerShell version"
            $scriptContent | Should -Match "IsPowerShell7Plus" -Because "Should detect PowerShell 7+"
            $scriptContent | Should -Match "IsPowerShell5" -Because "Should detect PowerShell 5.1"
        }
    }

    Context "Unicode Character Regression Tests" {
        It "Should not contain check mark Unicode characters" {
            $scriptContent = Get-Content $kickerScriptPath -Raw

            # Test for specific Unicode characters that were causing issues
            $scriptContent | Should -Not -Match "✓" -Because "Check mark Unicode character causes PowerShell 5.1 parsing errors"
            $scriptContent | Should -Not -Match "✗" -Because "Ballot X Unicode character causes PowerShell 5.1 parsing errors"
        }

        It "Should use ASCII alternatives for status indicators" {
            $scriptContent = Get-Content $kickerScriptPath -Raw

            # Should use ASCII alternatives
            $scriptContent | Should -Match "OK " -Because "Should use ASCII 'OK' instead of Unicode check marks"
            $scriptContent | Should -Match "FAIL " -Because "Should use ASCII 'FAIL' instead of Unicode X marks"
        }
    }
}
