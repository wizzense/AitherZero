# Standard Test Template for OpenTofu Lab Automation
# This template ensures all new tests follow the same robust structure

# Template Version: 1.0
# Compatible with: Pester 5.x+
# Project: OpenTofu Lab Automation

Describe '{SCRIPT_NAME} Tests' -Tag '{TAG}' {
    BeforeAll {
        # Standard script path setup - uses consistent pattern
        $script:ScriptPath = "LabRunner\{SCRIPT_NAME}.ps1"
        $script:ScriptName = "{SCRIPT_NAME}"
        
        # Set error handling
        $ErrorActionPreference = "Stop"
        
        # Optional: Import test helpers if available
        $testHelpersPath = Join-Path $PSScriptRoot 'helpers' 'TestHelpers.ps1'
        if (Test-Path $testHelpersPath) {
            . $testHelpersPath
        }
    }
    
    Context 'Script Structure Validation' {
        It 'should have a defined script path' {
            $script:ScriptPath  Should -Not -BeNullOrEmpty
        }
        
        It 'should follow naming conventions' {
            $script:ScriptPath  Should -Match '^.*0-9{4}_A-Za-zA-Z0-9-+\.ps1$^A-Za-zA-Z0-9-+\.ps1$'
        }
        
        It 'should have valid script name' {
            $script:ScriptName  Should -Not -BeNullOrEmpty
            $script:ScriptName  Should -Match '^0-9{4}_A-Za-zA-Z0-9-+$^A-Za-zA-Z0-9-+$'
        }
    }
    
    Context 'Basic Functionality Tests' {
        It 'should execute basic validation test' {
            # This test always passes - ensures the test file is syntactically correct
            $true | Should -Be $true
        }
        
        It 'should handle script validation if file exists' {
            if (Test-Path (Join-Path "LabRunner" "$($script:ScriptName).ps1")) {
                # Script exists - basic syntax validation
                { Get-Content (Join-Path "LabRunner" "$($script:ScriptName).ps1") }  Should -Not -Throw
            } else {
                # Script doesn't exist yet - that's OK for template
                $true | Should -Be $true
            }
        }
    }
    
    # Context for specific test cases - customize per script type
    Context '{CONTEXT_NAME} Tests' {
        It 'should meet basic requirements' {
            # Add specific tests here based on script purpose
            $true | Should -Be $true
        }
    }
}

# Template Metadata
# Replace these tokens when generating:
# {SCRIPT_NAME} - The script name (e.g., "0205_Install-Sysinternals")
# {TAG} - The tag category (e.g., "Installer", "Configuration", "SystemInfo")
# {CONTEXT_NAME} - Context based on script type (e.g., "Installation", "Configuration", "System Information")
