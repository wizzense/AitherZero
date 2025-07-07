function ConvertTo-ProviderResource {
    <#
    .SYNOPSIS
        Converts generic resources to provider-specific format.

    .DESCRIPTION
        Translates generic infrastructure resource definitions to provider-specific
        OpenTofu/Terraform resource configurations, handling property mapping and
        provider-specific optimizations.

    .PARAMETER ResourceDefinition
        Generic resource definition to convert.

    .PARAMETER ProviderName
        Target provider for the conversion.

    .PARAMETER Configuration
        Deployment configuration for context.

    .PARAMETER OptimizeForProvider
        Apply provider-specific optimizations.

    .PARAMETER IncludeMetadata
        Include metadata in the converted resource.

    .EXAMPLE
        $vm = @{
            type = "virtual_machine"
            properties = @{
                name = "web-server"
                memory_mb = 4096
                cpu_count = 2
            }
        }
        ConvertTo-ProviderResource -ResourceDefinition $vm -ProviderName "Hyper-V"

    .OUTPUTS
        Provider-specific resource configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$ResourceDefinition,
        
        [Parameter(Mandatory)]
        [string]$ProviderName,
        
        [Parameter()]
        [PSCustomObject]$Configuration,
        
        [Parameter()]
        [switch]$OptimizeForProvider,
        
        [Parameter()]
        [switch]$IncludeMetadata
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Converting resources for provider: $ProviderName"
        
        # Get provider information
        $script:provider = Get-InfrastructureProvider -Name $ProviderName -Registered
        
        if (-not $script:provider) {
            throw "Provider '$ProviderName' is not registered"
        }
        
        # Get resource mappings
        $script:resourceMappings = Get-ProviderResourceMapping -ProviderName $ProviderName
    }
    
    process {
        try {
            # Initialize conversion result
            $result = @{
                OriginalResource = $ResourceDefinition
                ProviderName = $ProviderName
                ConvertedResource = $null
                Warnings = @()
                Applied = @()
                Metadata = @{}
            }
            
            # Validate resource type is supported
            if (-not $script:resourceMappings.ResourceMappings.ContainsKey($ResourceDefinition.type)) {
                throw "Resource type '$($ResourceDefinition.type)' is not supported by provider '$ProviderName'"
            }
            
            # Use provider's translation method if available
            if ($script:provider.Methods.TranslateResource) {
                Write-CustomLog -Level 'DEBUG' -Message "Using provider's translation method"
                
                $translatedResource = & $script:provider.Methods.TranslateResource -Resource $ResourceDefinition -Configuration $Configuration
                $result.ConvertedResource = $translatedResource
            } else {
                # Use built-in translation
                Write-CustomLog -Level 'DEBUG' -Message "Using built-in resource translation"
                
                $translatedResource = Convert-GenericResource -Resource $ResourceDefinition -Provider $script:provider -Configuration $Configuration
                $result.ConvertedResource = $translatedResource
            }
            
            # Apply provider-specific optimizations
            if ($OptimizeForProvider) {
                $optimizedResource = Optimize-ProviderResource -Resource $result.ConvertedResource -Provider $script:provider -Configuration $Configuration
                
                if ($optimizedResource.Optimizations.Count -gt 0) {
                    $result.ConvertedResource = $optimizedResource.Resource
                    $result.Applied = $optimizedResource.Optimizations
                    Write-CustomLog -Level 'INFO' -Message "Applied $($optimizedResource.Optimizations.Count) optimization(s)"
                }
            }
            
            # Add metadata if requested
            if ($IncludeMetadata) {
                $result.Metadata = @{
                    ConversionTimestamp = Get-Date
                    ProviderVersion = $script:provider.Version
                    SourceResourceType = $ResourceDefinition.type
                    TargetResourceType = $result.ConvertedResource.type
                    MappingUsed = $script:resourceMappings.ResourceMappings[$ResourceDefinition.type].ProviderType
                }
            }
            
            # Validate converted resource
            $validationResult = Test-ConvertedResource -Resource $result.ConvertedResource -Provider $script:provider
            if (-not $validationResult.IsValid) {
                $result.Warnings += $validationResult.Warnings
            }
            
            return [PSCustomObject]$result
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to convert resource: $($_.Exception.Message)"
            throw
        }
    }
}

