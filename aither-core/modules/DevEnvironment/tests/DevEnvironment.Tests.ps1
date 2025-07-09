#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive test suite for the DevEnvironment module

.DESCRIPTION
    This test suite validates all aspects of the DevEnvironment module including:
    - Module structure and loading
    - Function availability and parameter validation
    - VS Code integration functionality
    - AI tools dependency management
    - Cross-platform compatibility
    - Environment health checking
    - Integration with other AitherZero modules

.NOTES
    These tests are designed to run in any environment and provide comprehensive
    validation of the DevEnvironment module capabilities.
#>

# Import required modules for testing
BeforeAll {
    # Find project root
    $script:ProjectRoot = $PSScriptRoot
    while ($script:ProjectRoot -and -not (Test-Path (Join-Path $script:ProjectRoot "Start-AitherZero.ps1"))) {
        $script:ProjectRoot = Split-Path $script:ProjectRoot -Parent
    }

    if (-not $script:ProjectRoot) {
        throw "Could not find AitherZero project root"
    }

    # Import the DevEnvironment module
    $script:ModulePath = Join-Path $script:ProjectRoot "aither-core/modules/DevEnvironment"
    Import-Module $script:ModulePath -Force

    # Import supporting modules
    $script:LoggingModulePath = Join-Path $script:ProjectRoot "aither-core/modules/Logging"
    if (Test-Path $script:LoggingModulePath) {
        Import-Module $script:LoggingModulePath -Force -Global -ErrorAction SilentlyContinue
    }

    $script:AIToolsModulePath = Join-Path $script:ProjectRoot "aither-core/modules/AIToolsIntegration"
    if (Test-Path $script:AIToolsModulePath) {
        Import-Module $script:AIToolsModulePath -Force -Global -ErrorAction SilentlyContinue
    }
}

Describe "DevEnvironment Module Structure" {
    Context "Module Files and Manifest" {
        It "Should have a module manifest file" {
            $manifestPath = Join-Path $script:ModulePath "DevEnvironment.psd1"
            $manifestPath | Should -Exist
        }

        It "Should have a module script file" {
            $moduleScript = Join-Path $script:ModulePath "DevEnvironment.psm1"
            $moduleScript | Should -Exist
        }

        It "Should have a Public functions directory" {
            $publicDir = Join-Path $script:ModulePath "Public"
            $publicDir | Should -Exist
        }

        It "Should have README documentation" {
            $readmePath = Join-Path $script:ModulePath "README.md"
            $readmePath | Should -Exist
        }

        It "Should have test files" {
            $testsPath = Join-Path $script:ModulePath "tests"
            $testsPath | Should -Exist
        }
    }

    Context "Module Manifest Validation" {
        BeforeAll {
            $script:Manifest = Test-ModuleManifest (Join-Path $script:ModulePath "DevEnvironment.psd1")
        }

        It "Should have correct module version format" {
            $script:Manifest.Version | Should -Match '^\d+\.\d+\.\d+$'
        }

        It "Should require PowerShell 7.0 or higher" {
            $script:Manifest.PowerShellVersion | Should -BeGreaterOrEqual ([Version]'7.0')
        }

        It "Should export the expected functions" {
            $expectedFunctions = @(
                'Initialize-DevEnvironment',
                'Get-DevEnvironmentStatus',
                'Test-DevEnvironment',
                'Initialize-VSCodeWorkspace',
                'Test-VSCodeIntegration',
                'Install-ClaudeCodeDependencies',
                'Optimize-PlatformEnvironment'
            )

            foreach ($function in $expectedFunctions) {
                $script:Manifest.ExportedFunctions.Keys | Should -Contain $function
            }
        }
    }
}

