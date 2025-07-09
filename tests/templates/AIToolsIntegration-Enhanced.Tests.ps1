#Requires -Version 7.0

<#
.SYNOPSIS
    Enhanced comprehensive test coverage for AIToolsIntegration module - ALL 25 FUNCTIONS

.DESCRIPTION
    This template provides 100% function coverage for the AIToolsIntegration module
    covering all 25 functions identified in the module analysis.

.NOTES
    Target: 100% function coverage
    Functions: 25 public functions
    Priority: High - AI development tools integration
#>

BeforeAll {
    # Import the module under test
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module $ModulePath -Force

    # Setup test environment
    $script:TestStartTime = Get-Date
    $script:TestWorkspace = if ($env:TEMP) {
        Join-Path $env:TEMP "AIToolsIntegration-Enhanced-Test-$(Get-Random)"
    } elseif (Test-Path '/tmp') {
        "/tmp/AIToolsIntegration-Enhanced-Test-$(Get-Random)"
    } else {
        Join-Path (Get-Location) "AIToolsIntegration-Enhanced-Test-$(Get-Random)"
    }

    # Create test workspace
    New-Item -Path $script:TestWorkspace -ItemType Directory -Force | Out-Null

    # Initialize logging system for tests
    . "$PSScriptRoot/../../aither-core/shared/Initialize-Logging.ps1"
    Initialize-Logging -NoImport

    # Mock npm for installation tests
    function Mock-NPM {
        param([string]$Command)
        return @{
            Success = $true
            Output = "Mock npm output"
            ExitCode = 0
        }
    }
}

