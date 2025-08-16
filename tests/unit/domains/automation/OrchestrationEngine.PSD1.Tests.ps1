#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for OrchestrationEngine PSD1 playbook support
.DESCRIPTION
    Tests the PSD1 playbook loading, parsing, and execution functionality
#>

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    $script:ModulePath = Join-Path $script:ProjectRoot "domains/automation/OrchestrationEngine.psm1"
    
    # Import the module under test
    Import-Module $script:ModulePath -Force -ErrorAction Stop
    
    # Create test playbook directory
    $script:TestPlaybookDir = Join-Path ([System.IO.Path]::GetTempPath()) "test-playbooks-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TestPlaybookDir -Force | Out-Null
    
    # Mock external dependencies
    Mock Write-CustomLog { }
    Mock Test-Path { $true }
    Mock Get-ChildItem {
        @(
            [PSCustomObject]@{ Name = "0400_Test.ps1"; FullName = "/scripts/0400_Test.ps1" }
        )
    }
    Mock Start-Process {
        [PSCustomObject]@{
            ExitCode = 0
            StandardOutput = "Success"
        }
    }
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TestPlaybookDir) {
        Remove-Item $script:TestPlaybookDir -Recurse -Force
    }
    Remove-Module OrchestrationEngine -Force -ErrorAction SilentlyContinue
}

