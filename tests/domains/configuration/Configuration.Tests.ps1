# Configuration Domain Tests - Comprehensive Coverage
# Tests for Configuration domain functions
# Total Expected Functions: 36

BeforeAll {
    # Setup test environment
    $script:ProjectRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
    $script:DomainsPath = Join-Path $ProjectRoot "aither-core/domains"
    $script:TestDataPath = Join-Path $PSScriptRoot "test-data"
    
    # Import logging module first
    $LoggingModulePath = Join-Path $ProjectRoot "aither-core/modules/Logging/Logging.psm1"
    if (Test-Path $LoggingModulePath) {
        Import-Module $LoggingModulePath -Force
    }
    
    # Import test helpers
    $TestHelpersPath = Join-Path $ProjectRoot "tests/TestHelpers.psm1"
    if (Test-Path $TestHelpersPath) {
        Import-Module $TestHelpersPath -Force
    }
    
    # Import configuration domain
    $ConfigurationDomainPath = Join-Path $DomainsPath "configuration/Configuration.ps1"
    if (Test-Path $ConfigurationDomainPath) {
        . $ConfigurationDomainPath
    }
    
    # Create test data directory
    if (-not (Test-Path $TestDataPath)) {
        New-Item -Path $TestDataPath -ItemType Directory -Force
    }
    
    # Test configuration data
    $script:TestConfig = @{
        TestKey = "TestValue"
        NestedConfig = @{
            SubKey = "SubValue"
        }
    }
    
    $script:TestConfigPath = Join-Path $TestDataPath "test-config.json"
}

Describe "Configuration Domain - Security Functions" {
    Context "Configuration Security" {
        It "Test-ConfigurationSecurity should validate security settings" {
            Mock Write-CustomLog { }
            
            $result = Test-ConfigurationSecurity -ConfigPath $TestConfigPath
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [bool]
        }
        
        It "Get-ConfigurationHash should generate configuration hash" {
            Mock Write-CustomLog { }
            $TestConfig | ConvertTo-Json | Out-File -FilePath $TestConfigPath
            
            $result = Get-ConfigurationHash -ConfigPath $TestConfigPath
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match "^[A-F0-9]{64}$"
        }
    }
}

Describe "Configuration Domain - Validation Functions" {
    Context "Configuration Validation" {
        It "Validate-Configuration should validate configuration structure" {
            Mock Write-CustomLog { }
            $TestConfig | ConvertTo-Json | Out-File -FilePath $TestConfigPath
            
            $result = Validate-Configuration -ConfigPath $TestConfigPath
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [bool]
        }
        
        It "Test-ConfigurationSchema should validate against schema" {
            Mock Write-CustomLog { }
            $schema = @{
                type = "object"
                properties = @{
                    TestKey = @{ type = "string" }
                }
            }
            
            $result = Test-ConfigurationSchema -Configuration $TestConfig -Schema $schema
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [bool]
        }
    }
}

Describe "Configuration Domain - Storage Functions" {
    Context "Configuration Storage Management" {
        It "Initialize-ConfigurationStorePath should create storage path" {
            Mock Write-CustomLog { }
            $storePath = Join-Path $TestDataPath "config-store"
            
            { Initialize-ConfigurationStorePath -StorePath $storePath } | Should -Not -Throw
        }
        
        It "Save-ConfigurationStore should save configuration store" {
            Mock Write-CustomLog { }
            $storePath = Join-Path $TestDataPath "config-store"
            New-Item -Path $storePath -ItemType Directory -Force
            
            { Save-ConfigurationStore -StorePath $storePath -Configuration $TestConfig } | Should -Not -Throw
        }
        
        It "Import-ExistingConfiguration should import existing configuration" {
            Mock Write-CustomLog { }
            $TestConfig | ConvertTo-Json | Out-File -FilePath $TestConfigPath
            
            $result = Import-ExistingConfiguration -ConfigPath $TestConfigPath
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Invoke-BackupCleanup should clean up old backups" {
            Mock Write-CustomLog { }
            Mock Get-ChildItem { return @() }
            Mock Remove-Item { }
            
            { Invoke-BackupCleanup -BackupPath $TestDataPath } | Should -Not -Throw
        }
    }
}