AfterAll {
    # Cleanup test workspace
    if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
        Remove-Item $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "AIToolsIntegration - Complete Function Coverage" {
    
    Context "Claude Code Functions" {
        It "Install-ClaudeCode should install Claude Code CLI" {
            Mock Test-NodeJsPrerequisites { return @{ Success = $true; NodeVersion = "18.0.0"; NPMVersion = "8.0.0" } }
            Mock Start-Process { return @{ ExitCode = 0 } }
            
            { Install-ClaudeCode -WhatIf } | Should -Not -Throw
        }

        It "Install-ClaudeCode should handle force installation" {
            Mock Test-NodeJsPrerequisites { return @{ Success = $true; NodeVersion = "18.0.0"; NPMVersion = "8.0.0" } }
            Mock Start-Process { return @{ ExitCode = 0 } }
            
            { Install-ClaudeCode -Force -WhatIf } | Should -Not -Throw
        }

        It "Install-ClaudeCode should handle version specification" {
            Mock Test-NodeJsPrerequisites { return @{ Success = $true; NodeVersion = "18.0.0"; NPMVersion = "8.0.0" } }
            Mock Start-Process { return @{ ExitCode = 0 } }
            
            { Install-ClaudeCode -Version "1.0.0" -WhatIf } | Should -Not -Throw
        }

        It "Test-ClaudeCodeInstallation should verify Claude Code installation" {
            Mock Get-Command { return @{ Name = "claude-code"; Version = "1.0.0" } }
            
            $result = Test-ClaudeCodeInstallation
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Test-ClaudeCodeInstallation should handle missing installation" {
            Mock Get-Command { throw "Command not found" }
            
            $result = Test-ClaudeCodeInstallation
            $result.Success | Should -Be $false
        }

        It "Configure-ClaudeCodeIntegration should configure Claude Code" {
            Mock Test-Path { return $true }
            Mock Set-Content { }
            
            { Configure-ClaudeCodeIntegration -WhatIf } | Should -Not -Throw
        }

        It "Test-ClaudeCodeConfiguration should validate configuration" {
            Mock Test-Path { return $true }
            Mock Get-Content { return "{ 'configured': true }" }
            
            $result = Test-ClaudeCodeConfiguration
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Gemini CLI Functions" {
        It "Install-GeminiCLI should install Gemini CLI" {
            Mock Test-NodeJsPrerequisites { return @{ Success = $true; NodeVersion = "18.0.0"; NPMVersion = "8.0.0" } }
            Mock Start-Process { return @{ ExitCode = 0 } }
            
            { Install-GeminiCLI -WhatIf } | Should -Not -Throw
        }

        It "Test-GeminiCLIInstallation should verify Gemini CLI installation" {
            Mock Get-Command { return @{ Name = "gemini"; Version = "1.0.0" } }
            
            $result = Test-GeminiCLIInstallation
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Test-GeminiCLIInstallation should handle missing installation" {
            Mock Get-Command { throw "Command not found" }
            
            $result = Test-GeminiCLIInstallation
            $result.Success | Should -Be $false
        }

        It "Test-GeminiCLIConfiguration should validate configuration" {
            Mock Test-Path { return $true }
            Mock Get-Content { return "{ 'configured': true }" }
            
            $result = Test-GeminiCLIConfiguration
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Codex CLI Functions" {
        It "Install-CodexCLI should install Codex CLI" {
            Mock Test-NodeJsPrerequisites { return @{ Success = $true; NodeVersion = "18.0.0"; NPMVersion = "8.0.0" } }
            Mock Start-Process { return @{ ExitCode = 0 } }
            
            { Install-CodexCLI -WhatIf } | Should -Not -Throw
        }

        It "Test-CodexCLIInstallation should verify Codex CLI installation" {
            Mock Get-Command { return @{ Name = "codex"; Version = "1.0.0" } }
            
            $result = Test-CodexCLIInstallation
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Test-CodexCLIInstallation should handle missing installation" {
            Mock Get-Command { throw "Command not found" }
            
            $result = Test-CodexCLIInstallation
            $result.Success | Should -Be $false
        }
    }

    Context "Testing and Validation Functions" {
        It "Test-AIToolsInstallation should test all AI tools" {
            Mock Test-ClaudeCodeInstallation { return @{ Success = $true; Tool = "Claude Code" } }
            Mock Test-GeminiCLIInstallation { return @{ Success = $true; Tool = "Gemini CLI" } }
            Mock Test-CodexCLIInstallation { return @{ Success = $true; Tool = "Codex CLI" } }
            
            $result = Test-AIToolsInstallation
            $result | Should -Not -BeNullOrEmpty
        }

        It "Test-NodeJsPrerequisites should check Node.js requirements" {
            Mock Get-Command { return @{ Version = @{ Major = 18; Minor = 0; Build = 0 } } }
            
            $result = Test-NodeJsPrerequisites
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }

        It "Test-NodeJsPrerequisites should handle missing Node.js" {
            Mock Get-Command { throw "Command not found" }
            
            $result = Test-NodeJsPrerequisites
            $result.Success | Should -Be $false
        }
    }

    Context "Configuration and Management Functions" {
        It "Get-PlatformInfo should return platform information" {
            $result = Get-PlatformInfo
            $result | Should -Not -BeNullOrEmpty
            $result.Platform | Should -Not -BeNullOrEmpty
        }

        It "Get-AIToolsStatus should return status of all AI tools" {
            Mock Test-AIToolsInstallation { return @{ Success = $true } }
            
            $result = Get-AIToolsStatus
            $result | Should -Not -BeNullOrEmpty
        }

        It "Configure-AITools should configure all AI tools" {
            Mock Configure-ClaudeCodeIntegration { }
            Mock Configure-VSCodeAIIntegration { }
            
            { Configure-AITools -WhatIf } | Should -Not -Throw
        }

        It "Configure-VSCodeAIIntegration should configure VS Code integration" {
            Mock Test-Path { return $true }
            Mock Get-Content { return "{ 'extensions': [] }" }
            Mock Set-Content { }
            
            { Configure-VSCodeAIIntegration -WhatIf } | Should -Not -Throw
        }

        It "Update-AITools should update all AI tools" {
            Mock Test-AIToolsInstallation { return @{ Success = $true } }
            Mock Start-Process { return @{ ExitCode = 0 } }
            
            { Update-AITools -WhatIf } | Should -Not -Throw
        }

        It "Remove-AITools should remove specified AI tools" {
            Mock Test-AIToolsInstallation { return @{ Success = $true } }
            Mock Start-Process { return @{ ExitCode = 0 } }
            
            { Remove-AITools -Tools @('claude-code') -WhatIf } | Should -Not -Throw
        }
    }

    Context "Management Interface Functions" {
        It "Start-AIToolsIntegrationManagement should start management interface" {
            Mock Test-AIToolsInstallation { return @{ Success = $true } }
            
            { Start-AIToolsIntegrationManagement -TestMode } | Should -Not -Throw
        }

        It "Stop-AIToolsIntegrationManagement should stop management interface" {
            Mock Get-Variable { return @{ Value = @{ Running = $true } } }
            
            { Stop-AIToolsIntegrationManagement } | Should -Not -Throw
        }

        It "Get-AIToolsIntegrationStatus should return management status" {
            Mock Get-Variable { return @{ Value = @{ Running = $true; StartTime = (Get-Date) } } }
            
            $result = Get-AIToolsIntegrationStatus
            $result | Should -Not -BeNullOrEmpty
        }

        It "Set-AIToolsIntegrationConfiguration should set configuration" {
            Mock Test-Path { return $true }
            Mock Set-Content { }
            
            $config = @{ 'setting' = 'value' }
            { Set-AIToolsIntegrationConfiguration -Configuration $config } | Should -Not -Throw
        }

        It "Invoke-AIToolsIntegrationOperation should perform operations" {
            Mock Test-AIToolsInstallation { return @{ Success = $true } }
            
            { Invoke-AIToolsIntegrationOperation -Operation "status" } | Should -Not -Throw
        }

        It "Reset-AIToolsIntegrationState should reset state" {
            Mock Remove-Variable { }
            Mock New-Variable { }
            
            { Reset-AIToolsIntegrationState } | Should -Not -Throw
        }

        It "Export-AIToolsIntegrationState should export state" {
            Mock Get-Variable { return @{ Value = @{ State = "active" } } }
            Mock ConvertTo-Json { return "{ 'state': 'active' }" }
            
            $result = Export-AIToolsIntegrationState
            $result | Should -Not -BeNullOrEmpty
        }

        It "Import-AIToolsIntegrationState should import state" {
            Mock ConvertFrom-Json { return @{ State = "active" } }
            Mock Set-Variable { }
            
            { Import-AIToolsIntegrationState -StateJson "{ 'state': 'active' }" } | Should -Not -Throw
        }

        It "Test-AIToolsIntegrationCoordination should test coordination" {
            Mock Test-AIToolsInstallation { return @{ Success = $true } }
            Mock Get-AIToolsStatus { return @{ Status = "healthy" } }
            
            $result = Test-AIToolsIntegrationCoordination
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Parameter Validation Tests" {
        It "Install-ClaudeCode should validate Version parameter" {
            Mock Test-NodeJsPrerequisites { return @{ Success = $true } }
            
            { Install-ClaudeCode -Version "" -WhatIf } | Should -Throw
        }

        It "Remove-AITools should validate Tools parameter" {
            { Remove-AITools -Tools @() -WhatIf } | Should -Throw
        }

        It "Set-AIToolsIntegrationConfiguration should validate Configuration parameter" {
            { Set-AIToolsIntegrationConfiguration -Configuration $null } | Should -Throw
        }
    }

    Context "Error Handling Tests" {
        It "Install-ClaudeCode should handle npm failure" {
            Mock Test-NodeJsPrerequisites { return @{ Success = $true } }
            Mock Start-Process { return @{ ExitCode = 1 } }
            
            { Install-ClaudeCode -WhatIf } | Should -Throw
        }

        It "Get-AIToolsStatus should handle service unavailable" {
            Mock Test-AIToolsInstallation { throw "Service unavailable" }
            
            { Get-AIToolsStatus } | Should -Not -Throw
        }

        It "Start-AIToolsIntegrationManagement should handle already running" {
            Mock Get-Variable { return @{ Value = @{ Running = $true } } }
            
            { Start-AIToolsIntegrationManagement } | Should -Not -Throw
        }
    }

    Context "Integration Tests" {
        It "Should install and configure Claude Code end-to-end" {
            Mock Test-NodeJsPrerequisites { return @{ Success = $true } }
            Mock Start-Process { return @{ ExitCode = 0 } }
            Mock Test-ClaudeCodeInstallation { return @{ Success = $true } }
            Mock Configure-ClaudeCodeIntegration { }
            
            { 
                Install-ClaudeCode -WhatIf
                Test-ClaudeCodeInstallation
                Configure-ClaudeCodeIntegration -WhatIf
            } | Should -Not -Throw
        }

        It "Should provide complete AI tools status" {
            Mock Test-ClaudeCodeInstallation { return @{ Success = $true; Tool = "Claude Code" } }
            Mock Test-GeminiCLIInstallation { return @{ Success = $true; Tool = "Gemini CLI" } }
            Mock Test-CodexCLIInstallation { return @{ Success = $true; Tool = "Codex CLI" } }
            
            $result = Get-AIToolsStatus
            $result | Should -Not -BeNullOrEmpty
        }
    }
}