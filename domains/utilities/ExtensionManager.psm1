#Requires -Version 7.0
<#
.SYNOPSIS
    Extension management system for AitherZero Core
.DESCRIPTION
    Provides plugin/extension capabilities to make AitherZero Core extensible.
    Extensions can add:
    - New CLI modes
    - New automation scripts
    - New commands
    - New domains/modules
    - Custom validators
    
    Extensions are discovered from:
    - extensions/ directory (local extensions)
    - ~/.aitherzero/extensions/ (user extensions)
    - Configured remote repositories
    
.EXAMPLE
    # Load all extensions
    Initialize-ExtensionSystem
    
.EXAMPLE
    # Load specific extension
    Import-Extension -Name "MyExtension"
    
.EXAMPLE
    # List available extensions
    Get-AvailableExtensions
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Extension system state
$script:ExtensionRegistry = @{
    Loaded = @{}
    Available = @{}
    SearchPaths = @()
    Initialized = $false
}

<#
.SYNOPSIS
    Initializes the extension system
#>
function Initialize-ExtensionSystem {
    [CmdletBinding()]
    param(
        [string[]]$AdditionalPaths = @()
    )
    
    if ($script:ExtensionRegistry.Initialized) {
        Write-Verbose "Extension system already initialized"
        return
    }
    
    # Setup search paths
    $projectRoot = if ($env:AITHERZERO_ROOT) { $env:AITHERZERO_ROOT } else { $PWD }
    
    $script:ExtensionRegistry.SearchPaths = @(
        (Join-Path $projectRoot "extensions")                    # Local extensions
        (Join-Path $HOME ".aitherzero" "extensions")            # User extensions
    ) + $AdditionalPaths
    
    # Create extension directories if they don't exist
    foreach ($path in $script:ExtensionRegistry.SearchPaths) {
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
    
    # Discover available extensions
    Discover-Extensions
    
    # Load enabled extensions
    $config = Get-ExtensionConfiguration
    foreach ($extName in $config.EnabledExtensions) {
        try {
            Import-Extension -Name $extName -ErrorAction Continue
        } catch {
            Write-Warning "Failed to load extension '$extName': $_"
        }
    }
    
    $script:ExtensionRegistry.Initialized = $true
    
    Write-Verbose "Extension system initialized. Loaded $($script:ExtensionRegistry.Loaded.Count) extensions."
}

<#
.SYNOPSIS
    Discovers available extensions
#>
function Discover-Extensions {
    [CmdletBinding()]
    param()
    
    $script:ExtensionRegistry.Available = @{}
    
    foreach ($searchPath in $script:ExtensionRegistry.SearchPaths) {
        if (-not (Test-Path $searchPath)) { continue }
        
        # Look for extension manifest files
        $manifestFiles = Get-ChildItem -Path $searchPath -Filter "*.extension.psd1" -Recurse -ErrorAction SilentlyContinue
        
        foreach ($manifestFile in $manifestFiles) {
            try {
                # Use scriptblock evaluation for .psd1 files
                $content = Get-Content -Path $manifestFile.FullName -Raw
                $scriptBlock = [scriptblock]::Create($content)
                $manifest = & $scriptBlock
                
                if (-not $manifest -or $manifest -isnot [hashtable]) {
                    Write-Warning "Extension manifest did not return a valid hashtable: $($manifestFile.FullName)"
                    continue
                }
                
                # Validate manifest
                if (-not $manifest.Name) {
                    Write-Warning "Extension manifest missing Name: $($manifestFile.FullName)"
                    continue
                }
                
                $extensionInfo = @{
                    Name = $manifest.Name
                    Version = $manifest.Version
                    Description = $manifest.Description
                    Author = $manifest.Author
                    ManifestPath = $manifestFile.FullName
                    RootPath = $manifestFile.Directory.FullName
                    Manifest = $manifest
                }
                
                $script:ExtensionRegistry.Available[$manifest.Name] = $extensionInfo
                
            } catch {
                Write-Warning "Failed to read extension manifest: $($manifestFile.FullName) - $_"
            }
        }
    }
}

<#
.SYNOPSIS
    Imports an extension
#>
function Import-Extension {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [switch]$Force
    )
    
    # Check if already loaded
    if ($script:ExtensionRegistry.Loaded.ContainsKey($Name) -and -not $Force) {
        Write-Verbose "Extension '$Name' already loaded"
        return $script:ExtensionRegistry.Loaded[$Name]
    }
    
    # Check if available
    if (-not $script:ExtensionRegistry.Available.ContainsKey($Name)) {
        throw "Extension '$Name' not found. Run Discover-Extensions first."
    }
    
    $extInfo = $script:ExtensionRegistry.Available[$Name]
    $manifest = $extInfo.Manifest
    
    Write-Verbose "Loading extension: $Name v$($manifest.Version)"
    
    # Check dependencies
    if ($manifest.Dependencies) {
        foreach ($dep in $manifest.Dependencies) {
            if (-not $script:ExtensionRegistry.Loaded.ContainsKey($dep)) {
                Write-Verbose "Loading dependency: $dep"
                Import-Extension -Name $dep
            }
        }
    }
    
    # Load modules
    if ($manifest.Modules) {
        foreach ($modulePath in $manifest.Modules) {
            $fullPath = Join-Path $extInfo.RootPath $modulePath
            if (Test-Path $fullPath) {
                Import-Module $fullPath -Force -ErrorAction Stop
            } else {
                Write-Warning "Module not found: $fullPath"
            }
        }
    }
    
    # Register CLI modes
    if ($manifest.CLIModes) {
        foreach ($mode in $manifest.CLIModes) {
            Register-ExtensionCLIMode -Extension $Name -Mode $mode
        }
    }
    
    # Register commands
    if ($manifest.Commands) {
        foreach ($command in $manifest.Commands) {
            Register-ExtensionCommand -Extension $Name -Command $command
        }
    }
    
    # Register automation scripts
    if ($manifest.Scripts) {
        Register-ExtensionScripts -Extension $Name -Scripts $manifest.Scripts -RootPath $extInfo.RootPath
    }
    
    # Run initialization script if provided
    if ($manifest.Initialize) {
        $initScript = Join-Path $extInfo.RootPath $manifest.Initialize
        if (Test-Path $initScript) {
            & $initScript
        }
    }
    
    # Mark as loaded
    $script:ExtensionRegistry.Loaded[$Name] = $extInfo
    
    Write-Verbose "Extension loaded: $Name"
    
    return $extInfo
}

