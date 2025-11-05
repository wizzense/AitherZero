#Requires -Version 7.0
<#
.SYNOPSIS
    Advanced configuration management with UI and switching capabilities
.DESCRIPTION
    Provides config-driven UI/CLI, config switching, validation, and manifest-based capabilities
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Configuration manager state
$script:ConfigManager = @{
    ActiveConfig = $null
    AvailableConfigs = @{}
    ConfigHistory = @()
    ManifestCapabilities = @{}
    Initialized = $false
}

<#
.SYNOPSIS
    Initializes the configuration manager
#>
function Initialize-ConfigManager {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = $null
    )
    
    if ($script:ConfigManager.Initialized) {
        return
    }
    
    $projectRoot = if ($env:AITHERZERO_ROOT) { $env:AITHERZERO_ROOT } else { $PWD }
    
    # Discover available configs
    Discover-Configurations -ProjectRoot $projectRoot
    
    # Load active config
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $projectRoot "config.psd1"
    }
    
    if (Test-Path $ConfigPath) {
        $script:ConfigManager.ActiveConfig = Import-ConfigManifest -Path $ConfigPath
        Build-CapabilitiesFromManifest -Config $script:ConfigManager.ActiveConfig
    }
    
    $script:ConfigManager.Initialized = $true
    
    Write-Verbose "Configuration manager initialized"
}

<#
.SYNOPSIS
    Discovers all available configuration files
#>
function Discover-Configurations {
    [CmdletBinding()]
    param([string]$ProjectRoot)
    
    $script:ConfigManager.AvailableConfigs = @{}
    
    # Look for config files in project root
    $configFiles = Get-ChildItem -Path $ProjectRoot -Filter "config*.psd1" -ErrorAction SilentlyContinue
    
    foreach ($file in $configFiles) {
        try {
            $config = Import-PowerShellDataFile -Path $file.FullName
            
            $configInfo = @{
                Name = $file.BaseName
                Path = $file.FullName
                Profile = if ($config.Core) { $config.Core.Profile } else { "Unknown" }
                Environment = if ($config.Core) { $config.Core.Environment } else { "Development" }
                Description = if ($config.Manifest) { $config.Manifest.Description } else { "Configuration file" }
                LastModified = $file.LastWriteTime
            }
            
            $script:ConfigManager.AvailableConfigs[$file.BaseName] = $configInfo
            
        } catch {
            Write-Warning "Failed to read config: $($file.FullName) - $_"
        }
    }
    
    # Also check for environment-specific configs
    $configDir = Join-Path $ProjectRoot "configs"
    if (Test-Path $configDir) {
        $envConfigs = Get-ChildItem -Path $configDir -Filter "*.psd1" -ErrorAction SilentlyContinue
        
        foreach ($file in $envConfigs) {
            try {
                $config = Import-PowerShellDataFile -Path $file.FullName
                
                $configInfo = @{
                    Name = $file.BaseName
                    Path = $file.FullName
                    Profile = if ($config.Core) { $config.Core.Profile } else { "Unknown" }
                    Environment = if ($config.Core) { $config.Core.Environment } else { "Development" }
                    Description = if ($config.Manifest) { $config.Manifest.Description } else { "Configuration file" }
                    LastModified = $file.LastWriteTime
                }
                
                $script:ConfigManager.AvailableConfigs["configs/$($file.BaseName)"] = $configInfo
                
            } catch {
                Write-Warning "Failed to read config: $($file.FullName) - $_"
            }
        }
    }
}

<#
.SYNOPSIS
    Imports and validates a configuration manifest
#>
function Import-ConfigManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        throw "Configuration file not found: $Path"
    }
    
    Write-Verbose "Loading configuration from: $Path"
    
    try {
        $config = Import-PowerShellDataFile -Path $Path
        
        # Add metadata
        $config._Metadata = @{
            LoadedFrom = $Path
            LoadedAt = Get-Date
            Version = if ($config.Manifest) { $config.Manifest.Version } else { "Unknown" }
        }
        
        # Validate required sections
        $requiredSections = @('Manifest', 'Core')
        foreach ($section in $requiredSections) {
            if (-not $config.ContainsKey($section)) {
                Write-Warning "Configuration missing required section: $section"
            }
        }
        
        Write-Verbose "Configuration loaded successfully"
        
        return $config
        
    } catch {
        throw "Failed to load configuration from $Path`: $_"
    }
}