Describe "Configuration Domain - Core Functions" {
    Context "Configuration Core Management" {
        It "Initialize-ConfigurationCore should initialize core system" {
            Mock Write-CustomLog { }
            Mock Initialize-ConfigurationStorePath { }
            Mock Initialize-DefaultSchemas { }
            
            { Initialize-ConfigurationCore } | Should -Not -Throw
        }
        
        It "Initialize-DefaultSchemas should create default schemas" {
            Mock Write-CustomLog { }
            Mock New-Item { }
            
            { Initialize-DefaultSchemas } | Should -Not -Throw
        }
        
        It "Get-ConfigurationStore should retrieve configuration store" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"test": "value"}' }
            
            $result = Get-ConfigurationStore -StoreName "test-store"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Set-ConfigurationStore should update configuration store" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Set-Content { }
            
            { Set-ConfigurationStore -StoreName "test-store" -Configuration $TestConfig } | Should -Not -Throw
        }
    }
}

Describe "Configuration Domain - Module Configuration Functions" {
    Context "Module Configuration Management" {
        It "Get-ModuleConfiguration should retrieve module configuration" {
            Mock Write-CustomLog { }
            Mock Get-ConfigurationStore { return $TestConfig }
            
            $result = Get-ModuleConfiguration -ModuleName "TestModule"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Set-ModuleConfiguration should update module configuration" {
            Mock Write-CustomLog { }
            Mock Get-ConfigurationStore { return @{} }
            Mock Set-ConfigurationStore { }
            
            { Set-ModuleConfiguration -ModuleName "TestModule" -Configuration $TestConfig } | Should -Not -Throw
        }
        
        It "Register-ModuleConfiguration should register module configuration" {
            Mock Write-CustomLog { }
            Mock Get-ConfigurationRegistry { return @{} }
            Mock Set-ConfigurationRegistry { }
            
            { Register-ModuleConfiguration -ModuleName "TestModule" -ConfigurationSchema @{} } | Should -Not -Throw
        }
    }
}

Describe "Configuration Domain - Carousel Functions" {
    Context "Configuration Carousel Management" {
        It "Initialize-ConfigurationCarousel should initialize carousel" {
            Mock Write-CustomLog { }
            Mock Initialize-ConfigurationStorePath { }
            Mock New-Item { }
            
            { Initialize-ConfigurationCarousel } | Should -Not -Throw
        }
        
        It "Get-ConfigurationRegistry should retrieve registry" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{}' }
            
            $result = Get-ConfigurationRegistry
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Set-ConfigurationRegistry should update registry" {
            Mock Write-CustomLog { }
            Mock Set-Content { }
            
            { Set-ConfigurationRegistry -Registry @{} } | Should -Not -Throw
        }
        
        It "Switch-ConfigurationSet should switch configuration sets" {
            Mock Write-CustomLog { }
            Mock Get-ConfigurationRegistry { return @{ "test-config" = @{} } }
            Mock Backup-CurrentConfiguration { }
            Mock Set-ConfigurationStore { }
            
            { Switch-ConfigurationSet -ConfigurationName "test-config" } | Should -Not -Throw
        }
        
        It "Get-AvailableConfigurations should list available configurations" {
            Mock Write-CustomLog { }
            Mock Get-ConfigurationRegistry { return @{ "config1" = @{}; "config2" = @{} } }
            
            $result = Get-AvailableConfigurations
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
        }
        
        It "Add-ConfigurationRepository should add repository" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $false }
            Mock git { return "success" }
            Mock Get-ConfigurationRegistry { return @{} }
            Mock Set-ConfigurationRegistry { }
            
            { Add-ConfigurationRepository -Name "test-repo" -Source "https://github.com/test/repo.git" } | Should -Not -Throw
        }
    }
}

Describe "Configuration Domain - Current Configuration Functions" {
    Context "Current Configuration Management" {
        It "Get-CurrentConfiguration should retrieve current configuration" {
            Mock Write-CustomLog { }
            Mock Get-ConfigurationStore { return $TestConfig }
            
            $result = Get-CurrentConfiguration
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Backup-CurrentConfiguration should backup current configuration" {
            Mock Write-CustomLog { }
            Mock Get-CurrentConfiguration { return $TestConfig }
            Mock New-Item { }
            Mock Set-Content { }
            
            { Backup-CurrentConfiguration -Reason "Test backup" } | Should -Not -Throw
        }
        
        It "Validate-ConfigurationSet should validate configuration set" {
            Mock Write-CustomLog { }
            Mock Get-ConfigurationRegistry { return @{ "test-config" = @{} } }
            Mock Test-Path { return $true }
            Mock Get-Content { return '{"valid": true}' }
            
            $result = Validate-ConfigurationSet -ConfigurationName "test-config"
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [bool]
        }
    }
}

