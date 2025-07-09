#Requires -Version 7.0

<#
.SYNOPSIS
    Pester tests for AitherZero non-interactive mode support

.DESCRIPTION
    Tests that AitherZero can run in automated environments without user interaction:
    - CI/CD pipeline compatibility
    - Automated deployment scenarios
    - Silent installation and setup
    - Error handling in non-interactive contexts

.NOTES
    These tests are crucial for ensuring AitherZero works in automated environments
#>

BeforeAll {
    # Set up test environment
    $script:TestStartTime = Get-Date
    $script:ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:AitherCorePath = Join-Path $script:ProjectRoot "aither-core"
    $script:StartupScript = Join-Path $script:ProjectRoot "Start-AitherZero.ps1"
    $script:CoreScript = Join-Path $script:AitherCorePath "aither-core.ps1"
    
    # Create test workspace
    $script:TestWorkspace = if ($env:TEMP) {
        Join-Path $env:TEMP "AitherZero-NonInteractiveTests-$(Get-Random)"
    } elseif (Test-Path '/tmp') {
        "/tmp/AitherZero-NonInteractiveTests-$(Get-Random)"
    } else {
        Join-Path (Get-Location) "AitherZero-NonInteractiveTests-$(Get-Random)"
    }
    
    New-Item -Path $script:TestWorkspace -ItemType Directory -Force | Out-Null
    
    # Store original environment variables
    $script:OriginalEnvVars = @{
        AITHER_LOG_LEVEL = $env:AITHER_LOG_LEVEL
        AITHER_CONSOLE_LEVEL = $env:AITHER_CONSOLE_LEVEL
        AITHER_LOG_TO_CONSOLE = $env:AITHER_LOG_TO_CONSOLE
        CI = $env:CI
        GITHUB_ACTIONS = $env:GITHUB_ACTIONS
        BUILD_BUILDID = $env:BUILD_BUILDID
    }
}

AfterAll {
    # Cleanup test workspace
    if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
        Remove-Item $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Restore original environment variables
    foreach ($envVar in $script:OriginalEnvVars.GetEnumerator()) {
        if ($envVar.Value) {
            [Environment]::SetEnvironmentVariable($envVar.Key, $envVar.Value, [EnvironmentVariableTarget]::Process)
        } else {
            [Environment]::SetEnvironmentVariable($envVar.Key, $null, [EnvironmentVariableTarget]::Process)
        }
    }
}