<#
.SYNOPSIS
    Builds capability map from manifest
#>
function Build-CapabilitiesFromManifest {
    [CmdletBinding()]
    param([hashtable]$Config)
    
    $script:ConfigManager.ManifestCapabilities = @{
        Modes = @()
        Scripts = @{}
        Features = @{}
        Domains = @()
        Extensions = @()
    }
    
    # Extract available modes from manifest or config
    if ($Config.ContainsKey('Manifest') -and $Config.Manifest -and $Config.Manifest.ContainsKey('SupportedModes')) {
        $script:ConfigManager.ManifestCapabilities.Modes = $Config.Manifest.SupportedModes
    } else {
        # Default modes
        $script:ConfigManager.ManifestCapabilities.Modes = @(
            'Interactive', 'Orchestrate', 'Validate', 'Deploy', 'Test', 'List', 'Search', 'Run'
        )
    }
    
    # Extract script inventory
    if ($Config.ContainsKey('ScriptInventory') -and $Config.ScriptInventory) {
        $script:ConfigManager.ManifestCapabilities.Scripts = $Config.ScriptInventory
    }
    
    # Extract features
    if ($Config.ContainsKey('Features') -and $Config.Features) {
        foreach ($key in $Config.Features.Keys) {
            $feature = $Config.Features[$key]
            if ($feature -is [hashtable] -and $feature.ContainsKey('Enabled') -and $feature.Enabled) {
                $script:ConfigManager.ManifestCapabilities.Features[$key] = $feature
            }
        }
    }
    
    # Extract enabled extensions
    if ($Config.ContainsKey('Extensions') -and $Config.Extensions -and $Config.Extensions.ContainsKey('EnabledExtensions')) {
        $script:ConfigManager.ManifestCapabilities.Extensions = $Config.Extensions.EnabledExtensions
    }
    
    Write-Verbose "Built capabilities: $($script:ConfigManager.ManifestCapabilities.Modes.Count) modes, $($script:ConfigManager.ManifestCapabilities.Features.Count) features"
}

<#
.SYNOPSIS
    Switches to a different configuration
#>
function Switch-Configuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigName,
        
        [switch]$Reload
    )
    
    # Check if config exists
    if (-not $script:ConfigManager.AvailableConfigs.ContainsKey($ConfigName)) {
        throw "Configuration '$ConfigName' not found. Available: $($script:ConfigManager.AvailableConfigs.Keys -join ', ')"
    }
    
    $configInfo = $script:ConfigManager.AvailableConfigs[$ConfigName]
    
    # Save current config to history
    if ($script:ConfigManager.ActiveConfig) {
        $script:ConfigManager.ConfigHistory += @{
            Config = $script:ConfigManager.ActiveConfig
            SwitchedAt = Get-Date
        }
    }
    
    # Load new config
    $script:ConfigManager.ActiveConfig = Import-ConfigManifest -Path $configInfo.Path
    Build-CapabilitiesFromManifest -Config $script:ConfigManager.ActiveConfig
    
    Write-Host "✅ Switched to configuration: $ConfigName" -ForegroundColor Green
    Write-Host "   Profile: $($configInfo.Profile)" -ForegroundColor Cyan
    Write-Host "   Environment: $($configInfo.Environment)" -ForegroundColor Cyan
    
    if ($Reload) {
        Write-Host "   Reloading modules..." -ForegroundColor Yellow
        # Trigger module reload (if needed)
    }
}

<#
.SYNOPSIS
    Gets list of available configurations
#>
function Get-AvailableConfigurations {
    [CmdletBinding()]
    param([switch]$Detailed)
    
    if (-not $script:ConfigManager.Initialized) {
        Initialize-ConfigManager
    }
    
    $configs = $script:ConfigManager.AvailableConfigs.GetEnumerator() | ForEach-Object {
        $key = $_.Key
        $value = $_.Value
        
        $isCurrent = $script:ConfigManager.ActiveConfig -and 
                     $script:ConfigManager.ActiveConfig._Metadata.LoadedFrom -eq $value.Path
        
        [PSCustomObject]@{
            Key = $key  # Add the actual dictionary key
            Name = $value.Name
            Profile = $value.Profile
            Environment = $value.Environment
            Description = $value.Description
            LastModified = $value.LastModified
            Current = $isCurrent
            Path = if ($Detailed) { $value.Path } else { $null }
        }
    }
    
    return $configs | Sort-Object -Property Name
}

