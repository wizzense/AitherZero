BeforeAll {
    # Find project root and import module
    . "$PSScriptRoot/../../../../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    
    # Import required modules
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/OpenTofuProvider") -Force
    
    # Mock environment
    $env:PROJECT_ROOT = $TestDrive
    
    # Create configs directory
    $configsDir = Join-Path $TestDrive "configs"
    New-Item -Path $configsDir -ItemType Directory -Force | Out-Null
    
    # Test data
    $script:testHyperVConfig = @{
        DefaultVMPath = Join-Path $TestDrive "VMs"
        DefaultVHDPath = Join-Path $TestDrive "VHDs"
        DefaultSwitchName = "Test Switch"
    }
    
    New-Item -Path $script:testHyperVConfig.DefaultVMPath -ItemType Directory -Force | Out-Null
    New-Item -Path $script:testHyperVConfig.DefaultVHDPath -ItemType Directory -Force | Out-Null
}

Describe "Get-InfrastructureProvider Tests" {
    BeforeEach {
        # Clear provider registry
        $script:infrastructureProviders = @{}
        
        # Mock functions
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        Mock Get-Module { 
            [PSCustomObject]@{ Name = "Hyper-V"; Version = "1.0" }
        } -ModuleName OpenTofuProvider
    }
    
    Context "Provider Discovery" {
        It "Should list available providers" {
            $providers = Get-InfrastructureProvider -ListAvailable
            
            $providers.Count | Should -BeGreaterThan 0
            $providers | Where-Object { $_.Name -eq "Hyper-V" } | Should -Not -BeNullOrEmpty
            $providers | Where-Object { $_.Name -eq "Azure" } | Should -Not -BeNullOrEmpty
        }
        
        It "Should get Hyper-V provider definition" {
            $providers = Get-InfrastructureProvider -ListAvailable -Name "Hyper-V"
            
            $hyperv = $providers | Where-Object { $_.Name -eq "Hyper-V" }
            $hyperv | Should -Not -BeNullOrEmpty
            $hyperv.Capabilities.SupportsVirtualMachines | Should -Be $true
            $hyperv.Capabilities.RequiresISO | Should -Be $true
        }
        
        It "Should filter by capability" {
            $providers = Get-InfrastructureProvider -ListAvailable -Capability "SupportsSnapshots"
            
            $providers.Count | Should -BeGreaterThan 0
            foreach ($provider in $providers) {
                $provider.Capabilities.SupportsSnapshots | Should -Be $true
            }
        }
        
        It "Should get registered providers when none exist" {
            $providers = Get-InfrastructureProvider
            
            $providers.Count | Should -Be 0
        }
    }
    
    Context "Provider Status" {
        It "Should mark unregistered providers as available" {
            $providers = Get-InfrastructureProvider -ListAvailable
            
            foreach ($provider in $providers) {
                $provider.Status | Should -Be "Available"
                $provider.Registered | Should -Not -Be $true
            }
        }
    }
}

