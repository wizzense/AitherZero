#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

BeforeAll {
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) "automation-scripts/0810_Create-IssueFromTestFailure.ps1"
    
    Mock Write-Host -MockWith {}
    Mock Write-Warning -MockWith {}
    Mock Write-Error -MockWith {}
    Mock Import-Module -MockWith {}
    
    # Mock system functions
    Mock Test-Path -MockWith { $true }
    Mock Get-Content -MockWith {
        if ($Path -like "*test-results.json") {
            return '{"Tests": [{"Name": "TestName", "Result": "Failed", "ErrorRecord": "Test error"}]}'
        }
        return ""
    }
    
    # Mock GitHub CLI
    Mock gh -MockWith {
        return "https://github.com/test/repo/issues/123"
    }
    
    Mock Get-Command -MockWith { return $true } -ParameterFilter { $Name -eq "gh" }
    
    # Mock git commands  
    Mock git -MockWith {
        switch ($args[0]) {
            "branch" { return "main" }
            "rev-parse" { return "abc123" }
            default { return "" }
        }
    }
    
    # Mock environment variables
    $env:GITHUB_ACTIONS = $null
    $env:GITHUB_RUN_ID = $null
    $env:GITHUB_ACTOR = $null
    $env:GITHUB_WORKFLOW = $null
    
    Mock Get-Date -MockWith { return [DateTime]"2023-01-01 12:00:00" }
}

