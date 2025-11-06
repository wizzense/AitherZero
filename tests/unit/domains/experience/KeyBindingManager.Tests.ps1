#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for KeyBindingManager module
#>

BeforeAll {
    $projectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    $script:ModulePath = Join-Path $projectRoot "domains/experience/KeyBindingManager.psm1"
    
    if (-not (Test-Path $script:ModulePath)) {
        throw "Module not found at: $script:ModulePath"
    }
    
    Import-Module $script:ModulePath -Force
}

Describe "KeyBindingManager" -Tag 'Unit', 'Experience', 'ModalUI' {
    
    Context "Initialization" {
        It "Should initialize with default bindings" {
            { Initialize-KeyBindingManager } | Should -Not -Throw
        }
        
        It "Should have Normal mode bindings" {
            $bindings = Get-AllKeyBindings -Mode 'Normal'
            $bindings.Count | Should -BeGreaterThan 0
        }
        
        It "Should have Command mode bindings" {
            $bindings = Get-AllKeyBindings -Mode 'Command'
            $bindings.Count | Should -BeGreaterThan 0
        }
        
        It "Should have Search mode bindings" {
            $bindings = Get-AllKeyBindings -Mode 'Search'
            $bindings.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Key Binding Lookup" {
        BeforeEach {
            Initialize-KeyBindingManager
        }
        
        It "Should get binding for valid key in Normal mode" {
            $binding = Get-KeyBinding -Mode 'Normal' -Key 'g'
            
            $binding | Should -Not -BeNullOrEmpty
            $binding.Action | Should -Be 'Go-ToTop'
        }
        
        It "Should get binding for Enter in Command mode" {
            $binding = Get-KeyBinding -Mode 'Command' -Key 'Enter'
            
            $binding | Should -Not -BeNullOrEmpty
            $binding.Action | Should -Be 'Execute-Command'
        }
        
        It "Should return null for unbound key" {
            $binding = Get-KeyBinding -Mode 'Normal' -Key 'UnboundKey'
            
            $binding | Should -BeNullOrEmpty
        }
        
        It "Should have VIM navigation bindings" {
            $bindings = @('h', 'j', 'k', 'l')
            foreach ($key in $bindings) {
                $binding = Get-KeyBinding -Mode 'Normal' -Key $key
                $binding | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should have number selection bindings" {
            1..9 | ForEach-Object {
                $binding = Get-KeyBinding -Mode 'Normal' -Key "$_"
                $binding | Should -Not -BeNullOrEmpty
                $binding.Action | Should -Be 'Select-Number'
                $binding.Number | Should -Be $_
            }
        }
    }
    
    Context "Custom Binding Registration" {
        BeforeEach {
            Initialize-KeyBindingManager
        }
        
        It "Should register new binding" {
            Register-KeyBinding -Mode 'Normal' -Key 'x' -Action 'Custom-Action' -Description 'Test action'
            
            $binding = Get-KeyBinding -Mode 'Normal' -Key 'x'
            $binding | Should -Not -BeNullOrEmpty
            $binding.Action | Should -Be 'Custom-Action'
            $binding.Description | Should -Be 'Test action'
        }
        
        It "Should override existing binding" {
            Register-KeyBinding -Mode 'Normal' -Key 'g' -Action 'New-Action' -Description 'New description'
            
            $binding = Get-KeyBinding -Mode 'Normal' -Key 'g'
            $binding.Action | Should -Be 'New-Action'
        }
        
        It "Should support metadata" {
            Register-KeyBinding -Mode 'Normal' -Key 'z' -Action 'Test' -Description 'Test' -Metadata @{ Custom = 'Value' }
            
            $binding = Get-KeyBinding -Mode 'Normal' -Key 'z'
            $binding.Custom | Should -Be 'Value'
        }
    }
    
    Context "Binding Removal" {
        BeforeEach {
            Initialize-KeyBindingManager
        }
        
        It "Should unregister binding" {
            Unregister-KeyBinding -Mode 'Normal' -Key 'g'
            
            $binding = Get-KeyBinding -Mode 'Normal' -Key 'g'
            $binding | Should -BeNullOrEmpty
        }
        
        It "Should not throw for unbound key" {
            { Unregister-KeyBinding -Mode 'Normal' -Key 'UnboundKey' } | Should -Not -Throw
        }
    }
    
    Context "Key Name Conversion" {
        It "Should convert Enter key" {
            $keyInfo = New-Object System.Management.Automation.Host.KeyInfo
            $keyInfo.VirtualKeyCode = 13
            
            $name = ConvertTo-KeyName -KeyInfo $keyInfo
            $name | Should -Be 'Enter'
        }
        
        It "Should convert Escape key" {
            $keyInfo = New-Object System.Management.Automation.Host.KeyInfo
            $keyInfo.VirtualKeyCode = 27
            
            $name = ConvertTo-KeyName -KeyInfo $keyInfo
            $name | Should -Be 'Escape'
        }
        
        It "Should convert arrow keys" {
            $arrowKeys = @{
                38 = 'UpArrow'
                40 = 'DownArrow'
                37 = 'LeftArrow'
                39 = 'RightArrow'
            }
            
            foreach ($code in $arrowKeys.Keys) {
                $keyInfo = New-Object System.Management.Automation.Host.KeyInfo
                $keyInfo.VirtualKeyCode = $code
                
                $name = ConvertTo-KeyName -KeyInfo $keyInfo
                $name | Should -Be $arrowKeys[$code]
            }
        }
        
        It "Should handle printable characters" {
            $keyInfo = New-Object System.Management.Automation.Host.KeyInfo
            $keyInfo.Character = 'a'
            $keyInfo.VirtualKeyCode = 65
            
            $name = ConvertTo-KeyName -KeyInfo $keyInfo
            $name | Should -Be 'a'
        }
    }
    
    Context "Help Text Generation" {
        BeforeEach {
            Initialize-KeyBindingManager
        }
        
        It "Should generate help for Normal mode" {
            $help = Get-KeyBindingHelp -Mode 'Normal'
            
            $help | Should -Not -BeNullOrEmpty
            $help | Should -Match 'Normal Mode'
        }
        
        It "Should include key descriptions" {
            $help = Get-KeyBindingHelp -Mode 'Normal'
            
            $help | Should -Match 'Navigate'
            $help | Should -Match 'Select'
        }
        
        It "Should categorize bindings" {
            $help = Get-KeyBindingHelp -Mode 'Normal'
            
            $help | Should -Match 'Navigation'
            $help | Should -Match 'Actions'
        }
    }
    
    Context "Reset" {
        It "Should reset to default bindings" {
            Initialize-KeyBindingManager
            Register-KeyBinding -Mode 'Normal' -Key 'x' -Action 'Custom' -Description 'Custom'
            
            Reset-KeyBindings
            
            $binding = Get-KeyBinding -Mode 'Normal' -Key 'x'
            $binding | Should -BeNullOrEmpty
        }
        
        It "Should preserve default bindings after reset" {
            Reset-KeyBindings
            
            $binding = Get-KeyBinding -Mode 'Normal' -Key 'g'
            $binding | Should -Not -BeNullOrEmpty
            $binding.Action | Should -Be 'Go-ToTop'
        }
    }
    
    Context "Custom Bindings on Init" {
        It "Should merge custom bindings with defaults" {
            $custom = @{
                Normal = @{
                    'x' = @{ Action = 'Custom-Action'; Description = 'Custom' }
                }
            }
            
            Initialize-KeyBindingManager -CustomBindings $custom
            
            $binding = Get-KeyBinding -Mode 'Normal' -Key 'x'
            $binding.Action | Should -Be 'Custom-Action'
            
            # Default binding should still exist
            $defaultBinding = Get-KeyBinding -Mode 'Normal' -Key 'g'
            $defaultBinding | Should -Not -BeNullOrEmpty
        }
    }
}