Describe "Register-InfrastructureProvider Tests" {
    BeforeEach {
        # Clear provider registry
        $script:infrastructureProviders = @{}
        
        # Mock dependencies
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        Mock Get-Module { 
            [PSCustomObject]@{ Name = "Hyper-V"; Version = "1.0" }
        } -ModuleName OpenTofuProvider
        Mock Get-WindowsOptionalFeature { 
            [PSCustomObject]@{ State = "Enabled" }
        } -ModuleName OpenTofuProvider
        Mock Install-Module {} -ModuleName OpenTofuProvider
        Mock Set-SecureCredential {} -ModuleName OpenTofuProvider
        Mock Save-RegisteredProviders {} -ModuleName OpenTofuProvider
    }
    
    Context "Basic Registration" {
        It "Should register Hyper-V provider successfully" {
            { Register-InfrastructureProvider -Name "Hyper-V" } | Should -Not -Throw
            
            Should -Invoke Write-CustomLog -ModuleName OpenTofuProvider -ParameterFilter {
                $Message -like "*Successfully registered*Hyper-V*"
            }
        }
        
        It "Should register provider with custom configuration" {
            $config = @{
                DefaultVMPath = "C:\CustomVMs"
                DefaultSwitchName = "Custom Switch"
            }
            
            { Register-InfrastructureProvider -Name "Hyper-V" -Configuration $config } | Should -Not -Throw
            
            $script:infrastructureProviders["Hyper-V"].Configuration.DefaultVMPath | Should -Be "C:\CustomVMs"
        }
        
        It "Should prevent duplicate registration without Force" {
            Register-InfrastructureProvider -Name "Hyper-V"
            
            { Register-InfrastructureProvider -Name "Hyper-V" } | 
                Should -Throw "*already registered*"
        }
        
        It "Should allow re-registration with Force flag" {
            Register-InfrastructureProvider -Name "Hyper-V"
            
            { Register-InfrastructureProvider -Name "Hyper-V" -Force } | Should -Not -Throw
        }
    }
    
    Context "Validation" {
        It "Should fail for unknown provider" {
            { Register-InfrastructureProvider -Name "UnknownProvider" } |
                Should -Throw "*not found*"
        }
        
        It "Should skip validation when requested" {
            Mock Get-Module { $null } -ModuleName OpenTofuProvider
            
            { Register-InfrastructureProvider -Name "Hyper-V" -SkipValidation } | Should -Not -Throw
        }
        
        It "Should install missing modules when requested" {
            Mock Get-Module { $null } -ModuleName OpenTofuProvider
            
            Register-InfrastructureProvider -Name "Hyper-V" -Confirm:$false
            
            Should -Invoke Install-Module -ModuleName OpenTofuProvider
        }
    }
    
    Context "Credential Handling" {
        It "Should store credentials for providers that require them" {
            Mock Get-Command { [PSCustomObject]@{ Name = "Set-SecureCredential" } } -ModuleName OpenTofuProvider
            
            $cred = [PSCredential]::new("test", (ConvertTo-SecureString "password" -AsPlainText -Force))
            
            Register-InfrastructureProvider -Name "Azure" -Credential $cred
            
            Should -Invoke Set-SecureCredential -ModuleName OpenTofuProvider
        }
        
        It "Should warn about unnecessary credentials" {
            $cred = [PSCredential]::new("test", (ConvertTo-SecureString "password" -AsPlainText -Force))
            
            Register-InfrastructureProvider -Name "Hyper-V" -Credential $cred
            
            Should -Invoke Write-CustomLog -ModuleName OpenTofuProvider -ParameterFilter {
                $Level -eq "WARN" -and $Message -like "*does not require authentication*"
            }
        }
    }
}

Describe "Test-ProviderCapability Tests" {
    BeforeEach {
        # Register test provider
        $script:infrastructureProviders = @{
            "Hyper-V" = @{
                Name = "Hyper-V"
                Configuration = @{}
                RegisteredAt = Get-Date
            }
        }
        
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        Mock Get-InfrastructureProvider {
            [PSCustomObject]@{
                Name = "Hyper-V"
                Capabilities = @{
                    SupportsVirtualMachines = $true
                    SupportsSnapshots = $true
                    SupportsNetworking = $true
                    RequiresISO = $true
                    SupportsWindowsGuests = $true
                }
                Status = "Ready"
                Version = "1.0.0"
            }
        } -ModuleName OpenTofuProvider
    }
    
    Context "Capability Testing" {
        It "Should test single capability" {
            $result = Test-ProviderCapability -ProviderName "Hyper-V" -Capability "SupportsSnapshots"
            
            $result.HasCapability | Should -Be $true
            $result.SupportedCapabilities | Should -Contain "SupportsSnapshots"
            $result.UnsupportedCapabilities.Count | Should -Be 0
        }
        
        It "Should test multiple capabilities with OR logic" {
            $result = Test-ProviderCapability -ProviderName "Hyper-V" -Capability @("SupportsSnapshots", "SupportsStorage")
            
            $result.HasCapability | Should -Be $true
            $result.SupportedCapabilities | Should -Contain "SupportsSnapshots"
            $result.UnsupportedCapabilities | Should -Contain "SupportsStorage"
        }
        
        It "Should test multiple capabilities with AND logic" {
            $result = Test-ProviderCapability -ProviderName "Hyper-V" -Capability @("SupportsSnapshots", "SupportsStorage") -RequireAll
            
            $result.HasCapability | Should -Be $false
            $result.RequireAll | Should -Be $true
            $result.UnsupportedCapabilities | Should -Contain "SupportsStorage"
        }
        
        It "Should include detailed information when requested" {
            $result = Test-ProviderCapability -ProviderName "Hyper-V" -Capability "SupportsSnapshots" -IncludeDetails
            
            $result.AllCapabilities | Should -Not -BeNullOrEmpty
            $result.ProviderVersion | Should -Be "1.0.0"
            $result.ProviderStatus | Should -Be "Ready"
        }
    }
    
    Context "Error Handling" {
        It "Should fail for unregistered provider" {
            Mock Get-InfrastructureProvider { $null } -ModuleName OpenTofuProvider
            
            { Test-ProviderCapability -ProviderName "UnknownProvider" -Capability "SupportsVirtualMachines" } |
                Should -Throw "*not registered*"
        }
    }
}

