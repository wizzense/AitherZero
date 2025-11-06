#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for ModalUIEngine module
#>

BeforeAll {
    $projectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    $script:ModulePath = Join-Path $projectRoot "domains/experience/ModalUIEngine.psm1"
    
    if (-not (Test-Path $script:ModulePath)) {
        throw "Module not found at: $script:ModulePath"
    }
    
    Import-Module $script:ModulePath -Force
}

Describe "ModalUIEngine" -Tag 'Unit', 'Experience', 'ModalUI' {
    
    Context "Initialization" {
        It "Should initialize modal engine" {
            { Initialize-ModalUIEngine } | Should -Not -Throw
        }
        
        It "Should start in Normal mode" {
            Initialize-ModalUIEngine
            $state = Get-ModalState
            
            $state.CurrentMode | Should -Be 'Normal'
            $state.IsInitialized | Should -Be $true
        }
        
        It "Should clear all state on initialization" {
            Initialize-ModalUIEngine
            $state = Get-ModalState
            
            $state.KeyBuffer | Should -Be ''
            $state.SelectedIndex | Should -Be 0
            $state.SearchResultCount | Should -Be 0
        }
        
        It "Should be idempotent" {
            Initialize-ModalUIEngine
            { Initialize-ModalUIEngine } | Should -Not -Throw
            
            $state = Get-ModalState
            $state.CurrentMode | Should -Be 'Normal'
        }
    }
    
    Context "Mode Switching" {
        BeforeEach {
            Initialize-ModalUIEngine -Force
        }
        
        It "Should enter Command mode from Normal" {
            Enter-Mode -Mode 'Command'
            $state = Get-ModalState
            
            $state.CurrentMode | Should -Be 'Command'
            $state.PreviousMode | Should -Be 'Normal'
        }
        
        It "Should enter Search mode from Normal" {
            Enter-Mode -Mode 'Search'
            $state = Get-ModalState
            
            $state.CurrentMode | Should -Be 'Search'
            $state.PreviousMode | Should -Be 'Normal'
        }
        
        It "Should clear buffer when entering mode (default)" {
            Add-ToKeyBuffer -Text "test"
            Enter-Mode -Mode 'Command'
            
            $buffer = Get-KeyBuffer
            $buffer | Should -Be ''
        }
        
        It "Should preserve buffer with -PreserveBuffer switch" {
            Add-ToKeyBuffer -Text "test"
            Enter-Mode -Mode 'Command' -PreserveBuffer
            
            $buffer = Get-KeyBuffer
            $buffer | Should -Be 'test'
        }
        
        It "Should exit mode and return to previous" {
            Enter-Mode -Mode 'Command'
            Exit-Mode
            
            $state = Get-ModalState
            $state.CurrentMode | Should -Be 'Normal'
        }
        
        It "Should handle exit from Normal mode gracefully" {
            { Exit-Mode } | Should -Not -Throw
            
            $state = Get-ModalState
            $state.CurrentMode | Should -Be 'Normal'
        }
        
        It "Should maintain mode history" {
            Enter-Mode -Mode 'Command'
            Enter-Mode -Mode 'Search'
            Exit-Mode
            
            $state = Get-ModalState
            $state.CurrentMode | Should -Be 'Command'
        }
    }
    
    Context "Key Buffer Management" {
        BeforeEach {
            Initialize-ModalUIEngine -Force
        }
        
        It "Should add text to buffer" {
            Add-ToKeyBuffer -Text "test"
            $buffer = Get-KeyBuffer
            
            $buffer | Should -Be "test"
        }
        
        It "Should append text to existing buffer" {
            Add-ToKeyBuffer -Text "hello"
            Add-ToKeyBuffer -Text " "
            Add-ToKeyBuffer -Text "world"
            
            $buffer = Get-KeyBuffer
            $buffer | Should -Be "hello world"
        }
        
        It "Should remove last character with backspace" {
            Add-ToKeyBuffer -Text "test"
            Remove-FromKeyBuffer
            
            $buffer = Get-KeyBuffer
            $buffer | Should -Be "tes"
        }
        
        It "Should handle backspace on empty buffer" {
            { Remove-FromKeyBuffer } | Should -Not -Throw
            
            $buffer = Get-KeyBuffer
            $buffer | Should -Be ''
        }
        
        It "Should clear buffer" {
            Add-ToKeyBuffer -Text "test"
            Clear-KeyBuffer
            
            $buffer = Get-KeyBuffer
            $buffer | Should -Be ''
        }
    }
    
    Context "Command History" {
        BeforeEach {
            Initialize-ModalUIEngine -Force
        }
        
        It "Should add command to history" {
            Add-ToCommandHistory -Command ":run 0402"
            
            $state = Get-ModalState
            $state.CommandHistoryCount | Should -BeGreaterThan 0
        }
        
        It "Should not add empty commands" {
            Add-ToCommandHistory -Command ""
            Add-ToCommandHistory -Command "   "
            
            $state = Get-ModalState
            $state.CommandHistoryCount | Should -Be 0
        }
        
        It "Should navigate up in history" {
            Add-ToCommandHistory -Command ":run 0402"
            Add-ToCommandHistory -Command ":run 0404"
            
            $cmd = Get-CommandFromHistory -Direction 'Up'
            $cmd | Should -Be ":run 0404"
        }
        
        It "Should navigate down in history" {
            Add-ToCommandHistory -Command ":run 0402"
            Add-ToCommandHistory -Command ":run 0404"
            
            Get-CommandFromHistory -Direction 'Up' | Out-Null
            Get-CommandFromHistory -Direction 'Up' | Out-Null
            $cmd = Get-CommandFromHistory -Direction 'Down'
            
            $cmd | Should -Be ":run 0404"
        }
        
        It "Should handle history navigation at bounds" {
            Add-ToCommandHistory -Command ":run 0402"
            
            $cmd1 = Get-CommandFromHistory -Direction 'Up'
            $cmd2 = Get-CommandFromHistory -Direction 'Up'  # At top
            
            $cmd1 | Should -Be $cmd2
        }
        
        It "Should limit history to 50 items" {
            1..60 | ForEach-Object {
                Add-ToCommandHistory -Command ":command $_"
            }
            
            $state = Get-ModalState
            $state.CommandHistoryCount | Should -BeLessOrEqual 50
        }
    }
    
    Context "Selection Index" {
        BeforeEach {
            Initialize-ModalUIEngine -Force
        }
        
        It "Should get selection index" {
            $index = Get-SelectedIndex
            $index | Should -Be 0
        }
        
        It "Should set selection index" {
            Set-SelectedIndex -Index 5
            $index = Get-SelectedIndex
            
            $index | Should -Be 5
        }
        
        It "Should not allow negative index" {
            Set-SelectedIndex -Index -5
            $index = Get-SelectedIndex
            
            $index | Should -Be 0
        }
    }
    
    Context "Search Results" {
        BeforeEach {
            Initialize-ModalUIEngine -Force
        }
        
        It "Should set search results" {
            $items = @('item1', 'item2', 'item3')
            Set-SearchResults -Results $items
            
            $results = Get-SearchResults
            $results.Count | Should -Be 3
        }
        
        It "Should handle empty search results" {
            Set-SearchResults -Results @()
            
            $results = Get-SearchResults
            $results.Count | Should -Be 0
        }
        
        It "Should update state with result count" {
            Set-SearchResults -Results @('a', 'b')
            
            $state = Get-ModalState
            $state.SearchResultCount | Should -Be 2
        }
    }
    
    Context "Reset" {
        It "Should reset to clean state" {
            Initialize-ModalUIEngine
            Enter-Mode -Mode 'Command'
            Add-ToKeyBuffer -Text "test"
            Set-SelectedIndex -Index 10
            
            Reset-ModalUIEngine
            
            $state = Get-ModalState
            $state.CurrentMode | Should -Be 'Normal'
            $state.KeyBuffer | Should -Be ''
            $state.SelectedIndex | Should -Be 0
        }
        
        It "Should preserve command history on reset" {
            Initialize-ModalUIEngine
            Add-ToCommandHistory -Command ":run 0402"
            
            Reset-ModalUIEngine
            
            $state = Get-ModalState
            $state.CommandHistoryCount | Should -BeGreaterThan 0
        }
    }
    
    Context "State Isolation" {
        It "Should return independent state objects" {
            Initialize-ModalUIEngine
            
            $state1 = Get-ModalState
            $state2 = Get-ModalState
            
            # Modifying one shouldn't affect the other
            $state1.CurrentMode = 'Modified'
            $state2.CurrentMode | Should -Be 'Normal'
        }
    }
}
