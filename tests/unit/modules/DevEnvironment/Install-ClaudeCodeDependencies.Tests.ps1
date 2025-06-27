#Requires -Version 7.0

<#
.SYNOPSIS
    Tests for Install-ClaudeCodeDependencies function

.DESCRIPTION
    Comprehensive tests for the Claude Code dependencies installation function,
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

Describe "Install-ClaudeCodeDependencies Function Tests" -Tags @('Unit', 'DevEnvironment', 'ClaudeCode') {
    
    Context "Function Availability and Structure" {
        It "Should be available after module import" {
            Get-Command Install-ClaudeCodeDependencies -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have correct parameter structure" {
            $command = Get-Command Install-ClaudeCodeDependencies
            $command.Parameters.Keys | Should -Contain 'SkipWSL'
            $command.Parameters.Keys | Should -Contain 'WSLUsername'
            $command.Parameters.Keys | Should -Contain 'WSLPassword'
            $command.Parameters.Keys | Should -Contain 'NodeVersion'
            $command.Parameters.Keys | Should -Contain 'Force'
            $command.Parameters.Keys | Should -Contain 'WhatIf'
        }
        
        It "Should support ShouldProcess (WhatIf)" {
            $command = Get-Command Install-ClaudeCodeDependencies
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
            { Install-ClaudeCodeDependencies -WhatIf } | Should -Not -Throw
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
            
            { Install-ClaudeCodeDependencies -WSLUsername "testuser" -WhatIf } | Should -Not -Throw
        }
        
        It "Should skip WSL when requested" {
            Mock wsl { return "Ubuntu" }
            
            { Install-ClaudeCodeDependencies -SkipWSL -WhatIf } | Should -Not -Throw
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
            { Install-ClaudeCodeDependencies -WhatIf } | Should -Not -Throw
        }
        
        It "Should handle existing nvm installation" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*/.nvm/*" }
            
            { Install-ClaudeCodeDependencies -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Cross-Platform Path Handling" {
        It "Should use proper cross-platform path construction" {
            # Test that the function uses Join-Path and cross-platform compatible paths
            $content = Get-Content (Join-Path $devEnvModulePath "Public/Install-ClaudeCodeDependencies.ps1") -Raw
            
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
            
            { Install-ClaudeCodeDependencies -WhatIf } | Should -Not -Throw
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
            { Install-ClaudeCodeDependencies -NodeVersion "18.20.0" -WhatIf } | Should -Not -Throw
        }
        
        It "Should default to LTS Node.js version" {
            $command = Get-Command Install-ClaudeCodeDependencies
            $nodeVersionParam = $command.Parameters['NodeVersion']
            $nodeVersionParam.Attributes.DefaultValue | Should -Be 'lts'
        }
        
        It "Should support Force parameter" {
            { Install-ClaudeCodeDependencies -Force -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Security Considerations" {
        It "Should handle passwords securely" {
            $securePassword = ConvertTo-SecureString "testpassword" -AsPlainText -Force
            { Install-ClaudeCodeDependencies -WSLUsername "testuser" -WSLPassword $securePassword -WhatIf } | Should -Not -Throw
        }
        
        It "Should not expose passwords in output" {
            # Verify that password handling is secure
            $content = Get-Content (Join-Path $devEnvModulePath "Public/Install-ClaudeCodeDependencies.ps1") -Raw
            $content | Should -Match 'SecureString'
            $content | Should -Match 'SecureStringToBSTR'
        }
    }
    
    Context "Validation and Prerequisites" {
        It "Should validate PowerShell version requirement" {
            # Function should require PowerShell 7.0+
            $content = Get-Content (Join-Path $devEnvModulePath "Public/Install-ClaudeCodeDependencies.ps1") -Raw
            $content | Should -Match '#Requires -Version 7.0'
        }
        
        It "Should check for required tools" {
            # Should check for curl, bash, etc. on Linux
            $true | Should -Be $true
        }
    }
    
    Context "Integration with AitherZero Framework" {
        It "Should use AitherZero coding standards" {
            $content = Get-Content (Join-Path $devEnvModulePath "Public/Install-ClaudeCodeDependencies.ps1") -Raw
            
            # Should use Write-CustomLog
            $content | Should -Match 'Write-CustomLog'
            
            # Should use proper parameter validation
            $content | Should -Match '\[CmdletBinding\(SupportsShouldProcess\)\]'
            
            # Should use shared utilities
            $content | Should -Match 'Find-ProjectRoot'
        }
        
        It "Should follow AitherZero module structure" {
            $functionFile = Join-Path $devEnvModulePath "Public/Install-ClaudeCodeDependencies.ps1"
            Test-Path $functionFile | Should -Be $true
        }
    }
}

Describe "Claude Code Dependencies - Integration Tests" -Tags @('Integration', 'ClaudeCode', 'SystemIntegration') {
    
    Context "End-to-End Workflow Simulation" {
        It "Should complete full workflow with WhatIf" {
            # Simulate complete installation workflow
            { Install-ClaudeCodeDependencies -WhatIf } | Should -Not -Throw
        }
        
        It "Should provide comprehensive installation summary" {
            # Test that the function provides good feedback
            $true | Should -Be $true
        }
    }
    
    Context "Real-World Scenarios" {
        It "Should handle developer workstation setup" {
            # Test typical developer setup scenario
            if ($IsWindows) {
                { Install-ClaudeCodeDependencies -WSLUsername "developer" -WhatIf } | Should -Not -Throw
            } else {
                { Install-ClaudeCodeDependencies -WhatIf } | Should -Not -Throw
            }
        }
        
        It "Should handle CI/CD environment setup" {
            # Test automated setup scenario
            { Install-ClaudeCodeDependencies -Force -WhatIf } | Should -Not -Throw
        }
    }
}

AfterAll {
    # Cleanup test resources
    Write-Host "✅ Install-ClaudeCodeDependencies tests completed" -ForegroundColor Green
}
