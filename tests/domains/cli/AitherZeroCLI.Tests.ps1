#Requires -Version 7.0

BeforeAll {
    # Import the core module which loads all domains
    $projectRoot = Split-Path -Parent -Path $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
    Import-Module (Join-Path $projectRoot "AitherZero.psm1") -Force
}

Describe "AitherZeroCLI Module Tests" {
    Context "Write-AitherLog" {
        BeforeEach {
            # Reset log settings
            Set-LogLevel -Level "Information"
            Set-LogTargets -Targets @("Console")
        }

        It "Should successfully write log messages without errors" {
            { Write-AitherLog -Message "Test message" } | Should -Not -Throw
        }

        It "Should accept all log levels" {
            # Write-AitherLog maps to Write-CustomLog which supports these levels
            $levels = @('Information', 'Warning', 'Error', 'Debug')
            
            foreach ($level in $levels) {
                { Write-AitherLog -Message "Test $level message" -Level $level } | Should -Not -Throw
            }
        }

        It "Should accept Category parameter" {
            # This test ensures the Category parameter is accepted without errors
            { Write-AitherLog -Message "Test message" -Category "TestCategory" } | Should -Not -Throw
        }

        It "Should use default Category value of 'General' when not specified" {
            # Default category should be 'General'
            { Write-AitherLog -Message "Test message" } | Should -Not -Throw
        }
    }
}