Describe "ConvertTo-ProviderResource Tests" {
    BeforeEach {
        # Mock provider and mappings
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        Mock Get-InfrastructureProvider {
            [PSCustomObject]@{
                Name = "Hyper-V"
                Configuration = @{
                    Provider = "taliesins/hyperv"
                    DefaultVMPath = "C:\VMs"
                    DefaultVHDPath = "C:\VHDs"
                    DefaultSwitchName = "Default Switch"
                }
                Methods = @{}
            }
        } -ModuleName OpenTofuProvider
        
        Mock Get-ProviderResourceMapping {
            [PSCustomObject]@{
                ResourceMappings = @{
                    virtual_machine = @{
                        ProviderType = "hyperv_machine_instance"
                        RequiredProperties = @("name")
                        OptionalProperties = @("memory_mb", "cpu_count", "disk_size_gb")
                    }
                }
            }
        } -ModuleName OpenTofuProvider
    }
    
    Context "Resource Conversion" {
        It "Should convert virtual machine resource" {
            $vmResource = [PSCustomObject]@{
                type = "virtual_machine"
                properties = [PSCustomObject]@{
                    name = "test-vm"
                    memory_mb = 2048
                    cpu_count = 2
                    disk_size_gb = 40
                }
            }
            
            $result = ConvertTo-ProviderResource -ResourceDefinition $vmResource -ProviderName "Hyper-V"
            
            $result.ConvertedResource.type | Should -Be "hyperv_machine_instance"
            $result.ConvertedResource.provider | Should -Be "taliesins/hyperv"
            $result.ConvertedResource.config.name | Should -Be "test-vm"
            $result.ConvertedResource.config.memory_startup_bytes | Should -Be (2048 * 1MB)
            $result.ConvertedResource.config.processor_count | Should -Be 2
        }
        
        It "Should apply provider defaults" {
            $vmResource = [PSCustomObject]@{
                type = "virtual_machine"
                properties = [PSCustomObject]@{
                    name = "minimal-vm"
                }
            }
            
            $result = ConvertTo-ProviderResource -ResourceDefinition $vmResource -ProviderName "Hyper-V"
            
            $result.ConvertedResource.config.path | Should -Be "C:\VMs"
            $result.ConvertedResource.config.vhd_path | Should -Be "C:\VHDs"
            $result.ConvertedResource.config.switch_name | Should -Be "Default Switch"
        }
        
        It "Should include metadata when requested" {
            $vmResource = [PSCustomObject]@{
                type = "virtual_machine"
                properties = [PSCustomObject]@{
                    name = "test-vm"
                }
            }
            
            $result = ConvertTo-ProviderResource -ResourceDefinition $vmResource -ProviderName "Hyper-V" -IncludeMetadata
            
            $result.Metadata.ConversionTimestamp | Should -Not -BeNullOrEmpty
            $result.Metadata.SourceResourceType | Should -Be "virtual_machine"
            $result.Metadata.TargetResourceType | Should -Be "hyperv_machine_instance"
        }
        
        It "Should apply optimizations when requested" {
            $vmResource = [PSCustomObject]@{
                type = "virtual_machine"
                properties = [PSCustomObject]@{
                    name = "test-vm"
                    memory_mb = 2048
                    generation = 2
                }
            }
            
            $result = ConvertTo-ProviderResource -ResourceDefinition $vmResource -ProviderName "Hyper-V" -OptimizeForProvider
            
            $result.Applied.Count | Should -BeGreaterThan 0
            $result.ConvertedResource.config.dynamic_memory.enabled | Should -Be $true
            $result.ConvertedResource.config.secure_boot_enabled | Should -Be $true
        }
    }
    
    Context "Error Handling" {
        It "Should fail for unsupported resource type" {
            $invalidResource = [PSCustomObject]@{
                type = "unsupported_type"
                properties = [PSCustomObject]@{
                    name = "test"
                }
            }
            
            { ConvertTo-ProviderResource -ResourceDefinition $invalidResource -ProviderName "Hyper-V" } |
                Should -Throw "*not supported*"
        }
        
        It "Should fail for unregistered provider" {
            Mock Get-InfrastructureProvider { $null } -ModuleName OpenTofuProvider
            
            $vmResource = [PSCustomObject]@{
                type = "virtual_machine"
                properties = [PSCustomObject]@{ name = "test-vm" }
            }
            
            { ConvertTo-ProviderResource -ResourceDefinition $vmResource -ProviderName "UnknownProvider" } |
                Should -Throw "*not registered*"
        }
    }
}

