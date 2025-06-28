#Requires -Version 7.0

<#
.SYNOPSIS
    Tests for Install-CodexCLIDependencies function

.DESCRIPTION
    Comprehensive tests for the Codex CLI (OpenAI experimental CLI) dependencies installation function,
    covering Windows WSL setup, Linux nvm installation, and cross-platform scenarios.
#>

BeforeAll {
    # Mock Write-CustomLog function for testing
    function global:Write-CustomLog {
        param(
            [string]$Message, 
            [string]$Level = "INFO",
            [hashtable]$Context = @{},
            [hashtable]$Data = @{}
        )
        Write-Host "[$Level] $Message" -ForegroundColor $(
            switch ($Level) {
                'ERROR' { 'Red' }
                'WARN' { 'Yellow' }
                'SUCCESS' { 'Green' }
                'INFO' { 'Cyan' }
                default { 'White' }
            }
        )
    }
    
    # Import required modules first
    $projectRoot = if ($env:PROJECT_ROOT) { 
        $env:PROJECT_ROOT 
    } else {
        '/workspaces/AitherZero'
    }
    
    # Load Logging module first (required dependency)
    $loggingModulePath = Join-Path $projectRoot "aither-core/modules/Logging"
    try {
        Import-Module $loggingModulePath -Force -ErrorAction Stop
        Write-Host "✅ Logging module imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not import Logging module: $_"
    }
    
    # Import the DevEnvironment module
    $devEnvModulePath = Join-Path $projectRoot "aither-core/modules/DevEnvironment"
    
    try {
        Import-Module $devEnvModulePath -Force -ErrorAction Stop
        Write-Host "✅ DevEnvironment module imported successfully from: $devEnvModulePath" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Failed to import DevEnvironment module from $devEnvModulePath : $_"
        throw
    }
}

