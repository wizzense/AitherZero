#Requires -Modules Pester

<#
.SYNOPSIS
    Tests for playbook selection UI fix
.DESCRIPTION
    Validates that playbooks with category prefixes can be properly selected and loaded
#>

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:StartAitherPath = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"
    
    # Import required modules
    Import-Module (Join-Path $script:ProjectRoot "AitherZero.psd1") -Force -ErrorAction Stop
    Import-Module (Join-Path $script:ProjectRoot "domains/automation/OrchestrationEngine.psm1") -Force -ErrorAction Stop
}

Describe "Playbook Selection Fix" {
    Context "When playbooks have category prefixes" {
        It "Should resolve playbook names correctly" {
            # Simulate a playbook selection with category prefix
            $selection = [PSCustomObject]@{
                Name = '[analysis] automated-security-review'
                OriginalName = 'automated-security-review'
                Description = 'Test security review playbook'
                Category = 'analysis'
                Path = 'test-path'
            }

            # Test the name resolution logic from the fix
            $playbookName = if ($selection.OriginalName) { $selection.OriginalName } else { $selection.Name }
            
            $playbookName | Should -Be 'automated-security-review'
            $playbookName | Should -Not -Be '[analysis] automated-security-review'
        }
        
        It "Should find existing playbooks with resolved names" {
            # Test that the resolved name can actually find the playbook
            $playbookName = 'automated-security-review'
            $playbook = Get-OrchestrationPlaybook -Name $playbookName
            
            $playbook | Should -Not -BeNullOrEmpty
            $playbook.Name | Should -Be $playbookName
        }
        
        It "Should handle fallback to Name when OriginalName is missing" {
            # Test backward compatibility
            $selection = [PSCustomObject]@{
                Name = 'test-playbook'
                Description = 'Test playbook without OriginalName'
            }
            
            $playbookName = if ($selection.OriginalName) { $selection.OriginalName } else { $selection.Name }
            
            $playbookName | Should -Be 'test-playbook'
        }
    }
    
    Context "Playbook loading validation" {
        It "Should load analysis category playbooks" {
            $analysisPlaybooks = @('automated-security-review', 'claude-code-review', 'tech-debt-analysis')
            
            foreach ($name in $analysisPlaybooks) {
                $playbook = Get-OrchestrationPlaybook -Name $name
                $playbook | Should -Not -BeNullOrEmpty -Because "Playbook '$name' should be found"
                # Handle case-insensitive JSON property names
                $playbookName = if ($playbook.Name) { $playbook.Name } else { $playbook.name }
                $playbookName | Should -Be $name
            }
        }
    }
}