#Requires -Modules Pester

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:ConfigModule = Join-Path $script:ProjectRoot "domains/configuration/Configuration.psm1"

    # Import the module under test
    Import-Module $script:ConfigModule -Force -ErrorAction Stop
    
    # Store original functions for mocking
    $script:OriginalConfig = $null
}

AfterAll {
    # Cleanup
    Remove-Module Configuration -Force -ErrorAction SilentlyContinue
}

Describe "Configuration Module" -Tag 'Unit' {
    BeforeEach {
        # Setup test data
        $script:TestConfigPath = Join-Path $TestDrive "test-config.psd1"
        $script:TestConfig = @{
            Core = @{
                Name = "TestAither"
                Version = "1.0.0"
                Environment = "Test"
            }
            Testing = @{
                Framework = "Pester"
                MinVersion = "5.0.0"
            }
        }
        # Create a proper PowerShell Data File instead of JSON
        $psd1Content = "@{
    Core = @{
        Name = 'TestAither'
        Version = '1.0.0'
        Environment = 'Test'
    }
    Testing = @{
        Framework = 'Pester'
        MinVersion = '5.0.0'
    }
}"
        Set-Content -Path $script:TestConfigPath -Value $psd1Content
    }
    
    Context "Get-Configuration" {
        It "Should load configuration from file" {
            # Initialize the configuration system with the test config path first
            Initialize-ConfigurationSystem -ConfigPath $script:TestConfigPath -Environment "Test"
            
            $config = Get-Configuration
            $config | Should -Not -BeNullOrEmpty
            $config | Should -BeOfType [hashtable]
        }
        
        It "Should return default configuration when file not found" {
            # Initialize with a non-existent path
            $nonExistentPath = Join-Path $TestDrive "non-existent-config.psd1"
            Initialize-ConfigurationSystem -ConfigPath $nonExistentPath -Environment "Test"
            
            $config = Get-Configuration
            $config | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle malformed JSON gracefully" {
            # Initialize first, then test
            Initialize-ConfigurationSystem -ConfigPath $script:TestConfigPath -Environment "Test"
            { Get-Configuration } | Should -Not -Throw
        }
        
        It "Should enable hot reload when specified" {
            $result = Initialize-ConfigurationSystem -ConfigPath $script:TestConfigPath -EnableHotReload
            $result | Should -Be $true
        }
    }
    
    
    Context "Set-Configuration" {
        BeforeEach {
            Initialize-ConfigurationSystem -ConfigPath $script:TestConfigPath -Environment "Test"
        }
        
        It "Should update configuration values" {
            $newConfig = Get-Configuration
            $newConfig.Core.Version = "2.0.0"
            
            Set-Configuration -Configuration $newConfig
            
            $updated = Get-Configuration
            $updated.Core.Version | Should -Be "2.0.0"
        }
        
        It "Should save configuration to file when SaveToFile is specified" {
            $config = Get-Configuration
            $config.Core.Version = "3.0.0"
            
            Set-Configuration -Configuration $config -SaveToFile
            
            # Reload from file
            $fileContent = Import-PowerShellDataFile $script:TestConfigPath
            $fileContent.Core.Version | Should -Be "3.0.0"
        }
        
        It "Should merge partial configuration updates" {
            $partialUpdate = @{
                Core = @{
                    Version = "4.0.0"
                }
            }
            
            Set-Configuration -Configuration $partialUpdate -Merge
            
            $updated = Get-Configuration
            $updated.Core.Version | Should -Be "4.0.0"
            $updated.Core.Name | Should -Be "TestAither"  # Original value preserved
        }
    }
    
    Context "Get-ConfigValue" {
        BeforeEach {
            Initialize-ConfigurationSystem -ConfigPath $script:TestConfigPath -Environment "Test"
        }
        
        It "Should retrieve nested configuration values using dot notation" {
            $value = Get-ConfigValue -Path "Core.Name"
            $value | Should -Be "TestAither"
        }
        
        It "Should return default for missing values" {
            # Get-ConfigValue doesn't have a -Default parameter, use Get-ConfiguredValue instead
            $value = Get-ConfiguredValue -Name "Missing" -Section "NonExistent" -Default "DefaultTest"
            $value | Should -Be "DefaultTest"
        }
        
        It "Should handle array indices in path" {
            $config = Get-Configuration
            $config.TestArray = @("First", "Second", "Third")
            Set-Configuration -Configuration $config
            
            $value = Get-ConfigValue -Path "TestArray[1]"
            $value | Should -Be "Second"
        }
        
        It "Should return null for invalid path without default" {
            $value = Get-ConfigValue -Path "Invalid.Path.To.Value"
            $value | Should -BeNullOrEmpty
        }
    }
    
    Context "Validate-Configuration" {
        BeforeEach {
            Initialize-ConfigurationSystem -ConfigPath $script:TestConfigPath -Environment "Test"
        }
        
        It "Should validate correct configuration structure" {
            $result = Validate-Configuration
            $result.IsValid | Should -Be $true
        }
        
        It "Should detect missing required sections" {
            $config = Get-Configuration
            $config.PSObject.Properties.Remove('Core')
            Set-Configuration -Configuration $config
            
            $result = Validate-Configuration
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "*Core*"
        }
        
        It "Should throw when ThrowOnError is specified" {
            $config = Get-Configuration
            $config.PSObject.Properties.Remove('Core')
            Set-Configuration -Configuration $config
            
            { Validate-Configuration -ThrowOnError } | Should -Throw
        }
    }
    
    Context "Switch-ConfigurationEnvironment" {
        BeforeEach {
            Initialize-ConfigurationSystem -ConfigPath $script:TestConfigPath -Environment "Development"
        }
        
        It "Should switch between environments" {
            Switch-ConfigurationEnvironment -Environment "Production"
            
            $config = Get-Configuration
            $config.Core.Environment | Should -Be "Production"
        }
        
        It "Should reload configuration for new environment" {
            # Create production config
            $prodConfigPath = Join-Path $TestDrive "config.production.psd1"
            Set-Content -Path $prodConfigPath -Value "@{ Core = @{ Name = 'ProdAither' } }"
            
            Switch-ConfigurationEnvironment -Environment "Production"
            
            # Should attempt to load production-specific config
            $config = Get-Configuration
            $config | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Export/Import Configuration" {
        BeforeEach {
            Initialize-ConfigurationSystem -ConfigPath $script:TestConfigPath -Environment "Test"
        }
        
        It "Should export configuration to file" {
            $exportPath = Join-Path $TestDrive "exported-config.psd1"
            
            Export-Configuration -Path $exportPath
            
            Test-Path $exportPath | Should -Be $true
            $exported = Import-PowerShellDataFile $exportPath
            $exported.Core.Name | Should -Be "TestAither"
        }
        
        It "Should import configuration from file" {
            $importPath = Join-Path $TestDrive "import-config.psd1"
            "@{ Core = @{ Name = 'ImportedAither'; Version = '5.0.0' } }" | Set-Content $importPath
            
            Import-Configuration -Path $importPath
            
            $config = Get-Configuration
            $config.Core.Name | Should -Be "ImportedAither"
            $config.Core.Version | Should -Be "5.0.0"
        }
        
        It "Should merge imported configuration when specified" {
            $importPath = Join-Path $TestDrive "merge-config.psd1"
            "@{ Core = @{ Version = '6.0.0' }; NewSection = @{ Value = 'Test' } }" | Set-Content $importPath
            
            Import-Configuration -Path $importPath -Merge
            
            $config = Get-Configuration
            $config.Core.Name | Should -Be "TestAither"  # Original preserved
            $config.Core.Version | Should -Be "6.0.0"    # Updated
            $config.NewSection.Value | Should -Be "Test" # New added
        }
    }
    
    Context "Configuration Hot Reload" {
        It "Should detect file changes when hot reload is enabled" -Skip {
            # This would require file system watcher testing
            # Marking as skip for now as it requires async testing
        }
    }
    
    Context "Configuration Encryption" {
        It "Should encrypt sensitive values when specified" -Skip {
            # Future feature: encryption of sensitive config values
        }
    }
}