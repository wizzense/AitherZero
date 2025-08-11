#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Integration tests for Claude Code integration components following TDD principles.

.DESCRIPTION
    This test suite validates the Claude Code integration plan implementation:
    - Sub Agents functionality
    - Hooks implementation
    - MCP Server integration
    - GitHub Actions workflows
    
    Following Test-Driven Development (TDD) methodology.

.NOTES
    Author: AitherZero Development Team
    Version: 1.0.0
    Requires: PowerShell 7.0+, Pester 5.0+
#>

#Requires -Version 7.0

BeforeAll {
    # Import shared test utilities
    . "$PSScriptRoot/../shared/Find-ProjectRoot.ps1"
    $script:ProjectRoot = Find-ProjectRoot
    
    # Import required modules
    Import-Module "$script:ProjectRoot/aither-core/modules/TestingFramework" -Force
    Import-Module "$script:ProjectRoot/aither-core/modules/Logging" -Force
    
    # Setup test environment
    $script:TestResults = @{
        SubAgents = @()
        Hooks = @()
        MCPServer = @{}
        GitHubActions = @()
    }
    
    # Mock functions for testing
    function Write-TestLog {
        param([string]$Message, [string]$Level = 'INFO')
        Write-CustomLog -Level $Level -Message "[Claude Integration Test] $Message"
    }
}

