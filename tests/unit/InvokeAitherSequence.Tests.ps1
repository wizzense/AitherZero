#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    Unit tests for Invoke-AitherSequence parameter handling
.DESCRIPTION
    Tests to verify that Invoke-AitherSequence correctly handles both string and array inputs
#>

BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    
    # Import the full AitherZero module to get all dependencies
    Import-Module (Join-Path $script:ProjectRoot "AitherZero.psd1") -Force -ErrorAction Stop
    
    # Mock Invoke-OrchestrationSequence to avoid actual execution
    Mock Invoke-OrchestrationSequence {
        param($Sequence, $ContinueOnError, $Parallel, $MaxConcurrency, $DryRun, $Variables, $SavePlaybook, $UseCache, $GenerateSummary)
        
        # Return a mock result
        return [PSCustomObject]@{
            Success = $true
            Completed = $Sequence.Count
            Failed = 0
            Skipped = 0
            Duration = [TimeSpan]::FromSeconds(1)
            Results = @()
            ExitCode = 0
        }
    }
}

Describe "Invoke-AitherSequence Parameter Handling" -Tag 'Unit', 'CLI', 'Sequence' {
    
    Context "String Parameter Format" {
        It "Should accept comma-separated string format" {
            { Invoke-AitherSequence "0500,0501" } | Should -Not -Throw
        }
        
        It "Should accept single script in string format" {
            { Invoke-AitherSequence "0500" } | Should -Not -Throw
        }
        
        It "Should accept range in string format" {
            { Invoke-AitherSequence "0500-0510" } | Should -Not -Throw
        }
        
        It "Should accept complex string format with ranges and exclusions" {
            { Invoke-AitherSequence "0400-0499,!0450,0500" } | Should -Not -Throw
        }
    }
    
    Context "Array Parameter Format" {
        It "Should accept PowerShell array syntax without quotes (0500,0501)" {
            { Invoke-AitherSequence 0500,0501 } | Should -Not -Throw
        }
        
        It "Should accept explicit string array @('0500', '0501')" {
            { Invoke-AitherSequence @("0500", "0501") } | Should -Not -Throw
        }
        
        It "Should accept array with ranges @('0500-0510', '0600')" {
            { Invoke-AitherSequence @("0500-0510", "0600") } | Should -Not -Throw
        }
        
        It "Should accept mixed array with numbers and strings @(0500, '0501')" {
            { Invoke-AitherSequence @(0500, "0501") } | Should -Not -Throw
        }
    }
    
    Context "Parameter Transformation" {
        It "Should pass array parameter to Invoke-OrchestrationSequence correctly" {
            $result = Invoke-AitherSequence 0500,0501
            
            # Verify the mock was called
            Should -Invoke Invoke-OrchestrationSequence -Times 1 -Exactly
        }
        
        It "Should preserve array elements when calling orchestration engine" {
            Mock Invoke-OrchestrationSequence {
                param($Sequence)
                # Verify we receive an array
                $Sequence | Should -BeOfType [System.Array]
                
                return [PSCustomObject]@{
                    Success = $true
                    Completed = $Sequence.Count
                    Failed = 0
                    Duration = [TimeSpan]::FromSeconds(1)
                }
            }
            
            Invoke-AitherSequence 0500,0501
        }
    }
    
    Context "Additional Parameters" {
        It "Should accept array sequence with -ContinueOnError switch" {
            { Invoke-AitherSequence 0500,0501 -ContinueOnError } | Should -Not -Throw
        }
        
        It "Should accept array sequence with -DryRun switch" {
            { Invoke-AitherSequence 0500,0501 -DryRun } | Should -Not -Throw
        }
        
        It "Should accept array sequence with -Parallel and -MaxConcurrency" {
            { Invoke-AitherSequence 0500,0501 -Parallel -MaxConcurrency 8 } | Should -Not -Throw
        }
        
        It "Should accept array sequence with -Variables hashtable" {
            { Invoke-AitherSequence 0500,0501 -Variables @{TestMode=$true} } | Should -Not -Throw
        }
    }
    
    Context "Return Values" {
        It "Should return result object from orchestration engine" {
            $result = Invoke-AitherSequence 0500,0501
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeTrue
            $result.Completed | Should -BeGreaterThan 0
        }
        
        It "Should set exit code based on result" {
            $result = Invoke-AitherSequence 0500,0501
            
            $global:LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "Invoke-AitherSequence Error Handling" -Tag 'Unit', 'CLI', 'Sequence', 'Error' {
    
    BeforeAll {
        # Mock orchestration engine to return failure
        Mock Invoke-OrchestrationSequence {
            param($Sequence, $ContinueOnError)
            
            return [PSCustomObject]@{
                Success = $false
                Completed = 1
                Failed = 1
                Skipped = 0
                Duration = [TimeSpan]::FromSeconds(1)
                Results = @(
                    [PSCustomObject]@{ Number = "0500"; Success = $false; Error = "Test failure" }
                )
                ExitCode = 1
            }
        }
    }
    
    Context "Failure Scenarios" {
        It "Should set exit code to 1 on failure" {
            try {
                Invoke-AitherSequence 0500,0501 -ErrorAction SilentlyContinue
            } catch {
                # Expected to throw
            }
            
            $global:LASTEXITCODE | Should -Be 1
        }
        
        It "Should throw error when script fails and -ContinueOnError is not set" {
            { Invoke-AitherSequence 0500,0501 -ErrorAction Stop } | Should -Throw -ExpectedMessage "*failed*"
        }
        
        It "Should not throw when -ContinueOnError is set" {
            { Invoke-AitherSequence 0500,0501 -ContinueOnError } | Should -Not -Throw
        }
    }
}
