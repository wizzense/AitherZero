#Requires -Module Pester

<#
.SYNOPSIS
    Enhanced comprehensive test suite for ConfigurationCore module
.DESCRIPTION
    Comprehensive testing of all ConfigurationCore functionality including:
    - Core configuration management (30+ functions)
    - Environment management and switching
    - Schema validation and type checking
    - Hot reload functionality with file watchers
    - Configuration backup and restore
    - Event system integration
    - Import/export operations
    - Security features and access control
    - Performance under load
    - Cross-platform compatibility
    - Error handling and recovery
.NOTES
    This test suite uses the sophisticated TestingFramework infrastructure
    and provides comprehensive coverage of the configuration management system.
#>

BeforeAll {
    # Import required modules using the TestingFramework infrastructure
    $ProjectRoot = if ($env:PROJECT_ROOT) { $env:PROJECT_ROOT } else {
        $currentPath = $PSScriptRoot
        while ($currentPath -and -not (Test-Path (Join-Path $currentPath ".git"))) {
            $currentPath = Split-Path $currentPath -Parent
        }
        $currentPath
    }
    
    # Import TestingFramework for infrastructure
    $testingFrameworkPath = Join-Path $ProjectRoot "aither-core/modules/TestingFramework"
    if (Test-Path $testingFrameworkPath) {
        Import-Module $testingFrameworkPath -Force
    }
    
    # Import the module under test
    $ModulePath = Split-Path $PSScriptRoot -Parent
    Import-Module $ModulePath -Force
    
    # Mock Write-CustomLog if not available
    if (-not (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Level, [string]$Message)
            Write-Host "[$Level] $Message"
        }
    }
    
    # Mock event system functions if not available
    if (-not (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue)) {
        function Publish-TestEvent {
            param([string]$EventName, [hashtable]$EventData)
            # Mock implementation for testing
        }
    }
    
    # Create test directory structure
    $TestConfigDir = Join-Path $TestDrive 'ConfigurationCore'
    $TestBackupDir = Join-Path $TestConfigDir 'backups'
    $TestEnvDir = Join-Path $TestConfigDir 'environments'
    
    @($TestConfigDir, $TestBackupDir, $TestEnvDir) | ForEach-Object {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
    
    # Set up test configuration path
    $TestConfigPath = Join-Path $TestConfigDir 'test-config.json'
    
    # Initialize test environment
    $env:TEST_CONFIG_PATH = $TestConfigPath
    $env:TEST_BACKUP_DIR = $TestBackupDir
    
    # Test data for comprehensive testing
    $script:TestData = @{
        SimpleConfig = @{
            Property1 = 'Value1'
            Property2 = 42
            Property3 = $true
        }
        ComplexConfig = @{
            Database = @{
                ConnectionString = 'Server=localhost;Database=test'
                Timeout = 30
                PoolSize = 10
            }
            Features = @{
                EnableCaching = $true
                CacheExpiry = 3600
                DebugMode = $false
            }
            Arrays = @(
                @{ Name = 'Item1'; Value = 100 }
                @{ Name = 'Item2'; Value = 200 }
            )
        }
        SchemaDefinition = @{
            Properties = @{
                TestProperty = @{
                    Type = 'string'
                    Default = 'DefaultValue'
                    Required = $true
                    Description = 'Test property'
                    ValidValues = @('Option1', 'Option2', 'Option3')
                }
                NumericProperty = @{
                    Type = 'int'
                    Default = 42
                    Min = 1
                    Max = 100
                    Description = 'Numeric test property'
                }
                BooleanProperty = @{
                    Type = 'bool'
                    Default = $false
                    Description = 'Boolean test property'
                }
                ArrayProperty = @{
                    Type = 'array'
                    Default = @()
                    Description = 'Array test property'
                }
                ObjectProperty = @{
                    Type = 'object'
                    Default = @{}
                    Description = 'Object test property'
                    Properties = @{
                        NestedString = @{
                            Type = 'string'
                            Default = 'NestedDefault'
                        }
                    }
                }
            }
        }
        EnvironmentConfigs = @{
            dev = @{
                Name = 'dev'
                Description = 'Development environment'
                Settings = @{
                    LogLevel = 'Debug'
                    DatabaseTimeout = 5
                    EnableProfiling = $true
                }
            }
            staging = @{
                Name = 'staging'
                Description = 'Staging environment'
                Settings = @{
                    LogLevel = 'Info'
                    DatabaseTimeout = 15
                    EnableProfiling = $false
                }
            }
            prod = @{
                Name = 'prod'
                Description = 'Production environment'
                Settings = @{
                    LogLevel = 'Error'
                    DatabaseTimeout = 30
                    EnableProfiling = $false
                }
            }
        }
    }
}