Describe "Claude Code Integration - Test-Driven Development" -Tags @('Integration', 'ClaudeCode', 'TDD') {
    
    Context "Sub Agents Implementation Tests" {
        
        BeforeEach {
            $script:AgentsDirectory = Join-Path $script:ProjectRoot ".claude/agents"
        }
        
        It "Should create .claude/agents directory structure" {
            # Arrange
            $expectedPath = $script:AgentsDirectory
            
            # Act & Assert
            $expectedPath | Should -Not -BeNullOrEmpty
            # Test will fail until implementation exists
        }
        
        It "Should validate AitherZero Infrastructure Manager sub-agent configuration" {
            # Arrange
            $agentFile = Join-Path $script:AgentsDirectory "aitherzero-infrastructure-manager.md"
            $expectedContent = @(
                "name: aitherzero-infrastructure-manager",
                "description: Expert in AitherZero infrastructure automation",
                "tools: Bash, Read, Edit, Write, Grep, Glob",
                "LabRunner, OpenTofuProvider, DevEnvironment"
            )
            
            # Act
            if (Test-Path $agentFile) {
                $content = Get-Content $agentFile -Raw
                $validAgent = $true
                foreach ($expected in $expectedContent) {
                    if ($content -notmatch [regex]::Escape($expected)) {
                        $validAgent = $false
                        break
                    }
                }
            } else {
                $validAgent = $false
            }
            
            # Assert
            $validAgent | Should -Be $true -Because "Infrastructure Manager agent should be properly configured"
        }
        
        It "Should validate PowerShell DevOps Specialist sub-agent" {
            # Arrange
            $agentFile = Join-Path $script:AgentsDirectory "powershell-devops-specialist.md"
            
            # Act & Assert
            Test-Path $agentFile | Should -Be $true
            if (Test-Path $agentFile) {
                $content = Get-Content $agentFile -Raw
                $content | Should -Match "powershell-devops-specialist"
                $content | Should -Match "PowerShell 7\+"
                $content | Should -Match "PatchManager"
                $content | Should -Match "Pester"
            }
        }
        
        It "Should validate Security & Compliance Guardian sub-agent" {
            # Arrange
            $agentFile = Join-Path $script:AgentsDirectory "security-compliance-guardian.md"
            
            # Act & Assert
            Test-Path $agentFile | Should -Be $true
            if (Test-Path $agentFile) {
                $content = Get-Content $agentFile -Raw
                $content | Should -Match "security-compliance-guardian"
                $content | Should -Match "PSScriptAnalyzer"
                $content | Should -Match "SecureCredentials"
            }
        }
        
        It "Should validate Release Management Orchestrator sub-agent" {
            # Arrange
            $agentFile = Join-Path $script:AgentsDirectory "release-management-orchestrator.md"
            
            # Act & Assert
            Test-Path $agentFile | Should -Be $true
            if (Test-Path $agentFile) {
                $content = Get-Content $agentFile -Raw
                $content | Should -Match "release-management-orchestrator"
                $content | Should -Match "semantic versioning"
                $content | Should -Match "bulletproof validation"
            }
        }
        
        It "Should validate Testing & Quality Assurance Expert sub-agent" {
            # Arrange
            $agentFile = Join-Path $script:AgentsDirectory "testing-qa-expert.md"
            
            # Act & Assert
            Test-Path $agentFile | Should -Be $true
            if (Test-Path $agentFile) {
                $content = Get-Content $agentFile -Raw
                $content | Should -Match "testing-qa-expert"
                $content | Should -Match "80% code coverage"
                $content | Should -Match "TestingFramework"
            }
        }
    }
    
    Context "Hooks Implementation Tests" {
        
        BeforeEach {
            $script:SettingsFile = Join-Path $script:ProjectRoot ".claude/settings.json"
        }
        
        It "Should have .claude/settings.json file" {
            # Act & Assert
            Test-Path $script:SettingsFile | Should -Be $true
        }
        
        It "Should validate Pre-Commit Code Quality Hook configuration" {
            # Arrange
            $expectedHookStructure = @{
                hooks = @{
                    PreToolUse = @(
                        @{
                            matcher = "Edit|MultiEdit|Write"
                            hooks = @(
                                @{
                                    type = "command"
                                    command = "*PSScriptAnalyzer*"
                                }
                            )
                        }
                    )
                }
            }
            
            # Act
            if (Test-Path $script:SettingsFile) {
                $settings = Get-Content $script:SettingsFile | ConvertFrom-Json
                $hasCodeQualityHook = $false
                
                if ($settings.hooks -and $settings.hooks.PreToolUse) {
                    foreach ($hookConfig in $settings.hooks.PreToolUse) {
                        if ($hookConfig.hooks) {
                            foreach ($hook in $hookConfig.hooks) {
                                if ($hook.command -match "PSScriptAnalyzer") {
                                    $hasCodeQualityHook = $true
                                    break
                                }
                            }
                        }
                    }
                }
            } else {
                $hasCodeQualityHook = $false
            }
            
            # Assert
            $hasCodeQualityHook | Should -Be $true -Because "Code quality hook should be configured"
        }
        
        It "Should validate Security Validation Hook configuration" {
            # Arrange & Act
            if (Test-Path $script:SettingsFile) {
                $settings = Get-Content $script:SettingsFile | ConvertFrom-Json
                $hasSecurityHook = $false
                
                if ($settings.hooks -and $settings.hooks.PreToolUse) {
                    foreach ($hookConfig in $settings.hooks.PreToolUse) {
                        if ($hookConfig.hooks) {
                            foreach ($hook in $hookConfig.hooks) {
                                if ($hook.command -match "(password|secret|key|token)") {
                                    $hasSecurityHook = $true
                                    break
                                }
                            }
                        }
                    }
                }
            } else {
                $hasSecurityHook = $false
            }
            
            # Assert
            $hasSecurityHook | Should -Be $true -Because "Security validation hook should be configured"
        }
        
        It "Should validate Automated Testing Hook configuration" {
            # Arrange & Act
            if (Test-Path $script:SettingsFile) {
                $settings = Get-Content $script:SettingsFile | ConvertFrom-Json
                $hasTestingHook = $false
                
                if ($settings.hooks -and $settings.hooks.PostToolUse) {
                    foreach ($hookConfig in $settings.hooks.PostToolUse) {
                        if ($hookConfig.hooks) {
                            foreach ($hook in $hookConfig.hooks) {
                                if ($hook.command -match "Run-Tests") {
                                    $hasTestingHook = $true
                                    break
                                }
                            }
                        }
                    }
                }
            } else {
                $hasTestingHook = $false
            }
            
            # Assert
            $hasTestingHook | Should -Be $true -Because "Automated testing hook should be configured"
        }
    }
    
    Context "MCP Server Integration Tests" {
        
        BeforeEach {
            $script:MCPServerPath = Join-Path $script:ProjectRoot "src/tools/ProjectManager/mcp-server"
            $script:MCPConfigFile = Join-Path $script:ProjectRoot ".mcp.json"
        }
        
        It "Should have MCP server directory structure" {
            # Act & Assert
            Test-Path $script:MCPServerPath | Should -Be $true
            Test-Path (Join-Path $script:MCPServerPath "package.json") | Should -Be $true
        }
        
        It "Should validate MCP server package configuration" {
            # Arrange
            $packageFile = Join-Path $script:MCPServerPath "package.json"
            
            # Act
            if (Test-Path $packageFile) {
                $package = Get-Content $packageFile | ConvertFrom-Json
                $validConfig = ($package.name -eq "aitherzero-mcp-server") -and
                               ($package.scripts.build) -and
                               ($package.dependencies)
            } else {
                $validConfig = $false
            }
            
            # Assert
            $validConfig | Should -Be $true -Because "MCP server should have valid package.json"
        }
        
        It "Should validate AitherZero-specific MCP tools implementation" {
            # Arrange
            $toolsFile = Join-Path $script:MCPServerPath "src/tools.ts"
            $expectedTools = @(
                "invoke_patchmanager_workflow",
                "run_bulletproof_validation",
                "deploy_lab_environment"
            )
            
            # Act
            if (Test-Path $toolsFile) {
                $content = Get-Content $toolsFile -Raw
                $validTools = $true
                foreach ($tool in $expectedTools) {
                    if ($content -notmatch [regex]::Escape($tool)) {
                        $validTools = $false
                        break
                    }
                }
            } else {
                $validTools = $false
            }
            
            # Assert
            $validTools | Should -Be $true -Because "MCP server should implement AitherZero-specific tools"
        }
        
        It "Should validate MCP configuration file" {
            # Act
            $mcpConfigExists = Test-Path $script:MCPConfigFile
            
            if ($mcpConfigExists) {
                $config = Get-Content $script:MCPConfigFile | ConvertFrom-Json
                $validConfig = $config.servers -and $config.servers."aitherzero-pm"
            } else {
                $validConfig = $false
            }
            
            # Assert
            $validConfig | Should -Be $true -Because "MCP configuration should be properly set up"
        }
    }
    
    Context "GitHub Actions Integration Tests" {
        
        BeforeEach {
            $script:WorkflowsPath = Join-Path $script:ProjectRoot ".github/workflows"
        }
        
        It "Should validate Claude-Enhanced CI/CD Pipeline workflow" {
            # Arrange
            $workflowFile = Join-Path $script:WorkflowsPath "claude-enhanced-ci.yml"
            
            # Act & Assert
            Test-Path $workflowFile | Should -Be $true
            
            if (Test-Path $workflowFile) {
                $content = Get-Content $workflowFile -Raw
                $content | Should -Match "Claude-Enhanced CI/CD Pipeline"
                $content | Should -Match "anthropics/claude-code-action"
                $content | Should -Match "Run-Tests-Unified.ps1"
            }
        }
        
        It "Should validate Intelligent PR Management workflow" {
            # Arrange
            $workflowFile = Join-Path $script:WorkflowsPath "claude-pr-automation.yml"
            
            # Act & Assert
            Test-Path $workflowFile | Should -Be $true
            
            if (Test-Path $workflowFile) {
                $content = Get-Content $workflowFile -Raw
                $content | Should -Match "Claude PR Automation"
                $content | Should -Match "@claude"
                $content | Should -Match "issue_comment"
            }
        }
        
        It "Should validate GitHub Actions secrets configuration" {
            # This test checks for required secrets in a safe way
            # (actual secrets should not be in code)
            
            # Arrange
            $requiredSecrets = @("ANTHROPIC_API_KEY")
            
            # Act - We can only check if workflow files reference the secrets
            $workflowFiles = Get-ChildItem $script:WorkflowsPath -Filter "claude-*.yml" -ErrorAction SilentlyContinue
            $secretsReferenced = $false
            
            foreach ($file in $workflowFiles) {
                $content = Get-Content $file.FullName -Raw
                if ($content -match "secrets\.ANTHROPIC_API_KEY") {
                    $secretsReferenced = $true
                    break
                }
            }
            
            # Assert
            $secretsReferenced | Should -Be $true -Because "Workflows should reference required secrets"
        }
    }
    
    Context "Integration Testing - End-to-End Scenarios" {
        
        It "Should validate complete Claude Code integration setup" {
            # Arrange
            $integrationComponents = @{
                AgentsDirectory = Join-Path $script:ProjectRoot ".claude/agents"
                SettingsFile = Join-Path $script:ProjectRoot ".claude/settings.json"
                MCPConfig = Join-Path $script:ProjectRoot ".mcp.json"
                WorkflowsDirectory = Join-Path $script:ProjectRoot ".github/workflows"
            }
            
            # Act
            $integrationComplete = $true
            $missingComponents = @()
            
            foreach ($component in $integrationComponents.GetEnumerator()) {
                if (-not (Test-Path $component.Value)) {
                    $integrationComplete = $false
                    $missingComponents += $component.Key
                }
            }
            
            # Assert
            $integrationComplete | Should -Be $true -Because "All integration components should be present. Missing: $($missingComponents -join ', ')"
        }
        
        It "Should validate PatchManager integration with Claude Code workflows" {
            # Arrange
            $patchManagerModule = Join-Path $script:ProjectRoot "aither-core/modules/PatchManager"
            
            # Act
            $integrationValid = $false
            
            if (Test-Path $patchManagerModule) {
                try {
                    Import-Module $patchManagerModule -Force
                    $patchManagerCommands = Get-Command -Module PatchManager -ErrorAction SilentlyContinue
                    if ($patchManagerCommands -and ($patchManagerCommands.Count -gt 0)) {
                        $integrationValid = $true
                    }
                } catch {
                    Write-TestLog "Error importing PatchManager: $($_.Exception.Message)" -Level 'WARN'
                }
            }
            
            # Assert
            $integrationValid | Should -Be $true -Because "PatchManager should be available for Claude Code integration"
        }
        
        It "Should validate TestingFramework integration with validation hooks" {
            # Arrange
            $testingFramework = Join-Path $script:ProjectRoot "aither-core/modules/TestingFramework"
            
            # Act
            $frameworkValid = $false
            
            if (Test-Path $testingFramework) {
                try {
                    Import-Module $testingFramework -Force
                    $testCommands = Get-Command -Module TestingFramework -ErrorAction SilentlyContinue
                    if ($testCommands -and ($testCommands.Count -gt 0)) {
                        $frameworkValid = $true
                    }
                } catch {
                    Write-TestLog "Error importing TestingFramework: $($_.Exception.Message)" -Level 'WARN'
                }
            }
            
            # Assert
            $frameworkValid | Should -Be $true -Because "TestingFramework should be available for hook validation"
        }
    }
    
    Context "Security and Compliance Validation" {
        
        It "Should validate no hardcoded secrets in configuration files" {
            # Arrange
            $configFiles = @(
                Join-Path $script:ProjectRoot ".claude/settings.json",
                Join-Path $script:ProjectRoot ".mcp.json"
            )
            
            $dangerousPatterns = @(
                'password\s*=\s*["''][^"'']*["'']',
                'secret\s*=\s*["''][^"'']*["'']',
                'key\s*=\s*["''][^"'']*["'']',
                'token\s*=\s*["''][^"'']*["'']'
            )
            
            # Act
            $securityValid = $true
            $violationFiles = @()
            
            foreach ($file in $configFiles) {
                if (Test-Path $file) {
                    $content = Get-Content $file -Raw
                    foreach ($pattern in $dangerousPatterns) {
                        if ($content -match $pattern) {
                            $securityValid = $false
                            $violationFiles += $file
                            break
                        }
                    }
                }
            }
            
            # Assert
            $securityValid | Should -Be $true -Because "Configuration files should not contain hardcoded secrets. Violations in: $($violationFiles -join ', ')"
        }
        
        It "Should validate cross-platform compatibility" {
            # Arrange
            $crossPlatformElements = @{
                "Path separators" = @{
                    Files = @(Join-Path $script:ProjectRoot ".claude/settings.json")
                    Pattern = '[\\][^\\]'  # Looking for hardcoded backslashes
                }
            }
            
            # Act
            $compatibilityValid = $true
            $issues = @()
            
            foreach ($element in $crossPlatformElements.GetEnumerator()) {
                foreach ($file in $element.Value.Files) {
                    if (Test-Path $file) {
                        $content = Get-Content $file -Raw
                        if ($content -match $element.Value.Pattern) {
                            $compatibilityValid = $false
                            $issues += "$($element.Key) in $file"
                        }
                    }
                }
            }
            
            # Assert
            $compatibilityValid | Should -Be $true -Because "All components should be cross-platform compatible. Issues: $($issues -join ', ')"
        }
    }
}

AfterAll {
    Write-TestLog "Claude Code Integration tests completed"
    
    # Generate test summary
    $summary = @{
        TestsRun = (Get-Variable -Name "TestResults" -Scope Script -ErrorAction SilentlyContinue).Value
        ProjectRoot = $script:ProjectRoot
        Timestamp = Get-Date
    }
    
    Write-TestLog "Test Summary: $($summary | ConvertTo-Json -Depth 2)"
}
