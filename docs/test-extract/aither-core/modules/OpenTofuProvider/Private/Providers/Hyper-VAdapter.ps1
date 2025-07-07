# Hyper-V Provider Adapter
# Adapts existing Taliesins Hyper-V provider functionality to the provider abstraction layer

function Initialize-Hyper-VProvider {
    <#
    .SYNOPSIS
        Initializes the Hyper-V provider with specified configuration.
    #>
    param([hashtable]$Configuration)
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Initializing Hyper-V provider"
        
        # Validate Hyper-V is available
        if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
            throw "Hyper-V PowerShell module is not available"
        }
        
        # Test Hyper-V service
        $hyperVService = Get-Service -Name vmms -ErrorAction SilentlyContinue
        if (-not $hyperVService -or $hyperVService.Status -ne 'Running') {
            throw "Hyper-V Virtual Machine Management service is not running"
        }
        
        # Ensure required paths exist
        if ($Configuration.DefaultVMPath -and -not (Test-Path $Configuration.DefaultVMPath)) {
            New-Item -Path $Configuration.DefaultVMPath -ItemType Directory -Force | Out-Null
            Write-CustomLog -Level 'INFO' -Message "Created VM path: $($Configuration.DefaultVMPath)"
        }
        
        if ($Configuration.DefaultVHDPath -and -not (Test-Path $Configuration.DefaultVHDPath)) {
            New-Item -Path $Configuration.DefaultVHDPath -ItemType Directory -Force | Out-Null
            Write-CustomLog -Level 'INFO' -Message "Created VHD path: $($Configuration.DefaultVHDPath)"
        }
        
        # Validate or create default virtual switch
        if ($Configuration.DefaultSwitchName) {
            $switch = Get-VMSwitch -Name $Configuration.DefaultSwitchName -ErrorAction SilentlyContinue
            if (-not $switch) {
                Write-CustomLog -Level 'WARN' -Message "Default switch '$($Configuration.DefaultSwitchName)' not found"
                
                # Try to find any available switch
                $availableSwitch = Get-VMSwitch | Select-Object -First 1
                if ($availableSwitch) {
                    $Configuration.DefaultSwitchName = $availableSwitch.Name
                    Write-CustomLog -Level 'INFO' -Message "Using available switch: $($availableSwitch.Name)"
                } else {
                    Write-CustomLog -Level 'WARN' -Message "No virtual switches found. VMs may not have network connectivity."
                }
            }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Hyper-V provider initialized successfully"
        return @{ Success = $true }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize Hyper-V provider: $($_.Exception.Message)"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-Hyper-VConfiguration {
    <#
    .SYNOPSIS
        Validates Hyper-V provider configuration.
    #>
    param([hashtable]$Configuration)
    
    $result = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
    }
    
    try {
        # Validate VM path
        if ($Configuration.DefaultVMPath) {
            $parentPath = Split-Path $Configuration.DefaultVMPath -Parent
            if (-not (Test-Path $parentPath)) {
                $result.Errors += "VM path parent directory does not exist: $parentPath"
                $result.IsValid = $false
            }
        }
        
        # Validate VHD path
        if ($Configuration.DefaultVHDPath) {
            $parentPath = Split-Path $Configuration.DefaultVHDPath -Parent
            if (-not (Test-Path $parentPath)) {
                $result.Errors += "VHD path parent directory does not exist: $parentPath"
                $result.IsValid = $false
            }
        }
        
        # Check available disk space
        if ($Configuration.DefaultVMPath) {
            $drive = (Get-Item $Configuration.DefaultVMPath -ErrorAction SilentlyContinue).PSDrive
            if ($drive) {
                $freeSpaceGB = [Math]::Round($drive.Free / 1GB, 2)
                if ($freeSpaceGB -lt 10) {
                    $result.Warnings += "Low disk space on VM drive: ${freeSpaceGB}GB free"
                }
            }
        }
        
        # Validate switch name if specified
        if ($Configuration.DefaultSwitchName) {
            $switch = Get-VMSwitch -Name $Configuration.DefaultSwitchName -ErrorAction SilentlyContinue
            if (-not $switch) {
                $result.Warnings += "Virtual switch '$($Configuration.DefaultSwitchName)' not found"
            }
        }
        
        # Check provider string
        if ($Configuration.Provider -and $Configuration.Provider -ne 'taliesins/hyperv') {
            $result.Warnings += "Provider string '$($Configuration.Provider)' may not be compatible with Hyper-V"
        }
        
    } catch {
        $result.IsValid = $false
        $result.Errors += "Configuration validation failed: $($_.Exception.Message)"
    }
    
    return $result
}

