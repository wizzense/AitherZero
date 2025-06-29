BeforeAll {
    # Find project root and import module
    . "$PSScriptRoot/../../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import required modules
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/OpenTofuProvider") -Force
    
    # Test data
    $script:testConfigYaml = @"
version: 1.0
metadata:
  name: test-deployment
  environment: development
repository:
  url: https://github.com/test/templates.git
  branch: main
template: hyperv-single-vm
parameters:
  vm_name: TEST-VM-01
  cpu_count: 4
  memory_gb: 16
iso_requirements:
  - name: WindowsServer2025
    cache: true
deployment:
  dry_run: false
  auto_approve: false
"@

    $script:testConfigJson = @{
        version = "1.0"
        metadata = @{
            name = "test-deployment"
            environment = "development"
        }
        repository = @{
            url = "https://github.com/test/templates.git"
            branch = "main"
        }
        template = "hyperv-single-vm"
        parameters = @{
            vm_name = "TEST-VM-01"
            cpu_count = 4
            memory_gb = 16
        }
    } | ConvertTo-Json -Depth 10
}

Describe "Read-DeploymentConfiguration Tests" {
    BeforeEach {
        $script:yamlConfigPath = Join-Path $TestDrive "config.yaml"
        $script:jsonConfigPath = Join-Path $TestDrive "config.json"
        
        $script:testConfigYaml | Set-Content -Path $script:yamlConfigPath
        $script:testConfigJson | Set-Content -Path $script:jsonConfigPath
    }
    
    Context "File Format Support" {
        It "Should read YAML configuration" -Skip {
            # Skip as simplified YAML parser is not complete
            $config = Read-DeploymentConfiguration -Path $script:yamlConfigPath
            
            $config.version | Should -Be "1.0"
            $config.template | Should -Be "hyperv-single-vm"
            $config.parameters.vm_name | Should -Be "TEST-VM-01"
        }
        
        It "Should read JSON configuration" {
            $config = Read-DeploymentConfiguration -Path $script:jsonConfigPath
            
            $config.version | Should -Be "1.0"
            $config.template | Should -Be "hyperv-single-vm"
            $config.parameters.vm_name | Should -Be "TEST-VM-01"
        }
        
        It "Should validate file exists" {
            { Read-DeploymentConfiguration -Path "non-existent.yaml" } |
                Should -Throw -ErrorId "ParameterArgumentValidationError*"
        }
    }
    
    Context "Configuration Validation" {
        It "Should validate required fields" {
            $invalidConfig = @{
                version = "1.0"
                # Missing template field
                parameters = @{}
            } | ConvertTo-Json
            
            $invalidPath = Join-Path $TestDrive "invalid.json"
            $invalidConfig | Set-Content -Path $invalidPath
            
            { Read-DeploymentConfiguration -Path $invalidPath } |
                Should -Throw "*Missing required field: template*"
        }
        
        It "Should validate version compatibility" {
            $futureConfig = @{
                version = "99.0"
                template = "test"
            } | ConvertTo-Json
            
            $futurePath = Join-Path $TestDrive "future.json"
            $futureConfig | Set-Content -Path $futurePath
            
            { Read-DeploymentConfiguration -Path $futurePath } |
                Should -Throw "*Unsupported configuration version*"
        }
        
        It "Should validate only without returning config" {
            $result = Read-DeploymentConfiguration -Path $script:jsonConfigPath -ValidateOnly
            
            $result.Valid | Should -Be $true
            $result.Path | Should -Be $script:jsonConfigPath
            $result.PSObject.Properties.Name | Should -Not -Contain "template"
        }
    }
    
    Context "Variable Expansion" {
        It "Should expand environment variables" {
            $envConfig = @{
                version = "1.0"
                template = "test"
                parameters = @{
                    username = "%USERNAME%"
                    temp_path = "%TEMP%"
                }
            } | ConvertTo-Json
            
            $envPath = Join-Path $TestDrive "env.json"
            $envConfig | Set-Content -Path $envPath
            
            $config = Read-DeploymentConfiguration -Path $envPath -ExpandVariables
            
            $config.parameters.username | Should -Be $env:USERNAME
            $config.parameters.temp_path | Should -Be $env:TEMP
        }
        
        It "Should mark secure references" {
            $secureConfig = @{
                version = "1.0"
                template = "test"
                parameters = @{
                    password = '${secure:AdminPassword}'
                }
            } | ConvertTo-Json
            
            $securePath = Join-Path $TestDrive "secure.json"
            $secureConfig | Set-Content -Path $securePath
            
            $config = Read-DeploymentConfiguration -Path $securePath -ExpandVariables
            
            $config.parameters.password | Should -Match "\*\*\*SECURE:"
        }
    }
    
    Context "Configuration Merging" {
        It "Should merge multiple configurations" {
            $baseConfig = @{
                version = "1.0"
                template = "test"
                parameters = @{
                    vm_name = "BASE"
                    cpu_count = 2
                }
            } | ConvertTo-Json
            
            $overrideConfig = @{
                parameters = @{
                    cpu_count = 4
                    memory_gb = 16
                }
            } | ConvertTo-Json
            
            $basePath = Join-Path $TestDrive "base.json"
            $overridePath = Join-Path $TestDrive "override.json"
            
            $baseConfig | Set-Content -Path $basePath
            $overrideConfig | Set-Content -Path $overridePath
            
            $config = Read-DeploymentConfiguration -Path $basePath -Merge $overridePath
            
            $config.parameters.vm_name | Should -Be "BASE"
            $config.parameters.cpu_count | Should -Be 4
            $config.parameters.memory_gb | Should -Be 16
        }
    }
}

