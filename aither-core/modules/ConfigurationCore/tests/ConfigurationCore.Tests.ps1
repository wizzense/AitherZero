#Requires -Module Pester

<#
.SYNOPSIS
    Comprehensive test suite for ConfigurationCore module
.DESCRIPTION
    Tests all functionality of the ConfigurationCore module including:
    - Module initialization and configuration
    - Environment management
    - Schema validation
    - Hot reload functionality
    - Configuration backup and restore
    - Import/export operations
#>

BeforeAll {
    # Import required modules
    $ModulePath = Split-Path $PSScriptRoot -Parent
    Import-Module $ModulePath -Force

    # Mock Write-CustomLog if not available
    if (-not (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue)) {
        function Write-CustomLog {
            param([string]$Level, [string]$Message)
            Write-Host "[$Level] $Message"
        }
    }

    # Mock Publish-TestEvent if not available
    if (-not (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue)) {
        function Publish-TestEvent {
            param([string]$EventName, [hashtable]$EventData)
            # Mock implementation
        }
    }

    # Create test directory
    $TestConfigDir = Join-Path $TestDrive 'ConfigurationCore'
    New-Item -ItemType Directory -Path $TestConfigDir -Force | Out-Null

    # Set up test configuration path
    $TestConfigPath = Join-Path $TestConfigDir 'test-config.json'

    # Initialize configuration core with test path
    $script:ConfigurationStore = @{
        Modules = @{}
        Environments = @{
            'default' = @{
                Name = 'default'
                Description = 'Default test environment'
                Settings = @{}
            }
        }
        CurrentEnvironment = 'default'
        Schemas = @{}
        HotReload = @{
            Enabled = $false
            Watchers = @{}
        }
        StorePath = $TestConfigPath
    }
}

