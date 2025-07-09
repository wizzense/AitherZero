# CoreApp PowerShell Module
# Consolidates lab utilities, runner scripts, and configuration files
# NOW SERVES AS PARENT ORCHESTRATION MODULE FOR ALL OTHER MODULES

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

# Module-level variables for orchestration
$script:CoreModules = @(
    # Core Infrastructure (Required)
    @{ Name = 'Logging'; Path = 'modules/Logging'; Description = 'Centralized logging system'; Required = $true },
    @{ Name = 'LabRunner'; Path = 'modules/LabRunner'; Description = 'Lab automation and script execution'; Required = $true },
    @{ Name = 'OpenTofuProvider'; Path = 'modules/OpenTofuProvider'; Description = 'OpenTofu/Terraform infrastructure deployment'; Required = $true },

    # Platform Services
    @{ Name = 'ModuleCommunication'; Path = 'modules/ModuleCommunication'; Description = 'Scalable inter-module communication bus'; Required = $true },
    @{ Name = 'ConfigurationCore'; Path = 'modules/ConfigurationCore'; Description = 'Core configuration management with 25+ functions'; Required = $true },
    @{ Name = 'ConfigurationCarousel'; Path = 'modules/ConfigurationCarousel'; Description = 'Environment switching and configuration sets'; Required = $false },
    @{ Name = 'ConfigurationRepository'; Path = 'modules/ConfigurationRepository'; Description = 'Git-based configuration repository management'; Required = $false },
    @{ Name = 'ConfigurationManager'; Path = 'modules/ConfigurationManager'; Description = 'Configuration testing and coordination'; Required = $false },
    @{ Name = 'OrchestrationEngine'; Path = 'modules/OrchestrationEngine'; Description = 'Advanced workflow and playbook execution'; Required = $false },
    @{ Name = 'ParallelExecution'; Path = 'modules/ParallelExecution'; Description = 'Parallel task execution'; Required = $false },
    @{ Name = 'ProgressTracking'; Path = 'modules/ProgressTracking'; Description = 'Visual progress tracking for operations'; Required = $false },

    # Feature Modules
    @{ Name = 'ISOManager'; Path = 'modules/ISOManager'; Description = 'Comprehensive ISO management: download, organization, customization, and autounattend generation'; Required = $false },
    @{ Name = 'SecureCredentials'; Path = 'modules/SecureCredentials'; Description = 'Enterprise-grade credential management'; Required = $false },
    @{ Name = 'RemoteConnection'; Path = 'modules/RemoteConnection'; Description = 'Multi-protocol remote connection management'; Required = $false },
    @{ Name = 'SystemMonitoring'; Path = 'modules/SystemMonitoring'; Description = 'System performance monitoring'; Required = $false },
    @{ Name = 'RestAPIServer'; Path = 'modules/RestAPIServer'; Description = 'REST API server and webhook support'; Required = $false },

    # Development Tools
    @{ Name = 'DevEnvironment'; Path = 'modules/DevEnvironment'; Description = 'Development environment management'; Required = $false },
    @{ Name = 'PatchManager'; Path = 'modules/PatchManager'; Description = 'Git-controlled patch management'; Required = $false },
    @{ Name = 'TestingFramework'; Path = 'modules/TestingFramework'; Description = 'Unified testing framework'; Required = $false },
    @{ Name = 'AIToolsIntegration'; Path = 'modules/AIToolsIntegration'; Description = 'AI development tools management'; Required = $false },

    # Maintenance & Operations
    @{ Name = 'BackupManager'; Path = 'modules/BackupManager'; Description = 'Backup and maintenance operations'; Required = $false },
    @{ Name = 'UnifiedMaintenance'; Path = 'modules/UnifiedMaintenance'; Description = 'Unified maintenance operations'; Required = $false },
    @{ Name = 'ScriptManager'; Path = 'modules/ScriptManager'; Description = 'Script management and templates'; Required = $false },
    @{ Name = 'RepoSync'; Path = 'modules/RepoSync'; Description = 'Repository synchronization and management'; Required = $false },
    @{ Name = 'SecurityAutomation'; Path = 'modules/SecurityAutomation'; Description = 'Security automation and compliance'; Required = $false },
    @{ Name = 'SetupWizard'; Path = 'modules/SetupWizard'; Description = 'Intelligent setup and onboarding wizard'; Required = $false },
    
    # Utility Services
    @{ Name = 'UtilityServices'; Path = 'modules/UtilityServices'; Description = 'Utility services integration testing'; Required = $false },
    @{ Name = 'SemanticVersioning'; Path = 'modules/SemanticVersioning'; Description = 'Semantic versioning utilities'; Required = $false },
    @{ Name = 'LicenseManager'; Path = 'modules/LicenseManager'; Description = 'License management and feature access control'; Required = $false },
    @{ Name = 'PSScriptAnalyzerIntegration'; Path = 'modules/PSScriptAnalyzerIntegration'; Description = 'PowerShell code analysis automation'; Required = $false },
    @{ Name = 'StartupExperience'; Path = 'modules/StartupExperience'; Description = 'Interactive startup and configuration management'; Required = $false }
)

$script:LoadedModules = @{

}

# Create Public and Private directories if they don't exist
$publicFolder = Join-Path $PSScriptRoot 'Public'
$privateFolder = Join-Path $PSScriptRoot 'Private'

if (-not (Test-Path $publicFolder)) {
    New-Item -ItemType Directory -Path $publicFolder -Force | Out-Null
}

if (-not (Test-Path $privateFolder)) {
    New-Item -ItemType Directory -Path $privateFolder -Force | Out-Null
}

# Import public functions
$publicFunctions = @(
    Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -ErrorAction SilentlyContinue
)

# Import private functions if they exist
$privateFunctions = @(
    Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue
)

# Load all functions
$allFunctions = $privateFunctions + $publicFunctions

foreach ($function in $allFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Imported function: $($function.BaseName)"
    } catch {
        Write-Error "Failed to import function $($function.FullName): $_"
    }
}