Describe "Configuration Domain - Event Functions" {
    Context "Configuration Event Management" {
        It "Publish-ConfigurationEvent should publish events" {
            Mock Write-CustomLog { }
            Mock Get-Date { return (Get-Date) }
            
            { Publish-ConfigurationEvent -EventType "ConfigurationChanged" -EventData $TestConfig } | Should -Not -Throw
        }
        
        It "Subscribe-ConfigurationEvent should subscribe to events" {
            Mock Write-CustomLog { }
            
            { Subscribe-ConfigurationEvent -EventType "ConfigurationChanged" -Handler { param($data) } } | Should -Not -Throw
        }
        
        It "Unsubscribe-ConfigurationEvent should unsubscribe from events" {
            Mock Write-CustomLog { }
            
            { Unsubscribe-ConfigurationEvent -EventType "ConfigurationChanged" -Handler { param($data) } } | Should -Not -Throw
        }
        
        It "Get-ConfigurationEventHistory should retrieve event history" {
            Mock Write-CustomLog { }
            
            $result = Get-ConfigurationEventHistory -EventType "ConfigurationChanged"
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Configuration Domain - Environment Functions" {
    Context "Configuration Environment Management" {
        It "New-ConfigurationEnvironment should create new environment" {
            Mock Write-CustomLog { }
            Mock New-Item { }
            Mock Set-Content { }
            
            { New-ConfigurationEnvironment -EnvironmentName "test-env" -BaseConfiguration $TestConfig } | Should -Not -Throw
        }
        
        It "Get-ConfigurationEnvironment should retrieve environment" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return ($TestConfig | ConvertTo-Json) }
            
            $result = Get-ConfigurationEnvironment -EnvironmentName "test-env"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Set-ConfigurationEnvironment should update environment" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Set-Content { }
            
            { Set-ConfigurationEnvironment -EnvironmentName "test-env" -Configuration $TestConfig } | Should -Not -Throw
        }
    }
}

Describe "Configuration Domain - Backup and Restore Functions" {
    Context "Configuration Backup and Restore" {
        It "Backup-Configuration should backup configuration" {
            Mock Write-CustomLog { }
            Mock Get-CurrentConfiguration { return $TestConfig }
            Mock New-Item { }
            Mock Set-Content { }
            
            { Backup-Configuration -BackupName "test-backup" } | Should -Not -Throw
        }
        
        It "Restore-Configuration should restore configuration" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return ($TestConfig | ConvertTo-Json) }
            Mock Set-ConfigurationStore { }
            
            { Restore-Configuration -BackupName "test-backup" } | Should -Not -Throw
        }
        
        It "Test-ConfigurationAccessible should test configuration accessibility" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            
            $result = Test-ConfigurationAccessible -ConfigPath $TestConfigPath
            $result | Should -BeOfType [bool]
        }
    }
}

Describe "Configuration Domain - Advanced Functions" {
    Context "Advanced Configuration Management" {
        It "Apply-ConfigurationSet should apply configuration set" {
            Mock Write-CustomLog { }
            Mock Get-ConfigurationRegistry { return @{ "test-config" = $TestConfig } }
            Mock Set-ConfigurationStore { }
            
            { Apply-ConfigurationSet -ConfigurationName "test-config" } | Should -Not -Throw
        }
        
        It "New-ConfigurationFromTemplate should create configuration from template" {
            Mock Write-CustomLog { }
            Mock Test-Path { return $true }
            Mock Get-Content { return ($TestConfig | ConvertTo-Json) }
            Mock New-Item { }
            Mock Set-Content { }
            
            { New-ConfigurationFromTemplate -TemplateName "test-template" -ConfigurationName "new-config" } | Should -Not -Throw
        }
    }
}

AfterAll {
    # Clean up test environment
    if (Test-Path $TestDataPath) {
        Remove-Item -Path $TestDataPath -Recurse -Force
    }
}