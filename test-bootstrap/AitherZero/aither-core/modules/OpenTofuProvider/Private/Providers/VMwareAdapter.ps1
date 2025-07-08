# VMware Provider Adapter
# Adapts VMware vSphere provider functionality to the provider abstraction layer

function Initialize-VMwareProvider {
    <#
    .SYNOPSIS
        Initializes the VMware vSphere provider with specified configuration.
    #>
    param([hashtable]$Configuration)
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Initializing VMware vSphere provider"
        
        # Check if VMware PowerCLI is available
        if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
            throw "VMware PowerCLI is not installed"
        }
        
        # Import required modules
        $requiredModules = @('VMware.VimAutomation.Core', 'VMware.VimAutomation.Common')
        foreach ($module in $requiredModules) {
            if (-not (Get-Module -Name $module)) {
                Import-Module $module -Force -ErrorAction Stop
            }
        }
        
        # Disable certificate warnings for development
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -ErrorAction SilentlyContinue
        
        # Test vCenter connectivity
        if ($Configuration.vCenter) {
            Write-CustomLog -Level 'INFO' -Message "Testing connection to vCenter: $($Configuration.vCenter)"
            
            # Use stored credentials if available
            $credential = $null
            if ($Configuration.CredentialName) {
                $credential = Get-StoredCredential -Name $Configuration.CredentialName -ErrorAction SilentlyContinue
            }
            
            if ($credential) {
                $connection = Connect-VIServer -Server $Configuration.vCenter -Credential $credential -ErrorAction Stop
            } else {
                Write-CustomLog -Level 'WARN' -Message "No credentials provided for vCenter connection"
                return @{ Success = $false; Error = "vCenter credentials required" }
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "Connected to vCenter: $($connection.Name)"
        }
        
        # Validate datacenter
        if ($Configuration.Datacenter) {
            $datacenter = Get-Datacenter -Name $Configuration.Datacenter -ErrorAction SilentlyContinue
            if (-not $datacenter) {
                throw "Datacenter not found: $($Configuration.Datacenter)"
            }
        }
        
        # Validate cluster
        if ($Configuration.Cluster) {
            $cluster = Get-Cluster -Name $Configuration.Cluster -ErrorAction SilentlyContinue
            if (-not $cluster) {
                throw "Cluster not found: $($Configuration.Cluster)"
            }
        }
        
        # Validate datastore
        if ($Configuration.Datastore) {
            $datastore = Get-Datastore -Name $Configuration.Datastore -ErrorAction SilentlyContinue
            if (-not $datastore) {
                Write-CustomLog -Level 'WARN' -Message "Datastore not found: $($Configuration.Datastore)"
            }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "VMware vSphere provider initialized successfully"
        return @{ Success = $true }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize VMware provider: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-VMwareConfiguration {
    <#
    .SYNOPSIS
        Validates VMware vSphere provider configuration.
    #>
    param([hashtable]$Configuration)
    
    $result = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
    }
    
    try {
        # Validate required configuration
        $requiredFields = @('vCenter', 'Datacenter')
        foreach ($field in $requiredFields) {
            if (-not $Configuration.$field) {
                $result.Errors += "Missing required VMware configuration: $field"
                $result.IsValid = $false
            }
        }
        
        # Validate vCenter format
        if ($Configuration.vCenter) {
            if ($Configuration.vCenter -notmatch '^[a-zA-Z0-9\.\-]+$') {
                $result.Warnings += "vCenter server name may contain invalid characters"
            }
        }
        
        # Check for credentials
        if (-not $Configuration.CredentialName) {
            $result.Warnings += "No credential name specified for vCenter authentication"
        }
        
        # Validate provider string
        if ($Configuration.Provider -and $Configuration.Provider -ne 'vsphere') {
            $result.Warnings += "Provider string '$($Configuration.Provider)' may not be compatible with VMware"
        }
        
        # Check connection
        $viServers = $global:DefaultVIServers
        if (-not $viServers -or $viServers.Count -eq 0) {
            $result.Warnings += "Not connected to any vCenter servers"
        }
        
    } catch {
        $result.IsValid = $false
        $result.Errors += "Configuration validation failed: $($_.Exception.Message)"
    }
    
    return $result
}

function ConvertTo-VMwareResource {
    <#
    .SYNOPSIS
        Translates generic resource definitions to VMware vSphere specific resources.
    #>
    param(
        [PSCustomObject]$Resource,
        [hashtable]$Configuration
    )
    
    try {
        Write-CustomLog -Level 'DEBUG' -Message "Translating resource: $($Resource.Type)"
        
        $vmwareResource = @{
            provider = 'vsphere'
            source = 'hashicorp/vsphere'
        }
        
        switch ($Resource.Type) {
            'virtual_machine' {
                $vmwareResource.type = 'vsphere_virtual_machine'
                $vmwareResource.config = @{
                    name = $Resource.Properties.name
                    resource_pool_id = "data.vsphere_compute_cluster.$($Configuration.Cluster).resource_pool_id"
                    datastore_id = "data.vsphere_datastore.$($Configuration.Datastore).id"
                    num_cpus = $Resource.Properties.cpu_count -or 2
                    memory = $Resource.Properties.memory_mb -or 2048
                    guest_id = $Resource.Properties.guest_id -or 'ubuntu64Guest'
                }
                
                # Network interface
                $vmwareResource.config.network_interface = @{
                    network_id = "data.vsphere_network.$($Resource.Properties.network -or 'VM Network').id"
                }
                
                # Disk configuration
                $vmwareResource.config.disk = @{
                    label = 'disk0'
                    size = $Resource.Properties.disk_size_gb -or 20
                }
                
                # Clone configuration if template specified
                if ($Resource.Properties.template) {
                    $vmwareResource.config.clone = @{
                        template_uuid = "data.vsphere_virtual_machine.$($Resource.Properties.template).id"
                    }
                    
                    # Customization
                    if ($Resource.Properties.customize) {
                        $vmwareResource.config.clone.customize = @{
                            linux_options = @{
                                host_name = $Resource.Properties.name
                                domain = $Resource.Properties.domain -or 'local'
                            }
                            network_interface = @{
                                ipv4_address = $Resource.Properties.ip_address
                                ipv4_netmask = $Resource.Properties.netmask -or 24
                            }
                            ipv4_gateway = $Resource.Properties.gateway
                            dns_server_list = $Resource.Properties.dns_servers -or @('8.8.8.8')
                        }
                    }
                }
            }
            
            'network' {
                $vmwareResource.type = 'vsphere_distributed_port_group'
                $vmwareResource.config = @{
                    name = $Resource.Properties.name
                    distributed_virtual_switch_uuid = "data.vsphere_distributed_virtual_switch.$($Resource.Properties.dvs_name).id"
                    vlan_id = $Resource.Properties.vlan_id -or 0
                }
            }
            
            'folder' {
                $vmwareResource.type = 'vsphere_folder'
                $vmwareResource.config = @{
                    path = $Resource.Properties.path
                    type = $Resource.Properties.type -or 'vm'
                    datacenter_id = "data.vsphere_datacenter.$($Configuration.Datacenter).id"
                }
            }
            
            'resource_pool' {
                $vmwareResource.type = 'vsphere_resource_pool'
                $vmwareResource.config = @{
                    name = $Resource.Properties.name
                    parent_resource_pool_id = "data.vsphere_compute_cluster.$($Configuration.Cluster).resource_pool_id"
                }
                
                if ($Resource.Properties.cpu_reservation) {
                    $vmwareResource.config.cpu_reservation = $Resource.Properties.cpu_reservation
                }
                if ($Resource.Properties.memory_reservation) {
                    $vmwareResource.config.memory_reservation = $Resource.Properties.memory_reservation
                }
            }
            
            'datastore_cluster' {
                $vmwareResource.type = 'vsphere_datastore_cluster'
                $vmwareResource.config = @{
                    name = $Resource.Properties.name
                    datacenter_id = "data.vsphere_datacenter.$($Configuration.Datacenter).id"
                    sdrs_enabled = $Resource.Properties.sdrs_enabled -or $true
                }
            }
            
            default {
                throw "Unsupported resource type for VMware: $($Resource.Type)"
            }
        }
        
        return $vmwareResource
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to translate resource: $($_.Exception.Message)"
        throw
    }
}

function Test-VMwareReadiness {
    <#
    .SYNOPSIS
        Tests if VMware vSphere provider is ready for use.
    #>
    try {
        # Check if PowerCLI is available
        if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
            return $false
        }
        
        # Import core module
        Import-Module VMware.VimAutomation.Core -ErrorAction Stop
        
        # Test vCenter connectivity
        $viServers = $global:DefaultVIServers
        if (-not $viServers -or $viServers.Count -eq 0) {
            return $false
        }
        
        # Test basic vSphere operations
        Get-Datacenter -ErrorAction Stop | Out-Null
        
        return $true
        
    } catch {
        Write-CustomLog -Level 'DEBUG' -Message "VMware readiness check failed: $_"
        return $false
    }
}

