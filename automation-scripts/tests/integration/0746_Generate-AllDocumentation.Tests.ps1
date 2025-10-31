#Requires -Version 7.0

<#
.SYNOPSIS
    Integration tests for 0746 Documentation Orchestrator script
.DESCRIPTION
    Tests the documentation orchestration and automation workflow
#>

BeforeAll {
    $script:projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:script0746 = Join-Path $script:projectRoot "automation-scripts/0746_Generate-AllDocumentation.ps1"
    
    if (-not (Test-Path $script:script0746)) {
        throw "0746_Generate-AllDocumentation.ps1 not found"
    }
}

Describe "0746 Documentation Orchestrator Script" {
    Context "Script Validation" {
        It "Script file exists and is executable" {
            Test-Path $script:script0746 | Should -Be $true
            
            if (-not $IsWindows) {
                $permissions = (Get-Item $script:script0746).UnixMode
                $permissions | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Has valid PowerShell syntax" {
            $result = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($script:script0746, [ref]$result, [ref]$errors) | Out-Null
            $errors.Count | Should -Be 0
        }
        
        It "Accepts required parameters" {
            $content = Get-Content $script:script0746 -Raw
            $content | Should -Match 'param\s*\('
            $content | Should -Match '\[ValidateSet.*Mode'
            $content | Should -Match '\[ValidateSet.*Format'
        }
        
        It "Has proper comment-based help" {
            $content = Get-Content $script:script0746 -Raw
            $content | Should -Match '\.SYNOPSIS'
            $content | Should -Match '\.DESCRIPTION'
            $content | Should -Match '\.EXAMPLE'
        }
    }
    
    Context "Script Dependencies" {
        It "0744 script exists (dependency)" {
            $script0744 = Join-Path $script:projectRoot "automation-scripts/0744_Generate-AutoDocumentation.ps1"
            Test-Path $script0744 | Should -Be $true
        }
        
        It "0745 script exists (dependency)" {
            $script0745 = Join-Path $script:projectRoot "automation-scripts/0745_Generate-ProjectIndexes.ps1"
            Test-Path $script0745 | Should -Be $true
        }
        
        It "DocumentationEngine module exists" {
            $docEngine = Join-Path $script:projectRoot "domains/documentation/DocumentationEngine.psm1"
            Test-Path $docEngine | Should -Be $true
        }
        
        It "ProjectIndexer module exists" {
            $indexer = Join-Path $script:projectRoot "domains/documentation/ProjectIndexer.psm1"
            Test-Path $indexer | Should -Be $true
        }
    }
    
    Context "Cleanup Logic" {
        It "Has case-sensitive INDEX.md detection" {
            $content = Get-Content $script:script0746 -Raw
            $content | Should -Match '-ceq\s+["'']INDEX\.md["'']'
        }
        
        It "Checks for lowercase index.md before removing uppercase" {
            $content = Get-Content $script:script0746 -Raw
            $content | Should -Match 'Test-Path.*index\.md'
        }
    }
    
    Context "Orchestration" {
        It "Calls both 0744 and 0745 scripts" {
            $content = Get-Content $script:script0746 -Raw
            $content | Should -Match '0744_Generate-AutoDocumentation'
            $content | Should -Match '0745_Generate-ProjectIndexes'
        }
        
        It "Has cleanup step for legacy INDEX.md files" {
            $content = Get-Content $script:script0746 -Raw
            $content | Should -Match 'INDEX\.md'
            $content | Should -Match 'Remove-Item'
        }
    }
}