# Basic logging function if not already defined
if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
    function Write-CustomLog {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Message,

            [Parameter()]
            [ValidateSet('ERROR', 'WARN', 'INFO', 'SUCCESS', 'DEBUG', 'TRACE', 'VERBOSE')]
            [string]$Level = 'INFO',

            [Parameter()]
            [string]$Component = 'CoreApp'
        )

        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARN' { 'Yellow' }
            'INFO' { 'Green' }
            'SUCCESS' { 'Cyan' }
            'DEBUG' { 'Gray' }
            'VERBOSE' { 'Magenta' }
            'TRACE' { 'DarkGray' }
            default { 'White' }
        }
          Write-Host "[$Level] [$Component] $Message" -ForegroundColor $color
    }
}

# Core functions if not defined in Public folder
if (-not (Get-Command Invoke-CoreApplication -ErrorAction SilentlyContinue)) {    function Invoke-CoreApplication {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param(
            [Parameter(Mandatory = $true)]
            [string]$ConfigPath,

            [Parameter()]
            [string[]]$Scripts,

            [Parameter()]
            [switch]$Auto,

            [Parameter()]
            [switch]$Force,

            [Parameter()]
            [switch]$NonInteractive
        )
          process {
            Write-CustomLog -Message 'Starting core application execution' -Level 'INFO'

            try {
                # Load configuration
                if (-Not (Test-Path $ConfigPath)) {
                    throw "Configuration file not found at $ConfigPath"
                }

                $config = Get-Content $ConfigPath | ConvertFrom-Json
                Write-CustomLog -Message 'Loaded configuration' -Level 'INFO'

                # Initialize the complete CoreApp ecosystem
                if (-not $script:LoadedModules.Count) {
                    Write-CustomLog -Message 'Initializing CoreApp ecosystem...' -Level 'INFO'
                    Initialize-CoreApplication -RequiredOnly:(-not $Auto)
                }

                # Execute lab runner
                Write-CustomLog -Message 'Core application operation started' -Level 'INFO'

                # Run specified scripts or all scripts
                if ($Scripts) {
                    foreach ($script in $Scripts) {
                        $scriptPath = Join-Path $PSScriptRoot 'scripts' $script
                        if (Test-Path $scriptPath) {
                            Write-CustomLog -Message "Executing script: $script" -Level 'INFO'
                            if ($PSCmdlet.ShouldProcess($script, 'Execute script')) {
                                & $scriptPath -Config $config
                            }
                        } else {
                            Write-CustomLog -Message "Script not found: $script" -Level 'WARN'
                        }
                    }
                } else {
                    Write-CustomLog -Message 'No specific scripts specified - running core operations' -Level 'INFO'

                    # If Auto mode and LabRunner is available, use it for orchestration
                    if ($Auto -and $script:LoadedModules.ContainsKey('LabRunner')) {
                        Write-CustomLog -Message 'Auto mode: delegating to LabRunner for full orchestration' -Level 'INFO'
                        # Could call LabRunner functions here if needed
                    }
                }

                Write-CustomLog -Message 'Core application operation completed successfully' -Level 'SUCCESS'
                return $true

            } catch {
                Write-CustomLog -Message "Core application operation failed: $($_.Exception.Message)" -Level 'ERROR'
                throw
            }
        }
    }
}

if (-not (Get-Command Start-LabRunner -ErrorAction SilentlyContinue)) {
    function Start-LabRunner {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param(
            [Parameter(Mandatory = $true)]
            [string]$ConfigPath,

            [Parameter()]
            [switch]$Parallel,

            [Parameter()]
            [switch]$NonInteractive
        )

        process {
            try {
                if ($Parallel) {
                    Write-CustomLog -Message 'Parallel lab runner not implemented yet - using standard runner' -Level 'WARN'
                    return Invoke-CoreApplication -ConfigPath $ConfigPath
                } else {
                    if ($PSCmdlet.ShouldProcess($ConfigPath, 'Start lab runner')) {
                        return Invoke-CoreApplication -ConfigPath $ConfigPath
                    } else {
                        # Return true for WhatIf scenarios
                        return $true
                    }
                }
            } catch {
                Write-CustomLog -Message "Lab runner failed: $($_.Exception.Message)" -Level 'ERROR'
                throw
            }
        }
    }
}

if (-not (Get-Command Get-CoreConfiguration -ErrorAction SilentlyContinue)) {
    function Get-CoreConfiguration {
        [CmdletBinding()]
        param(
            [Parameter()]
            [string]$ConfigPath = (Join-Path $PSScriptRoot 'default-config.json')
        )

        process {
            try {
                if (Test-Path $ConfigPath) {
                    return Get-Content $ConfigPath | ConvertFrom-Json
                } else {
                    throw "Configuration file not found: $ConfigPath"
                }
            } catch {
                Write-CustomLog -Message "Failed to load configuration: $($_.Exception.Message)" -Level 'ERROR'
                throw
            }
        }
    }
}

if (-not (Get-Command Test-CoreApplicationHealth -ErrorAction SilentlyContinue)) {
    function Test-CoreApplicationHealth {
        [CmdletBinding()]
        param()

        process {
            try {
                Write-CustomLog -Message 'Running core application health check' -Level 'INFO'

                # Check configuration files
                $configPath = Join-Path $PSScriptRoot 'default-config.json'
                if (-not (Test-Path $configPath)) {
                    Write-CustomLog -Message 'Default configuration file missing' -Level 'ERROR'
                    return $false
                }

                # Check scripts directory
                $scriptsPath = Join-Path $PSScriptRoot 'scripts'
                if (-not (Test-Path $scriptsPath)) {
                    Write-CustomLog -Message 'Scripts directory missing' -Level 'ERROR'
                    return $false
                }

                Write-CustomLog -Message 'Core application health check passed' -Level 'INFO'
                return $true

            } catch {
                Write-CustomLog -Message "Health check failed: $($_.Exception.Message)" -Level 'ERROR'
                return $false
            }
        }
    }
}