Describe "Test-ProviderConfiguration Tests" {
    BeforeEach {
        # Mock provider
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        Mock Get-InfrastructureProvider {
            [PSCustomObject]@{
                Name = "Hyper-V"
                Capabilities = @{
                    RequiresISO = $true
                    SupportsWindowsGuests = $true
                }
                Methods = @{}
            }
        } -ModuleName OpenTofuProvider
        
        Mock Get-ProviderResourceMapping {
            [PSCustomObject]@{
                ResourceMappings = @{
                    virtual_machine = @{
                        RequiredProperties = @("name")
                        OptionalProperties = @("memory_mb", "cpu_count")
                    }
                }
            }
        } -ModuleName OpenTofuProvider
        
        # Test configuration
        $script:testConfig = [PSCustomObject]@{
            version = "1.0"
            infrastructure = [PSCustomObject]@{
                virtual_machine = [PSCustomObject]@{
                    name = "test-vm"
                    memory_mb = 2048
                    cpu_count = 2
                }
            }
            iso_requirements = @(
                @{ name = "Windows Server 2025" }
            )
        }
    }
    
    Context "Configuration Validation" {
        It "Should validate valid configuration" {
            $result = Test-ProviderConfiguration -Configuration $script:testConfig -ProviderName "Hyper-V"
            
            $result.IsValid | Should -Be $true
            $result.Errors.Count | Should -Be 0
        }
        
        It "Should detect missing required properties" {
            $invalidConfig = [PSCustomObject]@{
                infrastructure = [PSCustomObject]@{
                    virtual_machine = [PSCustomObject]@{
                        memory_mb = 2048
                        # Missing required 'name' property
                    }
                }
            }
            
            $result = Test-ProviderConfiguration -Configuration $invalidConfig -ProviderName "Hyper-V"
            
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "Required property 'name' missing for resource type 'virtual_machine'"
        }
        
        It "Should validate property values in strict mode" {
            $strictConfig = [PSCustomObject]@{
                infrastructure = [PSCustomObject]@{
                    virtual_machine = [PSCustomObject]@{
                        name = "test-vm"
                        memory_mb = 100  # Very low memory
                        cpu_count = 0    # Invalid CPU count
                    }
                }
            }
            
            $result = Test-ProviderConfiguration -Configuration $strictConfig -ProviderName "Hyper-V" -Strict
            
            $result.IsValid | Should -Be $false
            $result.Warnings | Should -Contain "VM memory less than 512MB may cause performance issues"
        }
        
        It "Should provide recommendations when requested" {
            $result = Test-ProviderConfiguration -Configuration $script:testConfig -ProviderName "Hyper-V" -IncludeRecommendations
            
            $result.Recommendations.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Provider-Specific Validation" {
        It "Should warn about missing ISOs for providers that require them" {
            $configNoISO = [PSCustomObject]@{
                infrastructure = [PSCustomObject]@{
                    virtual_machine = [PSCustomObject]@{
                        name = "test-vm"
                    }
                }
            }
            
            $result = Test-ProviderConfiguration -Configuration $configNoISO -ProviderName "Hyper-V"
            
            $result.Warnings | Should -Contain "Provider 'Hyper-V' typically requires ISO configuration"
        }
    }
}

Describe "Unregister-InfrastructureProvider Tests" {
    BeforeEach {
        # Setup registered provider
        $script:infrastructureProviders = @{
            "TestProvider" = @{
                Name = "TestProvider"
                Configuration = @{
                    CredentialName = "TestProvider_Credentials"
                }
            }
        }
        
        Mock Write-CustomLog {} -ModuleName OpenTofuProvider
        Mock Remove-SecureCredential {} -ModuleName OpenTofuProvider
        Mock Save-RegisteredProviders {} -ModuleName OpenTofuProvider
        Mock Get-Command { [PSCustomObject]@{ Name = "Remove-SecureCredential" } } -ModuleName OpenTofuProvider
    }
    
    Context "Provider Unregistration" {
        It "Should unregister provider successfully" {
            Unregister-InfrastructureProvider -Name "TestProvider" -Force
            
            $script:infrastructureProviders.ContainsKey("TestProvider") | Should -Be $false
            Should -Invoke Save-RegisteredProviders -ModuleName OpenTofuProvider
        }
        
        It "Should remove credentials when requested" {
            Unregister-InfrastructureProvider -Name "TestProvider" -RemoveCredentials -Force
            
            Should -Invoke Remove-SecureCredential -ModuleName OpenTofuProvider -ParameterFilter {
                $Name -eq "TestProvider_Credentials"
            }
        }
        
        It "Should warn about unregistered provider" {
            Unregister-InfrastructureProvider -Name "UnknownProvider" -Force
            
            Should -Invoke Write-CustomLog -ModuleName OpenTofuProvider -ParameterFilter {
                $Level -eq "WARN" -and $Message -like "*not registered*"
            }
        }
    }
}

AfterAll {
    # Restore environment
    $env:PROJECT_ROOT = $projectRoot
}