function Convert-GenericResource {
    param(
        [PSCustomObject]$Resource,
        [PSCustomObject]$Provider,
        [PSCustomObject]$Configuration
    )
    
    # Get the resource mapping
    $mapping = $script:resourceMappings.ResourceMappings[$Resource.type]
    
    # Create base provider resource
    $providerResource = @{
        type = $mapping.ProviderType
        provider = $Provider.Configuration.Provider
    }
    
    # Convert properties based on resource type
    switch ($Resource.type) {
        'virtual_machine' {
            $providerResource.config = Convert-VirtualMachineProperties -Properties $Resource.properties -Provider $Provider -Configuration $Configuration
        }
        
        'network' {
            $providerResource.config = Convert-NetworkProperties -Properties $Resource.properties -Provider $Provider -Configuration $Configuration
        }
        
        'virtual_switch' {
            $providerResource.config = Convert-VirtualSwitchProperties -Properties $Resource.properties -Provider $Provider -Configuration $Configuration
        }
        
        'snapshot' {
            $providerResource.config = Convert-SnapshotProperties -Properties $Resource.properties -Provider $Provider -Configuration $Configuration
        }
        
        default {
            # Generic property mapping
            $providerResource.config = @{}
            foreach ($prop in $Resource.properties.PSObject.Properties) {
                $providerResource.config[$prop.Name] = $prop.Value
            }
        }
    }
    
    return $providerResource
}

function Convert-VirtualMachineProperties {
    param(
        [PSCustomObject]$Properties,
        [PSCustomObject]$Provider,
        [PSCustomObject]$Configuration
    )
    
    $config = @{
        name = $Properties.name
    }
    
    switch ($Provider.Name) {
        'Hyper-V' {
            # Hyper-V specific mappings
            if ($Properties.memory_mb) {
                $config.memory_startup_bytes = $Properties.memory_mb * 1MB
            }
            
            if ($Properties.cpu_count) {
                $config.processor_count = $Properties.cpu_count
            }
            
            if ($Properties.disk_size_gb) {
                $config.vhd = @{
                    size_bytes = $Properties.disk_size_gb * 1GB
                    block_size_bytes = 1MB
                }
            }
            
            if ($Properties.iso_path) {
                $config.dvd_drives = @(
                    @{ path = $Properties.iso_path }
                )
            }
            
            if ($Properties.generation) {
                $config.generation = $Properties.generation
            }
            
            # Use configuration defaults
            if ($Configuration -and $Configuration.variables) {
                if ($Configuration.variables.vm_path) {
                    $config.path = $Configuration.variables.vm_path
                }
                if ($Configuration.variables.vhd_path) {
                    $config.vhd_path = $Configuration.variables.vhd_path
                }
                if ($Configuration.variables.switch_name) {
                    $config.switch_name = $Configuration.variables.switch_name
                }
            }
            
            # Provider defaults
            if (-not $config.path) {
                $config.path = $Provider.Configuration.DefaultVMPath
            }
            if (-not $config.vhd_path) {
                $config.vhd_path = $Provider.Configuration.DefaultVHDPath
            }
            if (-not $config.switch_name) {
                $config.switch_name = $Provider.Configuration.DefaultSwitchName
            }
        }
        
        'Azure' {
            # Azure specific mappings
            if ($Properties.memory_mb -and $Properties.cpu_count) {
                $config.vm_size = Get-AzureVMSize -MemoryMB $Properties.memory_mb -CPUCount $Properties.cpu_count
            }
            
            if ($Properties.disk_size_gb) {
                $config.os_disk = @{
                    disk_size_gb = $Properties.disk_size_gb
                    storage_account_type = "Standard_LRS"
                }
            }
        }
        
        'AWS' {
            # AWS specific mappings
            if ($Properties.memory_mb -and $Properties.cpu_count) {
                $config.instance_type = Get-AWSInstanceType -MemoryMB $Properties.memory_mb -CPUCount $Properties.cpu_count
            }
            
            if ($Properties.disk_size_gb) {
                $config.root_block_device = @{
                    volume_size = $Properties.disk_size_gb
                    volume_type = "gp2"
                }
            }
        }
    }
    
    return $config
}

function Convert-NetworkProperties {
    param(
        [PSCustomObject]$Properties,
        [PSCustomObject]$Provider,
        [PSCustomObject]$Configuration
    )
    
    $config = @{}
    
    switch ($Provider.Name) {
        'Hyper-V' {
            $config.vm_name = $Properties.vm_name
            $config.switch_name = $Properties.switch_name -or $Provider.Configuration.DefaultSwitchName
            
            if ($Properties.vlan_id) {
                $config.vlan_access = @{
                    vlan_id = $Properties.vlan_id
                }
            }
            
            if ($Properties.static_mac) {
                $config.static_mac_address = $Properties.static_mac
            }
        }
        
        'Azure' {
            $config.name = $Properties.name
            $config.virtual_machine_id = "/subscriptions/{subscription-id}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/$($Properties.vm_name)"
            
            if ($Properties.subnet_id) {
                $config.subnet_id = $Properties.subnet_id
            }
        }
    }
    
    return $config
}