function ConvertTo-Hyper-VResource {
    <#
    .SYNOPSIS
        Translates generic resource definitions to Hyper-V specific resources.
    #>
    param(
        [PSCustomObject]$Resource,
        [hashtable]$Configuration
    )
    
    try {
        Write-CustomLog -Level 'DEBUG' -Message "Translating resource: $($Resource.Type)"
        
        $hyperVResource = @{
            provider = 'taliesins/hyperv'
            source = 'taliesins/hyperv'
        }
        
        switch ($Resource.Type) {
            'virtual_machine' {
                $hyperVResource.type = 'hyperv_machine_instance'
                $hyperVResource.config = @{
                    name = $Resource.Properties.name
                    path = $Configuration.DefaultVMPath
                    vhd_path = $Configuration.DefaultVHDPath
                    switch_name = $Configuration.DefaultSwitchName
                }
                
                # Map standard properties to Hyper-V specific
                if ($Resource.Properties.memory_mb) {
                    $hyperVResource.config.memory_startup_bytes = $Resource.Properties.memory_mb * 1MB
                }
                if ($Resource.Properties.cpu_count) {
                    $hyperVResource.config.processor_count = $Resource.Properties.cpu_count
                }
                if ($Resource.Properties.disk_size_gb) {
                    $hyperVResource.config.vhd = @{
                        size_bytes = $Resource.Properties.disk_size_gb * 1GB
                        block_size_bytes = 1MB
                    }
                }
                if ($Resource.Properties.iso_path) {
                    $hyperVResource.config.dvd_drives = @(
                        @{ path = $Resource.Properties.iso_path }
                    )
                }
            }
            
            'network' {
                $hyperVResource.type = 'hyperv_network_adapter'
                $hyperVResource.config = @{
                    vm_name = $Resource.Properties.vm_name
                    switch_name = $Resource.Properties.switch_name -or $Configuration.DefaultSwitchName
                }
                
                if ($Resource.Properties.vlan_id) {
                    $hyperVResource.config.vlan_access = @{
                        vlan_id = $Resource.Properties.vlan_id
                    }
                }
            }
            
            'virtual_switch' {
                $hyperVResource.type = 'hyperv_vswitch'
                $hyperVResource.config = @{
                    name = $Resource.Properties.name
                    switch_type = $Resource.Properties.type -or 'Internal'
                }
                
                if ($Resource.Properties.external_adapter) {
                    $hyperVResource.config.net_adapter_names = @($Resource.Properties.external_adapter)
                }
            }
            
            'snapshot' {
                $hyperVResource.type = 'hyperv_vm_snapshot'
                $hyperVResource.config = @{
                    vm_name = $Resource.Properties.vm_name
                    snapshot_name = $Resource.Properties.name
                }
            }
            
            default {
                throw "Unsupported resource type for Hyper-V: $($Resource.Type)"
            }
        }
        
        return $hyperVResource
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to translate resource: $($_.Exception.Message)"
        throw
    }
}

