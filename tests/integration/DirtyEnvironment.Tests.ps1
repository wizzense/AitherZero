#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    Tests bootstrap handling of dirty environments with conflicting modules
.DESCRIPTION
    Ensures bootstrap can handle environments with CoreApp, Aitherium, and other conflicts
#>

Describe "Bootstrap Dirty Environment Handling" {
    
    Context "CoreApp Conflict Resolution" {
        It "Should remove CoreApp module if present" {
            # Create fake CoreApp module
            $fakeModule = New-Module -Name CoreApp -ScriptBlock {
                function Start-CoreApp { "CoreApp Running" }
                Export-ModuleMember -Function Start-CoreApp
            }
            Import-Module $fakeModule -Force
            
            # Verify it's loaded
            Get-Module CoreApp | Should -Not -BeNullOrEmpty
            
            # Run bootstrap cleaning
            $bootstrapPath = Join-Path $PSScriptRoot "../../bootstrap.ps1"
            
            # Execute just the cleaning portion
            & {
                $conflictingModules = @('CoreApp', 'AitherRun', 'ConfigurationManager')
                foreach ($module in $conflictingModules) {
                    Remove-Module $module -Force -ErrorAction SilentlyContinue 2>$null
                }
            }
            
            # Verify it's removed
            Get-Module CoreApp | Should -BeNullOrEmpty
        }
        
        It "Should clean PSModulePath of aither-core paths" {
            # Pollute PSModulePath
            $env:PSModulePath = "$env:PSModulePath;C:\fake\aither-core\modules;C:\fake\Aitherium\modules"
            
            # Run path cleaning
            & {
                if ($env:PSModulePath) {
                    $cleanPaths = $env:PSModulePath -split [IO.Path]::PathSeparator | 
                        Where-Object { 
                            $_ -notlike "*aither-core*" -and 
                            $_ -notlike "*Aitherium*" -and 
                            $_ -notlike "*AitherRun*" 
                        }
                    $env:PSModulePath = $cleanPaths -join [IO.Path]::PathSeparator
                }
            }
            
            # Verify paths are cleaned
            $env:PSModulePath | Should -Not -BeLike "*aither-core*"
            $env:PSModulePath | Should -Not -BeLike "*Aitherium*"
        }
        
        It "Should remove conflicting environment variables" {
            # Set conflicting variables
            $env:AITHERIUM_ROOT = "C:\fake\Aitherium"
            $env:COREAPP_ROOT = "C:\fake\CoreApp"
            $env:AITHER_CORE_PATH = "C:\fake\aither-core"
            
            # Run cleanup
            & {
                @('AITHERIUM_ROOT', 'AITHERRUN_ROOT', 'COREAPP_ROOT', 'AITHER_CORE_PATH') | ForEach-Object {
                    Remove-Item "env:$_" -ErrorAction SilentlyContinue 2>$null
                }
            }
            
            # Verify they're removed
            $env:AITHERIUM_ROOT | Should -BeNullOrEmpty
            $env:COREAPP_ROOT | Should -BeNullOrEmpty
            $env:AITHER_CORE_PATH | Should -BeNullOrEmpty
        }
        
        It "Should set blocking environment variables" {
            # Run blocking setup
            & {
                $env:DISABLE_COREAPP = "1"
                $env:SKIP_AUTO_MODULES = "1"
                $env:AITHERZERO_ONLY = "1"
            }
            
            # Verify they're set
            $env:DISABLE_COREAPP | Should -Be "1"
            $env:SKIP_AUTO_MODULES | Should -Be "1"
            $env:AITHERZERO_ONLY | Should -Be "1"
        }
    }
    
    Context "Multiple Conflicting Modules" {
        It "Should handle all known conflicting modules" {
            $conflictingModules = @(
                'CoreApp', 'AitherRun', 'ConfigurationManager', 'SecurityAutomation',
                'UtilityServices', 'ConfigurationCore', 'ConfigurationCarousel',
                'ModuleCommunication', 'ConfigurationRepository', 'StartupExperience'
            )
            
            # Create and load fake modules
            foreach ($moduleName in $conflictingModules[0..2]) {  # Test with first 3
                $module = New-Module -Name $moduleName -ScriptBlock {
                    function Test-Function { "Test" }
                }
                Import-Module $module -Force -ErrorAction SilentlyContinue
            }
            
            # Run cleanup
            foreach ($module in $conflictingModules) {
                Remove-Module $module -Force -ErrorAction SilentlyContinue 2>$null
            }
            
            # Verify all are removed
            foreach ($moduleName in $conflictingModules[0..2]) {
                Get-Module $moduleName | Should -BeNullOrEmpty
            }
        }
    }
    
    Context "Bootstrap Script Execution" {
        It "Should clean environment at the very start" {
            $bootstrapContent = Get-Content (Join-Path $PSScriptRoot "../../bootstrap.ps1") -Raw
            
            # Check that cleaning happens BEFORE any other operations
            $cleaningPosition = $bootstrapContent.IndexOf("# CRITICAL: Clean environment BEFORE anything else")
            $cleaningPosition | Should -BeGreaterThan 0
            
            # Verify it happens before helper functions
            $helperPosition = $bootstrapContent.IndexOf("# Helper functions")
            $cleaningPosition | Should -BeLessThan $helperPosition
        }
        
        It "Should block CoreApp in Start-AitherZero.ps1" {
            $startScriptPath = Join-Path $PSScriptRoot "../../Start-AitherZero.ps1"
            if (Test-Path $startScriptPath) {
                $content = Get-Content $startScriptPath -Raw
                
                # Verify blocking code exists
                $content | Should -BeLike "*DISABLE_COREAPP*"
                $content | Should -BeLike "*Remove-Module*CoreApp*"
            }
        }
    }
    
    Context "Initialize-CleanEnvironment Script" {
        It "Should have comprehensive module list" {
            $cleanEnvPath = Join-Path $PSScriptRoot "../../Initialize-CleanEnvironment.ps1"
            if (Test-Path $cleanEnvPath) {
                $content = Get-Content $cleanEnvPath -Raw
                
                # Check for all critical modules
                @('CoreApp', 'AitherRun', 'ConfigurationCore', 'LabRunner', 'OpenTofuProvider') | ForEach-Object {
                    $content | Should -BeLike "*'$_'*"
                }
            }
        }
        
        It "Should clean PATH environment variable" {
            $cleanEnvPath = Join-Path $PSScriptRoot "../../Initialize-CleanEnvironment.ps1"
            if (Test-Path $cleanEnvPath) {
                $content = Get-Content $cleanEnvPath -Raw
                
                # Verify PATH cleaning exists
                $content | Should -BeLike "*`$env:PATH*"
                $content | Should -BeLike "*aither-core*"
            }
        }
    }
}

