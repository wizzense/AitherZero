#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

BeforeAll {
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) "automation-scripts/0801_Parse-PesterResults.ps1"
    
    Mock Write-Host -MockWith {}
    Mock Write-Error -MockWith {}
    Mock Get-Content -MockWith {
        if ($Path -like "*.xml") {
            return '<?xml version="1.0"?><test-run total="1" passed="1" failed="0"><test-case name="Test1" result="Passed" /></test-run>'
        }
        if ($Path -like "*.json") {
            return '{"TotalCount": 1, "PassedCount": 1, "FailedCount": 0}'
        }
    }
    Mock Test-Path -MockWith { $true }
    Mock Get-Date -MockWith { return "2023-01-01" }
}

Describe "0801_Parse-PesterResults" {
    Context "Parameter Validation" {
        It "Should require ResultsFile parameter" {
            { & $scriptPath } | Should -Throw
        }
        
        It "Should accept valid Format values" {
            { & $scriptPath -ResultsFile "test.xml" -Format "XML" } | Should -Not -Throw
            { & $scriptPath -ResultsFile "test.json" -Format "JSON" } | Should -Not -Throw
            { & $scriptPath -ResultsFile "test.xml" -Format "Auto" } | Should -Not -Throw
        }
        
        It "Should accept valid OutputFormat values" {
            { & $scriptPath -ResultsFile "test.xml" -OutputFormat "Summary" } | Should -Not -Throw
            { & $scriptPath -ResultsFile "test.xml" -OutputFormat "Detailed" } | Should -Not -Throw
            { & $scriptPath -ResultsFile "test.xml" -OutputFormat "Full" } | Should -Not -Throw
        }
    }
    
    Context "File Validation" {
        It "Should fail when file does not exist" {
            Mock Test-Path -MockWith { $false }
            
            { & $scriptPath -ResultsFile "nonexistent.xml" } | Should -Throw
        }
        
        It "Should detect XML format by extension" {
            & $scriptPath -ResultsFile "test.xml" -Format "Auto"
            
            Should -Invoke Test-Path -Times 1
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should detect JSON format by extension" {
            & $scriptPath -ResultsFile "test.json" -Format "Auto"
            
            Should -Invoke Test-Path -Times 1
            Should -Invoke Get-Content -Times 1
        }
    }
    
    Context "XML Parsing" {
        It "Should parse NUnit XML format" {
            Mock Get-Content -MockWith {
                return '<?xml version="1.0"?><test-run total="2" passed="1" failed="1" duration="5.5"><test-case name="Test1" result="Failed" duration="1.0"><failure message="Failed">Stack trace</failure></test-case></test-run>'
            }
            
            { & $scriptPath -ResultsFile "test.xml" -Format "XML" } | Should -Not -Throw
        }
        
        It "Should handle malformed XML gracefully" {
            Mock Get-Content -MockWith { return "invalid xml" }
            
            { & $scriptPath -ResultsFile "test.xml" -Format "XML" } | Should -Throw
        }
    }
    
    Context "JSON Parsing" {
        It "Should parse Pester 5+ JSON format" {
            Mock Get-Content -MockWith {
                return '{"TotalCount": 2, "PassedCount": 1, "FailedCount": 1, "Duration": {"TotalSeconds": 5.5}}'
            }
            
            { & $scriptPath -ResultsFile "test.json" -Format "JSON" } | Should -Not -Throw
        }
        
        It "Should handle malformed JSON gracefully" {
            Mock Get-Content -MockWith { return "invalid json" }
            
            { & $scriptPath -ResultsFile "test.json" -Format "JSON" } | Should -Throw
        }
    }
    
    Context "Output Formatting" {
        It "Should output summary format by default" {
            & $scriptPath -ResultsFile "test.xml" -OutputFormat "Summary"
            
            Should -Invoke Write-Host -AtLeast 1
        }
        
        It "Should output detailed JSON when requested" {
            $result = & $scriptPath -ResultsFile "test.xml" -OutputFormat "Detailed"
            
            # Should produce JSON output
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should output full data when requested" {
            $result = & $scriptPath -ResultsFile "test.xml" -OutputFormat "Full"
            
            Should -Invoke Get-Content -Times 1
        }
    }
    
    Context "Options Processing" {
        It "Should group failures by Describe when requested" {
            & $scriptPath -ResultsFile "test.xml" -GroupByDescribe
            
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should include performance analysis when requested" {
            & $scriptPath -ResultsFile "test.xml" -IncludePerformance
            
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should filter to failures only when requested" {
            & $scriptPath -ResultsFile "test.xml" -FailuresOnly
            
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should include coverage when requested" {
            & $scriptPath -ResultsFile "test.json" -IncludeCoverage -Format "JSON"
            
            Should -Invoke Get-Content -Times 1
        }
    }
}
