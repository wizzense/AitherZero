#Requires -Version 7.0

BeforeAll {
    # Import the core module which loads all domains
    $projectRoot = Split-Path -Parent -Path $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
    Import-Module (Join-Path $projectRoot "AitherZeroCore.psm1") -Force
}

Describe "Configuration Module Tests" {
    BeforeEach {
        # Reset configuration for each test
        $script:TestConfigPath = Join-Path $TestDrive "test-config.json"
        Initialize-ConfigurationSystem -ConfigPath $script:TestConfigPath
    }
    
    Context "Get-Configuration" {
        It "Should return default configuration when no file exists" {
            $config = Get-Configuration
            
            $config | Should -Not -BeNullOrEmpty
            $config.Core | Should -Not -BeNullOrEmpty
            $config.Core.Name | Should -Be "AitherZero"
            $config.Core.Version | Should -Be "1.0.0"
        }
        
        It "Should return specific section when requested" {
            $logging = Get-Configuration -Section "Logging"
            
            $logging | Should -Not -BeNullOrEmpty
            $logging.Level | Should -Be "Information"
            $logging.Path | Should -Be "./logs"
        }
        
        It "Should return specific key when requested" {
            $level = Get-Configuration -Section "Logging" -Key "Level"
            
            $level | Should -Be "Information"
        }
        
        It "Should return null for non-existent section" {
            $result = Get-Configuration -Section "NonExistent" -WarningAction SilentlyContinue
            
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Set-Configuration" {
        It "Should update configuration and save to file" {
            $newConfig = [PSCustomObject]@{
                Core = [PSCustomObject]@{
                    Name = "TestProject"
                    Version = "2.0.0"
                }
            }
            
            Set-Configuration -Configuration $newConfig

            # Verify file was created
            Test-Path $script:TestConfigPath | Should -Be $true

            # Verify content
            $savedConfig = Get-Content $script:TestConfigPath -Raw | ConvertFrom-Json
            $savedConfig.Core.Name | Should -Be "TestProject"
            $savedConfig.Core.Version | Should -Be "2.0.0"
        }
    }
    
    Context "Environment Switching" {
        It "Should switch between environments" {
            Switch-ConfigurationEnvironment -Environment "Production"
            
            $config = Get-Configuration
            $config.Core.Environment | Should -Be "Production"
        }
        
        It "Should validate environment names" {
            { Switch-ConfigurationEnvironment -Environment "InvalidEnv" } | Should -Throw
        }
    }
    
    Context "Configuration Validation" {
        It "Should pass validation for valid configuration" {
            $result = Test-Configuration
            
            $result | Should -Be $true
        }
        
        It "Should fail validation for invalid configuration" {
            # Set invalid configuration
            $invalidConfig = [PSCustomObject]@{
                InvalidSection = @{
                    SomeKey = "SomeValue"
                }
            }
            Set-Configuration -Configuration $invalidConfig
            
            $result = Test-Configuration
            
            $result | Should -Be $false
        }
        
        It "Should throw on validation error when requested" {
            # Set invalid configuration
            $invalidConfig = [PSCustomObject]@{
                InvalidSection = @{
                    SomeKey = "SomeValue"
                }
            }
            Set-Configuration -Configuration $invalidConfig
            
            { Test-Configuration -ThrowOnError } | Should -Throw
        }
    }
    
    Context "Import/Export Configuration" {
        It "Should export configuration to file" {
            $exportPath = Join-Path $TestDrive "exported-config.json"
            
            Export-Configuration -Path $exportPath
            
            Test-Path $exportPath | Should -Be $true
            
            $exported = Get-Content $exportPath -Raw | ConvertFrom-Json
            $exported.Core.Name | Should -Be "AitherZero"
        }
        
        It "Should import configuration from file" {
            $importPath = Join-Path $TestDrive "import-config.json"
            
            $importConfig = [PSCustomObject]@{
                Core = [PSCustomObject]@{
                    Name = "ImportedProject"
                    Version = "3.0.0"
                }
            }
            
            $importConfig | ConvertTo-Json -Depth 10 | Set-Content $importPath
            
            Import-Configuration -Path $importPath
            
            $config = Get-Configuration
            $config.Core.Name | Should -Be "ImportedProject"
            $config.Core.Version | Should -Be "3.0.0"
        }
        
        It "Should merge configuration when requested" {
            # Set initial config with custom value
            $initialConfig = Get-Configuration
            $initialConfig | Add-Member -NotePropertyName "CustomSection" -NotePropertyValue @{ Value = "Original" }
            Set-Configuration -Configuration $initialConfig

            # Create import config
            $importPath = Join-Path $TestDrive "merge-config.json"
            $mergeConfig = [PSCustomObject]@{
                Core = [PSCustomObject]@{
                    Version = "4.0.0"
                }
            }
            $mergeConfig | ConvertTo-Json -Depth 10 | Set-Content $importPath
            
            Import-Configuration -Path $importPath -Merge
            
            $config = Get-Configuration
            $config.Core.Name | Should -Be "AitherZero" # Original value preserved
            $config.Core.Version | Should -Be "4.0.0" # New value merged
            $config.CustomSection.Value | Should -Be "Original" # Custom section preserved
        }
    }
    
    AfterAll {
        # Clean up
        Remove-Module AitherZeroCore -Force -ErrorAction SilentlyContinue
    }
}