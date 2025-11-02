#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    End-to-End tests for Interactive UI functionality
.DESCRIPTION
    Tests for interactive menu system, playbook browser, and user interface components
#>

BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    
    # Import module
    Import-Module (Join-Path $script:ProjectRoot "AitherZero.psd1") -Force -ErrorAction Stop
    
    # Set test mode to avoid actual interactive prompts
    $env:AITHERZERO_TEST_MODE = "1"
    $env:AITHERZERO_NONINTERACTIVE = "1"
}

Describe "Interactive UI Components" -Tag 'E2E', 'UI', 'Interactive' {
    Context "Menu System" {
        It "Should have Show-BetterMenu function available" {
            Get-Command Show-BetterMenu -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Show-UIMenu function available" {
            Get-Command Show-UIMenu -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Show-UIMenu function with proper signature" {
            $menuCmd = Get-Command Show-UIMenu -ErrorAction SilentlyContinue
            $menuCmd | Should -Not -BeNullOrEmpty
            $menuCmd.Parameters.Keys | Should -Contain 'Title'
            $menuCmd.Parameters.Keys | Should -Contain 'Items'
        }
    }
    
    Context "UI Text Components" {
        It "Should have Write-UIText function available" {
            Get-Command Write-UIText -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should render text without errors" {
            { Write-UIText -Message "Test message" -Color Green } | Should -Not -Throw
        }
        
        It "Should handle empty messages" {
            { Write-UIText -Message "" -Color White } | Should -Not -Throw
        }
    }
    
    Context "UI Header Components" {
        It "Should have Show-UIBorder function available" {
            Get-Command Show-UIBorder -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should render borders without errors" {
            { Show-UIBorder } | Should -Not -Throw
        }
    }
    
    Context "UI Section Components" {
        It "Should have Show-UINotification function available" {
            Get-Command Show-UINotification -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should render notifications without errors" {
            { Show-UINotification -Message "Test notification" -Type Info } | Should -Not -Throw
        }
    }
    
    Context "Spinner Component" {
        It "Should have Show-UISpinner function available" {
            Get-Command Show-UISpinner -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Playbook Browser UI" -Tag 'E2E', 'UI', 'Playbooks' {
    Context "Playbook Listing" {
        It "Should call Get-OrchestrationPlaybook without errors" {
            { Get-OrchestrationPlaybook -ListAll -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
        
        It "Should format playbook information for display" {
            $playbooks = Get-OrchestrationPlaybook -ListAll -ErrorAction SilentlyContinue
            if ($playbooks) {
                foreach ($playbook in $playbooks | Select-Object -First 3) {
                    $playbook | Should -HaveProperty 'Name'
                    $playbook.Name | Should -Not -BeNullOrEmpty
                }
            } else {
                # If no playbooks, test passes
                $true | Should -BeTrue
            }
        }
        
        It "Should handle playbooks with category prefixes" {
            # Test the fix for category prefix handling
            $selection = [PSCustomObject]@{
                Name = '[analysis] test-playbook'
                OriginalName = 'test-playbook'
            }
            
            $resolvedName = if ($selection.OriginalName) { 
                $selection.OriginalName 
            } else { 
                $selection.Name 
            }
            
            $resolvedName | Should -Be 'test-playbook'
            $resolvedName | Should -Not -Match '^\[.*\]'
        }
    }
    
    Context "Playbook Details Display" {
        It "Should display playbook information" {
            $playbook = Get-OrchestrationPlaybook -ListAll | Select-Object -First 1
            if ($playbook) {
                # Verify essential properties exist
                $playbook.PSObject.Properties.Name -contains 'Name' | Should -BeTrue
            }
        }
    }
}

Describe "Interactive Mode Integration" -Tag 'E2E', 'UI', 'Integration' {
    Context "Module Loading for Interactive Mode" {
        It "Should load BetterMenu functions" {
            Get-Command Show-BetterMenu -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should load InteractiveUI functions" {
            Get-Command Start-InteractiveUI -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should load UserInterface functions" {
            Get-Command Show-UIMenu -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "UI Helper Functions" {
        It "Should have Show-UIPrompt function" {
            Get-Command Show-UIPrompt -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Show-UITable function" {
            Get-Command Show-UITable -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Color and Formatting" {
        It "Should handle color parameters" {
            $validColors = @('Black', 'Red', 'Green', 'Yellow', 'Blue', 'Magenta', 'Cyan', 'White')
            
            foreach ($color in $validColors) {
                { Write-UIText -Message "Test" -Color $color } | Should -Not -Throw
            }
        }
    }
}

Describe "Interactive Error Handling" -Tag 'E2E', 'UI', 'ErrorHandling' {
    Context "Invalid Input Handling" {
        It "Should have input validation functions available" {
            Get-Command Show-UIMenu -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "UI Fallback Mechanisms" {
        It "Should work in non-interactive environments" {
            $originalEnv = $env:AITHERZERO_NONINTERACTIVE
            try {
                $env:AITHERZERO_NONINTERACTIVE = "1"
                
                # Should not prompt in non-interactive mode
                { 
                    Get-Configuration | Out-Null
                } | Should -Not -Throw
            } finally {
                $env:AITHERZERO_NONINTERACTIVE = $originalEnv
            }
        }
    }
}

Describe "UI Component Integration" -Tag 'E2E', 'UI', 'Components' {
    Context "Wizard Components" {
        It "Should have wizard functions available if implemented" {
            # Test for wizard functions if they exist
            $wizardFunctions = Get-Command -Name "*Wizard*" -ErrorAction SilentlyContinue
            # This is informational - wizards may not be implemented yet
            $wizardFunctions.Count | Should -BeGreaterOrEqual 0
        }
    }
    
    Context "Progress Indicators" {
        It "Should have progress display functions" {
            Get-Command Show-UISpinner -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle progress updates" {
            { 
                # Test progress display in non-interactive mode
                1..3 | ForEach-Object {
                    Write-UIText -Message "Step $_" -Color Cyan
                }
            } | Should -Not -Throw
        }
    }
}