<#
.SYNOPSIS
    Gets current configuration
#>
function Get-CurrentConfiguration {
    [CmdletBinding()]
    param([switch]$Full)
    
    if (-not $script:ConfigManager.Initialized) {
        Initialize-ConfigManager
    }
    
    if ($Full) {
        return $script:ConfigManager.ActiveConfig
    }
    
    return [PSCustomObject]@{
        Name = if ($script:ConfigManager.ActiveConfig._Metadata) { 
            [System.IO.Path]::GetFileNameWithoutExtension($script:ConfigManager.ActiveConfig._Metadata.LoadedFrom)
        } else { "Unknown" }
        Profile = $script:ConfigManager.ActiveConfig.Core.Profile
        Environment = $script:ConfigManager.ActiveConfig.Core.Environment
        Version = $script:ConfigManager.ActiveConfig.Manifest.Version
        LoadedAt = $script:ConfigManager.ActiveConfig._Metadata.LoadedAt
    }
}

<#
.SYNOPSIS
    Gets capabilities from manifest
#>
function Get-ManifestCapabilities {
    [CmdletBinding()]
    param(
        [ValidateSet('All', 'Modes', 'Scripts', 'Features', 'Extensions')]
        [string]$Type = 'All'
    )
    
    if (-not $script:ConfigManager.Initialized) {
        Initialize-ConfigManager
    }
    
    if ($Type -eq 'All') {
        return $script:ConfigManager.ManifestCapabilities
    }
    
    return $script:ConfigManager.ManifestCapabilities[$Type]
}

<#
.SYNOPSIS
    Interactive configuration selector