if (-not (Get-Command Get-PlatformInfo -ErrorAction SilentlyContinue)) {
    function Get-PlatformInfo {
        [CmdletBinding()]
        param()

        process {
            if ($IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and -not (Get-Command uname -ErrorAction SilentlyContinue))) {
                return 'Windows'
            } elseif ($IsMacOS -or (uname) -eq 'Darwin') {
                return 'macOS'
            } elseif ($IsLinux -or (uname) -match 'Linux') {
                return 'Linux'
            } else {
                return 'Unknown'
            }
        }
    }
}

# Core orchestration functions for parent module functionality

if (-not (Get-Command Initialize-CoreApplication -ErrorAction SilentlyContinue)) {
    function Initialize-CoreApplication {
        <#
        .SYNOPSIS
            Initializes the complete CoreApp ecosystem with all modules
        .DESCRIPTION
            Sets up environment, imports required modules, and validates the complete system
        .PARAMETER RequiredOnly
            Import only required modules (Logging, LabRunner)
        .PARAMETER Force
            Force reimport of all modules
        #>
        [CmdletBinding()]
        param(
            [Parameter()]
            [switch]$RequiredOnly,

            [Parameter()]
            [switch]$Force
        )

        process {
            try {
                Write-CustomLog -Message 'Initializing CoreApp ecosystem...' -Level 'INFO'

                # Step 1: Setup environment variables
                if (-not $env:PROJECT_ROOT) {
                    $env:PROJECT_ROOT = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
                    Write-CustomLog -Message "Set PROJECT_ROOT: $env:PROJECT_ROOT" -Level 'INFO'
                }

                if (-not $env:PWSH_MODULES_PATH) {
                    $env:PWSH_MODULES_PATH = Join-Path $env:PROJECT_ROOT (Join-Path "aither-core" "modules")
                    Write-CustomLog -Message "Set PWSH_MODULES_PATH: $env:PWSH_MODULES_PATH" -Level 'INFO'
                }

                # Step 2: Import core modules
                $result = Import-CoreModules -RequiredOnly:$RequiredOnly -Force:$Force

                # Step 3: Validate system health
                $healthResult = Test-CoreApplicationHealth

                if ($healthResult -and $result.ImportedCount -gt 0) {
                    Write-CustomLog -Message "CoreApp ecosystem initialized successfully - $($result.ImportedCount) modules loaded" -Level 'SUCCESS'
                    return $true
                } else {
                    Write-CustomLog -Message 'CoreApp initialization completed with issues' -Level 'WARN'
                    return $false
                }

            } catch {
                Write-CustomLog -Message "CoreApp initialization failed: $($_.Exception.Message)" -Level 'ERROR'
                throw
            }
        }
    }
}

