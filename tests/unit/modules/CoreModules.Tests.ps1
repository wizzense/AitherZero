BeforeAll {
    $projectRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
    $modulesPath = Join-Path $projectRoot "aither-core/modules"
}

Describe "Core Modules Loading Tests" {
    Context "Module Directory Structure" {
        It "Should have modules directory" {
            $modulesPath | Should -Exist
        }
        
        It "Should contain expected core modules" {
            $expectedModules = @(
                'BackupManager',
                'DevEnvironment', 
                'ISOCustomizer',
                'ISOManager',
                'LabRunner',
                'Logging',
                'OpenTofuProvider',
                'ParallelExecution',
                'PatchManager',
                'RemoteConnection',
                'ScriptManager',
                'SecureCredentials',
                'TestingFramework',
                'UnifiedMaintenance'
            )
            
            foreach ($module in $expectedModules) {
                $modulePath = Join-Path $modulesPath $module
                $modulePath | Should -Exist -Because "Module $module should exist"
            }
        }
    }
    
    Context "Module Files Structure" {
        It "Should have proper .psd1 and .psm1 files for each module" {
            $moduleNames = Get-ChildItem $modulesPath -Directory | Where-Object { $_.Name -ne 'packages-microsoft-prod.deb' }
            
            foreach ($moduleDir in $moduleNames) {
                $psd1Path = Join-Path $moduleDir.FullName "$($moduleDir.Name).psd1"
                $psm1Path = Join-Path $moduleDir.FullName "$($moduleDir.Name).psm1"
                
                $psd1Path | Should -Exist -Because "Module $($moduleDir.Name) should have manifest file"
                $psm1Path | Should -Exist -Because "Module $($moduleDir.Name) should have module file"
            }
        }
    }
    
    Context "Module Loading Performance" {
        It "Should load modules within reasonable time" {
            $startTime = Get-Date
            
            # Test loading a few key modules
            $testModules = @('Logging', 'ParallelExecution', 'BackupManager')
            
            foreach ($module in $testModules) {
                $modulePath = Join-Path $modulesPath $module
                { Import-Module $modulePath -Force } | Should -Not -Throw
            }
            
            $elapsed = (Get-Date) - $startTime
            $elapsed.TotalSeconds | Should -BeLessThan 10 -Because "Module loading should be fast"
        }
    }
}