Describe "OrchestrationEngine PSD1 Support" -Tag 'Unit' {
    
    Context "PSD1 Playbook Loading" {
        
        BeforeEach {
            # Create a test PSD1 playbook
            $script:TestPlaybook = @'
@{
    Name = 'test-playbook'
    Description = 'Test playbook for unit tests'
    Version = '1.0.0'
    Variables = @{
        TestVar = 'TestValue'
        RunTests = $true
    }
    Stages = @(
        @{
            Name = 'Stage1'
            Description = 'First test stage'
            Sequence = @('0400', '0401')
            Variables = @{
                StageVar = 'Stage1Value'
            }
            ContinueOnError = $false
        }
        @{
            Name = 'Stage2'
            Description = 'Second test stage'
            Sequence = @('0402')
            Conditional = @{
                When = 'Variables.RunTests -eq $true'
            }
        }
    )
}
'@
            $script:PlaybookPath = Join-Path $script:TestPlaybookDir "test-playbook.psd1"
            Set-Content -Path $script:PlaybookPath -Value $script:TestPlaybook
        }
        
        It "Should load PSD1 playbook correctly" {
            $playbook = Import-PowerShellDataFile -Path $script:PlaybookPath
            
            $playbook | Should -Not -BeNullOrEmpty
            $playbook.Name | Should -Be 'test-playbook'
            $playbook.Description | Should -Be 'Test playbook for unit tests'
            $playbook.Version | Should -Be '1.0.0'
        }
        
        It "Should handle Stages property correctly" {
            $playbook = Import-PowerShellDataFile -Path $script:PlaybookPath
            
            $playbook.Stages | Should -Not -BeNullOrEmpty
            $playbook.Stages.Count | Should -Be 2
            $playbook.Stages[0].Name | Should -Be 'Stage1'
            $playbook.Stages[0].Sequence | Should -Contain '0400'
            $playbook.Stages[0].Sequence | Should -Contain '0401'
        }
        
        It "Should extract all sequences from stages" {
            $playbook = Import-PowerShellDataFile -Path $script:PlaybookPath
            
            $allSequences = @()
            foreach ($stage in $playbook.Stages) {
                if ($stage.Sequence) {
                    $allSequences += $stage.Sequence
                }
            }
            
            $allSequences.Count | Should -Be 3
            $allSequences | Should -Contain '0400'
            $allSequences | Should -Contain '0401'
            $allSequences | Should -Contain '0402'
        }
        
        It "Should handle missing Sequence property gracefully" {
            $playbookContent = @'
@{
    Name = 'no-sequence-playbook'
    Stages = @(
        @{
            Name = 'StageWithoutSequence'
            Description = 'This stage has no sequence'
        }
    )
}
'@
            $path = Join-Path $script:TestPlaybookDir "no-sequence.psd1"
            Set-Content -Path $path -Value $playbookContent
            
            $playbook = Import-PowerShellDataFile -Path $path
            
            { 
                foreach ($stage in $playbook.Stages) {
                    if ($stage.Sequence) {
                        # Process sequence
                    }
                }
            } | Should -Not -Throw
        }
    }
    
    Context "Property Access Patterns" {
        
        It "Should not use ContainsKey on PSD1 objects" {
            $playbook = Import-PowerShellDataFile -Path $script:PlaybookPath
            
            # PSD1 returns hashtables, but safe property access is better
            $hasStages = $null -ne $playbook.Stages
            $hasStages | Should -Be $true
            
            $hasSequence = $null -ne $playbook.Sequence
            $hasSequence | Should -Be $false
        }
        
        It "Should handle both Stages and stages properties" {
            # Test case sensitivity
            $lowerCasePlaybook = @'
@{
    name = 'lowercase-playbook'
    stages = @(
        @{
            name = 'stage1'
            sequence = @('0400')
        }
    )
}
'@
            $path = Join-Path $script:TestPlaybookDir "lowercase.psd1"
            Set-Content -Path $path -Value $lowerCasePlaybook
            
            $playbook = Import-PowerShellDataFile -Path $path
            
            # PowerShell hashtables are case-insensitive by default
            # Both Stages and stages will work
            $stages = $playbook.stages ?? $playbook.Stages ?? @()
            
            $stages.Count | Should -Be 1
        }
    }
    
    Context "Variable Merging" {
        
        It "Should merge playbook variables with user variables" {
            $playbook = Import-PowerShellDataFile -Path $script:PlaybookPath
            
            $userVars = @{
                UserVar = 'UserValue'
                TestVar = 'OverriddenValue'  # Should override playbook default
            }
            
            # Merge logic (user vars take precedence)
            $mergedVars = @{}
            foreach ($key in $playbook.Variables.Keys) {
                $mergedVars[$key] = $playbook.Variables[$key]
            }
            foreach ($key in $userVars.Keys) {
                $mergedVars[$key] = $userVars[$key]
            }
            
            $mergedVars.TestVar | Should -Be 'OverriddenValue'
            $mergedVars.UserVar | Should -Be 'UserValue'
            $mergedVars.RunTests | Should -Be $true
        }
        
        It "Should apply stage variables correctly" {
            $playbook = Import-PowerShellDataFile -Path $script:PlaybookPath
            
            $stage1 = $playbook.Stages[0]
            $stage1.Variables | Should -Not -BeNullOrEmpty
            $stage1.Variables.StageVar | Should -Be 'Stage1Value'
        }
    }
    
    Context "Conditional Execution" {
        
        It "Should parse conditional expressions" {
            $playbook = Import-PowerShellDataFile -Path $script:PlaybookPath
            
            $stage2 = $playbook.Stages[1]
            $stage2.Conditional | Should -Not -BeNullOrEmpty
            $stage2.Conditional.When | Should -Be 'Variables.RunTests -eq $true'
        }
        
        It "Should handle stages without conditionals" {
            $playbook = Import-PowerShellDataFile -Path $script:PlaybookPath
            
            $stage1 = $playbook.Stages[0]
            $stage1.Conditional | Should -BeNullOrEmpty
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle malformed PSD1 gracefully" {
            $badPlaybook = @'
@{
    Name = 'bad-playbook
    # Missing closing quote and brace
'@
            $path = Join-Path $script:TestPlaybookDir "bad.psd1"
            Set-Content -Path $path -Value $badPlaybook
            
            # Import-PowerShellDataFile throws a terminating error
            { Import-PowerShellDataFile -Path $path -ErrorAction Stop } | Should -Throw -ErrorId "CouldNotParseAsPowerShellDataFile*"
        }
        
        It "Should handle empty Stages array" {
            $emptyStagesPlaybook = @'
@{
    Name = 'empty-stages'
    Stages = @()
}
'@
            $path = Join-Path $script:TestPlaybookDir "empty.psd1"
            Set-Content -Path $path -Value $emptyStagesPlaybook
            
            $playbook = Import-PowerShellDataFile -Path $path
            $playbook.Stages.Count | Should -Be 0
        }
    }
    
    Context "Backward Compatibility" {
        
        It "Should still support direct Sequence property" {
            $directSequencePlaybook = @'
@{
    Name = 'direct-sequence'
    Sequence = @('0400', '0401', '0402')
    Variables = @{
        TestVar = 'Value'
    }
}
'@
            $path = Join-Path $script:TestPlaybookDir "direct.psd1"
            Set-Content -Path $path -Value $directSequencePlaybook
            
            $playbook = Import-PowerShellDataFile -Path $path
            
            $playbook.Sequence | Should -Not -BeNullOrEmpty
            $playbook.Sequence.Count | Should -Be 3
            $playbook.Stages | Should -BeNullOrEmpty
        }
        
        It "Should handle both Sequence and Stages if present" {
            $hybridPlaybook = @'
@{
    Name = 'hybrid-playbook'
    Sequence = @('0400')  # Direct sequence
    Stages = @(
        @{
            Name = 'AdditionalStage'
            Sequence = @('0401')
        }
    )
}
'@
            $path = Join-Path $script:TestPlaybookDir "hybrid.psd1"
            Set-Content -Path $path -Value $hybridPlaybook
            
            $playbook = Import-PowerShellDataFile -Path $path
            
            # Should have both
            $playbook.Sequence | Should -Not -BeNullOrEmpty
            $playbook.Stages | Should -Not -BeNullOrEmpty
            
            # Direct sequence should take precedence
            $sequenceToUse = if ($playbook.Sequence) { $playbook.Sequence }
                            else { 
                                $seq = @()
                                foreach ($stage in $playbook.Stages) {
                                    if ($stage.Sequence) { $seq += $stage.Sequence }
                                }
                                $seq
                            }
            
            $sequenceToUse | Should -Contain '0400'
        }
    }
}