function Test-Hyper-VReadiness {
    <#
    .SYNOPSIS
        Tests if Hyper-V provider is ready for use.
    #>
    try {
        # Check if Hyper-V module is loaded
        if (-not (Get-Module Hyper-V)) {
            Import-Module Hyper-V -ErrorAction Stop
        }
        
        # Test basic Hyper-V functionality
        Get-VM -ErrorAction Stop | Out-Null
        
        # Check if we can access Hyper-V service
        $vmms = Get-Service vmms -ErrorAction Stop
        if ($vmms.Status -ne 'Running') {
            return $false
        }
        
        return $true
        
    } catch {
        Write-CustomLog -Level 'DEBUG' -Message "Hyper-V readiness check failed: $_"
        return $false
    }
}

function Get-Hyper-VResourceTypes {
    <#
    .SYNOPSIS
        Gets supported resource types for Hyper-V provider.
    #>
    return @{
        'virtual_machine' = @{
            Name = 'Virtual Machine'
            Description = 'Hyper-V virtual machine instance'
            RequiredProperties = @('name')
            OptionalProperties = @('memory_mb', 'cpu_count', 'disk_size_gb', 'iso_path', 'generation')
            HyperVType = 'hyperv_machine_instance'
        }
        
        'network' = @{
            Name = 'Network Adapter'
            Description = 'Virtual network adapter for VM'
            RequiredProperties = @('vm_name')
            OptionalProperties = @('switch_name', 'vlan_id', 'static_mac')
            HyperVType = 'hyperv_network_adapter'
        }
        
        'virtual_switch' = @{
            Name = 'Virtual Switch'
            Description = 'Hyper-V virtual switch'
            RequiredProperties = @('name')
            OptionalProperties = @('type', 'external_adapter', 'internal_network')
            HyperVType = 'hyperv_vswitch'
        }
        
        'snapshot' = @{
            Name = 'VM Snapshot'
            Description = 'Virtual machine snapshot'
            RequiredProperties = @('vm_name', 'name')
            OptionalProperties = @('description')
            HyperVType = 'hyperv_vm_snapshot'
        }
    }
}

function Test-Hyper-VCredentials {
    <#
    .SYNOPSIS
        Tests Hyper-V credentials (not applicable for local Hyper-V).
    #>
    param([PSCredential]$Credential)
    
    # Local Hyper-V doesn't require separate credentials
    # It uses the current user's permissions
    try {
        # Test if we can perform basic Hyper-V operations
        Get-VM | Out-Null
        return @{ IsValid = $true }
    } catch {
        return @{ 
            IsValid = $false
            Error = "Current user does not have sufficient privileges for Hyper-V operations"
        }
    }
}

function Get-Hyper-VProviderInfo {
    <#
    .SYNOPSIS
        Gets detailed information about the Hyper-V provider environment.
    #>
    try {
        $info = @{
            HostInformation = @{
                ComputerName = $env:COMPUTERNAME
                OSVersion = (Get-CimInstance Win32_OperatingSystem).Caption
                HyperVVersion = (Get-WindowsFeature -Name Hyper-V).InstallState
            }
            
            VirtualMachines = @{
                Total = (Get-VM).Count
                Running = (Get-VM | Where-Object State -eq 'Running').Count
                Stopped = (Get-VM | Where-Object State -eq 'Off').Count
            }
            
            VirtualSwitches = @()
            Storage = @{
                DefaultVMPath = Get-VMHost | Select-Object -ExpandProperty VirtualMachinePath
                DefaultVHDPath = Get-VMHost | Select-Object -ExpandProperty VirtualHardDiskPath
            }
        }
        
        # Get switch information
        $switches = Get-VMSwitch
        foreach ($switch in $switches) {
            $info.VirtualSwitches += @{
                Name = $switch.Name
                Type = $switch.SwitchType
                Status = $switch.Status
            }
        }
        
        return $info
        
    } catch {
        Write-CustomLog -Level 'WARN' -Message "Could not get Hyper-V provider info: $_"
        return @{}
    }
}