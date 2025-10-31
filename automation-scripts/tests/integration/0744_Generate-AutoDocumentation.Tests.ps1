#Requires -Version 7.0

<#
.SYNOPSIS
    Integration tests for 0744 Auto Documentation script
.DESCRIPTION
    Tests the automated reactive documentation generation system
#>

BeforeAll {
    $script:projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:script0744 = Join-Path $script:projectRoot "automation-scripts/0744_Generate-AutoDocumentation.ps1"
    
    if (-not (Test-Path $script:script0744)) {
        throw "0744_Generate-AutoDocumentation.ps1 not found"
    }
}

Describe "0744 Auto Documentation Script" {
    Context "Script Validation" {
        It "Script file exists" {
            Test-Path $script:script0744 | Should -Be $true
        }
        
        It "Has valid PowerShell syntax" {
            $result = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($script:script0744, [ref]$result, [ref]$errors) | Out-Null
            $errors.Count | Should -Be 0
        }
        
        It "Accepts required parameters" {
            $content = Get-Content $script:script0744 -Raw
            $content | Should -Match 'param\s*\('
            $content | Should -Match '\[ValidateSet.*Mode'
        }
        
        It "Has proper comment-based help" {
            $content = Get-Content $script:script0744 -Raw
            $content | Should -Match '\.SYNOPSIS'
            $content | Should -Match '\.DESCRIPTION'
        }
    }
    
    Context "Script Dependencies" {
        It "DocumentationEngine module exists" {
            $docEngine = Join-Path $script:projectRoot "domains/documentation/DocumentationEngine.psm1"
            Test-Path $docEngine | Should -Be $true
        }
    }
    
    Context "Configuration" {
        It "Uses lowercase index.md naming" {
            $content = Get-Content $script:script0744 -Raw
            # Should use lowercase index.md
            $content | Should -Match 'index\.md'
            # Should not have uppercase INDEX.md
            $uppercaseRefs = [regex]::Matches($content, 'INDEX\.md')
            $uppercaseRefs.Count | Should -Be 0
        }
    }
}