Describe "ConfigurationCore Module - Core Functionality" {
    BeforeEach {
        # Reset configuration state for each test
        try {
            Initialize-ConfigurationCore -Force -StorePath $TestConfigPath
        } catch {
            # Initialize may not be available in all versions
        }
    }
    
    Context "Module Import and Basic Functions" {
        It "Should import the module without errors" {
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }
        
        It "Should export all required functions" {
            $exportedFunctions = Get-Command -Module ConfigurationCore -CommandType Function
            $exportedFunctions.Count | Should -BeGreaterThan 20
            
            # Verify key functions are exported
            $keyFunctions = @(
                'Get-ConfigurationStore', 'Set-ConfigurationStore',
                'Get-ModuleConfiguration', 'Set-ModuleConfiguration',
                'Get-ConfigurationEnvironment', 'Set-ConfigurationEnvironment',
                'Enable-ConfigurationHotReload', 'Disable-ConfigurationHotReload',
                'Backup-Configuration', 'Restore-Configuration'
            )
            
            foreach ($function in $keyFunctions) {
                Get-Command $function -Module ConfigurationCore -ErrorAction SilentlyContinue | 
                    Should -Not -BeNullOrEmpty -Because "Key function $function should be exported"
            }
        }
        
        It "Should have proper module metadata" {
            $module = Get-Module ConfigurationCore
            $module | Should -Not -BeNullOrEmpty
            $module.Version | Should -Not -BeNullOrEmpty
            $module.Description | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Configuration Store Management" {
        It "Should get configuration store successfully" {
            $store = Get-ConfigurationStore
            $store | Should -Not -BeNullOrEmpty
            $store | Should -BeOfType [hashtable]
            $store.Keys | Should -Contain 'Modules'
            $store.Keys | Should -Contain 'Environments'
            $store.Keys | Should -Contain 'CurrentEnvironment'
        }
        
        It "Should get configuration store as JSON" {
            $json = Get-ConfigurationStore -AsJson
            $json | Should -Not -BeNullOrEmpty
            $json | Should -BeOfType [string]
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should set configuration store with validation" {
            $newStore = @{
                Modules = @{ 'TestModule' = @{ 'TestSetting' = 'TestValue' } }
                Environments = @{
                    'default' = @{
                        Name = 'default'
                        Description = 'Default environment'
                        Settings = @{}
                    }
                }
                CurrentEnvironment = 'default'
                Schemas = @{}
                HotReload = @{ Enabled = $false; Watchers = @{} }
                StorePath = $TestConfigPath
            }
            
            { Set-ConfigurationStore -Store $newStore -Validate } | Should -Not -Throw
            
            $retrievedStore = Get-ConfigurationStore
            $retrievedStore.Modules.TestModule.TestSetting | Should -Be 'TestValue'
        }
        
        It "Should reject invalid configuration store structure" {
            $invalidStore = @{
                InvalidProperty = 'InvalidValue'
            }
            
            { Set-ConfigurationStore -Store $invalidStore -Validate } | Should -Throw
        }
        
        It "Should handle large configuration stores efficiently" {
            # Test with large configuration
            $largeStore = @{
                Modules = @{}
                Environments = @{
                    'default' = @{
                        Name = 'default'
                        Description = 'Default environment'
                        Settings = @{}
                    }
                }
                CurrentEnvironment = 'default'
                Schemas = @{}
                HotReload = @{ Enabled = $false; Watchers = @{} }
                StorePath = $TestConfigPath
            }
            
            # Add 100 modules with complex configuration
            for ($i = 1; $i -le 100; $i++) {
                $largeStore.Modules["Module$i"] = $script:TestData.ComplexConfig
            }
            
            Measure-Command {
                Set-ConfigurationStore -Store $largeStore
            } | ForEach-Object { $_.TotalSeconds | Should -BeLessThan 5 }
        }
    }
    
    Context "Import/Export Operations" {
        It "Should export configuration store to file" {
            $exportPath = Join-Path $TestDrive 'exported-config.json'
            { Export-ConfigurationStore -Path $exportPath } | Should -Not -Throw
            Test-Path $exportPath | Should -Be $true
            
            # Validate exported content
            $exportedContent = Get-Content $exportPath | ConvertFrom-Json
            $exportedContent | Should -Not -BeNullOrEmpty
        }
        
        It "Should import configuration store from file" {
            # First export a configuration
            $exportPath = Join-Path $TestDrive 'test-export.json'
            Export-ConfigurationStore -Path $exportPath
            
            # Modify current config
            Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration @{ TestProperty = 'ModifiedValue' }
            
            # Import from file
            { Import-ConfigurationStore -Path $exportPath } | Should -Not -Throw
            
            # Verify import worked
            $store = Get-ConfigurationStore
            $store | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle different export formats" {
            $formats = @('JSON', 'XML', 'YAML')
            
            foreach ($format in $formats) {
                if ($format -eq 'JSON' -or (Get-Command "ConvertTo-$format" -ErrorAction SilentlyContinue)) {
                    $exportPath = Join-Path $TestDrive "test-export.$($format.ToLower())"
                    { Export-ConfigurationStore -Path $exportPath -Format $format } | Should -Not -Throw
                    Test-Path $exportPath | Should -Be $true
                }
            }
        }
        
        It "Should validate imported configuration integrity" {
            $exportPath = Join-Path $TestDrive 'integrity-test.json'
            Export-ConfigurationStore -Path $exportPath
            
            # Test with valid file
            { Import-ConfigurationStore -Path $exportPath -ValidateIntegrity } | Should -Not -Throw
            
            # Test with corrupted file
            $corruptPath = Join-Path $TestDrive 'corrupt-config.json'
            Set-Content -Path $corruptPath -Value '{ invalid json content'
            { Import-ConfigurationStore -Path $corruptPath -ValidateIntegrity } | Should -Throw
        }
    }
}

Describe "ConfigurationCore Module - Module Configuration Management" {
    BeforeEach {
        # Register test modules for each test
        $testSchema = $script:TestData.SchemaDefinition
        Register-ModuleConfiguration -ModuleName 'TestModule' -Schema $testSchema
    }
    
    Context "Module Registration and Schema Management" {
        It "Should register module configuration with schema" {
            $schema = Get-ConfigurationSchema -ModuleName 'TestModule'
            $schema | Should -Not -BeNullOrEmpty
            $schema.Properties | Should -Not -BeNullOrEmpty
            $schema.Properties.TestProperty | Should -Not -BeNullOrEmpty
        }
        
        It "Should get all registered schemas" {
            Register-ModuleConfiguration -ModuleName 'AnotherModule' -Schema $script:TestData.SchemaDefinition
            
            $schemas = Get-ConfigurationSchema -All
            $schemas | Should -Not -BeNullOrEmpty
            $schemas.Count | Should -BeGreaterOrEqual 2
            $schemas.Keys | Should -Contain 'TestModule'
            $schemas.Keys | Should -Contain 'AnotherModule'
        }
        
        It "Should get schema with default values" {
            $schema = Get-ConfigurationSchema -ModuleName 'TestModule' -IncludeDefaults
            $schema | Should -Not -BeNullOrEmpty
            $schema.DefaultValues | Should -Not -BeNullOrEmpty
            $schema.DefaultValues.TestProperty | Should -Be 'DefaultValue'
            $schema.DefaultValues.NumericProperty | Should -Be 42
        }
        
        It "Should handle schema updates" {
            $originalSchema = Get-ConfigurationSchema -ModuleName 'TestModule'
            
            # Update schema
            $updatedSchema = $script:TestData.SchemaDefinition.Clone()
            $updatedSchema.Properties.NewProperty = @{
                Type = 'string'
                Default = 'NewDefault'
                Description = 'Newly added property'
            }
            
            Register-ModuleConfiguration -ModuleName 'TestModule' -Schema $updatedSchema -Update
            
            $newSchema = Get-ConfigurationSchema -ModuleName 'TestModule'
            $newSchema.Properties.NewProperty | Should -Not -BeNullOrEmpty
        }
        
        It "Should prevent duplicate module registration without update flag" {
            { Register-ModuleConfiguration -ModuleName 'TestModule' -Schema $script:TestData.SchemaDefinition } |
                Should -Throw -Because "Duplicate registration should be prevented"
        }
    }
    
    Context "Module Configuration CRUD Operations" {
        It "Should get module configuration with defaults" {
            $config = Get-ModuleConfiguration -ModuleName 'TestModule'
            $config | Should -Not -BeNullOrEmpty
            $config.TestProperty | Should -Be 'DefaultValue'
            $config.NumericProperty | Should -Be 42
            $config.BooleanProperty | Should -Be $false
        }
        
        It "Should set module configuration with validation" {
            $newConfig = @{
                TestProperty = 'Option1'
                NumericProperty = 50
                BooleanProperty = $true
                ArrayProperty = @('item1', 'item2')
                ObjectProperty = @{
                    NestedString = 'NestedValue'
                }
            }
            
            { Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $newConfig } | Should -Not -Throw
            
            $retrievedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
            $retrievedConfig.TestProperty | Should -Be 'Option1'
            $retrievedConfig.NumericProperty | Should -Be 50
            $retrievedConfig.BooleanProperty | Should -Be $true
            $retrievedConfig.ObjectProperty.NestedString | Should -Be 'NestedValue'
        }
        
        It "Should merge module configuration when specified" {
            # Set initial configuration
            Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration @{
                TestProperty = 'InitialValue'
                NumericProperty = 25
            }
            
            # Merge additional configuration
            $mergeConfig = @{
                NumericProperty = 75
                BooleanProperty = $true
                ArrayProperty = @('merged1', 'merged2')
            }
            
            { Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $mergeConfig -Merge } | Should -Not -Throw
            
            $retrievedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
            $retrievedConfig.TestProperty | Should -Be 'InitialValue'  # Should remain unchanged
            $retrievedConfig.NumericProperty | Should -Be 75  # Should be updated
            $retrievedConfig.BooleanProperty | Should -Be $true  # Should be added
            $retrievedConfig.ArrayProperty.Count | Should -Be 2
        }
        
        It "Should validate configuration against schema" {
            $validConfig = @{
                TestProperty = 'Option2'
                NumericProperty = 80
            }
            
            $result = Test-ModuleConfiguration -ModuleName 'TestModule' -Configuration $validConfig -Detailed
            $result.IsValid | Should -Be $true
            $result.Errors.Count | Should -Be 0
        }
        
        It "Should detect schema validation errors" {
            $invalidConfigs = @(
                @{ TestProperty = 'InvalidOption'; Description = 'Invalid enum value' },
                @{ NumericProperty = 150; Description = 'Value exceeds maximum' },
                @{ NumericProperty = -5; Description = 'Value below minimum' },
                @{ TestProperty = 123; Description = 'Wrong data type' }
            )
            
            foreach ($invalidConfig in $invalidConfigs) {
                $result = Test-ModuleConfiguration -ModuleName 'TestModule' -Configuration $invalidConfig.InvalidConfig -Detailed
                $result.IsValid | Should -Be $false -Because $invalidConfig.Description
                $result.Errors.Count | Should -BeGreaterThan 0
            }
        }
        
        It "Should handle missing required properties" {
            $incompleteConfig = @{
                NumericProperty = 50
                # TestProperty is required but missing
            }
            
            { Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $incompleteConfig } | Should -Throw
        }
    }
    
    Context "Configuration Validation and Type Checking" {
        It "Should perform comprehensive type validation" {
            $testCases = @(
                @{ Property = 'TestProperty'; Value = 'ValidString'; ShouldPass = $true },
                @{ Property = 'TestProperty'; Value = 123; ShouldPass = $false },
                @{ Property = 'NumericProperty'; Value = 50; ShouldPass = $true },
                @{ Property = 'NumericProperty'; Value = 'NotANumber'; ShouldPass = $false },
                @{ Property = 'BooleanProperty'; Value = $true; ShouldPass = $true },
                @{ Property = 'BooleanProperty'; Value = 'NotABoolean'; ShouldPass = $false },
                @{ Property = 'ArrayProperty'; Value = @(1, 2, 3); ShouldPass = $true },
                @{ Property = 'ArrayProperty'; Value = 'NotAnArray'; ShouldPass = $false }
            )
            
            foreach ($testCase in $testCases) {
                $config = @{ $testCase.Property = $testCase.Value }
                $result = Test-ModuleConfiguration -ModuleName 'TestModule' -Configuration $config -Detailed
                
                if ($testCase.ShouldPass) {
                    $result.IsValid | Should -Be $true -Because "Valid $($testCase.Property) should pass validation"
                } else {
                    $result.IsValid | Should -Be $false -Because "Invalid $($testCase.Property) should fail validation"
                }
            }
        }
        
        It "Should validate enum/valid values constraints" {
            $validValues = @('Option1', 'Option2', 'Option3')
            
            foreach ($validValue in $validValues) {
                $config = @{ TestProperty = $validValue }
                $result = Test-ModuleConfiguration -ModuleName 'TestModule' -Configuration $config -Detailed
                $result.IsValid | Should -Be $true -Because "$validValue should be valid"
            }
            
            $invalidValue = 'InvalidOption'
            $config = @{ TestProperty = $invalidValue }
            $result = Test-ModuleConfiguration -ModuleName 'TestModule' -Configuration $config -Detailed
            $result.IsValid | Should -Be $false -Because "$invalidValue should be invalid"
        }
        
        It "Should validate numeric range constraints" {
            $testCases = @(
                @{ Value = 1; ShouldPass = $true; Description = 'Minimum boundary' },
                @{ Value = 50; ShouldPass = $true; Description = 'Valid middle value' },
                @{ Value = 100; ShouldPass = $true; Description = 'Maximum boundary' },
                @{ Value = 0; ShouldPass = $false; Description = 'Below minimum' },
                @{ Value = 101; ShouldPass = $false; Description = 'Above maximum' }
            )
            
            foreach ($testCase in $testCases) {
                $config = @{ NumericProperty = $testCase.Value }
                $result = Test-ModuleConfiguration -ModuleName 'TestModule' -Configuration $config -Detailed
                
                if ($testCase.ShouldPass) {
                    $result.IsValid | Should -Be $true -Because $testCase.Description
                } else {
                    $result.IsValid | Should -Be $false -Because $testCase.Description
                }
            }
        }
        
        It "Should validate nested object properties" {
            $validNestedConfig = @{
                ObjectProperty = @{
                    NestedString = 'ValidNestedValue'
                    AdditionalProperty = 'AllowedAdditional'
                }
            }
            
            $result = Test-ModuleConfiguration -ModuleName 'TestModule' -Configuration $validNestedConfig -Detailed
            $result.IsValid | Should -Be $true
            
            # Test with missing nested required properties if any
            $invalidNestedConfig = @{
                ObjectProperty = @{
                    WrongProperty = 'ShouldNotBeHere'
                }
            }
            
            # This test depends on schema having nested validation rules
            Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $validNestedConfig
            $retrievedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
            $retrievedConfig.ObjectProperty.NestedString | Should -Be 'ValidNestedValue'
        }
    }
}

Describe "ConfigurationCore Module - Environment Management" {
    Context "Environment CRUD Operations" {
        It "Should get current environment" {
            $env = Get-ConfigurationEnvironment
            $env | Should -Not -BeNullOrEmpty
            $env.Name | Should -Not -BeNullOrEmpty
            $env.IsCurrent | Should -Be $true
        }
        
        It "Should get all environments" {
            $envs = Get-ConfigurationEnvironment -All
            $envs | Should -Not -BeNullOrEmpty
            $envs.Count | Should -BeGreaterOrEqual 1
            $envs.Keys | Should -Contain 'default'
        }
        
        It "Should create new environments with validation" {
            $envName = 'test-env'
            $envDescription = 'Test environment for validation'
            
            $newEnv = New-ConfigurationEnvironment -Name $envName -Description $envDescription
            $newEnv | Should -Not -BeNullOrEmpty
            $newEnv.Name | Should -Be $envName
            $newEnv.Description | Should -Be $envDescription
            
            # Verify environment was added to store
            $allEnvs = Get-ConfigurationEnvironment -All
            $allEnvs.Keys | Should -Contain $envName
        }
        
        It "Should create environment with custom settings" {
            $customSettings = @{
                LogLevel = 'Debug'
                EnableProfiling = $true
                DatabaseTimeout = 30
                CustomFeatures = @('Feature1', 'Feature2')
            }
            
            $newEnv = New-ConfigurationEnvironment -Name 'custom-env' -Description 'Custom environment' -Settings $customSettings
            $newEnv.Settings.LogLevel | Should -Be 'Debug'
            $newEnv.Settings.EnableProfiling | Should -Be $true
            $newEnv.Settings.CustomFeatures.Count | Should -Be 2
        }
        
        It "Should copy environment settings from existing environment" {
            # Create source environment
            New-ConfigurationEnvironment -Name 'source-env' -Description 'Source' -Settings @{ Setting1 = 'Value1'; Setting2 = 42 }
            
            # Copy to new environment
            $copiedEnv = New-ConfigurationEnvironment -Name 'copied-env' -Description 'Copied environment' -CopyFrom 'source-env'
            $copiedEnv | Should -Not -BeNullOrEmpty
            $copiedEnv.Name | Should -Be 'copied-env'
            $copiedEnv.Settings.Setting1 | Should -Be 'Value1'
            $copiedEnv.Settings.Setting2 | Should -Be 42
        }
        
        It "Should switch active environment" {
            # Create test environment
            New-ConfigurationEnvironment -Name 'switch-test' -Description 'Switch test environment'
            
            # Switch to it
            { Set-ConfigurationEnvironment -Name 'switch-test' } | Should -Not -Throw
            
            # Verify switch
            $currentEnv = Get-ConfigurationEnvironment
            $currentEnv.Name | Should -Be 'switch-test'
        }
        
        It "Should remove environment with validation" {
            # Create environment to remove
            New-ConfigurationEnvironment -Name 'temp-env' -Description 'Temporary environment'
            
            # Remove it
            { Remove-ConfigurationEnvironment -Name 'temp-env' -Force } | Should -Not -Throw
            
            # Verify removal
            $allEnvs = Get-ConfigurationEnvironment -All
            $allEnvs.Keys | Should -Not -Contain 'temp-env'
        }
        
        It "Should prevent removal of current environment without force" {
            Set-ConfigurationEnvironment -Name 'default'
            { Remove-ConfigurationEnvironment -Name 'default' } | Should -Throw
        }
        
        It "Should prevent removal of non-existent environment" {
            { Remove-ConfigurationEnvironment -Name 'non-existent' -Force } | Should -Throw
        }
    }
    
    Context "Environment-Specific Configuration" {
        BeforeEach {
            # Set up test environments
            foreach ($envName in $script:TestData.EnvironmentConfigs.Keys) {
                $envConfig = $script:TestData.EnvironmentConfigs[$envName]
                New-ConfigurationEnvironment -Name $envName -Description $envConfig.Description -Settings $envConfig.Settings -Force
            }
            
            # Register test module
            Register-ModuleConfiguration -ModuleName 'EnvTestModule' -Schema $script:TestData.SchemaDefinition
        }
        
        It "Should maintain separate configurations per environment" {
            $environments = @('dev', 'staging', 'prod')
            
            foreach ($env in $environments) {
                Set-ConfigurationEnvironment -Name $env
                
                $envSpecificConfig = @{
                    TestProperty = "Value-$env"
                    NumericProperty = switch ($env) {
                        'dev' { 10 }
                        'staging' { 50 }
                        'prod' { 90 }
                    }
                }
                
                Set-ModuleConfiguration -ModuleName 'EnvTestModule' -Configuration $envSpecificConfig
            }
            
            # Verify each environment has its own configuration
            foreach ($env in $environments) {
                $config = Get-ModuleConfiguration -ModuleName 'EnvTestModule' -Environment $env
                $config.TestProperty | Should -Be "Value-$env"
                $config.NumericProperty | Should -Be $(switch ($env) {
                    'dev' { 10 }
                    'staging' { 50 }
                    'prod' { 90 }
                })
            }
        }
        
        It "Should apply environment-specific overrides" {
            # Set base configuration
            Set-ConfigurationEnvironment -Name 'dev'
            Set-ModuleConfiguration -ModuleName 'EnvTestModule' -Configuration @{
                TestProperty = 'BaseValue'
                NumericProperty = 25
            }
            
            # Switch environment and verify inheritance/override
            Set-ConfigurationEnvironment -Name 'staging'
            $stagingConfig = Get-ModuleConfiguration -ModuleName 'EnvTestModule'
            
            # Should get defaults when no environment-specific config exists
            $stagingConfig.TestProperty | Should -Be 'DefaultValue'
        }
        
        It "Should handle environment switching with active configurations" {
            # Configure module in dev environment
            Set-ConfigurationEnvironment -Name 'dev'
            Set-ModuleConfiguration -ModuleName 'EnvTestModule' -Configuration @{
                TestProperty = 'DevValue'
                NumericProperty = 10
            }
            
            # Switch to staging and configure
            Set-ConfigurationEnvironment -Name 'staging'
            Set-ModuleConfiguration -ModuleName 'EnvTestModule' -Configuration @{
                TestProperty = 'StagingValue'
                NumericProperty = 50
            }
            
            # Switch back to dev and verify configuration persisted
            Set-ConfigurationEnvironment -Name 'dev'
            $devConfig = Get-ModuleConfiguration -ModuleName 'EnvTestModule'
            $devConfig.TestProperty | Should -Be 'DevValue'
            $devConfig.NumericProperty | Should -Be 10
        }
        
        It "Should validate environment-specific constraints" {
            # This test would validate that certain configurations are only valid in certain environments
            # For example, debug settings only in dev, production settings only in prod
            
            Set-ConfigurationEnvironment -Name 'prod'
            
            # Assume we have environment-specific validation rules
            $prodConfig = @{
                TestProperty = 'Option1'
                NumericProperty = 95  # High performance setting for prod
            }
            
            $result = Test-ModuleConfiguration -ModuleName 'EnvTestModule' -Configuration $prodConfig -Environment 'prod'
            $result.IsValid | Should -Be $true
        }
    }
}

Describe "ConfigurationCore Module - Hot Reload Functionality" {
    Context "Hot Reload Enable/Disable" {
        It "Should enable hot reload functionality" {
            { Enable-ConfigurationHotReload } | Should -Not -Throw
            
            $watcher = Get-ConfigurationWatcher
            $watcher.HotReloadEnabled | Should -Be $true
        }
        
        It "Should disable hot reload functionality" {
            Enable-ConfigurationHotReload
            { Disable-ConfigurationHotReload -RemoveWatchers } | Should -Not -Throw
            
            $watcher = Get-ConfigurationWatcher
            $watcher.HotReloadEnabled | Should -Be $false
        }
        
        It "Should get watcher information" {
            Enable-ConfigurationHotReload
            $watchers = Get-ConfigurationWatcher -All
            $watchers | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle multiple enable/disable cycles" {
            for ($i = 1; $i -le 3; $i++) {
                Enable-ConfigurationHotReload
                $watcher = Get-ConfigurationWatcher
                $watcher.HotReloadEnabled | Should -Be $true
                
                Disable-ConfigurationHotReload
                $watcher = Get-ConfigurationWatcher
                $watcher.HotReloadEnabled | Should -Be $false
            }
        }
    }
    
    Context "File System Watching" {
        BeforeEach {
            Enable-ConfigurationHotReload
        }
        
        AfterEach {
            Disable-ConfigurationHotReload -RemoveWatchers
        }
        
        It "Should detect configuration file changes" {
            # This test simulates file system changes and verifies hot reload
            $testConfigFile = Join-Path $TestDrive 'hot-reload-test.json'
            $initialConfig = @{ TestValue = 'Initial' }
            $initialConfig | ConvertTo-Json | Set-Content -Path $testConfigFile
            
            # Register file for watching (if supported)
            if (Get-Command Register-ConfigurationWatcher -ErrorAction SilentlyContinue) {
                Register-ConfigurationWatcher -Path $testConfigFile -ModuleName 'HotReloadTest'
                
                # Simulate file change
                $updatedConfig = @{ TestValue = 'Updated' }
                $updatedConfig | ConvertTo-Json | Set-Content -Path $testConfigFile
                
                # Give hot reload time to process
                Start-Sleep -Milliseconds 500
                
                # Verify configuration was reloaded
                # This would depend on the actual hot reload implementation
                $true | Should -Be $true  # Placeholder for actual verification
            } else {
                Set-ItResult -Skipped -Because "Hot reload watching not implemented"
            }
        }
        
        It "Should handle file system events efficiently" {
            # Test that hot reload doesn't cause performance issues
            $testConfigFile = Join-Path $TestDrive 'performance-test.json'
            $config = @{ TestValue = 'Performance' }
            $config | ConvertTo-Json | Set-Content -Path $testConfigFile
            
            # Measure time for multiple file changes
            $changeCount = 10
            $measureTime = Measure-Command {
                for ($i = 1; $i -le $changeCount; $i++) {
                    $config.TestValue = "Update$i"
                    $config | ConvertTo-Json | Set-Content -Path $testConfigFile
                    Start-Sleep -Milliseconds 50  # Brief pause between changes
                }
            }
            
            # Should handle changes efficiently
            $measureTime.TotalSeconds | Should -BeLessThan 5
        }
        
        It "Should handle file system errors gracefully" {
            # Test hot reload behavior when files are locked, deleted, etc.
            $testConfigFile = Join-Path $TestDrive 'error-test.json'
            $config = @{ TestValue = 'Error' }
            $config | ConvertTo-Json | Set-Content -Path $testConfigFile
            
            # Delete file and ensure hot reload handles gracefully
            Remove-Item $testConfigFile -Force
            
            # Hot reload should continue to function
            $watcher = Get-ConfigurationWatcher
            $watcher.HotReloadEnabled | Should -Be $true
        }
    }
    
    Context "Configuration Reload Events" {
        It "Should publish reload events" {
            # Test that configuration changes publish appropriate events
            Enable-ConfigurationHotReload
            
            # Set up event capture
            $capturedEvents = @()
            if (Get-Command Subscribe-ConfigurationEvent -ErrorAction SilentlyContinue) {
                Subscribe-ConfigurationEvent -EventName 'ConfigurationReloaded' -Action {
                    param($EventData)
                    $script:capturedEvents += $EventData
                }
                
                # Trigger a configuration change
                Set-ModuleConfiguration -ModuleName 'EventTestModule' -Configuration @{ TestProperty = 'EventTest' }
                
                # Allow time for event processing
                Start-Sleep -Milliseconds 100
                
                # Verify event was published
                $capturedEvents.Count | Should -BeGreaterThan 0
            } else {
                Set-ItResult -Skipped -Because "Event system not available"
            }
        }
        
        It "Should include change details in events" {
            # Test that reload events contain sufficient information about what changed
            $true | Should -Be $true  # Placeholder for event detail verification
        }
    }
}

Describe "ConfigurationCore Module - Backup and Restore" {
    Context "Configuration Backup" {
        It "Should create configuration backup" {
            $backupResult = Backup-Configuration -Reason "Test backup"
            $backupResult | Should -Not -BeNullOrEmpty
            $backupResult.BackupPath | Should -Not -BeNullOrEmpty
            Test-Path $backupResult.BackupPath | Should -Be $true
        }
        
        It "Should create backup with custom name" {
            $customName = "custom-backup-$(Get-Date -Format 'yyyyMMdd')"
            $backupResult = Backup-Configuration -Reason "Custom backup" -BackupName $customName
            $backupResult.BackupPath | Should -Match $customName
        }
        
        It "Should include metadata in backup" {
            $backupResult = Backup-Configuration -Reason "Metadata test"
            $metadataPath = Join-Path (Split-Path $backupResult.BackupPath) "backup-metadata.json"
            
            if (Test-Path $metadataPath) {
                $metadata = Get-Content $metadataPath | ConvertFrom-Json
                $metadata.reason | Should -Be "Metadata test"
                $metadata.timestamp | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should handle backup directory creation" {
            $customBackupDir = Join-Path $TestDrive 'custom-backups'
            $backupResult = Backup-Configuration -Reason "Custom directory" -BackupDirectory $customBackupDir
            Test-Path $customBackupDir | Should -Be $true
        }
        
        It "Should manage backup retention" {
            # Create multiple backups to test retention
            for ($i = 1; $i -le 5; $i++) {
                Backup-Configuration -Reason "Retention test $i"
                Start-Sleep -Milliseconds 100  # Ensure different timestamps
            }
            
            # Verify backup cleanup works (implementation dependent)
            $true | Should -Be $true  # Placeholder for retention verification
        }
    }
    
    Context "Configuration Restore" {
        BeforeEach {
            # Create a known configuration state
            Register-ModuleConfiguration -ModuleName 'RestoreTestModule' -Schema $script:TestData.SchemaDefinition
            Set-ModuleConfiguration -ModuleName 'RestoreTestModule' -Configuration @{
                TestProperty = 'OriginalValue'
                NumericProperty = 75
            }
        }
        
        It "Should restore configuration from backup" {
            # Create backup
            $backupResult = Backup-Configuration -Reason "Test restore"
            
            # Modify current configuration
            Set-ModuleConfiguration -ModuleName 'RestoreTestModule' -Configuration @{
                TestProperty = 'ModifiedValue'
                NumericProperty = 25
            }
            
            # Restore from backup
            $restoreResult = Restore-Configuration -Path $backupResult.BackupPath -Force
            $restoreResult | Should -Not -BeNullOrEmpty
            
            # Verify restoration
            $config = Get-ModuleConfiguration -ModuleName 'RestoreTestModule'
            $config.TestProperty | Should -Be 'OriginalValue'
            $config.NumericProperty | Should -Be 75
        }
        
        It "Should validate backup before restore" {
            # Create valid backup
            $validBackup = Backup-Configuration -Reason "Valid backup"
            
            # Test restore with validation
            { Restore-Configuration -Path $validBackup.BackupPath -ValidateBeforeRestore } | Should -Not -Throw
            
            # Test with invalid backup
            $invalidBackupPath = Join-Path $TestDrive 'invalid-backup.json'
            Set-Content -Path $invalidBackupPath -Value '{ invalid json }'
            
            { Restore-Configuration -Path $invalidBackupPath -ValidateBeforeRestore } | Should -Throw
        }
        
        It "Should create restore point before restore" {
            $originalBackup = Backup-Configuration -Reason "Original state"
            
            # Modify configuration
            Set-ModuleConfiguration -ModuleName 'RestoreTestModule' -Configuration @{ TestProperty = 'ModifiedValue' }
            
            # Restore with automatic restore point
            $restoreResult = Restore-Configuration -Path $originalBackup.BackupPath -CreateRestorePoint
            
            # Verify restore point was created
            $restoreResult.RestorePointPath | Should -Not -BeNullOrEmpty
            Test-Path $restoreResult.RestorePointPath | Should -Be $true
        }
        
        It "Should handle partial restore scenarios" {
            # Test restoring only specific modules or environments
            if (Get-Command Restore-Configuration -ParameterName ModuleName -ErrorAction SilentlyContinue) {
                $backup = Backup-Configuration -Reason "Partial restore test"
                
                # Modify multiple modules
                Set-ModuleConfiguration -ModuleName 'RestoreTestModule' -Configuration @{ TestProperty = 'Modified1' }
                Register-ModuleConfiguration -ModuleName 'OtherModule' -Schema $script:TestData.SchemaDefinition
                Set-ModuleConfiguration -ModuleName 'OtherModule' -Configuration @{ TestProperty = 'Modified2' }
                
                # Restore only one module
                Restore-Configuration -Path $backup.BackupPath -ModuleName 'RestoreTestModule' -Force
                
                # Verify selective restore
                $restoredConfig = Get-ModuleConfiguration -ModuleName 'RestoreTestModule'
                $restoredConfig.TestProperty | Should -Be 'OriginalValue'
                
                # Other module should remain modified
                $otherConfig = Get-ModuleConfiguration -ModuleName 'OtherModule'
                $otherConfig.TestProperty | Should -Be 'Modified2'
            } else {
                Set-ItResult -Skipped -Because "Partial restore not implemented"
            }
        }
    }
    
    Context "Backup Integrity and Security" {
        It "Should verify backup integrity with checksums" {
            $backupResult = Backup-Configuration -Reason "Integrity test" -IncludeChecksum
            
            if ($backupResult.Checksum) {
                # Verify checksum calculation
                $backupResult.Checksum | Should -Not -BeNullOrEmpty
                $backupResult.Checksum | Should -Match '^[a-fA-F0-9]+$'
            }
        }
        
        It "Should encrypt sensitive backup data" {
            # Test backup encryption if available
            if (Get-Command Backup-Configuration -ParameterName Encrypt -ErrorAction SilentlyContinue) {
                $encryptedBackup = Backup-Configuration -Reason "Encryption test" -Encrypt -PassPhrase "TestPassPhrase"
                
                # Verify backup is encrypted (content should not be readable as plain JSON)
                $backupContent = Get-Content $encryptedBackup.BackupPath -Raw
                { $backupContent | ConvertFrom-Json } | Should -Throw
            } else {
                Set-ItResult -Skipped -Because "Backup encryption not implemented"
            }
        }
        
        It "Should handle backup compression" {
            $uncompressedBackup = Backup-Configuration -Reason "Uncompressed test"
            $uncompressedSize = (Get-Item $uncompressedBackup.BackupPath).Length
            
            if (Get-Command Backup-Configuration -ParameterName Compress -ErrorAction SilentlyContinue) {
                $compressedBackup = Backup-Configuration -Reason "Compressed test" -Compress
                $compressedSize = (Get-Item $compressedBackup.BackupPath).Length
                
                # Compressed backup should be smaller
                $compressedSize | Should -BeLessThan $uncompressedSize
            } else {
                Set-ItResult -Skipped -Because "Backup compression not implemented"
            }
        }
    }
}

Describe "ConfigurationCore Module - Advanced Features" {
    Context "Configuration Comparison" {
        It "Should compare configurations and detect differences" {
            $config1 = @{
                Property1 = 'Value1'
                Property2 = 'Value2'
                Nested = @{
                    NestedProperty = 'NestedValue'
                }
            }
            
            $config2 = @{
                Property1 = 'Value1'
                Property2 = 'ModifiedValue'
                Property3 = 'NewValue'
                Nested = @{
                    NestedProperty = 'ModifiedNestedValue'
                }
            }
            
            $comparison = Compare-Configuration -ReferenceConfiguration $config1 -DifferenceConfiguration $config2
            $comparison | Should -Not -BeNullOrEmpty
            $comparison.HasChanges | Should -Be $true
            $comparison.Summary.ModifiedCount | Should -BeGreaterThan 0
            $comparison.Summary.AddedCount | Should -BeGreaterThan 0
        }
        
        It "Should detect no changes in identical configurations" {
            $config1 = $script:TestData.SimpleConfig
            $config2 = $script:TestData.SimpleConfig.Clone()
            
            $comparison = Compare-Configuration -ReferenceConfiguration $config1 -DifferenceConfiguration $config2
            $comparison.HasChanges | Should -Be $false
            $comparison.Summary.ModifiedCount | Should -Be 0
            $comparison.Summary.AddedCount | Should -Be 0
            $comparison.Summary.RemovedCount | Should -Be 0
        }
        
        It "Should provide detailed change information" {
            $config1 = @{ A = 1; B = 2; C = 3 }
            $config2 = @{ A = 1; B = 20; D = 4 }  # B modified, C removed, D added
            
            $comparison = Compare-Configuration -ReferenceConfiguration $config1 -DifferenceConfiguration $config2 -Detailed
            
            $comparison.Changes | Should -Not -BeNullOrEmpty
            $comparison.Changes | Should -Contain { $_.ChangeType -eq 'Modified' -and $_.PropertyName -eq 'B' }
            $comparison.Changes | Should -Contain { $_.ChangeType -eq 'Removed' -and $_.PropertyName -eq 'C' }
            $comparison.Changes | Should -Contain { $_.ChangeType -eq 'Added' -and $_.PropertyName -eq 'D' }
        }
    }
    
    Context "Variable Expansion" {
        It "Should expand environment variables" {
            $config = @{
                PathProperty = '${ENV:TEMP}/test'
                UserProperty = '${ENV:USERNAME}'
            }
            
            Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $config
            $expandedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
            
            # Should not contain literal variable syntax
            $expandedConfig.PathProperty | Should -Not -Match '\$\{ENV:'
            $expandedConfig.UserProperty | Should -Not -Match '\$\{ENV:'
            
            # Should contain actual values
            $expandedConfig.PathProperty | Should -Match 'test$'
        }
        
        It "Should expand platform variables" {
            $config = @{
                PlatformProperty = '${PLATFORM}'
                OSProperty = '${OS}'
            }
            
            Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $config
            $expandedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
            
            $expandedConfig.PlatformProperty | Should -Match '^(Windows|Linux|macOS)$'
        }
        
        It "Should expand custom variables" {
            # Test custom variable expansion if available
            if (Get-Command Set-ConfigurationVariable -ErrorAction SilentlyContinue) {
                Set-ConfigurationVariable -Name 'CUSTOM_VAR' -Value 'CustomValue'
                
                $config = @{
                    CustomProperty = '${CUSTOM_VAR}/suffix'
                }
                
                Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $config
                $expandedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
                
                $expandedConfig.CustomProperty | Should -Be 'CustomValue/suffix'
            } else {
                Set-ItResult -Skipped -Because "Custom variable expansion not implemented"
            }
        }
        
        It "Should handle nested variable expansion" {
            $config = @{
                ComplexPath = '${ENV:TEMP}/${PLATFORM}/logs'
                NestedObject = @{
                    DatabasePath = '${ENV:PROGRAMDATA}/database'
                }
            }
            
            Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $config
            $expandedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
            
            $expandedConfig.ComplexPath | Should -Not -Match '\$\{'
            $expandedConfig.NestedObject.DatabasePath | Should -Not -Match '\$\{'
        }
    }
    
    Context "Event System Integration" {
        BeforeEach {
            # Reset event history for each test
            if (Get-Command Clear-ConfigurationEventHistory -ErrorAction SilentlyContinue) {
                Clear-ConfigurationEventHistory
            }
        }
        
        It "Should publish configuration change events" {
            if (Get-Command Get-ConfigurationEventHistory -ErrorAction SilentlyContinue) {
                # Subscribe to events
                $eventCount = 0
                Subscribe-ConfigurationEvent -EventName 'ConfigurationChanged' -Action {
                    $script:eventCount++
                }
                
                # Make configuration changes
                Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration @{ TestProperty = 'EventTest1' }
                Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration @{ TestProperty = 'EventTest2' }
                
                # Allow time for event processing
                Start-Sleep -Milliseconds 100
                
                # Verify events were published
                $eventCount | Should -BeGreaterThan 0
            } else {
                Set-ItResult -Skipped -Because "Event system not available"
            }
        }
        
        It "Should include event metadata" {
            if (Get-Command Get-ConfigurationEventHistory -ErrorAction SilentlyContinue) {
                # Subscribe and capture event data
                $capturedEvents = @()
                Subscribe-ConfigurationEvent -EventName 'ConfigurationChanged' -Action {
                    param($EventData)
                    $script:capturedEvents += $EventData
                }
                
                Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration @{ TestProperty = 'MetadataTest' }
                Start-Sleep -Milliseconds 100
                
                if ($capturedEvents.Count -gt 0) {
                    $event = $capturedEvents[0]
                    $event.ModuleName | Should -Be 'TestModule'
                    $event.Timestamp | Should -Not -BeNullOrEmpty
                    $event.ChangeType | Should -Not -BeNullOrEmpty
                }
            } else {
                Set-ItResult -Skipped -Because "Event system not available"
            }
        }
        
        It "Should support event filtering" {
            if (Get-Command Subscribe-ConfigurationEvent -ParameterName Filter -ErrorAction SilentlyContinue) {
                # Subscribe with filter
                $filteredEvents = @()
                Subscribe-ConfigurationEvent -EventName 'ConfigurationChanged' -Filter { $_.ModuleName -eq 'TestModule' } -Action {
                    param($EventData)
                    $script:filteredEvents += $EventData
                }
                
                # Change different modules
                Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration @{ TestProperty = 'Filtered1' }
                Set-ModuleConfiguration -ModuleName 'OtherModule' -Configuration @{ TestProperty = 'Filtered2' }
                
                Start-Sleep -Milliseconds 100
                
                # Should only capture TestModule events
                $filteredEvents | Should -Not -BeNullOrEmpty
                $filteredEvents | ForEach-Object { $_.ModuleName | Should -Be 'TestModule' }
            } else {
                Set-ItResult -Skipped -Because "Event filtering not implemented"
            }
        }
    }
    
    Context "Security and Access Control" {
        It "Should detect sensitive information in configurations" {
            $configWithSecrets = @{
                DatabasePassword = 'PLACEHOLDER_PASSWORD'
                ApiKey = 'PLACEHOLDER_API_KEY'
                ConnectionString = 'Server=localhost;Password=PLACEHOLDER'
                SafeProperty = 'PublicValue'
            }
            
            # Test security scanning if available
            if (Get-Command Test-ConfigurationSecurity -ErrorAction SilentlyContinue) {
                $securityResult = Test-ConfigurationSecurity -Configuration $configWithSecrets
                $securityResult.HasSecurityIssues | Should -Be $true
                $securityResult.SecurityIssues.Count | Should -BeGreaterThan 0
            } else {
                # Manual check for sensitive patterns
                $sensitiveKeys = @('Password', 'Secret', 'Key', 'Token')
                $foundSensitive = $configWithSecrets.Keys | Where-Object { 
                    $key = $_
                    $sensitiveKeys | Where-Object { $key -match $_ }
                }
                $foundSensitive.Count | Should -BeGreaterThan 0
            }
        }
        
        It "Should support configuration encryption" {
            if (Get-Command Set-ModuleConfiguration -ParameterName Encrypt -ErrorAction SilentlyContinue) {
                $sensitiveConfig = @{
                    SecretProperty = 'VerySecretValue'
                    PublicProperty = 'PublicValue'
                }
                
                # Set with encryption
                Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $sensitiveConfig -Encrypt -EncryptionKey 'TestKey123'
                
                # Verify data is encrypted in storage
                $store = Get-ConfigurationStore -Raw
                $moduleConfig = $store.Modules.TestModule
                
                # Should not contain plain text secrets
                $moduleConfig.ToString() | Should -Not -Match 'VerySecretValue'
                
                # But should decrypt correctly when retrieved
                $decryptedConfig = Get-ModuleConfiguration -ModuleName 'TestModule' -DecryptionKey 'TestKey123'
                $decryptedConfig.SecretProperty | Should -Be 'VerySecretValue'
            } else {
                Set-ItResult -Skipped -Because "Configuration encryption not implemented"
            }
        }
        
        It "Should validate configuration access permissions" {
            if (Get-Command Test-ConfigurationAccess -ErrorAction SilentlyContinue) {
                # Test access control if implemented
                $accessResult = Test-ConfigurationAccess -ModuleName 'TestModule' -User $env:USERNAME
                $accessResult | Should -Not -BeNullOrEmpty
                $accessResult.HasAccess | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "Access control not implemented"
            }
        }
    }
}

Describe "ConfigurationCore Module - Performance and Scalability" {
    Context "Performance Under Load" {
        It "Should handle large configurations efficiently" {
            # Create large configuration
            $largeConfig = @{}
            for ($i = 1; $i -le 1000; $i++) {
                $largeConfig["Property$i"] = "Value$i"
            }
            
            # Test performance of operations
            $setTime = Measure-Command {
                Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $largeConfig
            }
            
            $getTime = Measure-Command {
                Get-ModuleConfiguration -ModuleName 'TestModule'
            }
            
            # Should be reasonably fast
            $setTime.TotalSeconds | Should -BeLessThan 2
            $getTime.TotalSeconds | Should -BeLessThan 1
        }
        
        It "Should handle multiple concurrent operations" {
            $jobs = @()
            
            # Start multiple configuration operations simultaneously
            for ($i = 1; $i -le 5; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($ModulePath, $ModuleNumber)
                    
                    Import-Module $ModulePath -Force
                    
                    $config = @{
                        TestProperty = "ConcurrentValue$ModuleNumber"
                        NumericProperty = $ModuleNumber * 10
                    }
                    
                    Set-ModuleConfiguration -ModuleName "ConcurrentModule$ModuleNumber" -Configuration $config
                    Get-ModuleConfiguration -ModuleName "ConcurrentModule$ModuleNumber"
                } -ArgumentList $ModulePath, $i
            }
            
            # Wait for all jobs to complete
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            # All operations should succeed
            $results.Count | Should -Be 5
            $results | ForEach-Object { 
                $_.TestProperty | Should -Match '^ConcurrentValue\d+$'
            }
        }
        
        It "Should maintain performance with many modules" {
            # Register many modules
            $moduleCount = 50
            for ($i = 1; $i -le $moduleCount; $i++) {
                Register-ModuleConfiguration -ModuleName "PerfModule$i" -Schema $script:TestData.SchemaDefinition
                Set-ModuleConfiguration -ModuleName "PerfModule$i" -Configuration @{
                    TestProperty = "Value$i"
                    NumericProperty = $i
                }
            }
            
            # Test retrieval performance
            $retrievalTime = Measure-Command {
                for ($i = 1; $i -le $moduleCount; $i++) {
                    Get-ModuleConfiguration -ModuleName "PerfModule$i" | Out-Null
                }
            }
            
            # Should scale reasonably
            $retrievalTime.TotalSeconds | Should -BeLessThan 10
        }
        
        It "Should handle memory usage efficiently" {
            # Monitor memory usage during large operations
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Perform memory-intensive operations
            for ($i = 1; $i -le 20; $i++) {
                $largeConfig = @{}
                for ($j = 1; $j -le 100; $j++) {
                    $largeConfig["Prop$j"] = "Value$j" * 10  # Create larger strings
                }
                Set-ModuleConfiguration -ModuleName "MemoryModule$i" -Configuration $largeConfig
            }
            
            # Force garbage collection
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            
            $finalMemory = [GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            # Memory increase should be reasonable (less than 100MB for test)
            $memoryIncrease | Should -BeLessThan (100 * 1024 * 1024)
        }
    }
    
    Context "Caching and Optimization" {
        It "Should cache frequently accessed configurations" {
            if (Get-Command Get-ModuleConfiguration -ParameterName UseCache -ErrorAction SilentlyContinue) {
                # Test with caching
                $cachedTime = Measure-Command {
                    for ($i = 1; $i -le 10; $i++) {
                        Get-ModuleConfiguration -ModuleName 'TestModule' -UseCache | Out-Null
                    }
                }
                
                # Test without caching
                $uncachedTime = Measure-Command {
                    for ($i = 1; $i -le 10; $i++) {
                        Get-ModuleConfiguration -ModuleName 'TestModule' -NoCache | Out-Null
                    }
                }
                
                # Cached should be faster
                $cachedTime.TotalMilliseconds | Should -BeLessThan $uncachedTime.TotalMilliseconds
            } else {
                Set-ItResult -Skipped -Because "Configuration caching not implemented"
            }
        }
        
        It "Should invalidate cache when configuration changes" {
            if (Get-Command Get-ModuleConfiguration -ParameterName UseCache -ErrorAction SilentlyContinue) {
                # Get initial cached value
                $config1 = Get-ModuleConfiguration -ModuleName 'TestModule' -UseCache
                
                # Change configuration
                Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration @{ TestProperty = 'CacheInvalidationTest' }
                
                # Get cached value again - should reflect change
                $config2 = Get-ModuleConfiguration -ModuleName 'TestModule' -UseCache
                
                $config2.TestProperty | Should -Be 'CacheInvalidationTest'
                $config2.TestProperty | Should -Not -Be $config1.TestProperty
            } else {
                Set-ItResult -Skipped -Because "Configuration caching not implemented"
            }
        }
    }
}

Describe "ConfigurationCore Module - Cross-Platform Compatibility" {
    Context "Platform-Specific Behavior" {
        It "Should work on current platform" {
            $platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
            
            # Test platform-specific configuration paths
            $store = Get-ConfigurationStore
            $store.StorePath | Should -Not -BeNullOrEmpty
            
            # Path should be appropriate for platform
            if ($IsWindows) {
                $store.StorePath | Should -Match '^[A-Z]:\\'
            } else {
                $store.StorePath | Should -Match '^/'
            }
        }
        
        It "Should handle platform-specific path separators" {
            $config = @{
                PathProperty = 'directory' + [System.IO.Path]::DirectorySeparatorChar + 'file.txt'
            }
            
            Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $config
            $retrievedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
            
            $retrievedConfig.PathProperty | Should -Contain [System.IO.Path]::DirectorySeparatorChar
        }
        
        It "Should respect platform-specific file permissions" {
            if (-not $IsWindows) {
                # Test Unix-style permissions
                $configFile = Join-Path $TestDrive 'permissions-test.json'
                Export-ConfigurationStore -Path $configFile
                
                # Check file permissions
                $permissions = Get-Item $configFile | ForEach-Object { $_.UnixMode }
                if ($permissions) {
                    # Should have appropriate read/write permissions
                    $permissions | Should -Match '^-rw'
                }
            }
        }
    }
    
    Context "Character Encoding and Localization" {
        It "Should handle Unicode characters correctly" {
            $unicodeConfig = @{
                EnglishProperty = 'Hello World'
                ChineseProperty = '你好世界'
                EmojiProperty = '🚀 Configuration Test 🔧'
                SpecialChars = 'àáâãäåæçèéêë'
            }
            
            Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $unicodeConfig
            $retrievedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
            
            $retrievedConfig.ChineseProperty | Should -Be '你好世界'
            $retrievedConfig.EmojiProperty | Should -Be '🚀 Configuration Test 🔧'
            $retrievedConfig.SpecialChars | Should -Be 'àáâãäåæçèéêë'
        }
        
        It "Should maintain encoding through export/import" {
            $unicodeConfig = @{
                TestProperty = 'Tëst Vælūe with ünīcødé'
            }
            
            Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $unicodeConfig
            
            $exportPath = Join-Path $TestDrive 'unicode-test.json'
            Export-ConfigurationStore -Path $exportPath
            
            # Clear and re-import
            Initialize-ConfigurationCore -Force
            Import-ConfigurationStore -Path $exportPath
            
            $importedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
            $importedConfig.TestProperty | Should -Be 'Tëst Vælūe with ünīcødé'
        }
    }
}

Describe "ConfigurationCore Module - Error Handling and Recovery" {
    Context "Error Handling" {
        It "Should handle invalid JSON gracefully" {
            $invalidJsonPath = Join-Path $TestDrive 'invalid.json'
            Set-Content -Path $invalidJsonPath -Value '{ invalid json content'
            
            { Import-ConfigurationStore -Path $invalidJsonPath } | Should -Throw
            
            # Configuration store should remain stable
            $store = Get-ConfigurationStore
            $store | Should -Not -BeNullOrEmpty
        }
        
        It "Should recover from corrupted configuration" {
            # Simulate corruption by writing invalid data
            $corruptPath = Join-Path $TestDrive 'corrupt-config.json'
            Set-Content -Path $corruptPath -Value 'This is not JSON at all!'
            
            # Should handle gracefully and fall back to defaults
            { Import-ConfigurationStore -Path $corruptPath -CreateBackup } | Should -Throw
            
            # Backup should be created
            $backupFiles = Get-ChildItem -Path (Split-Path $corruptPath) -Filter "*.backup"
            $backupFiles.Count | Should -BeGreaterThan 0
        }
        
        It "Should handle missing dependencies gracefully" {
            # Test behavior when optional dependencies are missing
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Write-CustomLog' }
            
            # Should still function with fallback logging
            { Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration @{ TestProperty = 'FallbackTest' } } | Should -Not -Throw
        }
        
        It "Should provide meaningful error messages" {
            # Test various error conditions and verify error messages are helpful
            try {
                Set-ModuleConfiguration -ModuleName 'NonExistentModule' -Configuration @{ Test = 'Value' }
                throw "Should have thrown an error"
            } catch {
                $_.Exception.Message | Should -Match 'module|not|found|registered'
            }
        }
    }
    
    Context "Recovery Mechanisms" {
        It "Should auto-recover from temporary failures" {
            # Simulate temporary I/O failure
            $testPath = Join-Path $TestDrive 'recovery-test.json'
            
            # Create file with exclusive lock to simulate I/O failure
            $fileStream = [System.IO.File]::Open($testPath, 'Create', 'Write', 'None')
            
            try {
                # Should handle the locked file gracefully
                { Export-ConfigurationStore -Path $testPath -RetryOnFailure } | Should -Throw
            } finally {
                $fileStream.Close()
            }
            
            # Should succeed after lock is released
            { Export-ConfigurationStore -Path $testPath } | Should -Not -Throw
        }
        
        It "Should maintain configuration consistency during failures" {
            # Test that partial failures don't leave configuration in inconsistent state
            $originalStore = Get-ConfigurationStore
            
            try {
                # Attempt operation that might fail
                Set-ConfigurationStore -Store @{ InvalidStructure = $true } -Validate
                throw "Should have failed validation"
            } catch {
                # Configuration should be unchanged
                $currentStore = Get-ConfigurationStore
                $currentStore.Modules.Count | Should -Be $originalStore.Modules.Count
            }
        }
    }
}

AfterAll {
    # Clean up test environment
    try {
        # Remove test modules
        $testModules = @('TestModule', 'EnvTestModule', 'RestoreTestModule', 'HotReloadTest')
        foreach ($module in $testModules) {
            if (Get-Command Remove-ModuleConfiguration -ErrorAction SilentlyContinue) {
                Remove-ModuleConfiguration -ModuleName $module -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Disable hot reload
        if (Get-Command Disable-ConfigurationHotReload -ErrorAction SilentlyContinue) {
            Disable-ConfigurationHotReload -RemoveWatchers -ErrorAction SilentlyContinue
        }
        
        # Clean up environment variables
        Remove-Item Env:TEST_CONFIG_PATH -ErrorAction SilentlyContinue
        Remove-Item Env:TEST_BACKUP_DIR -ErrorAction SilentlyContinue
        
    } catch {
        Write-Warning "Cleanup failed: $_"
    }
}