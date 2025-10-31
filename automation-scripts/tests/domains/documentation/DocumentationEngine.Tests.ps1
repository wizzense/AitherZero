#Requires -Version 7.0

<#
.SYNOPSIS
    Tests for DocumentationEngine module
.DESCRIPTION
    Validates the DocumentationEngine module functionality
#>

BeforeAll {
    $script:projectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $script:modulePath = Join-Path $script:projectRoot "domains/documentation/DocumentationEngine.psm1"
    
    if (-not (Test-Path $script:modulePath)) {
        throw "DocumentationEngine.psm1 not found"
    }
    
    # Import the module
    Import-Module $script:modulePath -Force -ErrorAction Stop
}

Describe "DocumentationEngine Module" {
    Context "Module Loading" {
        It "Module file exists" {
            Test-Path $script:modulePath | Should -Be $true
        }
        
        It "Has valid PowerShell syntax" {
            $result = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($script:modulePath, [ref]$result, [ref]$errors) | Out-Null
            $errors.Count | Should -Be 0
        }
        
        It "Module loads without errors" {
            { Import-Module $script:modulePath -Force } | Should -Not -Throw
        }
        
        It "Exports expected functions" {
            $module = Get-Module -Name DocumentationEngine
            $module | Should -Not -BeNull
            $module.ExportedFunctions.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Core Functions" {
        It "Initialize-DocumentationEngine function exists" {
            Get-Command Initialize-DocumentationEngine -ErrorAction SilentlyContinue | Should -Not -BeNull
        }
        
        It "New-ModuleDocumentation function exists" {
            Get-Command New-ModuleDocumentation -ErrorAction SilentlyContinue | Should -Not -BeNull
        }
        
        It "New-ProjectDocumentation function exists" {
            Get-Command New-ProjectDocumentation -ErrorAction SilentlyContinue | Should -Not -BeNull
        }
        
        It "New-DocumentationIndex function exists" {
            Get-Command New-DocumentationIndex -ErrorAction SilentlyContinue | Should -Not -BeNull
        }
    }
    
    Context "Index File Naming" {
        It "Uses lowercase index.md naming" {
            $content = Get-Content $script:modulePath -Raw
            $indexReferences = [regex]::Matches($content, 'Join-Path.*index\.md')
            $indexReferences.Count | Should -BeGreaterThan 0
        }
        
        It "Does not use uppercase INDEX.md" {
            $content = Get-Content $script:modulePath -Raw
            $uppercaseRefs = [regex]::Matches($content, 'Join-Path.*INDEX\.md')
            $uppercaseRefs.Count | Should -Be 0
        }
    }
    
    Context "Error Handling" {
        It "Has try-catch blocks for error handling" {
            $content = Get-Content $script:modulePath -Raw
            $content | Should -Match '\btry\s*\{'
            $content | Should -Match '\bcatch\s*\{'
        }
        
        It "Uses Write-DocLog for logging" {
            $content = Get-Content $script:modulePath -Raw
            $content | Should -Match 'Write-DocLog'
        }
        
        It "Has proper error logging in catch blocks" {
            $content = Get-Content $script:modulePath -Raw
            $content | Should -Match 'catch\s*\{[^}]*Write-DocLog'
        }
    }
    
    Context "Module Configuration" {
        It "Has module state management" {
            $content = Get-Content $script:modulePath -Raw
            $content | Should -Match '\$script:DocumentationState'
        }
        
        It "Has configuration management" {
            $content = Get-Content $script:modulePath -Raw
            $content | Should -Match 'Get-DefaultDocumentationConfig'
        }
    }
}
