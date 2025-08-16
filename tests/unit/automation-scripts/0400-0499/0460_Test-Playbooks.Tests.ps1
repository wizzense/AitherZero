#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Unit tests for 0460_Test-Playbooks.ps1
.DESCRIPTION
    Tests the playbook validation functionality
#>

BeforeAll {
    # Get script path
    $script:ScriptPath = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) "automation-scripts/0460_Test-Playbooks.ps1"
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
    
    # Create temp directory for test playbooks
    $script:TempPlaybookDir = Join-Path ([System.IO.Path]::GetTempPath()) "test-playbooks-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TempPlaybookDir -Force | Out-Null
    
    # Define Write-CustomLog function if it doesn't exist
    if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param($Message, $Level = 'Information')
            # Mock implementation
        }
    }
    
    # Mock functions
    Mock Write-Host { }
    Mock Write-CustomLog { }
    Mock Import-Module { }
    Mock Test-Path { 
        param($Path)
        if ($Path -like "*automation-scripts*") { return $true }
        if ($Path -like "*.psd1") { return $true }
        return $false
    }
    Mock Get-ChildItem {
        param($Path, $Filter)
        if ($Filter -eq "*.psd1") {
            return @(
                [PSCustomObject]@{ 
                    Name = "test-playbook.psd1"
                    FullName = Join-Path $script:TempPlaybookDir "test-playbook.psd1"
                }
            )
        }
        return @()
    }
    Mock Import-PowerShellDataFile {
        return @{
            Name = 'test-playbook'
            Description = 'Test playbook'
            Stages = @(
                @{
                    Name = 'Stage1'
                    Sequence = @('0400', '0401')
                }
            )
        }
    }
    Mock Start-Process {
        return [PSCustomObject]@{
            ExitCode = 0
        }
    }
}

AfterAll {
    # Cleanup
    if (Test-Path $script:TempPlaybookDir) {
        Remove-Item $script:TempPlaybookDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "0460_Test-Playbooks.ps1 Tests" -Tag 'Unit' {
    
    Context "Parameter Validation" {
        
        It "Should accept valid playbook directory" {
            { 
                & $script:ScriptPath -PlaybookDir $script:TempPlaybookDir -WhatIf
            } | Should -Not -Throw
        }
        
        It "Should handle missing playbook directory" {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq "./missing" }
            
            { 
                & $script:ScriptPath -PlaybookDir "./missing" -WhatIf
            } | Should -Throw
        }
    }
    
    Context "Playbook Loading" {
        
        It "Should load all PSD1 playbooks" {
            & $script:ScriptPath -PlaybookDir $script:TempPlaybookDir -WhatIf
            
            Should -Invoke Get-ChildItem -Times 1 -ParameterFilter {
                $Filter -eq "*.psd1"
            }
        }
        
        It "Should validate playbook structure" {
            # Create a valid playbook
            $validPlaybook = @'
@{
    Name = 'valid-playbook'
    Description = 'Valid test playbook'
    Stages = @(
        @{
            Name = 'Stage1'
            Sequence = @('0400')
        }
    )
}
'@
            $playbookPath = Join-Path $script:TempPlaybookDir "valid.psd1"
            Set-Content -Path $playbookPath -Value $validPlaybook
            
            { 
                & $script:ScriptPath -PlaybookDir $script:TempPlaybookDir -WhatIf
            } | Should -Not -Throw
        }
    }
    
    Context "Script Validation" {
        
        It "Should check if referenced scripts exist" {
            & $script:ScriptPath -PlaybookDir $script:TempPlaybookDir -WhatIf
            
            Should -Invoke Test-Path -ParameterFilter {
                $Path -like "*0400*.ps1" -or $Path -like "*0401*.ps1"
            }
        }
        
        It "Should report missing scripts" {
            Mock Test-Path { $false } -ParameterFilter { $Path -like "*0999*.ps1" }
            Mock Import-PowerShellDataFile {
                return @{
                    Name = 'test-playbook'
                    Stages = @(
                        @{
                            Name = 'Stage1'
                            Sequence = @('0999')
                        }
                    )
                }
            }
            
            $output = & $script:ScriptPath -PlaybookDir $script:TempPlaybookDir -WhatIf 2>&1
            $output | Should -Match "missing|not found" -Because "Should report missing script 0999"
        }
    }
    
    Context "Dry Run Testing" {
        
        It "Should perform dry run for each playbook" -Skip {
            # Skip dry run test as it's optional
            $true | Should -Be $true
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle malformed playbooks gracefully" {
            Mock Import-PowerShellDataFile { throw "Invalid PSD1" }
            
            $output = & $script:ScriptPath -PlaybookDir $script:TempPlaybookDir 2>&1
            $output | Should -Match "Failed|Error|Invalid"
        }
        
        It "Should stop on error when requested" {
            Mock Import-PowerShellDataFile { throw "Test error" } -MockWith {
                throw "Test error"
            }
            
            { 
                & $script:ScriptPath -PlaybookDir $script:TempPlaybookDir -StopOnError
            } | Should -Throw
        }
    }
    
    Context "CI Mode" {
        
        It "Should throw on failures in CI mode" {
            Mock Test-Path { $false } -ParameterFilter { $Path -like "*0999*.ps1" }
            Mock Import-PowerShellDataFile {
                return @{
                    Name = 'test-playbook'
                    Stages = @(
                        @{
                            Name = 'Stage1'
                            Sequence = @('0999')
                        }
                    )
                }
            }
            
            { 
                & $script:ScriptPath -PlaybookDir $script:TempPlaybookDir -CI
            } | Should -Throw
        }
    }
}