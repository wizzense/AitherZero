#Requires -Version 7.0

BeforeAll {
    # Mock AI integration modules
    $script:MockCalls = @{}
    
    # Create mock GitAutomation module
    New-Module -Name 'MockGitAutomation' -ScriptBlock {
        function Get-GitStatus {
            return @{
                Clean = $false
                Modified = @(@{ Path = 'src/main.ps1' }, @{ Path = 'tests/test.ps1' })
                Staged = @(@{ Path = 'src/main.ps1' })
                Untracked = @()
                Deleted = @()
            }
        }
        
        function Get-GitDiff {
            param($Staged = $false)
            return @"
diff --git a/src/main.ps1 b/src/main.ps1
index abc123..def456 100644
--- a/src/main.ps1
+++ b/src/main.ps1
@@ -1,3 +1,6 @@
 function Get-Data {
     param($Id)
+    if (-not $Id) {
+        throw "Id parameter is required"
+    }
     return "Data for $Id"
 }
"@
        }
        
        Export-ModuleMember -Function *
    } | Import-Module -Force
    
    # Create mock AI modules
    New-Module -Name 'MockAIWorkflowOrchestrator' -ScriptBlock {
        function Invoke-AIAnalysis {
            param($Content, $Context, $Provider = 'Claude')
            $script:MockCalls['Invoke-AIAnalysis'] += @{ 
                Content = $Content
                Context = $Context
                Provider = $Provider
            }
            
            return @{
                Success = $true
                Response = @{
                    type = 'feat'
                    scope = 'validation'
                    subject = 'add parameter validation to Get-Data function'
                    body = 'Added null check for Id parameter to prevent errors when called without required parameter'
                    breakingChange = $false
                    confidence = 0.9
                }
                Provider = $Provider
                TokensUsed = 150
            }
        }
        
        Export-ModuleMember -Function *
    } | Import-Module -Force

    # Mock external commands
    Mock git { 
        switch -Regex ($arguments -join ' ') {
            'diff --staged' { return (Get-GitDiff -Staged $true) }
            'diff' { return (Get-GitDiff) }
            'log -1 --pretty' { return 'feat(api): add user authentication system' }
            'branch --show-current' { return 'feature/add-validation' }
            default { return '' }
        }
    }
    
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-Error { }
    Mock Read-Host { return 'y' }
    Mock Test-Path { return $true }
    Mock Get-Content { return '{"ai": {"defaultProvider": "Claude"}}' }
    
    # Initialize mock calls tracking
    $script:MockCalls = @{
        'Invoke-AIAnalysis' = @()
    }
}