if (-not (Get-Command Import-CoreModules -ErrorAction SilentlyContinue)) {
    function Import-CoreModules {
        <#
        .SYNOPSIS
            Imports all available CoreApp modules with dependency resolution
        .DESCRIPTION
            Dynamically discovers and imports modules in the correct order based on
            their dependencies. Uses topological sorting to ensure dependencies are
            loaded before dependent modules. Logging module is always loaded first.
        .PARAMETER RequiredOnly
            Import only modules marked as required
        .PARAMETER Force
            Force reimport of modules
        .PARAMETER UseDependencyResolution
            Use the dependency resolution system to determine load order.
            Defaults to $true. Set to $false to use legacy load order.
        .PARAMETER UseParallelLoading
            Use parallel loading for modules at the same dependency depth.
            Defaults to $true for better performance.
        #>
        [CmdletBinding()]
        param(
            [Parameter()]
            [switch]$RequiredOnly,

            [Parameter()]
            [switch]$Force,

            [Parameter()]
            [bool]$UseDependencyResolution = $true,

            [Parameter()]
            [bool]$UseParallelLoading = $true
        )

        process {
            # Check if parallel loading is requested and available
            if ($UseParallelLoading -and $UseDependencyResolution) {
                # Try to use the parallel loading function if available
                if (Get-Command Import-CoreModulesParallel -ErrorAction SilentlyContinue) {
                    Write-CustomLog -Message "Using parallel module loading for improved performance..." -Level 'INFO'
                    return Import-CoreModulesParallel -RequiredOnly:$RequiredOnly -Force:$Force
                } else {
                    Write-CustomLog -Message "Parallel loading function not available, falling back to sequential loading" -Level 'DEBUG'
                }
            }

            $importResults = @{
                ImportedCount = 0
                FailedCount = 0
                SkippedCount = 0
                Details = @()
                LoadOrder = @()
                DependencyInfo = $null
            }

            # Get modules to import based on RequiredOnly flag
            $requestedModules = if ($RequiredOnly) {
                $script:CoreModules | Where-Object { $_.Required } | Select-Object -ExpandProperty Name
            } else {
                $script:CoreModules | Select-Object -ExpandProperty Name
            }

            Write-CustomLog -Message "Preparing to import $($requestedModules.Count) modules..." -Level 'INFO'

            # Determine load order
            $modulesToImport = @()
            
            if ($UseDependencyResolution) {
                try {
                    # Get module dependencies
                    $dependencyGraph = Get-ModuleDependencies -ModulePath (Join-Path $PSScriptRoot "modules")
                    
                    # Resolve load order
                    $loadOrderResult = Resolve-ModuleLoadOrder -DependencyGraph $dependencyGraph -ModulesToLoad $requestedModules
                    
                    $importResults.LoadOrder = $loadOrderResult.LoadOrder
                    $importResults.DependencyInfo = $loadOrderResult
                    
                    # Map load order to module info
                    foreach ($moduleName in $loadOrderResult.LoadOrder) {
                        $moduleInfo = $script:CoreModules | Where-Object { $_.Name -eq $moduleName } | Select-Object -First 1
                        if ($moduleInfo) {
                            $modulesToImport += $moduleInfo
                        }
                    }
                    
                    if ($loadOrderResult.CircularDependencies.Count -gt 0) {
                        Write-CustomLog -Message "Circular dependencies detected: $($loadOrderResult.CircularDependencies -join ', ')" -Level 'WARNING'
                    }
                    
                    Write-CustomLog -Message "Using dependency-resolved load order" -Level 'INFO'
                    
                } catch {
                    Write-CustomLog -Message "Failed to resolve dependencies, falling back to legacy order: $($_.Exception.Message)" -Level 'WARNING'
                    $UseDependencyResolution = $false
                }
            }
            
            # Fallback to legacy order if dependency resolution is disabled or failed
            if (-not $UseDependencyResolution) {
                $modulesToImport = if ($RequiredOnly) {
                    $script:CoreModules | Where-Object { $_.Required }
                } else {
                    $script:CoreModules
                }
                $importResults.LoadOrder = $modulesToImport | Select-Object -ExpandProperty Name
            }

            Write-CustomLog -Message "Importing $($modulesToImport.Count) modules in resolved order..." -Level 'INFO'

            # Import modules in the determined order
            foreach ($moduleInfo in $modulesToImport) {
                try {
                    $modulePath = Join-Path $PSScriptRoot $moduleInfo.Path

                    if (-not (Test-Path $modulePath)) {
                        Write-CustomLog -Message "Module path not found: $modulePath" -Level 'WARNING'
                        $importResults.SkippedCount++
                        $importResults.Details += @{
                            Name = $moduleInfo.Name
                            Status = 'Skipped'
                            Reason = 'Path not found'
                        }
                        continue
                    }

                    # Check if already loaded (unless Force specified)
                    if ($script:LoadedModules.ContainsKey($moduleInfo.Name) -and -not $Force) {
                        Write-CustomLog -Message "Module already loaded: $($moduleInfo.Name)" -Level 'DEBUG'
                        $importResults.SkippedCount++
                        $importResults.Details += @{
                            Name = $moduleInfo.Name
                            Status = 'Already Loaded'
                            Reason = 'Previously imported'
                            LoadTime = $script:LoadedModules[$moduleInfo.Name].ImportTime
                        }
                        continue
                    }

                    # Import with Force only if explicitly requested or module not loaded
                    $shouldForceImport = $Force -or -not (Get-Module -Name $moduleInfo.Name -ErrorAction SilentlyContinue)

                    Import-Module $modulePath -Force:$shouldForceImport -Global -ErrorAction Stop
                    $script:LoadedModules[$moduleInfo.Name] = @{
                        Path = $modulePath
                        ImportTime = Get-Date
                        Description = $moduleInfo.Description
                    }

                    Write-CustomLog -Message "✓ Imported: $($moduleInfo.Name)" -Level 'SUCCESS'
                    $importResults.ImportedCount++
                    $importResults.Details += @{
                        Name = $moduleInfo.Name
                        Status = 'Imported'
                        Reason = $moduleInfo.Description
                    }

                } catch {
                    Write-CustomLog -Message "✗ Failed to import $($moduleInfo.Name): $($_.Exception.Message)" -Level 'ERROR'
                    $importResults.FailedCount++
                    $importResults.Details += @{
                        Name = $moduleInfo.Name
                        Status = 'Failed'
                        Reason = $_.Exception.Message
                    }
                }
            }

            Write-CustomLog -Message "Module import complete: $($importResults.ImportedCount) imported, $($importResults.FailedCount) failed, $($importResults.SkippedCount) skipped" -Level 'INFO'
            return $importResults
        }
    }
}

if (-not (Get-Command Get-CoreModuleStatus -ErrorAction SilentlyContinue)) {
    function Get-CoreModuleStatus {
        <#
        .SYNOPSIS
            Gets the status of all CoreApp modules
        .DESCRIPTION
            Returns detailed information about module availability and load status
        #>
        [CmdletBinding()]
        param()

        process {
            $moduleStatus = @()

            foreach ($moduleInfo in $script:CoreModules) {
                $modulePath = Join-Path $PSScriptRoot $moduleInfo.Path
                $isLoaded = $script:LoadedModules.ContainsKey($moduleInfo.Name)
                $isAvailable = Test-Path $modulePath

                $status = @{
                    Name = $moduleInfo.Name
                    Description = $moduleInfo.Description
                    Required = $moduleInfo.Required
                    Available = $isAvailable
                    Loaded = $isLoaded
                    Path = $modulePath
                }

                if ($isLoaded) {
                    $status.LoadTime = $script:LoadedModules[$moduleInfo.Name].ImportTime
                }

                $moduleStatus += $status
            }

            return $moduleStatus
        }
    }
}