<#
.SYNOPSIS
    Unloads an extension
#>
function Remove-Extension {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    if (-not $script:ExtensionRegistry.Loaded.ContainsKey($Name)) {
        Write-Warning "Extension '$Name' is not loaded"
        return
    }
    
    $extInfo = $script:ExtensionRegistry.Loaded[$Name]
    $manifest = $extInfo.Manifest
    
    # Unload modules
    if ($manifest.Modules) {
        foreach ($modulePath in $manifest.Modules) {
            $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($modulePath)
            Remove-Module $moduleName -ErrorAction SilentlyContinue
        }
    }
    
    # Run cleanup script if provided
    if ($manifest.Cleanup) {
        $cleanupScript = Join-Path $extInfo.RootPath $manifest.Cleanup
        if (Test-Path $cleanupScript) {
            & $cleanupScript
        }
    }
    
    # Remove from loaded registry
    $script:ExtensionRegistry.Loaded.Remove($Name)
    
    Write-Verbose "Extension unloaded: $Name"
}

<#
.SYNOPSIS
    Gets list of available extensions
#>
function Get-AvailableExtensions {
    [CmdletBinding()]
    param(
        [switch]$LoadedOnly,
        [switch]$AsHashtable
    )
    
    if ($AsHashtable) {
        # Return the raw hashtable for programmatic access
        if ($LoadedOnly) {
            return $script:ExtensionRegistry.Loaded
        }
        return $script:ExtensionRegistry.Available
    }
    
    if ($LoadedOnly) {
        return $script:ExtensionRegistry.Loaded.Values | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                Version = $_.Version
                Description = $_.Description
                Author = $_.Author
                Status = 'Loaded'
                Path = $_.RootPath
            }
        }
    }
    
    return $script:ExtensionRegistry.Available.Values | ForEach-Object {
        $status = if ($script:ExtensionRegistry.Loaded.ContainsKey($_.Name)) { 'Loaded' } else { 'Available' }
        
        [PSCustomObject]@{
            Name = $_.Name
            Version = $_.Version
            Description = $_.Description
            Author = $_.Author
            Status = $status
            Path = $_.RootPath
        }
    }
}