#>
function Show-ConfigurationSelector {
    [CmdletBinding()]
    param()
    
    if (-not $script:ConfigManager.Initialized) {
        Initialize-ConfigManager
    }
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              Configuration Selector                            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    $current = Get-CurrentConfiguration
    Write-Host "Current Configuration: " -NoNewline -ForegroundColor White
    Write-Host $current.Name -ForegroundColor Yellow
    Write-Host "Profile: " -NoNewline -ForegroundColor White
    Write-Host $current.Profile -ForegroundColor Cyan
    Write-Host "Environment: " -NoNewline -ForegroundColor White
    Write-Host $current.Environment -ForegroundColor Cyan
    Write-Host ""
    
    $configs = Get-AvailableConfigurations
    
    if ($configs.Count -eq 0) {
        Write-Host "No configurations found" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Available Configurations:" -ForegroundColor Yellow
    Write-Host ""
    
    $index = 1
    $configList = @()
    foreach ($config in $configs) {
        $marker = if ($config.Current) { "►" } else { " " }
        $status = if ($config.Current) { " (current)" } else { "" }
        
        Write-Host "  $marker [$index] " -NoNewline -ForegroundColor $(if ($config.Current) { "Cyan" } else { "White" })
        Write-Host $config.Name -NoNewline -ForegroundColor $(if ($config.Current) { "Yellow" } else { "White" })
        Write-Host $status -ForegroundColor Green
        Write-Host "        Profile: $($config.Profile) | Environment: $($config.Environment)" -ForegroundColor DarkGray
        
        $configList += $config
        $index++
    }
    
    Write-Host ""
    Write-Host "Select configuration (1-$($configs.Count)), R to reload, Q to quit: " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    
    if ($selection -eq 'Q' -or $selection -eq 'q') {
        return
    }
    
    if ($selection -eq 'R' -or $selection -eq 'r') {
        Discover-Configurations -ProjectRoot $(if ($env:AITHERZERO_ROOT) { $env:AITHERZERO_ROOT } else { $PWD })
        Write-Host "✅ Configuration list reloaded" -ForegroundColor Green
        return Show-ConfigurationSelector
    }
    
    try {
        $selectedIndex = [int]$selection - 1
        if ($selectedIndex -ge 0 -and $selectedIndex -lt $configList.Count) {
            $selectedConfig = $configList[$selectedIndex]
            # Use the Key property which contains the actual dictionary key (e.g., "configs/dev")
            Switch-Configuration -ConfigName $selectedConfig.Key
        } else {
            Write-Host "Invalid selection" -ForegroundColor Red
        }
    } catch {
        Write-Host "Invalid input" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Edits configuration file
#>
function Edit-Configuration {
    [CmdletBinding()]
    param(
        [string]$ConfigName = $null,
        
        [string]$Editor = $null
    )
    
    if (-not $script:ConfigManager.Initialized) {
        Initialize-ConfigManager
    }
    
    # Determine which config to edit
    $configPath = if ($ConfigName) {
        if ($script:ConfigManager.AvailableConfigs.ContainsKey($ConfigName)) {
            $script:ConfigManager.AvailableConfigs[$ConfigName].Path
        } else {
            throw "Configuration '$ConfigName' not found"
        }
    } else {
        # Edit current config
        $script:ConfigManager.ActiveConfig._Metadata.LoadedFrom
    }
    
    # Determine editor
    if (-not $Editor) {
        if ($env:EDITOR) {
            $Editor = $env:EDITOR
        } elseif ($IsWindows) {
            $Editor = "notepad"
        } else {
            $Editor = "nano"
        }
    }
    
    Write-Host "Opening configuration in $Editor..." -ForegroundColor Cyan
    Write-Host "File: $configPath" -ForegroundColor White
    
    & $Editor $configPath
    
    Write-Host ""
    Write-Host "Reload configuration? (Y/N): " -NoNewline -ForegroundColor Cyan
    $reload = Read-Host
    
    if ($reload -eq 'Y' -or $reload -eq 'y') {
        $configName = [System.IO.Path]::GetFileNameWithoutExtension($configPath)
        Switch-Configuration -ConfigName $configName -Reload
    }
}

<#
.SYNOPSIS
    Validates configuration file
#>
function Test-ConfigurationValidity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    $errors = @()
    $warnings = @()
    
    try {
        $config = Import-PowerShellDataFile -Path $Path
        
        # Check required sections
        $requiredSections = @('Manifest', 'Core')
        foreach ($section in $requiredSections) {
            if (-not $config.ContainsKey($section)) {
                $errors += "Missing required section: $section"
            }
        }
        
        # Check Manifest fields
        if ($config.Manifest) {
            $requiredFields = @('Name', 'Version', 'Type')
            foreach ($field in $requiredFields) {
                if (-not $config.Manifest.ContainsKey($field)) {
                    $warnings += "Manifest missing recommended field: $field"
                }
            }
        }
        
        # Check Core section
        if ($config.Core) {
            if (-not $config.Core.Profile) {
                $warnings += "Core.Profile not specified"
            }
            if (-not $config.Core.Environment) {
                $warnings += "Core.Environment not specified"
            }
        }
        
    } catch {
        $errors += "Failed to parse configuration: $_"
    }
    
    return [PSCustomObject]@{
        IsValid = $errors.Count -eq 0
        Errors = $errors
        Warnings = $warnings
        Path = $Path
    }
}

<#
.SYNOPSIS
    Exports configuration to different format
#>
function Export-ConfigurationTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [ValidateSet('Minimal', 'Standard', 'Full')]
        [string]$Profile = 'Standard',
        
        [string]$Environment = 'Development'
    )
    
    $template = @"
@{
    # ===================================================================
    # Configuration Manifest
    # ===================================================================
    Manifest = @{
        Name = 'AitherZero'
        Version = '2.0.0'
        Type = 'Infrastructure Automation Platform'
        Description = 'Configuration for $Environment environment'
    }
    
    # ===================================================================
    # Core Configuration
    # ===================================================================
    Core = @{
        Profile = '$Profile'
        Environment = '$Environment'
        ProjectRoot = "`$PWD"
    }
    
    # ===================================================================
    # Features
    # ===================================================================
    Features = @{
        Git = @{ Enabled = `$true }
        Docker = @{ Enabled = `$false }
        Node = @{ Enabled = `$false }
    }
    
    # ===================================================================
    # Extensions
    # ===================================================================
    Extensions = @{
        EnabledExtensions = @()
    }
    
    # ===================================================================
    # Automation
    # ===================================================================
    Automation = @{
        MaxConcurrency = 4
        DefaultTimeout = 300
    }
}
"@
    
    Set-Content -Path $OutputPath -Value $template
    Write-Host "✅ Configuration template created: $OutputPath" -ForegroundColor Green
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-ConfigManager'
    'Discover-Configurations'
    'Import-ConfigManifest'
    'Build-CapabilitiesFromManifest'
    'Switch-Configuration'
    'Get-AvailableConfigurations'
    'Get-CurrentConfiguration'
    'Get-ManifestCapabilities'
    'Show-ConfigurationSelector'
    'Edit-Configuration'
    'Test-ConfigurationValidity'
    'Export-ConfigurationTemplate'
)
