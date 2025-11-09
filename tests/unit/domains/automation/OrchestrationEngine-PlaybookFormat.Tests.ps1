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

Describe "OrchestrationEngine - Playbook Format Validation" -Tag 'Unit', 'Critical' {

    Context "Sequence Format Normalization" {
        
        It "Should normalize lowercase property names to PascalCase" {
            $playbook = @{
                name = 'test-lowercase'
                description = 'Test description'
                version = '1.0.0'
                sequence = @(
                    @{ Script = '0001'; Description = 'Test script' }
                )
                variables = @{ TestVar = 'value' }
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            
            $result.Name | Should -Be 'test-lowercase'
            $result.Description | Should -Be 'Test description'
            $result.Version | Should -Be '1.0.0'
            $result.Sequence | Should -Not -BeNullOrEmpty
            $result.Variables.TestVar | Should -Be 'value'
        }

        It "Should preserve PascalCase property names" {
            $playbook = @{
                Name = 'test-pascalcase'
                Description = 'Test description'
                Version = '1.0.0'
                Sequence = @(
                    @{ Script = '0001' }
                )
                Variables = @{ TestVar = 'value' }
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            
            $result.Name | Should -Be 'test-pascalcase'
            $result.Description | Should -Be 'Test description'
            $result.Version | Should -Be '1.0.0'
            $result.Sequence | Should -Not -BeNullOrEmpty
            $result.Variables.TestVar | Should -Be 'value'
        }

        It "Should handle mixed-case properties consistently" {
            $playbook = @{
                Name = 'test-mixed'
                description = 'lowercase desc'  # lowercase
                Sequence = @( @{ Script = '0001' } )  # PascalCase
                variables = @{ Key = 'Value' }  # lowercase
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            
            $result.Name | Should -Be 'test-mixed'
            $result.Description | Should -Be 'lowercase desc'
            $result.Sequence.Count | Should -Be 1
            $result.Variables.Key | Should -Be 'Value'
        }
    }

    Context "Sequence Structure Validation" {
        
        It "Should accept Sequence with single script" {
            $playbook = @{
                Name = 'single-script'
                Sequence = @(
                    @{ 
                        Script = '0407'
                        Description = 'Validate syntax'
                        Parameters = @{ All = $true }
                        ContinueOnError = $false
                        Timeout = 120
                    }
                )
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            
            $result.Sequence | Should -Not -BeNullOrEmpty
            # PowerShell might unwrap single-item array, so handle both cases
            if ($result.Sequence -is [Array]) {
                $result.Sequence[0].Script | Should -Be '0407'
                $result.Sequence[0].Description | Should -Be 'Validate syntax'
            } else {
                $result.Sequence.Script | Should -Be '0407'
                $result.Sequence.Description | Should -Be 'Validate syntax'
            }
        }

        It "Should accept Sequence with multiple scripts" {
            $playbook = @{
                Name = 'multi-script'
                Sequence = @(
                    @{ Script = '0407'; Description = 'Syntax check' }
                    @{ Script = '0404'; Description = 'PSScriptAnalyzer' }
                    @{ Script = '0402'; Description = 'Unit tests' }
                )
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            
            $result.Sequence.Count | Should -Be 3
            $result.Sequence[0].Script | Should -Be '0407'
            $result.Sequence[1].Script | Should -Be '0404'
            $result.Sequence[2].Script | Should -Be '0402'
        }

        It "Should preserve complex sequence item properties" {
            $playbook = @{
                Name = 'complex-sequence'
                Sequence = @(
                    @{
                        Script = '0515'
                        Description = 'Generate build metadata'
                        Parameters = @{
                            OutputPath = 'library/reports/build-metadata.json'
                            IncludePRInfo = $true
                            IncludeGitInfo = $true
                        }
                        ContinueOnError = $false
                        Timeout = 60
                        Phase = 'metadata'
                    }
                )
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            
            # Access the sequence item correctly
            $item = if ($result.Sequence -is [Array]) { $result.Sequence[0] } else { $result.Sequence }
            $item.Script | Should -Be '0515'
            $item.Parameters.OutputPath | Should -Be 'library/reports/build-metadata.json'
            $item.Parameters.IncludePRInfo | Should -Be $true
            $item.Timeout | Should -Be 60
            $item.Phase | Should -Be 'metadata'
        }

        It "Should handle empty Sequence array" {
            $playbook = @{
                Name = 'empty-sequence'
                Sequence = @()
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            $result.ContainsKey('Sequence') | Should -Be $true
        }
    }

    Context "Playbook Property Preservation" {
        
        It "Should preserve standard playbook properties" {
            $playbook = @{
                Name = 'test-props'
                Description = 'Test playbook'
                Version = '2.0.0'
                Author = 'AitherZero'
                Tags = @('test', 'validation')
                Sequence = @( @{ Script = '0001' } )
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            
            $result.Name | Should -Be 'test-props'
            $result.Description | Should -Be 'Test playbook'
            $result.Version | Should -Be '2.0.0'
            $result.Author | Should -Be 'AitherZero'
            $result.Tags | Should -Contain 'test'
            $result.Tags | Should -Contain 'validation'
        }

        It "Should preserve Variables property" {
            $playbook = @{
                Name = 'test-vars'
                Sequence = @( @{ Script = '0001' } )
                Variables = @{
                    CI = 'true'
                    AITHERZERO_CI = 'true'
                    BUILD_PHASE = 'pr-ecosystem-build'
                }
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            
            $result.Variables.CI | Should -Be 'true'
            $result.Variables.AITHERZERO_CI | Should -Be 'true'
            $result.Variables.BUILD_PHASE | Should -Be 'pr-ecosystem-build'
        }

        It "Should preserve Options property" {
            $playbook = @{
                Name = 'test-options'
                Sequence = @( @{ Script = '0001' } )
                Options = @{
                    Parallel = $true
                    MaxConcurrency = 4
                    StopOnError = $false
                    CaptureOutput = $true
                }
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            
            $result.Options.Parallel | Should -Be $true
            $result.Options.MaxConcurrency | Should -Be 4
            $result.Options.StopOnError | Should -Be $false
            $result.Options.CaptureOutput | Should -Be $true
        }

        It "Should preserve SuccessCriteria property" {
            $playbook = @{
                Name = 'test-success'
                Sequence = @( @{ Script = '0001' } )
                SuccessCriteria = @{
                    RequireAllSuccess = $false
                    MinimumSuccessCount = 3
                    AllowedFailures = @('0900_Test-SelfDeployment.ps1')
                }
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            
            $result.SuccessCriteria.RequireAllSuccess | Should -Be $false
            $result.SuccessCriteria.MinimumSuccessCount | Should -Be 3
            $result.SuccessCriteria.AllowedFailures | Should -Contain '0900_Test-SelfDeployment.ps1'
        }

        It "Should preserve Artifacts property" {
            $playbook = @{
                Name = 'test-artifacts'
                Sequence = @( @{ Script = '0001' } )
                Artifacts = @{
                    Required = @(
                        'library/reports/build-metadata.json'
                        'AitherZero-*-runtime.zip'
                    )
                    Optional = @(
                        'library/reports/build-summary.json'
                    )
                }
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            
            $result.Artifacts.Required.Count | Should -Be 2
            $result.Artifacts.Optional.Count | Should -Be 1
        }

        It "Should preserve custom properties not in normalized list" {
            $playbook = @{
                Name = 'test-custom'
                Sequence = @( @{ Script = '0001' } )
                CustomProperty = 'custom-value'
                Reporting = @{ GenerateReport = $true }
                Notifications = @{ Enabled = $false }
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            
            $result.CustomProperty | Should -Be 'custom-value'
            $result.Reporting.GenerateReport | Should -Be $true
            $result.Notifications.Enabled | Should -Be $false
        }
    }

    Context "Error Handling" {
        
        It "Should reject playbook missing Sequence property" {
            $playbook = @{
                Name = 'no-sequence'
                Description = 'Missing sequence'
            }
            
            { ConvertTo-StandardPlaybookFormat -Playbook $playbook } | 
                Should -Throw -ExpectedMessage '*missing required*Sequence*'
        }

        It "Should provide helpful error for invalid playbook" {
            $playbook = @{
                Name = 'invalid'
            }
            
            try {
                ConvertTo-StandardPlaybookFormat -Playbook $playbook
                throw "Should have thrown error"
            } catch {
                $_.Exception.Message | Should -Match 'Sequence'
                $_.Exception.Message | Should -Match 'Script = '
            }
        }
    }

    Context "Real-World Playbook Examples" {
        
        It "Should handle pr-ecosystem-build playbook structure" {
            $playbook = @{
                Name = "pr-ecosystem-build"
                Description = "Complete PR Build Phase"
                Version = "2.0.0"
                Author = "AitherZero"
                Tags = @("pr", "build", "ecosystem")
                Sequence = @(
                    @{
                        Script = "0407"
                        Description = "Syntax validation"
                        Parameters = @{ All = $true }
                        ContinueOnError = $false
                        Timeout = 120
                    }
                    @{
                        Script = "0515"
                        Description = "Generate build metadata"
                        Parameters = @{ OutputPath = "library/reports/build-metadata.json" }
                        Timeout = 60
                    }
                )
                Variables = @{
                    CI = "true"
                    BUILD_PHASE = "pr-ecosystem-build"
                }
                Options = @{
                    Parallel = $true
                    MaxConcurrency = 3
                }
                SuccessCriteria = @{
                    MinimumSuccessCount = 3
                }
            }
            
            $result = ConvertTo-StandardPlaybookFormat -Playbook $playbook
            
            # Validate structure preserved
            $result.Name | Should -Be "pr-ecosystem-build"
            $result.Sequence.Count | Should -Be 2
            $result.Variables.BUILD_PHASE | Should -Be "pr-ecosystem-build"
            $result.Options.MaxConcurrency | Should -Be 3
            $result.SuccessCriteria.MinimumSuccessCount | Should -Be 3
        }
    }
}