if (-not (Get-Command Invoke-UnifiedMaintenance -ErrorAction SilentlyContinue)) {
    function Invoke-UnifiedMaintenance {
        <#
        .SYNOPSIS
            Unified entry point for all maintenance operations
        .DESCRIPTION
            Orchestrates maintenance across all modules through CoreApp
        .PARAMETER Mode
            Maintenance mode: Quick, Full, Emergency
        .PARAMETER AutoFix
            Automatically apply fixes where possible
        #>
        [CmdletBinding(SupportsShouldProcess = $true)]
        param(
            [Parameter()]
            [ValidateSet('Quick', 'Full', 'Emergency')]
            [string]$Mode = 'Quick',

            [Parameter()]
            [switch]$AutoFix
        )

        process {
            try {
                Write-CustomLog -Message "Starting unified maintenance in $Mode mode..." -Level 'INFO'

                # Ensure core modules are loaded
                Import-CoreModules -RequiredOnly

                $results = @{
                    Mode = $Mode
                    StartTime = Get-Date
                    Operations = @()
                    Success = $true
                }

                # Run maintenance based on available modules
                if ($script:LoadedModules.ContainsKey('BackupManager')) {
                    if ($PSCmdlet.ShouldProcess('BackupManager', 'Run maintenance')) {
                        try {
                            $backupResult = Invoke-BackupMaintenance -ProjectRoot $env:PROJECT_ROOT -Mode $Mode -AutoFix:$AutoFix
                            $results.Operations += @{ Module = 'BackupManager'; Result = $backupResult }
                        } catch {
                            Write-CustomLog -Message "BackupManager maintenance failed: $($_.Exception.Message)" -Level 'ERROR'
                            $results.Success = $false
                        }
                    }
                }

                if ($script:LoadedModules.ContainsKey('UnifiedMaintenance')) {
                    if ($PSCmdlet.ShouldProcess('UnifiedMaintenance', 'Run maintenance')) {
                        try {
                            $unifiedResult = Start-UnifiedMaintenance -Mode $Mode -AutoFix:$AutoFix
                            $results.Operations += @{ Module = 'UnifiedMaintenance'; Result = $unifiedResult }
                        } catch {
                            Write-CustomLog -Message "UnifiedMaintenance failed: $($_.Exception.Message)" -Level 'ERROR'
                            $results.Success = $false
                        }
                    }
                }

                $results.EndTime = Get-Date
                $results.Duration = $results.EndTime - $results.StartTime

                if ($results.Success) {
                    Write-CustomLog -Message "Unified maintenance completed successfully in $($results.Duration.TotalSeconds) seconds" -Level 'SUCCESS'
                } else {
                    Write-CustomLog -Message "Unified maintenance completed with errors" -Level 'WARN'
                }

                return $results

            } catch {
                Write-CustomLog -Message "Unified maintenance failed: $($_.Exception.Message)" -Level 'ERROR'
                throw
            }
        }
    }
}

if (-not (Get-Command Start-DevEnvironmentSetup -ErrorAction SilentlyContinue)) {
    function Start-DevEnvironmentSetup {
        <#
        .SYNOPSIS
            Unified development environment setup through CoreApp
        .DESCRIPTION
            Orchestrates complete development environment setup using DevEnvironment module
        .PARAMETER Force
            Force setup even if environment appears configured
        .PARAMETER SkipModuleImportFixes
            Skip module import issue resolution
        #>
        [CmdletBinding(SupportsShouldProcess = $true)]
        param(
            [Parameter()]
            [switch]$Force,

            [Parameter()]
            [switch]$SkipModuleImportFixes
        )

        process {
            try {
                Write-CustomLog -Message 'Starting development environment setup through CoreApp...' -Level 'INFO'

                # Import DevEnvironment module if available
                Import-CoreModules -RequiredOnly:$false

                if ($script:LoadedModules.ContainsKey('DevEnvironment')) {
                    if ($PSCmdlet.ShouldProcess('DevEnvironment', 'Initialize development environment')) {
                        Initialize-DevelopmentEnvironment -Force:$Force -SkipModuleImportFixes:$SkipModuleImportFixes
                        Write-CustomLog -Message 'Development environment setup completed' -Level 'SUCCESS'
                        return $true
                    }
                } else {
                    Write-CustomLog -Message 'DevEnvironment module not available - basic setup only' -Level 'WARN'
                    Initialize-CoreApplication -RequiredOnly
                    return $true
                }

            } catch {
                Write-CustomLog -Message "Development environment setup failed: $($_.Exception.Message)" -Level 'ERROR'
                throw
            }
        }
    }
}

# Enhanced Integration Functions for Seamless Module Orchestration

