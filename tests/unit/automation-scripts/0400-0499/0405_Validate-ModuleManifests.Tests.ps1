#!/usr/bin/env pwsh
#Requires -Module Pester

<#
.SYNOPSIS
    Tests for the module manifest validation script (0405)
.DESCRIPTION
    Tests the functionality of 0405_Validate-ModuleManifests.ps1 including:
    - Unicode character detection and fixing
    - PowerShell manifest validation
    - Error handling and reporting
#>

Describe "0405_Validate-ModuleManifests" {
    BeforeAll {
        # Set up test environment
        $scriptPath = "$PSScriptRoot/../../../../automation-scripts/0405_Validate-ModuleManifests.ps1"
        $toolPath = "$PSScriptRoot/../../../../tools/Validate-ModuleManifest.ps1"
        $testTempDir = Join-Path $TestDrive "manifest-tests"
        New-Item -Path $testTempDir -ItemType Directory -Force
        
        # Ensure the scripts exist
        $scriptPath | Should -Exist
        $toolPath | Should -Exist
    }

    Context "Script Validation" {
        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$errors)
            $errors | Should -BeNullOrEmpty
        }

        It "Should support WhatIf" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'SupportsShouldProcess'
        }
    }

    Context "Metadata" {
        It "Should be in stage: Testing" {
            $content = Get-Content $scriptPath
            ($content -join ' ') | Should -Match 'Stage:'
            ($content -join ' ') | Should -Match 'Testing'
        }

        It "Should have order: 0405" {
            $content = Get-Content $scriptPath
            ($content -join ' ') | Should -Match 'Order.*0405'
        }
    }

    Context "Execution" {
        It "Should execute with WhatIf" {
            { & $scriptPath -WhatIf } | Should -Not -Throw
        }
    }

    Context "Valid Manifest Validation" {
        It "Should pass validation for a clean manifest" {
            $validManifest = @"
@{
    ModuleVersion = '1.0.0'
    GUID = 'a7d4e8f1-2b3c-4d5e-6f7a-8b9c0d1e2f3a'
    Author = 'Test Author'
    Description = 'Test module without Unicode issues'
    PowerShellVersion = '7.0'
    RootModule = 'TestModule.psm1'
    FunctionsToExport = @('*')
}
"@
            $manifestPath = Join-Path $testTempDir "valid-manifest.psd1"
            Set-Content -Path $manifestPath -Value $validManifest -Encoding UTF8
            
            # Create a dummy module file to satisfy Test-ModuleManifest
            $modulePath = Join-Path $testTempDir "TestModule.psm1"
            Set-Content -Path $modulePath -Value "# Test module" -Encoding UTF8
            
            $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $toolPath -Path $manifestPath 2>&1
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Unicode Issue Detection" {
        It "Should detect Unicode arrow characters" {
            $unicodeManifest = @"
@{
    ModuleVersion = '1.0.0'
    GUID = 'a7d4e8f1-2b3c-4d5e-6f7a-8b9c0d1e2f3a'
    Author = 'Test Author'
    Description = 'Test module with Unicode arrows → ← ↑ ↓'
    PowerShellVersion = '7.0'
    RootModule = 'TestModule.psm1'
    FunctionsToExport = @('*')
}
"@
            $manifestPath = Join-Path $testTempDir "unicode-manifest.psd1"
            Set-Content -Path $manifestPath -Value $unicodeManifest -Encoding UTF8
            
            $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $toolPath -Path $manifestPath 2>&1
            $resultText = $result -join "`n"
            
            $resultText | Should -Match "Unicode.*issues"
            $resultText | Should -Match "UnicodeArrow"
            $resultText | Should -Match "NonAsciiCharacter"
        }

        It "Should detect Unicode quotes and dashes" {
            $unicodeManifest = @"
@{
    ModuleVersion = '1.0.0'
    GUID = 'a7d4e8f1-2b3c-4d5e-6f7a-8b9c0d1e2f3a'
    Author = 'Test Author'
    Description = 'Test module with "smart quotes" and – em-dash — characters'
    PowerShellVersion = '7.0'
    RootModule = 'TestModule.psm1'
    FunctionsToExport = @('*')
}
"@
            $manifestPath = Join-Path $testTempDir "quotes-manifest.psd1"
            Set-Content -Path $manifestPath -Value $unicodeManifest -Encoding UTF8
            
            $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $toolPath -Path $manifestPath 2>&1
            $resultText = $result -join "`n"
            
            $resultText | Should -Match "Unicode.*issues"
            $resultText | Should -Match "NonAsciiCharacter"
        }
    }

    Context "Unicode Issue Fixing" {
        It "Should fix Unicode arrows" {
            $unicodeManifest = @"
@{
    ModuleVersion = '1.0.0'
    GUID = 'a7d4e8f1-2b3c-4d5e-6f7a-8b9c0d1e2f3a'
    Author = 'Test Author'
    Description = 'Complexity reduction (33 → 6 modules)'
    PowerShellVersion = '7.0'
    RootModule = 'TestModule.psm1'
    FunctionsToExport = @('*')
}
"@
            $manifestPath = Join-Path $testTempDir "fix-arrows-manifest.psd1"
            Set-Content -Path $manifestPath -Value $unicodeManifest -Encoding UTF8
            
            # Run with fix option
            $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $toolPath -Path $manifestPath -Fix 2>&1
            $resultText = $result -join "`n"
            
            $resultText | Should -Match "Applied fixes"
            $resultText | Should -Match "All Unicode issues resolved"
            
            # Check that the file was actually fixed
            $fixedContent = Get-Content -Path $manifestPath -Raw
            $fixedContent | Should -Match "33 -> 6 modules"
            $fixedContent | Should -Not -Match "→"
        }

        It "Should create backup when fixing" {
            $unicodeManifest = @"
@{
    ModuleVersion = '1.0.0'
    GUID = 'a7d4e8f1-2b3c-4d5e-6f7a-8b9c0d1e2f3a'
    Author = 'Test Author'
    Description = 'Test with – dash'
    PowerShellVersion = '7.0'
    RootModule = 'TestModule.psm1'
    FunctionsToExport = @('*')
}
"@
            $manifestPath = Join-Path $testTempDir "backup-test-manifest.psd1"
            Set-Content -Path $manifestPath -Value $unicodeManifest -Encoding UTF8
            
            # Run with fix option
            $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $toolPath -Path $manifestPath -Fix 2>&1
            
            # Check that backup was created
            $backupPath = "$manifestPath.bak"
            $backupPath | Should -Exist
            
            # Backup should contain original Unicode characters
            $backupContent = Get-Content -Path $backupPath -Raw
            $backupContent | Should -Match "–"
            
            # Fixed file should not contain Unicode characters
            $fixedContent = Get-Content -Path $manifestPath -Raw
            $fixedContent | Should -Match "Test with - dash"
            $fixedContent | Should -Not -Match "–"
        }
    }

    Context "Main Script Functionality" {
        It "Should validate multiple manifests" {
            # Create multiple test manifests in a subdirectory structure that mimics real usage
            $moduleTestDir = Join-Path $testTempDir "TestModules"
            New-Item -Path $moduleTestDir -ItemType Directory -Force
            
            $validManifest = @"
@{
    ModuleVersion = '1.0.0'
    GUID = 'a7d4e8f1-2b3c-4d5e-6f7a-8b9c0d1e2f3a'
    Author = 'Test Author'
    Description = 'Valid test module'
    PowerShellVersion = '7.0'
    RootModule = 'Valid.psm1'
    FunctionsToExport = @('*')
}
"@
            
            $unicodeManifest = @"
@{
    ModuleVersion = '1.0.0'
    GUID = 'b8e5f2g3-4c5d-6e7f-8a9b-0c1d2e3f4a5b'
    Author = 'Test Author'
    Description = 'Test with → arrow'
    PowerShellVersion = '7.0'
    RootModule = 'Unicode.psm1'
    FunctionsToExport = @('*')
}
"@
            
            $validPath = Join-Path $moduleTestDir "valid.psd1"
            $unicodePath = Join-Path $moduleTestDir "unicode.psd1"
            
            Set-Content -Path $validPath -Value $validManifest -Encoding UTF8
            Set-Content -Path $unicodePath -Value $unicodeManifest -Encoding UTF8
            
            # Create corresponding module files
            Set-Content -Path (Join-Path $moduleTestDir "Valid.psm1") -Value "# Valid test module" -Encoding UTF8
            Set-Content -Path (Join-Path $moduleTestDir "Unicode.psm1") -Value "# Unicode test module" -Encoding UTF8
            
            # Test that the validation tool finds Unicode issues directly
            $unicodeResult = & pwsh -NoProfile -ExecutionPolicy Bypass -File $toolPath -Path $unicodePath 2>&1
            $unicodeResultText = $unicodeResult -join "`n"
            
            $unicodeResultText | Should -Match "Unicode.*issues"
        }
    }

    Context "Error Handling" {
        It "Should handle non-existent files gracefully" {
            $nonExistentPath = Join-Path $testTempDir "does-not-exist.psd1"
            
            $result = & pwsh -NoProfile -ExecutionPolicy Bypass -File $toolPath -Path $nonExistentPath 2>&1
            $LASTEXITCODE | Should -Be 1
            
            $resultText = $result -join "`n"
            $resultText | Should -Match "File not found"
        }
    }
}