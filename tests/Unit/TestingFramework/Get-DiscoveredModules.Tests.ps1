#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/TestingFramework'
    $script:ModuleName = 'TestingFramework'
    $script:FunctionName = 'Get-DiscoveredModules'
}

Describe 'TestingFramework.Get-DiscoveredModules' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock dependencies
        Mock Write-TestLog { } -ModuleName $script:ModuleName
        
        # Set up test directory structure
        $script:TestProjectRoot = Join-Path $TestDrive 'TestProject'
        $script:TestModulesPath = Join-Path $script:TestProjectRoot 'aither-core/modules'
        New-Item -Path $script:TestModulesPath -ItemType Directory -Force | Out-Null
        
        # Mock project root
        InModuleScope $script:ModuleName -ArgumentList $script:TestProjectRoot {
            param($root)
            $script:ProjectRoot = $root
        }
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    BeforeEach {
        # Clean test modules directory
        if (Test-Path $script:TestModulesPath) {
            Get-ChildItem $script:TestModulesPath | Remove-Item -Recurse -Force
        }
    }
    
    Context 'Module Discovery' {
        It 'Should return empty array when modules directory does not exist' {
            # Remove modules directory
            Remove-Item $script:TestModulesPath -Force -Recurse
            
            $result = Get-DiscoveredModules
            
            $result | Should -BeOfType [array]
            $result.Count | Should -Be 0
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Modules directory not found' -and
                $Level -eq 'WARN'
            }
        }
        
        It 'Should discover modules with .psm1 files' {
            # Create test modules
            $module1Path = Join-Path $script:TestModulesPath 'Module1'
            $module2Path = Join-Path $script:TestModulesPath 'Module2'
            
            New-Item -Path $module1Path -ItemType Directory -Force | Out-Null
            New-Item -Path $module2Path -ItemType Directory -Force | Out-Null
            
            'Module1 content' | Set-Content -Path "$module1Path\Module1.psm1"
            'Module2 content' | Set-Content -Path "$module2Path\Module2.psm1"
            
            $result = Get-DiscoveredModules
            
            $result.Count | Should -Be 2
            $result[0].Name | Should -BeIn @('Module1', 'Module2')
            $result[1].Name | Should -BeIn @('Module1', 'Module2')
        }
        
        It 'Should include module manifest path when .psd1 exists' {
            $modulePath = Join-Path $script:TestModulesPath 'TestModule'
            New-Item -Path $modulePath -ItemType Directory -Force | Out-Null
            
            'Module content' | Set-Content -Path "$modulePath\TestModule.psm1"
            '@{ ModuleVersion = "1.0" }' | Set-Content -Path "$modulePath\TestModule.psd1"
            
            $result = Get-DiscoveredModules
            
            $result.Count | Should -Be 1
            $result[0].ManifestPath | Should -Not -BeNullOrEmpty
            $result[0].ManifestPath | Should -Match 'TestModule\.psd1$'
        }
        
        It 'Should set ManifestPath to null when .psd1 does not exist' {
            $modulePath = Join-Path $script:TestModulesPath 'NoManifest'
            New-Item -Path $modulePath -ItemType Directory -Force | Out-Null
            
            'Module content' | Set-Content -Path "$modulePath\NoManifest.psm1"
            
            $result = Get-DiscoveredModules
            
            $result.Count | Should -Be 1
            $result[0].ManifestPath | Should -Be $null
        }
        
        It 'Should skip directories without .psm1 files' {
            $validModule = Join-Path $script:TestModulesPath 'ValidModule'
            $invalidModule = Join-Path $script:TestModulesPath 'InvalidModule'
            
            New-Item -Path $validModule -ItemType Directory -Force | Out-Null
            New-Item -Path $invalidModule -ItemType Directory -Force | Out-Null
            
            'Module content' | Set-Content -Path "$validModule\ValidModule.psm1"
            'Not a module' | Set-Content -Path "$invalidModule\SomeFile.txt"
            
            $result = Get-DiscoveredModules
            
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'ValidModule'
        }
        
        It 'Should include correct paths in module info' {
            $modulePath = Join-Path $script:TestModulesPath 'PathTest'
            New-Item -Path $modulePath -ItemType Directory -Force | Out-Null
            'Module content' | Set-Content -Path "$modulePath\PathTest.psm1"
            
            $result = Get-DiscoveredModules
            
            $result[0].Path | Should -Be $modulePath
            $result[0].ScriptPath | Should -Be "$modulePath\PathTest.psm1"
            $result[0].TestPath | Should -Match 'tests[/\\]unit[/\\]modules[/\\]PathTest$'
            $result[0].IntegrationTestPath | Should -Match 'tests[/\\]integration$'
        }
    }
    
    Context 'Module Filtering' {
        BeforeEach {
            # Create multiple test modules
            @('Module1', 'Module2', 'Module3') | ForEach-Object {
                $modPath = Join-Path $script:TestModulesPath $_
                New-Item -Path $modPath -ItemType Directory -Force | Out-Null
                "Module content" | Set-Content -Path "$modPath\$_.psm1"
            }
        }
        
        It 'Should return all modules when no filter specified' {
            $result = Get-DiscoveredModules
            
            $result.Count | Should -Be 3
        }
        
        It 'Should filter modules by specific names' {
            $result = Get-DiscoveredModules -SpecificModules @('Module1', 'Module3')
            
            $result.Count | Should -Be 2
            $result[0].Name | Should -BeIn @('Module1', 'Module3')
            $result[1].Name | Should -BeIn @('Module1', 'Module3')
        }
        
        It 'Should return empty array when specified modules do not exist' {
            $result = Get-DiscoveredModules -SpecificModules @('NonExistent')
            
            $result.Count | Should -Be 0
        }
        
        It 'Should handle empty specific modules array' {
            $result = Get-DiscoveredModules -SpecificModules @()
            
            $result.Count | Should -Be 3
        }
    }
    
    Context 'Logging' {
        It 'Should log each discovered module' {
            $modulePath = Join-Path $script:TestModulesPath 'LogTest'
            New-Item -Path $modulePath -ItemType Directory -Force | Out-Null
            'Module content' | Set-Content -Path "$modulePath\LogTest.psm1"
            
            Get-DiscoveredModules
            
            Should -Invoke Write-TestLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match 'Discovered module: LogTest' -and
                $Level -eq 'INFO'
            }
        }
    }
    
    Context 'Edge Cases' {
        It 'Should handle module names with special characters' {
            $specialModule = Join-Path $script:TestModulesPath 'Module-With-Dashes'
            New-Item -Path $specialModule -ItemType Directory -Force | Out-Null
            'Module content' | Set-Content -Path "$specialModule\Module-With-Dashes.psm1"
            
            $result = Get-DiscoveredModules
            
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'Module-With-Dashes'
        }
        
        It 'Should handle nested directories' {
            $nestedPath = Join-Path $script:TestModulesPath 'Parent/Child'
            New-Item -Path $nestedPath -ItemType Directory -Force | Out-Null
            'Not a module' | Set-Content -Path "$nestedPath\file.txt"
            
            $modulePath = Join-Path $script:TestModulesPath 'ActualModule'
            New-Item -Path $modulePath -ItemType Directory -Force | Out-Null
            'Module content' | Set-Content -Path "$modulePath\ActualModule.psm1"
            
            $result = Get-DiscoveredModules
            
            # Should only find the actual module, not nested directories
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'ActualModule'
        }
        
        It 'Should handle case sensitivity in module filtering' {
            $modulePath = Join-Path $script:TestModulesPath 'CaseSensitive'
            New-Item -Path $modulePath -ItemType Directory -Force | Out-Null
            'Module content' | Set-Content -Path "$modulePath\CaseSensitive.psm1"
            
            # Test with different case
            $result = Get-DiscoveredModules -SpecificModules @('CASESENSITIVE')
            
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'CaseSensitive'
        }
    }
}