if (-not (Get-Command Get-IntegratedToolset -ErrorAction SilentlyContinue)) {
    function Get-IntegratedToolset {
        <#
        .SYNOPSIS
            Gets a comprehensive overview of all available toolsets and their integration status
        .DESCRIPTION
            Provides a unified view of all modules, their capabilities, and cross-module integrations
        #>
        [CmdletBinding()]
        param(
            [Parameter()]
            [switch]$Detailed
        )

        process {
            $toolset = @{
                CoreModules = @{}
                Capabilities = @{}
                Integrations = @{}
                HealthStatus = @{}
                QuickActions = @{}
            }

            # Analyze each loaded module
            foreach ($moduleName in $script:LoadedModules.Keys) {
                $moduleInfo = $script:LoadedModules[$moduleName]
                $module = Get-Module -Name $moduleName -ErrorAction SilentlyContinue

                if ($module) {
                    $commands = Get-Command -Module $moduleName -ErrorAction SilentlyContinue
                    $toolset.CoreModules[$moduleName] = @{
                        Description = $moduleInfo.Description
                        CommandCount = $commands.Count
                        Commands = ($commands | Select-Object -ExpandProperty Name)
                        LoadTime = $moduleInfo.ImportTime
                        Status = 'Loaded'
                    }

                    # Categorize capabilities
                    switch ($moduleName) {
                        'ISOManager' {
                            $toolset.Capabilities['ISOManagement'] = @{
                                Module = $moduleName
                                Functions = @('Get-ISODownload', 'Get-ISOInventory', 'New-ISORepository')
                                Description = 'Complete ISO lifecycle management'
                            }
                        }
                        'ISOManager' {
                            $toolset.Capabilities['ISOCustomization'] = @{
                                Module = $moduleName
                                Functions = @('New-AutounattendFile', 'New-CustomISO')
                                Description = 'ISO customization and automation'
                            }
                        }
                        'PatchManager' {
                            $toolset.Capabilities['PatchManagement'] = @{
                                Module = $moduleName
                                Functions = @('Invoke-PatchWorkflow', 'New-PatchIssue', 'New-PatchPR')
                                Description = 'Git-controlled development workflow'
                            }
                        }
                        'LabRunner' {
                            $toolset.Capabilities['LabAutomation'] = @{
                                Module = $moduleName
                                Functions = @('Start-LabAutomation', 'Invoke-LabScript')
                                Description = 'Infrastructure lab orchestration'
                            }
                        }
                        'TestingFramework' {
                            $toolset.Capabilities['Testing'] = @{
                                Module = $moduleName
                                Functions = @('Invoke-BulletproofTests', 'Start-TestValidation')
                                Description = 'Comprehensive testing suite'
                            }
                        }
                        'BackupManager' {
                            $toolset.Capabilities['BackupManagement'] = @{
                                Module = $moduleName
                                Functions = @('Start-BackupOperation', 'Remove-OldBackups')
                                Description = 'Automated backup and cleanup'
                            }
                        }
                        'SecureCredentials' {
                            $toolset.Capabilities['CredentialManagement'] = @{
                                Module = $moduleName
                                Functions = @('Get-SecureCredential', 'Set-SecureCredential')
                                Description = 'Enterprise credential security'
                            }
                        }
                        'RemoteConnection' {
                            $toolset.Capabilities['RemoteAccess'] = @{
                                Module = $moduleName
                                Functions = @('Connect-RemoteSystem', 'Test-RemoteConnection')
                                Description = 'Multi-protocol remote connections'
                            }
                        }
                    }
                }
            }

            # Define cross-module integrations
            $toolset.Integrations = @{
                'ISOWorkflow' = @{
                    Description = 'Complete ISO management workflow'
                    Modules = @('ISOManager', 'TestingFramework')
                    Workflow = 'Download → Customize → Test → Deploy'
                }
                'DevelopmentWorkflow' = @{
                    Description = 'Development and deployment pipeline'
                    Modules = @('PatchManager', 'TestingFramework', 'BackupManager')
                    Workflow = 'Patch → Test → Backup → Deploy'
                }
                'LabDeployment' = @{
                    Description = 'End-to-end lab infrastructure deployment'
                    Modules = @('LabRunner', 'ISOManager', 'RemoteConnection')
                    Workflow = 'Plan → Provision → Configure → Connect'
                }
                'MaintenanceOperations' = @{
                    Description = 'Automated maintenance and housekeeping'
                    Modules = @('UnifiedMaintenance', 'BackupManager', 'TestingFramework')
                    Workflow = 'Backup → Clean → Validate → Report'
                }
            }

            # Quick actions for common tasks
            $toolset.QuickActions = @{
                'CreateISO' = @{
                    Description = 'Download and customize an ISO'
                    Command = 'Get-ISODownload | New-CustomISO'
                    Modules = @('ISOManager')
                }
                'RunTests' = @{
                    Description = 'Execute comprehensive test suite'
                    Command = 'Invoke-BulletproofTests -ValidationLevel Complete'
                    Modules = @('TestingFramework')
                }
                'CreatePatch' = @{
                    Description = 'Create and manage code patches'
                    Command = 'Invoke-PatchWorkflow -CreatePR'
                    Modules = @('PatchManager')
                }
                'LabSetup' = @{
                    Description = 'Initialize complete lab environment'
                    Command = 'Start-LabAutomation -Auto'
                    Modules = @('LabRunner', 'ISOManager')
                }
            }

            return $toolset
        }
    }
}

if (-not (Get-Command Invoke-IntegratedWorkflow -ErrorAction SilentlyContinue)) {
    function Invoke-IntegratedWorkflow {
        <#
        .SYNOPSIS
            Executes predefined integrated workflows across multiple modules
        .DESCRIPTION
            Orchestrates complex operations that span multiple modules for common scenarios
        #>
        [CmdletBinding(SupportsShouldProcess)]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('ISOWorkflow', 'DevelopmentWorkflow', 'LabDeployment', 'MaintenanceOperations')]
            [string]$WorkflowType,

            [Parameter()]
            [hashtable]$Parameters = @{},            [Parameter()]
            [switch]$DryRun
        )

        process {
            Write-CustomLog -Message "Starting integrated workflow: $WorkflowType" -Level 'INFO'

            switch ($WorkflowType) {
                'ISOWorkflow' {
                    if ($PSCmdlet.ShouldProcess("ISO Workflow", "Execute complete ISO management workflow")) {                        # Step 1: Download ISO
                        $isoName = $Parameters.ISOName ?? 'Windows11'
                        Write-CustomLog -Message "Downloading ISO: $isoName" -Level 'INFO'
                        $downloadResult = Get-ISODownload -ISOName $isoName -WhatIf:$DryRun

                        # Step 2: Customize ISO
                        if ($downloadResult -and -not $DryRun) {
                            Write-CustomLog -Message "Customizing ISO with autounattend" -Level 'INFO'
                            $autounattendPath = New-AutounattendFile -ISOName $isoName
                            $customISOResult = New-CustomISO -SourceISO $downloadResult.FilePath -AutounattendPath $autounattendPath
                        }

                        # Step 3: Validate with tests
                        Write-CustomLog -Message "Running validation tests" -Level 'INFO'
                        $testResult = Invoke-BulletproofTests -ValidationLevel Quick -DryRun:$DryRun

                        return @{
                            Workflow = $WorkflowType
                            Download = $downloadResult
                            Customization = $customISOResult ?? 'Skipped (DryRun)'
                            Validation = $testResult
                            Success = $true
                        }
                    }
                }

                'DevelopmentWorkflow' {
                    if ($PSCmdlet.ShouldProcess("Development Workflow", "Execute patch and test workflow")) {
                        # Step 1: Create patch
                        $patchDescription = $Parameters.PatchDescription ?? 'Automated development workflow'
                        Write-CustomLog -Message "Creating patch: $patchDescription" -Level 'INFO'

                        $patchOperation = $Parameters.PatchOperation ?? { Write-Host "Sample patch operation" }
                        $patchResult = Invoke-PatchWorkflow -PatchDescription $patchDescription -PatchOperation $patchOperation -DryRun:$DryRun

                        # Step 2: Run comprehensive tests
                        Write-CustomLog -Message "Running comprehensive test suite" -Level 'INFO'
                        $testResult = Invoke-BulletproofTests -ValidationLevel Standard -DryRun:$DryRun

                        # Step 3: Create backup
                        Write-CustomLog -Message "Creating backup point" -Level 'INFO'
                        $backupResult = Start-BackupOperation -DryRun:$DryRun

                        return @{
                            Workflow = $WorkflowType
                            Patch = $patchResult
                            Tests = $testResult
                            Backup = $backupResult
                            Success = $true
                        }
                    }
                }

                'LabDeployment' {
                    if ($PSCmdlet.ShouldProcess("Lab Deployment", "Execute complete lab setup workflow")) {                        # Step 1: Setup lab environment
                        Write-CustomLog -Message "Initializing lab environment" -Level 'INFO'
                        $labResult = Start-LabAutomation -Auto -DryRun:$DryRun

                        # Step 2: Prepare ISOs
                        Write-CustomLog -Message "Preparing lab ISOs" -Level 'INFO'
                        $isoRepo = New-ISORepository -RepositoryPath ($Parameters.ISOPath ?? "$env:TEMP/LabISOs") -WhatIf:$DryRun

                        # Step 3: Test connections
                        Write-CustomLog -Message "Testing remote connections" -Level 'INFO'
                        $connectionResult = Test-RemoteConnection -DryRun:$DryRun

                        return @{
                            Workflow = $WorkflowType
                            Lab = $labResult
                            ISORepo = $isoRepo
                            Connections = $connectionResult
                            Success = $true
                        }
                    }
                }

                'MaintenanceOperations' {
                    if ($PSCmdlet.ShouldProcess("Maintenance Operations", "Execute maintenance workflow")) {                        # Step 1: Create backup
                        Write-CustomLog -Message "Creating maintenance backup" -Level 'INFO'
                        $backupResult = Start-BackupOperation -DryRun:$DryRun

                        # Step 2: Run unified maintenance
                        Write-CustomLog -Message "Running unified maintenance" -Level 'INFO'
                        $maintenanceResult = Start-UnifiedMaintenance -DryRun:$DryRun

                        # Step 3: Validate system health
                        Write-CustomLog -Message "Validating system health" -Level 'INFO'
                        $healthResult = Test-CoreApplicationHealth

                        return @{
                            Workflow = $WorkflowType
                            Backup = $backupResult
                            Maintenance = $maintenanceResult
                            Health = $healthResult
                            Success = $true
                        }
                    }
                }
            }
        }
    }
}

