function Get-InfrastructureProvider {
    <#
    .SYNOPSIS
        Gets registered infrastructure providers.

    .DESCRIPTION
        Retrieves information about registered infrastructure providers including
        their capabilities, version, and configuration requirements. Supports
        filtering by name and capability queries.

    .PARAMETER Name
        Name of the provider to retrieve. Accepts wildcards.

    .PARAMETER ListAvailable
        List all available providers including unregistered ones.

    .PARAMETER Capability
        Filter providers by specific capability.

    .PARAMETER Registered
        Only return providers that are currently registered.

    .EXAMPLE
        Get-InfrastructureProvider

    .EXAMPLE
        Get-InfrastructureProvider -Name "Hyper-V" -Capability "SupportsSnapshots"

    .EXAMPLE
        Get-InfrastructureProvider -ListAvailable

    .OUTPUTS
        Provider information objects
    #>
    [CmdletBinding(DefaultParameterSetName = 'Registered')]
    param(
        [Parameter(Position = 0)]
        [SupportsWildcards()]
        [string]$Name = '*',
        
        [Parameter(ParameterSetName = 'Available')]
        [switch]$ListAvailable,
        
        [Parameter()]
        [ValidateSet(
            'SupportsVirtualMachines',
            'SupportsNetworking', 
            'SupportsStorage',
            'SupportsSnapshots',
            'SupportsTemplates',
            'RequiresISO',
            'SupportsWindowsGuests',
            'SupportsLinuxGuests',
            'SupportsCustomization'
        )]
        [string[]]$Capability,
        
        [Parameter(ParameterSetName = 'Registered')]
        [switch]$Registered
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Getting infrastructure providers"
        
        # Get providers directory
        $providersPath = Join-Path $PSScriptRoot "../../Private/Providers"
        
        # Get registered providers cache
        $script:registeredProviders = Get-RegisteredProviders
    }
    
    process {
        try {
            $providers = @()
            
            if ($ListAvailable) {
                # Get all available provider definitions
                Write-CustomLog -Level 'INFO' -Message "Listing all available providers"
                
                # Built-in providers
                $builtInProviders = @(
                    Get-HyperVProviderDefinition
                    Get-AzureProviderDefinition
                    Get-AWSProviderDefinition
                    Get-VMwareProviderDefinition
                )
                
                # Custom providers from directory
                if (Test-Path $providersPath) {
                    $customProviderFiles = Get-ChildItem -Path $providersPath -Filter "*Provider.ps1" -File
                    foreach ($file in $customProviderFiles) {
                        try {
                            . $file.FullName
                            $providerFunc = "Get-$($file.BaseName)Definition"
                            if (Get-Command $providerFunc -ErrorAction SilentlyContinue) {
                                $builtInProviders += & $providerFunc
                            }
                        } catch {
                            Write-CustomLog -Level 'WARN' -Message "Failed to load provider from $($file.Name): $_"
                        }
                    }
                }
                
                $providers = $builtInProviders
            } else {
                # Get only registered providers
                Write-CustomLog -Level 'INFO' -Message "Getting registered providers"
                
                foreach ($regProvider in $script:registeredProviders.Values) {
                    # Load provider definition
                    $providerDef = Get-ProviderDefinition -ProviderName $regProvider.Name
                    if ($providerDef) {
                        # Add registration info
                        $providerDef | Add-Member -NotePropertyName 'Registered' -NotePropertyValue $true
                        $providerDef | Add-Member -NotePropertyName 'RegisteredAt' -NotePropertyValue $regProvider.RegisteredAt
                        $providerDef | Add-Member -NotePropertyName 'Configuration' -NotePropertyValue $regProvider.Configuration
                        
                        $providers += $providerDef
                    }
                }
            }
            
            # Filter by name
            if ($Name -ne '*') {
                $providers = $providers | Where-Object { $_.Name -like $Name }
            }
            
            # Filter by capabilities
            if ($Capability) {
                foreach ($cap in $Capability) {
                    $providers = $providers | Where-Object { 
                        $_.Capabilities.$cap -eq $true 
                    }
                }
            }
            
            # Add status information
            foreach ($provider in $providers) {
                # Check if provider is ready
                $isReady = Test-ProviderReadiness -Provider $provider
                $provider | Add-Member -NotePropertyName 'IsReady' -NotePropertyValue $isReady -Force
                
                # Get provider status
                $status = if ($provider.Registered) {
                    if ($isReady) { 'Ready' } else { 'NotReady' }
                } else {
                    'Available'
                }
                $provider | Add-Member -NotePropertyName 'Status' -NotePropertyValue $status -Force
            }
            
            # Sort by name
            $providers = $providers | Sort-Object Name
            
            # Output
            foreach ($provider in $providers) {
                Write-Output ([PSCustomObject]$provider)
            }
            
            # Summary if multiple providers
            if ($providers.Count -gt 1) {
                Write-CustomLog -Level 'INFO' -Message "Found $($providers.Count) provider(s)"
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get infrastructure providers: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-RegisteredProviders {
    # Get registered providers from module state
    if (-not $script:infrastructureProviders) {
        $script:infrastructureProviders = @{}
        
        # Load from persistent storage if available
        $statePath = Join-Path $env:PROJECT_ROOT "configs" "registered-providers.json"
        if (Test-Path $statePath) {
            try {
                $savedProviders = Get-Content $statePath | ConvertFrom-Json
                foreach ($provider in $savedProviders) {
                    $script:infrastructureProviders[$provider.Name] = $provider
                }
            } catch {
                Write-CustomLog -Level 'WARN' -Message "Could not load registered providers: $_"
            }
        }
    }
    
    return $script:infrastructureProviders
}

function Get-ProviderDefinition {
    param([string]$ProviderName)
    
    # Try to get provider definition
    $definitionFunc = "Get-${ProviderName}ProviderDefinition"
    
    if (Get-Command $definitionFunc -ErrorAction SilentlyContinue) {
        return & $definitionFunc
    }
    
    # Check for custom provider file
    $providersPath = Join-Path $PSScriptRoot "../../Private/Providers"
    $providerFile = Join-Path $providersPath "${ProviderName}Provider.ps1"
    
    if (Test-Path $providerFile) {
        . $providerFile
        if (Get-Command $definitionFunc -ErrorAction SilentlyContinue) {
            return & $definitionFunc
        }
    }
    
    return $null
}

function Test-ProviderReadiness {
    param([PSCustomObject]$Provider)
    
    # Basic readiness checks
    if (-not $Provider.Registered) {
        return $false
    }
    
    # Check required modules
    if ($Provider.RequiredModules) {
        foreach ($module in $Provider.RequiredModules) {
            if (-not (Get-Module -Name $module -ListAvailable)) {
                return $false
            }
        }
    }
    
    # Check provider-specific readiness
    if ($Provider.Methods.TestReadiness) {
        try {
            return & $Provider.Methods.TestReadiness
        } catch {
            Write-CustomLog -Level 'DEBUG' -Message "Provider readiness check failed: $_"
            return $false
        }
    }
    
    return $true
}

# Built-in provider definitions
function Get-HyperVProviderDefinition {
    @{
        Name = 'Hyper-V'
        DisplayName = 'Microsoft Hyper-V'
        Description = 'Microsoft Hyper-V virtualization provider for Windows Server'
        Version = '1.0.0'
        Author = 'AitherCore'
        
        Capabilities = @{
            SupportsVirtualMachines = $true
            SupportsNetworking = $true
            SupportsStorage = $true
            SupportsSnapshots = $true
            SupportsTemplates = $true
            RequiresISO = $true
            SupportsWindowsGuests = $true
            SupportsLinuxGuests = $true
            SupportsCustomization = $true
        }
        
        Requirements = @{
            OperatingSystem = 'Windows'
            PowerShellVersion = '5.1'
            RequiredModules = @('Hyper-V')
            RequiredFeatures = @('Hyper-V-PowerShell')
        }
        
        Configuration = @{
            DefaultVMPath = 'C:\VMs'
            DefaultVHDPath = 'C:\VMs\VHDs'
            DefaultSwitchName = 'Default Switch'
            Provider = 'taliesins/hyperv'
        }
        
        Methods = @{
            Initialize = $null  # Will be loaded from provider adapter
            ValidateConfiguration = $null
            TranslateResource = $null
            TestReadiness = $null
        }
    }
}

function Get-AzureProviderDefinition {
    @{
        Name = 'Azure'
        DisplayName = 'Microsoft Azure'
        Description = 'Microsoft Azure cloud provider'
        Version = '0.1.0'
        Author = 'AitherCore'
        
        Capabilities = @{
            SupportsVirtualMachines = $true
            SupportsNetworking = $true
            SupportsStorage = $true
            SupportsSnapshots = $true
            SupportsTemplates = $true
            RequiresISO = $false
            SupportsWindowsGuests = $true
            SupportsLinuxGuests = $true
            SupportsCustomization = $true
        }
        
        Requirements = @{
            OperatingSystem = 'Any'
            PowerShellVersion = '7.0'
            RequiredModules = @('Az')
        }
        
        Configuration = @{
            Provider = 'azurerm'
            RequiresAuthentication = $true
        }
        
        Methods = @{}
    }
}

function Get-AWSProviderDefinition {
    @{
        Name = 'AWS'
        DisplayName = 'Amazon Web Services'
        Description = 'Amazon Web Services cloud provider'
        Version = '0.1.0'
        Author = 'AitherCore'
        
        Capabilities = @{
            SupportsVirtualMachines = $true
            SupportsNetworking = $true
            SupportsStorage = $true
            SupportsSnapshots = $true
            SupportsTemplates = $true
            RequiresISO = $false
            SupportsWindowsGuests = $true
            SupportsLinuxGuests = $true
            SupportsCustomization = $true
        }
        
        Requirements = @{
            OperatingSystem = 'Any'
            PowerShellVersion = '7.0'
            RequiredModules = @('AWS.Tools')
        }
        
        Configuration = @{
            Provider = 'aws'
            RequiresAuthentication = $true
        }
        
        Methods = @{}
    }
}

function Get-VMwareProviderDefinition {
    @{
        Name = 'VMware'
        DisplayName = 'VMware vSphere'
        Description = 'VMware vSphere virtualization provider'
        Version = '0.1.0'
        Author = 'AitherCore'
        
        Capabilities = @{
            SupportsVirtualMachines = $true
            SupportsNetworking = $true
            SupportsStorage = $true
            SupportsSnapshots = $true
            SupportsTemplates = $true
            RequiresISO = $true
            SupportsWindowsGuests = $true
            SupportsLinuxGuests = $true
            SupportsCustomization = $true
        }
        
        Requirements = @{
            OperatingSystem = 'Any'
            PowerShellVersion = '7.0'
            RequiredModules = @('VMware.PowerCLI')
        }
        
        Configuration = @{
            Provider = 'vsphere'
            RequiresAuthentication = $true
        }
        
        Methods = @{}
    }
}