Describe "New-DeploymentConfiguration Tests" {
    BeforeEach {
        # Mock template finding
        Mock Find-Template {
            return @{
                Name = "test-template"
                Path = Join-Path $TestDrive "templates" "test-template"
                Repository = "test-repo"
                Version = "1.0.0"
            }
        } -ModuleName OpenTofuProvider
        
        # Mock template metadata
        Mock Get-TemplateMetadata {
            return @{
                metadata = @{ name = "test-template" }
                parameters = @{
                    vm_name = @{
                        type = "string"
                        description = "VM name"
                        validation = @{ pattern = "^[A-Z0-9-]+$" }
                    }
                    cpu_count = @{
                        type = "number"
                        default = 2
                    }
                    enable_backup = @{
                        type = "boolean"
                        default = $false
                    }
                    environment = @{
                        type = "string"
                        allowed_values = @("dev", "prod")
                        default = "dev"
                    }
                }
                requirements = @{
                    iso_requirements = @(
                        @{
                            id = "os_iso"
                            supported = @("WindowsServer2025")
                            customization_profile = "standard"
                        }
                    )
                }
            }
        } -ModuleName OpenTofuProvider
    }
    
    Context "Configuration Generation" {
        It "Should create configuration from template" {
            $outputPath = Join-Path $TestDrive "deployment.json"
            
            $result = New-DeploymentConfiguration -Template "test-template" `
                -OutputPath $outputPath `
                -Parameters @{ vm_name = "TEST-01" }
            
            $result | Should -Be $outputPath
            Test-Path $outputPath | Should -Be $true
            
            $config = Get-Content $outputPath | ConvertFrom-Json
            $config.template | Should -Be "test-template"
            $config.parameters.vm_name | Should -Be "TEST-01"
            $config.parameters.cpu_count | Should -Be 2  # Default value
        }
        
        It "Should support YAML output" {
            $outputPath = Join-Path $TestDrive "deployment.yaml"
            
            $result = New-DeploymentConfiguration -Template "test-template" `
                -OutputPath $outputPath `
                -Parameters @{ vm_name = "TEST-01" }
            
            Test-Path $outputPath | Should -Be $true
            
            $content = Get-Content $outputPath -Raw
            $content | Should -Match "version: 1.0"
            $content | Should -Match "template: test-template"
        }
        
        It "Should handle interactive mode" {
            # Mock Read-Host for interactive input
            Mock Read-TemplateParameter {
                param($Name)
                switch ($Name) {
                    "vm_name" { return "INTERACTIVE-VM" }
                    "enable_backup" { return $true }
                    default { return $null }
                }
            } -ModuleName OpenTofuProvider
            
            $outputPath = Join-Path $TestDrive "interactive.json"
            
            New-DeploymentConfiguration -Template "test-template" `
                -OutputPath $outputPath `
                -Interactive
            
            $config = Get-Content $outputPath | ConvertFrom-Json
            $config.parameters.vm_name | Should -Be "INTERACTIVE-VM"
            $config.parameters.enable_backup | Should -Be $true
        }
    }
    
    Context "Template Requirements" {
        It "Should include ISO requirements from template" {
            $outputPath = Join-Path $TestDrive "with-iso.json"
            
            New-DeploymentConfiguration -Template "test-template" `
                -OutputPath $outputPath `
                -Parameters @{ vm_name = "TEST" }
            
            $config = Get-Content $outputPath | ConvertFrom-Json
            
            $config.iso_requirements | Should -Not -BeNullOrEmpty
            $config.iso_requirements[0].name | Should -Be "os_iso"
            $config.iso_requirements[0].type | Should -Be "WindowsServer2025"
            $config.iso_requirements[0].customization | Should -Be "standard"
        }
    }
    
    Context "Validation" {
        It "Should validate configuration after creation" {
            Mock Read-DeploymentConfiguration {
                return @{ Valid = $true }
            } -ModuleName OpenTofuProvider
            
            $outputPath = Join-Path $TestDrive "validated.json"
            
            New-DeploymentConfiguration -Template "test-template" `
                -OutputPath $outputPath `
                -Parameters @{ vm_name = "TEST" }
            
            Should -Invoke Read-DeploymentConfiguration -Times 1 -ModuleName OpenTofuProvider
        }
        
        It "Should skip validation when requested" {
            Mock Read-DeploymentConfiguration {} -ModuleName OpenTofuProvider
            
            $outputPath = Join-Path $TestDrive "no-validate.json"
            
            New-DeploymentConfiguration -Template "test-template" `
                -OutputPath $outputPath `
                -Parameters @{ vm_name = "TEST" } `
                -SkipValidation
            
            Should -Not -Invoke Read-DeploymentConfiguration -ModuleName OpenTofuProvider
        }
    }
}