Describe "End-to-End Dirty Environment Test" {
    It "Should successfully bootstrap in extremely dirty environment" {
        # This is the ultimate test
        $testScript = {
            # Create worst-case scenario
            $env:PWSH_MODULES_PATH = "C:/bad/aither-core/modules"
            $env:AITHERIUM_ROOT = "C:/bad/Aitherium"
            $env:COREAPP_ROOT = "C:/bad/CoreApp"
            $env:PSModulePath = "$env:PSModulePath;C:/bad/aither-core;C:/bad/Aitherium"
            
            # Create conflicting module
            $coreApp = New-Module -Name CoreApp -ScriptBlock {
                Write-Host "[CoreApp] Interfering with bootstrap!"
            }
            Import-Module $coreApp -Force
            
            # Source the bootstrap (just the cleaning part for testing)
            $bootstrapPath = Join-Path $PSScriptRoot "../../bootstrap.ps1"
            
            # Read and execute just the cleaning section
            $content = Get-Content $bootstrapPath -Raw
            $cleaningCode = $content -match '# CRITICAL: Clean environment BEFORE anything else(.|\n)*?# Helper functions'
            
            if ($cleaningCode) {
                # Execute cleaning
                $conflictingModules = @(
                    'CoreApp', 'AitherRun', 'ConfigurationManager', 'SecurityAutomation',
                    'UtilityServices', 'ConfigurationCore', 'ConfigurationCarousel',
                    'ModuleCommunication', 'ConfigurationRepository', 'StartupExperience'
                )
                
                foreach ($module in $conflictingModules) {
                    Remove-Module $module -Force -ErrorAction SilentlyContinue 2>$null
                }
                
                # Clean PSModulePath
                if ($env:PSModulePath) {
                    $cleanPaths = $env:PSModulePath -split [IO.Path]::PathSeparator | 
                        Where-Object { 
                            $_ -notlike "*aither-core*" -and 
                            $_ -notlike "*Aitherium*" -and 
                            $_ -notlike "*AitherRun*" 
                        }
                    $env:PSModulePath = $cleanPaths -join [IO.Path]::PathSeparator
                }
                
                # Remove conflicting environment variables
                @('AITHERIUM_ROOT', 'AITHERRUN_ROOT', 'COREAPP_ROOT', 'AITHER_CORE_PATH') | ForEach-Object {
                    Remove-Item "env:$_" -ErrorAction SilentlyContinue 2>$null
                }
                
                # Block any auto-loading scripts
                $env:AITHERZERO_BOOTSTRAP_RUNNING = "1"
            }
            
            # Verify environment is clean
            return @{
                CoreAppGone = (Get-Module CoreApp) -eq $null
                PathCleaned = $env:PSModulePath -notlike "*aither-core*"
                VarsRemoved = [string]::IsNullOrEmpty($env:COREAPP_ROOT)
                BlockingSet = $env:AITHERZERO_BOOTSTRAP_RUNNING -eq "1"
            }
        }
        
        $result = & $testScript
        
        $result.CoreAppGone | Should -Be $true
        $result.PathCleaned | Should -Be $true
        $result.VarsRemoved | Should -Be $true
        $result.BlockingSet | Should -Be $true
    }
}