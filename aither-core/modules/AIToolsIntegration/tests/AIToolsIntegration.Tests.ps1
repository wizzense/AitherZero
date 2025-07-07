#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Comprehensive test suite for AIToolsIntegration module
.DESCRIPTION
    Tests installation, configuration, and management of AI development tools
    including Claude Code, Gemini CLI, and other AI assistants
#>

BeforeAll {
    # Import module
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/AIToolsIntegration.psd1" -Force
    
    # Set up test environment
    $script:TestDrive = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) "AIToolsTest_$(Get-Random)")
    $script:OriginalPath = $env:PATH
    
    # Mock functions for external dependencies
    Mock Write-CustomLog { } -ModuleName AIToolsIntegration
    
    # Store original functions for cleanup
    $script:OriginalGetCommand = Get-Command Get-Command
}

AfterAll {
    # Restore environment
    $env:PATH = $script:OriginalPath
    if (Test-Path $script:TestDrive) {
        Remove-Item $script:TestDrive -Recurse -Force
    }
}

Describe "AIToolsIntegration Module Tests" {
    Context "Module Loading and Structure" {
        It "Should import module successfully" {
            Get-Module AIToolsIntegration | Should -Not -BeNullOrEmpty
        }
        
        It "Should export all expected functions" {
            $exportedFunctions = (Get-Module AIToolsIntegration).ExportedFunctions.Keys
            $expectedFunctions = @(
                'Install-ClaudeCode',
                'Install-GeminiCLI',
                'Install-CodexCLI',
                'Test-AIToolsInstallation',
                'Get-AIToolsStatus',
                'Configure-AITools',
                'Update-AITools',
                'Remove-AITools'
            )
            
            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }
    }
    
    Context "Install-ClaudeCode Function" {
        BeforeEach {
            Mock Test-NodeJsPrerequisites {
                return @{
                    Success = $true
                    NodeVersion = "18.0.0"
                    NPMVersion = "9.0.0"
                    Message = "Prerequisites met"
                }
            } -ModuleName AIToolsIntegration
            
            Mock Start-Process {
                return @{ ExitCode = 0 }
            } -ModuleName AIToolsIntegration
        }
        
        Context "Valid Installation Scenarios" {
            It "Should install Claude Code successfully with default parameters" {
                Mock Get-Command { } -ModuleName AIToolsIntegration
                
                $result = Install-ClaudeCode
                
                $result.Success | Should -Be $true
                $result.Message | Should -Match "successfully installed"
            }
            
            It "Should detect existing installation and skip if not forced" {
                Mock Get-Command {
                    return @{ Source = "C:\npm\claude-code.cmd" }
                } -ModuleName AIToolsIntegration -ParameterFilter { $Name -eq "claude-code" }
                
                Mock & { "1.0.0" } -CommandName "claude-code" -ModuleName AIToolsIntegration
                
                $result = Install-ClaudeCode
                
                $result.Success | Should -Be $true
                $result.AlreadyInstalled | Should -Be $true
            }
            
            It "Should force reinstall when -Force parameter is used" {
                Mock Get-Command {
                    return @{ Source = "C:\npm\claude-code.cmd" }
                } -ModuleName AIToolsIntegration
                
                $result = Install-ClaudeCode -Force
                
                Assert-MockCalled Start-Process -ModuleName AIToolsIntegration
                $result.Success | Should -Be $true
                $result.AlreadyInstalled | Should -Be $false
            }
            
            It "Should install specific version when requested" {
                Mock Get-Command { } -ModuleName AIToolsIntegration
                
                Install-ClaudeCode -Version "2.0.0"
                
                Assert-MockCalled Start-Process -ModuleName AIToolsIntegration -ParameterFilter {
                    $ArgumentList -contains "claude-code@2.0.0"
                }
            }
        }
        
        Context "Error Handling" {
            It "Should throw when Node.js prerequisites are not met" {
                Mock Test-NodeJsPrerequisites {
                    return @{
                        Success = $false
                        Message = "Node.js not found"
                        InstallHint = "Install Node.js from nodejs.org"
                    }
                } -ModuleName AIToolsIntegration
                
                { Install-ClaudeCode } | Should -Throw "Node.js prerequisites not met"
            }
            
            It "Should handle npm installation failures gracefully" {
                Mock Get-Command { } -ModuleName AIToolsIntegration
                Mock Start-Process {
                    return @{ ExitCode = 1 }
                } -ModuleName AIToolsIntegration
                
                $result = Install-ClaudeCode
                
                $result.Success | Should -Be $false
                $result.Message | Should -Match "Installation failed"
            }
            
            It "Should handle corrupted existing installation" {
                Mock Get-Command {
                    return @{ Source = "C:\npm\claude-code.cmd" }
                } -ModuleName AIToolsIntegration
                
                Mock & { throw "Command not found" } -CommandName "claude-code" -ModuleName AIToolsIntegration
                
                $result = Install-ClaudeCode
                
                Assert-MockCalled Start-Process -ModuleName AIToolsIntegration
            }
        }
        
        Context "Cross-Platform Compatibility" {
            It "Should use correct npm command on Windows" {
                Mock Get-Command { } -ModuleName AIToolsIntegration
                Mock Test-Path { $true } -ParameterFilter { $Path -eq "npm.cmd" }
                
                Install-ClaudeCode
                
                Assert-MockCalled Start-Process -ModuleName AIToolsIntegration -ParameterFilter {
                    $FilePath -eq "npm"
                }
            }
            
            It "Should use correct npm command on Linux/macOS" {
                Mock Get-Command { } -ModuleName AIToolsIntegration
                Mock Test-Path { $false } -ParameterFilter { $Path -eq "npm.cmd" }
                
                Install-ClaudeCode
                
                Assert-MockCalled Start-Process -ModuleName AIToolsIntegration -ParameterFilter {
                    $FilePath -eq "npm"
                }
            }
        }
    }
    
    Context "Get-AIToolsStatus Function" {
        It "Should return status for all supported tools" {
            Mock Get-Command { } -ModuleName AIToolsIntegration
            
            $status = Get-AIToolsStatus
            
            $status | Should -Not -BeNullOrEmpty
            $status.Keys | Should -Contain "claude-code"
            $status.Keys | Should -Contain "gemini"
            $status.Keys | Should -Contain "codex"
        }
        
        It "Should detect installed tools correctly" {
            Mock Get-Command {
                if ($Name -eq "claude-code") {
                    return @{ Source = "C:\npm\claude-code.cmd" }
                }
            } -ModuleName AIToolsIntegration
            
            Mock & { "1.0.0" } -CommandName "claude-code" -ModuleName AIToolsIntegration
            
            $status = Get-AIToolsStatus
            
            $status["claude-code"].Installed | Should -Be $true
            $status["claude-code"].Version | Should -Be "1.0.0"
            $status["gemini"].Installed | Should -Be $false
        }
    }
    
    Context "Configure-AITools Function" {
        BeforeEach {
            $script:ConfigPath = Join-Path $script:TestDrive "ai-tools-config.json"
        }
        
        It "Should create default configuration" {
            Mock Get-AIToolsConfigPath { $script:ConfigPath } -ModuleName AIToolsIntegration
            
            Configure-AITools
            
            Test-Path $script:ConfigPath | Should -Be $true
            $config = Get-Content $script:ConfigPath | ConvertFrom-Json
            $config | Should -Not -BeNullOrEmpty
        }
        
        It "Should update existing configuration" {
            Mock Get-AIToolsConfigPath { $script:ConfigPath } -ModuleName AIToolsIntegration
            
            # Create initial config
            @{ tools = @{ "claude-code" = @{ enabled = $false } } } | 
                ConvertTo-Json | Set-Content $script:ConfigPath
            
            Configure-AITools -Tool "claude-code" -Settings @{ enabled = $true }
            
            $config = Get-Content $script:ConfigPath | ConvertFrom-Json
            $config.tools."claude-code".enabled | Should -Be $true
        }
    }
    
    Context "Update-AITools Function" {
        It "Should update all installed tools" {
            Mock Get-AIToolsStatus {
                return @{
                    "claude-code" = @{ Installed = $true; Version = "1.0.0" }
                    "gemini" = @{ Installed = $true; Version = "2.0.0" }
                    "codex" = @{ Installed = $false }
                }
            } -ModuleName AIToolsIntegration
            
            Mock Start-Process { return @{ ExitCode = 0 } } -ModuleName AIToolsIntegration
            
            $result = Update-AITools
            
            $result.UpdatedTools | Should -Contain "claude-code"
            $result.UpdatedTools | Should -Contain "gemini"
            $result.UpdatedTools | Should -Not -Contain "codex"
        }
        
        It "Should update specific tool when requested" {
            Mock Get-AIToolsStatus {
                return @{
                    "claude-code" = @{ Installed = $true; Version = "1.0.0" }
                }
            } -ModuleName AIToolsIntegration
            
            Mock Start-Process { return @{ ExitCode = 0 } } -ModuleName AIToolsIntegration
            
            Update-AITools -Tools @("claude-code")
            
            Assert-MockCalled Start-Process -ModuleName AIToolsIntegration -Times 1
        }
    }
    
    Context "Remove-AITools Function" {
        It "Should remove specified tools" {
            Mock Get-Command {
                return @{ Source = "C:\npm\claude-code.cmd" }
            } -ModuleName AIToolsIntegration
            
            Mock Start-Process { return @{ ExitCode = 0 } } -ModuleName AIToolsIntegration
            
            $result = Remove-AITools -Tools @("claude-code")
            
            $result.Success | Should -Be $true
            $result.RemovedTools | Should -Contain "claude-code"
        }
        
        It "Should skip tools that are not installed" {
            Mock Get-Command { } -ModuleName AIToolsIntegration
            
            $result = Remove-AITools -Tools @("non-existent-tool")
            
            $result.Success | Should -Be $true
            $result.SkippedTools | Should -Contain "non-existent-tool"
        }
        
        It "Should prompt for confirmation unless -Force is used" {
            Mock Get-Command {
                return @{ Source = "C:\npm\claude-code.cmd" }
            } -ModuleName AIToolsIntegration
            
            Mock Read-Host { "N" } -ModuleName AIToolsIntegration
            
            $result = Remove-AITools -Tools @("claude-code")
            
            $result.Success | Should -Be $false
            $result.Message | Should -Match "cancelled"
        }
    }
    
    Context "Integration Tests" {
        It "Should complete full installation and configuration workflow" {
            Mock Test-NodeJsPrerequisites {
                return @{ Success = $true; NodeVersion = "18.0.0"; NPMVersion = "9.0.0" }
            } -ModuleName AIToolsIntegration
            
            Mock Get-Command { } -ModuleName AIToolsIntegration
            Mock Start-Process { return @{ ExitCode = 0 } } -ModuleName AIToolsIntegration
            
            # Install
            $installResult = Install-ClaudeCode
            $installResult.Success | Should -Be $true
            
            # Configure
            Configure-AITools -Tool "claude-code" -Settings @{ theme = "dark" }
            
            # Verify status
            Mock Get-Command {
                return @{ Source = "C:\npm\claude-code.cmd" }
            } -ModuleName AIToolsIntegration -ParameterFilter { $Name -eq "claude-code" }
            
            $status = Get-AIToolsStatus
            $status["claude-code"].Installed | Should -Be $true
        }
    }
    
    Context "Performance Tests" -Tag "Performance" {
        It "Should complete Get-AIToolsStatus within performance threshold" {
            Mock Get-Command { } -ModuleName AIToolsIntegration
            
            $elapsed = Measure-Command { Get-AIToolsStatus }
            
            $elapsed.TotalMilliseconds | Should -BeLessThan 1000
        }
        
        It "Should handle multiple tool operations efficiently" {
            Mock Get-Command { } -ModuleName AIToolsIntegration
            Mock Start-Process { return @{ ExitCode = 0 } } -ModuleName AIToolsIntegration
            
            $elapsed = Measure-Command {
                Get-AIToolsStatus
                Configure-AITools
                Test-AIToolsInstallation
            }
            
            $elapsed.TotalSeconds | Should -BeLessThan 5
        }
    }
}

# Run specific test examples
<#
# Run all tests
Invoke-Pester -Path $PSScriptRoot

# Run only unit tests
Invoke-Pester -Path $PSScriptRoot -ExcludeTag "Performance"

# Run with coverage
Invoke-Pester -Path $PSScriptRoot -CodeCoverage "$ModulePath/*.psm1"

# Run specific test
Invoke-Pester -Path $PSScriptRoot -TestName "Install-ClaudeCode*"
#>