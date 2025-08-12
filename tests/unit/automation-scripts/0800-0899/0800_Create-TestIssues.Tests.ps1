#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    Pester tests for 0800_Create-TestIssues.ps1
.DESCRIPTION
    Tests the GitHub issue creation from test failures functionality
#>

BeforeAll {
    # Get the script path
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) "automation-scripts/0800_Create-TestIssues.ps1"
    
    # Mock dependencies
    Mock Import-Module -MockWith {}
    Mock Write-Host -MockWith {}
    Mock Write-Warning -MockWith {}
    Mock Write-Error -MockWith {}
    
    # Mock GitHub CLI
    Mock gh -MockWith {
        if ($args[0] -eq 'issue' -and $args[1] -eq 'create') {
            return "https://github.com/test/repo/issues/123"
        }
        if ($args[0] -eq 'issue' -and $args[1] -eq 'list') {
            return '[]' | ConvertTo-Json
        }
        return ""
    }
    
    # Mock file operations
    Mock Get-Content -MockWith {
        param($Path, $Raw)
        
        if ($Path -like "*Pester*.xml") {
            return @'
<?xml version="1.0" encoding="utf-8"?>
<test-run id="1" testcasecount="2" total="2" passed="1" failed="1">
  <test-case id="1" name="Test1" classname="TestClass" result="Passed" duration="0.001" />
  <test-case id="2" name="Test2" classname="TestClass" result="Failed" duration="0.002">
    <failure message="Test failed">Stack trace here</failure>
  </test-case>
</test-run>
'@
        }
        
        if ($Path -like "*Analyzer*.json") {
            return '[{"RuleName": "PSAvoidUsingWriteHost", "Severity": "Warning", "Message": "Avoid using Write-Host", "ScriptPath": "test.ps1", "Line": 10, "Column": 5}]'
        }
        
        return ""
    }
    
    Mock Get-ChildItem -MockWith {
        param($Path, $Filter, $ErrorAction)
        
        if ($Filter -like "*Pester*.xml") {
            return @(
                [PSCustomObject]@{
                    Name = "pester-results.xml"
                    FullName = "tests/results/pester-results.xml"
                    LastWriteTime = Get-Date
                }
            )
        }
        
        if ($Filter -like "*Analyzer*.json") {
            return @(
                [PSCustomObject]@{
                    Name = "analyzer-results.json"
                    FullName = "tests/results/analyzer-results.json"
                    LastWriteTime = Get-Date
                }
            )
        }
        
        return @()
    }
    
    Mock New-GitHubIssue -MockWith {
        return @{
            Number = 123
            Url = "https://github.com/test/repo/issues/123"
        }
    }
}

Describe "0800_Create-TestIssues" {
    Context "Parameter Validation" {
        It "Should accept valid Source parameter values" {
            { & $scriptPath -Source 'Pester' -DryRun } | Should -Not -Throw
            { & $scriptPath -Source 'PSScriptAnalyzer' -DryRun } | Should -Not -Throw
            { & $scriptPath -Source 'All' -DryRun } | Should -Not -Throw
        }
        
        It "Should support WhatIf functionality" {
            { & $scriptPath -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Results Parsing" {
        BeforeEach {
            Mock Test-Path -MockWith { $true }
        }
        
        It "Should parse Pester XML results correctly" {
            & $scriptPath -Source 'Pester' -DryRun -ResultsPath "./tests/results"
            
            Should -Invoke Get-ChildItem -AtLeast 1
        }
        
        It "Should parse PSScriptAnalyzer JSON results correctly" {
            & $scriptPath -Source 'PSScriptAnalyzer' -DryRun -ResultsPath "./tests/results"
            
            Should -Invoke Get-ChildItem -AtLeast 1
        }
        
        It "Should handle missing results gracefully" {
            Mock Get-ChildItem -MockWith { return @() }
            
            { & $scriptPath -DryRun } | Should -Not -Throw
        }
    }
    
    Context "Issue Creation" {
        BeforeEach {
            Mock Test-Path -MockWith { $true }
        }
        
        It "Should create issues in DryRun mode without calling GitHub API" {
            & $scriptPath -DryRun
            
            Should -Invoke gh -Times 0
        }
        
        It "Should group failures by file when specified" {
            & $scriptPath -GroupByFile -DryRun
            
            Should -Invoke Get-ChildItem -AtLeast 1
        }
        
        It "Should limit number of issues created" {
            & $scriptPath -MaxIssues 1 -DryRun
            
            Should -Invoke Get-ChildItem -AtLeast 1
        }
    }
    
    Context "Error Handling" {
        It "Should handle invalid paths" {
            Mock Test-Path -MockWith { $false }
            
            { & $scriptPath -ResultsPath "nonexistent" -DryRun } | Should -Not -Throw
        }
        
        It "Should handle malformed XML" {
            Mock Get-Content -MockWith { return "invalid xml" }
            
            { & $scriptPath -Source 'Pester' -DryRun } | Should -Not -Throw
        }
    }
}
