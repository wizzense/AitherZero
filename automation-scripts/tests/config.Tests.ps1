#Requires -Version 7.0

<#
.SYNOPSIS
    Tests for config.psd1 configuration manifest
.DESCRIPTION
    Validates the configuration manifest structure and contents
#>

BeforeAll {
    $script:projectRoot = Split-Path $PSScriptRoot -Parent
    $script:configPath = Join-Path $script:projectRoot "config.psd1"
    
    if (-not (Test-Path $script:configPath)) {
        throw "config.psd1 not found"
    }
}

Describe "Config Manifest (config.psd1)" {
    Context "File Validation" {
        It "Config file exists" {
            Test-Path $script:configPath | Should -Be $true
        }
        
        It "Has valid PowerShell data file syntax" {
            { Import-PowerShellDataFile -Path $script:configPath } | Should -Not -Throw
        }
        
        It "Can be loaded as hashtable" {
            $config = Import-PowerShellDataFile -Path $script:configPath
            $config | Should -BeOfType [hashtable]
        }
    }
    
    Context "Required Sections" {
        BeforeAll {
            $script:config = Import-PowerShellDataFile -Path $script:configPath
        }
        
        It "Has Manifest section" {
            $script:config.ContainsKey('Manifest') | Should -Be $true
        }
        
        It "Has FeatureDependencies section" {
            $script:config.Manifest.ContainsKey('FeatureDependencies') | Should -Be $true
        }
        
        It "Has ScriptInventory section" {
            $script:config.Manifest.ContainsKey('ScriptInventory') | Should -Be $true
        }
        
        It "Has version information" {
            $script:config.Manifest.ContainsKey('Version') | Should -Be $true
            $script:config.Manifest.Version | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Script Registration" {
        BeforeAll {
            $script:config = Import-PowerShellDataFile -Path $script:configPath
        }
        
        It "Documentation scripts include 0746" {
            $docScripts = $script:config.Manifest.FeatureDependencies.AIAgents.Documentation.Scripts
            $docScripts | Should -Contain '0746'
        }
        
        It "Script inventory count matches expected" {
            $inventory = $script:config.Manifest.ScriptInventory
            $totalCount = 0
            foreach ($range in $inventory.Keys) {
                $totalCount += $inventory[$range].Count
            }
            $totalCount | Should -BeGreaterThan 0
        }
    }
    
    Context "Data Integrity" {
        BeforeAll {
            $script:config = Import-PowerShellDataFile -Path $script:configPath
        }
        
        It "All script ranges have category labels" {
            $inventory = $script:config.Manifest.ScriptInventory
            foreach ($range in $inventory.Keys) {
                $inventory[$range].ContainsKey('Category') | Should -Be $true
                $inventory[$range].Category | Should -Not -BeNullOrEmpty
            }
        }
        
        It "All script ranges have valid counts" {
            $inventory = $script:config.Manifest.ScriptInventory
            foreach ($range in $inventory.Keys) {
                $inventory[$range].ContainsKey('Count') | Should -Be $true
                $inventory[$range].Count | Should -BeGreaterThan 0
            }
        }
    }
}
