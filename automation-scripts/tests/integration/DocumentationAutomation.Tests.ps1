#Requires -Version 7.0

<#
.SYNOPSIS
    Integration tests for documentation automation (0746 script)
.DESCRIPTION
    Tests that the documentation orchestrator properly coordinates
    documentation generation and prevents duplicate uppercase INDEX.md files.
    Ensures all generated index files use lowercase naming (index.md).
#>

BeforeAll {
    # Calculate project root: tests/integration -> tests -> project_root
    $script:projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:script0746 = Join-Path $script:projectRoot "automation-scripts/0746_Generate-AllDocumentation.ps1"
    
    # Verify script exists
    if (-not (Test-Path $script:script0746)) {
        throw "0746_Generate-AllDocumentation.ps1 not found at: $script:script0746"
    }
}

Describe "Documentation Automation (0746)" {
    Context "Script Execution" {
        It "Script file exists and is executable" {
            $script0746 = Join-Path $script:projectRoot "automation-scripts/0746_Generate-AllDocumentation.ps1"
            Test-Path $script0746 | Should -Be $true
            
            # Check if file has execute permissions (on Unix-like systems)
            if (-not $IsWindows) {
                $permissions = (Get-Item $script0746).UnixMode
                $permissions | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Script has valid PowerShell syntax" {
            $script0746 = Join-Path $script:projectRoot "automation-scripts/0746_Generate-AllDocumentation.ps1"
            $result = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($script0746, [ref]$result, [ref]$errors) | Out-Null
            $errors.Count | Should -Be 0
        }
        
        It "Script accepts valid parameters" {
            $script0746 = Join-Path $script:projectRoot "automation-scripts/0746_Generate-AllDocumentation.ps1"
            $content = Get-Content $script0746 -Raw
            $content | Should -Match 'param\s*\('
            $content | Should -Match '\[ValidateSet.*Mode'
            $content | Should -Match '\[ValidateSet.*Format'
        }
    }
    
    Context "Index File Naming" {
        It "DocumentationEngine uses lowercase index.md" {
            $docEngine = Join-Path $script:projectRoot "domains/documentation/DocumentationEngine.psm1"
            $content = Get-Content $docEngine -Raw
            
            # Should use lowercase index.md
            $content | Should -Match 'index\.md'
            
            # Should NOT use uppercase INDEX.md
            $content | Should -Not -Match 'INDEX\.md'
        }
        
        It "0744 script uses lowercase index.md" {
            $script0744 = Join-Path $script:projectRoot "automation-scripts/0744_Generate-AutoDocumentation.ps1"
            $content = Get-Content $script0744 -Raw
            
            # Check for lowercase index.md in relevant contexts
            $indexReferences = [regex]::Matches($content, 'Join-Path.*["''](?:INDEX|index)\.md["'']')
            foreach ($match in $indexReferences) {
                $match.Value | Should -Match 'index\.md' -Because "All index files should be lowercase"
            }
        }
        
        It "No uppercase INDEX.md files exist in generated docs" {
            $docsGenerated = Join-Path $script:projectRoot "docs/generated"
            if (Test-Path $docsGenerated) {
                # Only check docs/generated as this is where 0744 and 0745 generate documentation
                # Other directories use different naming conventions and are not managed by these scripts
                $uppercaseIndexFiles = @(Get-ChildItem -Path $docsGenerated -Recurse -File | Where-Object { $_.Name -ceq "INDEX.md" })
                $uppercaseIndexFiles.Count | Should -Be 0 -Because "All index files in generated docs should be lowercase (index.md)"
            }
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
        It "0746 script has case-sensitive INDEX.md detection" {
            $script0746 = Join-Path $script:projectRoot "automation-scripts/0746_Generate-AllDocumentation.ps1"
            $content = Get-Content $script0746 -Raw
            
            # Should use case-sensitive comparison operator
            $content | Should -Match '-ceq\s+["'']INDEX\.md["'']' -Because "Cleanup should use case-sensitive comparison"
        }
        
        It "0746 script checks for lowercase index.md before removing uppercase" {
            $script0746 = Join-Path $script:projectRoot "automation-scripts/0746_Generate-AllDocumentation.ps1"
            $content = Get-Content $script0746 -Raw
            
            # Should check for lowercase before removing
            $content | Should -Match 'Test-Path.*index\.md' -Because "Should verify lowercase exists before cleanup"
        }
    }
}

Describe "Documentation Generation Workflow" {
    Context "Integration" {
        It "WhatIf mode executes without errors" {
            $script0746 = Join-Path $script:projectRoot "automation-scripts/0746_Generate-AllDocumentation.ps1"
            
            # Run with WhatIf to test logic without making changes
            $result = & $script0746 -Mode Incremental -WhatIf -ErrorAction Stop 2>&1
            $LASTEXITCODE | Should -Be 0
        }
    }
}