if (-not (Get-Command Test-ConsolidationHealth -ErrorAction SilentlyContinue)) {
    function Test-ConsolidationHealth {
        <#
        .SYNOPSIS
            Tests the health of module consolidation and integration
        .DESCRIPTION
            Validates that the consolidated module structure is working correctly,
            all expected modules are available, and integration between modules is functioning
        .PARAMETER Detailed
            Include detailed module analysis
        .PARAMETER TestIntegration
            Test cross-module integration points
        #>
        [CmdletBinding()]
        param(
            [Parameter()]
            [switch]$Detailed,

            [Parameter()]
            [switch]$TestIntegration
        )

        process {
            try {
                Write-CustomLog -Message "Starting consolidation health check..." -Level 'INFO'

                $healthReport = @{
                    ConsolidationStatus = @{
                        CoreModuleAvailable = Test-Path (Join-Path $PSScriptRoot "AitherCore.psd1")
                        IndividualModulesPath = Join-Path $PSScriptRoot "modules"
                        RegistryModuleCount = $script:CoreModules.Count
                        LoadedModuleCount = $script:LoadedModules.Count
                    }
                    ModuleValidation = @{}
                    DuplicateCheck = @{
                        Status = "Clean"
                        Issues = @()
                    }
                    IntegrationTests = @{}
                    Recommendations = @()
                    Timestamp = Get-Date
                }

                # Check for duplicate modules (like the ISOManagement we just removed)
                $knownModules = $script:CoreModules | ForEach-Object { $_.Name }
                $modulesPath = Join-Path $PSScriptRoot "modules"
                if (Test-Path $modulesPath) {
                    $existingModuleDirs = Get-ChildItem -Path $modulesPath -Directory | Select-Object -ExpandProperty Name

                    foreach ($moduleDir in $existingModuleDirs) {
                        if ($moduleDir -notin $knownModules -and $moduleDir -ne "BUILD-TEST-RELEASE-AUTOMATION-2025.md") {
                            $healthReport.DuplicateCheck.Issues += "Unknown module directory found: $moduleDir"
                            $healthReport.DuplicateCheck.Status = "Issues Found"
                        }
                    }
                }

                # Validate each registered module
                foreach ($moduleInfo in $script:CoreModules) {
                    $validation = @{
                        Name = $moduleInfo.Name
                        Required = $moduleInfo.Required
                        PathExists = Test-Path (Join-Path $PSScriptRoot $moduleInfo.Path)
                        Loaded = $script:LoadedModules.ContainsKey($moduleInfo.Name)
                        Status = "Unknown"
                    }

                    if (-not $validation.PathExists) {
                        $validation.Status = "Missing"
                        if ($moduleInfo.Required) {
                            $healthReport.Recommendations += "CRITICAL: Required module $($moduleInfo.Name) is missing"
                        }
                    } elseif ($validation.Loaded) {
                        $validation.Status = "Loaded"
                        $validation.LoadTime = $script:LoadedModules[$moduleInfo.Name].ImportTime
                    } else {
                        $validation.Status = "Available"
                    }

                    $healthReport.ModuleValidation[$moduleInfo.Name] = $validation
                }

                # Test integration points if requested
                if ($TestIntegration) {
                    Write-CustomLog -Message "Testing cross-module integration..." -Level 'INFO'

                    # Test ConfigurationCore + ConfigurationCarousel integration
                    if ($script:LoadedModules.ContainsKey('ConfigurationCore') -and $script:LoadedModules.ContainsKey('ConfigurationCarousel')) {
                        $healthReport.IntegrationTests.ConfigurationIntegration = @{
                            Status = "Available"
                            Description = "ConfigurationCore and ConfigurationCarousel both loaded"
                        }
                    } else {
                        $healthReport.IntegrationTests.ConfigurationIntegration = @{
                            Status = "Incomplete"
                            Description = "Configuration modules not fully loaded"
                        }
                    }

                    # Test ISOManager integration (after consolidation)
                    if ($script:LoadedModules.ContainsKey('ISOManager')) {
                        $healthReport.IntegrationTests.ISOWorkflow = @{
                            Status = "Available"
                            Description = "ISO workflow modules integrated"
                        }
                    } else {
                        $healthReport.IntegrationTests.ISOWorkflow = @{
                            Status = "Partial"
                            Description = "ISO modules available separately"
                        }
                    }
                }

                # Calculate overall health score
                $requiredModules = $script:CoreModules | Where-Object { $_.Required }
                $requiredAvailable = ($healthReport.ModuleValidation.Values | Where-Object { $_.Required -and $_.PathExists }).Count
                $healthScore = if ($requiredModules.Count -gt 0) {
                    [Math]::Round(($requiredAvailable / $requiredModules.Count) * 100, 1)
                } else { 100 }

                $healthReport.OverallHealth = @{
                    Score = $healthScore
                    Status = if ($healthScore -eq 100) { "Excellent" }
                             elseif ($healthScore -ge 80) { "Good" }
                             elseif ($healthScore -ge 60) { "Fair" }
                             else { "Poor" }
                    RequiredModulesAvailable = "$requiredAvailable/$($requiredModules.Count)"
                }

                # Log summary
                Write-CustomLog -Message "Consolidation health check completed - Score: $healthScore% ($($healthReport.OverallHealth.Status))" -Level "SUCCESS"

                if ($healthReport.DuplicateCheck.Issues.Count -gt 0) {
                    Write-CustomLog -Message "Duplicate module issues found: $($healthReport.DuplicateCheck.Issues.Count)" -Level "WARN"
                }

                return $healthReport

            } catch {
                Write-CustomLog -Message "Consolidation health check failed: $($_.Exception.Message)" -Level "ERROR"
                throw
            }
        }
    }
}

