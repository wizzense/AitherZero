#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Example test demonstrating environment-aware testing patterns
.DESCRIPTION
    This test file demonstrates how to use the new environment-aware test helpers
    to create tests that adapt to CI vs local execution environments.
    
    This is a reference implementation showing best practices for:
    - Detecting CI vs local environments
    - Adjusting timeouts based on environment
    - Skipping tests conditionally
    - Using environment-specific resource paths
    - Configuring tests based on environment context
#>

Describe 'Environment-Aware Testing Examples' -Tag 'Unit', 'Example' {

    BeforeAll {
        # Import test helpers
        $testHelpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "TestHelpers.psm1"
        Import-Module $testHelpersPath -Force

        # Initialize test environment
        $script:TestEnv = Get-TestEnvironment
        $script:Config = New-TestConfiguration
    }

    Context 'Environment Detection' {
        It 'Should detect if running in CI' {
            # Test-IsCI returns true in GitHub Actions, GitLab CI, Azure Pipelines, etc.
            $isCI = Test-IsCI
            $isCI | Should -BeIn @($true, $false)
            
            Write-Host "Running in CI: $isCI"
        }

        It 'Should provide complete environment context' {
            $env = Get-TestEnvironment
            
            $env | Should -Not -BeNullOrEmpty
            $env.Keys | Should -Contain 'IsCI'
            $env.Keys | Should -Contain 'Platform'
            $env.Keys | Should -Contain 'CIProvider'
            
            Write-Host "Environment: IsCI=$($env.IsCI), Platform=$($env.Platform), Provider=$($env.CIProvider)"
        }

        It 'Should identify CI provider correctly' {
            $provider = Get-CIProvider
            
            # Should be one of: GitHubActions, GitLabCI, AzurePipelines, Jenkins, TravisCI, AppVeyor, CircleCI, TeamCity, or Local
            $validProviders = @('GitHubActions', 'GitLabCI', 'AzurePipelines', 'Jenkins', 'TravisCI', 'AppVeyor', 'CircleCI', 'TeamCity', 'Local', 'AitherZeroCI')
            $provider | Should -BeIn $validProviders
            
            Write-Host "CI Provider: $provider"
        }
    }

    Context 'Environment-Adaptive Timeouts' {
        It 'Should provide appropriate timeout for short operations' {
            $timeout = Get-TestTimeout -Operation 'Short'
            
            # CI environments get 2x timeout
            if ($script:TestEnv.IsCI) {
                $timeout | Should -BeGreaterOrEqual 60  # 30s * 2 = 60s in CI
            } else {
                $timeout | Should -Be 30  # 30s locally
            }
            
            Write-Host "Short operation timeout: $timeout seconds"
        }

        It 'Should provide appropriate timeout for long operations' {
            $timeout = Get-TestTimeout -Operation 'Long'
            
            # CI environments get 2x timeout
            if ($script:TestEnv.IsCI) {
                $timeout | Should -BeGreaterOrEqual 600  # 300s * 2 = 600s in CI
            } else {
                $timeout | Should -Be 300  # 300s (5 min) locally
            }
            
            Write-Host "Long operation timeout: $timeout seconds"
        }
    }

    Context 'Conditional Test Execution' {
        It 'Should only run in CI environments' {
            # Skip if not in CI
            if (-not $script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "CI-only validation"
                return
            }
            
            # This test only runs in CI
            $script:TestEnv.IsCI | Should -Be $true
            
            Write-Host "This test runs ONLY in CI"
        }

        It 'Should only run in local environments' {
            # Skip if in CI
            if ($script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "Requires interactive console"
                return
            }
            
            # This test only runs locally
            $script:TestEnv.IsCI | Should -Be $false
            
            Write-Host "This test runs ONLY locally"
        }

        It 'Should always run regardless of environment' {
            # No Skip logic - runs in both CI and local
            $script:TestEnv | Should -Not -BeNullOrEmpty
            
            Write-Host "This test runs in BOTH CI and local environments"
        }
    }

    Context 'Environment-Specific Resource Paths' {
        It 'Should provide environment-appropriate temp directory' {
            $tempPath = Get-TestResourcePath -ResourceType 'TempDir'
            
            $tempPath | Should -Not -BeNullOrEmpty
            
            # Verify it's a valid temp directory path
            $tempPath | Should -Match '(tmp|temp|TEMP|TMP)'
            
            Write-Host "Temp directory: $tempPath"
        }

        It 'Should provide environment-appropriate log paths' {
            $logPath = Get-TestResourcePath -ResourceType 'Logs'
            
            $logPath | Should -Not -BeNullOrEmpty
            
            # Logs should be segregated by environment
            if ($script:TestEnv.IsCI) {
                $logPath | Should -BeLike '*ci-tests*'
            } else {
                $logPath | Should -BeLike '*local-tests*'
            }
            
            Write-Host "Log path: $logPath"
        }

        It 'Should provide environment-appropriate output paths' {
            $outputPath = Get-TestResourcePath -ResourceType 'Output'
            
            $outputPath | Should -Not -BeNullOrEmpty
            
            # Output should be segregated by environment
            if ($script:TestEnv.IsCI) {
                $outputPath | Should -BeLike '*results*ci*'
            } else {
                $outputPath | Should -BeLike '*results*local*'
            }
            
            Write-Host "Output path: $outputPath"
        }
    }

    Context 'Environment-Adaptive Configuration' {
        It 'Should create CI-appropriate test configuration' {
            $config = New-TestConfiguration
            
            $config | Should -Not -BeNullOrEmpty
            
            if ($script:TestEnv.IsCI) {
                # CI configuration
                $config.Core.Environment | Should -Be 'CI'
                $config.Automation.MaxConcurrency | Should -Be 1  # Sequential in CI
                $config.Testing.CoverageEnabled | Should -Be $true
            } else {
                # Local configuration
                $config.Core.Environment | Should -Be 'Test'
                $config.Automation.MaxConcurrency | Should -Be 2  # Parallel locally
            }
            
            Write-Host "Configuration profile: $($config.Core.Environment)"
        }

        It 'Should include environment context in configuration' {
            $config = New-TestConfiguration
            
            $config.Environment | Should -Not -BeNullOrEmpty
            $config.Environment.IsCI | Should -Be $script:TestEnv.IsCI
            $config.Environment.Platform | Should -Be $script:TestEnv.Platform
            $config.Environment.CIProvider | Should -Be $script:TestEnv.CIProvider
            
            Write-Host "Config environment: CI=$($config.Environment.IsCI), Platform=$($config.Environment.Platform)"
        }

        It 'Should provide environment-adaptive timeouts in configuration' {
            $config = New-TestConfiguration
            
            $config.Testing.Timeouts | Should -Not -BeNullOrEmpty
            $config.Testing.Timeouts.Short | Should -BeGreaterThan 0
            $config.Testing.Timeouts.Medium | Should -BeGreaterThan 0
            $config.Testing.Timeouts.Long | Should -BeGreaterThan 0
            
            # CI should have longer timeouts
            if ($script:TestEnv.IsCI) {
                $config.Testing.Timeouts.Medium | Should -BeGreaterThan 120
            }
            
            Write-Host "Configured timeouts: Short=$($config.Testing.Timeouts.Short)s, Medium=$($config.Testing.Timeouts.Medium)s, Long=$($config.Testing.Timeouts.Long)s"
        }
    }

    Context 'Best Practices Examples' {
        It 'Should demonstrate timeout usage in tests' {
            # Get environment-appropriate timeout
            $timeout = Get-TestTimeout -Operation 'Medium'
            
            # Use the timeout in your test logic
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Simulate an operation that might take longer in CI
            Start-Sleep -Milliseconds 100
            
            $stopwatch.Stop()
            
            # Verify operation completed within timeout
            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan $timeout
            
            Write-Host "Operation completed in $($stopwatch.Elapsed.TotalMilliseconds)ms (timeout: ${timeout}s)"
        }

        It 'Should demonstrate resource path usage' {
            # Get environment-appropriate cache path
            $cachePath = Get-TestResourcePath -ResourceType 'Cache'
            
            # In real tests, you would use this path for caching test data
            # For example: storing pre-compiled assets, downloaded fixtures, etc.
            
            $cachePath | Should -Not -BeNullOrEmpty
            
            Write-Host "Cache path for test artifacts: $cachePath"
        }

        It 'Should demonstrate conditional test logic' {
            # Different assertions based on environment
            if ($script:TestEnv.IsCI) {
                # In CI, we might have stricter requirements
                Write-Host "Running strict CI validation"
                $script:TestEnv.HasInteractiveConsole | Should -Be $false
            } else {
                # Locally, we might be more lenient
                Write-Host "Running flexible local validation"
                # Interactive console might be available
                $script:TestEnv.HasInteractiveConsole | Should -BeIn @($true, $false)
            }
        }
    }

    AfterAll {
        Write-Host "`nEnvironment-Aware Test Summary:"
        Write-Host "  Environment: $(if ($script:TestEnv.IsCI) { 'CI' } else { 'Local' })"
        Write-Host "  Platform: $($script:TestEnv.Platform)"
        Write-Host "  CI Provider: $($script:TestEnv.CIProvider)"
        Write-Host "  PowerShell: $($script:TestEnv.PowerShellVersion)"
    }
}
