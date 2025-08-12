#Requires -Version 7.0

BeforeAll {
    # Mock AI agent modules
    $script:MockCalls = @{}
    
    # Create mock ClaudeCodeIntegration module
    New-Module -Name 'MockClaudeCodeIntegration' -ScriptBlock {
        function Initialize-ClaudeIntegration {
            param($ApiKey, $ValidationOnly)
            $script:MockCalls['Initialize-ClaudeIntegration'] += @{ 
                ApiKey = $ApiKey
                ValidationOnly = $ValidationOnly
            }
            return @{ Success = $true; Message = "Claude integration initialized" }
        }
        
        function Test-ClaudeConnection {
            return @{ Success = $true; ResponseTime = 150 }
        }
        
        Export-ModuleMember -Function *
    } | Import-Module -Force
    
    # Create mock AIWorkflowOrchestrator module
    New-Module -Name 'MockAIWorkflowOrchestrator' -ScriptBlock {
        function Initialize-AIOrchestrator {
            param($Providers)
            $script:MockCalls['Initialize-AIOrchestrator'] += @{ Providers = $Providers }
            return @{ Success = $true; ActiveProviders = $Providers }
        }
        
        function Set-AIRateLimit {
            param($Provider, $RequestsPerMinute)
            $script:MockCalls['Set-AIRateLimit'] += @{ 
                Provider = $Provider
                RequestsPerMinute = $RequestsPerMinute 
            }
        }
        
        Export-ModuleMember -Function *
    } | Import-Module -Force

    # Mock external commands
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-Error { }
    Mock Read-Host { return 'fake-api-key' }
    Mock Test-Path { return $true }
    Mock Get-Content { return '{"ai": {"providers": {}}}' }
    Mock Set-Content { }
    Mock ConvertFrom-Json { 
        return @{
            ai = @{
                providers = @{
                    claude = @{ apiKey = 'existing-key'; enabled = $true }
                    gemini = @{ apiKey = 'gemini-key'; enabled = $false }
                }
                rateLimit = @{
                    requestsPerMinute = 60
                    burstLimit = 10
                }
            }
        }
    }
    Mock ConvertTo-Json { return '{}' }
    
    # Mock environment variables
    Mock Get-ChildItem { 
        return @(
            @{ Name = 'CLAUDE_API_KEY'; Value = 'env-claude-key' }
            @{ Name = 'GEMINI_API_KEY'; Value = 'env-gemini-key' }
        )
    } -ParameterFilter { $Path -eq 'Env:' }
    
    # Initialize mock calls tracking
    $script:MockCalls = @{
        'Initialize-ClaudeIntegration' = @()
        'Initialize-AIOrchestrator' = @()
        'Set-AIRateLimit' = @()
    }
}