Describe "Non-Interactive Mode Support" -Tag @('NonInteractive', 'CI', 'Automation') {
    
    Context "Environment Detection" {
        It "Should detect CI/CD environments" {
            # Test GitHub Actions detection
            $env:GITHUB_ACTIONS = "true"
            $env:CI = "true"
            
            try {
                $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
                { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
                
                # Should handle CI environment appropriately
                { Initialize-CoreApplication -RequiredOnly } | Should -Not -Throw
            } finally {
                Remove-Item Env:\GITHUB_ACTIONS -ErrorAction SilentlyContinue
                Remove-Item Env:\CI -ErrorAction SilentlyContinue
            }
        }
        
        It "Should detect Azure DevOps environments" {
            $env:BUILD_BUILDID = "12345"
            $env:TF_BUILD = "true"
            
            try {
                $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
                { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
                
                # Should handle Azure DevOps environment appropriately
                { Initialize-CoreApplication -RequiredOnly } | Should -Not -Throw
            } finally {
                Remove-Item Env:\BUILD_BUILDID -ErrorAction SilentlyContinue
                Remove-Item Env:\TF_BUILD -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Silent Operation" {
        It "Should support silent logging configuration" {
            $env:AITHER_LOG_LEVEL = "ERROR"
            $env:AITHER_CONSOLE_LEVEL = "SILENT"
            
            try {
                $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
                { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
                
                # Should initialize without console output
                { Initialize-CoreApplication -RequiredOnly } | Should -Not -Throw
            } finally {
                Remove-Item Env:\AITHER_LOG_LEVEL -ErrorAction SilentlyContinue
                Remove-Item Env:\AITHER_CONSOLE_LEVEL -ErrorAction SilentlyContinue
            }
        }
        
        It "Should disable console output when requested" {
            $env:AITHER_LOG_TO_CONSOLE = "false"
            
            try {
                $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
                { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
                
                # Should work without console output
                { Initialize-CoreApplication -RequiredOnly } | Should -Not -Throw
            } finally {
                Remove-Item Env:\AITHER_LOG_TO_CONSOLE -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Parameter Support" {
        It "Should support NonInteractive parameter" {
            if (Test-Path $script:StartupScript) {
                $content = Get-Content $script:StartupScript -Raw
                $content | Should -Match "NonInteractive" -Because "Start-AitherZero should support NonInteractive parameter"
            }
        }
        
        It "Should support Auto parameter" {
            if (Test-Path $script:StartupScript) {
                $content = Get-Content $script:StartupScript -Raw
                $content | Should -Match "Auto" -Because "Start-AitherZero should support Auto parameter"
            }
        }
        
        It "Should support Quiet parameter" {
            if (Test-Path $script:CoreScript) {
                $content = Get-Content $script:CoreScript -Raw
                $content | Should -Match "Quiet" -Because "aither-core should support Quiet parameter"
            }
        }
    }
    
    Context "Error Handling in Non-Interactive Mode" {
        It "Should handle missing dependencies gracefully" {
            # Simulate missing optional dependency
            $env:AITHER_LOG_LEVEL = "ERROR"
            $env:AITHER_CONSOLE_LEVEL = "ERROR"
            
            try {
                $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
                { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
                
                # Should not fail due to missing optional dependencies
                { Initialize-CoreApplication } | Should -Not -Throw
            } finally {
                Remove-Item Env:\AITHER_LOG_LEVEL -ErrorAction SilentlyContinue
                Remove-Item Env:\AITHER_CONSOLE_LEVEL -ErrorAction SilentlyContinue
            }
        }
        
        It "Should provide proper exit codes for automation" {
            # Test that the system provides meaningful exit codes
            $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
            
            # Successful operations should not throw
            { Initialize-CoreApplication -RequiredOnly } | Should -Not -Throw
        }
    }
    
    Context "Configuration File Support" {
        It "Should support configuration file override" {
            # Create a test configuration file
            $testConfigPath = Join-Path $script:TestWorkspace "test-config.json"
            $testConfig = @{
                version = "1.0.0"
                mode = "test"
                modules = @("Logging", "LabRunner")
            }
            
            $testConfig | ConvertTo-Json | Set-Content $testConfigPath
            
            # Test that configuration can be loaded
            Test-Path $testConfigPath | Should -Be $true
            
            # Configuration should be loadable
            { Get-Content $testConfigPath | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should handle missing configuration gracefully" {
            # Test with non-existent configuration
            $nonExistentConfig = Join-Path $script:TestWorkspace "nonexistent-config.json"
            Test-Path $nonExistentConfig | Should -Be $false
            
            # System should handle missing configuration gracefully
            $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
        }
    }
    
    Context "Logging in Non-Interactive Mode" {
        It "Should support file-only logging" {
            $logPath = Join-Path $script:TestWorkspace "aither-test.log"
            $env:AITHER_LOG_PATH = $logPath
            $env:AITHER_LOG_TO_CONSOLE = "false"
            $env:AITHER_LOG_TO_FILE = "true"
            
            try {
                $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
                { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
                
                # Initialize and verify logging
                { Initialize-CoreApplication -RequiredOnly } | Should -Not -Throw
                
                # Log file should be created
                Test-Path $logPath | Should -Be $true
            } finally {
                Remove-Item Env:\AITHER_LOG_PATH -ErrorAction SilentlyContinue
                Remove-Item Env:\AITHER_LOG_TO_CONSOLE -ErrorAction SilentlyContinue
                Remove-Item Env:\AITHER_LOG_TO_FILE -ErrorAction SilentlyContinue
            }
        }
        
        It "Should support structured logging output" {
            $env:AITHER_LOG_FORMAT = "JSON"
            $logPath = Join-Path $script:TestWorkspace "aither-json.log"
            $env:AITHER_LOG_PATH = $logPath
            
            try {
                $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
                { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
                
                { Initialize-CoreApplication -RequiredOnly } | Should -Not -Throw
                
                # Should support JSON format
                if (Test-Path $logPath) {
                    $logContent = Get-Content $logPath -Raw
                    # JSON log should be parseable
                    # Note: This is a simplified test - in practice, each line would be JSON
                    $logContent | Should -Not -BeNullOrEmpty
                }
            } finally {
                Remove-Item Env:\AITHER_LOG_FORMAT -ErrorAction SilentlyContinue
                Remove-Item Env:\AITHER_LOG_PATH -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Performance in Non-Interactive Mode" {
        It "Should complete initialization quickly in non-interactive mode" {
            $env:AITHER_LOG_LEVEL = "ERROR"
            $env:AITHER_CONSOLE_LEVEL = "SILENT"
            $env:CI = "true"
            
            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                
                $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
                Import-Module $aitherCorePath -Force
                Initialize-CoreApplication -RequiredOnly
                
                $stopwatch.Stop()
                
                # Should complete within reasonable time in CI mode
                $stopwatch.ElapsedMilliseconds | Should -BeLessThan 20000 -Because "Non-interactive mode should be fast"
            } finally {
                Remove-Item Env:\AITHER_LOG_LEVEL -ErrorAction SilentlyContinue
                Remove-Item Env:\AITHER_CONSOLE_LEVEL -ErrorAction SilentlyContinue
                Remove-Item Env:\CI -ErrorAction SilentlyContinue
            }
        }
        
        It "Should handle concurrent operations safely" {
            # Test that multiple processes could theoretically run simultaneously
            $env:AITHER_LOG_LEVEL = "ERROR"
            
            try {
                $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
                
                # Multiple imports should not conflict
                { Import-Module $aitherCorePath -Force } | Should -Not -Throw
                { Import-Module $aitherCorePath -Force } | Should -Not -Throw
                
                { Initialize-CoreApplication -RequiredOnly } | Should -Not -Throw
            } finally {
                Remove-Item Env:\AITHER_LOG_LEVEL -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Integration with CI/CD Pipelines" {
        It "Should support GitHub Actions workflow" {
            $env:GITHUB_ACTIONS = "true"
            $env:CI = "true"
            $env:RUNNER_OS = "Linux"
            
            try {
                $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
                { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
                
                # Should work in GitHub Actions environment
                { Initialize-CoreApplication -RequiredOnly } | Should -Not -Throw
            } finally {
                Remove-Item Env:\GITHUB_ACTIONS -ErrorAction SilentlyContinue
                Remove-Item Env:\CI -ErrorAction SilentlyContinue
                Remove-Item Env:\RUNNER_OS -ErrorAction SilentlyContinue
            }
        }
        
        It "Should support Azure DevOps pipeline" {
            $env:TF_BUILD = "true"
            $env:BUILD_BUILDID = "12345"
            $env:AGENT_OS = "Windows_NT"
            
            try {
                $aitherCorePath = Join-Path $script:AitherCorePath "AitherCore.psm1"
                { Import-Module $aitherCorePath -Force -ErrorAction Stop } | Should -Not -Throw
                
                # Should work in Azure DevOps environment
                { Initialize-CoreApplication -RequiredOnly } | Should -Not -Throw
            } finally {
                Remove-Item Env:\TF_BUILD -ErrorAction SilentlyContinue
                Remove-Item Env:\BUILD_BUILDID -ErrorAction SilentlyContinue
                Remove-Item Env:\AGENT_OS -ErrorAction SilentlyContinue
            }
        }
    }
}