Describe "ConfigurationCore Module Tests" {
    Context "Module Import and Basic Functions" {
        It "Should import the module without errors" {
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }

        It "Should export all required functions" {
            $exportedFunctions = Get-Command -Module ConfigurationCore
            $exportedFunctions.Count | Should -BeGreaterThan 20
        }
    }

    Context "Configuration Store Management" {
        It "Should get configuration store" {
            $store = Get-ConfigurationStore
            $store | Should -Not -BeNullOrEmpty
            $store.Modules | Should -Not -BeNullOrEmpty
            $store.Environments | Should -Not -BeNullOrEmpty
        }

        It "Should get configuration store as JSON" {
            $json = Get-ConfigurationStore -AsJson
            $json | Should -Not -BeNullOrEmpty
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should set configuration store" {
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
        }

        It "Should export configuration store" {
            $exportPath = Join-Path $TestDrive 'exported-config.json'
            { Export-ConfigurationStore -Path $exportPath } | Should -Not -Throw
            Test-Path $exportPath | Should -Be $true
        }

        It "Should import configuration store" {
            $importPath = Join-Path $TestDrive 'exported-config.json'
            { Import-ConfigurationStore -Path $importPath } | Should -Not -Throw
        }
    }

    Context "Module Configuration Management" {
        BeforeEach {
            # Register a test module
            $testSchema = @{
                Properties = @{
                    TestProperty = @{
                        Type = 'string'
                        Default = 'DefaultValue'
                        Required = $true
                        Description = 'Test property'
                    }
                    NumericProperty = @{
                        Type = 'int'
                        Default = 42
                        Min = 1
                        Max = 100
                        Description = 'Numeric test property'
                    }
                }
            }

            Register-ModuleConfiguration -ModuleName 'TestModule' -Schema $testSchema
        }

        It "Should register module configuration" {
            $schema = Get-ConfigurationSchema -ModuleName 'TestModule'
            $schema | Should -Not -BeNullOrEmpty
            $schema.Properties.TestProperty | Should -Not -BeNullOrEmpty
        }

        It "Should get module configuration" {
            $config = Get-ModuleConfiguration -ModuleName 'TestModule'
            $config | Should -Not -BeNullOrEmpty
            $config.TestProperty | Should -Be 'DefaultValue'
        }

        It "Should set module configuration" {
            $newConfig = @{
                TestProperty = 'NewValue'
                NumericProperty = 50
            }

            { Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $newConfig } | Should -Not -Throw

            $retrievedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
            $retrievedConfig.TestProperty | Should -Be 'NewValue'
            $retrievedConfig.NumericProperty | Should -Be 50
        }

        It "Should validate module configuration" {
            $result = Test-ModuleConfiguration -ModuleName 'TestModule' -Detailed
            $result.IsValid | Should -Be $true
            $result.Errors.Count | Should -Be 0
        }

        It "Should merge module configuration" {
            $mergeConfig = @{
                NumericProperty = 75
                NewProperty = 'NewValue'
            }

            { Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $mergeConfig -Merge } | Should -Not -Throw

            $retrievedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
            $retrievedConfig.NumericProperty | Should -Be 75
            $retrievedConfig.NewProperty | Should -Be 'NewValue'
        }
    }

    Context "Environment Management" {
        It "Should get current environment" {
            $env = Get-ConfigurationEnvironment
            $env | Should -Not -BeNullOrEmpty
            $env.Name | Should -Be 'default'
            $env.IsCurrent | Should -Be $true
        }

        It "Should get all environments" {
            $envs = Get-ConfigurationEnvironment -All
            $envs | Should -Not -BeNullOrEmpty
            $envs.Count | Should -BeGreaterOrEqual 1
        }

        It "Should create new environment" {
            $newEnv = New-ConfigurationEnvironment -Name 'test-env' -Description 'Test environment'
            $newEnv | Should -Not -BeNullOrEmpty
            $newEnv.Name | Should -Be 'test-env'
            $newEnv.Description | Should -Be 'Test environment'
        }

        It "Should set active environment" {
            { Set-ConfigurationEnvironment -Name 'test-env' } | Should -Not -Throw
            $currentEnv = Get-ConfigurationEnvironment
            $currentEnv.Name | Should -Be 'test-env'
        }

        It "Should copy environment settings" {
            $copiedEnv = New-ConfigurationEnvironment -Name 'copied-env' -Description 'Copied environment' -CopyFrom 'test-env'
            $copiedEnv | Should -Not -BeNullOrEmpty
            $copiedEnv.Name | Should -Be 'copied-env'
        }

        It "Should remove environment" {
            { Remove-ConfigurationEnvironment -Name 'copied-env' -Force } | Should -Not -Throw
            $envs = Get-ConfigurationEnvironment -All
            $envs.Keys | Should -Not -Contain 'copied-env'
        }
    }

    Context "Schema Management" {
        It "Should get all schemas" {
            $schemas = Get-ConfigurationSchema -All
            $schemas | Should -Not -BeNullOrEmpty
            $schemas.Count | Should -BeGreaterOrEqual 1
        }

        It "Should get schema with defaults" {
            $schema = Get-ConfigurationSchema -ModuleName 'TestModule' -IncludeDefaults
            $schema | Should -Not -BeNullOrEmpty
            $schema.DefaultValues | Should -Not -BeNullOrEmpty
            $schema.DefaultValues.TestProperty | Should -Be 'DefaultValue'
        }
    }

    Context "Configuration Validation" {
        BeforeEach {
            # Ensure test module is registered
            $testSchema = @{
                Properties = @{
                    RequiredProperty = @{
                        Type = 'string'
                        Required = $true
                        Description = 'Required property'
                    }
                    ValidatedProperty = @{
                        Type = 'string'
                        ValidValues = @('option1', 'option2', 'option3')
                        Description = 'Property with valid values'
                    }
                    RangedProperty = @{
                        Type = 'int'
                        Min = 1
                        Max = 10
                        Description = 'Property with range validation'
                    }
                }
            }

            Register-ModuleConfiguration -ModuleName 'ValidationTestModule' -Schema $testSchema
        }

        It "Should validate valid configuration" {
            $validConfig = @{
                RequiredProperty = 'test'
                ValidatedProperty = 'option1'
                RangedProperty = 5
            }

            Set-ModuleConfiguration -ModuleName 'ValidationTestModule' -Configuration $validConfig
            $result = Test-ModuleConfiguration -ModuleName 'ValidationTestModule' -Detailed
            $result.IsValid | Should -Be $true
        }

        It "Should detect missing required property" {
            $invalidConfig = @{
                ValidatedProperty = 'option1'
            }

            { Set-ModuleConfiguration -ModuleName 'ValidationTestModule' -Configuration $invalidConfig } | Should -Throw
        }

        It "Should detect invalid enum value" {
            $invalidConfig = @{
                RequiredProperty = 'test'
                ValidatedProperty = 'invalid_option'
            }

            { Set-ModuleConfiguration -ModuleName 'ValidationTestModule' -Configuration $invalidConfig } | Should -Throw
        }

        It "Should detect out of range value" {
            $invalidConfig = @{
                RequiredProperty = 'test'
                RangedProperty = 15
            }

            { Set-ModuleConfiguration -ModuleName 'ValidationTestModule' -Configuration $invalidConfig } | Should -Throw
        }
    }

    Context "Hot Reload Functionality" {
        It "Should enable hot reload" {
            { Enable-ConfigurationHotReload } | Should -Not -Throw
            $watcher = Get-ConfigurationWatcher
            $watcher.HotReloadEnabled | Should -Be $true
        }

        It "Should get watcher information" {
            $watchers = Get-ConfigurationWatcher -All
            $watchers | Should -Not -BeNullOrEmpty
        }

        It "Should disable hot reload" {
            { Disable-ConfigurationHotReload -RemoveWatchers } | Should -Not -Throw
            $watcher = Get-ConfigurationWatcher
            $watcher.HotReloadEnabled | Should -Be $false
        }
    }

    Context "Configuration Comparison" {
        It "Should compare configurations" {
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
    }

    Context "Backup and Restore" {
        It "Should create configuration backup" {
            $backupResult = Backup-Configuration -Reason "Test backup"
            $backupResult | Should -Not -BeNullOrEmpty
            $backupResult.BackupPath | Should -Not -BeNullOrEmpty
            Test-Path $backupResult.BackupPath | Should -Be $true
        }

        It "Should restore configuration from backup" {
            # First create a backup
            $backupResult = Backup-Configuration -Reason "Test restore"

            # Modify current configuration
            Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration @{ TestProperty = 'ModifiedValue' }

            # Restore from backup
            $restoreResult = Restore-Configuration -Path $backupResult.BackupPath -Force
            $restoreResult | Should -Not -BeNullOrEmpty

            # Verify restoration
            $config = Get-ModuleConfiguration -ModuleName 'TestModule'
            $config.TestProperty | Should -Be 'DefaultValue'
        }
    }

    Context "Variable Expansion" {
        It "Should expand environment variables" {
            $config = @{
                PathProperty = '${ENV:TEMP}/test'
            }

            Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $config
            $expandedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
            $expandedConfig.PathProperty | Should -Match 'test$'
        }

        It "Should expand platform variables" {
            $config = @{
                PlatformProperty = '${PLATFORM}'
            }

            Set-ModuleConfiguration -ModuleName 'TestModule' -Configuration $config
            $expandedConfig = Get-ModuleConfiguration -ModuleName 'TestModule'
            $expandedConfig.PlatformProperty | Should -Match '^(Windows|Linux|macOS)$'
        }
    }
}

Describe "ConfigurationCore Integration Tests" {
    Context "Module Integration" {
        It "Should support module lifecycle" {
            # Register module
            $schema = @{
                Properties = @{
                    Setting1 = @{ Type = 'string'; Default = 'default1' }
                    Setting2 = @{ Type = 'int'; Default = 42 }
                }
            }

            Register-ModuleConfiguration -ModuleName 'IntegrationTestModule' -Schema $schema

            # Configure module
            $config = @{
                Setting1 = 'configured1'
                Setting2 = 100
            }

            Set-ModuleConfiguration -ModuleName 'IntegrationTestModule' -Configuration $config

            # Verify configuration
            $retrievedConfig = Get-ModuleConfiguration -ModuleName 'IntegrationTestModule'
            $retrievedConfig.Setting1 | Should -Be 'configured1'
            $retrievedConfig.Setting2 | Should -Be 100

            # Test validation
            Test-ModuleConfiguration -ModuleName 'IntegrationTestModule' | Should -Be $true
        }

        It "Should support environment-specific configuration" {
            # Create environments
            New-ConfigurationEnvironment -Name 'dev' -Description 'Development'
            New-ConfigurationEnvironment -Name 'prod' -Description 'Production'

            # Configure for dev environment
            Set-ConfigurationEnvironment -Name 'dev'
            Set-ModuleConfiguration -ModuleName 'IntegrationTestModule' -Configuration @{ Setting1 = 'dev-value' }

            # Configure for prod environment
            Set-ConfigurationEnvironment -Name 'prod'
            Set-ModuleConfiguration -ModuleName 'IntegrationTestModule' -Configuration @{ Setting1 = 'prod-value' }

            # Verify environment-specific configuration
            $devConfig = Get-ModuleConfiguration -ModuleName 'IntegrationTestModule' -Environment 'dev'
            $prodConfig = Get-ModuleConfiguration -ModuleName 'IntegrationTestModule' -Environment 'prod'

            $devConfig.Setting1 | Should -Be 'dev-value'
            $prodConfig.Setting1 | Should -Be 'prod-value'
        }
    }
}

AfterAll {
    # Clean up test configuration
    if (Test-Path $TestConfigPath) {
        Remove-Item $TestConfigPath -Force -ErrorAction SilentlyContinue
    }
}