Describe "0741_Generate-AICommitMessage" {
    BeforeEach {
        $script:MockCalls = @{
            'Invoke-AIAnalysis' = @()
        }
    }
    
    Context "Parameter Validation" {
        It "Should accept Provider parameter" {
            { & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -Provider "Claude" -WhatIf } | Should -Not -Throw
        }
        
        It "Should accept IncludeContext switch" {
            { & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -IncludeContext -WhatIf } | Should -Not -Throw
        }
        
        It "Should accept MaxTokens parameter" {
            { & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -MaxTokens 500 -WhatIf } | Should -Not -Throw
        }
        
        It "Should accept AutoCommit switch" {
            { & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -AutoCommit -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Git Status Analysis" {
        It "Should analyze staged changes for commit message generation" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf
            
            Should -Invoke git -ParameterFilter { $arguments -contains 'diff' -and $arguments -contains '--staged' }
        }
        
        It "Should handle case with no staged changes" {
            Mock git { return '' } -ParameterFilter { $arguments -contains '--staged' }
            
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf
            
            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*no staged changes*" }
        }
        
        It "Should collect file changes for analysis" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf
            
            $analysisCall = $script:MockCalls['Invoke-AIAnalysis'] | Select-Object -First 1
            $analysisCall.Content | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "AI Analysis Integration" {
        It "Should call AI analysis with git diff content" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf
            
            $script:MockCalls['Invoke-AIAnalysis'] | Should -HaveCount 1
            $analysisCall = $script:MockCalls['Invoke-AIAnalysis'] | Select-Object -First 1
            $analysisCall.Content | Should -Match "function Get-Data"
        }
        
        It "Should use specified provider" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -Provider "Gemini" -WhatIf
            
            $analysisCall = $script:MockCalls['Invoke-AIAnalysis'] | Select-Object -First 1
            $analysisCall.Provider | Should -Be "Gemini"
        }
        
        It "Should include context when IncludeContext is specified" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -IncludeContext -WhatIf
            
            $analysisCall = $script:MockCalls['Invoke-AIAnalysis'] | Select-Object -First 1
            $analysisCall.Context | Should -Not -BeNullOrEmpty
        }
        
        It "Should build context from branch name and recent commits" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -IncludeContext -WhatIf
            
            Should -Invoke git -ParameterFilter { $arguments -contains 'branch' -and $arguments -contains '--show-current' }
            Should -Invoke git -ParameterFilter { $arguments -contains 'log' }
        }
    }
    
    Context "Commit Message Generation" {
        It "Should generate conventional commit message format" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Generated commit message:*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "feat(validation): add parameter validation*" }
        }
        
        It "Should display confidence score" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Confidence: 90%*" }
        }
        
        It "Should show token usage information" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Tokens used:*" }
        }
        
        It "Should format commit message with body when provided" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Added null check for Id parameter*" }
        }
    }
    
    Context "Auto Commit Functionality" {
        It "Should prompt for confirmation before auto-committing" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -AutoCommit -WhatIf
            
            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*Use this commit message*" }
        }
        
        It "Should create commit when user confirms" {
            Mock Read-Host { return 'y' }
            
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -AutoCommit -WhatIf
            
            Should -Invoke git -ParameterFilter { $arguments[0] -eq 'commit' }
        }
        
        It "Should not create commit when user declines" {
            Mock Read-Host { return 'n' }
            
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -AutoCommit -WhatIf
            
            Should -Not -Invoke git -ParameterFilter { $arguments[0] -eq 'commit' }
        }
    }
    
    Context "Low Confidence Handling" {
        BeforeAll {
            # Mock low confidence response
            New-Module -Name 'MockAIWorkflowOrchestratorLowConf' -ScriptBlock {
                function Invoke-AIAnalysis {
                    param($Content, $Context, $Provider = 'Claude')
                    $script:MockCalls['Invoke-AIAnalysis'] += @{ 
                        Content = $Content
                        Context = $Context
                        Provider = $Provider
                    }
                    
                    return @{
                        Success = $true
                        Response = @{
                            type = 'chore'
                            scope = ''
                            subject = 'update files'
                            body = ''
                            breakingChange = $false
                            confidence = 0.3
                        }
                        Provider = $Provider
                        TokensUsed = 75
                    }
                }
                
                Export-ModuleMember -Function *
            } | Import-Module -Force
        }
        
        It "Should warn about low confidence scores" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf
            
            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*low confidence*" }
        }
        
        It "Should suggest manual review for low confidence" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*manual review*" }
        }
    }
    
    Context "Breaking Changes Detection" {
        BeforeAll {
            # Mock breaking change response
            New-Module -Name 'MockAIWorkflowOrchestratorBreaking' -ScriptBlock {
                function Invoke-AIAnalysis {
                    param($Content, $Context, $Provider = 'Claude')
                    
                    return @{
                        Success = $true
                        Response = @{
                            type = 'feat'
                            scope = 'api'
                            subject = 'change authentication method'
                            body = 'Switched from basic auth to OAuth2. This is a breaking change.'
                            breakingChange = $true
                            confidence = 0.95
                        }
                        Provider = $Provider
                        TokensUsed = 200
                    }
                }
                
                Export-ModuleMember -Function *
            } | Import-Module -Force
        }
        
        It "Should detect and format breaking changes" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*BREAKING CHANGE*" }
        }
        
        It "Should add exclamation mark for breaking changes" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "feat(api)\!: change authentication*" }
        }
    }
    
    Context "Error Handling" {
        It "Should handle AI analysis failures" {
            New-Module -Name 'MockAIWorkflowOrchestratorError' -ScriptBlock {
                function Invoke-AIAnalysis { throw "AI service unavailable" }
                Export-ModuleMember -Function *
            } | Import-Module -Force
            
            { & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Error -ParameterFilter { $Message -like "*AI analysis failed*" }
        }
        
        It "Should handle git command failures" {
            Mock git { throw "Git error" }
            
            { & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle missing AI modules" {
            Mock Import-Module { throw "Module not found" }
            
            { & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -WhatIf } | Should -Throw
        }
    }
    
    Context "Token Limit Management" {
        It "Should respect MaxTokens parameter" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -MaxTokens 100 -WhatIf
            
            # Should truncate diff content if it exceeds token limit
            $analysisCall = $script:MockCalls['Invoke-AIAnalysis'] | Select-Object -First 1
            $analysisCall.Content.Length | Should -BeLessOrEqual 1000  # Approximate token-to-char ratio
        }
        
        It "Should warn about large diffs" {
            Mock git { return ('A' * 10000) } -ParameterFilter { $arguments -contains '--staged' }
            
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -MaxTokens 100 -WhatIf
            
            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*large diff*" }
        }
    }
    
    Context "WhatIf Support" {
        It "Should show commit message generation without creating commit when WhatIf is used" {
            & "/workspaces/AitherZero/automation-scripts/0741_Generate-AICommitMessage.ps1" -AutoCommit -WhatIf
            
            Should -Not -Invoke git -ParameterFilter { $arguments[0] -eq 'commit' }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Generated commit message:*" }
        }
    }
}