<#
.SYNOPSIS
    Registers a CLI mode from an extension
#>
function Register-ExtensionCLIMode {
    [CmdletBinding()]
    param(
        [string]$Extension,
        [hashtable]$Mode
    )
    
    # Store in global registry for CommandParser
    if (-not $global:AitherZeroExtensionModes) {
        $global:AitherZeroExtensionModes = @{}
    }
    
    $global:AitherZeroExtensionModes[$Mode.Name] = @{
        Extension = $Extension
        Handler = $Mode.Handler
        Description = $Mode.Description
        Parameters = $Mode.Parameters
    }
    
    Write-Verbose "Registered CLI mode: $($Mode.Name) from extension $Extension"
}

<#
.SYNOPSIS
    Registers a command from an extension
#>
function Register-ExtensionCommand {
    [CmdletBinding()]
    param(
        [string]$Extension,
        [hashtable]$Command
    )
    
    # Store in global registry
    if (-not $global:AitherZeroExtensionCommands) {
        $global:AitherZeroExtensionCommands = @{}
    }
    
    $global:AitherZeroExtensionCommands[$Command.Name] = @{
        Extension = $Extension
        Function = $Command.Function
        Description = $Command.Description
        Alias = $Command.Alias
    }
    
    Write-Verbose "Registered command: $($Command.Name) from extension $Extension"
}

<#
.SYNOPSIS
    Registers automation scripts from an extension
#>
function Register-ExtensionScripts {
    [CmdletBinding()]
    param(
        [string]$Extension,
        [hashtable]$Scripts,
        [string]$RootPath
    )
    
    # Store in global registry
    if (-not $global:AitherZeroExtensionScripts) {
        $global:AitherZeroExtensionScripts = @{}
    }
    
    foreach ($scriptInfo in $Scripts) {
        $scriptPath = Join-Path $RootPath $scriptInfo.Path
        
        $global:AitherZeroExtensionScripts[$scriptInfo.Number] = @{
            Extension = $Extension
            Number = $scriptInfo.Number
            Name = $scriptInfo.Name
            Path = $scriptPath
            Category = $scriptInfo.Category
        }
        
        Write-Verbose "Registered script: $($scriptInfo.Number) from extension $Extension"
    }
}

<#
.SYNOPSIS
    Gets extension configuration
#>
function Get-ExtensionConfiguration {
    [CmdletBinding()]
    param()
    
    # Default configuration
    $config = @{
        EnabledExtensions = @()
        ExtensionRepositories = @()
    }
    
    # Try to load from config.psd1
    $projectRoot = if ($env:AITHERZERO_ROOT) { $env:AITHERZERO_ROOT } else { $PWD }
    $configPath = Join-Path $projectRoot "config.psd1"
    
    if (Test-Path $configPath) {
        try {
            # Use scriptblock evaluation to handle PowerShell expressions in config
            $configContent = Get-Content -Path $configPath -Raw
            $scriptBlock = [scriptblock]::Create($configContent)
            $mainConfig = & $scriptBlock
            if ($mainConfig.Extensions) {
                $config = $mainConfig.Extensions
            }
        } catch {
            Write-Warning "Failed to load extension configuration: $_"
        }
    }
    
    return $config
}

<#
.SYNOPSIS
    Creates a new extension template
#>
function New-ExtensionTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$Author = $env:USERNAME,
        
        [string]$Description = "AitherZero extension"
    )
    
    $extPath = Join-Path $Path $Name
    
    if (Test-Path $extPath) {
        throw "Extension directory already exists: $extPath"
    }
    
    # Create directory structure
    New-Item -ItemType Directory -Path $extPath -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $extPath "modules") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $extPath "scripts") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $extPath "tests") -Force | Out-Null
    
    # Create manifest
    $manifestContent = @"
