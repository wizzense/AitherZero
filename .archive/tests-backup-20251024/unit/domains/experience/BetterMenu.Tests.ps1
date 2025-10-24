#Requires -Version 7.0
#Requires -Modules Pester

BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    $script:ModulePath = Join-Path $script:ProjectRoot "domains/experience/BetterMenu.psm1"
    
    # Import module
    Import-Module $script:ModulePath -Force
}

Describe "Show-BetterMenu" -Tag 'Unit' {
    Context "Non-Interactive Mode" {
        BeforeEach {
            $env:AITHERZERO_NONINTERACTIVE = 'true'
            Mock Write-Host { }
            Mock Clear-Host { }
        }
        
        AfterEach {
            Remove-Item env:AITHERZERO_NONINTERACTIVE -ErrorAction SilentlyContinue
        }
        
        It "Should display numbered menu in non-interactive mode" {
            Mock Read-Host { return "1" } -ModuleName BetterMenu
            
            $items = @("Option 1", "Option 2", "Option 3")
            $result = Show-BetterMenu -Title "Test" -Items $items -ShowNumbers
            
            $result | Should -Be "Option 1"
            Should -Invoke Read-Host -Times 1 -ModuleName BetterMenu
        }
        
        It "Should handle custom actions in non-interactive mode" {
            Mock Read-Host { return "Q" } -ModuleName BetterMenu
            
            $items = @("Option 1", "Option 2")
            $result = Show-BetterMenu -Title "Test" -Items $items -CustomActions @{ 'Q' = 'Quit' }
            
            $result | Should -BeOfType [hashtable]
            $result.Action | Should -Be "Q"
        }
        
        It "Should return null for invalid selection" {
            Mock Read-Host { return "99" } -ModuleName BetterMenu
            
            $items = @("Option 1", "Option 2")
            $result = Show-BetterMenu -Title "Test" -Items $items
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle objects with Name and Description" {
            Mock Read-Host { return "2" } -ModuleName BetterMenu
            
            $items = @(
                [PSCustomObject]@{ Name = "First"; Description = "First item" }
                [PSCustomObject]@{ Name = "Second"; Description = "Second item" }
            )
            $result = Show-BetterMenu -Title "Test" -Items $items
            
            $result.Name | Should -Be "Second"
            $result.Description | Should -Be "Second item"
        }
        
        It "Should handle empty input as cancellation" {
            Mock Read-Host { return "" } -ModuleName BetterMenu
            
            $items = @("Option 1", "Option 2")
            $result = Show-BetterMenu -Title "Test" -Items $items
            
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Interactive Mode Detection" {
        BeforeEach {
            Mock Write-Host { }
            Mock Clear-Host { }
        }
        
        It "Should detect non-interactive environment when KeyAvailable fails" {
            Mock Read-Host { return "1" } -ModuleName BetterMenu
            
            # Force non-interactive by setting env var
            $env:AITHERZERO_NONINTERACTIVE = 'true'
            
            $items = @("Option 1", "Option 2")
            $result = Show-BetterMenu -Title "Test" -Items $items
            
            $result | Should -Be "Option 1"
            Should -Invoke Read-Host -Times 1 -ModuleName BetterMenu
            
            Remove-Item env:AITHERZERO_NONINTERACTIVE -ErrorAction SilentlyContinue
        }
    }
    
    Context "Input Validation" {
        BeforeEach {
            $env:AITHERZERO_NONINTERACTIVE = 'true'
            Mock Write-Host { }
            Mock Clear-Host { }
        }
        
        AfterEach {
            Remove-Item env:AITHERZERO_NONINTERACTIVE -ErrorAction SilentlyContinue
        }
        
        It "Should handle numeric input correctly" {
            Mock Read-Host { return "3" } -ModuleName BetterMenu
            
            $items = @("First", "Second", "Third", "Fourth")
            $result = Show-BetterMenu -Title "Test" -Items $items
            
            $result | Should -Be "Third"
        }
        
        It "Should handle out-of-range numeric input" {
            Mock Read-Host { return "10" } -ModuleName BetterMenu
            
            $items = @("First", "Second")
            $result = Show-BetterMenu -Title "Test" -Items $items
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle negative numeric input" {
            Mock Read-Host { return "-1" } -ModuleName BetterMenu
            
            $items = @("First", "Second")
            $result = Show-BetterMenu -Title "Test" -Items $items
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should handle zero as invalid input" {
            Mock Read-Host { return "0" } -ModuleName BetterMenu
            
            $items = @("First", "Second")
            $result = Show-BetterMenu -Title "Test" -Items $items
            
            $result | Should -BeNullOrEmpty
        }
        
        It "Should be case-insensitive for custom actions" {
            Mock Read-Host { return "q" } -ModuleName BetterMenu
            
            $items = @("Option 1", "Option 2")
            $result = Show-BetterMenu -Title "Test" -Items $items -CustomActions @{ 'Q' = 'Quit' }
            
            $result | Should -BeOfType [hashtable]
            $result.Action | Should -Be "Q"
        }
    }
    
    Context "Edge Cases" {
        BeforeEach {
            $env:AITHERZERO_NONINTERACTIVE = 'true'
            Mock Write-Host { }
            Mock Clear-Host { }
        }
        
        AfterEach {
            Remove-Item env:AITHERZERO_NONINTERACTIVE -ErrorAction SilentlyContinue
        }
        
        It "Should handle single item list" {
            Mock Read-Host { return "1" } -ModuleName BetterMenu
            
            $items = @("Only Option")
            $result = Show-BetterMenu -Title "Test" -Items $items
            
            $result | Should -Be "Only Option"
        }
        
        It "Should handle empty title gracefully" {
            Mock Read-Host { return "1" } -ModuleName BetterMenu
            
            $items = @("Option 1", "Option 2")
            $result = Show-BetterMenu -Items $items
            
            $result | Should -Be "Option 1"
        }
        
        It "Should handle very long item lists" {
            Mock Read-Host { return "50" } -ModuleName BetterMenu
            
            $items = 1..100 | ForEach-Object { "Option $_" }
            $result = Show-BetterMenu -Title "Test" -Items $items
            
            $result | Should -Be "Option 50"
        }
        
        It "Should handle special characters in items" {
            Mock Read-Host { return "2" } -ModuleName BetterMenu
            
            $items = @("Normal", "Special!@#$%^&*()", "Another")
            $result = Show-BetterMenu -Title "Test" -Items $items
            
            $result | Should -Be "Special!@#$%^&*()"
        }
    }
}

Describe "Show-BetterMenu Performance" {
    BeforeEach {
        $env:AITHERZERO_NONINTERACTIVE = 'true'
        Mock Write-Host { }
        Mock Clear-Host { }
    }
    
    AfterEach {
        Remove-Item env:AITHERZERO_NONINTERACTIVE -ErrorAction SilentlyContinue
    }
    
    It "Should handle large item lists efficiently" {
        Mock Read-Host { return "500" } -ModuleName BetterMenu
        
        $items = 1..1000 | ForEach-Object { "Item $_" }
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $result = Show-BetterMenu -Title "Performance Test" -Items $items
        $stopwatch.Stop()
        
        $result | Should -Be "Item 500"
        $stopwatch.ElapsedMilliseconds | Should -BeLessThan 1000  # Should complete in under 1 second
    }
}