#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Tests for CommandParser component
#>

BeforeAll {
    # Navigate up from tests/unit/domains/experience to project root, then to module
    $projectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    $script:ModulePath = Join-Path $projectRoot "domains/experience/Components/CommandParser.psm1"
    
    if (-not (Test-Path $script:ModulePath)) {
        throw "Module not found at: $script:ModulePath"
    }
    
    Import-Module $script:ModulePath -Force
}

Describe "CommandParser" -Tag 'Unit', 'Experience' {
    Context "Basic Command Parsing" {
        It "Should parse Run mode with Target" {
            $result = Parse-AitherCommand "-Mode Run -Target 0402"
            
            $result.IsValid | Should -Be $true
            $result.Mode | Should -Be 'Run'
            $result.Parameters.Target | Should -Be '0402'
            $result.Error | Should -BeNullOrEmpty
        }
        
        It "Should parse Orchestrate mode with Playbook" {
            $result = Parse-AitherCommand "-Mode Orchestrate -Playbook test-quick"
            
            $result.IsValid | Should -Be $true
            $result.Mode | Should -Be 'Orchestrate'
            $result.Parameters.Playbook | Should -Be 'test-quick'
        }
        
        It "Should parse Search mode with Query" {
            $result = Parse-AitherCommand "-Mode Search -Query security"
            
            $result.IsValid | Should -Be $true
            $result.Mode | Should -Be 'Search'
            $result.Parameters.Query | Should -Be 'security'
        }
        
        It "Should handle quoted values with spaces" {
            $result = Parse-AitherCommand '-Mode Search -Query "security tools"'
            
            $result.IsValid | Should -Be $true
            $result.Parameters.Query | Should -Be 'security tools'
        }
        
        It "Should handle multiple parameters" {
            $result = Parse-AitherCommand "-Mode Orchestrate -Playbook test-quick -PlaybookProfile full"
            
            $result.IsValid | Should -Be $true
            $result.Mode | Should -Be 'Orchestrate'
            $result.Parameters.Playbook | Should -Be 'test-quick'
            $result.Parameters.PlaybookProfile | Should -Be 'full'
        }
    }
    
    Context "Shortcut Resolution" {
        It "Should resolve 'test' shortcut" {
            $result = Parse-AitherCommand "test"
            
            $result.IsValid | Should -Be $true
            $result.Mode | Should -Be 'Run'
        }
        
        It "Should resolve 'lint' shortcut" {
            $result = Parse-AitherCommand "lint"
            
            $result.IsValid | Should -Be $true
            $result.Mode | Should -Be 'Run'
            $result.Parameters.Target | Should -Be '0404'
        }
        
        It "Should resolve 'quick-test' shortcut" {
            $result = Parse-AitherCommand "quick-test"
            
            $result.IsValid | Should -Be $true
            $result.Mode | Should -Be 'Orchestrate'
            $result.Parameters.Playbook | Should -Be 'test-quick'
        }
        
        It "Should parse bare script number" {
            $result = Parse-AitherCommand "0402"
            
            $result.IsValid | Should -Be $true
            $result.Mode | Should -Be 'Run'
            $result.Parameters.Target | Should -Be '0402'
        }
    }
    
    Context "Error Handling" {
        It "Should reject empty command" {
            $result = Parse-AitherCommand ""
            
            $result.IsValid | Should -Be $false
            $result.Error | Should -Match "Empty command"
        }
        
        It "Should reject command without Mode" {
            $result = Parse-AitherCommand "-Target 0402"
            
            $result.IsValid | Should -Be $false
            $result.Error | Should -Match "Mode parameter is required"
        }
        
        It "Should reject invalid mode" {
            $result = Parse-AitherCommand "-Mode InvalidMode -Target 0402"
            
            $result.IsValid | Should -Be $false
            $result.Error | Should -Match "Invalid mode"
        }
        
        It "Should reject Run mode without Target" {
            $result = Parse-AitherCommand "-Mode Run"
            
            $result.IsValid | Should -Be $false
            $result.Error | Should -Match "requires -Target"
        }
        
        It "Should reject Orchestrate mode without Playbook" {
            $result = Parse-AitherCommand "-Mode Orchestrate"
            
            $result.IsValid | Should -Be $false
            $result.Error | Should -Match "requires -Playbook"
        }
        
        It "Should reject Search mode without Query" {
            $result = Parse-AitherCommand "-Mode Search"
            
            $result.IsValid | Should -Be $false
            $result.Error | Should -Match "requires -Query"
        }
        
        It "Should reject invalid format" {
            $result = Parse-AitherCommand "random text"
            
            $result.IsValid | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Command Building" {
        It "Should build simple command" {
            $cmd = Build-AitherCommand -Mode 'Run' -Parameters @{ Target = '0402' }
            
            $cmd | Should -Be '-Mode Run -Target 0402'
        }
        
        It "Should build command with quoted values" {
            $cmd = Build-AitherCommand -Mode 'Search' -Parameters @{ Query = 'security tools' }
            
            $cmd | Should -Match '-Mode Search -Query "security tools"'
        }
        
        It "Should build command with multiple parameters" {
            $cmd = Build-AitherCommand -Mode 'Orchestrate' -Parameters @{ 
                Playbook = 'test-quick'
                PlaybookProfile = 'full'
            }
            
            $cmd | Should -Match '-Mode Orchestrate'
            $cmd | Should -Match '-Playbook test-quick'
            $cmd | Should -Match '-PlaybookProfile full'
        }
    }
    
    Context "Command Validation" {
        It "Should validate complete command" {
            $parsed = Parse-AitherCommand "-Mode Run -Target 0402"
            $isComplete = Test-CommandComplete -ParsedCommand $parsed
            
            $isComplete | Should -Be $true
        }
        
        It "Should invalidate incomplete command" {
            $parsed = @{ IsValid = $false; Error = 'Test error' }
            $isComplete = Test-CommandComplete -ParsedCommand $parsed
            
            $isComplete | Should -Be $false
        }
    }
    
    Context "Command Suggestions" {
        It "Should suggest modes for empty input" {
            $suggestions = Get-CommandSuggestions "-"
            
            $suggestions | Should -Contain '-Mode'
        }
        
        It "Should suggest mode values" {
            $suggestions = Get-CommandSuggestions "-Mode R"
            
            $suggestions | Should -Contain 'Run'
        }
        
        It "Should suggest next parameters for Run mode" {
            $suggestions = Get-CommandSuggestions "-Mode Run "
            
            $suggestions | Should -Contain '-Target'
        }
        
        It "Should suggest next parameters for Orchestrate mode" {
            $suggestions = Get-CommandSuggestions "-Mode Orchestrate "
            
            $suggestions | Should -Contain '-Playbook'
        }
        
        It "Should suggest parameter names" {
            $suggestions = Get-CommandSuggestions "-T"
            
            $suggestions | Should -Contain '-Target'
        }
    }
    
    Context "Command Formatting" {
        It "Should format valid command" {
            $parsed = Parse-AitherCommand "-Mode Run -Target 0402"
            $formatted = Format-ParsedCommand -ParsedCommand $parsed
            
            $formatted | Should -Match "Mode: Run"
            $formatted | Should -Match "Target=0402"
        }
        
        It "Should format invalid command" {
            $parsed = @{ IsValid = $false; Error = 'Test error' }
            $formatted = Format-ParsedCommand -ParsedCommand $parsed
            
            $formatted | Should -Match "Invalid"
            $formatted | Should -Match "Test error"
        }
    }
}