function Convert-VirtualSwitchProperties {
    param(
        [PSCustomObject]$Properties,
        [PSCustomObject]$Provider,
        [PSCustomObject]$Configuration
    )
    
    $config = @{
        name = $Properties.name
    }
    
    switch ($Provider.Name) {
        'Hyper-V' {
            $config.switch_type = $Properties.type -or 'Internal'
            
            if ($Properties.external_adapter) {
                $config.net_adapter_names = @($Properties.external_adapter)
            }
            
            if ($Properties.allow_management_os -ne $null) {
                $config.allow_management_os = $Properties.allow_management_os
            }
        }
    }
    
    return $config
}

function Convert-SnapshotProperties {
    param(
        [PSCustomObject]$Properties,
        [PSCustomObject]$Provider,
        [PSCustomObject]$Configuration
    )
    
    $config = @{
        vm_name = $Properties.vm_name
        snapshot_name = $Properties.name
    }
    
    if ($Properties.description) {
        $config.notes = $Properties.description
    }
    
    return $config
}

function Optimize-ProviderResource {
    param(
        [PSCustomObject]$Resource,
        [PSCustomObject]$Provider,
        [PSCustomObject]$Configuration
    )
    
    $result = @{
        Resource = $Resource
        Optimizations = @()
    }
    
    switch ($Provider.Name) {
        'Hyper-V' {
            # Optimize for Hyper-V
            if ($Resource.type -eq 'hyperv_machine_instance') {
                # Enable dynamic memory if not specified
                if (-not $Resource.config.dynamic_memory) {
                    $Resource.config.dynamic_memory = @{
                        enabled = $true
                        maximum_bytes = $Resource.config.memory_startup_bytes * 2
                        minimum_bytes = [Math]::Max($Resource.config.memory_startup_bytes / 2, 512MB)
                    }
                    $result.Optimizations += "Enabled dynamic memory"
                }
                
                # Set optimal VHD block size for performance
                if ($Resource.config.vhd -and -not $Resource.config.vhd.block_size_bytes) {
                    $Resource.config.vhd.block_size_bytes = 32MB
                    $result.Optimizations += "Set optimal VHD block size (32MB)"
                }
                
                # Enable secure boot for Generation 2 VMs
                if ($Resource.config.generation -eq 2 -and -not $Resource.config.secure_boot_enabled) {
                    $Resource.config.secure_boot_enabled = $true
                    $result.Optimizations += "Enabled Secure Boot for Generation 2 VM"
                }
            }
        }
        
        'Azure' {
            # Azure-specific optimizations
            if ($Resource.type -eq 'azurerm_virtual_machine') {
                # Enable managed disks
                if (-not $Resource.config.storage_os_disk.managed_disk_type) {
                    $Resource.config.storage_os_disk.managed_disk_type = "Premium_LRS"
                    $result.Optimizations += "Enabled Premium SSD managed disks"
                }
            }
        }
    }
    
    return $result
}

function Test-ConvertedResource {
    param(
        [PSCustomObject]$Resource,
        [PSCustomObject]$Provider
    )
    
    $result = @{
        IsValid = $true
        Warnings = @()
    }
    
    # Basic validation
    if (-not $Resource.type) {
        $result.IsValid = $false
        $result.Warnings += "Converted resource missing type"
    }
    
    if (-not $Resource.config) {
        $result.IsValid = $false
        $result.Warnings += "Converted resource missing configuration"
    }
    
    # Provider-specific validation
    switch ($Provider.Name) {
        'Hyper-V' {
            if ($Resource.type -eq 'hyperv_machine_instance') {
                if (-not $Resource.config.name) {
                    $result.IsValid = $false
                    $result.Warnings += "Hyper-V VM missing name"
                }
            }
        }
    }
    
    return $result
}

function Get-AzureVMSize {
    param([int]$MemoryMB, [int]$CPUCount)
    
    # Simple mapping to Azure VM sizes
    if ($CPUCount -le 1 -and $MemoryMB -le 1024) { return "Standard_B1s" }
    if ($CPUCount -le 2 -and $MemoryMB -le 2048) { return "Standard_B2s" }
    if ($CPUCount -le 2 -and $MemoryMB -le 4096) { return "Standard_B2ms" }
    if ($CPUCount -le 4 -and $MemoryMB -le 8192) { return "Standard_B4ms" }
    
    return "Standard_D2s_v3"  # Default
}

function Get-AWSInstanceType {
    param([int]$MemoryMB, [int]$CPUCount)
    
    # Simple mapping to AWS instance types
    if ($CPUCount -le 1 -and $MemoryMB -le 1024) { return "t3.micro" }
    if ($CPUCount -le 2 -and $MemoryMB -le 2048) { return "t3.small" }
    if ($CPUCount -le 2 -and $MemoryMB -le 4096) { return "t3.medium" }
    if ($CPUCount -le 4 -and $MemoryMB -le 8192) { return "t3.large" }
    
    return "m5.large"  # Default
}