if (-not (Get-Command Start-QuickAction -ErrorAction SilentlyContinue)) {
    function Start-QuickAction {
        <#
        .SYNOPSIS
            Executes predefined quick actions for common tasks
        .DESCRIPTION
            Provides one-command access to frequently used integrated operations
        #>
        [CmdletBinding(SupportsShouldProcess)]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('CreateISO', 'RunTests', 'CreatePatch', 'LabSetup', 'SystemHealth', 'ModuleStatus')]
            [string]$Action,

            [Parameter()]
            [hashtable]$Parameters = @{
            }
        )

        process {
            Write-CustomLog -Message "Executing quick action: $Action" -Level 'INFO'

            switch ($Action) {
                'CreateISO' {
                    $isoName = $Parameters.ISOName ?? 'Windows11'
                    if ($PSCmdlet.ShouldProcess($isoName, "Download and customize ISO")) {
                        Invoke-IntegratedWorkflow -WorkflowType 'ISOWorkflow' -Parameters @{ ISOName = $isoName }
                    }
                }
                'RunTests' {
                    $level = $Parameters.ValidationLevel ?? 'Standard'
                    if ($PSCmdlet.ShouldProcess("Test Suite", "Run $level validation")) {
                        Invoke-BulletproofTests -ValidationLevel $level
                    }
                }
                'CreatePatch' {
                    $description = $Parameters.Description ?? 'Quick patch via Start-QuickAction'
                    if ($PSCmdlet.ShouldProcess("Patch", "Create patch: $description")) {
                        Invoke-PatchWorkflow -PatchDescription $description -PatchOperation { Write-Host "Quick patch operation executed" }
                    }
                }
                'LabSetup' {
                    if ($PSCmdlet.ShouldProcess("Lab Environment", "Initialize lab setup")) {
                        Invoke-IntegratedWorkflow -WorkflowType 'LabDeployment' -Parameters $Parameters
                    }
                }
                'SystemHealth' {
                    Write-CustomLog -Message "Running comprehensive system health check" -Level 'INFO'
                    $coreHealth = Test-CoreApplicationHealth
                    $moduleStatus = Get-CoreModuleStatus
                    $toolsetOverview = Get-IntegratedToolset

                    return @{
                        CoreHealth = $coreHealth
                        ModuleStatus = $moduleStatus
                        ToolsetOverview = $toolsetOverview
                        Timestamp = Get-Date
                    }
                }
                'ModuleStatus' {
                    return Get-IntegratedToolset -Detailed
                }
            }
        }
    }
}

# Export all public functions
Export-ModuleMember -Function @(
    # Core platform functions
    'Invoke-CoreApplication',
    'Start-LabRunner',
    'Get-CoreConfiguration',
    'Test-CoreApplicationHealth',
    'Write-CustomLog',
    'Get-PlatformInfo',
    'Initialize-CoreApplication',
    'Import-CoreModules',
    'Import-CoreModulesParallel',
    'Get-CoreModuleStatus',
    'Invoke-UnifiedMaintenance',
    'Start-DevEnvironmentSetup',
    'Get-IntegratedToolset',
    'Invoke-IntegratedWorkflow',
    'Start-QuickAction',
    'Test-ConsolidationHealth',

    # Module dependency resolution
    'Get-ModuleDependencies',
    'Resolve-ModuleLoadOrder',
    'Get-ModuleDependencyReport',

    # Unified Platform API Gateway (Phase 4)
    'Initialize-AitherPlatform',
    'New-AitherPlatformAPI',
    'Get-PlatformStatus',
    'Get-PlatformHealth',
    'Get-PlatformLifecycle',
    'Start-PlatformServices',

    # Performance & Error Handling (Phase 5)
    'Optimize-PlatformPerformance',
    'Initialize-PlatformErrorHandling',
    'Write-PlatformError',
    'Write-PlatformLog'
)
