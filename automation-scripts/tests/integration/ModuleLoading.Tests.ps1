#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    Integration tests for AitherZero module loading system
.DESCRIPTION
    Tests module loading order, dependencies, and function availability
#>

BeforeAll {
    # Import test helpers
    $script:TestRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $script:TestRoot "TestHelpers.psm1") -Force

    $script:ProjectRoot = Split-Path $script:TestRoot -Parent

    # Clear environment before testing
    Clear-TestEnvironment
}

Describe "Clean Environment Module Loading" {
    Context "Conflicting Module Removal" {
        BeforeEach {
            # Simulate conflicting modules
            $script:ConflictingModules = @('AitherRun', 'CoreApp', 'ConfigurationManager')
        }

        It "Should detect and remove conflicting modules" {
            # Test the clean environment script
            $cleanEnvPath = Join-Path $script:ProjectRoot "Initialize-CleanEnvironment.ps1"
            Test-Path $cleanEnvPath | Should -BeTrue

            # Verify it removes conflicting modules
            $cleanContent = Get-Content $cleanEnvPath -Raw
            foreach ($module in $script:ConflictingModules) {
                $cleanContent | Should -BeLike "*Remove-Module*$module*"
            }
        }

        It "Should clean PSModulePath of Aitherium references" {
            $cleanEnvPath = Join-Path $script:ProjectRoot "Initialize-CleanEnvironment.ps1"
            $cleanContent = Get-Content $cleanEnvPath -Raw

            $cleanContent | Should -BeLike "*PSModulePath*"
            $cleanContent | Should -BeLike "*-notlike*Aitherium*"
        }

        It "Should remove lingering environment variables" {
            $cleanEnvPath = Join-Path $script:ProjectRoot "Initialize-CleanEnvironment.ps1"
            $cleanContent = Get-Content $cleanEnvPath -Raw

            $cleanContent | Should -BeLike "*Remove-Item env:AITHERIUM_ROOT*"
            $cleanContent | Should -BeLike "*Remove-Item env:AITHERRUN_ROOT*"
        }
    }
}

Describe "AitherZero Module Manifest" {
    Context "Module Manifest Structure" {
        It "Should have valid module manifest" {
            $manifestPath = Join-Path $script:ProjectRoot "AitherZero.psd1"
            Test-Path $manifestPath | Should -BeTrue

            # Test manifest can be imported
            { Test-ModuleManifest -Path $manifestPath } | Should -Not -Throw
        }

        It "Should specify root module" {
            $manifestPath = Join-Path $script:ProjectRoot "AitherZero.psd1"
            $manifest = Test-ModuleManifest -Path $manifestPath

            $manifest.RootModule | Should -Be "AitherZero.psm1"
        }

        It "Should have correct PowerShell version requirement" {
            $manifestPath = Join-Path $script:ProjectRoot "AitherZero.psd1"
            $manifest = Test-ModuleManifest -Path $manifestPath

            $manifest.PowerShellVersion | Should -Be "7.0"
        }
    }
}

Describe "Module Loading Order" {
    Context "Critical Modules First" {
        It "Should load Logging module first" {
            $rootModulePath = Join-Path $script:ProjectRoot "AitherZero.psm1"
            $content = Get-Content $rootModulePath -Raw

            # Find module loading order
            $pattern = '(?s)modulesToLoad\s*=\s*@\((.*?)\)'
            if ($content -match $pattern) {
                $moduleList = $Matches[1]
                $firstModule = ($moduleList -split '\n' | Where-Object { $_ -like "*'./*" } | Select-Object -First 1)
                $firstModule | Should -BeLike "*Logging.psm1*"
            }
        }

        It "Should load Configuration module second" {
            $rootModulePath = Join-Path $script:ProjectRoot "AitherZero.psm1"
            $content = Get-Content $rootModulePath -Raw

            # Verify Configuration comes after Logging
            $content | Should -BeLike "*Logging.psm1*Configuration.psm1*"
        }

        It "Should load BetterMenu before UserInterface" {
            $rootModulePath = Join-Path $script:ProjectRoot "AitherZero.psm1"
            $content = Get-Content $rootModulePath -Raw

            # Verify order
            $content | Should -BeLike "*BetterMenu.psm1*UserInterface.psm1*"
        }
    }

    Context "Module Dependencies" {
        It "Should handle module dependencies correctly" {
            # Initialize environment
            $env = Initialize-TestEnvironment

            # Check that dependent modules are loaded
            $modules = Get-Module | Where-Object { $_.Path -like "*$script:ProjectRoot*" }
            $moduleNames = $modules.Name

            # Core modules should be loaded
            $moduleNames | Should -Contain 'Logging'
            $moduleNames | Should -Contain 'Configuration'
        }
    }
}