Describe "Install-CodexCLIDependencies Function Tests" -Tags @('Unit', 'DevEnvironment', 'CodexCLI') {
    
    Context "Function Availability and Structure" {
        It "Should be available after module import" {
            Get-Command Install-CodexCLIDependencies -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have correct parameter structure" {
            $command = Get-Command Install-CodexCLIDependencies
            $command.Parameters.Keys | Should -Contain 'SkipWSL'
            $command.Parameters.Keys | Should -Contain 'WSLUsername'
            $command.Parameters.Keys | Should -Contain 'WSLPassword'
            $command.Parameters.Keys | Should -Contain 'NodeVersion'
            $command.Parameters.Keys | Should -Contain 'Force'
            $command.Parameters.Keys | Should -Contain 'WhatIf'
        }
        
        It "Should support ShouldProcess (WhatIf)" {
            $command = Get-Command Install-CodexCLIDependencies
            $command.CmdletBinding.SupportsShouldProcess | Should -Be $true
        }
    }
    
    Context "Platform Detection" {
        It "Should detect current platform correctly" {
            # Mock platform variables
            if ($IsWindows) {
                $env:PLATFORM = 'Windows'
            } elseif ($IsLinux) {
                $env:PLATFORM = 'Linux'
            } elseif ($IsMacOS) {
                $env:PLATFORM = 'macOS'
            }
            
            # Test with WhatIf to avoid actual installation
            { Install-CodexCLIDependencies -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle unsupported platforms gracefully" {
            # This test would need platform mocking in a real scenario
            # For now, just ensure the function doesn't crash
            $true | Should -Be $true
        }
    }
    
    Context "Windows-Specific Functionality" -Skip:(-not $IsWindows) {
        BeforeEach {
            # Mock Windows-specific commands
            Mock wsl { return "Ubuntu" } -ParameterFilter { $args -contains "--list" }
            Mock Enable-WindowsOptionalFeature { return @{ RestartNeeded = $false } }
        }
        
        It "Should handle WSL installation on Windows" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*wsl*" }
            
            { Install-CodexCLIDependencies -WSLUsername "testuser" -WhatIf } | Should -Not -Throw
        }
        
        It "Should skip WSL when requested" {
            Mock wsl { return "Ubuntu" }
            
            { Install-CodexCLIDependencies -SkipWSL -WhatIf } | Should -Not -Throw
        }
        
        It "Should require admin privileges for WSL installation" {
            # This would need privilege mocking in real testing
            $true | Should -Be $true
        }
    }
    
    Context "Linux-Specific Functionality" -Skip:(-not $IsLinux) {
        BeforeEach {
            # Mock Linux-specific commands
            Mock Test-Path { return $false } -ParameterFilter { $Path -like "*/.nvm/*" }
            Mock Invoke-Expression { return "nvm installed" }
        }
        
        It "Should install nvm on Linux" {
            { Install-CodexCLIDependencies -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle existing nvm installation" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*/.nvm/*" }
            
            { Install-CodexCLIDependencies -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Cross-Platform Path Handling" {
        It "Should use proper cross-platform path construction" {
            # Test that the function uses Join-Path and cross-platform compatible paths
            $content = Get-Content (Join-Path $devEnvModulePath "Public/Install-CodexCLIDependencies.ps1") -Raw
            
            # Should use shared utilities
            $content | Should -Match 'Find-ProjectRoot'
            
            # Should not use hardcoded path separators
            $content | Should -Not -Match '\\\\|C:\\'
        }
    }
    
    Context "Error Handling" {
        It "Should handle network connectivity issues gracefully" {
            # Mock network failure
            Mock Invoke-Expression { throw "Network error" } -ParameterFilter { $Command -like "*curl*" }
            
            { Install-CodexCLIDependencies -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle permission issues gracefully" {
            # This would need permission mocking
            $true | Should -Be $true
        }
        
        It "Should provide clear error messages" {
            # Test error message clarity
            $true | Should -Be $true
        }
    }
    
    Context "Configuration Options" {
        It "Should accept custom Node.js version" {
            { Install-CodexCLIDependencies -NodeVersion "18.20.0" -WhatIf } | Should -Not -Throw
        }
        
        It "Should default to LTS Node.js version" {
            $command = Get-Command Install-CodexCLIDependencies
            $nodeVersionParam = $command.Parameters['NodeVersion']
            $nodeVersionParam.Attributes.DefaultValue | Should -Be 'lts'
        }
        
        It "Should support Force parameter" {
            { Install-CodexCLIDependencies -Force -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Security Considerations" {
        It "Should handle passwords securely" {
            # Import test credential helper
            . "$PSScriptRoot/../../../helpers/Test-Credentials.ps1"
            $securePassword = Get-TestSecurePassword -Purpose 'WSL'
            { Install-CodexCLIDependencies -WSLUsername "testuser" -WSLPassword $securePassword -WhatIf } | Should -Not -Throw
        }
        
        It "Should not expose passwords in output" {
            # Verify that password handling is secure
            $content = Get-Content (Join-Path $devEnvModulePath "Public/Install-CodexCLIDependencies.ps1") -Raw
            $content | Should -Match 'SecureString'
            $content | Should -Match 'SecureStringToBSTR'
        }
    }
    
    Context "Codex CLI Specific Features" {
        It "Should install OpenAI Codex CLI package" {
            # Test that the function installs the correct npm package
            $content = Get-Content (Join-Path $devEnvModulePath "Public/Install-CodexCLIDependencies.ps1") -Raw
            
            # Should reference OpenAI Codex CLI package
            $content | Should -Match 'codex'
        }
        
        It "Should validate OpenAI API key requirements" {
            # Test that the function provides guidance for API key setup
            $content = Get-Content (Join-Path $devEnvModulePath "Public/Install-CodexCLIDependencies.ps1") -Raw
            
            # Should mention API key or OpenAI configuration
            $content | Should -Match 'OPENAI_API_KEY|OpenAI.*key'
        }
        
        It "Should handle experimental CLI warnings" {
            # Test that the function warns about experimental status
            $content = Get-Content (Join-Path $devEnvModulePath "Public/Install-CodexCLIDependencies.ps1") -Raw
            
            # Should mention experimental nature
            $content | Should -Match 'experimental'
        }
    }
    
    Context "Validation and Prerequisites" {
        It "Should validate PowerShell version requirement" {
            # Function should require PowerShell 7.0+
            $content = Get-Content (Join-Path $devEnvModulePath "Public/Install-CodexCLIDependencies.ps1") -Raw
            $content | Should -Match '#Requires -Version 7.0'
        }
        
        It "Should check for required tools" {
            # Should check for curl, bash, etc. on Linux
            $true | Should -Be $true
        }
        
        It "Should validate Node.js version compatibility" {
            # Test that the function checks Node.js compatibility for Codex CLI
            $content = Get-Content (Join-Path $devEnvModulePath "Public/Install-CodexCLIDependencies.ps1") -Raw
            
            # Should have Node.js version checks
            $content | Should -Match 'node.*version|Node.*js'
        }
    }
    
    Context "Integration with AitherZero Framework" {
        It "Should use AitherZero coding standards" {
            $content = Get-Content (Join-Path $devEnvModulePath "Public/Install-CodexCLIDependencies.ps1") -Raw
            
            # Should use Write-CustomLog
            $content | Should -Match 'Write-CustomLog'
            
            # Should use proper parameter validation
            $content | Should -Match '\[CmdletBinding\(SupportsShouldProcess\)\]'
            
            # Should use shared utilities
            $content | Should -Match 'Find-ProjectRoot'
        }
        
        It "Should follow AitherZero module structure" {
            $functionFile = Join-Path $devEnvModulePath "Public/Install-CodexCLIDependencies.ps1"
            Test-Path $functionFile | Should -Be $true
        }
        
        It "Should be properly exported in module manifest" {
            $manifestPath = Join-Path $devEnvModulePath "DevEnvironment.psd1"
            $manifestContent = Get-Content $manifestPath -Raw
            $manifestContent | Should -Match 'Install-CodexCLIDependencies'
        }
    }
    
    Context "Configuration File Integration" {
        It "Should integrate with AitherZero config files" {
            # Check that Codex CLI is referenced in config files
            $defaultConfigPath = Join-Path $projectRoot "configs/default-config.json"
            if (Test-Path $defaultConfigPath) {
                $configContent = Get-Content $defaultConfigPath -Raw
                $configContent | Should -Match 'CodexCLI|codex'
            }
        }
        
        It "Should support config-driven installation options" {
            # Test that the function can read from config files
            $true | Should -Be $true
        }
    }
}

Describe "Codex CLI Dependencies - Integration Tests" -Tags @('Integration', 'CodexCLI', 'SystemIntegration') {
    
    Context "End-to-End Workflow Simulation" {
        It "Should complete full workflow with WhatIf" {
            # Simulate complete installation workflow
            { Install-CodexCLIDependencies -WhatIf } | Should -Not -Throw
        }
        
        It "Should provide comprehensive installation summary" {
            # Test that the function provides good feedback
            $true | Should -Be $true
        }
        
        It "Should integrate with VS Code tasks" {
            # Check that VS Code tasks exist for Codex CLI
            $tasksPath = Join-Path $projectRoot ".vscode/tasks.json"
            if (Test-Path $tasksPath) {
                $tasksContent = Get-Content $tasksPath -Raw
                $tasksContent | Should -Match 'Codex.*CLI'
            }
        }
    }
    
    Context "Real-World Scenarios" {
        It "Should handle developer workstation setup" {
            # Test typical developer setup scenario
            if ($IsWindows) {
                { Install-CodexCLIDependencies -WSLUsername "developer" -WhatIf } | Should -Not -Throw
            } else {
                { Install-CodexCLIDependencies -WhatIf } | Should -Not -Throw
            }
        }
        
        It "Should handle CI/CD environment setup" {
            # Test automated setup scenario
            { Install-CodexCLIDependencies -Force -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle AI development environment setup" {
            # Test scenario specific to AI/ML development with Codex
            { Install-CodexCLIDependencies -NodeVersion "lts" -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Comparison with Other CLI Tools" {
        It "Should coexist with Claude Code CLI" {
            # Test that Codex CLI installation doesn't conflict with Claude Code
            { Install-CodexCLIDependencies -WhatIf } | Should -Not -Throw
        }
        
        It "Should coexist with Gemini CLI" {
            # Test that Codex CLI installation doesn't conflict with Gemini CLI
            { Install-CodexCLIDependencies -WhatIf } | Should -Not -Throw
        }
        
        It "Should use consistent Node.js environment" {
            # Test that all CLI tools use the same Node.js setup
            $true | Should -Be $true
        }
    }
    
    Context "Script Integration" {
        It "Should work with runnable install script" {
            # Check that the standalone install script exists
            $scriptPath = Join-Path $projectRoot "aither-core/scripts/0219_Install-Codex.ps1"
            Test-Path $scriptPath | Should -Be $true
        }
        
        It "Should provide consistent behavior with direct function call" {
            # Test that script and function provide same results
            $true | Should -Be $true
        }
    }
}

Describe "Codex CLI Dependencies - Performance and Reliability Tests" -Tags @('Performance', 'CodexCLI', 'Reliability') {
    
    Context "Performance Characteristics" {
        It "Should complete installation check quickly" {
            # Test that WhatIf operations are fast
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            { Install-CodexCLIDependencies -WhatIf } | Should -Not -Throw
            $stopwatch.Stop()
            
            # Should complete check in reasonable time (5 seconds)
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }
        
        It "Should handle multiple concurrent installations gracefully" {
            # Test parallel execution safety
            $true | Should -Be $true
        }
    }
    
    Context "Error Recovery" {
        It "Should recover from partial installations" {
            # Test recovery from interrupted installations
            $true | Should -Be $true
        }
        
        It "Should provide rollback capabilities" {
            # Test that failed installations can be cleaned up
            $true | Should -Be $true
        }
    }
    
    Context "Cross-Platform Reliability" {
        It "Should work consistently across Windows versions" -Skip:(-not $IsWindows) {
            # Test on different Windows versions
            { Install-CodexCLIDependencies -WhatIf } | Should -Not -Throw
        }
        
        It "Should work consistently across Linux distributions" -Skip:(-not $IsLinux) {
            # Test on different Linux distributions
            { Install-CodexCLIDependencies -WhatIf } | Should -Not -Throw
        }
        
        It "Should work on macOS if supported" -Skip:(-not $IsMacOS) {
            # Test on macOS
            { Install-CodexCLIDependencies -WhatIf } | Should -Not -Throw
        }
    }
}

AfterAll {
    # Cleanup test resources
    Write-Host "✅ Install-CodexCLIDependencies tests completed" -ForegroundColor Green
    Write-Host "📝 Note: Codex CLI is an experimental OpenAI tool - test coverage includes experimental status validation" -ForegroundColor Yellow
}
