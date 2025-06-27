<#
.SYNOPSIS
    Tests for kicker-git.ps1 PowerShell 5.1 compatibility and Unicode character handling

.DESCRIPTION
    Validates that kicker-git.ps1 works correctly with PowerShell 5.1 and doesn't contain
    Unicode characters that would cause parsing errors on Windows endpoints.
#>

Describe "kicker-git.ps1 PowerShell 5.1 Compatibility" {
    BeforeAll {
        $kickerScriptPath = Join-Path $PSScriptRoot "../../../kicker-git.ps1"
        $kickerContent = Get-Content $kickerScriptPath -Raw -Encoding UTF8
    }

    Context "Unicode Character Validation" {
        It "Should not contain problematic Unicode characters" {
            # Check for common problematic Unicode characters that cause PowerShell 5.1 parsing errors
            $problematicChars = @(
                [char]0x2713,  # ✓ (check mark)
                [char]0x2717,  # ✗ (ballot x)
                [char]0x2022,  # • (bullet)
                [char]0x2192,  # → (right arrow)
                [char]0x2190,  # ← (left arrow)
                [char]0x2605,  # ★ (star)
                [char]0x26A0   # ⚠ (warning sign)
            )

            foreach ($char in $problematicChars) {
                $kickerContent | Should -Not -Match [regex]::Escape($char.ToString()) -Because "Unicode character '$char' can cause PowerShell 5.1 parsing errors"
            }
        }

        It "Should only contain ASCII characters in critical sections" {
            # Check function headers for ASCII compatibility
            $functionHeaders = [regex]::Matches($kickerContent, "function\s+[\w-]+\s*\{", [System.Text.RegularExpressions.RegexOptions]::Multiline)

            foreach ($match in $functionHeaders) {
                $headerText = $match.Value
                for ($i = 0; $i -lt $headerText.Length; $i++) {
                    $char = $headerText[$i]
                    [int]$charCode = [int]$char
                    $charCode | Should -BeLessOrEqual 127 -Because "Function headers should only contain ASCII characters (found char code $charCode at position $i)"
                }
            }
        }

        It "Should not contain UTF-8 BOM" {
            $bytes = [System.IO.File]::ReadAllBytes($kickerScriptPath)
            if ($bytes.Length -ge 3) {
                # Check for UTF-8 BOM (EF BB BF)
                $hasBOM = ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)
                $hasBOM | Should -Be $false -Because "UTF-8 BOM can cause issues with PowerShell 5.1"
            }
        }
    }

    Context "PowerShell 5.1 Syntax Validation" {
        It "Should have valid PowerShell syntax" {
            # Test that the script can be parsed without errors
            $errors = $null
            $tokens = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($kickerScriptPath, [ref]$tokens, [ref]$errors)

            $errors | Should -BeNullOrEmpty -Because "Script should parse without syntax errors"
            $ast | Should -Not -BeNullOrEmpty -Because "Script should produce a valid AST"
        }

        It "Should properly handle cross-platform paths" {
            # Verify that path handling is compatible
            $kickerContent | Should -Match "Get-PlatformTempPath" -Because "Should use cross-platform path function"
        }

        It "Should handle missing PowerShell 7 gracefully" {
            # Verify fallback behavior when PowerShell 7 is not available
            $kickerContent | Should -Match "powershell\.exe" -Because "Should fallback to PowerShell 5.1 when PowerShell 7 is unavailable"
        }
    }

    Context "Runtime Compatibility" {
        It "Should execute without errors in script block creation" {
            try {
                # Test script parsing in a restricted scope
                $scriptBlock = [ScriptBlock]::Create($kickerContent)
                $scriptBlock | Should -Not -BeNullOrEmpty -Because "Script should compile to a valid script block"
            }
            catch {
                throw "Script failed to compile: $($_.Exception.Message)"
            }
        }

        It "Should have proper parameter block syntax" {
            # Test parameter parsing doesn't fail
            $paramBlockMatch = [regex]::Match($kickerContent, "param\s*\([^\)]*\)", [System.Text.RegularExpressions.RegexOptions]::Singleline)
            $paramBlockMatch.Success | Should -Be $true -Because "Should have a valid parameter block"
        }
    }
}