@{
    Name = '$Name'
    Version = '1.0.0'
    Description = '$Description'
    Author = '$Author'
    
    # Modules to load
    Modules = @(
        'modules/$Name.psm1'
    )
    
    # CLI modes this extension adds
    CLIModes = @(
        @{
            Name = '${Name}Mode'
            Handler = 'Invoke-${Name}Mode'
            Description = 'Custom mode from $Name extension'
            Parameters = @('Target')
        }
    )
    
    # Commands this extension provides
    Commands = @(
        @{
            Name = 'Invoke-${Name}Command'
            Function = 'Invoke-${Name}Command'
            Description = 'Main command for $Name extension'
            Alias = @()
        }
    )
    
    # Automation scripts
    Scripts = @(
        @{
            Number = '8000'
            Name = '${Name}-Example'
            Path = 'scripts/8000_${Name}-Example.ps1'
            Category = 'Extensions'
        }
    )
    
    # Dependencies on other extensions
    Dependencies = @()
    
    # Initialization script
    Initialize = 'Initialize.ps1'
    
    # Cleanup script
    Cleanup = 'Cleanup.ps1'
}
"@
    
    Set-Content -Path (Join-Path $extPath "$Name.extension.psd1") -Value $manifestContent
    
    # Create sample module
    $moduleContent = @"
#Requires -Version 7.0

function Invoke-${Name}Command {
    [CmdletBinding()]
    param(
        [string]`$Target
    )
    
    Write-Host "Hello from $Name extension!" -ForegroundColor Green
    Write-Host "Target: `$Target" -ForegroundColor Cyan
}

function Invoke-${Name}Mode {
    [CmdletBinding()]
    param(
        [hashtable]`$Parameters
    )
    
    Write-Host "${Name}Mode activated!" -ForegroundColor Green
    Invoke-${Name}Command -Target `$Parameters.Target
}

Export-ModuleMember -Function @(
    'Invoke-${Name}Command'
    'Invoke-${Name}Mode'
)
"@
    
    Set-Content -Path (Join-Path $extPath "modules" "$Name.psm1") -Value $moduleContent
    
    # Create initialization script
    $initContent = @"
# Initialize $Name extension
Write-Verbose "Initializing $Name extension..."
"@
    
    Set-Content -Path (Join-Path $extPath "Initialize.ps1") -Value $initContent
    
    # Create cleanup script
    $cleanupContent = @"
# Cleanup $Name extension
Write-Verbose "Cleaning up $Name extension..."
"@
    
    Set-Content -Path (Join-Path $extPath "Cleanup.ps1") -Value $cleanupContent
    
    # Create sample script
    $scriptContent = @"
#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Example script from $Name extension
.DESCRIPTION
    This is a sample automation script provided by the $Name extension.
#>

param()

Write-Host "Executing $Name extension script" -ForegroundColor Green
"@
    
    Set-Content -Path (Join-Path $extPath "scripts" "8000_${Name}-Example.ps1") -Value $scriptContent
    
    # Create README
    $readmeContent = @"
# $Name Extension

$Description

## Installation

1. Copy this directory to ``extensions/$Name`` or ``~/.aitherzero/extensions/$Name``
2. Add to config.psd1:
   ``````powershell
   Extensions = @{
       EnabledExtensions = @('$Name')
   }
   ``````
3. Restart AitherZero or run ``Import-Extension -Name '$Name'``

## Usage

``````powershell
# Use the custom command
Invoke-${Name}Command -Target "example"

# Use the custom CLI mode
./Start-AitherZero.ps1 -Mode ${Name}Mode -Target "example"
``````

## Files

- ``$Name.extension.psd1`` - Extension manifest
- ``modules/$Name.psm1`` - PowerShell module
- ``scripts/`` - Automation scripts
- ``tests/`` - Tests for this extension

## Author

$Author
"@
    
    Set-Content -Path (Join-Path $extPath "README.md") -Value $readmeContent
    
    Write-Host "✅ Extension template created: $extPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Edit the manifest: $extPath/$Name.extension.psd1" -ForegroundColor White
    Write-Host "  2. Implement your module: $extPath/modules/$Name.psm1" -ForegroundColor White
    Write-Host "  3. Add automation scripts to: $extPath/scripts/" -ForegroundColor White
    Write-Host "  4. Test your extension: Import-Extension -Name '$Name'" -ForegroundColor White
    
    return $extPath
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-ExtensionSystem'
    'Discover-Extensions'
    'Import-Extension'
    'Remove-Extension'
    'Get-AvailableExtensions'
    'New-ExtensionTemplate'
    'Get-ExtensionConfiguration'
)
