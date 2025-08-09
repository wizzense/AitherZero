#Requires -Version 7.0
<#
.SYNOPSIS
    Component registry for dynamic component registration and discovery
.DESCRIPTION
    Manages component registration, discovery, and instantiation
#>

# Component registry storage
$script:RegisteredComponents = @{}
$script:ComponentAliases = @{}
$script:ComponentMetadata = @{}

function Register-UIComponent {
    <#
    .SYNOPSIS
        Register a component type with the registry
    .PARAMETER Name
        Component name
    .PARAMETER Type
        Component type/class
    .PARAMETER Factory
        Factory function to create component instances
    .PARAMETER Aliases
        Alternative names for the component
    .PARAMETER Metadata
        Additional metadata about the component
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string]$Type,
        
        [Parameter(Mandatory)]
        [scriptblock]$Factory,
        
        [string[]]$Aliases = @(),
        
        [hashtable]$Metadata = @{}
    )
    
    # Register component
    $script:RegisteredComponents[$Name] = @{
        Name = $Name
        Type = $Type
        Factory = $Factory
        Aliases = $Aliases
        Metadata = $Metadata
        RegisteredAt = [DateTime]::Now
    }
    
    # Register aliases
    foreach ($alias in $Aliases) {
        $script:ComponentAliases[$alias] = $Name
    }
    
    # Store metadata
    $script:ComponentMetadata[$Name] = $Metadata
    
    Write-Verbose "Registered component: $Name (Type: $Type)"
}

function Get-UIComponent {
    <#
    .SYNOPSIS
        Get a registered component by name
    .PARAMETER Name
        Component name or alias
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    # Check if it's an alias
    if ($script:ComponentAliases.ContainsKey($Name)) {
        $Name = $script:ComponentAliases[$Name]
    }
    
    # Return component registration
    return $script:RegisteredComponents[$Name]
}

function New-UIComponentInstance {
    <#
    .SYNOPSIS
        Create a new instance of a registered component
    .PARAMETER Name
        Component name or alias
    .PARAMETER Parameters
        Parameters to pass to the factory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [hashtable]$Parameters = @{}
    )
    
    $component = Get-UIComponent -Name $Name
    
    if (-not $component) {
        throw "Component '$Name' is not registered"
    }
    
    # Call factory with parameters
    $instance = & $component.Factory @Parameters
    
    # Add registry metadata
    if ($instance -is [PSCustomObject]) {
        Add-Member -InputObject $instance -MemberType NoteProperty -Name "__ComponentType" -Value $component.Type -Force
        Add-Member -InputObject $instance -MemberType NoteProperty -Name "__ComponentName" -Value $component.Name -Force
    }
    
    return $instance
}

function Get-UIComponentList {
    <#
    .SYNOPSIS
        Get list of all registered components
    .PARAMETER Type
        Filter by component type
    .PARAMETER Tag
        Filter by metadata tag
    #>
    [CmdletBinding()]
    param(
        [string]$Type,
        [string]$Tag
    )
    
    $components = $script:RegisteredComponents.Values
    
    if ($Type) {
        $components = $components | Where-Object { $_.Type -eq $Type }
    }
    
    if ($Tag) {
        $components = $components | Where-Object { 
            $_.Metadata.Tags -and $Tag -in $_.Metadata.Tags 
        }
    }
    
    return $components
}

function Unregister-UIComponent {
    <#
    .SYNOPSIS
        Unregister a component from the registry
    .PARAMETER Name
        Component name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    if ($script:RegisteredComponents.ContainsKey($Name)) {
        $component = $script:RegisteredComponents[$Name]
        
        # Remove aliases
        foreach ($alias in $component.Aliases) {
            $script:ComponentAliases.Remove($alias)
        }
        
        # Remove metadata
        $script:ComponentMetadata.Remove($Name)
        
        # Remove component
        $script:RegisteredComponents.Remove($Name)
        
        Write-Verbose "Unregistered component: $Name"
    }
}