function Get-VMwareResourceTypes {
    <#
    .SYNOPSIS
        Gets supported resource types for VMware vSphere provider.
    #>
    return @{
        'virtual_machine' = @{
            Name = 'Virtual Machine'
            Description = 'VMware vSphere virtual machine'
            RequiredProperties = @('name')
            OptionalProperties = @('cpu_count', 'memory_mb', 'disk_size_gb', 'template', 'network', 'ip_address', 'customize')
            VMwareType = 'vsphere_virtual_machine'
        }
        
        'network' = @{
            Name = 'Distributed Port Group'
            Description = 'VMware distributed port group'
            RequiredProperties = @('name', 'dvs_name')
            OptionalProperties = @('vlan_id')
            VMwareType = 'vsphere_distributed_port_group'
        }
        
        'folder' = @{
            Name = 'Folder'
            Description = 'VMware inventory folder'
            RequiredProperties = @('path')
            OptionalProperties = @('type')
            VMwareType = 'vsphere_folder'
        }
        
        'resource_pool' = @{
            Name = 'Resource Pool'
            Description = 'VMware resource pool'
            RequiredProperties = @('name')
            OptionalProperties = @('cpu_reservation', 'memory_reservation')
            VMwareType = 'vsphere_resource_pool'
        }
        
        'datastore_cluster' = @{
            Name = 'Datastore Cluster'
            Description = 'VMware datastore cluster'
            RequiredProperties = @('name')
            OptionalProperties = @('sdrs_enabled')
            VMwareType = 'vsphere_datastore_cluster'
        }
    }
}

