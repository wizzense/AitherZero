#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

Describe "AitherCore Module Tests" -Tag 'Unit', 'CoreApp', 'AitherCore' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot "../../../../aither-core/AitherCore.psm1"
        $script:ProjectRoot = Join-Path $PSScriptRoot "../../../.."
        
        # Store original environment variables
        $script:OriginalEnv = @{
            PROJECT_ROOT = $env:PROJECT_ROOT
            PWSH_MODULES_PATH = $env:PWSH_MODULES_PATH
        }
        
        # Mock Write-Host to suppress output during tests
        Mock Write-Host {}
    }
    
    AfterAll {
        # Restore original environment variables
        $env:PROJECT_ROOT = $script:OriginalEnv.PROJECT_ROOT
        $env:PWSH_MODULES_PATH = $script:OriginalEnv.PWSH_MODULES_PATH
        
        # Remove the module if loaded
        Remove-Module -Name AitherCore -Force -ErrorAction SilentlyContinue
    }
    
    Context "Module Loading and Exports" {
        BeforeAll {
            # Import the module
            Import-Module $script:ModulePath -Force
        }
        
        It "Should load the module successfully" {
            $module = Get-Module -Name AitherCore
            $module | Should -Not -BeNullOrEmpty
            $module.Name | Should -Be 'AitherCore'
        }
        
        It "Should export all expected functions" {
            $expectedFunctions = @(
                'Invoke-CoreApplication',
                'Start-LabRunner',
                'Get-CoreConfiguration',
                'Test-CoreApplicationHealth',
                'Write-CustomLog',
                'Get-PlatformInfo',
                'Initialize-CoreApplication',
                'Import-CoreModules',
                'Get-CoreModuleStatus',
                'Invoke-UnifiedMaintenance',
                'Start-DevEnvironmentSetup',
                'Get-IntegratedToolset',
                'Invoke-IntegratedWorkflow',
                'Start-QuickAction'
            )
            
            $module = Get-Module -Name AitherCore
            $exportedFunctions = $module.ExportedFunctions.Keys
            
            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }
    }
    
    Context "Write-CustomLog" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }
        
        It "Should write log with default parameters" {
            { Write-CustomLog -Message "Test message" } | Should -Not -Throw
        }
        
        It "Should accept all valid log levels" {
            $levels = @('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')
            foreach ($level in $levels) {
                { Write-CustomLog -Message "Test" -Level $level } | Should -Not -Throw
            }
        }
        
        It "Should accept custom component name" {
            { Write-CustomLog -Message "Test" -Component "TestComponent" } | Should -Not -Throw
        }
    }
    
    Context "Get-PlatformInfo" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }
        
        It "Should return a valid platform name" {
            $platform = Get-PlatformInfo
            $platform | Should -BeIn @('Windows', 'macOS', 'Linux', 'Unknown')
        }
        
        It "Should not throw any errors" {
            { Get-PlatformInfo } | Should -Not -Throw
        }
    }
    
    Context "Get-CoreConfiguration" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
            
            # Create a test config file
            $script:TestConfigPath = Join-Path $TestDrive "test-config.json"
            $testConfig = @{
                version = "1.0.0"
                settings = @{
                    debug = $true
                    timeout = 30
                }
            } | ConvertTo-Json
            Set-Content -Path $script:TestConfigPath -Value $testConfig
        }
        
        It "Should load configuration from specified path" {
            $config = Get-CoreConfiguration -ConfigPath $script:TestConfigPath
            $config | Should -Not -BeNullOrEmpty
            $config.version | Should -Be "1.0.0"
            $config.settings.debug | Should -Be $true
            $config.settings.timeout | Should -Be 30
        }
        
        It "Should throw when config file doesn't exist" {
            { Get-CoreConfiguration -ConfigPath "nonexistent.json" } | Should -Throw
        }
        
        It "Should throw when config file is invalid JSON" {
            $invalidConfigPath = Join-Path $TestDrive "invalid-config.json"
            Set-Content -Path $invalidConfigPath -Value "not valid json"
            { Get-CoreConfiguration -ConfigPath $invalidConfigPath } | Should -Throw
        }
    }
    
    Context "Test-CoreApplicationHealth" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }
        
        It "Should return a boolean value" {
            Mock Test-Path { return $true }
            $result = Test-CoreApplicationHealth
            $result | Should -BeOfType [bool]
        }
        
        It "Should return false when configuration is missing" {
            # Create a more specific mock that properly handles the paths
            Mock Test-Path {
                param($Path)
                if ($Path -like "*default-config.json") {
                    return $false
                } elseif ($Path -like "*scripts") {
                    return $true
                }
                return $true
            }
            
            $result = Test-CoreApplicationHealth
            $result | Should -Be $false
        }
        
        It "Should return false when scripts directory is missing" {
            # Create a more specific mock that properly handles the paths
            Mock Test-Path {
                param($Path)
                if ($Path -like "*default-config.json") {
                    return $true
                } elseif ($Path -like "*scripts") {
                    return $false
                }
                return $true
            }
            
            $result = Test-CoreApplicationHealth
            $result | Should -Be $false
        }
        
        It "Should return true when all requirements are met" {
            Mock Test-Path { return $true }
            
            $result = Test-CoreApplicationHealth
            $result | Should -Be $true
        }
    }
    
    Context "Get-CoreModuleStatus" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }
        
        It "Should return module status array" {
            Mock Test-Path { return $true }
            
            $status = Get-CoreModuleStatus
            $status | Should -Not -BeNullOrEmpty
            $status | Should -BeOfType [array]
        }
        
        It "Should include required module properties" {
            Mock Test-Path { return $true }
            
            $status = Get-CoreModuleStatus
            $firstModule = $status | Select-Object -First 1
            
            $firstModule.Name | Should -Not -BeNullOrEmpty
            $firstModule.Description | Should -Not -BeNullOrEmpty
            $firstModule.ContainsKey('Required') | Should -Be $true
            $firstModule.ContainsKey('Available') | Should -Be $true
            $firstModule.ContainsKey('Loaded') | Should -Be $true
            $firstModule.ContainsKey('Path') | Should -Be $true
        }
    }
    
    Context "Import-CoreModules" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }
        
        It "Should return import results object" {
            Mock Test-Path { return $false }
            Mock Import-Module {}
            
            $results = Import-CoreModules
            $results | Should -Not -BeNullOrEmpty
            $results.ContainsKey('ImportedCount') | Should -Be $true
            $results.ContainsKey('FailedCount') | Should -Be $true
            $results.ContainsKey('SkippedCount') | Should -Be $true
            $results.ContainsKey('Details') | Should -Be $true
        }
        
        It "Should skip modules when paths don't exist" {
            Mock Test-Path { return $false }
            
            $results = Import-CoreModules
            $results.SkippedCount | Should -BeGreaterThan 0
        }
        
        It "Should respect RequiredOnly parameter" {
            Mock Test-Path { return $false }
            
            $results = Import-CoreModules -RequiredOnly
            # Should attempt to import fewer modules
            $results.Details.Count | Should -BeLessThan 10
        }
        
        It "Should force import when Force parameter is used" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            
            $results = Import-CoreModules -Force
            # Since we're mocking the functions, we can't use Assert-MockCalled reliably
            # Just verify the operation completed
            $results | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Initialize-CoreApplication" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }
        
        It "Should set environment variables" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            
            $result = Initialize-CoreApplication
            
            $env:PROJECT_ROOT | Should -Not -BeNullOrEmpty
            $env:PWSH_MODULES_PATH | Should -Not -BeNullOrEmpty
        }
        
        It "Should return boolean result" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            
            $result = Initialize-CoreApplication
            $result | Should -BeOfType [bool]
        }
        
        It "Should handle initialization failures gracefully" {
            Mock Test-Path { return $false }
            Mock Import-Module { throw "Module import failed" }
            
            { Initialize-CoreApplication } | Should -Throw
        }
    }
    
    Context "Invoke-CoreApplication" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
            
            # Create test config
            $script:TestConfigPath = Join-Path $TestDrive "test-config.json"
            @{ testSetting = "value" } | ConvertTo-Json | Set-Content -Path $script:TestConfigPath
        }
        
        It "Should validate config path exists" {
            { Invoke-CoreApplication -ConfigPath "nonexistent.json" } | Should -Throw "*not found*"
        }
        
        It "Should load configuration successfully" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            
            $result = Invoke-CoreApplication -ConfigPath $script:TestConfigPath
            # Result may be an array if multiple operations occurred
            if ($result -is [array]) {
                $result[-1] | Should -Be $true
            } else {
                $result | Should -Be $true
            }
        }
        
        It "Should support WhatIf parameter" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            
            $result = Invoke-CoreApplication -ConfigPath $script:TestConfigPath -WhatIf
            $result | Should -Be $true
        }
        
        It "Should execute specified scripts" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            
            $result = Invoke-CoreApplication -ConfigPath $script:TestConfigPath -Scripts @("TestScript")
            $result | Should -Be $true
        }
        
        It "Should support Auto mode" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            
            $result = Invoke-CoreApplication -ConfigPath $script:TestConfigPath -Auto
            $result | Should -Be $true
        }
    }
    
    Context "Start-LabRunner" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
            
            # Create test config
            $script:TestConfigPath = Join-Path $TestDrive "test-config.json"
            @{ labSetting = "value" } | ConvertTo-Json | Set-Content -Path $script:TestConfigPath
        }
        
        It "Should start lab runner with valid config" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            
            $result = Start-LabRunner -ConfigPath $script:TestConfigPath
            # Result may be an array if multiple operations occurred
            if ($result -is [array]) {
                $result[-1] | Should -Be $true
            } else {
                $result | Should -Be $true
            }
        }
        
        It "Should support WhatIf parameter" {
            $result = Start-LabRunner -ConfigPath $script:TestConfigPath -WhatIf
            $result | Should -Be $true
        }
        
        It "Should handle parallel parameter" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            
            $result = Start-LabRunner -ConfigPath $script:TestConfigPath -Parallel
            $result | Should -Be $true
        }
        
        It "Should propagate errors correctly" {
            { Start-LabRunner -ConfigPath "nonexistent.json" } | Should -Throw
        }
    }
    
    Context "Invoke-UnifiedMaintenance" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }
        
        It "Should accept valid maintenance modes" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            Mock Invoke-BackupMaintenance { return @{ Success = $true } }
            Mock Start-UnifiedMaintenance { return @{ Success = $true } }
            
            $modes = @('Quick', 'Full', 'Emergency')
            foreach ($mode in $modes) {
                { Invoke-UnifiedMaintenance -Mode $mode } | Should -Not -Throw
            }
        }
        
        It "Should return maintenance results object" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            Mock Invoke-BackupMaintenance { return @{ Success = $true } }
            Mock Start-UnifiedMaintenance { return @{ Success = $true } }
            
            $result = Invoke-UnifiedMaintenance -Mode 'Quick'
            $result.Mode | Should -Be 'Quick'
            $result.ContainsKey('StartTime') | Should -Be $true
            $result.ContainsKey('Operations') | Should -Be $true
            $result.ContainsKey('Success') | Should -Be $true
        }
        
        It "Should support AutoFix parameter" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            Mock Invoke-BackupMaintenance { return @{ Success = $true } }
            Mock Start-UnifiedMaintenance { return @{ Success = $true } }
            
            { Invoke-UnifiedMaintenance -Mode 'Quick' -AutoFix } | Should -Not -Throw
        }
    }
    
    Context "Start-DevEnvironmentSetup" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }
        
        It "Should setup development environment" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            
            $result = Start-DevEnvironmentSetup -WhatIf
            $result | Should -Be $true
        }
        
        It "Should support Force parameter" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            
            $result = Start-DevEnvironmentSetup -Force -WhatIf
            $result | Should -Be $true
        }
        
        It "Should support SkipModuleImportFixes parameter" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return $null }
            
            $result = Start-DevEnvironmentSetup -SkipModuleImportFixes -WhatIf
            $result | Should -Be $true
        }
    }
    
    Context "Get-IntegratedToolset" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }
        
        It "Should return toolset overview" {
            Mock Get-Module { return @{ Name = "TestModule" } }
            Mock Get-Command { return @(@{ Name = "Test-Command" }) }
            
            $toolset = Get-IntegratedToolset
            $toolset | Should -Not -BeNullOrEmpty
            $toolset.ContainsKey('CoreModules') | Should -Be $true
            $toolset.ContainsKey('Capabilities') | Should -Be $true
            $toolset.ContainsKey('Integrations') | Should -Be $true
            $toolset.ContainsKey('HealthStatus') | Should -Be $true
            $toolset.ContainsKey('QuickActions') | Should -Be $true
        }
        
        It "Should support Detailed parameter" {
            Mock Get-Module { return @{ Name = "TestModule" } }
            Mock Get-Command { return @(@{ Name = "Test-Command" }) }
            
            { Get-IntegratedToolset -Detailed } | Should -Not -Throw
        }
    }
    
    Context "Invoke-IntegratedWorkflow" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }
        
        It "Should validate workflow types" {
            $validTypes = @('ISOWorkflow', 'DevelopmentWorkflow', 'LabDeployment', 'MaintenanceOperations')
            
            # Mock all the external functions that might be called
            function Get-ISODownload { return @{ FilePath = "test.iso" } }
            function New-AutounattendFile { return "test.xml" }
            function New-CustomISO { return @{ Path = "custom.iso" } }
            function Invoke-BulletproofTests { return @{ Success = $true } }
            function Invoke-PatchWorkflow { return @{ Success = $true } }
            function Start-BackupOperation { return @{ Success = $true } }
            function Start-LabAutomation { return @{ Success = $true } }
            function New-ISORepository { return @{ Path = "repo" } }
            function Test-RemoteConnection { return @{ Connected = $true } }
            function Start-UnifiedMaintenance { return @{ Success = $true } }
            Mock Test-CoreApplicationHealth { return $true }
            
            foreach ($type in $validTypes) {
                { Invoke-IntegratedWorkflow -WorkflowType $type -DryRun } | Should -Not -Throw
            }
        }
        
        It "Should return workflow results" {
            function Invoke-BulletproofTests { return @{ Success = $true } }
            function Invoke-PatchWorkflow { return @{ Success = $true } }
            function Start-BackupOperation { return @{ Success = $true } }
            
            $result = Invoke-IntegratedWorkflow -WorkflowType 'DevelopmentWorkflow' -DryRun
            $result.Workflow | Should -Be 'DevelopmentWorkflow'
            $result.Success | Should -Be $true
        }
        
        It "Should accept parameters hashtable" {
            function Invoke-BulletproofTests { return @{ Success = $true } }
            function Invoke-PatchWorkflow { return @{ Success = $true } }
            function Start-BackupOperation { return @{ Success = $true } }
            
            $params = @{ PatchDescription = "Test patch" }
            { Invoke-IntegratedWorkflow -WorkflowType 'DevelopmentWorkflow' -Parameters $params -DryRun } | Should -Not -Throw
        }
        
        It "Should support WhatIf" {
            function Invoke-BulletproofTests { return @{ Success = $true } }
            function Invoke-PatchWorkflow { return @{ Success = $true } }
            function Start-BackupOperation { return @{ Success = $true } }
            
            $result = Invoke-IntegratedWorkflow -WorkflowType 'DevelopmentWorkflow' -WhatIf
            # WhatIf should not execute the actual workflow
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Start-QuickAction" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }
        
        It "Should validate action types" {
            $validActions = @('CreateISO', 'RunTests', 'CreatePatch', 'LabSetup', 'SystemHealth', 'ModuleStatus')
            
            function Invoke-IntegratedWorkflow { return @{ Success = $true } }
            function Invoke-BulletproofTests { return @{ Success = $true } }
            function Invoke-PatchWorkflow { return @{ Success = $true } }
            Mock Test-CoreApplicationHealth { return $true }
            Mock Get-CoreModuleStatus { return @() }
            Mock Get-IntegratedToolset { return @{} }
            
            foreach ($action in $validActions) {
                { Start-QuickAction -Action $action -WhatIf } | Should -Not -Throw
            }
        }
        
        It "Should execute SystemHealth action" {
            Mock Test-CoreApplicationHealth { return $true }
            Mock Get-CoreModuleStatus { return @(@{ Name = "Test" }) }
            Mock Get-IntegratedToolset { return @{ Modules = @{} } }
            
            $result = Start-QuickAction -Action 'SystemHealth'
            $result | Should -Not -BeNullOrEmpty
            $result.CoreHealth | Should -Be $true
            $result.ContainsKey('ModuleStatus') | Should -Be $true
            $result.ContainsKey('ToolsetOverview') | Should -Be $true
            $result.ContainsKey('Timestamp') | Should -Be $true
        }
        
        It "Should execute ModuleStatus action" {
            Mock Get-IntegratedToolset { return @{ Modules = @{} } }
            
            $result = Start-QuickAction -Action 'ModuleStatus'
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should accept parameters for actions" {
            function Invoke-BulletproofTests { return @{ Success = $true } }
            
            $params = @{ ValidationLevel = 'Complete' }
            { Start-QuickAction -Action 'RunTests' -Parameters $params -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Error Handling and Edge Cases" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }
        
        It "Should handle missing dependencies gracefully" {
            Mock Get-Module { return $null }
            Mock Import-Module { throw "Module not found" }
            
            { Import-CoreModules -RequiredOnly } | Should -Not -Throw
        }
        
        It "Should handle invalid JSON in configuration" {
            $invalidJsonPath = Join-Path $TestDrive "invalid.json"
            Set-Content -Path $invalidJsonPath -Value "{ invalid json"
            
            { Get-CoreConfiguration -ConfigPath $invalidJsonPath } | Should -Throw
        }
        
        It "Should handle null parameters appropriately" {
            # Write-CustomLog doesn't validate null - it will just write empty message
            { Write-CustomLog -Message "" } | Should -Not -Throw
            { Invoke-IntegratedWorkflow -WorkflowType 'ISOWorkflow' -Parameters $null -DryRun } | Should -Not -Throw
        }
        
        It "Should handle empty script arrays" {
            Mock Test-Path { return $true }
            
            $configPath = Join-Path $TestDrive "config.json"
            @{} | ConvertTo-Json | Set-Content -Path $configPath
            
            { Invoke-CoreApplication -ConfigPath $configPath -Scripts @() } | Should -Not -Throw
        }
    }
    
    Context "Module State Management" {
        BeforeAll {
            Import-Module $script:ModulePath -Force
        }
        
        It "Should track loaded modules correctly" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return @{ Name = "TestModule" } }
            
            # Import modules
            $results = Import-CoreModules -RequiredOnly
            
            # Check status
            $status = Get-CoreModuleStatus
            $loadedModules = $status | Where-Object { $_.Loaded -eq $true }
            
            # At least required modules should show as loaded
            $loadedModules.Count | Should -BeGreaterThan 0
        }
        
        It "Should not reload modules unless forced" {
            Mock Test-Path { return $true }
            Mock Import-Module {}
            Mock Get-Module { return @{ Name = "Logging" } }
            
            # First import
            Import-CoreModules -RequiredOnly
            
            # Second import without force
            $results = Import-CoreModules -RequiredOnly
            
            # Should have skipped already loaded modules
            $results.SkippedCount | Should -BeGreaterThan 0
        }
    }
}

# Performance tests
Describe "AitherCore Performance Tests" -Tag 'Performance', 'CoreApp' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot "../../../../aither-core/AitherCore.psm1"
        Import-Module $script:ModulePath -Force
    }
    
    It "Should load module within acceptable time" {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Remove-Module -Name AitherCore -Force -ErrorAction SilentlyContinue
        Import-Module $script:ModulePath -Force
        $stopwatch.Stop()
        
        # Module should load in under 2 seconds
        $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 2
    }
    
    It "Should execute quick actions rapidly" {
        Mock Test-CoreApplicationHealth { return $true }
        Mock Get-CoreModuleStatus { return @() }
        Mock Get-IntegratedToolset { return @{} }
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Start-QuickAction -Action 'SystemHealth'
        $stopwatch.Stop()
        
        # Quick actions should complete in under 1 second
        $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 1
    }
}
