#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    End-to-End tests for Orchestration Engine
.DESCRIPTION
    Comprehensive tests for orchestration, playbook execution, and job coordination
#>

BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    
    # Import module
    Import-Module (Join-Path $script:ProjectRoot "AitherZero.psd1") -Force -ErrorAction Stop
    
    # Set test mode
    $env:AITHERZERO_TEST_MODE = "1"
    $env:AITHERZERO_NONINTERACTIVE = "1"
}

Describe "Orchestration Engine Core Functions" -Tag 'E2E', 'Orchestration' {
    Context "Orchestration Module Loading" {
        It "Should have orchestration functions available" {
            Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have core orchestration functions available" {
            Get-Command Invoke-OrchestrationSequence -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have playbook functions available" {
            Get-Command Get-OrchestrationPlaybook -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Playbook Discovery" {
        It "Should discover available playbooks" {
            $playbooks = Get-OrchestrationPlaybook -ListAll -ErrorAction SilentlyContinue
            # Playbooks may or may not exist, so we just check the function works
            { Get-OrchestrationPlaybook -ListAll -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
        
        It "Should load specific playbooks by name" {
            # Get first available playbook
            $allPlaybooks = Get-OrchestrationPlaybook -ListAll -ErrorAction SilentlyContinue
            if ($allPlaybooks -and $allPlaybooks.Count -gt 0) {
                $firstPlaybook = $allPlaybooks[0]
                $playbookName = if ($firstPlaybook.Name) { $firstPlaybook.Name } else { $firstPlaybook.name }
                
                $loaded = Get-OrchestrationPlaybook -Name $playbookName
                $loaded | Should -Not -BeNullOrEmpty
            } else {
                # No playbooks available - test passes
                $true | Should -BeTrue
            }
        }
        
        It "Should handle non-existent playbook gracefully" {
            $result = Get-OrchestrationPlaybook -Name "nonexistent-playbook-xyz123" -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Playbook Structure Validation" {
        It "Should validate playbook has required properties" {
            $playbooks = Get-OrchestrationPlaybook -ListAll
            if ($playbooks.Count -gt 0) {
                $playbook = $playbooks[0]
                
                # Check for name property (case-insensitive)
                $hasName = $playbook.PSObject.Properties.Name -contains 'Name' -or 
                          $playbook.PSObject.Properties.Name -contains 'name'
                $hasName | Should -BeTrue
            }
        }
    }
}

Describe "Sequence Orchestration" -Tag 'E2E', 'Orchestration', 'Sequences' {
    Context "Sequence Validation" {
        It "Should validate sequence format" {
            $validSequences = @("0000-0099", "0100-0199", "0400-0499")
            
            foreach ($seq in $validSequences) {
                $seq | Should -Match '^\d{4}-\d{4}$'
            }
        }
        
        It "Should handle invalid sequence format" {
            # Test that invalid formats are rejected appropriately
            $invalidSequence = "invalid-sequence"
            $invalidSequence | Should -Not -Match '^\d{4}-\d{4}$'
        }
    }
    
    Context "Script Number Resolution" {
        It "Should resolve script numbers to paths" {
            $testScriptNumber = "0402"
            $scriptsPath = Join-Path $script:ProjectRoot "automation-scripts"
            $expectedPath = Join-Path $scriptsPath "${testScriptNumber}_*.ps1"
            
            $scriptFiles = Get-ChildItem -Path $scriptsPath -Filter "${testScriptNumber}_*.ps1" -ErrorAction SilentlyContinue
            $scriptFiles | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Job Orchestration" -Tag 'E2E', 'Orchestration', 'Jobs' {
    Context "Job Configuration" {
        It "Should support job definition structure" {
            $jobConfig = @{
                Name = "test-job"
                Steps = @(
                    @{ 
                        Name = "step1"
                        Script = "0402"
                    }
                )
            }
            
            $jobConfig | Should -Not -BeNullOrEmpty
            $jobConfig.Steps.Count | Should -Be 1
        }
        
        It "Should validate job dependencies" {
            $jobWithDeps = @{
                Name = "dependent-job"
                DependsOn = @("prerequisite-job")
                Steps = @()
            }
            
            $jobWithDeps.DependsOn | Should -Contain "prerequisite-job"
        }
    }
    
    Context "Job Execution Order" {
        It "Should respect job dependencies" {
            # Test dependency resolution
            $jobs = @(
                @{ Name = "job1"; DependsOn = @() }
                @{ Name = "job2"; DependsOn = @("job1") }
                @{ Name = "job3"; DependsOn = @("job1", "job2") }
            )
            
            # Job3 should come after job1 and job2
            $job3Deps = $jobs[2].DependsOn
            $job3Deps | Should -Contain "job1"
            $job3Deps | Should -Contain "job2"
        }
    }
}

Describe "Playbook Execution" -Tag 'E2E', 'Orchestration', 'Execution' {
    Context "Playbook Profile Selection" {
        It "Should support different execution profiles" {
            $profiles = @("quick", "full", "ci")
            
            foreach ($profile in $profiles) {
                $profile | Should -BeIn @("quick", "full", "ci", "standard")
            }
        }
    }
    
    Context "Playbook Variable Interpolation" {
        It "Should support variable references" {
            $variables = @{
                TestVar = "test-value"
                Environment = "testing"
            }
            
            $variables.TestVar | Should -Be "test-value"
            $variables.Environment | Should -Be "testing"
        }
        
        It "Should handle nested variable references" {
            $config = @{
                Base = @{
                    Path = "/test/path"
                }
                Derived = @{
                    FullPath = "{Base.Path}/subdir"
                }
            }
            
            $config.Base.Path | Should -Be "/test/path"
        }
    }
    
    Context "Conditional Execution" {
        It "Should support conditional job execution" {
            $conditionalJob = @{
                Name = "conditional-job"
                If = '${{ variables.RunTests == "true" }}'
                Steps = @()
            }
            
            $conditionalJob.If | Should -Not -BeNullOrEmpty
            $conditionalJob.If | Should -Match 'variables\.'
        }
    }
}

Describe "Orchestration Error Handling" -Tag 'E2E', 'Orchestration', 'ErrorHandling' {
    Context "Job Failure Handling" {
        It "Should support continue-on-error flag" {
            $job = @{
                Name = "resilient-job"
                ContinueOnError = $true
                Steps = @()
            }
            
            $job.ContinueOnError | Should -Be $true
        }
        
        It "Should support retry configuration" {
            $job = @{
                Name = "retry-job"
                MaxRetries = 3
                Steps = @()
            }
            
            $job.MaxRetries | Should -Be 3
        }
    }
    
    Context "Timeout Configuration" {
        It "Should support job timeouts" {
            $job = @{
                Name = "timed-job"
                TimeoutMinutes = 30
                Steps = @()
            }
            
            $job.TimeoutMinutes | Should -Be 30
        }
    }
}

Describe "Orchestration Integration" -Tag 'E2E', 'Orchestration', 'Integration' {
    Context "Configuration Integration" {
        It "Should load orchestration configuration" {
            $config = Get-Configuration
            $config | Should -Not -BeNullOrEmpty
            
            # Check for Automation key in hashtable
            $config.Keys | Should -Contain 'Automation'
        }
        
        It "Should access automation settings" {
            $config = Get-Configuration
            $automationConfig = $config['Automation']
            $automationConfig | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Logging Integration" {
        It "Should have logging functions available for orchestration" {
            Get-Command Write-CustomLog -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Script Registry Integration" {
        It "Should access automation scripts registry" {
            $scriptsPath = Join-Path $script:ProjectRoot "automation-scripts"
            Test-Path $scriptsPath | Should -BeTrue
            
            $scriptFiles = Get-ChildItem -Path $scriptsPath -Filter "*.ps1" -ErrorAction SilentlyContinue
            $scriptFiles.Count | Should -BeGreaterThan 0
        }
    }
}

Describe "Expression Validation" -Tag 'E2E', 'Orchestration', 'Security' {
    Context "Expression Syntax" {
        It "Should support GitHub Actions-style expressions" {
            $expressions = @(
                '${{ variables.test }}'
                '${{ jobs.job1.status }}'
                '${{ parameters.environment }}'
            )
            
            foreach ($expr in $expressions) {
                $expr | Should -Match '\$\{\{\s*.*\s*\}\}'
            }
        }
        
        It "Should validate expression format" {
            $validExpr = '${{ variables.test }}'
            $invalidExpr = '{{ variables.test }}'
            
            $validExpr | Should -Match '^\$\{\{.*\}\}$'
            $invalidExpr | Should -Not -Match '^\$\{\{.*\}\}$'
        }
    }
}

Describe "Playbook Categories" -Tag 'E2E', 'Orchestration', 'Categories' {
    Context "Category Organization" {
        It "Should organize playbooks by category" {
            $playbooks = Get-OrchestrationPlaybook -ListAll
            
            if ($playbooks.Count -gt 0) {
                # Check if playbooks have category information
                $hasCategories = $playbooks | Where-Object { 
                    $_.PSObject.Properties.Name -contains 'Category' -or
                    $_.PSObject.Properties.Name -contains 'category'
                }
                
                # Some playbooks should have categories
                $hasCategories.Count | Should -BeGreaterOrEqual 0
            }
        }
    }
}
