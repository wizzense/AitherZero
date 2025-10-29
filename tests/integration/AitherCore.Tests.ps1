#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    Pester tests for AitherCore module
.DESCRIPTION
    Validates that AitherCore loads correctly and all essential functions are available
#>

BeforeAll {
    # Get the project root
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:AitherCorePath = Join-Path $script:ProjectRoot "aithercore"
    $script:ManifestPath = Join-Path $script:AitherCorePath "AitherCore.psd1"
    
    # Import the module
    Import-Module $script:ManifestPath -Force -ErrorAction Stop
}

AfterAll {
    # Clean up
    Remove-Module AitherCore -Force -ErrorAction SilentlyContinue
}

Describe 'AitherCore Module' {
    
    Context 'Module Loading' {
        It 'Should load the AitherCore module' {
            $module = Get-Module -Name AitherCore
            $module | Should -Not -BeNullOrEmpty
        }
        
        It 'Should have the correct version' {
            $module = Get-Module -Name AitherCore
            $module.Version.ToString() | Should -Be '1.0.0.0'
        }
        
        It 'Should export functions' {
            $commands = Get-Command -Module AitherCore
            $commands | Should -Not -BeNullOrEmpty
            $commands.Count | Should -BeGreaterThan 10
        }
    }
    
    Context 'Logging Functions' {
        It 'Should export Write-CustomLog' {
            Get-Command -Name Write-CustomLog -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Initialize-Logging' {
            Get-Command -Name Initialize-Logging -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Write-AuditLog' {
            Get-Command -Name Write-AuditLog -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Get-Logs' {
            Get-Command -Name Get-Logs -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Configuration Functions' {
        It 'Should export Get-Configuration' {
            Get-Command -Name Get-Configuration -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Set-Configuration' {
            Get-Command -Name Set-Configuration -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Get-ConfigValue' {
            Get-Command -Name Get-ConfigValue -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Initialize-ConfigurationSystem' {
            Get-Command -Name Initialize-ConfigurationSystem -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'UI Functions' {
        It 'Should export Show-BetterMenu' {
            Get-Command -Name Show-BetterMenu -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Show-UIMenu' {
            Get-Command -Name Show-UIMenu -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Show-UIProgress' {
            Get-Command -Name Show-UIProgress -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Initialize-AitherUI' {
            Get-Command -Name Initialize-AitherUI -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Write-UIText' {
            Get-Command -Name Write-UIText -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Infrastructure Functions' {
        It 'Should export Test-OpenTofu' {
            Get-Command -Name Test-OpenTofu -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Get-InfrastructureTool' {
            Get-Command -Name Get-InfrastructureTool -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Security Functions' {
        It 'Should export Invoke-SSHCommand' {
            Get-Command -Name Invoke-SSHCommand -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Test-SSHConnection' {
            Get-Command -Name Test-SSHConnection -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Orchestration Functions' {
        It 'Should export Invoke-OrchestrationSequence' {
            Get-Command -Name Invoke-OrchestrationSequence -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Get-OrchestrationPlaybook' {
            Get-Command -Name Get-OrchestrationPlaybook -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export Save-OrchestrationPlaybook' {
            Get-Command -Name Save-OrchestrationPlaybook -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Utility Functions' {
        It 'Should export Repair-TextSpacing' {
            Get-Command -Name Repair-TextSpacing -Module AitherCore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Module Dependencies' {
        It 'Should have all required module files in aithercore directory' {
            $requiredFiles = @(
                'Logging.psm1',
                'Configuration.psm1',
                'TextUtilities.psm1',
                'BetterMenu.psm1',
                'UserInterface.psm1',
                'Infrastructure.psm1',
                'Security.psm1',
                'OrchestrationEngine.psm1'
            )
            
            foreach ($file in $requiredFiles) {
                $filePath = Join-Path $script:AitherCorePath $file
                Test-Path $filePath | Should -Be $true -Because "$file should exist in aithercore"
            }
        }
        
        It 'Should have AitherCore.psm1 loader' {
            $loaderPath = Join-Path $script:AitherCorePath "AitherCore.psm1"
            Test-Path $loaderPath | Should -Be $true
        }
        
        It 'Should have AitherCore.psd1 manifest' {
            Test-Path $script:ManifestPath | Should -Be $true
        }
        
        It 'Should have README.md documentation' {
            $readmePath = Join-Path $script:AitherCorePath "README.md"
            Test-Path $readmePath | Should -Be $true
        }
    }
    
    Context 'Functional Tests' {
        It 'Should be able to write a log message' {
            { Write-CustomLog -Message "Test message" -Level 'Information' -Source "Test" } | Should -Not -Throw
        }
        
        It 'Should be able to get configuration' {
            # Configuration may not be initialized, so just test the function exists and doesn't crash
            { $config = Get-Configuration -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
        
        It 'Should be able to test infrastructure tools' {
            { $result = Test-OpenTofu -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

Describe 'AitherCore vs Full AitherZero' {
    Context 'Module Comparison' {
        It 'Should be a subset of full AitherZero functionality' {
            # This test verifies that AitherCore provides essential functions
            # while AitherZero provides the complete set
            
            $aitherCoreCommands = (Get-Command -Module AitherCore).Count
            $aitherCoreCommands | Should -BeGreaterThan 20 -Because "AitherCore should provide at least 20+ essential functions"
        }
        
        It 'Should include all critical foundation functions' {
            $criticalFunctions = @(
                'Write-CustomLog',
                'Get-Configuration',
                'Show-UIMenu',
                'Test-OpenTofu',
                'Invoke-OrchestrationSequence'
            )
            
            foreach ($func in $criticalFunctions) {
                Get-Command -Name $func -Module AitherCore -ErrorAction SilentlyContinue | 
                    Should -Not -BeNullOrEmpty -Because "$func is a critical function"
            }
        }
    }
}