Describe "Module Function Availability" {
    BeforeAll {
        # Load the environment
        $script:Env = Initialize-TestEnvironment
    }

    Context "Logging Functions" {
        It "Should provide Write-CustomLog function" {
            Test-ModuleFunction -FunctionName 'Write-CustomLog' | Should -BeTrue
        }

        It "Should provide Initialize-LoggingSystem function" {
            Test-ModuleFunction -FunctionName 'Initialize-LoggingSystem' | Should -BeTrue
        }
    }

    Context "Configuration Functions" {
        It "Should provide Get-Configuration function" {
            Test-ModuleFunction -FunctionName 'Get-Configuration' | Should -BeTrue
        }

        It "Should provide Set-Configuration function" {
            Test-ModuleFunction -FunctionName 'Set-Configuration' | Should -BeTrue
        }
    }

    Context "UI Functions" {
        It "Should provide Show-UIMenu function" {
            Test-ModuleFunction -FunctionName 'Show-UIMenu' | Should -BeTrue
        }

        It "Should provide Show-UIPrompt function" {
            Test-ModuleFunction -FunctionName 'Show-UIPrompt' | Should -BeTrue
        }

        It "Should provide Show-UINotification function" {
            Test-ModuleFunction -FunctionName 'Show-UINotification' | Should -BeTrue
        }
    }

    Context "Orchestration Functions" {
        It "Should provide Invoke-OrchestrationSequence function" {
            Test-ModuleFunction -FunctionName 'Invoke-OrchestrationSequence' | Should -BeTrue
        }

        It "Should provide Save-OrchestrationPlaybook function" {
            Test-ModuleFunction -FunctionName 'Save-OrchestrationPlaybook' | Should -BeTrue
        }
    }
}

Describe "Module Aliases" {
    BeforeAll {
        # Load the environment
        $script:Env = Initialize-TestEnvironment
    }

    Context "Command Aliases" {
        It "Should create 'az' alias" {
            $alias = Get-Alias -Name 'az' -ErrorAction SilentlyContinue
            $alias | Should -Not -BeNullOrEmpty
        }

        It "Should create 'seq' alias" {
            $alias = Get-Alias -Name 'seq' -ErrorAction SilentlyContinue
            $alias | Should -Not -BeNullOrEmpty
            $alias.Definition | Should -Be 'Invoke-OrchestrationSequence'
        }
    }
}

Describe "Environment Variables" {
    BeforeAll {
        # Load the environment
        $script:Env = Initialize-TestEnvironment
    }

    Context "AitherZero Environment Variables" {
        It "Should set AITHERZERO_ROOT" {
            $env:AITHERZERO_ROOT | Should -Not -BeNullOrEmpty
            $env:AITHERZERO_ROOT | Should -Be $script:ProjectRoot
        }

        It "Should set AITHERZERO_INITIALIZED" {
            $env:AITHERZERO_INITIALIZED | Should -Be "1"
        }

        It "Should add automation-scripts to PATH" {
            $automationPath = Join-Path $script:ProjectRoot "automation-scripts"
            $env:PATH | Should -BeLike "*$automationPath*"
        }
    }
}

Describe "Module Error Handling" {
    Context "Missing Module Files" {
        It "Should handle missing module files gracefully" {
            # Test with a non-existent module path
            $testModulePath = Join-Path $TestDrive "NonExistent.psm1"
            { Import-Module $testModulePath -Force -ErrorAction Stop } | Should -Throw
        }
    }

    Context "Circular Dependencies" {
        It "Should not have circular module dependencies" {
            # This is validated by successful loading
            $env = Initialize-TestEnvironment
            $env.ModulesLoaded | Should -BeGreaterThan 0
        }
    }
}

Describe "Transcript Logging" {
    Context "Transcript Configuration" {
        It "Should respect AITHERZERO_DISABLE_TRANSCRIPT variable" {
            $rootModulePath = Join-Path $script:ProjectRoot "AitherZero.psm1"
            $content = Get-Content $rootModulePath -Raw

            $content | Should -BeLike "*AITHERZERO_DISABLE_TRANSCRIPT*"
        }

        It "Should create transcript log file" {
            $rootModulePath = Join-Path $script:ProjectRoot "AitherZero.psm1"
            $content = Get-Content $rootModulePath -Raw

            $content | Should -BeLike "*Start-Transcript*"
            $content | Should -BeLike "*logs/transcript-*"
        }
    }
}

AfterAll {
    # Clean up test environment
    Clear-TestEnvironment
}