Describe "Core DevEnvironment Functions" {
    Context "Function Availability" {
        It "Should export Initialize-DevEnvironment function" {
            Get-Command Initialize-DevEnvironment -Module DevEnvironment | Should -Not -BeNullOrEmpty
        }

        It "Should export Get-DevEnvironmentStatus function" {
            Get-Command Get-DevEnvironmentStatus -Module DevEnvironment | Should -Not -BeNullOrEmpty
        }

        It "Should export Test-DevEnvironment function" {
            Get-Command Test-DevEnvironment -Module DevEnvironment | Should -Not -BeNullOrEmpty
        }

        It "Should export Optimize-PlatformEnvironment function" {
            Get-Command Optimize-PlatformEnvironment -Module DevEnvironment | Should -Not -BeNullOrEmpty
        }
    }

    Context "Get-DevEnvironmentStatus Function" {
        It "Should return a valid status object" {
            $status = Get-DevEnvironmentStatus
            $status | Should -Not -BeNullOrEmpty
            $status.Timestamp | Should -Not -BeNullOrEmpty
            $status.Environment | Should -Not -BeNullOrEmpty
            $status.Health | Should -BeIn @('Healthy', 'Warning', 'Critical', 'Unknown')
        }

        It "Should include PowerShell version information" {
            $status = Get-DevEnvironmentStatus
            $status.Environment.PowerShellVersion | Should -Not -BeNullOrEmpty
            $status.Environment.Platform | Should -Not -BeNullOrEmpty
        }

        It "Should include module information" {
            $status = Get-DevEnvironmentStatus
            $status.Modules | Should -Not -BeNullOrEmpty
            $status.Modules.Total | Should -BeGreaterThan 0
        }

        It "Should support metrics inclusion" {
            $status = Get-DevEnvironmentStatus -IncludeMetrics
            $status.Metrics | Should -Not -BeNullOrEmpty
            $status.Metrics.MemoryUsage | Should -BeGreaterThan 0
        }
    }

    Context "Test-DevEnvironment Function" {
        It "Should perform basic environment testing" {
            $testResult = Test-DevEnvironment
            $testResult | Should -Not -BeNullOrEmpty
            $testResult.TestsTotal | Should -BeGreaterThan 0
            $testResult.OverallHealth | Should -BeIn @('Healthy', 'Warning', 'Critical')
        }

        It "Should test PowerShell environment" {
            $testResult = Test-DevEnvironment
            $psCategory = $testResult.Categories.PowerShell
            $psCategory | Should -Not -BeNullOrEmpty
            $psCategory.Tests | Should -Not -BeNullOrEmpty
        }

        It "Should test Git environment" {
            $testResult = Test-DevEnvironment
            $gitCategory = $testResult.Categories.Git
            $gitCategory | Should -Not -BeNullOrEmpty
            $gitCategory.Tests | Should -Not -BeNullOrEmpty
        }

        It "Should support AI tools testing when requested" {
            $testResult = Test-DevEnvironment -IncludeAITools
            $aiCategory = $testResult.Categories.AITools
            $aiCategory | Should -Not -BeNullOrEmpty
            $aiCategory.Tests | Should -Not -BeNullOrEmpty
        }

        It "Should support performance metrics when requested" {
            $testResult = Test-DevEnvironment -IncludePerformanceMetrics
            $perfCategory = $testResult.Categories.Performance
            $perfCategory | Should -Not -BeNullOrEmpty
            $perfCategory.Tests | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "VS Code Integration" {
    Context "VS Code Functions" {
        It "Should export Initialize-VSCodeWorkspace function" {
            Get-Command Initialize-VSCodeWorkspace -Module DevEnvironment | Should -Not -BeNullOrEmpty
        }

        It "Should export Test-VSCodeIntegration function" {
            Get-Command Test-VSCodeIntegration -Module DevEnvironment | Should -Not -BeNullOrEmpty
        }

        It "Should export Install-VSCodeExtensions function" {
            Get-Command Install-VSCodeExtensions -Module DevEnvironment | Should -Not -BeNullOrEmpty
        }

        It "Should export Update-VSCodeSettings function" {
            Get-Command Update-VSCodeSettings -Module DevEnvironment | Should -Not -BeNullOrEmpty
        }
    }

    Context "Test-VSCodeIntegration Function" {
        It "Should test VS Code integration without errors" {
            { Test-VSCodeIntegration } | Should -Not -Throw
        }

        It "Should return valid integration test results" {
            $result = Test-VSCodeIntegration
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -BeOfType [bool]
            $result.VSCodeInstalled | Should -BeOfType [bool]
            $result.CLIAvailable | Should -BeOfType [bool]
        }

        It "Should support detailed testing mode" {
            { Test-VSCodeIntegration -Detailed } | Should -Not -Throw
        }

        It "Should support extension checking" {
            { Test-VSCodeIntegration -RequiredExtensions @('ms-vscode.powershell') } | Should -Not -Throw
        }
    }

    Context "Initialize-VSCodeWorkspace Function" {
        It "Should support WhatIf mode" {
            { Initialize-VSCodeWorkspace -WhatIf } | Should -Not -Throw
        }

        It "Should support workspace creation" {
            { Initialize-VSCodeWorkspace -CreateWorkspaceFile -WhatIf } | Should -Not -Throw
        }

        It "Should support extension installation" {
            { Initialize-VSCodeWorkspace -InstallExtensions -WhatIf } | Should -Not -Throw
        }
    }
}

Describe "AI Tools Integration" {
    Context "AI Tools Functions" {
        It "Should export Install-ClaudeCodeDependencies function" {
            Get-Command Install-ClaudeCodeDependencies -Module DevEnvironment | Should -Not -BeNullOrEmpty
        }

        It "Should export Install-GeminiCLIDependencies function" {
            Get-Command Install-GeminiCLIDependencies -Module DevEnvironment | Should -Not -BeNullOrEmpty
        }
    }

    Context "Claude Code Dependencies" {
        It "Should support WhatIf mode for dependency installation" {
            { Install-ClaudeCodeDependencies -WhatIf } | Should -Not -Throw
        }

        It "Should detect platform requirements" {
            # This should not throw and should detect platform-specific requirements
            { Install-ClaudeCodeDependencies -WhatIf } | Should -Not -Throw
        }
    }

    Context "Integration with AIToolsIntegration Module" {
        It "Should be able to use AIToolsIntegration functions if available" {
            if (Get-Module -Name AIToolsIntegration) {
                Get-Command Test-NodeJsPrerequisites -Module AIToolsIntegration | Should -Not -BeNullOrEmpty
                Get-Command Install-ClaudeCode -Module AIToolsIntegration | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe "Platform Optimization" {
    Context "Platform Detection" {
        It "Should correctly detect current platform" {
            $platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
            $platform | Should -Not -Be 'Unknown'
        }
    }

    Context "Optimize-PlatformEnvironment Function" {
        It "Should support WhatIf mode" {
            { Optimize-PlatformEnvironment -WhatIf } | Should -Not -Throw
        }

        It "Should support platform-specific optimization" {
            $platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Auto' }
            { Optimize-PlatformEnvironment -Platform $platform -WhatIf } | Should -Not -Throw
        }

        It "Should support performance tuning options" {
            { Optimize-PlatformEnvironment -IncludePerformanceTuning -WhatIf } | Should -Not -Throw
        }

        It "Should support development tools configuration" {
            { Optimize-PlatformEnvironment -ConfigureDevelopmentTools -WhatIf } | Should -Not -Throw
        }

        It "Should return optimization results" {
            $result = Optimize-PlatformEnvironment -WhatIf
            $result | Should -Not -BeNullOrEmpty
            $result.Platform | Should -Not -BeNullOrEmpty
            $result.OptimizationsApplied | Should -BeOfType [array]
        }
    }
}

Describe "Cross-Platform Compatibility" {
    Context "Path Handling" {
        It "Should handle paths correctly on current platform" {
            $testPath = Join-Path $script:ProjectRoot "aither-core"
            $testPath | Should -Exist
        }

        It "Should use platform-appropriate path separators" {
            $testPath = Join-Path "test" "path"
            if ($IsWindows) {
                $testPath | Should -Match '\\'
            } else {
                $testPath | Should -Match '/'
            }
        }
    }

    Context "Command Availability" {
        It "Should detect PowerShell correctly on all platforms" {
            $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
            if ($pwshCmd) {
                $pwshCmd.Name | Should -Be 'pwsh'
            }
        }

        It "Should handle platform-specific commands gracefully" {
            if ($IsWindows) {
                # Windows-specific tests
                { Get-Command winget -ErrorAction SilentlyContinue } | Should -Not -Throw
            } elseif ($IsLinux) {
                # Linux-specific tests
                { Get-Command apt -ErrorAction SilentlyContinue } | Should -Not -Throw
            } elseif ($IsMacOS) {
                # macOS-specific tests
                { Get-Command brew -ErrorAction SilentlyContinue } | Should -Not -Throw
            }
        }
    }
}

Describe "Error Handling and Resilience" {
    Context "Function Parameter Validation" {
        It "Should validate parameters correctly in Initialize-DevEnvironment" {
            { Initialize-DevEnvironment -WhatIf } | Should -Not -Throw
        }

        It "Should validate parameters correctly in Test-DevEnvironment" {
            { Test-DevEnvironment -WhatIf } | Should -Not -Throw
        }

        It "Should validate parameters correctly in Optimize-PlatformEnvironment" {
            { Optimize-PlatformEnvironment -Platform 'InvalidPlatform' -WhatIf } | Should -Throw
        }
    }

    Context "Graceful Degradation" {
        It "Should handle missing VS Code gracefully" {
            # This should not throw even if VS Code is not installed
            { Test-VSCodeIntegration } | Should -Not -Throw
        }

        It "Should handle missing Node.js gracefully" {
            # This should not throw even if Node.js is not installed
            { Install-ClaudeCodeDependencies -WhatIf } | Should -Not -Throw
        }

        It "Should handle missing Git gracefully" {
            # Test-DevEnvironment should not throw even if Git is missing
            { Test-DevEnvironment } | Should -Not -Throw
        }
    }
}

Describe "Integration with Other Modules" {
    Context "Logging Integration" {
        It "Should use Write-CustomLog function if available" {
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                # Functions should use Write-CustomLog for output
                { Get-DevEnvironmentStatus } | Should -Not -Throw
            }
        }

        It "Should have fallback logging if Logging module unavailable" {
            # Even without logging module, functions should work
            { Get-DevEnvironmentStatus } | Should -Not -Throw
        }
    }

    Context "AIToolsIntegration Module" {
        It "Should integrate with AIToolsIntegration if available" {
            if (Get-Module -Name AIToolsIntegration) {
                # Should be able to call AIToolsIntegration functions
                { Test-NodeJsPrerequisites } | Should -Not -Throw
            }
        }
    }
}

Describe "Performance and Resource Usage" {
    Context "Module Loading Performance" {
        It "Should load module in reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Import-Module $script:ModulePath -Force
            $stopwatch.Stop()

            # Module should load in under 5 seconds
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }
    }

    Context "Memory Usage" {
        It "Should not consume excessive memory" {
            $beforeMemory = [System.GC]::GetTotalMemory($false)

            # Perform various operations
            Get-DevEnvironmentStatus | Out-Null
            Test-DevEnvironment -WhatIf | Out-Null
            Test-VSCodeIntegration | Out-Null

            $afterMemory = [System.GC]::GetTotalMemory($false)
            $memoryIncrease = $afterMemory - $beforeMemory

            # Should not increase memory by more than 50MB
            $memoryIncrease | Should -BeLessThan (50MB)
        }
    }
}

Describe "Documentation and Help" {
    Context "Function Help" {
        $functions = @(
            'Initialize-DevEnvironment',
            'Get-DevEnvironmentStatus',
            'Test-DevEnvironment',
            'Initialize-VSCodeWorkspace',
            'Test-VSCodeIntegration',
            'Optimize-PlatformEnvironment'
        )

        foreach ($function in $functions) {
            It "Should have help documentation for $function" {
                $help = Get-Help $function
                $help.Synopsis | Should -Not -BeNullOrEmpty
                $help.Description | Should -Not -BeNullOrEmpty
            }

            It "Should have parameter documentation for $function" {
                $help = Get-Help $function -Detailed
                if ($help.Parameters.Parameter) {
                    foreach ($param in $help.Parameters.Parameter) {
                        $param.Description | Should -Not -BeNullOrEmpty
                    }
                }
            }

            It "Should have examples for $function" {
                $help = Get-Help $function -Examples
                $help.Examples | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "README Documentation" {
        It "Should have comprehensive README" {
            $readmePath = Join-Path $script:ModulePath "README.md"
            $readmeContent = Get-Content $readmePath -Raw

            $readmeContent | Should -Match "DevEnvironment Module"
            $readmeContent | Should -Match "Usage Examples"
            $readmeContent | Should -Match "Key Functions"
        }
    }
}
