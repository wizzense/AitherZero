#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for ModalCommandParser module
#>

BeforeAll {
    $projectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    $script:ModulePath = Join-Path $projectRoot "domains/experience/Commands/ModalCommandParser.psm1"
    
    if (-not (Test-Path $script:ModulePath)) {
        throw "Module not found at: $script:ModulePath"
    }
    
    Import-Module $script:ModulePath -Force
}

Describe "ModalCommandParser" -Tag 'Unit', 'Experience', 'ModalUI', 'CommandParser' {
    
    Context "Basic Command Parsing" {
        It "Should parse run command" {
            $result = Parse-ModalCommand -CommandText ":run 0402"
            
            $result.IsValid | Should -Be $true
            $result.Command | Should -Be 'run'
            $result.Arguments | Should -Contain '0402'
        }
        
        It "Should parse orchestrate command" {
            $result = Parse-ModalCommand -CommandText ":orchestrate test-quick"
            
            $result.IsValid | Should -Be $true
            $result.Command | Should -Be 'orchestrate'
            $result.Arguments | Should -Contain 'test-quick'
        }
        
        It "Should parse command without leading colon" {
            $result = Parse-ModalCommand -CommandText "run 0402"
            
            $result.IsValid | Should -Be $true
            $result.Command | Should -Be 'run'
        }
        
        It "Should handle empty command" {
            $result = Parse-ModalCommand -CommandText ""
            
            $result.IsValid | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle whitespace-only command" {
            $result = Parse-ModalCommand -CommandText "   "
            
            $result.IsValid | Should -Be $false
        }
    }
    
    Context "Command Shortcuts" {
        It "Should expand 'r' to 'run'" {
            $result = Parse-ModalCommand -CommandText ":r 0402"
            
            $result.Command | Should -Be 'run'
        }
        
        It "Should expand 'o' to 'orchestrate'" {
            $result = Parse-ModalCommand -CommandText ":o test"
            
            $result.Command | Should -Be 'orchestrate'
        }
        
        It "Should expand 's' to 'search'" {
            $result = Parse-ModalCommand -CommandText ":s pattern"
            
            $result.Command | Should -Be 'search'
        }
        
        It "Should expand 'b' to 'bookmarks'" {
            $result = Parse-ModalCommand -CommandText ":b"
            
            $result.Command | Should -Be 'bookmarks'
        }
        
        It "Should expand 'h' to 'health'" {
            $result = Parse-ModalCommand -CommandText ":h"
            
            $result.Command | Should -Be 'health'
        }
        
        It "Should expand 'q' to 'quit'" {
            $result = Parse-ModalCommand -CommandText ":q"
            
            $result.Command | Should -Be 'quit'
        }
    }
    
    Context "Multi-word Arguments" {
        It "Should handle arguments with spaces" {
            $result = Parse-ModalCommand -CommandText ":search error message"
            
            $result.Arguments.Count | Should -BeGreaterThan 0
            $result.Arguments -join ' ' | Should -Match 'error'
        }
        
        It "Should split arguments by whitespace" {
            $result = Parse-ModalCommand -CommandText ":session save my-work"
            
            $result.Command | Should -Be 'session'
            $result.Arguments | Should -Contain 'save'
            $result.Arguments | Should -Contain 'my-work'
        }
    }
    
    Context "Command Validation" {
        It "Should validate known commands" {
            $commands = @('run', 'orchestrate', 'search', 'bookmarks', 'health', 'quit', 'session')
            
            foreach ($cmd in $commands) {
                Test-ModalCommand -CommandName $cmd | Should -Be $true
            }
        }
        
        It "Should reject unknown commands" {
            Test-ModalCommand -CommandName 'unknown-command' | Should -Be $false
        }
    }
    
    Context "Argument Validation" {
        It "Should validate run command requires script number" {
            $parsed = Parse-ModalCommand -CommandText ":run"
            $validation = Test-ModalCommandArguments -ParsedCommand $parsed
            
            $validation.IsValid | Should -Be $false
            $validation.Error | Should -Match 'requires a script number'
        }
        
        It "Should validate script number format" {
            $parsed = Parse-ModalCommand -CommandText ":run abc"
            $validation = Test-ModalCommandArguments -ParsedCommand $parsed
            
            $validation.IsValid | Should -Be $false
            $validation.Error | Should -Match '4 digits'
        }
        
        It "Should accept valid script number" {
            $parsed = Parse-ModalCommand -CommandText ":run 0402"
            $validation = Test-ModalCommandArguments -ParsedCommand $parsed
            
            $validation.IsValid | Should -Be $true
        }
        
        It "Should validate orchestrate requires playbook name" {
            $parsed = Parse-ModalCommand -CommandText ":orchestrate"
            $validation = Test-ModalCommandArguments -ParsedCommand $parsed
            
            $validation.IsValid | Should -Be $false
        }
        
        It "Should validate search requires pattern" {
            $parsed = Parse-ModalCommand -CommandText ":search"
            $validation = Test-ModalCommandArguments -ParsedCommand $parsed
            
            $validation.IsValid | Should -Be $false
        }
        
        It "Should allow commands without required arguments" {
            $parsed = Parse-ModalCommand -CommandText ":quit"
            $validation = Test-ModalCommandArguments -ParsedCommand $parsed
            
            $validation.IsValid | Should -Be $true
        }
    }
    
    Context "Command Help" {
        It "Should provide help for run command" {
            $help = Get-ModalCommandHelp -CommandName 'run'
            
            $help | Should -Not -BeNullOrEmpty
            $help | Should -Match ':run'
            $help | Should -Match 'script'
        }
        
        It "Should provide help for orchestrate command" {
            $help = Get-ModalCommandHelp -CommandName 'orchestrate'
            
            $help | Should -Match 'playbook'
        }
        
        It "Should handle unknown command help" {
            $help = Get-ModalCommandHelp -CommandName 'unknown'
            
            $help | Should -Match 'No help available'
        }
    }
    
    Context "Command List" {
        It "Should return all available commands" {
            $commands = Get-ModalCommands
            
            $commands.Count | Should -BeGreaterThan 0
            $commands[0].Command | Should -Not -BeNullOrEmpty
            $commands[0].Description | Should -Not -BeNullOrEmpty
        }
        
        It "Should include shortcuts in command info" {
            $commands = Get-ModalCommands
            $runCmd = $commands | Where-Object { $_.Command -eq 'run' }
            
            $runCmd.Shortcuts | Should -Contain 'r'
        }
    }
    
    Context "Autocomplete Suggestions" {
        It "Should return all commands for empty input" {
            $suggestions = Get-ModalCommandSuggestions -Partial ''
            
            $suggestions.Count | Should -BeGreaterThan 0
        }
        
        It "Should filter by partial match" {
            $suggestions = Get-ModalCommandSuggestions -Partial 'ru'
            
            $suggestions | Should -Contain 'run'
            $suggestions | Should -Not -Contain 'orchestrate'
        }
        
        It "Should match shortcuts" {
            $suggestions = Get-ModalCommandSuggestions -Partial 'r'
            
            $suggestions | Should -Contain 'run'
        }
        
        It "Should be case-insensitive" {
            $suggestions = Get-ModalCommandSuggestions -Partial 'RUN'
            
            $suggestions | Should -Contain 'run'
        }
        
        It "Should return unique results" {
            $suggestions = Get-ModalCommandSuggestions -Partial 'r'
            
            $unique = $suggestions | Select-Object -Unique
            $suggestions.Count | Should -Be $unique.Count
        }
    }
    
    Context "Command Formatting" {
        It "Should format valid command" {
            $parsed = Parse-ModalCommand -CommandText ":run 0402"
            $formatted = Format-ModalCommand -ParsedCommand $parsed
            
            $formatted | Should -Match ':run'
            $formatted | Should -Match '0402'
        }
        
        It "Should format command without arguments" {
            $parsed = Parse-ModalCommand -CommandText ":quit"
            $formatted = Format-ModalCommand -ParsedCommand $parsed
            
            $formatted | Should -Be ':quit'
        }
        
        It "Should show error for invalid command" {
            $parsed = Parse-ModalCommand -CommandText ""
            $formatted = Format-ModalCommand -ParsedCommand $parsed
            
            $formatted | Should -Match 'Invalid'
        }
    }
    
    Context "Raw Text Preservation" {
        It "Should preserve original command text" {
            $input = ":run 0402"
            $result = Parse-ModalCommand -CommandText $input
            
            $result.RawText | Should -Be $input
        }
    }
    
    Context "Case Insensitivity" {
        It "Should parse uppercase commands" {
            $result = Parse-ModalCommand -CommandText ":RUN 0402"
            
            $result.IsValid | Should -Be $true
            $result.Command | Should -Be 'run'
        }
        
        It "Should parse mixed case commands" {
            $result = Parse-ModalCommand -CommandText ":OrChEsTrAtE test"
            
            $result.IsValid | Should -Be $true
            $result.Command | Should -Be 'orchestrate'
        }
    }
}
