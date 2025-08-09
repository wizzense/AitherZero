#Requires -Modules Pester

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $script:ConfigModule = Join-Path $script:ProjectRoot "domains/configuration/Configuration.psm1"

    # Import the module under test
    Import-Module $script:ConfigModule -Force -ErrorAction Stop
}

AfterAll {
    # Cleanup
    Remove-Module Configuration -Force -ErrorAction SilentlyContinue
}

Describe "Configuration Module" {
    BeforeEach {
        # Setup test data
        $script:TestConfigPath = Join-Path $TestDrive "test-config.json"
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
        $script:TestConfig | ConvertTo-Json -Depth 5 | Set-Content $script:TestConfigPath
    }
    
    Context "Get-AitherConfiguration" {
        It "Should load configuration from file" {
            $config = Get-AitherConfiguration -ConfigPath $script:TestConfigPath
            $config | Should -Not -BeNullOrEmpty
            $config.Core.Name | Should -Be "TestAither"
        }
        
        It "Should return default configuration when file not found" {
            $config = Get-AitherConfiguration -ConfigPath "nonexistent.json"
            $config | Should -Not -BeNullOrEmpty
            $config.Core | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle malformed JSON gracefully" {
            "{ invalid json }" | Set-Content $script:TestConfigPath
            { Get-AitherConfiguration -ConfigPath $script:TestConfigPath } | Should -Not -Throw
        }
    }
    
    Context "Merge-Configuration" {
        It "Should merge configurations correctly" {
            $base = @{ Core = @{ Name = "Base" }; Feature = @{ Enabled = $false } }
            $override = @{ Core = @{ Version = "2.0" }; Feature = @{ Enabled = $true } }
            
            $result = Merge-Configuration -BaseConfiguration $base -OverrideConfiguration $override
            
            $result.Core.Name | Should -Be "Base"
            $result.Core.Version | Should -Be "2.0" 
            $result.Feature.Enabled | Should -Be $true
        }
        
        It "Should handle null configurations" {
            $base = @{ Core = @{ Name = "Base" } }
            $result = Merge-Configuration -BaseConfiguration $base -OverrideConfiguration $null
            $result.Core.Name | Should -Be "Base"
        }
    }
    
    Context "Get-ConfigurationValue" {
        It "Should retrieve nested configuration values" {
            $config = Get-AitherConfiguration -ConfigPath $script:TestConfigPath
            $value = Get-ConfigurationValue -Configuration $config -Path "Core.Name"
            $value | Should -Be "TestAither"
        }
        
        It "Should return default for missing values" {
            $config = Get-AitherConfiguration -ConfigPath $script:TestConfigPath
            $value = Get-ConfigurationValue -Configuration $config -Path "Missing.Value" -DefaultValue "DefaultTest"
            $value | Should -Be "DefaultTest"
        }
    }
}