Describe "0730_Setup-AIAgents" {
    BeforeEach {
        $script:MockCalls = @{
            'Initialize-ClaudeIntegration' = @()
            'Initialize-AIOrchestrator' = @()
            'Set-AIRateLimit' = @()
        }
    }
    
    Context "Parameter Validation" {
        It "Should validate Provider parameter values" {
            $validProviders = @('Claude', 'Gemini', 'Codex', 'All')
            foreach ($provider in $validProviders) {
                { & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider $provider -WhatIf } | Should -Not -Throw
            }
        }
        
        It "Should accept ValidateOnly switch" {
            { & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -ValidateOnly -WhatIf } | Should -Not -Throw
        }
        
        It "Should accept custom ConfigPath" {
            { & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -ConfigPath "custom/config.json" -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Configuration File Handling" {
        It "Should read existing configuration file" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            Should -Invoke Test-Path -ParameterFilter { $Path -like "*config.json*" }
            Should -Invoke Get-Content -ParameterFilter { $Path -like "*config.json*" }
        }
        
        It "Should create configuration file if it doesn't exist" {
            Mock Test-Path { return $false }
            
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            Should -Invoke Set-Content -ParameterFilter { $Path -like "*config.json*" }
        }
        
        It "Should update configuration with new settings" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            Should -Invoke ConvertTo-Json
            Should -Invoke Set-Content -ParameterFilter { $Path -like "*config.json*" }
        }
    }
    
    Context "API Key Management" {
        It "Should detect API keys from environment variables" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            Should -Invoke Get-ChildItem -ParameterFilter { $Path -eq 'Env:' }
        }
        
        It "Should prompt for missing API keys" {
            Mock Get-ChildItem { return @() } -ParameterFilter { $Path -eq 'Env:' }
            Mock ConvertFrom-Json { return @{ ai = @{ providers = @{} } } }
            
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*API key*" }
        }
        
        It "Should use existing API keys from configuration" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            # Should not prompt for key if it exists in config
            Should -Not -Invoke Read-Host
        }
    }
    
    Context "Provider Initialization" {
        It "Should initialize Claude provider when specified" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            $script:MockCalls['Initialize-ClaudeIntegration'] | Should -HaveCount 1
            $initCall = $script:MockCalls['Initialize-ClaudeIntegration'] | Select-Object -First 1
            $initCall.ApiKey | Should -Not -BeNullOrEmpty
        }
        
        It "Should initialize all providers when Provider is 'All'" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "All" -WhatIf
            
            $script:MockCalls['Initialize-ClaudeIntegration'] | Should -HaveCount 1
            # Would also initialize Gemini and Codex if those modules were mocked
        }
        
        It "Should run in validation mode when ValidateOnly is specified" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -ValidateOnly -WhatIf
            
            $initCall = $script:MockCalls['Initialize-ClaudeIntegration'] | Select-Object -First 1
            $initCall.ValidationOnly | Should -Be $true
        }
    }
    
    Context "Rate Limiting Configuration" {
        It "Should configure rate limits for providers" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            $script:MockCalls['Set-AIRateLimit'] | Should -HaveCount 1
            $rateLimitCall = $script:MockCalls['Set-AIRateLimit'] | Select-Object -First 1
            $rateLimitCall.Provider | Should -Be "Claude"
            $rateLimitCall.RequestsPerMinute | Should -BeGreaterThan 0
        }
        
        It "Should use default rate limits from configuration" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            $rateLimitCall = $script:MockCalls['Set-AIRateLimit'] | Select-Object -First 1
            $rateLimitCall.RequestsPerMinute | Should -Be 60  # From mock config
        }
    }
    
    Context "Orchestrator Initialization" {
        It "Should initialize AI orchestrator with active providers" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            $script:MockCalls['Initialize-AIOrchestrator'] | Should -HaveCount 1
            $orchestratorCall = $script:MockCalls['Initialize-AIOrchestrator'] | Select-Object -First 1
            $orchestratorCall.Providers | Should -Contain 'Claude'
        }
        
        It "Should initialize orchestrator with multiple providers for 'All'" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "All" -WhatIf
            
            $orchestratorCall = $script:MockCalls['Initialize-AIOrchestrator'] | Select-Object -First 1
            $orchestratorCall.Providers.Count | Should -BeGreaterThan 1
        }
    }
    
    Context "Connectivity Validation" {
        It "Should test connection to AI providers" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            # Should call Test-ClaudeConnection or equivalent
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*connection*" }
        }
        
        It "Should report connection success" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*successfully*" }
        }
    }
    
    Context "ValidateOnly Mode" {
        It "Should only validate configuration without making changes" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -ValidateOnly -WhatIf
            
            # Should not write configuration file in validate-only mode
            Should -Not -Invoke Set-Content -ParameterFilter { $Path -like "*config.json*" }
        }
        
        It "Should report validation results" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -ValidateOnly -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Validation*" }
        }
    }
    
    Context "Error Handling" {
        It "Should handle missing configuration file gracefully" {
            Mock Test-Path { return $false }
            Mock Get-Content { throw "File not found" }
            
            { & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle provider initialization failures" {
            New-Module -Name 'MockClaudeCodeIntegrationError' -ScriptBlock {
                function Initialize-ClaudeIntegration { throw "API Error" }
                function Test-ClaudeConnection { throw "Connection failed" }
                Export-ModuleMember -Function *
            } | Import-Module -Force
            
            { & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Error
        }
        
        It "Should handle invalid JSON configuration" {
            Mock ConvertFrom-Json { throw "Invalid JSON" }
            
            { & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Module Import Handling" {
        It "Should handle missing AI modules gracefully" {
            Mock Import-Module { throw "Module not found" }
            
            { & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*module*" }
        }
    }
    
    Context "WhatIf Support" {
        It "Should show AI setup operations without executing them when WhatIf is used" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            # Should still call mock functions for validation
            $script:MockCalls['Initialize-ClaudeIntegration'] | Should -HaveCount 1
        }
    }
    
    Context "Success Reporting" {
        It "Should report successful setup" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*setup complete*" }
        }
        
        It "Should provide next steps guidance" {
            & "/workspaces/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1" -Provider "Claude" -WhatIf
            
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Next steps*" }
        }
    }
}