function Import-UIComponentModule {
    <#
    .SYNOPSIS
        Import a module and auto-register its components
    .PARAMETER Path
        Path to the module
    .PARAMETER Prefix
        Prefix for component names
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$Prefix = ""
    )
    
    if (-not (Test-Path $Path)) {
        throw "Module path not found: $Path"
    }
    
    # Import module
    $module = Import-Module $Path -PassThru -Force
    
    # Look for exported functions that match component pattern
    $componentFunctions = $module.ExportedFunctions.Keys | Where-Object { 
        $_ -match '^New-.*Component$' -or $_ -match '^New-UI.*'
    }
    
    foreach ($funcName in $componentFunctions) {
        # Extract component name
        $componentName = $funcName -replace '^New-' -replace 'Component$' -replace '^UI'
        
        if ($Prefix) {
            $componentName = "$Prefix$componentName"
        }
        
        # Create factory
        $factory = [scriptblock]::Create("param(`$Parameters) & $funcName @Parameters")
        
        # Register component
        Register-UIComponent -Name $componentName -Type "Module:$($module.Name)" -Factory $factory -Metadata @{
            Module = $module.Name
            Function = $funcName
            Path = $Path
        }
    }
    
    Write-Verbose "Imported $($componentFunctions.Count) components from $($module.Name)"
}

function Initialize-UIComponentRegistry {
    <#
    .SYNOPSIS
        Initialize the component registry with built-in components
    #>
    [CmdletBinding()]
    param()
    
    # Register built-in components
    $componentsPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Components"
    
    # InteractiveMenu
    if (Test-Path (Join-Path $componentsPath "InteractiveMenu.psm1")) {
        Register-UIComponent -Name "InteractiveMenu" -Type "BuiltIn" -Factory {
            param($Items, $Title, $MultiSelect, $ShowNumbers)
            
            $menuModule = Join-Path $componentsPath "InteractiveMenu.psm1"
            Import-Module $menuModule -Force
            
            New-InteractiveMenu -Items $Items -Title $Title `
                -MultiSelect:$MultiSelect -ShowNumbers:$ShowNumbers
        } -Aliases @("Menu", "IMenu") -Metadata @{
            Tags = @("Menu", "Interactive", "BuiltIn")
            Description = "Interactive menu with keyboard navigation"
            Version = "1.0.0"
        }
    }
    
    # Register other built-in components as they're created
    # TextField, SelectList, ProgressBar, Table, Dialog, etc.
    
    Write-Verbose "Component registry initialized with built-in components"
}

function Export-UIComponentRegistry {
    <#
    .SYNOPSIS
        Export the component registry to JSON
    .PARAMETER Path
        Path to save the registry
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $export = @{
        Components = @()
        Aliases = $script:ComponentAliases
        ExportedAt = [DateTime]::Now
    }
    
    foreach ($component in $script:RegisteredComponents.Values) {
        $export.Components += @{
            Name = $component.Name
            Type = $component.Type
            Aliases = $component.Aliases
            Metadata = $component.Metadata
            RegisteredAt = $component.RegisteredAt
        }
    }
    
    $export | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
    Write-Verbose "Exported component registry to: $Path"
}

function Import-UIComponentRegistry {
    <#
    .SYNOPSIS
        Import a component registry from JSON
    .PARAMETER Path
        Path to the registry file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        throw "Registry file not found: $Path"
    }
    
    $import = Get-Content $Path -Raw | ConvertFrom-Json
    
    # Note: This only imports metadata, not the actual factories
    # Factories need to be re-registered from their source modules
    
    foreach ($component in $import.Components) {
        $script:ComponentMetadata[$component.Name] = $component.Metadata
        
        foreach ($alias in $component.Aliases) {
            $script:ComponentAliases[$alias] = $component.Name
        }
    }
    
    Write-Verbose "Imported component registry from: $Path"
}

# Auto-discovery of components
function Discover-UIComponents {
    <#
    .SYNOPSIS
        Discover and register components from a directory
    .PARAMETER Path
        Directory to search for components
    .PARAMETER Recursive
        Search recursively
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [switch]$Recursive
    )
    
    $searchPath = if ($Recursive) { 
        Join-Path $Path "**/*.psm1" 
    } else { 
        Join-Path $Path "*.psm1" 
    }
    
    $modules = Get-ChildItem -Path $searchPath -File
    
    foreach ($module in $modules) {
        try {
            Import-UIComponentModule -Path $module.FullName
        }
        catch {
            Write-Warning "Failed to import component module: $($module.Name) - $_"
        }
    }
    
    Write-Verbose "Discovered components in: $Path"
}

# Export functions
Export-ModuleMember -Function @(
    'Register-UIComponent'
    'Get-UIComponent'
    'New-UIComponentInstance'
    'Get-UIComponentList'
    'Unregister-UIComponent'
    'Import-UIComponentModule'
    'Initialize-UIComponentRegistry'
    'Export-UIComponentRegistry'
    'Import-UIComponentRegistry'
    'Discover-UIComponents'
)