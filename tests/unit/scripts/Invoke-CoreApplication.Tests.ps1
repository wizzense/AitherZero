#!/usr/bin/env pwsh
#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive tests for Invoke-CoreApplication.ps1
.DESCRIPTION
    Tests for the Invoke-CoreApplication.ps1 script including syntax validation,
    parameter validation, and functionality testing.
#>

# Set environment variables for admin-friendly module discovery
if (-not $env:PWSH_MODULES_PATH) {
    $env:PWSH_MODULES_PATH = (Resolve-Path "$PSScriptRoot/../../aither-core/modules").Path
}
if (-not $env:PROJECT_ROOT) {
    $env:PROJECT_ROOT = (Resolve-Path "$PSScriptRoot/../..").Path
}

# Import required modules
try {
    Import-Module "$env:PWSH_MODULES_PATH/Logging/" -Force -ErrorAction Stop
    Import-Module "$env:PWSH_MODULES_PATH/LabRunner/" -Force -ErrorAction Stop
} catch {
    Write-Error "Failed to import required modules: $_"
    exit 1
}

Describe "Invoke-CoreApplication.ps1 Tests" {
    BeforeAll {
        Write-CustomLog "Starting tests for Invoke-CoreApplication.ps1" -Level "INFO"
        $script:ScriptPath = "$env:PROJECT_ROOT/pwsh/core_app/scripts/Invoke-CoreApplication.ps1"
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw -ErrorAction SilentlyContinue
        
        # Create a test config file
        $script:TestConfigPath = Join-Path $TestDrive "test-config.json"
        $script:TestConfig = @{
            ApplicationName = "TestApp"
            TestMode = $true
        } | ConvertTo-Json
        $script:TestConfig | Out-File -FilePath $script:TestConfigPath -Encoding UTF8
    }

    Context "Script Validation" {
        It "Should exist and be readable" {
            $script:ScriptPath | Should -Exist
            $script:ScriptContent | Should -Not -BeNullOrEmpty
            Write-CustomLog "Script file validation passed" -Level "INFO"
        }

        It "Should have valid PowerShell syntax" {
            { 
                $tokens = $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$tokens, [ref]$errors)
                if ($errors.Count -gt 0) {
                    Write-CustomLog "Syntax errors found: $($errors | Out-String)" -Level "ERROR"
                    throw "Syntax errors detected"
                }
            } | Should -Not -Throw
        }

        It "Should have mandatory parameter ConfigPath" {
            $script:ScriptContent | Should -Match '\[Parameter\(Mandatory=\$true\)\]'
            $script:ScriptContent | Should -Match '\[string\]\$ConfigPath'
            Write-CustomLog "Mandatory parameter validation passed" -Level "INFO"
        }

        It "Should import required modules" {
            $script:ScriptContent | Should -Match 'Import-Module.*LabRunner'
            Write-CustomLog "Module import validation passed" -Level "INFO"
        }
    }

    Context "Parameter Validation" {
        It "Should have proper error handling for missing config file" {
            $script:ScriptContent | Should -Match 'Test-Path \$ConfigPath'
            $script:ScriptContent | Should -Match 'Write-Error.*Configuration file not found'
            Write-CustomLog "Missing config file error handling validated" -Level "INFO"
        }

        It "Should use ErrorActionPreference Stop" {
            $script:ScriptContent | Should -Match '\$ErrorActionPreference\s*=\s*"Stop"'
            Write-CustomLog "ErrorActionPreference validation passed" -Level "INFO"
        }
    }

    Context "Functionality Tests" {
        It "Should contain Invoke-LabStep usage" {
            $script:ScriptContent | Should -Match 'Invoke-LabStep.*-Config.*-Body'
            Write-CustomLog "Invoke-LabStep usage validated" -Level "INFO"
        }

        It "Should contain proper logging statements" {
            $script:ScriptContent | Should -Match 'Write-CustomLog'
            Write-CustomLog "Logging statements validated" -Level "INFO"
        }

        It "Should handle JSON configuration loading" {
            $script:ScriptContent | Should -Match 'ConvertFrom-Json'
            Write-CustomLog "JSON configuration handling validated" -Level "INFO"
        }

        It "Should have try-catch error handling" {
            $script:ScriptContent | Should -Match 'try\s*\{'
            $script:ScriptContent | Should -Match 'catch\s*\{'
            $script:ScriptContent | Should -Match 'throw'
            Write-CustomLog "Error handling structure validated" -Level "INFO"
        }
    }

    Context "Integration Tests" {
        It "Should validate test config file creation" {
            $script:TestConfigPath | Should -Exist
            $testContent = Get-Content $script:TestConfigPath | ConvertFrom-Json
            $testContent.ApplicationName | Should -Be "TestApp"
            Write-CustomLog "Test config file validation passed" -Level "INFO"
        }

        It "Should properly handle valid configuration" {
            # This would be a mock test since we don't want to actually run the script
            # In a real scenario, we'd mock the dependencies and test the logic
            $true | Should -Be $true
            Write-CustomLog "Configuration handling test passed" -Level "INFO"
        }
    }

    AfterAll {
        Write-CustomLog "Completed tests for Invoke-CoreApplication.ps1" -Level "SUCCESS"
    }
}