function Test-VMwareCredentials {
    <#
    .SYNOPSIS
        Tests VMware vSphere credentials.
    #>
    param([PSCredential]$Credential)
    
    try {
        # Disconnect any existing connections
        Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
        
        # Test connection with provided credentials
        if (-not $Credential) {
            return @{ 
                IsValid = $false
                Error = "No credentials provided for VMware authentication"
            }
        }
        
        # This would require a vCenter server address to test against
        # For now, just validate credential format
        if (-not $Credential.UserName -or -not $Credential.Password) {
            return @{ 
                IsValid = $false
                Error = "Invalid credential format"
            }
        }
        
        return @{ 
            IsValid = $true
            Note = "Credential format valid. Connection test requires vCenter server configuration."
        }
        
    } catch {
        return @{ 
            IsValid = $false
            Error = "VMware credential validation failed: $($_.Exception.Message)"
        }
    }
}

function Get-VMwareProviderInfo {
    <#
    .SYNOPSIS
        Gets detailed information about the VMware vSphere provider environment.
    #>
    try {
        $viServers = $global:DefaultVIServers
        if (-not $viServers -or $viServers.Count -eq 0) {
            return @{ Error = "Not connected to any vCenter servers" }
        }
        
        $info = @{
            Connections = @()
            Environment = @{}
        }
        
        foreach ($server in $viServers) {
            $serverInfo = @{
                Name = $server.Name
                Version = $server.Version
                Build = $server.Build
                IsConnected = $server.IsConnected
                User = $server.User
            }
            
            $info.Connections += $serverInfo
        }
        
        # Get datacenter information
        $datacenters = Get-Datacenter
        $info.Environment.Datacenters = @()
        foreach ($dc in $datacenters) {
            $info.Environment.Datacenters += @{
                Name = $dc.Name
                Id = $dc.Id
            }
        }
        
        # Get cluster information
        $clusters = Get-Cluster
        $info.Environment.Clusters = @()
        foreach ($cluster in $clusters) {
            $info.Environment.Clusters += @{
                Name = $cluster.Name
                HAEnabled = $cluster.HAEnabled
                DrsEnabled = $cluster.DrsEnabled
            }
        }
        
        # Get datastore information
        $datastores = Get-Datastore | Select-Object -First 10
        $info.Environment.Datastores = @()
        foreach ($ds in $datastores) {
            $info.Environment.Datastores += @{
                Name = $ds.Name
                Type = $ds.Type
                CapacityGB = [Math]::Round($ds.CapacityGB, 2)
                FreeSpaceGB = [Math]::Round($ds.FreeSpaceGB, 2)
            }
        }
        
        return $info
        
    } catch {
        Write-CustomLog -Level 'WARN' -Message "Could not get VMware provider info: $_"
        return @{}
    }
}