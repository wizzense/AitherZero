#Requires -Modules Pester

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    $script:ModulePath = Join-Path $script:ProjectRoot "aithercore/automation/OrchestrationEngine.psm1"

    # Import the module under test
    Import-Module $script:ModulePath -Force -ErrorAction Stop
}

AfterAll {
    # Cleanup
    Remove-Module OrchestrationEngine -Force -ErrorAction SilentlyContinue
}

Describe "OrchestrationEngine - Playbook Validation" -Tag 'Unit', 'Critical' {

    Context "Valid Playbook Format" {
        
        It "Should accept playbook with Sequence" {
            $playbook = @{
                Name = 'test-valid'
                Description = 'Test playbook'
                Version = '1.0.0'
                Sequence = @(
                    @{ Script = '0001'; Description = 'Test' }
                )
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            $result.Sequence | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'test-valid'
        }

        It "Should normalize property casing" {
            $playbook = @{
                name = 'test-lowercase'
                description = 'lowercase description'
                sequence = @(
                    @{ Script = '0001' }
                )
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            $result.Name | Should -Be 'test-lowercase'
            $result.Description | Should -Be 'lowercase description'
            $result.Sequence | Should -Not -BeNullOrEmpty
        }

        It "Should preserve all other properties" {
            $playbook = @{
                Name = 'test-props'
                Sequence = @( @{ Script = '0001' } )
                CustomProperty = 'custom-value'
                Options = @{ Parallel = $true }
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            $result.CustomProperty | Should -Be 'custom-value'
            $result.Options.Parallel | Should -Be $true
        }
    }

    Context "Invalid Playbook Format" {
        
        It "Should reject playbook with legacy Stages format" {
            $playbook = @{
                Name = 'test-legacy'
                Stages = @(
                    @{ Name = 'Setup'; Scripts = @( @{ Path = '0001.ps1' } ) }
                )
            }
            
            { ConvertTo-StandardPlaybookFormat -Playbook $playbook } | 
                Should -Throw -ExpectedMessage '*unsupported legacy format*'
        }

        It "Should reject playbook missing Sequence property" {
            $playbook = @{
                Name = 'test-no-sequence'
                Description = 'Missing sequence'
            }
            
            { ConvertTo-StandardPlaybookFormat -Playbook $playbook } | 
                Should -Throw -ExpectedMessage '*missing required*Sequence*'
        }

        It "Should provide migration guidance in error message" {
            $playbook = @{
                Name = 'test-legacy'
                Stages = @( @{ Name = 'Test' } )
            }
            
            try {
                ConvertTo-StandardPlaybookFormat -Playbook $playbook
                throw "Should have thrown error"
            } catch {
                $_.Exception.Message | Should -Match 'Sequence = @\('
                $_.Exception.Message | Should -Match 'STAGES-DEPRECATION-MIGRATION'
            }
        }
    }

    Context "Edge Cases" {
        
        It "Should accept empty Sequence" {
            $playbook = @{
                Name = 'test-empty'
                Sequence = @()
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            # Empty array might become $null in hashtable copy - that's OK as long as property exists
            $result.ContainsKey('Sequence') | Should -Be $true
        }

        It "Should not include Stages property in output" {
            $playbook = @{
                Name = 'test-mixed'
                Sequence = @( @{ Script = '0001' } )
                Stages = @( @{ Name = 'Should be excluded' } )
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            $result.ContainsKey('Stages') | Should -Be $false
            $result.ContainsKey('stages') | Should -Be $false
        }
    }
}