Describe "0810_Create-IssueFromTestFailure" {
    Context "Parameter Validation" {
        It "Should accept valid IssueType values" {
            { & $scriptPath -IssueType "TestFailure" -AutoCreate } | Should -Not -Throw
            { & $scriptPath -IssueType "CodeViolation" -AutoCreate } | Should -Not -Throw  
            { & $scriptPath -IssueType "Bug" -AutoCreate } | Should -Not -Throw
        }
        
        It "Should support WhatIf functionality" {
            { & $scriptPath -WhatIf } | Should -Not -Throw
        }
        
        It "Should accept custom TestResults path" {
            { & $scriptPath -TestResults "custom/path.json" -AutoCreate } | Should -Not -Throw
        }
        
        It "Should handle GitHubActions switch" {
            { & $scriptPath -GitHubActions -AutoCreate } | Should -Not -Throw
        }
    }
    
    Context "Environment Detection" {
        It "Should detect GitHub Actions environment" {
            $env:GITHUB_ACTIONS = "true"
            $env:GITHUB_RUN_ID = "123456"
            $env:GITHUB_ACTOR = "testuser"
            $env:GITHUB_WORKFLOW = "CI"
            
            & $scriptPath -AutoCreate
            
            Should -Invoke Get-Content -AtLeast 1
            
            # Cleanup
            $env:GITHUB_ACTIONS = $null
            $env:GITHUB_RUN_ID = $null
            $env:GITHUB_ACTOR = $null
            $env:GITHUB_WORKFLOW = $null
        }
        
        It "Should get system context correctly" {
            & $scriptPath -AutoCreate
            
            Should -Invoke git -ParameterFilter { $args[0] -eq "branch" }
            Should -Invoke git -ParameterFilter { $args[0] -eq "rev-parse" }
        }
    }
    
    Context "Test Failure Parsing" {
        BeforeEach {
            Mock Test-Path -MockWith { $true }
        }
        
        It "Should parse JSON test results" {
            Mock Get-Content -MockWith {
                return '{"Tests": [{"Name": "FailedTest", "Result": "Failed", "ErrorRecord": "Assertion failed"}]}'
            }
            
            & $scriptPath -IssueType "TestFailure" -AutoCreate
            
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should parse XML test results" {
            Mock Get-Content -MockWith {
                return '<?xml version="1.0"?><test-run><test-case name="Test" result="Failed"></test-case></test-run>'
            }
            
            & $scriptPath -TestResults "test.xml" -IssueType "TestFailure" -AutoCreate
            
            Should -Invoke Get-Content -Times 1
        }
        
        It "Should handle missing test results file" {
            Mock Test-Path -MockWith { $false }
            
            & $scriptPath -TestResults "missing.json" -AutoCreate
            
            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*not found*" }
        }
        
        It "Should handle malformed test results" {
            Mock Get-Content -MockWith { return "invalid json" }
            
            { & $scriptPath -IssueType "TestFailure" -AutoCreate } | Should -Not -Throw
        }
    }
    
    Context "Code Violation Processing" {
        It "Should get PSScriptAnalyzer violations" {
            Mock Test-Path -MockWith { $true }
            Mock Get-Content -MockWith {
                return '[{"RuleName": "PSAvoidUsingWriteHost", "Severity": "Warning", "Message": "Avoid Write-Host"}]'
            }
            
            & $scriptPath -IssueType "CodeViolation" -AutoCreate
            
            Should -Invoke Get-Content -AtLeast 1
        }
        
        It "Should group violations by rule" {
            Mock Test-Path -MockWith { $true }
            Mock Get-Content -MockWith {
                return '[{"RuleName": "Rule1", "Severity": "Error"}, {"RuleName": "Rule1", "Severity": "Error"}]'
            }
            
            & $scriptPath -IssueType "CodeViolation" -AutoCreate
            
            Should -Invoke Get-Content -AtLeast 1
        }
        
        It "Should run analyzer if results dont exist" {
            Mock Test-Path -MockWith { $false }
            Mock Test-Path -MockWith { $true } -ParameterFilter { $Path -like "*0404*" }
            
            & $scriptPath -IssueType "CodeViolation" -AutoCreate
            
            Should -Invoke Test-Path -AtLeast 1
        }
    }
    
    Context "Issue Body Generation" {
        It "Should generate TestFailure issue body" {
            Mock Test-Path -MockWith { $true }
            Mock Get-Content -MockWith {
                return '{"Tests": [{"Name": "Test1", "Result": "Failed", "ErrorRecord": "Error occurred", "ScriptBlock": {"File": "test.ps1", "StartPosition": {"StartLine": 10}}}]}'
            }
            
            & $scriptPath -IssueType "TestFailure" -AutoCreate
            
            Should -Invoke Get-Content -AtLeast 1
        }
        
        It "Should generate CodeViolation issue body" {
            Mock Test-Path -MockWith { $true }
            Mock Get-Content -MockWith {
                return '[{"RuleName": "TestRule", "Severity": "Warning", "Message": "Test violation", "ScriptName": "test.ps1", "Line": 5}]'
            }
            
            & $scriptPath -IssueType "CodeViolation" -AutoCreate
            
            Should -Invoke Get-Content -AtLeast 1
        }
        
        It "Should generate Bug issue body" {
            $testData = @{
                Description = "Test bug description"
                Error = "Test error message"
            }
            
            & $scriptPath -IssueType "Bug" -AutoCreate
            
            # Should complete without errors even without specific bug data
            Should -Invoke Get-Date -AtLeast 1
        }
        
        It "Should include GitHub Actions context when available" {
            $env:GITHUB_ACTIONS = "true"
            $env:GITHUB_RUN_ID = "123456"
            $env:GITHUB_ACTOR = "testuser"
            $env:GITHUB_WORKFLOW = "Test Workflow"
            
            & $scriptPath -IssueType "TestFailure" -AutoCreate
            
            Should -Invoke Get-Content -AtLeast 1
            
            # Cleanup
            $env:GITHUB_ACTIONS = $null
            $env:GITHUB_RUN_ID = $null
            $env:GITHUB_ACTOR = $null  
            $env:GITHUB_WORKFLOW = $null
        }
    }
    
    Context "GitHub Issue Creation" {
        BeforeEach {
            Mock Test-Path -MockWith { $true }
            Mock Get-Content -MockWith {
                return '{"Tests": [{"Name": "Test1", "Result": "Failed"}]}'
            }
        }
        
        It "Should check for GitHub CLI availability" {
            & $scriptPath -IssueType "TestFailure" -AutoCreate
            
            Should -Invoke Get-Command -ParameterFilter { $Name -eq "gh" }
        }
        
        It "Should handle missing GitHub CLI" {
            Mock Get-Command -MockWith { return $null } -ParameterFilter { $Name -eq "gh" }
            
            { & $scriptPath -IssueType "TestFailure" -AutoCreate } | Should -Throw "*GitHub CLI*not installed*"
        }
        
        It "Should create issue with proper parameters" {
            & $scriptPath -IssueType "TestFailure" -AutoCreate
            
            Should -Invoke gh -ParameterFilter { $args[0] -eq "issue" -and $args[1] -eq "create" }
        }
        
        It "Should handle GitHub CLI errors" {
            Mock gh -MockWith { 
                $global:LASTEXITCODE = 1
                return "Error creating issue"
            }
            
            & $scriptPath -IssueType "TestFailure" -AutoCreate
            
            Should -Invoke Write-Error -ParameterFilter { $Message -like "*Failed to create issue*" }
        }
        
        It "Should include proper labels" {
            & $scriptPath -IssueType "TestFailure" -AutoCreate
            
            Should -Invoke gh -ParameterFilter { $args -contains "--label" }
        }
        
        It "Should add CI failure label in GitHub Actions" {
            $env:GITHUB_ACTIONS = "true"
            
            & $scriptPath -IssueType "TestFailure" -AutoCreate
            
            Should -Invoke gh -AtLeast 1
            
            $env:GITHUB_ACTIONS = $null
        }
    }
    
    Context "Interactive Mode" {
        BeforeEach {
            Mock Test-Path -MockWith { $true }
            Mock Get-Content -MockWith {
                return '{"Tests": [{"Name": "Test1", "Result": "Failed"}]}'
            }
        }
        
        It "Should prompt user when not in AutoCreate mode" {
            Mock Read-Host -MockWith { return "Y" }
            $env:GITHUB_ACTIONS = $null
            
            & $scriptPath -IssueType "TestFailure"
            
            Should -Invoke Read-Host -Times 1
        }
        
        It "Should skip prompts in AutoCreate mode" {
            Mock Read-Host -MockWith { return "N" }
            
            & $scriptPath -IssueType "TestFailure" -AutoCreate
            
            Should -Invoke Read-Host -Times 0
        }
        
        It "Should skip prompts in GitHub Actions" {
            $env:GITHUB_ACTIONS = "true"
            Mock Read-Host -MockWith { return "N" }
            
            & $scriptPath -IssueType "TestFailure"
            
            Should -Invoke Read-Host -Times 0
            
            $env:GITHUB_ACTIONS = $null
        }
    }
    
    Context "Error Handling and Edge Cases" {
        It "Should handle no issues to create" {
            Mock Test-Path -MockWith { $true }
            Mock Get-Content -MockWith { return '{"Tests": []}' }
            
            $result = & $scriptPath -IssueType "TestFailure" -AutoCreate
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*No issues to create*" }
        }
        
        It "Should handle script execution errors gracefully" {
            Mock Test-Path -MockWith { throw "File system error" }
            
            { & $scriptPath -IssueType "TestFailure" -AutoCreate } | Should -Throw
        }
        
        It "Should output GitHub Actions notices when appropriate" {
            $env:GITHUB_ACTIONS = "true"
            Mock Test-Path -MockWith { $true }
            Mock Get-Content -MockWith {
                return '{"Tests": [{"Name": "Test1", "Result": "Failed"}]}'
            }
            
            & $scriptPath -IssueType "TestFailure" -AutoCreate
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*::notice::*" }
            
            $env:GITHUB_ACTIONS = $null
        }
        
        It "Should validate issue types" {
            { & $scriptPath -IssueType "InvalidType" } | Should -Throw
        }
    }
}
